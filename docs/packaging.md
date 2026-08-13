# Packaging

cue-dev ships to Claude Code. This page records what that requires and why the
repository is laid out the way it is.

## The manifest and the marketplace

| | |
|---|---|
| manifest | `plugins/cue-dev/.claude-plugin/plugin.json` |
| hook registration | `hooks/hooks.json` (discovered) |
| distribution | `.claude-plugin/marketplace.json` at the repository root |

The two version numbers (the manifest and `marketplace.json`) are kept in step by
`.version-bump.json`, and `tests/cue-dev/test-plugin-infra.sh` fails if they
drift.

**An earlier tree shipped to a second harness as well, from the same skills and
the same scripts.** That path is not in this release: nothing in it was ever run
against a real install of that harness, and a packaging failure of that kind is
silent — an absent directory and every script call dying at once on the user's
first command. Shipping one harness that has been exercised is the honest scope.
What remains from that work is the layout below, which is kept for a reason of its
own.

## Why the scripts live under a skill

Every script sits at `skills/using-cue/scripts/` and rides along inside `skills/`.
`using-cue` is their home because it is the skill that gives `<cue>` a value — the
skills themselves write `<cue>/gate`, never a path, and `hooks/session-start`
substitutes the real directory once per session.

**One token means one directory, and that is the load-bearing part.** It was not
true for a while: three scripts — `sdd-workspace`, `task-brief` and
`review-package` — stayed behind at `skills/implement/scripts/`, which installs
fine and was therefore never a packaging problem. It was a *reachability* problem.
`<cue>` names one directory, that folder was not it, and `implement`'s harness
binding called them as bare `scripts/task-brief …` — a relative path resolved
against wherever the Bash tool happened to be standing. The first command of every
dispatch loop was `command not found`. A second scripts folder is a token nobody
defined. `test-plugin-infra.sh` now refuses both the folder's return and the bare
call form.

`test-plugin-infra.sh` also refuses any directory at the plugin root outside the
installable set. That is what keeps a later convenience directory from undoing
this quietly.

Moving them cost almost nothing: every script finds its siblings through its own
`$(dirname "$0")`, so not one script body changed.

## The hook

`hooks/hooks.json` registers one `SessionStart` entry. It carries
`"shell": "bash"`, which is how `run-hook.cmd` gets a bash to run on Windows.

The injection is `using-cue` in full, plus the language and scripts directives —
around 1600 tokens.
