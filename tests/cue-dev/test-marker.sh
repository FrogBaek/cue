#!/usr/bin/env bash
#
# scripts/marker is two things at once, and the second is what these tests are
# about. It prints the commit subject that stamps a stage — and because every
# stage skill is forbidden from assembling that string by hand, it is the one
# place every stage commit must pass through. So it is where the stage gate
# stands: no marker for records that do not pass scripts/verify.
#
# What that buys is visible in the run that motivated it. A hand-typed design.md
# (headings at `#` instead of `##`) was committed with no verify, implement then
# stamped its outcome marker with no verify either, and twelve errors from three
# stages arrived together at /cue-dev:finish — the one stage with nothing left to
# fix them in. Each of those commits called this script.
#
# The mechanism is the empty subject: git refuses `-m ""`, including under
# `--allow-empty`, so a refusal here stops the commit rather than merely
# complaining about it. That is asserted below rather than assumed, because the
# whole gate rests on it.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/cue-dev/helpers.sh
. "$HERE/helpers.sh"

REPO_ROOT="$(cd "$HERE/../.." && pwd)"
S="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts"
MARKER="$S/marker"

TEST_ROOT=$(mktemp -d)
trap cleanup EXIT

KEY=2026-08-12-marker-fixture

echo "=== Test: scripts/marker ==="

# --- the gate opens for a record that passes ---------------------------------

new_repo main
write_demand "$KEY"

if out=$("$MARKER" demand "$KEY" 2>/dev/null) && [ "$out" = "cue-dev(demand): $KEY" ]; then
    pass "a record that passes verify gets its marker"
else
    fail "a record that passes verify gets its marker" "got: ${out:-<empty>}"
fi

# --- and stays shut for one that does not ------------------------------------
#
# One heading removed. The point is not that verify catches it — test-verify.sh
# owns that — but that catching it reaches all the way to the commit.

sed_i '/^## Acceptance criteria/,$d' ".cue/dev/$KEY/demand.md"

rc=0
out=$("$MARKER" demand "$KEY" 2>/dev/null) || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "a record that fails verify is refused with exit 1"
else
    fail "a record that fails verify is refused with exit 1" "exit: $rc"
fi

if [ -z "$out" ]; then
    pass "nothing reaches stdout when it refuses"
else
    fail "nothing reaches stdout when it refuses" "got: $out"
fi

# stderr has to carry both halves: what verify objected to, and what that means
# here. A gate that will not open and cannot say why is the dead-end refusal
# scripts/gate exists to abolish.
errs=$("$MARKER" demand "$KEY" 2>&1 >/dev/null || true)
if [[ "$errs" == *"Acceptance criteria"* && "$errs" == *"no demand marker"* ]]; then
    pass "stderr carries verify's objection and what it blocks"
else
    fail "stderr carries verify's objection and what it blocks" "$errs"
fi

# --- the refusal actually stops the commit -----------------------------------
#
# The claim the whole gate rests on. Asserted for the plain form and for the
# --allow-empty form implement uses on the outcome marker: that flag permits an
# empty diff, never an empty subject.

before=$(git rev-parse HEAD)
git add -A
git "${GIT_ID[@]}" commit -qm "$("$MARKER" demand "$KEY" 2>/dev/null)" >/dev/null 2>&1 || true
if [ "$(git rev-parse HEAD)" = "$before" ]; then
    pass "git aborts on the empty subject, so no commit is made"
else
    fail "git aborts on the empty subject, so no commit is made" \
        "HEAD moved to $(git log -1 --format=%s)"
fi

git "${GIT_ID[@]}" commit -q --allow-empty -m "$("$MARKER" outcome "$KEY" 2>/dev/null)" >/dev/null 2>&1 || true
if [ "$(git rev-parse HEAD)" = "$before" ]; then
    pass "--allow-empty does not rescue an empty subject either"
else
    fail "--allow-empty does not rescue an empty subject either" \
        "HEAD moved to $(git log -1 --format=%s)"
fi

# --- warnings are not errors -------------------------------------------------
#
# The provenance header is a warning in verify. A gate that treated it as a
# refusal would make every stage commit conditional on a comment nobody reads.

new_repo main
write_demand "$KEY"
sed_i '/^<!-- cue-dev · written /d' ".cue/dev/$KEY/demand.md"

rc=0
out=$("$MARKER" demand "$KEY" 2>/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "cue-dev(demand): $KEY" ]; then
    pass "a warning does not close the gate"
else
    fail "a warning does not close the gate" "exit: $rc, got: ${out:-<empty>}"
fi

errs=$("$MARKER" demand "$KEY" 2>&1 >/dev/null || true)
if [[ "$errs" == *"provenance header"* ]]; then
    pass "but the warning is still said, on stderr"
else
    fail "but the warning is still said, on stderr" "${errs:-<empty>}"
fi

# A clean pass says nothing at all. This script runs inside `$(…)` on a commit
# line, so a `verify — ok` under every stage commit of every cycle would train
# the reader to skip the exact place the warnings appear.
new_repo main
write_demand "$KEY"
errs=$("$MARKER" demand "$KEY" 2>&1 >/dev/null || true)
if [ -z "$errs" ]; then
    pass "a clean pass is silent"
else
    fail "a clean pass is silent" "$errs"
fi

# --- outcome is verified as the implement stage ------------------------------
#
# The one stage whose name differs on the two sides: `outcome` is the marker
# implement stamps at its end, and the records it closes are what verify calls
# --stage implement. Getting this wrong would verify design-stage rules over a
# finished implementation and pass everything.

new_repo main
write_demand "$KEY"
write_design "$KEY"
write_plan "$KEY" 2
bash "$S/outcome-init" "$KEY" >/dev/null

rc=0
out=$("$MARKER" outcome "$KEY" 2>/dev/null) || rc=$?
if [ "$rc" -eq 1 ] && [ -z "$out" ]; then
    pass "an outcome marker over unrecorded rows is refused"
else
    fail "an outcome marker over unrecorded rows is refused" "exit: $rc, got: ${out:-<empty>}"
fi

errs=$("$MARKER" outcome "$KEY" 2>&1 >/dev/null || true)
if [[ "$errs" == *"unrecorded"* ]]; then
    pass "and it is refused for the implement-stage reason, not a design one"
else
    fail "and it is refused for the implement-stage reason, not a design one" "$errs"
fi

# --- usage errors are still usage errors -------------------------------------
#
# exit 2 is the shape of "you called this wrong" across every script here, and
# the new exit 1 must not swallow it.

rc=0; "$MARKER" nonsense "$KEY" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "an unknown stage is still exit 2, not the gate's exit 1"
else
    fail "an unknown stage is still exit 2, not the gate's exit 1" "exit: $rc"
fi

rc=0; "$MARKER" demand >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "a missing argument is still exit 2"
else
    fail "a missing argument is still exit 2" "exit: $rc"
fi

finish
