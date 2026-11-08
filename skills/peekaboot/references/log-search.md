# Search the logs

The log search covers the lines inside traces and the ones outside them, newest first. Filter
by `level` (that level and every one above it), `q` (text in the message or stack trace),
`logger` (the start of its name), `traceId`, `since` and `until`:

```bash
BASE=${BASE:-http://localhost:8080}
curl -s -G "$BASE/peekaboot/api/logs" --data-urlencode 'level=WARN' --data-urlencode 'q=timeout' \
  | jq '.logs[] | {timestamp, level, logger, message, traceId}'
```

No output means no line matched. A line with a `traceId` leads to its trace.

A page holds 100 lines unless `limit` says otherwise. Its `next` is the page token for the one
after it. Send it back as `cursor` with the same filters. On the last page `next` is `null`:

```bash
BASE=${BASE:-http://localhost:8080}
NEXT=$(curl -s -G "$BASE/peekaboot/api/logs" --data-urlencode 'level=WARN' --data-urlencode 'q=timeout' \
  | jq -r '.next // empty')
if [ -z "$NEXT" ]; then echo 'That was the last page.'
else curl -s -G "$BASE/peekaboot/api/logs" --data-urlencode 'level=WARN' --data-urlencode 'q=timeout' \
  --data-urlencode "cursor=$NEXT" | jq '{next, logs: [.logs[] | {timestamp, level, logger, message, traceId}]}'; fi
```
