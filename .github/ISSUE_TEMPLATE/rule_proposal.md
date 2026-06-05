---
name: Rule proposal
about: Propose a new cleanup rule or suggest narrowing / correcting an existing one
title: "[Rule] "
labels: rule-proposal
assignees: ""
---

## Proposal summary
Describe the rule you want to add or adjust.

## App / component
- App name:
- App version (if known):
- Vendor (if known):

## Candidate path or pattern
Provide the exact path or pattern you observed.

- Path:
- File pattern (if relevant):
- Recursive needed: `Yes` / `No`

## Content type
What kind of content is this?

- [ ] Rebuildable cache
- [ ] Log files
- [ ] Crash dumps
- [ ] Diagnostic files
- [ ] Update residue
- [ ] Temporary files
- [ ] Empty directories
- [ ] Other

## Why it looks safe
Explain why this content appears safe to remove.

Please cover if possible:
- whether the app recreates it automatically
- whether cleanup only causes re-download / re-index / recompile cache
- whether the directory mixes config, credentials, or user data

## Evidence
Provide concrete evidence instead of path-name guessing.

Examples:
- sample filenames
- file extensions
- approximate size
- screenshot
- scan result excerpt
- before/after behavior

## Risk assessment
Your suggested risk level:
- [ ] Low
- [ ] Medium
- [ ] High

Suggested `RiskNote`:

Why this risk level fits:

## Scope control
Explain how the proposal stays narrow.

- Why this path is specific enough:
- Why sibling directories are excluded:
- Why a broader wildcard should not be used:

## Suggested rule shape
If you already know the likely type, fill it in:

- Rule type: `directory_contents` / `directory_glob_contents` / `file_pattern` / `empty_directories`
- Suggested rule name:

## Validation
Please check any that apply:
- [ ] I reviewed `RULE_AUTHORING_GUIDE.md`
- [ ] I reviewed `CONTRIBUTING.md`
- [ ] I confirmed this is not an install directory or binary/runtime directory
- [ ] I confirmed the directory does not mix user data with cache
- [ ] I tested that the app still works after cleanup or can rebuild the content

## Additional notes
Add any extra context that may help maintainers evaluate the proposal.
