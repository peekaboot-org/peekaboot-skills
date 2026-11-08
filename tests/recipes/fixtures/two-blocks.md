# Two blocks

```bash
GREETING=hello
echo "first $GREETING"
```

A block in another language never runs:

```sh
echo should-not-run
```

```bash
echo "second ${GREETING:-unset}"
```
