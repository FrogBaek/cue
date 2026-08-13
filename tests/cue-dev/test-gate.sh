#!/usr/bin/env bash
# scripts/gate: may this stage run here, and if not, what can?
#
# The regression this pins: a refusal that names only what failed. `/cue-dev:status`
# in a repository where nothing had been started printed
#
#     no KEY found from the current branch. Pass one: scripts/status <KEY>
#
# and exited 2. Accurate, and useless — the controller retried with a guessed KEY,
# then read `.cue/dev/` by hand and improvised the next step, arriving at the right
# answer by luck. Every assertion below is about the way out being present, not
# just the refusal.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/gate"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/gate ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

# Runs the gate and captures both streams and the exit code.
run() {
    GATE_RC=0
    GATE_OUT=$(bash "$GATE" "$@" 2>&1) || GATE_RC=$?
}

blocks_with_a_way_out() {
    local label=$1
    if [ "$GATE_RC" -ne 1 ]; then
        fail "$label" "expected exit 1, got $GATE_RC" "$GATE_OUT"
        return
    fi
    if [[ "$GATE_OUT" =~ blocked[[:space:]] ]] && [[ "$GATE_OUT" =~ now[[:space:]] ]]; then
        pass "$label"
    else
        fail "$label" "a refusal without a 'now' line is the bug this script exists for" "$GATE_OUT"
    fi
}

# --- a repository with no commits --------------------------------------------
# Branching here produces an unborn branch and no base branch ever exists, which
# only surfaces at finish with nowhere to open a PR.
dir="$TEST_ROOT/empty"
git init -q -b main "$dir"
cd "$dir"
run init
blocks_with_a_way_out "no commits blocks even init"
if [[ "$GATE_OUT" == *"commit"* ]]; then
    pass "it says to make a commit first"
else
    fail "it says to make a commit first" "$GATE_OUT"
fi

# --- a prepared repository with no work --------------------------------------
new_repo main
run init
if [ "$GATE_RC" -eq 0 ]; then
    pass "init may run in a repository with commits"
else
    fail "init may run in a repository with commits" "$GATE_OUT"
fi

run start
if [ "$GATE_RC" -eq 0 ]; then
    pass "start may run before any work exists"
else
    fail "start may run before any work exists" "$GATE_OUT"
fi

# This is the exact case from the session. `status` with nothing started must not
# answer "pass a KEY" — there is no KEY to pass.
run status
blocks_with_a_way_out "status blocks when nothing has been started"
if [[ "$GATE_OUT" == *"/cue-dev:start"* ]]; then
    pass "it points at start rather than asking for a KEY that cannot exist"
else
    fail "it points at start rather than asking for a KEY that cannot exist" "$GATE_OUT"
fi

run design
blocks_with_a_way_out "design blocks when nothing has been started"

# --- the language line is on stderr, and only it -----------------------------
# stdout is the answer about this repository; stderr is the instruction to the
# model reading it. On one channel they were relayed together, and a user who
# asked where their work stood was shown "language ko — reply to the user in this
# language…". The line must still be reachable, so both halves are asserted.
stdout_only=$(bash "$GATE" status 2>/dev/null) || true
stderr_only=$(bash "$GATE" status 2>&1 >/dev/null) || true
if [[ "$stdout_only" != *language* ]] && [[ "$stdout_only" == *blocked* ]]; then
    pass "the language line is not on stdout, and the answer still is"
else
    fail "the language line is not on stdout, and the answer still is" "$stdout_only"
fi
if [[ "$stderr_only" == *"reply to the user in this language"* ]]; then
    pass "the language line still reaches the model, on stderr"
else
    fail "the language line still reaches the model, on stderr" "$stderr_only"
fi

# --- work exists, but not on this branch -------------------------------------
KEY=PROJ-142
commit_stage "$KEY" demand demand.md
git checkout -q -b unrelated-branch
run status
blocks_with_a_way_out "an unrelated branch blocks rather than guessing"
# This assertion used to be its own opposite — it required the existing items to
# be named. That is what put a list in front of a session that had not asked
# about any of them, and the session continued the wrong one. Refusing and asking
# for the KEY is the answer; the archive's contents are not.
if [[ "$GATE_OUT" != *"$KEY"* ]]; then
    pass "it asks for a KEY rather than listing what exists"
else
    fail "it asks for a KEY rather than listing what exists" "$GATE_OUT"
fi

# --- the ordering --------------------------------------------------------------
git checkout -q -b "cue-dev/$KEY"

run design
if [ "$GATE_RC" -eq 0 ] && [[ "$GATE_OUT" =~ key[[:space:]]+$KEY ]]; then
    pass "design may run once demand is stamped, and the KEY comes back"
else
    fail "design may run once demand is stamped, and the KEY comes back" "$GATE_OUT"
fi

run plan
blocks_with_a_way_out "plan blocks before design is stamped"
if [[ "$GATE_OUT" == *"/cue-dev:design"* ]]; then
    pass "it names the stage that unblocks it"
else
    fail "it names the stage that unblocks it" "$GATE_OUT"
fi

run implement
blocks_with_a_way_out "implement blocks before plan is stamped"
run finish
blocks_with_a_way_out "finish blocks before plan is stamped"

commit_stage "$KEY" design design.md
run plan
[ "$GATE_RC" -eq 0 ] && pass "plan opens once design is stamped" \
    || fail "plan opens once design is stamped" "$GATE_OUT"
run implement
blocks_with_a_way_out "implement still blocks — plan has not run"

commit_stage "$KEY" plan plan.md
run implement
[ "$GATE_RC" -eq 0 ] && pass "implement opens once plan is stamped" \
    || fail "implement opens once plan is stamped" "$GATE_OUT"

# finish needs the outcome marker, not the plan marker. The marker is stamped at
# the end of implement, and this is what makes that placement enforced rather than
# hoped for: skip the stamp and finish refuses, naming implement.
run finish
blocks_with_a_way_out "finish blocks while the outcome marker is missing"
if [[ "$GATE_OUT" == *"/cue-dev:implement"* ]]; then
    pass "finish points at implement, which is what stamps the marker"
else
    fail "finish points at implement, which is what stamps the marker" "$GATE_OUT"
fi

commit_stage "$KEY" outcome outcome.md
run finish
[ "$GATE_RC" -eq 0 ] && pass "finish opens once outcome is stamped" \
    || fail "finish opens once outcome is stamped" "$GATE_OUT"

# --- a stage that has already run --------------------------------------------
#
# The other half of the ordering, and the half that was missing. Running design
# again in place rewrites design.md while plan.md and the outcome rows stay —
# records that no longer describe one another, reached by walking forwards
# instead of back, and with no backup branch because nothing rewound.

for s in design plan implement; do
    run "$s"
    blocks_with_a_way_out "$s blocks once it has already been stamped"
    if [[ "$GATE_OUT" == *"/cue-dev:redo $s"* ]]; then
        pass "$s points at the rewind rather than at itself"
    else
        fail "$s points at the rewind rather than at itself" "$GATE_OUT"
    fi
done

# finish stamps nothing and is meant to be repeatable — it is where an
# interrupted run is picked up.
run finish
[ "$GATE_RC" -eq 0 ] && pass "finish stays repeatable" || fail "finish stays repeatable" "$GATE_OUT"

# --- an explicit KEY overrides the branch ------------------------------------
git checkout -q -b somewhere-else
run finish "$KEY"
[ "$GATE_RC" -eq 0 ] && pass "an explicit KEY is used instead of the branch name" \
    || fail "an explicit KEY is used instead of the branch name" "$GATE_OUT"

run design NOPE-1
blocks_with_a_way_out "a KEY with no records blocks"

# --- the candidate list is not a directory listing ----------------------------
# `.cue/dev/` is an archive. Offering all of it as "which one do you mean" put
# work that had merged months ago beside work still in flight, and a real session
# read the list back as "several items in progress", named four, and asked which
# to continue. All four had landed.
new_repo main
BASE_SHA=$(git rev-parse --short HEAD)
DONE_KEY=DONE-1
git "${GIT_ID[@]}" checkout -qb "feature/$DONE_KEY"
commit_stage "$DONE_KEY" demand demand.md
{ printf '<!-- base: main @ %s -->\n' "$BASE_SHA"
  printf '<!-- branch: feature/%s -->\n' "$DONE_KEY"
  printf '\n# %s — landed fixture\n' "$DONE_KEY"; } > ".cue/dev/$DONE_KEY/demand.md"
git add -A && git "${GIT_ID[@]}" commit -qm "record the base"
commit_stage "$DONE_KEY" design design.md
write_skeleton "$DONE_KEY" 1
commit_stage "$DONE_KEY" plan plan.md
sed_i 's/^- 1 · unrecorded$/- 1 · abc1234 · as-planned/' ".cue/dev/$DONE_KEY/outcome.md"
commit_stage "$DONE_KEY" outcome
git "${GIT_ID[@]}" checkout -q main
git "${GIT_ID[@]}" merge -q --no-ff -m "Merge branch feature/$DONE_KEY" "feature/$DONE_KEY"
git "${GIT_ID[@]}" branch -qD "feature/$DONE_KEY"
# And one that really is still open. Its records have to be on the branch being
# looked at — the listing is built from `.cue/dev/` in the working tree, so an
# item whose records live only on an unmerged branch is not in the list to begin
# with, which is a different case from the one under test here.
commit_stage "$KEY" demand demand.md

run status
blocks_with_a_way_out "with no KEY it still offers a way out"

# The whole assertion: no KEY was given, so there is no item to name. Naming any
# of them — open, landed, or split into both — answers "what exists in the
# archive", and a real session read that answer back as "several items in
# progress" and asked which to continue.
if ! printf '%s\n' "$GATE_OUT" | grep -q "$DONE_KEY"; then
    pass "it does not name the items in the archive"
else
    fail "it does not name the items in the archive" "$GATE_OUT"
fi
if ! printf '%s\n' "$GATE_OUT" | grep -q "$KEY"; then
    pass "not even the one that is still open — no KEY was asked about"
else
    fail "not even the one that is still open — no KEY was asked about" "$GATE_OUT"
fi
if [[ "$GATE_OUT" == *"/cue-dev:status <KEY>"* ]]; then
    pass "it asks for the KEY instead"
else
    fail "it asks for the KEY instead" "$GATE_OUT"
fi

# Branch inference is not guessing — it reads the branch: line the item recorded
# — so it must keep working. This is what makes refusing above affordable.
git "${GIT_ID[@]}" checkout -q -b "feature/$KEY"
printf '<!-- branch: feature/%s -->\n\n# %s\n' "$KEY" "$KEY" > ".cue/dev/$KEY/demand.md"
git add -A && git "${GIT_ID[@]}" commit -qm "record the branch"
run status
if [ "$GATE_RC" -eq 0 ] && [[ "$GATE_OUT" == *"$KEY"* ]]; then
    pass "the recorded branch still finds the item with no KEY given"
else
    fail "the recorded branch still finds the item with no KEY given" "rc=$GATE_RC" "$GATE_OUT"
fi
git "${GIT_ID[@]}" checkout -q main

# --- the records survived, the markers did not --------------------------------
# The same blindness status had, and it has to be answered the same way here or
# the two disagree on the screen: reading markers only, gate sent an item whose
# committed records show a finished implementation back to /cue-dev:start.
new_repo main
git "${GIT_ID[@]}" checkout -qb "feature/$KEY"
commit_stage "$KEY" demand demand.md
commit_stage "$KEY" design design.md
write_skeleton "$KEY" 1
commit_stage "$KEY" plan plan.md
sed_i 's/^- 1 · unrecorded$/- 1 · abc1234 · as-planned/' ".cue/dev/$KEY/outcome.md"
commit_stage "$KEY" outcome
git "${GIT_ID[@]}" checkout -q main
git "${GIT_ID[@]}" merge -q --squash "feature/$KEY"
git "${GIT_ID[@]}" commit -qm "chore: land $KEY"
git "${GIT_ID[@]}" branch -qD "feature/$KEY"

run design "$KEY"
blocks_with_a_way_out "a stage already recorded is blocked even with its marker gone"
if [[ "$GATE_OUT" != *"cue-dev:redo"* ]]; then
    pass "it does not offer a rewind that has no marker to rewind to"
else
    fail "it does not offer a rewind that has no marker to rewind to" "$GATE_OUT"
fi

run finish "$KEY"
if [ "$GATE_RC" -eq 0 ] && [[ "$GATE_OUT" == *"history"* ]]; then
    pass "finish is reachable and says the stage came from the records"
else
    fail "finish is reachable and says the stage came from the records" "rc=$GATE_RC" "$GATE_OUT"
fi

# --- usage ---------------------------------------------------------------------
run bogus-stage
[ "$GATE_RC" -eq 2 ] && pass "exit 2 on an unknown stage" \
    || fail "exit 2 on an unknown stage" "$GATE_OUT"

run
[ "$GATE_RC" -eq 2 ] && pass "exit 2 with no arguments" \
    || fail "exit 2 with no arguments" "$GATE_OUT"

cd "$TEST_ROOT"
mkdir -p notrepo && cd notrepo
run status
[ "$GATE_RC" -eq 2 ] && pass "exit 2 outside a git repository" \
    || fail "exit 2 outside a git repository" "$GATE_OUT"

finish
