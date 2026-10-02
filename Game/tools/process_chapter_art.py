"""Deterministic slicing / chroma cleanup of ImageGen sources; no art synthesis."""
import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/chapter1'

def normalize_grid(folder, prefix, processor):
    """Reuse the skill's cleanup/crop contract, with nearest sampling for pixel runtime."""
    data = json.loads((folder / 'pipeline-meta.json').read_text(encoding='utf-8'))
    source = Path(data['input'])
    if not source.is_absolute():
        source = ROOT / source
    cleaned = processor.remove_bg_magenta(Image.open(source).convert('RGBA'),
                                          data['threshold'], data['edge_threshold'])
    out = folder / 'frames'
    out.mkdir(exist_ok=True)
    report = {'sampling': 'nearest', 'source': source.relative_to(ROOT).as_posix(),
              'cell_size': data['cell_size'], 'frames': []}
    sheet = Image.new('RGBA', (data['cell_size'] * data['cols'],
                               data['cell_size'] * data['rows']))
    for i, info in enumerate(data['frames']):
        frame = cleaned.crop(info['source_box'])
        frame = processor.trim_border(frame, data['trim_border'])
        frame = processor.clean_edges(frame, data['edge_clean_depth'])
        frame = frame.crop(info['crop_bbox']).resize(info['output_size'], Image.Resampling.NEAREST)
        canvas = Image.new('RGBA', (data['cell_size'], data['cell_size']))
        canvas.paste(frame, info['paste_position'])
        bbox = canvas.getbbox()
        if not bbox or bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= canvas.width or bbox[3] >= canvas.height:
            raise ValueError(f'{folder.name} frame {i}: empty or edge-clipped runtime frame')
        canvas.save(out / f'{prefix}_{i:03d}.png')
        sheet.paste(canvas, ((i % data['cols']) * canvas.width,
                             (i // data['cols']) * canvas.height))
        report['frames'].append({'index': i, 'bbox': bbox, 'height': bbox[3]-bbox[1]})
    report['passed'] = True
    sheet.save(folder / 'runtime-sheet.png')
    (folder / 'runtime-qc.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

def pack_source(name, rows, cols):
    """Repack uneven generated gutters without changing any subject pixels."""
    raw = Image.open(ART / f'{name}_raw.png').convert('RGBA')
    bounds = [round(i*raw.height/rows) for i in range(rows+1)]
    if name == 'npcs':
        bounds = [0, 430, 840, raw.height]
    elif name == 'props':
        bounds = [0, 310, 615, 910, raw.height]
    widths = [round(i*raw.width/cols) for i in range(cols+1)]
    side = max(max(b-a for a,b in zip(bounds,bounds[1:])),
               max(b-a for a,b in zip(widths,widths[1:]))) + 12
    canvas = Image.new('RGBA', (side*cols, side*rows), (255,0,255,255))
    for row in range(rows):
        for col in range(cols):
            crop = raw.crop((widths[col],bounds[row],widths[col+1],bounds[row+1]))
            canvas.paste(crop,(col*side+(side-crop.width)//2,row*side+(side-crop.height)//2))
    path = ART / f'{name}_grid.png'
    canvas.save(path)
    return path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--processor', required=True)
    parser.add_argument('--runtime-only', action='store_true')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sprite_cleanup', args.processor)
    processor = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = processor
    spec.loader.exec_module(processor)
    if args.runtime_only:
        for name in ['lin_da', 'npcs', 'props', 'rabbits']:
            normalize_grid(ART / name, 'frame', processor)
        return
    terrain = Image.open(ART / 'terrain_raw.png').convert('RGBA')
    target = ART / 'terrain'
    target.mkdir(exist_ok=True)
    for y in range(4):
        for x in range(4):
            # Remove the narrow raw atlas gutter; preserve generated texture.
            box = (round(x*terrain.width/4)+4, round(y*terrain.height/4)+4,
                   round((x+1)*terrain.width/4)-4, round((y+1)*terrain.height/4)-4)
            terrain.crop(box).resize((48,48), Image.Resampling.NEAREST).save(target / f'tile_{y*4+x:02d}.png')
    subprocess.run([sys.executable, args.processor, 'process', '--input', str(ART / 'lin_da_raw.png'),
                    '--target', 'player', '--mode', 'player_sheet', '--output-dir', str(ART / 'lin_da'),
                    '--cell-size', '48', '--fit-scale', '0.84', '--align', 'feet',
                    '--scale-strategy', 'fit', '--shared-scale', '--component-mode', 'largest',
                    '--strict-qc', '--max-body-scale-cv', '0.08', '--max-anchor-y-std', '0.05',
                    '--write-scale-profile', str(ART / 'lin_da/scale-profile.json'),
                    '--prompt-file', str(ART / 'prompts/lin_da_walk.prompt.txt')], check=True)
    normalize_grid(ART / 'lin_da', 'frame', processor)
    for name, rows, cols, size in [('npcs',3,3,48), ('props',4,3,96), ('rabbits',2,2,48)]:
        if not (ART / f'{name}_raw.png').exists():
            continue
        source = pack_source(name,rows,cols)
        command = [sys.executable, args.processor, 'process', '--input', str(source),
                   '--target', 'asset', '--mode', 'asset', '--output-dir', str(ART / name),
                   '--rows', str(rows), '--cols', str(cols), '--cell-size', str(size), '--fit-scale','0.84',
                   '--align','feet', '--component-mode','largest', '--strict-qc',
                   '--prompt-file', str(ART / 'prompts' / f'{name}.prompt.txt')]
        subprocess.run(command, check=True)
        normalize_grid(ART / name, 'frame', processor)
    for name, size in [('academy',512),('counter',256),('bed',192)]:
        if not (ART / f'{name}_raw.png').exists():
            continue
        command = [sys.executable, args.processor, 'process','--input',str(ART / f'{name}_raw.png'),
                   '--target','asset','--mode','asset','--output-dir',str(ART / name),
                   '--single-size',str(size),'--prompt-file',str(ART / 'prompts' / f'{name}.prompt.txt')]
        subprocess.run(command, check=True)
        output = ART / name
        # Trim transparent export margins for explicit engine dimensions.
        im = Image.open(output / 'clean.png').convert('RGBA')
        bbox = im.getbbox()
        if not bbox:
            raise ValueError(f'{name}: empty transparent output')
        im.crop(bbox).save(output / 'runtime.png')

if __name__ == '__main__':
    main()
