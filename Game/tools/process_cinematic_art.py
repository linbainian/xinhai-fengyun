"""Deterministic cleanup of six generated directional sheets; retain original idle scale."""
import argparse
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from PIL import Image
import numpy as np
from process_refined_art import repack_grid
from process_chapter_art import normalize_grid

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'assets/chapter1/cinematics'
NAMES = ['wen_rang','su_wanyan','liu','shen','wen','tang']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--processor',required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sprite_cleanup',args.processor)
    processor = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = processor
    spec.loader.exec_module(processor)
    manifest = {'source':'OpenAI built-in ImageGen','third_party_downloads':[], 'sources':[], 'runtime':[],'passed':True}
    for index,name in enumerate(NAMES):
        raw = ART/f'{name}_raw.png'
        prompt = ART/'prompts'/f'{name}.prompt.txt'
        folder = ART/name
        grid = repack_grid(raw,4,4,processor)
        subprocess.run([sys.executable,args.processor,'process','--input',str(grid),'--target','player',
            '--mode','player_sheet','--rows','4','--cols','4','--output-dir',str(folder),'--cell-size','96',
            '--fit-scale','0.84','--shared-scale','--align','feet','--component-mode','largest','--strict-qc',
            '--max-body-scale-cv','0.08','--max-anchor-y-std','0.05','--prompt-file',str(prompt),
            '--write-scale-profile',str(folder/'scale-profile.json')],check=True)
        normalize_grid(folder,'frame',processor)
        frames = [Image.open(p).convert('RGBA') for p in sorted((folder/'frames').glob('frame_*.png'))]
        master = Image.open(ROOT/f'assets/chapter1/refined/npcs/frames/frame_{index:03d}.png').convert('RGBA')
        reference = master.getbbox()
        factor = (reference[3]-reference[1])/max(im.getbbox()[3]-im.getbbox()[1] for im in frames)
        sheet = Image.new('RGBA',(384,384))
        for number,frame in enumerate(frames):
            body = frame.crop(frame.getbbox())
            body = body.resize((round(body.width*factor),round(body.height*factor)),Image.Resampling.NEAREST)
            sheet.alpha_composite(body,((number%4)*96+(96-body.width)//2,(number//4)*96+reference[3]-body.height))
        alpha = sheet.getchannel('A').point(lambda v:255 if v>=128 else 0)
        sheet = sheet.convert('RGB').quantize(colors=48,dither=Image.Dither.NONE).convert('RGBA')
        sheet.putalpha(alpha)
        sheet.save(folder/'runtime-sheet.png')
        for number in range(16):
            x,y = number%4*96,number//4*96
            path = folder/'frames'/f'frame_{number:03d}.png'
            sheet.crop((x,y,x+96,y+96)).save(path)
            manifest['runtime'].append({'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        qc = json.loads((folder/'runtime-qc.json').read_text(encoding='utf-8'))
        bounds = [Image.open(folder/'frames'/f'frame_{number:03d}.png').getbbox() for number in range(16)]
        heights = np.array([box[3]-box[1] for box in bounds],dtype=float)
        feet = np.array([box[3] for box in bounds],dtype=float)
        assert heights.std()/heights.mean() <= 0.08 and feet.std() <= 0.05
        qc['frames'] = [{'index':number,'bbox':list(box),'height':box[3]-box[1]} for number,box in enumerate(bounds)]
        qc['source'] = raw.relative_to(ROOT).as_posix()
        qc.update(binary_alpha=True,palette_colors=48,world_footprint=[48,48],shared_idle_scale=factor,
                  idle_reference=f'assets/chapter1/refined/npcs/frames/frame_{index:03d}.png',feet_y=reference[3],
                  body_height_cv=float(heights.std()/heights.mean()),feet_y_std=float(feet.std()))
        (folder/'runtime-qc.json').write_text(json.dumps(qc,indent=2)+'\n',encoding='utf-8')
        for filename in ['pipeline-meta.json','scale-profile.json']:
            path = folder/filename
            data = json.loads(path.read_text(encoding='utf-8'))
            for key in ['input','prompt_file']:
                if key in data and Path(data[key]).is_absolute(): data[key] = Path(data[key]).relative_to(ROOT).as_posix()
            path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        manifest['sources'].append({'character':name,'path':raw.relative_to(ROOT).as_posix(),
            'sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'prompt':prompt.relative_to(ROOT).as_posix(),
            'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest(),'qc':(folder/'runtime-qc.json').relative_to(ROOT).as_posix()})
        print(f'{name}: 16 directional frames, hard alpha, shared scale and original feet line',flush=True)
    (ART/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__': main()
