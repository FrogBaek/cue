---
name: implement
description: Use when executing implementation plans with independent tasks in the current session
---

# Executing a plan

**Speak the repository's language.** The first script this skill runs — `<cue>/gate`,
or `<cue>/init-check` — prints a `language` line. **Everything you say to the user
goes in that language, starting with your first sentence**: the questions you ask,
not only the record you write at the end. This skill body is English because it is
the plugin's source, not because it is your output. Template headings, commit
markers, `outcome.md` status tokens, paths and code stay exactly as written.


Turn an approved plan into commits, and leave a record that says honestly what
happened — including where it diverged and what was left over.

**Announce at start:** "I'm using the cue-dev:implement skill to execute the plan."

**Narration:** between tool calls, narrate at most one short line — the records
and the tool results carry the rest.

**Continuous execution:** Do not pause to check in between tasks. The only reasons
to stop are a blocker you cannot resolve, ambiguity that genuinely prevents
progress, or all tasks complete. "Should I continue?" wastes your human partner's
time — they asked you to execute the plan.

## This file does not contain the method

There are two ways to execute a plan and this item has already been assigned one.
**The procedure lives in its own file, and you read exactly one of them:**

| the item's level | the procedure |
|---|---|
| `independent-review` | [independent-review.md](independent-review.md) |
| `self-review` | [self-review.md](self-review.md) |

`<cue>/work-check <KEY> --plan` prints which, with the path. **Do not read the
other one, and do not proceed from this file alone** — what is here is the record
and the gate, which are identical either way.

**The split is not tidiness.** This file used to carry both: `self-review`
written out in full, `independent-review` as a table cell pointing at a linked
`harness-claude-code.md`. A real run of an item whose header said
`independent-review` read this file to the end, found a complete and usable
procedure in it, never opened the link, implemented all eight tasks in the
controller session, and committed six of them as a single commit. Nothing in the
file was wrong. The path of least resistance was simply the wrong path, and the
right one was behind a link. So there is no longer a procedure here to fall into.

## What must be true when you are done

These six are the whole of this skill. Everything else — how you dispatch, which
model, how many fix rounds, whether there is a dispatch at all — is one way of
satisfying them.

| # | Invariant | Why it is not negotiable |
|---|---|---|
| 1 | Each task's diff is read by something that did not write it | A context that wrote the code is conditioned on its own choices. Self-review is systematically blinder, whatever the model. |
| 2 | An implementer does not silently exceed its task's `Files` | Scope that grows without a record is invisible until the final review. |
| 3 | A test was seen failing, and the RED output is in the record | A test nobody watched fail may assert nothing, and a passing run cannot reveal that. |
| 4 | Every task has its row in `outcome.md`, written when it finishes | The row is the record and the resume point. Written later, it is written from memory. |
| 5 | The work is resumable after a break or a compaction | Re-dispatching a completed task is the most expensive failure observed. |
| 6 | The fix loop is finite and ends at a human | Otherwise a disagreement with a reviewer runs forever. |

**Invariant 1 is the one the two procedures answer differently**, and
`self-review.md` says plainly which part of it it cannot deliver. That is what
`checked-by` records.

**If your harness cannot supply the mechanism for one of these, say which
invariant is weakened and record it** — see "Closing the record" below. Degrading
loudly is fine. Degrading silently is what this skill exists to prevent.

## Prerequisite check

**Run this first.**

```
<cue>/gate implement
```

`<cue>` is the scripts directory named in your session context.
**On exit 1, stop and relay the `now` lines.** On exit 0 it prints the KEY;
`.cue/dev/<KEY>/plan.md` and `.cue/dev/<KEY>/outcome.md` are your inputs.

**`outcome.md` is the only one of the four records this stage writes.** demand.md,
design.md and plan.md are inputs and stay exactly as they were committed —
including when the plan turns out to be wrong halfway through, which is what the
`deviated` row and its `reason:` line exist to record. A plan edited to match what
was actually built stops being a plan and becomes a second copy of the diff, and
the divergence it was hiding is the one thing a reviewer cannot recover from the
code. If the plan is wrong enough that following it is pointless, stop and say so:
`/cue-dev:redo plan` is the path, and it is the user's call, not yours.

`/cue-dev:plan` creates the outcome.md skeleton. Do not create it here instead —
you would start with a task count that disagrees with the plan.

The plan this skill executes is `.cue/dev/<KEY>/plan.md`. Every `PLAN_FILE` in the
procedure files is that path.

## How this item is checked — read it, do not decide it

```bash
<cue>/work-check <KEY> --plan
```

**This is the second thing you run, and its `procedure` line is where you go
next.** It prints the level the user chose at `/cue-dev:start`, where that answer
came from, the method that level means, the path to that method, and the
`checked-by` value the record will carry.

**Both paths carry all six invariants.** `self-review` is not a lighter process;
it is the same process with one participant.

**Do not form your own view of which is warranted here.** This used to be
unanswerable: the config held a *floor*, a floor says only what may not happen,
and so this skill decided per run from the shape of the plan. Two runs of one item
took different paths, and neither was written down as a choice anyone made. The
value is now a per-item record precisely so that there is nothing left here to
judge.

**If the level says `independent-review` and a dispatch genuinely cannot be
made**, follow [self-review.md](self-review.md) instead, record `checked-by:
self-review`, and say so in the report. **Record what happened, never what was
asked for** — the gap between the two is the one thing this pair of fields exists
to show, and `/cue-dev:finish` puts it in front of a human rather than passing it.

## Setup

Ensure the work happens in an isolated workspace: use
cue-dev:using-git-worktrees to create one or verify the existing one. **Never
start implementation on a main/master branch without explicit consent.**

Read the plan once, note its context and Global Constraints, and create a todo per
task.

**Run this once, whichever procedure you are on:**

```
<cue>/config --get language
```

It prints a two-letter code — `en` unless the repository says otherwise. Every
commit subject you compose follows it. On the `independent-review` path it also
goes into every dispatch prompt; that file carries the exact wording.

**This rule used to say "commit messages are unaffected", and that was wrong in a
way nothing caught.** It was written to protect the cue-dev markers — `status`
and `gate` parse the stage out of `cue-dev(design): <KEY>`, so a translated
marker breaks the state machine. But "commit message" is not "marker", and the
exemption swallowed every ordinary commit subject with it: a `ko` repository got
`feat: add navigation links to pages 3 and 4`, sitting in a history whose records
were all Korean. What has to stay fixed is what a machine reads. A subject line
is read by people, and it follows the setting like the rest of the prose.

**Before starting Task 1, scan the plan once for conflicts:**

- tasks that contradict each other or the Global Constraints
- anything the plan mandates that the review rubric treats as a defect (a test
  that asserts nothing, verbatim duplication of a logic block)

Present everything you find as **one batched question** — each finding beside the
plan text that mandates it, asking which governs — before execution begins, not
one interrupt per discovery mid-plan. If the scan is clean, proceed without
comment.

**Then go to your procedure file.** Come back here when every row is in.

## Recording the row

**Every time a task finishes, replace its `- <N> · unrecorded` row in
`.cue/dev/<KEY>/outcome.md` and commit it in the same breath.**

```bash
git add .cue/dev/<KEY>/outcome.md
git commit -m "chore: <record task N, in the record language> — <KEY>"
```

**The subject follows `.cue/dev/config`'s language, like every other commit this
plugin makes.** `chore:` is a conventional-commit type and tooling matches on it,
so the prefix stays English; the `— <KEY>` suffix is an identifier and stays as
it is. What sits between them is a sentence a person reads. Written out in full,
the English form of it is `record task <N>` — that is an example of the wording,
not the wording.

This is the same rule `/cue-dev:plan` states for the commit subjects it writes
into tasks, and it is stated again here because this is the one commit subject
this skill composes itself. A real `ko` repository ended up with `feat:` subjects
in Korean, written from the plan, sitting between `chore: record task 1 —
<KEY>` and `chore: record task 2 — <KEY>` in English, because the plan's rule had
nowhere to reach this line.

**The dividing line, once, for the whole plugin: a subject *you* compose follows
the record language; a subject a *script* composes does not.** `<cue>/marker`'s
stage markers are the whole of the second group. They are English because a shell
script cannot write a sentence in a language it was not given, and because
`scripts/status` matches the markers as strings. Everything else in the history is a sentence a person reads,
and it is written in their language.

Do not add or remove rows — **replace only**. Do not batch the rows up until the
end; by then you no longer remember what changed or why.

**Committing each row is what makes the record durable, and it replaces the
progress ledger this skill used to keep.** outcome.md sits in a working tree that
subagents also touch, and a task's row has been wiped there by a subagent's
cleanup. Committed, it survives that, it survives a compaction, and `git log`
shows exactly how far the work got — so there is no second file to keep in sync
and nothing to copy over before deleting a workspace.

**Row format**

```
- <N> · <SHA> · as-planned | deviated | skipped
    [deviated: <kind> — <planned> → <actual> · reason: <what you learned while implementing>]
    [dropped: <attempt> → <why it didn't work>]
    [deferred: <item> · <ticket ID>]
    [parked: <finding> — ruling: <why the code stands>]
```

- `<SHA>` is that task's last commit (7 chars). The result is **one of three
  values only**.
- **A task that produced no commit is recorded as `no-commit`, in the SHA slot.**
  A verification task, a task whose whole content turned out to be already done —
  they exist, and until this value did, the field had no true answer and got a
  neighbouring task's SHA instead. A real run recorded task 10 against task 9's
  commit and every gate passed. `verify` refuses a SHA that appears twice, so the
  substitution is caught now; this is what to write instead.
- For `as-planned`, the single line is the whole row. **One line is the normal
  case for most tasks.**
- Add a bracket line only when that fact actually exists. No free-form prose.

```
- 3 · a7f3c21 · as-planned
- 4 · 91b2e04 · deviated
    [deviated: data structure — in-memory Map → Redis SETEX · reason: integration
     tests confirmed every session is lost on each process restart]
- 5 · 5c1d8ff · skipped
    [deferred: admin audit log · PROJ-151]
```

**You already hold the evidence.** Do not go back for it.

| Source | What it gives you |
|---|---|
| plan.md task ↔ the task's commit diff | whether it diverged from the plan |
| the implementer's report, or your own read of the diff | why it diverged · what was deferred · what was dropped |
| review results | differences a reader found |
| `DONE_WITH_CONCERNS` · parked findings | what was accepted and moved past |

**Review-finding filter** — one criterion: **does it survive the fix?**

```
record        the plan itself proved wrong / deferred out of scope / accepted as is
don't record  added something missing / removed over-implementation / renaming
```

Findings fixed inside the loop leave no trace in the result — the code already
matches the plan. Parked findings and anything that blocked do remain.

## Closing the record

**Reached from either procedure file, once every row is in and the whole-branch
review it describes is done.**

1. **Write the `## Summary` section.** A few lines on where plan and result
   diverged and what was left behind. If nothing diverged, one line is enough.
2. **Carry over everything the reviews left unfixed** — parked findings with their
   rulings, checks you could not run, tests that did not exist to run, anything a
   human has to look at, and any commits outside the plan with the reason. What
   matters six months from now is **what was left over**, not that it passed.
3. **Fill in `checked-by` and `evidence`**, below.

**Do not delete the plan's workspace here.** `/cue-dev:finish` does it. The briefs
and reports are what `<cue>/evidence` counts in the next step, and a run that
tidied them away first is a run that answered the next question from memory.

### The two header fields

```
checked-by: independent-review | self-review | none
evidence:   red-output | tests-only | manual | none
```

**Two lines. Replace the value on each; never join them.** `scripts/outcome-init`
already wrote both lines into the skeleton, so there is nothing to add here —
only a word to swap on each. `scripts/verify` matches them anchored to the start
of a line, so `checked-by: self-review evidence: manual` on one line parses as a
`checked-by` with no `evidence` at all, and verify says `no 'evidence:' line`.
That happened, and the joined line reached the record — which means verify either
was not run or its errors were read past. It is the gate; run it and fix what it
names.

`checked-by` is invariant 1, stated as a fact rather than a hope:

- `independent-review` — every task's diff was read by something that did not
  write it.
- `self-review` — the same context that wrote the code checked it. Say this when
  a subagent review was not available, **not** when it was skipped for speed.
- `none` — nothing read the diff.

**`none` is writable here and askable nowhere.** No item can ask for `none` —
the two levels are `independent-review` and `self-review` — so recording it always
fails `verify` and always stops `/cue-dev:finish`. **That is what the value is for,
not a reason to avoid it.** Asked for in advance it would be a standing waiver:
answered once, never seen again, the work shipping unchecked while verify passed.
Recorded afterwards it stops there, once, in front of a human who decides.

So if nothing reviewed this work, **write `none` and say why in the summary.**
Writing `self-review` because it clears the gate is the failure this field exists
to make impossible, and the gate you cleared was the one that would have told
someone.

`evidence` is invariant 3: `red-output` when failing tests were seen and their
output is in the reports, `tests-only` when tests ran but never failed first,
`manual` when a human looked, `none` when nothing was checked.

**Write what happened, never what was asked for.** What this item asked for is
`check:` in its own `demand.md` header, and `scripts/verify` compares the two — a
field that echoed the request would prove nothing. If what happened is weaker than
what was asked, the honest value plus the reason in the summary is right; quietly
writing the asked-for value is not, and it is the easier mistake now that the two
values sit in the same vocabulary.

**`manual` means a person or a tool looked, in this session, and you can say
which call.** Run this before you write either line:

```bash
<cue>/evidence <KEY>
```

It prints what the record currently claims, the design's own "How we know it
works", and — for an item that asked for `independent-review` — how many
implementer reports are actually sitting in the workspace. Then it asks which tool
call in this session produced each of those observations. **Answer it before
writing the values.** No call, no observation: the value is `none` and the reason
goes in the summary.

**The report count is a fact, not a verdict.** Zero reports under an item that
asked for `independent-review` means either that no task was dispatched or that
the workspace has been cleaned since, and the script says exactly that rather than
choosing. You know which. It is not a gate because the two cases are
indistinguishable from disk, and a gate that cannot tell them apart would
eventually be cleared by writing a `checked-by` that was not true — which is the
one failure this field exists to prevent.

This is where the worst thing this plugin has produced starts. A run whose final
task was "integration test and final verification" did `find`, `head -5` and
`grep` — three calls, no page rendered, no script executed — while the design's
five acceptance lines every one required a browser. It wrote `checked-by:
self-review` and `evidence: manual`, `verify` passed, and by the time `finish`
read the field it was a fact of record; the four sentences of invented eyewitness
testimony came later, downstream, from a value nobody could go back and question.
**finish checks this too, and the duplication is deliberate:** there the claim is
already committed, and here it is still a question.

## Before you hand off

```bash
<cue>/verify <KEY> --stage implement
```

This is the gate. It checks that the rows match the plan's task count, that none
is still `unrecorded`, that each row names a commit that exists, that no commit is
recorded for two tasks, that each of those commits is on this item's branch, and
that `checked-by` is not below the level **this item** asked for in its own
`demand.md` header. **Fix what it names before handing off** — every one of these
shows up in the PR diff otherwise.

**Then stamp the marker. This commit is the end of implement.**

```bash
git add .cue/dev/<KEY>/outcome.md
git commit --allow-empty -m "$(<cue>/marker outcome <KEY>)"
```

It carries the final review's work — the `## Summary`, `checked-by` and
`evidence` — which the per-task row commits have no place for. **Stamp it here
and nowhere else.** Verify has just passed, so the record this marker names is
complete; that is what the marker means and it is the only moment it is true.
Stamping it any earlier claims a result before the review that produced it, and
`scripts/gate` will not let finish run until it exists.

**Do not write the marker string by hand.** The prefix can differ per repository
(`.cue/dev/config`); `scripts/marker` reads the settings and emits the finished
subject. A hand-assembled marker fails silently — the commit succeeds and only
that stage becomes invisible.

**`marker` runs the verify above itself and prints nothing if it fails**, so git
aborts on the empty subject and the outcome marker is not stamped. Running verify
first is still right — it is where you fix things with the work in hand — but the
line above is no longer the only thing standing between an unfinished record and
a stamp claiming it is done. That is deliberate: in a real run this verify was
skipped and the marker went on anyway.

**`--allow-empty` is deliberate.** The marker is a stamp, not a payload, and
whether anything is left to stage here depends on which commit happened to sweep
the final review's edit in. That is not a fact this command may fail on: it did,
in a real session, and the marker was lost while everything else looked finished.

```bash
<cue>/notice "IMPLEMENT done" <<'EOF'
  key       <KEY>
  tasks     <N> (deviated <D> · skipped <S>)
  commits   <base7>..<head7>
  checked   <checked-by> · <evidence>
  artifact  .cue/dev/<KEY>/outcome.md

  next      /cue-dev:finish
  rewind    /cue-dev:redo implement
EOF
```

**Reproduce its output verbatim in your reply, in a fenced code block, and put it
last.** Anything you need to say goes *above* it — a decision you need from the
user, a warning, the answer to what they actually asked. **Nothing goes under it,
and nothing restates its labels.**

**Stop here.** Do not call `/cue-dev:finish` automatically. This is where a human
reads outcome.md and fixes it — the marker does not close the file, and a
correction after it is an ordinary commit that finish carries along.

## Common Rationalizations

Shared across both procedures: [rationalizations.md](rationalizations.md). Each
procedure file carries the ones specific to it.

| Excuse | Reality |
|--------|---------|
| "I've read this file, I know what to do" | This file has no method in it. Whichever half of the work you are picturing, it came from somewhere else — read the procedure `work-check --plan` names. |
| "I'll write all the rows at the end" | By then you are reconstructing from diffs what you knew at the time. The divergence reasons are the first thing lost. |
| "The row can stay uncommitted until finish" | A subagent's cleanup has wiped a row out of the working tree already. Committed, it survives that and a compaction, and it is how the next session knows where you got to. |
| "The item asked for independent-review, so I'll write that" | Then the field records the request, not the work, and the one comparison that could have caught a weakened check is gone. `check:` is what was asked for; `checked-by` is what happened. Write what happened. |
| "Verify is a formality once the tests pass" | It checks the record, not the code. Every failure it reports is one that would otherwise surface in the PR diff, in front of a reviewer. |
