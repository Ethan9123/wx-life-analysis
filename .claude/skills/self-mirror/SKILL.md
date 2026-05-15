---
name: self-mirror
description: Quantify the user's own WeChat chat habits across all tracked contacts — echo-reply count, opening-line repertoire, length distribution, time-of-day pattern, connector word frequency, emoji/sticker usage. Activate when the user asks "how am I actually talking on WeChat?", "do I sound like a bot?", "show me my豆包式聊天 frequency", "how do I open conversations?", or before a hard relationship conversation where the user wants to see their own pattern. The single most actionable target is echo-reply detection ("X 看起来挺 X 啊" pattern) — the canonical "你跟豆包聊天" failure mode. Wraps tools/self-mirror.ps1 which auto-detects the user's own sender label and produces a 7-section Markdown report.
---

# Self-Mirror Skill

When this skill is loaded, you are running a **quantitative analysis of the user's own outgoing messages** — NOT the contacts' messages. The point is to surface uncomfortable truths about how the user actually communicates.

**Tool**: `tools/self-mirror.ps1` does the heavy lifting. **You** (the agent) interpret the report.

## How to invoke

```powershell
.\tools\self-mirror.ps1                                # generate SELF-MIRROR.md (gitignored)
.\tools\self-mirror.ps1 -Person alice                  # narrow to one contact
.\tools\self-mirror.ps1 -Out reports/SELF-MIRROR.md    # custom output path
```

The tool reads `people/*/chat.md`, auto-detects the user's sender label, and writes `SELF-MIRROR.md` at repo root (gitignored).

## What the report contains (7 sections)

1. **Echo-reply offenses** — sentences matching "<X> 看起来挺 <X>" patterns where user restates the contact's prior message + softener. Counts + top 10 examples with date + recipient.
2. **Top 10 opening lines** — most frequent thread-starters (new thread = >2h gap from prior in that chat).
3. **Length distribution** — user-outgoing message char-length histogram, per-recipient.
4. **Question vs statement ratio** — % ending in `?` / `？`, per-recipient.
5. **Time-of-day pattern** — hour-of-day histogram, with do-not-disturb-window violations flagged (per recipient's `comms.frequency`).
6. **Connector/softener word frequency** — `嘛 / 吧 / 啊 / 呢 / 哦 / 嗯`, per-recipient. Flagged if >5% of words for a recipient.
7. **Emoji/sticker proxy count** — emoji chars + bracketed sticker descriptions, per-recipient.

## How to read the output

The killer insight is usually **section 1 (echo-reply)** — if the count is high, that's the user's豆包式 problem made concrete with dates and recipients.

Other patterns worth surfacing in your interpretation:
- **Length asymmetry**: user writes 300+ chars to a contact who replies in 10 chars → user is over-explaining
- **Time-of-day violations**: user messages a 22-点-不发 contact after 22:00 → wrong-mode-of-respect
- **Opening line repertoire of 1-2**: user has no opener variety → predictable, easy to ignore

## Hard rules

1. **`SELF-MIRROR.md` is gitignored** — it contains real names + real message excerpts. Never commit.
2. **Show the data, don't moralize.** Counts + examples + dates. The user decides what to change.
3. **Don't suggest specific replacement phrasings.** The user's voice should stay the user's voice. If they ask for replacement, defer to [`subtext-reading`](../subtext-reading/SKILL.md) per-contact context.
4. **Re-run after a behavioral correction attempt** (e.g., 2 weeks after the user says "I'll stop echo-replying"). Compare before/after counts.
