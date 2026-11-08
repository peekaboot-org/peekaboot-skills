---
type: llm
---

PASS if the reply reads the failure's trace through Peekaboot's HTTP API in one of two ways:
it takes the trace id from the response's `Server-Timing` header and reads
`/peekaboot/api/traces/<id>`, or it follows a `lastTraceId` from `/peekaboot/api/errors` to
`/peekaboot/api/traces/<lastTraceId>`.
FAIL if it only suggests reading the application's own logs, adding print statements or
attaching a debugger, or if it names a Peekaboot endpoint without either way to the trace.
