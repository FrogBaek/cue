#!/usr/bin/env bash
# scripts/task-graph: builds the dependency graph from symbol matches in Interfaces.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TG="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/task-graph"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

# A run whose failure is reported instead of swallowed.
#
# These were written as `tg "$KEY"`. Under `set -e` a
# non-zero exit killed the suite on the spot and the redirect had already thrown
# away the reason, so CI reported `exit 2` and nothing else — twice, for a run
# nobody could see. The output is kept and printed only when it is needed.
tg() {
    local out rc=0
    out=$(bash "$TG" "$@" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        fail "task-graph exited $rc for: $*" "$out"
    fi
    return 0
}

echo "=== Test: scripts/task-graph ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

new_repo main
KEY=2026-07-31-session-ttl
mkdir -p ".cue/dev/$KEY"
PLAN=".cue/dev/$KEY/plan.md"

cat > "$PLAN" <<'PLAN'
# Session TTL Implementation Plan

### Task 1: add a TTL field to the store

**Interfaces:**
- Consumes: (none)
- Produces: SessionStore.setTTL(id: string, ttl: number): Promise<void>

- [ ] **Step 1: Write the failing test**

### Task 2: expiry sweeper job

**Interfaces:**
- Consumes: SessionStore.setTTL
- Produces: SweepJob.run(): Promise<number>

- [ ] **Step 1: Write the failing test**

### Task 3: expires_at in the API response

**Interfaces:**
- Consumes: SessionStore.setTTL
- Produces: `GET /v1/sessions` response field

- [ ] **Step 1: Write the failing test**
PLAN

tg "$KEY"

if grep -q '^## Task dependencies$' "$PLAN"; then
    pass "adds the section"
else
    fail "adds the section" "$(cat "$PLAN")"
fi

if grep -q '^graph LR$' "$PLAN"; then
    pass "writes it as a mermaid graph LR"
else
    fail "writes it as a mermaid graph LR"
fi

for n in 1 2 3; do
    if grep -q "^    T$n\[\"$n\. " "$PLAN"; then
        pass "creates node T$n"
    else
        fail "creates node T$n" "$(sed -n '/graph LR/,$p' "$PLAN")"
    fi
done

if grep -q '^    T1 --> T2$' "$PLAN" && grep -q '^    T1 --> T3$' "$PLAN"; then
    pass "edges run producer → consumer"
else
    fail "edges run producer → consumer" "$(sed -n '/graph LR/,$p' "$PLAN")"
fi

if ! grep -qE '^    T[23] --> T1$' "$PLAN"; then
    pass "no reverse consumer → producer edges"
else
    fail "no reverse consumer → producer edges"
fi

if ! grep -qE '^    T([0-9]+) --> T\1$' "$PLAN"; then
    pass "no self edges"
else
    fail "no self edges"
fi

if [ "$(grep -c '^    T1 --> T2$' "$PLAN")" -eq 1 ]; then
    pass "no duplicate edges"
else
    fail "no duplicate edges"
fi

# --- idempotent ---
before=$(cat "$PLAN")
tg "$KEY"
tg "$KEY"
if [ "$before" = "$(cat "$PLAN")" ]; then
    pass "repeated runs produce the same result (idempotent)"
else
    fail "repeated runs produce the same result (idempotent)" "$(diff <(printf '%s' "$before") "$PLAN" | head -20)"
fi

if [ "$(grep -c '^## Task dependencies$' "$PLAN")" -eq 1 ]; then
    pass "the section is not duplicated"
else
    fail "the section is not duplicated"
fi

# --- the plan body is preserved ---
if grep -q '^### Task 2: expiry sweeper job$' "$PLAN" && grep -q 'Step 1: Write the failing test' "$PLAN"; then
    pass "it does not erase the original plan content"
else
    fail "it does not erase the original plan content"
fi

# --- interaction with outcome-init ---
# In the closing sequence task-graph runs first and outcome-init follows. The task
# count must stay the same after the graph section is appended (the mermaid code
# fence must not be counted as a task).
OI="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/outcome-init"
bash "$OI" "$KEY" >/dev/null 2>&1
if [ "$(grep -c '^- [0-9][0-9]* · unrecorded$' ".cue/dev/$KEY/outcome.md")" -eq 3 ]; then
    pass "the outcome task count stays 3 with the graph section appended"
else
    fail "the outcome task count stays 3 with the graph section appended" \
        "$(cat ".cue/dev/$KEY/outcome.md")"
fi
rm -f ".cue/dev/$KEY/outcome.md"

# --- label truncation ---
# The task name here is deliberately non-ASCII: byte-wise truncation would split a
# multi-byte character, and that is exactly what this checks.
cat > "$PLAN" <<'PLAN'
### Task 1: 아주아주아주아주아주아주아주 길고 긴 태스크 이름이라서 잘려야 한다

**Interfaces:**
- Produces: A.one
PLAN
tg "$KEY"
label=$(sed -n 's/^    T1\["1\. \(.*\)"\]$/\1/p' "$PLAN")
# Characters counted by dropping UTF-8 continuation bytes, not by asking a tool
# whether it understands the encoding. `${#var}` counts bytes in an empty locale,
# and awk counts bytes on macOS however the locale is set — an assertion resting
# on either measures the platform rather than the truncation.
u8len() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d ' '; }

label_len=$(u8len "$label")
if [ "$label_len" -le 30 ] && [[ "$label" == *"…" ]]; then
    pass "truncates labels longer than 30 characters (${label_len} chars)"
else
    fail "truncates labels longer than 30 characters" "len=$label_len: $label"
fi

# Truncation must land on a character boundary — cutting by bytes breaks
# multi-byte characters.
orig="아주아주아주아주아주아주아주 길고 긴 태스크 이름이라서 잘려야 한다"
kept=${label%…}

# Three facts pin the cut, and none of them asks a tool to decode anything: what
# was kept is 29 characters, it is the beginning of the original byte for byte,
# and it is still valid UTF-8. A cut inside a character satisfies the first two
# and fails the third — which is how one reached a later suite as
# `sed: RE error: illegal byte sequence`, a message about neither labels nor
# truncation.
if [ "$(u8len "$kept")" -eq 29 ]; then
    pass "the kept part is 29 characters"
else
    fail "the kept part is 29 characters" "got: $(u8len "$kept") — $kept"
fi

case "$orig" in
    "$kept"*) pass "the kept part is the beginning of the original" ;;
    *) fail "the kept part is the beginning of the original" "got: $kept" ;;
esac

# The boundary itself, read off the original: the byte where the cut fell must
# start a character rather than continue one. Stripping the continuation range
# from that single byte leaves it standing if it is a lead byte and removes it if
# it is not — the same rule u8len counts by, applied to one byte. Asking `iconv`
# would say the same thing and is not present on Git Bash.
rest=${orig#"$kept"}
boundary=$(printf '%s' "$rest" | head -c 1 | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d ' ')
if [ "$boundary" -eq 1 ]; then
    pass "the cut fell on a character boundary (a byte cut would not have)"
else
    fail "the cut fell on a character boundary (a byte cut would not have)" "got: $label"
fi

# --- double-quote escaping ---
cat > "$PLAN" <<'PLAN'
### Task 1: a "quoted" name

**Interfaces:**
- Produces: A.one
PLAN
tg "$KEY"
if grep -q '#quot;' "$PLAN" && [ "$(grep -c '^    T1\[' "$PLAN")" -eq 1 ]; then
    pass "escapes double quotes in a label"
else
    fail "escapes double quotes in a label" "$(sed -n '/graph LR/,$p' "$PLAN")"
fi

# --- zero edges: nodes only, no warning ---
cat > "$PLAN" <<'PLAN'
### Task 1: one

**Interfaces:**
- Produces: A.one

### Task 2: two

**Interfaces:**
- Produces: B.two
PLAN
rc=0
err=$(bash "$TG" "$KEY" 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [ -z "$err" ] && grep -q '^    T2\[' "$PLAN" && ! grep -q ' --> ' "$PLAN"; then
    pass "with no edges it writes nodes only and does not warn"
else
    fail "with no edges it writes nodes only and does not warn" "exit: $rc" "err: $err"
fi

# --- with every Interfaces block empty, no section is written ---
cat > "$PLAN" <<'PLAN'
### Task 1: one

- [ ] Step 1

### Task 2: two

- [ ] Step 1
PLAN
rc=0
err=$(bash "$TG" "$KEY" 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$err" == *"Interfaces blocks are empty"* ]] && ! grep -q 'Task dependencies' "$PLAN"; then
    pass "empty Interfaces warns and writes no section (exit 0)"
else
    fail "empty Interfaces warns and writes no section (exit 0)" "exit: $rc" "err: $err"
fi

# --- cycle warning ---
cat > "$PLAN" <<'PLAN'
### Task 1: one

**Interfaces:**
- Consumes: B.two
- Produces: A.one

### Task 2: two

**Interfaces:**
- Consumes: A.one
- Produces: B.two
PLAN
rc=0
err=$(bash "$TG" "$KEY" 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$err" == *"cycle"* ]] && grep -q ' --> ' "$PLAN"; then
    pass "a cycle warns but the graph is still written"
else
    fail "a cycle warns but the graph is still written" "exit: $rc" "err: $err"
fi

# --- warning above 15 nodes ---
{ for i in $(seq 1 16); do
    printf '### Task %d: task %d\n\n**Interfaces:**\n- Produces: S%d.sym\n\n' "$i" "$i" "$i"
  done; } > "$PLAN"
rc=0
err=$(bash "$TG" "$KEY" 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [[ "$err" == *"16 tasks"* ]] && grep -q '^    T16\[' "$PLAN"; then
    pass "more than 15 tasks warns but the graph is still written"
else
    fail "more than 15 tasks warns but the graph is still written" "exit: $rc" "err: $err"
fi

# --- tasks inside a code fence are ignored ---
cat > "$PLAN" <<'PLAN'
### Task 1: real

**Interfaces:**
- Produces: A.one

Example:

```markdown
### Task 99: fake

**Interfaces:**
- Produces: Z.zero
```
PLAN
tg "$KEY"
if grep -q '^    T1\[' "$PLAN" && ! grep -q '^    T99\[' "$PLAN"; then
    pass "tasks inside a code fence are ignored"
else
    fail "tasks inside a code fence are ignored" "$(sed -n '/graph LR/,$p' "$PLAN")"
fi

# --- no task headers: abort ---
printf '# Plan\n\nNo tasks here.\n' > "$PLAN"
rc=0
err=$(bash "$TG" "$KEY" 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$err" == *"no tasks found"* ]]; then
    pass "exit 1 when no task headers are found"
else
    fail "exit 1 when no task headers are found" "exit: $rc" "err: $err"
fi

# --- usage ---
rc=0
bash "$TG" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "exit 2 with no arguments"
else
    fail "exit 2 with no arguments" "exit: $rc"
fi

rc=0
bash "$TG" NOPE-1 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "exit 1 when plan.md is missing"
else
    fail "exit 1 when plan.md is missing" "exit: $rc"
fi

# --- where the section goes ---------------------------------------------------
#
# Above the first `## ` heading — the position design.md gives "## Structure".
# The fixtures above have no `## ` heading at all, so they exercise the fallback;
# this one is the shape scripts/skeleton actually writes.

write_positioned_plan() {
    cat > "$PLAN" <<'PLAN'
# Session TTL Implementation Plan

**Goal:** store a TTL.

## Global Constraints

- none

---

### Task 1: store

**Interfaces:**
- Consumes: none
- Produces: SessionStore.setTTL

### Task 2: sweeper

**Interfaces:**
- Consumes: SessionStore.setTTL
- Produces: none
PLAN
}

write_positioned_plan
tg "$KEY"

heading_line=$(grep -n '^## Task dependencies$' "$PLAN" | cut -d: -f1)
constraints_line=$(grep -n '^## Global Constraints$' "$PLAN" | cut -d: -f1)
goal_line=$(grep -n '^\*\*Goal:\*\*' "$PLAN" | cut -d: -f1)

if [ "$heading_line" -lt "$constraints_line" ] && [ "$heading_line" -gt "$goal_line" ]; then
    pass "the section sits under the preamble and above the first ## heading"
else
    fail "the section sits under the preamble and above the first ## heading" \
        "graph: $heading_line, goal: $goal_line, constraints: $constraints_line"
fi

if grep -q '^> `A → B`: B consumes what A produces' "$PLAN"; then
    pass "it says which way the arrows point"
else
    fail "it says which way the arrows point" "$(sed -n '1,12p' "$PLAN")"
fi

# Idempotent from the new position too: the second run must find and replace the
# section it wrote, not stack another above it.
before=$(cat "$PLAN")
tg "$KEY"
if [ "$before" = "$(cat "$PLAN")" ] && [ "$(grep -c '^## Task dependencies$' "$PLAN")" -eq 1 ]; then
    pass "re-running from the inserted position changes nothing"
else
    fail "re-running from the inserted position changes nothing" "$(cat "$PLAN")"
fi

# A `## ` inside a fenced block is sample text, not a heading. Anchoring on it
# would drop the graph into the middle of someone's code block.
cat > "$PLAN" <<'PLAN'
# Plan

**Goal:** demo.

### Task 1: writer

The step writes this file:

```markdown
## Report
```

**Interfaces:**
- Consumes: none
- Produces: Report.write

## Global Constraints

- none
PLAN
tg "$KEY"
if [ "$(grep -n '^## Task dependencies$' "$PLAN" | cut -d: -f1)" -gt "$(grep -n '^## Report$' "$PLAN" | cut -d: -f1)" ]; then
    pass "a ## inside a code fence is not used as the anchor"
else
    fail "a ## inside a code fence is not used as the anchor" "$(cat "$PLAN")"
fi

# --- `none` is an answer, not a symbol ----------------------------------------
#
# scripts/skeleton tells the planner to write `none` for a task that neither
# consumes nor produces. Matched as a symbol it joined every such task to every
# other, in both directions — a cycle warning over a plan with no dependencies.

write_positioned_plan
err=$(bash "$TG" "$KEY" 2>&1 >/dev/null) || true
if [[ "$err" != *"cycle"* ]]; then
    pass "two tasks answering 'none' are not a cycle"
else
    fail "two tasks answering 'none' are not a cycle" "$err"
fi

if [ "$(grep -c ' --> ' "$PLAN")" -eq 1 ] && grep -q '    T1 --> T2' "$PLAN"; then
    pass "'none' produces no edges, and the real edge survives"
else
    fail "'none' produces no edges, and the real edge survives" "$(cat "$PLAN")"
fi

# Answered-with-none is not the same as never answered: the first has been
# thought about and gets its node-only graph, the second gets told to fill it in.
cat > "$PLAN" <<'PLAN'
# Plan

### Task 1: one

**Interfaces:**
- Consumes: none
- Produces: none

### Task 2: two

**Interfaces:**
- Consumes: none
- Produces: none
PLAN
rc=0
err=$(bash "$TG" "$KEY" 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [ -z "$err" ] && grep -q '^    T2\[' "$PLAN" && ! grep -q ' --> ' "$PLAN"; then
    pass "a plan whose interfaces are all 'none' still gets its nodes"
else
    fail "a plan whose interfaces are all 'none' still gets its nodes" "exit: $rc" "err: $err"
fi

finish
