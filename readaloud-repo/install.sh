#!/usr/bin/env bash
# readaloud installer
# Detects distro, installs deps, copies script to ~/.local/bin

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}!${RESET} $*"; }
error() { echo -e "${RED}✗${RESET} $*"; exit 1; }
step()  { echo -e "\n${BOLD}$*${RESET}"; }

step "readaloud installer"

# ── Detect distro ────────────────────────────────────────────────────────────
if command -v pacman &>/dev/null; then
    DISTRO="arch"
elif command -v apt &>/dev/null; then
    DISTRO="debian"
elif command -v dnf &>/dev/null; then
    DISTRO="fedora"
else
    warn "Unknown distro — skipping system package install."
    warn "Please ensure ffmpeg and pipx are installed manually."
    DISTRO="unknown"
fi

# ── System packages ───────────────────────────────────────────────────────────
step "Installing system dependencies..."
case "$DISTRO" in
    arch)
        sudo pacman -S --needed --noconfirm python-pipx ffmpeg
        ;;
    debian)
        sudo apt-get update -qq
        sudo apt-get install -y python3-pip pipx ffmpeg
        ;;
    fedora)
        sudo dnf install -y pipx ffmpeg
        ;;
esac

# ── Python packages ───────────────────────────────────────────────────────────
step "Installing Python dependencies..."
if python3 -c "import ebooklib" 2>/dev/null; then
    info "ebooklib already installed"
else
    pip install --break-system-packages ebooklib
    info "ebooklib installed"
fi

# ── edge-tts (pipx run — no explicit install needed) ─────────────────────────
step "Checking edge-tts..."
if pipx run edge-tts --version &>/dev/null; then
    info "edge-tts available via pipx"
else
    warn "pipx run edge-tts failed — trying pipx install..."
    pipx install edge-tts
fi

# ── Install script ────────────────────────────────────────────────────────────
step "Installing readaloud..."
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"
cp readaloud "$INSTALL_DIR/readaloud"
chmod +x "$INSTALL_DIR/readaloud"
info "Installed to $INSTALL_DIR/readaloud"

# ── PATH check ────────────────────────────────────────────────────────────────
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    warn "$INSTALL_DIR is not in your PATH."
    echo "   Add this to your ~/.bashrc or ~/.zshrc:"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
info "Done! Run: readaloud book.epub"
