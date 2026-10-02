"""Chroma/crop/nearest/palette-only processing of generated character and FX sheets."""
import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from PIL import Image
from process_chapter_art import normalize_grid

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/chapter1/refined'


def repack_grid(path, rows, cols, processor):
    """Locate empty generated gutters; pad equal cells without altering subject pixels."""
    raw = Image.open(path).convert('RGBA')
    alpha = processor.remove_bg_magenta(raw, 40, 65).getchannel('A')
    def bounds(length, count, vertical):
        values = [0]
        for index in range(1, count):
            expected = length * index / count
            radius = length / count * 0.18
            quiet = []
            for point in range(max(1, int(expected - radius)), min(length, int(expected + radius))):
                box = (0, point, raw.width, point + 1) if vertical else (point, 0, point + 1, raw.height)
                if alpha.crop(box).getbbox() is None:
                    quiet.append(point)
            if not quiet:
                raise ValueError(f'No safe gutter near grid cut {index}: {path}')
            cuts = []
            start = previous = quiet[0]
            for point in quiet[1:] + [quiet[-1] + 2]:
                if point != previous + 1:
                    cuts.append((start, previous))
                    start = point
                previous = point
            gap = min(cuts, key=lambda pair: abs((pair[0] + pair[1]) / 2 - expected))
            values.append(round(sum(gap) / 2))
        return values + [length]
    xs, ys = bounds(raw.width, cols, False), bounds(raw.height, rows, True)
    side = max(max(b-a for a,b in zip(xs,xs[1:])), max(b-a for a,b in zip(ys,ys[1:]))) + 24
    canvas = Image.new('RGBA', (side * cols, side * rows), '#ff00ff')
    for y in range(rows):
        for x in range(cols):
            cell = raw.crop((xs[x], ys[y], xs[x+1], ys[y+1]))
            canvas.paste(cell, (x * side + (side-cell.width)//2, y * side + (side-cell.height)//2))
    packed = path.with_name(path.stem.replace('_raw', '_grid') + '.png')
    canvas.save(packed)
    return packed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', choices=['lin_da', 'npcs', 'fx'])
    parser.add_argument('--processor', required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sprite_cleanup', args.processor)
    processor = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = processor
    spec.loader.exec_module(processor)
    name = args.name
    folder = ART / name
    rows, cols = (4, 4) if name == 'lin_da' else (3, 3) if name == 'npcs' else (5, 4)
    source = repack_grid(ART / f'{name}_raw.png', rows, cols, processor)
    command = [sys.executable, args.processor, 'process', '--input', str(source),
               '--target', 'player' if name == 'lin_da' else 'asset',
               '--mode', 'player_sheet' if name == 'lin_da' else 'asset',
               '--rows', str(rows), '--cols', str(cols), '--output-dir', str(folder),
               '--cell-size', '96', '--fit-scale', '0.84', '--shared-scale',
               '--align', 'feet' if name != 'fx' else 'center',
               '--component-mode', 'largest' if name != 'fx' else 'all',
               '--strict-qc', '--prompt-file', str(ART / 'prompts' / ('lin_da_walk.prompt.txt' if name == 'lin_da' else f'{name}.prompt.txt'))]
    if name != 'fx':
        command += ['--max-body-scale-cv', '0.08', '--max-anchor-y-std', '0.05',
                    '--write-scale-profile', str(folder / 'scale-profile.json')]
    subprocess.run(command, check=True)
    normalize_grid(folder, 'frame', processor)
    # One shared palette per sheet; no resynthesis or sharpening of art.
    sheet = Image.open(folder / 'runtime-sheet.png').convert('RGBA')
    alpha = sheet.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
    palette = sheet.convert('RGB').quantize(colors=48 if name == 'npcs' else 32)
    sheet = palette.convert('RGBA')
    sheet.putalpha(alpha)
    sheet.save(folder / 'runtime-sheet.png')
    for index in range(rows * cols):
        x, y = (index % cols) * 96, (index // cols) * 96
        sheet.crop((x, y, x + 96, y + 96)).save(folder / 'frames' / f'frame_{index:03d}.png')
    for filename in ['pipeline-meta.json', 'scale-profile.json']:
        path = folder / filename
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding='utf-8'))
        for key in ['input', 'prompt_file']:
            if key in data and Path(data[key]).is_absolute():
                data[key] = Path(data[key]).relative_to(ROOT).as_posix()
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    qc_path = folder / 'runtime-qc.json'
    qc = json.loads(qc_path.read_text(encoding='utf-8'))
    qc.update(palette_colors=48 if name == 'npcs' else 32, binary_alpha=True, world_footprint=[48, 48])
    qc_path.write_text(json.dumps(qc, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'{name}: {rows * cols} frames, 96px nearest, strict QC passed')


if __name__ == '__main__':
    main()
