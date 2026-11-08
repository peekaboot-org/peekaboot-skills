The block and its child ignore TERM, so only a KILL ends them.

```bash
exec 9> "$LOCK"
flock 9
trap '' TERM
(echo started > "$STARTED"; exec sleep 30)
```
