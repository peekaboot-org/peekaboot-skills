#!/usr/bin/env bash
# Runs every ```bash block of a Markdown file, each in a fresh shell as an agent's separate
# commands would run, and holds the combined output to an expectations file.
#
#   run.sh <file.md> <expectations>
#
# An expectations line is an extended regex some output line must match; a leading ! means no
# line may match it. Blank lines and lines starting with # are skipped. A block fails when it
# exits non-zero, writes to stderr or runs past RECIPE_BLOCK_TIMEOUT seconds (default 300, above
# the longest recipe wait). A ```bash fence that is indented or carries text after bash fails the
# run, since it would be skipped. HUP, INT or TERM stops the running block and the run, with exit
# 130. A block's leftover children are stopped when it ends, and a block that ignores TERM gets
# KILL 5 s later.
set -euo pipefail

markdown=${1:?usage: run.sh <file.md> <expectations>}
expectations=${2:?usage: run.sh <file.md> <expectations>}
block_timeout=${RECIPE_BLOCK_TIMEOUT:-300}

for input in "$markdown" "$expectations"; do
  if [ ! -r "$input" ]; then
    echo "$input: cannot read" >&2
    exit 1
  fi
done
if ! command -v timeout > /dev/null; then
  echo "run.sh: needs timeout from GNU coreutils" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

count=$(awk -v dir="$work" '
  inside && /^```/ { inside = 0; next }
  inside           { print > file; next }
  /^```bash$/      { n++; file = sprintf("%s/block-%d.sh", dir, n); printf "" > file; inside = 1; next }
  /^[[:space:]]*```+[[:space:]]*bash/ {
    printf "%s:%d: fence is skipped, write exactly ```bash at column 0\n", FILENAME, NR > "/dev/stderr"
    skipped = 1
  }
  END { if (skipped) exit 1; print n + 0 }
' "$markdown")
if [ "$count" -eq 0 ]; then
  echo "$markdown: no bash blocks" >&2
  exit 1
fi

fail_block() {
  echo "$markdown: block $i $1" >&2
  cat "$work/stderr" >&2
  echo "--- output of block $i" >&2
  cat "$work/stdout" >&2
  exit 1
}

# timeout's own process group hides the block from a terminal Ctrl-C, so the trap passes it on.
# The block is waited on in the background because bash defers traps for a foreground child.
# timeout leads the block's process group, so -$block_pid also reaches a child that missed its kill.
# stop_run's wait hides bash's "Killed" notice, which -k 5 causes and the block never wrote.
block_pid=
stop_run() {
  if [ -n "$block_pid" ]; then
    kill -TERM "$block_pid" 2> /dev/null || true
    wait "$block_pid" 2> /dev/null || true
    kill -TERM -- -"$block_pid" 2> /dev/null || true
  fi
  echo "$markdown: stopped by a signal" >&2
  exit 130
}
trap stop_run HUP INT TERM

: > "$work/output"
for i in $(seq "$count"); do
  status=0
  timeout -k 5 "$block_timeout" bash "$work/block-$i.sh" \
    < /dev/null > "$work/stdout" 2> "$work/stderr" &
  block_pid=$!
  wait "$block_pid" || status=$?
  kill -TERM -- -"$block_pid" 2> /dev/null || true
  block_pid=
  cat "$work/stdout" >> "$work/output"
  if [ "$status" -eq 124 ]; then
    fail_block "exited 124 (timeout's status; the limit is $block_timeout s)"
  fi
  if [ "$status" -ne 0 ]; then
    fail_block "exited $status"
  fi
  if [ -s "$work/stderr" ]; then
    fail_block "wrote to stderr"
  fi
done

failed=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    '' | '#'*) continue ;;
    '!'*) pattern=${line#!} want_status=1 miss="output matches" ;;
    *) pattern=$line want_status=0 miss="no output line matches" ;;
  esac
  status=0
  grep -Eq -- "$pattern" "$work/output" 2> /dev/null || status=$?
  if [ "$status" -gt 1 ]; then
    echo "$expectations: bad pattern $line" >&2
    failed=1
  elif [ "$status" -ne "$want_status" ]; then
    echo "$markdown: $miss $pattern" >&2
    failed=1
  fi
done < "$expectations"

if [ "$failed" -ne 0 ]; then
  echo "--- output of $markdown" >&2
  cat "$work/output" >&2
  exit 1
fi
echo "ok $markdown ($count blocks)"
