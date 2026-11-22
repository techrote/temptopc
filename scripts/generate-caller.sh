#!/usr/bin/env bash
# Generates a pinned, audited workflow for a target project; never edits it.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-$root/build/temptopc-acceptance.yml}"
command -v gh >/dev/null || { echo 'Install/authenticate GitHub CLI' >&2; exit 1; }
sha="$(gh api repos/techrote/temptopc/commits/main --jq '.sha')"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "Invalid TempToPC SHA from GitHub" >&2; exit 1; }
mkdir -p "$(dirname "$output")"
sed "s/%TEMPTOPC_COMMIT%/$sha/g" "$root/templates/caller.yml" > "$output"
echo "Generated $output pinned to TempToPC $sha"
echo 'Have the project agent review and commit it at .github/workflows/temptopc-acceptance.yml'
echo 'Then configure project secrets TAILSCALE_AUTHKEY and TEMPTOPC_RDP_PASSWORD.'
