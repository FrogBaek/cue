---
name: finish
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

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


## Overview

**Core principle:** Verify tests → Detect environment → Settle where the work lands → Settle the workspace → Clean up → Print the notice → *then* ask about integration.

**This skill closes what `/cue-dev:start` opened, and nothing more.** start cut a
branch and a worktree and wrote both into the record; finish accounts for both and
says where they ended up. That is the whole bracket, and it completes without
anything being pushed, proposed or merged.

**Integration is a separate question, asked after the notice.** A pull request or a
merge is a commitment to other people — in a real team it is the step someone
carries responsibility for, and it may wait for a review slot, a release window or
a conversation this session is not part of. So it is not the price of finishing.
The box goes up first, saying the work is complete and the workspace is settled;
then Step 9 asks, once, what to do about integrating it, and `not now` is a
complete answer that costs nothing — the branch holds every commit and all four
records, and running `/cue-dev:finish` again picks the question back up.

**This ordering used to be the other way round** and the menu's first question was
"publish the branch and open a change request, or keep it". That put the
irreversible, outward-facing act in the position of the default next step, and it
made the tidy-up conditional on answering it. A developer who wanted the PR
immediately was served; anyone who did not had to decline something before they
could finish.

**What cue-dev requires, and what it does not.** Five things are not negotiable and
this skill enforces every one: the suite runs on the tree being integrated, every
outcome row is recorded *and sits on this item's branch*, the marker is stamped,
the landing point is derived from the record and checked against git, and the
workspace is accounted for. **The integration act itself is none of cue-dev's
business** — a repository proposes work through a pull request, or a merge request,
or a mailing list, or not at all, and which of those it is comes from
`<cue>/integration` rather than from this text.

**Announce at start:** "I'm using the cue-dev:finish skill to complete this work."

## Prerequisite check

**Run this first.**

```
<cue>/gate finish
```

`<cue>` is the scripts directory named in your session context.
**On exit 1, stop and relay the `now` lines.** On exit 0 it prints the KEY.

**Then run the record gate and the landing check, together.**

```bash
<cue>/verify <KEY> --stage implement
<cue>/integration --landed <KEY>
```

**Both, in one go, before anything else.** The landing check belongs to Step 3a
and it is the branch point for the whole skill — `landed yes` skips Steps 3b, 3c,
5b and 9 entirely. It is run up here because down there it gets skipped: a real
session went from Step 1 straight to "Step 2-4" and never asked, so the ancestor
check in 3b never ran either and the run proceeded on an assumption nothing had
tested. A question that decides the shape of everything below it does not belong
in the middle of the sequence it decides.

Hold the answer. Step 3a reads it.

This is the last point where the records can still be fixed cheaply. It checks
that every task has a row, that no row is still `unrecorded`, that each row names
a commit that exists, and that `checked-by` is not below the check level **this
item** asked for at `/cue-dev:start` (`<cue>/work-check <KEY> --show`). **If it
reports errors, stop and show them.** Everything it catches would otherwise land
in the pull request in front of a reviewer.

> "The records are not ready yet: <what verify reported>. Fix them with
> `/cue-dev:implement` and run this again."

**Do not fill in a missing row yourself.** A controller inventing rows here from
the commit log alone is exactly what this system exists to prevent —
after-the-fact narrative with no evidence.

**One of the things it checks is whether the work is on the branch at all**, and
it is the check this gate was missing. A row names the task's last commit; that
commit must be reachable from this item's recorded branch. In a real session every
task was implemented and committed in the main checkout — a forgotten
`git -C <worktree>` — so the branch carried its six record commits and no code,
and nothing anywhere noticed: the commit existed, the marker was on the branch,
the suite passed against a tree that did have the change, and the notice below
said the branch held "every commit and record". **If verify reports this, do not
work around it.** The commits are real and they are somewhere; find out where
before deciding anything about integration, because every option in Step 5 is
about a branch that does not contain the work.

**Do not edit `checked-by` to clear the gate either.** If the work really was
checked more weakly than this item asked for, that is a fact about the work: say
so, show both values, and let your human partner decide between re-reviewing it
and accepting the difference.

**And do not go looking for the setting that dismisses the question — there is no
longer one to find.** The level is `check:` in this item's `demand.md` header, put
there by the person who answered `/cue-dev:start`, about this item. Editing it now
to match what happened is not lowering a threshold, it is rewriting the question
after seeing the answer, and it leaves the one record that could have shown the
gap saying there was none.

**`checked-by: none` cannot be cleared at all.** The two levels an item may ask
for are `independent-review` and `self-review`, and `none` sits below both, so
this one stops here whatever was asked. Nothing read the diff, and the decision is
a human's: review it now, or accept it in so many words.

## Which tree every command in this skill runs against

**Read this before Step 1. Every check below is worthless if it runs on the wrong
tree, and one whole run has already been lost that way.**

cue-dev cuts a worktree and does *not* move the session into it. So this skill is
almost always executing in the **main checkout**, where `HEAD` is the base branch
and the item's work is nowhere in sight. Three separate things in here used to ask
git where it was standing:

| the command | what it must be told |
|---|---|
| the test suite (Step 1) | run it **in the item's worktree** — `<cue>/work-path <KEY>` |
| `git status` on outcome.md (Step 4) | the same tree |
| the ancestor checks (Step 3b) | the item's **recorded branch**, never `HEAD` |

**The failure this prevents, in full.** In a real session every task was
implemented and committed in the main checkout — one forgotten `git -C <path>` —
so the item's branch held its six record commits and not one line of code. Then
finish ran, also in the main checkout: the suite passed (against a tree that did
have the change), the ancestor check asked whether the base branch was still on
itself, and the notice reported that the branch held "every commit and record". It
did not. Nothing in the run was capable of noticing, because every question was
asked about wherever the shell happened to be.

**`<cue>/verify` now catches the specific case** — a row naming a commit that is not
on the item's branch is an error, and it is the reason to run the record gate
before anything else. The rule here is the general one, and it is the same rule the
rest of cue-dev already follows: **the item's facts come from the item's record.**
`work-path`, `work-branch` and `work-base` are the three that answer, they all take
the KEY, and none of them cares where you are standing.

**So do not `cd` into the worktree to run them, and do not stay there.** The one
thing in this skill that needs the worktree as its working directory is the test
suite in Step 1; a suite reads config, resolves imports and writes fixtures
relative to where it runs. Everything else takes the KEY, and running it from the
main checkout is both correct and shorter.

**The reason is that this step is about to delete that directory**, and on every
platform a process sitting inside it makes that worse — differently, which is why
it is worth naming all three:

| | what happens when the cwd is deleted under you |
|---|---|
| Windows | the unlink is refused outright — `Device or resource busy` over an empty directory. A real run hit exactly this, reported the worktree as removed anyway, and left the directory behind for two sessions |
| macOS · Linux | the unlink succeeds and the shell keeps a handle to a directory that no longer has a name. The next command fails with `shell-init: error retrieving current directory`, or worse, a relative path resolves against nothing |

Neither is a state to reason from, and neither is reachable if the shell was
never in there. Stand in the main checkout, pass the KEY, and let Step 1's suite
be the one exception — `cd` in for it, and come back.

## Step 1: Verify Tests

```bash
<cue>/evidence <KEY>           # what was claimed, and what the design said would decide it
<cue>/work-path <KEY>          # the tree the suite must run in
```

**Run `evidence` first, on every path, and answer its `ask` line before anything
else in this step.** It prints `outcome.md`'s `checked-by` and `evidence` verbatim
and the design's own "How we know it works", and then asks which tool call in
*this* session produced each line. That question is the whole of Step 1b, and it
is asked here because a run with a green suite can fail it too.

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`)
**in that directory** — `cd` into it, or whatever the runner's equivalent is. A
suite is not portable to `git -C`: it reads config, resolves imports and writes
fixtures relative to its own working directory.

**If `work-path` says there is no worktree**, the item was built in place. Then the
tree to run in is the main checkout **with the item's branch checked out** — check
`git rev-parse --abbrev-ref HEAD` against `<cue>/work-branch <KEY>` and say so if
they differ, rather than running the suite on whatever is there.

**Say which tree the suite ran in when you report the result.** "Tests pass" with
no tree named is the claim that cost the run described above.

### 1b. When there is no suite to run

**Then say exactly that, and stop there. Do not describe checks you did not
perform.**

**Naming this step is not performing it.** A run that reached here wrote "there is
no test suite, so I follow Step 1b" and went straight to Step 2 — no evidence
field relayed, no question put to the user, and the `IMPLEMENT done` box behind it
already said `checked  self-review · manual` over a session whose entire
verification had been `grep` and `head` over the files it had just written. That
is why the step now begins with a command: `<cue>/evidence <KEY>` puts the claim
and the design's checks in front of you as output, and there is no reading of it
that is compatible with moving on.

This is the most serious failure this skill has produced, and it produced it in a
repository of four static HTML files. There was no test runner, so Step 1 had
nothing to run — and the report that went out read: *"tested manually in the
browser during implementation: page5.html renders correctly, the Instagram button
opens the link in a new tab, the back button returns to index.html."* None of it
happened. No browser was opened at any point in the session, in any stage. The
implementation had been Write, commit, record, and nothing else. `outcome.md`
said `evidence: manual`, `scripts/verify` passed it, and this step turned a value
in a field into four sentences of eyewitness testimony.

Nothing downstream can catch this. `evidence: manual` is a legitimate answer and
the script cannot ask what was looked at. **The check is here, and it is one
question: can you point at the tool call that produced this observation?** If you
cannot, you did not make it.

**What to do instead, in order:**

1. **Read `outcome.md`'s `evidence:` field and report what it says**, as a
   field — `evidence: manual`, `evidence: red-output`. That is a record of what
   the implementer claimed, and relaying it is honest. Elaborating it is not.
2. **If the design's "How we know it works" names a check that nothing has run**
   — a page opened in a browser, a command whose output someone reads — and you
   cannot run it, **ask your human partner to run it.** You are not blocked and
   they are not being tested; they are the only party here with a browser.

   > "Nothing in this repository runs a suite, and the design says this is
   > settled by opening the page. I have not opened it. Could you check
   > `page5.html` — the button opens `https://instagram.com` in a new tab, and
   > back returns to `index.html` — and tell me what you see?"

   Wait for the answer, and report what they told you, attributed to them. If
   they would rather not, that is a complete answer too: say the check was not
   run and carry on. **An unrun check that is named as unrun costs nothing. An
   unrun check reported as passed is the thing cue-dev exists to prevent.**
3. **Never write the observation yourself in the meantime**, not as a summary,
   not as a bullet list, not as "verified during implementation".

**If tests fail**, report the failures and stop — asking how to integrate comes after the suite is green:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
<cue>/work-path <KEY>          # this item's worktree, or "no worktree recorded"
```

**There is no `WORKTREE_PATH` to capture any more.** It used to be read here,
before Step 6 changes directory, and carried forward to Step 7 — a value observed
in one place and used in another, which is the shape every fact cue-dev has moved
into a record has failed in. Step 7 takes the KEY and reads the record itself.

This determines which questions get asked and how cleanup works:

| State | What is asked | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Step 5b is not asked — there is no worktree | Nothing to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Step 5b asks about the worktree | From the record (see Step 7) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Neither Step 5b nor Step 9 is offered | Externally managed — leave in place |

In a normal repo there is nothing for Step 5b to ask: the branch is kept either
way, and there is no worktree to settle. Say so and go on — the `worktree` line in
Step 8's box is then `worktree  none — this item has no worktree`, from the script.

**This paragraph used to offer an option here.** It read "'keep the branch, clean
up the worktree' and 'keep both' are the same thing: offer it once, as **Keep the
branch as-is**" — two rows of the four-way menu Step 5 no longer has, collapsed
into a third that was never a question, three lines under a table saying 5b is not
asked at all in this case.

## Step 3: Settle where the work lands, and where it is pushed

**These are two separate questions.** Conflating them is what made whole workflows
impossible to express: a git-flow hotfix starts at `main` while a feature starts
at `develop`, and a fork is pushed to one repository but proposed to another.

### 3a. Has it already landed? — settled at the prerequisite check

**This is a re-run in every case where the answer is yes**, and it comes first
because everything below it is about work that still has to go somewhere.

`<cue>/integration --landed <KEY>` already ran, up at the prerequisite check.
Read its answer:

- **`landed yes`.** The work is in. There is no integration act left, and 3b and
  3c have nothing to settle — **skip to Step 5r.** Do not run the ancestor check
  below: the landing branch has moved on since the record was written, so it would
  fail and put a question in front of the user about a decision that is already
  history.
- **`landed no`.** Carry on with 3b.
- **`landed unknown`.** git cannot tell, and the script says why — a squash or a
  rebase landing leaves no ancestry, which is how most forges merge. **Ask;
  do not decide.** Relay the `reason` line and the request URL if you have one:

  > "git can't tell whether this landed — a squash merge leaves no trace in the
  > history. Did `<request>` go in?"

  If they say yes, treat it as `landed yes` and go to Step 5r, **carrying the fact
  that the branch is not contained in its base** — Step 5r needs it.

**Why this is a script and not four lines of git here.** `merge-base
--is-ancestor` proves a merge commit and disproves nothing. A controller
computing it in prose reports "not landed" for the single most common way work
lands, and then offers to integrate something that is already in. The adapter asks
the forge when there is one to ask, and says `unknown` rather than `no` when there
is not.

### 3b. Where it lands — derive it, do not read it

**Work lands where it came from,** and `/cue-dev:start` wrote down where that was
— per item, in `.cue/dev/<KEY>/demand.md`'s header. So this is a lookup of one
item's record, followed by a check against git.

```bash
<cue>/work-base <KEY>             # this item's start point
<cue>/work-branch <KEY>           # this item's branch — not the one you are standing on
git merge-base --is-ancestor <that ref> <that branch>     # is the branch still on it?
```

**Both come from the record, and the second one used to be `HEAD`.** That was
wrong from the moment cue-dev stopped moving the session into the worktree: finish
now usually runs in the main checkout, where `HEAD` is the base branch, so the
check asked whether the base branch was still on itself — and passed, every time,
saying nothing about the item. Every branch-relative command in this step names
`<that branch>` for the same reason. If `work-branch` cannot answer, treat it
exactly like a missing start point below: say what is missing, do not substitute
whatever is checked out.

- **Exit 0.** That ref is the landing branch. **Do not ask.** The user answered
  this at `/cue-dev:start`, for this item, and asking again over a fact git just
  confirmed is the friction cue-dev exists to remove.
- **Exit 1.** The branch is no longer on what it was cut from — it was rebased
  elsewhere, or the record and the branch have come apart. **Merging on that
  assumption would be silent and wrong**, so stop and ask.

  Find the real candidates rather than guessing at one:

  ```bash
  git branch --all --contains "$(git merge-base <that branch> <that ref>)" 2>/dev/null
  git log --oneline --decorate -1 "$(git merge-base <that branch> <that ref>)"
  ```

  > "The record says this was cut from `develop`, but the branch isn't on
  > `develop` any more — it looks like it came off `main`. Which should it land
  > in?"

- **If `work-base` fails outright**, this item has no recorded start point —
  `/cue-dev:start` never settled one, or the header line was lost. **Do not guess
  one and merge on it.** Say what is missing, offer your best reading of where the
  branch came from, and get the user's confirmation before anything is merged. Do
  not reach for `/cue-dev:init`: there is no repository-wide start point to record
  any more, and the item's own record is repaired with
  `/cue-dev:redo demand <KEY>`.

Below, `<base-branch>` means the branch settled here.

**Nothing settled here gets written back.** The landing point is not a setting and
not a new record — it is the item's start point, confirmed against git.

**There is no fallback, on purpose.** `work-base` does not consult any
repository-wide default when an item recorded none — that would be the previous
ticket's answer applied to this one, and nothing would say so until the merge.
A missing start point is a question for the user, not a gap to fill in.

### 3c. Where it is pushed — and why that is not the same as the request target

```bash
<cue>/config --get remote
```

`remote` is **the push target only**. The pull request's target is carried by the
item's start point: when that reads `upstream/main`, the request goes against
`main` on `upstream` while the branch is pushed to `remote`. That is the whole of
fork support, and it needs no additional setting — nor, now, any repository-wide
one, so a fork contribution and an internal branch can sit side by side in the
same checkout.

- **If `remote` is empty and there is exactly one remote**, use it.
- **If there are several remotes, ask which one you can push to.** Do not assume
  `origin` — though in a fork it usually is `origin`, with `upstream` appearing in
  the item's start point instead.
- **If there is no remote at all**, there is nothing to decide here. You do not
  have to remember to drop the request option either: `<cue>/integration` already
  did, because a repository with no remote resolves to adapter `none`.

## Step 4: Carry any late correction to outcome.md

**The outcome marker is already stamped — `/cue-dev:implement` stamps it as its
last act, and `scripts/gate` refused to let you get here without it.** So
there is nothing to stamp and nothing to remember. What is left is the window
implement deliberately opens after that stamp: a human reading outcome.md and
fixing it.

```bash
WT=$(<cue>/work-path <KEY>)     # or the main checkout when there is none
git -C "$WT" status --short .cue/dev/<KEY>/outcome.md
```

**If it is clean, this step is done.** If it is dirty, someone corrected the
record after implement finished; commit it as ordinary work and move on.

```bash
git -C "$WT" add .cue/dev/<KEY>/outcome.md
git -C "$WT" commit -m "docs: <correct the outcome record, in the record language> — <KEY>"
```

**`docs:` and the `— <KEY>` suffix stay; the sentence between them follows
`.cue/dev/config`'s language,** like every commit subject cue-dev composes. The
only exceptions are the stage markers, which `<cue>/marker` writes and
`scripts/status` matches on.

**`-C "$WT"`, not a bare `git`.** The correction was made in the tree the work
lives in, and a bare `git commit` here puts it on whatever branch the main
checkout has — which is how a commit belonging to this item ends up on the base
branch. That is the failure named at the top of this skill, and this is one of the
three places it can happen.

**Do not stamp a second marker here.** Stage determination takes the newest
matching subject, so a duplicate does not break anything visibly — it just puts
two commits forward as the end of implement, and the one that reads as the answer
is the one that verified nothing.

**Commit it here, before anything else happens to the branch.** Every path from
here depends on the record already being committed — a merge carries it into the
base branch with the work, a pull request shows the reviewer the diff, and doing
nothing at all leaves it on the branch where the next reader finds it. Defer it
and the correction sits uncommitted in a worktree Step 7 may be about to remove.

## Step 5: Present Options

### 5b. Settle the workspace — the one question this step asks

**The branch is kept. That is not a question and there is no option that deletes
it here.** Every commit and all four records are on it, it is what Step 9 will
propose or merge if anything does, and it is what `/cue-dev:status <KEY>` finds
afterwards. The only branch deletions in this skill are consequences: the merge in
Step 9 removes the branch it just merged, Reclaim removes one whose work has
already landed, and discard happens only when your human partner asks for it in so
many words.

So there is exactly one thing to settle, and it is the workspace.

| | the option to offer |
|---|---|
| **Retire the worktree** | the work is done in there; the branch keeps every commit and can be checked out again whenever it is needed |
| **Keep the worktree** | you are coming back to this work — review comments, another commit, something still being tried |

**Ask with `AskUserQuestion`, and recommend neither.** Which one is right depends
on what the user intends to do next, which is Step 9's question and has not been
asked yet — that is deliberate (see the Overview), and it means the reason for
keeping a worktree is theirs to know, not yours to infer.

**But the cost of each answer is yours to state, because they are being asked
before the question that decides it.** Put both in the descriptions:

- **Retiring it** frees a second full checkout of the repository — one that
  someone will otherwise edit by mistake, believing they are in the main tree.
- **Keeping it** keeps a tree that is ready to work in. If Step 9 opens a change
  request, the review comments come back to this branch, and this is where they
  are answered.

**Re-cutting one is not "a single `git worktree add`", and this page said it was
for a long time.** A worktree carries the tracked files and nothing else:
`node_modules`, `.venv`, build caches and every untracked local `.env` stay
behind. The sentence was written from git's point of view and it is wrong from
the user's — in a real session the user kept the worktree and still could not
start the app, because `react-scripts` was not installed in it. Say the install,
not just the command.

**A prose question here does not work.** It does not end the turn, so the same
turn continues, and continuing needs an answer: a real session wrote `User says
yes, so I'll proceed` and cut a branch nobody had approved. Add no options of your
own — the interface supplies its own "something else".

**Detached HEAD is the one case that skips the question.** The workspace is not
cue-dev's to remove (Step 7); say so and move on.

**`landed yes`** (Step 3a): none of this applies — you are in Step 5r.

**Keeping a branch has never required keeping the worktree it was built in.** That
pairing was assumed for a long time, and it left the most ordinary case — work
parked for later — with no way to tidy up. It also runs the other way: a worktree
kept now is retired by Step 9 if a merge happens, because a worktree cannot outlive
the branch it has checked out. Say that in the description if they keep it.

**And the reverse pairing is not assumed either: retiring the worktree does not
mean the work is over.** Both answers leave the branch, every commit and all four
records exactly where they are, and Step 9 asks about integration afterwards
either way. A user who retires the worktree and then opens a change request has
done a perfectly ordinary thing — what they have given up is a checkout that was
ready to work in, which matters when the review comes back and not before.

**What is *not* an answer to review feedback is `/cue-dev:start`.** That command
cuts a new branch from the base ref (`cue-dev:start`, step 4), so running it on a
branch with an open request produces a second branch and a second request rather
than a commit on the first. Review comments are the same item — same requirement,
same design, same plan, a changed implementation — and they belong on the branch
the request is already reading. `cue-dev:receiving-code-review` is that path.

### 5r. When the work has already landed

**Reached from Step 3a, and only from there.** There is no integration act to
choose: the work is in. What is left is the workspace it was built in, and the
branch that is now a duplicate of history.

Ask one question with `AskUserQuestion`. **No option carries a "(recommended)"
badge** — order carries the recommendation, the description carries the reason.
The rule is at the head of step 4 in `cue-dev:start`. This step had one, on a page
that says twice elsewhere (5b, 9a) to recommend nothing.

> "`<KEY>` has landed in `<base-branch>` — `<the evidence line the script
> printed>`. Reclaim the workspace?"
>
> 1. **Retire the branch and the worktree** — the work is in `<base-branch>`, so
>    the branch is a duplicate of history and the worktree has nothing left to do
> 2. **Leave them in place** — you are still working out of that checkout

Then Step 6's **Reclaim** path. **This is the whole reason `/cue-dev:finish` may be
run twice.** It stamps no marker, so nothing stops a second run — and until this
existed, choosing the request path meant the branch and the worktree stayed on
disk forever, because the skill said in so many words that there was no stage
after finish.

## Step 6: Carry out the workspace answer

**There is one answer to carry out and it came from 5b.** This step used to be a
switch over integration actions; those moved to Step 9, and what is left is the
thing finish owes the item it is closing.

Both branches of it start in the main checkout, because Step 7 cannot remove a
worktree from inside it:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

- **Retire it** → Step 7. The script does the removal and reports what is actually
  on disk afterwards.
- **Keep it** → nothing to run. Hold on to the path for the notice; the line is
  `worktree  <path> (kept)` and it is not optional (Step 8).

**The branch is untouched either way, and nothing is pushed or merged here.** That
is the whole of the ordinary path: the branch holds every commit and all four
records, and Step 9 asks what to do about that after the box.

**`scripts/status` still finds the work** — it matches the checked-out branch
against the `branch:` line in each item's demand.md, and the branch is still
there. From the main checkout, where that branch is not the one checked out, pass
the KEY.

### Reclaim — the work has landed, take the workspace back

**Reached only from Step 5r.** Nothing is integrated here; it already was.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then Step 7 for the worktree, and the branch:

```bash
git branch -d <feature-branch>
```

**`-d`, and read what it says.** It refuses a branch whose commits are not in the
current branch, and on this path that refusal carries information: with an
ordinary merge it will not happen, and when it does happen the landing was a
squash or a rebase — which is exactly the case Step 3a could not settle from git
either.

**If it refuses, do not reach for `-D` on your own.** The user has already told
you the work landed; what they have not been told is that git disagrees, and `-D`
throws the commits away on the strength of an answer they gave to a different
question:

> "git won't delete `<branch>` — it says the commits aren't in `<base-branch>`,
> which is what a squash merge looks like. Deleting it anyway drops those commits
> from this repository. Go ahead?"

Only on an explicit yes: `git branch -D <feature-branch>`.

**The record survives either way.** `.cue/dev/<KEY>/` went in with the landing, so
`<cue>/status <KEY>` still finds it once the branch is gone.

### If your human partner asks to discard the work

This path exists only as a response to an explicit request to throw the
work away. Confirm first:

```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then clean up the worktree (Step 7) and force-delete the branch:

```bash
git branch -D <feature-branch>
```

## Step 7: Cleanup Workspace

**Runs whenever 5b's answer was to retire the workspace, and on Reclaim and on a
confirmed discard.** Step 9c's merge always runs it too — a worktree cannot outlive
the branch it has checked out, including one 5b chose to keep. **Do not decide this
from what happens to the work.** The criterion is not "merged" but **"is anyone
still going to work in there"**, and that is the question 5b asked, before the
integration question existed to confuse it.

```bash
<cue>/finish-cleanup <KEY>
<cue>/backups <KEY>          # Step 7d's input — one call, usually silent
```

`finish-cleanup` is one call and does the whole thing. It reads the worktree from
this item's record — from the item's own branch when this checkout does not have
it — removes the implementation scratch (`.cue/dev/sdd/`), asks git whether the
worktree is registered, removes it, clears an empty `.worktrees/` behind it, and
then **looks again** and reports what is actually on disk. Its output is notice
lines — put them in Step 8's block as they came.

**This skill is where the scratch dies, and that is a recent change.**
`/cue-dev:implement` used to delete it as its own last act. But the implementer
reports in there are what `<cue>/evidence` counts to answer "was this actually
reviewed by something that did not write it" — the question Step 1 above already
asked, and the one implement asks before writing `checked-by`. Deleted at the end
of implement, the answer was zero for every item by the time anyone could ask it.
It goes here, after both questions.

`backups` rides along in the same block because it is the step most easily skipped
and it costs nothing: it prints nothing when there are none. Step 7d says what to
do with a non-empty list.

### 7c. When it contradicts the answer you were given

**Two of its lines are answers to a question 5b already settled, and when they
disagree with 5b, the disagreement is the finding. Do not reconcile it in
prose.**

| what it printed | what it means |
|---|---|
| `worktree  none — this item has no worktree` | the record says this item was built in the main checkout |
| `worktree  unknown — no record for <KEY> …` | nothing in this repository has a record for that KEY |

**If 5b offered to retire the workspace, neither of these can be right** — 5b is
only asked when Step 2 found a worktree. Something is wrong with the KEY, the
record, or which repository you are standing in. **Stop and show the line.**

This is not a hypothetical reconciliation problem. In a real session the user
chose *retire the worktree*, the script printed `none — this item has no
worktree`, and the notice went out reading `worktree  none — removed` — a line
the script never printed, assembled to make the contradiction go away. The
worktree was still there. Two steps later `git branch -d` refused because of it,
and the removal was finished by hand, outside every guard in this file: no dirty
check, no empty-parent cleanup, no looking again afterwards. `.worktrees/` was
still sitting in that repository the next day.

**The script's lines go into the notice as they came, including when they are not
what you expected.** That is the entire reason they come from a script. If a line
does not fit the story you were about to tell, the line is right and the story is
wrong.

**It takes the KEY, not a path**, and that is what lets a finish running days
later, from the main checkout, clean up the right directory. A path read off
`--show-toplevel` answers "where am I", which is the same question the record was
introduced to stop asking.

**This used to be five steps of prose and it failed as prose.** In a real session
the user chose the path that cleans the worktree up and the notice said `worktree
preserved`: nothing was removed and the report was written from intent instead of
from the last observation. The scratch had never been deleted by anything, in any
run, since it was introduced.

**On exit 1 the workspace is still there.** Show the `worktree` and `action`
lines and stop; do not report a cleanup that did not happen. "Worktree removed"
after a failed removal is worse than leaving it in place, because the user stops
looking.

### 7b. When it lists uncommitted files

`holds <n> uncommitted file(s)` means the worktree contains work that removing it
would destroy, and **nothing was removed** — not the worktree, not the scratch.
This is the good outcome, not an obstacle.

**Show the list and ask what to do with each thing on it.** Use
`AskUserQuestion`: commit them, or discard them.

> "The worktree still holds files that are not in git. Removing it deletes them.
>
>     ?? .cue/dev/20260806-green-text/notes.md"

If they say commit, commit them and run `finish-cleanup <KEY>` again — with no
flag, so the same check passes on its own. **Only if they say discard**, run
`<cue>/finish-cleanup --force <KEY>`.

**`--force` is how consent gets carried out, not how the question gets skipped.**
Reaching for it because the plain run refused is the failure this check exists to
catch, and it has already cost a real user a file: a generated page was written
into a worktree, no step committed it, and `git worktree remove --force` took it
with the directory. Nobody saw a warning, because nobody had asked.

**Never `--force` on your own judgement that the files look unimportant.** You are
looking at names. The user is looking at their work.

**And never delete the files instead.** This is the worse version of the same
move and it has happened: a run whose cleanup kept refusing worked out which path
the check was naming and ran `rm -rf .claude` on it — the user's own directory, in
the main checkout, unasked, with no backup branch and nothing in git to recover
it from. `--force` at least leaves a record of a decision somebody made. Deleting
the obstacle leaves the check passing and no trace that it ever fired.

**If the list names something outside the worktree, the list is the bug — stop
and say so.** `finish-cleanup` scopes its check to the worktree, so a path like
`../../.claude/` cannot come from it; it comes from a `git status` run by hand
inside a directory whose worktree is already gone, which walks up to the parent
repository and reports *its* untracked files relative to where you are standing.
Nothing there is this item's to clean up.

### 7a. When it says the worktree is not cue-dev's

The item has no recorded worktree and you are standing in one, so something other
than cue-dev made it. **Do not remove it and do not call a harness exit tool on
cue-dev's behalf** — report the path and let the user decide. If they remove it
themselves, confirm with:

```bash
<cue>/finish-cleanup --verify <KEY>
```

An unregistered worktree can leave its directory sitting there, which is exactly
the leftover this step was rewritten for.

## Step 7d: Ask about this work's backup branches

Every `/cue-dev:redo` on this item left a backup branch behind, and nothing
deletes them. This is the first moment they are safe to drop — the work is done
and integrated, so there is no rewind left to undo.

```bash
<cue>/backups <KEY>
```

Nothing printed means there are none: skip this step in silence. Otherwise show
the list as it stands and ask with `AskUserQuestion` — delete them, or keep them.

> "These backup branches are left from rewinds of `<KEY>`. The work is finished,
> so they have nothing left to restore. Delete them?
>
>     cue-dev/backup/<KEY>-20260804-174619  (7 hours ago)
>     cue-dev/backup/<KEY>-20260804-152210  (9 hours ago)"

**Show the list first, then ask, then run `git branch -D` yourself** with exactly
the branches the script printed. Deleting branches without asking is what must not
happen; making the user type the command is not what protects them from that, and
it puts them in a terminal this tool exists to keep them out of.

**Only this KEY's backups.** The script is scoped to the KEY and has no flag to
widen it, so pass the KEY and use what comes back. Other work items keep backups
at the same prefix, and those are another piece of work's only recovery path — a
`git branch -D 'cue-dev/backup/*'` of your own composition destroys them all, and
that is exactly the accident the scoping prevents.

**If they say no, that is a complete answer.** The branches cost nothing to keep
and asking twice is worse than the clutter.

## Step 8: Print the notice

**There is one box on the ordinary path now, not one per integration action.**
Nothing has been pushed or merged at this point, so there is nothing that differs
between them: the branch is kept, the workspace is settled, the records are on the
branch. Reclaim (5r) is the one variant, below.

**The `scratch` and `worktree` lines are not yours to write.** Put the line
`@cleanup <KEY>` where they belong and `scripts/notice` fills them in, by asking
`finish-cleanup` again as the box is drawn. You do not copy them, you do not
remember them, and there is no wording of them you can get wrong.

This step used to say "copy what it printed, do not write those lines from what
you meant to happen". A session that had that paragraph in front of it wrote
`worktree  .worktrees/<KEY> (removed)` over a directory `finish-cleanup` had
refused to remove one tool call earlier, and then `worktree  removed` again in
the `MERGE done` box. Both were true about the intent. The token is there so that
the intent has no way in.

**Every `FINISH done` box carries a `worktree` line. There is no path that omits
it.** Either 5b retired the workspace, and the line is the one `finish-cleanup`
printed, or 5b kept it, and the line is `worktree  <path> (kept)`. A box with no
`worktree` line at all is not a box for an item without a worktree — that item
gets `worktree  none — this item has no worktree`, from the script, because the
script says so. It is the signature of Step 5b and Step 7 having been skipped, and
that is exactly how it has failed in a real session: the user chose to keep the
branch, the notice listed the key, the branch, the records and the commit, and a
second full checkout of the repository was still sitting in `.worktrees/<KEY>` with
nothing anywhere saying so. The line is the only thing in this skill that reports
on disk state, so if you cannot fill it in, the answer is to go back and run Step
7, not to leave it out.

**Reproduce its output verbatim in your reply, in a fenced code block, and put it
last.** Anything you need to say goes *above* it — a decision you need from the
user, a warning, the answer to what they actually asked. **Nothing goes under it,
and nothing restates its labels.** That holds for all four boxes this skill can
print, not only this one.

```bash
<cue>/notice "FINISH done" <<'EOF'
  key       <KEY>
  branch    <feature-branch> (kept — every commit and record is on it)
  records   .cue/dev/<KEY>/ (demand · design · plan · outcome)
  commit    <only when Step 4 committed a correction — omit this line otherwise>
  @cleanup  <KEY>          <-- retired in 5b; on the kept path write: worktree  <path> (kept)

  next      /cue-dev:finish asks about integration next — nothing is pushed yet
EOF
```

**`commit` is the one optional line here, and the template used to demand it.** It
read `<the commit subject actually written>`, which on the ordinary path names
nothing: Step 4 commits only when someone corrected outcome.md after implement
stamped its marker, and its first instruction is "if it is clean, this step is
done". So the usual run reached this box with the line unfillable and two ways to
go — drop it against the instruction to reproduce the template, or invent a
subject. **Neither.** Finish stamps no commit of its own; when there is nothing to
name, the line is not there. That is the standing rule for these blocks: a line
appears when it says something, and one printed on every run stops being read.

**The `worktree` line is the opposite case and stays unconditional**, because it is
the only thing here that reports on disk state — see below.

**`branch  <name> (kept — every commit and record is on it)` is a claim, and the
record gate is what makes it true.** `verify` refuses a row whose commit is not on
that branch, so by the time this line is printed the claim has been checked. It was
not always: the same sentence was printed over a branch holding six record commits
and no code. Do not write it if you skipped the gate.

**`next` names Step 9 and nothing else.** The item is finished; what follows is a
question, not an obligation, and the box should not read as though the user still
owes somebody a pull request. It used to say `/cue-dev:finish again when there is
somewhere to propose it`, which a real user stopped at and asked what it meant —
fairly, because it put a command on the `next` line, which everywhere else in
cue-dev means *do this now*, and made it conditional on a circumstance they had no
reason to be thinking about.

**Reclaim:** nothing was integrated here — say where it landed and what came back.

```bash
<cue>/notice "FINISH done" <<'EOF'
  key       <KEY>
  landed    <base-branch> — <the evidence line the script printed>
  records   .cue/dev/<KEY>/ (on the landing branch)
  branch    <feature-branch> (deleted) | (kept)
  @cleanup  <KEY>

  look      /cue-dev:status <KEY>   ← the branch name no longer finds it
EOF
```

**Add a `backups` line whenever Step 7d had something to show** — `deleted <n>`
or `kept <n>`, whichever the user chose. It is the only record that the question
was asked.

**The box is not the end of the skill — Step 9 is.** Print it, then go straight to
Step 9 and ask the integration question. The only path that ends here is Reclaim:
the work already landed, so there is nothing left to integrate.

**This paragraph used to say "Stop here."** — meant for the path that had just
opened a pull request, written under that path's template, and read by a session
on the other path as the end of the skill. It stopped there, Step 9 was never
offered, and the user had just been told the branch was parked with nowhere to
propose it to — which made the skipped question the only one that mattered. An
instruction to stop, in a skill that has a step after it, is taken by whoever
reaches it first.

## Step 9: Integration — asked after the notice, once

**The item is already finished.** Step 8's box said so, the workspace is settled
and nothing here is owed. This step asks what to do about integrating the work, and
**`not now` is a complete answer** — the branch keeps every commit and all four
records, and `/cue-dev:finish` run again comes straight back to this question
(Step 4 finds outcome.md clean and passes through).

**Skip the whole step when either of these is true:**

- Step 3a said `landed yes` — it is already in, and Step 5r handled it
- detached HEAD (Step 2) — there is no named branch to propose or merge. Say that,
  rather than skipping silently.

### 9a. Ask

**The options come from the repository, not from here.**

```bash
<cue>/integration --actions      # one action per line
<cue>/integration                # the adapter's own wording, for the descriptions
```

| an action it printed | the option to offer |
|---|---|
| `request` | **Open a change request** — push the branch and propose it against `<base-branch>`, worded from the adapter's own `request` line |
| `keep` (always printed) | **Not now** — the branch and its records stay exactly as they are |
| — | **Merge it into `<base-branch>` here** — never an action, and offered under every adapter. It needs no forge; it takes the main checkout for as long as the tests run, so only one workspace can do it at a time |

**Ask with `AskUserQuestion`, exactly once, and recommend nothing.** Which of the
three is right is a judgement about a team, a release and who carries the
consequence, and none of that is visible from here. The description of each option
says what it does; the choice is theirs.

**Do not offer `request` when it is not among `--actions`** — a repository with
no remote has nowhere to propose the work, and an option that dies on the command
that carries it out is worse than one that is not offered. Read the tokens, not
the display: bare `integration` prints a `request` line under every adapter,
including the one where the line exists to say the action is unavailable. Then it is a
two-option question, which is still a question: merging into the base branch is
not what most teams do, and it must not become the path of least resistance just
because it is the one that tidies up.

**And do not ask this in prose.** A prose question does not end the turn, so the
turn carries on, and carrying on needs an answer — a real session wrote `User says
yes, so I'll proceed` and cut a branch nobody had approved. These are the two most
outward-facing acts in cue-dev; they are the last place to accept a question that
can answer itself.

**Ask it once.** If they decline, that is the end of the skill. Do not raise it
again, do not re-offer it in prose, and do not add a closing sentence suggesting
they will want it later — the box already carries the way back.

**Why this is here and not in a menu before the box.** Both of these are
commitments to other people, and the tidy-up is not. Putting them first made
finishing conditional on answering them, which served the developer who wanted the
pull request immediately and nobody else. It also split them apart for a reason
that no longer holds: `request` was an adapter action and the merge was not, so
one sat in the menu and the other after the notice, which is an implementation
detail of `scripts/integration` showing through as two different kinds of
question. They are the same kind of question. The merge still needs the lock, and
it takes it in 9c.

### 9b. Open a change request

**Publishing is the same under every adapter. Proposing is not.** The push below
belongs to git; what follows it comes from `<cue>/integration`'s `request` line,
and that line is the only thing in this skill that knows what a forge is.

```bash
git push -u <remote> <feature-branch>
```

| adapter | how the request is opened |
|---|---|
| `github` | `gh pr create` (below) |
| `git` | **cue-dev does not open it.** Report the creation URL the push printed — most forges print one — and say that the request is theirs to open. Do not reach for a CLI you have not confirmed is installed. |

**The push target and the request target can be different repositories.** Split
`<base-branch>` from Step 3b:

| the item's start point | push to | request against |
|---|---|---|
| `main` or `origin/main` | `<remote>` | `main` on the same repository |
| `upstream/main` | `<remote>` (your fork) | `main` on `upstream` |

That second row is the fork workflow, and it is the reason `remote` is not read as
the request target. With `gh`, the cross-repository form is explicit:

```bash
gh pr create --repo <owner-of-upstream>/<repo> --base main --head <your-owner>:<feature-branch>
```

Derive `<owner>/<repo>` from `git remote get-url <name>` rather than assuming it.

**Do not manufacture a request body.** Follow the repository's template if it has
one; otherwise keep it short. What was built and why lives in the four documents
under `.cue/dev/<KEY>/`, on the same branch, where the reviewer reads them in the
diff. Copy them into the body and you have two copies, and the two start to drift.
Pointing at the `.cue/dev/<KEY>/` path is enough.

**If the push fails** (no permission, the remote moved), stop there and report it
as is. Nothing is lost — the item was already finished before this step, and the
box that said so is already up. Fix the cause and run `/cue-dev:finish` again.

Then print the second box:

```bash
<cue>/notice "REQUEST done" <<'EOF'
  key       <KEY>
  request   <url, or the creation URL the push printed>
  branch    <feature-branch> pushed to <remote>
  worktree  <the state Step 6 left it in — kept at <path>, or removed>

  next      /cue-dev:finish once it lands — reclaims the branch and the workspace
EOF
```

**The review is a human's job; the workspace still has to come back one day.** That
is what `next` is for, and it is the whole reason finish repeats. Before Step 5r
existed, choosing this path meant the branch and the worktree stayed on disk for
good, because nothing ever came back for them.

**If the worktree was retired in Step 6 and review comments arrive later**, cutting
a new one is `git worktree add <path> <feature-branch>`. Say so once, here, rather
than steering the 5b answer toward keeping it.

**Then stop.** Do not pre-empt review comments by fixing what you guess they will
say.

### 9c. Merge it into the base branch, behind the lock

```bash
# Nobody else may be inside a merge right now
<cue>/merge-lock --acquire <KEY>

# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Is the landing branch free to check out here?
<cue>/branch-holder <base-branch>

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull --ff-only                       # only if <base-branch> tracks a remote
git merge --no-ff <feature-branch>
```

**`git pull` is conditional and it used to be unconditional.** A repository with
no remote — the case Step 3c handles two screens up, the case `integration`
resolves to adapter `none` — has no tracking branch, so `git pull` exits 1 with
*"There is no tracking information for the current branch"*. Chained with `&&`
that takes the merge down with it, which is exactly what happened in a real
session: the merge did not run, and the recovery was to retype the command
without the pull, unmerged and unremarked. Check first, and skip it when there is
nothing to pull from:

```bash
git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1
```

**Then verify tests on the merged result** — in the main checkout, which is the
tree you are now standing in and the one about to become the base branch. **If
there is no suite, say so in that sentence**; Step 1b's rule applies here
unchanged, and a merged result reported green by a run that never happened is the
same fabrication one step later.

**The lock is the first command and it is not optional.** This is the one
repository-wide path in cue-dev: everything else happens on this item's branch in
this item's worktree, but here you leave the worktree, take over the main checkout
and run the tests there. **`merge-lock` exits 1 when another item is inside its
merge — stop, relay its lines, and offer to come back to Step 9 later.** Do not
break the lock to get past it; `--break` exists for a lock a human has judged
abandoned, and the script says when it looks that way.

**`branch-holder` is a second check, not the same one.** It answers whether some
*other worktree* has the landing branch checked out, which git would refuse three
commands later — after the worktree had been left, looking like a broken tool. It
does not answer the two-sessions question, because in the ordinary layout the
landing branch lives in the main checkout and both sessions get "checked out
here". That is what the lock is for. Run both.

**`--no-ff` is deliberate and not configurable.** A fast-forward erases the fact
that a branch existed, and with it the shape of the work — which is the one thing
this whole tool is built to preserve. It is also what git flow requires of a
feature merge. A team that wants linear history uses the `request` path, where the
forge decides.

**No `-m`, unless you write it in the record language.** git's default subject —
`Merge branch 'feat/x'` — is git's own wording and reads as such in any
repository. Supplying one puts a sentence you composed into the history, and a
composed sentence follows `.cue/dev/config` like every other one: a real `ko`
repository ended up with `Merge feat/add-instagram-page into main` sitting on top
of six Korean commits. Either let git write it, or write it in the record
language. Do not write your own in English.

**This step is plain git and works under every adapter, including `none`.** Merging
into a branch needs no forge, which is why it is not an adapter action: folding it
in would have made "merge locally" a feature of having a GitHub remote.

**If tests fail on the merged result:** release the lock, stop, and leave the
worktree and branch in place while you investigate. Nothing has been pushed, so the
merge is local and recoverable — and holding the lock through an investigation
blocks every other workspace.

```bash
<cue>/merge-lock --release <KEY>
```

**Once the merged result is green**, three things in this order, and the order is
not cosmetic:

```bash
<cue>/finish-cleanup <KEY>          # 1. the worktree — see Step 7
git branch -d <feature-branch>      # 2. the branch
<cue>/merge-lock --release <KEY>    # 3. the lock, always
```

**The worktree goes first because git will not let the branch go while a worktree
has it checked out.** Reverse them and `git branch -d` fails with *"cannot delete
branch … used by worktree at …"*, which is how a real session ended up running
`git worktree remove` by hand — bypassing Step 7 entirely, and with it the dirty
check, the empty-parent cleanup and the look-again. **If you see that error, the
answer is Step 7, not `git worktree remove`.**

Step 7 runs here **even when 5b chose to keep the worktree**: a worktree cannot
outlive the branch it has checked out. Say so when you report it — the user
answered 5b before this question existed.

**Release the lock even when something went wrong** — a lock nobody releases stops
the next workspace for thirty minutes and then asks a human to break it.

**Once the branch is gone, nothing on disk points at this item from where you are
standing.** The record (`.cue/dev/<KEY>/`) is safe — it went into the base branch
with the merge, `branch:` line and all — but that line names a branch that no
longer exists, so `scripts/status` with no argument will not land on it. Look it up
with `<cue>/status <KEY>` instead, and put that one line in the notice.

Then print the second notice:

```bash
<cue>/notice "MERGE done" <<'EOF'
  key       <KEY>
  merged    <base-branch> ← <feature-branch> (branch deleted)
  records   .cue/dev/<KEY>/ (on the base branch)
  @cleanup  <KEY>

  look      /cue-dev:status <KEY>   ← the branch name no longer finds it
EOF
```

**`merged` says only what the merge did.** It used to read `(branch and worktree
cleaned up)`, and in a real session both halves of that were printed over a
workspace still on disk — the `@cleanup` line two rows up is the only thing in
this box entitled to say anything about the workspace, because it is the only
thing that looked.

**`MERGE done` is the only merge title `scripts/notice` accepts, and it exists
because this step does.** A real session merged outside finish and reported it
inside a `━━━ MERGED · <KEY> ━━━` frame it drew itself, naming a stage that did not
exist. `MERGED` is still refused. A merge done anywhere but here is still ordinary
prose with no box at all.

## After finish — one stage repeats, everything else is ordinary work

**`/cue-dev:finish` is repeatable, and deliberately so.** It stamps no marker
(`scripts/gate` allows it every time), and two things depend on that. A `not now`
at Step 9 is not a decision the user is stuck with — running finish again comes
straight back to the question. And 9b's pull request is closed out by Step 5r:
propose the work today, come back when it lands, and finish reclaims the branch
and the workspace. Before that existed, opening a request meant those two stayed
on disk permanently.

**Everything else after finish is ordinary work reported in ordinary prose** — the
user asks you to push it, delete it, rename the branch, open the request by hand.

**Do not draw a box for any of it.** In a real session a merge performed after
finish was reported inside a hand-rendered `━━━ MERGED · <KEY> ━━━` frame: a stage
that does not exist, in the frame that means "a cue-dev stage produced this and a
script verified it". `scripts/notice` refuses any title outside its list, so the
only way to produce one is to draw it yourself. Do not.

**If they ask for a local merge, that is Step 9c.** Come back here and run it,
rather than doing the merge freehand — 9c takes the merge lock, removes the branch
and retires the worktree, which is why the freehand merge is followed by a
repository that still has all three and by nothing at all stopping a second
workspace from merging into the same checkout at the same moment. The same is true
of a push done by hand: 9b prints a `REQUEST done` box because a request opened
through this step is one the records were checked for.

## Quick Reference

**Steps 1–8 are the same every time.** Verify, settle where it lands, settle the
workspace, clean up, print the box. Nothing is pushed, merged or deleted in there —
the branch is kept, always. Then one question:

| Step 9 answer | Merge | Push | Branch after | Workspace |
|------|-------|------|---------------|-----------|
| Not now | - | - | kept | as 5b decided |
| 9b request | - | yes | kept | as 5b decided (re-cut one later if it was retired) |
| 9c merge | yes | - | deleted | always retired — it cannot outlive the branch |

Two paths never reach that question:

| | Merge | Push | Branch after | Workspace |
|------|-------|------|---------------|-----------|
| Reclaim (already landed, 5r) | - | - | deleted, or kept on refusal | retired |
| Discard (explicit request only) | - | - | deleted | retired |

`request` is offered only when `<cue>/integration` prints it; the merge is offered
everywhere, including a repository with no remote at all, and it holds
`scripts/merge-lock` for its duration so that two workspaces cannot take the main
checkout at once.

In every path the `cue-dev(outcome)` commit is already on the branch, stamped at
the end of implement — and `verify` has already confirmed the task commits are on
that branch too.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "There's no suite, but I checked it manually while implementing" | Point at the tool call. If you cannot, it did not happen — and this exact sentence, in a repository of four static HTML files, produced four bullet points of browser observations nobody had made. Report `evidence:` as the field it is, and ask the user to run the check if one is named. |
| "`evidence: manual` means someone looked, so I can say what they saw" | It means a field holds the word `manual`. What was looked at is not in the record, so it is not yours to describe. |
| "Asking the user to open a page is admitting I'm stuck" | It is the one check in this repository you cannot run and they can. An unrun check named as unrun costs nothing; an unrun check reported as passed is what this whole tool exists to prevent. |
| "The script says no worktree but the user asked me to retire one — I'll word the notice around it" | The contradiction is the finding. 5b is only offered when there *is* a worktree, so one of the KEY, the record or the checkout is wrong. Wording it away is how a second checkout stayed on disk with a box saying it was gone. |
| "I'll add a tidy ✓ summary above the box so they can see what happened" | The box already says it, in fewer lines, from scripts. A summary that walks its labels is the box again at twice the length — and the one that shipped asserted a worktree cleanup that had not occurred. |
| "The merge is done, so a summary of the whole run is a nice closing touch" | Nothing goes under the box and nothing restates it. What you have to add goes above it and says something the box does not. |
| "They obviously want it merged" | Integration is your human partner's decision, it is Step 9, and it comes after the item is already finished. Ask once and take the answer. |
| "A couple of unrecorded rows are left, but the commit log tells me enough" | A narrative invented from the commit log is exactly what this system exists to prevent. Send it back to `/cue-dev:implement`. |
| "implement must have committed outcome.md already" | implement only fills it in. Skip the commit here and you get a PR missing its result. |
| "Let me write the design rationale into the PR body" | The four documents on the same branch are the original. Copy them into the body and you have two copies that soon drift. Point at the path instead. |
| "They seem done with this feature — I'll offer to discard it" | Discard happens only when your human partner asks for it in so many words. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the worktree is clutter now" | PR feedback gets fixed in that worktree. It stays until the work lands. |
| "No remote, so merging into the base locally is the only way to finish" | Keeping the branch and retiring the worktree finishes it too, and it is the option that matches how the work started. Most teams do not merge straight into the base; do not make that the easiest button just because it is the one that tidies up. |
| "They'll want to merge, so I'll put it in the Step 5 question" | Then finishing the item is conditional on answering an outward-facing question, and two workspaces get handed the main checkout in the same breath. Step 5 settles this item's workspace; Step 9 asks about the world outside it. |
| "The lock looks stale, I'll `--break` it and carry on" | The script says how long it has been held and names `--break` for exactly that judgement — a human's. A forty-minute test suite and a dead session look identical from here, and guessing wrong puts two merges in one checkout. |
| "The tests failed, I'll hold the lock while I look into it" | Every other workspace is stopped for as long as you hold it. Release it, investigate, and run Step 9 again — it is re-entrant for this KEY precisely so a second attempt is free. |
| "They want the branch kept, so the worktree stays too" | The branch is always kept at Step 5 — that is not a choice, so it implies nothing about the workspace. 5b asks that separately. A branch costs nothing to keep; a stale worktree is a second checkout of the repo that someone will later edit by mistake. |
| "The notice has nothing to say about the worktree, so I'll leave the line out" | Then nothing on the page says a second checkout is still on disk, and nobody looks again. Every box carries the line; if you cannot fill it in, Step 7 is what you skipped. |
| "The notice is printed, so finish is over" | Step 9 comes after it, and on the ordinary path it is the question the user has been waiting for. `Stop here` belonged to one path and was read as the end of the skill on the other. |
| "This other worktree looks stale — I'll clean it too" | `finish-cleanup` removes the one path this item recorded. Everything else belongs to the host, including a worktree cue-dev did not make. |
| "`git worktree remove` returned, so the worktree is gone" | It can fail on an already-unregistered path and leave the directory sitting there. `finish-cleanup` looks afterwards and its exit code carries the answer — read it. |
| "The exit tool ran, so the directory must be gone" | The harness unregisters and can leave the directory. That is where the leftover came from. `--verify` is the step that finds out. |
| "The scratch is gitignored, so it does no harm" | Nothing else has ever deleted it. Every finished item left one behind and every new worktree grew another. Gitignored means invisible to git, not absent from the disk. |
| "The user asked me to merge after finish — I'll report it in a box" | The box means a cue-dev stage produced this. A merge you did freehand is not one. `notice` refuses the title now; do not hand-draw it. Better: run finish's `merge` path, which also cleans up. |
| "The backup branches are harmless, no need to bring them up" | Nothing else ever deletes them, so they accumulate one per rewind forever. Finish is the first moment they have nothing left to restore. Ask once. |
| "While I'm at it I'll clear out the other backups too" | They belong to other work items and are those items' only recovery path. `scripts/backups` takes a KEY for that reason and has no flag to widen it. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Branch and worktree stay put while you investigate. |
| "Committing the outcome in Step 4 makes it hard to undo" | Undoing is `/cue-dev:redo`'s job. Defer the commit and the correction is still sitting in a worktree Step 7 may remove. |
| "The base branch is obviously main" | Read the item's record and ask git. `work-base <KEY>` plus `merge-base --is-ancestor` settles it in two commands, and when the second says no, that is a branch that would otherwise have been merged into the wrong place in silence. |
| "The ancestor check passed but I'll confirm the base anyway" | Then you are asking the user to re-answer what they already answered at start, over a fact git just verified. Confirm only when the check fails. |
| "`work-base` failed, so I'll set the repository's base branch and re-run" | There is no repository-wide start point any more. The missing value belongs to this item, and the item's record is fixed with `/cue-dev:redo demand <KEY>` — not with `/cue-dev:init`. |
| "`remote` is where the PR goes" | `remote` is where the branch is pushed. The request target comes from the item's start point, which is what makes a fork work without another setting. |
| "A fast-forward merge is cleaner" | It erases the fact that the branch existed. This tool exists to keep that. Use `--no-ff`. |
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
| "This repo is on GitHub, so the options are the usual four" | There is no menu at Step 5 any more — one question about the workspace — and Step 9's options come from `<cue>/integration`. Writing a fixed list out is how the GitHub shape got baked in the first time. |
| "No `gh`, but I'll offer the PR option and figure it out after they pick" | The adapter already decided: without `gh` on PATH a GitHub remote resolves to `git`, and `request` means push and hand the URL over. Offering an option that dies on the command that carries it out is worse than not offering it. |
| "`merge-base --is-ancestor` says no, so it hasn't landed" | It proves a merge commit and disproves nothing. A squash landing — the most common kind — leaves no ancestry. That is why `integration --landed` answers `unknown` there, and `unknown` is a question for the user, not a `no`. |
| "They said it landed, so `-D` the branch" | They answered "did it land", not "may I drop these commits". git refusing `-d` means it disagrees with them; say so and ask again before `-D`. |
| "The request is open, so finish is done with this item" | Finish repeats. When the request lands, running it again reclaims the branch and the workspace — which is the only reason those two do not accumulate forever. |
| "They said not now, so I'll leave the worktree for when they come back" | 5b already asked and was answered, before this question existed. Carry out that answer; do not revise it from something they said afterwards about integration. |
