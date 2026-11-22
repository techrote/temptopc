#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
desktop="$HOME/Desktop"
mkdir -p "$desktop"
cat > "$desktop/Launch Windows Acceptance.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Launch Windows Acceptance
Comment=Dispatch a manual Windows acceptance workflow in the selected project
Exec=xfce4-terminal --hold --command=$root/scripts/windows.sh
Terminal=false
Icon=utilities-terminal
Categories=Development;
EOF
cat > "$desktop/TempToPC Desktop Status.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=TempToPC Desktop Status
Exec=xfce4-terminal --hold --command=$root/scripts/desktop-status.sh
Terminal=false
Icon=computer
Categories=System;
EOF
chmod 755 "$desktop/Launch Windows Acceptance.desktop" "$desktop/TempToPC Desktop Status.desktop"
if command -v gio >/dev/null 2>&1; then
  gio set "$desktop/Launch Windows Acceptance.desktop" metadata::trusted true >/dev/null 2>&1 || true
  gio set "$desktop/TempToPC Desktop Status.desktop" metadata::trusted true >/dev/null 2>&1 || true
fi
