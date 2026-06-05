# System Disk Slimmer

一个面向 Windows 的**配置驱动系统盘清理工具**。核心目标不是“激进删除”，而是：

- **先扫描、后清理**
- **按风险分层**
- **优先清理可重建缓存、日志、诊断文件、更新残留**
- **尽量扩大覆盖，但避免误伤系统核心目录和应用运行时**

适合作为个人桌面工具，也适合作为后续发布到 GitHub 的可维护项目基础。

---

## 项目亮点

### 1. 配置驱动，而不是把规则写死在代码里
清理目标集中定义在 `cleanup_targets.json`：

- 新增规则不需要改 GUI 主逻辑
- 便于持续补充新应用缓存类型
- 便于审查每条规则的风险等级和适用范围

### 2. 风险分层明确
工具内置三种模式：

- **Safe / 安全清理**：优先清理低风险缓存、日志、临时文件
- **Advanced / 进阶清理**：额外纳入部分需要重新下载的资源/插件
- **Scan Only / 仅扫描**：只做发现和估算，不执行删除

### 3. 有保护机制，不是无脑删
主脚本内置保护路径判断，默认跳过：

- `System32`
- `SysWOW64`
- `WinSxS`
- `Installer`
- `Program Files`
- `System Volume Information`
- `Recovery`

同时会跳过：

- 重解析点 / 链接目录
- 不存在路径
- 明显受保护目录

### 4. 多语言支持
当前内置：

- 中文
- English
- 日本語

文本统一由 `translations.json` 管理，方便继续扩展语言。

### 5. GUI 直接可用
基于 PowerShell + Windows Forms：

- 无需额外安装 Python / Node / .NET SDK
- Windows 自带 PowerShell 环境即可运行
- 支持扫描结果导出、日志导出、选择性清理

### 6. 已做通用化处理，方便分发
当前版本已经尽量避免依赖开发机路径：

- 配置文件通过 **相对脚本目录** 加载
- 翻译文件通过 **相对脚本目录** 加载
- VBS 启动器通过 **自身目录** 启动 PowerShell
- 导出文件默认落到工具目录下的 `exports/`
- 系统盘空闲空间显示改为 **自动识别系统驱动器**，不再写死 `C:`

---

## 目录结构

```text
repo-root/
├─ README.md                      # 项目说明 / GitHub 首页
├─ CHANGELOG.md                   # 版本变更记录
├─ CONTRIBUTING.md                # 协作与贡献说明
├─ RULE_AUTHORING_GUIDE.md        # 清理规则编写规范
├─ GITHUB_RELEASE_CHECKLIST.md    # 发布前检查清单
├─ RELEASE_NOTES_v1.3.md          # 当前版本发布说明
├─ PACKAGING_GUIDE.md             # 打包与发布说明
├─ LICENSE                        # Apache-2.0 许可证
├─ .gitignore                     # 忽略导出与运行产物
├─ system_disk_slim_gui.ps1       # 主程序（GUI + 扫描/清理逻辑）
├─ run_system_disk_slim_gui.vbs   # 静默启动器
├─ cleanup_targets.json           # 清理规则配置
├─ translations.json              # 多语言文案
├─ screenshots/                   # GitHub 展示截图
│  ├─ language-selection.png
│  ├─ cleanup-modes.png
│  ├─ cleanup-log-example.png
│  └─ README.md
├─ .github/                       # GitHub issue / PR 模板
│  ├─ ISSUE_TEMPLATE/
│  │  ├─ bug_report.md
│  │  └─ rule_proposal.md
│  └─ pull_request_template.md
└─ exports/                       # 扫描结果/日志导出目录（运行时自动创建）
```

---

## 运行方式

### 方式 1：双击启动
直接运行：

- `run_system_disk_slim_gui.vbs`

### 方式 2：PowerShell 启动
在工具目录中执行：

```powershell system_disk_slim_tool/README.md
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\system_disk_slim_gui.ps1
```

### 方式 3：自检
用于发布前或改规则后验证配置和多语言是否完整：

```powershell system_disk_slim_tool/README.md
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system_disk_slim_gui.ps1 -SelfTest
```

---

## 规则模型

`cleanup_targets.json` 目前支持以下类型：

- `directory_contents`
  - 删除目录下内容，但保留目录本身
- `directory_glob_contents`
  - 对多组通配目录执行内容清理
- `file_pattern`
  - 通过文件名模式匹配删除
- `empty_directories`
  - 清理空目录

常见字段：

- `Name`
- `Type`
- `Path` / `Paths`
- `Include`
- `Recurse`
- `ZeroByteOnly`
- `MinAgeDays`
- `Risk`
- `RiskNote`

风险级别：

- `Low`
- `Medium`
- `High`

---

## 当前覆盖思路

本项目目前更偏向以下“高性价比”清理目标：

- Windows 临时目录
- Windows Update / Delivery Optimization 缓存
- 缩略图 / 图标缓存
- WER / CrashDumps / 诊断日志
- 显卡 Shader Cache
- Chromium / WebView / Electron 类缓存
- 常见桌面应用日志、崩溃报告、缓存目录
- 下载残留、更新残留、局部安装器缓存

并且已经针对多个中国区常见桌面软件做了专项补充，例如：

- 网易云音乐 / 网易邮箱大师
- WPS / Kingsoft
- 微信 / QQ / 腾讯会议
- 百度网盘
- 剪映
- Quark / Doubao / LarkShell / CherryStudio / Codex / Claude 等 Electron / Chromium 桌面应用

---

## 安全边界

这个工具的设计原则是：

1. **默认优先缓存、日志、临时文件**
2. **单条规则尽量窄化**，避免“大而全”误删
3. **不默认删除系统核心目录**
4. **不默认删除应用主程序目录 / 运行时目录 / 二进制本体**
5. **对需要重新下载的资源，明确标记风险说明**

如果你要新增规则，建议遵守：

- 先扫描证据
- 再判断是否属于可重建缓存 / 日志 / 下载残留
- 不要把安装目录、运行时、驱动本体直接加入清理
- 新规则尽量单一职责、命名可追溯

---

## 适合发布到 GitHub 的原因

这个项目已经具备较好的开源基础：

- 结构简单
- 依赖少
- 配置与逻辑分离
- 有多语言
- 有自检入口
- 有风险分层
- 有明确保护路径
- 规则可以持续扩展

后续如果要进一步发布化，建议再补：

1. 真实界面截图补充到 `screenshots/`
2. 可选的英文独立首页增强内容
3. 若后续发新版，继续补充对应版本发布说明

当前项目已经补充：

- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `RULE_AUTHORING_GUIDE.md`
- `GITHUB_RELEASE_CHECKLIST.md`
- `RELEASE_NOTES_v1.3.md`
- `PACKAGING_GUIDE.md`
- `LICENSE`（Apache-2.0）
- `.gitignore`
- `screenshots/README.md`
- 3 张实际界面效果图

当前仓库根目录发布时，也可直接使用以下 GitHub 协作模板：

- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/rule_proposal.md`
- `.github/pull_request_template.md`

---

## 建议的后续优化

### 功能层
- 增加“按应用分类筛选”
- 增加“仅显示大于 X MB 项目”
- 增加“删除前导出快照”
- 增加“规则命中数 / 规则回收量统计”

### 工程层
- 把主脚本进一步拆分为：
  - UI 层
  - 配置校验层
  - 扫描层
  - 删除执行层
- 增加 Pester 测试
- 为规则建立命名规范文档

### 发布层
- 可选封装为 `.exe`
- 增加英文 GitHub 首页说明
- 后续版本继续补充真实界面截图与更新日志

---

## 许可证

本项目当前采用：

- `Apache-2.0`

适合希望开源发布、允许再分发和商用、同时保留明确许可证与专利条款的场景。

---

## 快速结论

如果要一句话概括这个项目：

> 这是一个以“安全边界 + 配置驱动 + 桌面软件缓存覆盖”为核心设计的 Windows 系统盘清理工具，适合持续扩展并发布到 GitHub。
