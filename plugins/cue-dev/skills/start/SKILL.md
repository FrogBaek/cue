---
name: start
description: Use when beginning any new unit of work in a cue-dev project - a ticket, a feature request, a bug report, or a spoken request. Use it before designing or planning, and before touching code for a new item.
argument-hint: [requirement or ticket body] [KEY]
---

# Start work

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


Capture the requirement, create an isolated workspace, and mark the branch.

**Announce when you start:** "Starting work with the cue-dev:start skill."

If you were given a KEY as in `/cue-dev:start <KEY>`, use it as is. Otherwise you
decide it in step 2 below.

## Sequence

Follow the numbers. **Order matters** — demand.md must be written *after* the
worktree exists, inside it. Write it earlier and it stays in the original
checkout, missing from the worktree.

### 0. Check that the repository is ready

```
<cue>/init-check
```

**If the `blocked` line carries a reason, stop there and point at
`/cue-dev:init`.**

Starting in an unprepared repository surfaces the problem not during the work
but **after it is done**. Branching in a repository with no commits creates no
base branch, and you find out the moment you try to open a PR. Without a scratch
ignore rule, a `.gitignore` commit nobody planned slips into the implementation.

> "The repository is not ready yet: <reason>. Run `/cue-dev:init` first."

If `blocked` is `none`, continue. `config` being `absent` is fine — without
settings it runs on the defaults. But if the `gitignore` line says `no rule`,
say so and recommend `/cue-dev:init`.

### 1. Secure the requirement

Do not interpret or expand the requirement. **Only normalize it.** Design is
`cue-dev:design`'s job.

- **If a ticket/issue tool is connected and you were given a KEY**, look it up
  with that KEY.
- **Otherwise ask the user** — pasted text or a spoken description, either works.

> "Tell me the requirement for this work. You can paste the ticket body or just
> describe it."

Take the requirement even if it is a single sentence. Do not dig here when it
feels thin — probing what to build belongs to `cue-dev:design`.

### 2. Decide the KEY

**If you got a KEY as an argument, use it. Skip step 2.**

If not, build `YYYYMMDD-<slug>` from the requirement title and **propose it,
then get confirmation.** The date is today, written without separators so the one
hyphen in the KEY is the boundary between date and slug; the slug is two or three
lowercase English words. Never localize the date — the KEY lands in directory
names, branch names and commit markers, where sorting lexically is sorting by
time.

**Ask with `AskUserQuestion`, and give it two options.** The tool requires at
least two and rejects a one-option question outright — see the box below. Propose
the KEY you built, and offer a second one that is genuinely different: a shorter
slug, or the ticket ID if there is one.

> **Use `20260731-session-ttl`?** — Records accumulate under
> `.cue/dev/20260731-session-ttl/`, and the name goes into every commit marker
> for this work.
> **`20260731-ttl`** — the same thing, shorter. Slugs turn up in branch names and
> directory listings for the life of the work.

**`AskUserQuestion` needs two options or it does not run.** This skill used to say
one was enough, on the reasoning that the interface adds its own "type something
else" and a second entry would be that entry printed twice. The reasoning is fine
and the premise was wrong: the interface adds that entry *after* the call is
validated, and validation requires two. In a real session this question and the
one in 4a both came back `Invalid tool parameters`, twice in a row, and the user
was left watching a tool fail at the two moments the skill had identified as the
ones that must not be answered on their behalf.

So: **two real options, everywhere in this skill.** If you cannot think of a
second one worth offering, that is a sign the question is thinner than it looked,
not a licence to send one.

**This was prose until a session answered it for the user.** The argument for
prose was that one proposal plus one typed value makes a menu whose only entry
sits beside the interface's own "Other" — the same choice printed twice. The
logic is fine; the premise was not. **A prose question does not end the turn.**
Nothing stops the same turn continuing, continuing needs an answer, and so an
answer gets supplied: a real session wrote *"User says yes, so I'll proceed with
creating the worktree:"* and cut the branch, having been told nothing. The value
of the tool here is not the menu, it is that the harness stops and waits.

**The line is reversibility.** Everything from here to 4c names something that
outlives the answer: a directory, a branch, the commit markers, the branch this
work will merge back into. Those get the tool. A value that can be changed later
with one command — the marker prefix in `/cue-dev:init`, say — stays prose, and
that is not an inconsistency between the two skills but the same rule applied to
different stakes.

If the user gives you a ticket key, use that. cue-dev does not validate the KEY
format.

### 3. Check for a conflict

Run `<cue>/work-init --check <KEY>`. `--check` only
judges; it creates nothing.

**On exit 1 (already exists), stop there.** Do not overwrite existing work. Only
rewinding through `cue-dev:redo`, as the script instructs, leaves a backup
branch. Tell the user the situation and let them decide.

> "Work for `<KEY>` already exists. To continue it, check the current state with
> `/cue-dev:status`; to start over, rewind with `/cue-dev:redo demand <KEY>`."

### 4. Create the workspace

**REQUIRED SUB-SKILL:** use `cue-dev:using-git-worktrees`.

```bash
<cue>/config --get remote
```

#### How to ask the three questions in this step

4a, 4b and 4d each end in an `AskUserQuestion`, and they share one rule. **It is
cue-dev's rule for every menu it asks, not just these three** — `/cue-dev:init`
and `/cue-dev:finish` point back here for the reasoning.

**Put the option you would pick first, and do not mark it as recommended.**
Position is the recommendation. `AskUserQuestion`'s own instructions say to append
"(Recommended)" to the label, and a real session did — on the start point and on
the branch name, the two answers this plugin explicitly has no opinion about. The
label is the wrong place for it in either direction: cue-dev requires nothing of
a branch name, so a badge there reads as "cue-dev wants this", and the user is
left thinking their team's convention is the tool's business. It is not, and that
independence is the point of 4a and 4b existing as questions at all.

**Put the reason in the description instead, as a fact about this repository.**
"the other branches here use `feat/`" is checkable and the user can overrule it
without arguing with the tool. "(Recommended)" is an assertion with nothing under
it.

One rule for all three, because three rules with exceptions is what gets
half-applied.

**And no exception where cue-dev genuinely does have an opinion.** That reading is
available — the badge's worst damage is on a question the plugin has no stake in —
and it is the wrong one, for two reasons. The tool's own description pushes the
other way on every call, so a rule that first asks "does cue-dev have a view here?"
is a rule to be re-decided each time, which is how it drifts. And where the plugin
does have a view it also has a *reason*, which belongs in the description where the
user can weigh it: "reviewers see demand·design·plan·outcome in every PR" is
something they can disagree with, and "(recommended)" is not. Two questions
elsewhere in the plugin carried the badge under exactly this reasoning, one of them
in a skill that told itself twice on the same page to recommend nothing.

#### 4a. Settle the start point — this item's, not the repository's

**The branch this work is cut from is a decision made here, per item, and it is
not a setting.** A git-flow hotfix comes off `main` while the feature before it
came off `develop`; when this lived in the config, expressing the second item
meant rewriting a value the first one still depended on, and forgetting to put it
back cut the next item from the wrong branch — invisibly, until the merge.

Settle it in this order.

1. **If the requirement names a branch, use that.** You have the requirement from
   step 1. A ticket that says "branch from `release/4.2`" has answered this, and
   proposing something else over the top of it is not a judgment call.
2. **Otherwise propose one from what the repository has.** `init-check`'s
   `start_points` line lists the candidates it found.
3. **Either way, say which one and why, and get the answer — with
   `AskUserQuestion`.** Offer the candidates `init-check` found as options, the
   one you would pick first and unlabelled (see the rule above), and let the
   interface carry anything else.

> **Cut from `develop`?** — It is what the repository's other work branches off,
> and the ticket does not say. This is also where the work merges back at finish.
> **Cut from `main`** — the release line; right for a hotfix.

**When `init-check` found only one candidate, you still need two options.** The
tool refuses a one-option question (step 2), and a repository whose
`start_points` line lists `main` alone is the ordinary case, not the rare one —
that is exactly where this failed in a real session. The second option is the
current branch when it differs from the candidate, and otherwise it is *this*:

> **Cut from `main`?** — the only start point this repository has, and where the
> work merges back at finish.
> **Somewhere else** — name a branch or a tag; it does not have to exist locally.

**Say in the description that this decides the merge target too.** It is the one
consequence users do not expect from a question phrased as "where does it start",
and by the time it shows up, finish is merging.

**Do not skip the question because there is only one candidate.** One candidate
makes it easy to answer, not unnecessary — and this is the last moment the answer
is free.

**Resolve it and hold on to the line, both:**

```bash
<cue>/work-base --line <the branch they settled on>
```

It prints the exact header line step 6 writes into demand.md, with the branch
resolved to a ref that exists (`develop`, or `origin/develop` when the branch
lives only on the remote) and the commit it is at:

```
<!-- base: develop @ 4f311b5 -->
```

**Run it now, before the fetch, and again after** — the fetch can move the
branch, and the SHA that goes into the record must be the one you actually
branched from. **Do not compose that line by hand.** Everything downstream —
`finish`'s landing check — parses it, and a
hand-assembled one fails silently: the file is written, the commit succeeds, and
only that item's start point becomes unreadable.

**If it refuses**, the branch does not exist locally or on any remote. That is
worth offering to fix rather than falling back to something they did not ask for:

> "`release/4.2` isn't here. Shall I create it from `main`, or did you mean
> another branch?"

#### 4b. Name the branch — the team's convention, not cue-dev's

**cue-dev requires nothing of this name.** Not a prefix, not the KEY, nothing. The
name is recorded in step 6 and read back from there, so `feat/add-hello-world-test`
and `PROJ-142` and `cue-dev/<KEY>` all work identically.

There used to be a `branch_prefix` setting. It is gone for the reason 4a's value
left the config one release earlier: git flow calls a feature branch `feature/`
and a hotfix `hotfix/`, so one repository-wide value cannot describe the second
item without being rewritten under the first.

Propose in the same shape as 4a: **the ticket first, then what the repository
already does, then confirm — with `AskUserQuestion`.** `init-check`'s
`branch_style` line lists the prefixes this repository's branches actually use.

> **Call it `feat/add-hello-world-test`?** — The other branches here use `feat/`.
> cue-dev requires nothing of the name; it records whatever gets made.

**When `branch_style` says there are no prefixed branches yet, say that.** The
line reads `no prefixed branches yet (start proposes a name to confirm)`, and it
is an answer, not a blank to fill in. Propose whatever name you like — a
descriptive one is fine — but the description says where it came from, and where
it came from is you:

> **Call it `feat/react-migration`?** — This repository has no branch naming
> convention yet, so this is only a suggestion. cue-dev requires nothing of the
> name; it records whatever gets made.

**Do not describe your suggestion as the repository's convention.** A real session
read `no prefixed branches yet` two minutes earlier, proposed `feat/`, and wrote
"the convention used in this repository" into the description — inventing a fact
about the user's repository, in the one field they were reading in order to
decide. The repository had one branch, `main`. This is the same failure as a
manufactured rejected alternative in a design: a choice presented as settled by
evidence that does not exist.

**This is the question where a "(Recommended)" badge does the most damage**, and
it is where a real session put one. The paragraph above says cue-dev requires
nothing of this name; a badge on the option says the opposite, in the interface,
where it is read. The description already carries the reason — the repository's
own prefixes — and that is a fact the user can weigh. See the rule at the top of
step 4.

**This is the last of the three the tool answers, and the one the failure landed
on.** The branch is cut in 4c, immediately after. A prose question here leaves the
same turn free to run `git worktree add`, and that is precisely what happened.

#### 4c. Cut the workspace

**Fetch first, whenever the start point is on a remote** (the resolved ref
contains a `/`) or a `remote` is configured.

```bash
git fetch <remote>
```

Every workflow assumes work starts from an up-to-date base; skipping this means
the first sign of divergence is a conflict at `/cue-dev:finish`, with the
implementation already done. It is also why 4a says to run `work-base --line`
again after the fetch: the fetch can move the branch, and the SHA that goes into
the record must be the one you actually branched from.

**Then ask for the path; do not choose one.**

```bash
<cue>/work-path --propose <KEY>
```

It prints `<repo-root>/.worktrees/<KEY>` and creates nothing. A real session
invented `.cue/worktrees/<KEY>` instead — a location this plugin names nowhere —
and that single invented path is what left the worktree unownable at finish time,
because every rule about who removes it was written against paths it did not
match. There is nothing to decide here, so decide nothing.

**Then branch from the start point explicitly — never from wherever HEAD happens
to be.** Pass it as the third argument:

```bash
git worktree add <the proposed path> -b <the branch name from 4b> <the resolved ref from 4a>
```

Leave it off and git branches from the current checkout. If the user was standing
on an unrelated feature branch, that branch's commits are now inside this work and
nothing says so until the merge. **This is the single most important line in this
step.**

**Do not call a harness worktree tool afterwards.** cue-dev cuts its worktrees
with git and works in them with `git -C <path>`; nothing needs the session's
working directory to move. Handing the worktree to `EnterWorktree` buys one thing
— that move — and costs the harness's own rule that a worktree entered by path is
one it will keep rather than remove, which put cleanup back on cue-dev anyway.

**So every command from here names the path.** `git -C <path> …`, and absolute
paths for files. A forgotten `-C` edits the main checkout instead, and the shell's
working directory resets between calls, so there is no "cd once and forget it".
`<cue>/work-path <KEY>` answers with the path whenever you need it again.

You may fail to create a worktree, or the user may decline and proceed in the
original checkout. That is fine — but **the fact must be visible.** Step 5 makes
that judgment, so you do not need to remember it.

#### 4d. Settle how strongly this item gets checked

**The last question, and the only one about the work rather than the workspace.**

```
<cue>/work-check --line <independent-review|self-review>
```

**Ask with `AskUserQuestion`** — two options, the one you would pick first and
unlabelled (the rule at the top of step 4). You have the requirement from step 1,
so order them from it: how much of the system it touches, whether it is
reversible, whether getting it subtly wrong would be noticed.

**The two `label`s are the literal tokens `independent-review` and
`self-review`.** They are values: the answer comes back to you as the label
string, you pass it to `<cue>/work-check --line`, and it is written into
demand.md's header for `/cue-dev:implement` and `scripts/verify` to read. Nothing
else in the menu is a value, and everything else is written in the repository's
language.

**Each `description` carries these four facts, in the repository's language.**
They are the whole content of the choice; if one is missing from what you wrote,
the option is wrong:

```
independent-review    how many agents:  two subagents
                      who reads the diff:  an agent that did not write it
                      cost:  slower
                      fits:  shared state, data, behaviour other code depends on

self-review           how many agents:  this session, one agent, no subagent
                      who reads the diff:  the agent that wrote it
                      cost:  faster
                      fits:  small, visible, easily reversed
```

**The first fact has to name agents, in whatever words the language uses for
them** — "two subagents" against "one agent, this session, no subagent". That is
the difference the user is actually buying, and it is the one that keeps getting
paraphrased away.

**Describe the mechanism, not the mood.** The one thing that differs between the
two answers is whether the diff is read by a context that did not write it. "More
thorough verification" and "for simple changes" name a *feeling* about the levels
and leave the user guessing at what will actually happen; a real session offered
exactly that pair and the difference it was asking about — isolation — never
appeared in the question.

**Translate the values, keep the fields.** A session that was told to write these
as free sentences produced one option saying only "simple, intuitive change" — the
mood again — and one that was not a grammatical sentence in the language it was
asking in. The four field names are the guard against that: an empty one is
visible before the question is sent, and a paraphrase has nowhere to hide.

**And say what the answer does, because it decides a method and not just a
threshold.** `/cue-dev:implement` reads this value and dispatches subagents or
does not. It is not a bar the work has to clear afterwards; it is the plan.

**In 0.1, `self-review` is the exercised path and `independent-review` is not.**
Every real run of cue-dev so far went through `self-review`; the dispatch loop has
never completed a full item end to end. Both remain on the menu — the choice is
the user's and the reasons above are unchanged — but **when the requirement does
not clearly ask for isolation, order `self-review` first**, and if the user picks
`independent-review` say once, in one sentence, that it is the newer path. Do not
label it, do not argue with the answer, and do not raise it again: `/cue-dev:redo`
is how a wrong choice here gets corrected, and it costs one stage.

**This used to be `min_check` in `.cue/dev/config`, and it is asked here now for
two reasons.**

One value could not serve two items. The colour change and the migration wanted
different answers, and because worktrees each carry their own copy of the config,
changing it for one either missed the session beside it or — at merge — reached
every session at once, retroactively, with nobody having been asked.

And a floor answered the wrong question. It said what may not happen and never
what should, so `implement` had nothing to read and decided per run, from the
shape of the plan, whether to dispatch anything. Two runs of one item took
different paths. Asked here, it is settled by the person who knows how risky the
item is, at the moment they are already thinking about it.

**A repository that still has a `min_check` line keeps being honoured** for items
that predate this question — but ask anyway, every time. The old value is a
fallback for records already written, not an answer to give on the user's behalf.

### 5. Create the work directory

**With the worktree as the working directory**, run `work-init`. This time
without `--check` — it actually creates.

```bash
(cd <path> && <cue>/work-init <KEY>)
```

It creates `.cue/dev/<KEY>/` in the checkout it is run from, and reports the
isolation it can see from there. Run it in the main checkout by mistake and the
records land in the wrong tree — which is the same `-C` class of error 4c warns
about, in the one command where `-C` does not apply.

The output is three lines, or four.

```
<created path>
isolation  worktree (<path>)     or     isolation  none — main checkout (<path>)
branch  <actual branch name>                    ← what git reports, whatever it is
branch  (none)  · detached HEAD — a branch must exist before finish
workspace  shared checkout, N worktree(s) alongside — …   ← only when it applies
```

**The branch name is reported, not judged.** There is no verdict to read here any
more: nothing is required of the name, so a bare line is the whole answer. Do not
add a reassurance of your own ("this differs from the usual prefix but still
works") — that sentence was printed on every run until it stopped being read.

**Carry the lines below the path verbatim into step 8.** The script prints in
English — relay it to the user in the configured language, but do not change what
it says. Do not judge isolation or the branch name yourself, and do not reword it
into prose. What git answered and what you remember are different things — in a
real session no worktree was created, nobody mentioned it, and the silence read as
"we must be isolated."

**A `workspace` line means another worktree exists and this item is not in one.**
Two sessions editing one checkout share a HEAD and an index, and `/cue-dev:redo`
there rewinds whatever else is in that directory. Relay the line and say the
worktree is worth making; do not stop for it.

### 6. Write demand.md

**Get the branch and worktree lines first, with the workspace as the working
directory:**

```bash
(cd <path> && <cue>/work-branch --line && <cue>/work-path --line)
```

Both take no argument on purpose — they ask git what is true where they are run
and print that. Run them **after** the workspace exists, so what gets recorded is
what was made rather than what was requested.

**`git -C` is not enough for these.** It redirects git, not the script's own
working directory, and these two read the checkout they are standing in. A
subshell (`cd … && …`) is the form to use, because the shell's directory resets
between calls anyway.

```
<!-- branch: feat/add-hello-world-test -->
<!-- worktree: /home/you/repo/.worktrees/20260806-add-test-output -->
```

**`work-path --line` refuses in the main checkout, and that refusal is correct.**
An item built in place has no worktree; recording one would hand finish-cleanup a
directory to remove that nobody made. Leave the line out and write the rest.

Write `.cue/dev/<KEY>/demand.md` in this format.

```markdown
<!-- cue-dev · written <YYYY-MM-DD> · source: MCP(<tool>) | paste | conversation -->
<!-- origin: <ticket ID — only when a ticket is used> -->
<the whole line scripts/work-base --line printed in step 4a, verbatim>
<the whole line scripts/work-branch --line printed just now, verbatim>
<the whole line scripts/work-path --line printed just now, verbatim — omit when it refused>
<the whole line scripts/work-check --line printed in step 4d, verbatim>
<!-- This document is a requirement snapshot. If the origin changes, use /cue-dev:redo demand. -->

# <KEY> — <title>

## Requirement
<body. Close to the original. No interpretation or expansion. From a paste or a
ticket, this is the text itself; from a conversation, it is what they asked for
stated once, cleanly — not the transcript.>

## Acceptance criteria
<verbatim if present. Otherwise "not specified".>

## Meta
<labels, priority, links if present. Omit otherwise.>
```

**"Close to the original" is not "paste the transcript".** The `source:` line in
the header says which of the two this is, and the answer changes what the body
looks like:

| source | what goes under `## Requirement` |
|---|---|
| `MCP(<tool>)` · `paste` | the ticket body as it stands — someone else wrote it, and it is quoted |
| `conversation` | what they asked for, stated once and in order, in their own words wherever they used them |

A spoken requirement arrives with false starts, a correction two sentences later
and a question you answered in between. Filing all of that is not fidelity, it is
a transcript — and the next stage reads this document as *the* requirement. Write
the settled version.

**What is forbidden is deciding anything they did not.** No scope you inferred, no
acceptance criterion you invented, no solution — those are `cue-dev:design`'s, and
design is where the requirement gets developed through the back-and-forth you are
thinking of. If that conversation shows the requirement itself was wrong, the
answer is `/cue-dev:redo demand`, which rewrites this document deliberately and
leaves a backup. It is not something to fix by editing demand.md quietly
afterwards: the whole value of a requirement snapshot is that it says what was
asked for *before* anyone knew how hard it would be.

**Write the requirement in the language it arrived in, and never translate it.**
Not into English, not into the configured record language, and above all **never
both** — a requirement followed by its own translation in parentheses is the same
sentence stored twice, and from then on nobody knows which one the work is
answering. The template's headings are English because they are anchors; the body
under them is a quotation. If the surrounding prose you write (the title, a note)
is in another language, that is fine — the quotation still does not move.

**Always record the source in the header.** Six months from now, whether this
document came from a ticket or from a conversation is what decides how much to
trust it.

**The `base:` and `branch:` lines go in the header, never in the body.** The body
is a quotation of the requirement, and neither fact is part of what was asked
for — both are facts about how this item was cut, like `written` and `source`
beside them. Putting one in the body also puts it where nothing looks: the readers
parse the header and stop at the first line that is not a comment. That cut is
deliberate — a `<!-- base: … -->` inside a pasted ticket must never be mistaken
for the record, or the text of a ticket decides where the work merges.

**Nothing else records either one.** `finish` reads `base:` to decide where the
work lands; `status`, `redo`, `backups`
and `gate` read `branch:` to find this item at all. There is no repository-wide
default behind them to catch a miss. Leave `base:` out and `finish` stops and
asks — which is the good outcome, and only because there is nothing for it to
guess with. Leave `branch:` out and the item is found by the old rule instead
(the KEY appearing somewhere in the branch name), which is exactly the coupling
recording it removes.

**`check:` follows the same rule and has one extra consequence.** `implement`
reads it to decide whether to dispatch subagents at all, and `verify` reads it to
judge what `checked-by` ended up saying. Leave it out and both fall back to a
`min_check` line in the config if the repository still has one, or to
`independent-review` if it does not — which is safe, and is not what anyone
answered. Write the line `work-check --line` printed.

**Do not invent acceptance criteria when there are none.** "Not specified" is the
accurate record.

### 7. Commit

```bash
git add .cue/dev/<KEY>/demand.md
git commit -m "$(<cue>/marker demand <KEY>)"
```

**Do not write the marker string by hand.** The prefix can differ per repository
(`.cue/dev/config`). `scripts/marker` reads the settings and emits the finished
subject. Assemble it yourself and it drifts in any repository that changed the
setting, and **a drifted marker fails silently** — the commit succeeds and only
that stage becomes invisible forever.

**It also runs `verify` and prints nothing if it fails**, so git aborts on the
empty subject and no demand commit is made. If it refuses, its stderr carries
verify's errors — usually a missing `## Requirement` or `## Acceptance criteria`;
fix those and run the same command again. **A record that reaches this point
clean makes it silent.**

### 8. Point at the next stage

```bash
<cue>/notice "START done" <<'EOF'
  key       <KEY>
  artifact  .cue/dev/<KEY>/demand.md
  commit    <the commit subject actually written>
  isolation <the isolation line work-init printed in step 5>
  branch    <the branch line work-init printed in step 5>
  base      <the ref and SHA from the base: line, as work-base printed them>
  check     <the level settled in 4d — implement reads this, it is not a threshold>

  next      /cue-dev:design
  rewind    /cue-dev:redo demand
EOF
```

**Reproduce its output verbatim in your reply, in a fenced code block, and put it
last.** Anything you need to say goes *above* it — a decision you need from the
user, a warning, the answer to what they actually asked. **Nothing goes under it,
and nothing restates its labels** — the box already says what `artifact`,
`commit` and `base` mean, and a paraphrase is the same information at twice the
length.

**Stop here.** Do not call `cue-dev:design` automatically. A human checkpoint
between stages is cue-dev's design.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll add an English translation so everyone can read it" | Then the file holds the requirement twice and the two start to drift. A snapshot has one original. Whoever needs it in another language can translate it then, against a source that never changed. |
| "The requirement is thin, let me fill it in" | demand.md is a snapshot. What you filled in is your guess, not the requirement, and six months later the two are indistinguishable. Record it thin and dig in design. |
| "Any KEY will do" | The KEY names the record directory and every commit marker for this work. Get the user's confirmation. |
| "Work already exists but I can just continue it" | Overwriting loses the previous demand.md with no backup. Only going through redo leaves a backup branch. |
| "`git worktree add -b <name> <path>` is enough" | Without a start point it branches from whatever is checked out. Someone else's feature commits end up inside this work, and the first sign of it is the merge at finish. Pass the base ref. |
| "Fetching is slow and the base is probably current" | "Probably" is the whole problem. A stale base turns into a conflict after the implementation is done, which is the most expensive moment to find it. |
| "The repository has one obvious branch, so the start point needs no asking" | One candidate makes the question easy, not redundant. This is the last moment the answer costs nothing; after the branch is cut it costs a rewind. |
| "There's a `base_branch` in the config — that settles it" | Nothing reads it. It is not a setting any more, and using it would be applying the last ticket's answer to this one. |
| "There's a `min_check` in the config, so 4d is answered" | It is honoured for items recorded before the question existed, and that is all it is for. This item is being recorded now. Ask. |
| "One option is enough — the interface adds Other" | It adds it after validating the call, and validation requires two. This exact belief produced `Invalid tool parameters` at two of this skill's three questions in a real session. |
| "The change is small, so `self-review` obviously" | Put it first, then let them answer. Size is what you can see; blast radius is what they can. |
| "Marking my pick '(Recommended)' is just being helpful" | On the branch name and the start point it is a claim cue-dev does not make — those are the team's, and the badge says otherwise in the one place the user reads. Order carries it; the description carries why. |
| "I know the branch and the SHA — I'll just write the `base:` line" | `finish` parses that line. A hand-assembled one fails silently: the file is written, the commit succeeds, and only this item's start point becomes unreadable. Use `<cue>/work-base --line`. |
| "The `base:` line is bookkeeping — the branch is what matters" | The branch does not say what it was cut from once the base has moved on. That line is the only record of it, and finish decides the landing branch from it. |
| "The branch should carry the KEY so the work can be found" | It is found by the `branch:` line in demand.md. Requiring the KEY in the name was how it used to be found, and it made a team's branch convention cue-dev's business. Name it whatever the team names branches. |
| "There's a `branch_prefix` in the config — that settles the name" | Nothing reads it. It is not a setting any more, for the same reason `base_branch` stopped being one: the second item needs a different value and rewriting it breaks the first. |
| "The native worktree tool is the recommended path, so use it to create the branch" | It takes no start point — it branches from `origin/<default>` or local HEAD by user setting, not from 4a's answer. Cut it with `git worktree add` and work in it by path; do not hand it to the tool afterwards either (4c says why, and `cue-dev:using-git-worktrees` 1a has the full accounting). |
| "The worktree can wait" | demand.md ends up in the original checkout and missing from the worktree. The commit marker lands on the wrong branch too. |
| "Jumping straight to design is faster" | The user loses the chance to look at demand.md and confirm "yes, that's it." A design built on a wrong requirement is the most expensive one. |
