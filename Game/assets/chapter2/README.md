# 第2章生成像素素材

2026-10-01新增8份内置ImageGen原图，包含江北辰、韩烛、秦妖妖各4方向×4行走帧，酒吧4人物（靳寻、老猎人、港口工人、女猎人），4异兽/残骸、裂隙门、6地表切片及4远征物件（货箱、晶岩、系船柱、急救箱）。没有第三方素材下载。

人物外观与能力参照032江北辰、026韩烛、061秦妖妖、185靳寻；靳寻34岁、胡茬旧外套，不戴帽子。林初夏沿用首章清晰人物，能力按060被动预知；没有追加主动攻击异能。

保留 `*_raw.png` 原图、`prompts/*.prompt.txt` 提示词、每套QC报告及 `manifest.json`，运行输出共67张PNG。静态人物/物件/异兽输出96×96硬透明帧；3名行走角色共48帧，身体高度CV≤0.08、脚底偏差为0；地表6张48×48不透明切片。全都使用最近邻采样，与首章尺度衔接。

管线由 `tools/process_playable_art.py` 编排本地sprite处理器。仅做品红抠图、拆帧、统一尺度与脚底对齐、最近邻缩放及调色板限制。原图本身由ImageGen生成；Python没有画出最终游戏美术。地图加载独立组件和碰撞，预览截图不作为整幅背景加载。

在Game目录执行：

```powershell
$py = 'C:/Users/l/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$processor = 'C:/Users/l/.agents/skills/generate2dsprite/scripts/generate2dsprite.py'
$env:PYTHONIOENCODING = 'utf-8'
& $py tools/process_playable_art.py --processor $processor --bundle chapter2
& $py tools/build_chapter_two_maps.py
& $py tests/chapter2_assets.py
& $py tools/reproduce_playable_art.py --processor $processor
```

最后一项同时重处理大厅与第2章两套素材，共14份原图/79张运行PNG；本机全部哈希一致。更改原图/提示词后应重新处理，manifest随输出更新，再让Godot导入。禁止手动编辑 `.godot` 或 `.import`。

新增8图与10段演出维护于 `data/chapter2/maps.json` / `cutscenes.json`。实际玩法、检查与预览见 [第2章验收记录](../../docs/第2章验收记录.md)。
