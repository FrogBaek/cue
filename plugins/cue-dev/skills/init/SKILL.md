---
name: init
description: Use when setting up cue-dev in a repository for the first time, or when changing the conventions it already uses - the commit marker prefix, record language, or remote name. Also use when /cue-dev:start reports the repository is not initialized. Safe to run again on an initialized repository.
argument-hint: (none)
---

# Preparing a repository

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


cue-dev leaves traces in the user's repository — commit markers, branch names, the
`.cue/dev/` directory. Those conventions must not be decided without asking. This
is where the asking happens.

**Announce when you start:** "Preparing the repository with the cue-dev:init
skill."

This skill is **idempotent**. Run it again in an already-prepared repository and
it shows the current settings and asks whether to change them. There is no
separate path for editing settings — this is that path.

## Sequence

### 1. Determine the state

```
<cue>/init-check
```

**Do not guess.** This script determines, in one shot: whether it is a repository,
the commit count, start point candidates, remotes, gitignore, settings, and
whether markers exist. Read its output as is and continue below.

**If the `blocked` line carries a reason, stop there.**

The most common case is a repository with no commits. Branch in that state and you
get an unborn branch; the first commit lands on it and **no base branch is ever
created**. You then discover, after all the work is done, that there is nowhere to
open a PR.

> "This repository has no commits. cue-dev needs a base branch to open a PR later.
> Please make an initial commit first — a README is enough."

### 2. If it is already prepared, show the current settings

If the `config` line says `present`, initialization is done. Show the current
values and ask.

```
<cue>/config
```

> "This repository is already prepared. The current conventions are above. Is
> there anything you want to change?"

If there is nothing to change, you are done here. If there is, go to step 5.

### 3. Ask about the conventions

<HARD-GATE>
**One question per message, and wait for the answer before asking the next.**
This skill asks four things at most, and every one of them is answered by the
user, in a separate turn, before you move on:

| where | question | asked |
|---|---|---|
| 3a | the record language | always |
| 3b | the commit marker prefix | always |
| 4 | which remote work is pushed to | only when there is more than one |
| 6 | whether `.cue/dev/<KEY>/` records are committed | always |

**Step 6 is one of them.** The count here used to read "two questions in steps 3
and 4", and the sentence below the gate still says "ask about two things only" —
both were written about the *conventions* that land in `.cue/dev/config`, and both
read as a count of this skill's questions. Step 6 asks a fourth with
`AskUserQuestion` and writes `.gitignore`, which is as much the user's shared
space as the marker prefix is.

**The start point, the branch name and the check level are not among them.** All
three belong to the work item, and `/cue-dev:start` asks for them there — the check
level most recently, and 3c says why. The branch prefix used to be
asked here and is gone: git flow names a feature branch `feature/` and a hotfix
`hotfix/`, so one repository-wide value could not describe the second work item
without being rewritten under the first.

**A default is a proposal, never a decision you may take on their behalf.** Not
when the answer looks obvious, not when the repository has one obvious candidate,
not when a question failed to render, and not when you have already asked two
things and it feels like a lot of asking. If a question does not reach the user,
ask it again — announcing "I'll use the defaults" is the failure this whole skill
exists to prevent, and it has happened in a real session for the marker prefix,
the branch prefix and the start point at once (two of which are no longer asked
here at all, which is a smaller surface, not a solved problem).

**Never state a setting in the indicative.** "The marker prefix is `cue-dev`" is
not a question, and a user reading it has nothing to answer. Propose, then stop
and wait.

**Where a question has real, enumerable answers, ask it with the
`AskUserQuestion` tool, not in prose.** That is the language, the remote, and
whether records get committed — three of the questions below say so at the point
they are asked. A tool call cannot be answered by
silence: there is no way for the conversation to move on with the value
undecided, which is exactly the failure the gate above is written against, and
prose questions kept producing it anyway. Prose remains right for the marker
prefix and only for it, for the reason given in 3b.
</HARD-GATE>

**Two settings go in the config, and no more.** The rest of `.cue/dev/`'s layout
is cue-dev's, not the user's to decide. (This is a count of settings, not of the
skill's questions — the table in the gate above has those.)

There are two criteria for asking, and a value must pass both. **Does it stay in
the user's shared space?** The git history and the branch list are used by the
whole team and already have their own conventions; `language` is the same, because
config is committed and this value decides the record language for everyone. **And
is one answer right for the whole repository?** That is the criterion that retired
the check level (see 3c), and the start point before it: a value that differs per
work item cannot live in a file every work item shares, least of all one that
parallel worktrees each hold their own copy of.

| What to ask | Default | Result |
|---|---|---|
| record language | `en` | which language the prose in `.cue/dev/` is written in |
| commit marker prefix | `cue-dev` | `cue-dev(demand): <KEY>` |

**`integration` is not asked either, and for the opposite reason: it is
observed.** `<cue>/integration` reads the remote and reports how a change request
gets opened here — `github` when there is a GitHub remote *and* `gh` is installed,
`git` when there is some other remote, `none` when there is none. Asking would put
a question in front of the user whose answer is already visible.

Write it only when observation is wrong, which happens in one shape: a repository
whose requests go somewhere other than the remote it pushes to — a GitHub mirror
of a Gerrit project, a team that takes patches by mail. `config --set integration
none` says so, and finish stops offering to propose the work.

**`backup_prefix` is not asked**, though it is a setting. cue-dev creates those
branches itself and finds them again by globbing the value, so changing it orphans
every backup already made — there is nothing for the user to gain by answering and
a recovery path to lose. It is reported by `init-check` and settable with
`config --set backup_prefix` for a repository that genuinely needs the namespace
moved.

**Ask about the language first, and switch to it before asking anything else.**
Everything after this — the questions below, the remote question, the notice at
the end — is prose you are writing to this user. Ask it last and you
have conducted the whole of setup in a language they did not choose, which is
exactly how this ordering came to be written down.

#### 3a. The record language

**Ask this with `AskUserQuestion`.** Two options: **`en` (default) and `ko`.** Any
other language is a two-letter code the user types — do not add a "type something
else" entry of your own, the interface already offers one, and two of them side
by side read as two different things.

> The records under `.cue/dev/` and everything I say — which language? `en` is the
> default; `ko` is the other one set up out of the box. Any other two-letter code
> works too (`ja`, `zh`, `fr`).

**Apply it the moment it is answered** — run `--set language <value>` from step 5
straight away, and from your very next sentence write in that language. Do not
wait for the end of this skill, and do not tell the user to restart. The
SessionStart hook that normally carries this value already ran, so for the rest of
*this* session you are the only thing carrying it.

**Know exactly what `language` changes and what it does not.** Explain it wrong
and the user expects script output to be translated too.

| What changes | What does not |
|---|---|
| what I say to the user | the output of cue-dev's scripts (**always English**) |
| the prose in `.cue/dev/<KEY>/*.md` | commit markers · `outcome.md` status tokens |
| reports from the subagents implement dispatches | section headings in the record templates |
| | file paths · code · identifiers |

There is no "decide later" value. Every skill body, template and script line in
cue-dev is English, so an undecided setting does not leave the choice open — it
hands it to the English text on the page. `en` is a default, not a detection: it
is not guessed from the shell locale (`$LANG` is empty on Windows Git Bash, so the
guess is simply wrong).

#### 3b. The marker prefix

**Ask this in prose. Do not use `AskUserQuestion` here.** There is only ever one
proposal and one alternative — "the default, or a value you type" — and rendering
that as a menu produces a "type a different value" entry beside the interface's
own "type something", which is the same choice printed twice. Show the resulting
shape in one line and ask only whether they want a different value.

**`cue-dev:start` makes the opposite call on a question of the same shape, and
the difference is reversibility.** A prose question does not end the turn, so a
run can carry on and supply its own answer — which is survivable for a value that
`/cue-dev:init` can change again tomorrow (`marker_prefix_history` exists so that
it can), and not survivable for a branch that has already been cut. Stakes decide
this, not shape.

> I'll use `cue-dev` as the commit marker prefix — commit subjects will look like
> `cue-dev(demand): PROJ-142`. `/cue-dev:status` and `/cue-dev:redo` determine the
> stage from this string. Would you like a different value?

**Do not accept a typed value without validation.** Pass the value straight to the
script and let it judge — if it passes, it is applied; if not, you get a reason.
cue-dev checks only the *syntax* of a value and never forces a list, so anything
inside the bounds below works.

| Key | Allowed | Not allowed |
|---|---|---|
| `marker_prefix` | any string without spaces, parentheses, or colons (`cue`, `spec`, `ai-dev`, `teamA`) | empty, `(`, `)`, `:`, spaces — they break the marker syntax |

**An empty value means "the default", not "no prefix".** Leaving `marker_prefix=`
empty in the settings file reads as `cue-dev` — an empty value is not
distinguished from an unset one. If you are asked to genuinely remove the prefix,
say that it cannot be done.

**If `init-check`'s `markers` line says `present`, always say so.** Changing the
prefix records the old one in `marker_prefix_history`, so earlier work stays
findable — nothing is lost, but from then on the history mixes two conventions.

#### 3c. The check level is not asked here — it is asked per work item

**There is no third question in this step.** `min_check` used to be here, a
repository-wide floor on how strongly implementation work is checked, and it moved
to `/cue-dev:start`, which asks it about the item in front of it and records the
answer in that item's `demand.md` header.

**Say so if the user asks where it went**, because the reasons are theirs to know:

- **One value could not serve two items.** A colour change wants `self-review`;
  the migration in the worktree beside it wants `independent-review`. Setting it
  for one either missed the session next door or, once that branch merged, changed
  it for everyone retroactively — nobody having been asked.
- **A floor answered the wrong question.** It said what may not happen and never
  what should, so `/cue-dev:implement` had nothing to read and decided per run,
  from the shape of the plan, whether to dispatch a reviewer at all. Per item, it
  is a method someone chose, not a bar the work discovers afterwards.

**A repository that already has a `min_check` line keeps it, and it keeps
working** — for items recorded before the question moved. Do not offer to remove
it and do not offer to change it: `scripts/config` refuses `--set min_check` and
says where the question went. `/cue-dev:start` asks every new item regardless.

### 4. Settle the remote

**Do not ask which branch work starts from. That is not a setting.** The branch
work is cut from belongs to the work item, not to the repository — in git flow a
hotfix comes off `main` while the feature before it came off `develop` — so
`/cue-dev:start` settles it per item and records it in that item's demand.md.
Answering it here would mean the second item had to overwrite the first item's
answer to express itself, which is how it worked and why it stopped.

`init-check`'s `start_points` line is there for `start` to propose from, not for
you to fix. **Say nothing about it here.**

**There is one question in this step,** and only when the repository has more than
one remote:

- **If there is no remote, leave it.** A local-only repository is normal, and
  `/cue-dev:finish` offers other options instead of a PR when the time comes.
- **If there is exactly one, use it.**
- **If there are several, ask which one work is pushed to.** `remote` is the push
  target and nothing else. In a fork it is your own fork — usually `origin` —
  while the original repository is named by the item's start point, as
  `upstream/main`. That pairing is the whole of fork support; there is no third
  setting to look for, and because the start point is now per item, a fork
  contribution and an internal branch can live in the same checkout.

**Ask this with `AskUserQuestion`:** the remotes are real, distinct, and
enumerable. Offer them and nothing else — no "type a different one" entry of your
own, the interface already provides one.

### 5. Write the settings

```
<cue>/config --set language <value>
<cue>/config --set remote <value>
```

**The file this writes is the main checkout's `.cue/dev/config`,** whichever
checkout you run from. Everything in it is a repository-wide convention, and a
worktree's own copy made each parallel item a private version of one.

`remote` and `language` are values no history depends on, so run these as soon as
they are answered. Run `--set language` the moment step 3a is
answered rather than saving it for here — and if the answer was `en`, run it
anyway. Writing the default down costs one line and makes the choice visible to
the next person; only `marker_prefix` is skippable at its default.

**One change needs the user to agree first:** `marker_prefix`, because it changes
how the whole history is read. `backup_prefix` needs consent too, but init never
sets it.

For those, the sequence is **preview → ask → apply**:

```bash
# 1. Preview. Changes nothing, exits 0, prints exactly what would change.
<cue>/config --set marker_prefix <value> --dry-run

# 2. Show that output and ask with AskUserQuestion: apply it, or leave it.

# 3. Only once they have said yes:
<cue>/config --set marker_prefix <value> --yes
```

**Never hand the command to the user to type.** Telling someone to run
`! scripts/config … --yes` themselves is how this step used to end, and it is
wrong twice over: it makes the user the executor of a tool that exists to spare
them that, and it left the conversation sitting on a preview that had failed —
the old preview reached the consent prompt, found no stdin, and exited 1, so
"let me show you the preview first" was followed by an error and nothing else.

**What is forbidden is applying without asking**, not running `--yes`. `echo yes |`,
`<<< yes` and `yes |` are all the same violation: they satisfy the prompt without
anyone having been asked. The consent lives in the conversation — a question you
put, and an answer they gave — and `--yes` is how you carry it to the script.

If you settled on the defaults for both prefixes, do not run `--set` for them at
all. With no line in the settings file, the default applies.

### 6. `.gitignore` — ask about tracking `.cue/dev/`, then show and get consent

First, ask about the tracking preference — **with `AskUserQuestion`**, two
options, yes and no.

**No option carries a "(recommended)" badge.** Order carries the recommendation
and the description carries the reason — the rule is at the head of step 4 in
`cue-dev:start`, which has the reasoning. It holds here too, and here is where it
was broken: cue-dev really does want the records committed, so the badge felt
earned. What the user can weigh is "reviewers see all four records in every PR";
what they cannot weigh is a badge.

> "Should cue-dev work records (`.cue/dev/<KEY>/`) be committed to this repository?
> This affects whether design decisions, plans, and outcomes travel with your code
> and show up in pull requests.
>
> - **Yes**: Records stay with the code. Reviewers see the full context
>   (demand·design·plan·outcome) in every PR.
> - **No**: Records stay local only. Useful if your team uses a separate system
>   for design tracking, or you want to keep the repository light."

**If the answer is no**, add both rules:

> "I'll add these lines to `.gitignore`. The implementation scratch is always
> excluded; you're also excluding the work records.
>
> ```
> # cue-dev records and implementation scratch
> .cue/dev/
> .worktrees/
> ```
> "

**If the answer is yes**, add only the scratch rule:

> "I'll add these lines to `.gitignore`. One is the scratch directory used during
> implementation, the other is where cue-dev cuts worktrees — neither is something
> to commit. Work records will be committed.
>
> ```
> # cue-dev implementation scratch (records under .cue/dev/<KEY>/ are committed)
> .cue/dev/sdd/
> .worktrees/
> ```
> "

**`.worktrees/` goes in either way**, and it is the rule with the largest
accident behind it: cue-dev cuts its own worktrees there rather than asking a
harness to place them outside the repository, so an unignored `.worktrees/` puts
a second full checkout one `git add -A` away from being committed. If the line is
already there, say nothing about it.

If the `gitignore` line contains **`WARNING`**, `.cue/dev/<KEY>/` itself is being
ignored — meaning none of the records get committed. Find out which rule catches
it with `git check-ignore -v .cue/dev/SOME-KEY/demand.md` and tell the user.

### 7. `.gitattributes` — only report it

If `init-check`'s `gitattributes` line says `absent`, Windows prints a CRLF
warning on every commit. Annoying, but harmless.

**Never write it automatically.** Adding `* text=auto` changes the line-ending
normalization policy for the whole repository, and the next commit can show every
existing file as a diff. That is not something to slip quietly into someone else's
repository.

> "There is no `.gitattributes`, so Windows prints a CRLF warning on every commit.
> Adding `* text=auto` would remove it, but that changes the line-ending policy for
> the whole repository and can surface every existing file as a diff. I'll leave
> the call to you — cue-dev will not touch it."

### 8. Commit

If you changed the settings file or `.gitignore`, commit. If nothing changed, skip
this.

```bash
git add .cue/dev/config .gitignore
git commit -m "chore: <cue-dev repository settings, in the language just settled>"
```

**`chore:` stays; the subject after it follows the language this run settled.**
It is the first commit the repository gets in that language, and getting it wrong
here is what a reader notices — a `ko` repository whose history opens in English
and continues in Korean.

**The settings are meant to be committed.** The team has to share the conventions
for the markers not to drift.

### 9. Notice

```bash
<cue>/notice "INIT done" <<'EOF'
  marker    <marker_prefix>(<stage>): <KEY>
  language  <language>
  remote    <remote, or "none — local only">

  next      /cue-dev:start
  settings  /cue-dev:init  (just run it again)
EOF
```

**There is no `check` line here and there must not be one.** It used to say `check
per work item — /cue-dev:start asks it`, which reports the absence of a setting in
the box that lists the settings — and it announces a question the very next stage
is about to ask anyway. A box is read for what this repository now has; a line
saying where something *isn't* is answered before it can be useful. 3c is where
that question's move is explained, to a user who asks.

**Reproduce its output verbatim in your reply, in a fenced code block, and put it
last.** Anything you need to say goes *above* it — a decision you need from the
user, a warning, the answer to what they actually asked. **Nothing goes under it,
and nothing restates its labels**; restating them says the same thing at twice the
length.

**Stop here.** Do not call `cue-dev:start` automatically.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "No commits? I'll just branch and start" | Starting from an unborn branch creates no base branch. You find out the moment you try to open a PR with all the work done. This actually happened. |
| "While I'm here I'll settle the base branch too" | There is no base branch setting. The start point belongs to the work item, and `/cue-dev:start` asks for it there — where a hotfix can answer `main` without overwriting what the last feature answered. |
| "`init-check` prints `start_points`, so it wants an answer" | It is reporting what `start` will have to choose from. Reading it out here invites the user to settle a question this stage no longer stores. |
| "The remote is origin" | It usually is — but ask when there are several. `remote` is only the push target; the repository a PR is proposed to comes from the item's start point, so `upstream` belongs there, not here. |
| "Setting `remote` to `upstream` covers the fork case" | Then the push goes to a repository you cannot write to. Push to your fork (`remote`), propose against the original — which is the item's start point reading `upstream/main`. |
| "I asked two questions in one message and got one reply — the other takes the default" | The half they did not answer is the half you just decided for them. One question per message, and wait. |
| "The question failed to render, so I'll proceed with the defaults" | Then the user was never asked at all. Ask again in plain prose. A tool error is not consent. |
| "They asked about check strength, so I'll set `min_check` for them" | The script refuses it. That question moved to `/cue-dev:start`, which asks it about one item instead of all of them; point them there. |
| "The repository already has a `min_check` line, so I should clean it up" | Leave it. It is what items recorded before the move are read against, and removing it changes how already-finished work is judged. |
| "The config is right here in this worktree, so I'll edit the file directly" | That copy is this branch's. `config --set` writes the main checkout's, which is the only one every parallel item can see. |
| "The default marker prefix is good enough" | It may well be, but that is the user's call. Deciding someone else's commit convention without asking is exactly what this skill exists to prevent. |
| "Running `--set marker_prefix --yes` myself is faster" | Running it is your job. Running it *before asking* is the violation, and `echo yes \|` is that violation wearing a flag. Preview with `--dry-run`, ask, then apply. |
| "I'll hand the `--yes` command to the user with `!` so they consent by running it" | Then the tool that exists to spare them the terminal has put them in it, and the last thing they saw was a preview that exited 1. The consent belongs in the conversation; the execution belongs to you. |
| "I'll offer the default and a 'type a different value' option" | The interface already appends its own "type something". Yours makes the same choice appear twice, and the user has to work out whether the two differ. One proposal and one alternative is a prose question. |
| "The branch they named doesn't exist, so I'll propose `main` instead" | They told you where the work should start. Offer to create that branch. Substituting a different one is answering a question they did not ask. |
| "Language can be asked last, with the rest of the settings" | Then the whole of setup happened in a language the user never chose. Ask it first and switch immediately — the SessionStart hook already ran, so nothing else will carry the value this session. |
| "They set `ko`, so I'll tell them to restart the session" | Nothing needs restarting. You read the answer directly; write in it from your next sentence. The hook only matters for the *next* session. |
| "Let me fix `.gitattributes` to silence the CRLF warning" | It changes the line-ending policy for the whole repository and surfaces every existing file as a diff. The warning is an irritation that breaks nothing. Report it and move on. |
| "`.gitignore` is obviously fine to edit" | It is a shared team file. Show the lines and get consent. |
| "It's already initialized, so this skill has no use" | This skill is the settings-change path. Run it again and it shows the current values and asks whether to change them. |
