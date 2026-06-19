#!/usr/bin/env bash
# =============================================================================
# install.sh — Install dx to ~/.local/share/dx (copy, not symlink)
#
# Standalone (curl):
#   curl -fsSL https://raw.githubusercontent.com/ChonlakanSutthimatmongkhol/developer-workflow-cli/main/install.sh | bash
#
# From cloned repo (repo can be deleted after):
#   ./install.sh
# =============================================================================
set -euo pipefail

REPO="ChonlakanSutthimatmongkhol/developer-workflow-cli"
INSTALL_DIR="$HOME/.local/share/dx"
BIN_DIR="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"

# Detect whether we're running from inside the repo or standalone via curl.
# When invoked as `curl ... | bash`, BASH_SOURCE[0] can be unset under `set -u`.
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
  SCRIPT_DIR="$PWD"
fi
if [[ -f "$SCRIPT_DIR/bin/dx" ]]; then
  SRC_DIR="$SCRIPT_DIR"
else
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  echo "⬇️  Downloading dx..."
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" \
    | tar -xz -C "$TMP_DIR" --strip-components=1
  SRC_DIR="$TMP_DIR"
fi

# Copy files to install dir
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$SRC_DIR/bin" "$SRC_DIR/lib" "$SRC_DIR/templates" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/bin/dx"

# Symlink into PATH
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/bin/dx" "$BIN_DIR/dx"

# Add ~/.local/bin to PATH in ~/.zshrc if needed
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -qF "$PATH_LINE" "$ZSHRC" 2>/dev/null; then
  printf '\n%s\n' "$PATH_LINE" >> "$ZSHRC"
  echo "✅ Added ~/.local/bin to PATH in $ZSHRC"
fi

echo "✅ Installed: dx → $BIN_DIR/dx  (files at $INSTALL_DIR)"
echo ""
echo "   source ~/.zshrc   # or open a new terminal"
echo "   dx auth login     # set up credentials"
echo ""
echo "To update:"
echo "   curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash"
echo ""
echo "To uninstall:"
echo "   rm $BIN_DIR/dx && rm -rf $INSTALL_DIR"
