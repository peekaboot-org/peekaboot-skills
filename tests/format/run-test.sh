#!/usr/bin/env bash
# Holds check-skill-format.sh to its contract on generated skills. Prints one line per case.
set -euo pipefail
if ! command -v agentskills > /dev/null; then
  echo "run-test.sh: needs agentskills from the skills-ref venv (.github/ci/requirements.txt)" >&2
  exit 1
fi
if ! command -v jq > /dev/null; then
  echo "run-test.sh: needs jq" >&2
  exit 1
fi

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
check="$repo/.github/ci/check-skill-format.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

# write_skill <directory name> <skill name> <description length> [<license> [<compatibility> [<body lines>]]]
# Prints the directory. The optional fields default to valid values; an empty one leaves the field out.
write_skill() {
  local dir="$work/$1" name=$2 description license=${4-Apache-2.0}
  local compatibility=${5-Needs curl, jq and a Peekaboot that serves GET /peekaboot/api.} body_lines=${6-2} i
  description=$(head -c "$3" /dev/zero | tr '\0' x)
  mkdir -p "$dir"
  {
    printf -- '---\nname: %s\ndescription: %s\n' "$name" "$description"
    if [ -n "$license" ]; then
      printf 'license: %s\n' "$license"
    fi
    if [ -n "$compatibility" ]; then
      printf 'compatibility: %s\n' "$compatibility"
    fi
    printf -- '---\n'
    for ((i = 0; i < body_lines; i++)); do
      echo Body.
    done
  } > "$dir/SKILL.md"
  echo "$dir"
}

# expect <case> <exit> <stdout> <stderr> [<argument>...]
expect() {
  local name=$1 want_status=$2 want_out=$3 want_err=$4 out err status=0
  shift 4
  out=$("$check" "$@" 2> "$work/stderr") || status=$?
  err=$(cat "$work/stderr")
  if [ "$status" = "$want_status" ] && [ "$out" = "$want_out" ] && [ "$err" = "$want_err" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: exit $status, stdout [$out], stderr [$err]"
    failures=$((failures + 1))
  fi
}

expect no-argument 2 "" "usage: check-skill-format.sh <skill-dir>"

at_limit=$(write_skill at-limit at-limit 200)
expect at-limit 0 "Valid skill: $at_limit
description is 200 characters
body is 2 lines" "" "$at_limit"

over_limit=$(write_skill over-limit over-limit 201)
expect over-limit 1 "Valid skill: $over_limit" \
  "description is 201 characters, the limit is 200" "$over_limit"

misnamed=$(write_skill misnamed other-name 10)
expect misnamed 1 "" "Validation failed for $misnamed:
  - Directory name 'misnamed' must match skill name 'other-name'" "$misnamed"

wrong_license=$(write_skill wrong-license wrong-license 10 MIT)
expect wrong-license 1 "Valid skill: $wrong_license
description is 10 characters" "license must be Apache-2.0, found MIT" "$wrong_license"

no_license=$(write_skill no-license no-license 10 "")
expect no-license 1 "Valid skill: $no_license
description is 10 characters" "license must be Apache-2.0, found none" "$no_license"

no_jq=$(write_skill no-jq no-jq 10 Apache-2.0 "Needs curl and a Peekaboot that serves GET /peekaboot/api.")
expect no-jq 1 "Valid skill: $no_jq
description is 10 characters" "compatibility must mention jq" "$no_jq"

no_compatibility=$(write_skill no-compatibility no-compatibility 10 Apache-2.0 "")
expect no-compatibility 1 "Valid skill: $no_compatibility
description is 10 characters" "compatibility must mention curl
compatibility must mention jq
compatibility must mention /peekaboot/api" "$no_compatibility"

body_at_limit=$(write_skill body-at-limit body-at-limit 10 Apache-2.0 "curl, jq, /peekaboot/api" 499)
expect body-at-limit 0 "Valid skill: $body_at_limit
description is 10 characters
body is 499 lines" "" "$body_at_limit"

body_over_limit=$(write_skill body-over-limit body-over-limit 10 Apache-2.0 "curl, jq, /peekaboot/api" 500)
expect body-over-limit 1 "Valid skill: $body_over_limit
description is 10 characters" "body is 500 lines, the limit is 499" "$body_over_limit"

[ "$failures" -eq 0 ]
