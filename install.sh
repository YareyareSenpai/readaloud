#!/usr/bin/env bash
# readaloud — Isolated Application Installer
# Creates a self-contained venv at ~/.local/share/readaloud/venv
# and drops a launcher at ~/.local/bin/readaloud
set -euo pipefail

# Resolve the directory this script lives in — works from any CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e " ${GREEN}✓${RESET} $1"; }
warn()  { echo -e " ${YELLOW}!${RESET} $1"; }
error() { echo -e " ${RED}✗${RESET} $1"; exit 1; }
step()  { echo -e "\n${BOLD}>>> $1${RESET}"; }

# pip_install <args...>
# Runs pip install; on failure prints a warning but does NOT abort the script.
pip_install() {
    if ! "$VENV_DIR/bin/pip" install "$@" 2>/dev/null; then
        warn "pip install $* failed — continuing (engine will show unavailable)"
    fi
}

# ── Distro detection ──────────────────────────────────────────────────────────
step "Detecting Operating System"
if   command -v pacman &>/dev/null; then DISTRO="arch"
elif command -v apt    &>/dev/null; then DISTRO="debian"
elif command -v dnf    &>/dev/null; then DISTRO="fedora"
else
    warn "Unknown distribution — ensure ffmpeg, python3, and python3-venv are installed."
    DISTRO="unknown"
fi

# ── Host system packages (only what can't go in a venv) ──────────────────────
step "Installing Host System Dependencies"
case "$DISTRO" in
    arch)
        sudo pacman -S --needed --noconfirm ffmpeg python python-pipx
        ;;
    debian)
        sudo apt-get update -qq
        sudo apt-get install -y ffmpeg python3 python3-venv python3-pip pipx
        ;;
    fedora)
        sudo dnf install -y ffmpeg python3 python3-pip pipx
        ;;
    unknown)
        warn "Skipping host package install — handle manually."
        ;;
esac

# ── Paths ─────────────────────────────────────────────────────────────────────
APP_DIR="$HOME/.local/share/readaloud"
BIN_DIR="$HOME/.local/bin"
VENV_DIR="$APP_DIR/venv"
CFG_DIR="$HOME/.config/readaloud"
MODELS_DIR="$CFG_DIR/models"
VOICES_DIR="$CFG_DIR/voices"

# ── Create directory structure ────────────────────────────────────────────────
step "Creating Application Directories"
mkdir -p "$APP_DIR" "$BIN_DIR" "$MODELS_DIR" "$VOICES_DIR"
info "Config dir:  $CFG_DIR"
info "Models dir:  $MODELS_DIR  (drop Piper .onnx files here)"
info "Voices dir:  $VOICES_DIR  (drop ref.wav here for F5-TTS)"

# ── Virtual environment ───────────────────────────────────────────────────────
step "Creating Isolated Python Virtual Environment"
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel
info "venv: $VENV_DIR"

# ── Core dependencies (always required) ──────────────────────────────────────
step "Installing Core Dependencies"
"$VENV_DIR/bin/pip" install ebooklib edge-tts soundfile
info "ebooklib, edge-tts, soundfile installed"

# ── Format parsers (PDF, DOCX, HTML, RTF, Markdown) ──────────────────────────
step "Installing Format Parsers"
pip_install pdfminer.six && info "pdfminer.six installed (PDF)"
pip_install python-docx  && info "python-docx installed (DOCX)"
pip_install striprtf     && info "striprtf installed (RTF)"
pip_install markdown2    && info "markdown2 installed (Markdown)"
# HTML parsing uses the built-in HTMLParser — no extra package needed
info "HTML parser: built-in (no extra package)"

# ── Kokoro (offline, fast CPU TTS) ───────────────────────────────────────────
step "Installing Kokoro Offline TTS"
PY_VER=$("$VENV_DIR/bin/python" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
info "Python version in venv: $PY_VER"

KOKORO_OK=false
# kokoro 0.9.x caps at Python <3.13 — try native first
if "$VENV_DIR/bin/python" -c "import sys; exit(0 if sys.version_info < (3,13) else 1)" 2>/dev/null; then
    if "$VENV_DIR/bin/pip" install "kokoro>=0.9.4" 2>/dev/null; then
        info "kokoro installed (native)"
        KOKORO_OK=true
    fi
fi

if [ "$KOKORO_OK" = false ]; then
    warn "kokoro>=0.9.4 unavailable for Python $PY_VER (requires <3.13)"
    warn "Falling back to pykokoro — pure-Python ONNX wrapper, same voices"
    if "$VENV_DIR/bin/pip" install pykokoro onnxruntime soundfile 2>/dev/null; then
        info "pykokoro + onnxruntime installed"
        KOKORO_OK=true
    else
        warn "pykokoro install also failed — Kokoro engine will show as unavailable"
        warn "Try manually: $VENV_DIR/bin/pip install pykokoro onnxruntime"
    fi
fi

# ── Piper (offline, ONNX TTS) ────────────────────────────────────────────────
step "Installing Piper Offline TTS"
if "$VENV_DIR/bin/pip" install piper-tts 2>/dev/null; then
    if [ -f "$VENV_DIR/bin/piper" ]; then
        ln -sf "$VENV_DIR/bin/piper" "$BIN_DIR/piper"
        info "piper binary linked to $BIN_DIR/piper"
    else
        warn "piper binary not found in venv after install"
    fi
    info "piper-tts installed"
else
    warn "piper-tts install failed — Piper engine will show as unavailable"
fi
warn "Piper needs .onnx + .onnx.json model pairs in $MODELS_DIR"
echo "      wget -P $MODELS_DIR \\"
echo "        https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
echo "      wget -P $MODELS_DIR \\"
echo "        https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"

# ── F5-TTS (offline, voice cloning) ──────────────────────────────────────────
step "Installing F5-TTS Voice Cloner"
if "$VENV_DIR/bin/pip" install f5-tts 2>/dev/null; then
    if [ -f "$VENV_DIR/bin/f5-tts_infer-cli" ]; then
        ln -sf "$VENV_DIR/bin/f5-tts_infer-cli" "$BIN_DIR/f5-tts_infer-cli"
        info "f5-tts_infer-cli linked to $BIN_DIR/f5-tts_infer-cli"
    fi
    info "f5-tts installed"
    warn "F5-TTS needs a reference audio file at $VOICES_DIR/ref.wav"
    warn "Optional transcript at $VOICES_DIR/ref.txt improves alignment"
    warn "GPU (CUDA) strongly recommended — CPU generation is slow"
else
    warn "F5-TTS install failed (often needs torch/CUDA first) — skipping"
    warn "Install manually: $VENV_DIR/bin/pip install f5-tts"
fi

# ── Deploy application ────────────────────────────────────────────────────────
step "Deploying readaloud"
if [ ! -f "$SCRIPT_DIR/readaloud.py" ]; then
    error "readaloud.py not found in $SCRIPT_DIR — run install.sh from inside the repo"
fi
cp "$SCRIPT_DIR/readaloud.py" "$APP_DIR/readaloud.py"
chmod +x "$APP_DIR/readaloud.py"
info "Deployed readaloud.py to $APP_DIR"

cat << 'EOF' > "$BIN_DIR/readaloud"
#!/usr/bin/env bash
APP_DIR="$HOME/.local/share/readaloud"
exec "$APP_DIR/venv/bin/python" "$APP_DIR/readaloud.py" "$@"
EOF
chmod +x "$BIN_DIR/readaloud"
info "Launcher installed at $BIN_DIR/readaloud"

# ── PATH reminder ─────────────────────────────────────────────────────────────
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    warn "~/.local/bin is not in your PATH"
    echo "  Add to ~/.zshrc or ~/.bashrc:"
    echo '      export PATH="$HOME/.local/bin:$PATH"'
fi

echo ""
echo -e "${BOLD}${GREEN}Installation complete.${RESET}"
echo "  Run: readaloud"
echo "  Or:  readaloud book.epub"
echo ""
echo "  Engine status is shown at startup — unavailable engines are greyed out."
echo "  Piper needs .onnx + .onnx.json model pairs in: $MODELS_DIR"
echo "  F5-TTS needs ref.wav in: $VOICES_DIR"
