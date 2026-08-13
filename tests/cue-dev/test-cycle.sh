#!/usr/bin/env bash
# Full-cycle integration test (plan §10.5).
#
# The unit tests each hand-build a fixture for one script and look only at that
# one. So even when every script is right, nobody looks at the seams between them —
# does outcome-init find the directory work-init created, does status count the
# skeleton outcome-init wrote, does status read the point redo rewound to as the
# same stage?
#
# Here we walk start → design → plan → implement → finish in real order and ask
# status "where am I" at every transition. No LLM is called. The test stands in for
# the file writing and committing the skills prescribe; what is under test is how
# the scripts are wired together.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
S="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: full cycle (§10.5) ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=2026-08-03-timeout-config

# Checks whether a string is in status's output.
status_has() {
    local want=$1 label=$2 out
    out=$(bash "$S/status" "$KEY" 2>&1)
    case "$out" in
        *"$want"*) pass "$label" ;;
        *) fail "$label" "want: '$want'" "got:" "$out" ;;
    esac
}

status_lacks() {
    local unwanted=$1 label=$2 out
    out=$(bash "$S/status" "$KEY" 2>&1)
    case "$out" in
        *"$unwanted"*) fail "$label" "must not contain: '$unwanted'" "got:" "$out" ;;
        *) pass "$label" ;;
    esac
}

commit_all() {  # commit_all <subject>
    git add -A
    git "${GIT_ID[@]}" commit -qm "$1"
}

# ── 0. Prepare the repository ────────────────────────────────────────────────
new_repo main
printf '.cue/dev/sdd/\n' > .gitignore
commit_all "chore: ignore the scratch"

rc=0; bash "$S/init-check" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "0. init-check passes in a ready repository"
else
    fail "0. init-check passes in a ready repository" "exit: $rc"
fi

# ── 1. START ────────────────────────────────────────────────────────────────
# No markers stamped yet. status must say "not started here", and asking about
# work that does not exist must fail rather than guide.
rc=0; bash "$S/status" "$KEY" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "1. before starting, it answers that no work exists for that KEY"
else
    fail "1. before starting, it answers that no work exists for that KEY" "exit: $rc"
fi

# The branch name is the team's business now, and deliberately carries neither a
# cue-dev prefix nor the KEY: what makes this item findable is the branch: line
# start records in demand.md, which step 2 below writes.
git checkout -q -b "feat/hello-world"

rc=0; bash "$S/work-init" --check "$KEY" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "1. a KEY with no conflict passes --check"
else
    fail "1. a KEY with no conflict passes --check" "exit: $rc"
fi

work_out=$(bash "$S/work-init" "$KEY")
work_dir=$(printf '%s\n' "$work_out" | head -1)
if [ -d "$work_dir" ]; then
    pass "1. work-init creates the work directory"
else
    fail "1. work-init creates the work directory" "got: $work_out"
fi

{
    bash "$S/work-branch" --line
    printf '<!-- cue-dev · written 2026-08-03 · source: test fixture -->\n'
    # What this item asks for. verify compares it against outcome.md's checked-by
    # at the outcome marker below, so the cycle needs both halves to be real.
    printf '<!-- check: self-review -->\n'
    printf '\n# %s\n\n## Requirement\nRead the timeout value from a config file.\n' "$KEY"
    printf '\n## Acceptance criteria\n- the configured timeout is used\n- the default applies when the key is absent\n'
} > "$work_dir/demand.md"
commit_all "$(bash "$S/marker" demand "$KEY")"

# Everything from here is found through that line: this branch carries no KEY, so
# a status that still worked would be matching the directory listing against the
# name, which is the coupling the line removes.
if [ "$(bash "$S/work-branch" "$KEY")" = "feat/hello-world" ]; then
    pass "1. the branch it was cut onto is recorded, whatever it is called"
else
    fail "1. the branch it was cut onto is recorded, whatever it is called" \
        "got: $(bash "$S/work-branch" "$KEY" 2>&1)"
fi

status_has "▶ design" "1. after the demand marker, the caret sits on design"
status_has "/cue-dev:design" "1. it points at design as the next stage"

# ── 2. DESIGN ───────────────────────────────────────────────────────────────
# The in-between state: the file is written but not committed yet. In a real
# session this is what produced the contradiction "design.md ✓ but next is
# /cue-dev:design".
write_design "$KEY"
# The one section with content of its own: the rest is the frame verify requires,
# and this is the line a reviewer would actually read.
sed_i 's|^- doing nothing: .*|- environment variables: they differ per deployment, so the value could not be reviewed.|' \
    "$work_dir/design.md"
status_has "~" "2. an artifact written but not committed shows as ~"
status_has "▶ design" "2. an uncommitted artifact does not advance the stage"

commit_all "$(bash "$S/marker" design "$KEY")"
status_has "▶ plan" "2. after the design marker, the caret sits on plan"
status_lacks "~ design.md" "2. a committed artifact is no longer uncommitted"

# ── 3. PLAN ─────────────────────────────────────────────────────────────────
write_plan "$KEY" 2
sed_i 's|^### Task 1: step 1|### Task 1: config parser|; s|^### Task 2: step 2|### Task 2: default handling|' \
    "$work_dir/plan.md"

bash "$S/task-graph" "$KEY" >/dev/null 2>&1 || true
outcome_path=$(bash "$S/outcome-init" "$KEY" 2>/dev/null)
if [ -f "$work_dir/outcome.md" ]; then
    pass "3. outcome-init creates the skeleton"
else
    fail "3. outcome-init creates the skeleton" "got: $outcome_path"
fi

# The heart of the contract: the task count in plan.md and the row count in
# outcome.md must match. If they drift, a controller skipping a task goes unnoticed.
rows=$(grep -c '^- [0-9]* · unrecorded' "$work_dir/outcome.md" || true)
if [ "$rows" -eq 2 ]; then
    pass "3. one unrecorded row per task in plan.md ($rows)"
else
    fail "3. one unrecorded row per task in plan.md" "rows: $rows, want: 2"
fi

commit_all "$(bash "$S/marker" plan "$KEY")"
status_has "▶ implement" "3. after the plan marker, the caret sits on implement"
status_has "0/2" "3. no tasks recorded yet"

# ── 4. IMPLEMENT ────────────────────────────────────────────────────────────
# One code commit plus one outcome.md row replacement per task, and the row is
# committed in the same breath. That row replacement is the point judged to decide
# whether this project works, and committing it is what makes it survive a
# subagent's cleanup and a compaction.
printf 'timeout = 30\n' > config.ini
commit_all "feat: config parser"
sha1=$(git rev-parse --short HEAD)
sed_i "s|^- 1 · unrecorded|- 1 · $sha1 · as-planned|" "$work_dir/outcome.md"

status_has "1/2" "4. recording one task counts as 1/2"
status_has "/cue-dev:redo implement" "4. once implementation starts, the rewind is implement"

# The recommendation is implement, not plan — following the box must not destroy
# the plan along with the code. `plan` does appear now, on the line below, with
# every further rewind and with what taking one costs; that line exists because
# redo accepts them and status used to be the only thing saying otherwise. What
# must not happen is `plan` on the `rewind` line itself.
out=$(bash "$S/status" "$KEY" 2>&1)
if printf '%s\n' "$out" | grep -qE '^  rewind    /cue-dev:redo implement$'; then
    pass "4. it does not recommend a rewind that destroys the plan"
else
    fail "4. it does not recommend a rewind that destroys the plan" "$out"
fi
if printf '%s\n' "$out" | grep -q 'redo plan · design · demand  — further back'; then
    pass "4. but it still says the further rewinds exist, and what they cost"
else
    fail "4. but it still says the further rewinds exist, and what they cost" "$out"
fi

commit_all "chore: record task 1 — $KEY"
status_has "1/2" "4. the row still counts once it is committed"
status_lacks "▶ finish" "4. a committed row is not a finished implementation"

printf 'default = 10\n' >> config.ini
commit_all "feat: default handling"
sha2=$(git rev-parse --short HEAD)
sed_i "s|^- 2 · unrecorded|- 2 · $sha2 · as-planned|" "$work_dir/outcome.md"
commit_all "chore: record task 2 — $KEY"

status_lacks "open " "4. no unrecorded rows are left"

# The final review: the summary and the evidence fields, then the marker. This is
# the commit that used to be missing. Every row was already committed by the loop
# above, so finish's `git add` found nothing to stage, its commit died on "nothing
# added to commit", and the marker was never written — a whole item merged without
# one, and gate went on offering implement over finished work.
sed_i 's|^(write after implementation)|Finished as planned. Nothing left over.|' "$work_dir/outcome.md"
sed_i 's|^checked-by:.*|checked-by: self-review|; s|^evidence:.*|evidence:   tests-only|' "$work_dir/outcome.md"
status_has "~" "4. the final review's edit shows outcome.md as uncommitted"

git add -A
git "${GIT_ID[@]}" commit -q --allow-empty -m "$(bash "$S/marker" outcome "$KEY")"
status_has "implement ✓" "4. the outcome marker ticks implement"

# ── 5. FINISH ───────────────────────────────────────────────────────────────
# finish stamps nothing and is repeatable, so the caret stays on it. The record it
# integrates is already committed — that is the whole point of stamping at the end
# of implement rather than here.
status_has "▶ finish" "5. the caret stands on finish, which stamps nothing"
status_has "/cue-dev:finish" "5. it points at finish as the next command"
status_lacks "~" "5. no uncommitted artifacts remain"

# ── 6. What the whole cycle left behind ─────────────────────────────────────
for f in demand.md design.md plan.md outcome.md; do
    if [ -f "$work_dir/$f" ]; then
        pass "6. $f remains"
    else
        fail "6. $f remains"
    fi
done

if [ -z "$(git status --porcelain)" ]; then
    pass "6. no uncommitted artifacts once the cycle ends"
else
    fail "6. no uncommitted artifacts once the cycle ends" "$(git status --porcelain)"
fi

# Are the markers left in order? Whether the records and the code are on the same
# branch also surfaces here — on a different branch they would not show in this log.
markers=$(git log --format='%s' | grep -E '^cue-dev\((demand|design|plan|outcome)\): ' | sed 's/^cue-dev(\(.*\)): .*/\1/' | awk '{ a[NR] = $0 } END { for (i = NR; i >= 1; i--) print a[i] }' | paste -sd' ' -)
if [ "$markers" = "demand design plan outcome" ]; then
    pass "6. the four markers remain in order"
else
    fail "6. the four markers remain in order" "got: $markers"
fi

code_branch=$(git log --format='%H' -1 -- config.ini)
if git merge-base --is-ancestor "$code_branch" HEAD; then
    pass "6. the records are on the same branch as the code"
else
    fail "6. the records are on the same branch as the code"
fi

rc=0; out=$(bash "$S/init-check" 2>&1) || rc=$?
case "$out" in
    *"markers        present"*) pass "6. init-check knows markers now exist" ;;
    *) fail "6. init-check knows markers now exist" "$out" ;;
esac

# ── 7. Starting again with the same KEY is blocked ──────────────────────────
# Overwriting would lose the previous demand.md with no backup.
rc=0; out=$(bash "$S/work-init" "$KEY" 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"redo"* ]]; then
    pass "7. starting again with the same KEY is blocked and points at redo"
else
    fail "7. starting again with the same KEY is blocked and points at redo" "exit: $rc" "$out"
fi

# ── 8. redo rewinds to exactly one point in the cycle ───────────────────────
# The unit test looks at what redo deletes. What is under test here is whether
# status reads the rewound point as the same stage — if the two disagree, you are
# lost right after rewinding.
bash "$S/redo" plan "$KEY" --yes >/dev/null 2>&1
status_has "▶ plan" "8. after redo plan, the caret returns to plan"

if [ -f "$work_dir/design.md" ] && [ ! -f "$work_dir/plan.md" ]; then
    pass "8. redo plan keeps design and deletes only plan"
else
    fail "8. redo plan keeps design and deletes only plan" \
        "design.md: $([ -f "$work_dir/design.md" ] && echo present || echo absent)" \
        "plan.md: $([ -f "$work_dir/plan.md" ] && echo present || echo absent)"
fi

if git branch --list "$(bash "$S/config" --get backup_prefix)*" | grep -q .; then
    pass "8. what was rewound remains on a backup branch"
else
    fail "8. what was rewound remains on a backup branch" "$(git branch --list)"
fi

finish
