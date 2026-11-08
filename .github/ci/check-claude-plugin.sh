#!/usr/bin/env bash
# Validates the plugin and its marketplace, installs the plugin from the checkout the way a user
# installs it, and checks the install lists the peekaboot skill.
#
#   check-claude-plugin.sh <repo-root>
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "${1:?usage: check-claude-plugin.sh <repo-root>}" && pwd)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# A throwaway home, so neither the marketplace nor the install touches the caller's own setup.
export HOME="$work/home"
# The CLI's own variables go too. Some redirect where it writes, such as CLAUDE_CONFIG_DIR, and
# some add plugins the listing would then show, such as CLAUDE_CODE_PLUGIN_DIRS.
mapfile -t cli_variables < <(compgen -e | grep -E '^(CLAUDE|ANTHROPIC)' || true)
unset "${cli_variables[@]}"
mkdir -p "$HOME"
source="$work/source"
"$here/copy-plugin-source.sh" "$repo" "$source"

# --strict fails on every warning too. The report goes to stdout, so it is moved to stderr.
if ! report=$(claude plugin validate --strict "$source"); then
  echo "claude plugin validate --strict found problems:" >&2
  printf '%s\n' "$report" >&2
  exit 1
fi

claude plugin marketplace add "$source" > /dev/null
claude plugin install peekaboot@peekaboot > /dev/null

if ! claude plugin list --json | jq -e 'any(.[]; .id == "peekaboot@peekaboot" and .enabled)' > /dev/null; then
  echo "peekaboot@peekaboot is not installed and enabled" >&2
  exit 1
fi

details=$(claude plugin details peekaboot)
if ! grep -Eq '^ +Skills \(1\) +peekaboot$' <<<"$details"; then
  echo "the plugin does not list the peekaboot skill:" >&2
  echo "$details" >&2
  exit 1
fi

echo "ok: peekaboot@peekaboot installs and lists the peekaboot skill"
