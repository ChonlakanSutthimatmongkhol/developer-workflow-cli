#!/usr/bin/env bash
# =============================================================================
# install.sh — One-time setup: symlink bin/dx into PATH
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/dx"

mkdir -p "$BIN_DIR"
chmod +x "$SCRIPT_DIR/bin/dx"
ln -sf "$SCRIPT_DIR/bin/dx" "$TARGET"

# Add ~/.local/bin to PATH in ~/.zshrc if not already present
ZSHRC="$HOME/.zshrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -qF "$PATH_LINE" "$ZSHRC" 2>/dev/null; then
  echo "" >> "$ZSHRC"
  echo "$PATH_LINE" >> "$ZSHRC"
  echo "✅ Added ~/.local/bin to PATH in $ZSHRC"
fi

echo "✅ Installed! dx → $TARGET"
echo ""
echo "👉 Run: dx auth login"
echo ""
echo "To update (no reinstall needed — symlink picks up changes automatically):"
echo "  cd $SCRIPT_DIR && git pull"
echo ""
echo "To uninstall:"
echo "  rm $TARGET"
