# Windows打包与GitHub发布 · 2026-10-02

仓库：[linbainian/xinhai-fengyun](https://github.com/linbainian/xinhai-fengyun)，公开仓库；试玩版本标记 `preview-2026-10-02`，下载入口为[对应Release](https://github.com/linbainian/xinhai-fengyun/releases/tag/preview-2026-10-02)。

新增仓库首页README和工程开发README，包含可玩范围、操作、存档、源码结构、台词编辑、规则验收与重新导出命令。当前内容包含首章、01-04—01-14自由养成、第二章首版，以及最新白沐瑶初识对白修订。

Godot 4.7.2的Windows x86_64模板从官方godot-builds发布页安装。通过Godot编辑器API `EditorExportPlatformWindows.create_preset()`生成平台默认值，使用ConfigFile保存新增 `export_presets.cfg`。预设使用Release、PCK嵌入EXE、剧情JSON随包导出，并排除开发测试、文档预览及生成参考图。没有手工修改project.godot或引擎缓存。

运行包输出为 `Game/builds/windows/XinhaiFengyun.exe`。`tools/package_release.py`生成Windows ZIP、完整源码ZIP、SHA256SUMS与构建清单，输出到 `Game/builds/releases/preview-2026-10-02/`。Godot引擎许可由 `Engine.get_license_text()`提取，随运行包提供。

源码保留 `Game/`、`策划与剧情/`、`世界观与人物设定/` 的同级结构，台词作者稿与导入工具可继续配合使用。发布使用忽略目录下的独立源码快照，原Game/.git与既有历史保持。源码排除.git、.godot、构建输出、开发备份、Python缓存及本机助手状态；二进制运行包作为Release附件上传。

重新构建与打包命令见 [Game/README.md](../README.md)。

## 验证结果

- 官方Windows Release模板导出成功，EXE内嵌PCK，文件179,961,360字节。JSON配表与当前白沐瑶“谢谢”版本随包导出。
- 实际EXE从工程外的验证目录headless启动并自动退出，退出码0，日志包含章节Ready；再次使用真实GPU启动，结果归入本地发布验证记录。
- 使用相同版本Godot的 `--main-pack`直接挂载导出EXE内的PCK检查资源、存档与场景：headless410/410项通过，GPU窗口414/414项通过。确认读取project.binary，未借用松散project.godot；地图和演出引用可解析，tests/tools/docs未进入运行包。
- 窗口覆盖1280×720和1920×1080、中文标题、日程面板、图书馆自动入场、选择、最新道谢对白、奖励结算与返回养成。测试写入独立 `user://release-verification/chapter.json`，不操作正式主槽。

官方Release模板禁用了外部脚本路径覆盖，因此场景自动化由同版本Godot挂载**最终导出包**执行；EXE自身另做独立启动检查。源码中的完整规则回归与M2一小时人工连续试玩属于另行记录的验收，不能由本次导出检查替代。

预览：[Windows标题](previews/windows_release_20261002/windows-title.png)、[养成面板](previews/windows_release_20261002/windows-cultivation.png)、[图书馆道谢](previews/windows_release_20261002/windows-library-thanks.png)、[1080p面板](previews/windows_release_20261002/windows-cultivation-1080p.png)。

导出方式参考[Godot官方Windows导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)与[项目导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)。ZIP附带SHA256SUMS，Release附件校验与发布清单保存在本地构建目录。
