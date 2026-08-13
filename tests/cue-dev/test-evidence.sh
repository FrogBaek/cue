#!/usr/bin/env bash
# scripts/evidence: the two facts finish's Step 1 must have in front of it.
#
# The defect it exists for: in a repository with no test runner, finish reported
# four browser observations no session had made. `evidence: manual` is a legal
# value and no script can ask what was looked at, so Step 1b was written as prose
# — and the next run said "there is no test suite, so I follow Step 1b" and moved
# on without relaying the field or asking the user. Both facts are mechanical, so
# neither is left to be remembered.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVIDENCE="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/evidence"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/evidence ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=PROJ-142

records() {  # records <checked-by> <evidence> <design "how we know" body>
    mkdir -p ".cue/dev/$KEY"
    printf '<!-- cue-dev -->\n\n# %s\n' "$KEY" > ".cue/dev/$KEY/demand.md"
    { printf '## Why this way\n\nbecause\n\n'
      printf '## How we know it works\n\n%s\n\n' "$3"
      printf '## Program design\n\nmodules\n'; } > ".cue/dev/$KEY/design.md"
    { printf '# %s — implementation outcome\n\n' "$KEY"
      printf 'checked-by: %s\n' "$1"
      printf 'evidence:   %s\n\n' "$2"
      printf '## Tasks\n\n- 1 · abc1234 · as-planned\n'; } > ".cue/dev/$KEY/outcome.md"
}

# --- it relays the claim verbatim --------------------------------------------
new_repo main
records self-review manual '- open every page in a browser and see it render'
git add -A && git "${GIT_ID[@]}" commit -qm "records"

out=$(bash "$EVIDENCE" "$KEY")
if [[ "$out" == *"checked-by: self-review"* && "$out" == *"evidence: manual"* ]]; then
    pass "it prints both header fields as they stand"
else
    fail "it prints both header fields as they stand" "$out"
fi

if [[ "$out" == *"open every page in a browser"* ]]; then
    pass "it prints the design's own definition of done"
else
    fail "it prints the design's own definition of done" "$out"
fi

# The question is the step. Without it the output is two facts and no obligation.
if [[ "$out" == *"which tool call in THIS session"* ]]; then
    pass "it asks what produced each observation"
else
    fail "it asks what produced each observation" "$out"
fi

# Printed even on the easy path: a check that only fires when the answer is hard
# is one nobody has practised.
records independent-review tests-only '- `npm test` is green'
git add -A && git "${GIT_ID[@]}" commit -qm "green records"
out=$(bash "$EVIDENCE" "$KEY")
if [[ "$out" == *"which tool call in THIS session"* ]]; then
    pass "the question is asked with a suite too"
else
    fail "the question is asked with a suite too" "$out"
fi

# --- a design that names no check says so ------------------------------------
# Silence here used to be indistinguishable from "nothing to check".
new_repo main
mkdir -p ".cue/dev/$KEY"
printf '<!-- cue-dev -->\n\n# %s\n' "$KEY" > ".cue/dev/$KEY/demand.md"
printf '## Why this way\n\nbecause\n' > ".cue/dev/$KEY/design.md"
{ printf 'checked-by: self-review\n'; printf 'evidence:   manual\n'; } > ".cue/dev/$KEY/outcome.md"
git add -A && git "${GIT_ID[@]}" commit -qm "no check named"

out=$(bash "$EVIDENCE" "$KEY")
if [[ "$out" == *"names no check"* ]]; then
    pass "a design with no 'How we know it works' is reported, not skipped"
else
    fail "a design with no 'How we know it works' is reported, not skipped" "$out"
fi

# --- it answers from the main checkout for an unmerged item ------------------
#
# This is where finish runs, and an item that has not merged has no `.cue/dev/`
# there — its records are committed on its own branch and nowhere else. The same
# gap cost finish-cleanup a whole run before the lookup learned to read the
# branch.
new_repo main
git "${GIT_ID[@]}" commit -q --allow-empty -m "base"
git "${GIT_ID[@]}" checkout -qb "feature/$KEY"
records self-review manual '- open page5.html and click the button'
git add -A && git "${GIT_ID[@]}" commit -qm "records on the branch"
git "${GIT_ID[@]}" checkout -q main

out=$(bash "$EVIDENCE" "$KEY")
if [[ "$out" == *"click the button"* ]]; then
    pass "records living only on the item's branch are found from main"
else
    fail "records living only on the item's branch are found from main" "$out"
fi

# --- what the dispatches left behind -----------------------------------------
#
# Only for an item that asked for independent-review, and only ever as a fact.
# Zero reports means either that no task was ever dispatched or that the
# workspace has been cleaned since; the script says both rather than picking, and
# a run that dispatched nothing is exactly where it wanted to be told.
new_repo main
records self-review tests-only '- the suite'
printf '<!-- check: independent-review -->\n\n# %s\n' "$KEY" > ".cue/dev/$KEY/demand.md"
printf '### Task 1: a\n\n### Task 2: b\n' > ".cue/dev/$KEY/plan.md"
git add -A && git "${GIT_ID[@]}" commit -qm "records"

out=$(bash "$EVIDENCE" "$KEY")
if [[ "$out" == *"reports"*"none in"* && "$out" == *"no task was dispatched"* ]]; then
    pass "an independent-review item with no reports says so, and says why it might be"
else
    fail "an independent-review item with no reports says so, and says why it might be" "$out"
fi

mkdir -p ".cue/dev/sdd/$KEY"
printf 'r\n' > ".cue/dev/sdd/$KEY/task-1-report.md"
printf 'r\n' > ".cue/dev/sdd/$KEY/task-2-report.md"
printf 'b\n' > ".cue/dev/sdd/$KEY/task-1-brief.md"
out=$(bash "$EVIDENCE" "$KEY")
if [[ "$out" == *"2 for 2 task(s)"* ]]; then
    pass "it counts the reports against the plan's task count, and only the reports"
else
    fail "it counts the reports against the plan's task count, and only the reports" "$out"
fi

# It is silent on this for a self-review item: there is nothing on disk to count
# and a `reports none` line under every such item is a warning about nothing.
printf '<!-- check: self-review -->\n\n# %s\n' "$KEY" > ".cue/dev/$KEY/demand.md"
git add -A && git "${GIT_ID[@]}" commit -qm "self-review now"
out=$(bash "$EVIDENCE" "$KEY")
if [[ "$out" != *"reports"* ]]; then
    pass "a self-review item is not asked about reports"
else
    fail "a self-review item is not asked about reports" "$out"
fi

# --- usage -------------------------------------------------------------------
rc=0
out=$(bash "$EVIDENCE" NO-SUCH-KEY 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"no records"* ]]; then
    pass "a KEY with no records anywhere is refused, not answered"
else
    fail "a KEY with no records anywhere is refused, not answered" "exit: $rc" "$out"
fi

rc=0
bash "$EVIDENCE" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && pass "exit 2 with no arguments" || fail "exit 2 with no arguments" "$rc"

finish
