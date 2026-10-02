"""Repeat the offline cleanup pipelines and compare every final runtime PNG hash."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--processor',required=True)
args = parser.parse_args()
manifest = json.loads((ROOT/'assets/chapter1/manifest.json').read_text(encoding='utf-8'))
paths = [ROOT/item['path'] for item in manifest['refined_runtime']]
before = {path.relative_to(ROOT).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
for name in ['lin_da','npcs','fx']:
    subprocess.run([sys.executable,str(ROOT/'tools/process_refined_art.py'),name,'--processor',args.processor],check=True)
subprocess.run([sys.executable,str(ROOT/'tools/process_hall_v2.py'),'--processor',args.processor],check=True)
subprocess.run([sys.executable,str(ROOT/'tools/process_rest_art.py')],check=True)
after = {path.relative_to(ROOT).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
changed = [key for key in before if before[key]!=after[key]]
report = {'passed':not changed,'count':len(paths),'changed':changed,'before':before,'after':after}
(ROOT/'.dev/chapter1-refined-reproduce.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'{len(paths)-len(changed)}/{len(paths)} repeated runtime PNGs match; changed={changed}')
sys.exit(1 if changed else 0)
