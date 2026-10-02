# 首章像素美术

更新：2026-10-01。累计28张源图均由本项目使用内置ImageGen生成，没有下载第三方素材。`manifest.json`记录此前22张源图及77张精修运行PNG；`cinematics/manifest.json`记录追加六张四向行走源图与96帧。共173张精修运行PNG；第一批资源保留用于其他房间与开发入口。

| 目录 | 当前资源与用途 |
|---|---|
| refined/lin_da/frames | 96×96四向16帧；世界绘制占位48×48，四向共享尺度和脚底锚点 |
| refined/lin_da/rest.png | 低血休息姿势，脚底与站立人物对齐 |
| refined/npcs/frames | 96×96温让、苏挽颜、四导师、凌未央、林初夏与工作人员共9帧 |
| cinematics | 温让、苏挽颜、四导师的四向16帧，共96帧；匹配原NPC的身高和脚底线，源图/提示词/严格QC/哈希独立保留 |
| refined/fx/frames | 96×96斩击、冲击、弹道、防御、突破五组各4帧 |
| refined/hall_v2 | 大会场与检测礼堂的25个物件、6张48×48地砖 |
| refined/hall/module-manifest.json | 最终v2组件清单、源图裁剪、尺寸、脚底锚点、调色板与哈希 |
| terrain / rabbits / props / academy / counter / bed | 第一批地表、四类野兔、其他房间道具及建筑/柜台/床；旧人物源帧保留 |

`*_raw.png`及同目录下的`prompts/`为出图来源；`*_guide.png`是生成布局参考。处理仅做抠色、裁剪、最近邻缩放、调色板限制、对齐与QC。人物、效果和组件使用硬透明边缘，人物使用共享尺度；不会逐帧随意放缩。`pipeline-meta.json`、`runtime-qc.json`和`runtime-sheet.png`保留处理与检查记录。

在Game目录重跑最终资源并比较77张PNG哈希（需Pillow/Numpy）：

```powershell
& 'C:\Users\l\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/reproduce_refined_art.py --processor 'C:\Users\l\.agents\skills\generate2dsprite\scripts\generate2dsprite.py'
```

如有意重新处理并更新此前来源清单，再运行 `tools/update_art_manifest.py`，它不写台词。新96帧使用 `tools/process_cinematic_art.py --processor 处理器路径` 处理；`tools/reproduce_cinematic_art.py` 在隔离目录重处理并比较哈希，不覆盖实际运行帧。

地图数据与预览由 `tools/assemble_hall_map.py` 生成，仅改大会场和检测礼堂；随后运行 `tools/build_chapter_cinematics.py` 补回校门、主席台和演出默认路点。它重写cutscenes，手调演出前先备份。修改地图后运行 `tests/chapter1_assets.py` 检查碰撞、入口与角色接近通路。旧 `process_hall_art.py` 属于早期v1处理脚本，不用于重建最终清单。

地图资产模型为 `tile_mode / layered_tilemap / interactive_scene_objects / explicit_collision / Godot`。TileMapLayer地表、建筑、道具、NPC、互动与碰撞可独立修改；建筑按真实比例放置，旗杆以杆脚对齐，较高物件遮挡人物时淡化。外部会场中央道路通向门口与四导师，室内主席台/试炼台/看台分区明确。相机2倍、战斗角色3倍，UI独立适配窗口。

实际资源拼合预览：[大会场](refined/hall/plaza-preview.png)、[入学检测礼堂](refined/hall/auditorium-preview.png)。这些PNG只用于检查，不作为游戏背景加载。运行截图及维护说明见[首章美术与台词修订](../../docs/首章美术与台词修订.md)。
