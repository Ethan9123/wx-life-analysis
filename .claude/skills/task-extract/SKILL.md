---
name: task-extract
description: Extract a structured TODO list from a boss/client/family-stakeholder's chat dump + attached files (PDFs, docs, links). Activate when the user says "Jennifer / Alice / 老板 dumped a bunch of stuff on me, what am I supposed to do?", "list the actual tasks from these messages", "what's blocking what", "what did the boss decide vs leave open". Reads people/<task-giver-slug>/chat.md + projects/<project>/*.txt (PDF extracts) + optional topics/<group-slug>/chat.json (group chats), produces a structured task list classified into 6 buckets (Direct work / Decision needed / Data needed / Already-promised / Implicit / Closed) with 3-axis priority scores (stakeholder × urgency × reversibility). Strict quote-don't-paraphrase rule because paraphrasing drift causes wrong-direction work.
---

# Task Extraction Skill

When this skill is loaded, you are converting **work-chat streams + attached files** into a typed TODO list with priorities, dependencies, and decision points.

**Full methodology**: read [`docs/task-extract.md`](../../../docs/task-extract.md). It defines the 7 speech-act categories, the 6-bucket classification, the 3-axis priority scoring, and the hard rules.

## Quick reference

### Inputs (in order)

1. `people/<task-giver-slug>/chat.md` — last 100-200 messages or since last project milestone
2. Group chat (optional): `topics/<slug>/chat.json` — pull with `tools/refresh-group.ps1` if not cached
3. Source materials: `projects/<name>/*.pdf` → extract with `tools/extract-pdf.js` first
4. Prior state: `projects/<name>/notes.md` — avoid re-listing already-captured tasks

### First-pass filter

Run `tools/task-extract.ps1 -Person <task-giver-slug> -Project <slug>` to get a pre-filtered candidates file. **You** (the agent) then classify + prioritize. The tool does regex filtering only, not classification.

### Speech-act categories that count as tasks

- **Direct ask**: "你 [verb]…", "麻烦…", "请…", "Can you…"
- **Implicit ask**: "你看一下", "这个怎么处理", "Take a look"
- **Deferred decision**: "你来定", "Your call"
- **Information request**: "什么时候能…", "Status?"
- **Resource send** (file with no comment = implicit "read this")
- **Deadline statement**: "X 之前", "by Friday"
- **Escalation**: "尽快", "ASAP"

A bare "知道了" / "好" / 👍 **closes** a thread, not opens one.

### 6 buckets

Direct work · Decision needed (from them) · Data needed (from third party) · Already-promised (by you) · Implicit / inferred · Closed

### 3-axis priority (each 1-3, sum 3-9)

Stakeholder weight (3 = boss/family/paying client) × Urgency (3 = named deadline within 7 days) × Reversibility (3 = recoverable, 1 = once shipped you can't take back).
- P0 = 7-9 (this week)
- P1 = 5-6 (this month)
- P2 = 3-4 (whenever)

For INTJ-style bosses (e.g. user's typical setup), calibration note: under-react is the bigger risk than over-react. They don't repeat themselves.

## Output format

Produces a **diff proposal** for `projects/<name>/notes.md`, not a wholesale rewrite. Each new task includes:

```markdown
- [ ] **<short imperative>** — bucket: <Direct work / Decision needed / ...>
  - **From**: <stakeholder>, <date> <message-or-file-reference>
  - **Original**: <verbatim or near-verbatim quote, ≤30 chars, in quotes>
  - **Priority**: P<0/1/2> (stakeholder=<n> urgency=<n> reversibility=<n>)
  - **Blocks**: <if blocked, name the dependency>
  - **Status**: pending
```

Ambiguous messages go in `## Needs clarification`, not invented as TODOs.

## Hard rules

1. **Quote, don't paraphrase.** ≤30-char verbatim quotes. Paraphrasing introduces drift.
2. **Surface your own promises.** Outgoing messages where you committed to action ("我下周给你") become Already-promised — easy to forget.
3. **Respect 知道了-closes-thread.** Standalone "knows" / "ok" / "👍" from the task-giver CLOSES the prior thread.
4. **Don't invent tasks.** If a message is ambiguous, list under `## Needs clarification` for a follow-up ping, not as a concrete TODO.
5. **Don't drop dependencies.** "Need data from Sophie" must be a tracked task even if Sophie isn't in `people/` yet.
