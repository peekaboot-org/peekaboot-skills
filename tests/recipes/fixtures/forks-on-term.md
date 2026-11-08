The block forks a child when TERM arrives, so the child misses the signal that reached the
block's process group.

```bash
exec 9> "$LOCK"
flock 9
trap '(exec sleep 30) & exit 0' TERM
(echo started > "$STARTED"; exec sleep 30)
```
