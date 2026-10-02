"""Process generated service-hall/chapter-two art: crop, key, nearest, shared scale and QC."""
import argparse
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from process_refined_art import repack_grid
from process_chapter_art import normalize_grid

ROOT = Path(__file__).resolve().parents[1]


def palette(image, colors=48):
    alpha = image.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
    result = image.convert('RGB').quantize(colors=colors, dither=Image.Dither.NONE).convert('RGBA')
    result.putalpha(alpha)
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--processor', required=True)
    parser.add_argument('--bundle', choices=['venues', 'chapter2', 'all'], default='all')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sprite_cleanup', args.processor)
    processor = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = processor
    spec.loader.exec_module(processor)
    venues = ROOT/'assets/venues'
    chapter = ROOT/'assets/chapter2'
    bundles = [venues, chapter] if args.bundle == 'all' else [venues if args.bundle == 'venues' else chapter]
    master = Image.open(ROOT/'assets/chapter1/refined/npcs/frames/frame_000.png').convert('RGBA')
    master_box = master.getbbox()
    for base in bundles:
        manifest = {'source': 'OpenAI built-in ImageGen', 'sampling': 'nearest', 'third_party_downloads': [], 'sources': [], 'runtime': [], 'objects': {}, 'passed': True}
        def record_runtime(path):
            manifest['runtime'].append({'path': path.relative_to(ROOT).as_posix(), 'sha256': digest(path)})
        sources = [('academy_wall', 'object',1248), ('bureau_wall','object',1152),
                   ('academy_counter','object',384),('bureau_counter','object',672),
                   ('academy_people','static',4),('bureau_people','static',4)] if base == venues else [
                   ('jiang','walk',16),('han','walk',16),('qin','walk',16),
                   ('bar_people','static',4),('creatures','creatures',4),('rift_gate','object',144),('rift_terrain','terrain',6),('expedition_props','props',4)]
        for name, kind, amount in sources:
            raw = base/f'{name}_raw.png'
            prompt = base/'prompts'/f'{name}.prompt.txt'
            folder = base/('actors/'+name if kind == 'walk' else name if kind != 'terrain' else 'terrain')
            folder.mkdir(parents=True,exist_ok=True)
            source_meta = {'id':name,'path':raw.relative_to(ROOT).as_posix(),'sha256':digest(raw),
                           'prompt':prompt.relative_to(ROOT).as_posix(),'prompt_sha256':digest(prompt)}
            manifest['sources'].append(source_meta)
            if kind == 'terrain':
                image = Image.open(raw).convert('RGBA')
                for index in range(6):
                    x,y = index%3,index//3
                    tile = image.crop((round(x*image.width/3)+3, round(y*image.height/2)+3,
                                       round((x+1)*image.width/3)-3,round((y+1)*image.height/2)-3))
                    tile = palette(tile.resize((48,48),Image.Resampling.NEAREST),32)
                    path = folder/f'tile_{index:02d}.png'
                    tile.save(path); record_runtime(path)
                (folder/'runtime-qc.json').write_text(json.dumps({'passed':True,'tiles':6,'dimensions':[48,48],'source':source_meta['path'],'opaque':True},indent=2)+'\n',encoding='utf-8')
            elif kind == 'object':
                image = processor.remove_bg_magenta(Image.open(raw).convert('RGBA'),40,65)
                if name in ('academy_wall','bureau_wall'):
                    # Remove darkened chroma spill along architecture edges only.
                    pixels = np.array(image)
                    rgb = pixels[:,:,:3].astype(float)
                    spill = (rgb[:,:,0]>130)&(rgb[:,:,2]>110)&(rgb[:,:,0]>rgb[:,:,1]*1.8)&(rgb[:,:,2]>rgb[:,:,1]*1.8)
                    pixels[spill,3] = 0
                    image = Image.fromarray(pixels)
                box = image.getbbox()
                if not box or box[0] <= 0 or box[1] <= 0 or box[2] >= image.width or box[3] >= image.height:
                    raise ValueError(f'{name}: clipped or empty source object')
                image = image.crop(box)
                height = round(image.height*amount/image.width)
                image = palette(image.resize((amount,height),Image.Resampling.NEAREST),64)
                path = folder/'runtime.png'; image.save(path); record_runtime(path)
                manifest['objects'][name] = {'asset':'res://'+path.relative_to(ROOT).as_posix(),'size':list(image.size),'anchor':[image.width/2,image.height]}
                (folder/'runtime-qc.json').write_text(json.dumps({'passed':True,'source':source_meta['path'],'source_bbox':list(box),'size':list(image.size),'binary_alpha':True,'palette_colors':64},indent=2)+'\n',encoding='utf-8')
            else:
                rows = cols = 4 if kind == 'walk' else 2
                grid = repack_grid(raw,rows,cols,processor)
                if kind == 'walk':
                    # Translate generated cells to one foot line before measuring drift.
                    keyed = processor.remove_bg_magenta(Image.open(grid).convert('RGBA'),40,65)
                    side = keyed.width // cols
                    aligned = Image.new('RGBA', keyed.size, '#ff00ff')
                    for index in range(amount):
                        cell = keyed.crop(((index%cols)*side,(index//cols)*side,(index%cols+1)*side,(index//cols+1)*side))
                        body = cell.crop(cell.getbbox())
                        aligned.alpha_composite(body,((index%cols)*side+(side-body.width)//2,(index//cols+1)*side-12-body.height))
                    aligned.save(grid)
                command = [sys.executable,args.processor,'process','--input',str(grid),
                           '--target','player' if kind == 'walk' else 'asset','--mode','player_sheet' if kind == 'walk' else 'asset',
                           '--rows',str(rows),'--cols',str(cols),'--output-dir',str(folder),'--cell-size','96',
                           '--fit-scale','0.84','--shared-scale','--align','feet','--component-mode','largest','--strict-qc','--prompt-file',str(prompt)]
                if kind == 'walk': command += ['--max-body-scale-cv','0.08','--max-anchor-y-std','0.05','--write-scale-profile',str(folder/'scale-profile.json')]
                subprocess.run(command,check=True,stdout=subprocess.DEVNULL)
                normalize_grid(folder,'frame',processor)
                frames = [Image.open(folder/'frames'/f'frame_{index:03d}.png').convert('RGBA') for index in range(amount)]
                factor = 1.0 if kind in ('creatures', 'props') else (master_box[3]-master_box[1])/max(frame.getbbox()[3]-frame.getbbox()[1] for frame in frames)
                sheet = Image.new('RGBA',(cols*96,rows*96))
                for index, frame in enumerate(frames):
                    body = frame.crop(frame.getbbox())
                    body = body.resize((round(body.width*factor),round(body.height*factor)),Image.Resampling.NEAREST)
                    baseline = 92 if kind in ('creatures', 'props') else master_box[3]
                    sheet.alpha_composite(body,((index%cols)*96+(96-body.width)//2,(index//cols)*96+baseline-body.height))
                sheet = palette(sheet); sheet.save(folder/'runtime-sheet.png')
                bounds = []
                for index in range(amount):
                    x,y = index%cols*96,index//cols*96
                    frame = sheet.crop((x,y,x+96,y+96))
                    box = frame.getbbox()
                    assert box and min(box[0],box[1])>0 and max(box[2],box[3])<96
                    bounds.append(box)
                    path = folder/'frames'/f'frame_{index:03d}.png'; frame.save(path); record_runtime(path)
                heights = np.array([box[3]-box[1] for box in bounds],dtype=float)
                feet = np.array([box[3] for box in bounds],dtype=float)
                if kind == 'walk': assert heights.std()/heights.mean()<=0.08 and feet.std()==0
                qc = {'passed':True,'source':source_meta['path'],'binary_alpha':True,'palette_colors':48,
                      'frames':[{'index':i,'bbox':list(box)} for i,box in enumerate(bounds)],'shared_scale':factor,
                      'body_height_cv':float(heights.std()/heights.mean()),'feet_y_std':float(feet.std()),'world_footprint':[48,48]}
                (folder/'runtime-qc.json').write_text(json.dumps(qc,indent=2)+'\n',encoding='utf-8')
                for filename in ['pipeline-meta.json','scale-profile.json']:
                    path = folder/filename
                    if not path.exists(): continue
                    data = json.loads(path.read_text(encoding='utf-8'))
                    for key in ['input','prompt_file']:
                        if key in data and Path(data[key]).is_absolute(): data[key]=Path(data[key]).relative_to(ROOT).as_posix()
                    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
            print(name+': generated source processed and QC passed',flush=True)
        (base/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__': main()
