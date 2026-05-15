# AGENTS.md

This file is the contract for any autonomous code-agent (Codex, Claude Code, Cursor, Aider, etc.) working in this repository.

## What this repo is

A template for analyzing personal WeChat data using `@jackwener/wx-cli` + an AI agent. The repo itself contains **only**:

- documentation (`README.md`, `AGENTS.md`, `CLAUDE.md`)
- scripts (`tools/`)
- empty templates (`people/_template/`, `projects/_template/`)
- license + gitignore

End users clone this repo, run scripts locally to pull their own WeChat data into `people/<name>/` and `projects/<name>/`, and then have an agent help them analyze it. **That user data never enters the repo.** Our `.gitignore` enforces this.

## Hard rules

1. **Do not commit user data.** `people/<name>/`, `projects/<name>/`, `topics/<name>/` are all gitignored. If a PR adds files there (outside `_template/`), reject it.
2. **No real names, real chat content, or real contact info** in:
   - source code
   - docs
   - tests
   - issue/PR descriptions
   - commit messages
3. **Use placeholders consistently**: `张三` / `李四` / `Alice` / `Bob` / `Acme Corp`.
4. **Tools must be cross-platform-aware**. If you add a `.ps1`, consider whether a `.sh` equivalent makes sense. Don't break Windows when adding *nix tooling.
5. **`wx-cli` is a dependency, not a fork**. Don't reimplement its commands. Always shell out to `wx ...`.

## Repository structure

```
.
├── README.md           Human-facing intro
├── AGENTS.md           This file (Codex et al)
├── CLAUDE.md           Claude Code specific guidance
├── LICENSE             Apache-2.0
├── .gitignore          Blocks user data
├── docs/               Long-form methodology docs
│   ├── mbti-analysis.md
│   ├── subtext-reading.md
│   └── task-extract.md
├── tools/              Scripts (PowerShell + Bash + Node)
│   ├── extract-pdf.js
│   ├── refresh.ps1
│   ├── refresh.sh
│   ├── status.ps1
│   └── status.sh
├── people/_template/   Profile scaffold
├── projects/_template/ Project notes scaffold
└── .github/workflows/  CI (lint, no-data-leaked checks)
```

## Coding conventions

### PowerShell scripts (`tools/*.ps1`)

- Target **PowerShell 5.1+** (Windows default). Avoid `pwsh`-only features unless guarded.
- Set UTF-8 encoding at the top of every script:
  ```powershell
  $OutputEncoding = [System.Text.Encoding]::UTF8
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  chcp 65001 | Out-Null
  ```
- Use `[CmdletBinding()]` + `param()` blocks with typed parameters and `Mandatory` where appropriate.
- Validate inputs (`Test-Path`, `if (-not $Name) { throw ... }`).
- Wrap `wx.exe` calls in try/catch — PowerShell sometimes mis-categorizes its stdout as `RemoteException`. That's noise, not a real failure. Check `$LASTEXITCODE`, not just `$?`.

### Node scripts (`tools/*.js`)

- Target **Node 18+**.
- Use plain CommonJS (`require`) — no build step, no TypeScript, no bundler. These are throwaway utility scripts.
- Resolve dependencies from the **global** `npm root -g` (so users don't need a local `node_modules/`).
- Read args from `process.argv`. No fancy CLI framework.
- Print to stdout for piping. Errors to stderr with a clear prefix.

### Markdown

- Headings in title case for English, no extra formatting for Chinese.
- Use fenced code blocks with language tags.
- Keep line length flexible — these are read by humans and LLMs, not diffed by code review tools.

## How to add a new tool

1. Decide PowerShell or Node based on:
   - PowerShell: orchestrating `wx-cli` calls, file system operations, Windows-first workflows
   - Node: text/PDF/JSON parsing, anything needing npm packages
2. Add the script to `tools/`.
3. Document it in `README.md` under "Commands".
4. Update `CLAUDE.md` if the new tool changes the analysis workflow.
5. **Test it locally on dummy data**. Never use real user data in tests.

## How to add a new template

`people/_template/profile.md` and `projects/_template/notes.md` are the only templates today. When adding:

1. Use placeholder names (`张三`, `Acme Project`).
2. Mark fillable slots with `<...>` or `TODO:` comments.
3. Include a `last-updated:` field so staleness is visible.
4. Use YAML frontmatter with this **minimum** fixed schema (read by `tools/status.ps1`):
   ```yaml
   ---
   last-updated: 2026-01-01
   ball-in-court: Alice
   next-action: <one concrete next step>
   tags: [tag-1, tag-2]
   ---
   ```
5. Templates MAY extend the frontmatter with type-specific fields. Current extensions:
   - `people/_template/profile.md` adds `mbti`, `trip-wires`, `comms`. Methodology
     is documented in `docs/mbti-analysis.md`. Any new field must be additive — never
     break the minimum schema above, or `status.ps1` parsing fails.

## PR review checklist (for agents reviewing each other's work)

- [ ] No real names, emails, phone numbers, WeChat IDs, or chat excerpts anywhere
- [ ] No files added under `people/*/`, `projects/*/`, `topics/*/` outside `_template/`
- [ ] Scripts have UTF-8 setup at top
- [ ] Scripts validate inputs and handle missing `wx.exe`
- [ ] Docs updated if user-visible behavior changed
- [ ] `.gitignore` still blocks the file types it should

## Out of scope (don't do these)

- Don't reimplement `wx-cli` features (decryption, querying, daemon). Defer to it.
- Don't add a build system, bundler, or framework. Keep it scripts-only.
- Don't add telemetry, analytics, or any network calls beyond what `wx-cli` already does.
- Don't add a web UI. HTML files generated for personal use (like `task-plan.html`) are static and gitignored.
- Don't add cloud sync, backup, or "share" features. Local-only is the point.

## When you're unsure

Open an issue describing the proposed change before writing code. Reference this file. Tag the maintainer.
