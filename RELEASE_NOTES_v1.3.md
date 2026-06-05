# Release Notes - v1.3

Release date: 2026-06-05

## Summary
`v1.3` continues the project’s shift from a machine-specific cleanup script toward a more portable, GitHub-ready Windows cleanup tool.

This release expands observed cleanup coverage for desktop application caches, removes hard-coded path assumptions, and improves repository readiness through documentation, licensing, and collaboration support.

## Highlights

### 1. Expanded cleanup coverage
This release adds and refines cleanup targets for desktop software with embedded Chromium / WebView style caches and related residue.

Notable additions include:

- `Observed Edraw MindMaster QtWebEngine Cache Round 20`
- `Observed LarkShell Aha Profile Cache Round 19`
- NetEase CloudMusic related cleanup coverage
- MailMaster related cleanup coverage

These additions continue the project’s evidence-driven approach:

- target specific cache locations
- prefer rebuildable artifacts
- avoid broad deletion of unknown sibling directories
- keep risk notes explicit

### 2. Portability improvements
The tool is now substantially easier to move between machines or folders without path breakage.

Key improvements:

- config loading now uses script-relative paths
- translation loading now uses script-relative paths
- export output defaults to a relative `exports/` directory under the tool root
- elevated restart uses the tool root as working directory
- system drive reporting is auto-detected instead of assuming `C:`

This makes the project much more suitable for ZIP distribution and GitHub publication.

### 3. User-facing wording cleanup
Localized strings were updated to avoid hard-coded assumptions such as:

- fixed `C:` drive wording
- `.exe`-specific elevation wording

This better matches the current delivery model, where users may launch via the VBS launcher or directly via PowerShell.

### 4. GitHub readiness
The repository now includes the core documentation expected for an open-source project:

- project README / GitHub landing README
- changelog
- contribution guide
- rule authoring guide
- release checklist
- Apache-2.0 license
- issue / PR templates
- screenshot guidance

## Safety boundary notes
This release does **not** change the core philosophy of the tool.

The project still prioritizes:

- scan before cleanup
- narrow rule scope
- rebuildable caches and logs over aggressive deletion
- protected handling of risky system paths
- avoiding application binaries and runtime directories by default

The newly added cleanup rules were selected because they fit the existing conservative model rather than expanding into high-risk cleanup categories.

## Validation
The following validation was completed for the current project state:

- `system_disk_slim_gui.ps1 -SelfTest` passes
- GUI script, cleanup config, and translations validate successfully

Validation command:

```powershell system_disk_slim_tool/RELEASE_NOTES_v1.3.md
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system_disk_slim_gui.ps1 -SelfTest
```

## Packaging notes
Recommended release contents:

- `system_disk_slim_gui.ps1`
- `run_system_disk_slim_gui.vbs`
- `cleanup_targets.json`
- `translations.json`
- `README.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `RULE_AUTHORING_GUIDE.md`
- `LICENSE`

Do not include:

- `exports/`
- generated scan exports
- generated log files
- machine-specific temporary investigation scripts

## Known limitations
Current known limitations remain:

- no packaged `.exe` distribution by default
- screenshots may lag behind the latest UI state
- cleanup coverage remains intentionally conservative and selective
- the project is Windows-focused and PowerShell-based

## Suggested GitHub Release summary
> v1.3 expands evidence-driven desktop app cache coverage, removes hard-coded path assumptions, and upgrades the project into a more portable, GitHub-ready Windows cleanup tool.
