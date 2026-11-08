#!/usr/bin/env bash
# Checks that every manifest names the same plugin version. Bumping it is a manual step, so a
# file left behind would ship two versions of one plugin.
#
#   check-manifest-versions.sh <repo-root>
set -euo pipefail

repo=${1:?usage: check-manifest-versions.sh <repo-root>}
readonly MANIFESTS=(.claude-plugin/plugin.json .codex-plugin/plugin.json)

declare -A versions
for manifest in "${MANIFESTS[@]}"; do
  if [ -f "$repo/$manifest" ]; then
    versions[$manifest]=$(jq -r '.version // "none"' "$repo/$manifest")
  else
    versions[$manifest]=missing
  fi
done

distinct=$(printf '%s\n' "${versions[@]}" | sort -u)
if [ "$(wc -l <<<"$distinct")" -ne 1 ] || [ "$distinct" = none ] || [ "$distinct" = missing ]; then
  echo "the manifests do not name one version:" >&2
  for manifest in "${MANIFESTS[@]}"; do
    echo "$manifest: ${versions[$manifest]}" >&2
  done
  exit 1
fi
echo "ok: every manifest names version $distinct"
