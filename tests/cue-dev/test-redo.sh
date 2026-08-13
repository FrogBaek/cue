#!/usr/bin/env bash
# scripts/redo: finds the marker, creates a backup branch, and resets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REDO="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/redo"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/redo ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=PROJ-142

# A repository taken through demand → design → plan → two implementation commits.
full_repo() {
    new_repo "feature/$KEY"
    commit_stage "$KEY" demand demand.md
    commit_stage "$KEY" design design.md
    write_skeleton "$KEY" 3
    commit_stage "$KEY" plan plan.md
    printf 'src 1\n' > impl-1.txt
    git add -A && git "${GIT_ID[@]}" commit -qm "implement task 1"
    printf 'src 2\n' > impl-2.txt
    sed_i 's/^- 1 · unrecorded$/- 1 · aaa1111 · as-planned/' ".cue/dev/$KEY/outcome.md"
    git add -A && git "${GIT_ID[@]}" commit -qm "implement task 2"
}

# --- redo design: everything after design disappears ---
full_repo
bash "$REDO" design "$KEY" --yes >/dev/null

if [ ! -f ".cue/dev/$KEY/design.md" ] && [ -f ".cue/dev/$KEY/demand.md" ]; then
    pass "redo design keeps demand and deletes design"
else
    fail "redo design keeps demand and deletes design" "$(ls ".cue/dev/$KEY")"
fi

if [ ! -f ".cue/dev/$KEY/plan.md" ] && [ ! -f ".cue/dev/$KEY/outcome.md" ]; then
    pass "redo design leaves neither plan.md nor outcome.md"
else
    fail "redo design leaves neither plan.md nor outcome.md" "$(ls ".cue/dev/$KEY")"
fi

if [ ! -f impl-1.txt ] && [ ! -f impl-2.txt ]; then
    pass "redo design rewinds the implementation commits"
else
    fail "redo design rewinds the implementation commits"
fi

backup=$(git branch --list 'cue-dev/backup/*' | tr -d ' *')
if [ -n "$backup" ]; then
    pass "creates a backup branch"
else
    fail "creates a backup branch"
fi

if [ -n "$(git show "$backup:impl-2.txt" 2>/dev/null)" ]; then
    pass "what was rewound can be recovered from the backup branch"
else
    fail "what was rewound can be recovered from the backup branch"
fi

# --- redo implement: keeps the plan and rewinds only the implementation ---
full_repo
bash "$REDO" implement "$KEY" --yes >/dev/null

if [ -f ".cue/dev/$KEY/plan.md" ]; then
    pass "redo implement keeps plan.md"
else
    fail "redo implement keeps plan.md"
fi

if [ ! -f impl-1.txt ] && [ ! -f impl-2.txt ]; then
    pass "redo implement rewinds the implementation commits"
else
    fail "redo implement rewinds the implementation commits"
fi

if [ "$(grep -c 'unrecorded' ".cue/dev/$KEY/outcome.md")" -eq 3 ]; then
    pass "redo implement resets outcome.md to the skeleton"
else
    fail "redo implement resets outcome.md to the skeleton" \
        "$(cat ".cue/dev/$KEY/outcome.md")"
fi

if [ -n "$(git log --fixed-strings --grep="cue-dev(plan): $KEY" --format=%H)" ]; then
    pass "redo implement leaves the plan marker commit in place"
else
    fail "redo implement leaves the plan marker commit in place"
fi

# --- redo plan ---
full_repo
bash "$REDO" plan "$KEY" --yes >/dev/null
if [ -f ".cue/dev/$KEY/design.md" ] && [ ! -f ".cue/dev/$KEY/plan.md" ]; then
    pass "redo plan keeps design and deletes plan"
else
    fail "redo plan keeps design and deletes plan" "$(ls ".cue/dev/$KEY")"
fi

# --- redo demand: the work directory itself disappears ---
full_repo
bash "$REDO" demand "$KEY" --yes >/dev/null
if [ ! -d ".cue/dev/$KEY" ]; then
    pass "redo demand leaves no work directory"
else
    fail "redo demand leaves no work directory" "$(ls -a ".cue/dev/$KEY")"
fi

# --- a stage that never ran ---
#
# Going back is as linear as going forward: `redo plan` before there is a plan is
# the same mistake as `implement` before there is one. What the two must share is
# not only the refusal but the way out — this one used to print a single line and
# exit, which is what left the controller to improvise the next move.
new_repo "feature/$KEY"
commit_stage "$KEY" demand demand.md
rc=0
out=$(bash "$REDO" plan "$KEY" --yes 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"REWIND blocked"* ]]; then
    pass "aborts when the marker is missing"
else
    fail "aborts when the marker is missing" "exit: $rc" "$out"
fi

if [[ "$out" == *"/cue-dev:redo demand"* && "$out" == *"/cue-dev:status $KEY"* ]]; then
    pass "the refusal names the stages that can be rewound"
else
    fail "the refusal names the stages that can be rewound" "$out"
fi

# Only what is actually stamped. Offering `redo design` here would send the user
# at a marker that does not exist and produce this same refusal a second time.
if [[ "$out" != *"/cue-dev:redo design"* && "$out" != *"/cue-dev:redo implement"* ]]; then
    pass "it does not offer stages that have not run either"
else
    fail "it does not offer stages that have not run either" "$out"
fi

if [ -f ".cue/dev/$KEY/demand.md" ]; then
    pass "aborting touches nothing"
else
    fail "aborting touches nothing"
fi

# implement rides on the plan marker rather than one of its own, so it becomes
# available exactly when plan does.
new_repo "feature/$KEY"
commit_stage "$KEY" demand demand.md
commit_stage "$KEY" design design.md
commit_stage "$KEY" plan plan.md
rc=0
out=$(bash "$REDO" implement "$KEY" --dry-run 2>&1) || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "implement may be rewound once the plan marker exists"
else
    fail "implement may be rewound once the plan marker exists" "exit: $rc" "$out"
fi

# --- it also cleans up artifacts left uncommitted ---
full_repo
printf 'scratch\n' > ".cue/dev/$KEY/scratch.md"
bash "$REDO" plan "$KEY" --yes >/dev/null
if [ ! -f ".cue/dev/$KEY/scratch.md" ]; then
    pass "uncommitted artifacts are cleaned up too"
else
    fail "uncommitted artifacts are cleaned up too"
fi

# --- bad arguments ---
rc=0
bash "$REDO" nonsense "$KEY" --yes >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "exit 2 on an unknown stage"
else
    fail "exit 2 on an unknown stage" "exit: $rc"
fi

rc=0
bash "$REDO" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "exit 2 with no arguments"
else
    fail "exit 2 with no arguments" "exit: $rc"
fi

# --- a repository where cue-dev(demand) is the initial commit ---
# git init in an empty directory followed by /cue-dev:start really produces this
# shape. There is no parent commit, so marker^ cannot rewind — the rewind point is
# "zero commits".
root_repo() {
    local dir="$TEST_ROOT/root-$RANDOM"
    git init -q -b "cue-dev/$KEY" "$dir"
    cd "$dir" || return 1
    commit_stage "$KEY" demand demand.md
}

root_repo
rc=0
out=$(bash "$REDO" demand "$KEY" --yes 2>&1) || rc=$?
if [ -z "$(git rev-parse --verify --quiet HEAD || true)" ]; then
    pass "when the marker is the initial commit, it rewinds to zero commits"
else
    fail "when the marker is the initial commit, it rewinds to zero commits" "$out"
fi

if [ ! -f ".cue/dev/$KEY/demand.md" ]; then
    pass "rewinding the initial commit deletes the artifacts too"
else
    fail "rewinding the initial commit deletes the artifacts too"
fi

backup=$(git branch --list 'cue-dev/backup/*' | tr -d ' *')
if [ -n "$backup" ] && [ -n "$(git rev-parse --verify --quiet "$backup" || true)" ]; then
    pass "the rewound commit remains on a backup branch"
else
    fail "the rewound commit remains on a backup branch" "$out"
fi

# --- after rewinding to demand the hint is /cue-dev:start (there is no /cue-dev:demand) ---
full_repo
out=$(bash "$REDO" demand "$KEY" --yes 2>&1)
if echo "$out" | grep -q '/cue-dev:start' && ! echo "$out" | grep -q '/cue-dev:demand'; then
    pass "rewinding demand points at /cue-dev:start"
else
    fail "rewinding demand points at /cue-dev:start" "$out"
fi

full_repo
out=$(bash "$REDO" plan "$KEY" --yes 2>&1)
if echo "$out" | grep -q '/cue-dev:plan'; then
    pass "other stages point at the command of the same name"
else
    fail "other stages point at the command of the same name" "$out"
fi

# --- it lists earlier backups (repeated rewinds pile them up) ---
full_repo
out1=$(bash "$REDO" plan "$KEY" --yes 2>&1)
if ! echo "$out1" | grep -q 'from earlier rewinds'; then
    pass "the first rewind has no older-backups list"
else
    fail "the first rewind has no older-backups list" "$out1"
fi
first=$(git branch --list 'cue-dev/backup/*' | tr -d ' *' | head -1)

sleep 1   # backup branch names carry a per-second timestamp, so two in one second collide
out2=$(bash "$REDO" design "$KEY" --yes 2>&1)
if echo "$out2" | grep -q "$first"; then
    pass "the next rewind puts the earlier backup in the list"
else
    fail "the next rewind puts the earlier backup in the list" "$out2"
fi

newest=$(git branch --list 'cue-dev/backup/*' | tr -d ' *' | sort | tail -1)
del=$(echo "$out2" | sed -n 's/^ *delete  *git branch -D //p')
if [ -n "$del" ] && [[ "$del" != *"$newest"* ]]; then
    pass "the deletion command excludes the backup just created"
else
    fail "the deletion command excludes the backup just created" "deletion command: $del" "just created: $newest"
fi

if [ "$(git branch --list 'cue-dev/backup/*' | wc -l)" -eq 2 ]; then
    pass "the script never deletes backups on its own"
else
    fail "the script never deletes backups on its own" "$(git branch --list 'cue-dev/backup/*')"
fi

# --- the frame closes at the width the title opened it to ---
#
# The title carries a `·`, which is three bytes. cue_head used to measure with
# ${#}, which counts bytes whenever the locale is empty — as it is on Git Bash —
# so the closing rule came up short of the header. The box is the one thing a user
# reads before deciding to destroy commits; it should not look broken.
full_repo
out=$(bash "$REDO" plan "$KEY" --yes 2>&1)
width() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }
head_line=$(printf '%s\n' "$out" | grep -m1 'REWIND done')
last_line=$(printf '%s\n' "$out" | tail -1)
if [ "$(width "$head_line")" = "$(width "$last_line")" ]; then
    pass "the closing rule matches the header width with a multi-byte title"
else
    fail "the closing rule matches the header width with a multi-byte title" \
        "header $(width "$head_line") vs closing $(width "$last_line")" "$out"
fi

# The KEY is a body line, not part of the title. Putting the longest and most
# variable string in the position that decides the frame's width stretched every
# box sideways to carry what `key  <KEY>` carries in place.
if [[ "$head_line" != *"$KEY"* ]]; then
    pass "the header carries no KEY"
else
    fail "the header carries no KEY" "$head_line"
fi

if [[ "$out" =~ key[[:space:]]+$KEY ]]; then
    pass "the KEY is reported on a labelled body line"
else
    fail "the KEY is reported on a labelled body line" "$out"
fi

# --- --dry-run is a report, and reports succeed ---
#
# The preview used to be "run it with no stdin and let the prompt hit EOF", which
# exited 1. A preview that reports itself as a failure is unusable: in a real
# session Claude said "let me show you the preview first" and the user saw an
# error, after which the only path anyone found was handing the --yes command back
# for the user to type.
full_repo
rc=0
out=$(bash "$REDO" plan "$KEY" --dry-run 2>&1) || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "--dry-run exits 0"
else
    fail "--dry-run exits 0" "exit: $rc" "$out"
fi

if [ -f ".cue/dev/$KEY/plan.md" ] && [ -z "$(git branch --list 'cue-dev/backup/*')" ]; then
    pass "--dry-run changes nothing — no reset, no backup branch"
else
    fail "--dry-run changes nothing — no reset, no backup branch" "$out"
fi

if [[ "$out" =~ discard[[:space:]] ]] && [[ "$out" =~ lose[[:space:]] ]]; then
    pass "--dry-run still shows what would be discarded"
else
    fail "--dry-run still shows what would be discarded" "$out"
fi

if [[ "$out" == *"--yes"* ]]; then
    pass "--dry-run names how to proceed once the user has agreed"
else
    fail "--dry-run names how to proceed once the user has agreed" "$out"
fi

# --- it refuses to reset a branch that is not this item's --------------------
#
# Nothing here ever asked what HEAD was. The marker lookup only proves the commit
# is in *this* history, and after a merge it is in the base branch's history too —
# so on a landed item, run from the base branch, redo resolved the plan marker,
# found it, and reset the base branch onto it. In a real repository that was main
# and seventeen commits with the merge among them, and scripts/status was printing
# the command that got there.
landed_repo() {
    new_repo main
    base_sha=$(git rev-parse --short HEAD)
    git "${GIT_ID[@]}" checkout -qb "feature/$KEY"
    commit_stage "$KEY" demand demand.md
    # commit_stage writes placeholder content; the header carries the two fields
    # the guard reads — without a base line there is nothing to have landed in.
    { printf '<!-- base: main @ %s -->
' "$base_sha"
      printf '<!-- branch: feature/%s -->
' "$KEY"
      printf '
# %s — landed fixture
' "$KEY"; } > ".cue/dev/$KEY/demand.md"
    git add -A && git "${GIT_ID[@]}" commit -qm "record the base"
    commit_stage "$KEY" design design.md
    write_skeleton "$KEY" 1
    commit_stage "$KEY" plan plan.md
    printf 'src 1
' > impl-1.txt
    git add -A && git "${GIT_ID[@]}" commit -qm "implement task 1"
    sed_i 's/^- 1 · unrecorded$/- 1 · aaa1111 · as-planned/' ".cue/dev/$KEY/outcome.md"
    commit_stage "$KEY" outcome
}

landed_repo
git "${GIT_ID[@]}" checkout -q main
git "${GIT_ID[@]}" merge -q --no-ff -m "Merge branch feature/$KEY" "feature/$KEY"
git "${GIT_ID[@]}" branch -qD "feature/$KEY"
before=$(git rev-parse HEAD)
rc=0
out=$(bash "$REDO" implement "$KEY" --yes 2>&1) || rc=$?

if [ "$rc" -eq 1 ] && [ "$(git rev-parse HEAD)" = "$before" ]; then
    pass "landed work is not rewound, --yes or not"
else
    fail "landed work is not rewound, --yes or not" "exit: $rc" "$out"
fi

if [[ "$out" == *"has landed in main"* ]]; then
    pass "it says the work landed rather than that the marker is missing"
else
    fail "it says the work landed rather than that the marker is missing" "$out"
fi

# The number is what makes the refusal read as a rescue rather than an obstacle.
if [[ "$out" == *"would"*"commits from main"* ]]; then
    pass "it names how many commits the reset would have discarded"
else
    fail "it names how many commits the reset would have discarded" "$out"
fi

if [ -z "$(git branch --list 'cue-dev/backup/*')" ]; then
    pass "a refused rewind leaves no backup branch behind"
else
    fail "a refused rewind leaves no backup branch behind"
fi

# --- and refuses when HEAD is simply some other branch -----------------------
# Same root cause, before the merge: the item records the branch it was built on,
# and a reset run anywhere else moves the wrong ref.
landed_repo
git "${GIT_ID[@]}" checkout -q main
rc=0
before=$(git rev-parse HEAD)
out=$(bash "$REDO" implement "$KEY" --yes 2>&1) || rc=$?

if [ "$rc" -eq 1 ] && [ "$(git rev-parse HEAD)" = "$before" ]; then
    pass "a rewind run off the item's branch changes nothing"
else
    fail "a rewind run off the item's branch changes nothing" "exit: $rc" "$out"
fi

if [[ "$out" == *"feature/$KEY"* && "$out" == *"HEAD is main"* ]]; then
    pass "it names both branches — the item's and the one you are on"
else
    fail "it names both branches — the item's and the one you are on" "$out"
fi

# The item's own branch still rewinds. A guard that blocked the normal path would
# be the more expensive bug.
git "${GIT_ID[@]}" checkout -q "feature/$KEY"
bash "$REDO" implement "$KEY" --yes >/dev/null
if [ ! -f impl-1.txt ] && [ -f ".cue/dev/$KEY/plan.md" ]; then
    pass "on its own branch, an unlanded item still rewinds"
else
    fail "on its own branch, an unlanded item still rewinds"
fi

# --- it never proceeds without confirmation ---
full_repo
rc=0
out=$(printf 'no\n' | bash "$REDO" plan "$KEY" 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [ -f ".cue/dev/$KEY/plan.md" ]; then
    pass "anything but yes does not rewind"
else
    fail "anything but yes does not rewind" "exit: $rc" "$out"
fi

finish
