#!/usr/bin/env bash
# Starts the test app, runs every bash block of SKILL.md and references/*.md against it before
# any traffic and again after it, and holds each run to tests/recipes/expected/.
#
#   check.sh <test-app.jar>
set -euo pipefail

jar=${1:?usage: check.sh <test-app.jar>}
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
skill="$repo/skills/peekaboot"
expected="$repo/tests/recipes/expected"
readonly PORT=8090
# The test app serves under a context path, so every block proves it builds its URLs from BASE.
export BASE="http://localhost:$PORT/shop"

shopt -s nullglob
files=("$skill/SKILL.md" "$skill"/references/*.md)

# expectations_for <markdown file> <state>
expectations_for() {
  echo "$expected/$(basename "$1" .md).$2"
}

missing=0
for file in "${files[@]}"; do
  for state in empty populated; do
    if [ ! -f "$(expectations_for "$file" "$state")" ]; then
      echo "missing $(expectations_for "$file" "$state")" >&2
      missing=1
    fi
  done
done
for expectation in "$expected"/*; do
  name=$(basename "$expectation")
  name=${name%.*}
  if [ "$name" != SKILL ] && [ ! -f "$skill/references/$name.md" ]; then
    echo "$expectation has no references/$name.md" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ]

# Only a refused connection (curl's exit 7) means the port is free. A listener that answers
# anything, or nothing within 5 s, holds it.
port_probe=0
curl -s -o /dev/null --max-time 5 "http://localhost:$PORT/" || port_probe=$?
if [ "$port_probe" -ne 7 ]; then
  echo "port $PORT is taken" >&2
  exit 1
fi

work=$(mktemp -d)
java -jar "$jar" > "$work/app.log" 2>&1 &
app=$!
startup=

on_exit() {
  local status=$?
  if [ -n "$startup" ]; then
    kill "$startup" 2> /dev/null || true
  fi
  kill "$app" 2> /dev/null || true
  wait "$app" 2> /dev/null || true
  if [ "$status" -ne 0 ]; then
    echo "--- test app log" >&2
    cat "$work/app.log" >&2
  fi
  rm -rf "$work"
}
trap on_exit EXIT

# curl's retry is the wait for startup. It asks again once a second while the port refuses.
curl -s -o /dev/null -w '%{http_code}' --retry 90 --retry-connrefused --retry-delay 1 \
  "$BASE/peekaboot/api" > "$work/startup-status" &
startup=$!
# Returns when curl is done or java has exited, whichever comes first.
wait -n "$startup" "$app" || true
if ! kill -0 "$app" 2> /dev/null; then
  echo "the test app exited during startup" >&2
  exit 1
fi
startup=
status=$(< "$work/startup-status")
if [ "$status" = 000 ]; then
  echo "GET $BASE/peekaboot/api never answered" >&2
  exit 1
fi
if [ "$status" != 200 ]; then
  echo "GET $BASE/peekaboot/api answered $status; the test app needs a Peekaboot that serves the agent API" >&2
  exit 1
fi

# run_all <state>
run_all() {
  local file
  for file in "${files[@]}"; do
    "$repo/tests/recipes/run.sh" "$file" "$(expectations_for "$file" "$1")"
  done
}

# Before any traffic. A recipe that takes a request gets one Peekaboot never records.
export REQUEST=/peekaboot/api
run_all empty
unset REQUEST

# wait_for_events <count> <data line prefix> <what> <seconds>
# Reads the insights stream until it has sent <count> events whose data starts with the prefix.
wait_for_events() {
  local want=$1 prefix=$2 what=$3 seconds=$4 seen=0 line stream
  exec 3< <(curl -sN --max-time "$seconds" "$BASE/peekaboot/api/insights/stream")
  stream=$!
  while [ "$seen" -lt "$want" ] && IFS= read -r line <&3; do
    case "$line" in
      "$prefix"*) seen=$((seen + 1)) ;;
    esac
  done
  kill "$stream" 2> /dev/null || true
  exec 3<&-
  if [ "$seen" -lt "$want" ]; then
    echo "saw $seen $what in $seconds s, expected $want" >&2
    exit 1
  fi
}

# Every rate counts from the first level-0 sample, so traffic before it never shows in the
# insights data.
wait_for_events 1 'data:{"epochMs":' 'level-0 ticks' 30

# expect_status <status> <path>
expect_status() {
  local got
  got=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE$2") || true
  if [ "$got" != "$1" ]; then
    echo "GET $2 answered $got, expected $1" >&2
    exit 1
  fi
}
expect_status 500 /orders/42
expect_status 500 /orders/42
expect_status 500 /orders/42
expect_status 200 /reports/monthly
expect_status 200 /inventory/sync

# Level 1 of the insights data takes a sample a minute. By the second rollup after the traffic,
# a level-1 sample holds it and every span of it has been exported.
wait_for_events 2 'data:{"level":1,' 'level-1 rollups' 180

run_all populated
echo "ok: every block holds before and after traffic"
