---
name: Bug report
about: Report incorrect behavior, scan/cleanup problems, UI issues, or documentation mismatch
title: "[Bug] "
labels: bug
assignees: ""
---

## Summary
Describe the problem in one or two sentences.

## Environment
- Tool version:
- Launch method: `VBS` / `PowerShell`
- Windows version:
- Language selected in UI:
- Mode used: `Scan` / `Safe` / `Advanced`

## What happened
Describe the actual behavior.

## What you expected
Describe the expected behavior.

## Reproduction steps
1. 
2. 
3. 

## Related cleanup target or area
If known, specify:
- Rule name:
- Path involved:
- Risk level:
- Exported scan/log file names:

## Evidence
Please provide any relevant evidence:
- Screenshot
- Exported log excerpt
- Exported scan result excerpt
- Error message
- Self-test output

## Safety impact
Please check any that apply:
- [ ] No deletion happened, but scan results look wrong
- [ ] Cleanup failed unexpectedly
- [ ] A rule appears too broad
- [ ] A non-cache / non-log file may have been targeted
- [ ] UI text or translation seems incorrect
- [ ] Export behavior seems incorrect

## Validation performed
- [ ] I reviewed `README.md`
- [ ] I checked whether this is already documented behavior
- [ ] I ran the self-test when relevant:

```powershell .github/ISSUE_TEMPLATE/bug_report.md
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system_disk_slim_gui.ps1 -SelfTest
```

## Additional context
Add anything else that may help reproduce or diagnose the issue.
