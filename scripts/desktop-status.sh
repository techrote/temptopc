#!/usr/bin/env bash
set -euo pipefail
private="$HOME/.config/temptopc"
state="$HOME/.cache/temptopc"
if [[ "${1:-}" == "--show-password" ]]; then
  if [[ ! -s "$private/vnc-password" ]]; then
    echo 'VNC credential not created; run scripts/start-desktop.sh' >&2
    exit 1
  fi
  cat "$private/vnc-password"
  exit 0
fi
for service in xvfb xfce vnc novnc; do
  file="$state/$service.pid"
  if [[ -r "$file" ]] && kill -0 "$(cat "$file")" 2>/dev/null; then
    printf '%-6s running\n' "$service"
  else
    printf '%-6s stopped\n' "$service"
  fi
done
echo 'Open private forwarded port 6080 -> /vnc.html; VNC TCP port 5901 never forwarded.'
echo 'To show your VNC password: bash scripts/desktop-status.sh --show-password'
