#!/usr/bin/env bash
# scripts/work-check: how strongly one item's implementation is to be checked.
#
# This value used to be `min_check` in .cue/dev/config — a repository-wide floor.
# It moved for two reasons, and both are what the assertions below pin.
#
# One value could not serve two items. A colour change wants `self-review`; the
# migration in the worktree beside it wants `independent-review`. And because each
# worktree carries its own checked-out copy of the config, changing it for one item
# either missed the session next door or, once that branch merged, changed it for
# everyone retroactively.
#
# And a floor answered the wrong question. It said what may not happen and never
# what should, so /cue-dev:implement had nothing to read and decided per run, from
# the shape of the plan, whether to dispatch subagents at all. `--plan` is the
# repair: the level names the method, so implement executes instead of judging.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/work-check"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/work-check ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=PROJ-7

# Writes demand.md with an optional check header.
record() {  # record [<level>]
    mkdir -p ".cue/dev/$KEY"
    {
        printf '<!-- cue-dev · written 2026-08-07 · source: conversation -->\n'
        [ -n "${1:-}" ] && printf '<!-- check: %s -->\n' "$1"
        printf '\n# %s — fixture\n' "$KEY"
    } > ".cue/dev/$KEY/demand.md"
}

new_repo main

# --- the emitter -------------------------------------------------------------
#
# start writes demand.md but not this line, for the same reason it does not write
# the base line: a string other scripts parse must have exactly one author, or it
# drifts in the one repository that formatted it differently and nothing says so.
out=$(bash "$CHECK" --line independent-review)
if [ "$out" = "<!-- check: independent-review -->" ]; then
    pass "--line emits the header line"
else
    fail "--line emits the header line" "$out"
fi

for bad in none floor "" SELF-REVIEW self_review; do
    if bash "$CHECK" --line "$bad" >/dev/null 2>&1; then
        fail "--line rejects '$bad'" "it was accepted"
    else
        pass "--line rejects '$bad'"
    fi
done

# `none` is the one refusal worth a message rather than a shrug: it is a real
# value, just not one anyone may ask for in advance. Asked for, it is a standing
# waiver; recorded in outcome.md afterwards it stops finish once, in front of a
# human.
out=$(bash "$CHECK" --line none 2>&1 || true)
if [[ "$out" == *"checked-by"* ]]; then
    pass "the refusal of 'none' says where it does belong"
else
    fail "the refusal of 'none' says where it does belong" "$out"
fi

# --- reading it back ---------------------------------------------------------
record self-review
if [ "$(bash "$CHECK" "$KEY")" = "self-review" ]; then
    pass "the item's own header is what it reads"
else
    fail "the item's own header is what it reads" "$(bash "$CHECK" "$KEY")"
fi
if [[ "$(bash "$CHECK" "$KEY" --source)" == *"demand.md"* ]]; then
    pass "it names the header as the source"
else
    fail "it names the header as the source" "$(bash "$CHECK" "$KEY" --source)"
fi

# Two items, two answers, at the same time — the case one config value could not
# express at all.
mkdir -p ".cue/dev/OTHER"
printf '<!-- check: independent-review -->\n\n# OTHER\n' > .cue/dev/OTHER/demand.md
if [ "$(bash "$CHECK" "$KEY")" = "self-review" ] \
   && [ "$(bash "$CHECK" OTHER)" = "independent-review" ]; then
    pass "two items in one repository hold different levels at once"
else
    fail "two items in one repository hold different levels at once" \
         "$(bash "$CHECK" "$KEY") / $(bash "$CHECK" OTHER)"
fi

# --- the legacy fallback -----------------------------------------------------
#
# A repository still carrying `min_check` answered this question once. Honouring
# it is what keeps a plugin upgrade from re-judging work already in flight, so it
# applies only where the item itself is silent.
record
mkdir -p .cue/dev && printf 'min_check=self-review\n' > .cue/dev/config
if [ "$(bash "$CHECK" "$KEY")" = "self-review" ]; then
    pass "a retired min_check line answers for an item that recorded nothing"
else
    fail "a retired min_check line answers for an item that recorded nothing" \
         "$(bash "$CHECK" "$KEY")"
fi
if [[ "$(bash "$CHECK" "$KEY" --source)" == *"legacy"* ]]; then
    pass "and it says the answer came from there"
else
    fail "and it says the answer came from there" "$(bash "$CHECK" "$KEY" --source)"
fi

record independent-review
if [ "$(bash "$CHECK" "$KEY")" = "independent-review" ]; then
    pass "the item's header beats the legacy setting"
else
    fail "the item's header beats the legacy setting" "$(bash "$CHECK" "$KEY")"
fi

# With neither, the safe answer — never the weaker one.
record
rm -f .cue/dev/config
if [ "$(bash "$CHECK" "$KEY")" = "independent-review" ]; then
    pass "with nothing recorded anywhere it defaults to the stronger level"
else
    fail "with nothing recorded anywhere it defaults to the stronger level" \
         "$(bash "$CHECK" "$KEY")"
fi

# --- --plan names a method, not a threshold ----------------------------------
#
# The whole reason this is a script. implement used to read a floor and then work
# out for itself what to do about it, which is the step that made two runs of one
# item diverge.
record independent-review
out=$(bash "$CHECK" "$KEY" --plan)
if [[ "$out" == *"method"*"subagent"* ]]; then
    pass "--plan says to dispatch subagents at independent-review"
else
    fail "--plan says to dispatch subagents at independent-review" "$out"
fi
if [[ "$out" == *"checked-by: independent-review"* ]]; then
    pass "--plan names the value the record will carry"
else
    fail "--plan names the value the record will carry" "$out"
fi

record self-review
out=$(bash "$CHECK" "$KEY" --plan)
if [[ "$out" == *"in this session"* ]]; then
    pass "--plan says to implement in session at self-review"
else
    fail "--plan says to implement in session at self-review" "$out"
fi
# self-review is not a lighter process, and the output has to say so — otherwise
# the level reads as permission to skip the parts that are not the review.
if [[ "$out" == *"invariants do not move"* ]]; then
    pass "--plan says the invariants are unchanged at self-review"
else
    fail "--plan says the invariants are unchanged at self-review" "$out"
fi

# --- the procedure line ------------------------------------------------------
#
# The whole reason --plan exists in the form it does. implement's SKILL.md carries
# no method: it names two files and this line says which is yours. A path that
# does not resolve turns that into the dead end the split was meant to remove, so
# the file is checked to exist, not just to be mentioned.
for pair in "independent-review independent-review.md" "self-review self-review.md"; do
    set -- $pair
    mkdir -p ".cue/dev/$KEY"
    printf '<!-- check: %s -->\n\n# %s\n' "$1" "$KEY" > ".cue/dev/$KEY/demand.md"
    out=$(bash "$CHECK" "$KEY" --plan)
    path=$(printf '%s\n' "$out" | sed -n 's/^  procedure  *//p')
    if [ -n "$path" ] && [ -f "$path" ] && [[ "$path" == *"/implement/$2" ]]; then
        pass "--plan names an existing procedure file for $1"
    else
        fail "--plan names an existing procedure file for $1" "got: ${path:-<no procedure line>}"
    fi
    if [[ "$out" == *"SKILL.md does not contain this method"* ]]; then
        pass "--plan says SKILL.md is not the method, for $1"
    else
        fail "--plan says SKILL.md is not the method, for $1" "$out"
    fi
done

# --- errors ------------------------------------------------------------------
if bash "$CHECK" NO-SUCH-KEY >/dev/null 2>&1; then
    fail "an unknown KEY fails" "it answered"
else
    pass "an unknown KEY fails"
fi

if bash "$CHECK" >/dev/null 2>&1; then
    fail "no argument is a usage error" "it answered"
else
    pass "no argument is a usage error"
fi

# A header carrying a value nothing can act on is a broken record, not a silent
# fallback: --plan is where implement would branch on it, so that is where it
# stops.
mkdir -p ".cue/dev/$KEY"
printf '<!-- check: thoroughly -->\n\n# %s\n' "$KEY" > ".cue/dev/$KEY/demand.md"
out=$(bash "$CHECK" "$KEY" --plan 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && [[ "$out" == *"work-check --line"* ]]; then
    pass "an unreadable level stops --plan and says how to fix the header"
else
    fail "an unreadable level stops --plan and says how to fix the header" "exit $rc: $out"
fi

finish
