# Read health over time

Peekaboot samples the application's metrics and keeps them at several levels. Level 0 is the
finest tick, each higher level a coarser window:

```bash
BASE=${BASE:-http://localhost:8080}
curl -s "$BASE/peekaboot/api/insights/config" | jq '.levels'
```

The data at a level summarises each metric over a window and names the problems it shows, such
as CPU running high or connections waiting for the pool:

```bash
BASE=${BASE:-http://localhost:8080}
curl -s -G "$BASE/peekaboot/api/insights/data" --data-urlencode 'level=1' | jq '{level, count, problems}'
```

`count` is the number of samples. Level 1 takes one a minute by default, so `count: 0` means the
application has not run long enough to judge. With samples, an empty `problems` list means no
rule reached its threshold, and a rule whose series has no samples in the window is left out.
For a shorter window, add `--data-urlencode "since=<instant>"` with an ISO-8601 instant in UTC,
such as an hour ago.

To read the samples around an incident, add `view=full` and `series=<id>`. `timestamps` then holds
each sample's time, shared by every series. At level 0 a series' samples are its `values`. Above
level 0 `values` is null and the samples are in `stats`, one list per statistic, each aligned
with `timestamps` and holding null for a gap. Print one series' per-sample max between `SINCE` and
`UNTIL`, ISO-8601 instants in UTC, which the defaults below widen to everything:

```bash
BASE=${BASE:-http://localhost:8080}
SERIES=${SERIES:-cpu.process}
SINCE=${SINCE:-2000-01-01T00:00:00Z}
UNTIL=${UNTIL:-2999-12-31T23:59:59Z}
curl -s -G "$BASE/peekaboot/api/insights/data" --data-urlencode 'level=1' --data-urlencode 'view=full' \
  --data-urlencode "series=$SERIES" --data-urlencode "since=$SINCE" \
  | jq -r --arg series "$SERIES" --arg until "$UNTIL" '
      .timestamps as $at | .series[$series].stats.max as $max
      | range($at | length) | select($at[.] <= ($until | fromdate) * 1000)
      | "\($at[.] / 1000 | todate) \($max[.])"'
```

Restarts and deployments are in the run history, newest first:

```bash
BASE=${BASE:-http://localhost:8080}
curl -s "$BASE/peekaboot/api/lifecycle/runs" | jq '.runs[:3] | map({startedAt, running, uncleanExit, changed})'
```

`uncleanExit: true` means that run recorded no stop, as after a crash or a kill. `changed`
lists which of `version`, `branch` and `commit` differ from the run before.
