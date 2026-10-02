"""Reprocess the 14 retained ImageGen sources and compare all 79 runtime hashes."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--processor',required=True)
    args = parser.parse_args()
    expected = {}
    for name in ['venues','chapter2']:
        manifest = json.loads((ROOT/f'assets/{name}/manifest.json').read_text(encoding='utf-8'))
        for entry in manifest['runtime']: expected[entry['path']] = entry['sha256']
    report = ROOT/'.dev/playable-art-reproduction.json'
    report.write_text(json.dumps({'passed':False,'status':'running','expected':expected},indent=2)+'\n',encoding='utf-8')
    subprocess.run([sys.executable,str(ROOT/'tools/process_playable_art.py'),'--processor',args.processor],check=True)
    failed = [name for name,digest in expected.items() if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest]
    report.write_text(json.dumps({'passed':not failed,'sources':14,'runtime_pngs':len(expected),'mismatched':failed,'expected':expected},indent=2)+'\n',encoding='utf-8')
    if failed: raise ValueError('Reproduction mismatch: '+', '.join(failed))
    print(f'{len(expected)} runtime PNGs reproduce exactly from the retained generated sources')


if __name__=='__main__': main()
