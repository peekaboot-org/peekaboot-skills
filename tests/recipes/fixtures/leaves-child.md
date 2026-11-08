The block exits while its background child still holds the lock on $LOCK.

```bash
exec 9> "$LOCK"
flock 9
(exec sleep 30) &
echo backgrounded
```
