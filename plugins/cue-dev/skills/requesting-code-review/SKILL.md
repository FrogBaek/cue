---
name: requesting-code-review
description: Use when dispatching a code reviewer over a whole branch - how the reviewer is briefed, what range it reads, and how the diff reaches it. Whether an item gets one at all is settled by its check level at /cue-dev:start, not here.
user-invocable: false
---

# Requesting Code Review

**Speak the repository's language.** `.cue/dev/config`'s `language` decides what
you write to the user, and the session hook states it at the top of every session
— this skill runs no cue-dev script of its own, so nothing repeats it here. This
skill body is English because it is the plugin's source, not because it is your
output. Code, identifiers, paths, test names and commit markers stay exactly as
written.

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** the reviewer did not write the code, and the diff reaches it as a file.

## When to Request Review — this skill does not decide that

**Inside a cue-dev item, the answer is already recorded.** `/cue-dev:start` asks
how strongly this item gets checked and writes it into `demand.md`'s header;
`<cue>/work-check <KEY> --plan` reads it back and names the method.

| the item's level | what happens |
|---|---|
| `independent-review` | every task's diff is reviewed by something that did not write it, and the branch gets this review at the end |
| `self-review` | no reviewer is dispatched — the implementing session reads each diff itself and `outcome.md` records `checked-by: self-review` |

**So do not dispatch a review because the change looks risky, and do not skip one
because it looks small.** Both are judgments the level already made, once, by the
person who knew the blast radius. This skill used to open with a *Mandatory* list
("after each task", "before merge to main") and a red flag reading "never skip
review because it's simple" — written before the level existed, and now an
instruction to override it. An item that answered `self-review` and then got a
subagent review anyway has a record that does not describe what happened.

**Outside a cue-dev item** — a branch someone hands you, a spike, a bug fix with no
KEY — there is no level to read and the judgment is yours. Then this skill is the
whole answer.

## How to Request

**1. Get the range. `HEAD~1` is not it.**

```bash
BASE_SHA=$(git merge-base <base-branch> HEAD)   # where this branch started
HEAD_SHA=$(git rev-parse HEAD)
```

`HEAD~1` reviews the last commit and reports on it as though it were the branch;
every commit before it goes unread and nothing says so. Inside a cue-dev item the
base is the item's own start point — `<cue>/work-base <KEY>`.

**2. Write the diff to a file, and hand over the path.**

```bash
<cue>/review-package <PLAN_FILE> "$BASE_SHA" "$HEAD_SHA"
```

It prints the path it wrote: the commit list, a stat summary and the full diff
with context. **Hand the reviewer that path, not the diff.** A diff pasted into
the dispatch is in your context for the rest of the session and is re-read every
turn — and the reviewer reads it in one call either way.

**`PLAN_FILE` is required and it also names the output directory**
(`.cue/dev/sdd/<its basename>/`). Inside an item that is `.cue/dev/<KEY>/plan.md`.
Outside one, pass whichever document states the requirements — it is read for the
name, not for its contents. If there is no such file, write the diff to a file
yourself and hand over that path; what the template needs is a path, not this
script.

**3. Dispatch the reviewer**, filling the template at
[code-reviewer.md](code-reviewer.md). Every REQUIRED placeholder is required,
including `[LANGUAGE_DIRECTIVE]` and `[MODEL]`: subagents inherit no hooks, so the
repository's record language reaches them only if you carry it, and an omitted
model silently inherits the session's.

**4. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning) — `cue-dev:receiving-code-review`

## Example

```
[Every task in PROJ-142 is recorded; the branch is ready for its final review]

BASE_SHA=$(<cue>/work-base PROJ-142)            # a7981ec — this item's start point
HEAD_SHA=$(git rev-parse HEAD)                  # 3df7661

[Run <cue>/review-package .cue/dev/PROJ-142/plan.md a7981ec 3df7661
 → .cue/dev/sdd/plan/review-a7981ec..3df7661.diff]

[Dispatch code reviewer subagent, most capable model]
  LANGUAGE_DIRECTIVE: (the line from implement's Output Language section)
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: .cue/dev/PROJ-142/plan.md
  PARKED_FINDINGS: [parked: magic number (100) — ruling: matches the spec's
                    stated reporting interval]
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DIFF_FILE: .cue/dev/sdd/plan/review-a7981ec..3df7661.diff

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
  Parked triage: magic number — stands, the spec fixes the value
  Assessment: With fixes

You: [Fix progress indicators]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll just review the diff myself instead of dispatching a reviewer" | You're the coordinator — reviewing the diff inline burns the context window you need to keep driving the work. Dispatch a reviewer subagent: the diff and the evaluation live in its context, and only the findings come back to you. |
| "The reviewer needs my whole session history to understand the change" | Hand it precisely crafted context, never your session's history. That keeps the reviewer on the work product, not your thought process. |
| "`HEAD~1` is close enough for the base" | It reviews the last commit and reports on it as the branch. Every earlier commit goes unread and the report says nothing about that. Use the branch's start point. |
| "I'll paste the diff into the dispatch so the reviewer definitely has it" | Then it is in your context too, for the rest of the session, re-read every turn. `<cue>/review-package` writes it once and the reviewer opens it once. |
| "The change is risky, so I'll dispatch a review even though the item said `self-review`" | The level was answered by the person who knew the blast radius, and `outcome.md` records what actually happened. If you now believe the level was wrong, say so — do not quietly do something the record will not describe. |
| "The item said `independent-review` but this task is trivial" | Then the record and the work part company, and `verify` compares exactly those two. The level is the plan, not a bar to clear. |

## Red Flags

**Never:**
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [code-reviewer.md](code-reviewer.md)
