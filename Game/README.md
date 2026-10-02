# 觉醒者档案：新海风云 · Godot 工程

**Godot 4.7.2 标准版 / GDScript / Compatibility / Windows PC。** 当前可玩首章01-01—01-03、自由养成01-04—01-14和01-15起的第二章首版，最终平衡与M2连续试玩尚待验收。项目介绍、试玩下载与按键见[仓库首页](../README.md)。

## 从源码运行

1. 保留 `Game/`、`策划与剧情/`、`世界观与人物设定/` 的同级结构。
2. 用 Godot 4.7.2 导入本目录 `project.godot`，等待首次资源导入。
3. 按 **F5** 运行 `scenes/chapter/chapter_one.tscn`。F6只运行当前选中的开发场景。

PowerShell也可运行；将 `$Godot` 改为本机编辑器路径：

```powershell
$Godot = 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe'
& $Godot --path .
```

世界层以960×540为构图基准，UI以1920×1080为布局基准；`ChapterDisplay`负责窗口、最大化与F11全屏自适应。探索镜头2倍、战斗角色3倍，角色与地表采用最近邻采样。

## 编辑台词与配表

对白作者稿保存在工程外的 `../策划与剧情/`。用Python 3运行导入工具，默认先检查；`--apply`先备份再导入运行JSON和Game/docs可读副本：

```powershell
python tools/import_chapter_script.py
python tools/import_chapter_script.py --apply
python tools/import_chapter_two_script.py --apply
python tools/import_encounter_script.py --apply
```

当前正文为首章61片段/296句、第二章113片段/394句、独立人物奇遇19片段/101句。白沐瑶图书馆初识只点头道谢，后续对练按熟悉程度回应；最新剧情卷为v0.3.11。不要用旧运行数据覆盖作者稿。

`data/chapter1/`、`data/chapter2/`、`data/cultivation/`保存地图、对白、选项、演出和成长配表，`data/battle/`保存战斗Resource。美术管线重跑说明在各assets目录的README；维护任务大厅地图时运行 `tools/build_chapter_two_maps.py`。

## 导出 Windows EXE

先安装与编辑器**完全匹配**的Godot 4.7.2导出模板。在“项目 → 导出”中可编辑已有的 **Windows Desktop** 预设：x86_64、Release、PCK嵌入EXE，剧情JSON随包导出，开发测试、文档预览及生成参考图排除在运行包外。

从Game目录执行：

```powershell
$Godot = 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Path builds/windows -Force | Out-Null
& $Godot --headless --path . --export-release 'Windows Desktop' builds/windows/XinhaiFengyun.exe
python tools/package_release.py --version preview-2026-10-02
```

`builds/`被Git忽略，压缩包通过GitHub Release发布。导出模板与引擎不放进源码仓库。正式包保留 `XinhaiFengyun.exe`、中文启动说明、引擎许可和导出器生成的运行依赖；请完整解压。

打包工具另生成完整源码ZIP，包含工程、策划和角色设定，排除缓存、旧构建、开发备份、Python缓存与本机助手状态。它不会修改原来的Git仓库或运行资源。

## 验证

以下命令在Game目录执行，使用既有规则验收：

```powershell
& $Godot --headless --path . --script res://tests/chapter1_smoke.gd
& $Godot --headless --path . --script res://tests/chapter2_smoke.gd
& $Godot --headless --path . --script res://tests/cultivation_smoke.gd
& $Godot --headless --path . --script res://tests/encounter_smoke.gd
python tests/chapter1_assets.py
python tests/chapter2_assets.py
python tests/encounter_assets.py
python tests/map_routes.py
```

窗口验收需本机GPU，会打开游戏并使用独立测试存档。`tests/chapter1_visual.gd`、`chapter2_visual.gd`、`cultivation_visual.gd`、`encounter_visual.gd`覆盖实际键鼠和剧情演出；报告写到忽略的 `.dev/`。导出后的EXE也须验证，不能以编辑器F5成功代替。

## 保留的开发入口

| 场景 | 用途 |
|---|---|
| `scenes/main.tscn` | M0移动、碰撞和相机灰盒 |
| `scenes/battle/battle_sandbox.tscn` | M1-A独立1v1 |
| `scenes/battle/battle_rules_sandbox.tscn` | M1-B多单位、技能、克制、CD和精神负荷 |
| `scenes/battle/breakthrough_sandbox.tscn` | M1-C临界槽、突破、保底和温让测试 |
| `scenes/battle/back_hill_tutorial.tscn` | M1-D三段后山教学战 |

F6运行相应场景。灰盒中的测试值与正式章节配表分别维护；整段战斗日志写入 `user://battle_logs/`。

## 维护文档

- [项目约定](../AGENTS.md)
- [首章验收与边界](docs/第1章验收记录.md)
- [第二章验收](docs/第2章验收记录.md)
- [自由养成验收](docs/自由养成验收记录.md)
- [转场与角色登场](docs/第1章转场演出.md)
- [奇遇自动触发](docs/奇遇自动触发与台词修订.md)
- [对白整体修订](docs/游戏对白与剧情衔接修订.md)
- [白沐瑶初识修订](docs/白沐瑶初识对白修订.md)
- [Windows打包与发布](docs/Windows打包与GitHub发布.md)

`.godot/`由引擎管理，不手工编辑或提交。场景与资源保留原有路径和UID；导出设置优先通过Godot编辑器修改。存档始终写入 `user://`，运行包内的 `res://`只读。
