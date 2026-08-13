# Security

## What this plugin can do on your machine

Worth knowing before you read the rest, because it decides what counts as a
vulnerability here.

cue-dev is shell scripts and instructions. Installing it means:

- **A `SessionStart` hook runs on every session** (`hooks/session-start`, through
  `hooks/run-hook.cmd` on Windows). It reads files from the plugin directory and
  prints text into the session. It makes no network calls.
- **Its scripts run git commands in the repository you are working in.** They
  create branches and worktrees, commit files under `.cue/dev/`, and — on the
  paths that ask you first — merge, remove worktrees, and reset a branch to a
  recorded commit.
- **Nothing leaves your machine.** No telemetry, no analytics, no outbound
  requests. `tests/cue-dev/test-plugin-infra.sh` fails if `curl`, `wget`, `nc`,
  `ncat` or `telnet` appears in any executable file in the plugin.

The one path that reaches a network is `scripts/integration`, and only when *you*
choose to open a change request: it shells out to `gh`, which uses your own
GitHub credentials.

## Reporting a vulnerability

**Use GitHub's private vulnerability reporting** — the *Security* tab of this
repository, then *Report a vulnerability*. That opens a private thread with the
maintainer; it is not visible to anyone else.

Please do not open a public issue for something that could be exploited before
there is a fix.

There is no published contact address by design. If private reporting is not
available to you for some reason, open a public issue that says only *"security,
need a private channel"* with no details, and a channel will be arranged.

## What to expect

This is a personal project maintained by one person, not a product with an
on-call rotation. A realistic commitment: an acknowledgement within a week, and an
honest answer about whether and when it will be fixed. If it will not be fixed,
you will be told that rather than left waiting.

## Things that are not vulnerabilities here

- **A script running git commands that change your repository.** That is the
  purpose. The interesting question is whether it does so *without asking*, on a
  path documented as asking — that one is a real report.
- **A skill telling Claude to do something you disagree with.** Skills are
  instructions, and instructions are arguable. Open a normal issue.
- **Anything requiring an attacker who already runs code as you.** They have your
  shell; the plugin is not the weak link.
