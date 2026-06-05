# Packaging Guide

本说明用于将当前项目整理成可直接发布到 GitHub Releases 的 ZIP 包。

目标不是制作安装器，而是提供一个**便携、相对路径可运行、开箱即用**的发布包。

---

## 1. 推荐发布形式

当前最推荐的发布形式是：

- GitHub 仓库源码
- GitHub Release 附件 ZIP

建议 ZIP 名称示例：

- `system-disk-slimmer-v1.3.zip`
- `system-disk-slim-tool-v1.3.zip`

---

## 2. ZIP 内应包含的文件

建议至少包含以下文件：

- `system_disk_slim_gui.ps1`
- `run_system_disk_slim_gui.vbs`
- `cleanup_targets.json`
- `translations.json`
- `README.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `RULE_AUTHORING_GUIDE.md`
- `GITHUB_RELEASE_CHECKLIST.md`
- `LICENSE`

如希望发布说明一并随包附带，也可加入：

- `RELEASE_NOTES_v1.3.md`
- `PACKAGING_GUIDE.md`

---

## 3. ZIP 内不应包含的内容

发布前请不要将以下内容打进包中：

- `exports/` 目录下的运行产物
- 导出的扫描 CSV / JSON
- 导出的日志文件
- 本机调试文件
- 临时调查脚本
- 与项目无关的仓库其他目录
- 用户名、绝对路径、设备特征明显的文件

---

## 4. 推荐目录结构

建议发布包解压后保持如下结构：

```text system_disk_slim_tool/PACKAGING_GUIDE.md
system-disk-slimmer-v1.3/
├─ README.md
├─ CHANGELOG.md
├─ CONTRIBUTING.md
├─ RULE_AUTHORING_GUIDE.md
├─ GITHUB_RELEASE_CHECKLIST.md
├─ LICENSE
├─ system_disk_slim_gui.ps1
├─ run_system_disk_slim_gui.vbs
├─ cleanup_targets.json
└─ translations.json
```

如果一并附带发布说明，也可以多放：

```text system_disk_slim_tool/PACKAGING_GUIDE.md
system-disk-slimmer-v1.3/
├─ RELEASE_NOTES_v1.3.md
└─ PACKAGING_GUIDE.md
```

---

## 5. 发布前检查顺序

建议在打包前至少完成以下顺序：

1. 运行 `-SelfTest`
2. 确认 `README.md` 与当前行为一致
3. 确认 `cleanup_targets.json` 无无效规则
4. 确认 `translations.json` 覆盖完整
5. 清理导出文件与调试残留
6. 检查 ZIP 内只包含发布所需文件

---

## 6. 建议的发布说明内容

GitHub Release 页面建议至少包含：

- 本版本摘要
- 新增清理覆盖
- 风险边界说明
- 可移植性改进
- 自检验证说明
- 启动方式

可直接参考：

- `RELEASE_NOTES_v1.3.md`

---

## 7. 用户使用说明建议

在 Release 页面建议明确告诉用户：

### 启动方式
- 双击 `run_system_disk_slim_gui.vbs`
- 或用 PowerShell 运行 `system_disk_slim_gui.ps1`

### 推荐流程
- 先执行扫描
- 查看命中项
- 再决定是否执行 Safe / Advanced 清理

### 权限说明
- 某些清理目标可能需要管理员权限
- 如果自动提权失败，可手动以管理员身份运行启动器或 PowerShell 脚本

---

## 8. 当前适合公开发布的理由

按目前项目状态，已经具备公开发布的基本条件：

- 相对路径加载已完成
- 导出目录行为已明确
- 系统盘识别不再写死
- 自检可用于发布前验证
- License、README、CHANGELOG、贡献文档已齐全
- GitHub issue / PR 模板已补齐

---

## 9. 暂不建议承诺的事项

在正式发布文案中，当前不建议承诺以下内容：

- 支持所有 Windows 应用的全面清理
- 一键深度清理所有磁盘垃圾
- 不需要任何人工判断的自动安全删除
- 已有 `.exe` 安装版或签名发行版

更准确的表述应是：

> 这是一个保守、配置驱动、适合逐步扩展的 Windows 清理工具。

---

## 10. 一句话发布建议

如果现在就要发 GitHub Release，推荐采用：

- 附件：便携 ZIP
- 文案：使用 `RELEASE_NOTES_v1.3.md`
- 首页：直接使用当前项目的 `README.md`
- 发布说明：使用 `RELEASE_NOTES_v1.3.md`
