#!/usr/bin/env bash
# scripts/config: reads the user's conventions and validates them deterministically.
#
# This test guards two contracts.
#
# (1) With no settings it runs on the defaults exactly as before. Adding a settings
#     feature must not change existing repositories.
# (2) Bad values are caught deterministically, *all* of them. A wrong marker_prefix
#     fails silently — the commit succeeds and only that stage becomes invisible
#     forever — so "it surfaces later" is not acceptable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/config"
MARKER="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/marker"
STATUS="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/status"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

TEST_ROOT=$(mktemp -d)
trap cleanup EXIT

echo "=== Test: scripts/config ==="

write_config() {
    mkdir -p .cue/dev
    printf '%s\n' "$@" > .cue/dev/config
}

# --- no settings = the defaults ---
new_repo main
# The marker script runs scripts/verify before it will print anything, so every
# check below that calls it needs a record that passes. PROJ-1 gets one once,
# here, and the settings tests then vary only what they are about — the prefix.
write_demand PROJ-1

for pair in "marker_prefix cue-dev" "backup_prefix cue-dev/backup/"; do
    set -- $pair
    got=$("$CONFIG" --get "$1")
    if [ "$got" = "$2" ]; then
        pass "with no settings, $1 is $2"
    else
        fail "with no settings, $1 is $2" "got: $got"
    fi
done

if [ "$("$MARKER" demand PROJ-1)" = "cue-dev(demand): PROJ-1" ]; then
    pass "with no settings the marker keeps its original form"
else
    fail "with no settings the marker keeps its original form" "got: $("$MARKER" demand PROJ-1)"
fi

if "$CONFIG" --check >/dev/null 2>&1; then
    pass "validation passes even with no settings file"
else
    fail "validation passes even with no settings file"
fi

# --- every bad value is caught ---
new_repo main

# each entry: <config line>|<key the error message must contain>
bad_cases=(
    "marker_prefix=cue(x)|marker_prefix"
    "marker_prefix=spec:v1|marker_prefix"
    "marker_prefix=my prefix|marker_prefix"
    "backup_prefix=..bad/|backup_prefix"
    "remote=no-such-remote|remote"
)
for case_ in "${bad_cases[@]}"; do
    line=${case_%%|*}
    want=${case_##*|}
    write_config "$line"
    if out=$("$CONFIG" --check 2>&1); then
        fail "catches a bad setting: $line" "it passed validation"
    elif [[ "$out" == *"$want"* ]]; then
        pass "catches a bad setting: $line"
    else
        fail "catches a bad setting: $line" "the message lacks '$want'" "$out"
    fi
done

# An empty value is not an error but "use the default". A marker with no prefix
# would be `(demand): KEY`, which is not even valid syntax, so taking an empty value
# literally is not an option. Falling back to the default is the safe reading.
write_config "marker_prefix="
if [ "$("$CONFIG" --get marker_prefix)" = "cue-dev" ] && "$CONFIG" --check >/dev/null 2>&1; then
    pass "an empty value falls back to the default rather than erroring"
else
    fail "an empty value falls back to the default rather than erroring" "got: $("$CONFIG" --get marker_prefix)"
fi

# --- valid settings pass and actually take effect ---
new_repo main
write_demand PROJ-1
write_config "marker_prefix=spec" "backup_prefix=spec/backup/"

if "$CONFIG" --check >/dev/null 2>&1; then
    pass "valid settings pass validation"
else
    fail "valid settings pass validation" "$("$CONFIG" --check 2>&1)"
fi

if [ "$("$MARKER" demand PROJ-1)" = "spec(demand): PROJ-1" ]; then
    pass "marker_prefix takes effect in the marker"
else
    fail "marker_prefix takes effect in the marker" "got: $("$MARKER" demand PROJ-1)"
fi

if [ "$("$CONFIG" --get backup_prefix)" = "spec/backup/" ]; then
    pass "backup_prefix is its own setting, not derived"
else
    fail "backup_prefix is its own setting, not derived" "got: $("$CONFIG" --get backup_prefix)"
fi

# --- does status actually read a commit stamped with the changed marker? ---
# A setting that only affects printed strings and not the determination is useless.
git add -A
git "${GIT_ID[@]}" commit -qm "$("$MARKER" demand PROJ-1)"

out=$("$STATUS" PROJ-1 2>&1)
if [[ "$out" == *"▶ design"* ]]; then
    pass "status uses a commit stamped with the changed marker to determine the stage"
else
    fail "status uses a commit stamped with the changed marker to determine the stage" "$out"
fi

# Under the default prefix this commit must not be visible — that is what proves
# the danger of a prefix change hiding history is real, and what justifies init
# refusing the change.
write_config "marker_prefix=cue-dev"
# Do not pipe into grep — grep -q closing the pipe on the first match kills status
# with SIGPIPE (141), and pipefail then reports a failure despite the match.
out=$("$STATUS" PROJ-1 2>&1)
if [[ "$out" == *"▶ demand"* ]]; then
    pass "changing the prefix hides the earlier markers (the basis for refusing)"
else
    fail "changing the prefix hides the earlier markers (the basis for refusing)" "$out"
fi

# --- does it tolerate comments and whitespace? ---
new_repo main
write_config "# this repository's commit convention" "  marker_prefix =  spec  " "" "backup_prefix=spec/backup/"
if [ "$("$CONFIG" --get marker_prefix)" = "spec" ]; then
    pass "reads the value despite comments and whitespace"
else
    fail "reads the value despite comments and whitespace" "got: '$("$CONFIG" --get marker_prefix)'"
fi

# --- unknown keys ---
if "$CONFIG" --get nonsense >/dev/null 2>&1; then
    fail "rejects an unknown key"
else
    pass "rejects an unknown key"
fi

# --- --set: a decision has to be changeable afterwards ---
# A setting fixed forever once chosen contradicts why redo exists. But the risk
# differs per key, so the handling does too — the criterion is whether it changes
# how the history is read.
new_repo main

# Keys no history depends on are applied straight away, without consent.
git remote add origin https://example.invalid/r.git
if "$CONFIG" --set remote origin >/dev/null 2>&1 \
   && [ "$("$CONFIG" --get remote)" = "origin" ]; then
    pass "remote is applied without consent"
else
    fail "remote is applied without consent"
fi

# A value that fails validation is never written.
before=$("$CONFIG" --get remote)
if "$CONFIG" --set remote no-such-remote >/dev/null 2>&1; then
    fail "a value failing validation is not written" "the write was allowed"
elif [ "$("$CONFIG" --get remote)" = "$before" ]; then
    pass "a value failing validation is not written"
else
    fail "a value failing validation is not written" "the value changed: $("$CONFIG" --get remote)"
fi

# --- the start point is not a setting any more -------------------------------
#
# It differs per work item - a git-flow hotfix comes off main while the feature
# before it came off develop - so one repository-wide value could only express the
# second item by overwriting the first item's answer. It moved into
# .cue/dev/<KEY>/demand.md; see tests/cue-dev/test-work-base.sh.
#
# Both the write and the read are refused rather than ignored. A silent success on
# either is a start point that never takes effect, which is exactly the class of
# failure that stays invisible until the merge.
new_repo main
if out=$("$CONFIG" --set base_branch main 2>&1); then
    fail "--set base_branch is refused" "the write was allowed"
elif [[ "$out" == *"work item"* ]]; then
    pass "--set base_branch is refused, and says where the start point lives"
else
    fail "--set base_branch is refused" "the message does not name the work item: $out"
fi

for key in base_branch base_ref; do
    if out=$("$CONFIG" --get "$key" 2>&1); then
        fail "--get $key is refused" "it answered: $out"
    elif [[ "$out" == *"work-base"* ]]; then
        pass "--get $key points at scripts/work-base"
    else
        fail "--get $key points at scripts/work-base" "$out"
    fi
done

# A repository that still carries the line hears about it - as an unrecognized
# key, which is what it now is. Tolerating it would leave people editing a value
# that decides nothing.
write_config "base_branch=main"
# Captured before matching: `grep -q` exits on the first hit, and with pipefail a
# writer killed by the closed pipe fails the whole pipeline.
out=$("$CONFIG" --check 2>&1)
if [[ "$out" == *"unrecognized"* && "$out" == *"base_branch"* ]]; then
    pass "a leftover base_branch is reported as unrecognized"
else
    fail "a leftover base_branch is reported as unrecognized" "$out"
fi

# It is not printed among the settings either - the listing is what people read to
# find out what is in effect.
out=$("$CONFIG" 2>&1)
if [[ "$out" == *$'\n  base_branch'* ]]; then
    fail "a leftover base_branch is not listed as a setting" "$out"
else
    pass "a leftover base_branch is not listed as a setting"
fi

# --- branch_prefix: the same refusal, one step later in the same argument ------
#
# The work branch is named per item and recorded in that item's demand.md, so a
# repository-wide prefix has nothing left to decide. It is refused rather than
# ignored for the reason base_branch is: a silent success leaves someone believing
# they set the name of every future branch.
new_repo main
if out=$("$CONFIG" --set branch_prefix "feature/" 2>&1); then
    fail "--set branch_prefix is refused" "the write was allowed"
elif [[ "$out" == *"per item"* || "$out" == *"work item"* ]]; then
    pass "--set branch_prefix is refused, and says the name is per item"
else
    fail "--set branch_prefix is refused" "the message does not say where the name lives: $out"
fi

if out=$("$CONFIG" --get branch_prefix 2>&1); then
    fail "--get branch_prefix is refused" "it answered: $out"
elif [[ "$out" == *"work-branch"* ]]; then
    pass "--get branch_prefix points at scripts/work-branch"
else
    fail "--get branch_prefix points at scripts/work-branch" "$out"
fi

# The one place a prefix still lives is cue-dev's own backup namespace, and the
# refusal has to say so - otherwise the reader concludes prefixes are gone
# entirely and goes looking for their backups by hand.
if out=$("$CONFIG" --get branch_prefix 2>&1); then :; fi
if [[ "$out" == *"backup_prefix"* ]]; then
    pass "the refusal names backup_prefix as the surviving one"
else
    fail "the refusal names backup_prefix as the surviving one" "$out"
fi

write_config "branch_prefix=feature/"
out=$("$CONFIG" --check 2>&1)
if [[ "$out" == *"unrecognized"* && "$out" == *"branch_prefix"* ]]; then
    pass "a leftover branch_prefix is reported as unrecognized"
else
    fail "a leftover branch_prefix is reported as unrecognized" "$out"
fi

# A leftover line must not quietly become the backup namespace either. The two
# were derived from one another until the parent was removed, and inheriting it
# back would put this repository's backups somewhere nobody chose.
if [ "$("$CONFIG" --get backup_prefix)" = "cue-dev/backup/" ]; then
    pass "a leftover branch_prefix does not move the backup namespace"
else
    fail "a leftover branch_prefix does not move the backup namespace" \
        "got: $("$CONFIG" --get backup_prefix)"
fi

new_repo main

# Change marker_prefix with markers already present.
write_demand PROJ-9
git add -A
git "${GIT_ID[@]}" commit -qm "$("$MARKER" demand PROJ-9)"

# Without a yes, nothing changes.
if printf 'no\n' | "$CONFIG" --set marker_prefix spec >/dev/null 2>&1; then
    fail "changing marker_prefix takes consent" "it was applied without consent"
elif [ "$("$CONFIG" --get marker_prefix)" = "cue-dev" ]; then
    pass "changing marker_prefix takes consent"
else
    fail "changing marker_prefix takes consent" "got: $("$CONFIG" --get marker_prefix)"
fi

printf 'yes\n' | "$CONFIG" --set marker_prefix spec >/dev/null 2>&1

if [ "$("$MARKER" demand PROJ-9)" = "spec(demand): PROJ-9" ]; then
    pass "after the change, new markers use the new prefix"
else
    fail "after the change, new markers use the new prefix" "got: $("$MARKER" demand PROJ-9)"
fi

# This is why the feature exists — changing the prefix does not lose old work.
out=$("$STATUS" PROJ-9 2>&1)
if [[ "$out" == *"▶ design"* ]]; then
    pass "after a prefix change it still finds markers stamped with the old one"
else
    fail "after a prefix change it still finds markers stamped with the old one" "$out"
fi

# There used to be an assertion here that status printed the marker subject exactly
# as stamped, rather than reassembled from the current prefix — the record lying
# about itself. status no longer prints the subject at all (the line restated the
# KEY and stage that the header and the track already show), so there is nothing
# left that could lie. The determination above is the part that had to survive.

if [ "$("$CONFIG" --get marker_prefix)" = "spec" ] \
   && grep -q '^marker_prefix_history=cue-dev$' .cue/dev/config; then
    pass "the old prefix is kept in marker_prefix_history"
else
    fail "the old prefix is kept in marker_prefix_history" "$(cat .cue/dev/config)"
fi

# Setting the same value again must do nothing (idempotent).
if out=$("$CONFIG" --set marker_prefix spec 2>&1) && [[ "$out" == *"Nothing to change"* ]]; then
    pass "setting the same value again does nothing"
else
    fail "setting the same value again does nothing" "$out"
fi

# --set must not erase comments the user wrote or other keys.
new_repo main
write_config "# our team convention" "base_branch=main"
"$CONFIG" --set remote origin >/dev/null 2>&1 || true
printf 'yes\n' | "$CONFIG" --set backup_prefix "spec/backup/" >/dev/null 2>&1
if grep -q '^# our team convention$' .cue/dev/config && grep -q '^base_branch=main$' .cue/dev/config; then
    pass "--set preserves comments and other keys"
else
    fail "--set preserves comments and other keys" "$(cat .cue/dev/config)"
fi

# --- language: the record language setting ---
#
# This value does not change the shell scripts' output. The scripts are fixed to
# English; what this decides is the prose Claude produces. So the only thing under
# test here is whether the value is read and validated properly.
new_repo main

if [ "$("$CONFIG" --get language)" = "en" ]; then
    pass "the default for language is en"
else
    fail "the default for language is en" "got: $("$CONFIG" --get language)"
fi

for good in ko en zh fr; do
    write_config "language=$good"
    if [ "$("$CONFIG" --get language)" = "$good" ] && "$CONFIG" --check >/dev/null 2>&1; then
        pass "accepts language=$good"
    else
        fail "accepts language=$good" "$("$CONFIG" --check 2>&1)"
    fi
done

# kr is a common typo for ko. It is two letters, so it passes the syntax — and
# passing it is right: with no catalog, whatever code it is simply gets handed to
# Claude. What must be rejected is a value that is not of the shape at all.
# `auto` used to be the default and is now rejected outright. It meant "not
# decided", on which the hook injected nothing — and once every skill body was
# translated to English, injecting nothing stopped meaning "follow the user" and
# started meaning "write English". A config still carrying it must fail loudly
# rather than quietly resolve to the thing it was chosen to avoid.
for bad in "auto" "korean" "k" "KO" "ko_KR" "1 2"; do
    write_config "language=$bad"
    if ! "$CONFIG" --check >/dev/null 2>&1; then
        pass "rejects language=$bad"
    else
        fail "rejects language=$bad"
    fi
done

# It does not go through the consent gate. It does not change how the history is
# read, so there is no reason to take a yes as marker_prefix does. It must pass
# with no stdin.
new_repo main
if "$CONFIG" --set language ko </dev/null >/dev/null 2>&1    && [ "$("$CONFIG" --get language)" = "ko" ]; then
    pass "--set language applies without a consent gate"
else
    fail "--set language applies without a consent gate" "$(cat .cue/dev/config 2>&1)"
fi

# --- the preview ---
#
# The preview used to be "run --set with no stdin and let the consent prompt hit
# EOF", which exited 1. A report that reports itself as a failure is unusable: in
# a real session Claude said "let me show you the preview first" and the user saw
# an error, after which the only path anyone found was handing the `--yes` command
# back for the user to type. --dry-run is the same report, and it succeeds.
new_repo main
out=$("$CONFIG" --set marker_prefix spec --dry-run 2>&1) && st=0 || st=$?
if [ "$st" -eq 0 ] && [ "$("$CONFIG" --get marker_prefix)" = "cue-dev" ]; then
    pass "--dry-run exits 0 and changes nothing"
else
    fail "--dry-run exits 0 and changes nothing" "exit $st: $out"
fi

if [[ "$out" == *"current"* && "$out" == *"new"* ]]; then
    pass "the preview shows the current and new values"
else
    fail "the preview shows the current and new values" "$out"
fi

# It has to say whether an answer is needed before applying, because that is what
# decides Claude's next move: ask, or just apply.
if [[ "$out" =~ consent[[:space:]] ]] && [[ "$out" == *"--yes"* ]]; then
    pass "the preview says consent is needed and how to carry it"
else
    fail "the preview says consent is needed and how to carry it" "$out"
fi

out=$("$CONFIG" --set language ko --dry-run 2>&1) && st=0 || st=$?
if [ "$st" -eq 0 ] && [[ "$out" == *"no consent needed"* ]] \
   && [ "$("$CONFIG" --get language)" = "en" ]; then
    pass "--dry-run on an ungated key says so, and still changes nothing"
else
    fail "--dry-run on an ungated key says so, and still changes nothing" "exit $st: $out"
fi

# EOF at the interactive prompt is still not consent. Nothing routes through it
# any more, but a gate that opened on an empty stdin would be no gate.
out=$("$CONFIG" --set marker_prefix spec </dev/null 2>&1) && st=0 || st=$?
if [ "$st" -ne 0 ] && [ "$("$CONFIG" --get marker_prefix)" = "cue-dev" ]; then
    pass "EOF at the consent prompt is not consent"
else
    fail "EOF at the consent prompt is not consent" "exit $st: $out"
fi

# --yes is the user's own command line. It applies, and it must still record the
# old prefix in the history — when this lived inside the prompt block, --yes
# applied the change while dropping the history, making every earlier marker
# unfindable.
write_demand PROJ-1
git add -A
git "${GIT_ID[@]}" commit -q -m "$("$MARKER" demand PROJ-1)"
if "$CONFIG" --set marker_prefix spec --yes </dev/null >/dev/null 2>&1 \
   && [ "$("$CONFIG" --get marker_prefix)" = "spec" ] \
   && grep -q '^marker_prefix_history=cue-dev$' .cue/dev/config; then
    pass "--set --yes applies and still records the prefix history"
else
    fail "--set --yes applies and still records the prefix history" "$(cat .cue/dev/config 2>&1)"
fi

# language must appear in the settings display, and so must a pointer to where the
# check level now lives. If they do not, the user never learns either exists.
#
# `min_check` is deliberately not asserted here any more: it prints only when the
# repository still carries the retired line, which this fixture does not.
#
# Captured rather than piped, for the SIGPIPE reason noted further up: grep -q
# closes the pipe on its match, config dies with 141 finishing the listing, and
# pipefail reports a failure despite the match. Piping worked here only while
# `language` happened to be the last line printed.
out=$("$CONFIG" 2>&1)
if [[ "$out" == *$'\n  language'* && "$out" == *$'\n  check'* ]]; then
    pass "the config output has a language line and points at work-check"
else
    fail "the config output has a language line and points at work-check" "$out"
fi

# --- min_check is retired: read for old items, never written again -----------
#
# The check level moved to the work item (demand.md's `check:`, scripts/work-check)
# because one repository-wide value could not be right for a colour change and a
# migration at once — and because parallel worktrees each carry their own copy of
# this file, so changing it for one item either missed the session beside it or
# reached everyone at merge time, retroactively.
#
# What must not happen is a new one being written. What must keep happening is an
# existing one being honoured, or upgrading the plugin silently re-judges work
# already in flight.

new_repo main

out=$("$CONFIG" --set min_check self-review --yes 2>&1) && st=0 || st=$?
if [ "$st" -ne 0 ] && [ ! -f .cue/dev/config ]; then
    pass "--set min_check is refused and writes nothing"
else
    fail "--set min_check is refused and writes nothing" "exit $st: $out" "$(cat .cue/dev/config 2>&1)"
fi

if [[ "$out" == *"work-check"* ]]; then
    pass "the refusal names where the question went"
else
    fail "the refusal names where the question went" "$out"
fi

out=$("$CONFIG" --get min_check 2>&1) && st=0 || st=$?
if [ "$st" -ne 0 ] && [[ "$out" == *"per work item"* ]]; then
    pass "--get min_check answers with the per-item script, not a value"
else
    fail "--get min_check answers with the per-item script, not a value" "exit $st: $out"
fi

# A repository that already carries the line is one that answered this question
# once. It stays valid, it stays out of the unrecognized-key list, and the display
# says plainly that it is retired rather than pretending it is a live setting.
write_config "min_check=self-review"
out=$("$CONFIG" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"retired"* ]]; then
    pass "an existing min_check line is shown as retired, not as a setting"
else
    fail "an existing min_check line is shown as retired, not as a setting" "exit $rc" "$out"
fi

if [[ "$out" != *"unrecognized"* ]]; then
    pass "it is not reported as an unrecognized key"
else
    fail "it is not reported as an unrecognized key" "$out"
fi

out=$("$CONFIG" --check 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ]; then
    pass "--check passes on a config that still carries it"
else
    fail "--check passes on a config that still carries it" "exit $rc" "$out"
fi

# And the live keys no longer include it, so `config` cannot present it as
# something to choose.
out=$("$CONFIG" --get nonesuch 2>&1) || true
if [[ "$out" != *"min_check"* ]]; then
    pass "min_check is gone from the list of settable keys"
else
    fail "min_check is gone from the list of settable keys" "$out"
fi

# --- unrecognized keys are visible, not fatal --------------------------------
#
# A typo silently reverts a policy to its default, so it has to be said. But an
# older plugin reading a newer config hits the same condition, and stopping there
# would make every upgrade a breakage.

new_repo main
write_config "min_chek=none" "language=ko"
out=$("$CONFIG" 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"min_chek"* ]]; then
    pass "an unrecognized key is reported without failing the run"
else
    fail "an unrecognized key is reported without failing the run" "exit $rc" "$out"
fi

if [ "$("$CONFIG" --get language)" = "ko" ]; then
    pass "a typo'd key leaves the real settings alone"
else
    fail "a typo'd key leaves the real settings alone" "$("$CONFIG" --get language)"
fi

finish
