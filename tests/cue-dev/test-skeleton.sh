#!/usr/bin/env bash
# scripts/skeleton: the frame of design.md and plan.md, written by a script.
#
# The regression it closes is a language one. Both skills say prose follows the
# record language, then hand over a template that mixes prose with literals
# `scripts/verify` greps for — and every real session translated some of the
# literals. `**Goal:**` became `**목표:**`; `Planned contract changes` was
# answered `없음`. One session lost two rewrites of plan.md to it.
#
# So the assertions here are: the frame satisfies verify's structural checks
# without anyone typing them, and an unfilled frame cannot pass verify.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPTS="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts"
SKELETON="$SCRIPTS/skeleton"
VERIFY="$SCRIPTS/verify"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/skeleton ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

run() {
    RC=0
    OUT=$(bash "$SKELETON" "$@" 2>&1) || RC=$?
}

new_repo main
mkdir -p .cue/dev/PROJ-1
cat > .cue/dev/PROJ-1/demand.md <<'EOF'
<!-- cue-dev · written 2026-08-11 · source: conversation -->

# PROJ-1 — a thing

## Requirement
build the thing

## Acceptance criteria
the thing is built
EOF

# --- design ------------------------------------------------------------------
run design PROJ-1
if [ "$RC" -eq 0 ] && [ -f .cue/dev/PROJ-1/design.md ]; then
    pass "it writes design.md"
else
    fail "it writes design.md" "exit: $RC" "$OUT"
fi

# Every heading verify requires, with nobody having typed one.
MISSING=""
for h in Structure "What we build" "Worked example" "Why this way" \
         "Rejected alternatives" "Divergence from demand" "Constraints at the time" \
         "Program design" "How we know it works" "Planned contract changes"; do
    grep -qx "## $h" .cue/dev/PROJ-1/design.md || MISSING="$MISSING $h;"
done
if [ -z "$MISSING" ]; then
    pass "the frame carries every heading verify requires"
else
    fail "the frame carries every heading verify requires" "missing:$MISSING"
fi

# The two literals that kept being translated are pre-filled, so they cannot be.
if grep -A2 '^## Planned contract changes' .cue/dev/PROJ-1/design.md | grep -qx none \
   && grep -A2 '^## Divergence from demand' .cue/dev/PROJ-1/design.md | grep -qx none; then
    pass "the 'none' answers are pre-filled rather than asked for"
else
    fail "the 'none' answers are pre-filled rather than asked for" \
         "$(cat .cue/dev/PROJ-1/design.md)"
fi

# --- an unfilled frame does not pass ------------------------------------------
RC=0
OUT=$(bash "$VERIFY" PROJ-1 2>&1) || RC=$?
if [ "$RC" -eq 1 ] && [[ "$OUT" == *"unfilled skeleton prompt"* ]]; then
    pass "verify refuses a frame nobody filled in"
else
    fail "verify refuses a frame nobody filled in" "exit: $RC" "$OUT"
fi

# --- a filled frame passes ----------------------------------------------------
# Prose in a non-English record language, structure untouched: the exact shape the
# skills ask for and the one that kept failing.
cat > .cue/dev/PROJ-1/design.md <<'EOF'
> 이 문서는 2026-08-11의 판단을 반영하며 업데이트되지 않습니다.
> 현재 시스템 구조는 프로젝트 설명서를 참고하세요.

## Structure

구조적 변화 없음.

## What we build

새 페이지 하나.

## Worked example

버튼을 누르면 page5.html 로 간다.

## Why this way

기존 패턴과 같기 때문.

## Rejected alternatives

- 별도 컴포넌트: 페이지 하나에 과한 구조여서 버렸다.

## Divergence from demand

none

## Constraints at the time

정적 HTML 뿐.

## Program design

- page5.html 하나, 의존성 없음.

## How we know it works

- 브라우저에서 링크를 눌러 확인한다.

## Planned contract changes

none
EOF
RC=0
OUT=$(bash "$VERIFY" PROJ-1 2>&1) || RC=$?
if [ "$RC" -eq 0 ]; then
    pass "a frame filled in with non-English prose passes verify"
else
    fail "a frame filled in with non-English prose passes verify" "exit: $RC" "$OUT"
fi

# --- it refuses to overwrite --------------------------------------------------
run design PROJ-1
if [ "$RC" -eq 1 ] && [[ "$OUT" == *"already exists"* ]]; then
    pass "it refuses to overwrite a design.md that is already there"
else
    fail "it refuses to overwrite a design.md that is already there" "exit: $RC" "$OUT"
fi
run design PROJ-1 --force
if [ "$RC" -eq 0 ] && grep -q '\[\[' .cue/dev/PROJ-1/design.md; then
    pass "--force overwrites it"
else
    fail "--force overwrites it" "exit: $RC" "$OUT"
fi
rm -f .cue/dev/PROJ-1/design.md

# --- plan ---------------------------------------------------------------------
run plan PROJ-1 3
if [ "$RC" -eq 0 ] && [ -f .cue/dev/PROJ-1/plan.md ]; then
    pass "it writes plan.md"
else
    fail "it writes plan.md" "exit: $RC" "$OUT"
fi

TASKS=$(grep -c '^### Task [0-9][0-9]*:' .cue/dev/PROJ-1/plan.md || true)
FILES=$(grep -c '^\*\*Files:\*\*' .cue/dev/PROJ-1/plan.md || true)
IFACE=$(grep -c '^\*\*Interfaces:\*\*' .cue/dev/PROJ-1/plan.md || true)
if [ "$TASKS" -eq 3 ] && [ "$FILES" -eq 3 ] && [ "$IFACE" -eq 3 ]; then
    pass "every task comes with its Files and Interfaces block already"
else
    fail "every task comes with its Files and Interfaces block already" \
         "tasks=$TASKS files=$FILES interfaces=$IFACE"
fi

if grep -q '^\*\*Goal:\*\*' .cue/dev/PROJ-1/plan.md \
   && grep -q '^\*\*Architecture:\*\*' .cue/dev/PROJ-1/plan.md \
   && grep -q '^## Global Constraints' .cue/dev/PROJ-1/plan.md; then
    pass "the header fields verify greps for are written, not asked for"
else
    fail "the header fields verify greps for are written, not asked for" \
         "$(head -20 .cue/dev/PROJ-1/plan.md)"
fi

# --- usage --------------------------------------------------------------------
run plan PROJ-1 --force
[ "$RC" -eq 2 ] && pass "plan needs a task count" || fail "plan needs a task count" "exit: $RC" "$OUT"

run plan PROJ-1 zero --force
[ "$RC" -eq 2 ] && pass "a non-numeric task count is refused" \
    || fail "a non-numeric task count is refused" "exit: $RC" "$OUT"

run outcome PROJ-1
[ "$RC" -eq 2 ] && pass "there is no skeleton for a stage that has no template" \
    || fail "there is no skeleton for a stage that has no template" "exit: $RC" "$OUT"

run design NO-SUCH-KEY
[ "$RC" -eq 1 ] && pass "an unknown KEY is refused" || fail "an unknown KEY is refused" "exit: $RC" "$OUT"

run design "a/b"
[ "$RC" -eq 2 ] && pass "exit 2 for a KEY containing a slash" \
    || fail "exit 2 for a KEY containing a slash" "exit: $RC" "$OUT"

finish
