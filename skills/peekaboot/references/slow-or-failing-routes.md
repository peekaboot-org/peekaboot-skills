# Find slow or failing routes

The route list sums up requests, failures and latency per route over the traces Peekaboot
holds. The slowest first:

```bash
BASE=${BASE:-http://localhost:8080}
curl -s "$BASE/peekaboot/api/routes" \
  | jq '.routes | sort_by(-.p95Ms) | .[:5] | map({method, route, count, errorCount, p95Ms, latestSlowTraceId, latestErrorTraceId})'
```

`[]` means no request has been traced yet. Sort by `-.errorCount` to put the failing routes
first.

Read the latest slow trace of the slowest route that has one. Its `summary.hotspots` names the
spans that spent longest on their own work, and `summary.issues` every issue on its spans, such
as slow spans, slow queries and repeated queries:

```bash
BASE=${BASE:-http://localhost:8080}
T=$(curl -s "$BASE/peekaboot/api/routes" | jq -r '[.routes[] | select(.latestSlowTraceId)] | max_by(.p95Ms) | .latestSlowTraceId // empty')
if [ -z "$T" ]; then echo 'No route has a slow trace.'
else curl -s "$BASE/peekaboot/api/traces/$T" | jq '.summary | {durationMs, hotspots, issues: [.issues[] | {type, message}]}'; fi
```

A trace is slow at 1000 ms by default (`peekaboot.tracing.slow-trace-threshold-ms`). A failing
route's `latestErrorTraceId` reads the same way; [debug-a-500.md](debug-a-500.md) covers its
cause.
