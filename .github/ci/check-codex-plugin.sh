#!/usr/bin/env bash
# Installs the plugin from the checkout's .agents marketplace the way a user installs it, and
# checks the install offers the peekaboot skill.
#
#   check-codex-plugin.sh <repo-root>
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "${1:?usage: check-codex-plugin.sh <repo-root>}" && pwd)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# A throwaway home, so neither the marketplace nor the install touches the caller's own setup.
export HOME="$work/home"
# The CLI's own variables go too. Some redirect where it writes, such as CODEX_HOME.
mapfile -t cli_variables < <(compgen -e | grep '^CODEX_' || true)
unset "${cli_variables[@]}"
# Codex warns and skips its helper binaries when its home sits under the temp directory.
export TMPDIR="$work/tmp"
mkdir -p "$HOME" "$TMPDIR"
source="$work/source"
"$here/copy-plugin-source.sh" "$repo" "$source"
# Codex falls back to .claude-plugin/, which would hide a missing or broken .agents marketplace.
rm -rf "$source/.claude-plugin"

codex plugin marketplace add "$source" > /dev/null
codex plugin add peekaboot@peekaboot > /dev/null

if ! codex plugin list --json | jq -e 'any(.installed[]; .pluginId == "peekaboot@peekaboot" and .enabled)' > /dev/null; then
  echo "peekaboot@peekaboot is not installed and enabled" >&2
  exit 1
fi

# No codex command lists a plugin's skills. The prompt input it would send the model names each
# skill it offers, as <plugin>:<skill>: <description>.
# Captured whole, since grep -q closing the pipe early makes codex fail on a broken pipe.
prompt=$(cd "$HOME" && codex debug prompt-input)
if ! grep -Fq 'peekaboot:peekaboot: ' <<<"$prompt"; then
  echo "the plugin does not list the peekaboot skill" >&2
  exit 1
fi

echo "ok: peekaboot@peekaboot installs and lists the peekaboot skill"
