#!/usr/bin/env bash
# install.sh — Sets up resolution-fixer as a login LaunchAgent.
# Run once from the project directory: bash install.sh

set -euo pipefail

LABEL="com.resolution-fixer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR"
PLIST_SRC="$SCRIPT_DIR/${LABEL}.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs"

echo "=== resolution-fixer installer ==="
echo ""

# ── 1. Check for displayplacer ────────────────────────────────────────────────
if ! command -v displayplacer &>/dev/null; then
    echo "displayplacer is not installed."
    if command -v brew &>/dev/null; then
        echo "Installing displayplacer via Homebrew…"
        brew install jakehilborn/jakehilborn/displayplacer
    else
        echo ""
        echo "Homebrew not found. Please install displayplacer manually:"
        echo "  https://github.com/jakehilborn/displayplacer"
        echo ""
        echo "Or install Homebrew first: https://brew.sh"
        exit 1
    fi
else
    echo "✓ displayplacer found: $(command -v displayplacer)"
fi

# ── 2. Compile the dynamic-resolution helper ─────────────────────────────────
echo "Compiling set-dynamic-resolution helper…"
cc -framework CoreGraphics \
    -o "$SCRIPT_DIR/set-dynamic-resolution" \
    "$SCRIPT_DIR/set-dynamic-resolution.c"
echo "✓ Compiled set-dynamic-resolution"

# ── 3. Make the main script executable ───────────────────────────────────────
chmod +x "$SCRIPT_DIR/resolution-fixer.sh"
echo "✓ Made resolution-fixer.sh executable"

# ── 3. Show current display info ─────────────────────────────────────────────
echo ""
echo "── Available displays ──────────────────────────────────────────────"
displayplacer list 2>/dev/null | grep -E "^(Persistent screen id|Resolution|Hertz|Scaling)" | sed 's/^/  /'
echo "────────────────────────────────────────────────────────────────────"
echo ""

# ── 5. Write the LaunchAgent plist ───────────────────────────────────────────
mkdir -p "$HOME/Library/LaunchAgents"

sed \
    -e "s|INSTALL_DIR_PLACEHOLDER|${INSTALL_DIR}|g" \
    -e "s|LOG_DIR_PLACEHOLDER|${LOG_DIR}|g" \
    "$PLIST_SRC" > "$PLIST_DEST"

echo "✓ LaunchAgent plist written to $PLIST_DEST"

# ── 6. Load the LaunchAgent ───────────────────────────────────────────────────
# Unload first in case a previous version was already loaded
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load -w "$PLIST_DEST"

echo "✓ LaunchAgent loaded (will also start automatically at login)"
echo ""
echo "Logs:"
echo "  Stdout : $LOG_DIR/resolution-fixer.log"
echo "  Stderr : $LOG_DIR/resolution-fixer.error.log"
echo ""
echo "To check status : launchctl list | grep resolution-fixer"
echo "To view logs    : tail -f ~/Library/Logs/resolution-fixer.log"
echo "To uninstall    : bash $SCRIPT_DIR/uninstall.sh"
echo ""
echo "=== Installation complete ==="
