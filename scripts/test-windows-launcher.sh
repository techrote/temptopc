#!/usr/bin/env bash
# End-to-end offline launcher test. All GH/UI/system calls are mocked.
# This test must NEVER dispatch a real GitHub Actions run.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/gh" "$tmp/home"
export PATH="$tmp/bin:$PATH" HOME="$tmp/home" GH_CONFIG_DIR="$tmp/gh"
export TEST_LOG="$tmp/gh-requests" TEST_REPO="techrote/temptopc"
export TEST_SECRETS="both" TEST_WORKFLOW="active" TEST_ACCEPT="1"
: > "$TEST_LOG"

cat > "$tmp/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TEST_LOG"
case "$1" in
  api)
    case "$2" in
      repos/*/actions/workflows/*)
        [[ "$TEST_WORKFLOW" == active ]] || exit 1
        printf 'active\n' ;;
      repos/*/actions/secrets)
        case "$TEST_SECRETS" in
          both) printf 'TAILSCALE_AUTHKEY\nTEMPTOPC_RDP_PASSWORD\n' ;;
          missing) printf 'TAILSCALE_AUTHKEY\n' ;;
          forbidden) exit 1 ;;
        esac ;;
      *) exit 2 ;;
    esac ;;
  workflow)
    [[ "$2" == run ]] || exit 2 ;;
  run) : ;;
  *) exit 2 ;;
esac
MOCK
cat > "$tmp/bin/zenity" <<'MOCK'
#!/usr/bin/env bash
case " $* " in
  *" --entry "*) echo "$TEST_REPO" ;;
  *" --list "*) echo 30 ;;
  *" --question "*) [[ "$TEST_ACCEPT" == 1 ]] ;;
  *" --error "*) exit 0 ;;
  *) exit 2 ;;
esac
MOCK
cat > "$tmp/bin/xfce4-terminal" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  case "$arg" in
    --command=*)
      cmd="$(printf '%s' "$arg" | cut -c11-)"
      bash -c "$cmd"
      exit $? ;;
  esac
done
exit 2
MOCK
chmod +x "$tmp/bin/"*

fail() { echo "FAIL: $*" >&2; exit 1; }
reset_log() { : > "$TEST_LOG"; }
assert_no_dispatch() {
  if grep -q '^workflow run ' "$TEST_LOG"; then
    fail "Unexpected mocked dispatch: $(cat "$TEST_LOG")"
  fi
}
assert_dispatch() {
  grep -Fq -- "workflow run $1" "$TEST_LOG" || fail "Missing mocked dispatch $1"
}

echo 'Testing TempToPC launch scripts with fake gh, zenity, xfce4-terminal...'
bash "$root/scripts/windows.sh" preflight techrote/temptopc > /dev/null
assert_no_dispatch
reset_log

TEST_SECRETS=missing bash "$root/scripts/windows.sh" start techrote/temptopc 30 > /dev/null 2>&1 && fail 'Missing secret accepted'
assert_no_dispatch
bash "$root/scripts/windows.sh" start 'techrote/invalid;touch' 30 > /dev/null 2>&1 && fail 'Invalid repository accepted'
assert_no_dispatch
bash "$root/scripts/windows.sh" start techrote/temptopc 12 > /dev/null 2>&1 && fail 'Invalid duration accepted'
assert_no_dispatch

reset_log
TEST_ACCEPT=0 bash "$root/scripts/launch-windows-gui.sh" >/dev/null
assert_no_dispatch
reset_log
bash "$root/scripts/launch-windows-gui.sh" >/dev/null
assert_dispatch 'windows-desktop-selftest.yml --repo techrote/temptopc -f minutes=30'

reset_log
bash "$root/scripts/windows.sh" start techrote/PlasmaTerm 60 1234 release.zip 0123456789abcdef0123456789abcdef01234567 > /dev/null
assert_dispatch 'temptopc-acceptance.yml --repo techrote/PlasmaTerm -f minutes=60 -f candidate_run_id=1234'
grep -Fq 'candidate_artifact=release.zip' "$TEST_LOG" || fail 'Missing candidate artifact'
grep -Fq 'candidate_sha=0123456789abcdef0123456789abcdef01234567' "$TEST_LOG" || fail 'Missing source SHA'

reset_log
bash "$root/scripts/windows.sh" start techrote/PlasmaTerm 30 1234 release.zip > /dev/null 2>&1 && fail 'Incomplete identity accepted'
assert_no_dispatch
reset_log
TEST_WORKFLOW=inactive bash "$root/scripts/windows.sh" start techrote/PlasmaTerm 30 > /dev/null 2>&1 && fail 'Inactive workflow accepted'
assert_no_dispatch

echo 'PASS: preflight, secret refusal, validation, GUI cancellation, confirmed GUI dispatch, candidate identity and workflow refusal.'
