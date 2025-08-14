#!/usr/bin/env bash
set -euo pipefail
LOGDIR="$HOME/.atlas/ramwatch/logs"
mkdir -p "$LOGDIR"
install -m 755 scripts/ramwatch.sh "$HOME/.atlas/ramwatch/ramwatch.sh"
plutil -lint launchagents/com.atlas.ramwatch.plist >/dev/null
install -m 644 launchagents/com.atlas.ramwatch.plist "$HOME/Library/LaunchAgents/com.atlas.ramwatch.plist"
launchctl bootout gui/$(id -u)/com.atlas.ramwatch 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/com.atlas.ramwatch.plist"
launchctl kickstart -k gui/$(id -u)/com.atlas.ramwatch
echo "Installed. Log: $LOGDIR/ramwatch.log"
