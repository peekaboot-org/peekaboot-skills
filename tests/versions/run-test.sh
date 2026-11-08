#!/usr/bin/env bash
# Holds check-manifest-versions.sh to its contract on copies of this checkout's manifests.
# Prints one line per case.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
check="$repo/.github/ci/check-manifest-versions.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

# copy_manifests <case> <claude version> <codex version>; an empty version drops the field.
# Prints the copy's path.
copy_manifests() {
  local dir="$work/$1"
  mkdir -p "$dir/.claude-plugin" "$dir/.codex-plugin"
  set_version "$2" "$repo/.claude-plugin/plugin.json" > "$dir/.claude-plugin/plugin.json"
  set_version "$3" "$repo/.codex-plugin/plugin.json" > "$dir/.codex-plugin/plugin.json"
  echo "$dir"
}

# set_version <version> <manifest>
set_version() {
  jq --arg v "$1" 'if $v == "" then del(.version) else .version = $v end' "$2"
}

# expect <case> <dir> <exit> <stdout> <stderr>
expect() {
  local name=$1 dir=$2 want_status=$3 want_out=$4 want_err=$5 out err status=0
  out=$("$check" "$dir" 2> "$work/stderr") || status=$?
  err=$(cat "$work/stderr")
  if [ "$status" = "$want_status" ] && [ "$out" = "$want_out" ] && [ "$err" = "$want_err" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: exit $status, stdout [$out], stderr [$err]"
    failures=$((failures + 1))
  fi
}

expect same "$(copy_manifests same 0.1.0 0.1.0)" 0 "ok: every manifest names version 0.1.0" ""

expect different "$(copy_manifests different 0.1.0 0.2.0)" 1 "" "the manifests do not name one version:
.claude-plugin/plugin.json: 0.1.0
.codex-plugin/plugin.json: 0.2.0"

expect missing "$(copy_manifests missing 0.1.0 '')" 1 "" "the manifests do not name one version:
.claude-plugin/plugin.json: 0.1.0
.codex-plugin/plugin.json: none"

expect neither "$(copy_manifests neither '' '')" 1 "" "the manifests do not name one version:
.claude-plugin/plugin.json: none
.codex-plugin/plugin.json: none"

no_file=$(copy_manifests no-file 0.1.0 0.1.0)
rm "$no_file/.codex-plugin/plugin.json"
expect no-file "$no_file" 1 "" "the manifests do not name one version:
.claude-plugin/plugin.json: 0.1.0
.codex-plugin/plugin.json: missing"

no_files=$(copy_manifests no-files 0.1.0 0.1.0)
rm "$no_files/.claude-plugin/plugin.json" "$no_files/.codex-plugin/plugin.json"
expect no-files "$no_files" 1 "" "the manifests do not name one version:
.claude-plugin/plugin.json: missing
.codex-plugin/plugin.json: missing"

[ "$failures" -eq 0 ]
