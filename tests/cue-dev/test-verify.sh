#!/usr/bin/env bash
#
# scripts/verify is the gate the stage skills point at instead of running a prose
# checklist themselves. These tests pin the two properties that make that
# substitution safe: it catches what the prose used to catch, and it never fails a
# record that is merely thin.
#
# The second half matters as much as the first. A checker that starts objecting to
# short-but-complete records would push every skill back into padding documents to
# please it, which is the failure the length limits exist to prevent.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/cue-dev/helpers.sh
. "$HERE/helpers.sh"

REPO_ROOT="$(cd "$HERE/../.." && pwd)"
VERIFY="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/verify"
OUTCOME_INIT="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/outcome-init"

TEST_ROOT=$(mktemp -d)
trap cleanup EXIT

KEY=2026-08-05-verify-fixture

# A complete, minimal, entirely valid work item. Every test below starts from
# this and breaks exactly one thing, so a failure names its own cause.
write_records() {
    mkdir -p ".cue/dev/$KEY"
    cat > ".cue/dev/$KEY/demand.md" <<'EOF'
<!-- cue-dev · written 2026-08-05 · source: conversation -->
# fixture — a requirement

## Requirement
Store the session TTL somewhere that survives a restart.

## Acceptance criteria
not specified
EOF
    cat > ".cue/dev/$KEY/design.md" <<'EOF'
> This document reflects the judgment as of 2026-08-05 and is not updated.

## Structure
no structural change

## What we build
A TTL field on the session record.

## Worked example
A session created at 12:00 with ttl=3600 is refused at 13:01.

## Why this way
The store already round-trips a struct; a field costs nothing.

## Rejected alternatives
- a separate expiry table: one approach was available and the space was narrow.

## Divergence from demand
none

## Constraints at the time
The store is in-memory and restarts lose it.

## Program design
- SessionStore owns expiry; callers never compute it.

## How we know it works
The existing store suite covers it.

## Planned contract changes
none
EOF
    cat > ".cue/dev/$KEY/plan.md" <<'EOF'
# TTL Implementation Plan

**Goal:** Persist the session TTL.

**Architecture:** One field, one accessor.

**Tech Stack:** TypeScript

## Global Constraints
- No new dependencies.

---

### Task 1: add the field

**Files:**
- Modify: `src/session/store.ts:40-88`

**Interfaces:**
- Produces: SessionStore.setTTL(id: string, ttl: number): Promise<void>

- [ ] **Step 1: Write the failing test**

```ts
// TODO: this lives inside a fence and must not read as an unfinished plan
```

### Task 2: use it

**Files:**
- Modify: `src/api/sessions.ts`

**Interfaces:**
- Consumes: SessionStore.setTTL
EOF
}

record_rows() {
    local sha=$1
    # Row 1 gets the SHA and the rest get `no-commit`. One SHA across every row is
    # what a real run produced when a verification task had no commit of its own —
    # it reached for the previous task's — and verify refuses that now, so a
    # fixture written that way fails for a reason none of these assertions is
    # about.
    sed_i "s/^- 1 · unrecorded$/- 1 · ${sha} · as-planned/" ".cue/dev/$KEY/outcome.md"
    sed_i "s/^- \([0-9][0-9]*\) · unrecorded$/- \1 · no-commit · as-planned/" ".cue/dev/$KEY/outcome.md"
    sed_i "s/^checked-by: unrecorded/checked-by: independent-review/" ".cue/dev/$KEY/outcome.md"
    sed_i "s/^evidence:   unrecorded/evidence:   red-output/" ".cue/dev/$KEY/outcome.md"
}

# Runs verify and reports the exit code alongside the output, so an assertion can
# distinguish "complained" from "failed".
run_verify() {
    VERIFY_OUT=$(bash "$VERIFY" "$KEY" 2>&1) && VERIFY_RC=0 || VERIFY_RC=$?
}

# --- a complete record passes -------------------------------------------------

new_repo main
write_records
bash "$OUTCOME_INIT" "$KEY" >/dev/null 2>&1
git add -A && git "${GIT_ID[@]}" commit -qm "records"
record_rows "$(git rev-parse --short HEAD)"

run_verify
if [ "$VERIFY_RC" -eq 0 ]; then
    pass "a complete record passes"
else
    fail "a complete record passes" "$VERIFY_OUT"
fi

# The fixture's design is deliberately terse — three sentences a section, "none"
# for contracts, one rejected alternative saying the space was narrow. If verify
# ever fails this, it has started judging depth.
if [[ "$VERIFY_OUT" != *ERROR* ]]; then
    pass "a terse but complete design is not a defect"
else
    fail "a terse but complete design is not a defect" "$VERIFY_OUT"
fi

# --- missing sections ---------------------------------------------------------

for section in "Worked example" "Rejected alternatives" "Divergence from demand" "How we know it works"; do
    new_repo main
    write_records
    sed_i "/^## ${section}$/d" ".cue/dev/$KEY/design.md"
    run_verify
    if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"$section"* ]]; then
        pass "a missing '## $section' fails"
    else
        fail "a missing '## $section' fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
    fi
done

# --- a heading at the wrong level ----------------------------------------------
#
# The same failure, one `#` short, and the error has to say so. `no '## Structure'
# section` over a file whose third line reads `# Structure` was read as a false
# positive in a real session: the model reported "design.md is present and
# complete", re-ran verify six times, and burned a compaction before a `sed` fixed
# the levels. Since scripts/marker turned this report into a gate, a refusal that
# cannot be acted on is worse than the six lost calls.

new_repo main
write_records
sed_i 's|^## Structure$|# Structure|' ".cue/dev/$KEY/design.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"wrong heading level"* && "$VERIFY_OUT" == *"found '# Structure'"* ]]; then
    pass "a heading at the wrong level says what it found, not that nothing is there"
else
    fail "a heading at the wrong level says what it found, not that nothing is there" \
        "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# The same message under a genuinely absent heading would be a lie, so the two
# stay distinguishable.
new_repo main
write_records
sed_i '/^## Structure$/d' ".cue/dev/$KEY/design.md"
run_verify
if [[ "$VERIFY_OUT" == *"no '## Structure' section"* && "$VERIFY_OUT" != *"wrong heading level"* ]]; then
    pass "an absent heading still reports as absent"
else
    fail "an absent heading still reports as absent" "$VERIFY_OUT"
fi

# demand.md's headings are matched as a prefix rather than whole, and get the same
# treatment — the check that differs must not be the message that differs.
new_repo main
write_records
sed_i 's|^## Requirement|#### Requirement|' ".cue/dev/$KEY/demand.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"wrong heading level"* && "$VERIFY_OUT" == *"#### Requirement"* ]]; then
    pass "demand.md reports a wrong heading level the same way"
else
    fail "demand.md reports a wrong heading level the same way" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- an empty divergence section ----------------------------------------------
# The heading present with nothing under it is the state that has to fail: a
# design that diverged and did not say so is indistinguishable from one that did
# not diverge, and "none" is the whole cost of telling them apart.

new_repo main
write_records
# The `;` before `}` is required by BSD sed, which otherwise reads `}` as a flag
# on the substitute command. GNU sed accepts it either way.
sed_i '/^## Divergence from demand$/{n;s/^none$//;}' ".cue/dev/$KEY/design.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"Divergence from demand"* ]]; then
    pass "an empty 'Divergence from demand' fails"
else
    fail "an empty 'Divergence from demand' fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- placeholders -------------------------------------------------------------

new_repo main
write_records
run_verify
if [[ "$VERIFY_OUT" != *"unfinished placeholder"* ]]; then
    pass "a TODO inside a code fence is not a placeholder"
else
    fail "a TODO inside a code fence is not a placeholder" "$VERIFY_OUT"
fi

new_repo main
write_records
printf '\nTBD: decide the eviction policy\n' >> ".cue/dev/$KEY/design.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"unfinished placeholder"* ]]; then
    pass "a TBD in prose fails"
else
    fail "a TBD in prose fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- contract-change format ---------------------------------------------------

new_repo main
write_records
sed_i 's|^none$|- we will probably change the sessions endpoint|' ".cue/dev/$KEY/design.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"kind: target"* ]]; then
    pass "a contract line without the fixed shape fails"
else
    fail "a contract line without the fixed shape fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

new_repo main
write_records
sed_i 's|^none$|- api: POST /v1/sessions — add expires_at (backward compatible)|' ".cue/dev/$KEY/design.md"
run_verify
if [ "$VERIFY_RC" -eq 0 ]; then
    pass "a correctly shaped contract line passes"
else
    fail "a correctly shaped contract line passes" "$VERIFY_OUT"
fi

# --- rows against tasks -------------------------------------------------------

new_repo main
write_records
bash "$OUTCOME_INIT" "$KEY" >/dev/null 2>&1
git add -A && git "${GIT_ID[@]}" commit -qm "records"

run_verify
if [ "$VERIFY_RC" -eq 0 ] && [[ "$VERIFY_OUT" == *"still unrecorded"* ]]; then
    pass "unrecorded rows before implementation are a warning, not an error"
else
    fail "unrecorded rows before implementation are a warning, not an error" \
         "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

echo "- 3 · unrecorded" >> ".cue/dev/$KEY/outcome.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"3 rows for 2 tasks"* ]]; then
    pass "an added row fails against the plan's task count"
else
    fail "an added row fails against the plan's task count" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- a row must name a commit that exists -------------------------------------

new_repo main
write_records
bash "$OUTCOME_INIT" "$KEY" >/dev/null 2>&1
git add -A && git "${GIT_ID[@]}" commit -qm "records"
record_rows "deadbee"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"commit that does not exist"* ]]; then
    pass "a row naming a commit that does not exist fails"
else
    fail "a row naming a commit that does not exist fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- the evidence level -------------------------------------------------------
#
# demand.md's `check:` holds what this item asked for, outcome.md's `checked-by`
# holds what happened. The comparison is the reason both exist; a field that echoed
# the request would prove nothing.
#
# Both halves are per item now. The asked-for level used to be `min_check` in the
# config, one number for a whole repository, which could not be right for a colour
# change and a migration at once — and which parallel worktrees each held their own
# copy of. A leftover config line is still read, for items recorded before the
# move, and that fallback is pinned below.

new_repo main
write_records
bash "$OUTCOME_INIT" "$KEY" >/dev/null 2>&1
git add -A && git "${GIT_ID[@]}" commit -qm "records"
record_rows "$(git rev-parse --short HEAD)"
sed_i 's/^checked-by: independent-review/checked-by: self-review/' ".cue/dev/$KEY/outcome.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"this item asked for"* ]]; then
    pass "checked-by below what the item asked for fails"
else
    fail "checked-by below what the item asked for fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# Which record it read is part of the answer. `default — nothing recorded` and
# `demand.md header` lead to different fixes, and a message naming neither sent the
# reader to the config, which is no longer where the answer is.
if [[ "$VERIFY_OUT" == *"asked for in:"* ]]; then
    pass "it names where the asked-for level came from"
else
    fail "it names where the asked-for level came from" "$VERIFY_OUT"
fi

# The item's own header is the first source, and it beats everything else.
# Prepends with the shell rather than with `sed 1i`, whose GNU one-line form BSD
# sed rejects outright ("command i expects \ followed by text").
header_check() {
    local f=".cue/dev/$KEY/demand.md"
    { printf '<!-- check: %s -->\n' "$1"; cat "$f"; } > "$f.tmp" && mv "$f.tmp" "$f"
}
drop_check()   { sed_i '/^<!-- check: /d' ".cue/dev/$KEY/demand.md"; }

header_check self-review
run_verify
if [ "$VERIFY_RC" -eq 0 ]; then
    pass "the same record passes once the item asked for that level"
else
    fail "the same record passes once the item asked for that level" "$VERIFY_OUT"
fi

# A repository still carrying the retired setting is one that answered this once.
# Honouring it is what keeps a plugin upgrade from re-judging work already in
# flight — so it applies only where the item itself is silent.
drop_check
mkdir -p .cue/dev && printf 'min_check=self-review\n' > .cue/dev/config
run_verify
if [ "$VERIFY_RC" -eq 0 ]; then
    pass "a legacy min_check line is honoured when the item recorded nothing"
else
    fail "a legacy min_check line is honoured when the item recorded nothing" "$VERIFY_OUT"
fi

header_check independent-review
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"demand.md header"* ]]; then
    pass "the item's own header beats the legacy setting"
else
    fail "the item's own header beats the legacy setting" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi
drop_check

# `checked-by: none` fails in every repository, because no floor may be set to
# `none` any more. That is the whole design: the value stays writable so a run
# nothing reviewed can say so, and it stops here once, per item, in front of a
# human — rather than being waived at init for everything that follows.
printf 'min_check=self-review\n' > .cue/dev/config
sed_i 's/^checked-by: self-review/checked-by: none/' ".cue/dev/$KEY/outcome.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"nothing read this work's diff"* ]]; then
    pass "checked-by: none fails even at the lowest settable floor"
else
    fail "checked-by: none fails even at the lowest settable floor" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# It has to separate two things that read alike: the setting *is* changeable, and
# neither of its values clears this. Collapsed into "no setting makes it", the
# message reads as "the settings are locked" — which is false, and sends the
# reader looking for a way to unlock them.
if [[ "$VERIFY_OUT" == *"neither check level clears this"* ]]; then
    pass "it says no level clears this, rather than implying a setting might"
else
    fail "it says no level clears this, rather than implying a setting might" "$VERIFY_OUT"
fi

# The rows themselves are unaffected — verify's completeness checks never looked
# at min_check. Worth pinning, because "nothing was checked" was mistaken for
# "nothing was recorded", and the two lead to opposite designs.
if [[ "$VERIFY_OUT" != *"unrecorded"* ]]; then
    pass "an unchecked run still has complete task rows"
else
    fail "an unchecked run still has complete task rows" "$VERIFY_OUT"
fi

printf 'min_check=self-review\n' > .cue/dev/config
sed_i 's/^checked-by: none/checked-by: thoroughly/' ".cue/dev/$KEY/outcome.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"checked-by must be"* ]]; then
    pass "a checked-by outside the allowed set fails"
else
    fail "a checked-by outside the allowed set fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- one commit recorded for two tasks ---------------------------------------
#
# The row format asks for "that task's last commit", and a task that produced no
# commit had no answer to that: a real run gave task 10 ("integration test and
# final verification") the SHA already recorded for task 9. Every check passed —
# the commit exists, it is on the branch, no row is unrecorded — and the record
# said one commit had delivered two tasks.

new_repo main
write_records
bash "$OUTCOME_INIT" "$KEY" >/dev/null 2>&1
git add -A && git "${GIT_ID[@]}" commit -qm "records"
sha=$(git rev-parse --short HEAD)
sed_i "s/^- \([0-9][0-9]*\) · unrecorded$/- \1 · ${sha} · as-planned/" ".cue/dev/$KEY/outcome.md"
sed_i "s/^checked-by: unrecorded/checked-by: independent-review/" ".cue/dev/$KEY/outcome.md"
sed_i "s/^evidence:   unrecorded/evidence:   red-output/" ".cue/dev/$KEY/outcome.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"recorded for more than one task"* ]]; then
    pass "one SHA across two rows is an error"
else
    fail "one SHA across two rows is an error" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# And the way out is a value, not a better SHA to reach for.
sed_i "s/^- 2 · ${sha} · as-planned$/- 2 · no-commit · as-planned/" ".cue/dev/$KEY/outcome.md"
run_verify
if [ "$VERIFY_RC" -eq 0 ]; then
    pass "no-commit is a legal value in the SHA slot"
else
    fail "no-commit is a legal value in the SHA slot" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- unrecorded evidence once every task is in --------------------------------

new_repo main
write_records
bash "$OUTCOME_INIT" "$KEY" >/dev/null 2>&1
git add -A && git "${GIT_ID[@]}" commit -qm "records"
sha=$(git rev-parse --short HEAD)
sed_i "s/^- \([0-9][0-9]*\) · unrecorded$/- \1 · ${sha} · as-planned/" ".cue/dev/$KEY/outcome.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"checked-by is still 'unrecorded'"* ]]; then
    pass "every task recorded but no checked-by fails"
else
    fail "every task recorded but no checked-by fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- the two header fields joined onto one line -------------------------------
# `checked-by: self-review evidence: manual` reached a real record. Both fields
# are matched anchored to the start of a line, so the join silently drops
# `evidence` — and this is what should have stopped it before the commit.

new_repo main
write_records
bash "$OUTCOME_INIT" "$KEY" >/dev/null 2>&1
git add -A && git "${GIT_ID[@]}" commit -qm "records"
sha=$(git rev-parse --short HEAD)
sed_i "s/^- \([0-9][0-9]*\) · unrecorded$/- \1 · ${sha} · as-planned/" ".cue/dev/$KEY/outcome.md"
sed_i -e '/^evidence:/d' \
       -e 's/^checked-by: unrecorded$/checked-by: self-review evidence: manual/' \
       ".cue/dev/$KEY/outcome.md"
run_verify
if [ "$VERIFY_RC" -ne 0 ] && [[ "$VERIFY_OUT" == *"no 'evidence:' line"* ]]; then
    pass "checked-by and evidence joined onto one line fails"
else
    fail "checked-by and evidence joined onto one line fails" "rc=$VERIFY_RC" "$VERIFY_OUT"
fi

# --- a stage that has not run is not a defect ---------------------------------

new_repo main
mkdir -p ".cue/dev/$KEY"
cat > ".cue/dev/$KEY/demand.md" <<'EOF'
<!-- cue-dev · written 2026-08-05 · source: conversation -->
# fixture

## Requirement
r

## Acceptance criteria
not specified
EOF
run_verify
if [ "$VERIFY_RC" -eq 0 ]; then
    pass "demand alone passes — design has simply not run yet"
else
    fail "demand alone passes — design has simply not run yet" "$VERIFY_OUT"
fi

# --- usage --------------------------------------------------------------------

new_repo main
if bash "$VERIFY" 2>/dev/null; then
    fail "no KEY is a usage error" "it exited 0"
else
    rc=$?
    [ "$rc" -eq 2 ] && pass "no KEY is a usage error" \
                    || fail "no KEY is a usage error" "expected exit 2, got $rc"
fi

if bash "$VERIFY" no-such-key 2>/dev/null; then
    fail "an unknown KEY is a usage error" "it exited 0"
else
    rc=$?
    [ "$rc" -eq 2 ] && pass "an unknown KEY is a usage error" \
                    || fail "an unknown KEY is a usage error" "expected exit 2, got $rc"
fi

finish
