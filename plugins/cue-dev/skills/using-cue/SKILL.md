---
name: using-cue
description: Use when starting any conversation - establishes how to find and use skills, and how to recover the in-progress cue-dev stage after a compaction
user-invocable: false
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

## Check for work in progress first

This is injected at session start, on `/clear`, and **right after a compaction**.
Right after a compaction you may have forgotten the stage you were just in. Do not
bridge the gap from memory — ask.

```bash
<cue>/status
```

**`<cue>` is the scripts directory named in your session context, just below this
skill.** Every cue-dev command is written `<cue>/<script>`; put that one path in
its place and change nothing else. It is already absolute and already POSIX, so
there is nothing to reassemble — a path built by hand produces
`d:cuepluginscue-devscriptsstatus: command not found`, because backslashes are
escapes in the shell. That has happened.

It tells you which stage you reached, what comes next, and how many unrecorded
rows are left in outcome.md. If it cannot find a KEY (you are not in cue-dev
work), it simply fails and you move on.

**Move on means move on.** Do not then list `.cue/dev/`, do not pick the
newest-looking item, and do not report what is in there as work in progress. The
script finds an item by the branch that item recorded; no match means nothing is
in flight on this branch, and that is a complete answer. A session that treated
the refusal as a prompt to go looking named four finished items as "in progress"
and asked the user which to continue.

**When a cue-dev script refuses, do not diagnose it yourself.**
`<cue>/gate <stage>` answers what is available instead, deterministically.
Retrying with a guessed KEY and then reading `.cue/dev/` by hand is how a real
session arrived at the right answer by luck. **`<cue>/status` with no KEY is the
exception, because it already handed the question to gate** — what you are
holding is gate's answer, and running gate after it prints the same lines twice.

**Gate's output is read, not relayed.** Its `blocked` and `now` lines are
commands and facts for you to act on; say what they mean in the user's language.
Only the `━━━` block is reproduced verbatim, and gate never prints one.

If outcome.md has recorded rows alongside unrecorded ones, you are mid-implement.
**Re-dispatching a completed task is the most expensive failure there is** — trust
the recorded rows and `git log` over your own memory.

## Using skills

When a skill fits the work, invoke it **before exploring, asking, or opening
files** — the skill tells you what to explore and how. After invoking it, announce
"Using [skill] to [purpose]", and if it has a checklist, make a todo per item.

If you are about to enter plan mode without having designed anything, invoke
cue-dev:design first.

**Priority:** the process skill decides the method; the implementation skill
carries it out.

- "let's build X" → cue-dev:design → implementation skill
- "fix this bug" → cue-dev:systematic-debugging → domain skill

## The `━━━` box is never yours to draw

Reproduce it when a cue-dev script prints one. **Never write one yourself.**

The frame means one thing: a cue-dev stage produced this, and a script assembled
it. That is worth nothing the moment anyone can draw it — and in a real session a
merge performed outside `/cue-dev:finish` was reported inside a hand-rendered
`━━━ MERGED · <KEY> ━━━`, naming a stage that does not exist, in the frame that
promises the opposite. `scripts/notice` now refuses every title but its own list,
so hand-drawing is the only way left to produce a fake one.

Anything cue-dev has no stage for — a merge you were asked to do, a branch you
deleted, a file you moved — is ordinary work, reported in ordinary prose.

## A question that failed is not a question that was answered

Every cue-dev stage that needs a decision gets it from the user. When the call
that asks fails — `AskUserQuestion` returning an error instead of an answer, a
tool refusal, anything that comes back without the user in it — **you do not have
a decision, and the stage does not proceed.** Say what happened and ask again in
plain prose, in the reply itself.

This is not a hypothetical. On Windows the harness's rendering of a menu's
non-ASCII fields can corrupt them, and the skills that ask menus say so — as a
cosmetic cost, "a mangled syllable is recoverable from context". It is not always
cosmetic. In one real session the corruption produced invalid escapes and the
call was rejected outright five times, `InputValidationError`, nothing shown to
anyone. At `/cue-dev:plan` the two rejected calls were the plan's approval gate:
the next turn opened "Good, I'll write the plan with these nine tasks", and the
skeleton, the file and the commit followed. The user was told afterwards that they
had approved a plan they had never been shown a menu for.

An error is the one answer that means nothing was decided. Treat the retry as a
new question, not as a formality standing between you and the work — and if the
menu fails twice, stop using it and ask in prose, which cannot fail this way.

**When you fall back to prose, the question is the end of your reply.** Do not
call another tool in that turn. This is the one thing the menu was doing for you:
the harness stops and waits on it, and a prose question does not — nothing stops
the same turn continuing, continuing needs an answer, and an answer is what gets
supplied. `/cue-dev:start` records a session that wrote *"User says yes, so I'll
proceed"* and cut a branch, having been told nothing. Ending the turn is what
replaces the stop you lost.

## Where you run cue-dev's scripts from

**Anywhere. They take the KEY and read the item's record; none of them cares
where you are standing.** So there is no reason to `cd` into an item's worktree
to run one, and one good reason not to: `/cue-dev:finish` deletes that directory,
and a shell sitting inside it turns a clean removal into a platform-specific mess
— refused outright on Windows (`Device or resource busy`, over a directory that is
already empty), and on macOS and Linux silently succeeding into a shell whose cwd
no longer has a name. Both have happened.

What genuinely needs a directory is a *test suite*, which resolves imports and
writes fixtures relative to where it runs. `cd` in for that, and come back.

## Order of instructions

User instructions (CLAUDE.md, AGENTS.md, direct requests) > skills > default
behavior. Skip a skill's procedure only when the user explicitly says to.
