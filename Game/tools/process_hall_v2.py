"""Chroma-key and export level/front-facing generated hall components; no painted art."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from types import SimpleNamespace
from PIL import Image
from process_hall_art import key_hall
from process_refined_art import repack_grid

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/chapter1/refined'
OUT = ART / 'hall_v2'
MANIFEST = ART / 'hall/module-manifest.json'
SHEETS = {
    'facade_v2': (2, 2, [('wall',192,'w'),('arch_window',192,'w'),('column',170,'h'),('portal',170,'h')]),
    'interior_v2': (3, 3, [('unused_left',192,'w'),('unused_middle',192,'w'),('unused_right',192,'w'),
                           ('stairs',112,'w'),('stand',288,'w'),('railing',96,'w'),
                           ('trial_table',96,'w'),('bench',144,'w'),('barrier',144,'w')]),
    'props_v2': (3, 3, [('flag_red',104,'h'),('flag_gray',104,'h'),('flag_teal',104,'h'),('flag_silver',104,'h'),
                        ('streetlamp',128,'h'),('planter',112,'w'),('trash',48,'h'),('cone',28,'h'),('gate_left',96,'h')]),
    'stage_v2': (1, 3, [('podium_left',192,'w'),('podium_middle',192,'w'),('podium_right',192,'w')]),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--processor', required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sprite_cleanup', args.processor)
    processor = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = processor
    spec.loader.exec_module(processor)
    OUT.mkdir(exist_ok=True)
    entries = {}

    def export(name, image, amount, axis, source, box):
        cleaned = processor.clean_edges(key_hall(image), 1)
        bounds = cleaned.getbbox()
        if not bounds or bounds[0] <= 0 or bounds[1] <= 0 or bounds[2] >= image.width or bounds[3] >= image.height:
            raise ValueError(f'{name}: empty or source-edge contact')
        subject = cleaned.crop(bounds)
        scale = amount / (subject.width if axis == 'w' else subject.height)
        size = (round(subject.width * scale), round(subject.height * scale))
        runtime = subject.resize(size, Image.Resampling.NEAREST)
        alpha = runtime.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
        runtime = runtime.convert('RGB').quantize(colors=40, dither=Image.Dither.NONE).convert('RGBA')
        runtime.putalpha(alpha)
        canvas = Image.new('RGBA', (size[0] + 4, size[1] + 4))
        canvas.paste(runtime, (2, 2))
        path = OUT / f'{name}.png'
        canvas.save(path)
        anchor_x = canvas.width / 2
        if name.startswith('flag_'):
            base = canvas.getchannel('A').crop((0,canvas.height-10,canvas.width,canvas.height)).getbbox()
            anchor_x = (base[0]+base[2])/2
        entries[name] = {'id':name,'path':path.relative_to(ROOT).as_posix(),'source':source.relative_to(ROOT).as_posix(),
                         'source_box':box,'crop_bbox':list(bounds),'size':list(canvas.size),'world_footprint':list(canvas.size),
                         'anchor':[round(anchor_x),canvas.height-2],
                         'aspect_ratio_preserved':True,'alpha':True,'edge_touch':False,'sampling':'nearest',
                         'view':'front orthographic / zero yaw','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

    source = ART / 'hall_dome_raw.png'
    image = Image.open(source)
    export('dome',image,960,'w',source,[0,0,image.width,image.height])
    for name, (rows, cols, pieces) in SHEETS.items():
        source = repack_grid(ART / f'hall_{name}_raw.png', rows, cols,
                             SimpleNamespace(remove_bg_magenta=lambda image, *args: key_hall(image)))
        sheet = Image.open(source)
        cell = sheet.width // cols
        for index, (piece, amount, axis) in enumerate(pieces):
            if piece.startswith('unused_'): continue
            x,y = index % cols * cell, index // cols * cell
            box = [x,y,x+cell,y+cell]
            export(piece,sheet.crop(box),amount,axis,source,box)
    # Matching gate posts are copies of one symmetric front-facing generated module.
    left = entries['gate_left']
    target = OUT / 'gate_right.png'
    target.write_bytes((ROOT/left['path']).read_bytes())
    entries['gate_right'] = dict(left,id='gate_right',path=target.relative_to(ROOT).as_posix())
    # The first plain banner is level; resize that generated source to the doorway span.
    old = json.loads(MANIFEST.read_text(encoding='utf-8'))
    banner = next(item for item in old['modules'] if item['id']=='banner')
    source = ROOT / banner['source']
    image = Image.open(source).crop(banner['source_box'])
    export('banner',image,240,'w',source,banner['source_box'])
    # ImageGen terrain uses unequal empty-free row heights. Explicit crop boxes remove
    # the spare bottom strip; these are crop/nearest/palette operations only.
    source = ART / 'hall_terrain_v2_raw.png'
    terrain = Image.open(source).convert('RGB')
    rows = [(0,458,8),(458,952,4),(952,1482,6)]
    for row,(top,bottom,colors) in enumerate(rows):
        for col in range(2):
            box = [col*terrain.width//2,top,(col+1)*terrain.width//2,bottom]
            tile = terrain.crop(box).resize((48,48),Image.Resampling.NEAREST)
            tile = tile.quantize(colors=colors,dither=Image.Dither.NONE).convert('RGB')
            name = f'tile_{row*2+col:02d}'
            path = OUT / f'{name}.png'
            tile.save(path)
            entries[name] = {'id':name,'path':path.relative_to(ROOT).as_posix(),'source':source.relative_to(ROOT).as_posix(),
                             'source_box':box,'size':[48,48],'sampling':'nearest','full_bleed':True,
                             'palette_colors':colors,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    manifest = {'schema':'chapter1.hall-modules.v2','source':'OpenAI built-in ImageGen','passed':True,
                'design_reference':'assets/chapter1/refined/hall_reference_v2.png','modules':list(entries.values()),
                'third_party_downloads':[]}
    MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(entries)} hall modules/tiles; level facades, deep walkable stage, hard alpha and preserved object aspect ratios')


if __name__ == '__main__': main()
