#!/usr/bin/env bash
# uninstall.sh — Removes the resolution-fixer LaunchAgent.

set -euo pipefail

LABEL="com.resolution-fixer"
PLIST_DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"

echo "=== resolution-fixer uninstaller ==="
echo ""

if launchctl list | grep -q "$LABEL"; then
    launchctl unload -w "$PLIST_DEST" 2>/dev/null || true
    echo "✓ LaunchAgent unloaded"
else
    echo "  (LaunchAgent was not loaded)"
fi

if [[ -f "$PLIST_DEST" ]]; then
    rm -f "$PLIST_DEST"
    echo "✓ Removed $PLIST_DEST"
else
    echo "  (Plist not found at $PLIST_DEST)"
fi

echo ""
echo "=== Uninstall complete ==="
echo "Note: displayplacer, logs, and the project source files were NOT removed."
