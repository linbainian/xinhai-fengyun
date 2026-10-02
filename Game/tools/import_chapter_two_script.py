"""Import the chapter-two author manuscript; check by default, backup before --apply."""
import argparse
import hashlib
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / '策划与剧情/第2章实装台词脚本_v0.1.md'
DEST = ROOT / 'data/chapter2/dialogues.json'
HEADING = re.compile(r'^### 片段 `([^`]+)`$')
SPEECH = re.compile(r'^\*\*(.+?)\*\*：(.+)$')


def parse(text):
    blocks = {}
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        match = HEADING.fullmatch(line)
        if match:
            current = match[1]
            if not current.startswith('c2_') or current in blocks:
                raise ValueError('Invalid or duplicate block: ' + current)
            blocks[current] = []
        elif line.startswith('##'):
            current = None
        elif current and line:
            speech = SPEECH.fullmatch(line)
            if not speech:
                raise ValueError(f'{current}: invalid dialogue format: {line}')
            blocks[current].append({'speaker': speech[1], 'text': speech[2]})
    if not blocks or any(not lines for lines in blocks.values()):
        raise ValueError('Empty dialogue blocks')
    return blocks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    data = parse(SOURCE.read_text(encoding='utf-8-sig'))
    original = json.loads(DEST.read_text(encoding='utf-8')) if DEST.exists() else {}
    changed = data != original
    if changed and args.apply:
        backup = ROOT / '.dev/backups/chapter-two-script' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        backup.mkdir(parents=True)
        for file in [SOURCE] + ([DEST] if DEST.exists() else []):
            (backup/file.name).write_bytes(file.read_bytes())
        temp = DEST.with_suffix('.json.tmp')
        temp.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        temp.replace(DEST)
    export = ROOT/'docs/第2章台词脚本.md'
    if args.apply:
        export.write_text(SOURCE.read_text(encoding='utf-8'), encoding='utf-8')
    print(json.dumps({'applied': args.apply, 'changed': changed, 'blocks': len(data),
                      'lines': sum(map(len, data.values())), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest()}, ensure_ascii=False))


if __name__ == '__main__': main()
