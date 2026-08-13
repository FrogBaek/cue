# The branching model

cue-dev supports trunk-based development, GitHub flow, git flow, and fork-based
contribution **without knowing that any of them exist**. There is no workflow
setting and no branch in the code that names one. This document explains how, and
what is deliberately left out.

## The problem it replaces

Settings each did a job they could not do, and each one came apart in a real
workflow.

| Setting | Used to mean | Broke on |
|---|---|---|
| `base_branch` | where work starts **and** where it lands | git flow — a hotfix starts at `main`, a feature at `develop`; no one value is both. In practice nothing read it as a start point at all, so branches came off whatever was checked out. |
| `base_branch`, once it meant the start point alone | the branch *this repository's* work starts from | the second work item — a hotfix off `main` after a feature off `develop` meant rewriting a setting the feature still depended on, and forgetting to put it back cut the next item from the wrong branch, invisibly, until the merge. |
| `remote` | where work is pushed **and** where a PR is proposed | forks — you push to your own fork and propose against the original. Setting it to `upstream` made the push fail. |

Neither fix added a setting. The first gave each one a single job and derived the
third fact instead of storing it. The second moved a value out of the settings
file entirely, into the record of the work item it actually describes.

## The four facts, and where each lives

Four facts decide what a branch is called, where it is cut from, where it lands,
and where it is pushed. They are not four of a kind, and the point of the model is
that each one lives in the only place that can hold it honestly:

| Fact | Lives in |
|---|---|
| start point | a **record** — the item's `.cue/dev/<KEY>/demand.md` header |
| branch name | a **record** — the same header, written from what git reports |
| landing point | **nothing** — derived from git at the moment it is needed |
| `remote` | a **setting** — `.cue/dev/config` |

Only the last one is repository-wide, which is why only the last one is a
setting. What the four share is that none of them names a workflow.

**1. The start point — per work item, recorded.** The branch work is cut from,
and nothing else. `/cue-dev:start` settles it for that item — from the ticket
when the ticket says, otherwise proposed from the branches that exist and
confirmed — and writes it into that item's demand.md header:

```
<!-- base: develop @ 4f311b5 -->
```

Every consumer reads it through `scripts/work-base <KEY>`, so `start` and
`finish` cannot disagree about where a piece of work began.

It is **recorded** rather than **configured** because the answer belongs to the
ticket, not to the repository. It is **recorded** rather than **observed** because
"which branch did this come off" stops having a single answer the moment the
branch exists: `git branch --contains` names every branch that reached that
commit, and the base moves on afterwards. The one moment it is unambiguous is the
moment the branch is cut, so that is when it is written down.

This does not bend the rule that only what cannot be observed goes into settings —
it applies it. `.cue/dev/<KEY>/demand.md` is a record, not a settings file, and it
sits beside the other facts about how this item came to be (`source:`, `origin:`).

**2. The branch name — per work item, recorded, and required of nobody.** cue-dev
asks nothing of it: not a prefix, not the KEY, nothing. `/cue-dev:start` proposes
one — from the ticket, else from the prefixes this repository's branches already
use — and once the workspace exists, `scripts/work-branch --line` asks git what
was actually made and prints the header line for it:

```
<!-- branch: feat/add-hello-world-test -->
```

It is written **after** creation, not from the requested name, because native
worktree tooling renames what it makes: a request for `cue-dev/I18N` came back as
`worktree-cue-dev+I18N`. Recording git's answer turns that from a warning into a
non-event.

This one exists to *remove* a requirement rather than to express a choice.
`status`, `redo`, `backups` and `gate` all need to know which item they are
looking at, and until this line existed they worked it out by matching the branch
name against the directories under `.cue/dev/` — which quietly made "the KEY must
appear in the branch name" a contract, and told a team whose branches are called
`feat/add-hello-world-test` that its work could not be found. An item started
before the line existed is still matched the old way; nothing else is.

**3. The landing point — derived, never stored.** The rule is *work lands where it
came from*, and git can confirm that:

```bash
git merge-base --is-ancestor "$(scripts/work-base "$KEY")" HEAD
```

True, and the recorded start point is the landing branch — no question is asked.
False, and the branch is no longer on what it was cut from; `/cue-dev:finish`
stops and asks. A git-flow hotfix no longer trips this at all: it recorded `main`
at start and lands in `main`, without the word "hotfix" appearing anywhere.

**4. `remote` — the push target.** The pull-request target rides along inside the
item's start point, which may name a remote-tracking ref. `upstream/main` says
both which repository the request goes to and which branch, so a fork needs no
second setting — and because the start point is per item, a fork contribution and
an internal branch can sit in the same checkout.

One prefix does remain a setting, and it is not the work branch's:
`backup_prefix`, the namespace `/cue-dev:redo` puts its backup branches in. That
value is cue-dev's own — it creates those branches and finds them again by
globbing it — so it has to be the same across the repository and stable over time,
which is exactly what a setting is for.

## What each workflow records

Every row runs the same code path. The first column is written per work item, not
once per repository.

| Workflow | start point recorded at `start` | branch name (example) | `remote` | Lands in (derived) |
|---|---|---|---|---|
| trunk-based | `main` | `PROJ-142` | `origin` | `main` |
| GitHub flow | `main` | `feat/session-ttl` | `origin` | `main` |
| git flow — feature | `develop` | `feature/session-ttl` | `origin` | `develop` |
| git flow — hotfix | `main` | `hotfix/session-ttl` | `origin` | `main` — recorded as such, so nothing has to catch it |
| fork / OSS contribution | `upstream/main` | `fix-session-ttl` | `origin` | `main` on `upstream` |
| local only | `main` | anything | (none) | `main` |

The branch-name column is illustrative and nothing enforces it — which is the
point. It is there to show that the second column varies per item in exactly the
way a repository-wide prefix could not express.

## The settings these came out of

`base_branch` and `branch_prefix` are both gone, one release apart and for one
reason. Nothing reads either, `config --set` refuses both, `config --get` answers
each by naming the script that knows (`work-base`, `work-branch`), and
`/cue-dev:init` asks for neither. A repository that still carries either line is
told so through the unrecognized-keys report, because that is what the lines now
are.

The reason is the second work item. A git-flow hotfix comes off `main` and is
called `hotfix/…` while the feature before it came off `develop` and was called
`feature/…`; expressing the second one meant rewriting a value the first still
depended on. The difference between them is only in what a stale value costs —
`base_branch` cut work from the wrong branch and said nothing until the merge,
`branch_prefix` merely proposed a name someone would have to correct. A setting
nothing may safely read is still a setting that should not exist.

There is deliberately no fallback for the start point. An item with no recorded
one is an item `/cue-dev:start` never settled, and the repair is to settle it —
`/cue-dev:redo demand <KEY>`. A repository-wide default standing in would be the
last ticket's answer applied to this one, silently, and the wrongness of it would
not surface until the merge. That is precisely the failure this change exists to
remove, so reintroducing it as a safety net would undo the change.

The branch name is different, and the difference is instructive: there *is* a
fallback there — an item with no `branch:` line is matched by the old substring
rule. That is not a default answering for a missing value. It is the previous
mechanism still serving the items written under it, and it produces the same
answer it always did.

## Resolution

`cue_resolve_base` in `scripts/common` turns a branch name into a ref that
exists, trying in order: a local branch, the configured remote, any remote, then
the value as written. Every caller goes through it — `init-check` when it lists
candidates, `work-base --line` when it records one, `work-base <KEY>` when it
reads one back — so a name `init-check` offers cannot be one `start` then fails
to find.

This is what makes `develop` a legal answer in a freshly cloned git-flow
repository, where the local checkout holds only `main` and `develop` exists as
`origin/develop`. Checking `refs/heads` alone rejected the one value such a
repository needs, and blocked `init` before any work began.

## Not modelled, on purpose

These are not gaps to be filled later. They are outside cue-dev's unit of work.

**Release branches.** The only case where start and landing differ structurally
(cut from `develop`, merged to `main`). A release is not a unit of development
work — it has no requirement, no design, no KEY. It is a process run over work
that cue-dev already finished.

**git flow's double merge** (a hotfix landing in both `main` and `develop`).
Release management, performed after `finish`, not part of building the thing.

**Rebase, squash, and fast-forward policy.** Team policy that cannot be observed
from the repository, and adding a setting for it invites the next policy after it.
The local merge is fixed at `--no-ff` because erasing the fact that a branch
existed contradicts what this tool is for; every other policy lives on the PR
path, where the forge decides.

**Which workflow the team uses.** Never asked, never stored, never branched on. If
a future change starts to want that question, the four facts above have started
doing each other's jobs again — fix that instead of answering it.

## Several items at once

Nothing in the model is repository-global except `remote`, so parallel work needs
no coordination: each item has its own record directory, its own branch and its
own worktree, and separate worktrees have separate HEADs and indexes. Two items
being built at the same time cannot see each other's files, and their records
merge without conflict because they are different directories. git refuses the one
overlap that would matter — the same branch checked out twice.

Two things are worth knowing rather than fixing.

**One checkout, two sessions is the unsafe shape** — not one repository, two
sessions. A shared checkout shares HEAD and the index, and `/cue-dev:redo` there
rewinds whatever else is being edited in that directory. cue-dev cannot see other
sessions, so it says the observable half instead: `work-init` prints a `workspace`
line when an item starts unisolated in a repository that has worktrees.

**finish's `merge` path is the one repository-scope path.** It leaves the worktree, checks
out the landing branch in the main checkout and runs the tests there, so two
sessions reaching it at once interleave. `scripts/branch-holder` is checked first
and names the worktree already holding that branch; serializing the merges is the
user's call, and git's own refusal is the backstop.
