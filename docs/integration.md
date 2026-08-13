# Where work goes

`/cue-dev:start` abstracted "where does the work come from" into one line of
`demand.md`, and every stage reads it from there rather than asking again. This
page is about the other end, which took longer to get right.

## What finish requires, and what it does not

Five things are cue-dev's and are enforced on every path:

1. the suite runs on the tree being integrated
2. every task has a recorded outcome row
3. the `outcome` marker is stamped
4. the landing point is derived from the record and checked against git
5. the workspace is reclaimed

**The integration act itself is not one of them.** A repository proposes work
through a pull request, or a merge request, or a patch on a mailing list, or not
at all. That belongs to the repository, and `scripts/integration` is where it is
answered.

## Why there is no menu in the skill any more

There used to be four options written out in `finish/SKILL.md`:

```
1. Push and create a Pull Request
2. Keep the branch, clean up the worktree
3. Merge into <base-branch> locally
4. Keep both the branch and the worktree
```

Two things were wrong with it, and the second is the one that mattered.

**It was shaped like GitHub.** Option 1 named a GitHub artifact. A GitLab
repository got the same menu with a footnote, and a repository whose work goes out
by mail got no expressible answer at all.

**It was a flattening the skill knew about.** The paragraph directly above that
menu said two independent questions decided it — where the work goes, and whether
the worktree stays — and then listed their product as four rows. Adding merge
requests makes it six rows. Adding Gerrit makes it eight. Nothing in the skill
would have told you which of the eight were real.

Now the two questions are asked as two questions, and the first one's options come
from `scripts/integration`.

## The adapter

`integration` answers one thing: **how a change request is opened here.**

| value | meaning |
|---|---|
| `github` | `gh` opens the pull request, and can be asked whether it merged |
| `git` | there is a remote; cue-dev pushes, and the request is opened outside it |
| `none` | no change-request path from here |

**Merging into the landing branch is deliberately not an adapter concern.** It is
plain git, it needs no forge, and `scripts/integration` prints it under every
adapter including `none`. Folding it in would have made "merge locally" a feature
of having a GitHub remote.

**The value is observed, not stored.** No remote is `none`; a GitHub remote *with
`gh` actually on PATH* is `github`; any other remote is `git`. That second
condition is the one worth keeping: claiming `github` from the URL alone puts an
option in the menu that dies on the command that would carry it out, one step
after the user chose it.

It is still a setting, because observation is blind to exactly one shape — a
repository whose requests go somewhere other than the remote it pushes to. A
GitHub mirror of a Gerrit project pushes to GitHub and proposes nothing there.
`config --set integration none` is how that repository says so.

## Has it landed?

`integration --landed <KEY>` answers `yes`, `no` or `unknown`, and the third value
is why this is a script rather than a paragraph in the skill.

`git merge-base --is-ancestor` **proves a merge commit and disproves nothing.**
GitHub's squash button rewrites the commits, so a branch that landed an hour ago
has no ancestry in its base and reads exactly like a branch that never went in. A
controller computing this in prose would report "not landed" for the most common
way work lands, and then offer to integrate something already integrated.

So the adapter answers it:

- `github` — ask `gh` about the request. It tracks the request, not the commits, so
  it survives a squash or a rebase.
- `git` — try ancestry. On a miss, say `unknown`, say why, and say explicitly that
  this must not be reported as not landed.
- `none` — try ancestry. On a miss, `no` is honest: there is no forge that could
  have rewritten anything.

## Finish repeats

`scripts/gate` allows `finish` every time — it stamps no marker, and that was
already true before any of this. What was missing was a reason to run it twice.

Now there is one. Propose the work on Monday; the request lands on Thursday; run
`/cue-dev:finish` again and Step 5r reclaims the branch and the workspace. Until
that path existed, the skill said in so many words that there was no stage after
finish, and the branch and worktree of every proposed item stayed on disk
permanently.

The branch deletion on that path uses `git branch -d`, not `-D`, and its refusal
carries information: after an ordinary merge it will not refuse, and when it does,
the landing was a squash — the same case `--landed` could not settle from git. The
user is asked again before anything is force-deleted, because "did it land" and
"may I drop these commits" are different questions.
