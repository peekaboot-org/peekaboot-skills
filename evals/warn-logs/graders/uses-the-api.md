---
type: llm
---

PASS if the reply searches `/peekaboot/api/logs` with `level=WARN` and a text filter such as
`q=timeout`.
FAIL if it only suggests grepping log files or the console.
