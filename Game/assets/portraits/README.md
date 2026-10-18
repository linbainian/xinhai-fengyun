# 对话人物立绘 · 2026-10-18

采用现代都市服装、细墨线轮廓、柔和水粉厚涂、自然成人比例的统一国风RPG人物画风。画面方向参考《逸剑风云决》一类“像素世界配精细人物立绘”的表现方式；本目录图片全部由内置 ImageGen 生成，不使用该游戏的原角色图或素材。

当前覆盖首章、章节前养成与第二章的33个实际发言身份；旁白、系统提示和日程记录不显示人物立绘。无对白的背景人群继续使用已有像素小人。人物姓名、年龄、性别、发色、体型和标志物按世界观条目及现有游戏像素形象核对；没有具名设定的职员、学生与店员按现有职业和像素配色做视觉设计。

- `source/*_raw.png`：内置 ImageGen 原始透明PNG，原图保留。
- `runtime/*.png`：768×1152 RGBA，等比适配、底部居中；保留原始透明通道，不绘制或替换人物。
- `prompts/*.txt`：逐人的最终生成提示词；苏挽颜作为同批画风参考。
- `res://data/portraits/characters.json`：发言名到立绘的唯一索引，附设定来源、像素身份参考、图像尺寸与SHA256。
- `res://scripts/chapter/chapter_portraits.gd`：按发言人惰性加载并缓存纹理，主对话与后山教程共用。
- `res://tools/process_dialogue_portraits.py`：透明度检查、等比规范化和联系表生成。运行 `python -X utf8 tools/process_dialogue_portraits.py --preview`。
- `res://tests/dialogue_portraits_visual.gd`：从实际三份运行台词提取人物，验证纹理、透明度、界面占位、窗口适配、移动和教程入口。

运行图按768×1152、RGBA8计算，单图解压约3.38MiB，全部33张约111.4MiB，未计引擎开销。运行时按发言人惰性加载并缓存，像素世界另用原有小尺寸纹理。

| 发言身份 | 运行图片 |
|---|---|
| 苏挽颜 | `su_wan_yan.png` |
| 林大 | `lin_da.png` |
| 温让 | `wen_rang.png` |
| 柳无眠 | `liu_wu_mian.png` |
| 沈听澜 | `shen_ting_lan.png` |
| 温若水 | `wen_ruo_shui.png` |
| 唐半夏 | `tang_ban_xia.png` |
| 凌未央 | `ling_wei_yang.png` |
| 林初夏 | `lin_chu_xia.png` |
| 江北辰 | `jiang_bei_chen.png` |
| 韩烛 | `han_zhu.png` |
| 秦妖妖 | `qin_yao_yao.png` |
| 白沐瑶 | `bai_mu_yao.png` |
| 苏晚棠 | `su_wan_tang.png` |
| 靳寻 | `jin_xun.png` |
| 苏父 | `su_fu.png` |
| 老猎人 | `old_hunter.png` |
| 旧书摊主 | `old_bookseller.png` |
| 考官 | `examiner.png` |
| 任务管理员 | `task_administrator.png` |
| 管理局职员 | `bureau_clerk.png` |
| 剑道社学长 | `club_sword_student.png` |
| 元素研究社学姐 | `club_element_student.png` |
| 治愈社学姐 | `club_healing_student.png` |
| 社团学生 | `club_recruit_student.png` |
| 招新同学 | `recruitment_student.png` |
| 社团值班生 | `club_duty_student.png` |
| 值日生 | `duty_student.png` |
| 值班员 | `field_attendant.png` |
| 学生 | `student.png` |
| 办事人员 | `civic_visitor.png` |
| 店员 | `shop_clerk.png` |
| 图书管理员 | `librarian.png` |

对话框右下角的立绘使用线性采样；移动、地图和战斗小人仍使用原有像素帧及最近邻整数缩放。原有素材路径和UID保持。原始生成图按既有导出过滤规则排除，Windows包使用runtime图片和data中的索引。生成、规范化、引擎展示与导出包验证分别记录，维护入口见 `Game/docs/人物立绘接入与验收.md`。
