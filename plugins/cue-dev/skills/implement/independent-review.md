# Implementing with independent review

**The procedure for an item whose `check:` is `independent-review`.**
`<cue>/work-check <KEY> --plan` sent you here. Read it through before your first
dispatch — the loop is not recoverable from the diagram alone.

[SKILL.md](SKILL.md) holds what both procedures share: the six invariants, the
row format, the two header fields, and the gate and marker at the end. It
deliberately holds no method. This file is the method.

**Everything below is one way of satisfying the six invariants on today's
harness.** The invariants are not negotiable; the mechanisms are. The sections
marked **[binding]** are the ones that exist because of what the harness can and
cannot do — when that changes, delete them rather than maintaining them. Nothing
in SKILL.md should need an edit.

**This file used to be two.** The dispatch procedure lived in a separate
`harness-claude-code.md`, reached from a table cell in SKILL.md that said "the
loop below, in full". A real run of an `independent-review` item never opened it,
implemented all eight tasks in the controller session, and committed six of them
as one commit. The abstraction was right and its cost was a file nobody read;
what replaces it is the marking above.

One full run of this loop, end to end, is in
[example-workflow.md](example-workflow.md).

## What the binding assumes **[binding]**

| Assumption | Serves | If it stops being true |
|---|---|---|
| A subagent can be dispatched with a fresh context | invariant 1 | fall back to [self-review.md](self-review.md) and record `checked-by: self-review` |
| A live subagent can be sent another message | invariant 6 | dispatch a fresh implementer carrying the brief and report paths — the report file is the persistent memory either way |
| A model can be chosen per dispatch | cost only | drop the tiers below; no invariant moves |
| Conversation memory does not survive compaction | invariant 5 | already handled — the committed rows are the resume point, not a scratch file |

That last row has already paid off once: this skill used to keep a `progress.md`
ledger in the workspace, and every rule about identifying it, resuming from it and
copying it into outcome.md went away the moment the rows themselves became
commits.

## The loop, per task

```
  dispatch ─▶ implement, test, commit ─▶ review the diff (invariant 1)
                                              │
                        ┌─────────────────────┴──────────────┐
                     clean                                findings
                        │                                     │
                        │                            fix round ─▶ scoped re-review
                        │                                     │  (bounded — invariant 6)
                        │                              ┌──────┴──────┐
                        │                          addressed     cap reached
                        │                              │              │
                        │                              │          adjudicate:
                        │                              │          park, or STOP
                        ▼                              ▼              ▼
                  record the row in outcome.md and commit it  ◀───────┘
                        │                        (invariant 4)
                        ▼
                  next task, or the final review
```

**The row goes in as each task finishes** — format and rules in
[SKILL.md](SKILL.md). Do not batch them.

## The language line

SKILL.md had you run `<cue>/config --get language` at setup. **Every dispatch
prompt carries this**, whatever the code turned out to be:

```
Write your report and any prose in `<language>`. The brief, the plan and this
prompt are English by repository convention; that is not an instruction about
your output language. A commit subject is prose and follows `<language>` too —
only the machine-read parts stay fixed: cue-dev's own markers
(`cue-dev(<stage>): <KEY>`), the conventional-commit type prefix (`feat:`,
`fix:`, …), code, identifiers, paths, and outcome.md status tokens.
```

Carry it even when the value is `en` — a rule with an exception is a rule that
gets forgotten on the branch where it matters. **Subagents inherit no hooks and no
session context**, so a language set in `.cue/dev/config` reaches them only if you
put it there.

## Dispatching an implementer **[binding]**

`<cue>` is the scripts directory named in your session context.

Record BASE (`git rev-parse HEAD`) before dispatching — the review package and the
fix-round diffs need it.

- **Workspace.** Run `<cue>/sdd-workspace PLAN_FILE` once at skill start. It
  prints this item's git-ignored directory (`<repo-root>/.cue/dev/sdd/<KEY>/`),
  home to briefs, reports and review packages. Another item's directory is never
  yours to read or write.
- **Task brief.** Run `<cue>/task-brief PLAN_FILE N` — it extracts the task's
  full text to a uniquely named file and prints the path. **Never make a subagent
  read the whole plan file.**
- **The dispatch** contains: (1) one line on where this task fits; (2) the brief
  path, introduced as "read this first — it is your requirements, with the exact
  values to use verbatim"; (3) interfaces and decisions from earlier tasks the
  brief cannot know; (4) your resolution of any ambiguity you noticed in the
  brief; (5) the report-file path and report contract; (6) the language directive
  above. Exact values (numbers, magic strings, signatures, test cases) appear
  **only in the brief**.
- **Report file.** Name it after the brief (`…/task-N-brief.md` →
  `…/task-N-report.md`). The implementer writes the full report there and returns
  only status, commits, a one-line test summary, and concerns.
- **A dispatch describes one task, not the session's history.** Do not paste
  accumulated prior-task summaries into later dispatches — a real session's
  dispatch reached 42k characters, 99% of it pasted history.
- If an earlier task parked a finding in the area this task touches, carry a
  pointer to it.
- Record the implementer's agent identity — fix rounds 1-3 resume this agent.
- **Never dispatch implementation subagents in parallel.** They conflict.

Template: [implementer-prompt.md](implementer-prompt.md). The TDD line in the
brief (`evidence-only` · `required` · `n/a`) decides what the report must carry:
for the first two, the RED command and its output (invariant 3).

Everything you paste into a dispatch — and everything a subagent prints back —
stays in your context for the rest of the session and is re-read every turn. **Hand
artifacts over as files.**

**The report files are not scratch you clean up here.** They are what
`<cue>/evidence` counts when you come to write `checked-by`, and the only trace on
disk that the loop ran at all. `/cue-dev:finish` removes the workspace; leave it
alone.

## Handling the report

**DONE:** generate the review package and dispatch the task reviewer.

**DONE_WITH_CONCERNS:** read the concerns first. Correctness or scope concerns get
addressed before review; observations ("this file is getting large") are noted and
you proceed. A file touched outside the brief's `Files` arrives here (invariant 2)
— it belongs in the task's row.

**NEEDS_CONTEXT:** provide what was missing and re-dispatch, same model.

**BLOCKED:** assess. A context problem → more context, same model. Needs more
reasoning → a more capable model. Too large → break it up. The plan itself is
wrong → escalate to the human.

**Never** ignore an escalation or force the same model to retry unchanged. If the
implementer asks questions, answer them completely before it starts.

## Reviewing the task (invariant 1)

- Hand the reviewer its diff **as a file**: `<cue>/review-package PLAN_FILE BASE
  HEAD` prints the path it wrote. Use the BASE you recorded — **never `HEAD~1`**,
  which silently drops all but the last commit of a multi-commit task. The diff
  never enters your own context.
- **Reviewer inputs:** the brief file, the report file, the review package path,
  and the global constraints that bind the task.
- The constraints block is the reviewer's attention lens. Copy the binding
  requirements **verbatim** from the plan's Global Constraints: exact values,
  exact formats, stated relationships ("same layout as X"). The template already
  carries the process rules; this block is for what THIS project demands.
- Do not add open-ended directives ("check all uses", "run race tests if useful")
  without a concrete reason.
- Do not ask a reviewer to re-run tests the implementer already ran on the same
  code — the report carries the evidence.
- **Do not pre-judge.** Never instruct a reviewer to ignore or downgrade a
  specific issue. If your prompt contains "do not flag", "don't treat X as a
  defect", "at most Minor", or "the plan chose" — stop. You are sparing yourself a
  review loop.

Both verdicts are required: spec compliance **and** code quality. Implementer
self-review never replaces this.

A reviewer may report "⚠️ Cannot verify from diff" — requirements living in
unchanged code or spanning tasks. These do not block the review, but **you** must
resolve each before completing the task; you hold the cross-task context it
lacks. A confirmed gap enters the fix loop.

Template: [task-reviewer-prompt.md](task-reviewer-prompt.md).

## The fix loop (invariant 6)

Triggers on: spec ❌, any Critical or Important finding, or a ⚠️ item you confirmed.

Two routes leave immediately:

- **Minor findings** never enter the loop. Put them in the task's row as
  `[parked: … ]` and point the final review at them. A roll-up nobody reads is a
  silent discard.
- **A plan-mandated finding** is the human's decision: present the finding and the
  plan text, ask which governs. Do not dismiss it because the plan mandates it,
  and do not dispatch a fix that contradicts the plan without asking.

Everything else enters. One round = one fix dispatch plus one scoped re-review.
**Five rounds maximum per task.**

**Rounds 1-3 — resume the original implementer.** Send the open findings verbatim;
its context is intact.

**Rounds 4-5 — a fresh implementer on a more capable model,** with the brief path,
the report-file path, the open findings, and: "A prior implementer attempted this
task [N] times; you own it now. Read the report file for what was tried." A loop
surviving three resumes usually means the implementer cannot see its own problem.

**Every round:** the implementer fixes, re-runs the tests covering the amended
code, appends its fix report to the same report file, and returns the short
contract. Confirm the fix report carries the covering tests, the command, and the
output before re-dispatching the reviewer.

**The re-review is scoped.** `<cue>/review-package PLAN_FILE FIX_BASE HEAD`
where FIX_BASE is the head the previous review saw. The re-reviewer verdicts each
finding ADDRESSED or NOT ADDRESSED and flags new breakage in the fix diff only.
New Critical/Important breakage joins the open list. Out-of-scope observations
become parked minors — they never extend the loop.
Template: [re-review-prompt.md](re-review-prompt.md).

**Never fix findings yourself in the controller session.** Controller fixes skip
review, and your context is for coordination.

**The breaker.** When round 5's re-review still leaves findings open, stop
dispatching and adjudicate each one yourself:

- **Reviewer wrong, or contestable:** park it with a ruling saying why the code
  stands.
- **Real, but nothing downstream builds on it:** park it, ruling that it is real
  and deferred.
- **Real and load-bearing** — a later task builds on it, or it reveals a plan
  defect: **STOP.** Report to your human partner with the finding, the plan text
  it collides with, and the fix history. Parking a structural failure lets every
  dependent task build on it.

Adjudicate **only at the cap**. Adjudicating earlier to end a loop is pre-judging
with a different name. Every ruling goes into the task's row — a silent discard is
forbidden.

## The final review

`<cue>/review-package PLAN_FILE MERGE_BASE HEAD` (MERGE_BASE = where the branch
started — `<cue>/work-base <KEY>` when the item recorded one, otherwise
`git merge-base main HEAD`), dispatched on the most capable model with
cue-dev:requesting-code-review's
[code-reviewer.md](../requesting-code-review/code-reviewer.md). Its `[DIFF_FILE]`
is the path review-package printed, `[PARKED_FINDINGS]` is the `[parked: … ]`
lines from outcome.md with their rulings, and `[LANGUAGE_DIRECTIVE]` and
`[MODEL]` are required there exactly as they are in the three templates above —
that reviewer's findings are the ones a human reads.

If it returns findings, dispatch **ONE** fix subagent with the complete list — not
one fixer per finding. Per-finding fixers each rebuild context and re-run suites;
a real session's final-review fix wave cost more than all its tasks combined. Then
exactly one scoped re-review of the fix range. Adjudicate residuals as in the
breaker. **There is no second fix wave** — residual load-bearing findings are
grounds to stop and report.

**Then go back to [SKILL.md](SKILL.md), "Closing the record".** The Summary, the
two header fields, the gate and the marker are the same for both procedures and
live there.

## Model selection **[binding]**

**Turn count beats token price.** Wall-clock and context cost scale with how many
turns a subagent takes, and the cheapest models routinely take 2-3× the turns on
multi-step work — costing more overall.

| Role | Tier |
|---|---|
| Task whose plan text contains the complete code (transcription plus testing) | cheapest |
| Single-file mechanical fix | cheapest |
| Multi-file integration, pattern matching, debugging | standard |
| Design judgment or broad codebase understanding | most capable |
| Task review | scaled to the diff's size and risk |
| Scoped re-review of a small fix | cheap-to-mid |
| Final whole-branch review | most capable |
| Fix rounds 4-5 | one tier above the implementer that got stuck |

**Always specify the model explicitly.** An omitted model inherits the session's —
often the most expensive.

## Rented, not owned **[binding]**

Parts of this file exist because of what the harness cannot do yet. When that
changes, delete them rather than maintaining them.

| Part | What makes it unnecessary |
|---|---|
| The model tier table | harness-level routing that picks per role |
| Brief extraction and file hand-off | contexts large enough that pasting a plan costs nothing |
| Resuming an implementer for rounds 1-3 | a native primitive for "same worker, new findings" |
| The five-round cap | nothing — invariant 6 stands. Only the number is a mechanism. |

## Rationalizations specific to this loop

The shared ones are in [rationalizations.md](rationalizations.md).

| Excuse | Reality |
|--------|---------|
| "This task is small, I'll just do it here" | Then invariant 1 is gone for that task and nothing records it. The level is the plan, not a bar to clear per task. |
| "I'll dispatch, but review it myself to save a call" | You did not write the code, so this is not the failure invariant 1 names — but you *chose* the brief and resolved its ambiguities, and the reviewer's job is to catch what that framing missed. |
| "The subagent's report says it is done" | The report is a claim by the party with the most reason to make it. That is what the task reviewer is for. |
| "I'll clean up the workspace now that the tasks are done" | Those reports are the only on-disk trace that the loop ran, and `<cue>/evidence` counts them before you write `checked-by`. finish removes them. |
