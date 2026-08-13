---
name: design
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
---

# Brainstorming Ideas Into Designs

**Speak the repository's language.** The first script this skill runs — `<cue>/gate`,
or `<cue>/init-check` — prints a `language` line. **Everything you say to the user
goes in that language, starting with your first sentence**: the questions you ask,
not only the record you write at the end. This skill body is English because it is
the plugin's source, not because it is your output. Template headings, commit
markers, `outcome.md` status tokens, paths and code stay exactly as written.


Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design and get user approval.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Prerequisite check

**Run this first, before reading anything.** It settles in one call whether this
stage may run here, against which KEY, and — if it may not — what is available
instead.

```
<cue>/gate design
```

`<cue>` is the scripts directory named in your session context. Substitute that
path and nothing else — a Windows path assembled by hand produces
`d:cuepluginscue-devscriptsgate: command not found`, which has happened.

**On exit 1, stop and relay the `now` lines.** They are the whole answer — do not
add a diagnosis of your own, and do not retry with a guessed KEY.

On exit 0 it prints the KEY. **Read `.cue/dev/<KEY>/demand.md` before you start**
— it is the input to this design.

## Anti-Pattern: "This Is Too Simple To Need A Design"

**The gate is on the step, not on the length.** A config change may be three
sentences and a "none" in four sections — that is a complete design, not a
shortcut. Padding it to look thorough wastes the reviewer's attention, which is
the scarcest thing in this workflow.

What is not optional is going through the step and getting approval. Every
project does: a todo list, a single-function utility, a config change. "Simple"
projects are where unexamined assumptions cause the most wasted work.

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Read demand.md** — grasp the requirement. Do not ask about it again
2. **Explore project context** — check files, docs, recent commits
3. **Ask clarifying questions** — only about *how* to build it. Never about *what* to build
4. **Propose approaches** — 2-3 with trade-offs and your recommendation, or one with why the space is narrow
5. **Present design** — in sections scaled to their complexity; get approval in
   prose, before any file exists
6. **Write design doc** — `<cue>/skeleton design <KEY>` writes the frame; you fill it in
7. **Spec self-review** — run `<cue>/verify <KEY>` for the mechanical half, then judge the rest yourself (see below)
8. **User reviews written spec** — only confirm the spots the self-review filled in
9. **Commit and stop** — commit as `cue-dev(design): <KEY>` and point at the next stage

## The two places this can branch

The checklist above is otherwise linear. Only two steps decide anything:

- **After step 1** — if demand.md's requirement is not clear enough to design
  against, stop and report. Do not design your way past it.
- **After step 7** — if the self-review changed nothing, commit without asking
  again. If it filled something in, confirm just that delta.

**The terminal state is: commit and stop.** Do not call the planning skill
automatically. Do not call any implementation skill either — frontend-design,
mcp-builder, or anything else. The user reviews design.md and runs the next stage
themselves.

## The Process

**The requirement is already settled:**

- demand.md tells you what to build. **Do not ask about it again.** "Why is this
  feature needed?", "Who uses it?", "What is the success criterion?" are questions
  `/cue-dev:start` already finished. Asking again makes the user say the same
  thing twice.
- What you ask here is **how to build it** — structure, boundaries, the relation
  to existing code, trade-offs.
- **If the requirement itself is unclear, do not paper over it with design.** Stop
  and report.

  > "<item> in demand.md is too unclear to settle the design. To fix the
  > requirement, rewind with `/cue-dev:redo demand`."

  A requirement filled in by guesswork is indistinguishable from the original six
  months later.

**Understanding the idea:**

- Check out the current project state first (files, docs, recent commits)
- Before asking detailed questions, assess scope: if the request describes multiple independent subsystems (e.g., "build a platform with chat, file storage, billing, and analytics"), flag this immediately. Don't spend questions refining details of a project that needs to be decomposed first.
- If the project is too large for a single spec, help the user decompose into sub-projects: what are the independent pieces, how do they relate, what order should they be built? Then brainstorm the first sub-project through the normal design flow. Each sub-project gets its own spec → plan → implementation cycle.
- For appropriately-scoped projects, ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on understanding: purpose, constraints, success criteria

**Exploring approaches:**

- Propose 2-3 different approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why
- **If there is genuinely only one approach, say so and say why the space is
  narrow** — an existing convention, a platform constraint, a decision already
  settled elsewhere. One honest approach beats three where two are strawmen: a
  padded comparison makes the reviewer believe the choice was examined when it
  was not. Never manufacture an alternative to fill the section.
- YAGNI ruthlessly - remove unnecessary features from every approach and design

**Presenting the design:**

- Once you believe you understand what you're building, present the design
- Scale each section to its complexity: a few sentences if straightforward, up to 200-300 words if nuanced
- Cover: architecture, components, data flow, error handling, testing
- **Ask once.** Present the design and ask whether it looks right. Only for a
  design long enough that a wrong premise early would waste the rest — several
  sections of substance — check in as you go. Section-by-section approval on a
  short design is the same "yes" collected four times.
- Be ready to go back and clarify if something doesn't make sense

**Design for isolation and clarity:**

- Break the system into smaller units that each have one clear purpose, communicate through well-defined interfaces, and can be understood and tested independently
- For each unit, you should be able to answer: what does it do, how do you use it, and what does it depend on?
- Can someone understand what a unit does without reading its internals? Can you change the internals without breaking consumers? If not, the boundaries need work.
- Smaller, well-bounded units are also easier for you to work with - you reason better about code you can hold in context at once, and your edits are more reliable when files are focused. When a file grows large, that's often a signal that it's doing too much.

**Working in existing codebases:**

- Explore the current structure before proposing changes. Follow existing patterns.
- Where existing code has problems that affect the work (e.g., a file that's grown too large, unclear boundaries, tangled responsibilities), include targeted improvements as part of the design - the way a good developer improves code they're working in.
- Don't propose unrelated refactoring. Stay focused on what serves the current goal.

## Get approval before the file exists

**Present the design and get an answer. Nothing in "After the Design" runs until
then** — not `skeleton`, not the file.

This is the same checkpoint `/cue-dev:plan` puts in front of plan.md, in the same
place and for the same reason, and it is written here in the same shape because
one of the two stages having it was how it got skipped.

**Present the design, not the approach you picked.** The choice between two
approaches is step 4 and it is already behind you. What needs an answer here is
the thing that is about to be written down: what gets built, the worked example,
the program design, and how anyone will know it works. Those are the sections the
reviewer reads, and the user cannot push back on a section they have not seen.

> "<what we build, in two or three sentences>. <the worked example>. <the program
> design in outline>. <how we know it works>. Shall I write this to
> `.cue/dev/<KEY>/design.md`?"

**Ask in prose, not as a menu.** "Approve, or tell me what to change" is one
proposal and free-text feedback. A menu turns it into a choice between options you
wrote, and a real session's entire design approval was a two-option menu —
"structured architecture" against "simple conversion" — after which the worked
example, the program design and the verification method went into the file and
into a commit without the user having seen a word of any of them. The trade-off
menu is step 4's tool. This step's tool is a paragraph and a question mark.

**And the question is the end of the reply. Do not call another tool in that
turn.** A menu makes the harness stop and wait; prose does not, and a turn that
continues past its own question is a turn that answers it. `cue-dev:plan` carries
the same rule at the same point, and `cue-dev:using-cue` says what to do when the
question itself fails.

**A rewrite here is free — nothing has been written.** After the commit it costs a
`/cue-dev:redo design`.

## After the Design

**Do not type the document's structure. Ask for it.**

```bash
<cue>/skeleton design <KEY>
```

That writes `.cue/dev/<KEY>/design.md` — this path is fixed; the later cue-dev
stages look for it there — carrying every heading, the two fixed literals, and a
`[[ ... ]]` prompt wherever prose goes. **You fill in the prompts and change
nothing else.** `scripts/verify` errors on any `[[` that survives, so a frame
that reached a commit unfilled is not a thing that can happen.

Use elements-of-style:writing-clearly-and-concisely skill if available.

**Everything you write into a `[[ ... ]]` goes in the repository's record
language.**

```
<cue>/config --get language
```

**Everything the skeleton already wrote is structure and stays exactly as it
is** — the headings, and the `none` pre-filled under "Divergence from demand" and
"Planned contract changes". Later stages and `scripts/verify` look those up by
name, in English, and a translated one fails a check that reads as though the
section were missing. That is not hypothetical: a real session answered
`Planned contract changes` with `없음` and was told the section was empty.

This split is the whole reason the frame is generated rather than copied. Before
it, the template was English and the instruction was "prose follows the record
language", and nothing on the page said which words were which. Get it wrong the
other way — writing the prose in English in a `ko` repository — and the
repository ends up with the requirement in one language, the design in another,
and the outcome back in the first. Nobody notices until a reviewer reads all four
in a row.

**Do not add sections and do not drop any.** The list is fixed so that a reader
who reviews many of these can scan them the same way every time, and so that an
empty section is readable as "we considered this and there was nothing."
**"none" is a complete answer.** Length is what scales, not the skeleton.

What the sections are for:

| section | what belongs there |
|---|---|
| Structure | mermaid, the **delta only**. No structural change is a claim worth making, not a heading to drop |
| What we build | two or three sentences |
| Worked example | one concrete value through the system — real values, not interfaces |
| Why this way | the substance of the review; may run longer |
| Rejected alternatives | `<alternative>: <why it was dropped, as the reasoning stood then>`; may run longer |
| Divergence from demand | pre-filled `none`; replace it only for the case below |
| Constraints at the time | performance · state of the existing code · schedule · team practice |
| Program design | modules · responsibility boundaries · signatures · dependency direction · error handling |
| How we know it works | what decides this is done, and whether that check runs by itself |
| Planned contract changes | pre-filled `none`; otherwise `kind: target — description (compatibility)`, one per line |

**The worked example is what makes a large design readable.** Every other section
is abstract, and a reader with no foothold gives up on a long one — which is the
actual reason big designs go unread, not their length. Put one real value through
the system and the abstractions afterwards have something to attach to.

Use values that could appear in a log line: `ttl=3600`, `12:00`, `session-4f21`.
Not `<some id>`. If the work has no runtime path to trace — a refactor, a
documentation change — trace what a reader does instead: the file they open now
versus the file they will open after.

**Always fill in the rejected alternatives.** The approaches you proposed above
and the user did not pick go here. Left only in the conversation, they vanish
with the session, and six months later nobody can answer "why didn't we do it
that way?"

If there was genuinely only one approach, write that and why the space was
narrow. That is a real entry — it tells the reviewer the choice was bounded, not
unexamined. **An invented alternative is worse than none**: it makes a comparison
that never happened look like it did.

**Divergence from demand — the requirement moved, and only this stage saw it.**

Requirements are not settled in one pass outside a textbook. Designing something
surfaces what the request could not have known, and the design that comes out is
then not quite the design that was asked for. Before this section existed there
was nowhere to say so: the only path was "the requirement is unclear, stop and
rewind", which fits a requirement that cannot be designed against and not one
that simply grew. So the growth went unrecorded, and demand.md and design.md
described two different pieces of work with nothing between them saying which
was built.

**Two things happen here and only one of them is divergence.**

- **Narrowing** — demand left something open and the design closes it. This is
  what design is for. It goes in "What we build" and "Why this way", and it does
  **not** go here. Record it here and every design grows a section of noise that
  reviewers learn to skip.
- **Contradicting or extending** — the design settles on something demand did
  not ask for, or asked against. That goes here, one line each.

**"none" is the normal answer, and the heading stays either way.** Same reason as
the other sections: a heading that appears only when there is something to say
turns "nothing diverged" into an absence, and an absence cannot be told apart
from a stage that did not look. `scripts/verify` checks the heading is present,
so this is enforced rather than remembered.

**If it is not "none", stop and ask before you write the file.** Show the user
each line and let them choose:

> "demand.md asks for <X>; the design settles on <Y> because <reason>. Shall I
> record that as a divergence and carry on, or is the requirement itself wrong —
> in which case `/cue-dev:redo demand` puts it back and we start from the real
> one?"

**Do not edit demand.md.** It is what was asked for, signed and dated, and
rewriting it to match the design leaves nobody able to answer "what did we
originally want?" six months later. The difference belongs in the later record,
where the git history already shows which came first. `/cue-dev:redo demand` is
the one path that changes it, and it is a rewind — it discards this design on
purpose, because a design built against a requirement that no longer exists is
not worth keeping.

**How we know it works.** The reviewer of this document may never read the code,
so this is where they check the work is checkable at all. One or two lines: the
test, the command, the observable behaviour that settles it — and whether it runs
by itself or someone has to look. "The existing suite covers it" is a valid
answer. "Manual check" is valid too, as long as it says what is being looked at.
What is not valid is silence, because then nothing at the plan or implement stage
has a target to hit.

**Scope of planned contract changes:**

```
included: HTTP API request/response · DB schema · event payloads · public library
          signatures · config file formats · CLI arguments
excluded: internal functions · private methods · refactoring · file moves
```

Fix the format as `kind: target — description (compatibility)`. This is so
documentation tooling can grep out "contracts changed in the last six months."
**For most work, "none" is the normal answer.**

**Length limit:** two or three sentences per section. Only "Why this way" and
"Rejected alternatives" may run longer — they are the substance of the review.
If "Program design" grows long, planning-stage content has leaked in.

This is a limit, not a suggestion, and the self-review below checks it. A section
over the limit is not a thorough section; it is one that spends the reviewer's
attention on the wrong thing.

**Self-review — the mechanical half is a script:**

```bash
<cue>/verify <KEY>
```

It checks the things that can be checked without judgment: every required heading
present, no `TBD`/`TODO` left in prose, the contract-change lines in their fixed
shape. Fix whatever it names and run it again.

**Do not do this part by reading.** Counting sections and scanning for
placeholders by eye is spent attention that degrades silently — and it competes
with the four questions below, which are the ones nobody else can answer.

**Then the half that needs judgment.** Look at the document with fresh eyes:

1. **Does it contradict itself?** Does the structure match what "What we build"
   describes? Could any statement be read two ways — if so, pick one and say it.
2. **Is it one plan's worth of work?** Or does it need decomposing into
   sub-projects first?
3. **Are the rejected alternatives more than a formality?** "Bad performance" or
   "too complex" is not a reason. It must say what it was worse than and by how
   much, and what the reasoning was at the time. Record only alternatives you
   actually considered — **do not invent any to fill the section.** If there was
   one approach, the entry says so and why.
4. **Is "How we know it works" answerable by someone who won't read the code?**
   It must name a check, not a hope. "It should work correctly" is not a check.
5. **Is there design judgment at all?** Check that the document is not just
   demand.md reworded. If all it does is restate the requirement and "Why this
   way" is empty, no design was done.

Also cut any section over two or three sentences other than "Why this way" and
"Rejected alternatives". Do not keep a paragraph because it is accurate — keep it
only if the reviewer needs it to judge the design.

Fix any issues inline. No need to re-review — just fix and move on.

**User Review Gate — conditional:**

You already got approval at step 5 (presenting the design). Asking "please
confirm" again over the same content makes the user approve what they just
approved. That repetition is what makes cue-dev feel like friction.

**There is exactly one reason to ask again — something entered the document that
was not agreed in the conversation.**

- **If the self-review filled in or fixed something**, point at just that spot and
  get confirmation. What the user approved was the design in the conversation, not
  the supplement.

  > "I wrote the design to `.cue/dev/<KEY>/design.md`. In the self-review I filled
  > in <item> as <how> — that part was not settled in the conversation, so it
  > needs a check. Shall I commit as is?"

- **If the document is exactly the design you agreed on, do not ask.** Commit,
  print the notice below, and stop. If the user finds something to fix after
  reading the document, `/cue-dev:redo design` is that path — it is already in the
  notice.

If there are open questions or judgments you deferred to the next stage, **report
them** instead of asking for confirmation. That is a report, not a question.

**Commit:**

Commit after you have approval.

```bash
git add .cue/dev/<KEY>/design.md
git commit -m "$(<cue>/marker design <KEY>)"
```

**Do not change the marker format.** `cue-dev:status` and `cue-dev:redo` decide
the stage from this string.

**`marker` runs `verify` and prints nothing if it fails**, so git aborts on the
empty subject and no design commit is made. That is not a second gate to satisfy
— it is the one above, enforced where it cannot be walked past. If it refuses,
its stderr carries verify's errors; fix those and run the same command again.
**A record that reaches this point clean makes it silent.**

**Point at the next stage:**

```bash
<cue>/notice "DESIGN done" <<'EOF'
  key       <KEY>
  artifact  .cue/dev/<KEY>/design.md
  commit    <the commit subject actually written>

  next      /cue-dev:plan
  rewind    /cue-dev:redo design
EOF
```

**Reproduce its output verbatim in your reply, in a fenced code block, and put it
last.** Anything you need to say goes *above* it — a decision you need from the
user, a warning, the answer to what they actually asked. **Nothing goes under it,
and nothing restates its labels.**

**Stop here.** Do not call the planning skill automatically. A human checkpoint
between stages is cue-dev's design.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Let me re-ask the requirement just to be sure" | It is already in demand.md. The user says the same thing twice, and that is what makes cue-dev feel like friction. Read it and start. |
| "The requirement is vague but I can settle it while designing" | At that moment the requirement and your guess get mixed, and six months later they are indistinguishable. Stop and report. |
| "Rejected alternatives are a formality, fill them in roughly" | It is the first place a reviewer looks. A one-liner with no reasoning is worse than nothing — it only leaves the impression that you considered it. |
| "Only one approach fits, but three looks more thorough" | The reviewer reads three and concludes the choice was examined. Two of them were props, so it was not — you have hidden the fact that nothing was compared. Write the one and why the space is narrow. |
| "The worked example is padding — the design already says what it does" | Every other section is abstract. The example is the only place a reader gets a foothold, and without one a long design goes unread no matter how correct it is. |
| "I'll scan for the required sections and placeholders myself" | That is `scripts/verify`'s job, it does not get tired, and the attention you spend on it comes straight out of the five questions only you can answer. |
| "A longer design is a safer design" | The reviewer's attention is the scarce resource here, not page count. Padding buries the two or three lines that actually needed pushback. |
| "Contract changes can be tidied up later" | It is the reviewer's first checkpoint. Leave it empty and the review descends into variable names. |
| "The template is English, so design.md is written in English" | The headings are English because later stages look them up by name. What goes in the `[[ ... ]]` prompts follows `.cue/dev/config`. A repository whose demand and outcome are Korean and whose design is English is one nobody can review in one pass. |
| "The record language is Korean, so `none` should be `없음`" | `none` is one of the two literals `scripts/verify` greps for, which is why `scripts/skeleton` writes it for you. Translating it does not read as a translated answer — it reads as a section nobody filled in. |
| "I'll just write the file; I know what the sections are" | Then you are transcribing structure from memory, which is where the two failures above came from. `scripts/skeleton` costs one call and cannot mistype a heading. |
| "Going straight through to the plan is faster" | The user loses the chance to check the design. A plan built on a wrong design is thrown away whole. |
