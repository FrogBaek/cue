#!/usr/bin/env bash
# scripts/status: determines the current stage from markers, files, and unrecorded rows.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATUS="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/status"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/status ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=PROJ-142

# --- only the demand marker stamped ---
new_repo "feature/$KEY"
commit_stage "$KEY" demand demand.md
out=$(bash "$STATUS" "$KEY")

if [[ "$out" == *"▶ design"* ]]; then
    pass "the caret sits on design with only the demand marker"
else
    fail "the caret sits on design with only the demand marker" "got: $out"
fi

if [[ "$out" =~ next[[:space:]]+/cue-dev:design ]]; then
    pass "points at /cue-dev:design as the next stage"
else
    fail "points at /cue-dev:design as the next stage" "got: $out"
fi

if [[ "$out" == *"demand ✓"* && "$out" == *"design ·"* ]]; then
    pass "shows which artifacts exist"
else
    fail "shows which artifacts exist" "got: $out"
fi

# --- omitting the KEY finds it from the branch name ---
out_implicit=$(bash "$STATUS")
if [[ "$out_implicit" == "$out" ]]; then
    pass "derives the KEY from the branch name when omitted"
else
    fail "derives the KEY from the branch name when omitted" "got: $out_implicit"
fi

# --- through plan, with 2 of 8 tasks recorded ---
new_repo "feature/$KEY"
commit_stage "$KEY" demand demand.md
commit_stage "$KEY" design design.md
mkdir -p ".cue/dev/$KEY"
write_skeleton "$KEY" 8
sed_i 's/^- 3 · unrecorded$/- 3 · abc1234 · as-planned/; s/^- 6 · unrecorded$/- 6 · def5678 · as-planned/' \
    ".cue/dev/$KEY/outcome.md"
commit_stage "$KEY" plan plan.md
out=$(bash "$STATUS" "$KEY")

if [[ "$out" == *"▶ implement"* ]]; then
    pass "the caret sits on implement at the plan marker"
else
    fail "the caret sits on implement at the plan marker" "got: $out"
fi

if [[ "$out" =~ tasks[[:space:]]+2/8\ recorded ]]; then
    pass "counts the recorded tasks"
else
    fail "counts the recorded tasks" "got: $out"
fi

if [[ "$out" == *"open 1,2,4,5,7,8"* ]]; then
    pass "lists the unrecorded task numbers"
else
    fail "lists the unrecorded task numbers" "got: $out"
fi

# --- every task recorded, marker not yet stamped ---
#
# A legacy shape: an item implemented before the marker moved to the end of
# implement. The rows are all in and the last marker is still plan. Status reads
# it the same way it always did, so those items stay legible.
sed_i 's/^- \([0-9][0-9]*\) · unrecorded$/- \1 · aaa0000 · as-planned/' ".cue/dev/$KEY/outcome.md"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"▶ finish"* && "$out" =~ next[[:space:]]+/cue-dev:finish ]]; then
    pass "awaits FINISH once every task is recorded"
else
    fail "awaits FINISH once every task is recorded" "got: $out"
fi

# --- the outcome marker means implement is done ---
git add -A && git "${GIT_ID[@]}" commit -qm "cue-dev(outcome): $KEY"
out=$(bash "$STATUS" "$KEY")
# The glyph sits on implement, because that is the stage the marker now ends. The
# caret stands on finish: it stamps nothing, so it is where the user still is.
if [[ "$out" == *"implement ✓"* && "$out" == *"▶ finish"* ]]; then
    pass "the outcome marker ticks implement and leaves the caret on finish"
else
    fail "the outcome marker ticks implement and leaves the caret on finish" "got: $out"
fi
if [[ "$out" =~ next[[:space:]]+/cue-dev:finish && "$out" == *"redo implement"* ]]; then
    pass "the rewind from a stamped outcome is implement, not plan"
else
    fail "the rewind from a stamped outcome is implement, not plan" "got: $out"
fi

# The rewinds that were being left out. redo takes any stamped stage at any time
# — cue-dev:redo has a whole section on the cascade — and this box named only the
# nearest one, so a user standing at finish was shown `redo implement` and had no
# way to learn from here that `redo design` was both allowed and one command away.
if [[ "$out" == *"redo plan · design · demand"* ]]; then
    pass "and the further rewinds are named too, most recent first"
else
    fail "and the further rewinds are named too, most recent first" "got: $out"
fi

if [[ "$out" == *"discarding everything after it"* ]]; then
    pass "with what taking one of them costs"
else
    fail "with what taking one of them costs" "got: $out"
fi

# --- work that does not exist ---
rc=0
bash "$STATUS" NOPE-1 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "exit 1 for work that does not exist"
else
    fail "exit 1 for work that does not exist" "exit: $rc"
fi

# --- KEYs that are unsafe on the filesystem ---
rc=0
bash "$STATUS" "a/b" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "exit 2 for a KEY containing a slash"
else
    fail "exit 2 for a KEY containing a slash" "exit: $rc"
fi

# --- no markers at all means START not done ---
new_repo main
mkdir -p ".cue/dev/$KEY"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"▶ demand"* ]]; then
    pass "the caret sits on demand when there are no markers"
else
    fail "the caret sits on demand when there are no markers" "got: $out"
fi

# --- artifact display distinguishes committed from not ---
# Printing ✓ merely because the file exists produces a self-contradicting display:
# "design.md ✓" next to "next /cue-dev:design". The stage rests on the marker, not
# on the files.
new_repo main
commit_stage "$KEY" demand demand.md

printf 'design\n' > ".cue/dev/$KEY/design.md"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"design ~"* ]]; then
    pass "an uncommitted artifact shows as ~"
else
    fail "an uncommitted artifact shows as ~" "got: $out"
fi

git add -A
git "${GIT_ID[@]}" commit -qm "$KEY design commit"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"design ✓"* ]]; then
    pass "a committed artifact shows as ✓"
else
    fail "a committed artifact shows as ✓" "got: $out"
fi

printf 'design revision\n' >> ".cue/dev/$KEY/design.md"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"design ~"* ]]; then
    pass "an artifact edited after the commit goes back to ~"
else
    fail "an artifact edited after the commit goes back to ~" "got: $out"
fi

# --- the rewind hint once implementation has started ---
# implement leaves no marker, so the last marker stays plan. Recommending
# /cue-dev:redo plan anyway means following the hint destroys not just the code but
# the plan as well.
new_repo main
commit_stage "$KEY" demand demand.md
commit_stage "$KEY" design design.md
write_skeleton "$KEY" 2
printf 'plan\n' > ".cue/dev/$KEY/plan.md"
git add -A
git "${GIT_ID[@]}" commit -qm "cue-dev(plan): $KEY"

out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"redo plan"* ]]; then
    pass "before implementation it recommends redo plan"
else
    fail "before implementation it recommends redo plan" "got: $out"
fi

# Only stages that actually have a marker. Naming one that does not is naming a
# refusal, which is the one thing this box must never do.
if [[ "$out" == *"redo design · demand"* ]]; then
    pass "the further rewinds list only the stages that are stamped"
else
    fail "the further rewinds list only the stages that are stamped" "got: $out"
fi

sed_i 's/- 1 · unrecorded/- 1 · abc1234 · as-planned/' ".cue/dev/$KEY/outcome.md"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"redo implement"* ]]; then
    pass "one recorded task is enough to recommend redo implement"
else
    fail "one recorded task is enough to recommend redo implement" "got: $out"
fi

sed_i 's/- 2 · unrecorded/- 2 · def5678 · as-planned/' ".cue/dev/$KEY/outcome.md"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"▶ finish"* && "$out" == *"redo implement"* ]]; then
    pass "it still recommends redo implement while awaiting FINISH"
else
    fail "it still recommends redo implement while awaiting FINISH" "got: $out"
fi

# --- isolation is called out only when it is missing ---
# A line printed on every single run stops being read, and this was the longest one
# in the block. The state worth interrupting for is the unisolated one, so that is
# the only one that gets a line — and it is marked, not merely stated.
if [[ "$out" == *"⚠ not isolated — main checkout"* ]]; then
    pass "warns that the main checkout is not isolated"
else
    fail "warns that the main checkout is not isolated" "got: $out"
fi

MAIN_REPO=$(pwd)
git worktree add -q "$TEST_ROOT/wt-status" "$(git branch --show-current)" 2>/dev/null \
    || git worktree add -q "$TEST_ROOT/wt-status" -b wt-status-branch
cd "$TEST_ROOT/wt-status"
out=$(bash "$STATUS" "$KEY")
# The converse: inside a worktree the warning must be absent. Without this the
# assertion above would pass even if the line were printed unconditionally.
if [[ "$out" != *"not isolated"* && "$out" != *"where"* ]]; then
    pass "says nothing about isolation inside a worktree"
else
    fail "says nothing about isolation inside a worktree" "got: $out"
fi
cd "$MAIN_REPO"

# --- when the item has a worktree, the warning carries the path ---------------
#
# cue-dev cuts its own worktrees and no longer asks the harness to move the
# session into them, so work is done with `git -C <path>` from wherever the
# session stands — and a forgotten `-C` edits the main checkout. That was the one
# real cost of dropping the harness tool, so the warning stops saying "you are not
# isolated" and starts saying where the work actually is. A warning that withholds
# the value you need is a warning you route around.
# Prepended with shell rather than by handing the path to another program: Git
# Bash rewrites POSIX-looking arguments into `C:/...` on their way to a native
# Windows binary, so the recorded path would stop matching the one status reads
# back from git — on Windows only, which is where this plugin is developed.
#
# The line is committed before the worktrees below are cut, because the record
# lives in the repository: a worktree of a branch that predates the commit cannot
# see it, and an assertion resting on that would pass for the wrong reason.
#
# The directory is created, not merely recorded. status drops the path when it is
# not on disk, because /cue-dev:finish removes the worktree and a finished item
# used to keep pointing at the deleted directory — offering a `git -C <path>`
# command that could only fail. A fixture that records a path it never made is
# indistinguishable from that, so it makes one.
WT_LINE="$TEST_ROOT/wt-item"
mkdir -p "$WT_LINE"
DEMAND=".cue/dev/$KEY/demand.md"
{ printf '<!-- worktree: %s -->\n' "$WT_LINE"; cat "$DEMAND"; } > "$DEMAND.tmp"
mv "$DEMAND.tmp" "$DEMAND"
git add -A && git "${GIT_ID[@]}" commit -qm "record the worktree"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"main checkout — this item's worktree is $WT_LINE"* ]]; then
    pass "the main-checkout warning names this item's worktree"
else
    fail "the main-checkout warning names this item's worktree" "got: $out"
fi
if [[ "$out" == *"git -C $WT_LINE"* ]]; then
    pass "it gives the command that works in the right place"
else
    fail "it gives the command that works in the right place" "got: $out"
fi

# Standing in the right worktree is the quiet case, as before.
git worktree add -q "$WT_LINE" -b wt-item-branch
cd "$WT_LINE"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" != *"where"* ]]; then
    pass "no warning when you are in this item's own worktree"
else
    fail "no warning when you are in this item's own worktree" "got: $out"
fi

# A worktree, but somebody else's. Silence here would read as "you are in the
# right place".
git -C "$MAIN_REPO" worktree add -q "$TEST_ROOT/wt-other" -b wt-other-branch
cd "$TEST_ROOT/wt-other"
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"not this item's"* && "$out" == *"$WT_LINE"* ]]; then
    pass "warns in a worktree that is not this item's, and names the right one"
else
    fail "warns in a worktree that is not this item's, and names the right one" "got: $out"
fi
cd "$MAIN_REPO"

# --- work that has landed is not still waiting on finish ----------------------
#
# The last marker cue-dev stamps is `outcome`, so an item merged into main weeks
# ago read `▶ finish · next /cue-dev:finish` for ever. Three items in a real
# repository did, all three merged, and status — the one place that exists to
# answer "where does this stand" — could not say so.
#
# It is observed rather than marked: finish is repeatable on purpose, its `keep`
# path integrates nothing, and two of its three paths have no commit of their own
# to stamp. What is asked is whether the outcome commit is in the item's own start
# point, because the branch is usually deleted by the merge that landed it.
new_repo main
BASE_SHA=$(git rev-parse --short HEAD)
git "${GIT_ID[@]}" checkout -qb "feature/$KEY"
commit_stage "$KEY" demand demand.md
# commit_stage writes placeholder content, so the header goes in afterwards. The
# base line is what cue_item_landed compares against; without it there is nothing
# to be contained in.
{ printf '<!-- base: main @ %s -->\n' "$BASE_SHA"
  printf '<!-- branch: feature/%s -->\n' "$KEY"
  printf '\n# %s — landed fixture\n' "$KEY"; } > ".cue/dev/$KEY/demand.md"
git add -A && git "${GIT_ID[@]}" commit -qm "record the base"
commit_stage "$KEY" design design.md
write_skeleton "$KEY" 1
commit_stage "$KEY" plan plan.md
sed_i 's/^- 1 · unrecorded$/- 1 · abc1234 · as-planned/' ".cue/dev/$KEY/outcome.md"
commit_stage "$KEY" outcome

out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"▶ finish"* ]]; then
    pass "before the merge it still points at finish"
else
    fail "before the merge it still points at finish" "got: $out"
fi

git "${GIT_ID[@]}" checkout -q main
git "${GIT_ID[@]}" merge -q --no-ff -m "Merge branch feature/$KEY" "feature/$KEY"
git "${GIT_ID[@]}" branch -qD "feature/$KEY"
out=$(bash "$STATUS" "$KEY")

if [[ "$out" == *"finish ✓"* && "$out" != *"▶"* ]]; then
    pass "once it is in the base branch, finish is done and no caret is left"
else
    fail "once it is in the base branch, finish is done and no caret is left" "got: $out"
fi

if [[ "$out" == *"next      (none"* ]]; then
    pass "it stops recommending a stage that has nothing left to do"
else
    fail "it stops recommending a stage that has nothing left to do" "got: $out"
fi

# The verdict carries its evidence. A line saying the work is done with nothing
# behind it is the kind of claim status was written to replace — and it survives
# the branch being deleted, which is exactly when the claim gets hard to check.
if [[ "$out" == *"landed"*"main contains"* ]]; then
    pass "it shows what the verdict rests on"
else
    fail "it shows what the verdict rests on" "got: $out"
fi

# Every branch of the `where` block warns about where the next edit would go, and
# for finished work there is no next edit.
if [[ "$out" != *"where"* ]]; then
    pass "no isolation warning once the work has landed"
else
    fail "no isolation warning once the work has landed" "got: $out"
fi

# The rewind line used to read `/cue-dev:redo implement  (rewinds the branch —
# what landed stays landed)`. The branch it described had been deleted by the
# merge, so the command reached the base branch the user was standing on, and
# scripts/redo reset it: the plan marker is in main's history too once the merge
# has put it there. In a real repository that was seventeen commits, the merge
# among them. status must not be the line the user follows into that.
if [[ "$out" == *"rewind"*"(none"* && "$out" != *"redo implement"* ]]; then
    pass "no rewind is offered once the work has landed"
else
    fail "no rewind is offered once the work has landed" "got: $out"
fi

# --- the records survived, the markers did not -------------------------------
# A squash landing puts all four records into the base branch in one commit and
# none of the four markers. Reading markers alone, that is indistinguishable from
# never started, and status said so: `next /cue-dev:start` printed three lines
# under demand ✓ design ✓ plan ✓ and a fully recorded outcome.md. The display
# contradicted itself and named neither half.
new_repo main
BASE_SHA=$(git rev-parse --short HEAD)
git "${GIT_ID[@]}" checkout -qb "feature/$KEY"
commit_stage "$KEY" demand demand.md
{ printf '<!-- base: main @ %s -->\n' "$BASE_SHA"
  printf '<!-- branch: feature/%s -->\n' "$KEY"
  printf '\n# %s — squashed fixture\n' "$KEY"; } > ".cue/dev/$KEY/demand.md"
git add -A && git "${GIT_ID[@]}" commit -qm "record the base"
commit_stage "$KEY" design design.md
write_skeleton "$KEY" 1
commit_stage "$KEY" plan plan.md
sed_i 's/^- 1 · unrecorded$/- 1 · abc1234 · as-planned/' ".cue/dev/$KEY/outcome.md"
commit_stage "$KEY" outcome

git "${GIT_ID[@]}" checkout -q main
git "${GIT_ID[@]}" merge -q --squash "feature/$KEY"
git "${GIT_ID[@]}" commit -qm "chore: land $KEY"
git "${GIT_ID[@]}" branch -qD "feature/$KEY"
out=$(bash "$STATUS" "$KEY")

if [[ "$out" != *"cue-dev:start"* ]]; then
    pass "committed records are never read as work that never started"
else
    fail "committed records are never read as work that never started" "got: $out"
fi

if [[ "$out" == *"history"*"no cue-dev markers in this history"* ]]; then
    pass "it says the stage came from the records and not from a marker"
else
    fail "it says the stage came from the records and not from a marker" "got: $out"
fi

# scripts/redo resolves `implement` to the plan marker and refuses when there is
# none, so offering the command here walks the user into that refusal.
if [[ "$out" != *"cue-dev:redo"* ]]; then
    pass "it offers no rewind when there is no marker to rewind to"
else
    fail "it offers no rewind when there is no marker to rewind to" "got: $out"
fi

if [[ "$out" == *"next      (none"* ]]; then
    pass "a squashed landing still reads as landed"
else
    fail "a squashed landing still reads as landed" "got: $out"
fi

# --- the same warning must not fire on the normal path -----------------------
# outcome.md is committed by the *plan* marker and its rows are filled in one
# commit at a time, so "fully recorded, no outcome marker yet" is the last minutes
# of every implement run — not damage. An earlier draft of the detector flagged it
# and put the warning on the screen during ordinary work.
new_repo main
commit_stage "$KEY" demand demand.md
commit_stage "$KEY" design design.md
write_skeleton "$KEY" 2
commit_stage "$KEY" plan plan.md
sed_i 's/^- 1 · unrecorded$/- 1 · abc1234 · as-planned/' ".cue/dev/$KEY/outcome.md"
git add -A && git "${GIT_ID[@]}" commit -qm "chore: record task 1"
sed_i 's/^- 2 · unrecorded$/- 2 · def5678 · as-planned/' ".cue/dev/$KEY/outcome.md"
git add -A && git "${GIT_ID[@]}" commit -qm "chore: record task 2"
out=$(bash "$STATUS" "$KEY")

if [[ "$out" != *"history"* ]]; then
    pass "no marker warning while implement is simply not stamped yet"
else
    fail "no marker warning while implement is simply not stamped yet" "got: $out"
fi

if [[ "$out" == *"▶ finish"* && "$out" == *"redo implement"* ]]; then
    pass "the rewind hint is untouched on the normal path"
else
    fail "the rewind hint is untouched on the normal path" "got: $out"
fi

# --- merged, with every marker except outcome --------------------------------
# The shape left by the older rules, where finish stamped the outcome marker: the
# item is in main, every row is recorded, and nothing is "lost" — demand, design
# and plan are all still there. Landing was asked of the outcome marker, so these
# read `▶ finish · next /cue-dev:finish` forever. Landing is a question about the
# base, not about the markers.
new_repo main
BASE_SHA=$(git rev-parse --short HEAD)
git "${GIT_ID[@]}" checkout -qb "feature/$KEY"
commit_stage "$KEY" demand demand.md
{ printf '<!-- base: main @ %s -->\n' "$BASE_SHA"
  printf '<!-- branch: feature/%s -->\n' "$KEY"
  printf '\n# %s — legacy fixture\n' "$KEY"; } > ".cue/dev/$KEY/demand.md"
git add -A && git "${GIT_ID[@]}" commit -qm "record the base"
commit_stage "$KEY" design design.md
write_skeleton "$KEY" 1
commit_stage "$KEY" plan plan.md
sed_i 's/^- 1 · unrecorded$/- 1 · abc1234 · as-planned/' ".cue/dev/$KEY/outcome.md"
git add -A && git "${GIT_ID[@]}" commit -qm "chore: record task 1"

# Still on the branch: not in the base yet, so nothing may be promoted. This is
# the assertion that keeps the fallback off the normal path — between the last row
# commit and the outcome stamp, an item is finished-looking and not done.
out=$(bash "$STATUS" "$KEY")
if [[ "$out" == *"▶ finish"* && "$out" != *"landed"* ]]; then
    pass "a fully recorded outcome on its own branch is not landed"
else
    fail "a fully recorded outcome on its own branch is not landed" "got: $out"
fi

git "${GIT_ID[@]}" checkout -q main
git "${GIT_ID[@]}" merge -q --no-ff -m "Merge branch feature/$KEY" "feature/$KEY"
git "${GIT_ID[@]}" branch -qD "feature/$KEY"
out=$(bash "$STATUS" "$KEY")

if [[ "$out" == *"finish ✓"* && "$out" == *"landed"* ]]; then
    pass "once it is in the base it is landed, outcome marker or not"
else
    fail "once it is in the base it is landed, outcome marker or not" "got: $out"
fi

# Nothing was rewritten here — every marker that should exist does — so the
# records never spoke and the warning must stay off.
if [[ "$out" != *"history"* ]]; then
    pass "a missing outcome stamp is not reported as a rewritten history"
else
    fail "a missing outcome stamp is not reported as a rewritten history" "got: $out"
fi

# --- finished, but recording no start point ----------------------------------
# Items written before the start point moved into demand.md have no base, so
# "is it in its base" has no subject. That is a different answer from `no`, and
# rendering it as `no` is what left merged work pointing at finish.
new_repo main
commit_stage "$KEY" demand demand.md
commit_stage "$KEY" design design.md
write_skeleton "$KEY" 1
commit_stage "$KEY" plan plan.md
sed_i 's/^- 1 · unrecorded$/- 1 · abc1234 · as-planned/' ".cue/dev/$KEY/outcome.md"
git add -A && git "${GIT_ID[@]}" commit -qm "chore: record task 1"
out=$(bash "$STATUS" "$KEY")

if [[ "$out" == *"landed"*"unknown"*"no start point"* ]]; then
    pass "it says landing cannot be asked rather than answering no"
else
    fail "it says landing cannot be asked rather than answering no" "got: $out"
fi

# --- no KEY, and none recoverable from the branch ----------------------------
# The normal state for landed work: the item records the branch it was cut onto,
# and the merge deleted it. It refuses, and the refusal carries the way out —
# but the way out is "name the item", not a list of what is lying around.
# `using-cue` calls this with no KEY at session start and says what should happen:
# "If it cannot find a KEY (you are not in cue-dev work), it simply fails and you
# move on."
new_repo main
commit_stage "$KEY" demand demand.md
git "${GIT_ID[@]}" checkout -q -b unrelated-branch
set +e
out=$(bash "$STATUS" 2>&1)
rc=$?
set -e

if [ "$rc" -ne 0 ] && [[ "$out" == *"/cue-dev:status <KEY>"* ]]; then
    pass "with no KEY to be had it asks for one"
else
    fail "with no KEY to be had it asks for one" "rc=$rc" "got: $out"
fi

if ! printf '%s\n' "$out" | grep -q "$KEY"; then
    pass "and does not enumerate what is in .cue/dev/"
else
    fail "and does not enumerate what is in .cue/dev/" "got: $out"
fi

finish
