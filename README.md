# wx-life-analysis

> A workspace template for analyzing your own WeChat data with Claude / Codex / any code-agent.

Built on top of [`@jackwener/wx-cli`](https://github.com/jackwener/wx-cli) — `wx-cli` decrypts and queries your local WeChat database; **this repo** is the opinionated directory layout, scripts, and agent prompts that turn raw chat data into actionable analysis (relationships, projects, decisions).

**License**: Apache-2.0 · **Platforms**: Windows / macOS / Linux · **Agents**: Claude Code, Codex, Cursor

---

## What this is (and isn't)

✅ **A template repo** — fork or clone, fill in your own data locally, never push the data back.
✅ **An agent contract** — `AGENTS.md` + `CLAUDE.md` tell any code-agent how to behave in this workspace.
✅ **A small toolbox** — PowerShell + Node scripts that wrap `wx-cli` for common workflows.

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

### 2. Clone this template

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

```powershell
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"
```

This wraps the `wx export` + `wx sns-feed` + `wx stats` trio into one command and writes to `people/zhangsan/`. The directory is gitignored.

---

## Directory layout

```
wx-life-analysis/
├── README.md              ← you are here
├── AGENTS.md              ← contract for Codex / code-agents
├── CLAUDE.md              ← contract for Claude Code
├── LICENSE                ← Apache-2.0
├── .gitignore             ← defensively blocks real data
├── tools/
│   ├── extract-pdf.js     ← PDF text extraction (Node + pdf-parse)
│   ├── refresh.ps1        ← pull latest chat/SNS for one contact
│   └── status.ps1         ← one-line status per active contact
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

```powershell
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan" -N 500
```

Equivalent to:
```powershell
wx export "张三" -n 500 --format markdown -o people\zhangsan\chat.md
wx sns-feed --user "张三" -n 50 --json | Out-File people\zhangsan\sns.json -Encoding utf8
wx stats "张三" > people\zhangsan\stats.txt
```

### Search a topic across all chats

```powershell
wx search "桌游" -n 500 --json | Out-File topics\boardgame\search.json -Encoding utf8
```

### Extract text from a PDF (for project research)

```powershell
node tools\extract-pdf.js "C:\path\to\file.pdf" 1 20 > projects\my-project\extract-p1-20.txt
```

### One-line status across all active contacts

```powershell
.\tools\status.ps1
```

Reads each `people/*/profile.md`, prints `name | last-updated | ball-in-court | next-action`.

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

For project work (`projects/<name>/`):
1. Drop the source PDFs / docs into the project folder (gitignored)
2. Extract text with `tools/extract-pdf.js`
3. Agent reads extracts + writes `notes.md` with task breakdown
4. Optionally generate `task-plan.html` for a visual dashboard

The agent files (`AGENTS.md`, `CLAUDE.md`) describe these flows in machine-readable detail.

---

## Privacy & legal

- **All data stays on your machine.** This repo's `.gitignore` actively blocks `people/*`, `projects/*`, `topics/*`, `*.db`, `*.pdf`, `*.docx`, etc. from being committed.
- **Decrypt only your own WeChat data.** Same rule as `wx-cli`. Read [`wx-cli`'s legal notice](https://github.com/jackwener/wx-cli#legal-notice).
- **Don't share or paste the contents of `people/*/chat.md`** into other LLM chats, issue trackers, or messages. Treat it like your password store.
- **CLAUDE.md / AGENTS.md restate this** so any agent reading them inherits the rule.

If you accidentally commit data, follow GitHub's [removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) guide and rotate any tokens.

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
