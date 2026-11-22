#!/usr/bin/env bash
# Minimal XFCE/Zenity GUI; uses the same authenticated project dispatcher.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v zenity >/dev/null; then
  exec xfce4-terminal --hold --command="$root/scripts/windows.sh"
fi
repo="$(zenity --entry --title='TempToPC — Windows acceptance' --width=440 \
  --text='Choose the project repository whose acceptance workflow should run:' \
  --entry-text='techrote/temptopc')" || exit 0
if [[ ! "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  zenity --error --title='Invalid repository' --text='Use owner/repository (letters, digits, dot, dash, underscore).' || true
  exit 2
fi
duration="$(zenity --list --radiolist --width=340 --height=300 \
  --title='Acceptance duration' --text='Choose a bounded Windows test session:' \
  --column='Select' --column='Minutes' \
  TRUE 60 FALSE 30 FALSE 120 FALSE 240 FALSE 300)" || exit 0
case "$duration" in 30|60|120|240|300) ;; *) exit 2;; esac
xfce4-terminal --hold --command="$root/scripts/windows.sh start $repo $duration"
