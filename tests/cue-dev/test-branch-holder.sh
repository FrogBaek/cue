#!/usr/bin/env bash
# scripts/branch-holder: which worktree, if any, has a branch checked out.
#
# Parallel cue-dev sessions are safe because each item gets its own worktree, with
# its own HEAD and index. Exactly one path breaks that symmetry — finish's Step 9
# merge, which returns to the main checkout, checks out the landing branch there
# and runs the tests.
#
# What this script covers is the case git itself would refuse: another worktree
# already holds the landing branch. git says so only when the checkout runs, which
# is after the worktree has been left, so the failure looks like a broken tool
# rather than like another session working.
#
# What it does *not* cover is two sessions merging at once — in the ordinary layout
# the landing branch lives in the main checkout, so both get "checked out here" and
# both proceed. That is scripts/merge-lock's job, and Step 9 runs both.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOLDER="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/branch-holder"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

TEST_ROOT=$(mktemp -d)
trap cleanup EXIT

echo "=== Test: scripts/branch-holder ==="

new_repo main
MAIN_REPO=$PWD
git branch feature-a
git branch feature-b

# --- free -------------------------------------------------------------------
rc=0; out=$("$HOLDER" feature-a) || rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    pass "a branch no worktree holds is free, and says nothing"
else
    fail "a branch no worktree holds is free, and says nothing" "exit: $rc, out: $out"
fi

# --- held here --------------------------------------------------------------
#
# The branch you are standing on is not a collision. Reporting it as one would
# stop every merge, since finish reaches this check from the checkout it is about
# to merge in.
rc=0; out=$("$HOLDER" main) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"checked out here"* ]]; then
    pass "the branch checked out here is not a collision"
else
    fail "the branch checked out here is not a collision" "exit: $rc, out: $out"
fi

# --- held elsewhere ---------------------------------------------------------
WT="$TEST_ROOT/other-workspace"
git worktree add -q "$WT" feature-b

rc=0; out=$("$HOLDER" feature-b) || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "a branch another worktree holds exits 1"
else
    fail "a branch another worktree holds exits 1" "exit: $rc, out: $out"
fi

if [[ "$out" == *"other-workspace"* ]]; then
    pass "it names the workspace holding it"
else
    fail "it names the workspace holding it" "got: $out"
fi

# The path is normalized before comparison. `git worktree list` prints `D:/repo`
# on Windows while `pwd -P` gives `/d/repo`, and comparing the raw forms reports
# "another worktree" about the directory you are standing in.
cd "$WT"
rc=0; out=$("$HOLDER" feature-b) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"checked out here"* ]]; then
    pass "from inside that worktree, the same branch is 'here', not 'elsewhere'"
else
    fail "from inside that worktree, the same branch is 'here', not 'elsewhere'" \
        "exit: $rc, out: $out"
fi

# And the reverse: from the linked worktree, the main checkout's branch is the
# one held elsewhere.
rc=0; out=$("$HOLDER" main) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"another worktree"* ]]; then
    pass "the main checkout's branch is reported from the worktree side too"
else
    fail "the main checkout's branch is reported from the worktree side too" \
        "exit: $rc, out: $out"
fi
cd "$MAIN_REPO"

# --- refs/heads/ prefix is accepted ------------------------------------------
rc=0; out=$("$HOLDER" refs/heads/feature-b) || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "a fully qualified ref names the same branch"
else
    fail "a fully qualified ref names the same branch" "exit: $rc, out: $out"
fi

# --- usage ------------------------------------------------------------------
rc=0; "$HOLDER" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "exit 2 with no argument"
else
    fail "exit 2 with no argument" "exit: $rc"
fi

finish
