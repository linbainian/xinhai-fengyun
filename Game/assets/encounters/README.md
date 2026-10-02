# 人物奇遇与校园生活素材

2026-10-01，内置ImageGen生成，使用`generate2dmap`、`generate2dsprite`及`imagegen`技能。用于社团招新、寝室/共用走廊、图书馆、苏家冰品店和训练场人物事件。

## 来源与运行资源

`manifest.json`记录11份源图、对应提示词、源图/提示词/80张运行PNG的SHA256，以及14个独立物件。原图为`*_raw.png`，提示词在`prompts/`；本包没有下载网络素材。

| 资源 | 运行数量 | 用途 |
|---|---|---|
| 白沐瑶、苏晚棠、林初夏 | 每人16帧+1张运行整表，共51张 | 四向走位、转身、出入场 |
| 职员与招新人员 | 4帧+1张运行整表，共5张 | 冰品店、图书馆、摊位 |
| 冰墙与雷电 | 每种4帧+1张运行整表，共10张 | 训练场对练演出 |
| 独立物件 | 14张 | 四类墙体、两种柜台、摊位、楼梯、书本、笔记本、冰碗、纸袋、手机、饭团 |

人物使用96×96源帧、48×48世界占位；整表与单帧采用同一脚底锚点和尺度。硬透明、48色调色板、最近邻缩放，行走方向有独立姿势。墙体、柜台与楼梯按物件宽高裁切，不塞进人物小格。

地图加载单件资源和TileMapLayer地表；碰撞、互动、Y排序及桌面前景层由地图数据维护。物件锚点见`manifest.json`和`runtime-qc.json`。截图用于预览，游戏不加载整幅截图。

## 重处理

在Game目录执行；这一步会从保留源图重新输出本包运行PNG和manifest：

```powershell
$py = 'C:/Users/l/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$processor = 'C:/Users/l/.agents/skills/generate2dsprite/scripts/generate2dsprite.py'
$env:PYTHONIOENCODING = 'utf-8'
& $py tools/process_encounter_art.py --processor $processor
& $py tools/build_encounter_maps.py
& $py tests/encounter_assets.py
```

处理器只做抠色、切帧、尺度/脚底对齐、调色板、最近邻导出与QC；新画面由ImageGen生成。`--sources`用于首次复制生成源图及提示词，已有完整源图时省略。

全套地图重建应先运行原大会场、首日演出及第二章构建器，再最后运行`build_encounter_maps.py`，恢复本包的走廊、寝室、招新与奇遇布局。运行后让Godot自行导入，禁止手改`.godot`或`.import`。

口语与自动触发修订后，资源/地图/作者稿检查2196/2196通过，GPU奇遇输入1282/1282通过。养成演出现16段（十一自动入场、五选择），80张运行PNG与源图保持。实际截图、日期和维护入口见[人物奇遇与宿舍场景验收](../../docs/人物奇遇与宿舍场景验收.md)与[最新修订](../../docs/奇遇自动触发与台词修订.md)。
