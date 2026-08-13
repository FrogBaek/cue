# Changelog

Notable changes to cue-dev. Versions follow [semantic versioning](https://semver.org),
and the version lives in `plugins/cue-dev/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` — `tools/bump-version.sh` keeps the two in step.

## 0.1.0 — 2026-08-13

The first release. cue-dev walks one unit of work through five stages — demand,
design, plan, implement, finish — and commits the record of each into
`.cue/dev/<KEY>/` on the same branch as the code.

**What is here**

- Five stage commands (`start` · `design` · `plan` · `implement` · `finish`),
  each with a human checkpoint, plus `init`, `status` and `redo`.
- Stage detection from git commit markers rather than session state, so work
  started today can be finished next week, in another session, by another model.
- Deterministic scripts behind every question of fact: what stage this item
  reached, where it was cut from, what the records are missing, what a rewind
  would discard, whether a backup can be walked back to.
- 32 test suites over those scripts and over the contracts the skills state,
  run on Linux, macOS and Windows.

**Scope, stated honestly**

Every stage in this release has been run end to end against a real repository,
seven times, and the defects those runs found are fixed. Three paths have *not*
been exercised that way and are shipped anyway, because removing them would be
removing a repair rather than a defect:

- opening a change request through `gh`, and the "already landed" detection that
  depends on it — the local merge is the exercised path;
- picking up an item whose work landed outside cue-dev;
- the `independent-review` check level, which dispatches subagents.
  `/cue-dev:start` says so where the choice is made, and `self-review` is the
  path with mileage on it.

**Not included**

An explanation-page generator and a second harness's packaging were built and
then cut before release: neither had been verified in the way the rest was.
