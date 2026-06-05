# GitHub Release Checklist

## 1. Basic repository readiness
- [ ] Confirm `system_disk_slim_gui.ps1 -SelfTest` passes
- [ ] Confirm `cleanup_targets.json` has no invalid rules
- [ ] Confirm `translations.json` covers all risk notes and UI keys
- [ ] Confirm `README.md` matches current behavior

## 2. Runtime artifact cleanup
- [ ] Do not commit `exports/`
- [ ] Do not commit generated scan result files
- [ ] Do not commit generated log files
- [ ] Do not commit machine-specific debug artifacts

## 3. Packaging checks
- [ ] Test launching via `run_system_disk_slim_gui.vbs`
- [ ] Test launching via PowerShell directly
- [ ] Test scan mode
- [ ] Test safe cleanup mode
- [ ] Test advanced cleanup warning flow
- [ ] Test export log / export scan result flow

## 4. Portability checks
- [ ] Verify script works when folder is moved to another path
- [ ] Verify config and translations load from script-relative paths
- [ ] Verify system drive display is auto-detected
- [ ] Verify export directory is created automatically

## 5. Release notes
- [x] Summarize newly added cleanup targets
- [x] Summarize risk boundary changes
- [x] Summarize portability / GitHub readiness improvements
- [x] Prepare concrete release notes document (`RELEASE_NOTES_v1.3.md`)

## 6. Optional publishing items
- [x] Choose a license explicitly (`Apache-2.0`)
- [x] Add screenshots guidance / placeholder documentation
- [x] Add contribution guide for new cleanup rules
- [x] Add issue template / bug report template
- [x] Add rule authoring guide for evidence-driven cleanup rule proposals
- [x] Add pull request template for rule and documentation review
- [x] Add release notes template for GitHub Releases or ZIP publication notes
- [x] Add concrete packaging guide for ZIP publication
