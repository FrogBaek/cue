# Testing cue-dev

cue-dev's tests are deterministic and run anywhere. Whether the model actually
follows the instructions these suites check for is not tested here — that shows up
only in real cycles.

## The regular path

```bash
tools/run-tests.sh
```

That is the canonical way to run the tests. It collects every `test-*.sh` under
`tests/`, runs them in parallel (6 at a time by default), and prints output only
for the suites that failed. About 6 minutes for all 32 suites.

```bash
tools/run-tests.sh -j 12                        # set the concurrency
tools/run-tests.sh tests/cue-dev                # only under a path
tools/run-tests.sh tests/cue-dev/test-status.sh # one suite
```

Nothing under `tests/` is excluded, and that is deliberate. There used to be a
`tests/claude-code/` holding suites that drove real LLM sessions, excluded by
directory so a machine with no credentials would not read them as failures.
**An exclusion is by directory, so a suite put in the wrong one runs nowhere and
says nothing about it** — two plain-shell suites were eventually found parked
behind that one, and one of them was the only coverage three scripts had. Adding
an exclusion back needs a better answer to that than the last one had.

Each suite is standalone, so `bash tests/cue-dev/test-status.sh` works too. Every
suite builds its own fixture repository with `mktemp -d` and shares no state, which
is what makes the parallelism safe.

## What is under test

| Directory | What it covers |
|---|---|
| `tests/cue-dev/` | the plugin scripts — unit and integration |
| `tests/hooks/` | the SessionStart hook's output shape and the language directive |
| `tests/shell-lint/` | `tools/lint-shell.sh` itself |
| `tests/systematic-debugging/` | `find-polluter.sh` from the skill of that name |

The `tests/cue-dev/` suites, and what each exists to catch:

| Suite | Contract |
|---|---|
| `test-cycle.sh` | start → design → plan → implement → finish end to end. The seams between scripts, which the unit tests never look at. |
| `test-stage-contract.sh` | instructions that live only in the skill documents — stopping without a prerequisite, pointing at the next stage, never chaining automatically. |
| `test-plugin-infra.sh` | plugin structure — manifests, frontmatter, references that resolve, deleted things staying deleted. |
| `test-status.sh` | stage determination, unrecorded counting, the ✓/~/· display. |
| `test-redo.sh` | the invalidation chain, backup branches, the consent gate. |
| `test-config.sh` | convention settings, validation, `marker_prefix_history`, and that `min_check` stays retired — `--set` refuses it and points at `/cue-dev:start`, `--get` answers with the per-item script, and a line an old repository still carries is displayed as retired rather than as a setting. |
| `test-init-check.sh` | the readiness gate — the one that stops "no commits, so no branch to start from" from surfacing at finish. |
| `test-work-base.sh` | the per-item start point — the round trip from `--line` to the readers, two items holding different start points at once, and an unrecorded item being an error rather than a guess. |
| `test-work-branch.sh` | the per-item branch name — that a name carrying no trace of the KEY round-trips and still finds it, that the recorded line beats a coincidental substring, and that items written before the line are still found the old way. |
| `test-branch-holder.sh` | the one repository-scope path — that a landing branch another worktree holds is named before `finish` starts merging, and that the branch under your own feet is not mistaken for one. |
| `test-work-init.sh` | work directory creation, never overwriting, reserved names, and the parallel-work signal an unisolated start prints when worktrees exist. |
| `test-outcome-init.sh` | the outcome skeleton, one row per task. |
| `test-skeleton.sh` | the generated frame of design.md and plan.md — that it satisfies `verify`'s structural checks without anyone typing them, that prose in another language passes, and that an unfilled frame does not. |
| `test-verify.sh` | the record gate — that it catches what the skills' prose checklists used to, and that it never fails a record for being merely terse. |
| `test-task-graph.sh` | the dependency graph from Interfaces symbol matches. |
| `test-notice.sh` | the completion notice block — that its two rules close at the same width, and that the title whitelist refuses a frame for a stage that does not exist. |
| `test-gate.sh` | stage ordering — that a stage invoked out of turn is refused *with the commands that are available instead*, which a bare exit code never carried. |
| `test-finish-cleanup.sh` | the workspace teardown — that the scratch goes, that a harness-owned worktree is left alone and named, and that the report matches the disk rather than the intent. |
| `test-backups.sh` | the backup listing finish offers to clean up, and that it never reaches past its KEY. |
| `test-sdd-workspace.sh` | the per-plan scratch directory, and that `task-brief` and `review-package` write into their own plan's copy of it. It sat under `tests/claude-code/` and therefore ran nowhere — plain shell parked behind an exclusion written for suites that call an LLM. |
| `test-marker.sh` | the one place every stage commit passes through, and therefore where the stage gate stands — no marker for records that do not pass `verify`. |
| `test-evidence.sh` | the two facts `finish` must have in front of it before Step 1, neither of them left to be remembered. |
| `test-integration.sh` | how work leaves the repository, and whether an item left — a forge named but not installed, a landing git cannot see, a branch that was never recorded. |
| `test-merge-lock.sh` | who owns the main checkout for the length of a merge, which is the one point where parallel items stop being isolated. |
| `test-restore.sh` | walking back to a backup branch `redo` left behind, with the properties that make a restore safe rather than the ones that make it work. |
| `test-work-check.sh` | the per-item check level, and that it stays per-item — one repository-wide floor could not serve two worktrees at once. |
| `test-work-path.sh` | where an item's worktree is, recorded rather than remembered. A session that remembered a path this plugin names nowhere is what it exists for. |
| `test-shell-portability.sh` | the shell constructs and tool behaviours the scripts rely on, exercised in isolation and named for what they are. A portability defect otherwise arrives as an unrelated symptom: `s━: unbound variable`, whose trailing bytes no log shows, from a line where `s` had just been assigned. |
| `test-review-package.sh` | what a reviewer is actually handed — every commit in the range, the net diff rather than the last commit's, and ten lines of context. `test-sdd-workspace.sh` covers where the file lands; this covers what is in it. |

`tests/cue-dev/helpers.sh` holds the shared fixtures (`new_repo`, `commit_stage`,
`write_skeleton`, `pass`/`fail`/`finish`). It is sourced, not run — `run-tests.sh`
only collects `test-*.sh`, so it is never picked up as a suite.

## Portability

The suites run on Linux, macOS and Windows, which means writing to the smaller
shell: POSIX `sh`-compatible regular expressions, and no GNU-only flags. Every
trap below has been sprung here, and each one first arrived looking like
something else.

`sed -i` is GNU-only. BSD sed, which is what macOS ships, reads the next argument
as a mandatory backup suffix, so `sed -i 's/a/b/' file` eats the filename and
fails. Use `sed_i` from `helpers.sh`, which takes the same arguments with the
file last.

`\+` in a basic regular expression is a GNU extension. BSD `sed` and `grep` match
a literal `+` instead, which is worse than an error: the pattern simply never
matches and the check silently passes. Write `[0-9][0-9]*` rather than `[0-9]\+`.
The same rule holds for the plugin scripts, where such a match decides whether
`verify` sees an unrecorded row.

Two more BSD sed forms: a block's last command needs its own `;` before the `}`
(`{n;s/a/b/;}`), and `1i text` is GNU-only — prepend with the shell instead.

**macOS ships bash 3.2, and the plugin scripts have to run on it.** Brace any
variable a multi-byte character follows: `"${s}━"`, never `"$s━"`. Unbraced,
bash 3.2 scans the character's leading byte as part of the name and looks up
`s━`, which under `set -u` is fatal — and the error names `s━`, whose trailing
bytes are invisible in a terminal and stripped by most log viewers, so it reads
as a complaint about `s` on the line where `s` was just assigned.
`tools/lint-shell.sh` refuses the unbraced form. Nothing from bash 4 is available
either — no `declare -A`, `mapfile`, `${var,,}` or `wait -n`.

**There is no UTF-8 locale to ask for.** macOS's awk counts bytes whatever
`LC_ALL` says — all four candidate locales were tried and each answered 3 for one
character — so anything that needs character semantics does its own UTF-8
arithmetic over bytes: a byte in 0x80-0xBF continues a character, every other byte
starts one. `task-graph` truncates labels that way, `cue_display_width` measures
that way, and the suites count that way. Scripts export `LC_ALL=C`, which resolves
everywhere; naming a locale that does *not* resolve is what makes awk abort
mid-file with `towc: multibyte conversion failure` rather than merely count
differently.

Three rounds of CI went into asking for a locale instead, and the byte-cut labels
that came out of the last attempt surfaced two suites away as `sed: RE error:
illegal byte sequence` — a message about neither labels nor truncation.

`printf` escapes are part of the same trap: `\xNN` is not processed by bash 3.2,
which emits the escape as text. Use octal `\NNN`, or a literal character.

**A bracket range is resolved by the locale's collation order.** macOS's default
locale interleaves the cases, so `K` sorts inside `a-z` and `case $v in [a-z][a-z])`
accepted `language=KO` there while rejecting it everywhere else. Use a character
class — `[[:lower:]]` — which is not collated.

`test-shell-portability.sh` exercises all of these directly, so a shell or a tool
that lacks one says which one rather than failing somewhere else.

Errors must not be swallowed. A test that runs a script as
`cmd >/dev/null 2>&1` under `set -e` reports the exit code and discards the
message, which cost two CI rounds on a macOS failure that said only `exit 2`.
Capture the output and print it in the failure.

## Shell lint

```bash
tools/lint-shell.sh            # changed scripts
tools/lint-shell.sh --all      # every script
tools/lint-shell.sh --format   # apply shfmt
```

`tests/shell-lint/test-lint-shell.sh` tests the linter itself and does run as part
of `run-tests.sh`. Running the linter over the repository is a separate step.

## What these suites do not cover

They check that an instruction is in place, not that the model follows it. That
second half is only visible in a real cycle, so it is checked by running one and
harvesting what went wrong.

There is no suite here that drives a real session. The one that existed was
removed: it had never been shown to run, and by the time it was tried it could
not — its runner reported an authentication failure as `[FAIL]`, the exact shape
this file warns about. Bringing that layer back means writing it against a session
that is actually available, and giving it a skip path that says "not run" rather
than "failed".

## Adding a suite

Name it `test-*.sh` under `tests/` and `run-tests.sh` picks it up with no
registration step. Source `helpers.sh`, build a fixture with `new_repo`, end with
`finish`. Keep it independent of every other suite — they run concurrently.

Write the assertion labels so a failure reads as a sentence about the contract
("exit 1 when the marker is missing"), not about the mechanics. The label is what
someone sees six months from now with no memory of why the check exists.
