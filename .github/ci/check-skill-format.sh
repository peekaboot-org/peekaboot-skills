#!/usr/bin/env bash
# Checks a skill folder against the Agent Skills format, claude.ai's description limit and the
# frontmatter and body rules this repo's skill must keep.
#
#   check-skill-format.sh <skill-dir>
set -euo pipefail

# claude.ai's limit, stricter than the format's 1024.
readonly MAX_DESCRIPTION_CHARS=200
readonly LICENSE=Apache-2.0
readonly COMPATIBILITY_TERMS=(curl jq /peekaboot/api)
readonly MAX_BODY_LINES=499

[ $# -eq 1 ] || { echo "usage: check-skill-format.sh <skill-dir>" >&2; exit 2; }
skill_dir=$1

agentskills validate "$skill_dir"
properties=$(agentskills read-properties "$skill_dir")

length=$(jq -r '.description | length' <<< "$properties")
if [ "$length" -gt "$MAX_DESCRIPTION_CHARS" ]; then
  echo "description is $length characters, the limit is $MAX_DESCRIPTION_CHARS" >&2
  exit 1
fi
echo "description is $length characters"

license=$(jq -r '.license // "none"' <<< "$properties")
if [ "$license" != "$LICENSE" ]; then
  echo "license must be $LICENSE, found $license" >&2
  exit 1
fi

compatibility=$(jq -r '.compatibility // ""' <<< "$properties")
missing=0
for term in "${COMPATIBILITY_TERMS[@]}"; do
  if [[ $compatibility != *"$term"* ]]; then
    echo "compatibility must mention $term" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 1

# The body is every line after the frontmatter's closing ---.
body_lines=$(awk 'delimiters >= 2 { lines++ } /^---$/ { delimiters++ } END { print lines + 0 }' \
  "$skill_dir/SKILL.md")
if [ "$body_lines" -gt "$MAX_BODY_LINES" ]; then
  echo "body is $body_lines lines, the limit is $MAX_BODY_LINES" >&2
  exit 1
fi
echo "body is $body_lines lines"
