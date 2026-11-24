#!/bin/bash
# Install (or remove) the 24/7 orchestrator runner as a launchd user agent for one repo.
#   bash install_launchd.sh <repo>            install + start (also starts again after a reboot / login)
#   bash install_launchd.sh <repo> --remove   stop + uninstall
# Crashes restart the runner; a deliberate stop (.agents/orchestrator.stop, or 3 failed sessions) does not.
set -euo pipefail
REPO="$(cd "$1" && pwd)"
NAME="com.claude.orchestrator.$(basename "$REPO")"
PLIST="$HOME/Library/LaunchAgents/$NAME.plist"
DOMAIN="gui/$(id -u)"

if [ "${2:-}" = "--remove" ]; then
	launchctl bootout "$DOMAIN/$NAME" 2>/dev/null || true
	rm -f "$PLIST"
	echo "removed $NAME"
	exit 0
fi

[ -f "$REPO/.claude/orchestrator.md" ] || { echo "no .claude/orchestrator.md in $REPO"; exit 1; }
mkdir -p "$REPO/.agents" "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$NAME</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$HOME/.claude/skills/orchestrator/scripts/runner.py</string>
    <string>$REPO</string>
  </array>
  <key>WorkingDirectory</key><string>$REPO</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$PATH</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>StandardOutPath</key><string>$REPO/.agents/orchestrator-launchd.log</string>
  <key>StandardErrorPath</key><string>$REPO/.agents/orchestrator-launchd.log</string>
</dict>
</plist>
EOF
plutil -lint "$PLIST" >/dev/null
launchctl bootout "$DOMAIN/$NAME" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
echo "started $NAME; log: $REPO/.agents/orchestrator-runner.log; stop: touch $REPO/.agents/orchestrator.stop"
