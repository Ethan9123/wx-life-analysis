---
name: subtext-reading
description: Read the right-now state of a specific WeChat conversation — is it warm, cooling, or disengaging — and decide the correct next move given who currently holds the ball. Activate when the user asks "is she/he cooling on me?", "what's the subtext of that reply?", "should I ping them again?", "am I being too pushy?", or after a refresh when reviewing what changed. Walks the last 20-50 messages in people/<slug>/chat.md and outputs a 5-line block (state / ball-in-court / last move / key signal / do now) into the "当前状态" section of profile.md. Never hedges — picks exactly one of six states (🔥 hot · 🟢 warm · 🟡 mild cool · 🟠 cooling · 🔴 disengaging · ⚫ gone).
---

# Subtext Reading Skill

When this skill is loaded, you are diagnosing **where this specific conversation is at this specific moment** — orthogonal to who the person is in general (that's the [`mbti-analysis`](../mbti-analysis/SKILL.md) skill).

**Full methodology**: read [`docs/subtext-reading.md`](../../../docs/subtext-reading.md). It defines the 9-signal checklist, the 6 states, the ball-in-court × state action matrix, and the common false positives.

## Quick reference

### The 6 states (pick ONE)

| State | Meaning | Default action |
|---|---|---|
| 🔥 hot | active, fast back-and-forth, energy matched | continue at current cadence |
| 🟢 warm | steady, normal pace, no negative signals | maintain |
| 🟡 mild cool | latency stretched, length shrinking, no hard signal | **hold. do not ping.** |
| 🟠 cooling | 2+ signals from different categories | pull density down, don't try to "fix" |
| 🔴 disengaging | explicit redirect / sticker-only / >48h silence on a clear ball | stop. acknowledge if anything, no new topics |
| ⚫ gone | >7 days silent, no ack on last 2 messages | don't chase. one neutral close max. |

### The 9 signals (find 2+ before calling cooling)

Latency: (1) reply gap spike, (2) conversational stop ·
Length: (3) length collapse, (4) stickerization ·
Content: (5) hard redirect, (6) soft non-answer, (7) topic never gets hook, (8) explicit boundary ·
Meta: (9) **🚨 critique of your style not the topic** — "you sound like a bot" — this one's critical.

### Ball-in-court × state action matrix

| State | Ball in their court | Ball in my court |
|---|---|---|
| 🟡 mild cool | **wait, do not double-ping** | reply normally, no escalation |
| 🟠 cooling | wait minimum 3× their normal gap | reply low-stakes, no big swing |
| 🔴 disengaging | do not ping unprompted | reply minimal, no question, no hook |

**The most common Ethan-style mistake** (per the methodology doc): ball in their court + mild cool → user sends a second "check in" message → converts mild cool into cooling. Call this out explicitly when relevant.

## Output format

Always 5 lines, no prose paragraph:

```
[name]
state: <one of 6 emoji + label>
ball: me / them
last move: <date> · <what happened in one line>
key signal: <which signals matched, e.g. "length collapse + soft non-answer">
do now: <one concrete action, e.g. "hold. no ping. wait 3+ days.">
```

Update the "当前状态" section in `people/<slug>/profile.md` body (not frontmatter — state changes too often).

## Hard rules

1. **Pick one state. No hedging.** "warm-to-mild-cool" defeats the purpose.
2. **2+ signals required to call cooling.** One signal = noise (e.g., 6h reply gap = could be sleeping).
3. **Don't paste `chat.md` content outside the local session.**
4. **For distant relationships** (>1 month no contact), this skill is calibrated wrong — use [`mbti-analysis`](../mbti-analysis/SKILL.md) instead.
