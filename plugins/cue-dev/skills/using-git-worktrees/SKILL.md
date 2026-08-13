---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or git worktree fallback
user-invocable: false
---

# Using Git Worktrees

**Speak the repository's language.** `.cue/dev/config`'s `language` decides what
you write to the user, and the session hook states it at the top of every session
— this skill runs no cue-dev script that repeats it. This skill body is English
because it is the plugin's source, not because it is your output. Paths, branch
names, code and commands stay exactly as written.

## Overview

Ensure work happens in an isolated workspace, cut with git and worked in by path.

**Core principle:** Detect existing isolation first. Then cut the worktree with
`git worktree add` at a path a script chose, and work in it with `git -C <path>`.
Nothing is handed to a harness worktree tool — not because harness tools are bad,
but because the one this plugin can use gives back less than it takes.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Submodule guard:** `GIT_DIR != GIT_COMMON` is also true inside git submodules. Before concluding "already in a worktree," verify you are not in a submodule:

```bash
# If this returns a path, you're in a submodule, not a worktree — treat as normal repo
git rev-parse --show-superproject-working-tree 2>/dev/null
```

**If `GIT_DIR != GIT_COMMON` (and not a submodule):** You are already in a linked worktree. Skip to Step 2 (Project Setup). Do NOT create another worktree.

Report with branch state:
- On a branch: "Already in isolated workspace at `<path>` on branch `<name>`."
- Detached HEAD: "Already in isolated workspace at `<path>` (detached HEAD, externally managed). Branch creation needed at finish time."

**If `GIT_DIR == GIT_COMMON` (or in a submodule):** You are in a normal repo checkout.

Has the user already indicated their worktree preference in your instructions? If not, ask for consent before creating a worktree:

> "Would you like me to set up an isolated worktree? It protects your current branch from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

### 1a. Why not the harness's worktree tool

**cue-dev used to hand the finished worktree to `EnterWorktree`, and no longer
does.** The reasoning is worth keeping, because the tool is genuinely good and
"never bypass the native tool" is genuinely the right instinct in most plugins.

A native tool normally owns three things: **placement, the session, and cleanup.**
Owning all three is what makes bypassing it a mistake — `git worktree add` behind
its back leaves phantom state it cannot see. But cue-dev could only ever have the
middle one:

- **Placement.** `EnterWorktree` takes a name or a path — never a start point.
  Where the branch is cut from comes from the user's `worktree.baseRef` setting,
  `origin/<default-branch>` by default. An item that recorded "cut this from
  `develop`" gets `origin/main` instead, silently, and the wrongness surfaces at
  the merge. cue-dev has a recorded start point for every item, so this was never
  available.
- **Cleanup.** The tool's own contract says it: *"ExitWorktree will not remove a
  worktree entered this way; use `action: "keep"`."* A worktree handed over by
  path is one it keeps. Removal was always going to be cue-dev's.
- **The session.** This it really does own, and it is real: the working directory
  moves, so commands can be typed without `-C`.

So the trade was eight harness-coupled call sites for one convenience, in a plugin
whose work items outlive sessions and which is meant to run on more than one
harness. It is not worth it. **Cut with git, work by path.**

#### Directory Selection

**Do not choose. Ask.**

```bash
<cue>/work-path --propose <KEY>
```

`<repo-root>/.worktrees/<KEY>`, hidden, under the main checkout. A real session
picked `.cue/worktrees/<KEY>` instead — a path named nowhere in this plugin — and
finish-cleanup, matching it against the locations it knew, fell through to a
default that declared it someone else's problem. **The defence against an invented
path is not a firmer instruction; it is having nothing left to invent.**

#### Safety Verification

**MUST verify the directory is ignored before creating a worktree:**

```bash
git check-ignore -q .worktrees
```

**If NOT ignored:** add it to .gitignore, commit that, then proceed.
`<cue>/init-check` reports this too, at the point a repository is set up.

**Why critical:** an unignored worktree directory commits the whole tree into the
repository.

#### Create the Worktree

```bash
git worktree add <the proposed path> -b <branch> <start point>
```

**`<start point>` is not optional when your caller gave you one.** Omit it and git
branches from whatever is checked out right now, which is only correct by
accident. `cue-dev:start` passes the item's recorded start point; if you were
invoked without one, branch from the current HEAD and **say so** — a start point
nobody chose is a fact the caller needs, not a detail to swallow.

### 1b. Working in it

**Every command names the path.**

```bash
git -C <path> status
```

The shell's working directory resets between tool calls, so there is no `cd` that
holds. **A forgotten `-C` edits the main checkout** — that is the price of not
handing the session to the harness, it is real, and it is paid by never typing the
path from memory: `<cue>/work-path <KEY>` prints it, and `<cue>/status` names it
when you are standing somewhere else.

**`-C` only redirects git.** Anything else that reads the checkout it is standing
in — cue-dev's own scripts included — needs a subshell:

```bash
(cd <path> && <cue>/work-init <KEY>)
```

**Sandbox fallback:** if `git worktree add` fails with a permission error (sandbox
denial), tell the user the sandbox blocked worktree creation and that you are
working in the current directory instead. Then run setup and baseline tests in
place, and record no worktree line — `work-path --line` refuses here, correctly.

## Step 2: Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

## Step 3: Verify Clean Baseline

Run tests to ensure workspace starts clean:

```bash
# Use project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in linked worktree | Skip creation (Step 0) |
| In a submodule | Treat as normal repo (Step 0 guard) |
| Need a path | `work-path --propose <KEY>` — never pick one |
| A harness worktree tool exists | Do not use it (Step 1a says why) |
| Creating | `git worktree add <path> -b <branch> <start point>` |
| Working in it | `git -C <path> …`, every time |
| Directory not ignored | Add to .gitignore + commit |
| Permission error on create | Sandbox fallback, work in place, record no worktree |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a worktree — no need to check" | Run Step 0. Harness-created isolation and submodules both fool eyeballing; the detection commands settle it. |
| "There's a native worktree tool, so use it" | It takes no start point and will not remove what it was handed, so it can own neither the base nor the cleanup — only the session's working directory. Step 1a has the full accounting. |
| "The native tool will branch from the right place" | It branches from where its own setting says (`worktree.baseRef`: `origin/<default>` or local HEAD), not from the start point this item recorded. |
| "The worktree directory is surely ignored already" | Run `git check-ignore`. An unignored worktree directory commits the whole tree into the repo. |
| "A start point is optional — git picks a sensible one" | git picks HEAD, which is sensible only if HEAD is what you meant. Branch from the base your caller named, or report that you branched from HEAD because nobody named one. |
| "I'll pick a sensible directory name" | `work-path --propose` picks it. A session that picked its own put the worktree where no cleanup rule could find it, and five separate symptoms came out of that one choice. |
| "I `cd`'d into the worktree, so I can drop the `-C`" | The working directory resets between tool calls. Without `-C` the next command edits the main checkout, and nothing says so until the diff looks wrong. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
