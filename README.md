# readaloud

A terminal EPUB/TXT reader with multi-backend neural TTS, built for Linux. A fast curses TUI, natural-sounding voices via online or offline TTS engines, and playback through `ffplay`.

Follows your terminal colour scheme out of the box. Tiling-friendly — resize the window and the layout reflows.

---

## Showcase

**Reading scenario 1 — both panels visible, single focused reading column**

![Both panels open, single reading column](260712_08h57m51s_screenshot.png)

**Reading scenario 2 — one panel visible, two-column snake layout**

![One panel open, two-column snake flow](260712_08h57m09s_screenshot.png)

**Reading scenario 3 — both panels hidden, three-column snake layout**

![Both panels hidden, three-column snake flow](260712_08h56m06s_screenshot.png)

---

## Features

- **Multi-backend TTS** — online (Edge TTS) and offline (Kokoro, Piper, F5-TTS) engines; auto-detected at startup
- **12 Edge TTS voices** — US/GB/AU/CA English via Microsoft's neural API; 7 Kokoro voices included; Piper uses your own ONNX models; F5-TTS clones any voice from a reference WAV
- **Wide format support** — EPUB, TXT, PDF, DOCX, HTML, RTF, and Markdown; chapters parsed from structure (headings, spine, page groups) or split by content length
- **Adaptive reading layout** — 3 scenarios auto-selected by panel visibility: single focused column (both panels open), two-column snake (one panel), three-column snake (both panels hidden)
- **Rice-friendly** — `Terminal` theme uses your kitty/terminal colours as-is; 4 additional themes (Dark Navy, Gruvbox, Nord, Solarized Dark) for 256-colour terminals
- **Tiling-friendly** — layout reflows on any resize; works in any window size ≥50×14
- **Text highlight** — current sentence tracked in sync with playback; toggle on/off with `h`
- **Auto-scroll** — reading area follows playback; toggle with `z`
- **Bookmarks** — add, browse, jump; stored per-file
- **Text zoom** — `Ctrl+scroll` sends kitty OSC font-size sequences for real terminal zoom
- **Variable speed** — 0.75× to 2.0× in 8 steps
- **Text alignment** — left, centre, right
- **Debug overlay** — live player state, engine availability, timing, config dump, log path
- **Persistent config** — all settings, active engine, and bookmarks saved across sessions

---

## TTS Engines

| Engine | Type | Quality | Notes |
|--------|------|---------|-------|
| **Edge TTS** | Online | ★★★★★ | Microsoft neural voices; no API key; needs internet |
| **Kokoro** | Offline | ★★★★☆ | Fast, high-quality CPU inference; best offline choice |
| **Piper** | Offline | ★★★☆☆ | Ultra-lightweight ONNX runtime; drop in `.onnx` model files |
| **F5-TTS** | Offline | ★★★★★ | Flow-matching voice cloner; slow on CPU, GPU recommended |

Engines are auto-detected at startup. Only available engines appear as selectable in the voices panel. The active engine label is always shown in the status bar.

---

## Requirements

### Host system (always required)

| Dependency | Purpose | Install |
|---|---|---|
| Python 3.10+ | Runtime | pre-installed on most distros |
| `ffplay` | Audio playback (part of ffmpeg) | `sudo pacman -S ffmpeg` |
| `pipx` | Edge TTS isolation | `sudo pacman -S python-pipx` |

Everything else (Python packages, engine binaries) is handled automatically by `install.sh` inside an isolated venv. No `--break-system-packages` needed.

### What the installer handles automatically

| Engine | What gets installed |
|--------|---------------------|
| **Edge TTS** | `edge-tts` package in venv; invoked via `pipx run` |
| **Kokoro** | `pykokoro` + `onnxruntime` + spaCy `en_core_web_sm` in venv (falls back to native `kokoro` on Python <3.13); ONNX model weights (~800 MB) downloaded from HuggingFace on first use |
| **Piper** | `piper-tts` in venv; binary symlinked to `~/.local/bin/piper` |
| **F5-TTS** | `f5-tts` in venv (skipped gracefully if torch/CUDA missing); binary symlinked to `~/.local/bin/f5-tts_infer-cli` |

| Format | Parser | What gets installed |
|--------|--------|---------------------|
| EPUB | `ebooklib` | installed as core dependency |
| TXT | built-in | no extra package |
| PDF | `pdfminer.six` | installed by `install.sh` |
| DOCX | `python-docx` | installed by `install.sh` |
| HTML / HTM | built-in `HTMLParser` | no extra package |
| RTF | `striprtf` | installed by `install.sh` |
| MD / Markdown | `markdown2` | installed by `install.sh` |

### What you must provide manually (post-install)

**Kokoro** works out of the box after `install.sh`, but on first use it downloads ~800 MB of ONNX model weights from HuggingFace into `~/.cache/pykokoro/`. This happens automatically in the background — expect a 30–60 second delay before the first chapter starts playing. Subsequent chapters and sessions are instant.

On **Python 3.13+** the installer uses `pykokoro` (pure-Python ONNX wrapper) instead of the native `kokoro` package. The voices and quality are identical. The `install.sh` handles the correct variant automatically.

**Piper** requires model files — the binary alone is not enough:

```bash
# Download a model — you need BOTH the .onnx and .onnx.json files
wget -P ~/.config/readaloud/models \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
wget -P ~/.config/readaloud/models \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
```

Any `.onnx` + `.onnx.json` pair in `~/.config/readaloud/models/` is auto-detected and listed in the voices panel.

**F5-TTS** requires a reference voice clip:

```bash
# Place 3–10 seconds of clean, single-speaker audio here
cp your_voice.wav ~/.config/readaloud/voices/ref.wav

# Optional: transcript of the clip (improves synthesis alignment)
echo "Your reference text here." > ~/.config/readaloud/voices/ref.txt
```

GPU (CUDA) is strongly recommended for F5-TTS; CPU generation works but is slow.

---

## Installation

### Method 1 — install.sh (recommended)

Installs everything into an isolated venv at `~/.local/share/readaloud/venv/` and places a launcher at `~/.local/bin/readaloud`. No host Python pollution.

```bash
git clone https://github.com/YareyareSenpai/readaloud.git
cd readaloud
chmod +x install.sh && ./install.sh
```

The script auto-detects your distro (Arch / Debian / Fedora) and installs host packages (`ffmpeg`, `python-pipx`) via the appropriate package manager, then builds the venv and installs all engines.

### Method 2 — pipx (single-command, portable)

Installs `readaloud` as a fully isolated pipx app with Edge TTS + Kokoro as the default set:

```bash
pipx install .
```

Install with specific offline engines or format parsers:

```bash
pipx install ".[kokoro]"     # + Kokoro
pipx install ".[piper]"      # + Piper
pipx install ".[f5]"         # + F5-TTS (needs torch)
pipx install ".[formats]"    # + PDF, DOCX, RTF, Markdown parsers
pipx install ".[all]"        # everything
```

### Method 3 — manual (no script)

```bash
cp readaloud.py ~/.local/bin/readaloud
chmod +x ~/.local/bin/readaloud
```

You are responsible for installing all dependencies yourself in this case. See the engine table above.

### PATH

Make sure `~/.local/bin` is in your `PATH` (required for all methods):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## Verifying the Install

```bash
# Confirm the launcher is reachable
which readaloud

# Confirm audio playback works
which ffplay

# Confirm Piper binary is linked (if using Piper)
which piper

# Run with debug overlay to see engine availability at startup
readaloud --debug somebook.epub
```

In the TUI, press `v` to open the voices panel. Each engine shows either a check mark (available) or `✗` (not detected). Engines greyed with `✗` need either a missing binary, a missing model file, or a missing `ref.wav` — the debug overlay (`?`) will show the exact availability map.

To clean up and reinstall from scratch:

```bash
rm -rf ~/.local/share/readaloud
rm -f ~/.local/bin/readaloud ~/.local/bin/piper ~/.local/bin/f5-tts_infer-cli
# Then re-run: ./install.sh
```

---

## Usage

```bash
readaloud                   # open file browser
readaloud book.epub         # EPUB
readaloud chapter.txt       # plain text
readaloud paper.pdf         # PDF
readaloud report.docx       # Word document
readaloud article.html      # HTML
readaloud notes.rtf         # RTF
readaloud README.md         # Markdown
readaloud book.epub --debug # start with debug overlay
```

---

## Key Bindings

### Playback

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `Enter` | Play selected chapter from start |
| `n` / `p` | Next / previous chapter |
| `s` | Cycle speed (0.75× → 0.9 → 1.0 → 1.1 → 1.25 → 1.5 → 1.75 → 2.0×) |

### Navigation

| Key | Action |
|-----|--------|
| `↑ ↓` | Move chapter list or scroll text (depends on focus) |
| `PgUp / PgDn` | Scroll text by page |
| `Tab` | Cycle focus: chapters → text → right panel |
| `g` | Go to chapter by number |
| `\` | Toggle chapter nav panel |

### Right Panels

| Key | Action |
|-----|--------|
| `v` | Toggle voices panel |
| `B` | Toggle bookmarks panel |
| `b` | Add bookmark at current chapter |
| `Esc` | Close right panel |
| `↑ ↓` (panel focused) | Navigate engine list or voice list |
| `Tab` / `→` (voices panel) | Switch from engine section to voice section |
| `Tab` / `←` (voices panel) | Switch from voice section back to engine section |
| `Enter` (engine focused) | Select active engine |
| `Enter` (voice focused) | Select voice and apply immediately |
| `Enter` (bookmarks focused) | Jump to bookmarked chapter |
| `d` (bookmarks focused) | Delete bookmark |

### Display

| Key | Action |
|-----|--------|
| `a` | Cycle text alignment (left → centre → right) |
| `t` | Cycle theme |
| `h` | Toggle TTS highlight |
| `z` | Toggle auto-scroll |
| `Ctrl + scroll ↑` | Zoom in |
| `Ctrl + scroll ↓` | Zoom out |

### Other

| Key | Action |
|-----|--------|
| `?` | Toggle debug overlay |
| `q` | Quit |

---

## Voices Panel

The voices panel (`v`) has two sub-sections navigated with `Tab` or arrow keys:

**Engine section** — lists all four TTS backends with availability status:
- `✓` marks the currently active engine
- `○` = online engine, `◉` = offline engine
- `✗` suffix = engine not detected / unavailable
- Press `Enter` to switch to the highlighted engine

**Voice section** — lists voices for whichever engine is highlighted in the engine section (even before committing to it, so you can browse):
- `✓` marks the current voice for the active engine
- ♀ / ♂ gender indicators where applicable
- Press `Enter` to activate both the engine and the highlighted voice simultaneously

Switching engine or voice while audio is playing restarts playback from the current chapter with the new settings.

---

## Themes

| Theme | Description |
|-------|-------------|
| `Terminal` | Uses your terminal/kitty colours — default, follows your rice |
| `Dark Navy` | Deep blue-grey |
| `Gruvbox` | Warm retro palette |
| `Nord` | Arctic blue-grey |
| `Solarized Dark` | Ethan Schoonover's classic |

Cycle with `t`. 256-colour terminals get full palette control; 8-colour terminals fall back to Terminal theme.

---

## Available Voices

### Edge TTS (online)

| Name | Region | Gender |
|------|--------|--------|
| Aria | US | ♀ |
| Jenny | US | ♀ |
| Michelle | US | ♀ |
| Guy | US | ♂ |
| Davis | US | ♂ |
| Sonia | GB | ♀ |
| Maisie | GB | ♀ |
| Ryan | GB | ♂ |
| Natasha | AU | ♀ |
| William | AU | ♂ |
| Clara | CA | ♀ |
| Liam | CA | ♂ |

### Kokoro (offline)

The 7 voices below are the curated default set shown in the voices panel. The full `pykokoro` library ships 54 voices — additional voices (e.g. `af_bella`, `af_sarah`, `am_echo`, `bm_daniel`, multilingual) can be used by editing `KOKORO_VOICES` in `readaloud.py` or selecting them via the voices panel once available.

| Name | Region | Gender |
|------|--------|--------|
| af_heart | US | ♀ |
| af_bella | US | ♀ |
| af_nicole | US | ♀ |
| am_adam | US | ♂ |
| am_michael | US | ♂ |
| bf_emma | GB | ♀ |
| bm_george | GB | ♂ |

### Piper (offline)

Voices are loaded automatically from any `.onnx` files in `~/.config/readaloud/models/`. The filename stem (e.g. `en_US-lessac-medium`) becomes the voice label. Download models from [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices) on Hugging Face.

### F5-TTS (offline)

Single cloned voice derived from `~/.config/readaloud/voices/ref.wav`. Provide 3–10 seconds of clean, single-speaker audio for best results. An optional `ref.txt` transcript of the clip improves synthesis alignment.

---

## Layout

```
╭─ readaloud ─ book.epub ──────────────────────── [·] ◀▶  Terminal  24/1413 ─╮
│ ▶ PLAYING   [Edge TTS] Jenny         Speed:1.00×  Align:Center  Z1/7  AUTO↓  HL │
├───────────────────────────────────────────────────────────────────────────────────┤
│ CHAPTERS     │  ── Chapter 24: Penny-pincher ──────────────── 0%  │ ENGINES…    │
│  22. Ch 19   │                                                     │ ✓○ Edge TTS │
│  23. Ch 20   │    "Melissa, this isn't a waste of salary..."       │  ◉ Kokoro   │
│ ›24. Ch 24   │                                                     │  ◉ Piper  ✗ │
│  25. Ch 25   │     He coughed lightly twice…                       │  ◉ F5-TTS ✗ │
│  ...         │                                                     │ ── VOICES ──│
├──────────────┴───────────────────────── ◀ prev  next ▶ ───────────┤ ✓♀ Jenny    │
│ Book [████░░░░░░░░░░░░░░░░]  24/1413  ┌─[Spc] play/pause  [\] nav─┐  ♀ Aria     │
│                               │[Enter] play ch   [v] voices│  ♀ Michelle │
│                               │[n/p]  next/prev  [B] bmks  │  …          │
│                               └───────────────────────────┘             │
╰───────────────────────────────────────────────────────────────────────────────────╯
```

---

## Configuration

Stored at `~/.config/readaloud/config.json`. Edited automatically on every settings change.

```json
{
  "voice_index": 1,
  "speed_index": 2,
  "theme": "terminal",
  "align": "center",
  "zoom": 0,
  "engine": "edge-tts",
  "last_file": "/home/user/books/lotm.epub",
  "bookmarks": {
    "Lord of the Mysteries (Complete).epub": [
      { "chapter": 9, "note": "" }
    ]
  }
}
```

Valid `engine` values: `"edge-tts"`, `"kokoro"`, `"piper"`, `"f5-tts"`.

Debug logs: `~/.config/readaloud/debug.log`

---

## How It Works

1. **Parsing** — Format is detected by file extension and routed through `_EXT_PARSER`: `ebooklib` for EPUB (spine order, HTML-stripped); `pdfminer.six` for PDF (grouped by ~10 pages); `python-docx` for DOCX (split on Heading styles); built-in `HTMLParser` for HTML/HTM; `striprtf` for RTF; `markdown2` + HTML stripper for Markdown; plain text split by heading patterns or blank lines for TXT.
2. **Engine scan** — at startup, `SystemScanner` checks for binary commands (`piper`, `f5-tts_infer-cli`, `ffplay`) and Python imports (`kokoro`, `piper`, `f5_tts`, `edge_tts`) to build an availability map. Unavailable engines are shown greyed out in the voices panel.
3. **TTS** — chapter text is split into ≤4500-char chunks at sentence boundaries, each synthesised by the active backend: Edge TTS writes MP3 via `pipx run edge-tts`; Kokoro uses `pykokoro` (Python 3.13+) or native `kokoro` (<3.13) with a cached ONNX session — the pipeline is built once per voice/speed pair and reused across chunks; Piper pipes stdin to its binary with an ONNX model; F5-TTS calls `f5-tts_infer-cli` with `ref.wav`.
4. **Playback** — `ffplay` plays all chunks as a concat playlist with an `atempo` filter for speed control. Pause/resume via `SIGSTOP`/`SIGCONT` on the ffplay process. WAV and MP3 chunks are handled identically by the concat pipeline.
5. **Highlight** — a background thread tracks elapsed time against estimated chars/second (140 wpm × speed × 5 chars/word) to approximate the current reading position.

---

## Troubleshooting

**SSL error from edge-tts**
```bash
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt readaloud book.epub
```

**No audio / ffplay not found**
```bash
sudo pacman -S ffmpeg
```

**ebooklib import error**
```bash
# If using install.sh:
~/.local/share/readaloud/venv/bin/pip install ebooklib
# If using pipx: pipx inject readaloud ebooklib
```

**Kokoro not detected**

On Python <3.13:
```bash
~/.local/share/readaloud/venv/bin/pip install "kokoro>=0.9.4" soundfile onnxruntime
```
On Python 3.13+:
```bash
~/.local/share/readaloud/venv/bin/pip install pykokoro
~/.local/share/readaloud/venv/bin/python -m spacy download en_core_web_sm
```

**Kokoro detected but synthesis fails (spaCy model missing)**
```bash
~/.local/share/readaloud/venv/bin/python -m spacy download en_core_web_sm
```

**Kokoro first run is very slow (30–60 s delay)**

Expected — it is downloading ~800 MB of ONNX model weights from HuggingFace on first use. Subsequent runs are instant. Check `~/.config/readaloud/debug.log` to watch progress.

**Piper model not found**
```
Piper requires .onnx model files in ~/.config/readaloud/models/
```
Download from [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices).

**F5-TTS: ref.wav not found**
```bash
cp your_voice_sample.wav ~/.config/readaloud/voices/ref.wav
```

**No chapters found in EPUB**
Some EPUBs have non-standard spine structures. Check `~/.config/readaloud/debug.log`. As a fallback, convert to TXT with Calibre:
```bash
ebook-convert book.epub book.txt
```

---

## Chapter Preloading

readaloud pre-synthesises the next 2 chapters in background threads while the current one plays, so pressing `n` starts audio immediately with no loading delay. Pre-warmed chapters are marked with `⚡` in the chapter nav. The cache lives at `~/.config/readaloud/cache/` and is keyed by chapter, engine, voice, and speed — it invalidates automatically when any of those change. Entries older than 2 hours are cleaned up on startup.

---

## Support

If readaloud is useful to you, consider buying me a coffee — it keeps the project going.

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/kamquat)

---

## License

MIT
