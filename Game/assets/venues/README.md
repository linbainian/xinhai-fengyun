# 学院任务大厅与管理局服务大厅素材

2026-10-01重新生成两处建筑墙体、两张柜台和两组人物；来源均为内置OpenAI ImageGen，未下载第三方素材。保留6份 `*_raw.png`、逐份提示词 `prompts/*.prompt.txt`、处理结果及 `manifest.json` 的来源/提示词/运行SHA256。

学院为奶油色木质学生服务大厅，4名新人物为任务管理员、候办男生、社团值日生和设施员。管理局为蓝灰色三联服务窗口，4名新人物为受理员、执勤员、候办市民和档案员。运行包含墙体/柜台4张和人物8帧，共12张PNG。

原图采用品红背景。`tools/process_playable_art.py` 只做裁切、抠色、最近邻缩放、调色板约束和身体尺度对齐，不绘制最终素材。人物输出96×96透明帧，与首章人物共同尺度；墙体额外清理暗品红边缘。NPC调色板最多48色、硬透明；柜台在地图中按世界尺寸放置，窗口的 `bureau_glass.gdshader` 将玻璃区域转为半透明灰蓝，保留工作人员可见。

在Game目录重跑：

```powershell
$py = 'C:/Users/l/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$processor = 'C:/Users/l/.agents/skills/generate2dsprite/scripts/generate2dsprite.py'
$env:PYTHONIOENCODING = 'utf-8'
& $py tools/process_playable_art.py --processor $processor --bundle venues
& $py tools/build_chapter_two_maps.py
& $py tests/chapter2_assets.py
```

`data/chapter1/maps.json` 的hall/cbd由上述地图脚本维护，墙体/物件/人物/碰撞独立。若重跑旧首章地图构建器，再运行 `build_chapter_two_maps.py` 恢复两处大厅。

完整两套新素材的14原图→79PNG重现已通过 `tools/reproduce_playable_art.py --processor $processor`，证据 `.dev/playable-art-reproduction.json`。实机截图与首章回归见 [第2章验收记录](../../docs/第2章验收记录.md)。
