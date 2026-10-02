"""Extract generated hall modules with alpha; preserve aspect ratio and nearest sampling."""
import argparse
import hashlib
import importlib.util
import json
import sys
from types import SimpleNamespace
import numpy as np
from pathlib import Path
from PIL import Image
from process_refined_art import repack_grid

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/chapter1/refined'
MODULES = ART / 'hall'
SHEETS = {
    'structure': (4, 2, [('wall',192,'w'),('arch_window',192,'w'),('podium_left',192,'w'),
                       ('podium_middle',192,'w'),('podium_right',192,'w'),('stairs',96,'w'),
                       ('stand',288,'w'),('railing',288,'w')]),
    'props': (3, 3, [('column',76,'h'),('gate_left',132,'h'),('gate_right',132,'h'),
                   ('trial_table',96,'w'),('flag_red',96,'h'),('flag_gray',96,'h'),
                   ('flag_teal',96,'h'),('flag_silver',96,'h'),('streetlamp',128,'h')]),
    'furniture': (3, 2, [('banner',360,'w'),('bench',144,'w'),('planter',64,'w'),
                       ('trash',44,'h'),('cone',28,'h'),('barrier',144,'w')]),
}


def key_hall(image):
    """Remove key-color spill; the hall palette has no purple/magenta material."""
    pixels = np.array(image.convert('RGBA')).copy()
    r,g,b = (pixels[:,:,i].astype(np.int16) for i in range(3))
    mask = (r > g + 30) & (b > g + 30) & (np.minimum(r,b) > 60)
    pixels[mask] = [0,0,0,0]
    return Image.fromarray(pixels)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--processor', required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sprite_cleanup', args.processor)
    processor = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = processor
    spec.loader.exec_module(processor)
    MODULES.mkdir(exist_ok=True)
    entries = []

    def export(name, image, amount, axis, source, box):
        cleaned = processor.clean_edges(key_hall(image), 1)
        bounds = cleaned.getbbox()
        if not bounds or bounds[0] <= 0 or bounds[1] <= 0 or bounds[2] >= image.width or bounds[3] >= image.height:
            raise ValueError(f'{name}: empty or source-edge contact')
        subject = cleaned.crop(bounds)
        scale = amount / (subject.width if axis == 'w' else subject.height)
        size = (round(subject.width * scale), round(subject.height * scale))
        runtime = subject.resize(size, Image.Resampling.NEAREST)
        # Keep one clear alpha margin. No generated ground/shadow baked into collision.
        alpha = runtime.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
        runtime = runtime.convert('RGB').quantize(colors=40).convert('RGBA')
        runtime.putalpha(alpha)
        canvas = Image.new('RGBA', (size[0] + 4, size[1] + 4))
        canvas.paste(runtime, (2, 2))
        path = MODULES / f'{name}.png'
        canvas.save(path)
        entries.append({'id': name, 'path': path.relative_to(ROOT).as_posix(),
                        'source': source.relative_to(ROOT).as_posix(), 'source_box': box,
                        'crop_bbox': bounds, 'size': list(canvas.size), 'world_footprint': list(canvas.size),
                        'aspect_ratio_preserved': True, 'alpha': True, 'edge_touch': False,
                        'sampling': 'nearest', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})

    dome = ART / 'hall_dome_raw.png'
    raw = Image.open(dome)
    export('dome',raw,768,'w',dome,[0,0,raw.width,raw.height])
    for name, (rows, cols, pieces) in SHEETS.items():
        packed = repack_grid(ART / f'hall_{name}_raw.png', rows, cols,
                             SimpleNamespace(remove_bg_magenta=lambda image, *args: key_hall(image)))
        image = Image.open(packed)
        cell = image.width // cols
        for index, (piece, amount, axis) in enumerate(pieces):
            x, y = index % cols * cell, index // cols * cell
            box = [x,y,x+cell,y+cell]
            export(piece, image.crop(box), amount, axis, packed, box)
    terrain = Image.open(ART / 'hall_terrain_raw.png').convert('RGB')
    for row in range(3):
        for col in range(2):
            box = [round(col*terrain.width/2),round(row*terrain.height/3),
                   round((col+1)*terrain.width/2),round((row+1)*terrain.height/3)]
            tile = terrain.crop(box).resize((48,48),Image.Resampling.NEAREST).quantize(colors=32).convert('RGB')
            path = MODULES / f'tile_{row*2+col:02d}.png'
            tile.save(path)
            entries.append({'id': f'tile_{row*2+col:02d}', 'path': path.relative_to(ROOT).as_posix(),
                            'source': 'assets/chapter1/refined/hall_terrain_raw.png', 'source_box': box,
                            'size': [48,48], 'sampling': 'nearest', 'full_bleed': True,
                            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest = {'schema': 'chapter1.hall-modules.v1', 'source': 'OpenAI built-in ImageGen',
                'passed': True, 'modules': entries, 'third_party_downloads': []}
    (MODULES / 'module-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{len(entries)} independent hall modules/tiles exported; no crop/edge contact; preserved aspect ratios')


if __name__ == '__main__':
    main()
