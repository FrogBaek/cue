# The notice block

Every surface a cue-dev user reads directly uses one shape, and **one piece of
code draws it.** `scripts/status` and `scripts/redo` call `cue_head`/`cue_rule`
directly; every stage skill (`init` · `start` · `design` · `plan` · `implement` ·
`finish`) pipes its lines through `scripts/notice`, which calls the
same pair. A user moving between stages should not have to re-learn where to look.

**The skills no longer write the box out.** They used to, and the templates were
all exactly 47 columns — right up until `<KEY>` was replaced with a real key. A
33-character KEY pushed the opening line 28 columns past a closing rule that is a
literal string and does not move, so the box came out ragged for every key longer
than five characters. Counting columns in prose at render time does not work;
`scripts/notice` exists so that nobody has to.

**What Claude must still do is reproduce the output verbatim** — in a fenced code
block, complete, in its own reply. The script's output lands in a tool result,
which the interface collapses after a few lines. Every skill that calls `notice`
says so, and the SessionStart hook carves the notice block out of its "relay the
meaning rather than pasting raw output" rule for the same reason.

```
━━━ <title> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  key       <KEY>
  <label>   <value>

  next      <command>
  rewind    <command>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## The rules

**The title is one of a closed set, and `scripts/notice` enforces it.**
`INIT done` · `START done` · `DESIGN done` · `PLAN done` · `IMPLEMENT done` ·
`FINISH done` · `REQUEST done` · `MERGE done`. Anything else exits 2.

The list on this page is a copy, and it went stale exactly as a copy does: 13ᵗʰ
added `REQUEST done` and `MERGE done` to the script and not to this sentence, so
the page documenting the whitelist disagreed with the whitelist for two releases.
`test-notice.sh` now compares the two, which is the same treatment the three
version numbers get — the authority is `CUE_NOTICE_TITLE_LIST` in the script, and
every other surface is bound to it rather than trusted.

This is a trust boundary, not tidiness. The frame's whole meaning is "a cue-dev
stage produced this and a script assembled it", and that meaning survives only if
the frame cannot be produced any other way. A real session hand-rendered
`━━━ MERGED · <KEY> ━━━` for a merge performed outside `/cue-dev:finish` — a stage
that does not exist, reporting a result nothing had checked, visually identical to
the six real boxes. Adding a stage means adding a title here, in the repository,
under review.

`status` and `redo` call `cue_head` directly and have their own titles: `STATUS`,
`REWIND preview · <stage>`, `REWIND done · <stage>`. They are not user-supplied
strings, so the whitelist does not reach them.

**The title goes in the rule, not on a line of its own**, padded to 47 columns —
or wider, when the title alone needs more. `cue_head` builds it and records the
width it used; `cue_rule` closes at that same width.

**The KEY is a body line, never part of the title.** It led the title for a
while, then trailed it; both were wrong for the same reason. The KEY is the
longest and most variable string in the block, and putting it in the one position
that decides the frame's width stretched the whole box sideways — a 33-character
KEY widened every rule to carry a value that `key  <KEY>` carries in place. Every
surface now opens with a fixed-width title and reports the KEY like any other
value.

`cue_head` measures the title with `cue_display_width`, not `${#}` — on Git Bash
the locale is empty and `${#}` counts bytes, so a `·` in the title closed the box
a column short.

**Every line is `label + value`.** Two spaces, the label in a 10-wide field, then
the value — so values line up at column 13. No sentences. A line that wants to be
a sentence is a line whose label has not been found yet.

This is also what keeps these outputs out of the localization question. Once the
labels are stripped, what remains is file names, SHAs, branch names and commands
— none of which translate. See the `language` note in `scripts/common`.

**A blank line separates the groups.** State above, action below. `next` and
`rewind` are the last thing in the block because they are what the reader came
for.

**Optional lines appear only when they say something.** `tasks` when the plan has
tasks, `legend` when a `~` is on screen, `where` when the work is *not* isolated.
A line printed on every single run stops being read, so the standing lines are
the ones that always carry news.

**`⚠` marks the value, not the label.** `where      ⚠ not isolated — …` keeps the
label column true; putting the mark before the label would shift every following
character.

## What goes under the block: nothing. The block is last.

The block is the report. **Restating its labels in prose is pure cost** — output
tokens spent to say `artifact` means a record was created, `commit` means a commit
was made. A real session printed six such lines under every box in the cycle,
and none of them carried anything the box had not.

The hook's language directive used to end with "and then add what it means",
which is where that came from: read against a box whose lines are already
label-and-value, "what it means" has nothing left to be except a translation of
the labels.

**The rule is positional, and that is what finally settled it.** The box is the
last thing in the reply; anything you need to say — a decision needed from the
user, a warning, the answer to what they actually asked — goes *above* it.

This was open from the 9ᵗʰ session to the 16ᵗʰ, because the two obvious rules each
had a failure to their name and neither could win on the evidence. "Add nothing"
produced a bare `START done` and a user asking whether the missing guidance was
intentional or whether the agent varies per run — the rule working as designed,
read as caprice. "At most one sentence, when it carries something the box does
not" produced the six restated lines above, because *does this carry something
new* is a judgment made fresh on every call, and a model making it under time
pressure decides yes.

Position dissolves both. Nothing is suppressed, so the bare box is never a
withheld answer; nothing is appended, so there is no slot for a paraphrase to
occupy; and there is no per-call judgment left to make, because where a sentence
goes does not depend on what it says.

**A fact the reader needs is a box line, not a sentence.** The plugin's one
standing exception used to be "add one line under it, because it is not in the box
and the user needs it". The need was real; the remedy authorised prose to carry a
fact, where it can be forgotten, reworded or dropped. Facts of that kind became
script-rendered box lines, and the exception went with them.

## What is deliberately outside the block

**Errors.** `usage`, an unresolvable KEY, a missing work directory, a stage that
never ran — these go to stderr as a single bare line and exit non-zero. Wrapping
a one-line failure in a 47-column box makes it look like a report rather than a
refusal, and the exit code already carries the verdict.

```
work not found: NOPE-1 (no /home/you/project/.cue/dev/NOPE-1)
```

**Everything Claude re-speaks.** `work-init`, `init-check`, `outcome-init`,
`task-graph` and `config` print for Claude to read and relay in its own words, so
they stay plain. Only what reaches the user unaltered gets the block — which is
exactly `status`, `redo`, and whatever a skill hands to `notice`.

## When a value does not fit

The block adapts to the title — `cue_head` records the width it used and
`cue_rule` closes at the same one, so a long KEY widens the box instead of
breaking it. Values are *not* truncated. A repository path, or `git branch -D`
across a dozen backups, is allowed to wrap: cutting it would break the copy-paste
that is the whole point of printing it.

## Asking the user

Not output, but the same question of shape, and it broke the same way — so the
convention lives here too.

**A menu is for choices that are genuinely different from each other**, and where
one belongs, the skill names `AskUserQuestion` outright rather than saying "an
options list fits". The record language, the item's check level, the remote, whether
records get committed, the integration path in `finish` — these enumerate.

Naming the tool is not pedantry. "An options list is right for this one" was in
the skill for every one of those questions, and a real session asked all of them
in prose anyway — then took a default for the one the user did not answer. A tool
call cannot be answered by silence; that is the property being bought.

**"The default, or a value you type" is not a menu.** One proposal, one
alternative, and the alternative is free text: ask that in prose. Rendered as a
menu it becomes "take the default" plus "type a different value" — and the
interface appends its own "type something" to every menu, so the user is shown the
same escape hatch twice and has to work out whether the two differ. A real session
produced exactly that three times over.

**The marker prefix is the one question this now applies to**, and
`/cue-dev:init` 3b says so. It used to list two more, and both are gone: the branch
prefix is not a setting any more, and **the KEY moved to `AskUserQuestion`** —
`/cue-dev:start` step 2 has the reversal in full. The short version is that the
shape argument was right and the premise was not: a prose question does not end the
turn, so the same turn carries on, and carrying on needs an answer. A real session
wrote *"User says yes, so I'll proceed"* and cut a branch nobody had approved. What
the tool buys at that question is not the menu, it is that the harness stops.

**So the rule is reversibility, not shape.** A value `/cue-dev:init` can change
again tomorrow may be asked in prose. Anything that names something outliving the
answer — a directory, a branch, the commit markers, the branch the work merges back
into — gets the tool.

**No option is labelled "(Recommended)".** Order carries the recommendation; the
description carries the reason, as a fact the user can weigh. `AskUserQuestion`'s
own description instructs the opposite on every call, which is why the rule is
unconditional rather than scoped to questions cue-dev has no opinion about — a rule
that must first ask "do we have a view here?" gets re-decided per call and drifts.
Both badges that reached the skills came in under that reading, one of them in
`finish`, which tells itself twice on the same page to recommend nothing.
`cue-dev:start` step 4 is where the reasoning lives, because it is a skill body and
this page is not: skills are loaded at runtime, `docs/` is not.

**Never write your own "other" entry.** Not in the menus that are justified
either. It is supplied.

## Tests

Assertions match the label and the value with flexible whitespace
(`next[[:space:]]+/cue-dev:design`), never a fixed run of spaces. The column width
is a design choice that may change; what the tests pin is that the label and its
value are there.
