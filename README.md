# readaloud

A terminal EPUB/TXT reader with Microsoft Edge neural TTS voices, built for Linux. No Electron, no browser, no SpeakUB — just a fast curses TUI, natural-sounding voices via `edge-tts`, and playback through `ffplay`.

Follows your terminal colour scheme out of the box. Tiling-friendly — resize the window and the layout reflows.

---

## Showcase

**Default layout — chapter nav, reading area, bordered key reference**

![Default layout with chapter navigation and key reference](screenshot-default.png)

**Voices panel open — slides in from the right, text area reflows**

![Voices panel open on the right](screenshot-voices.png)

**Tiling with a live wallpaper — transparent terminal, full reflow**

![Tiling window manager with wallpaper bleed-through](screenshot-tiling.png)

---

## Features

- **Neural TTS voices** — 12 English voices (US/GB/AU/CA) via Microsoft Edge TTS
- **EPUB & TXT support** — chapters parsed from spine order; TXT split by headings or blank lines
- **Three-column layout** — chapters left, reading area centre, voices/bookmarks panel right
- **Rice-friendly** — `Terminal` theme uses your kitty/terminal colours as-is; 4 additional themes (Dark Navy, Gruvbox, Nord, Solarized Dark) for 256-colour terminals
- **Tiling-friendly** — layout reflows on any resize; works in any window size ≥50×14
- **Text highlight** — current sentence tracked in sync with playback; toggle on/off with `h`
- **Auto-scroll** — reading area follows playback; toggle with `z`
- **Bookmarks** — add, browse, jump; stored per-file
- **Text zoom** — `Ctrl+scroll` sends kitty OSC font-size sequences for real terminal zoom
- **Variable speed** — 0.75× to 2.0× in 8 steps
- **Text alignment** — left, centre, right
- **Debug overlay** — live player state, timing, config dump, log path
- **Persistent config** — all settings and bookmarks saved across sessions

---

## Requirements

| Dependency | Purpose | Install |
|---|---|---|
| Python 3.9+ | Runtime | pre-installed on most distros |
| `ebooklib` | EPUB parsing | `pip install --break-system-packages ebooklib` |
| `pipx` | Run `edge-tts` in isolation | `sudo pacman -S python-pipx` |
| `edge-tts` | Microsoft neural TTS | auto-fetched via `pipx run` on first use |
| `ffplay` | Audio playback (part of ffmpeg) | `sudo pacman -S ffmpeg` |

> `edge-tts` requires an internet connection — it streams synthesis from Microsoft's API. No API key needed.

### Arch Linux

```bash
sudo pacman -S python-pipx ffmpeg
pip install --break-system-packages ebooklib
```

### Debian / Ubuntu

```bash
sudo apt install pipx ffmpeg
pip install ebooklib
```

### Fedora

```bash
sudo dnf install pipx ffmpeg
pip install ebooklib
```

---

## Installation

```bash
git clone https://github.com/YareyareSenpai/readaloud.git
cd readaloud
chmod +x install.sh && ./install.sh
```

Or manually:

```bash
cp readaloud ~/.local/bin/readaloud
chmod +x ~/.local/bin/readaloud
```

Make sure `~/.local/bin` is in your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## Usage

```bash
readaloud                   # open file browser
readaloud book.epub         # open directly
readaloud chapter.txt       # plain text supported
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
| `↑ ↓` (panel focused) | Navigate list |
| `Enter` (panel focused) | Select voice / jump to bookmark |
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

Open the voice panel with `v`, navigate with `↑ ↓`, confirm with `Enter`.

---

## Layout

```
╭─ readaloud ─ book.epub ──────────────────────────── [·] ◀▶  Terminal  24/1413 ─╮
│ ▶ PLAYING   Voice:Jenny    Speed:1.00×  Align:Center  Z1/7  AUTO↓  HL          │
├──────────────────────────────────────────────────────────────────────────────────┤
│ CHAPTERS     │  ── Chapter 24: Penny-pincher ──────────────────  0%            │
│  22. Ch 19   │                                                                  │
│  23. Ch 20   │    "Melissa, this isn't a waste of salary..."                    │
│ ›24. Ch 24   │                                                                  │
│  25. Ch 25   │     He coughed lightly twice as he quickly racked his brains.    │
│  ...         │                                                                  │
├──────────────┴──────────────────────────────────── ◀ prev  next ▶ ─────────────┤
│ Book [████░░░░░░░░░░░░░░░░]  24/1413  ┌─[Spc] play/pause  [\] nav─┐  ╭─────────╮│
│                               │[Enter] play ch   [v] voices│  │? debug ││
│                               │[n/p]  next/prev  [B] bmks  │  ├─────────┤│
│                               └───────────────────────────┘  │ q quit ││
│                                                               ╰─────────╯│
╰──────────────────────────────────────────────────────────────────────────────────╯
```

---

## Configuration

Stored at `~/.config/readaloud/config.json`. Edited automatically.

```json
{
  "voice_index": 1,
  "speed_index": 2,
  "theme": "terminal",
  "align": "center",
  "zoom": 0,
  "last_file": "/home/user/books/lotm.epub",
  "bookmarks": {
    "Lord of the Mysteries (Complete).epub": [
      { "chapter": 9, "note": "" }
    ]
  }
}
```

Debug logs: `~/.config/readaloud/debug.log`

---

## How It Works

1. **Parsing** — `ebooklib` reads the EPUB spine and extracts plain text per chapter via a custom HTML stripper. TXT files split by heading patterns or blank lines.
2. **TTS** — chapter text split into ≤4500-char chunks at sentence boundaries, each passed to `pipx run edge-tts` which writes MP3 files to a temp directory.
3. **Playback** — `ffplay` plays all chunks as a concat playlist with an `atempo` filter for speed control. Pause/resume via `SIGSTOP`/`SIGCONT` on the ffplay process.
4. **Highlight** — background thread tracks elapsed time against estimated chars/second (140wpm × speed × 5 chars/word) to approximate the current reading position.

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
pip install --break-system-packages ebooklib
```

**No chapters found in EPUB**
Some EPUBs have non-standard spine structures. Check `~/.config/readaloud/debug.log`. As a fallback, convert to TXT with Calibre:
```bash
ebook-convert book.epub book.txt
```

---

## Why Not SpeakUB?

SpeakUB's Edge-TTS integration hardcodes `pygame.mixer` for audio output, which fails on Arch Linux with PipeWire. The `tts_backend: mpv` config override isn't actually wired up. `readaloud` owns the full pipeline — TTS generation straight to `ffplay`, no intermediate audio framework.

---

## License

MIT
