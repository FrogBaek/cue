#!/usr/bin/env bash
# Shared fixtures for the cue-dev script tests.
#
# All path comparisons are aligned on pwd. On Git Bash, `git rev-parse
# --show-toplevel` yields `C:/...` while `pwd` yields `/c/...`, so mixing the two
# produces a test that fails on Windows only.

# shellcheck shell=bash

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    shift
    for line in "$@"; do echo "    $line"; done
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        chmod -R u+w "$TEST_ROOT" 2>/dev/null || true
        rm -rf "$TEST_ROOT"
    fi
}

# In-place sed, on GNU and BSD alike. `sed -i 's/…/…/' file` is GNU-only: BSD sed
# (macOS) reads the next argument as a mandatory backup suffix, so the same line
# eats the filename and reports a bad command. Rewriting through a temporary file
# is the one form both accept. Takes sed's arguments, with the file last.
sed_i() {
    local args=("$@")
    local last=$(( ${#args[@]} - 1 ))
    local file=${args[$last]}
    local tmp="$file.sed-tmp.$$"
    unset 'args[last]'
    sed "${args[@]}" "$file" > "$tmp" && mv -f "$tmp" "$file"
}

GIT_ID=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false)

# Stamps one marker commit. commit_stage <KEY> <stage> [filename...]
commit_stage() {
    local key=$1 stage=$2; shift 2
    local f
    mkdir -p ".cue/dev/$key"
    for f in "$@"; do
        printf '%s content\n' "$f" > ".cue/dev/$key/$f"
    done
    git add -A
    git "${GIT_ID[@]}" commit -qm "cue-dev($stage): $key"
}

# Records that pass scripts/verify.
#
# scripts/marker refuses to stamp a stage whose records fail verify, so a fixture
# that wrote the word `demand` into demand.md can no longer reach a marker commit.
# That is the gate working, and it means any fixture that stamps a marker has to
# look like a record. These write the smallest one each stage's checks accept —
# the prose is filler, the shape is the part under test.
#
# commit_stage above is unaffected: it writes the marker subject itself and never
# calls the script, which is right for tests about how markers are *read*.
write_demand() {
    local key=$1 work
    work=".cue/dev/$key"
    mkdir -p "$work"
    {
        printf '<!-- cue-dev · written 2026-01-01 · source: test fixture -->\n'
        printf '<!-- check: self-review -->\n\n'
        printf '# %s\n\n' "$key"
        printf '## Requirement\n\nA fixture requirement.\n\n'
        printf '## Acceptance criteria\n\n- the fixture behaves as written\n'
    } > "$work/demand.md"
}

write_design() {
    local key=$1 work
    work=".cue/dev/$key"
    mkdir -p "$work"
    {
        printf '## Structure\n\nNothing moves.\n\n'
        printf '## What we build\n\nA fixture.\n\n'
        printf '## Worked example\n\nin: 30 — out: 30\n\n'
        printf '## Why this way\n\nIt is the smallest thing that answers the requirement.\n\n'
        printf '## Rejected alternatives\n\n- doing nothing: the requirement would go unmet.\n\n'
        printf '## Divergence from demand\n\nnone\n\n'
        printf '## Constraints at the time\n\nNone worth recording.\n\n'
        printf '## Program design\n\n- one module, one entry point\n\n'
        printf '## How we know it works\n\n- the fixture suite runs it\n\n'
        printf '## Planned contract changes\n\nnone\n'
    } > "$work/design.md"
}

# write_plan <KEY> <task-count>
write_plan() {
    local key=$1 n=$2 work i
    work=".cue/dev/$key"
    mkdir -p "$work"
    {
        printf '# %s Implementation Plan\n\n' "$key"
        printf '**Goal:** build the fixture.\n\n'
        printf '**Architecture:** one module, built task by task.\n\n'
        printf '## Global Constraints\n\n- none\n\n---\n'
        for ((i = 1; i <= n; i++)); do
            printf '\n### Task %d: step %d\n\n' "$i" "$i"
            printf '**Files:**\n- Create: `src/step%d.txt`\n\n' "$i"
            printf '**Interfaces:**\n- Consumes: none\n- Produces: none\n\n'
            printf -- '- [ ] **Step 1: write it**\n'
        done
    } > "$work/plan.md"
}

# Writes an outcome.md skeleton with N tasks.
write_skeleton() {
    local key=$1 n=$2 i
    {
        echo "# $key — implementation outcome"
        echo
        echo "## Tasks"
        for ((i = 1; i <= n; i++)); do echo "- $i · unrecorded"; done
        echo
        echo "## Summary"
        echo "(write after implementation)"
    } > ".cue/dev/$key/outcome.md"
}

# Creates a new fixture repository and cds into it. new_repo <branch name>
# The path the scripts print for the checkout under $PWD. They all resolve the
# root through git and normalize it with `cd … && pwd`, so a fixture that spells
# it any other way is comparing two names for one directory.
#
# mktemp is where the two names come from. On macOS it hands back
# /var/folders/… while git answers /private/var/…; under Git Bash it hands back
# /tmp/… while git answers C:/Users/…/AppData/Local/Temp/…. Both platforms were
# failing assertions that read like real defects — "prints the path it created"
# against the path it had just created.
repo_root() { (cd "$(git rev-parse --show-toplevel)" && pwd); }

new_repo() {
    local branch=${1:-main} dir
    dir="$TEST_ROOT/repo-$RANDOM"
    git init -q -b "$branch" "$dir"
    cd "$dir" || return 1
    # Stand on the name the scripts use, so $(pwd) and their output are comparable.
    cd "$(repo_root)" || return 1
    # And carry that spelling back to TEST_ROOT, which is the same directory one
    # level up. Fixtures build worktree paths from it and hand them to the scripts
    # as recorded values; in the logical spelling the script normalizes what it
    # finds, compares it against what the fixture wrote, and reports the item's own
    # worktree as somebody else's.
    TEST_ROOT="$(dirname "$PWD")"
    git "${GIT_ID[@]}" commit -q --allow-empty -m "initial commit"
}

finish() {
    echo
    if [ "$FAILURES" -gt 0 ]; then
        echo "FAILED: $FAILURES"
        exit 1
    fi
    echo "STATUS: PASSED"
}
