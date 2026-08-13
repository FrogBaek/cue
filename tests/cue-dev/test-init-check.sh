#!/usr/bin/env bash
# scripts/init-check: determines whether the repository is ready to use cue-dev.
#
# There is a reason this script must not go untested. init-check is the gate built
# to prevent a defect that a real integration test exposed — the absence of a base
# branch surfacing only at finish — and step 0 of /cue-dev:start decides whether to
# proceed from this alone. A gate that passes silently brings the defect straight
# back.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT_CHECK="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/init-check"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/init-check ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

# init-check only judges, so exit 1 is a normal result. Wrap it so set -e does not
# catch it.
run_check() {
    RC=0
    OUT=$(bash "$INIT_CHECK" 2>&1) || RC=$?
}

# Looks a line up by key and returns its value. The output format is 'key<space>value'.
field() { printf '%s\n' "$OUT" | sed -n "s/^$1  *//p" | head -1; }

assert_line() {
    local key=$1 want=$2 label=$3 got
    got=$(field "$key")
    case "$got" in
        *"$want"*) pass "$label" ;;
        *) fail "$label" "want: '$want' in $key" "got: $key = '$got'" ;;
    esac
}

# --- exit 2 when it is not a repository --------------------------------------
mkdir -p "$TEST_ROOT/not-a-repo"
cd "$TEST_ROOT/not-a-repo"
run_check
if [ "$RC" -eq 2 ]; then
    pass "exit 2 outside a git repository"
else
    fail "exit 2 outside a git repository" "exit: $RC" "output: $OUT"
fi

# --- zero commits is blocked --------------------------------------------------
# This is where a real session went wrong. Starting on an unborn branch meant no
# base branch was ever created, and that surfaced the moment we tried to open a PR.
git init -q -b main "$TEST_ROOT/empty"
cd "$TEST_ROOT/empty"
run_check
if [ "$RC" -eq 1 ]; then
    pass "exit 1 when there are no commits"
else
    fail "exit 1 when there are no commits" "exit: $RC" "output: $OUT"
fi
assert_line commits 0 "reports zero commits as they are"
assert_line blocked "the repository has no commits" "puts the blocking reason on blocked"

# --- a healthy repository -----------------------------------------------------
new_repo main
run_check
if [ "$RC" -eq 0 ]; then
    pass "exit 0 for a ready repository"
else
    fail "exit 0 for a ready repository" "exit: $RC" "output: $OUT"
fi
assert_line blocked "none" "blocked is none when nothing blocks"
assert_line branch main "reports the current branch"
assert_line config "absent (all defaults)" "no settings means all defaults"
assert_line config_valid ok "config_valid is ok even with no settings"
assert_line marker_prefix cue-dev "shows the default marker_prefix"
assert_line markers "none" "with no markers, it says the prefix is still free"
assert_line works "0" "zero work items when there are none"

# --- it changes nothing -------------------------------------------------------
# A determination script with side effects would let step 0 of /cue-dev:start
# pollute the repository just by checking. It is especially worth verifying because
# the gitignore determination uses a check-ignore probe path.
before=$(git status --porcelain; git rev-parse HEAD)
run_check
after=$(git status --porcelain; git rev-parse HEAD)
if [ "$before" = "$after" ]; then
    pass "it only judges and never touches the repository"
else
    fail "it only judges and never touches the repository" "before: $before" "after: $after"
fi

# --- start point candidates ---------------------------------------------------
#
# Reported, never settled. The branch work is cut from belongs to the work item,
# so /cue-dev:start settles it per item; what init-check can usefully say is which
# branches are there to be proposed from.
assert_line start_points "candidates: main" "with nothing configured it proposes candidates that exist"

git branch -q develop
run_check
assert_line start_points "main develop" "lists every candidate it finds"

# A candidate list is not an instruction. It has to say who settles the question,
# or init reads it as a setting waiting to be written.
assert_line start_points "per work item" "says the start point is settled per work item"

# --- a start point that exists only on a remote -------------------------------
#
# Clone a git-flow repository and the local checkout holds `main` alone; `develop`
# is `origin/develop` and nothing else. Checking refs/heads only, init-check hid
# the one candidate such a repository needs, and the user was never offered the
# branch they had to start from.
git branch -q -D develop
git update-ref refs/remotes/origin/develop HEAD
git remote add origin https://example.invalid/r.git 2>/dev/null || true

run_check
assert_line start_points "develop" "a remote-only branch is offered as a candidate"

git update-ref -d refs/remotes/origin/develop 2>/dev/null || true
git remote remove origin 2>/dev/null || true

# --- a leftover base_branch never blocks --------------------------------------
#
# It used to. A base_branch in the config that resolved to nothing stopped init,
# which put one stale line in a settings file between the user and every piece of
# work in the repository - over a value that is not a setting at all now.
mkdir -p .cue/dev
printf 'base_branch=nonexistent\n' > .cue/dev/config
run_check
if [ "$RC" -eq 0 ]; then
    pass "a leftover base_branch does not block"
else
    fail "a leftover base_branch does not block" "exit: $RC" "output: $OUT"
fi

# It is not reported as a start point either. init-check has no opinion about it;
# config --check is where an unrecognized key gets named.
if printf '%s\n' "$OUT" | grep -q '^base_branch'; then
    fail "no base_branch line in init-check" "$OUT"
else
    pass "no base_branch line in init-check"
fi

rm -f .cue/dev/config

# --- broken settings are blocked ----------------------------------------------
printf 'marker_prefix=bad:prefix\n' > .cue/dev/config
run_check
if [ "$RC" -eq 1 ]; then
    pass "exit 1 when the settings are broken"
else
    fail "exit 1 when the settings are broken" "exit: $RC" "output: $OUT"
fi
assert_line config_valid "has problems" "reports broken settings through config_valid"
if printf '%s\n' "$OUT" | grep -q '^config_problem .*colon'; then
    pass "says what the problem is through config_problem"
else
    fail "says what the problem is through config_problem" "output: $OUT"
fi
rm -f .cue/dev/config

# --- remotes ------------------------------------------------------------------
run_check
assert_line remote "none (local only" "with no remote it says the PR path is unavailable"

git remote add upstream https://example.invalid/r.git
run_check
assert_line remote "unset (available: upstream)" "with a remote but no setting it shows the real names"

printf 'remote=upstream\n' > .cue/dev/config
run_check
assert_line remote "upstream (configured)" "reports a configured remote as it is"
rm -f .cue/dev/config

# --- gitignore ----------------------------------------------------------------
run_check
assert_line gitignore "no rule for .cue/dev/sdd/" "reports a missing scratch ignore rule"

printf '.cue/dev/sdd/\n' > .gitignore
run_check
assert_line gitignore "ok" "ok once the scratch ignore rule exists"

# Ignoring the records too means nothing gets committed — the accident in the
# opposite direction.
printf '.cue/dev/\n' > .gitignore
run_check
if printf '%s\n' "$OUT" | grep -q 'WARNING: .cue/dev/<KEY>/ is ignored'; then
    pass "warns when the record directory is ignored wholesale"
else
    fail "warns when the record directory is ignored wholesale" "output: $OUT"
fi
rm -f .gitignore

# The worktree directory. using-git-worktrees has always called verifying this
# "critical" and "MUST", and nothing checked it — the one rule this script looked
# at was the scratch. It matters more now than when that was written: cue-dev cuts
# its worktrees into `.worktrees/` itself instead of asking a harness to place
# them somewhere outside the repository, so an unignored directory is a whole
# second checkout one `git add -A` away from being committed.
run_check
if printf '%s\n' "$OUT" | grep -q 'no rule for .worktrees/'; then
    pass "reports a missing worktree ignore rule"
else
    fail "reports a missing worktree ignore rule" "output: $OUT"
fi

printf '.worktrees/\n' > .gitignore
run_check
if printf '%s\n' "$OUT" | grep -q 'ok (.worktrees/ is ignored)'; then
    pass "ok once the worktree ignore rule exists"
else
    fail "ok once the worktree ignore rule exists" "output: $OUT"
fi
rm -f .gitignore

# --- gitattributes is only reported -------------------------------------------
# The line-ending policy affects the whole repository, so it is not cue-dev's to
# decide quietly.
run_check
assert_line gitattributes "absent" "a missing gitattributes is only reported"
if [ "$RC" -eq 0 ]; then
    pass "a missing gitattributes does not block"
else
    fail "a missing gitattributes does not block" "exit: $RC"
fi

printf '* text=auto\n' > .gitattributes
run_check
assert_line gitattributes "present" "an existing gitattributes is marked present"
rm -f .gitattributes

# --- markers and the work count -----------------------------------------------
KEY=PROJ-9
commit_stage "$KEY" demand demand.md
run_check
assert_line markers "present" "with markers it states the cost of changing the prefix"
assert_line works "1" "counts the work directories"

# The scratch is not a work item. Counting it makes it look like one KEY too many.
mkdir -p .cue/dev/sdd/plan-a
run_check
assert_line works "1" "the scratch directory is not counted as work"

finish
