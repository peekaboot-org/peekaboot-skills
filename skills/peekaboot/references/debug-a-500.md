# Debug a 500

Every response from the application names its trace in a `Server-Timing` header. Set `REQUEST`
to the path that failed, then read the trace's cause and its stack trace. The block sends a GET
without a body, so for a failing POST, PUT or DELETE it traces a different request. Find those
in the error digest below instead.

```bash
BASE=${BASE:-http://localhost:8080}
REQUEST=${REQUEST:-/orders/42}
if ! HEADERS=$(curl -s -D - -o /dev/null "$BASE$REQUEST"); then
  echo "Nothing answered at $BASE, so check BASE as SKILL.md describes."
else
  T=$(grep -i '^server-timing' <<<"$HEADERS" | sed -nE 's/.*00-([0-9a-f]{32})-.*/\1/p')
  if [ -z "$T" ]; then
    echo 'No Server-Timing header, so Peekaboot did not trace this request.'
  else
    for i in 1 2 3 4 5 6 7 8 9 10; do
      RESPONSE=$(curl -s -w '\n%{http_code}' "$BASE/peekaboot/api/traces/$T")
      STATUS=${RESPONSE##*$'\n'} TRACE=${RESPONSE%$'\n'*}
      if [ "$STATUS" != 200 ] || [ "$(jq -r '.summary.complete' <<<"$TRACE")" = true ]; then break; fi
      [ "$i" = 10 ] || sleep 1
    done
    case $STATUS in
      200)
        jq '.summary | {complete, outcome, cause, reasons}' <<<"$TRACE"
        jq -r '.summary.cause as $c | select($c)
          | [.data | .. | objects | select(has("children") and .spanId == $c.spanId)] as $spans
          | first(
              ($spans[] | .exception.stackTrace // empty),
              (.data.logs[] | select(.level == "ERROR" and .spanId == $c.spanId) | .stackTrace // empty),
              if any($spans[]; .exception != null)
              then "No stack trace was recorded for \($c.type // "the exception")."
              elif any(.data.logs[]; .level == "ERROR" and .message == $c.message)
              then "The cause is an ERROR log line without a stack trace."
              else "The cause is the 5xx status the request answered with. No span recorded an exception."
              end)' <<<"$TRACE" ;;
      000) echo "Nothing answered at $BASE when reading the trace." ;;
      401) echo 'The trace read answered 401, so add credentials as Authentication in SKILL.md says.' ;;
      404) echo "The trace read answered 404, so Peekaboot does not hold trace $T. Newer traces may have evicted it." ;;
      *) echo "The trace read answered $STATUS." ;;
    esac
  fi
fi
```

`complete` is `false` while the trace's spans are still arriving, so the block asks again for
about ten seconds. If it still reads `false`, run the block again.

`cause` names the exception, its message and the application frame it came from. Its stack
trace follows, from the span that threw or from the ERROR log line that recorded it. A cause
without a stack trace gets one line saying what it is instead. `cause` is `null` when nothing
in the trace failed. A failed connection, a 401 and a 404 each print their own line, so a
`null` always comes from a trace Peekaboot read.

Peekaboot never records requests under `/peekaboot/`, `/actuator/`, `/static/`, `/webjars/` and
`/error/`, so their responses carry no header.

For failures you did not trigger yourself, the error digest lists every one the traces showed,
seen latest first:

```bash
BASE=${BASE:-http://localhost:8080}
curl -s "$BASE/peekaboot/api/errors" | jq '.errors[:5] | map({type, route, count, lastMessage, lastTraceId, traceAvailable})'
```

`[]` means the traces showed no failure. Read a `lastTraceId` at
`$BASE/peekaboot/api/traces/<lastTraceId>` while its `traceAvailable` is `true`.
