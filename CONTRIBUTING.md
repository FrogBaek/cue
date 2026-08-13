# Contributing

Thanks for looking. This page is what you need before the first change: how to run
the plugin from a checkout, how to run the tests, and the two conventions that are
not obvious from reading the code.

## Running it from a checkout

```bash
claude --plugin-dir /path/to/cue
```

That loads the plugin from the working tree, so an edit to a skill takes effect on
the next session rather than after a release. `/cue-dev:init` in the repository you
want to try it on, then `/cue-dev:start <KEY>`.

**Do not run the cue-dev cycle on this repository.** Its worktrees and `.cue/`
would sit on top of the ones being tested and neither is distinguishable from the
other afterwards. Use a scratch repository.

## Tests

```bash
tools/run-tests.sh                      # every suite — about 6 minutes
tools/run-tests.sh -j 12                # more concurrency
tools/run-tests.sh tests/cue-dev        # one directory
tools/run-tests.sh tests/cue-dev/test-status.sh
```

32 suites, run 6 at a time, output printed only for the ones that failed. They
build their own fixture repositories under `mktemp -d` and share no state, which
is why they can run in parallel at all.

`docs/testing.md` says what each suite exists to catch. Read the row for the file
you are about to change — several of them encode a defect that took a real session
to find, and the row says which.

**Every suite under `tests/` runs here — there is no excluded directory.** Nothing
in this repository drives a real Claude session as a test, so a suite that needs
one does not have a home yet. What these suites can check is that an instruction is
in place; whether the model follows it shows up only in a real cycle.

## Linting

```bash
tools/lint-shell.sh          # changed files (default)
tools/lint-shell.sh --all    # every tracked shell file
```

ShellCheck at `--severity=warning`. Both forms are clean at `main`, and CI runs
`--all` on every pull request.

## Two conventions worth knowing before you write

**The scripts are the source of truth, and the skills carry judgment.** Anything
that can be decided from files, git, or a config value belongs in
`plugins/cue-dev/skills/using-cue/scripts/`, where it is deterministic and
testable. What is left for a skill body is what needs a conversation with a human.
A rule stated only in prose is a rule that holds until a session is under
pressure — several of the suites exist because one did not hold.

**Every script is called as `<cue>/<script>`, never as a path.** `<cue>` is given
a value once, by `hooks/session-start`, and that is why every script lives under
`skills/using-cue/scripts/` rather than at the plugin root. `docs/packaging.md`
has the full reason. A second scripts directory anywhere else is unreachable, and
`tests/cue-dev/test-plugin-infra.sh` refuses one.

## Language

**Everything in this repository is written in English**: commit messages, pull
request and issue text, code comments, skill bodies, `docs/`, and the changelog.
Contributors have to be able to read the history and the reasoning without a
translator, and a repository that mixes two languages asks every reader to know
both.

The one exception is the README, which is translated per language:
`README.md` is the English original and `README.ko.md` the Korean one. A new
translation is `README.<code>.md`, linked from the header of the others.

This applies to what the plugin *ships*, not to what it *produces*. cue-dev writes
its records in whatever language the repository using it configures — see
`/cue-dev:init` — and Korean fixtures appear in the suites on purpose, because
label truncation and record parsing have to be exercised on multi-byte text.

## Pull requests

- One change per pull request, with the reason in the description. What the diff
  does is visible; why it is the right diff is not.
- Add or update the suite that covers what you changed. If nothing covers it, say
  so in the description — that is useful information, not an admission.
- `tools/run-tests.sh` and `tools/lint-shell.sh --all` pass before you open it.
- Keep the commit subject enough on its own; add a body only when the subject
  cannot carry the reason.

## Design notes

`docs/` holds the reasoning behind decisions that keep coming back up:

| | |
|---|---|
| `testing.md` | what each suite catches, and how to run the ones that need an LLM |
| `output-format.md` | the `━━━` notice block — one shape, one piece of code that draws it |
| `branching-model.md` | why the start point is recorded per item rather than configured |
| `integration.md` | what `finish` requires, and what belongs to the repository instead |
| `packaging.md` | the manifest, the hook, and why the scripts live under a skill |
| `windows/polyglot-hooks.md` | how one hook file runs on both cmd.exe and bash |
