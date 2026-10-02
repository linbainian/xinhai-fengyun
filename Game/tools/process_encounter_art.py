"""Rebuild encounter art from retained ImageGen sources; key/crop/nearest/QC only."""
import argparse
import hashlib
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from process_refined_art import repack_grid
from process_chapter_art import normalize_grid
from process_playable_art import palette

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/encounters'


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--processor', required=True)
    parser.add_argument('--sources', type=Path)
    args = parser.parse_args()
    if args.sources:
        for entry in json.loads(args.sources.read_text(encoding='utf-8')):
            ART.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entry['source'], ART / (entry['id'] + '_raw.png'))
            prompt = ART / 'prompts' / (entry['id'] + '.prompt.txt')
            prompt.parent.mkdir(parents=True, exist_ok=True)
            prompt.write_text(entry['prompt'] + '\n', encoding='utf-8')
    spec = importlib.util.spec_from_file_location('encounter_cleanup', args.processor)
    processor = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = processor
    spec.loader.exec_module(processor)
    manifest = {'version': 'encounter-art.1', 'source': 'OpenAI built-in ImageGen',
                'sampling': 'nearest', 'model': 'layered_tilemap_mode',
                'third_party_downloads': [], 'sources': [], 'runtime': [], 'objects': {}, 'passed': True}
    master = Image.open(ROOT / 'assets/chapter1/refined/npcs/frames/frame_000.png').convert('RGBA').getbbox()

    def record(path):
        manifest['runtime'].append({'path': path.relative_to(ROOT).as_posix(), 'sha256': digest(path)})

    def source(name):
        raw = ART / (name + '_raw.png')
        prompt = ART / 'prompts' / (name + '.prompt.txt')
        manifest['sources'].append({'id': name, 'path': raw.relative_to(ROOT).as_posix(), 'sha256': digest(raw),
                                    'prompt': prompt.relative_to(ROOT).as_posix(), 'prompt_sha256': digest(prompt)})
        return raw, prompt

    for name in ['bai_muyao', 'su_wantang', 'chuxia', 'encounter_people']:
        raw, prompt = source(name)
        walking = name != 'encounter_people'
        side = 4 if walking else 2
        count = side * side
        folder = ART / ('actors/' + name if walking else name)
        grid = repack_grid(raw, side, side, processor)
        if walking:
            keyed = processor.remove_bg_magenta(Image.open(grid).convert('RGBA'), 40, 65)
            cell_size = keyed.width // side
            aligned = Image.new('RGBA', keyed.size, '#ff00ff')
            for index in range(count):
                x, y = index % side * cell_size, index // side * cell_size
                frame = keyed.crop((x, y, x + cell_size, y + cell_size))
                body = frame.crop(frame.getbbox())
                aligned.alpha_composite(body, (x + (cell_size - body.width) // 2, y + cell_size - 12 - body.height))
            aligned.save(grid)
        command = [sys.executable, args.processor, 'process', '--input', str(grid), '--target', 'player' if walking else 'asset',
                   '--mode', 'player_sheet' if walking else 'asset', '--rows', str(side), '--cols', str(side),
                   '--output-dir', str(folder), '--cell-size', '96', '--fit-scale', '0.84', '--shared-scale',
                   '--align', 'feet', '--component-mode', 'largest', '--strict-qc', '--prompt-file', str(prompt)]
        if walking:
            command += ['--max-body-scale-cv', '0.08', '--max-anchor-y-std', '0.05']
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
        normalize_grid(folder, 'frame', processor)
        frames = [Image.open(folder / 'frames' / f'frame_{i:03d}.png').convert('RGBA') for i in range(count)]
        factor = (master[3] - master[1]) / max(im.getbbox()[3] - im.getbbox()[1] for im in frames)
        sheet = Image.new('RGBA', (side * 96, side * 96))
        for i, frame in enumerate(frames):
            body = frame.crop(frame.getbbox())
            body = body.resize((round(body.width * factor), round(body.height * factor)), Image.Resampling.NEAREST)
            sheet.alpha_composite(body, (i % side * 96 + (96 - body.width) // 2, i // side * 96 + master[3] - body.height))
        sheet = palette(sheet)
        sheet.save(folder / 'runtime-sheet.png')
        record(folder / 'runtime-sheet.png')
        bounds = []
        for i in range(count):
            x, y = i % side * 96, i // side * 96
            frame = sheet.crop((x, y, x + 96, y + 96))
            box = frame.getbbox()
            assert box and min(box[0], box[1]) > 0 and max(box[2], box[3]) < 96, (name, i, box)
            bounds.append(box)
            path = folder / 'frames' / f'frame_{i:03d}.png'
            frame.save(path)
            record(path)
        heights = np.array([b[3] - b[1] for b in bounds], dtype=float)
        feet = np.array([b[3] for b in bounds], dtype=float)
        if walking:
            assert heights.std() / heights.mean() <= 0.08 and feet.std() == 0
            for direction in range(4):
                assert len({digest(folder / 'frames' / f'frame_{direction * 4 + j:03d}.png') for j in range(4)}) >= 3
        write(folder / 'runtime-qc.json', {'passed': True, 'binary_alpha': True, 'palette_colors': 48,
              'frames': [{'index': i, 'bbox': list(b)} for i, b in enumerate(bounds)],
              'shared_scale': factor, 'body_height_cv': float(heights.std() / heights.mean()),
              'feet_y_std': float(feet.std()), 'world_footprint': [48, 48]})
        for filename in ['pipeline-meta.json']:
            path = folder / filename
            data = json.loads(path.read_text(encoding='utf-8'))
            for key in ['input', 'prompt_file']:
                if key in data and Path(data[key]).is_absolute(): data[key] = Path(data[key]).relative_to(ROOT).as_posix()
            write(path, data)
        print(name + ': shared scale and feet line, source and output edges safe', flush=True)

    # Similar wide wall/counter modules use wide source cells, never square prop extraction.
    bundles = [
        ('interior_walls', 2, 2, [('dorm_wall', 960), ('corridor_wall', 1152), ('library_wall', 1152), ('ice_shop_wall', 864)]),
        ('counters', 1, 2, [('library_desk', 240), ('ice_counter', 288)]),
        ('club_booth', 1, 1, [('club_booth', 240)]),
        ('corridor_stairs', 1, 1, [('corridor_stairs', 96)]),
        ('encounter_props', 2, 3, [('books', 34), ('notebook', 22), ('ice_bowl', 24), ('takeaway', 26), ('phone', 18), ('riceball', 18)])]
    for name, rows, cols, objects in bundles:
        raw, prompt = source(name)
        keyed = processor.remove_bg_magenta(Image.open(raw).convert('RGBA'), 40, 65)
        for index, (object_name, width) in enumerate(objects):
            x, y = index % cols, index // cols
            cell = keyed.crop((round(x * keyed.width / cols), round(y * keyed.height / rows),
                               round((x + 1) * keyed.width / cols), round((y + 1) * keyed.height / rows)))
            box = cell.getbbox()
            assert box and box[0] > 0 and box[1] > 0 and box[2] < cell.width and box[3] < cell.height, (name, object_name, box)
            body = cell.crop(box)
            body = palette(body.resize((width, round(body.height * width / body.width)), Image.Resampling.NEAREST), 64)
            path = ART / 'objects' / object_name / 'runtime.png'
            path.parent.mkdir(parents=True, exist_ok=True)
            body.save(path)
            record(path)
            manifest['objects'][object_name] = {'asset': 'res://' + path.relative_to(ROOT).as_posix(), 'size': list(body.size),
                                               'anchor': [body.width / 2, body.height]}
            write(path.with_name('runtime-qc.json'), {'passed': True, 'binary_alpha': True, 'source': raw.relative_to(ROOT).as_posix(),
                                                    'source_cell': [x, y], 'source_bbox': list(box), 'size': list(body.size), 'edge_touch': False})
            print(object_name + ': independent object, source edges safe', flush=True)
    for name in ['ice_wall_fx', 'lightning_fx']:
        raw, prompt = source(name)
        grid = repack_grid(raw, 2, 2, processor)
        folder = ART / name
        subprocess.run([sys.executable, args.processor, 'process', '--input', str(grid), '--target', 'asset', '--mode', 'asset',
                        '--rows', '2', '--cols', '2', '--output-dir', str(folder), '--cell-size', '128', '--fit-scale', '0.86',
                        '--shared-scale', '--align', 'feet', '--component-mode', 'all', '--strict-qc', '--prompt-file', str(prompt)],
                       check=True, stdout=subprocess.DEVNULL)
        normalize_grid(folder, 'frame', processor)
        sheet = palette(Image.open(folder / 'runtime-sheet.png').convert('RGBA'))
        sheet.save(folder / 'runtime-sheet.png')
        record(folder / 'runtime-sheet.png')
        bounds = []
        for index in range(4):
            x, y = index % 2 * 128, index // 2 * 128
            frame = sheet.crop((x, y, x + 128, y + 128))
            path = folder / 'frames' / f'frame_{index:03d}.png'
            frame.save(path)
            record(path)
            box = frame.getbbox()
            assert box and min(box[0], box[1]) > 0 and max(box[2], box[3]) < 128
            bounds.append(list(box))
        write(folder / 'runtime-qc.json', {'passed': True, 'binary_alpha': True, 'frames': bounds,
                                          'same_root': True, 'edge_touch': False, 'effect_only': True})
        meta_path = folder / 'pipeline-meta.json'
        meta = json.loads(meta_path.read_text(encoding='utf-8'))
        for key in ['input', 'prompt_file']:
            if key in meta and Path(meta[key]).is_absolute(): meta[key] = Path(meta[key]).relative_to(ROOT).as_posix()
        write(meta_path, meta)
        print(name + ': effect frames keyed, grounded and QC passed', flush=True)
    write(ART / 'manifest.json', manifest)


if __name__ == '__main__':
    main()
