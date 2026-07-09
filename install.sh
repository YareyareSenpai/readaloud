#!/usr/bin/env bash
# readaloud — High-Fidelity Isolated Application Installer
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info() { echo -e " ${GREEN}✓${RESET} $1"; }
warn() { echo -e " ${YELLOW}!${RESET} $1"; }
error() { echo -e " ${RED}✗${RESET} $1"; exit 1; }
step() { echo -e "\n${BOLD}>>> $1${RESET}"; }

step "Detecting Operating System Environment"
if command -v pacman &>/dev/null; then DISTRO="arch"
elif command -v apt &>/dev/null; then DISTRO="debian"
elif command -v dnf &>/dev/null; then DISTRO="fedora"
else
    warn "Unknown distribution. Ensure ffmpeg is installed manually."
    DISTRO="unknown"
fi

step "Installing Host Base Dependencies"
case "$DISTRO" in
    arch) sudo pacman -S --needed --noconfirm ffmpeg python ;;
    debian) sudo apt-get update -qq && sudo apt-get install -y ffmpeg python3-venv python3-pip ;;
    fedora) sudo dnf install -y ffmpeg python3 ;;
esac

APP_DIR="$HOME/.local/share/readaloud"
BIN_DIR="$HOME/.local/bin"
VENV_DIR="$APP_DIR/venv"

step "Constructing Isolated Application Sandbox Environment"
mkdir -p "$APP_DIR" "$BIN_DIR"
python3 -m venv "$VENV_DIR"

step "Injecting Core Python Dependencies into Sandbox"
"$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel
"$VENV_DIR/bin/pip" install ebooklib edge-tts pykokoro onnxruntime

step "Deploying Precompiled Language Splitter Weights (Python 3.14 Safe)"
# Directly installs pure wheel to bypass standard Cython syntax building traps
"$VENV_DIR/bin/pip" install "https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl"

step "Installing Executable Wrapper Logic"
cp readaloud.py "$APP_DIR/readaloud.py"
chmod +x "$APP_DIR/readaloud.py"

cat << 'EOF' > "$BIN_DIR/readaloud"
#!/usr/bin/env bash
APP_DIR="$HOME/.local/share/readaloud"
exec "$APP_DIR/venv/bin/python" "$APP_DIR/readaloud.py" "$@"
EOF
chmod +x "$BIN_DIR/readaloud"

info "Application successfully isolated and deployed to $BIN_DIR/readaloud"