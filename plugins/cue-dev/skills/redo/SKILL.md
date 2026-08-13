---
name: redo
description: Use when a cue-dev stage needs to be done over - the requirement was wrong, the design was wrong, the plan was wrong, or the implementation went off the rails. Do not hand-roll git reset or revert a stage marker yourself; use this instead.
argument-hint: <demand|design|plan|implement> [KEY]
---

# Redoing a stage

**Speak the repository's language.** The first script this skill runs — `<cue>/gate`,
or `<cue>/init-check` — prints a `language` line. **Everything you say to the user
goes in that language, starting with your first sentence**: the questions you ask,
not only the record you write at the end. This skill body is English because it is
the plugin's source, not because it is your output. Template headings, commit
markers, `outcome.md` status tokens, paths and code stay exactly as written.

**`AskUserQuestion` is not an exception. `question`, `header` and `description`
are written in the repository's language, like everything else you say.** A menu
is a thing the user reads in order to decide, and a menu they cannot read is not
a menu.

**What does not translate is a `label` that is a value.** A KEY, a branch name, a
base ref, `self-review`, `independent-review` — those go on to be passed to a
script or written into a record, and the answer comes back to you as the label
string. Translate one and what it names stops existing. A label that is only
prose — "leave it for now" — is written in the repository's language like the
rest of the menu.

**One known cost, so that it is not read as a defect when it appears.** On
Windows the harness's own rendering of these four fields can corrupt non-ASCII
text: a real session showed a Korean user menus with mangled syllables in them,
in the words for "merge" and "complete", while every line of ordinary prose in
the same session came through clean. It touches the menu and nothing else — the
records, commits and replies you write afterwards are unaffected. This skill used
to answer that by keeping the menu in English, and the user could then read the
options least of all. A mangled syllable is recoverable from context; a language
the reader does not have is not.

**But not every one of them is a mangled syllable.** The same corruption can
produce an invalid escape sequence, and then the call is rejected whole —
`InputValidationError`, no menu, nothing shown to anyone. That is not a cost to
absorb; it means you have no answer. The rule for it is in `cue-dev:using-cue`,
under "A question that failed is not a question that was answered", written once
because it is the same rule for every stage that asks.


Rewinding is destructive. **Do not run `git reset` yourself.** This script creates
a backup branch first, shows what will disappear, and only resets after getting
consent.

## Sequence

The user asked for the rewind. **Do not answer them by handing the same command
back** — run the preview, show what disappears, and hand over only the one step
you are not allowed to take for them.

0. **Check that there is anything to rewind.**

   ```bash
   <cue>/gate redo
   ```

   Run it exactly as written. **On exit 1, stop and relay the `now` lines.**

1. **Check the current state with `cue-dev:status` first** and show it to the user.
2. **Run the preview yourself.** It changes nothing — no backup branch, no reset —
   and it exits 0.

   ```bash
   <cue>/redo <stage> [KEY] --dry-run
   ```

   Show the `discard` and `lose` lines to the user. The `discard` count is the
   whole of the decision: a rewind to `demand` from a finished implementation can
   be dozens of commits.

   **If it prints `REWIND blocked` instead, that stage has never run** — going
   back is as linear as going forward, and `/cue-dev:redo plan` before there is a
   plan is the same kind of mistake as `/cue-dev:implement` before there is one.
   The block lists the stages that *can* be rewound. Relay those `now` lines and
   stop; do not pick one for the user, and do not reach for `git reset`.
3. **Ask, with `AskUserQuestion`.** Two answers — rewind, or leave it alone. Say
   in the question what disappears.
4. **Once they have said yes, run it.**

   ```bash
   <cue>/redo <stage> [KEY] --yes
   ```

   **What is forbidden is running this before they have answered**, not the flag
   itself. `echo yes |`, `printf 'yes\n' |`, `<<< yes` and `yes |` are all the
   same violation, because they satisfy the prompt without anyone having been
   asked. The consent lives in the conversation; `--yes` is how it reaches the
   script.

   Do not hand the command back for the user to type. They asked for the rewind;
   answering with homework is not a safety measure, and the preview they would
   have seen first used to end in an error — which is what "`!` the `--yes` form
   yourself" actually looked like in practice.
5. Relay the backup branch name it printed and the next command.
6. **Ask about cleaning up backups.** If earlier backups exist for the same KEY,
   the script prints the list. Show it as it stands, ask, and **then run
   `git branch -D` yourself** on exactly those branches. Backups do not disappear
   on their own — if nobody asks, they pile up with every rewind.

   ```
   There are 2 earlier backups. Delete them?
     cue-dev/backup/<KEY>-20260731-201000  (2 hours ago)
     cue-dev/backup/<KEY>-20260731-193000  (3 hours ago)

   I'd keep cue-dev/backup/<KEY>-20260731-215500, the one just created — it is
   the only way to undo this rewind.
   ```

   **Never widen the list.** Delete the branches the script named and no others;
   the ones belonging to other work items are those items' only recovery path.

## Undoing the rewind

**The backup branch is the recovery path, and `<cue>/restore` is how it is
walked.** Until that script existed the branch name was printed and nothing said
what to do with it — so a real session asked to get the plan back and got a
`git log` read by eye followed by `git reset --hard <sha>`. **Never do that.** It
is the same prohibition as the one at the top of this file, in the other
direction.

**A restore is another rewind, not an undo.** If you rewound at `design` and then
redid the design, restoring discards that new design. So it takes the same three
steps as the rewind above, for the same reason.

1. **List what there is.**

   ```bash
   <cue>/restore [KEY]
   ```

   Changes nothing. Each candidate comes with the stage it holds, how many commits
   it would bring back, and how many were made since the rewind. **Show the list.**

2. **Preview the one the user picks, and get consent.**

   ```bash
   <cue>/restore [KEY] --to <backup> --dry-run
   ```

   Then `AskUserQuestion`. The `discard` count is the half that is easy to skip
   past — say it.

   **Never pick the branch for the user, and there is no flag that would let you.**
   With two backups the one wanted is usually the older: realising the first
   rewind was the mistake is what the second rewind teaches.

3. **Run it with the answer in hand.**

   ```bash
   <cue>/restore [KEY] --to <backup> --yes
   ```

   The current HEAD is saved to a new backup branch before anything moves, so the
   restore is itself undoable. **Relay the box.** It names the branch you just
   restored from as `stale` — HEAD is standing on it now, so it is no longer a way
   back — and prints the `git branch -D` for it. **Ask, then run that yourself**,
   exactly as with the earlier backups above. This is the question that used to go
   unasked: nothing in cue-dev said anything about a backup after it had been used.

**If the tree is dirty it refuses**, naming what is uncommitted. That is not an
obstacle to work around — a reset would take those files, and this command is
reached by someone trying to get something *back*.

## The invalidation chain

| Stage | Rewinds to | What disappears |
|---|---|---|
| `demand` | before `cue-dev(demand)` | design · plan · outcome · all code |
| `design` | before `cue-dev(design)` | plan · outcome · code |
| `plan` | before `cue-dev(plan)` | outcome · code |
| `implement` | right after `cue-dev(plan)` | code commits · outcome records (the plan survives) |

`cue-dev` in the table is the default prefix. If the repository uses a different
one via `.cue/dev/config`, that one applies — the script reads the settings, so
there is nothing to worry about.

Only `implement` leaves the marker commit in place. That is what keeps the plan
while redoing just the implementation.

### Rewinding past more than one stage is allowed, and it cascades

`/cue-dev:redo design` while you are standing at implement is not an error and is
not blocked. It rewinds to before the `design` marker, which discards the design,
the plan, the outcome skeleton and every implementation commit in one reset — and
you then redo `design`, `plan` and `implement` in order.

**Blocking it would be the wrong answer, because the stages are not independent.**
The plan is derived from the design and the code is derived from the plan. Leaving
a plan in place under a design that was just replaced produces a repository whose
four records no longer describe one another, which is the state this tool exists
to make impossible. cue-dev is linear in exactly this sense: a stage is only ever
valid on top of the one before it.

**So there is nothing extra to do — the cascade is the reset.** Do not rewind one
stage at a time to "walk back" to design; that runs three destructive resets and
three backup branches to reach the state one reset reaches. And do not try to
preserve the plan across a design rewind.

**`/cue-dev:status` names these too.** Its `rewind` line is the nearest stage, and
the line under it lists every further one that has a marker. For a long time only
the first was printed, which read as the only rewind available — and a user who
believed that was believing something this section had already ruled out.

What this costs is visible before anything happens: the preview's `discard` line
counts every commit going away and `lose` names every artifact. **Show both and
let the user decide.**

## Where judgment is needed

- **If the requirement itself was wrong, use `demand`.** Fixing the design will
  not do it.
- **If pushed commits are included**, the script warns. Whether to force-push is
  the user's decision. cue-dev does not make it for them.
- **Do not delete the backup branch you just created.** It is the only recovery
  path if the rewind was a mistake, and `<cue>/restore` is how that path is
  walked. The time to delete it is after you have redone the stage and are
  satisfied with the result.
- **Earlier backups are cleaned up by asking.** The user makes the call; you carry
  it out, on the branches the script named.
