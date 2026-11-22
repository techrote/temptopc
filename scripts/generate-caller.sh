#!/usr/bin/env bash
# Generates a pinned, audited workflow for a target project; never edits it.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-$root/build/temptopc-acceptance.yml}"
command -v git >/dev/null || { echo 'Git is required' >&2; exit 1; }
[[ "$(git -C "$root" remote get-url origin)" == *'techrote/temptopc'* ]] || { echo 'This must be a trusted TempToPC checkout' >&2; exit 1; }
sha="$(git -C "$root" rev-parse HEAD)"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "Invalid TempToPC SHA from GitHub" >&2; exit 1; }
mkdir -p "$(dirname "$output")"
sed "s/%TEMPTOPC_COMMIT%/$sha/g" "$root/templates/caller.yml" > "$output"
echo "Generated $output pinned to current checked-out TempToPC commit $sha"
echo 'Run git pull --ff-only on main before generating to select the latest accepted implementation.'
echo 'Have the project agent review and commit it at .github/workflows/temptopc-acceptance.yml'
echo 'Then configure project secrets TAILSCALE_AUTHKEY and TEMPTOPC_RDP_PASSWORD.'
