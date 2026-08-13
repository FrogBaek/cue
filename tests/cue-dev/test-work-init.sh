#!/usr/bin/env bash
# scripts/work-init: creates the work directory and never overwrites existing work.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/work-init"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/work-init ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

new_repo main

KEY=2026-07-31-session-ttl

# --- normal creation ---
out=$(bash "$INIT" "$KEY")
if [ -d ".cue/dev/$KEY" ]; then
    pass "creates the work directory"
else
    fail "creates the work directory"
fi

# The contract is that the first line is the path alone. Adding an isolation line
# below it must not shake that.
if [ "$(printf '%s\n' "$out" | head -1)" = "$(pwd)/.cue/dev/$KEY" ]; then
    pass "prints the created path on the first line"
else
    fail "prints the created path on the first line" "got: $out" "want: $(pwd)/.cue/dev/$KEY"
fi

# --- it determines isolation itself ---
# In a real session no worktree was created and nobody mentioned it. If isolation
# depended on a person remembering to report it, "did not say" and "is isolated"
# would be indistinguishable.
if [[ "$out" == *"isolation  none — main checkout"* ]]; then
    pass "states there is no isolation in the main checkout"
else
    fail "states there is no isolation in the main checkout" "got: $out"
fi

MAIN_REPO=$(pwd)
git worktree add -q "$TEST_ROOT/wt-iso" -b iso-feature
cd "$TEST_ROOT/wt-iso"
out=$(bash "$INIT" WT-1)
if [[ "$out" == *"isolation  worktree ("* ]]; then
    pass "reports a linked worktree as a worktree"
else
    fail "reports a linked worktree as a worktree" "got: $out"
fi

if [[ "$(printf '%s\n' "$out" | head -1)" == "$TEST_ROOT/wt-iso/.cue/dev/WT-1" ]]; then
    pass "inside a worktree it creates the work directory on the worktree side"
else
    fail "inside a worktree it creates the work directory on the worktree side" "got: $out"
fi
cd "$MAIN_REPO"

# --- the branch line reports and does not judge ---
#
# cue-dev requires nothing of a branch name. It used to require the KEY to appear
# in it, because that was how the KEY was recovered later; the name is recorded in
# the item's demand.md now, so the requirement is gone rather than relaxed and the
# verdict with it. Whatever git says is the whole line.
for name in "cue-dev/BR-1" "worktree-cue-dev+BR-2" "feat/add-hello-world-test"; do
    key="K-${name//[^A-Za-z0-9]/}"
    git checkout -q -b "$name"
    out=$(bash "$INIT" "$key")
    line=$(printf '%s\n' "$out" | grep '^branch ')
    if [ "$line" = "branch  $name" ]; then
        pass "the branch line is the name and nothing else: $name"
    else
        fail "the branch line is the name and nothing else: $name" "got: $line"
    fi
    if [[ "$out" == *WARNING* ]]; then
        fail "a branch name is never warned about: $name" "got: $out"
    else
        pass "a branch name is never warned about: $name"
    fi
    git checkout -q main
done

# --- the parallel-work signal ---
#
# Separate worktrees are what makes two sessions safe: separate HEAD, separate
# index. A shared checkout is the unsafe shape, because redo's `git reset --hard`
# there rewinds whatever else is being edited in that directory. cue-dev cannot
# see other sessions, so it reports the observable half — an item starting
# unisolated in a repository that has worktrees.
#
# The worktree from the isolation section above is still registered here.
out=$(bash "$INIT" PAR-1)
if [[ "$out" == *"workspace  shared checkout"* ]]; then
    pass "an unisolated start alongside a worktree says so"
else
    fail "an unisolated start alongside a worktree says so" "got: $out"
fi

if [[ "$out" == *"redo here rewinds"* ]]; then
    pass "it names the cost rather than just the situation"
else
    fail "it names the cost rather than just the situation" "got: $out"
fi

# Inside a worktree there is nothing to say: that is the safe shape, and a line
# printed on every run is a line that stops being read.
cd "$TEST_ROOT/wt-iso"
out=$(bash "$INIT" PAR-2)
if [[ "$out" == *"workspace"* ]]; then
    fail "an isolated start is silent about the workspace" "got: $out"
else
    pass "an isolated start is silent about the workspace"
fi
cd "$MAIN_REPO"

# Nor is there anything to say in a repository with no worktrees at all, which is
# the solo case and by far the common one.
new_repo main
out=$(bash "$INIT" SOLO-1)
if [[ "$out" == *"workspace"* ]]; then
    fail "a repository with no worktrees is silent about the workspace" "got: $out"
else
    pass "a repository with no worktrees is silent about the workspace"
fi
cd "$MAIN_REPO"

# --- a second run is refused ---
rc=0
out=$(bash "$INIT" "$KEY" 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"work already exists"* ]]; then
    pass "exit 1 when starting again with the same KEY"
else
    fail "exit 1 when starting again with the same KEY" "exit: $rc" "$out"
fi

if [[ "$out" == *"scripts/redo demand"* ]]; then
    pass "it explains how to rewind"
else
    fail "it explains how to rewind" "$out"
fi

# --- it never touches existing artifacts ---
printf 'the original requirement\n' > ".cue/dev/$KEY/demand.md"
bash "$INIT" "$KEY" >/dev/null 2>&1 || true
if [ "$(cat ".cue/dev/$KEY/demand.md")" = "the original requirement" ]; then
    pass "refusing does not overwrite existing files"
else
    fail "refusing does not overwrite existing files"
fi

# --- KEYs that are unsafe on the filesystem ---
for bad in "a/b" "a\\b" "sp ace" "" "." ".."; do
    rc=0
    bash "$INIT" "$bad" >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq 2 ]; then
        pass "rejects an unsafe KEY: '$bad'"
    else
        fail "rejects an unsafe KEY: '$bad'" "exit: $rc"
    fi
done

# --- ticket keys and date slugs pass through unchanged ---
for good in "PROJ-142" "2026-08-01-other-work" "ABC_9"; do
    rc=0
    bash "$INIT" "$good" >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq 0 ] && [ -d ".cue/dev/$good" ]; then
        pass "does not validate the format: '$good'"
    else
        fail "does not validate the format: '$good'" "exit: $rc"
    fi
done

# --- --check creates nothing ---
rc=0
bash "$INIT" --check FRESH-1 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && [ ! -d ".cue/dev/FRESH-1" ]; then
    pass "--check only judges and creates nothing"
else
    fail "--check only judges and creates nothing" "exit: $rc"
fi

rc=0
bash "$INIT" --check "$KEY" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "--check also exits 1 on existing work"
else
    fail "--check also exits 1 on existing work" "exit: $rc"
fi

rc=0
bash "$INIT" --check "a/b" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "--check also exits 2 on an unsafe KEY"
else
    fail "--check also exits 2 on an unsafe KEY" "exit: $rc"
fi

# --- usage errors ---
rc=0
bash "$INIT" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "exit 2 with no arguments"
else
    fail "exit 2 with no arguments" "exit: $rc"
fi

# --- reserved names ---
# Under .cue/dev/ live things belonging to cue-dev itself, not just work
# directories.
#   sdd/    implementation scratch. A KEY of sdd makes the two share one directory,
#           and since the scratch is gitignored, that work's entire record goes
#           uncommitted.
#   config  is a file. A directory of the same name cannot even be created.
new_repo main
for reserved in sdd config; do
    rc=0
    out=$(bash "$INIT" "$reserved" 2>&1) || rc=$?
    if [ "$rc" -eq 2 ] && [[ "$out" == *"reserved"* ]]; then
        pass "rejects a reserved name: $reserved"
    else
        fail "rejects a reserved name: $reserved" "exit: $rc" "$out"
    fi
    if [ -e ".cue/dev/$reserved" ]; then
        fail "creates nothing for a reserved name: $reserved" "it was created"
    else
        pass "creates nothing for a reserved name: $reserved"
    fi
done

# --check must make the same call. Being refused *after* creating a worktree is
# wasted work.
rc=0
bash "$INIT" --check sdd >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "--check also rejects a reserved name"
else
    fail "--check also rejects a reserved name" "exit: $rc"
fi

finish
