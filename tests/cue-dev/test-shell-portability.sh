#!/usr/bin/env bash
# The shell features cue-dev's scripts rely on, asserted against the shell that is
# actually running them.
#
# This suite exists because a portability defect reaches the user as something
# else entirely. macOS ships bash 3.2, and a construct it mishandles produced
# `s: unbound variable` from a line where `s` had just been assigned — a message
# that describes the symptom and points nowhere near the cause. Two rounds of CI
# were spent guessing at it from the symptom.
#
# So each assertion here is a construct, exercised in isolation, named for what it
# is. A failure says which feature the shell does not have, and the version banner
# below says which shell that was.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"
# shellcheck source=plugins/cue-dev/skills/using-cue/scripts/common
. "$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/common"

echo "=== Test: shell portability ==="
echo "  shell: ${BASH_VERSION:-unknown}"

# --- nested parameter defaults ---------------------------------------------
#
# `${1:-${A:-$B}}`. On bash 3.2 the inner default runs past the outer closing
# brace and swallows what follows, including assignments on later lines. cue_rule
# was written this way and took seven macOS suites down with it.
nested_default() {
    local got second
    got=${1:-${OUTER_UNSET:-fallback}}
    second='assigned'
    printf '%s|%s' "$got" "$second"
}
unset OUTER_UNSET 2>/dev/null || true
out=$(nested_default)
if [ "$out" = "fallback|assigned" ]; then
    pass "a default nested in a default leaves the next assignment alone"
else
    fail "a default nested in a default leaves the next assignment alone" \
        "got: $out" "want: fallback|assigned"
fi

out=$(nested_default given)
if [ "$out" = "given|assigned" ]; then
    pass "a default nested in a default yields the argument when there is one"
else
    fail "a default nested in a default yields the argument when there is one" "got: $out"
fi

# --- the form cue_rule uses now ---------------------------------------------
plain_default() {
    local n s
    n=${1:-}
    [ -n "$n" ] || n=${CUE_HEAD_WIDTH_TEST:-7}
    s=''
    while [ "$n" -gt 0 ]; do s="$s-"; n=$((n - 1)); done
    printf '%s' "$s"
}
out=$(plain_default)
if [ "$out" = "-------" ]; then
    pass "a local accumulator builds a string of the defaulted length"
else
    fail "a local accumulator builds a string of the defaulted length" "got: $out"
fi

out=$(plain_default 3)
if [ "$out" = "---" ]; then
    pass "and of the given length"
else
    fail "and of the given length" "got: $out"
fi

# --- quoted inner expansion in a pattern ------------------------------------
#
# `${v#"${v%%[![:space:]]*}"}` is how every config value and record line is
# trimmed. The quotes matter: without them the stripped prefix is read as a
# pattern rather than as text.
trimmed="   padded value   "
trimmed=${trimmed#"${trimmed%%[![:space:]]*}"}
trimmed=${trimmed%"${trimmed##*[![:space:]]}"}
if [ "$trimmed" = "padded value" ]; then
    pass "a quoted inner expansion trims both ends"
else
    fail "a quoted inner expansion trims both ends" "got: [$trimmed]"
fi

# --- empty arrays under set -u ----------------------------------------------
#
# `${arr[@]+"${arr[@]}"}` is the guard that lets an empty array expand to nothing
# instead of erroring. Several scripts pass their arguments on this way.
empty_array_expansion() {
    local out='' item
    local arr=()
    for item in ${arr[@]+"${arr[@]}"}; do out="$out$item"; done
    arr=(a b)
    for item in ${arr[@]+"${arr[@]}"}; do out="$out$item"; done
    printf '%s' "$out"
}
out=$(empty_array_expansion)
if [ "$out" = "ab" ]; then
    pass "an empty array expands to nothing under set -u"
else
    fail "an empty array expands to nothing under set -u" "got: $out"
fi

# --- a variable followed by a multi-byte character ---------------------------
#
# `"$s━"` reads the variable `s━` on bash 3.2, because the leading byte of the
# character scans as part of the name. Braced, it is unambiguous on every shell.
# The box rules are built this way, one character at a time.
brace_before_multibyte() {
    local s=''
    local i=3
    while [ "$i" -gt 0 ]; do s="${s}━"; i=$((i - 1)); done
    printf '%s' "$s"
}
if [ "$(brace_before_multibyte)" = "━━━" ]; then
    pass "a braced variable accumulates a multi-byte character"
else
    fail "a braced variable accumulates a multi-byte character" "got: $(brace_before_multibyte)"
fi

# --- ranges collate, classes do not ------------------------------------------
#
# `[a-z]` is resolved through the locale's collation order, and macOS's default
# locale interleaves the cases, so `K` sorts inside `a-z` there. The validator
# for the record language was written that way and accepted `language=KO` on
# macOS while rejecting it everywhere else.
upper=KO
lower=ko

case "$upper" in
    [[:lower:]][[:lower:]]) fail "a lowercase class does not match uppercase" "matched $upper" ;;
    *) pass "a lowercase class does not match uppercase" ;;
esac

case "$lower" in
    [[:lower:]][[:lower:]]) pass "a lowercase class matches lowercase" ;;
    *) fail "a lowercase class matches lowercase" "did not match $lower" ;;
esac

# --- printf escapes ----------------------------------------------------------
#
# `\xNN` is not processed by bash 3.2's printf, which emits the escape as text.
# A probe written with it measured its own escape sequence and silently answered
# for every platform at once. Octal is POSIX, and a literal character in the
# source needs no escape processing at all.
if [ "$(printf '%s' '━' | LC_ALL=C wc -c | tr -d ' ')" = 3 ]; then
    pass "a literal multi-byte character survives printf as its own bytes"
else
    fail "a literal multi-byte character survives printf as its own bytes" \
        "got: $(printf '%s' '━' | LC_ALL=C wc -c | tr -d ' ') bytes"
fi

if [ "$(printf '\342\224\201' | LC_ALL=C wc -c | tr -d ' ')" = 3 ]; then
    pass "an octal escape expands to its byte"
else
    fail "an octal escape expands to its byte" \
        "got: $(printf '\342\224\201' | LC_ALL=C wc -c | tr -d ' ') bytes"
fi

# --- awk over multi-byte input -----------------------------------------------
#
# What is required of awk is that it not fall over. Character semantics are *not*
# required and are not available: macOS's awk counts bytes whatever the locale is
# set to, which is why task-graph does its own UTF-8 arithmetic over bytes rather
# than asking for a locale. Three rounds of CI went into asking.
#
# Under `LC_ALL=C` every platform agrees on byte semantics, and nothing aborts.
# The abort came from naming a locale that did not resolve.
awk_rc=0
awk_len=$(printf '한글자\n' | LC_ALL=C awk '{print length($0)}' 2>&1) || awk_rc=$?
if [ "$awk_rc" -eq 0 ] && [ "$awk_len" = "9" ]; then
    pass "awk reads multi-byte input as bytes under LC_ALL=C without aborting"
else
    fail "awk reads multi-byte input as bytes under LC_ALL=C without aborting" \
        "rc=$awk_rc" "got: $awk_len" "want: 9"
fi

# The arithmetic task-graph and cue_display_width both rest on: a UTF-8 character
# is one lead byte plus its continuations, so dropping the continuation range
# leaves one byte per character.
chars=$(printf '한글자' | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d ' ')
if [ "$chars" = "3" ]; then
    pass "dropping continuation bytes counts characters"
else
    fail "dropping continuation bytes counts characters" "got: $chars" "want: 3"
fi

# And the same rule read as a boundary test on a single byte, which is how the
# suites check that a cut landed cleanly.
lead=$(printf '한' | head -c 1 | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d ' ')
cont=$(printf '한' | tail -c 1 | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d ' ')
if [ "$lead" = "1" ] && [ "$cont" = "0" ]; then
    pass "a lead byte survives the strip and a continuation byte does not"
else
    fail "a lead byte survives the strip and a continuation byte does not" \
        "lead: $lead (want 1)" "continuation: $cont (want 0)"
fi

# --- the tools, not the shell -----------------------------------------------
#
# GNU and BSD differ here, and the BSD spelling is the one that works on both.
tmp=$(mktemp -d)
printf 'alpha\nbeta\n' > "$tmp/f"

if sed '/alpha/{n;s/^beta$/BETA/;}' "$tmp/f" | grep -q '^BETA$'; then
    pass "sed accepts a block whose last command is terminated"
else
    fail "sed accepts a block whose last command is terminated" "$(cat "$tmp/f")"
fi

if [ "$(printf 'a1\na22\n' | sed -n 's/^a\([0-9][0-9]*\)$/\1/p' | paste -sd, -)" = "1,22" ]; then
    pass "sed matches one-or-more written as [0-9][0-9]*"
else
    fail "sed matches one-or-more written as [0-9][0-9]*"
fi

if printf 'x\n' | grep -q '^[a-z][a-z]*$'; then
    pass "grep matches one-or-more the same way"
else
    fail "grep matches one-or-more the same way"
fi

rm -rf "$tmp"

finish
