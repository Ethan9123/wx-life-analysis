---
name: New tool request
about: Propose a new script under tools/
title: "tools: <one-line summary>"
labels: enhancement, tool
---

## What does the tool do?

<One paragraph. Be specific about inputs and outputs.>

## Why does it belong in this repo?

<It should wrap or compose `wx-cli` outputs into a workflow useful for analysis. If it's a general utility, suggest it lives elsewhere.>

## Proposed interface

```powershell
# example invocation
.\tools\<name>.ps1 -Foo "bar" -N 100
```

## Inputs / outputs

- **Reads from**: <files / wx commands>
- **Writes to**: <files / stdout>
- **Side effects**: <none / network / etc>

## Cross-platform plan

- [ ] PowerShell (Windows-first)
- [ ] Bash equivalent (`.sh`) — needed if maintainers agree the workflow is *nix-relevant
- [ ] No platform-specific assumptions, OR
- [ ] Documented platform requirements

## Privacy check

- [ ] Will not handle anything beyond what `wx-cli` already exposes
- [ ] Output files are under gitignored paths (`people/`, `projects/`, `topics/`)
- [ ] No telemetry, no network calls beyond `wx-cli`

## Acceptance criteria

- [ ] Documented in `README.md` under "Commands"
- [ ] Mentioned in `CLAUDE.md` if it changes the analysis workflow
- [ ] Passes `no-data-leaked` CI
