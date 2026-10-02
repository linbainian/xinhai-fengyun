"""Reprocess the six original directional sheets in an isolated folder and compare 96 PNGs."""
import argparse
import hashlib
import importlib.util
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--processor',required=True)
    args = parser.parse_args()
    original = ROOT/'assets/chapter1/cinematics'
    manifest = json.loads((original/'manifest.json').read_text(encoding='utf-8'))
    temporary = ROOT/'.dev/cinematic-art-reproduce'/datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    art = temporary/'assets/chapter1/cinematics'
    (art/'prompts').mkdir(parents=True)
    references = temporary/'assets/chapter1/refined/npcs/frames'
    references.mkdir(parents=True)
    for index,item in enumerate(manifest['sources']):
        shutil.copy2(ROOT/item['path'],art/Path(item['path']).name)
        shutil.copy2(ROOT/item['prompt'],art/'prompts'/Path(item['prompt']).name)
        shutil.copy2(ROOT/f'assets/chapter1/refined/npcs/frames/frame_{index:03d}.png',references/f'frame_{index:03d}.png')
    spec = importlib.util.spec_from_file_location('cinematic_pipeline',ROOT/'tools/process_cinematic_art.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = temporary
    module.ART = art
    sys.argv = [str(ROOT/'tools/process_cinematic_art.py'),'--processor',args.processor]
    module.main()
    results = []
    for item in manifest['runtime']:
        path = temporary/item['path']
        sha256 = hashlib.sha256(path.read_bytes()).hexdigest()
        results.append({'path':item['path'],'passed':sha256==item['sha256']})
    report = {'passed':all(r['passed'] for r in results),'checks':results,'folder':temporary.relative_to(ROOT).as_posix()}
    (ROOT/'.dev/chapter1-cinematic-art-reproduce.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"Cinematic art: {sum(r['passed'] for r in results)}/{len(results)} identical runtime PNGs")
    if not report['passed']: raise SystemExit(1)


if __name__ == '__main__': main()
