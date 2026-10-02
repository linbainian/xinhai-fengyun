"""Markdown -> runtime JSON, preserving IDs/events. Default: check; --apply: import with backups."""
import argparse
import copy
import hashlib
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data/chapter1'
AUTHOR_SCRIPT = ROOT.parent / '策划与剧情/第1章实装台词脚本_v0.1.md'
HEADING = re.compile(r'^###\s+(片段\s+)?`([^`]+)`(?:（[^）]+）)?\s*$')
SPEECH = re.compile(r'^\*\*(.+?)\*\*：(.+)$')
NUMBERED = re.compile(r'^\d+\.\s+(.+)$')
READING_DELAY = '[演出：仪器停顿0.5秒，期间不可跳过。]'


def load_data():
    dialogue, choices, settings = tuple(json.loads((DATA / name).read_text(encoding='utf-8'))
                                       for name in ('dialogues.json', 'choices.json', 'settings.json'))
    choices.setdefault('clubs_exit', ['', ''])
    return dialogue, choices, settings


def parse_script(text, dialogue, choices, settings):
    sections = {}
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        match = HEADING.fullmatch(line)
        if match:
            current = ('dialogue' if match[1] else 'choice', match[2])
            if current in sections:
                raise ValueError(f'重复片段：{current[1]}')
            sections[current] = []
        elif line.startswith('##'):
            current = None
        elif current is not None and line:
            sections[current].append(line)
    expected = {('dialogue', key) for key in dialogue} | {('choice', key) for key in choices}
    for added in ['day_one_close','mentor_entrance','clubs_arrive','club_sword','club_element','club_healing','clubs_depart','dorm_arrive','chuxia_repeat','clubs_crowd']:
        if ('dialogue',added) in sections: expected.add(('dialogue',added))
    if set(sections) != expected:
        raise ValueError(f'片段ID不匹配：缺少{sorted(expected - set(sections))}；多出{sorted(set(sections) - expected)}')
    imported_dialogue = {}
    substitutions = {'delivery_money': str(settings['delivery_reward']['money']),
                     'delivery_contribution': str(settings['delivery_reward']['contribution'])}
    for kind,key in sections:
        if kind != 'dialogue': continue
        original = dialogue.get(key,[])
        speeches = []
        directions = []
        for line in sections['dialogue', key]:
            if line.startswith('[系统提示：') and line.endswith(']'):
                speeches.append({'speaker':'系统提示','text':line[6:-1]})
                continue
            if line.startswith('[演出：') and line.endswith(']'):
                directions.append(line)
                continue
            match = SPEECH.fullmatch(line)
            if match is None:
                raise ValueError(f'{key}：无法识别的对白格式：{line}')
            entry = {'speaker':match[1],'text':match[2]}
            if directions:
                entry['directions_before'] = directions
                if any('仪器停顿0.5秒' in note for note in directions): entry['event'] = 'reading_delay'
                if key=='exam' and any('下午转场' in note for note in directions): entry['event'] = 'afternoon_transition'
                directions = []
            speeches.append(entry)
        if not speeches: raise ValueError(f'{key}：片段不能没有对白')
        if directions: speeches[-1]['directions_after'] = directions
        if key=='su_cafe' and any('入口位置' in note for note in directions):
            speeches[-1]['after_event'] = 'hill_route_received'
        if sum(entry.get('event')=='reading_delay' for entry in speeches) != (1 if key=='exam' else 0):
            raise ValueError(f'{key}：须保留唯一的仪器0.5秒演出，禁止复制到其他片段')
        # Unknown program metadata must not disappear merely because the author adds lines.
        allowed = {'speaker','text','event','after_event','directions_before','directions_after'}
        if any(set(entry)-allowed for entry in original):
            raise ValueError(f'{key}：包含未知程序元数据，需先明确迁移')
        for entry in speeches:
            speech = entry['text']
            for name, value in substitutions.items():
                token = '{' + name + '}'
                pattern = r'奖励(\d+)元' if name=='delivery_money' else r'贡献(\d+)'
                found = re.search(pattern,speech) if key in ['task','task_report'] else None
                if found:
                    if found[1] != value: raise ValueError(f'{key}：奖励与settings.json不一致')
                    speech = speech[:found.start(1)]+token+speech[found.end(1):]
            entry['text'] = speech
        imported_dialogue[key] = speeches
    imported_choices = copy.deepcopy(choices)
    for key, original in choices.items():
        content = sections['choice', key]
        if key == 'shen_options':
            groups = []
            for line in content:
                if re.fullmatch(r'第\d+题：', line):
                    if line != f'第{len(groups) + 1}题：':
                        raise ValueError('沈听澜问题次序不匹配')
                    groups.append([])
                elif NUMBERED.fullmatch(line) and groups:
                    groups[-1].append(NUMBERED.fullmatch(line)[1])
                else:
                    raise ValueError(f'{key}：无法识别的选项格式：{line}')
            if len(groups) != len(original) or any(len(a) != len(b) for a, b in zip(groups, original)):
                raise ValueError('沈听澜须保留三题及各题原有选项数量')
            imported_choices[key] = groups
        elif isinstance(original, list):
            if len(content) != len(original) or any(NUMBERED.fullmatch(line) is None for line in content):
                raise ValueError(f'{key}：选项数量/格式不匹配')
            imported_choices[key] = [NUMBERED.fullmatch(line)[1] for line in content]
        else:
            if len(content) != 1:
                raise ValueError(f'{key}：须保留一个文本项')
            imported_choices[key] = content[0]
    return imported_dialogue, imported_choices


def parse_tutorial_text(text):
    groups = {}
    current = ''
    for raw in text.splitlines():
        if raw.startswith('**第') and '`m1_d_lesson_' in raw:
            current = re.search(r'`(m1_d_lesson_\d)`',raw)[1]
            groups[current] = {}
        elif raw.startswith('**共通状态提示**'):
            current = 'm1_d_tutorial'
            groups[current] = {}
        elif raw.startswith('### '): current = ''
        elif current and raw.startswith('| `'):
            field,dialogue,system = [part.strip().strip('`') for part in raw.strip('|').split('|')]
            if field in groups[current]: raise ValueError('重复教程字段：'+field)
            groups[current][field] = {'dialogue':dialogue,'system':system}
    if groups:
        lesson_fields = {'introduction','opening_hint','attack_hint','skill_hint','defense_hint'}
        shared_fields = {'overload_hint','breakthrough_hint','uncontrolled_hint','weakness_hint'}
        if set(groups) != {'m1_d_lesson_1','m1_d_lesson_2','m1_d_lesson_3','m1_d_tutorial'}:
            raise ValueError('教程表须包含三段及共通状态提示')
        for key,value in groups.items():
            if set(value) != (shared_fields if key=='m1_d_tutorial' else lesson_fields):
                raise ValueError('教程字段不完整：'+key)
    return groups


def backup_files(paths):
    folder = ROOT / '.dev/backups/chapter-script' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    folder.mkdir(parents=True)
    manifest = []
    for index, path in enumerate(paths):
        content = path.read_bytes()
        filename = f'{index}-{path.name}'
        (folder / filename).write_bytes(content)
        manifest.append({'original': str(path), 'backup': filename, 'sha256': hashlib.sha256(content).hexdigest()})
    (folder / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    return folder


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=AUTHOR_SCRIPT)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    dialogue, choices, settings = load_data()
    source = args.source.read_text(encoding='utf-8-sig')
    new_dialogue, new_choices = parse_script(source, dialogue, choices, settings)
    tutorial = parse_tutorial_text(source)
    changed = [{'block':key,'before_lines':len(dialogue.get(key,[])),'after_lines':len(block)}
               for key,block in new_dialogue.items() if dialogue.get(key) != block]
    choice_changes = [key for key in choices if choices[key] != new_choices[key]]
    report = {'applied': args.apply, 'blocks': len(new_dialogue), 'lines': sum(map(len, new_dialogue.values())),
              'changed_dialogue': changed, 'changed_choices': choice_changes}
    tutorial_path = DATA / 'tutorial_text.json'
    tutorial_changed = tutorial and (not tutorial_path.exists() or json.loads(tutorial_path.read_text(encoding='utf-8')) != tutorial)
    report['tutorial_fields'] = sum(map(len,tutorial.values()))
    if args.apply and (changed or choice_changes or tutorial_changed):
        paths = [args.source, DATA / 'dialogues.json', DATA / 'choices.json']
        if tutorial_path.exists(): paths.append(tutorial_path)
        report['backup'] = str(backup_files(paths))
        outputs = [('dialogues.json', new_dialogue), ('choices.json', new_choices)]
        if tutorial: outputs.append(('tutorial_text.json',tutorial))
        for name, content in outputs:
            path = DATA / name
            temporary = path.with_suffix('.json.tmp')
            temporary.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
            temporary.replace(path)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
