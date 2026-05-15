# GitHub Copilot instructions

This file is read by **GitHub Copilot** (in VS Code, JetBrains, GitHub.com Chat, and the Copilot coding agent) when working in this repository.

The actual project rules + agent contract live in **`AGENTS.md`** at the repo root, which Copilot's coding agent also reads (per the [2025-08-28 Copilot changelog](https://github.blog/changelog/2025-08-28-copilot-coding-agent-now-supports-agents-md-custom-instructions/)).

**Treat `AGENTS.md` as the canonical source.** Specifically:

1. Privacy hard rules — never commit user data under `people/<name>/`, `projects/<name>/`, `topics/<name>/` (only `_template/` and `README.md` are allowed there). CI enforces. See `AGENTS.md` § Hard rules.
2. Placeholders only — use `张三` / `Alice` / `Acme Corp` in any code, docs, commits, issues, or PRs. No real names.
3. Don't reimplement `wx-cli` features — always shell out to `wx ...`.
4. PowerShell scripts target 5.1+; bash scripts POSIX-compatible; Node scripts target 18+.

For Claude-specific guidance, see `CLAUDE.md`. For per-task skills with activation triggers, see `.claude/skills/<name>/SKILL.md`. For Vercel Skills CLI install, see root `SKILL.md`.

When in doubt — read `AGENTS.md` § Hard rules and § PR review checklist before generating any output.
