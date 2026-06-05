# Changelog

All notable changes to this project should be documented in this file.

## [Unreleased]

### Added
- Added GitHub-oriented project documentation in `README.md`.
- Added repository-root `README.md` as a GitHub landing page and navigation entry.
- Added `CONTRIBUTING.md` to document collaboration expectations and contribution workflow.
- Added `RULE_AUTHORING_GUIDE.md` to document evidence standards, safety boundaries, and rule design conventions.
- Added GitHub collaboration templates for bug reports, cleanup rule proposals, and pull requests.
- Added `RELEASE_NOTES_TEMPLATE.md` for GitHub Releases and package publication notes.
- Added concrete `RELEASE_NOTES_v1.3.md` for immediate GitHub publication use.
- Added `PACKAGING_GUIDE.md` for portable ZIP release preparation.
- Added `screenshots/README.md` as guidance for presentation assets and screenshot maintenance.
- Added release preparation checklist for future publishing.
- Added ignore recommendations for runtime exports and generated logs.
- Added `LICENSE` with Apache-2.0.

### Changed
- Switched config and translation loading to be rooted at the script directory.
- Added `exports/` as the default relative export directory for logs and scan results.
- Changed cleanup status reporting to auto-detect the system drive instead of assuming `C:`.
- Improved elevation startup to reuse the tool root as working directory.
- Updated localized strings to remove hard-coded drive wording and executable naming assumptions.

### Validation
- `system_disk_slim_gui.ps1 -SelfTest` passes after the portability changes.

## [1.3] - 2026-06-05

### Added
- Added multiple observed cleanup targets for domestic desktop apps and embedded Chromium caches.
- Added `Observed Edraw MindMaster QtWebEngine Cache Round 20` rule.
- Added `Observed LarkShell Aha Profile Cache Round 19` rule.
- Added NetEase CloudMusic and MailMaster related cleanup rules.

### Changed
- Expanded cleanup coverage for Electron / Chromium / WebView style caches.
- Continued using evidence-driven rule additions with narrow path scope and explicit risk notes.
