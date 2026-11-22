#!/usr/bin/env bash
# Idempotent Codespace post-start hook: start only localhost-facing services.
set -euo pipefail
umask 077
root="$(cd "$(dirname "$0")/.." && pwd)"
state="$HOME/.cache/temptopc"
private="$HOME/.config/temptopc"
mkdir -p "$state" "$private"
chmod 700 "$state" "$private"
export DISPLAY=:9

# New container host keys are generated at runtime, never committed to the image.
sudo -n install -d -m 0755 /run/sshd
sudo -n ssh-keygen -A >/dev/null
sudo -n /usr/sbin/sshd -t
if ! sudo -n service ssh status >/dev/null 2>&1; then
  sudo -n service ssh start >/dev/null
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

# Do not trust a stale PID or signal unrelated processes. A dead child is
# replaced on Codespace restart or by rerunning this script manually.
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
  nohup "$@" > "$state/$name.log" 2>&1 < /dev/null &
  printf '%s\n' "$!" > "$state/$name.pid"
}
spawn xvfb 'Xvfb :9' Xvfb :9 -screen 0 1920x1080x24 -nolisten tcp
for attempt in $(seq 1 40); do
  if xdpyinfo -display :9 >/dev/null 2>&1; then break; fi
  sleep 0.25
done
xdpyinfo -display :9 >/dev/null
spawn xfce 'xfce4-session' env DISPLAY=:9 dbus-run-session -- xfce4-session
spawn vnc 'x11vnc' x11vnc -display :9 -localhost -rfbport 5901 -forever -shared -noxdamage -xkb -rfbauth "$private/vnc.pass"
spawn novnc 'websockify' websockify --web=/usr/share/novnc/ 127.0.0.1:6080 127.0.0.1:5901

bash "$root/scripts/install-shortcuts.sh"
for attempt in $(seq 1 40); do
  if python3 -c 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:6080/vnc.html",timeout=2).close()' 2>/dev/null; then
    echo 'TempToPC desktop: http://127.0.0.1:6080/vnc.html (open PRIVATE forwarded port 6080)'
    echo 'VNC password: run scripts/desktop-status.sh --show-password in the Codespace terminal'
    exit 0
  fi
  sleep 0.25
done
echo "noVNC failed to start; inspect $state/novnc.log" >&2
exit 1
