# Subtext reading: detecting "they're cooling / disengaging / had enough"

> Companion to [`mbti-analysis.md`](mbti-analysis.md). MBTI tells you *who* they are
> in general. Subtext-reading tells you *where they are right now in this conversation*
> — warm, neutral, cooling, gone — and what to do about it before you make it worse.

When an agent (Claude / Codex / etc) reads the latest 20-50 messages in
`people/<name>/chat.md`, it should run this checklist and report a state, not just
summarize content.

---

## The states

| State | Meaning | Default action |
|---|---|---|
| **🔥 Hot** | Active engagement, fast back-and-forth, energy matched | Continue at current cadence; don't break the rhythm |
| **🟢 Warm** | Steady, normal pace, signals stable | Maintain. No escalation needed. |
| **🟡 Mild cool** | Reply gap stretched, length shrinking, but no hard signal | **Hold position.** Do not ping again. Wait. |
| **🟠 Cooling** | Multiple signals: latency + length + redirect | **Pull density down.** Don't try to "fix" with a meta-message. |
| **🔴 Disengaging** | Explicit redirect / sticker-only replies / >48h silence after a clear ball | Stop. Re-read what *you* did. Consider a clean acknowledgment, not a new topic. |
| **⚫ Gone (for now)** | >7 days silent, no ack on your last 2 messages | Do not chase. Either wait for them, or close the loop with one neutral note and let it rest. |

The agent should pick **one** state. Hedging ("warm to mild cool") is what豆包 does.

---

## The 9 signals (look for these in chat.md)

For each, the agent records: **was it present? when? what was your last message before it?**

### Latency signals

1. **Reply gap spike.** Their typical gap before reply is N minutes. The latest gap is ≥ 3× N. → **cooling signal**.
   - Filter: ignore if your message landed during their known offline hours.
2. **Conversational stop.** Both sides have stopped; ball was last in *their* court for > 24h on an active topic. → **mild cool to cooling** depending on their baseline.

### Length signals

3. **Length collapse.** Their messages were averaging X chars; latest 3 are ≤ X/3 (e.g. went from paragraphs to "嗯" / "哦" / single emoji). → **cooling signal**.
4. **Stickerization.** Last 2-3 replies were sticker / emoji only, no text. Especially if it's a closing-feel sticker (😊 / 🌙 / 👌). → **mild cool to disengaging** depending on topic.

### Content signals

5. **Hard redirect.** They changed the topic in 1 message, no acknowledgment of yours. → **cooling signal**, possibly **trip wire hit**.
6. **Soft non-answer.** They responded but didn't engage with your question / proposal. ("是哦" / "看情况吧" / "再说" ). → **mild cool**.
7. **Topic doesn't get a hook.** You opened a topic 2+ times in the last 7 days, they never picked it up. → **stop pushing that topic**, regardless of overall state.
8. **Explicit boundary.** They said "我不太想聊这个" / "先这样吧" / 🙄 / "好" with no further engagement. → **disengaging**.

### Meta signals

9. **They critique your style, not the topic.** ("跟豆包聊天" / "你怎么老问这些" / "你今天怪怪的"). → **🚨 critical**. This is a meta trip wire — they're telling you HOW you're talking is the problem, not WHAT. Don't defend. Acknowledge and change behavior, not topic.

---

## The "ball-in-court" question (critical)

For every state assessment, the agent must answer: **is the ball in their court or mine?**

- Ball in **their** court = you sent last, you're waiting.
- Ball in **my** court = they sent last (even a sticker counts), you owe a reply.

State maps to default action through this lens:

| State | Ball in their court | Ball in my court |
|---|---|---|
| 🔥 Hot | reply quickly to keep pace | continue |
| 🟢 Warm | wait normally | reply normally |
| 🟡 Mild cool | **wait, do not double-ping** | reply normally, no escalation |
| 🟠 Cooling | **wait minimum 3× their normal gap** | reply low-stakes, no big swing |
| 🔴 Disengaging | **do not ping unprompted** | reply minimal, no question, no hook |
| ⚫ Gone | wait or one neutral close | one neutral close, no questions |

The most common Ethan-mistake (from chat data): **ball in their court + mild cool → he sends a second message to "check in"**. That's the move that converts mild cool into cooling. Don't.

---

## How the agent should report

When the agent finishes a session-start read of someone's `chat.md`, the output should be a 5-line block, not a paragraph:

```
[name]
state: 🟡 mild cool
ball: them
last move: 2026-05-13 12:31 — you sent皮影视频, she replied "挺搞笑的", no follow-up
key signal: length collapse (last 3 messages avg 4 chars, normal is 20+); no hook on 阴阳师 mention
do now: hold. don't ping. wait minimum 3 days, then re-engage with烤红薯 callback (low-stakes hook)
```

If multiple people, one block per person. **No prose summary.** Just blocks.

---

## What this is NOT

- Not a "should I send X?" tool. That's `draft-coach.ps1` (separate, not built yet).
- Not a fortune teller. The agent infers from observed patterns; humans aren't deterministic.
- Not for distant relationships ("she might be busy this week" applies for distant ties — this framework is calibrated for active 1:1s where the data is dense).
- Not a substitute for asking them directly when stakes are real. If you suspect something
  serious, ask — don't infer from sticker frequency.

---

## Common false positives (don't panic over these)

| Signal | But also could mean |
|---|---|
| 6h reply gap | They were at work / sleeping / driving |
| Sticker-only reply | They liked the message but had nothing to add |
| Hard redirect | They're enthusiastic about the new topic, not avoiding yours |
| 1-day silence after a hook | They want to think, not avoiding |

**Rule**: don't call cooling unless you see **2+ signals from different categories** (latency + length, or content + meta). One signal = noise.

---

## Example output (placeholder names)

> **张三** · state: 🔴 disengaging · ball: them
> last move: 5/10 21:14 — you sent third "want to grab dinner this weekend?" in 6 days; he replied "再看吧" then 0 messages for 4 days
> signals: 3rd consecutive non-answer (content); >4× normal reply gap (latency); soft brush-off language (content)
> do now: stop pinging. No more "checking in." If you must close, send a clean "no pressure, hit me up when free" once and rest.

> **Alice** · state: 🟢 warm · ball: mine
> last move: 5/14 19:08 — she sent a meme, you haven't replied
> signal: nothing concerning; normal cadence
> do now: reply normally in your usual window. Don't overthink it.

---

## Integration with `profile.md`

The state assessment goes into the body of `profile.md` under "当前状态" (current state)
— not the frontmatter, because state changes too often for static metadata. Frontmatter
holds the slow-moving fields (`last-updated`, `ball-in-court`, `next-action`, `mbti`,
`trip-wires`, `comms`); the body's "当前状态" section gets updated each refresh with
the latest read.
