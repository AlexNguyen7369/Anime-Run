#!/bin/bash
# Install (or remove) the 24/7 orchestrator runner as a systemd user service for one repo (Linux).
#   bash install_systemd.sh <repo>            install + start (also starts again after a reboot)
#   bash install_systemd.sh <repo> --remove   stop + uninstall
# Crashes restart the runner; a deliberate stop (.agents/orchestrator.stop, or 3 failed sessions) does not.
set -euo pipefail
REPO="$(cd "$1" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="claude-orchestrator-$(basename "$REPO")"
UNIT="$HOME/.config/systemd/user/$NAME.service"

if [ "${2:-}" = "--remove" ]; then
	systemctl --user disable --now "$NAME" 2>/dev/null || true
	rm -f "$UNIT"
	systemctl --user daemon-reload
	echo "removed $NAME"
	exit 0
fi

[ -f "$REPO/.claude/orchestrator.md" ] || { echo "no .claude/orchestrator.md in $REPO"; exit 1; }
command -v claude >/dev/null || { echo "claude is not on PATH"; exit 1; }
mkdir -p "$REPO/.agents" "$(dirname "$UNIT")"
cat > "$UNIT" <<UNIT_EOF
[Unit]
Description=Claude orchestrator runner for $REPO

[Service]
WorkingDirectory=$REPO
Environment=PATH=$PATH
ExecStart=$(command -v python3) $HERE/runner.py $REPO
Restart=on-failure
RestartSec=30
StandardOutput=append:$REPO/.agents/orchestrator-systemd.log
StandardError=append:$REPO/.agents/orchestrator-systemd.log

[Install]
WantedBy=default.target
UNIT_EOF
systemctl --user daemon-reload
systemctl --user enable --now "$NAME"
# Without linger the service stops when the last login session of this user ends.
loginctl enable-linger "$USER" 2>/dev/null || echo "run: sudo loginctl enable-linger $USER"
echo "started $NAME; log: $REPO/.agents/orchestrator-runner.log; stop: touch $REPO/.agents/orchestrator.stop"
