#!/usr/bin/env bash
set -euo pipefail
launchctl bootout gui/$(id -u)/com.atlas.ramwatch 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.atlas.ramwatch.plist"
echo "Uninstalled (LaunchAgent removed). Script remains in ~/.atlas/ramwatch if you want to delete it."
