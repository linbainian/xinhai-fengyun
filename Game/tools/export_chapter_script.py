"""JSON -> Markdown. Default output is Game/docs; protect the author script."""
import argparse
import json
from pathlib import Path
from import_chapter_script import backup_files

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data/chapter1'


def render_script():
    dialogue = json.loads((DATA / 'dialogues.json').read_text(encoding='utf-8'))
    choices = json.loads((DATA / 'choices.json').read_text(encoding='utf-8'))
    settings = json.loads((DATA / 'settings.json').read_text(encoding='utf-8'))
    sections = {
        'arrival': '01-01 上午 · 报到与测试',
        'liu': '01-01 下午 · 柳无眠与漫画',
        'shen': '01-01 下午 · 沈听澜的情境问答',
        'wen': '01-01 下午 · 温若水与元素样本',
        'tang': '01-01 下午 · 唐半夏与药柜',
        'joined_liu': '正式拜师 · 四个互斥分支',
        'su_cafe': '01-01 傍晚 · 拜师结束后 · 苏挽颜来访',
        'day_one_close': '01-01 夜 · 安置行李与次日赴约',
        'hill_intro': '01-02 上午 · 后山三段清剿',
        'clubs': '01-02 下午 · 社团招新首逛',
        'dorm': '01-02 夜 · 宿舍与楼道',
        'task': '01-03 · 送件任务与章节结束',
        'item_wait': '重复互动与流程保护台词',
    }
    lines = ['# 第1章 · 入学日 · 实装台词脚本 v0.1', '',
             '日期：2026-10-01。依据剧情卷 v0.3.6 第1章与对应人物条目。', '',
             '本文可作为台词编辑源。修改后在Game目录运行 tools/import_chapter_script.py 检查，确认无误后加 --apply 导入运行JSON。'
             'tools/export_chapter_script.py 为JSON→Markdown导出，默认只更新Game/docs，不覆盖本稿；指定外部输出须显式 --force 并自动备份。'
             '拜山可体验多个任务，正式拜师四选一。沈听澜按三次回答的多数倾向给评语，三项各一时取最后一次，所有答案均可通过。', '',
             '读数延迟只阻挡输入0.5秒；不解释异常、牧遥、兔子增多或初夏的预知。'
             '温让和凌未央的关系不变；邀温让同行只增加入口演出。正式入社留到第2章。', '']
    substitutions = {'delivery_money': settings['delivery_reward']['money'],
                     'delivery_contribution': settings['delivery_reward']['contribution']}
    for key, block in dialogue.items():
        if key in sections:
            lines.extend([f'## {sections[key]}', ''])
        lines.extend([f'### 片段 `{key}`', ''])
        for line in block:
            for note in line.get('directions_before',[]): lines.extend([note,''])
            if line.get('event') == 'reading_delay' and not line.get('directions_before'):
                lines.extend(['[演出：仪器停顿0.5秒，期间不可跳过。]', ''])
            lines.extend([f"**{line['speaker']}**：{line['text'].format(**substitutions)}", ''])
            for note in line.get('directions_after',[]): lines.extend([note,''])
    tutorial_path = DATA / 'tutorial_text.json'
    if tutorial_path.exists():
        lines.extend(['## 后山教程文案',''])
        tutorial = json.loads(tutorial_path.read_text(encoding='utf-8'))
        for index in range(1,4):
            key = f'm1_d_lesson_{index}'
            lines.extend([f'**第{index}段**（`{key}`）','', '| 现有字段 | 苏挽颜对白 | 系统提示 |','|---|---|---|'])
            for field,item in tutorial[key].items(): lines.append(f'| `{field}` | {item["dialogue"]} | {item["system"]} |')
            lines.append('')
        lines.extend(['**共通状态提示**（`m1_d_tutorial`）','','| 现有字段 | 苏挽颜对白 | 系统提示 |','|---|---|---|'])
        for field,item in tutorial['m1_d_tutorial'].items(): lines.append(f'| `{field}` | {item["dialogue"]} | {item["system"]} |')
        lines.append('')
    lines.extend(['## 玩家选择与评语', ''])
    for key, content in choices.items():
        lines.extend([f'### `{key}`', ''])
        if key == 'shen_options':
            for index, group in enumerate(content):
                lines.extend([f'第{index+1}题：', ''])
                lines.extend([f'{i+1}. {text}' for i, text in enumerate(group)])
                lines.append('')
        elif isinstance(content, list):
            lines.extend([f'{i+1}. {text}' for i, text in enumerate(content)])
            lines.append('')
        else:
            lines.extend([content, ''])
    lines.extend(['## 演出与结算口径', '',
                  '- 苏挽颜：爽快接下好感+5，嘴上推脱+3，邀温让同行保持初值40。',
                  '- 三段战斗规则与数值沿用 data/battle/tutorial/m1_d_tutorial.tres 与 m1_d_lesson_1/2/3.tres；首章的19项对白/系统提示由 data/chapter1/tutorial_text.json 覆盖，原M1-D开发入口保留。HP/SL连续携带，失败重试本段开场，返回入口保留入场前进度。',
                  '- 01-02夜谈和初夏照面均完成后可睡觉，进入01-03。',
                  f"- 送件在管理局签收后回学院结算：{substitutions['delivery_money']}元、贡献{substitutions['delivery_contribution']}，只发一次；章末自动存档。", '',
                  '数值、初始系别选择与入门技能为首章原型，详见第1章可玩流程实施补充。', ''])
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    default = ROOT / 'docs/第1章台词脚本.md'
    parser.add_argument('--output', type=Path, default=default)
    parser.add_argument('--force', action='store_true', help='显式覆盖非默认输出；覆盖前备份')
    args = parser.parse_args()
    text = render_script()
    path = args.output.resolve()
    if path.exists() and path.read_text(encoding='utf-8-sig') != text:
        if path != default.resolve() and not args.force:
            parser.error('输出已存在；为防覆盖用户修改，须先导入，再显式 --force 导出（会备份）。')
        print(f'Backup: {backup_files([path])}')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')
    print(f'JSON -> Markdown: {path}')


if __name__ == '__main__':
    main()
