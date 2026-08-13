#!/usr/bin/env bash
# scripts/notice: draws the completion notice block for the stage skills.
#
# The regression this pins: the skills used to carry the box as literal text, 47
# columns top and bottom. Substituting a real KEY for `<KEY>` widened only the
# opening line, so every key longer than five characters produced a box whose two
# rules disagreed. The script exists so the closing rule is derived, never typed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NOTICE="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/notice"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/notice ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT
new_repo main

# `━` is three bytes and ${#var} counts bytes when the locale is empty, which it
# is on Git Bash. Stripping UTF-8 continuation bytes leaves one byte per column —
# the same measurement cue_display_width makes.
width() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }

rules_match() {
    local label=$1 out=$2 first last
    first=$(printf '%s\n' "$out" | head -1)
    last=$(printf '%s\n' "$out" | tail -1)
    if [ "$(width "$first")" -eq "$(width "$last")" ]; then
        pass "$label"
    else
        fail "$label" "top is $(width "$first") wide, bottom is $(width "$last")" \
            "$first" "$last"
    fi
}

# --- a short title: the box stays at the standard width ---
out=$(bash "$NOTICE" "DESIGN done" <<'EOF'
  artifact  .cue/dev/PROJ-142/design.md

  next      /cue-dev:plan
EOF
)
rules_match "a short title closes at the width it opened" "$out"

if [ "$(width "$(printf '%s\n' "$out" | head -1)")" -eq 47 ]; then
    pass "a title that fits keeps the standard 47 columns"
else
    fail "a title that fits keeps the standard 47 columns" "got: $out"
fi

# --- the case that produced the ragged box in a real session ---
#
# A 33-character KEY used to sit in the title and pushed the opening line 28
# columns past a closing rule that never moved. The KEY is a body line now, so the
# frame no longer varies with it at all — the long value goes in the body and the
# two rules still agree.
LONG=2026-08-04-prev-button-navigation
out=$(bash "$NOTICE" "DESIGN done" <<EOF
  key       $LONG
  artifact  .cue/dev/$LONG/design.md
  commit    cue-dev(design): $LONG

  next      /cue-dev:plan
  rewind    /cue-dev:redo design
EOF
)
rules_match "a long KEY in the body leaves both rules alone" "$out"

if [ "$(width "$(printf '%s\n' "$out" | head -1)")" -eq 47 ]; then
    pass "a long KEY no longer widens the frame — it is not in the title"
else
    fail "a long KEY no longer widens the frame — it is not in the title" "got: $out"
fi

if [[ "$out" =~ key[[:space:]]+$LONG ]]; then
    pass "the KEY is reported on a labelled body line"
else
    fail "the KEY is reported on a labelled body line" "got: $out"
fi

# --- label and value land in the same columns as scripts/status ---
out=$(bash "$NOTICE" "START done" <<'EOF'
  artifact  .cue/dev/PROJ-142/demand.md

  next      /cue-dev:design
EOF
)
if [[ "$out" =~ next[[:space:]]+/cue-dev:design ]]; then
    pass "renders label and value on one line"
else
    fail "renders label and value on one line" "got: $out"
fi

if [ "$(printf '%s\n' "$out" | sed -n 2p)" = "" ]; then
    pass "keeps the blank line under the head"
else
    fail "keeps the blank line under the head" "got: $out"
fi

if [ "$(printf '%s\n' "$out" | sed -n 4p)" = "" ]; then
    pass "keeps the blank line that separates the groups"
else
    fail "keeps the blank line that separates the groups" "got: $out"
fi

# --- a continuation line prints with an empty label ---
# plan's notice lists plan.md and outcome.md under one `artifacts` label. The
# deeper indent is what marks the second line, so it must not be read as a label
# of its own.
out=$(bash "$NOTICE" "PLAN done" <<'EOF'
  artifacts .cue/dev/PROJ-142/plan.md
            .cue/dev/PROJ-142/outcome.md
EOF
)
if [ "$(printf '%s\n' "$out" | sed -n 4p)" = "            .cue/dev/PROJ-142/outcome.md" ]; then
    pass "an indented continuation line keeps the value column and drops the label"
else
    fail "an indented continuation line keeps the value column and drops the label" \
        "got: [$(printf '%s\n' "$out" | sed -n 4p)]"
fi

# --- a heredoc written flush left behaves the same ---
out=$(bash "$NOTICE" "PLAN done" <<'EOF'
artifacts .cue/dev/PROJ-142/plan.md
          .cue/dev/PROJ-142/outcome.md
EOF
)
if [ "$(printf '%s\n' "$out" | sed -n 4p)" = "            .cue/dev/PROJ-142/outcome.md" ]; then
    pass "the indent is measured against the first body line, not column zero"
else
    fail "the indent is measured against the first body line, not column zero" \
        "got: [$(printf '%s\n' "$out" | sed -n 4p)]"
fi

# --- a value carrying backslashes survives (Windows paths) ---
out=$(bash "$NOTICE" "FINISH done" <<'EOF'
  worktree  D:\repo\.worktrees\PROJ-142
EOF
)
if [[ "$out" == *'D:\repo\.worktrees\PROJ-142'* ]]; then
    pass "a Windows path passes through unchanged"
else
    fail "a Windows path passes through unchanged" "got: $out"
fi

# --- usage ---
if ! bash "$NOTICE" </dev/null >/dev/null 2>&1; then
    pass "refuses to run without a title"
else
    fail "refuses to run without a title"
fi

if ! bash "$NOTICE" "" </dev/null >/dev/null 2>&1; then
    pass "refuses an empty title"
else
    fail "refuses an empty title"
fi

# --- the title whitelist ---
#
# The frame's meaning is "a cue-dev stage produced this". A real session
# hand-rendered `━━━ MERGED · <KEY> ━━━` for a merge performed outside
# /cue-dev:finish — a stage that does not exist, visually identical to the real
# boxes. The script cannot stop hand-drawing, but it can stop being the thing that
# lends the forgery its shape, and it can make every legitimate box come from a
# title listed in the repository.
for bad in "MERGED · PROJ-142" "MERGED" "REVIEW done" "design done" "DESIGN DONE" "DESIGN done · PROJ-142"; do
    if ! out=$(bash "$NOTICE" "$bad" </dev/null 2>&1); then
        pass "refuses a title outside the list: $bad"
    else
        fail "refuses a title outside the list: $bad" "got: $out"
    fi
done

# Written out rather than read from the script on purpose. A test that derives its
# expectations from the thing under test cannot catch a wrong change to it — and a
# whitelist is exactly where that matters, because the frame's meaning is "a
# cue-dev stage produced this" and a title that arrives without review is the one
# way to forge it. Adding a stage means touching this line too.
EXPECTED_TITLES=("INIT done" "START done" "DESIGN done" "PLAN done" "IMPLEMENT done" \
                 "FINISH done" "REQUEST done" "MERGE done")

for good in "${EXPECTED_TITLES[@]}"; do
    if bash "$NOTICE" "$good" </dev/null >/dev/null 2>&1; then
        pass "accepts the stage title: $good"
    else
        fail "accepts the stage title: $good"
    fi
done

# The other half, which was missing: the loop above proves every expected title is
# accepted and says nothing about a title the script accepts that nobody expected.
# A whitelist that only grows unchecked is not a whitelist.
script_titles=$(sed -n '/^CUE_NOTICE_TITLE_LIST=(/,/^)/p' "$NOTICE" \
    | grep -oE "'[^']+'" | tr -d "'" | sort | tr '\n' ' ')
expected_sorted=$(printf '%s\n' "${EXPECTED_TITLES[@]}" | sort | tr '\n' ' ')
if [ "$script_titles" = "$expected_sorted" ]; then
    pass "the script's list holds these titles and no others"
else
    fail "the script's list holds these titles and no others" \
        "script:   $script_titles
expected: $expected_sorted"
fi

# And docs/output-format.md documents the whitelist, so it is a third copy. It
# went stale the release REQUEST done and MERGE done were added: the page listing
# the closed set named seven of the nine. Bound here rather than trusted.
#
# Read from the paragraph that makes the claim, not from the whole page. Scanning
# the file for every `X done` also picks the titles out of the prose *about* the
# list — including the paragraph explaining that it went stale — so deleting two
# titles from the closed-set sentence left the check green. It did, on the first
# attempt here.
DOC="$REPO_ROOT/docs/output-format.md"
doc_titles=$(awk '/closed set/ { on = 1 } on; on && /^$/ { exit }' "$DOC" \
    | grep -oE '`[A-Z]+ done`' | tr -d '`' | sort -u | tr '\n' ' ')
if [ "$doc_titles" = "$expected_sorted" ]; then
    pass "docs/output-format.md lists the same titles"
else
    fail "docs/output-format.md lists the same titles" \
        "doc:      $doc_titles
expected: $expected_sorted"
fi

# A box drawn inside a skill document is a box a model copies.
#
# implement's worked example carried `━━━ IMPLEMENT done · PROJ-142 ━━━` for a long
# time — a title scripts/notice refuses outright, since the KEY is a body line and
# the title is the closed set that fixes the frame's width. The example is where a
# model looks to see what the output should be, so an illegal box there teaches the
# forgery the whitelist exists to stop.
drawn=""
while IFS= read -r line; do
    [ -n "$line" ] || continue
    # grep -rn emits path:lineno:content — three fields, so two strips. Taking
    # only one left the line number glued to the title, so every box failed to
    # match the whitelist and the check failed on a correct file.
    f=${line%%:*}
    rest=${line#*:}
    f="$f:${rest%%:*}"
    # `s/━//g`, never `━+`. The rule character is three bytes (E2 94 81) and Git
    # Bash runs with an empty locale, so a quantifier binds to the last byte only:
    # `^━+` strips one ━ and then any repeats of 0x81, leaving the rest of the rule
    # glued to the title. Same byte-versus-character trap cue_display_width exists
    # for. Deleting the literal has no quantifier to misbind.
    title=$(printf '%s' "${rest#*:}" | sed 's/━//g' \
        | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -n "$title" ] || continue          # the closing rule carries no title
    listed=0
    for t in "${EXPECTED_TITLES[@]}"; do
        [ "$title" = "$t" ] && { listed=1; break; }
    done
    [ "$listed" -eq 1 ] || drawn="$drawn\n    $f: $title"
done <<< "$(grep -rn '^━━━' "$REPO_ROOT"/plugins/cue-dev/skills/*/*.md || true)"
if [ -z "$drawn" ]; then
    pass "no skill document draws a box notice would refuse"
else
    fail "no skill document draws a box notice would refuse" "$(printf '%b' "$drawn")"
fi

# --- @cleanup is observed, not copied ----------------------------------------
#
# finish's Step 8 said "copy the scratch and worktree lines finish-cleanup
# printed, do not write them from what you meant to happen" — in bold, with the
# session that got it wrong quoted underneath. The next session wrote `worktree
# .worktrees/<KEY> (removed)` over a directory finish-cleanup had just refused to
# remove, and then `worktree removed` again in the MERGE box. The correct line and
# the invented one are the same shape, so there is nothing left to copy: the token
# names the KEY and the answer is read off the disk as the box is drawn.
new_repo main
NMAIN=$(pwd -P)
mkdir -p ".cue/dev/HAS-WT"
{ printf '<!-- cue-dev · written 2026-08-11 · source: conversation -->
'
  printf '<!-- worktree: %s/.worktrees/HAS-WT -->
' "$NMAIN"
  printf '
# HAS-WT
'; } > ".cue/dev/HAS-WT/demand.md"
git add -A && git "${GIT_ID[@]}" commit -qm "record HAS-WT"
git "${GIT_ID[@]}" worktree add -q "$NMAIN/.worktrees/HAS-WT" -b cue-dev/HAS-WT >/dev/null 2>&1

out=$(bash "$NOTICE" "FINISH done" <<EOF
  key       HAS-WT
  @cleanup  HAS-WT
EOF
)
# The worktree is still there, so the only honest line says so — and the caller
# wrote nothing about it either way.
if [[ "$out" == *"worktree"* ]] && [[ "$out" != *"@cleanup"* ]]; then
    pass "@cleanup is replaced by the workspace lines"
else
    fail "@cleanup is replaced by the workspace lines" "got: $out"
fi
if [[ "$out" == *"still present"* ]]; then
    pass "it reports the disk, not the caller's intent"
else
    fail "it reports the disk, not the caller's intent" "got: $out"
fi
if [[ "$out" == *"━"* ]]; then
    pass "a non-zero finish-cleanup does not take the box down with it"
else
    fail "a non-zero finish-cleanup does not take the box down with it" "got: $out"
fi

git "${GIT_ID[@]}" worktree remove --force "$NMAIN/.worktrees/HAS-WT"
out=$(bash "$NOTICE" "FINISH done" <<EOF
  key       HAS-WT
  @cleanup  HAS-WT
EOF
)
if [[ "$out" == *"already gone"* ]]; then
    pass "once it is gone the same token says so"
else
    fail "once it is gone the same token says so" "got: $out"
fi

cd "$REPO_ROOT"

# The refusal has to say what to do instead, or the next move is to draw the box
# by hand — which is the failure itself.
out=$(bash "$NOTICE" "MERGED" </dev/null 2>&1 || true)
if [[ "$out" == *"ordinary prose"* ]] && [[ "$out" == *"FINISH done"* ]]; then
    pass "the refusal names the allowed titles and the alternative"
else
    fail "the refusal names the allowed titles and the alternative" "got: $out"
fi

finish
