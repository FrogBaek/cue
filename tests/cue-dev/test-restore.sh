#!/usr/bin/env bash
#
# scripts/restore: goes back to a backup branch scripts/redo left behind.
#
# Every rewind made one of these and printed its name; nothing knew how to use
# one. cue-dev:redo called the backup "the only recovery path" three times and
# never said how to walk it, so the recovery that actually happened in a real
# session was `git log` read by eye and a hand-rolled `git reset --hard` — the
# move the whole plugin exists to remove.
#
# The properties under test are the ones that make a restore safe rather than the
# ones that make it work. A restore is a second rewind pointing the other way: it
# discards whatever was done after the first one, so it needs the same preview,
# the same consent and a backup of its own. And it never picks the branch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
S="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts"
RESTORE="$S/restore"
REDO="$S/redo"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/restore ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=PROJ-142

# demand → design → plan, then two rewinds, so there are two backups to choose
# between. One candidate is the case that never teaches anything.
two_backups() {
    new_repo "feature/$KEY"
    commit_stage "$KEY" demand demand.md
    commit_stage "$KEY" design design.md
    write_skeleton "$KEY" 2
    commit_stage "$KEY" plan plan.md

    bash "$REDO" plan "$KEY" --yes >/dev/null      # backup 1 holds up to plan
    commit_stage "$KEY" plan plan.md               # a different plan
    sleep 1                                        # the branch name is a timestamp
    bash "$REDO" plan "$KEY" --yes >/dev/null      # backup 2 holds the second plan
}

backups_of() {
    git for-each-ref --format='%(refname:short)' "refs/heads/cue-dev/backup/${KEY}-*" | sort -r
}

# --- listing ------------------------------------------------------------------

two_backups
out=$(bash "$RESTORE" "$KEY")

if [ "$(printf '%s\n' "$out" | grep -c '^  backup ')" -eq 2 ]; then
    pass "it lists every backup for the KEY"
else
    fail "it lists every backup for the KEY" "$out"
fi

# The listing is the whole basis for the choice, so a date is not enough — two
# rewinds in one afternoon are "an hour ago" and "an hour ago".
if [[ "$out" == *"holds up to plan"* && "$out" == *"commit(s) not on"* && "$out" == *"made since"* ]]; then
    pass "each candidate names its stage and both commit counts"
else
    fail "each candidate names its stage and both commit counts" "$out"
fi

if [[ "$out" == *"nothing is chosen for you"* ]]; then
    pass "the listing says the choice is not being made"
else
    fail "the listing says the choice is not being made" "$out"
fi

before=$(git rev-parse HEAD)
bash "$RESTORE" "$KEY" >/dev/null
if [ "$(git rev-parse HEAD)" = "$before" ]; then
    pass "listing changes nothing"
else
    fail "listing changes nothing" "HEAD moved"
fi

# Another item's backups are that item's only recovery path and are never swept
# in — the same boundary scripts/backups holds.
git branch "cue-dev/backup/OTHER-1-20260101-000000" >/dev/null
out=$(bash "$RESTORE" "$KEY")
if [[ "$out" != *"OTHER-1"* ]]; then
    pass "another item's backups are not listed"
else
    fail "another item's backups are not listed" "$out"
fi

# --- it never picks -----------------------------------------------------------
#
# There is no --latest and a lone backup is not implied either. A rule that
# guesses when there is one candidate has never been practised on the day there
# are two, and the one wanted is usually the older.
out=$(bash "$RESTORE" "$KEY" --yes 2>&1 || true)
if [ "$(git rev-parse HEAD)" = "$before" ] && [[ "$out" == *"RESTORE candidates"* ]]; then
    pass "--yes without --to lists rather than restoring"
else
    fail "--yes without --to lists rather than restoring" "$out"
fi

# --to only accepts this item's backups. `--to main` is a request to reset the
# branch onto main, and it would have worked.
rc=0
out=$(bash "$RESTORE" "$KEY" --to main --dry-run 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"is not a backup branch of this item"* ]]; then
    pass "--to refuses a branch that is not one of this item's backups"
else
    fail "--to refuses a branch that is not one of this item's backups" "exit $rc" "$out"
fi

# --- the preview --------------------------------------------------------------

oldest=$(backups_of | tail -1)

out=$(bash "$RESTORE" "$KEY" --to "$oldest" --dry-run)
if [[ "$out" == *"RESTORE preview"* && "$out" == *"regain"* && "$out" == *"discard"* ]]; then
    pass "the preview counts both directions"
else
    fail "the preview counts both directions" "$out"
fi

if [[ "$out" == *"saved to a new backup branch first"* ]]; then
    pass "and says the current state is saved before anything moves"
else
    fail "and says the current state is saved before anything moves" "$out"
fi

if [[ "$out" == *"nothing was changed"* ]] && [ "$(git rev-parse HEAD)" = "$before" ]; then
    pass "--dry-run changes nothing and says so"
else
    fail "--dry-run changes nothing and says so" "$out"
fi

# Consent lives in the conversation. With no stdin there is no answer, and no
# answer is not yes — the same rule scripts/redo holds.
rc=0
out=$(bash "$RESTORE" "$KEY" --to "$oldest" </dev/null 2>&1) || rc=$?
if [ "$rc" -ne 0 ] && [ "$(git rev-parse HEAD)" = "$before" ]; then
    pass "EOF at the prompt is not consent"
else
    fail "EOF at the prompt is not consent" "exit $rc" "$out"
fi

# --- uncommitted work ---------------------------------------------------------
#
# This command is reached by someone trying to get something back. Losing
# something else on the way is the one outcome it must not have.
printf 'scratch\n' > ".cue/dev/$KEY/scratch.md"
rc=0
out=$(bash "$RESTORE" "$KEY" --to "$oldest" --dry-run 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"untracked"* ]]; then
    pass "it refuses when the record directory holds untracked files"
else
    fail "it refuses when the record directory holds untracked files" "exit $rc" "$out"
fi
rm ".cue/dev/$KEY/scratch.md"

printf 'changed\n' >> ".cue/dev/$KEY/demand.md"
rc=0
out=$(bash "$RESTORE" "$KEY" --to "$oldest" --dry-run 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"uncommitted changes"* ]]; then
    pass "it refuses when tracked files have uncommitted changes"
else
    fail "it refuses when tracked files have uncommitted changes" "exit $rc" "$out"
fi
git checkout -q -- ".cue/dev/$KEY/demand.md"

# An untracked file elsewhere in the tree is not this script's business. Refusing
# over it would make the refusal the normal case — a real session's repository
# carried an untracked `.claude/` throughout.
mkdir -p .claude && printf 'x\n' > .claude/settings.json
rc=0
bash "$RESTORE" "$KEY" --to "$oldest" --dry-run >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "an untracked file outside the record directory is not an obstacle"
else
    fail "an untracked file outside the record directory is not an obstacle" "exit $rc"
fi
rm -rf .claude

# --- restoring ----------------------------------------------------------------

before_count=$(git rev-list --count HEAD)
out=$(bash "$RESTORE" "$KEY" --to "$oldest" --yes)

if [ "$(git rev-parse HEAD)" = "$(git rev-parse "$oldest")" ]; then
    pass "HEAD lands on the chosen backup"
else
    fail "HEAD lands on the chosen backup" "$(git log --oneline -3)"
fi

if [ -f ".cue/dev/$KEY/plan.md" ] && [ "$(git rev-list --count HEAD)" -gt "$before_count" ]; then
    pass "the rewound commits and their records come back"
else
    fail "the rewound commits and their records come back" "$(ls ".cue/dev/$KEY")"
fi

# The restore is itself a rewind, so it is itself undoable.
if [ "$(backups_of | grep -c .)" -eq 3 ]; then
    pass "the state before the restore is kept as a new backup"
else
    fail "the state before the restore is kept as a new backup" "$(backups_of)"
fi

if [[ "$out" == *"saved"* ]] && [[ "$out" == *"the way back"* ]]; then
    pass "and the box names it as the way back"
else
    fail "and the box names it as the way back" "$out"
fi

# The question that used to go unasked. Nothing in cue-dev said anything about a
# backup once it had been used, so the branch sat in `git branch` looking like a
# recovery path it no longer was.
if [[ "$out" == *"stale"*"$oldest"* && "$out" == *"git branch -D $oldest"* ]]; then
    pass "the consumed backup is reported as stale, with the command to drop it"
else
    fail "the consumed backup is reported as stale, with the command to drop it" "$out"
fi

# It reports, it does not delete: the same rule scripts/redo follows for the
# earlier backups it lists.
if git rev-parse --verify --quiet "refs/heads/$oldest" >/dev/null; then
    pass "but it does not delete it — that is the user's call"
else
    fail "but it does not delete it — that is the user's call"
fi

if [[ "$out" == *"other backup(s) for this item remain"* ]]; then
    pass "the backups that are still recovery paths are counted, not dropped"
else
    fail "the backups that are still recovery paths are counted, not dropped" "$out"
fi

# --- the two refusals scripts/redo makes, made here too -----------------------
#
# A restore is a reset and reaches the same wrong branch in the same two ways.

new_repo main
BASE=$(git rev-parse HEAD)
git "${GIT_ID[@]}" checkout -qb "feature/$KEY"
mkdir -p ".cue/dev/$KEY"
{ printf '<!-- base: main @ %s -->\n' "$(git rev-parse --short "$BASE")"
  printf '<!-- branch: feature/%s -->\n\n# %s\n' "$KEY" "$KEY"; } > ".cue/dev/$KEY/demand.md"
git add -A && git "${GIT_ID[@]}" commit -qm "cue-dev(demand): $KEY"
commit_stage "$KEY" design design.md
# The outcome marker is what `landed` is asked about — a branch merged before the
# implementation finished has not landed anything.
write_skeleton "$KEY" 1
sed_i 's/^- 1 · unrecorded$/- 1 · aaa1111 · as-planned/' ".cue/dev/$KEY/outcome.md"
commit_stage "$KEY" plan plan.md
git add -A && git "${GIT_ID[@]}" commit -q --allow-empty -m "cue-dev(outcome): $KEY"
git branch "cue-dev/backup/${KEY}-20260101-000000" >/dev/null

git "${GIT_ID[@]}" checkout -q main
rc=0
out=$(bash "$RESTORE" "$KEY" --to "cue-dev/backup/${KEY}-20260101-000000" --yes 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"HEAD is main"* ]]; then
    pass "it refuses when the item's branch is not the one checked out"
else
    fail "it refuses when the item's branch is not the one checked out" "exit $rc" "$out"
fi

git "${GIT_ID[@]}" merge -q --no-ff "feature/$KEY" -m "land $KEY"
git "${GIT_ID[@]}" checkout -q "feature/$KEY"
rc=0
out=$(bash "$RESTORE" "$KEY" --to "cue-dev/backup/${KEY}-20260101-000000" --yes 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"has landed"* ]]; then
    pass "it refuses once the work has landed in its base"
else
    fail "it refuses once the work has landed in its base" "exit $rc" "$out"
fi

# --- nothing to restore -------------------------------------------------------

new_repo "feature/$KEY"
commit_stage "$KEY" demand demand.md
rc=0
out=$(bash "$RESTORE" "$KEY" 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"no backup branches"* ]]; then
    pass "an item that was never rewound says so, rather than listing nothing"
else
    fail "an item that was never rewound says so, rather than listing nothing" "exit $rc" "$out"
fi

rc=0; bash "$RESTORE" "$KEY" --to >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "--to with no value is a usage error"
else
    fail "--to with no value is a usage error" "exit: $rc"
fi

rc=0; bash "$RESTORE" "bad/key" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "a KEY containing a slash is refused"
else
    fail "a KEY containing a slash is refused" "exit: $rc"
fi

finish
