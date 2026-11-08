The block holds a lock on $LOCK, and so does its child, so the self-test sees when both are gone.

```bash
echo waiting
exec 9> "$LOCK"
flock 9
(sleep 30)
```
