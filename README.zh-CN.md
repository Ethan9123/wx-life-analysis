# wx-life-analysis

> 用 Claude / Codex / Cursor 分析你自己的微信数据的工作模板。

[English](README.md) · **中文**（你正在看）

基于 [`@jackwener/wx-cli`](https://github.com/jackwener/wx-cli)（负责解密 + 查询你本地的微信数据库），本仓库提供配套的**目录结构 + agent 行为契约 + 分析方法学 + 一组小工具**，把原始聊天数据转化为可执行的人际关系分析、项目任务清单和决策辅助。

**协议**：Apache-2.0 · **平台**：Windows / macOS / Linux · **支持的 agent**：Claude Code、OpenAI Codex、Cursor、Aider、GitHub Copilot

---

## 这是什么 / 这不是什么

✅ **一个模板仓** — fork 或 clone 之后，把数据填到本地，**永远不要 push 回 GitHub**。本仓的 `.gitignore` + CI（gitleaks）双重防止数据泄漏。
✅ **一份 agent 契约** — `AGENTS.md` + `CLAUDE.md` + `.claude/skills/*` 让任何 code-agent 都能在这个目录里按规范干活。
✅ **一组小工具** — PowerShell + Bash + Node 脚本，包装 `wx-cli` 的常见操作。

❌ **不是** `wx-cli` 的 fork — 你仍然需要单独安装 `wx-cli`。
❌ **不是**云服务 — 全部在本机运行。
❌ **不是**让 AI 代你发消息或代你聊天的工具 — 这是故意不做的，理由参见 `AGENTS.md` 的 "Out of scope" 一节。

---

## 5 分钟上手

### 1. 安装依赖

```bash
# wx-cli（解密 + 查询微信本地数据）
npm install -g @jackwener/wx-cli

# 初始化（提取微信密钥到 ~/.wx-cli/）
sudo wx init        # macOS / Linux
wx init             # Windows（以管理员身份）

# 验证
wx sessions
```

平台相关的具体步骤请参见 [`jackwener/wx-cli`](https://github.com/jackwener/wx-cli) 的官方文档。

### 2. 获取本仓

**方式 A：作为 Vercel Skill 一键安装**（推荐 agent 使用）

```bash
npx skills add Ethan9123/wx-life-analysis
```

agent 读取 `SKILL.md` 即可理解整套工作流。

**方式 B：clone 仓库**（你想要脚本和模板）

```bash
git clone https://github.com/Ethan9123/wx-life-analysis.git my-wx-workspace
cd my-wx-workspace
```

### 3. 拉取某个联系人的数据

```powershell
# Windows
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"
```

```bash
# macOS / Linux
chmod +x tools/refresh.sh
./tools/refresh.sh --name "张三" --dir "people/zhangsan"
```

脚本会把 `wx export` + `wx sns-feed` + `wx stats` 三件套打包到 `people/zhangsan/` 目录。整个目录已被 `.gitignore` 排除，**数据不会被上传到任何远程仓库**。

---

## 4 个核心工作流

### 工作流 1：单人画像分析（MBTI + 雷点 + 沟通策略）

方法学：[`docs/mbti-analysis.md`](docs/mbti-analysis.md)

让 agent **同时读两份数据源**：
- `people/<slug>/chat.md` — 1:1 私聊历史（占 ~70% 信号：ta 怎么跟你说话）
- `people/<slug>/sns.json` — 朋友圈 / SNS feed（占 ~30% 信号：ta 怎么希望被更大圈子看到）

两份都由 `tools/refresh.ps1` 一次拉好，都在 `.gitignore` 里。交叉对比能产出：

- **MBTI 推断**：带置信度（low / medium / high）+ 来自聊天和朋友圈的支持信号清单
- **人设分裂识别**：朋友圈里光鲜外向 vs 私聊里疲惫沉默 = 重要的沟通策略信号（不要按 ta 朋友圈的版本去接近 ta）
- **雷点（trip wires）**：哪些话题会让对方降低回复频率、转移话题或不接你的话
- **沟通策略**：联系频率 / 风格 / do-list / avoid-list
- **朋友圈观察**：发帖频率、主导话题、可见的 3+ 个月静默期（通常对应人生事件）、ta 跟你朋友圈的互动模式（点赞 / 评论 / 沉默）

输出会写入 `people/<slug>/profile.md` 的 YAML frontmatter（`tools/status.ps1` 自动读取）和正文章节，正文额外包含一节 "朋友圈观察"。

如果对方愿意，可以让 ta 亲自做一下 [types.learntocode.com.tw](https://types.learntocode.com.tw/) 的测试 —— 自报类型比你从聊天和朋友圈推断更可靠。

### 工作流 2：实时潜台词读取

方法学：[`docs/subtext-reading.md`](docs/subtext-reading.md)

针对一个**正在进行的对话**，agent 从 9 个信号（回复延迟突变、消息长度坍缩、硬转移话题、贴纸式回话、明确边界、"你跟豆包聊天"式 meta-吐槽 等）中识别匹配项，给出**唯一一个**状态：

🔥 hot · 🟢 warm · 🟡 mild cool · 🟠 cooling · 🔴 disengaging · ⚫ gone

输出 5 行 block，写入 `profile.md` 的 "当前状态" 段：

```
[名字]
state: 🟡 mild cool
ball: them
last move: <日期> · <发生了什么>
key signal: <匹配的信号类别>
do now: <一个具体动作，比如 "保持沉默。不要 ping。等 3+ 天。">
```

**最常见的错误**：球在对方手上 + mild cool → 用户忍不住又发了一条"打个招呼" → 把 mild cool 推成了 cooling。这个 skill 专门拦截这种行为。

### 工作流 3：从领导聊天中提取任务清单

方法学：[`docs/task-extract.md`](docs/task-extract.md)

适用场景：老板 / 客户 / 家人这类关键 stakeholder 在短时间内丢给你一堆消息 + 文件，你想理出 "ta 到底要我做什么"。

```powershell
# 第一步：用正则做候选过滤
.\tools\task-extract.ps1 -Person zhuhui -Project ungc-cop-2026

# 第二步：agent 读候选 → 分桶分类 → 评 P0/P1/P2 → 更新 projects/<slug>/notes.md
```

6 个分类桶：
- 直接派活
- 等对方拍板
- 需要第三方数据
- 你自己已答应做的
- 隐式任务（发完文件不说话，默认 = 要你读）
- 已关闭

3 轴优先级（每轴 1-3，加总 3-9）：stakeholder 权重 × 紧迫度 × 可撤回度。

硬规则：**只引用原话，不要意译**（≤30 字），否则会引入认知偏差；**不要凭空发明任务**，含糊的归到 "待澄清" 段，等下一轮主动问清楚再列。

### 工作流 4：你自己的聊天习惯量化

工具：`tools/self-mirror.ps1` → 生成 `SELF-MIRROR.md`（已 gitignored）

报告输出 7 个章节：
1. **复读式回话**（俗称 "豆包式"）— 出现次数 + top 10 实例 + 按收件人分组
2. Top 10 开场句
3. 你发出消息的长度分布
4. 问句 vs 陈述句比例
5. 时段分布 + 是否在对方静默时段（例如 "22 点后不回话"）越界发消息
6. 语气词频率（嘛 / 吧 / 啊 / 呢 / 哦 / 嗯）
7. 表情包 / 贴纸用量

最核心的发现通常在第 1 项：你自评 "已经改了不再复读"，但量化数据告诉你最近 2 周还在某人面前复读了 17 次 —— 这种自我盲点，靠主观很难察觉。

---

## 工具速查

| 工具 | 用途 |
|---|---|
| `tools/contacts.ps1` / `.sh` | 模糊查询联系人（refresh 之前确认正确的 display name，避免拉错人） |
| `tools/refresh.ps1` / `.sh` | 拉取一个 1:1 联系人的最新聊天 + 朋友圈 + 统计（**默认增量**：读 `.last-sync` 用 `--since` 只拉新消息） |
| `tools/refresh-group.ps1` / `.sh` | 拉取一个**群聊**到 `topics/<slug>/`（成员名单 + 增量消息） |
| `tools/attachments.ps1` / `.sh` | 列出 / 批量解密下载某联系人发来的附件（PDF / 图片 / 文件 / 语音）；list 模式默认，加 `-ExtractAll` 拉取 |
| `tools/voice-transcribe.ps1` / `.sh` | 语音消息转文字（silk → wav → Whisper 流水线）；**本地优先**，需要 `silk_v3_decoder` + `ffmpeg` + 任一 Whisper 后端；方法学见 [`docs/voice-transcription.md`](docs/voice-transcription.md) |
| `tools/digest.ps1` | 上次会话以来谁发了新消息 / 球在你这边的高亮提醒 |
| `tools/warmth.ps1` / `.sh` | 谁在给你朋友圈点赞 / 评论（"温度计"，喂给 `docs/mbti-analysis.md` 的 interaction signals 段） |
| `tools/status.ps1` / `.sh` | 一行 summary：所有人的当前状态 / 项目球在谁手上 / next-action |
| `tools/self-mirror.ps1` | 见上面工作流 4 |
| `tools/task-extract.ps1` | 见上面工作流 3 |
| `tools/extract-pdf.js` | PDF 文本提取（`pdf-parse` 包装） |

所有脚本顶部已设置 UTF-8 编码，可以放心使用中文姓名和中文 frontmatter 字段。

---

## 隐私 + 法律

### 永远不会被提交的内容（多层防护）

1. **`.gitignore`**：屏蔽 `people/*`、`projects/*`、`topics/*`、`*.db`、`*.pdf`、`*.docx`、`*.xlsx`、`*.pptx`、`all_keys.json` 以及各种 `.local.*` 文件。
2. **CI `no-data-leaked` workflow**：
   - **路径检查**：不允许 `people/`、`projects/`、`topics/` 下出现非 `_template/` 的文件。
   - **文件类型检查**：不允许 `*.db`、`*.pdf` 等敏感扩展名。
   - **gitleaks 内容扫描**：通过自定义 `.gitleaks.toml` 规则拦截中国大陆手机号（`1[3-9]\d{9}`）、`wxid_xxx`、邮箱地址、长度 50+ 的连续中文聊天片段等。
3. **`.gitleaks.local.toml` 个性化扩展**：每个 fork 都可以维护自己的 `.gitleaks.local.toml`（已 gitignored），用于添加私人真名、公司域名等本地正则规则。本地用 `gitleaks detect --config .gitleaks.toml --config .gitleaks.local.toml` 同时启用两套规则。

### 法律

只能解密**你自己的**微信数据。这是 `wx-cli` 的硬规则，本仓沿用。详情请参见 [`wx-cli` 的 legal notice](https://github.com/jackwener/wx-cli#legal-notice)。

### 万一不小心提交了敏感数据

请立即按照 GitHub 官方 [清除敏感数据指南](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) 操作，并第一时间重置（rotate）所有相关的 token、密码、API key。

---

## agent 契约

| 文件 | 何时被读取 |
|---|---|
| `AGENTS.md` | 任何 code-agent 在这个 repo 干活前必读（Codex / Cursor / Aider / Copilot agent / Claude Code 都遵循） |
| `CLAUDE.md` | Claude Code 每次 session 自动加载 |
| `.claude/skills/<name>/SKILL.md` | Claude Code 按 description 匹配后自动加载（含 mbti-analysis / subtext-reading / task-extract / self-mirror 四个） |
| `SKILL.md`（仓根） | Vercel Skills CLI 入口（`npx skills add`） |
| `.github/copilot-instructions.md` | GitHub Copilot 的 chat 窗口自动加载，内容指向 `AGENTS.md` |

---

## 参与贡献

欢迎提交 issue 或 PR，尤其欢迎以下方向：
- 新工具脚本（例如群聊年度总结、跨人话题图谱）
- 模板字段优化（`people/_template/profile.md`、`projects/_template/notes.md`）
- macOS / Linux 等价脚本
- agent prompt 改进（`AGENTS.md`、`CLAUDE.md`、`.claude/skills/*`）

**永远不要在 issue 或 PR 中附带真实姓名、电话号码、wxid、聊天截图、PDF 等真实数据。** 请使用 `张三` / `Alice` / `Acme Corp` 这类占位符。CI 会自动拦截，但人工审查是第一道防线，提交前请自查一遍。

---

## 致谢

- [`jackwener/wx-cli`](https://github.com/jackwener/wx-cli) — 承担了解密、查询、守护进程等全部底层重活，本仓只是它的工作流封装
- [Vercel Skills CLI](https://github.com/vercel-labs/skills) — `SKILL.md` 格式标准
- [Claude Code](https://www.anthropic.com/claude-code) — 本仓最初的开发工作流

---

**英文版**：[README.md](README.md)
