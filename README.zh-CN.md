# wx-life-analysis

> 用 Claude / Codex / Cursor 分析你自己的微信数据的工作模板。

[English](README.md) · **中文**（你正在看）

基于 [`@jackwener/wx-cli`](https://github.com/jackwener/wx-cli)（负责解密 + 查询你本地的微信数据库），本仓库提供配套的**目录结构 + agent 行为契约 + 分析方法学 + 一组小工具**，把原始聊天数据变成可操作的人际关系分析、项目任务清单、决策辅助。

**协议**：Apache-2.0 · **平台**：Windows / macOS / Linux · **支持的 agent**：Claude Code、OpenAI Codex、Cursor、Aider、GitHub Copilot

---

## 这是什么 / 这不是什么

✅ **一个模板仓** — fork 或 clone 后，把你的数据填到本地，**永远不要 push 回 GitHub**。本仓的 `.gitignore` + CI（gitleaks）双重防止数据泄漏。
✅ **一份 agent 契约** — `AGENTS.md` + `CLAUDE.md` + `.claude/skills/*` 让任何 code-agent 知道在这个目录怎么干活。
✅ **一组小工具** — PowerShell + Bash + Node 脚本，包装 `wx-cli` 的常见操作。

❌ **不是** `wx-cli` 的 fork — 你还得单独装 `wx-cli`。
❌ **不是**云服务 — 全部本机运行。
❌ **不是**让 AI 帮你发消息 / 代你聊天的工具 — 故意不做这个，理由见 `AGENTS.md` § Out of scope。

---

## 5 分钟上手

### 1. 装依赖

```bash
# wx-cli（解密 + 查询微信本地数据）
npm install -g @jackwener/wx-cli

# 初始化（提取微信密钥到 ~/.wx-cli/）
sudo wx init        # macOS / Linux
wx init             # Windows（以管理员身份）

# 验证
wx sessions
```

平台具体细节看 [`jackwener/wx-cli`](https://github.com/jackwener/wx-cli) 的 README。

### 2. 拉本仓

**A 路：作为 Vercel Skill 一键安装**（推荐 agent 用户）

```bash
npx skills add Ethan9123/wx-life-analysis
```

agent 读 `SKILL.md` 就懂这个工作流。

**B 路：clone 仓库**（你想要脚本和模板）

```bash
git clone https://github.com/Ethan9123/wx-life-analysis.git my-wx-workspace
cd my-wx-workspace
```

### 3. 拉一个人的数据

```powershell
# Windows
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"
```

```bash
# macOS / Linux
chmod +x tools/refresh.sh
./tools/refresh.sh --name "张三" --dir "people/zhangsan"
```

会把 `wx export` + `wx sns-feed` + `wx stats` 三件套打包到 `people/zhangsan/`。整个目录 gitignored，你的数据不会上传。

---

## 4 个核心工作流

### 工作流 1：单人画像分析（MBTI + 雷点 + 沟通策略）

方法学：[`docs/mbti-analysis.md`](docs/mbti-analysis.md)

让 agent 读 `people/<slug>/chat.md` 后产出：
- **MBTI 推断**（带置信度 + 支持信号）
- **雷点（trip wires）**：哪些话题让对方降密度、拐弯、不接
- **沟通策略**：频率 / 风格 / do-list / avoid-list

输出存到 `people/<slug>/profile.md` 的 YAML frontmatter（被 `tools/status.ps1` 读取）+ body 章节。

如果对方愿意，让 ta 自己测一下 [types.learntocode.com.tw](https://types.learntocode.com.tw/) — 比你从聊天里推靠谱。

### 工作流 2：实时潜台词读取

方法学：[`docs/subtext-reading.md`](docs/subtext-reading.md)

针对一个**正在进行的对话**，agent 从 9 个信号（reply 延迟突变、长度坍缩、硬转移话题、贴纸式回话、明确边界、"你跟豆包聊天"式 meta-吐槽 等）中挑出，给出**唯一一个**状态：

🔥 hot · 🟢 warm · 🟡 mild cool · 🟠 cooling · 🔴 disengaging · ⚫ gone

输出 5 行 block，写到 `profile.md` 的 "当前状态" 段：

```
[名字]
state: 🟡 mild cool
ball: them
last move: <日期> · <发生了什么>
key signal: <匹配的信号类别>
do now: <一个具体动作，比如 "hold. 不要 ping。等 3+ 天。">
```

**最常见的错误**：球在对方那 + mild cool → 用户发"check in 一下" → 把 mild cool 变成 cooling。这个 skill 专门拦截这种行为。

### 工作流 3：从领导聊天里扒任务清单

方法学：[`docs/task-extract.md`](docs/task-extract.md)

适用场景：老板/客户/家人 stakeholder 在某个时间窗砸了一堆消息 + 文件给你，你想理出"她到底要我干啥"。

```powershell
# 第一遍 regex 过滤候选
.\tools\task-extract.ps1 -Person zhuhui -Project ungc-cop-2026

# agent 读候选 → 分桶分类 → 评 P0/P1/P2 → 更新 projects/<slug>/notes.md
```

6 个分类桶：
- 直接派活 / 等她拍板 / 需要第三方数据 / 你自己已答应做 / 隐式（发完文件不说话） / 已 closed

3 轴优先级（每轴 1-3，加总 3-9）：stakeholder 权重 × 紧迫度 × 可撤回度。

硬规则：**引用原话不要意译**（≤30 字），意译会引入 drift；**不要凭空发明任务**（不清楚的归到"待澄清"段）。

### 工作流 4：你自己的聊天习惯量化

工具：`tools/self-mirror.ps1` → 生成 `SELF-MIRROR.md`（gitignored）

7 个 section 输出：
1. **复读式回话**（豆包式）— 出现次数 + top 10 实例 + 按收件人分组
2. Top 10 开场句
3. 你发出的消息长度分布
4. 问句 vs 陈述句比例
5. 时段分布 + 越界（在对方"22 点后不回话"窗口内发的消息）
6. 语气词频率（嘛 / 吧 / 啊 / 呢 / 哦 / 嗯）
7. 表情包 / 贴纸用量

杀手洞察通常在 #1：你自评不复读了，但量化数据说你最近 2 周还在某人面前复读 17 次——这种事情自己很难发现。

---

## 工具速查

| 工具 | 干嘛 |
|---|---|
| `tools/refresh.ps1` / `.sh` | 拉一个 1:1 联系人最新聊天 + 朋友圈 + 统计 |
| `tools/refresh-group.ps1` / `.sh` | 拉一个**群聊**到 `topics/<slug>/`（成员名单 + 增量消息） |
| `tools/digest.ps1` | 上次 session 以来谁有新消息 / 球在你那的高亮 |
| `tools/status.ps1` / `.sh` | 一行 summary：所有人状态 / 项目球在谁那 / next-action |
| `tools/self-mirror.ps1` | 上面工作流 4 |
| `tools/task-extract.ps1` | 上面工作流 3 |
| `tools/extract-pdf.js` | PDF 文本提取（pdf-parse 包装） |

所有脚本第一行已设 UTF-8 编码（中文名字 / 中文 frontmatter 字段安全）。

---

## 隐私 + 法律

### 永远不会被 commit 的（多层防护）

1. **`.gitignore`**：屏蔽 `people/*`、`projects/*`、`topics/*`、`*.db`、`*.pdf`、`*.docx`、`*.xlsx`、`*.pptx`、`all_keys.json`、各种 `.local.*`。
2. **CI `no-data-leaked` workflow**：
   - 路径检查：不允许 `people/`、`projects/`、`topics/` 下出现非 `_template/` 文件
   - 文件类型检查：不允许 `*.db`、`*.pdf` 等敏感扩展名
   - **gitleaks 内容扫描**：自定义 `.gitleaks.toml` 规则拦截中国手机号 (`1[3-9]\d{9}`)、`wxid_xxx`、邮箱、长度 50+ 的中文聊天片段
3. **`.gitleaks.local.toml` 逃生口**：每个 fork 可以加自己的 `.gitleaks.local.toml`（gitignored），加私人的真名 / 公司域名等正则。本地用 `gitleaks detect --config .gitleaks.toml --config .gitleaks.local.toml` 双重检查。

### 法律

只能解密**你自己的**微信数据。这是 `wx-cli` 的硬规则，本仓沿用。详见 [`wx-cli` legal notice](https://github.com/jackwener/wx-cli#legal-notice)。

### 万一漏了

参考 GitHub 的 [清除敏感数据指南](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) + 立刻 rotate 你所有的 token / 密码。

---

## 给 agent 的契约（如果你是 agent）

| 文件 | 何时读 |
|---|---|
| `AGENTS.md` | 任何 code-agent 在这个 repo 干活前必读（Codex / Cursor / Aider / Copilot agent / Claude Code 都读这个） |
| `CLAUDE.md` | Claude Code 每次 session 自动加载 |
| `.claude/skills/<name>/SKILL.md` | Claude Code 按 description 匹配自动加载（mbti-analysis / subtext-reading / task-extract / self-mirror 四个） |
| `SKILL.md`（仓根） | Vercel Skills CLI 入口（`npx skills add`） |
| `.github/copilot-instructions.md` | GitHub Copilot 的 chat 窗口自动加载，指向 `AGENTS.md` |

---

## 贡献

欢迎 issue / PR，特别是：
- 新工具脚本（如群聊年度总结、跨人话题图谱）
- 模板字段改进（`people/_template/profile.md`、`projects/_template/notes.md`）
- macOS / Linux 等价脚本
- agent prompt 改进（`AGENTS.md`、`CLAUDE.md`、`.claude/skills/*`）

**永远不要在 issue 或 PR 里附真实姓名、电话、wxid、聊天截图、PDF 等。** 用 `张三` / `Alice` / `Acme Corp` 这类占位符。CI 会拦截，但人为审查是第一道。

---

## 致谢

- [`jackwener/wx-cli`](https://github.com/jackwener/wx-cli) — 解密 + 查询 + 守护进程的全部重活
- [Vercel Skills CLI](https://github.com/vercel-labs/skills) — `SKILL.md` 格式
- [Claude Code](https://www.anthropic.com/claude-code) — 本仓最初的开发工作流

---

**English version**: [README.md](README.md)
