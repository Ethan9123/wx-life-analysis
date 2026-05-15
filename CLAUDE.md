# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Repo identity

This is a **template repo** for analyzing personal WeChat data with `@jackwener/wx-cli` + Claude. The repository itself contains no user data — only documentation, scripts, and templates. Users clone it and fill in their own data locally; their data is gitignored.

If you're being asked about *real* people, *real* chat content, or *real* projects, you are probably in a **user's local clone**, not this template repo. The user's clone has the same structure but with `people/<name>/chat.md` etc. filled in. Treat those files as private and never echo them outside the local session.

## When working in this repo (the template)

Your job is to improve the template — scripts, docs, agent prompts. You will not see any real chat data. If a PR or task description includes real-looking names, push back and ask for placeholders (`张三`, `Acme Corp`).

### Common tasks

- **Add a script to `tools/`**: see "Coding conventions" in `AGENTS.md`. Document it in `README.md`.
- **Improve a template**: edit `people/_template/profile.md` or `projects/_template/notes.md`. Keep placeholders.
- **Update the agent contract**: edit `AGENTS.md` (for Codex/Cursor) or this file (Claude-specific).

### What you must not do

- Don't commit any file under `people/<name>/`, `projects/<name>/`, `topics/<name>/` (except `_template/`).
- Don't add example data using real-looking names. Use `张三` / `Alice`.
- Don't add network calls (no telemetry, no cloud sync).
- Don't fork or reimplement `wx-cli`. Shell out to it.

## When working in a user's local clone

You'll know because `people/<name>/chat.md` and `projects/<name>/notes.md` will exist with real content.

### Session start checklist

1. Read this file (you're doing it).
2. Read the user's local `CLAUDE.local.md` if it exists — that's their private context (real names, family, work projects). It's gitignored.
3. Run `tools/status.ps1` to see what's stale and where the ball is.
4. Read the most relevant `people/<name>/profile.md` or `projects/<name>/notes.md` for the current task.
5. Ask the user what they want to push forward.

### Workflow for analyzing a person

1. Run `tools/refresh.ps1 -Name "<wechat-name>" -Dir "people/<dir>"` to pull latest chat + SNS.
2. Read the new `chat.md` chronologically (most recent first if time-constrained).
3. Update `people/<dir>/profile.md`:
   - bump `last-updated:` to today
   - update `ball-in-court` (`me` / `them`)
   - update `next-action`
   - add any new events to the timeline section
4. **MBTI + trip wire pass** (see [`docs/mbti-analysis.md`](docs/mbti-analysis.md)):
   - Score each of the four axes from chat signals; write to `mbti.type` + `mbti.basis`.
   - Walk the chat for trip wires (reply-latency spikes, length collapse, hard
     redirects). Record `trip-wires` list.
   - Translate to `comms.frequency` / `comms.style` / `comms.do` / `comms.avoid`.
   - Always include a confidence level. Don't fabricate certainty.
5. **Subtext pass** (see [`docs/subtext-reading.md`](docs/subtext-reading.md)):
   - Decide one state for *this moment*: 🔥 hot / 🟢 warm / 🟡 mild cool / 🟠 cooling /
     🔴 disengaging / ⚫ gone. **Pick one — no hedging.**
   - Answer "ball-in-court: me / them" explicitly.
   - Output the 5-line block format (state / ball / last move / key signal / do now).
   - Update `profile.md` body "当前状态" section with this block.
6. If the situation changed materially (new relationship phase, conflict, breakthrough), tell the user explicitly. Don't bury it.

### Workflow for a project

1. Source materials (PDFs, docs) go in `projects/<name>/` (gitignored).
2. Use `tools/extract-pdf.js` for text extraction.
2.5 If work mainly happens in a group chat, run `tools/refresh-group.ps1 -Name "研发群" -Slug "rd-group"` first to populate `topics/<slug>/chat.json` + `members.json`.
2.6 Run `tools/task-extract.ps1 -Person "<task-giver-slug>" -Project "<project-slug>"` for first-pass candidate filtering before full read.
3. Write `projects/<name>/notes.md` with task breakdown by priority (P0/P1/P2/P3).
4. Optionally generate a `task-plan.html` dashboard for visual scanning.
5. Track decisions needed from third parties (boss, family, etc.) in a dedicated section.

### Communication style

Match the user's preference, which they'll usually state. Sensible defaults:

- **Direct**, no hedging. Skip "I'll happily" / "Great question".
- **Action-oriented**. End with "do X next" or a concrete question, not a summary.
- **Add judgment**. Don't just summarize what's in `chat.md` — say what it means and what to do about it.
- **Avoid "echo replies"**. Don't restate the user's input with adjectives ("好充实啊", "好热闹啊"). Add observation, question, or pushback.

### Privacy hard rules

1. Never paste `chat.md` excerpts into any other context (other chats, web searches, issue trackers).
2. Never include real names in code, commits, or PRs even when working locally — use placeholders if asked to publish anything.
3. If the user asks you to commit something with real data, refuse and explain why. Suggest a sanitized alternative.
4. If you spot data leaking into a commit (e.g. real name in a script comment), flag it before pushing.

## Useful commands cheatsheet

```powershell
# Encoding fix (run once per PowerShell session)
$OutputEncoding = [System.Text.Encoding]::UTF8; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; chcp 65001 | Out-Null

# Pull one person's data
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"

# Status overview
.\tools\status.ps1

# Self mirror report (your own chat habits)
.\tools\self-mirror.ps1

# Task candidate extraction (first-pass, see docs/task-extract.md)
.\tools\task-extract.ps1 -Person "<task-giver-slug>" -Project "<project-slug>"

# Topic search
wx search "关键词" -n 500 --json | Out-File topics\<slug>\search.json -Encoding utf8

# PDF extract
node tools\extract-pdf.js "path\to\file.pdf" 1 20 > projects\<name>\extract.txt

# Daemon (if data feels stale)
wx daemon stop; wx new-messages
```

## When something feels wrong

- If `wx.exe` isn't installed: tell the user, link to https://github.com/jackwener/wx-cli.
- If the daemon is acting up: `wx daemon stop` then re-run.
- If PowerShell shows Chinese as garbled: re-run the encoding line above.
- If `wx export` output looks like a `RemoteException`: that's PowerShell mis-tagging stdout. The data is fine. Check `$LASTEXITCODE`.

## Where to look first

| Question | File |
|---|---|
| How do I install? | `README.md` § Quick start |
| What's the file layout? | `README.md` § Directory layout |
| How do I add a tool? | `AGENTS.md` § How to add a new tool |
| What are the hard rules? | `AGENTS.md` § Hard rules |
| How do I run an MBTI + trip-wire pass on a person? | `docs/mbti-analysis.md` |
| How do I read where they are *right now* in a conversation? | `docs/subtext-reading.md` |
| How do I turn a boss's chat dump into a structured TODO list? | `docs/task-extract.md` |
| What's the user's personal context? | `CLAUDE.local.md` (gitignored, only in local clones) |
