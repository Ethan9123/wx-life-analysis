# Task extraction: turn chats + files into a structured TODO list

> Methodology for "Jennifer just dumped 10 messages + 3 PDFs on me at 3pm — what
> exactly am I supposed to do?" — i.e. converting a real work-chat stream into a
> typed task list with priorities and dependencies.

Companion to [`mbti-analysis.md`](mbti-analysis.md) (who they are),
[`subtext-reading.md`](subtext-reading.md) (where this conversation is right now),
and `projects/<name>/notes.md` (where the output lives).

---

## When to run this

- After a boss / client / family-stakeholder dump (multiple messages + attachments in a short window).
- At the start of a working week, scanning unread work-chat activity.
- When a project's `notes.md` feels stale — re-extract from the latest chat dump.

This is **not** for casual social chats. The signal-to-noise ratio is wrong there.

---

## Inputs

The agent should read, in order:

1. **The 1:1 chat with the task-giver**: `people/<their-slug>/chat.md` — last 100-200
   messages, or since the last project milestone date in `projects/<name>/notes.md`.
2. **Relevant group chats**, if any: `topics/<group-slug>/search.json` or a
   `wx export <group-name> -n 300` dump if not already cached.
3. **Project source materials**: `projects/<name>/*.pdf` (extract with
   `tools/extract-pdf.js` first), `*.docx`, `*.txt`, etc.
4. **Prior project state**: `projects/<name>/notes.md` if it exists — to avoid
   re-listing tasks that have already been captured.

---

## What counts as a "task"

A task is anything the task-giver expects the user to **do**, **decide**, or
**produce**. Look for these speech-act categories:

| Category | Markers in Chinese chats | Markers in English chats |
|---|---|---|
| **Direct ask** | "你 [verb]…", "麻烦…", "请…", "需要你…", "帮我…" | "Can you…", "Please…", "I need you to…" |
| **Implicit ask** | "这个怎么处理", "你看一下", "这个你来吧", "你那边有没有…" | "Take a look", "What do you think", "Got time for…" |
| **Deferred decision** | "你来定", "你拍板", "看你的" | "Your call", "You decide" |
| **Information request** | "什么时候能…", "进度怎么样", "数据呢" | "When can…", "Status?", "Got the numbers?" |
| **Resource send** (implicit task to read) | PDF / link / image with no comment | Attachment with no comment |
| **Deadline statement** | "X 之前要…", "下周一", "月底" | "By Friday", "EOW", "before X" |
| **Escalation** | "这个很急", "尽快", "今天就要" | "Urgent", "ASAP", "today" |

A bare "知道了" or "好" from the task-giver is **closing** a thread, not opening one.
A bare "嗯" or "👍" is **acknowledgment**, not a task.

---

## Classification

Each extracted task goes into one of these buckets:

| Bucket | Definition | Example |
|---|---|---|
| **Direct work** | They said "你 do X". Concrete output expected from you. | "把 CoP Guidebook PDF 提取出来看" |
| **Decision needed (from them)** | You can't proceed until they pick A / B / C. | "Sophie 还是 Alan 签 CEO 字" |
| **Data needed (from third party)** | You can't proceed until someone else gives you info. | "HR 给员工人数 2024 vs 2025" |
| **Already-promised** | You said you'd do X. Track from your own outgoing messages. | "Ethan 5/9 跟悠悠：'下次我请你吃费大厨'" |
| **Implicit / inferred** | They sent material with no instruction. Read = task. | "Jennifer 5/14 14:44 发 CoP Questionnaire PDF" |
| **Closed** | A task that was raised and is now done / cancelled. Move to bottom or drop. | n/a |

---

## Priority scoring

Score each task on three axes (1-3), sum for total priority:

- **Stakeholder weight**: 3 = boss / direct family / paying client; 2 = colleague /
  peer; 1 = acquaintance / casual.
- **Urgency**: 3 = named deadline within 7 days; 2 = vague but soon; 1 = "no rush".
- **Reversibility**: 3 = if undone soon, you can recover (low cost); 1 = once
  shipped you can't take back (high cost — needs more care, not necessarily faster).

**Total priority** = stakeholder + urgency + (4 − reversibility). Range 3-9.
- P0: 7-9 (this week)
- P1: 5-6 (this month)
- P2: 3-4 (whenever)

For Ethan-style users: tasks from Jennifer default to stakeholder=3, urgency=2,
reversibility=2 unless overridden by chat content. INTJ bosses don't repeat
themselves — under-react is the bigger risk than over-react.

---

## Output format

Update `projects/<name>/notes.md` task lists. The agent should produce a diff
proposal, not a wholesale rewrite — preserve existing structure and the user's
prior categorization, only add new tasks and re-classify existing ones if
warranted by new evidence.

Each new task should include:

```markdown
- [ ] **<short imperative>** — bucket: <Direct work / Decision needed / ...>
  - **From**: <stakeholder>, <date> <message-or-file-reference>
  - **Original**: <verbatim or near-verbatim quote, ≤30 chars, in quotes>
  - **Priority**: P<0/1/2> (stakeholder=<n> urgency=<n> reversibility=<n>)
  - **Blocks**: <if blocked on a data / decision dependency, name it>
  - **Status**: pending
```

When updating existing tasks:
- If new evidence escalates urgency: bump priority + add an `**Update YYYY-MM-DD**:` line.
- If new evidence resolves a blocker: move blocker to ~~strikethrough~~ + bump.
- If a task is now ambiguous (e.g., they said "do A" then "actually do B"): flag both, mark the new one as `[ambiguous]` and note in `## Needs clarification`.

---

## Hard rules

1. **Quote, don't paraphrase.** When evidence is "Jennifer said X", show the verbatim
   quote (≤30 chars). Paraphrasing introduces drift — and drift causes EcoVadis-style
   wrong-direction work.
2. **Don't invent tasks.** If a message is ambiguous, list it under `## Needs
   clarification` instead of inventing a concrete TODO. The user can then ping the
   task-giver for clarification — or decide it's just chitchat.
3. **Don't drop dependencies.** If a task requires data from Alice and Alice isn't
   tracked yet, the agent should flag "needs Alice tracking" in
   `## Needs clarification`.
4. **Mark "your own promises" explicitly.** Outgoing messages from the user that
   commit to action ("我下周给你") become Already-promised tasks. Most people forget
   these — surfacing them is high-value.
5. **Respect the 知道了 rule.** A standalone "知道了" / "好" / "👌" from the task-giver
   CLOSES the prior thread. Don't extract anything from those.

---

## Example (placeholder names, fabricated content)

> Source: 5/14 chat with Alice (boss) + 3 files in `projects/acme-launch/`.
>
> **New tasks**:
>
> ```markdown
> - [ ] **Extract and summarize Spec_v3.pdf (18 pages)** — bucket: Implicit / inferred
>   - From: Alice, 2026-05-14 14:44 (file send, no comment)
>   - Original: (file send) `Spec_v3.pdf`
>   - Priority: P0 (stakeholder=3, urgency=2, reversibility=2)
>   - Blocks: nothing
>   - Status: pending
>
> - [ ] **Get Q2 headcount from HR (Sophie)** — bucket: Data needed
>   - From: Alice, 2026-05-14 15:21
>   - Original: "需要 Q2 末人数数据"
>   - Priority: P0 (stakeholder=3, urgency=3, reversibility=3)
>   - Blocks: launch spec section 4
>   - Status: pending
>
> - [ ] **Decide: pilot in 2 regions or 5?** — bucket: Decision needed (from Alice)
>   - From: Alice, 2026-05-14 15:30
>   - Original: "你想清楚就两个市还是五个"
>   - Priority: P1 (stakeholder=3, urgency=2, reversibility=1) — reversibility is low
>     once you commit
>   - Blocks: budget request, regional sign-off
>   - Status: needs Ethan's prep work + an options memo for Alice
> ```
>
> **Needs clarification**:
> - 5/14 15:15 "你看一下能不能搞" — what's the antecedent? Three messages prior was
>   the spec file, but also a calendar invite. Ask Alice which one.

---

## Process — running this on a project

1. Refresh the relevant chats: `tools/refresh.ps1 -Name "<task-giver>" -Dir "people/<slug>"`.
2. Extract any new source materials: `node tools/extract-pdf.js <pdf> 1 999 > out.txt`.
3. Agent reads inputs (step 1-3 of "Inputs") and produces the diff against
   `projects/<name>/notes.md`.
4. User reviews the diff — accepts / rejects / edits.
5. User addresses `## Needs clarification` items (usually a single round of
   pinging the task-giver).
6. Repeat on next dump or weekly.

For a tool-assisted first pass, see `tools/task-extract.ps1` (issue tracking the
build: search the repo's open issues for `task-extract`).
