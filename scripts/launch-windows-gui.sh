#!/usr/bin/env bash
# XFCE launcher: inspect preflight before dispatching an interactive runner.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v zenity >/dev/null 2>&1; then
  exec xfce4-terminal --hold --command="$root/scripts/windows.sh"
fi
repo="$(zenity --entry --title='TempToPC — Windows acceptance' --width=480 \
  --text='Repository containing the acceptance workflow (owner/repo):' \
  --entry-text='techrote/temptopc')" || exit 0
if [[ ! "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  zenity --error --title='Invalid repository' --text='Use owner/repository (letters, digits, dot, dash, underscore).' || true
  exit 2
fi
duration="$(zenity --list --radiolist --width=360 --height=310 \
  --title='Windows acceptance duration' \
  --text='Choose the maximum interactive session duration:' \
  --column='Select' --column='Minutes' \
  TRUE 30 FALSE 60 FALSE 120 FALSE 240 FALSE 300)" || exit 0
case "$duration" in 30|60|120|240|300) ;; *) exit 2;; esac

if output="$(bash "$root/scripts/windows.sh" preflight "$repo" 2>&1)"; then
  if ! zenity --question --width=510 --title='Confirm temporary Windows runner' \
    --ok-label='Launch Windows' --cancel-label='Cancel' \
    --text="$output

Start one $duration-minute Windows Server RDP acceptance run for $repo?

The Windows desktop will be reachable only through its configured Tailscale network."; then
    exit 0
  fi
else
  zenity --error --width=560 --title='Windows preflight failed' \
    --text="$output

No Windows runner was started. See the indicated project workflow or secret settings." || true
  exit 1
fi

# Keep the result or error visible. No shell characters are admitted in repo.
xfce4-terminal --hold --command="$root/scripts/windows.sh start $repo $duration"
