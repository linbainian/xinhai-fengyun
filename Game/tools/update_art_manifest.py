"""Art provenance/QC only; never touches dialogue or Markdown."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'assets/chapter1'


def main():
    manifest = {'source':'OpenAI built-in ImageGen; generated for this project','third_party_downloads':[],
                'runtime_sampling':'nearest','exploration_camera_zoom':2,'battle_character_scale':3,
                'refined_source_frame':[96,96],'character_world_footprint':[48,48],'sources':[],'qc':[]}
    for folder in [ART,ART/'refined']:
        for path in sorted(folder.glob('*_raw.png')):
            name = path.stem.removesuffix('_raw')
            prompt = folder/'prompts'/('lin_da_walk.prompt.txt' if name=='lin_da' else name+'.prompt.txt')
            if not prompt.exists() or not prompt.read_text(encoding='utf-8').strip():
                raise ValueError(f'Missing prompt: {prompt}')
            item = {'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'prompt':prompt.relative_to(ROOT).as_posix(),'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest()}
            if folder.name=='refined':
                item['batch'] = '2026-10-01 chapter refinement'
                guide = folder/(name+'_guide.png')
                if guide.exists(): item['layout_guide'] = guide.relative_to(ROOT).as_posix()
            manifest['sources'].append(item)
    qc_paths = [ART/name/'runtime-qc.json' for name in ['lin_da','npcs','props','rabbits']]
    qc_paths += [ART/'refined'/name/'runtime-qc.json' for name in ['lin_da','npcs','fx']]
    qc_paths += [ART/'refined/hall/module-manifest.json']
    for path in qc_paths:
        data = json.loads(path.read_text(encoding='utf-8'))
        if not data['passed']: raise ValueError(f'Failed QC: {path}')
        manifest['qc'].append({'path':path.relative_to(ROOT).as_posix(),'passed':True})
    runtime = [p for name in ['lin_da','npcs','fx'] for p in sorted((ART/'refined'/name/'frames').glob('*.png'))]
    runtime.append(ART/'refined/lin_da/rest.png')
    hall = json.loads((ART/'refined/hall/module-manifest.json').read_text(encoding='utf-8'))
    runtime += [ROOT/item['path'] for item in hall['modules']]
    manifest['refined_runtime'] = [{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in runtime]
    (ART/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(manifest["sources"])} generated sources, validated prompts, {len(runtime)} refined runtime PNGs')


if __name__ == '__main__': main()
