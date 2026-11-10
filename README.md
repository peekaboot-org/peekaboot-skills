# peekaboot-skills

A skill that teaches a coding agent to debug a Spring Boot application through
[Peekaboot](https://www.peekaboot.org)'s HTTP API. Ask your agent why `/orders/42` answers 500,
which route got slow or what the WARN lines say, and it reads Peekaboot's traces, error digest,
routes, metrics and logs with `curl` and `jq`.

## Requirements

- An application on Peekaboot 1.2.0 or later, the first version that serves `GET /peekaboot/api`.
- `curl` and `jq` where the agent runs its commands.
- An agent that can reach the application. claude.ai and the Claude API run in sandboxes that
  cannot reach `localhost`, so this skill does not support them.

## Install

Claude Code, in a session:

```text
/plugin marketplace add peekaboot-org/peekaboot-skills
/plugin install peekaboot@peekaboot
```

Or from a shell:

```bash
claude plugin marketplace add peekaboot-org/peekaboot-skills
claude plugin install peekaboot@peekaboot
```

Codex:

```bash
codex plugin marketplace add peekaboot-org/peekaboot-skills
codex plugin add peekaboot@peekaboot
```

Cursor, Gemini CLI and GitHub Copilot read skills from a project's `.agents/skills/`. From your
project's root, clone this repository next to it and copy the skill folder:

```bash
git clone --depth 1 https://github.com/peekaboot-org/peekaboot-skills ../peekaboot-skills
mkdir -p .agents/skills && cp -r ../peekaboot-skills/skills/peekaboot .agents/skills/
```

Claude Code reads a project's skills from `.claude/skills/` instead:

```bash
mkdir -p .claude/skills && cp -r ../peekaboot-skills/skills/peekaboot .claude/skills/
```

Marketplace installs follow the default branch, `main`.

## What it covers

- Debug a 500: the request's trace, its cause and stack trace, and the error digest.
- Find slow or failing routes: the route list and a slow trace's hotspots and issues.
- Read health over time: the problems the metric history shows, and restarts.
- Search the logs: by level, text, logger or trace, page by page.

The recipes live in [skills/peekaboot/references/](skills/peekaboot/references/).

## Development

Work lands on `dev`. `main` fast-forwards to `dev` once every CI job is green.
CI validates the skill and both marketplaces, installs the plugin into Claude Code and Codex,
and runs every `bash` block of the skill against `test-app/` before and after traffic.

Both CLIs keep an installed plugin under its version, so a user who installed it keeps the old
copy until the version changes. Bump `version` in `.claude-plugin/plugin.json` and
`.codex-plugin/plugin.json` together with every change to the skill. CI fails when the two
differ.

The checks need Node.js for the CLIs, Java 25 for the test app, `curl`, `jq`, and Python 3.13
for skills-ref and the self-tests' fake API. From the checkout's root:

```bash
python3.13 -m venv .venv
.venv/bin/pip install --requirement .github/ci/requirements.txt
npm ci --prefix .github/ci --ignore-scripts
node .github/ci/node_modules/@anthropic-ai/claude-code/install.cjs
export PATH="$PWD/.venv/bin:$PWD/.github/ci/node_modules/.bin:$PATH"
tests/format/run-test.sh
.github/ci/check-skill-format.sh skills/peekaboot
tests/versions/run-test.sh
.github/ci/check-manifest-versions.sh .
tests/plugin/run-test.sh claude
.github/ci/check-claude-plugin.sh .
tests/plugin/run-test.sh codex
.github/ci/check-codex-plugin.sh .
tests/recipes/run-test.sh
(cd test-app && ./mvnw --batch-mode package)
tests/recipes/check.sh test-app/target/test-app.jar
```

`tests/recipes/check.sh` needs port 8090 free and waits up to three and a half minutes for
metric samples. It stops any one block after 300 seconds. The environment variable
`RECIPE_BLOCK_TIMEOUT` sets another limit:

```bash
RECIPE_BLOCK_TIMEOUT=600 tests/recipes/check.sh test-app/target/test-app.jar
```

On a Mac, the scripts also need GNU `timeout`, bash 5.1 or newer for `wait -n`, and util-linux's
`flock`, each on your `PATH` under that name. Homebrew has them as `coreutils`, `bash` and
`util-linux`, and Python as `python@3.13`. `coreutils` keeps the unprefixed `timeout` in its
`gnubin` directory, and `util-linux` is keg-only, so put both directories first:

```bash
export PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$(brew --prefix)/opt/util-linux/bin:$PATH"
```

The scripts start with `#!/usr/bin/env bash`, so Homebrew's bash must also come before
`/bin/bash` on your `PATH`.

`evals/` holds `claude plugin eval` cases for when the skill should and should not load. They
call the model with your credentials and cost money, so CI does not run them. `--scaffold` runs
each case's script that writes the project's `pom.xml`. This runs each case once per arm and
starts no run once the cost estimate passes 5 USD:

```bash
claude plugin eval . --trust-plugin --scaffold --no-publish --runs 1 --max-cost-usd 5
```

## License

[Apache-2.0](LICENSE)
