#!/usr/bin/env bash
# Runs debug-a-500.md through run.sh against server.py's canned answers, one case per file in
# expected/, so each of the recipe's branches is held to its own output. Prints one line per case.
set -euo pipefail
# The block falls back to its own REQUEST only when the caller has none.
unset REQUEST

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
reference="$here/../../../skills/peekaboot/references/debug-a-500.md"
work=$(mktemp -d)
server=
stop_server() {
  if [ -n "$server" ]; then
    kill "$server" 2> /dev/null || true
    wait "$server" 2> /dev/null || true
  fi
  rm -rf "$work"
}
trap stop_server EXIT
failures=0

# server.py prints its port once it listens, so reading that line is the wait for readiness.
mkfifo "$work/port"
python3 -I "$here/server.py" > "$work/port" &
server=$!
if ! read -r -t 10 port < "$work/port"; then
  echo "FAIL fake-api: server.py printed no port"
  exit 1
fi

for expectations in "$here"/expected/*.expected; do
  name=$(basename "$expectations" .expected)
  # Nothing listens on port 1.
  if [ "$name" = refused-connection ]; then
    base=http://127.0.0.1:1
  else
    base=http://127.0.0.1:$port/$name
  fi
  if BASE=$base "$here/../run.sh" "$reference" "$expectations" > /dev/null 2> "$work/stderr"; then
    echo "ok   $name"
  else
    echo "FAIL $name: $(< "$work/stderr")"
    failures=$((failures + 1))
  fi
done

[ "$failures" -eq 0 ]
