## Summary
Describe what this PR changes.

## Change type
- [ ] New cleanup rule
- [ ] Existing rule adjustment
- [ ] Documentation update
- [ ] Translation update
- [ ] GUI / script logic change
- [ ] Release / packaging improvement

## Why this change is needed
Explain the motivation and problem being solved.

## Files changed
List the main files touched.

- `cleanup_targets.json`
- `translations.json`
- `system_disk_slim_gui.ps1`
- `README.md`
- `CONTRIBUTING.md`
- `RULE_AUTHORING_GUIDE.md`
- Other:

## Rule-related details
If this PR adds or changes cleanup rules, complete this section.

- App / component:
- Rule name(s):
- Rule type(s):
- Suggested risk level(s):
- Suggested `RiskNote`(s):
- Why the scope is safe and narrow:

## Evidence
Provide the evidence supporting this change.

Examples:
- directory listing summary
- sample filenames
- scan result excerpt
- before/after behavior
- screenshots
- validation notes

## Validation performed
Check all that apply.

- [ ] Reviewed `CONTRIBUTING.md`
- [ ] Reviewed `RULE_AUTHORING_GUIDE.md`
- [ ] Updated `translations.json` if new `RiskNote` or UI text was introduced
- [ ] Updated `README.md` if user-visible behavior changed
- [ ] Updated `CHANGELOG.md` when appropriate
- [ ] Ran self-test successfully

Self-test command used:

```powershell .github/pull_request_template.md
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system_disk_slim_gui.ps1 -SelfTest
```

## Risk review
Please confirm the following when applicable.

- [ ] This change does not target system core directories
- [ ] This change does not target application binaries or runtime components
- [ ] This change does not assume machine-specific absolute paths
- [ ] This change keeps cleanup scope intentionally narrow
- [ ] Any medium/high risk behavior is explicitly documented

## Additional notes
Anything maintainers should pay special attention to.
