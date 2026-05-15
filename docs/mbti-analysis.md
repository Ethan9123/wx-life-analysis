# Per-person analysis: MBTI inference + trip wires + comms strategy

> A repeatable framework for "given a contact's chat history, infer their personality
> type and the topics that shut them down, then translate that into how *you* should
> message them — what frequency, what style, what to avoid."

This is the methodology agents (Claude, Codex, etc.) should follow when filling in the
`mbti` and `trip-wires` sections of `people/<slug>/profile.md`.

---

## What MBTI is and isn't here

We use MBTI as a **shared vocabulary**, not as science. It's a useful 4-dimension
shorthand that compresses "how this person processes the world" into something you
can act on at 11pm before sending a reply.

Caveats baked in:

- **Type is inferred, not measured.** From chat alone you'll usually land within
  one letter on each axis. Always record a confidence level (`low / medium / high`)
  and the specific signals you used.
- **People aren't one type.** The same person codes differently with their boss vs
  with a date vs at 2am. Note the context.
- **If the contact has actually taken a test**, that wins. Ask them — or send
  them [types.learntocode.com.tw](https://types.learntocode.com.tw/) as a casual
  share. Their self-report is more reliable than your inference from 500 messages.

---

## The four dichotomies — what to look for in chat

For each axis, score `+2 / +1 / 0 / -1 / -2` (one side / leaning / unclear / leaning / other).
Confidence = how strong the signal is, not how extreme the score is.

### E ↔ I — Extroversion vs Introversion (where they get energy)

| Signal | Points to E | Points to I |
|---|---|---|
| Message volume | High, multi-thread | Lower, focused |
| Reply latency | Fast, often instant | Slower, batched |
| Voice notes | Frequent | Rare, prefers text |
| Topic depth | Skims many topics | Deep dives one topic |
| Energy in messages | "OMG let me tell you", exclamations | More measured, fewer exclamations |
| After a long convo | Wants more | Goes quiet to recharge |

**In `wx stats` data**: ratio of voice : text, average gap between consecutive messages.

### S ↔ N — Sensing vs Intuition (how they take in info)

| Signal | Points to S | Points to N |
|---|---|---|
| Questions they ask | "Where", "when", "how much" | "Why", "what if", "what does that mean" |
| Vocabulary | Concrete nouns, specific brands | Abstract concepts, analogies |
| Stories they tell | Step-by-step, detailed | Big-picture, jump to point |
| Reaction to your metaphors | Polite confusion, redirect to specifics | Engaged, runs with it |
| Future-talk | Plans within weeks | "Imagine in 10 years…" |

### T ↔ F — Thinking vs Feeling (how they decide)

| Signal | Points to T | Points to F |
|---|---|---|
| Response to your problem | "Have you tried X?" | "That sounds rough, how are you feeling?" |
| Disagreement style | Blunt, "actually that's wrong" | Cushions, "I see what you mean, but…" |
| Praise they give | "Smart take" | "You're so thoughtful" |
| Reaction to criticism | Engages on logic | Reads it as attack, withdraws |
| When you vent | Wants to solve it | Wants to sit with it |

### J ↔ P — Judging vs Perceiving (how they structure life)

| Signal | Points to J | Points to P |
|---|---|---|
| How they propose meet-ups | "Sat 7pm, X place" | "Free this week, you pick" |
| Plans | Locked in early | Improvised, flexible |
| Lists & schedules | Loves them | Treats them as suggestions |
| Last-minute changes | Frustrates them | No big deal |
| Closure | "Decided, moving on" | "Let's keep options open" |

---

## Trip wires (雷点) — what shuts them down

Separate from MBTI. These are **observed patterns** in *your* chat with this person.

### How to find them

Walk the `chat.md` chronologically and flag any of these:

1. **Reply latency spike.** A topic where their gap-before-reply jumps 3-5x their baseline.
2. **Length collapse.** A long thread that ends in `"嗯"` / `"哦"` / a sticker.
3. **Hard redirect.** They change subject in one message, no acknowledgment.
4. **Explicit pushback.** "我不喜欢这个话题" / "别说这个了" / 🙄.
5. **The "豆包" reaction.** They call out *your* style, not the topic — that's a meta trip wire about how you're talking.
6. **Days of silence after a specific message.** Cross-check what you said last.

For each, record:
- The topic / pattern
- What *you* did that triggered it
- The repair move (or the avoid-it move) for next time

### Common categories

- **Identity attacks**: anything that feels like "you're X kind of person" lands badly on most types, hits F especially hard.
- **Unsolicited fixing**: F types vent and don't want solutions. Going into T-mode is a trip wire.
- **Over-planning**: P types feel boxed in by rigid schedules.
- **Vague openings**: J types dislike "you free this week?" — they want a specific ask.
- **Over-frequent pings**: I types feel pursued at >3 messages/day with no reply.
- **Echo replies** (复读式回话): everyone hates "X 看起来挺 X 啊" — adds zero observation.
- **Wrong-modality enthusiasm**: voice-notes-blast to a text-only person, or short text to a voice person.

---

## From type → comms strategy (what to actually do)

### Frequency

| Type cluster | Default daily ping count | When to reach out |
|---|---|---|
| **I + introvert** (I_TJ, I_TP, ISFJ) | 0–1 | After a clear hook (their post, event) |
| **I + warmer** (INFP, INFJ) | 1–2 | Daily-ish OK if low-stakes content |
| **E + structured** (E_TJ, ESFJ) | 1–3 | Tied to plans / shared activities |
| **E + spontaneous** (E_TP, ENFP, ESFP) | 2–5 | Match their energy, don't lead |

Adjust by **their** reply pattern, not your urge. Always lower density after a cold signal.

### Style by axis

- **High I**: short, low-pressure, async. "看到这个想到你, 没事不用回 [link]"
- **High E**: match volume, voice notes OK, can banter.
- **High S**: concrete, specific, no metaphors. "周六 3 点 X 店见?" beats "我们下周搞点啥吧"
- **High N**: ideas, "what if", abstract layers. They love a good metaphor.
- **High T**: blunt, no padding, get to the point. Don't open with feelings.
- **High F**: validate first, problem-solve second (if at all). Acknowledge before suggesting.
- **High J**: propose specific plans. Don't make them decide what / where / when.
- **High P**: leave room. "周末有空挑一天?" not "周六下午 3 点".

### What to say when they trip-wire

The recovery move depends on type:
- **F**: name it ("我感觉刚才那句你不舒服 — 我没想清楚就发了"), don't double down with logic.
- **T**: don't apologize for the topic, just acknowledge the bad delivery if any. Move on.
- **I**: pull back density first, don't add a meta-message about it.
- **E**: a quick voice note or sticker re-opens better than a long text.
- **J**: clean up loose ends ("那这事就这样, 下一步 X")
- **P**: don't force closure ("先放着, 看下周再说")

---

## The `profile.md` schema

Update `people/<slug>/profile.md` frontmatter with these MBTI-related fields:

```yaml
---
last-updated: 2026-01-01
ball-in-court: them                 # me / them
next-action: <one concrete next step>
tags: [<tag>]
mbti:
  type: ENFP                        # or "INFP/ENFP" if uncertain, or "unclear"
  confidence: medium                # low / medium / high
  basis: |
    <2-4 sentences on the signals: data points, message patterns, key
    behaviors. Be specific — "fast reply (avg 3min), voice-note-heavy,
    abstract metaphors land, schedules feel constraining" beats "extrovert.">
trip-wires:
  - topic: <short label>
    pattern: <what triggers it>
    repair: <how to recover or what to avoid>
  - topic: <…>
    pattern: <…>
    repair: <…>
comms:
  frequency: <e.g. "1 ping / 2 days when ball-in-court mine">
  style: <e.g. "short, no metaphors, voice OK">
  do: [<thing-1>, <thing-2>]
  avoid: [<thing-1>, <thing-2>]
---
```

Then in the body of `profile.md`, the section reads from these fields and adds the
narrative. See `people/_template/profile.md` for the full template.

---

## Worked example (placeholder names only)

> 张三 — INTJ guess, medium confidence
>
> **Signals**:
> - 36 messages over 14 days; replies in 2-30 min, never voice notes (I)
> - Asks "why this approach" rather than "where / when" (N)
> - Disagrees bluntly: "我觉得这逻辑不对" with no cushion (T)
> - Proposed meeting: "周六 3 点万象城南门" (J)
>
> **Trip wires**:
> - Small talk about weather / food → 1-word replies. Skip.
> - "你最近怎么样" generic openers → polite but no thread. Open with a *thing*.
> - Direct emotional disclosure too early → he goes quiet for 2 days.
>
> **Comms strategy**:
> - Frequency: 1 ping / 3 days max unless there's a real prompt
> - Style: short, factual, link or question; no "希望你最近好" padding
> - Do: send articles in his domain, propose specific plans
> - Avoid: vague openings, emotional vent, sticker spam

---

## Process — running this on a new person

1. Pull data: `tools/refresh.ps1 -Name "张三" -Dir "people/zhangsan"`
2. Read `chat.md` chronologically. Note signals as you go.
3. Score each axis. Don't force a type if signals are mixed — write `"INFP/ENFP"` or `"unclear"`.
4. Walk the chat again for trip wires. List 2-5.
5. Translate to comms strategy. Be concrete.
6. Fill in `profile.md` frontmatter + body section.
7. **Sanity check**: would this analysis be obvious garbage to the actual person if they read it? If yes, it's probably wrong — keep digging.

---

## Limits and ethics

- **Never share the inferred type with the actual person as fact.** "I think you're an INTJ" is fine as a guess; "you ARE an INTJ" is annoying and probably wrong.
- **Trip wires aren't permanent labels.** People change, moods vary. Re-check every few months.
- **This is for *you* improving how *you* communicate.** It is not a tool to "win" with someone or manipulate them. If the analysis is making you optimize past honesty, stop using it.
- **Don't write this analysis into anything they'll see.** It lives in your local gitignored workspace.

## References

- [types.learntocode.com.tw](https://types.learntocode.com.tw/) — the Chinese self-test you can share with a contact who wants to know their own type
- The 16 types: standard descriptions are everywhere; pick any clear reference (16personalities.com, truity.com, etc)
- Function stack theory (Ni / Ne / Si / Se / Ti / Te / Fi / Fe) — useful when type inference is stuck between two letters; skip if you don't already know it
