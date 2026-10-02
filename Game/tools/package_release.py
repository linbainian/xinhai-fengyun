"""Package the exported Windows game and a complete, cache-free project source snapshot."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import zipfile

GAME = Path(__file__).resolve().parents[1]
PROJECT = GAME.parent
SKIP_DIRS = {'.git', '.godot', '.dev', 'builds', '__pycache__', '.zcode', '.workbuddy', 'node_modules'}
ROOT_FILES = ['README.md', 'AGENTS.md', '.gitignore', 'Codex会话交接_2026-09-30_首章.md']
TEXT_EXTENSIONS = {'.py', '.gd', '.md', '.json', '.cfg', '.godot', '.tscn', '.tres', '.txt', '.yml', '.yaml'}
CREDENTIAL_PATTERNS = [re.compile(r'\bgh[pousr]_[A-Za-z0-9]{25,}\b'),
                       re.compile(r'\bgithub_pat_[A-Za-z0-9_]{30,}\b'),
                       re.compile(r'\bsk-[A-Za-z0-9_-]{30,}\b'),
                       re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')]


def source_files():
    files = [PROJECT / name for name in ROOT_FILES if (PROJECT / name).is_file()]
    for top in ['Game', '策划与剧情', '世界观与人物设定']:
        for base, dirs, names in os.walk(PROJECT / top):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not (Path(base) / d).is_symlink())
            for name in sorted(names):
                path = Path(base) / name
                if name.endswith(('.pyc', '.pyo', '.log', '.tmp')) or name == '.env' or name.startswith('.env.') or name == 'export_credentials.cfg':
                    continue
                if path.is_symlink() or not path.resolve().is_relative_to(PROJECT.resolve()):
                    raise ValueError('Source path escapes the project: ' + str(path))
                if path.stat().st_size >= 100 * 1024 * 1024:
                    raise ValueError('Source file exceeds the GitHub per-file limit: ' + str(path.relative_to(PROJECT)))
                if path.suffix.lower() in TEXT_EXTENSIONS:
                    text = path.read_text(encoding='utf-8-sig', errors='replace')
                    if any(pattern.search(text) for pattern in CREDENTIAL_PATTERNS):
                        raise ValueError('Possible credential found; review file before upload: ' + str(path.relative_to(PROJECT)))
                files.append(path)
    return sorted(set(files), key=lambda path: path.relative_to(PROJECT).as_posix())


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', default='preview-2026-10-02')
    parser.add_argument('--stage', type=Path, help='Optional publication checkout, restricted to Game/.dev/')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,80}', args.version):
        parser.error('Version must be a short filename-safe tag')
    windows = GAME / 'builds/windows'
    executable = windows / 'XinhaiFengyun.exe'
    if not executable.is_file() or executable.stat().st_size == 0:
        raise FileNotFoundError('Export builds/windows/XinhaiFengyun.exe before packaging')
    if executable.open('rb').read(2) != b'MZ':
        raise ValueError('The export is not a Windows executable')
    files = source_files()
    if args.stage:
        stage = args.stage.resolve()
        if not stage.is_relative_to((GAME / '.dev').resolve()) or stage == (GAME / '.dev').resolve():
            raise ValueError('Publication stage must be a child directory of Game/.dev')
        stage.mkdir(parents=True, exist_ok=True)
        for path in files:
            dest = stage / path.relative_to(PROJECT)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)
    version = args.version
    player_readme = windows / '开始游戏.txt'
    player_readme.write_text(
        '觉醒者档案：新海风云\n' + version + '\n\n'
        '完整解压后，双击 XinhaiFengyun.exe。无需安装 Godot。\n'
        'Windows 64位；兼容模式；中文界面优先使用系统微软雅黑。\n\n'
        '内容：首章1月1—3日，自由养成1月4—14日，1月15日起第二章首版。\n'
        'WASD/方向键移动；E互动；Enter/空格推进；数字键选项。\n'
        'C日程与养成；M地图；J档案；Esc菜单或跳过演出；F11全屏。\n'
        'F5存档；F9读档。战斗A攻击、D防御、1/2技能、Tab换目标、B突破。\n\n'
        '存档：%APPDATA%\\Godot\\app_userdata\\觉醒者档案：新海风云\\saves\\\n'
        '新游戏使用同一主槽，请先备份需要保留的进度。\n'
        '这是开发中的个人非商用试玩原型，当前可玩至港口A/S结算。\n\n'
        '源码与更新：https://github.com/linbainian/xinhai-fengyun\n', encoding='utf-8-sig')
    shutil.copy2(GAME / 'docs/licenses/GODOT_LICENSE.txt', windows / 'GODOT_LICENSE.txt')
    output = GAME / 'builds/releases' / version
    output.mkdir(parents=True, exist_ok=True)
    runtime_zip = output / f'XinhaiFengyun-{version}-windows-x64.zip'
    source_zip = output / f'XinhaiFengyun-{version}-source.zip'
    runtime_files = sorted(path for path in windows.iterdir() if path.is_file() and path.suffix.lower() in {'.exe', '.dll', '.pck', '.dat', '.txt'})
    with zipfile.ZipFile(runtime_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in runtime_files:
            archive.write(path, f'XinhaiFengyun/{path.name}')
    with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            archive.write(path, f'xinhai-fengyun/{path.relative_to(PROJECT).as_posix()}')
    results = [{'name': path.name, 'bytes': path.stat().st_size, 'sha256': sha256(path)} for path in [executable, runtime_zip, source_zip]]
    (output / 'SHA256SUMS.txt').write_text(''.join(f"{item['sha256']}  {item['name']}\n" for item in results), encoding='ascii')
    manifest = {'version': version, 'engine': 'Godot 4.7.2', 'platform': 'Windows x86_64', 'build': 'Release',
                'embedded_pck': True, 'source_file_count': len(files),
                'source_bytes': sum(path.stat().st_size for path in files),
                'source_roots': ROOT_FILES + ['Game/', '策划与剧情/', '世界观与人物设定/'],
                'runtime_files': [path.name for path in runtime_files], 'artifacts': results}
    (output / 'release-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'output': str(output), **manifest}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
