---
name: peekaboot
description: Debug a Spring Boot app that runs Peekaboot through its HTTP API. Use for a failing or slow request, a 500 or other error, a log search, or the app's health over time.
license: Apache-2.0
compatibility: Needs curl, jq and a Peekaboot version that serves GET /peekaboot/api.
---

# Peekaboot

Peekaboot runs inside a Spring Boot application and records its traces, logs and metrics. Its
HTTP API under `/peekaboot/api` answers with Peekaboot's own judgement, such as a trace's cause,
its issues and the routes that fail. Ask it before reading code or guessing.

First check that `pom.xml`, `build.gradle` or `build.gradle.kts` has an `org.peekaboot`
dependency. Without one, the application does not run Peekaboot, so stop using this skill.

## Find the base URL

`BASE` is the application's scheme, host and port plus its context path, without
`/peekaboot`. The port is `server.port`, 8080 when unset. The context path is
`server.servlet.context-path`, and `spring.mvc.servlet.path` adds to it. Look in
`application.yml`, `application.properties`, the profile files and the run configuration. When
present, the startup log's `Peekaboot Dashboard:` line gives the URL; `BASE` is that URL without
`/peekaboot/`. The line needs Peekaboot's lifecycle feature and INFO logging, so a missing line
does not mean Peekaboot is off. Ask the user when the application runs elsewhere or you cannot
tell.

Every block below sets `BASE` itself, because a shell may not keep variables between commands.
Where the default is wrong, edit it in the block or start the command with
`export BASE=http://localhost:9090/shop;`.

## Start here

```bash
BASE=${BASE:-http://localhost:8080}
curl -fsS "$BASE/peekaboot/api" | jq -r '.endpoints[] | "\(.path)  \(.purpose)"'
```

It lists every endpoint with one line on what it is for. Each path already starts with the
context path and servlet path, so put only scheme, host and port in front of it, never `BASE`.
`/peekaboot/api/openapi.json` describes every parameter, response and problem body. A
connection error means nothing answers at `BASE`. A `404` most often means `BASE` lacks the
context path or servlet path. Otherwise Peekaboot is off there, or the application runs a
Peekaboot older than this API.

## Authentication

A local run needs no credentials. Where Peekaboot's guard is armed, the API answers `401` with
a problem body, and every request needs HTTP Basic credentials. Add
`-u "$PEEKABOOT_USER:$PEEKABOOT_PASSWORD"` to each `curl`. Ask the user to export
`PEEKABOOT_USER` and `PEEKABOOT_PASSWORD` in the environment your shell inherits, so the
password never appears in a command or the transcript.

- Username: `peekaboot.security.username`, else the build's artifact id plus `-admin`, else
  `spring.application.name` plus `-admin`, else `peekaboot-admin`.
- Password: only the user supplies it. They may have set `peekaboot.security.password` or the
  environment variable `PEEKABOOT_SECURITY_PASSWORD`. Otherwise Peekaboot generated one and
  printed it once, in the `Peekaboot Security` block of the start that created it.

Never print a password, write it into a file, or repeat it in a reply. Where the application's
own Spring Security guards `/peekaboot/**` instead, send the credentials it expects.

## Masked values

`******` means Peekaboot masked a value. The value exists, and the API does not show it. Never
use it, retry for it, or report it as empty. It can sit inside a longer string, such as
`jdbc:postgresql://db/orders?password=******`. The log search matches the masked text, so
`q=******` finds the lines Peekaboot masked a value in.

## Refused parameters

An endpoint refuses a parameter it does not take with a `400` whose `detail` lists the ones it
does take. Read `detail` and correct the call. A typo never returns the unfiltered list.

A jq error `Cannot iterate over null` means the call answered a problem body, such as this
`400`, a `401` or a `404`, so rerun the curl alone to read its status.

## Recipes

Each reference sets its own variables and says what an empty answer means. Run each block as
one command.

- A request fails or answers 500: [references/debug-a-500.md](references/debug-a-500.md)
