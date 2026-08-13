#!/usr/bin/env bash
# scripts/integration: how work leaves this repository, and whether an item left.
#
# The menu finish shows used to be four options in the shape of GitHub. This is
# the script that replaced that shape with a question the repository can answer,
# so what matters here is that the answers stay honest at the edges — a forge that
# is named but not installed, a landing that git cannot see, an item whose branch
# was never recorded.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPTS="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts"
INTEGRATION="$SCRIPTS/integration"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/integration ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

# Builds an item with a recorded branch and start point, on a branch of its own.
# item <KEY> <base-branch>
item() {
    local key=$1 base=$2 sha
    sha=$(git rev-parse --short HEAD)
    git checkout -q -b "work-$key"
    mkdir -p ".cue/dev/$key"
    {
        printf '<!-- base: %s @ %s -->\n' "$base" "$sha"
        printf '<!-- branch: work-%s -->\n' "$key"
        printf '\n# %s\n' "$key"
    } > ".cue/dev/$key/demand.md"
    git add -A
    git "${GIT_ID[@]}" commit -qm "cue-dev(demand): $key"
}

# --- the adapter is observed, and observation is conservative ---------------
new_repo
out=$("$INTEGRATION")
if printf '%s' "$out" | grep -q 'adapter *none'; then
    pass "no remote is adapter none"
else
    fail "no remote is adapter none" "$out"
fi

if [ "$("$INTEGRATION" --actions | tr '\n' ' ')" = "keep " ]; then
    pass "with no forge the only action is keep"
else
    fail "with no forge the only action is keep" "$("$INTEGRATION" --actions | tr '\n' ' ')"
fi

# The display and the token list answer differently, on purpose, and a caller that
# reads the wrong one is wrong only in the repository where it matters.
#
# With no forge there is no `request` action — and the *display* still carries a
# `request` line, because that line's job there is to say the action is
# unavailable. A caller testing "did it print request" therefore gets yes in the
# one case the answer is no, and finish did exactly that at 5a and 9a: a
# repository with no remote would have been offered an explanation page for a
# reviewer it cannot send it to, and a change-request option that dies on the push.
if printf '%s' "$out" | grep -q 'request'; then
    pass "the display mentions request even with no forge — which is why callers read --actions"
else
    fail "the display mentions request even with no forge" "$out"
fi

# The merge is repository scope — it takes the main checkout for the length of the
# tests — so it is offered after the menu, behind scripts/merge-lock. Two sessions
# handed it in the same menu both pick it and both walk into the same working tree.
if ! "$INTEGRATION" --actions | grep -q '^merge$'; then
    pass "merge is never a menu action"
else
    fail "merge is never a menu action" "$("$INTEGRATION" --actions | tr '\n' ' ')"
fi

git remote add origin https://gitlab.example.com/x/y.git
out=$("$INTEGRATION")
if printf '%s' "$out" | grep -q 'adapter *git'; then
    pass "a remote that is not a known forge is adapter git"
else
    fail "a remote that is not a known forge is adapter git" "$out"
fi

if [ "$("$INTEGRATION" --actions | tr '\n' ' ')" = "request keep " ]; then
    pass "a remote adds the request action"
else
    fail "a remote adds the request action" "$("$INTEGRATION" --actions | tr '\n' ' ')"
fi

# The half that is easy to get wrong: claiming github on the URL alone puts an
# option in the menu that dies on the command that would carry it out.
git remote set-url origin https://github.com/x/y.git
out=$("$INTEGRATION")
if command -v gh >/dev/null 2>&1; then
    expect=github
else
    expect=git
fi
if printf '%s' "$out" | grep -q "adapter *$expect"; then
    pass "github is claimed only when gh is actually on PATH (here: $expect)"
else
    fail "github is claimed only when gh is actually on PATH" "expected $expect" "$out"
fi

# --- config overrides observation ------------------------------------------
# The case observation cannot see: a mirror whose requests go somewhere else.
mkdir -p .cue/dev
printf 'integration=none\n' > .cue/dev/config
out=$("$INTEGRATION")
if printf '%s' "$out" | grep -q 'adapter *none' \
   && printf '%s' "$out" | grep -q 'source *set in'; then
    pass "a configured adapter beats observation, and says so"
else
    fail "a configured adapter beats observation, and says so" "$out"
fi

if [ "$("$SCRIPTS/config" --get integration)" = "none" ]; then
    pass "config --get integration returns the resolved value"
else
    fail "config --get integration returns the resolved value" "$("$SCRIPTS/config" --get integration)"
fi

printf 'integration=perforce\n' > .cue/dev/config
if "$SCRIPTS/config" --check >/dev/null 2>&1; then
    fail "an unusable integration value fails --check"
else
    pass "an unusable integration value fails --check"
fi
rm -f .cue/dev/config

# --- landed: the answer that a squash merge must not turn into a lie --------
new_repo
git remote add origin https://gitlab.example.com/x/y.git
item K1 main
git checkout -q main
git "${GIT_ID[@]}" merge -q --no-ff work-K1 -m "merge K1"

out=$("$INTEGRATION" --landed K1)
if printf '%s' "$out" | grep -q 'landed *yes'; then
    pass "a branch merged into its base reads as landed"
else
    fail "a branch merged into its base reads as landed" "$out"
fi

# Squash is the common way work lands on a forge, and it leaves no ancestry. With
# a forge in play the only honest answer is unknown — reporting `no` here would
# send finish into offering an integration that already happened.
new_repo
git remote add origin https://gitlab.example.com/x/y.git
item K2 main
echo change > f.txt
git add -A && git "${GIT_ID[@]}" commit -qm "work"
git checkout -q main
git merge -q --squash work-K2 >/dev/null 2>&1 || true
git add -A && git "${GIT_ID[@]}" commit -qm "squashed K2"

out=$("$INTEGRATION" --landed K2)
if printf '%s' "$out" | grep -q 'landed *unknown'; then
    pass "a squash landing reads as unknown, not as not-landed"
else
    fail "a squash landing reads as unknown, not as not-landed" "$out"
fi

if printf '%s' "$out" | grep -q 'do not report this as not landed'; then
    pass "the unknown answer says what to do with it"
else
    fail "the unknown answer says what to do with it" "$out"
fi

# With no forge at all there is nothing that could have rewritten the commits, so
# `no` is the honest answer rather than a hedge.
# Asked from the item's own branch, which is where finish stands: the record is
# committed there and nowhere else until the work lands.
new_repo
item K3 main
echo change > f.txt
git add -A && git "${GIT_ID[@]}" commit -qm "work"
out=$("$INTEGRATION" --landed K3)
if printf '%s' "$out" | grep -q 'landed *no'; then
    pass "with no forge, an uncontained branch reads as not landed"
else
    fail "with no forge, an uncontained branch reads as not landed" "$out"
fi

# --- refusals ---------------------------------------------------------------
if "$INTEGRATION" --landed no-such-key >/dev/null 2>&1; then
    fail "an unknown KEY is refused"
else
    pass "an unknown KEY is refused"
fi

# An item with no `branch:` line cannot be asked about: there is nothing to look
# up on the forge and nothing to compare against the base.
mkdir -p .cue/dev/K4
printf '<!-- base: main @ %s -->\n' "$(git rev-parse --short HEAD)" > .cue/dev/K4/demand.md
if "$INTEGRATION" --landed K4 >/dev/null 2>&1; then
    fail "an item with no recorded branch is refused"
else
    pass "an item with no recorded branch is refused"
fi

if "$INTEGRATION" --nonsense >/dev/null 2>&1; then
    fail "an unknown flag is a usage error"
else
    pass "an unknown flag is a usage error"
fi

finish
