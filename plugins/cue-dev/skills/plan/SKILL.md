---
name: plan
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

**Speak the repository's language.** The first script this skill runs — `<cue>/gate`,
or `<cue>/init-check` — prints a `language` line. **Everything you say to the user
goes in that language, starting with your first sentence**: the questions you ask,
not only the record you write at the end. This skill body is English because it is
the plugin's source, not because it is your output. Template headings, commit
markers, `outcome.md` status tokens, paths and code stay exactly as written.


## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the cue-dev:plan skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `cue-dev:using-git-worktrees` skill at execution time.

## Prerequisite check

**Run this first.** It settles whether this stage may run here, against which KEY,
and what is available instead if it may not.

```
<cue>/gate plan
```

`<cue>` is the scripts directory named in your session context. Substitute that
path and nothing else — one assembled by hand fails as `command not found`.

**On exit 1, stop and relay the `now` lines** without adding a diagnosis of your
own. On exit 0 it prints the KEY; read `.cue/dev/<KEY>/design.md`.

**Do not edit design.md.** Every record belongs to the stage that wrote it, and
only to that stage. If the design turns out to be wrong while you are planning
against it, that is `/cue-dev:redo design` — a rewind the user consents to, which
discards this plan on purpose because a plan built on a design nobody approved is
not worth keeping. Editing it here would leave a design nobody approved sitting
under a commit marker that says one was, and the git history would show the
approval preceding the wording it approved.

**Do not read demand.md again.** The only input to this stage is the design.md a
human approved. Going back to the requirement means bypassing the approved design.

**Save plans to:** `.cue/dev/<KEY>/plan.md` — this path is fixed.

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during design. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. When drawing task boundaries: fold setup,
configuration, scaffolding, and documentation steps into the task whose
deliverable needs them; split only where a reviewer could meaningfully
reject one task while approving its neighbor. Each task ends with an
independently testable deliverable.

## How much TDD a task carries

**Every task declares one of three values, and the default is `evidence-only`.**

```
TDD: evidence-only   the test must be seen failing before the code exists, and
                     the RED command and its output go in the implementer's
                     report. How the work is sequenced is the implementer's
                     business.
TDD: required        the five steps below, written out, in order. Use when the
                     order itself is what you want enforced.
TDD: n/a             no test applies — documentation, a config value, a file move.
```

**What is load-bearing is the evidence, not the choreography.** A test nobody
watched fail may verify nothing, and no amount of model capability reveals that
from a passing run — so `evidence-only` still demands the RED output. But
spelling out five steps with their code blocks was written for an implementer
that needed leading by the hand; it now costs most of plan.md's bytes and buys
nothing on a task whose deliverable is obvious.

Reach for `required` deliberately: a subtle algorithm, a bug you want pinned by a
regression test before it is touched, a place where writing the test second would
let the implementation define the assertion.

**When a task is `TDD: required`, each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

For `evidence-only`, write the task's deliverable, its test target, and a commit
step. The implementer knows how to get from one to the other.

## You do not type the document's structure

`<cue>/skeleton plan <KEY> <task-count>` writes it — the header fields, `## Global
Constraints`, and one `### Task N` block per task already carrying its
`**Files:**`, `**Interfaces:**` and `**TDD:**` lines, with a `[[ ... ]]` prompt
everywhere prose goes. **You fill in the prompts and change nothing else** — except
to add steps, which is expected: one `Step 1` is written and a task usually needs
more.

`scripts/verify` errors on any `[[` that survives, so an unfilled frame cannot
reach a commit.

**It runs in "Closing out" below, after the user has approved the plan** — not
here. Everything between here and there is about what you are going to put in it.

## Output Language

**What you write into a `[[ ... ]]` goes in the repository's record language.**

```
<cue>/config --get language
```

**Everything the skeleton already wrote is structure and stays exactly as it is.**
The headings, the field names — `Goal` · `Architecture` · `Tech Stack` · `Global
Constraints` · `Files` · `Interfaces` · `TDD` · `Step N` — and the checkbox
syntax are parsed by `cue-dev:implement` and greped by `scripts/verify`. A
translated one fails a check that reads as though the field were missing: a real
session wrote `**목표:**`, was told `plan.md: no '**Goal:**' line`, and rewrote
the whole file twice.

What goes *beside* them is prose and follows this setting: the goal sentence, the
architecture sentences, the step descriptions, the constraints. File paths,
signatures and commands are neither; they are copied verbatim from the design.

**The message inside `git commit -m "…"` is prose, not part of the command.**
The `git commit -m` is a command and stays as it is; what it quotes is a sentence
a person will read, and it follows this setting like every other sentence here. A
real session read the rule above, classified the whole line as a command, and
wrote `feat: add navigation links to pages 3 and 4` into a plan whose every other
sentence was Korean.

Inside that string, one part is still fixed: the conventional-commit type prefix
(`feat:`, `fix:`, `docs:`, …) is a token tooling matches on. The prefix stays
English, the subject after it does not — `feat: <subject in the record language>`.

The templates in this skill are English. That is a fact about the templates, not
an instruction about your output — and it is the reading that keeps producing an
English plan in a `ko` repository, sandwiched between a Korean demand and a
Korean outcome.

## What the frame looks like filled in

**`scripts/skeleton` writes the shape below; these two blocks are here so you can
see what a filled-in one reads like.** Do not copy them into the file — the file
already has the structure, and copying is how a field name gets retyped wrong.

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use cue-dev:implement to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

---
```

And one task:

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

**TDD:** evidence-only | required | n/a

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

**The commit subject in that template is an example, not a language.** `feat:`
stays; `add specific feature` is prose and gets written in the record language,
like every other example in this skill. See "Output Language" above — this is the
line the rule was being read past.

## Write Interfaces as exact signatures

`Produces` / `Consumes` are not descriptions — they are **a list of symbols that
must match as strings**.

```
bad    Produces: ability to set a TTL on the session store
good   Produces: SessionStore.setTTL(id: string, ttl: number): Promise<void>
       Consumes: SessionStore.setTTL
```

Two reasons.

1. **An implementer sees only their own task.** This is the only place they learn
   the names and types a neighboring task created. Paraphrase and the implementer
   invents a name that the next task cannot find.
2. **It is the input to the dependency graph.** An A → B edge exists only when the
   same symbol appears in task A's Produces and task B's Consumes. If the strings
   drift, the graph goes silently empty.

## Files are the task's boundary

Do not write `Files` as "probably somewhere around here." It is **the range the
implementer is allowed to touch, and the baseline a reviewer compares the diff
against**.

```
bad    Modify: session-related files
good   Modify: `src/session/store.ts:40-88`
```

Keep three rules.

1. **Exact paths.** When modifying an existing file, include the line range. The
   implementer sees only their own task, so the narrower this is, the less they
   wander into the wrong file.
2. **One file in one task where possible.** If the same file appears in several
   tasks' `Modify`, those tasks are order-dependent. If so, that dependency must
   show up in `Interfaces` — if it does not, one of the two is wrong.
3. **It must agree with the File Structure above.** A file listed in File
   Structure but in no task's `Files` is a file nobody creates.

**Needing to touch a file that is not on the list is a signal of a defect in the
plan.** In that case the implementer must not silently widen scope — they report
`DONE_WITH_CONCERNS`, and the reviewer raises out-of-list changes as a finding.
That is how "the plan was wrong" surfaces during implementation — today there is
nowhere for it to surface, so scope grows quietly and only shows up in the final
review.

**The list is not a shackle, though.** Touching a file the plan did not foresee is
normal in itself. What is a problem is that happening **without a record**.

## Split documentation updates into their own task

When standing project documentation (C4, Swagger, ERD, and so on) needs updating,
**give it an independent task rather than folding it into an implementation
task**. Buried in an implementation task it gets flattened together in review,
and when it slips, nothing shows what was left undone.

This is about documents that outlive the work and are read by people who were not
here. It is not a rule that every plan carries a documentation task. A docstring,
a comment, a README line that only makes sense next to the code it describes —
those belong to the task that writes the code. Splitting them out adds a review
gate that reviews nothing.

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Get approval before the file exists

**Present the plan in the conversation and get an answer. Nothing below this line
runs until then** — not the skeleton, not the file.

This is the checkpoint the whole method is built around. cue-dev exists so a human
can judge the work from design.md and plan.md **without reading the code**, and
this is the last document they see before code starts getting written.

**Present a summary, not the plan.** The goal in one line, the task list with one
line each, and anything you had to decide that the design did not settle. That is
what a person can hold in their head and push back on; the plan itself runs to
hundreds of lines and pasting it into the conversation makes a second copy of it
that nobody reads and that starts drifting the moment the file changes.

> "<N> tasks: <one line each>. <anything you had to decide>. Shall I write this
> to `.cue/dev/<KEY>/plan.md`?"

**Ask in prose, not as a menu** — "approve, or tell me what to change" is one
proposal and free-text feedback, not a list of choices.

**And the question is the end of the reply. Do not call another tool in that
turn.** A menu makes the harness stop and wait; prose does not, and the turn that
continues past its own question is the turn that answers it. A real session asked
this exact question, tried a menu on top of it, watched the menu fail twice with
`InputValidationError` — so the user saw neither — and opened the next turn with
"Good, I'll write the plan with these nine tasks." The skeleton, the file and the
commit followed a decision nobody made. Ending the turn is the whole safeguard
here; see `cue-dev:using-cue`, "A question that failed is not a question that was
answered".

**This mirrors `/cue-dev:design`, and it used to not.** design presents the
design, gets approval, writes the file, and stops. plan wrote the file first, then
asked over the top of it, then ran `task-graph` and `outcome-init` afterwards — so
the user was asked to approve something that already existed, and the artifact was
incomplete at the moment they were shown it. Two stages, two shapes, for no
reason. The judgment being bought is the same one, and buying it before the file
exists is strictly cheaper.

**A rewrite here is free — nothing has been written.** After the commit it costs a
`/cue-dev:redo plan`, and that is what the user reaches for if they read the file
afterwards and dislike it. Say so once if it comes up; do not offer a second
review of the finished document.

## Closing out

Once the user has approved, do these **in order, without stopping to ask again**.
The user has approved the plan; what follows is writing it down.

### 0. Write the file

Settle the task count, then:

```bash
<cue>/skeleton plan <KEY> <task-count>
```

Fill in every `[[ ... ]]`. If the count turns out wrong while you are filling it
in, that is a plan change, not a formatting problem — rerun with the right count
and `--force`, and tell the user the task count moved.

### 0b. Self-review

**The mechanical half is a script:**

```bash
<cue>/verify <KEY>
```

It checks that the header fields and Global Constraints are there, that tasks
parse, that every task carries a `Files` and an `Interfaces` block, that no `[[`
prompt survived, and that no placeholder survived outside a code fence. Fix what
it names and run it again.

**Then the half that needs judgment** — this is a checklist you run yourself, not
a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

**3. Files cross-check:** Is every file listed in File Structure present in some
task's `Files`? A missing file is one nobody creates. Conversely, if the same file
appears in several tasks' `Modify`, check that a dependency between those tasks is
expressed in `Interfaces` — if not, one of the two is wrong.

**4. TDD values:** Is anything marked `required` that does not need the order
enforced, or `n/a` that actually has a testable deliverable?

Fix what you find inline and go straight on to the graph. No need to re-review.
**Do not take a finding back to the user as a second approval question** — they
approved the plan, and a typo in an interface signature is not a change to it. The
one thing worth surfacing is a spec requirement with no task, because that is the
plan being wrong: add the task, and say you did.

### 1. Generate the dependency graph

```bash
<cue>/task-graph <KEY>
```

This writes a `## Task dependencies` mermaid section into plan.md, above the
first `## ` heading and below the Goal/Architecture preamble (replacing the
section if one is already there). The position is deliberate and matches
design.md's `## Structure`: what depends on what is read before the tasks it
describes, not after them.

**Edges run producer → consumer.** `A → B` means B consumes what A produces, so
A is done first — the arrow follows the work, not the dependency. The section
carries that line for the reader; you do not write it.

**Do not stop on a warning.** The graph is an accessory.

| Warning | Meaning | What to do |
|---|---|---|
| `Interfaces blocks are empty` | signatures were not written | fill in each task's Produces/Consumes and rerun |
| `contain a cycle` | task ordering is tangled | revisit the plan |
| `The graph may be hard to read` | the work units are large | fine to proceed as is |

Only `exit 1` (no tasks found) is a real problem — the task header format in
plan.md is broken, so fix it and rerun.

### 2. Generate the outcome skeleton

```bash
<cue>/outcome-init <KEY>
```

This creates `outcome.md` with one `unrecorded` row per task in plan.md. During
implementation the controller replaces each row as its task completes.

**This file is what replaces omission detection.** Miss task 4 and "4 ·
unrecorded" stays there, visible in the PR diff. No gate, no state machine needed.

### 3. Commit

```bash
git add .cue/dev/<KEY>/plan.md .cue/dev/<KEY>/outcome.md
git commit -m "$(<cue>/marker plan <KEY>)"
```

**Do not change the marker format.** `cue-dev:status` and `cue-dev:redo` decide
the stage from this string. outcome.md must go into this same commit so that
`cue-dev:redo implement` can rewind to the skeleton state.

**`marker` runs `verify` and prints nothing if it fails**, so git aborts on the
empty subject and no plan commit is made. That is not a second gate to satisfy —
it is the one above, enforced where it cannot be walked past. If it refuses, its
stderr carries verify's errors; fix those and run the same command again.
**A record that reaches this point clean makes it silent.**

### 4. Point at the next stage

```bash
<cue>/notice "PLAN done" <<'EOF'
  key       <KEY>
  artifacts .cue/dev/<KEY>/plan.md
            .cue/dev/<KEY>/outcome.md (<N> tasks, all unrecorded)
  commit    <the commit subject actually written>

  next      /cue-dev:implement
  rewind    /cue-dev:redo plan
EOF
```

**Reproduce its output verbatim in your reply, in a fenced code block, and put it
last.** Anything you need to say goes *above* it — a decision you need from the
user, a warning, the answer to what they actually asked. **Nothing goes under it,
and nothing restates its labels.**

**The parenthesis after plan.md is gone on purpose.** It read `(with dependency
graph)` — a description of the file's contents, on a line whose job is to say
where the file is. The graph is in there because this skill requires it; a reader
who opens the file finds it, and one who does not is no better off for having been
told. Every parenthesis in a notice costs a line's worth of attention, and
`outcome.md`'s earns it: `<N> tasks, all unrecorded` is a count nothing else
reports.

**Stop here.** Do not ask how to execute — cue-dev is fixed on subagent
implementation. And do not call the implementation skill automatically. The user
reviews the plan and runs it themselves.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Let me re-read the requirement and plan from that" | The input is the approved design.md. Going back to demand.md bypasses the design a human approved. |
| "Every task should be `TDD: required` — stricter is safer" | Stricter is longer, and length here is spent on choreography rather than on the requirements. What proves a test tests anything is the RED output, which `evidence-only` already demands. Reach for `required` when the order itself is the point. |
| "I'll scan for placeholders and count the Files blocks myself" | That is `scripts/verify`'s job. Doing it by eye degrades silently and takes the attention the four judgment checks need. |
| "A description is enough for Interfaces" | The implementer sees only their own task. Paraphrase and they invent a name the next task cannot find. Write exact signatures. |
| "Files can be rough, the implementer will find them" | It is the baseline a reviewer compares the diff against. Paraphrase and scope grows quietly, and that stays hidden until the final review. |
| "Let me fold the doc update into an implementation task" | It gets flattened together in review, and when it slips, nothing shows it. Give it its own task. |
| "`git commit -m` is a command, so the message stays English" | The command stays; the string it quotes is a sentence someone reads, and it follows the record language. Only `feat:` and the cue-dev markers are matched by machine. |
| "The self-review already checked the plan, so I can commit it" | The self-review checks the plan against the spec. It cannot check the plan against what the user actually wants — that is the one thing only they hold, and the summary you present before writing the file is the last time they see it before code exists. |
| "They'll read plan.md in the PR anyway" | By then the tasks are implemented. What the checkpoint buys is a rewrite that costs nothing; in the PR it costs the implementation. |
| "The file is written, so I should ask them to review it" | They already approved it — before it existed, which is when approving was free. Asking again over a document they have not read yet buys nothing and costs a turn. If they read it afterwards and want it different, that is `/cue-dev:redo plan`, and the notice already says so. |
| "I'll paste the plan into the conversation so they can see all of it" | Then there are two copies and they diverge from the next edit onward. Summarize and point at the path; the file is where the plan lives. |
| "I'll write plan.md myself, the template is right there" | The template in this skill is an example of a filled-in file, not a thing to copy. `scripts/skeleton` writes the structure so no field name is ever retyped — which is what two failed rewrites in one real session were spent on. |
| "The record language is Korean, so `**Goal:**` should be `**목표:**`" | `implement` parses those names and `verify` greps them. A translated one does not read as a translation; it reads as a missing field. The skeleton writes them so the question does not come up. |
| "The outcome skeleton can wait until implementation" | Without it in the plan commit, `cue-dev:redo implement` has no baseline to rewind to. Create it now and commit it together. |
