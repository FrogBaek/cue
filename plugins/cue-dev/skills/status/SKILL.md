---
name: status
description: Use when you or your human partner need to know where a cue-dev work item stands, when you have lost track of which stage is in progress, or after a compaction. Also use before redoing a stage, to see what will be discarded.
argument-hint: [KEY]
---

# Checking the current stage

**Speak the repository's language.** The first script this skill runs — `<cue>/gate`,
or `<cue>/init-check` — prints a `language` line. **Everything you say to the user
goes in that language, starting with your first sentence**: the questions you ask,
not only the record you write at the end. This skill body is English because it is
the plugin's source, not because it is your output. Template headings, commit
markers, `outcome.md` status tokens, paths and code stay exactly as written.


Run `<cue>/status [KEY]`. **When it prints the `━━━` block, reproduce that block
in your reply, inside a fenced code block, unchanged and complete.**

That instruction is the whole skill, and it is the one that gets skipped. The
script's output goes to a *tool result*, which the interface collapses to the
first few lines — so a user who ran `/cue-dev:status` and got a two-sentence
summary from you never saw the track, the task counts, or the isolation warning.
They asked for the report, not for your reading of it.

The block does not translate. Every line in it is a label and a value — stage
names, file paths, SHAs, commands — so paste it as it stands even when the record
language is not English.

**Only the `━━━` block is relayed.** When the script cannot answer it hands the
question to `<cue>/gate` instead, and gate prints no block — it prints `blocked`
and `now` lines, which are written to be *acted on*, not pasted. Say what they
mean, in the user's language, in a sentence or two. A session that pasted gate's
raw output showed the user `language ko — reply to the user in this language…`,
a line addressed to you and about nothing they asked. That line now goes to
stderr for exactly this reason; the rest of gate's output is still yours to read
and act on rather than to forward.

**Then add at most one sentence, and only if it says something the block does
not.** An unrecorded task worth flagging, an answer to what the user actually
asked. Walking the labels — "`next` means the next command is…" — is the block
again at twice the length, and it is what the instruction to "add what it means"
kept producing.

Omit the KEY and it finds the item whose recorded branch is the one checked out
here — the `branch:` line each item's demand.md carries. That is a recorded fact,
not a guess, which is why it is the only inference there is.

**When it matches nothing, the answer is that there is no answer.** Two items on
one branch, or a branch the merge already deleted, and the script says nothing is
in progress here and offers the KEY. Say that and stop. **Do not go and read
`.cue/dev/` to work out which item was meant, and do not pick one.** `.cue/dev/`
is an archive — it keeps finished work on purpose — so its contents answer "what
exists here", which is not the question that was asked. A real session was handed that list, read it
back as "several items in progress", named four, and asked the user which to
continue. All four had merged.

If the user did mean a specific item, they will name it. Ask.

**If the script exits non-zero, do not improvise a diagnosis.** The `now` lines
are the answer — give the user those, in their language. A refusal that only
names what failed is what sent a real session guessing at KEYs and then reading
`.cue/dev/` by hand to work out the next step for itself.

**Do not then run `<cue>/gate status` yourself.** With no KEY, `<cue>/status`
*is* gate — it hands the question over and gate's answer is the output you are
already holding. Running gate after it re-runs the identical check and prints the
identical lines, and a real session did exactly that: two tool calls, one answer,
both pasted. Run gate directly only when you invoked `<cue>/status <KEY>` with a
KEY and it refused.

## What this script tells you

| Item | Evidence |
|---|---|
| current stage | the most recent `cue-dev(<stage>): <KEY>` commit marker |
| artifacts | whether the four files exist under `.cue/dev/<KEY>/` |
| task progress | the number of `unrecorded` rows in `outcome.md` |
| worktree | whether the current location is a linked worktree |

**A `history` line means the markers are gone.** A squash or rebase landing keeps
the records and drops the commits that stamped them, and so does salvaging records
onto a branch by hand. The stage on that line was read from the committed records
instead, which is weaker evidence — and no rewind is offered, because there is no
marker left for `/cue-dev:redo` to rewind to. Nothing is lost from the tree; only
the history that produced it. Say that in one sentence if the user asks; do not
propose repairing the history.

## Do not interpret the output

The script has already made the determination. Do not summarize or re-explain it —
relay the output verbatim, and answer about the next command when the user asks.

**"design is done, plan is next" is not a relay.** It is a summary that replaced
the block, and it drops everything the block was carrying:
which artifacts are uncommitted, how many tasks are unrecorded, whether the
checkout is isolated, and how to rewind — the nearest stage on the `rewind` line
and every further one under it.

**If unrecorded tasks remain, point that out.** An `unrecorded` row in
`outcome.md` is a signal that the controller skipped a task, and this is the only
standing path for it to surface before the PR. Let it pass and it ships in the PR
as is.
