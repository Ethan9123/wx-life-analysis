# Changelog

All notable changes to this project will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project tries to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
but treats the **templates** + **agent contracts** as part of the
public-facing API: any breaking change to `people/_template/profile.md`
frontmatter schema, `AGENTS.md` hard rules, or `tools/*.ps1` parameter
shapes warrants a major-version bump.

---

## [Unreleased]

### Added

- `SECURITY.md` — vulnerability disclosure policy + threat model T1-T5
- `CHANGELOG.md` — this file
- `tools/digest.sh` — POSIX bash equivalent of `digest.ps1`, restores
  macOS/Linux parity for the "what changed since last session" digest

### Notes

- Two `tools/*.ps1` scripts (`self-mirror.ps1`, `task-extract.ps1`)
  still lack `.sh` equivalents. They do heavy multi-line regex on
  `chat.md` content that doesn't translate cleanly to portable bash.
  Tracked as future work; for now macOS/Linux users can run them via
  PowerShell Core (`pwsh tools/self-mirror.ps1`).

---

## [0.1.0] — 2026-05-18

First tagged release. The repo had been on `main` for ~3 days before
this tag — `v0.1.0` marks the point where everything below is in place,
CI is green, and the toolkit is ready for external use.

### Added

#### Tools (12 scripts)

- `tools/extract-pdf.js` — PDF text extraction (Node + global pdf-parse)
- `tools/contacts.ps1` / `.sh` — fuzzy lookup wrapping `wx contacts --query`
- `tools/refresh.ps1` / `.sh` — pull chat + SNS + stats for one contact;
  **incremental by default** (reads `.last-sync`, uses `wx export --since`)
- `tools/refresh-group.ps1` / `.sh` — pull a group chat into `topics/<slug>/`
- `tools/attachments.ps1` / `.sh` — list / extract chat attachments
  (PDFs, images, files), two-mode (list / extract)
- `tools/voice-transcribe.ps1` / `.sh` — 5-stage pipeline silk →
  pcm → wav → whisper; **local-only by default**, cloud requires
  interactive consent
- `tools/status.ps1` / `.sh` — one-line status per active contact
- `tools/digest.ps1` — unread incremental snapshot from `wx new-messages`
- `tools/warmth.ps1` / `.sh` — SNS engagement on your posts (warmth gauge)
- `tools/self-mirror.ps1` — quantify your own chat habits
  (echo-reply detection, opening repertoire, length distribution, etc.)
- `tools/task-extract.ps1` — first-pass TODO candidate extractor

#### Methodology docs

- `docs/mbti-analysis.md` — 4-axis MBTI inference framework, chat + SNS
  dual-input (~70% / 30% weight), trip-wire taxonomy, comms strategy
- `docs/subtext-reading.md` — 9-signal / 6-state conversation-now
  framework (🔥 / 🟢 / 🟡 / 🟠 / 🔴 / ⚫), ball-in-court × state action matrix
- `docs/task-extract.md` — speech-act categories, 6-bucket
  classification, 3-axis priority scoring (stakeholder × urgency ×
  reversibility), quote-don't-paraphrase rule
- `docs/voice-transcription.md` — 5-stage pipeline, Whisper backend
  selection, privacy hard rules

#### Agent contracts

- `README.md` — human-facing intro, install, commands cheatsheet
- `README.zh-CN.md` — concise Chinese version per
  `chinese-copywriting-guidelines`
- `AGENTS.md` — code-agent contract (Codex / Cursor / Aider / Copilot
  agent), hard rules, coding conventions, PR review checklist
- `CLAUDE.md` — Claude Code session-start checklist + workflows
- `SKILL.md` (repo root) — Vercel Skills CLI entry
  (`npx skills add Ethan9123/wx-life-analysis`)
- `.claude/skills/{mbti-analysis,subtext-reading,task-extract,self-mirror}/SKILL.md` —
  4 task-scoped Claude Code skills with activation descriptions
- `.github/copilot-instructions.md` — GitHub Copilot entry, delegates
  to `AGENTS.md`

#### Templates

- `people/_template/profile.md` — full YAML frontmatter schema
  (`last-updated`, `ball-in-court`, `next-action`, `tags`, `mbti`,
  `trip-wires`, `comms`) + body sections including `## 朋友圈观察`
- `projects/_template/notes.md` — project notes scaffold with YAML
  frontmatter, priority breakdown structure, decision-tracking section
- `people/README.md`, `projects/README.md`, `topics/README.md` — usage
  guides per directory

#### CI / security

- `.github/workflows/no-data-leaked.yml` — runs on push + PR; checks
  paths, file extensions, and content via `gitleaks-action@v2`
- `.gitleaks.toml` — custom rules: China mobile (`1[3-9]\d{9}`),
  `wxid_[a-z0-9]{8,}`, WeChat F-account IDs, generic email (with
  allowlist), 50+ char pure-Chinese line fragments
- `.gitleaks.local.toml` (gitignored) — per-fork escape hatch for
  personal real-name regexes
- `.github/ISSUE_TEMPLATE/{new-tool,improve-template}.md` — structured
  issue forms
- `.github/pull_request_template.md` — mandatory privacy checklist
- `LICENSE` — Apache-2.0

### Notable contributions

- **PR #5** (`tools: add bash equivalents (refresh.sh, status.sh)`) —
  external contributor **@shuibui** added the first round of POSIX
  bash equivalents within hours of the repo going public.
- **PRs #6, #9, #10, #13, #14, #15** — all built by **OpenAI Codex**
  via the issue → @codex → review → merge loop. Demonstrated that the
  template's agent contract (AGENTS.md hard rules + CI gates) is
  sufficient for autonomous code generation without privacy leaks.

### Privacy posture

- No user data is shipped in the repo. CI enforces.
- All tools default to **local-only** operation. The one exception
  (cloud Whisper in `voice-transcribe`) requires explicit per-session
  `I CONSENT` confirmation.
- No telemetry, no analytics, no remote calls beyond what the
  underlying CLIs (`wx-cli`, `ffmpeg`, Whisper backends) make.

[Unreleased]: https://github.com/Ethan9123/wx-life-analysis/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Ethan9123/wx-life-analysis/releases/tag/v0.1.0
