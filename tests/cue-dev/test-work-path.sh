#!/usr/bin/env bash
# scripts/work-path: where one item's worktree is, and where a new one goes.
#
# The third fact to move out of the conversation and into the record. The start
# point went first (7th session), the branch name second (8th), and this one for a
# reason neither of those had: it could not be observed at all. cue_isolation_kind
# answers "am I in a worktree"; nothing answered "where is this item's worktree",
# so the only copy of that path was whatever the session remembered.
#
# A real session remembered `.cue/worktrees/<KEY>` — a location named nowhere in
# this plugin. finish-cleanup matched it against the two locations it knew, fell
# through to a default of `harness`, called for a tool that no-ops on a
# `git worktree add` worktree, then reported `still present` and exited 1. Five
# symptoms, one invented path.
#
# Three contracts are under test.
#
# (1) --propose is the only place a path is chosen, and it chooses the same one
#     every time from the main checkout and from inside a worktree.
# (2) --line is the only place the record is written, and it refuses in the main
#     checkout rather than recording the repository as a worktree to remove.
# (3) A missing record is an answer ("this item has no worktree"), never a gap for
#     something else to fill.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_PATH="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/work-path"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

TEST_ROOT=$(mktemp -d)
trap cleanup EXIT

echo "=== Test: scripts/work-path ==="

run() {
    RC=0
    OUT=$(bash "$WORK_PATH" "$@" 2>&1) || RC=$?
}

write_demand() {  # write_demand <KEY> [<header line> ...]
    local key=$1; shift
    mkdir -p ".cue/dev/$key"
    {
        echo "<!-- cue-dev · written 2026-08-06 · source: conversation -->"
        [ $# -gt 0 ] && printf '%s\n' "$@"
        echo "<!-- This document is a requirement snapshot. -->"
        echo
        echo "# $key — a title"
    } > ".cue/dev/$key/demand.md"
}

new_repo main
MAIN=$(pwd -P)

# --- (1) the path is derived, not chosen -------------------------------------
run --propose PROJ-1
if [ "$RC" -eq 0 ] && [ "$OUT" = "$MAIN/.worktrees/PROJ-1" ]; then
    pass "--propose puts a worktree under .worktrees/<KEY>"
else
    fail "--propose puts a worktree under .worktrees/<KEY>" "exit: $RC" "$OUT"
fi

run --propose PROJ-1
SECOND=$OUT
run --propose PROJ-1
if [ "$OUT" = "$SECOND" ]; then
    pass "the same KEY always proposes the same path"
else
    fail "the same KEY always proposes the same path" "$SECOND vs $OUT"
fi

# It creates nothing. A --propose that made the directory would turn a question
# into a side effect, and the caller would have no way to ask without committing.
if [ ! -d "$MAIN/.worktrees" ]; then
    pass "--propose creates nothing"
else
    fail "--propose creates nothing" "$(ls -d "$MAIN/.worktrees")"
fi

run --propose "a/b"
[ "$RC" -eq 2 ] && pass "--propose refuses a KEY that is unsafe on the filesystem" \
    || fail "--propose refuses a KEY that is unsafe on the filesystem" "exit: $RC" "$OUT"

# --- (2) --line writes only what is true -------------------------------------
run --line
if [ "$RC" -eq 1 ] && [[ "$OUT" == *"main checkout"* ]]; then
    pass "--line refuses in the main checkout"
else
    fail "--line refuses in the main checkout" "exit: $RC" "$OUT"
fi

WT="$MAIN/.worktrees/PROJ-1"
git "${GIT_ID[@]}" worktree add -q "$WT" -b cue-dev/PROJ-1 >/dev/null 2>&1

RC=0
OUT=$(cd "$WT" && bash "$WORK_PATH" --line 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && [ "$OUT" = "<!-- worktree: $WT -->" ]; then
    pass "--line takes the current worktree when given no argument"
else
    fail "--line takes the current worktree when given no argument" "exit: $RC" "$OUT"
fi

# Proposed from inside the worktree, the answer must still be anchored to the main
# checkout — cue_repo_root answers with the worktree's own root in there, which is
# exactly how a nested `.worktrees/.worktrees/` would come about.
RC=0
OUT=$(cd "$WT" && bash "$WORK_PATH" --propose PROJ-2 2>&1) || RC=$?
if [ "$OUT" = "$MAIN/.worktrees/PROJ-2" ]; then
    pass "--propose is anchored to the main checkout, even from inside a worktree"
else
    fail "--propose is anchored to the main checkout, even from inside a worktree" "$OUT"
fi

run --line "$WT"
if [ "$OUT" = "<!-- worktree: $WT -->" ]; then
    pass "--line accepts an explicit path"
else
    fail "--line accepts an explicit path" "$OUT"
fi

run --line "$MAIN/nope"
[ "$RC" -eq 1 ] && pass "--line refuses a path that does not exist" \
    || fail "--line refuses a path that does not exist" "exit: $RC" "$OUT"

# --- (3) reading it back ------------------------------------------------------
write_demand PROJ-1 "<!-- worktree: $WT -->"
run PROJ-1
if [ "$RC" -eq 0 ] && [ "$OUT" = "$WT" ]; then
    pass "the recorded path round-trips"
else
    fail "the recorded path round-trips" "exit: $RC" "$OUT"
fi

run PROJ-1 --show
if [[ "$OUT" =~ worktree[[:space:]]+"$WT" ]]; then
    pass "--show renders it as a notice line"
else
    fail "--show renders it as a notice line" "$OUT"
fi

# An item built in the main checkout. Absent is the answer, and the message says
# so — cue-dev treats a missing line as "no worktree of ours", never as "go and
# find one", because finding one is what produced a five-symptom failure.
write_demand IN-PLACE
run IN-PLACE
if [ "$RC" -eq 1 ] && [[ "$OUT" == *"no worktree recorded"* ]]; then
    pass "an item with no recorded worktree says so rather than guessing"
else
    fail "an item with no recorded worktree says so rather than guessing" "exit: $RC" "$OUT"
fi

# The header stops at the first line that is neither a comment nor blank. A
# `<!-- worktree: -->` inside a pasted ticket is the ticket's text, and letting it
# through would hand finish-cleanup a directory chosen by whoever wrote the ticket.
mkdir -p .cue/dev/BODY
{
    echo "<!-- cue-dev · written 2026-08-06 -->"
    echo
    echo "# BODY — a title"
    echo
    echo "<!-- worktree: $MAIN/.worktrees/FROM-THE-TICKET -->"
} > .cue/dev/BODY/demand.md
run BODY
if [ "$RC" -eq 1 ]; then
    pass "a worktree line in the body is not a record"
else
    fail "a worktree line in the body is not a record" "exit: $RC" "$OUT"
fi

run NO-SUCH-KEY
[ "$RC" -eq 1 ] && pass "exit 1 for work that does not exist" \
    || fail "exit 1 for work that does not exist" "exit: $RC" "$OUT"

run
[ "$RC" -eq 2 ] && pass "exit 2 with no arguments" || fail "exit 2 with no arguments" "$OUT"

git "${GIT_ID[@]}" worktree remove --force "$WT" >/dev/null 2>&1 || true

finish
