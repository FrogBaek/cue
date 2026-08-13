#!/usr/bin/env bash
# scripts/outcome-init: creates one unrecorded row per task in plan.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/outcome-init"
BRIEF="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/task-brief"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/outcome-init ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=2026-07-31-session-ttl

write_plan() {
    mkdir -p ".cue/dev/$KEY"
    cat > ".cue/dev/$KEY/plan.md" <<'PLAN'
# Session TTL Implementation Plan

**Goal:** attach a TTL

### Task 1: add a TTL field to the store

- [ ] Step 1

### Task 2: expiry sweeper job

- [ ] Step 1

An example plan is written like this.

```markdown
### Task 99: this is inside a code fence and must not be counted
```

### Task 3: expires_at in the API response

- [ ] Step 1
PLAN
}

new_repo main
write_plan

# --- normal creation ---
out=$(bash "$INIT" "$KEY" 2>/dev/null)
skel=".cue/dev/$KEY/outcome.md"

if [ -f "$skel" ]; then
    pass "creates outcome.md"
else
    fail "creates outcome.md"
fi

if [ "$out" = "$(pwd)/$skel" ]; then
    pass "prints the path it created"
else
    fail "prints the path it created" "got: $out"
fi

if [ "$(grep -c '^- [0-9][0-9]* · unrecorded$' "$skel")" -eq 3 ]; then
    pass "tasks inside a code fence are not counted (3)"
else
    fail "tasks inside a code fence are not counted (3)" "$(cat "$skel")"
fi

if grep -q '^- 1 · unrecorded$' "$skel" && grep -q '^- 3 · unrecorded$' "$skel" \
    && ! grep -q '^- 99 · unrecorded$' "$skel"; then
    pass "row numbers run consecutively from 1"
else
    fail "row numbers run consecutively from 1" "$(cat "$skel")"
fi

if grep -q '## Summary' "$skel" && grep -q '(write after implementation)' "$skel"; then
    pass "the summary placeholder is present"
else
    fail "the summary placeholder is present"
fi

if head -1 "$skel" | grep -q 'Never add or remove rows'; then
    pass "it carries the notice not to touch the rows"
else
    fail "it carries the notice not to touch the rows"
fi

# --- task numbers must agree with task-brief ---
if bash "$BRIEF" ".cue/dev/$KEY/plan.md" 3 "$TEST_ROOT/b3.md" >/dev/null 2>&1 \
    && grep -q 'expires_at in the API response' "$TEST_ROOT/b3.md"; then
    pass "task-brief's task 3 and the skeleton's row 3 are the same task"
else
    fail "task-brief's task 3 and the skeleton's row 3 are the same task"
fi

# --- it never overwrites existing records ---
sed_i 's/^- 1 · unrecorded$/- 1 · abc1234 · as-planned/' "$skel"
rc=0
msg=$(bash "$INIT" "$KEY" 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$msg" == *"already exists"* ]]; then
    pass "exit 1 when an outcome.md already exists"
else
    fail "exit 1 when an outcome.md already exists" "exit: $rc" "$msg"
fi

if grep -q '^- 1 · abc1234 · as-planned$' "$skel"; then
    pass "refusing does not erase the records"
else
    fail "refusing does not erase the records"
fi

# --- --force rebuilds it ---
bash "$INIT" "$KEY" --force >/dev/null 2>&1
if [ "$(grep -c '^- [0-9][0-9]* · unrecorded$' "$skel")" -eq 3 ]; then
    pass "--force resets it to the skeleton"
else
    fail "--force resets it to the skeleton" "$(cat "$skel")"
fi

# --- no plan.md ---
rc=0
bash "$INIT" NOPLAN-1 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "exit 1 when plan.md is missing"
else
    fail "exit 1 when plan.md is missing" "exit: $rc"
fi

# --- a plan.md with no tasks at all ---
mkdir -p ".cue/dev/EMPTY-1"
printf '# Plan\n\nNo task headers here.\n' > ".cue/dev/EMPTY-1/plan.md"
rc=0
msg=$(bash "$INIT" EMPTY-1 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$msg" == *"no tasks found"* ]]; then
    pass "exit 1 on zero tasks"
else
    fail "exit 1 on zero tasks" "exit: $rc" "$msg"
fi

# --- usage ---
rc=0
bash "$INIT" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "exit 2 with no arguments"
else
    fail "exit 2 with no arguments" "exit: $rc"
fi

finish
