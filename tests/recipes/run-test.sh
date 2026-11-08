#!/usr/bin/env bash
# Holds run.sh to its contract with the fixtures in fixtures/. Prints one line per case.
set -euo pipefail
if ! command -v flock > /dev/null; then
  echo "run-test.sh: needs flock from util-linux" >&2
  exit 1
fi
# two-blocks.md proves a fresh shell per block through GREETING, so the caller's must not leak in.
unset GREETING

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$here/fixtures"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

pass() { echo "ok   $1"; }
fail() {
  echo "FAIL $1: $2"
  failures=$((failures + 1))
}

# expect <case> <exit> <stdout> <stderr> <run.sh arguments...>
expect() {
  local name=$1 want_status=$2 want_out=$3 want_err=$4 out err status=0
  shift 4
  out=$("$here/run.sh" "$@" 2> "$work/stderr") || status=$?
  err=$(< "$work/stderr")
  if [ "$status" = "$want_status" ] && [ "$out" = "$want_out" ] && [ "$err" = "$want_err" ]; then
    pass "$name"
  else
    fail "$name" "exit $status, stdout [$out], stderr [$err]"
  fi
}

# leaves_nothing <case> <lock>: no process may still hold the lock a fixture block took. flock
# waits in the kernel for the last holder to exit; the 5 s bound only runs out on a failure.
leaves_nothing() {
  if [ -e "$2" ] && flock -w 5 "$2" true; then
    pass "$1"
  else
    fail "$1" "a process still holds $2"
  fi
}

expect fresh-shell-per-block 0 "ok two-blocks.md (2 blocks)" "" two-blocks.md two-blocks.expected

BASE=http://example.test expect passes-the-environment 0 "ok uses-env.md (1 blocks)" "" \
  uses-env.md uses-env.expected

expect block-exits-nonzero 1 "" "exits-nonzero.md: block 1 exited 3
--- output of block 1
before" exits-nonzero.md any.expected

expect block-writes-stderr 1 "" "writes-stderr.md: block 1 wrote to stderr
oops
--- output of block 1" writes-stderr.md any.expected

LOCK=$work/hangs.lock RECIPE_BLOCK_TIMEOUT=1 expect block-times-out 1 "" "hangs.md: block 1 exited 124 (timeout's status; the limit is 1 s)
--- output of block 1
waiting" hangs.md any.expected
leaves_nothing timed-out-block-leaves-nothing "$work/hangs.lock"

# signal_run <case> <signal> <fixture> <lock>: sends the signal to run.sh once the fixture's block
# has started, and expects the run to stop within 10 s, which covers -k 5, with exit 130. The block
# reports through a FIFO, opened read-write here so neither side blocks on open.
signal_run() {
  local name=$1 signal=$2 markdown=$3 started=$work/$1.started second=$work/$1.second runner sent
  local elapsed out err status=0
  mkfifo "$started"
  exec 3<> "$started"
  STARTED=$started LOCK=$4 SECOND=$second \
    "$here/run.sh" "$markdown" any.expected > "$work/stdout" 2> "$work/stderr" &
  runner=$!
  read -r -t 10 -u 3 _ || true
  sent=$SECONDS
  kill -"$signal" "$runner" 2> /dev/null || true
  wait "$runner" || status=$?
  elapsed=$((SECONDS - sent))
  exec 3>&-
  out=$(< "$work/stdout")
  err=$(< "$work/stderr")
  if [ "$status" = 130 ] && [ -z "$out" ] && [ "$err" = "$markdown: stopped by a signal" ] \
    && [ "$elapsed" -lt 10 ] && [ ! -e "$second" ]; then
    pass "$name"
  else
    fail "$name" "exit $status after ${elapsed} s, stdout [$out], stderr [$err], \
second block ran: $([ -e "$second" ] && echo yes || echo no)"
  fi
}

# TERM stands in for a terminal Ctrl-C, which run.sh traps the same way.
signal_run term-stops-the-run TERM stops.md "$work/stops.lock"
leaves_nothing term-leaves-nothing "$work/stops.lock"

signal_run hup-stops-the-run HUP stops.md "$work/hup.lock"
leaves_nothing hup-leaves-nothing "$work/hup.lock"

signal_run term-ignored-stops-the-run TERM ignores-term.md "$work/ignores-term.lock"
leaves_nothing term-ignored-leaves-nothing "$work/ignores-term.lock"

signal_run late-child-stops-the-run TERM forks-on-term.md "$work/forks-on-term.lock"
leaves_nothing late-child-leaves-nothing "$work/forks-on-term.lock"

LOCK=$work/leaves-child.lock expect background-child 0 "ok leaves-child.md (1 blocks)" "" \
  leaves-child.md leaves-child.expected
leaves_nothing background-child-leaves-nothing "$work/leaves-child.lock"

expect closes-stdin 0 "ok reads-stdin.md (1 blocks)" "" reads-stdin.md reads-stdin.expected <<< secret

expect empty-block-keeps-numbering 0 "ok empty-block.md (3 blocks)" "" empty-block.md empty-block.expected

expect skipped-fence 1 "" 'skipped-fences.md:9: fence is skipped, write exactly ```bash at column 0
skipped-fences.md:13: fence is skipped, write exactly ```bash at column 0' \
  skipped-fences.md any.expected

# A PATH holding only bash. expect reads stderr with $(< ...), so it needs no cat.
mkdir "$work/bin"
ln -s "$(command -v bash)" "$work/bin/bash"
PATH=$work/bin expect needs-timeout 1 "" "run.sh: needs timeout from GNU coreutils" \
  two-blocks.md two-blocks.expected

expect unreadable-markdown 1 "" "nope.md: cannot read" nope.md any.expected

expect unreadable-expectations 1 "" "nope.expected: cannot read" exits-nonzero.md nope.expected

expect no-blocks 1 "" "no-blocks.md: no bash blocks" no-blocks.md any.expected

expect missing-line 1 "" "two-blocks.md: no output line matches ^third\$
--- output of two-blocks.md
first hello
second unset" two-blocks.md missing.expected

expect forbidden-line 1 "" "two-blocks.md: output matches ^first
--- output of two-blocks.md
first hello
second unset" two-blocks.md forbidden.expected

expect bad-required-pattern 1 "" "bad-required.expected: bad pattern first(
--- output of two-blocks.md
first hello
second unset" two-blocks.md bad-required.expected

expect bad-forbidden-pattern 1 "" "bad-forbidden.expected: bad pattern !first(
--- output of two-blocks.md
first hello
second unset" two-blocks.md bad-forbidden.expected

[ "$failures" -eq 0 ]
