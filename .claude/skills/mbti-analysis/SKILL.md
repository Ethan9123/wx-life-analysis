---
name: mbti-analysis
description: Infer a WeChat contact's MBTI type from their chat history AND their Moments / SNS feed combined, identify trip wires (topics that shut them down), surface persona splits (public-extrovert vs private-reserved), and translate everything to a concrete comms strategy (frequency, style, do-list, avoid-list). Activate when the user wants to understand what type a contact is, why a conversation cooled, what's safe to bring up, or how often to message them. Reads BOTH people/<slug>/chat.md (private 1:1, ~70% signal) AND people/<slug>/sns.json (public self-presentation, ~30% signal, often flips borderline axes). Writes to people/<slug>/profile.md YAML frontmatter under mbti / trip-wires / comms fields plus a "朋友圈观察" body section. Uses observable signals only — reply latency, voice/text ratio, abstract vs concrete language, planning style, SNS post frequency, caption tone, audience scope, visible gaps — never fabricates certainty (always records a confidence level).
---

# MBTI Analysis Skill

When this skill is loaded, you are running a **per-person personality + comms-strategy analysis** over a contact's WeChat chat history.

**Full methodology**: read [`docs/mbti-analysis.md`](../../../docs/mbti-analysis.md) before producing output. The methodology document defines the 4-axis scoring table, the trip-wire taxonomy, and the comms strategy translation rules.

## Quick reference (don't substitute for reading the methodology)

### Input sources (read BOTH)

1. **`people/<slug>/chat.md`** — private 1:1 history. ~70% of useful signal. Strongest for trip wires + comms style.
2. **`people/<slug>/sns.json`** — public Moments feed. ~30% of useful signal. Often flips a borderline axis call. Critical for surfacing persona splits and safe/unsafe topic territory.

### Four MBTI axes — what to look for (chat signals)

| Axis | Skew toward first letter | Skew toward second letter |
|---|---|---|
| E/I | high message volume, fast replies, voice notes, skims topics | lower volume, batched replies, prefers text, depth dives |
| S/N | "where/when/how-much" questions, concrete nouns, present-focused | "why/what-if" questions, abstract concepts, future-focused |
| T/F | logic-first, blunt disagreement, "smart take" praise | empathy-first, cushioned disagreement, "thoughtful" praise |
| J/P | proposes specific time+place, locked plans, lists | "free this week, you pick", flexible, last-minute OK |

### Four MBTI axes — what to look for (SNS signals)

| Axis | Skew toward first letter | Skew toward second letter |
|---|---|---|
| E/I | posts 3+/week, comments on others, broad audience | posts <1/week, mostly read-only, "close friends" audience |
| S/N | concrete captions ("今天在 X 吃了 Y"), documentary photos, practical share-links | abstract captions, aesthetic-curated photos, philosophical share-links |
| T/F | achievements / news / sports, sparse emotional disclosure | mood posts, named feelings, "for me this means…" framing |
| J/P | planned recaps ("年终") / curated trip albums / themed collections | spontaneous moments, unedited, jumps topic |

### Persona splits

If SNS shows a polished extrovert but chat shows reserved/tired — **don't approach with the public version of them**. Note explicitly in `mbti.basis`. This is one of the highest-value observations the SNS pass produces.

### Voice transcription (optional depth-add)

For voice-heavy contacts (voice/text ratio > 5%), the agent should suggest running [`tools/voice-transcribe.ps1`](../../../tools/voice-transcribe.ps1) / `.sh` to surface content from voice messages. Read the resulting `people/<slug>/voice-transcripts.md` alongside `chat.md` — voice often carries the emotional/vulnerable register that text doesn't. Methodology: [`docs/voice-transcription.md`](../../../docs/voice-transcription.md). Privacy default is local-only Whisper; cloud APIs require explicit user `I CONSENT` confirmation.

### Confidence required

Always record `mbti.confidence: low | medium | high` plus 2-4 sentences of `mbti.basis` citing **specific data points**, not vibes. If signals are mixed, write `"INFP/ENFP"` or `"unclear"`.

### Trip wires — what shuts them down

Walk the chat for: latency spikes (3-5× baseline), length collapse, hard topic redirect, soft non-answer, "you sound like a bot" meta-critique. Need 2+ signals from different categories before calling something a trip wire — single signals are noise.

### Output schema

```yaml
mbti:
  type: ENFP                  # or "INFP/ENFP" if borderline, or "unclear"
  confidence: medium          # low / medium / high
  basis: |
    <2-4 sentences citing specific signals from chat.md>
trip-wires:
  - topic: <short label>
    pattern: <what triggered → reaction>
    repair: <how to avoid / recover>
comms:
  frequency: <e.g. "1 ping / 2 days when ball mine">
  style: <e.g. "short, no metaphors, voice OK">
  do: [<topic-1>, <topic-2>]
  avoid: [<thing-1>, <thing-2>]
```

## Hard rules

1. **Never share the inferred type with the actual contact as fact.** "I think she's INTJ" is fine privately; saying it to her is annoying and often wrong.
2. **Don't paste `chat.md` excerpts outside the local session.** All evidence stays in the user's local clone.
3. **If you can, ask the contact** to take [types.learntocode.com.tw](https://types.learntocode.com.tw/) — self-report beats inference.
4. **Re-check every few months.** People change, moods vary. Treat MBTI as a snapshot, not a label.

## Integration with other skills

- This skill produces **slow-moving fields** (`mbti`, `trip-wires`, `comms`) in profile.md frontmatter.
- The companion [`subtext-reading`](../subtext-reading/SKILL.md) skill produces the **fast-moving** "current state" in the body — re-run subtext every refresh, re-run MBTI every few weeks or after a major shift.
