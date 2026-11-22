#!/usr/bin/env bash
# Idempotent Codespace post-start: desktop processes run in independent
# POSIX sessions so exiting the postStartCommand cannot SIGHUP them.
set -euo pipefail
umask 077
root="$(cd "$(dirname "$0")/.." && pwd)"
state="$HOME/.cache/temptopc"
private="$HOME/.config/temptopc"
mkdir -p "$state" "$private"
chmod 700 "$state" "$private"
export DISPLAY=:9

rotate=0
case "${1:-}" in
  "") ;;
  --rotate-password) rotate=1 ;;
  *) echo "Usage: bash scripts/start-desktop.sh [--rotate-password]" >&2; exit 2 ;;
esac

# SSH host private keys belong to the container, not the image or repository.
sudo -n install -d -m 0755 /run/sshd
sudo -n ssh-keygen -A >/dev/null
sudo -n /usr/sbin/sshd -t
if ! sudo -n service ssh status >/dev/null 2>&1; then
  sudo -n service ssh start >/dev/null
fi

running() {
  local file="$state/$1.pid" pid expected="$2"
  [[ -s "$file" ]] || return 1
  read -r pid < "$file"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ -r "/proc/$pid/cmdline" ]] || return 1
  tr '\0' ' ' < "/proc/$pid/cmdline" | grep -Fq -- "$expected"
}
spawn() {
  local name="$1" marker="$2"
  shift 2
  if running "$name" "$marker"; then return 0; fi
  python3 "$root/scripts/spawn-detached.py" \
    "$state/$name.pid" "$state/$name.log" -- "$@"
}
if (( rotate )); then
  # A live x11vnc reads its password at startup. Retire only a process whose
  # PID and command line are verified; never use pkill -f here.
  if running vnc 'x11vnc'; then
    read -r vnc_pid < "$state/vnc.pid"
    kill -TERM "$vnc_pid"
    for retry in $(seq 1 40); do
      if ! kill -0 "$vnc_pid" 2>/dev/null; then break; fi
      sleep 0.1
    done
  fi
  rm -f -- "$private/vnc.pass" "$private/vnc-password"
fi
if [[ ! -s "$private/vnc.pass" || ! -s "$private/vnc-password" ]]; then
  password="$(openssl rand -hex 4)"
  printf '%s\n' "$password" > "$private/vnc-password"
  if command -v tigervncpasswd >/dev/null; then
    printf '%s\n' "$password" | tigervncpasswd -f > "$private/vnc.pass"
  else
    printf '%s\n' "$password" | vncpasswd -f > "$private/vnc.pass"
  fi
  chmod 600 "$private/vnc.pass" "$private/vnc-password"
  unset password
fi

spawn xvfb 'Xvfb :9' Xvfb :9 -screen 0 1920x1080x24 -nolisten tcp
for retry in $(seq 1 60); do
  if xdpyinfo -display :9 >/dev/null 2>&1; then break; fi
  sleep 0.25
done
xdpyinfo -display :9 >/dev/null || { echo "Xvfb display :9 failed; see $state/xvfb.log" >&2; exit 1; }

spawn xfce 'dbus-run-session -- xfce4-session' env DISPLAY=:9 dbus-run-session -- xfce4-session
spawn vnc 'x11vnc' x11vnc -display :9 -localhost -rfbport 5901 -forever -shared -noxdamage -xkb -rfbauth "$private/vnc.pass"

# Show the actual VNC entry page instead of a websockify root directory listing.
mkdir -p "$state/novnc-web"
if [[ ! -e "$state/novnc-web/vnc.html" ]]; then
  cp -a /usr/share/novnc/. "$state/novnc-web/"
fi
ln -sfn vnc.html "$state/novnc-web/index.html"
spawn novnc 'websockify' websockify --web="$state/novnc-web/" 127.0.0.1:6080 127.0.0.1:5901

bash "$root/scripts/install-shortcuts.sh"
if ! python3 "$root/scripts/check-desktop.py" --wait 20; then
  echo "Desktop not ready. Inspect ~/.cache/temptopc/{xfce,vnc,novnc}.log" >&2
  echo "A webpage on port 6080 alone is not a desktop readiness check." >&2
  exit 1
fi
if ! running xfce 'xfce4-session'; then
  echo "XFCE session stopped; inspect $state/xfce.log" >&2
  exit 1
fi
echo "TempToPC: private Codespaces port 6080 -> /vnc.html"
echo "Password available locally: bash scripts/desktop-status.sh --show-password"
