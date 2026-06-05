# Rule Authoring Guide

本文档用于约束 `cleanup_targets.json` 中清理规则的编写方式，目标是让规则具备：

- 可理解
- 可验证
- 可维护
- 可扩展
- 有明确安全边界

本项目不是“尽可能删除更多文件”的脚本仓库，而是一个**证据驱动、风险分层、默认保守**的清理规则仓库。

---

## 1. 编写规则前先回答的 5 个问题

在新增任何规则之前，先确认以下问题：

1. 这是不是**缓存、日志、诊断文件、下载残留、更新残留**？
2. 这些内容是否会被应用自动重建，或删除后只带来可接受的代价？
3. 目标路径是否足够具体，避免误伤同级未知内容？
4. 是否存在更窄、更安全的匹配方式？
5. 是否有实际观测证据，而不是仅凭目录名猜测？

如果有任意一项不能明确回答，先不要加规则。

---

## 2. 允许优先考虑的清理对象

通常优先考虑以下对象：

- 浏览器 / Electron / WebView / Chromium 缓存
- Shader Cache
- 缩略图 / 图标缓存
- 临时目录中的过期文件
- 日志文件
- 崩溃转储
- WER / 诊断上报缓存
- 更新下载残留
- 明确可重建的索引或派生缓存

这些对象往往具备一个共同点：

> 删除后会重新生成，或最多导致下次启动重新下载 / 重新索引，而不会破坏应用主体。

---

## 3. 默认禁止直接纳入的对象

以下对象默认不要纳入规则：

- 应用安装目录
- 程序二进制文件
- 驱动、运行库、共享组件
- 用户文档、素材、项目文件、数据库
- 无法确认是否为缓存的数据目录
- 混合了配置、凭据、状态和缓存的目录
- 名称看起来像 `data`、`storage`、`resources` 但内容未核实的目录

### 高风险信号
如果你看到以下迹象，请先停止加规则：

- 路径位于 `Program Files`、`Windows` 或系统保护目录下
- 目录中包含 `.dll`、`.exe`、`.sys` 等运行组件
- 同一目录同时有配置文件、数据库文件和缓存文件
- 目录大小很大，但文件类型不清晰
- 清理后应用可能需要重新登录、重新同步或重新初始化

---

## 4. 规则设计原则

### 原则 A：优先最小作用域
优先使用：
- 更深层的具体目录
- 更明确的文件模式
- 更保守的匹配策略

不推荐：
- 清理整个应用根目录
- 仅凭 `cache` 关键字就全量删除
- 用一个宽泛 glob 覆盖多个未知目录

### 原则 B：单条规则单一职责
一条规则最好只解决一个问题，例如：
- 只清理某个应用的 QtWebEngine Cache
- 只清理某类 `.log` 文件
- 只清理空目录

不要让一条规则同时承担：
- 缓存清理
- 下载残留清理
- 日志清理
- 配置迁移

### 原则 C：命名要可追溯
规则名称应能表达：
- 对象应用
- 清理类型
- 观察来源或整理轮次（如适用）

例如：
- `Observed Edraw MindMaster QtWebEngine Cache Round 20`
- `Observed LarkShell Aha Profile Cache Round 19`

避免：
- `Temp Files`
- `Misc Cache`
- `Unknown Cleanup`

### 原则 D：风险要保守标注
如果你在 `Low` 和 `Medium` 之间犹豫，优先标 `Medium`。

大致参考：
- `Low`：删除后基本无感，仅重建缓存或清理日志
- `Medium`：删除后会重新下载、重新生成，或带来轻微可恢复成本
- `High`：存在明显副作用、较高误删风险、或需要用户明确知情

---

## 5. 当前支持的规则类型

### 5.1 `directory_contents`
**含义**：删除某个目录中的内容，但保留目录本身。

适合：
- 明确的缓存目录
- 临时文件目录
- 日志目录

示意：
```json:system_disk_slim_tool/cleanup_targets.json
{
  "Name": "Example App Cache",
  "Type": "directory_contents",
  "Path": "%LOCALAPPDATA%\\Vendor\\App\\Cache",
  "Risk": "Low",
  "RiskNote": "app_rebuild_cache"
}
```

### 5.2 `directory_glob_contents`
**含义**：对多组目录或带通配的目录，执行“删除目录内容、保留目录本身”。

适合：
- 同一类缓存散落在多个固定位置
- 需要覆盖多个同构缓存路径

使用注意：
- 只有在每个路径都已确认安全时再使用
- 不要用过宽泛 glob 去扫未知层级

示意：
```json:system_disk_slim_tool/cleanup_targets.json
{
  "Name": "Example Multi Cache",
  "Type": "directory_glob_contents",
  "Paths": [
    "%LOCALAPPDATA%\\Vendor\\App\\Cache",
    "%LOCALAPPDATA%\\Vendor\\App\\GPUCache"
  ],
  "Risk": "Medium",
  "RiskNote": "app_rebuild_cache"
}
```

### 5.3 `file_pattern`
**含义**：按文件名模式匹配并删除文件。

适合：
- `.log`
- `.tmp`
- `.dmp`
- 其他已知可删除的派生文件

推荐搭配：
- `Include`
- `Recurse`
- `MinAgeDays`
- `ZeroByteOnly`

示意：
```json:system_disk_slim_tool/cleanup_targets.json
{
  "Name": "Example Old Logs",
  "Type": "file_pattern",
  "Path": "%LOCALAPPDATA%\\Vendor\\App\\Logs",
  "Include": ["*.log"],
  "Recurse": true,
  "MinAgeDays": 7,
  "Risk": "Low",
  "RiskNote": "app_log_files"
}
```

### 5.4 `empty_directories`
**含义**：清理空目录。

适合：
- 清理历史残留的空壳目录
- 作为其他清理后的辅助整理

注意：
- 不要对系统核心树做大范围空目录清理
- 仍需确保路径范围是可控的

---

## 6. 字段编写建议

### `Name`
要求：
- 可读
- 可追溯
- 能看出清理对象

### `Type`
必须使用当前脚本已支持的类型，不要自造新类型后只改配置不改程序。

### `Path` / `Paths`
要求：
- 路径具体
- 尽量使用环境变量占位
- 避免机器私有绝对路径

推荐：
- `%LOCALAPPDATA%`
- `%APPDATA%`
- `%TEMP%`
- `%ProgramData%`

谨慎：
- `%WINDIR%`
- `%ProgramFiles%`
- `%ProgramFiles(x86)%`

### `Include`
仅在 `file_pattern` 等需要文件过滤时使用。

建议：
- 模式明确
- 不要一上来用 `*.*` 覆盖整个目录，除非该目录本身已被充分证明是纯可删内容

### `Recurse`
仅在确有必要时启用递归。

原则：
- 能不递归，就不递归
- 递归前先确认子层级没有混入配置或业务数据

### `MinAgeDays`
适合用于：
- 日志
- 临时文件
- 导出残留

目的：
- 避免清理刚生成、可能仍在使用的文件

### `ZeroByteOnly`
适合用于：
- 空文件残留
- 明确只想清理零字节占位文件的场景

### `Risk`
只能使用项目支持的风险级别：
- `Low`
- `Medium`
- `High`

### `RiskNote`
应尽量复用已有风险说明键；若新增键，必须同步更新 `translations.json`。

---

## 7. 证据要求

新增规则时，建议至少提供以下证据中的一部分：

- 目录完整路径
- 文件样例名
- 文件类型或扩展名
- 大小估算
- 是否由应用自动重建
- 清理后是否需要重新下载 / 重新编译缓存 / 重新索引
- 实际使用中是否产生副作用

### 推荐描述模板
可在 PR 中使用如下描述：

- App: `应用名称`
- Path: `候选路径`
- Content Type: `缓存 / 日志 / 转储 / 更新残留`
- Evidence: `观测到的文件类型、大小、用途`
- Recovery Behavior: `删除后是否自动重建`
- Risk Decision: `为什么标记为 Low / Medium / High`

---

## 8. 常见误区

### 误区 1：名字像缓存，就当缓存删
错误原因：
- 很多应用把配置、索引、登录状态也放在看起来像 cache 的目录附近

正确做法：
- 看文件类型
- 看目录层级
- 看删除后的应用行为

### 误区 2：目录很大，就一定值得加规则
错误原因：
- 大目录可能包含离线资源、安装包、业务数据、用户资产

正确做法：
- 先确定内容性质，再决定是否清理

### 误区 3：顺手把同级目录一起加了
错误原因：
- 同级目录往往用途完全不同

正确做法：
- 只提交已确认安全的那一部分

### 误区 4：只改配置，不补翻译
错误原因：
- 新增 `RiskNote` 后，如果翻译未补齐，自检会失败或 UI 说明不完整

正确做法：
- 修改配置时同步检查 `translations.json`

---

## 9. 变更后的最小验证

新增或修改规则后，至少完成：

1. JSON 结构检查
2. 命名与风险级别复核
3. `translations.json` 覆盖检查
4. 运行自检：

```powershell system_disk_slim_tool/RULE_AUTHORING_GUIDE.md
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system_disk_slim_gui.ps1 -SelfTest
```

如变更影响 README 中的对外描述，也应同步更新文档。

---

## 10. 推荐决策顺序

当你发现一个新候选目录时，建议按以下顺序判断：

1. 它是什么应用的什么目录？
2. 里面是缓存、日志，还是业务数据？
3. 能否把规则缩小到更深一级？
4. 用 `directory_contents` 是否比更宽的方式更安全？
5. 是否需要 `MinAgeDays`、`Include`、`ZeroByteOnly` 进一步收窄？
6. 这个规则放到 `safe` 还是 `advanced` 更合适？

---

## 11. 一句话准则

> 新规则默认宁可漏删，不可误删；先证明“为什么能删”，再决定“怎么删”。
