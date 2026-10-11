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

WARNINGS=0
# Optional-install pip output goes here instead of /dev/null so a failed
# engine install can be diagnosed afterwards.
LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/readaloud-install.XXXXXX")"

info()  { echo -e " ${GREEN}✓${RESET} $1"; }
warn()  { echo -e " ${YELLOW}!${RESET} $1"; WARNINGS=$((WARNINGS + 1)); }
error() { echo -e " ${RED}✗${RESET} $1"; exit 1; }
step()  { echo -e "\n${BOLD}>>> $1${RESET}"; }

# pip_install <args...>
# Optional install: returns 0 on success, 1 on failure (after a warning that
# points at the log). Never aborts the script — always call it inside `if`.
pip_install() {
    if "$VENV_DIR/bin/pip" install "$@" >>"$LOG_FILE" 2>&1; then
        return 0
    fi
    warn "pip install $* failed — see $LOG_FILE"
    return 1
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

command -v ffplay &>/dev/null \
    || warn "ffplay not found — readaloud needs it for playback (it ships with ffmpeg)"

step "Checking Python"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null \
    || error "Python 3.10+ is required (found: $(python3 -V 2>&1 || echo none))"
info "$(python3 -V)"

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
EDGE_VER="$("$VENV_DIR/bin/python" -c "from importlib.metadata import version; print(version('edge-tts'))" 2>/dev/null || echo "?")"
info "edge-tts $EDGE_VER (readaloud applies the Edge 403 endpoint workaround at runtime for versions <= 7.2.8)"
info "Azure TTS: no package needed — set AZURE_SPEECH_KEY + AZURE_SPEECH_REGION (see below)"

# ── Format parsers (PDF, DOCX, HTML, RTF, Markdown) ──────────────────────────
step "Installing Format Parsers"
if pip_install pdfminer.six; then info "pdfminer.six installed (PDF)"; fi
if pip_install python-docx;  then info "python-docx installed (DOCX)"; fi
if pip_install striprtf;     then info "striprtf installed (RTF)"; fi
if pip_install markdown2;    then info "markdown2 installed (Markdown)"; fi
# HTML parsing uses the built-in HTMLParser — no extra package needed
info "HTML parser: built-in (no extra package)"

# ── Kokoro (offline, fast CPU TTS) ───────────────────────────────────────────
step "Installing Kokoro Offline TTS"
PY_VER="$("$VENV_DIR/bin/python" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")"
info "Python version in venv: $PY_VER"

KOKORO_OK=false
# kokoro 0.9.x caps at Python <3.13 — try native first
if "$VENV_DIR/bin/python" -c "import sys; sys.exit(0 if sys.version_info < (3,13) else 1)"; then
    if pip_install "kokoro>=0.9.4" onnxruntime soundfile; then
        info "kokoro installed (native)"
        KOKORO_OK=true
    fi
fi

if [ "$KOKORO_OK" = false ]; then
    warn "kokoro>=0.9.4 unavailable for Python $PY_VER (requires <3.13)"
    warn "Falling back to pykokoro — pure-Python ONNX wrapper, same voices"
    if pip_install pykokoro onnxruntime soundfile; then
        info "pykokoro + onnxruntime installed"
        KOKORO_OK=true
    else
        warn "Kokoro engine will show as unavailable"
        warn "Try manually: $VENV_DIR/bin/pip install pykokoro onnxruntime"
    fi
fi

# Kokoro synthesis needs the small spaCy English model (not `md`)
if [ "$KOKORO_OK" = true ]; then
    if "$VENV_DIR/bin/python" -c "import sys, spacy.util as u; sys.exit(0 if u.is_package('en_core_web_sm') else 1)" 2>/dev/null; then
        info "spaCy en_core_web_sm already present"
    elif "$VENV_DIR/bin/python" -m spacy download en_core_web_sm >>"$LOG_FILE" 2>&1; then
        info "spaCy en_core_web_sm installed"
    else
        warn "spaCy model download failed — Kokoro will detect but fail to synthesise"
        warn "Run: $VENV_DIR/bin/python -m spacy download en_core_web_sm"
    fi
fi

# ── Piper (offline, ONNX TTS) ────────────────────────────────────────────────
step "Installing Piper Offline TTS"
if pip_install piper-tts; then
    if [ -f "$VENV_DIR/bin/piper" ]; then
        ln -sf "$VENV_DIR/bin/piper" "$BIN_DIR/piper"
        info "piper binary linked to $BIN_DIR/piper"
    else
        warn "piper binary not found in venv after install"
    fi
    info "piper-tts installed"
else
    warn "Piper engine will show as unavailable"
fi
warn "Piper needs .onnx + .onnx.json model pairs in $MODELS_DIR"
echo "      wget -P $MODELS_DIR \\"
echo "        https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
echo "      wget -P $MODELS_DIR \\"
echo "        https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"

# ── F5-TTS (offline, voice cloning) ──────────────────────────────────────────
step "Installing F5-TTS Voice Cloner"
if pip_install f5-tts; then
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
"$VENV_DIR/bin/python" -c "import ast, sys; ast.parse(open(sys.argv[1]).read())" "$SCRIPT_DIR/readaloud.py" \
    || error "readaloud.py has a syntax error — refusing to deploy it"
cp "$SCRIPT_DIR/readaloud.py" "$APP_DIR/readaloud.py"
chmod +x "$APP_DIR/readaloud.py"
info "Deployed readaloud.py to $APP_DIR"

cat << 'LAUNCHER' > "$BIN_DIR/readaloud"
#!/usr/bin/env bash
APP_DIR="$HOME/.local/share/readaloud"
exec "$APP_DIR/venv/bin/python" "$APP_DIR/readaloud.py" "$@"
LAUNCHER
chmod +x "$BIN_DIR/readaloud"
info "Launcher installed at $BIN_DIR/readaloud"

# ── PATH reminder ─────────────────────────────────────────────────────────────
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    warn "~/.local/bin is not in your PATH"
    echo "  Add to ~/.zshrc or ~/.bashrc:"
    echo '      export PATH="$HOME/.local/bin:$PATH"'
    echo "  Fish:  fish_add_path ~/.local/bin"
fi

echo ""
echo -e "${BOLD}${GREEN}Installation complete.${RESET}"
echo "  Run: readaloud"
echo "  Or:  readaloud book.epub"
echo ""
echo "  Engine status is shown at startup — unavailable engines are greyed out."
echo "  Piper needs .onnx + .onnx.json model pairs in: $MODELS_DIR"
echo "  F5-TTS needs ref.wav in: $VOICES_DIR"
echo "  Azure TTS (optional) needs AZURE_SPEECH_KEY + AZURE_SPEECH_REGION, or $CFG_DIR/azure.json"
echo "  Check what was detected with: readaloud --debug"

if [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo -e " ${YELLOW}!${RESET} $WARNINGS warning(s) above — pip details: $LOG_FILE"
else
    rm -f "$LOG_FILE"
fi
