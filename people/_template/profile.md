---
last-updated: 2026-01-01
ball-in-court: Alice / Bob
next-action: <one concrete next step>
tags:
  - <tag-1>
  - <tag-2>
mbti:
  type: unclear            # 16 letters, "ENFP/INFP" if borderline, or "unclear"
  confidence: low          # low / medium / high
  basis: |
    <2-4 sentences on chat-derived signals: reply latency, voice/text ratio,
    abstract vs concrete questions, blunt vs cushioned disagreement,
    scheduled vs improvised meet-ups, etc.>
trip-wires:
  - topic: <short label>
    pattern: <what you said / what they did — concrete>
    repair: <how to recover, or how to avoid next time>
  - topic: <short label>
    pattern: <…>
    repair: <…>
comms:
  frequency: <e.g. "1 ping / 2 days when ball-in-court is mine">
  style: <e.g. "short, no metaphors, voice notes OK">
  do:
    - <thing-1>
    - <thing-2>
  avoid:
    - <thing-1>
    - <thing-2>
---

# 张三

> Profile template. Copy this directory to `people/<your-contact-slug>/` and fill in.
> Anything under `people/<slug>/` is gitignored — your data stays local.

## 基本面
- **关系**: <朋友 / 同事 / 家人 / 暧昧 / 相亲 / 客户 / ...>
- **真名**: <如果知道>
- **昵称 / 备注**: <他们让你叫的名字>
- **居住**: <城市 + 区>
- **职业**: <Acme Corp + 岗位>
- **生日**: <YYYY-MM-DD 或月日>
- **怎么认识的**: <场合 + 时间>

## 数据量（来自 `wx stats`）
- 总消息: <N>
- 文本 / 图片 / 语音 / 链接: <a / b / c / d>
- 通话: <N>
- 视频通话: <N>
- 时段分布: <e.g. 7-22 点，22 点后 0 条 → 不熬夜聊>

## 性格 / 兴趣
- <一句话标签 1>
- <一句话标签 2>
- <一句话标签 3>

## MBTI 推断 + 沟通策略

> Methodology: see [`docs/mbti-analysis.md`](../../docs/mbti-analysis.md).
> All fields below also live in YAML frontmatter (top of file) for `tools/status.ps1`.

**类型**: <ENFP / unclear>  ·  **置信度**: <low / medium / high>

**支持信号**（来自 `chat.md` 实际观察，不是猜）:
- <signal 1 — 具体到数据 / 行为>
- <signal 2 — 具体到数据 / 行为>
- <signal 3 — 具体到数据 / 行为>

**他的强项**: <e.g. 共情快, 能拉住情绪 / 决断快, 能给方案>
**他的盲点**: <e.g. 不喜欢冲突 / 过度优化逻辑忽略关系>

### 雷点 (trip wires)

| 话题 / 模式 | 你做了什么 → 他怎么反应 | 下次怎么办 |
|---|---|---|
| <短标签 1> | <具体 — 引用日期或行为> | <避免 / 修复策略> |
| <短标签 2> | <…> | <…> |

### 沟通策略（给你 — Ethan）

- **频率**: <每天 1 条 / 隔天 1 条 / 球在他时不主动 / ...>
- **风格**: <短文本 / 可发语音 / 不要长 / 不要硬核新闻>
- **该做**:
  - <thing-1>
  - <thing-2>
- **不要**:
  - <thing-1>
  - <thing-2>
- **球在他那时**: <等多久才能再 ping 一次>

## 关系阶段标志事件（时间倒序）
- **YYYY-MM-DD**: <事件 + 你对它的解读>
- **YYYY-MM-DD**: <事件 + 你对它的解读>

## 推荐话题（按价值排序）
1. <话题 1 — 为什么>
2. <话题 2 — 为什么>
3. <话题 3 — 为什么>

## 避免
- <雷区 1>
- <雷区 2>

## 正信号
- <好的迹象 1>
- <好的迹象 2>

## 风险信号
- <警示迹象 1>
- <警示迹象 2>

## 当前状态
<2-3 行总结：球在谁那、TA 的节奏、你的下一步>

## 备注
- <长期任务 / 默契 / 隐私敏感点 / "绝对不要外传"的东西>
