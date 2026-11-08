---
type: llm
---

PASS if the reply finds the failed POST in `/peekaboot/api/errors` and reads its trace at
`/peekaboot/api/traces/` by its `lastTraceId`, or sends the POST again and reads the trace that
the response's `Server-Timing` header names.
FAIL if it only suggests reading the application's own logs, adding print statements or
attaching a debugger.
