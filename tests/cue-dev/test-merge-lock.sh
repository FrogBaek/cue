#!/usr/bin/env bash
# scripts/merge-lock: who owns the main checkout for the length of a merge.
#
# Parallel cue-dev items are safe because each one gets its own worktree, with its
# own HEAD and index. Finish's local merge is the single exception: it leaves the
# worktree, takes over the main checkout and runs the tests there.
#
# scripts/branch-holder was written for that collision and does not cover it — it
# asks whether *another worktree* holds the landing branch, and in the ordinary
# layout none does, because the landing branch lives in the main checkout, which is
# where every merging session goes. Both sessions get "checked out here" and both
# proceed into the same working tree. git serializes each command; nothing
# serializes the sequence. This script is what does.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCK="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/merge-lock"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

TEST_ROOT=$(mktemp -d)
trap cleanup EXIT

echo "=== Test: scripts/merge-lock ==="

new_repo main

# --- free -------------------------------------------------------------------
rc=0; out=$("$LOCK" --status) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"free"* ]]; then
    pass "an untouched repository reports the lock free"
else
    fail "an untouched repository reports the lock free" "exit: $rc, out: $out"
fi

# --- acquire ----------------------------------------------------------------
rc=0; out=$("$LOCK" --acquire K1) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"acquired by K1"* ]]; then
    pass "the first item takes the lock"
else
    fail "the first item takes the lock" "exit: $rc, out: $out"
fi

# --- the whole point --------------------------------------------------------
#
# The second item must be refused, and the refusal must name who has it. "Held"
# with no holder sends the next session looking through .git by hand.
rc=0; out=$("$LOCK" --acquire K2) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"K1"* ]] && [[ "$out" == *"held"* ]]; then
    pass "a second item is refused and told who holds it"
else
    fail "a second item is refused and told who holds it" "exit: $rc, out: $out"
fi

# --- re-entrant for its owner -----------------------------------------------
#
# finish stamps no marker and is repeatable by design, so a merge whose tests
# failed is expected to be run again from the same item. Deadlocking against its
# own first attempt would make the retry impossible.
rc=0; out=$("$LOCK" --acquire K1) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"already held by K1"* ]]; then
    pass "the holder may acquire its own lock again"
else
    fail "the holder may acquire its own lock again" "exit: $rc, out: $out"
fi

# --- release is owner-only --------------------------------------------------
#
# A release that any KEY could call is not mutual exclusion: the session that lost
# the race would clear the lock and walk into the merge it was refused.
rc=0; out=$("$LOCK" --release K2) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"not yours"* ]]; then
    pass "a non-owner cannot release the lock"
else
    fail "a non-owner cannot release the lock" "exit: $rc, out: $out"
fi

rc=0; out=$("$LOCK" --status) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"held"* ]] && [[ "$out" == *"K1"* ]]; then
    pass "the refused release left the lock where it was"
else
    fail "the refused release left the lock where it was" "exit: $rc, out: $out"
fi

# --- release ----------------------------------------------------------------
rc=0; out=$("$LOCK" --release K1) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"released by K1"* ]]; then
    pass "the owner releases it"
else
    fail "the owner releases it" "exit: $rc, out: $out"
fi

rc=0; out=$("$LOCK" --acquire K2) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"acquired by K2"* ]]; then
    pass "the next item can take it once released"
else
    fail "the next item can take it once released" "exit: $rc, out: $out"
fi

# --- releasing a free lock is not an error ----------------------------------
#
# Step 9 releases on the failure path too, and a release that failed when there
# was nothing to release would turn "the tests went red" into two problems.
"$LOCK" --release K2 >/dev/null
rc=0; out=$("$LOCK" --release K2) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"already free"* ]]; then
    pass "releasing an unheld lock succeeds"
else
    fail "releasing an unheld lock succeeds" "exit: $rc, out: $out"
fi

# --- the lock is shared across worktrees ------------------------------------
#
# This is the property the whole thing rests on. Each worktree has its own HEAD,
# index and .git file, so a lock kept anywhere per-worktree would be invisible to
# the session it exists to stop. It lives in the common git dir.
git worktree add -q "$TEST_ROOT/wt" -b work-K3 main
"$LOCK" --acquire K1 >/dev/null
rc=0; out=$(cd "$TEST_ROOT/wt" && "$LOCK" --acquire K3) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"K1"* ]]; then
    pass "a linked worktree sees the main checkout's lock"
else
    fail "a linked worktree sees the main checkout's lock" "exit: $rc, out: $out"
fi

# --- stale ------------------------------------------------------------------
#
# It is never stolen automatically: a forty-minute test suite and a dead session
# look identical from here, and guessing wrong puts two merges in one checkout. So
# an old lock still refuses — it just says how old, and names the way out.
COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
printf 'key=K1\nworktree=/somewhere\nsince=%s\n' "$(( $(date +%s) - 7200 ))" \
    > "$COMMON/cue-dev-merge.lock/holder"
rc=0; out=$("$LOCK" --acquire K2) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"stale"* ]] && [[ "$out" == *"--break"* ]]; then
    pass "a stale lock still refuses, and names --break"
else
    fail "a stale lock still refuses, and names --break" "exit: $rc, out: $out"
fi

rc=0; out=$("$LOCK" --break) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"K1"* ]]; then
    pass "--break removes it and says whose it was"
else
    fail "--break removes it and says whose it was" "exit: $rc, out: $out"
fi

rc=0; out=$("$LOCK" --acquire K2) || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "the lock is takeable after a break"
else
    fail "the lock is takeable after a break" "exit: $rc, out: $out"
fi
"$LOCK" --release K2 >/dev/null

# --- a half-written lock is held, not free ----------------------------------
#
# mkdir won and the write did not. Reading that as free decides a race in favour
# of whoever arrived second.
mkdir "$COMMON/cue-dev-merge.lock"
rc=0; out=$("$LOCK" --acquire K1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"unknown"* ]]; then
    pass "a lock directory with no holder file is held by an unknown owner"
else
    fail "a lock directory with no holder file is held by an unknown owner" "exit: $rc, out: $out"
fi
"$LOCK" --break >/dev/null

# --- usage ------------------------------------------------------------------
for bad in "" "--acquire" "--status K1" "--nonsense"; do
    rc=0
    # shellcheck disable=SC2086
    out=$("$LOCK" $bad 2>&1) || rc=$?
    if [ "$rc" -eq 2 ]; then
        pass "usage error: '${bad:-<no arguments>}'"
    else
        fail "usage error: '${bad:-<no arguments>}'" "exit: $rc, out: $out"
    fi
done

finish
