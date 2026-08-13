#!/usr/bin/env bash
# scripts/backups: lists the backup branches of one work item, and only that one.
#
# The scoping is the point. finish asks whether to delete these, and the branch
# list is shared — every other work item keeps its backups at the same prefix, and
# each of those is that item's only way back from a rewind. A listing that reached
# past the KEY would turn a routine cleanup question into an unrecoverable one.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUPS="$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/backups"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: scripts/backups ==="
TEST_ROOT="$(mktemp -d)"
trap cleanup EXIT

KEY=PROJ-142
OTHER=PROJ-999

new_repo "cue-dev/$KEY"
commit_stage "$KEY" demand demand.md
mkdir -p ".cue/dev/$OTHER"

git branch "cue-dev/backup/$KEY-20260804-101500"
git branch "cue-dev/backup/$KEY-20260804-174619"
git branch "cue-dev/backup/$OTHER-20260804-120000"

out=$(bash "$BACKUPS" "$KEY")

if [[ "$out" == *"cue-dev/backup/$KEY-20260804-101500"* \
   && "$out" == *"cue-dev/backup/$KEY-20260804-174619"* ]]; then
    pass "lists every backup of the given KEY"
else
    fail "lists every backup of the given KEY" "got: $out"
fi

if [[ "$out" != *"$OTHER"* ]]; then
    pass "does not reach into another work item's backups"
else
    fail "does not reach into another work item's backups" "got: $out"
fi

if [[ "$out" =~ delete[[:space:]]+git\ branch\ -D\ .*$KEY-20260804-101500.*$KEY-20260804-174619 ]]; then
    pass "prints one delete command covering the listed branches"
else
    fail "prints one delete command covering the listed branches" "got: $out"
fi

if [[ "$out" != *"branch -D"*"$OTHER"* ]]; then
    pass "the delete command carries no other item's branch"
else
    fail "the delete command carries no other item's branch" "got: $out"
fi

# --- a KEY that is a prefix of another KEY ---
# cue_backup_branch always appends `-<timestamp>`, so the trailing `-` in the glob
# is what keeps PROJ-14 from sweeping up PROJ-142's backups.
#
# No work directory is created for it. One under .cue/dev/ would make the branch
# name `cue-dev/PROJ-142` match two keys by substring, and the KEY could no longer
# be derived from the branch at all — which is the next assertion.
out_prefix=$(bash "$BACKUPS" PROJ-14)
if [ -z "$out_prefix" ]; then
    pass "a KEY that prefixes another KEY matches nothing of its own"
else
    fail "a KEY that prefixes another KEY matches nothing of its own" "got: $out_prefix"
fi

# --- nothing to report ---
out_none=$(bash "$BACKUPS" "$OTHER-unused")
if [ -z "$out_none" ]; then
    pass "prints nothing when there are no backups"
else
    fail "prints nothing when there are no backups" "got: $out_none"
fi

if bash "$BACKUPS" "$OTHER-unused" >/dev/null 2>&1; then
    pass "exits 0 when there are no backups"
else
    fail "exits 0 when there are no backups"
fi

# --- the KEY comes from the branch name when omitted ---
# Compared on the branch names, not the whole output: the `(N seconds ago)` column
# ticks over between the two runs.
out_implicit=$(bash "$BACKUPS" | sed 's/  ([^)]*)$//')
if [ "$out_implicit" = "$(printf '%s\n' "$out" | sed 's/  ([^)]*)$//')" ]; then
    pass "derives the KEY from the branch name when omitted"
else
    fail "derives the KEY from the branch name when omitted" "got: $out_implicit"
fi

# --- it only reports; it never deletes ---
if [ "$(git branch --list 'cue-dev/backup/*' | wc -l)" -eq 3 ]; then
    pass "listing deletes nothing"
else
    fail "listing deletes nothing" "$(git branch --list 'cue-dev/backup/*')"
fi

# --- the configured backup namespace is what gets globbed ---
#
# It is its own setting now. It used to derive from branch_prefix, which is gone:
# the work branch is named per item, and a namespace inherited from a value that
# changes every ticket would scatter the backups it has to find again.
new_repo "spec/$KEY"
commit_stage "$KEY" demand demand.md
printf 'backup_prefix=spec/backup/\n' >> .cue/dev/config
git branch "spec/backup/$KEY-20260804-101500"
git branch "cue-dev/backup/$KEY-20260804-101500"

out_cfg=$(bash "$BACKUPS" "$KEY")
if [[ "$out_cfg" == *"spec/backup/$KEY"* && "$out_cfg" != *"cue-dev/backup/$KEY"* ]]; then
    pass "reads the configured backup prefix"
else
    fail "reads the configured backup prefix" "got: $out_cfg"
fi

# --- an unusable KEY is refused ---
if ! bash "$BACKUPS" "../etc" >/dev/null 2>&1; then
    pass "refuses a KEY that is unsafe on the filesystem"
else
    fail "refuses a KEY that is unsafe on the filesystem"
fi

# --- two backups inside one second ---
#
# The name carries a timestamp resolved to the second, so this used to be a
# collision: `git branch` refused the duplicate and the rewind stopped there. It
# is not a hypothetical — scripts/restore takes a backup of the current state
# before walking back, so a restore following a rewind is two backups in a row,
# and CI's Linux runner is fast enough to do both inside one second. The one
# operation that exists to be recoverable was refusing because its own safety net
# already existed.
new_repo "cue-dev/$KEY"
commit_stage "$KEY" demand demand.md
# shellcheck source=plugins/cue-dev/skills/using-cue/scripts/common
. "$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/common"

# The clock is frozen for this, rather than the two calls being raced against it.
# Written as two calls in a row, the assertion passes on a slow machine for the
# wrong reason — the second ticks between them and no collision ever happens.
# Which is how the defect reached CI in the first place.
mkdir -p "$TEST_ROOT/frozen"
cat > "$TEST_ROOT/frozen/date" <<'STUB'
#!/usr/bin/env bash
printf '20260101-000000\n'
STUB
chmod +x "$TEST_ROOT/frozen/date"

REAL_PATH=$PATH
PATH="$TEST_ROOT/frozen:$PATH"
rc=0
first=$(cue_backup_branch "$KEY") || rc=$?
# Guarded, so a refusal reports as this assertion rather than killing the suite
# under `set -e` two lines before it is read.
second=$(cue_backup_branch "$KEY" 2>/dev/null) || rc=$?
PATH=$REAL_PATH

if [ "$rc" -eq 0 ] && [ -n "$second" ] && [ "$first" != "$second" ]; then
    pass "a second backup in the same second gets its own name"
else
    fail "a second backup in the same second gets its own name" \
        "rc=$rc" "first: $first" "second: $second"
fi

if git show-ref --verify --quiet "refs/heads/$first" \
    && git show-ref --verify --quiet "refs/heads/$second"; then
    pass "both backup branches exist"
else
    fail "both backup branches exist" "$(git branch --list 'cue-dev/backup/*')"
fi

# Still inside the glob scripts/backups and scripts/restore find them by.
listed=$(bash "$BACKUPS" "$KEY")
if [[ "$listed" == *"$first"* && "$listed" == *"$second"* ]]; then
    pass "the listing finds both"
else
    fail "the listing finds both" "got: $listed"
fi

finish
