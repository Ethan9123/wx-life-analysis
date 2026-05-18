---
name: wx-life-analysis
description: Personal WeChat data analysis workspace template. Use when the user wants to (a) analyze chat history with specific contacts via MBTI inference + trip-wire detection + per-person comms strategy, (b) read real-time subtext signals in an active conversation (cooling, disengaging, meta-critique), (c) extract structured TODO lists from a boss's chat dump + attached files, or (d) quantify the user's own chat habits (echo-reply detection, opening-line repertoire, length distribution). Built on top of @jackwener/wx-cli — wx-cli does the decryption + querying, this skill provides the directory layout, agent contract, methodology docs, and a small PowerShell + Bash + Node toolbox. Strictly local — no data leaves the user's machine, CI enforces no-data-leak rules. Requires wx-cli installed separately (npm install -g @jackwener/wx-cli).
license: Apache-2.0
compatibility: Claude Code, Codex, Cursor, Aider, OpenCode
metadata:
  homepage: https://github.com/Ethan9123/wx-life-analysis
  depends_on: "@jackwener/wx-cli"
---

# wx-life-analysis

A workspace template for analyzing your own decrypted WeChat data with an AI agent. Companion to [`@jackwener/wx-cli`](https://github.com/jackwener/wx-cli) — `wx-cli` decrypts and queries; this skill provides the structure, methodology, and tools that turn raw chat data into actionable per-person + per-project analysis.

## When to activate this skill

The user is asking the agent to:

- **Analyze a specific contact** — what kind of person they are (MBTI), what topics shut them down (trip-wires), how often / in what style to message them (comms strategy)
- **Read the room right now** — is this conversation warm / cooling / disengaging, and what's the right next move given who currently holds the ball
- **Extract a TODO list** from a work-chat dump + attached files (boss / client / family stakeholder)
- **Self-mirror** — quantify the user's own chat patterns to surface uncomfortable truths (echo-reply, opening repertoire, time-of-day, length-by-recipient)
- **Set up a private workspace** for ongoing WeChat-data analysis with Claude / Codex / Cursor

This skill does NOT help with: drafting messages on behalf of the user, posting to chats, fake-mimicking other people's tone, or any "AI participates in the user's relationships" pattern. See `AGENTS.md` § "Out of scope" for the full no-go list.

## Bootstrap

```bash
# 1. Install wx-cli (does decryption + querying)
npm install -g @jackwener/wx-cli

# 2. Initialize wx-cli once (per-platform setup at https://github.com/jackwener/wx-cli)
sudo wx init        # macOS / Linux
wx init             # Windows (as Administrator)
wx sessions         # verify

# 3. Clone this template
git clone https://github.com/Ethan9123/wx-life-analysis.git my-wx-workspace
cd my-wx-workspace

# 4. Pull a contact's data
./tools/refresh.sh --name "张三" --dir "people/zhangsan"          # macOS / Linux
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"            # Windows
./tools/refresh-group.sh --name "Acme Team Chat" --slug "acme-team"  # group chat to topics/<slug>/
.\tools\refresh-group.ps1 -Name "研发群" -Slug "rd-group"              # Windows equivalent
```

The agent then reads `AGENTS.md` + `CLAUDE.md` and knows the workflow.

## Workflow 1 — per-person analysis (MBTI + trip-wires + comms)

Methodology: [`docs/mbti-analysis.md`](docs/mbti-analysis.md)

1. Pull data: `refresh.ps1` (or `.sh`) — produces both `chat.md` AND `sns.json`. Optionally run `tools/warmth.ps1` (or `.sh`) for the SNS-engagement-on-your-posts warmth gauge.
2. Read **both** `people/<slug>/chat.md` (private, ~70% of signal) AND `people/<slug>/sns.json` (public self-presentation, ~30% of signal, often flips a borderline axis)
3. Score each of 4 axes (E/I, S/N, T/F, J/P) using signals from chat AND SNS combined (latency, voice/text ratio, abstract vs concrete language, planning style, post frequency, caption tone, audience scope, visible gaps)
4. Walk the chat for trip-wires (reply-latency spikes, length collapse, hard redirects, meta-critique). Cross-reference with SNS for safe / unsafe topic territory and persona splits.
5. Update `people/<slug>/profile.md` YAML frontmatter (and the `## 朋友圈观察` body section):
   ```yaml
   mbti:
     type: ENFP                       # or "INFP/ENFP" if borderline, or "unclear"
     confidence: medium               # low / medium / high
     basis: |
       <2-4 sentences of specific signals>
   trip-wires:
     - topic: <short label>
       pattern: <what you did → how they reacted>
       repair: <how to avoid or recover>
   comms:
     frequency: <e.g. "1 ping / 2 days when ball is mine">
     style: <e.g. "short, no metaphors, voice notes OK">
     do: [<topic-1>, <topic-2>]
     avoid: [<thing-1>, <thing-2>]
   ```

## Workflow 2 — right-now subtext read

Methodology: [`docs/subtext-reading.md`](docs/subtext-reading.md)

For every active conversation, the agent picks ONE of 6 states:
🔥 hot · 🟢 warm · 🟡 mild cool · 🟠 cooling · 🔴 disengaging · ⚫ gone

Output is a 5-line block per person, not prose:
```
[name]
state: 🟡 mild cool
ball: them
last move: <date> · <what happened>
key signal: <which signals matched, e.g. length collapse + soft non-answer>
do now: <one concrete action, e.g. "hold. no ping. wait 3+ days.">
```

## Workflow 3 — task extraction from a work chat

Methodology: [`docs/task-extract.md`](docs/task-extract.md)

1. First-pass filter: `.\tools\task-extract.ps1 -Person <task-giver-slug> -Project <slug>`
2. Agent reads the candidate file + classifies into 6 buckets (Direct work / Decision needed / Data needed / Already-promised / Implicit / Closed)
3. Score each task on 3 axes (stakeholder × urgency × reversibility) for P0/P1/P2
4. Update `projects/<slug>/notes.md` — **never wholesale rewrite, always diff**
5. Hard rule: **quote, don't paraphrase**. Paraphrasing introduces drift.

## Workflow 4 — self-mirror

Tool: `tools/self-mirror.ps1` → outputs `SELF-MIRROR.md` at repo root (gitignored).

Scans `people/*/chat.md`, auto-detects user's own sender label, produces a 7-section report:
echo-reply offenses · opening-line top 10 · length distribution · question vs statement ratio · time-of-day pattern · connector/softener word frequency · emoji/sticker count. Per-recipient breakdowns throughout.

Single most actionable target: **echo-reply detection** ("X 看起来挺 X 啊" pattern). The 5/2 "我是在跟豆包聊天吗" call-out is the canonical failure mode this catches.

## Repository structure

```
.
├── README.md                Human-facing intro
├── AGENTS.md                Codex / Cursor / Aider contract
├── CLAUDE.md                Claude Code workflow guide
├── SKILL.md                 ← this file (Vercel Skills entry)
├── LICENSE                  Apache-2.0
├── .gitignore               Blocks user data
├── .github/workflows/
│   └── no-data-leaked.yml   CI: blocks committing real data
├── docs/
│   ├── mbti-analysis.md
│   ├── subtext-reading.md
│   ├── task-extract.md
│   └── voice-transcription.md
├── tools/
│   ├── extract-pdf.js           PDF text extraction (Node + pdf-parse)
│   ├── contacts.ps1 / .sh       fuzzy contact lookup (verify exact name before refresh)
│   ├── refresh.ps1 / .sh        pull chat + SNS + stats for one contact (incremental)
│   ├── refresh-group.ps1 / .sh  pull a group chat into topics/<slug>/
│   ├── attachments.ps1 / .sh    list / extract chat attachments (PDFs, images, files)
│   ├── voice-transcribe.ps1 / .sh  silk → wav → whisper pipeline for voice (local-first)
│   ├── status.ps1 / .sh         one-line status per contact
│   ├── digest.ps1               unread incremental snapshot since last session
│   ├── warmth.ps1 / .sh         SNS engagement on your posts (warmth gauge)
│   ├── self-mirror.ps1          quantify own chat habits
│   └── task-extract.ps1         first-pass TODO candidate extractor
├── people/_template/        profile.md scaffold (with full YAML schema)
├── projects/_template/      notes.md scaffold
└── topics/                  cross-chat keyword search dumps (gitignored)
```

## Hard rules the agent must follow

1. **Never commit user data.** `people/<name>/`, `projects/<name>/`, `topics/<name>/` are all gitignored. CI (`.github/workflows/no-data-leaked.yml`) enforces.
2. **Never echo `chat.md` content** into any context outside the local session — other chats, web searches, issue trackers, PR descriptions. Treat as password-grade.
3. **Use placeholders** in any docs, commits, issues, or PRs: `张三` / `李四` / `Alice` / `Bob` / `Acme Corp`.
4. **Don't reimplement `wx-cli`.** Always shell out to `wx ...`.
5. **Match the user's communication style** if stated. Sensible defaults: direct, action-oriented, no hedging, avoid echo-reply patterns when responding to the user themselves.
6. **For Codex tasks specifically**: use the `codex-ready` label on issues you scope for Codex; the PR review checklist lives in `AGENTS.md` and `.github/pull_request_template.md`.

## Dependencies

| Dependency | Why | Install |
|---|---|---|
| `@jackwener/wx-cli` | Decryption + querying (does all the heavy lifting) | `npm install -g @jackwener/wx-cli` |
| `pdf-parse` (optional) | For `tools/extract-pdf.js` | `npm install -g pdf-parse` |
| `gh` (optional) | For PR / issue automation | https://cli.github.com |
| Node 18+, PowerShell 5.1+ or Bash | Scripts | per-platform |

## Privacy & legal

Decrypt only your own WeChat data. Same rule as `wx-cli`. This repository is intentionally structured to make data leakage difficult: gitignore + CI + agent rules + repeated docs. If you accidentally commit data, follow GitHub's [removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) guide and rotate any tokens.

## Acknowledgments

- [`jackwener/wx-cli`](https://github.com/jackwener/wx-cli) — the underlying CLI this skill depends on
- [Vercel Skills CLI](https://github.com/vercel-labs/skills) — the skill format this file follows
