#!/usr/bin/env bash
# Owner-operated, project-scoped Windows acceptance launcher.
set -euo pipefail

usage() {
  cat <<'USAGE'
TempToPC Windows acceptance
  windows.sh preflight [owner/repo]
  windows.sh start [owner/repo] [30|60|120|240|300] [RUN_ID ARTIFACT_NAME SOURCE_SHA]
  windows.sh list [owner/repo]
  windows.sh view owner/repo RUN_ID
  windows.sh cancel owner/repo RUN_ID

A project must have .github/workflows/temptopc-acceptance.yml on its default
branch. The optional three trailing inputs select an already-successful build
artifact from that same project. No launch happens during preflight.
USAGE
}

# Authenticated user login (if present) supersedes the restricted Codespaces
# injected token. Do not echo any credentials or retry ambiguous dispatches.
gh_project() {
  local config="${GH_CONFIG_DIR:-$HOME/.config/gh}"
  if [[ -s "$config/hosts.yml" ]]; then
    env -u GITHUB_TOKEN -u GH_TOKEN gh "$@"
  else
    gh "$@"
  fi
}

valid_repo() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; }
workflow_for() {
  if [[ "$1" == 'techrote/temptopc' ]]; then
    printf '%s\n' 'windows-desktop-selftest.yml'
  else
    printf '%s\n' 'temptopc-acceptance.yml'
  fi
}
preflight() {
  local repo="$1" workflow="$2" state names key missing=0
  printf 'Project: %s\nWorkflow: %s\n' "$repo" "$workflow"
  if ! state="$(gh_project api "repos/$repo/actions/workflows/$workflow" --jq '.state' 2>/dev/null)"; then
    echo "FAIL: GitHub workflow is inaccessible or not installed on $repo's default branch." >&2
    echo "Check https://github.com/$repo/actions, and use gh auth login if authentication is restricted." >&2
    return 1
  fi
  if [[ "$state" != 'active' ]]; then
    printf 'FAIL: workflow state is %s (expected active)\n' "$state" >&2
    return 1
  fi
  echo 'PASS: project workflow is active on GitHub.'
  # The Actions secrets metadata endpoint shows NAMES, never values.
  if names="$(gh_project api "repos/$repo/actions/secrets" --paginate --jq '.secrets[].name' 2>/dev/null)"; then
    for key in TAILSCALE_AUTHKEY TEMPTOPC_RDP_PASSWORD; do
      if grep -Fxq "$key" <<< "$names"; then
        printf 'PASS: %s is configured (value not accessible).\n' "$key"
      else
        printf 'FAIL: %s is missing from project Actions secrets.\n' "$key" >&2
        missing=1
      fi
    done
    (( missing == 0 )) || {
      echo "Open https://github.com/$repo/settings/secrets/actions to configure missing secrets." >&2
      return 1
    }
  else
    echo 'NOTE: this GitHub identity cannot inspect Actions secret names.'
    echo "Confirm both secrets exist at https://github.com/$repo/settings/secrets/actions"
    echo 'The Windows job also checks secret presence before joining Tailscale.'
  fi
  echo 'Preflight complete. No Windows runner has been launched.'
}

if [[ $# -eq 0 ]]; then
  usage
  printf '\nProject [techrote/temptopc]: '
  read -r repository
  printf 'Minutes [30]: '
  read -r minutes
  set -- start "${repository:-techrote/temptopc}" "${minutes:-30}"
fi

command -v gh >/dev/null || {
  echo 'GitHub CLI missing. Restore the Codespace devcontainer.' >&2
  exit 2
}
action="$1"
shift
case "$action" in
  help|-h|--help) usage; exit 0 ;;
  preflight|start|list|view|cancel) ;;
  *) usage >&2; exit 2 ;;
esac
repo="${1:-techrote/temptopc}"
valid_repo "$repo" || { printf 'Invalid project repository: %s\n' "$repo" >&2; exit 2; }
if (( $# )); then shift; fi
workflow="$(workflow_for "$repo")"

case "$action" in
  preflight)
    preflight "$repo" "$workflow"
    ;;
  start)
    duration="${1:-30}"
    case "$duration" in 30|60|120|240|300) ;; *) echo 'Minutes must be 30, 60, 120, 240 or 300.' >&2; exit 2;; esac
    if (( $# )); then shift; fi
    extra=()
    if (( $# == 3 )); then
      [[ "$1" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid Actions producer run ID' >&2; exit 2; }
      [[ "$2" =~ ^[A-Za-z0-9_.-]{1,160}$ ]] || { echo 'Invalid producer artifact name' >&2; exit 2; }
      [[ "$3" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'Expected exact 40-hex producer source SHA' >&2; exit 2; }
      if [[ "$repo" == 'techrote/temptopc' ]]; then
        echo 'The TempToPC self-test cannot stage third-party artifacts.' >&2; exit 2
      fi
      extra=(-f "candidate_run_id=$1" -f "candidate_artifact=$2" -f "candidate_sha=$3")
    elif (( $# != 0 )); then
      echo 'Provide all three optional candidate inputs or none.' >&2
      exit 2
    fi
    preflight "$repo" "$workflow"
    echo 'Dispatching ONE temporary Windows acceptance run.'
    if ! gh_project workflow run "$workflow" --repo "$repo" -f "minutes=$duration" "${extra[@]}"; then
      echo 'Dispatch failed. No success claimed; inspect the project Actions page.' >&2
      echo 'No automatic retry: GitHub might have accepted the original request.' >&2
      exit 1
    fi
    echo "DISPATCH REQUEST ACCEPTED for $repo ($duration minutes)."
    echo "Check https://github.com/$repo/actions/workflows/$workflow for the new run and private RDP details."
    ;;
  list)
    gh_project run list --repo "$repo" --workflow "$workflow" --limit 10
    ;;
  view|cancel)
    run_id="${1:-}"
    [[ "$run_id" =~ ^[1-9][0-9]*$ ]] || { echo 'Provide a numeric Actions run ID' >&2; exit 2; }
    if [[ "$action" == 'view' ]]; then
      gh_project run view "$run_id" --repo "$repo" --web
    else
      printf 'Cancel %s run %s? Type CANCEL: ' "$repo" "$run_id"
      read -r approval
      [[ "$approval" == 'CANCEL' ]] || { echo 'Not cancelled'; exit 1; }
      gh_project run cancel "$run_id" --repo "$repo"
    fi
    ;;
esac
