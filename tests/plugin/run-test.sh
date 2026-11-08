#!/usr/bin/env bash
# Holds check-<tool>-plugin.sh to its contract: it passes on a copy of this checkout and fails,
# naming the cause, on copies broken one way each. Prints one line per case.
#
#   run-test.sh claude|codex
set -euo pipefail

tool=${1:?usage: run-test.sh claude|codex}
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
check="$repo/.github/ci/check-$tool-plugin.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

# copy_repo <case>; prints the copy's path
copy_repo() {
  "$repo/.github/ci/copy-plugin-source.sh" "$repo" "$work/$1"
  echo "$work/$1"
}

# edit_json <file> <jq filter>
edit_json() {
  jq "$2" "$1" > "$1.edited"
  mv "$1.edited" "$1"
}

readonly OK_LINE="ok: peekaboot@peekaboot installs and lists the peekaboot skill"

# expect_pass <case> <copy> [<name>=<value> ...]; the assignments go into the check's environment
expect_pass() {
  local name=$1 dir=$2 out
  if ! out=$(env "${@:3}" "$check" "$dir" 2> "$work/stderr"); then
    echo "FAIL $tool $name: expected a pass"
    echo "$out"
    cat "$work/stderr"
    failures=$((failures + 1))
  elif [ "$out" != "$OK_LINE" ]; then
    echo "FAIL $tool $name: stdout is not '$OK_LINE'"
    echo "$out"
    failures=$((failures + 1))
  else
    echo "ok   $tool $name"
  fi
}

# expect_empty <case> <dir>
expect_empty() {
  local name=$1 dir=$2
  if [ -z "$(ls -A "$dir")" ]; then
    echo "ok   $tool $name"
  else
    echo "FAIL $tool $name: $dir is not empty:"
    ls -A "$dir"
    failures=$((failures + 1))
  fi
}

# expect_failure <case> <copy> <text stderr must contain> [<name>=<value> ...]; the assignments go
# into the check's environment
expect_failure() {
  local name=$1 dir=$2 text=$3 err
  if err=$(env "${@:4}" "$check" "$dir" 2>&1 > /dev/null); then
    echo "FAIL $tool $name: expected a failure"
    failures=$((failures + 1))
  elif [[ "$err" != *"$text"* ]]; then
    echo "FAIL $tool $name: stderr does not say '$text'"
    echo "$err"
    failures=$((failures + 1))
  else
    echo "ok   $tool $name"
  fi
}

intact=$(copy_repo intact)
expect_pass intact "$intact"

# The CLIs prefer these variables to HOME. A check that kept them would write to the caller's setup.
config_dir="$work/config-dir"
mkdir "$config_dir"
expect_pass config-dir-variables "$intact" \
  CLAUDE_CONFIG_DIR="$config_dir" CLAUDE_CODE_PLUGIN_CACHE_DIR="$config_dir" \
  CODEX_HOME="$config_dir" CODEX_SQLITE_HOME="$config_dir"
expect_empty config-dir-untouched "$config_dir"

case "$tool" in
  claude)
    unknown_field=$(copy_repo unknown-field)
    edit_json "$unknown_field/.claude-plugin/plugin.json" '.colour = "blue"'
    expect_failure unknown-field "$unknown_field" "Unknown field 'colour'"

    no_version=$(copy_repo no-version)
    edit_json "$no_version/.claude-plugin/plugin.json" 'del(.version)'
    expect_failure no-version "$no_version" "No version specified"

    no_skill=$(copy_repo no-skill)
    rm -r "$no_skill/skills"
    expect_failure no-skill "$no_skill" "the plugin does not list the peekaboot skill"

    # A plugin the caller's environment adds must not stand in for this one.
    decoy="$work/decoy-plugin"
    mkdir -p "$decoy/.claude-plugin" "$decoy/skills/peekaboot"
    echo '{"name": "peekaboot", "version": "0.1.0"}' > "$decoy/.claude-plugin/plugin.json"
    printf -- '---\nname: peekaboot\ndescription: A decoy.\n---\nA decoy.\n' \
      > "$decoy/skills/peekaboot/SKILL.md"
    expect_failure decoy-plugin "$no_skill" "the plugin does not list the peekaboot skill" \
      CLAUDE_CODE_PLUGIN_DIRS="$decoy"
    ;;
  codex)
    wrong_skills_path=$(copy_repo wrong-skills-path)
    edit_json "$wrong_skills_path/.codex-plugin/plugin.json" '.skills = "./nope/"'
    expect_failure wrong-skills-path "$wrong_skills_path" "the plugin does not list the peekaboot skill"

    renamed=$(copy_repo renamed)
    edit_json "$renamed/.codex-plugin/plugin.json" '.name = "not-peekaboot"'
    expect_failure renamed "$renamed" "does not match marketplace plugin name"

    no_agents_marketplace=$(copy_repo no-agents-marketplace)
    rm "$no_agents_marketplace/.agents/plugins/marketplace.json"
    expect_failure no-agents-marketplace "$no_agents_marketplace" "does not contain a supported manifest"
    ;;
  *)
    echo "unknown tool: $tool" >&2
    exit 2
    ;;
esac

[ "$failures" -eq 0 ]
