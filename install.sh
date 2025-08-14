#!/usr/bin/env bash
set -euo pipefail
mkdir -p ~/.atlas/ramwatch/logs
install -m 755 scripts/ramwatch.sh ~/.atlas/ramwatch/ramwatch.sh
install -m 644 launchagents/com.atlas.ramwatch.plist ~/Library/LaunchAgents/com.atlas.ramwatch.plist
plutil -lint ~/Library/LaunchAgents/com.atlas.ramwatch.plist
launchctl bootout gui/$(id -u)/com.atlas.ramwatch 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.atlas.ramwatch.plist
launchctl kickstart -k gui/$(id -u)/com.atlas.ramwatch
echo "Installed. Log: ~/.atlas/ramwatch/logs/ramwatch.log"
