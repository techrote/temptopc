#!/usr/bin/env bash
# Owner-invoked dispatcher. Dispatches the workflow IN THE PROJECT UNDER TEST;
# does not build, tunnel, execute, or open a general-purpose hosted machine.
set -euo pipefail
usage() {
  cat <<'USAGE'
TempToPC - Windows acceptance dispatcher
  windows.sh start [owner/repo] [30|60|120|240|300]
  windows.sh list [owner/repo]
  windows.sh view owner/repo RUN_ID
  windows.sh cancel owner/repo RUN_ID

Project repositories must first install templates/caller.yml as
.github/workflows/temptopc-acceptance.yml, pinning the TempToPC commit.
GitHub authentication with permission to dispatch workflows in that project
is required. A Codespace's default repository token may not have it.
USAGE
}
if [[ $# -eq 0 ]]; then
  usage
  printf '\nRepository to test [techrote/temptopc, for infrastructure self-test]: '
  read -r repository
  repository="${repository:-techrote/temptopc}"
  printf 'Acceptance duration in minutes [60]: '
  read -r duration
  set -- start "$repository" "${duration:-60}"
fi
command -v gh >/dev/null || { echo 'GitHub CLI is missing' >&2; exit 2; }
action="$1"
shift
repo="${1:-techrote/temptopc}"
if [[ ! "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid owner/repository: $repo" >&2
  exit 2
fi
if [[ $# -gt 0 ]]; then shift; fi
workflow='temptopc-acceptance.yml'
if [[ "$repo" == 'techrote/temptopc' ]]; then workflow='windows-desktop-selftest.yml'; fi
case "$action" in
  start)
    duration="${1:-60}"
    case "$duration" in 30|60|120|240|300) ;; *) echo 'Duration must be 30,60,120,240,300' >&2; exit 2;; esac
    if ! gh workflow run "$workflow" --repo "$repo" -f "minutes=$duration"; then
      echo "Dispatch failed. Check that $repo has the workflow on its default branch and that gh has Actions write permission." >&2
      echo 'If using the limited Codespaces GITHUB_TOKEN, authenticate a separate personal gh session with workflow access.' >&2
      echo 'Do not paste an access token into a chat, URL, script or log.' >&2
      exit 1
    fi
    echo "Dispatched a $duration-minute acceptance run for $repo."
    echo "Check: https://github.com/$repo/actions/workflows/$workflow"
    ;;
  list)
    gh run list --repo "$repo" --workflow "$workflow" --limit 10
    ;;
  view)
    run_id="${1:-}"
    [[ "$run_id" =~ ^[1-9][0-9]*$ ]] || { echo 'Provide numeric Actions run ID' >&2; exit 2; }
    gh run view "$run_id" --repo "$repo" --web
    ;;
  cancel)
    run_id="${1:-}"
    [[ "$run_id" =~ ^[1-9][0-9]*$ ]] || { echo 'Provide numeric Actions run ID' >&2; exit 2; }
    printf 'Cancel Actions run %s in %s? Type CANCEL: ' "$run_id" "$repo"
    read -r response
    [[ "$response" == 'CANCEL' ]] || { echo 'Not cancelled'; exit 1; }
    gh run cancel "$run_id" --repo "$repo"
    ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
