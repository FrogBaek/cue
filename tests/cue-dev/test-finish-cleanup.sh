#!/usr/bin/env bash
# scripts/finish-cleanup: retire the workspace, and report what is actually there.
#
# Two regressions, one shape. In a real session the user chose the path that
# cleans the worktree up and the notice said `worktree preserved` — nothing had
# been removed, so the report came from intent rather than from the last
# observation. And no run of cue-dev, ever, had deleted `.cue/dev/sdd/`: every
# finished item left one behind and every new worktree grew another.
#
# So the assertions here are mostly about the *report* matching the disk.
#
# It takes a KEY now, not a path. The path lives in that item's demand.md header,
# written when the worktree was cut — which is the only moment it is unambiguous.
# Before that, ownership was worked out by matching the path against two patterns
# with `harness` as the fallback, and a session that put its worktree at
# `.cue/worktrees/<KEY>` matched neither: it was declared harness-owned, handed to
# a tool that no-ops on a `git worktree add` worktree, and reported `still
# present` with exit 1. One invented path, five symptoms.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLEANUP="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/finish-cleanup"
WORKPATH="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/work-path"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/finish-cleanup ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

run() {
    RC=0
    OUT=$(bash "$CLEANUP" "$@" 2>&1) || RC=$?
}

# An item with a demand.md, and optionally a recorded worktree.
record() {  # record <KEY> [<worktree path>]
    mkdir -p "$MAIN/.cue/dev/$1"
    {
        printf '<!-- cue-dev · written 2026-08-06 · source: conversation -->\n'
        [ -n "${2:-}" ] && printf '<!-- worktree: %s -->\n' "$2"
        printf '\n# %s\n' "$1"
    } > "$MAIN/.cue/dev/$1/demand.md"
}

# --- an item with no worktree ------------------------------------------------
new_repo main
MAIN=$(pwd -P)
record IN-PLACE
mkdir -p .cue/dev/sdd/plan
echo scratch > .cue/dev/sdd/plan/task-1.md

run IN-PLACE
if [ ! -d "$MAIN/.cue/dev/sdd" ]; then
    pass "the implementation scratch is removed"
else
    fail "the implementation scratch is removed" "$OUT"
fi
if [[ "$OUT" =~ scratch[[:space:]]+removed ]]; then
    pass "it reports the scratch removal"
else
    fail "it reports the scratch removal" "$OUT"
fi

# No recorded worktree, standing in the main checkout: nothing to remove, and
# saying so is not the same as claiming to have removed something.
if [ "$RC" -eq 0 ] && [[ "$OUT" == *"no worktree"* ]]; then
    pass "an item with no worktree says so"
else
    fail "an item with no worktree says so" "exit: $RC" "$OUT"
fi

run IN-PLACE
if [[ "$OUT" =~ scratch[[:space:]]+none ]]; then
    pass "a second run reports no scratch rather than inventing one"
else
    fail "a second run reports no scratch rather than inventing one" "$OUT"
fi

# --- a recorded worktree is removed, and the report matches the disk ---------
WT="$MAIN/.worktrees/PROJ-1"
git "${GIT_ID[@]}" worktree add -q "$WT" -b cue-dev/PROJ-1 >/dev/null 2>&1
record PROJ-1 "$WT"
mkdir -p "$WT/.cue/dev/sdd/plan"
echo scratch > "$WT/.cue/dev/sdd/plan/task-1.md"

run PROJ-1
if [ "$RC" -eq 0 ] && [ ! -d "$WT" ]; then
    pass "a recorded worktree is removed"
else
    fail "a recorded worktree is removed" "exit: $RC" "$OUT" "$(ls -d "$WT" 2>&1 || true)"
fi
if [[ "$OUT" =~ worktree[[:space:]]+removed ]]; then
    pass "it reports the removal it actually performed"
else
    fail "it reports the removal it actually performed" "$OUT"
fi

# --- uncommitted work stops the removal --------------------------------------
#
# `git worktree remove --force` discards uncommitted changes without a word, and
# that is how a generated explanation page was lost: nothing committed it, and
# finish removed the directory it was sitting in. The scratch is exempt — it is
# what this script deletes on purpose — so the check must fire on a file beside
# it and not on the scratch itself.
WT9="$MAIN/.worktrees/PROJ-9"
git "${GIT_ID[@]}" worktree add -q "$WT9" -b cue-dev/PROJ-9 >/dev/null 2>&1
record PROJ-9 "$WT9"
mkdir -p "$WT9/.cue/dev/sdd/plan" "$WT9/.cue/dev/PROJ-9"
echo scratch > "$WT9/.cue/dev/sdd/plan/task-1.md"
echo 'notes' > "$WT9/.cue/dev/PROJ-9/notes.md"

run PROJ-9
if [ "$RC" -eq 1 ] && [ -d "$WT9" ]; then
    pass "a worktree holding uncommitted work is not removed"
else
    fail "a worktree holding uncommitted work is not removed" "exit: $RC" "$OUT"
fi
if [[ "$OUT" == *"notes.md"* ]]; then
    pass "it names the file that would have been destroyed"
else
    fail "it names the file that would have been destroyed" "$OUT"
fi
if [ -f "$WT9/.cue/dev/sdd/plan/task-1.md" ]; then
    pass "nothing is removed on the refusing path — not even the scratch"
else
    fail "nothing is removed on the refusing path — not even the scratch" "$OUT"
fi
if [[ "$OUT" != *"sdd/plan/task-1.md"* ]]; then
    pass "the scratch is not counted as work at risk"
else
    fail "the scratch is not counted as work at risk" "$OUT"
fi

# --force is how the user's consent gets carried out, once they have seen that
# list. It is the only thing that removes it.
run --force PROJ-9
if [ "$RC" -eq 0 ] && [ ! -d "$WT9" ]; then
    pass "--force removes it once the user has decided"
else
    fail "--force removes it once the user has decided" "exit: $RC" "$OUT"
fi

# The parent goes too, and only because it is empty. A real session left
# `.cue/worktrees/` sitting there after the worktree inside it went, because this
# script only ever looked at the worktree path itself.
if [ ! -d "$MAIN/.worktrees" ]; then
    pass "an empty .worktrees/ goes with the last worktree in it"
else
    fail "an empty .worktrees/ goes with the last worktree in it" "$(ls -a "$MAIN/.worktrees")"
fi

# --- a parent that still holds another item's worktree stays ------------------
KEEP="$MAIN/.worktrees/PROJ-KEEP"
GO="$MAIN/.worktrees/PROJ-GO"
git "${GIT_ID[@]}" worktree add -q "$KEEP" -b cue-dev/PROJ-KEEP >/dev/null 2>&1
git "${GIT_ID[@]}" worktree add -q "$GO" -b cue-dev/PROJ-GO >/dev/null 2>&1
record PROJ-GO "$GO"
run PROJ-GO
if [ ! -d "$GO" ] && [ -d "$KEEP" ]; then
    pass "a parent holding another worktree is left alone"
else
    fail "a parent holding another worktree is left alone" "exit: $RC" "$OUT"
fi
git "${GIT_ID[@]}" worktree remove --force "$KEEP" >/dev/null 2>&1 || true

# --- a worktree cue-dev did not make -----------------------------------------
# No recorded path, and the caller is standing in a linked worktree. This is where
# the script used to guess `harness` and name a tool — an owner who, in the one
# session that exercised it, was never going to act. Unknown is reported as
# unknown.
FOREIGN="$MAIN/.elsewhere/PROJ-2"
git "${GIT_ID[@]}" worktree add -q "$FOREIGN" -b cue-dev/PROJ-2 >/dev/null 2>&1
mkdir -p "$MAIN/.cue/dev/PROJ-2"
printf '<!-- cue-dev · written 2026-08-06 -->\n\n# PROJ-2\n' > "$MAIN/.cue/dev/PROJ-2/demand.md"
mkdir -p "$FOREIGN/.cue/dev/sdd"
echo scratch > "$FOREIGN/.cue/dev/sdd/note.md"

RC=0
OUT=$(cd "$FOREIGN" && bash "$CLEANUP" PROJ-2 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && [ -d "$FOREIGN" ]; then
    pass "a worktree cue-dev did not make is left in place"
else
    fail "a worktree cue-dev did not make is left in place" "exit: $RC" "$OUT"
fi
if [[ "$OUT" == *"not cue-dev's"* ]]; then
    pass "it says whose it is not, rather than naming an owner it guessed"
else
    fail "it says whose it is not, rather than naming an owner it guessed" "$OUT"
fi
if [[ "$OUT" != *"ExitWorktree"* ]]; then
    pass "it no longer calls for a harness exit tool"
else
    fail "it no longer calls for a harness exit tool" "$OUT"
fi
if [ ! -d "$FOREIGN/.cue/dev/sdd" ]; then
    pass "the scratch in that checkout is still cleaned"
else
    fail "the scratch in that checkout is still cleaned" "$OUT"
fi

# --- --verify while the directory is still there -----------------------------
# Reporting a cleanup that did not happen is worse than leaving the directory,
# because the user stops looking.
record PROJ-2 "$FOREIGN"
run --verify PROJ-2
if [ "$RC" -eq 1 ] && [[ "$OUT" == *"still present"* ]]; then
    pass "--verify fails while the directory is still there"
else
    fail "--verify fails while the directory is still there" "exit: $RC" "$OUT"
fi

# --- the leftover an unregistering removal leaves behind ---------------------
# The registration goes and an empty directory stays. `git worktree remove` on
# that path fails with `is not a working tree`, which is what got reported as
# success.
git "${GIT_ID[@]}" worktree remove --force "$FOREIGN" >/dev/null 2>&1 || true
mkdir -p "$FOREIGN"
run --verify PROJ-2
if [ "$RC" -eq 0 ] && [ ! -d "$FOREIGN" ]; then
    pass "--verify clears an empty unregistered leftover"
else
    fail "--verify clears an empty unregistered leftover" "exit: $RC" "$OUT"
fi

# --- a directory with files in it is refused, not deleted --------------------
# rmdir and not rm -rf. Whatever is in there, nobody asked for it to go.
mkdir -p "$FOREIGN"
echo "someone's uncommitted work" > "$FOREIGN/notes.txt"
run --verify PROJ-2
if [ "$RC" -eq 1 ] && [ -f "$FOREIGN/notes.txt" ]; then
    pass "a non-empty leftover is reported, never deleted"
else
    fail "a non-empty leftover is reported, never deleted" "exit: $RC" "$OUT"
fi

# --- a recorded path that is already gone is the goal state ------------------
run --verify PROJ-1
if [ "$RC" -eq 0 ] && [[ "$OUT" == *"already gone"* ]]; then
    pass "a recorded path that no longer exists succeeds"
else
    fail "a recorded path that no longer exists succeeds" "exit: $RC" "$OUT"
fi

# --- a record pointing at the repository itself is refused -------------------
# The one guard left after ownership stopped being guessed. Acting on it would
# hand this script the whole checkout to remove.
record SELF-REF "$MAIN"
run SELF-REF
if [ "$RC" -eq 1 ] && [ -d "$MAIN/.git" ]; then
    pass "a record pointing at the main checkout is refused, not acted on"
else
    fail "a record pointing at the main checkout is refused, not acted on" "exit: $RC" "$OUT"
fi

# --- the record is on the item's branch, and finish runs in the main checkout -
#
# The whole of the real failure, in one setup. finish does not move the session
# into the worktree, so it runs where HEAD is the base branch — and an item that
# has not merged yet has its `.cue/dev/<KEY>/` on its own branch and nowhere else.
# Every lookup came back empty, the emptiness was read as "this item has no
# worktree", and the script exited 0 having removed nothing while the notice
# reported a settled workspace.
new_repo main
MAIN=$(pwd -P)
BRANCHED="$MAIN/.worktrees/PROJ-BR"
git "${GIT_ID[@]}" worktree add -q "$BRANCHED" -b feat/proj-br >/dev/null 2>&1
mkdir -p "$BRANCHED/.cue/dev/PROJ-BR"
{
    printf '<!-- cue-dev · written 2026-08-11 · source: conversation -->\n'
    printf '<!-- worktree: %s -->\n' "$BRANCHED"
    printf '\n# PROJ-BR\n'
} > "$BRANCHED/.cue/dev/PROJ-BR/demand.md"
git "${GIT_ID[@]}" -C "$BRANCHED" add .cue >/dev/null 2>&1
git "${GIT_ID[@]}" -C "$BRANCHED" commit -qm "cue-dev(demand): PROJ-BR" >/dev/null 2>&1
mkdir -p "$BRANCHED/.cue/dev/sdd"
echo scratch > "$BRANCHED/.cue/dev/sdd/note.md"

[ ! -d "$MAIN/.cue/dev/PROJ-BR" ] || fail "fixture: the record must not be visible from main"

RC=0
OUT=$(cd "$MAIN" && bash "$CLEANUP" PROJ-BR 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && [ ! -d "$BRANCHED" ]; then
    pass "a record living only on the item's branch is still found from the main checkout"
else
    fail "a record living only on the item's branch is still found from the main checkout" "exit: $RC" "$OUT"
fi
if [[ "$OUT" =~ worktree[[:space:]]+removed ]]; then
    pass "it reports the removal rather than 'this item has no worktree'"
else
    fail "it reports the removal rather than 'this item has no worktree'" "$OUT"
fi
if [ ! -d "$MAIN/.worktrees" ]; then
    pass "the empty .worktrees/ goes with it"
else
    fail "the empty .worktrees/ goes with it" "$OUT"
fi

# --- a KEY with no record anywhere is unknown, not "no worktree" --------------
# The floor under the lookup above. An unanswered question must not leave here as
# a fact, because the caller writes the notice from these lines.
RC=0
OUT=$(cd "$MAIN" && bash "$CLEANUP" NO-SUCH-ITEM 2>&1) || RC=$?
if [ "$RC" -eq 1 ] && [[ "$OUT" == *"unknown"* ]]; then
    pass "a KEY with no record anywhere is reported as unknown"
else
    fail "a KEY with no record anywhere is reported as unknown" "exit: $RC" "$OUT"
fi

# --- work-path is the only author of that line -------------------------------
new_repo main
MAIN=$(pwd -P)
# The same argument as scripts/marker and work-base --line: a line another script
# parses must have one author, or it drifts in the one repository that formatted
# it differently — silently, because the file is written and the commit succeeds.
LINE=$(cd "$MAIN" && bash "$WORKPATH" --line "$MAIN" 2>&1)
if [ "$LINE" = "<!-- worktree: $MAIN -->" ]; then
    pass "work-path --line prints the header line finish-cleanup reads"
else
    fail "work-path --line prints the header line finish-cleanup reads" "$LINE"
fi

# --- the empty parent goes on every path that reaches "already gone" ---------
#
# `.worktrees/` was cleared only where this script did the removal itself. Every
# other route to an absent worktree — a `git worktree remove` by hand, a harness,
# an earlier run whose rmdir lost a race with a Windows lock — returned "already
# gone" several lines earlier and left the empty parent standing. A real
# repository carried one for two sessions.
new_repo main
MAIN=$(pwd -P)
WTP="$MAIN/.worktrees/PROJ-P"
git "${GIT_ID[@]}" worktree add -q "$WTP" -b cue-dev/PROJ-P >/dev/null 2>&1
record PROJ-P "$WTP"
git "${GIT_ID[@]}" worktree remove --force "$WTP"

run --verify PROJ-P
if [[ "$OUT" == *"already gone"* ]] && [ ! -d "$MAIN/.worktrees" ]; then
    pass "an empty .worktrees/ is cleared even when something else did the removal"
else
    fail "an empty .worktrees/ is cleared even when something else did the removal"         "$OUT" "$(ls -d "$MAIN/.worktrees" 2>&1 || true)"
fi

# --- how much there is to delete, said before deleting it ---------------------
#
# The removal unlinks the worktree file by file, build output included, and a
# dependency directory is tens of thousands of files. Measured on the machine this
# was written on: 8,201 files took 41 seconds. In a real session the step passed
# the harness's 120-second ceiling, went to the background, and starved the rest of
# the session for disk — a bare `git log` right after it took fifteen minutes. The
# files still have to go; what was missing was the number, printed while it can
# still explain the wait.
new_repo main
MAIN=$(pwd -P)
BIG="$MAIN/.worktrees/BIG"
git "${GIT_ID[@]}" worktree add -q "$BIG" -b big-item >/dev/null 2>&1
record BIG "$BIG"

# Ignored, so they are not the dirty check's business — the point is the unlink
# cost, which every file carries whether git tracks it or not.
printf 'nm/\n' > "$BIG/.gitignore"
git -C "$BIG" add -A && git -C "$BIG" "${GIT_ID[@]}" commit -qm "chore: ignore nm"
mkdir -p "$BIG/nm"
i=0; while [ "$i" -lt 5100 ]; do : > "$BIG/nm/f$i"; i=$((i + 1)); done

run BIG
if [[ "$OUT" =~ size[[:space:]]+5[0-9]+[[:space:]]files ]]; then
    pass "a large worktree is counted out loud before it is removed"
else
    fail "a large worktree is counted out loud before it is removed" "$OUT"
fi

# And the ordinary case says nothing. A `size 4 files` line on every finish is one
# more line that stops being read.
new_repo main
MAIN=$(pwd -P)
SMALL="$MAIN/.worktrees/SMALL"
git "${GIT_ID[@]}" worktree add -q "$SMALL" -b small-item >/dev/null 2>&1
record SMALL "$SMALL"

run SMALL
if [[ "$OUT" != *size* ]]; then
    pass "an ordinary worktree is removed without a word about its size"
else
    fail "an ordinary worktree is removed without a word about its size" "$OUT"
fi

# --- usage -------------------------------------------------------------------
run
[ "$RC" -eq 2 ] && pass "exit 2 with no arguments" || fail "exit 2 with no arguments" "$OUT"

# The flag after the KEY used to break out of the parse loop on the KEY and then
# fail the arity check, with a usage line that showed the flags first and did not
# say the order was the problem. A real session read the refusal as "--force does
# not exist", put the flag in front, and got the same refusal it already had.
new_repo main
MAIN=$(pwd -P)
record NO-WT
run NO-WT --verify
[ "$RC" -eq 0 ] && pass "a flag after the KEY is accepted"     || fail "a flag after the KEY is accepted" "exit: $RC" "$OUT"

run NO-WT EXTRA
[ "$RC" -eq 2 ] && pass "two KEYs are still a usage error"     || fail "two KEYs are still a usage error" "exit: $RC" "$OUT"

run "a/b"
[ "$RC" -eq 2 ] && pass "exit 2 for a KEY containing a slash" \
    || fail "exit 2 for a KEY containing a slash" "exit: $RC" "$OUT"

finish
