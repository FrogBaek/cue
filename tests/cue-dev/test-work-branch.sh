#!/usr/bin/env bash
# scripts/work-branch: the branch one work item was cut onto.
#
# The name used to be a contract. Nothing stored which branch belonged to which
# item, so status, redo, backups and gate recovered the KEY by matching the branch
# name against the .cue/dev/<KEY>/ directories — which silently required the KEY to
# be in the name, and told a team whose branches are called
# `feat/add-hello-world-test` that its work would not be findable.
#
# Three contracts are under test here.
#
# (1) A name with nothing of cue-dev in it round-trips, and the KEY is found from
#     it. That is the whole point: if this fails, the coupling is back.
# (2) The record wins over the name. An item that recorded a branch is found by
#     that line, never by a coincidental substring.
# (3) An item written before the line existed is still found the old way. That is
#     a legacy path for records already on disk, not a default inventing an answer
#     — which is why it applies only when no branch was recorded at all.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_BRANCH="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/work-branch"
STATUS="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/status"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

TEST_ROOT=$(mktemp -d)
trap cleanup EXIT

echo "=== Test: scripts/work-branch ==="

# Writes a demand.md carrying the given header lines, in the shape start writes.
write_demand() {
    local key=$1; shift
    mkdir -p ".cue/dev/$key"
    {
        echo "<!-- cue-dev · written 2026-08-06 · source: conversation -->"
        printf '%s\n' "$@"
        echo "<!-- This document is a requirement snapshot. -->"
        echo
        echo "# $key — a title"
        echo
        echo "## Requirement"
        echo "do the thing"
    } > ".cue/dev/$key/demand.md"
}

# --- the round trip, on a name that carries nothing of cue-dev ----------------
new_repo main
git checkout -q -b "feat/add-hello-world-test"

line=$("$WORK_BRANCH" --line)
if [ "$line" = "<!-- branch: feat/add-hello-world-test -->" ]; then
    pass "--line takes the name from git and needs no argument"
else
    fail "--line takes the name from git and needs no argument" "got: $line"
fi

write_demand HELLO "$line"
if [ "$("$WORK_BRANCH" HELLO)" = "feat/add-hello-world-test" ]; then
    pass "what --line wrote is what a later read gets back"
else
    fail "what --line wrote is what a later read gets back" "got: $("$WORK_BRANCH" HELLO 2>&1)"
fi

# The contract that matters to every other script: the KEY is found from a branch
# name that contains no part of it.
if [ "$(cd . && "$STATUS" 2>&1 | grep -c 'HELLO')" -gt 0 ]; then
    pass "the KEY is found from a branch name carrying no trace of it"
else
    fail "the KEY is found from a branch name carrying no trace of it" "$("$STATUS" 2>&1)"
fi

# --- the header only, never the body -----------------------------------------
#
# demand.md's body is a quotation of the requirement. A pasted ticket that happens
# to contain a branch line must not decide which item this branch belongs to.
new_repo main
git checkout -q -b real-branch
mkdir -p .cue/dev/BODY
{
    echo "<!-- cue-dev · written 2026-08-06 · source: paste -->"
    echo "<!-- branch: real-branch -->"
    echo
    echo "# BODY — a title"
    echo
    echo "## Requirement"
    echo "The ticket said: <!-- branch: something-else -->"
} > .cue/dev/BODY/demand.md
if [ "$("$WORK_BRANCH" BODY)" = "real-branch" ]; then
    pass "a branch line inside the quoted ticket is not the record"
else
    fail "a branch line inside the quoted ticket is not the record" "got: $("$WORK_BRANCH" BODY 2>&1)"
fi

# --- the record beats a coincidental substring -------------------------------
#
# Two items, one of which has the other's KEY inside its branch name. Under the
# old rule the substring decided; under this one the recorded line does.
new_repo main
git checkout -q -b "release/PROJ-1-and-more"
write_demand PROJ-1 "<!-- branch: some-other-branch -->"
write_demand PROJ-2 "<!-- branch: release/PROJ-1-and-more -->"
git add -A >/dev/null 2>&1
if [ "$("$STATUS" 2>&1 | grep -c 'PROJ-2')" -gt 0 ]; then
    pass "the recorded branch decides, not a name that contains another KEY"
else
    fail "the recorded branch decides, not a name that contains another KEY" "$("$STATUS" 2>&1)"
fi

# --- items written before the line existed ------------------------------------
new_repo main
git checkout -q -b "cue-dev/OLD-9"
write_demand OLD-9 "<!-- base: main @ abcdef1 -->"
if out=$("$STATUS" 2>&1) && [[ "$out" == *"OLD-9"* ]]; then
    pass "an item with no branch line is still found by the old name match"
else
    fail "an item with no branch line is still found by the old name match" "$out"
fi

if out=$("$WORK_BRANCH" OLD-9 2>&1); then
    fail "reading an unrecorded branch is an error, not an empty answer" "got: $out"
elif [[ "$out" == *"--relink"* ]]; then
    pass "the refusal points at the repair"
else
    fail "the refusal points at the repair" "$out"
fi

# --- --relink, the repair after a rename --------------------------------------
#
# The only sanctioned way to repoint the record. Editing the header by hand is how
# a line other scripts parse acquires a second author.
new_repo main
git checkout -q -b old-name
write_demand MOVE "<!-- base: main @ abcdef1 -->" "<!-- branch: old-name -->"
git branch -m new-name
"$WORK_BRANCH" MOVE --relink >/dev/null
if [ "$("$WORK_BRANCH" MOVE)" = "new-name" ]; then
    pass "--relink repoints the record at the branch checked out now"
else
    fail "--relink repoints the record at the branch checked out now" \
        "got: $("$WORK_BRANCH" MOVE 2>&1)"
fi

if [ "$(grep -c 'branch:' .cue/dev/MOVE/demand.md)" -eq 1 ]; then
    pass "--relink replaces the line rather than adding a second one"
else
    fail "--relink replaces the line rather than adding a second one" \
        "$(cat .cue/dev/MOVE/demand.md)"
fi

if grep -q '^<!-- base: main @ abcdef1 -->$' .cue/dev/MOVE/demand.md \
   && grep -q '^## Requirement$' .cue/dev/MOVE/demand.md; then
    pass "--relink leaves the rest of the record alone"
else
    fail "--relink leaves the rest of the record alone" "$(cat .cue/dev/MOVE/demand.md)"
fi

# An item that predates the line gets one rather than nothing to replace.
write_demand LEGACY "<!-- base: main @ abcdef1 -->"
"$WORK_BRANCH" LEGACY --relink >/dev/null
if [ "$("$WORK_BRANCH" LEGACY)" = "new-name" ]; then
    pass "--relink adds the line to an item that never had one"
else
    fail "--relink adds the line to an item that never had one" \
        "got: $("$WORK_BRANCH" LEGACY 2>&1)"
fi

# --- a name that is not a branch is refused, never recorded -------------------
#
# Recording a branch that does not exist is the silent kind of failure this line
# was introduced to remove: the file is written, the commit succeeds, and the item
# points at nothing.
if out=$("$WORK_BRANCH" --line no-such-branch 2>&1); then
    fail "--line refuses a branch that does not exist" "got: $out"
elif [[ "$out" == *"no such branch"* ]]; then
    pass "--line refuses a branch that does not exist"
else
    fail "--line refuses a branch that does not exist" "$out"
fi

# The refusal must not also print a half-written line. An exit inside a command
# substitution only kills the subshell, and that produced `<!-- branch:  -->`.
out=$("$WORK_BRANCH" --line no-such-branch 2>/dev/null || true)
if [ -z "$out" ]; then
    pass "a refused --line prints no header line at all"
else
    fail "a refused --line prints no header line at all" "got: $out"
fi

# --- unknown work, unusable KEY ----------------------------------------------
rc=0; "$WORK_BRANCH" NOPE >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then
    pass "exit 1 for a KEY with no work directory"
else
    fail "exit 1 for a KEY with no work directory" "exit: $rc"
fi

rc=0; "$WORK_BRANCH" "a/b" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
    pass "exit 2 for a KEY that is unsafe on the filesystem"
else
    fail "exit 2 for a KEY that is unsafe on the filesystem" "exit: $rc"
fi

finish
