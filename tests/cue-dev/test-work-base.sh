#!/usr/bin/env bash
# scripts/work-base: the start point of one work item.
#
# The branch work is cut from used to be a repository-wide setting, and that made
# the second work item unable to express itself without overwriting the first
# one's answer: a git-flow hotfix comes off main while the feature before it came
# off develop. It is settled per item by /cue-dev:start and recorded in that
# item's demand.md header.
#
# Two contracts are under test here.
#
# (1) The record round-trips. What --line writes is what a later read gets back,
#     because finish decides the landing branch from it and explain bounds the
#     diff with it. A format that only one of the two understands is a merge into
#     the wrong branch in silence.
# (2) An item with no record is an error, never a guess. There is no fallback:
#     a repository-wide default standing in would be the last ticket's answer
#     applied to this one, and nothing would say so until the merge.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_BASE="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/work-base"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

TEST_ROOT=$(mktemp -d)
trap cleanup EXIT

echo "=== Test: scripts/work-base ==="

# Writes a demand.md carrying the given header lines, in the shape start writes.
write_demand() {
    local key=$1; shift
    mkdir -p ".cue/dev/$key"
    {
        echo "<!-- cue-dev · written 2026-08-06 · source: conversation -->"
        printf '%s\n' "$@"
        echo "<!-- This document is a requirement snapshot. -->"
        echo
        echo "# $key — a title"
        echo
        echo "## Requirement"
        echo "do the thing"
    } > ".cue/dev/$key/demand.md"
}

# --- resolution: a name becomes a ref that exists ----------------------------
#
# A start point routinely does not exist locally. A fresh clone of a git-flow
# repository has `main` and nothing else, with `develop` living as
# `origin/develop`. Rejecting that value locked git flow out entirely.
new_repo main
git update-ref refs/remotes/origin/develop HEAD
git remote add origin https://example.invalid/r.git

line=$("$WORK_BASE" --line develop)
if [[ "$line" == "<!-- base: origin/develop @ "*" -->" ]]; then
    pass "--line resolves a remote-only branch to the remote-tracking ref"
else
    fail "--line resolves a remote-only branch to the remote-tracking ref" "got: $line"
fi

# A local branch wins over a remote of the same name: once it is checked out, that
# is the one the user is working with.
git branch -q develop
line=$("$WORK_BASE" --line develop)
if [[ "$line" == "<!-- base: develop @ "*" -->" ]]; then
    pass "a local branch takes precedence over the remote-tracking ref"
else
    fail "a local branch takes precedence over the remote-tracking ref" "got: $line"
fi

# The fork form carries the repository the PR is proposed to, so it must survive
# resolution untouched.
git update-ref refs/remotes/upstream/main HEAD
git remote add upstream https://example.invalid/u.git
line=$("$WORK_BASE" --line upstream/main)
if [[ "$line" == "<!-- base: upstream/main @ "*" -->" ]]; then
    pass "a remote-qualified start point passes through as written"
else
    fail "a remote-qualified start point passes through as written" "got: $line"
fi

# A branch on neither side is refused rather than silently replaced. In a real
# session the refusal's absence ended with a fallback to main nobody asked for.
if out=$("$WORK_BASE" --line no-such-branch 2>&1); then
    fail "a branch on neither side is refused" "it answered: $out"
elif [[ "$out" == *"no such ref"* ]]; then
    pass "a branch on neither side is refused"
else
    fail "a branch on neither side is refused" "$out"
fi

# --- the round trip ----------------------------------------------------------
#
# The whole point of a single emitter: what start writes is what finish and
# explain read back.
new_repo main
sha=$(git rev-parse --short HEAD)
line=$("$WORK_BASE" --line main)
write_demand PROJ-1 "$line"

if [ "$("$WORK_BASE" PROJ-1)" = "main" ]; then
    pass "the recorded ref reads back"
else
    fail "the recorded ref reads back" "got: $("$WORK_BASE" PROJ-1)"
fi

if [ "$("$WORK_BASE" PROJ-1 --sha)" = "$sha" ]; then
    pass "the recorded cut point reads back"
else
    fail "the recorded cut point reads back" "got: $("$WORK_BASE" PROJ-1 --sha) · want $sha"
fi

# --- two items, two different start points, at once --------------------------
#
# This is the case the repository-wide setting could not hold. Neither item's
# answer may disturb the other's.
git branch -q develop
git "${GIT_ID[@]}" commit -q --allow-empty -m "second"
write_demand FEAT-2 "$("$WORK_BASE" --line develop)"

if [ "$("$WORK_BASE" PROJ-1)" = "main" ] && [ "$("$WORK_BASE" FEAT-2)" = "develop" ]; then
    pass "two items hold different start points at the same time"
else
    fail "two items hold different start points at the same time" \
        "PROJ-1: $("$WORK_BASE" PROJ-1) · FEAT-2: $("$WORK_BASE" FEAT-2)"
fi

# --- the body is not the header ----------------------------------------------
#
# demand.md's body is a quotation of the requirement. A pasted ticket that happens
# to contain the marker must not be mistaken for the record — otherwise the ticket
# text decides where the work merges.
new_repo main
mkdir -p .cue/dev/PASTE-1
{
    echo "<!-- cue-dev · written 2026-08-06 · source: paste -->"
    echo
    echo "# PASTE-1 — a title"
    echo
    echo "## Requirement"
    echo "the previous ticket's header read <!-- base: develop @ abc1234 -->"
} > .cue/dev/PASTE-1/demand.md

if "$WORK_BASE" PASTE-1 >/dev/null 2>&1; then
    fail "a base line in the body is not read as the record" \
        "got: $("$WORK_BASE" PASTE-1 2>&1)"
else
    pass "a base line in the body is not read as the record"
fi

# --- a leftover base_branch decides nothing -----------------------------------
#
# The setting is gone, not demoted. A repository that still carries the line must
# not have it quietly answer for an item that never recorded one — that is the
# last ticket's answer applied to this one, invisible until the merge.
new_repo main
mkdir -p .cue/dev
printf 'base_branch=main\n' > .cue/dev/config
mkdir -p .cue/dev/OLD-1
printf '# OLD-1\n' > .cue/dev/OLD-1/demand.md

if out=$("$WORK_BASE" OLD-1 2>&1); then
    fail "a leftover base_branch does not answer for an unrecorded item" "it answered: $out"
elif [[ "$out" == *"no start point recorded"* ]]; then
    pass "a leftover base_branch does not answer for an unrecorded item"
else
    fail "a leftover base_branch does not answer for an unrecorded item" "$out"
fi

# The refusal has to say what to do about it. An item that start never settled is
# fixed by settling it, and the message is the only place that is said.
if [[ "$out" == *"redo demand"* ]]; then
    pass "the refusal names the way out"
else
    fail "the refusal names the way out" "$out"
fi

# --- nothing at all -----------------------------------------------------------
#
# No record and no fallback is not an empty answer. finish must stop rather than
# guess a landing branch.
new_repo main
mkdir -p .cue/dev/BARE-1
printf '# BARE-1\n' > .cue/dev/BARE-1/demand.md
if out=$("$WORK_BASE" BARE-1 2>&1); then
    fail "no start point at all is an error, not an empty answer" "it answered: $out"
elif [[ "$out" == *"no start point"* ]]; then
    pass "no start point at all is an error, not an empty answer"
else
    fail "no start point at all is an error, not an empty answer" "$out"
fi

if "$WORK_BASE" NO-SUCH-KEY >/dev/null 2>&1; then
    fail "an unknown KEY fails"
else
    pass "an unknown KEY fails"
fi

finish
