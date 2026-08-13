#!/usr/bin/env bash
# scripts/review-package: the diff a reviewer is handed, as one file.
#
# The script was the only shipped script with no suite of its own. What coverage
# it had lived in test-sdd-workspace.sh and was about *where* the file lands —
# nothing looked at what is in it, which is the part a reviewer's verdict rests
# on. A package that quietly loses a commit, or that carries the default three
# lines of context instead of ten, produces a review of something other than the
# work, and every reader downstream believes it.
#
# So the assertions here are about the contents and the range: every commit in
# the range listed, the net diff of the range rather than of the last commit, the
# wide context, and the arguments refused before any of that is written.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REVIEW_PACKAGE="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/review-package"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/review-package ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=PROJ-77

new_repo "cue-dev/$KEY"
write_plan "$KEY" 2
PLAN=".cue/dev/$KEY/plan.md"
git add -A
git "${GIT_ID[@]}" commit -qm "cue-dev(plan): $KEY"

BASE=$(git rev-parse HEAD)

# Three commits, so a package that silently reports only the last one is visible.
# survivor.txt is edited twice: the net diff must show one change from the base
# state to the final state, not two. transient.txt is created and then deleted
# inside the range, so a net diff must not mention it at all.
i=1
while [ "$i" -le 30 ]; do printf 'line %s\n' "$i" >> survivor.txt; i=$((i + 1)); done
git add -A
git "${GIT_ID[@]}" commit -qm "task 1: add survivor"
BASE_ONE_BACK=$(git rev-parse HEAD)

sed_i 's/^line 20$/line 20 CHANGED/' survivor.txt
printf 'temporary\n' > transient.txt
git add -A
git "${GIT_ID[@]}" commit -qm "task 2: change line 20, add transient"

git rm -q transient.txt
git "${GIT_ID[@]}" commit -qm "task 2: drop transient"
HEAD_SHA=$(git rev-parse HEAD)

# --- arguments -------------------------------------------------------------
# Refused before anything is written: the caller is a controller assembling a
# reviewer dispatch, and a package half-written from bad arguments is one it
# would hand over anyway.
for args in "" "$PLAN" "$PLAN $BASE" "$PLAN $BASE $HEAD_SHA out extra"; do
    rc=0
    # shellcheck disable=SC2086
    out=$("$REVIEW_PACKAGE" $args 2>&1) || rc=$?
    n=$(printf '%s' "$args" | wc -w | tr -d ' ')
    if [ "$rc" -eq 2 ] && [[ "$out" == *usage:* ]]; then
        pass "$n argument(s) is refused with the usage line and exit 2"
    else
        fail "$n argument(s) is refused with the usage line and exit 2" "rc=$rc" "$out"
    fi
done

rc=0
out=$("$REVIEW_PACKAGE" no-such-plan.md "$BASE" "$HEAD_SHA" 2>&1) || rc=$?
if [ "$rc" -eq 2 ] && [[ "$out" == *"no such plan file"* ]]; then
    pass "a plan file that does not exist is refused"
else
    fail "a plan file that does not exist is refused" "rc=$rc" "$out"
fi

rc=0
out=$("$REVIEW_PACKAGE" "$PLAN" nonexistent-ref "$HEAD_SHA" 2>&1) || rc=$?
if [ "$rc" -eq 2 ] && [[ "$out" == *"bad BASE"* ]]; then
    pass "an unresolvable BASE is named as BASE"
else
    fail "an unresolvable BASE is named as BASE" "rc=$rc" "$out"
fi

rc=0
out=$("$REVIEW_PACKAGE" "$PLAN" "$BASE" nonexistent-ref 2>&1) || rc=$?
if [ "$rc" -eq 2 ] && [[ "$out" == *"bad HEAD"* ]]; then
    pass "an unresolvable HEAD is named as HEAD"
else
    fail "an unresolvable HEAD is named as HEAD" "rc=$rc" "$out"
fi

# --- the package -----------------------------------------------------------
OUT="$TEST_ROOT/package.diff"
summary=$("$REVIEW_PACKAGE" "$PLAN" "$BASE" "$HEAD_SHA" "$OUT")

if [ -s "$OUT" ]; then
    pass "writes the package to an explicit OUTFILE"
else
    fail "writes the package to an explicit OUTFILE" "$summary"
fi

headings=$(grep -c '^## ' "$OUT" || true)
if [ "$headings" -eq 3 ] \
    && grep -q '^# Review package: ' "$OUT" \
    && grep -q '^## Commits$' "$OUT" \
    && grep -q '^## Files changed$' "$OUT" \
    && grep -q '^## Diff$' "$OUT"; then
    pass "carries the three sections a reviewer reads in one pass"
else
    fail "carries the three sections a reviewer reads in one pass" "## headings: $headings"
fi

# The reason the recorded per-task BASE is passed rather than HEAD~1: a task that
# took three commits is one task, and a package built from HEAD~1 would review
# the last of them as if it were the whole.
listed=$(sed -n '/^## Commits$/,/^$/p' "$OUT" | grep -c 'task ' || true)
if [ "$listed" -eq 3 ]; then
    pass "lists every commit in the range, not only the last"
else
    fail "lists every commit in the range, not only the last" "listed: $listed"
fi

if grep -q 'line 20 CHANGED' "$OUT" && [ "$(grep -c '^+line 20 CHANGED' "$OUT")" -eq 1 ]; then
    pass "a file edited twice in the range appears as one net change"
else
    fail "a file edited twice in the range appears as one net change"
fi

# Below the commit list, where the commit subjects that mention it no longer are.
if ! sed -n '/^## Files changed$/,$p' "$OUT" | grep -q 'transient'; then
    pass "a file created and deleted inside the range is absent from the net diff"
else
    fail "a file created and deleted inside the range is absent from the net diff"
fi

# -U10, not git's default 3. The reviewer cannot open the file — the package is
# the whole of what it sees — so the context is what makes a change readable.
#
# Measured from the commit after survivor.txt was created: over the full range
# the file is new, and a new file is all additions with no context to count.
CTX="$TEST_ROOT/context.diff"
"$REVIEW_PACKAGE" "$PLAN" "$BASE_ONE_BACK" "$HEAD_SHA" "$CTX" > /dev/null
if grep -q '^ line 10$' "$CTX" && grep -q '^ line 30$' "$CTX" && ! grep -q '^ line 9$' "$CTX"; then
    pass "the diff carries ten lines of context on each side, not git's default three"
else
    fail "the diff carries ten lines of context on each side, not git's default three" \
        "$(grep -c '^ line ' "$CTX" || true) context lines"
fi

commits=$(git rev-list --count "$BASE..$HEAD_SHA")
bytes=$(wc -c < "$OUT" | tr -d ' ')
if [[ "$summary" == *"$commits commit(s)"* && "$summary" == *"$bytes bytes"* ]]; then
    pass "the summary line reports the range's commit count and the file's size"
else
    fail "the summary line reports the range's commit count and the file's size" \
        "summary: $summary" "expected: $commits commit(s), $bytes bytes"
fi

# --- the default path is named per range -----------------------------------
# A re-review after fixes runs over a narrower range. If both wrote to one
# filename the second would overwrite the first, and a reviewer handed the stale
# path would review the code as it stood before the fixes.
first=$("$REVIEW_PACKAGE" "$PLAN" "$BASE" "$HEAD_SHA" | sed -n 's/^wrote \(.*\): [0-9].*$/\1/p')
second=$("$REVIEW_PACKAGE" "$PLAN" "$BASE_ONE_BACK" "$HEAD_SHA" | sed -n 's/^wrote \(.*\): [0-9].*$/\1/p')

base7=$(git rev-parse --short "$BASE")
head7=$(git rev-parse --short "$HEAD_SHA")
case "$first" in
    *"/review-$base7..$head7.diff") pass "the default filename carries the range it covers" ;;
    *) fail "the default filename carries the range it covers" "got: $first" ;;
esac

if [ "$first" != "$second" ] && [ -s "$first" ] && [ -s "$second" ]; then
    pass "a second range gets its own file and leaves the first standing"
else
    fail "a second range gets its own file and leaves the first standing" \
        "first: $first" "second: $second"
fi

finish
