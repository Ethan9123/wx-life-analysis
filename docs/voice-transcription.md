# Voice transcription — turn WeChat voice notes into searchable text

> Pipeline + methodology for getting voice content out of `people/<slug>/voice/`
> into a transcript that the agent can read alongside `chat.md` + `sns.json`.

Voice messages are commonly 5-10% of typical WeChat chat volume — and for
voice-heavy contacts, much more (one contact in a typical workspace can carry
100+ voice notes). The MBTI methodology currently treats them as *count only*
(voice/text ratio informs E/I) and never reads content. **This is a real
analysis gap** for voice-heavy relationships.

This doc + the companion [`tools/voice-transcribe.ps1`](../tools/voice-transcribe.ps1)
/ `.sh` close that gap, with a privacy-first default.

---

## TL;DR

```powershell
# Windows
.\tools\voice-transcribe.ps1 -Person qiumu -Since "2026-04-01" -Model base
```

```bash
# macOS / Linux
./tools/voice-transcribe.sh --person qiumu --since 2026-04-01 --model base
```

Both produce `people/<slug>/voice-transcripts.md` (gitignored). Output is
per-voice timestamped chunks suitable for the agent to read inline with
`chat.md`.

---

## Pipeline (5 stages)

```
wx attachments --kind voice --since DATE
        │
        ▼
wx extract <id> -o <work>/<id>.silk            decrypt to Tencent's .silk format
        │
        ▼
silk_v3_decoder <id>.silk <id>.pcm 24000        decode silk → raw PCM
        │
        ▼
ffmpeg -f s16le -ar 24000 -i <id>.pcm <id>.wav  raw PCM → WAV
        │
        ▼
whisper / whisper.cpp / faster-whisper <wav>    transcribe → text
        │
        ▼
people/<slug>/voice-transcripts.md              concatenate, timestamped
```

Each stage can fail gracefully — the tool catches and reports which one,
with concrete install hints.

---

## Dependencies

All four are external — this toolkit doesn't bundle binaries.

### 1. `wx-cli` (already required)

```bash
npm install -g @jackwener/wx-cli
```

The `wx attachments --kind voice` + `wx extract` pair handles the first two
columns of the pipeline. If your wx-cli version doesn't list voice kinds,
see "Fallback: direct filesystem path" below.

### 2. silk decoder

WeChat stores voice as Tencent's customized Silk-v3 codec. Open-source
decoder:

- **[kn007/silk-v3-decoder](https://github.com/kn007/silk-v3-decoder)** —
  C source, build with `cmake . && make`. Produces a `silk_v3_decoder`
  binary.
- Pre-built Windows builds: search "silk_v3_decoder Windows release" on
  GitHub releases.

Add the binary to PATH or supply `-SilkDecoder <path>` to the tool.

### 3. `ffmpeg`

```bash
# macOS
brew install ffmpeg

# Linux
sudo apt install ffmpeg

# Windows
winget install Gyan.FFmpeg
# or scoop install ffmpeg
```

### 4. Whisper backend (pick one)

| Backend | Install | Speed (1-min voice, CPU) | Notes |
|---|---|---|---|
| **whisper.cpp** | `brew install whisper-cpp` (mac) / build from source | ~5-15s | Fastest local; need to download model `.bin` separately |
| **faster-whisper** | `pip install faster-whisper` | ~10-30s | Python; CT2 backend; good balance |
| **openai-whisper** | `pip install openai-whisper` | ~30-90s | Reference impl; reads many formats; pure-CPU works |
| **OpenAI API** | none (network) | ~1-3s (network) | Cloud; **DO NOT USE without explicit user consent** — audio leaves the machine |

Default in the tool: **auto-detect in this order** — whisper.cpp →
faster-whisper → openai-whisper. **Never** falls back to cloud silently.

For the OpenAI API path, you must pass `-Backend cloud-openai` explicitly,
**and** the tool prints a confirmation prompt the first time it's used per
session. There's no `--auto-accept` for this — voice content is more
intimate than text and explicit consent is mandatory.

---

## Models (local backends)

| Model | Size | Quality | Speed | Recommended for |
|---|---|---|---|---|
| `tiny` | 75 MB | Low | Fastest | Quick scan, English mostly |
| `base` | 142 MB | Decent | Fast | Default — good balance for Chinese WeChat |
| `small` | 466 MB | Better | Medium | Better Chinese, more accurate |
| `medium` | 1.5 GB | Good | Slow | Production quality |
| `large` | 2.9 GB | Best | Slowest | When accuracy really matters (rare) |

For WeChat Chinese voice messages, `base` is usually adequate. Switch to
`small` if Cantonese / dialect content is mis-recognized.

---

## Fallback: direct filesystem path

If `wx attachments --kind voice` returns nothing or your wx-cli version
doesn't support that flag, voice files live directly on your machine:

- **Windows**: `C:\Users\<USER>\xwechat_files\<account>\msg\audio\YYYY-MM\`
- **macOS**: `~/Library/Containers/com.tencent.xinWeChat/Data/Library/Application Support/com.tencent.xinWeChat/2.0b4.0.9/<acct>/Audio/`
- **Linux** (Wine): mirror of the Windows path inside the WINEPREFIX

In that case, run the tool with `-SilkDir <path>` to point directly at the
`.silk` directory; the tool skips the wx-cli stages and starts at silk
decoding. Date filtering then uses file mtime instead of message metadata.

---

## How to read transcripts in the analysis workflows

`voice-transcripts.md` is structured as:

```markdown
# Voice transcripts — 张三

source: people/zhangsan/voice/
model: base (whisper.cpp)
generated: 2026-05-18 12:34
backend: local
language: zh (auto-detected)

---

## 2026-05-13 22:14:32 · 4.3s · 张三 → me
> 你那边搞定了吗

## 2026-05-13 22:18:11 · 12.7s · me → 张三
> 嗯, 这个事情我下周再说, 主要是…
```

Per the MBTI methodology ([`mbti-analysis.md`](mbti-analysis.md)):

- **For voice-heavy contacts**, read `voice-transcripts.md` alongside
  `chat.md` chronologically. Voice often carries the *emotional* layer
  (apologies, vulnerable disclosures, jokes) that text doesn't capture.
- **Caption tone in voice** (per the SNS section): same axis signals
  apply — abstract vs concrete, blunt vs cushioned, etc.
- **The voice/text decision** ("did they choose voice for this?") is
  itself a signal: voice = higher emotional bandwidth, T types avoid
  it, F types use it for hard topics.

---

## Privacy hard rules

1. **Voice content is more sensitive than text.** Voice carries tone, who's
   in the room, ambient noise. Treat `voice-transcripts.md` exactly like
   `chat.md` — never echo outside the local session, gitignored by default.
2. **Local-first.** The tool's default backend is local Whisper. It never
   sends audio anywhere outside the machine unless you explicitly opt into
   `-Backend cloud-openai` with an interactive confirmation.
3. **Don't commit transcripts.** `voice-transcripts.md` is under `people/<slug>/`
   which is already gitignored. The intermediate `.silk` / `.pcm` / `.wav`
   files (under `<temp>` by default) are deleted after transcription unless
   `-KeepTemp` is supplied. CI (gitleaks) will catch real-name leaks if
   somehow committed, but don't rely on that.
4. **Don't transcribe other people's WeChat data.** Same wx-cli legal
   notice: only your own data.

---

## When to skip voice transcription

- **Voice ratio under 5%**: not worth the setup. MBTI E/I signal is already
  in the voice/text count.
- **Distant relationships** (1-2 messages/year): no patterns to extract.
- **You don't have a model downloaded and can't spare the disk**: skip it.
  The toolkit is designed to be useful without this step — voice
  transcription is depth, not breadth.

---

## Future direction

- **Diarization** — separating multiple speakers in a single voice. The
  `pyannote-audio` library handles this; wraps cleanly but adds another
  heavy dep.
- **Live transcription** — for incoming voices in real time. Out of scope
  for this offline-analysis-focused toolkit.
- **Sentiment / emotion classification** — beyond transcription, extracting
  tone. Mostly noise for now (Chinese sentiment models for chat language
  are weak). Skip until the MBTI inference itself is fully exploited.

---

## References

- [`ylytdeng/wechat-decrypt`](https://github.com/ylytdeng/wechat-decrypt) — original implementation of the 5-stage pipeline; three Whisper backends
- [`kn007/silk-v3-decoder`](https://github.com/kn007/silk-v3-decoder) — silk decoder used in stage 3
- [openai/whisper](https://github.com/openai/whisper) — reference Whisper
- [ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp) — C++ port, fastest local
- [SYSTRAN/faster-whisper](https://github.com/SYSTRAN/faster-whisper) — CT2 backend; better than reference
