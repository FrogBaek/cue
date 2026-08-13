# cue

**English** · [한국어](README.ko.md)

Claude Code plugins for AI-assisted development. Each plugin works on its own and
uses a single directory under the project's `.cue/`.

| Plugin | What it does | Directory | Status |
|---|---|---|---|
| `cue-dev` | Development workflow, from requirement to merge | `.cue/dev/` | 0.1.0, in development |
| `cue-scan` | Project analysis | `.cue/scan/` | Planned |
| `cue-docs` | Documenting the project's current state | `.cue/docs/` | Planned |

## Install

```
/plugin marketplace add FrogBaek/cue
/plugin install cue-dev@cue
```

---

# cue-dev

## The problem

git records what changed and when, but not why it was changed that way. That
judgment sits in a conversation that has already closed. Open the code six months
later and the logic reads fine, but the reasoning is gone. Every reader guesses
differently, and reviewers approve without knowing which alternatives were weighed.

This debt accrues interest. One decision nobody can check makes the next decision
on top of it harder too. Working with an AI piles it up faster, in proportion to
the speed you gain.

cue-dev does not make the cost go away. It has you pay it while designing rather
than while reading code, and keeps it from growing. The requirement, the design,
the alternatives you rejected and the outcome are recorded as you work and
committed next to the code, so later you can trace back from any line.

```
git blame → commit → KEY → .cue/dev/<KEY>/design.md
```

## Key ideas

- **The records travel with the code.** They are committed to `.cue/dev/<KEY>/` on
  the same branch, so a PR carries the reasoning along with the diff.
- **Every stage stops and asks.** Nothing moves to the next stage on its own.
- **Progress is read from git, not from the session.** It is determined by commit
  markers, so work started today can be picked up next week, in another session,
  by another model.
- **Scripts answer the questions of fact.** Which stage this reached, what a
  rewind would cost, whether a backup can be restored — every one of those is
  answered by a script with tests behind it.

## Usage

### Once per repository

```
/cue-dev:init
```

Sets the commit marker prefix, the record language, the remote name, and whether
`.cue/dev/` is committed. It asks, waits for your confirmation, then writes
`.gitignore` and the settings file. Safe to run again.

### Starting a work item

```
/cue-dev:start Add a 5-attempt limit on failed logins
```

Write what you want to do in a sentence. Give it nothing and it will ask. At this
point you are offered a KEY, and confirming it creates the workspace and
`demand.md`.

`/cue-dev:start` takes the requirement you pass it. If the agent you run it in
has your issue tracker on MCP, that text can just as well be a ticket body it
pulled from there — pass whatever identifies the ticket and let it fetch the body:

```
/cue-dev:start PROJ-142
```

That identifier becomes the KEY, so you are not offered one. It is not validated,
but it ends up as a directory name and a branch name, so `PROJ-142` reads better
than a bare number. Either way, `demand.md` records where the text came from — a
tool, a paste, or the conversation.

The KEY is the name every later command uses to find this work item. It is
recorded on the branch, so **you do not have to pass it again.**

### Going through the stages

```
/cue-dev:design      digs into the requirement and writes design.md
/cue-dev:plan        splits the design into independent tasks in plan.md
/cue-dev:implement   builds task by task and records each outcome
/cue-dev:finish      verifies the records, integrates, writes outcome.md
```

Run them in order, with no arguments. Each command shows you what it produced and
stops. You review it, and running the next command is what moves things on. If
you do not like it, say so and have it fixed on the spot.

`design` asks back when the requirement is ambiguous, and keeps the rejected
alternatives in the record. `plan` draws the dependency graph between tasks and
attaches it. `implement` leaves a commit per task and fills in that task's row in
`outcome.md`. `finish` verifies that nothing in the records is missing, then
merges into the base branch or leaves the branch alone.

### Where things stand

```
/cue-dev:status
```

Shows which stage the item reached, what comes next, and what a rewind would
discard. Start here after a few days away, or when the session has changed. If you
are on a different branch, pass the KEY: `/cue-dev:status PROJ-142`.

### Rewinding when it went wrong

```
/cue-dev:redo plan
```

Takes back that stage and everything done after it. Before rewinding it saves the
current state to a backup branch, shows what will be discarded, and waits for your
confirmation.

You can also undo the rewind. There is no dedicated argument for it — just say so:

```
/cue-dev:redo   →  "undo that rewind, go back to the backup"
```

Every backup for the item is then listed, along with which stage each one holds
and how many commits would come back and be discarded. Choosing between them is
yours. The state you are in right before restoring is backed up too, so the
restore itself can be undone.

### Command summary

`<>` is required, `[]` optional. Leave out `[KEY]` and it is found from the
current branch.

| Command | Arguments |
|---|---|
| `/cue-dev:init` | none |
| `/cue-dev:start` | `[requirement or ticket body] [KEY]` |
| `/cue-dev:design` | none |
| `/cue-dev:plan` | none |
| `/cue-dev:implement` | none |
| `/cue-dev:finish` | none |
| `/cue-dev:status` | `[KEY]` |
| `/cue-dev:redo` | `<demand\|design\|plan\|implement> [KEY]` |

## Sharing the records with your team

Whether the records under `.cue/dev/<KEY>/` are committed to the repository or
kept local is chosen at `/cue-dev:init`, and the `.gitignore` rules follow that
choice.

- **Committed.** Teammates see the requirement, design and outcome in the PR
  alongside the diff. This is what cue-dev takes as the default.
- **Not committed.** `.cue/dev/` is ignored entirely. Use this when design
  documents are managed in another system, or when adding files to the repository
  is awkward.

Either way the workflow is identical; only whether the team sees it changes. The
scratch directory used during implementation (`.cue/dev/sdd/`) and the worktree
directory are always ignored.

## What it does not do

- **Act as an issue tracker.** It does not replace Jira or GitHub Issues. If you
  use a tracker, add its MCP separately; if you do not, `/cue-dev:start` asks you
  directly.
- **Code review.** It gets the work to a reviewable state. People review.
- **Manage project documentation.** It neither reads nor edits it.

## Contributing

To run it straight from a checkout:

```bash
claude --plugin-dir /path/to/cue
tools/run-tests.sh          # 32 suites, about 6 minutes
```

The rest is in [CONTRIBUTING.md](CONTRIBUTING.md), and what each suite catches is
written down in [docs/testing.md](docs/testing.md).

**Everything in this repository is written in English**: commit messages, issues,
PRs, code comments, `docs/`. The README is the one exception, translated per
language.

Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
