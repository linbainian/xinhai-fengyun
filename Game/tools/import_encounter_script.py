"""Import the independent encounter author file; check by default, backup before apply."""
import argparse
import hashlib
import json
from datetime import datetime
from pathlib import Path
from import_chapter_two_script import parse

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / '策划与剧情/养成人物奇遇实装台词_v0.1.md'
DEST = ROOT / 'data/cultivation/dialogues.json'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    data = parse(SOURCE.read_text(encoding='utf-8-sig'))
    original = json.loads(DEST.read_text(encoding='utf-8')) if DEST.exists() else {}
    if args.apply:
        backup = ROOT / '.dev/backups/encounter-script' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        backup.mkdir(parents=True)
        for file in [SOURCE] + ([DEST] if DEST.exists() else []):
            (backup / file.name).write_bytes(file.read_bytes())
        temporary = DEST.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        temporary.replace(DEST)
        (ROOT / 'docs/养成人物奇遇台词脚本.md').write_text(SOURCE.read_text(encoding='utf-8'), encoding='utf-8')
    print(json.dumps({'applied': args.apply, 'changed': data != original, 'blocks': len(data),
                      'lines': sum(map(len, data.values())), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest()}, ensure_ascii=False))


if __name__ == '__main__':
    main()
