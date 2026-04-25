#!/usr/bin/env bash
set -euo pipefail

WHISPER_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_DIR="$WHISPER_DIR/tools/whisper-paste"
MODEL_NAME="large-v3-turbo"
HOTKEY="cmd + alt - space"

red()   { printf "\033[1;31m%s\033[0m\n" "$*"; }
green() { printf "\033[1;32m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
step()  { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }

# ── Preflight ────────────────────────────────────────────────────────────────

if [[ "$(uname -m)" != "arm64" ]]; then
    red "whisper-paste is optimised for Apple Silicon (arm64). Aborting."
    exit 1
fi

if [[ "$(uname)" != "Darwin" ]]; then
    red "whisper-paste requires macOS. Aborting."
    exit 1
fi

bold "whisper-paste installer"
echo "Repo: $WHISPER_DIR"
echo ""

# ── Homebrew ─────────────────────────────────────────────────────────────────

step "Checking Homebrew"
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
green "Homebrew ready"

# ── Dependencies ─────────────────────────────────────────────────────────────

step "Installing dependencies"
brew install cmake sdl2 sox koekeishiya/formulae/skhd
green "Dependencies ready"

# ── Build whisper.cpp ─────────────────────────────────────────────────────────

step "Building whisper.cpp (Metal + SDL2)"
cmake -B "$WHISPER_DIR/build" -DGGML_METAL=ON -DWHISPER_SDL2=ON -S "$WHISPER_DIR" 2>&1 | tail -5
cmake --build "$WHISPER_DIR/build" --config Release -j"$(sysctl -n hw.logicalcpu)" 2>&1 | tail -5
green "Build complete"

# ── Model ────────────────────────────────────────────────────────────────────

step "Downloading model ($MODEL_NAME)"
if [[ ! -f "$WHISPER_DIR/models/ggml-${MODEL_NAME}.bin" ]]; then
    bash "$WHISPER_DIR/models/download-ggml-model.sh" "$MODEL_NAME"
else
    echo "Model already present, skipping download."
fi
green "Model ready"

# ── Install whisper-paste ─────────────────────────────────────────────────────

step "Testing whisper-paste"
bash "$SCRIPT_DIR/test-whisper-paste"

step "Installing whisper-paste"
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/whisper-paste" "$HOME/.local/bin/whisper-paste"
chmod +x "$HOME/.local/bin/whisper-paste"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    echo "Added ~/.local/bin to PATH in ~/.zshrc"
fi
green "whisper-paste installed to ~/.local/bin"

# ── Style config ──────────────────────────────────────────────────────────────

step "Setting up style config"
STYLE_DIR="$HOME/.config/whisper-dictate/styles"
mkdir -p "$STYLE_DIR"
if [[ ! -f "$STYLE_DIR/casual.txt" ]]; then
    cp "$SCRIPT_DIR/styles/casual-example.txt" "$STYLE_DIR/casual.txt"
    echo "Copied casual-example.txt → ~/.config/whisper-dictate/styles/casual.txt"
    echo "Edit that file to match your own writing style."
else
    echo "casual.txt already exists, leaving it untouched."
fi
green "Style config ready"

# ── WHISPER_DIR in shell config ───────────────────────────────────────────────

step "Configuring WHISPER_DIR"
SHELL_RC="$HOME/.zshrc"
EXPORT_LINE="export WHISPER_DIR=\"$WHISPER_DIR\""
if ! grep -qF "WHISPER_DIR" "$SHELL_RC" 2>/dev/null; then
    echo "$EXPORT_LINE" >> "$SHELL_RC"
    echo "Added WHISPER_DIR to $SHELL_RC"
else
    echo "WHISPER_DIR already set in $SHELL_RC"
fi

# ── skhd ─────────────────────────────────────────────────────────────────────

step "Configuring skhd hotkey ($HOTKEY)"
SKHDRC="$HOME/.skhdrc"
SKHD_LINE="$HOTKEY : WHISPER_DIR=\"$WHISPER_DIR\" $HOME/.local/bin/whisper-paste"
if [[ ! -f "$SKHDRC" ]] || ! grep -qF "whisper-paste" "$SKHDRC"; then
    echo "$SKHD_LINE" >> "$SKHDRC"
    echo "Added hotkey to $SKHDRC"
else
    echo "whisper-paste hotkey already in $SKHDRC"
fi
skhd --start-service 2>/dev/null || skhd --restart-service 2>/dev/null || true
green "skhd configured and running"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green "Installation complete!"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Two permissions required (one-time, manual):"
echo ""
echo "  1. Microphone"
echo "     System Settings → Privacy & Security → Microphone"
echo "     → enable Terminal (or whichever app triggers the hotkey)"
echo ""
echo "  2. Accessibility (for auto-paste)"
echo "     System Settings → Privacy & Security → Accessibility"
echo "     → add /opt/homebrew/Cellar/skhd/$(skhd --version 2>/dev/null | awk '{print $NF}')/bin/skhd"
echo "     (use the real binary path, not the symlink)"
echo ""
echo "Usage:"
echo "  Hotkey: $(echo "$HOTKEY" | sed 's/cmd/⌘/;s/alt/⌥/;s/ - / + /;s/space/Space/')"
echo "  Or from terminal: whisper-paste"
echo ""
echo "Customise your casual writing style:"
echo "  \$EDITOR ~/.config/whisper-dictate/styles/casual.txt"
echo ""
