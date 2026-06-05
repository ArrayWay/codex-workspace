# Release Notes Template

> 用于整理 GitHub Release 页面、压缩包说明或版本公告。

请在发版时复制本模板，并根据实际版本内容删除不适用项。

---

## Version
- Version: `vX.Y`
- Release date: `YYYY-MM-DD`

## Summary
用 2~4 句话概括本次版本的核心变化。

示例：
- expanded cleanup coverage for selected desktop app caches
- improved portability through script-relative paths
- added contributor documentation and GitHub collaboration templates

## Highlights

### 1. New cleanup coverage
列出本次新增或显著调整的清理目标：

- `Rule name A`
- `Rule name B`
- `Rule name C`

建议补充说明：
- 覆盖的是哪类应用或缓存
- 是否属于可重建缓存
- 是否只在 `advanced` 模式生效

### 2. Safety / risk boundary changes
如本次调整了风险边界、保护逻辑或规则范围，请说明：

- narrowed rule scope for `...`
- added or clarified `RiskNote` for `...`
- improved protection against risky paths

### 3. Portability / UX improvements
如本次版本改善了运行方式、路径兼容性或导出体验，请说明：

- script-relative config loading
- auto-created export directory
- system drive auto-detection
- launcher or elevation flow improvements

## Included documentation updates
列出本次版本新增或更新的文档：

- `README.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `RULE_AUTHORING_GUIDE.md`
- `GITHUB_RELEASE_CHECKLIST.md`
- `.github` templates

## Validation
建议写明本次发布前做过哪些验证：

- [ ] `system_disk_slim_gui.ps1 -SelfTest` passed
- [ ] launch via `run_system_disk_slim_gui.vbs` tested
- [ ] launch via PowerShell tested
- [ ] scan mode tested
- [ ] export flow tested

也可附上实际命令：

```powershell system_disk_slim_tool/RELEASE_NOTES_TEMPLATE.md
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system_disk_slim_gui.ps1 -SelfTest
```

## Upgrade / usage notes
如果用户升级后需要注意某些事项，请说明：

- whether old exports can be kept or ignored
- whether new rules may appear only in `advanced` mode
- whether users should rerun scan before cleanup

## Known limitations
如有已知限制，可在这里列出：

- no packaged `.exe` yet
- screenshots may lag behind the latest UI
- cleanup coverage remains intentionally conservative

## Download / package contents
如你发布 ZIP，可列出主要内容：

- `system_disk_slim_gui.ps1`
- `run_system_disk_slim_gui.vbs`
- `cleanup_targets.json`
- `translations.json`
- documentation files

## One-line release summary
> Replace this line with a short release summary for GitHub Releases.
