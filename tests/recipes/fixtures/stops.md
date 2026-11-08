The child reports from inside itself, so a signal sent once $STARTED is written never lands
while bash is still forking it.

```bash
exec 9> "$LOCK"
flock 9
(echo started > "$STARTED"; exec sleep 30)
```

```bash
touch "$SECOND"
```
