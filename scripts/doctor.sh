#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for exe in Xvfb xdpyinfo x11vnc websockify xfce4-session xfce4-terminal gh git python3 openssl sudo; do
  command -v "$exe" >/dev/null || { echo "Missing command: $exe" >&2; exit 1; }
done
command -v tigervncpasswd >/dev/null || command -v vncpasswd >/dev/null || {
  echo 'Missing TigerVNC password writer' >&2; exit 1;
}
python3 -m json.tool .devcontainer/devcontainer.json >/dev/null
for file in scripts/*.sh; do bash -n "$file"; done
grep -q '"visibility": "private"' .devcontainer/devcontainer.json
echo 'TempToPC container preflight PASS (source checks only; no remote desktop has been exercised)'
