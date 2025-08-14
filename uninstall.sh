#!/usr/bin/env bash
set -euo pipefail
launchctl bootout gui/$(id -u)/com.atlas.ramwatch 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.atlas.ramwatch.plist
rm -rf ~/.atlas/ramwatch
echo "Uninstalled."
