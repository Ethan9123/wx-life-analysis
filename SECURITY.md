# Security policy

> This repo is a **template** — it ships no real chat data, no user PII, no
> secrets. The threat model below is about protecting the *user's* private
> WeChat data when they use this template, plus the usual supply-chain
> concerns for an open-source toolkit.

## Reporting a vulnerability

If you find a security issue — anything that could lead to user data
exfiltration, CI bypass, dependency compromise, or unintended cloud calls
— please **do not open a public issue**.

Use GitHub's private vulnerability reporting:

  → https://github.com/Ethan9123/wx-life-analysis/security/advisories/new

Or email the maintainer via the address in `git log --format=%ae` of recent
commits (look for the Ethan9123 commits, not the Co-Authored-By bot
addresses).

Expect a first response within 7 days. We don't have a bounty program;
acknowledgement in `CHANGELOG.md` is on offer.

---

## Threat model — what we defend against

### T1: Accidental commit of user data

**Risk**: a user (or an agent on their behalf) `git push`es a `chat.md`,
`sns.json`, `voice-transcripts.md`, a real-name reference in a script
comment, or a PDF from `projects/<name>/raw/`.

**Mitigations shipped**:

1. **`.gitignore`** — blocks `people/*`, `projects/*`, `topics/*`, `*.db`,
   `*.sqlite`, `*.pdf`, `*.docx`, `*.xlsx`, `*.pptx`, `all_keys.json`,
   `CLAUDE.local.md`, `*.local.md`, `.env*`, `node_modules/`, build dirs,
   `DIGEST.md`, `SELF-MIRROR.md`, `task-candidates.md`, `.gitleaks.local.toml`.
2. **`.github/workflows/no-data-leaked.yml`** — runs on every push + PR:
   - **Path-based block**: rejects anything under `people/*`, `projects/*`,
     `topics/*` outside `_template/` and `README.md`.
   - **Extension-based block**: rejects `.db`, `.sqlite`, `.pdf`, `.docx`,
     `.xlsx`, `.pptx`, `all_keys.json`.
   - **`gitleaks-action@v2`** with custom rules in `.gitleaks.toml`:
     China mobile, `wxid_xxx`, WeChat F-account IDs, generic emails
     (with allowlist for placeholders), 50+-char pure-Chinese line
     fragments (likely chat excerpts).
3. **`AGENTS.md` § Hard rules + `CLAUDE.md` § Privacy hard rules** —
   instruct any agent in this repo to refuse commits with real names /
   chat content / contact info, even if the user asks.
4. **`SKILL.md` § Hard rules** — same rule restated at the skill-activation
   level for Vercel-Skills-CLI installs.
5. **`.gitleaks.local.toml`** — per-clone gitignored escape hatch where
   each user can add their own real-name / employer-domain regexes. Run
   locally with `gitleaks detect --config .gitleaks.toml --config .gitleaks.local.toml`.

If you find a way around any of these, please report it.

### T2: Voice / attachment content leaving the user's machine

**Risk**: `tools/voice-transcribe.ps1` or `tools/attachments.ps1` sends
audio or file content to a cloud service without explicit user consent.

**Mitigations shipped**:

1. `voice-transcribe.ps1` / `.sh` default to **local-only** Whisper
   backends (auto-detected in order: whisper.cpp → faster-whisper →
   openai-whisper). The cloud OpenAI API path requires `-Backend
   cloud-openai` **and** an interactive `I CONSENT` prompt per session.
2. Intermediate `.silk` / `.pcm` / `.wav` files are deleted after
   transcription unless `-KeepTemp` is supplied.
3. `attachments.ps1` only writes to local paths under `-Out`. No network
   destinations.
4. Filenames are sanitized before write (no path-traversal, no shell-meta).

### T3: Supply-chain compromise of `wx-cli` or other deps

**Risk**: an attacker publishes a malicious `@jackwener/wx-cli` update,
or a malicious `pdf-parse`, or a malicious gitleaks-action release.

**Mitigations**:

1. We **don't bundle** `wx-cli` — the user installs it themselves. The
   `npm install -g @jackwener/wx-cli` line in the README is the same trust
   surface as any other npm install.
2. Pinned action versions in `.github/workflows/`: `actions/checkout@v4`,
   `gitleaks/gitleaks-action@v2` — major-version pins, not SHAs. Tradeoff:
   we get patch updates automatically; SHA-pinning would be stricter but
   adds maintenance friction.
3. `tools/extract-pdf.js` resolves `pdf-parse` from `npm root -g` — uses
   the user's globally installed copy, so they control the version.
4. **No telemetry, no network calls** in any of our own scripts beyond
   what the underlying CLIs do.

### T4: Malicious PR sneaking data through CI

**Risk**: an external contributor opens a PR that adds a real-name regex
or chat snippet in a place CI doesn't scan.

**Mitigations**:

1. `gitleaks-action@v2` with `fetch-depth: 0` scans the full PR diff
   (not just the latest commit) — covers force-pushed history.
2. PR template (`.github/pull_request_template.md`) has a mandatory
   privacy checklist that human reviewers must check.
3. First-time contributors trigger GitHub's workflow-approval gate;
   maintainer must approve before CI runs.
4. `AGENTS.md § PR review checklist` for agent-to-agent reviews lists
   gitleaks-action passing as a required item.

### T5: Agent (Claude / Codex / Cursor / Copilot) misbehaving

**Risk**: an agent reads `CLAUDE.local.md` (the user's private context)
and accidentally echoes real names into a PR description or a public
issue comment.

**Mitigations**:

1. `AGENTS.md` / `CLAUDE.md` / `SKILL.md` / `.claude/skills/*/SKILL.md`
   all state: "never paste `chat.md` / `CLAUDE.local.md` content into
   any external context including issues, PRs, and other chats".
2. `.github/copilot-instructions.md` points Copilot to `AGENTS.md` —
   keeps the privacy rules even outside Claude Code.
3. Real names should never appear in commits / PRs — gitleaks would
   catch them if they did.

If you can construct a prompt or workflow that gets an agent to violate
these rules anyway, that's a security report — please follow the
disclosure path above.

---

## Out of scope (not threats we defend against)

- **A user's local machine being compromised**: at that point, `wx-cli`
  has already done the decryption and the data is locally accessible.
  Disk-encryption is the OS's responsibility, not ours.
- **Coercion**: if the user is *forced* to commit data, no CI rule helps.
- **A user explicitly choosing cloud-openai for voice transcription and
  consenting**: by design, that's their call.
- **WeChat itself**: we trust WeChat's local storage at the same level
  `wx-cli` does. If Tencent's encryption is broken, that's upstream.

---

## Auditing

If you're considering using this template, you should at minimum read:

1. `AGENTS.md` § Hard rules
2. `CLAUDE.md` § Privacy hard rules
3. `.github/workflows/no-data-leaked.yml`
4. `.gitleaks.toml`
5. `.gitignore`
6. This file

The four PowerShell + Bash tools that touch external CLIs (`wx`, `silk_v3_decoder`,
`ffmpeg`, whisper backends) are `refresh*`, `attachments`, `voice-transcribe`,
`warmth`, `digest`, `contacts`. Each ~150-300 lines, no obfuscation.
