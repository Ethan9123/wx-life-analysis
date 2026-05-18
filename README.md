# wx-life-analysis

**English** (you are here) · [中文](README.zh-CN.md)

> A workspace template for analyzing your own WeChat data with Claude / Codex / any code-agent.

Built on top of [`@jackwener/wx-cli`](https://github.com/jackwener/wx-cli) — `wx-cli` decrypts and queries your local WeChat database; **this repo** is the opinionated directory layout, scripts, and agent prompts that turn raw chat data into actionable analysis (relationships, projects, decisions).

**License**: Apache-2.0 · **Platforms**: Windows / macOS / Linux · **Agents**: Claude Code, Codex, Cursor

---

## What this is (and isn't)

✅ **A template repo** — fork or clone, fill in your own data locally, never push the data back.
✅ **An agent contract** — `AGENTS.md` + `CLAUDE.md` tell any code-agent how to behave in this workspace.
✅ **A small toolbox** — PowerShell, Bash + Node scripts that wrap `wx-cli` for common workflows.

❌ Not a fork of `wx-cli`. You still need `wx-cli` installed separately.
❌ Not a hosted service. Everything runs locally on your machine.
❌ Not a place to commit real chat data. The `.gitignore` actively blocks that.

---

## Quick start

### 1. Install prerequisites

```powershell
# wx-cli (the underlying decrypt + query CLI)
npm install -g @jackwener/wx-cli

# Initialize wx-cli once (extracts WeChat key into ~/.wx-cli/)
sudo wx init        # macOS / Linux
wx init             # Windows (as Administrator)

# Verify
wx sessions
```

See [`jackwener/wx-cli`](https://github.com/jackwener/wx-cli) for platform-specific setup.

### 2. Get the template

**Option A — install as a Vercel Skill (one-line, recommended for agents)**

```bash
npx skills add Ethan9123/wx-life-analysis
```

This makes the methodology + workflow contracts available to Claude Code / Codex / Cursor / Aider as an installed skill. See `SKILL.md` for what activates it.

**Option B — clone the repo (if you want the scripts + templates as a workspace)**

```powershell
git clone https://github.com/Ethan9123/wx-life-analysis.git my-wx-workspace
cd my-wx-workspace
```

### 3. Wire up an agent

Open the workspace in Claude Code, Codex, or Cursor. The agent reads `AGENTS.md` / `CLAUDE.md` and immediately understands:

- where to drop new person analyses (`people/<name>/`)
- where to drop project work (`projects/<name>/`)
- which scripts to run (`tools/`)
- what **never** to commit (everything in `.gitignore`)

### 4. Pull data for a contact

**Windows**

```powershell
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"
```

**macOS / Linux**

```bash
chmod +x tools/refresh.sh
./tools/refresh.sh --name "张三" --dir "people/zhangsan"
```

This wraps the `wx export` + `wx sns-feed` + `wx stats` trio into one command and writes to `people/zhangsan/`. The directory is gitignored.

---

## Directory layout

```
wx-life-analysis/
├── README.md              ← you are here
├── AGENTS.md              ← contract for Codex / Cursor / Aider / Copilot agent
├── CLAUDE.md              ← contract for Claude Code (always-on)
├── SKILL.md               ← Vercel Skills entry (`npx skills add Ethan9123/wx-life-analysis`)
├── LICENSE                ← Apache-2.0
├── .gitignore             ← defensively blocks real data
├── .gitleaks.toml         ← custom PII regex rules (China mobile / wxid / chinese-chat-block)
├── .claude/skills/        ← project-scoped Claude Code skills (load on description match)
│   ├── mbti-analysis/SKILL.md
│   ├── subtext-reading/SKILL.md
│   ├── task-extract/SKILL.md
│   └── self-mirror/SKILL.md
├── .github/
│   ├── workflows/no-data-leaked.yml   ← CI: gitleaks-action + path/extension blocks
│   └── copilot-instructions.md        ← GitHub Copilot entry → AGENTS.md
├── docs/
│   ├── mbti-analysis.md   ← per-person MBTI + trip-wire methodology
│   ├── subtext-reading.md ← 9-signal / 6-state conversation-now framework
│   └── task-extract.md    ← speech-act + 3-axis priority for boss chat dumps
├── tools/
│   ├── extract-pdf.js     ← PDF text extraction (Node + pdf-parse)
│   ├── refresh.ps1        ← pull latest chat/SNS for one contact (Windows)
│   ├── refresh.sh          ← same, for macOS / Linux
│   ├── status.ps1          ← one-line status per active contact (Windows)
│   └── status.sh           ← same, for macOS / Linux
├── people/
│   ├── _template/         ← profile.md scaffold (committed)
│   └── <name>/            ← your data (gitignored)
│       ├── chat.md
│       ├── sns.json
│       └── profile.md
├── projects/
│   ├── _template/         ← notes.md scaffold (committed)
│   └── <name>/            ← your data (gitignored)
│       ├── notes.md
│       └── task-plan.html
└── topics/
    └── <topic>/search.json   ← gitignored
```

`_template/` directories are the only things under `people/`, `projects/`, `topics/` that get committed. Everything else is data.

---

## Commands

All paths assume you're at the repo root.

### Pull a contact's latest data

**Windows (PowerShell)**

```powershell
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan" -N 500
```

**macOS / Linux (bash)**

```bash
./tools/refresh.sh --name "张三" --dir "people/zhangsan" --n 500
```

Equivalent to:
```powershell
wx export "张三" -n 500 --format markdown -o people\zhangsan\chat.md
wx sns-feed --user "张三" -n 50 --json | Out-File people\zhangsan\sns.json -Encoding utf8
wx stats "张三" > people\zhangsan\stats.txt
```

### Pull a group chat into topics/

**Windows (PowerShell)**

```powershell
.\tools\refresh-group.ps1 -Name "研发群" -Slug "rd-group"
.\tools\refresh-group.ps1 -Name "Acme Team Chat" -Slug "acme-team" -SinceDays 30
.\tools\refresh-group.ps1 -Name "AI讨论" -Slug "ai-discuss" -SinceDate "2026-04-01"
```

**macOS / Linux (bash)**

```bash
./tools/refresh-group.sh --name "研发群" --slug "rd-group"
./tools/refresh-group.sh --name "Acme Team Chat" --slug "acme-team" --since-days 30
./tools/refresh-group.sh --name "AI讨论" --slug "ai-discuss" --since-date "2026-04-01"
```

Writes to `topics/<slug>/members.json`, `topics/<slug>/chat.<ext>`, and `topics/<slug>/.last-sync`.

### Search a topic across all chats

```powershell
wx search "桌游" -n 500 --json | Out-File topics\boardgame\search.json -Encoding utf8
```

### Extract text from a PDF (for project research)

```powershell
node tools\extract-pdf.js "C:\path\to\file.pdf" 1 20 > projects\my-project\extract-p1-20.txt
```

### Generate self-mirror report

```powershell
.\tools\self-mirror.ps1
```

Optional:

```powershell
.\tools\self-mirror.ps1 -Person "alice" -Out "SELF-MIRROR.md"
```

Scans `people/*/chat.md` and outputs a 7-section Markdown report for your own messaging habits.

### What Changed Since Last Session (Digest)

```powershell
.\tools\digest.ps1
.\tools\digest.ps1 -Write
.\tools\digest.ps1 -Since "2026-05-10"
```

Runs `wx new-messages --json`, groups unread incremental messages by contact, and prints a compact 5-column digest (`名字 / 消息数 / 最后消息时间 / 前 80 字预览 / 球在你?`).

`-Write` also outputs `DIGEST.md` at repo root (gitignored).

### Warmth gauge (who's engaging with your SNS posts)

**Windows (PowerShell)**

```powershell
.\tools\warmth.ps1
.\tools\warmth.ps1 -IncludeRead -N 300
```

**macOS / Linux (bash)**

```bash
./tools/warmth.sh
./tools/warmth.sh --include-read --n 300 --format json | jq '.[] | select(.total > 5)'
```

Wraps `wx sns-notifications`. Outputs a sender-grouped table (total / likes / comments / latest engagement). Used by `docs/mbti-analysis.md` § Interaction signals as a per-contact warmth gauge.

### One-line status across all active contacts

**Windows (PowerShell)**

```powershell
.\tools\status.ps1
```

**macOS / Linux (bash)**

```bash
./tools/status.sh
```

Reads each `people/*/profile.md`, prints `name | last-updated | ball-in-court | next-action`.

`profile.md` / `notes.md` now use YAML frontmatter:

```yaml
---
last-updated: 2026-01-01
ball-in-court: Alice
next-action: <one concrete next step>
tags: [tag-1, tag-2]
---
```


### First-pass task candidate extraction (project workflow)

```powershell
.\tools\task-extract.ps1 -Person zhangsan -Project acme-launch
.\tools\task-extract.ps1 -Person zhangsan -Since "2026-05-01"
.\tools\task-extract.ps1 -Person zhangsan -Project acme-launch -Out projects/acme-launch/task-candidates.md
```

Generates a markdown candidate list from `people/<person>/chat.md` (and optional project/topic context) using pattern matching only. It is a first pass and does **not** do LLM classification or write `notes.md`. Methodology: [`docs/task-extract.md`](docs/task-extract.md).

### Daemon management (delegated to wx-cli)

```powershell
wx daemon status
wx daemon stop
wx new-messages
```

---

## Workflow with Claude / Codex

The intended loop:

1. **You**: run `refresh.ps1` to pull a contact's latest chat
2. **Agent**: reads `chat.md`, updates `profile.md` (using the `_template`), suggests next action
3. **You**: act on it (send a message, schedule something, draft a doc)
4. **Repeat** weekly or after key events

### Per-person analysis: MBTI + trip wires + comms strategy

When you want a deeper read on someone — what type they are, what topics shut them
down, how often / in what style to message them — point the agent at
[`docs/mbti-analysis.md`](docs/mbti-analysis.md). It's a 4-axis scoring framework
that reads **two sources together**:

- `people/<slug>/chat.md` — private 1:1 history (~70% of signal: how they talk *to you*)
- `people/<slug>/sns.json` — Moments / SNS feed (~30% of signal: how they want to be *seen by their broader circle*)

Both are produced by `tools/refresh.ps1` (gitignored). Cross-reading them surfaces:

- **MBTI inference** with explicit confidence level + chat- and SNS-derived signals
- **Persona splits** — if their SNS shows a polished extrovert but chat shows reserved/tired, that's important
- **Trip wires (雷点)** — observed patterns where they go quiet, redirect, or push back
- **Comms strategy** — frequency, style, do-list, avoid-list
- **SNS observations** — post frequency, dominant topics, gaps (3+ month silent stretches often mark life events), interaction patterns with your own posts

The output lives in `people/<name>/profile.md` (YAML frontmatter + body section).

If the contact wants to know their own type, share
[types.learntocode.com.tw](https://types.learntocode.com.tw/) — a self-test is more
reliable than inferring from chat + SNS.

### Reading the room: subtext detection

MBTI tells you *who* they are. Subtext tells you *where this conversation is right
now*. [`docs/subtext-reading.md`](docs/subtext-reading.md) gives the agent a
9-signal checklist (reply-gap spike, length collapse, hard redirect, stickerization,
explicit boundary, the meta-critique signal, etc) and a 6-state classifier
(🔥 hot → 🟢 warm → 🟡 mild cool → 🟠 cooling → 🔴 disengaging → ⚫ gone), plus the
correct response for each state given who currently holds the ball.

The output is a 5-line block per person, designed to be read in <10 seconds at
session start — no hedging, no prose summary.


For project work (`projects/<name>/`):
1. Drop the source PDFs / docs into the project folder (gitignored)
2. Extract text with `tools/extract-pdf.js`
3. Agent reads extracts + writes `notes.md` with task breakdown — methodology in
   [`docs/task-extract.md`](docs/task-extract.md) (speech-act categories, 3-axis
   priority scoring, "quote-don't-paraphrase" rule, etc)
4. Optionally generate `task-plan.html` for a visual dashboard

The agent files (`AGENTS.md`, `CLAUDE.md`) describe these flows in machine-readable detail.

---

## Privacy & legal

- **All data stays on your machine.** This repo's `.gitignore` actively blocks `people/*`, `projects/*`, `topics/*`, `*.db`, `*.pdf`, `*.docx`, etc. from being committed.
- **Decrypt only your own WeChat data.** Same rule as `wx-cli`. Read [`wx-cli`'s legal notice](https://github.com/jackwener/wx-cli#legal-notice).
- **Don't share or paste the contents of `people/*/chat.md`** into other LLM chats, issue trackers, or messages. Treat it like your password store.
- **CLAUDE.md / AGENTS.md restate this** so any agent reading them inherits the rule.

If you accidentally commit data, follow GitHub's [removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) guide and rotate any tokens.

### Personal `.gitleaks.local.toml`

Each fork can keep a private `.gitleaks.local.toml` with additional personal patterns
(real names, employer domains, custom IDs, etc.). That file is gitignored by default.

To combine the shared baseline and your private rules locally:

```bash
gitleaks detect --config .gitleaks.toml --config .gitleaks.local.toml
```

If you want pre-commit style local protection, you can opt in to `gitleaks protect` on
your machine.

---

## Acknowledgments

- [`jackwener/wx-cli`](https://github.com/jackwener/wx-cli) — does all the heavy lifting (decryption, querying, daemon). This repo is a thin agent-friendly wrapper around its outputs.
- Workflow originally developed with [Claude Code](https://www.anthropic.com/claude-code).

---

## Contributing

Issues and PRs welcome — especially for:
- New `tools/*` scripts (e.g. group-chat summarizer, year-in-review generator)
- Better `_template/` scaffolds
- macOS / Linux equivalents of the PowerShell scripts (`tools/*.sh`)
- Agent prompt improvements (`AGENTS.md`, `CLAUDE.md`)

**Never include real chat data, names, or contact info in issues or PRs.** Use placeholders like `张三` / `Alice`.
