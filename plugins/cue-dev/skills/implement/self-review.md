# Implementing in this session

**The procedure for an item whose `check:` is `self-review`.**
`<cue>/work-check <KEY> --plan` sent you here.

[SKILL.md](SKILL.md) holds what both procedures share: the six invariants, the
row format, the two header fields, and the gate and marker at the end. It
deliberately holds no method. This file is the method.

**This is not a lighter process. It is the same process with one participant.**
Every task still gets its tests, its own commit, its row and its evidence. What
differs is who reads the diff, and that difference is the whole of what
`checked-by` records. Invariant 1 is the one that bends here, and it bends by
being written down rather than by being skipped.

**You do not choose this path.** It is the item's recorded level. If you are here
because a dispatch could not be made rather than because the item asked for it,
that is legitimate — and the record says `self-review` with the reason in the
Summary, never `independent-review`.

## The loop, per task

```
  implement, test, commit ─▶ read this task's own diff ─▶ fix what it finds
                                                              │
                                          ┌───────────────────┴──────────────┐
                                       clean                            not fixable here
                                          │                                  │
                                          │                            park it with a ruling
                                          ▼                                  │
                            record the row in outcome.md and commit it ◀──────┘
                                          │                  (invariant 4)
                                          ▼
                                  next task, or the final read
```

**One task at a time, in order, and one commit per task.** The row's SHA field
holds *that task's* last commit, and `<cue>/verify` refuses a SHA that appears
twice — so implementing three tasks and committing them together leaves two rows
with no honest value to write. A task that genuinely produced no commit is
`no-commit`; a task whose work is inside another task's commit is a task that was
not implemented separately.

**Continuous execution.** Do not stop between tasks to check in.

### 1. Implement it

Read the task from `.cue/dev/<KEY>/plan.md` — its `Files`, `Interfaces`, `TDD`
line and steps. The `Files` list is the task's scope (invariant 2): touching
something outside it is allowed when the work requires it, and it goes in the
task's row.

**The `TDD` line decides what invariant 3 needs from you.** For `evidence-only`
and `required`, a test is seen failing first and the RED output is what you
carry into the row's evidence — not "tests pass afterwards", which a test
asserting nothing also produces. Use cue-dev:test-driven-development.

Commit the task's work with a subject in the record language.

### 2. Read the diff you just wrote

```bash
git diff <task-base>..HEAD
```

where `<task-base>` is the commit you were on before this task. **This is
invariant 1 doing what it can here, and it is worth doing properly even knowing
its limit** — you are conditioned on the choices you just made, so the findings
it produces are the shallow ones. Look for the shallow ones deliberately:

- **Spec:** does the diff do what the task asked, and nothing the task did not
  ask for? Extra scope is the most common finding on this path, because there is
  nobody to notice it later.
- **Against the plan's Global Constraints:** exact values, exact formats, stated
  relationships. Re-read them; do not recall them.
- **Test hygiene:** does each new test fail when the behaviour it covers is
  broken? A test that would pass against an empty implementation asserts nothing.
- **Leftovers:** debug output, commented-out code, a TODO you wrote in passing.

Use cue-dev:receiving-code-review on what you find — the point of that skill is
that a finding is evaluated rather than either performed on or waved away, and
that applies to your own findings too.

**Fix what you find, in the same task, before the row goes in.** A fix here is
part of the task and leaves no trace in the record — the code already matches the
plan. What does go in the row is anything you decided not to fix, as
`[parked: <finding> — ruling: <why the code stands>]`.

**If a finding means the plan is wrong**, that is not yours to fix quietly. The
row records it as `deviated` with the reason, and if following the plan has become
pointless, stop and say so: `/cue-dev:redo plan` is the path and it is the user's
call.

### 3. Record the row and commit it

Format and rules in [SKILL.md](SKILL.md). Every time a task finishes, in the same
breath — not batched at the end.

## The final read

Once every row is in, one pass over the whole branch rather than the task:

```bash
git diff $(<cue>/work-base <KEY>)..HEAD
```

(`work-base` prints where the branch started; without a recorded start point,
`git merge-base main HEAD`.)

What this pass is for is what the per-task reads structurally cannot see:

- **Between tasks** — two tasks solving the same problem twice, an interface one
  task produced that another quietly stopped using, a constraint honoured in
  task 2 and forgotten by task 7.
- **The shape of the whole** — is this the change the design described? Read
  `design.md`'s "What we build" beside the diff.
- **The acceptance criteria** in `demand.md`, one at a time, against what is
  actually in the tree.

Then go to [SKILL.md](SKILL.md), **"Closing the record"** — the Summary, the two
header fields, the gate and the marker.

## Rationalizations specific to this path

The shared ones are in [rationalizations.md](rationalizations.md).

| Excuse | Reality |
|--------|---------|
| "Reviewing my own diff finds nothing, so skip it" | It finds the shallow half, which is more than nothing and is the half that otherwise reaches the PR. Doing it badly is what makes it worthless, not doing it at all. |
| "self-review means the process is lighter" | It means one participant. The tests, the commits, the rows and the evidence are unchanged — that is why `checked-by` records only the one thing that did change. |
| "I'll batch these three small tasks into one commit" | Then three rows share one SHA, verify refuses it, and the record cannot say which commit delivered which task. |
| "I read the diff as I wrote it" | Writing and reading are the same pass then, which is the pass invariant 1 is about. Read it after the commit, as a diff. |
| "Nothing to park, so nothing to write" | `as-planned` is the record for that, and it is one line. `unrecorded` reads as "not done". |
