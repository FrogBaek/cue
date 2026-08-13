#!/usr/bin/env bash
# Checks that the plugin itself is intact. It verifies structure, not the behavior
# of the skill bodies.
#
# A forked plugin carries two risks — something broke during the deletions and
# renames, and something deleted came back. Since the skill files will keep being
# reworked, without this net a broken reference only surfaces in a real session.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

cd "$REPO_ROOT"
PLUGIN=plugins/cue-dev
SCRIPTS=$PLUGIN/skills/using-cue/scripts

echo "=== Test: plugin structure ==="

# --- manifests ---
# Two of them: the plugin manifest and the marketplace listing. They describe the
# same tree, so anything they both name has to say the same thing.
CLAUDE_MANIFEST=$PLUGIN/.claude-plugin/plugin.json

for m in "$CLAUDE_MANIFEST" .claude-plugin/marketplace.json; do
    if jq -e . "$m" >/dev/null 2>&1; then
        pass "$m is valid JSON"
    else
        fail "$m is valid JSON"
    fi
done

n=$(jq -r .name "$CLAUDE_MANIFEST")
if [ "$n" = "cue-dev" ]; then
    pass "the plugin manifest is named cue-dev"
else
    fail "the plugin manifest is named cue-dev" "$CLAUDE_MANIFEST: $n"
fi

pv=$(jq -r .version "$CLAUDE_MANIFEST")
mv=$(jq -r .plugins[0].version .claude-plugin/marketplace.json)
if [ "$pv" = "$mv" ]; then
    pass "the manifest and the marketplace agree on version ($pv)"
else
    fail "the manifest and the marketplace agree on version" \
        "manifest: $pv / marketplace: $mv"
fi

# Every version-carrying file has to be in the bumper's list, or a release ships
# with one of them left behind — and nothing downstream notices which.
if grep -qF "\"$CLAUDE_MANIFEST\"" .version-bump.json; then
    pass "the version bumper knows about the manifest"
else
    fail "the version bumper knows about the manifest" "$CLAUDE_MANIFEST"
fi

# --- the hook registration ---
# One file, discovered by Claude Code. It carries `shell`, which is how
# run-hook.cmd gets a bash to run on Windows. See docs/packaging.md.
CLAUDE_HOOKS=$PLUGIN/hooks/hooks.json
if jq -e . "$CLAUDE_HOOKS" >/dev/null 2>&1; then
    pass "$CLAUDE_HOOKS is valid JSON"
else
    fail "$CLAUDE_HOOKS is valid JSON"
fi

if jq -e '.. | objects | select(has("shell"))' "$CLAUDE_HOOKS" >/dev/null 2>&1; then
    pass "the hook names the shell that runs it on Windows"
else
    fail "the hook names the shell that runs it on Windows" \
        "no 'shell' field — run-hook.cmd has no bash to reach for"
fi

if [ "$(jq -r .plugins[0].name .claude-plugin/marketplace.json)" = "cue-dev" ]; then
    pass "marketplace.json points at cue-dev"
else
    fail "marketplace.json points at cue-dev"
fi

# --- skill frontmatter ---
bad_fm=""
for f in $PLUGIN/skills/*/SKILL.md; do
    dir=$(basename "$(dirname "$f")")
    if [ "$(head -1 "$f")" != "---" ]; then
        bad_fm="$bad_fm\n    $f: frontmatter does not start with ---"
        continue
    fi
    name=$(sed -n '2,10s/^name: *//p' "$f" | head -1)
    desc=$(sed -n '2,10s/^description: *//p' "$f" | head -1)
    [ "$name" = "$dir" ] || bad_fm="$bad_fm\n    $f: name('$name') != directory name('$dir')"
    [ -n "$desc" ] || bad_fm="$bad_fm\n    $f: description is empty"
done
if [ -z "$bad_fm" ]; then
    pass "every skill's frontmatter is valid ($(find "$PLUGIN/skills" -name SKILL.md | wc -l | tr -d ' ') skills)"
else
    fail "every skill's frontmatter is valid" "$(printf '%b' "$bad_fm")"
fi

# --- do the skill-to-skill references exist? ---
# Renaming a skill directory breaks this first. Only the `cue-dev:<name>` form is
# matched, to keep example paths in the prose out of it.
missing_skill=""
for f in $PLUGIN/skills/*/SKILL.md; do
    for ref in $(grep -oE 'cue-dev:[a-z][a-z0-9-]*' "$f" | sort -u); do
        name=${ref#cue-dev:}
        [ -d "$PLUGIN/skills/$name" ] || missing_skill="$missing_skill\n    $f → $ref"
    done
done
if [ -z "$missing_skill" ]; then
    pass "every skill referenced by another skill exists"
else
    fail "every skill referenced by another skill exists" "$(printf '%b' "$missing_skill")"
fi

# --- do the plugin scripts the skills call exist? ---
# The reference form (`<cue>/<script>`) is matched whole. If the regex stops
# tracking a change in that form, references come back as zero and this check
# quietly goes green — which is why the count itself is checked below.
#
# Every `.md` under a skill, not just SKILL.md. The auxiliary files are read by
# the same model in the same turn — implement's procedure file is loaded before
# the first task, the prompt templates go out inside it — and scanning only
# SKILL.md left them outside every check here. That is where the three implement
# scripts sat naming a directory nothing defined.
missing_script=""
script_refs=0
for f in $PLUGIN/skills/*/*.md; do
    for ref in $(grep -oE '<cue>/[A-Za-z0-9._-]+' "$f" | sort -u); do
        p=${ref#<cue>/}
        [ "$p" = "<script>" ] && continue      # the form itself, not a call
        script_refs=$((script_refs + 1))
        [ -e "$SCRIPTS/$p" ] || missing_script="$missing_script\n    $f → $p"
    done
done
if [ -z "$missing_script" ]; then
    pass "every plugin script the skills call exists"
else
    fail "every plugin script the skills call exists" "$(printf '%b' "$missing_script")"
fi

if [ "$script_refs" -gt 0 ]; then
    pass "script references were actually collected ($script_refs of them)"
else
    fail "script references were actually collected" "zero — the regex is not tracking the reference form"
fi

# --- a command is written <cue>/<script>, never a bare scripts/<script> ---
#
# `scripts/verify` with nothing after it is this repository's *name* for the
# script, used throughout the prose ("that is `scripts/verify`'s job"), and it is
# left alone. What is banned is the same string carrying arguments — that is a
# command, and a command is only runnable through the token the hook defines.
#
# The distinction is the whole finding. Three implement scripts were written
# `scripts/task-brief PLAN_FILE N` and lived in a second scripts folder under
# their own skill; no token named that folder, so the first command of every
# dispatch loop was `command not found`. It read as prose and ran as nothing.
# `<cue>` is absolute and substituted once per session; a relative `scripts/…`
# resolves against whatever directory the Bash tool happens to be in.
bare_cmd=$(grep -rnoE '`scripts/[A-Za-z0-9._-]+[ ][^`]+`|^[[:space:]]*scripts/[A-Za-z0-9._-]+[ ]' \
    "$PLUGIN"/skills/*/*.md || true)
if [ -z "$bare_cmd" ]; then
    pass "every script call is written <cue>/<script>"
else
    fail "every script call is written <cue>/<script>" \
        "these name a directory nothing defines:\n$bare_cmd"
fi

# --- every dispatch template carries the language directive and a model ---
#
# A subagent inherits no hooks and no session context, so the repository's record
# language reaches it only if the dispatching prompt carries the line. Three of
# the four templates marked it REQUIRED; the fourth — the whole-branch review, the
# one whose findings a human actually reads — had no slot for it at all, and no
# `model:` line either, which the harness binding says silently inherits the
# session's most expensive model.
#
# The set is found by the dispatch signature rather than by filename, so a fifth
# template cannot join by being called something else.
#
# The directive is matched as a line of its own, which is how it appears *inside*
# the prompt. A bare substring match also hits the `[LANGUAGE_DIRECTIVE]` in the
# Placeholders section below the template — so a file that documents the
# placeholder and never uses it would pass. That is exactly the state this check
# was written to catch, and it did pass it on the first attempt.
bad_prompt=""
prompt_files=0
for f in $(grep -rl 'Subagent (' "$PLUGIN"/skills/*/*.md); do
    prompt_files=$((prompt_files + 1))
    grep -qE '^[[:space:]]*\[LANGUAGE_DIRECTIVE\][[:space:]]*$' "$f" \
        || bad_prompt="$bad_prompt\n    $f: no [LANGUAGE_DIRECTIVE] line inside the prompt"
    grep -qE '^[[:space:]]*model:' "$f" || bad_prompt="$bad_prompt\n    $f: no model: line"
done
if [ "$prompt_files" -eq 0 ]; then
    fail "dispatch templates were collected" "zero — the 'Subagent (' signature is not tracking them"
elif [ -z "$bad_prompt" ]; then
    pass "every dispatch template carries [LANGUAGE_DIRECTIVE] and a model ($prompt_files of them)"
else
    fail "every dispatch template carries [LANGUAGE_DIRECTIVE] and a model" \
        "$(printf '%b' "$bad_prompt")"
fi

# --- CLAUDE_PLUGIN_ROOT is not something a skill may spell ---
# It is set for hook commands, not for the shell the Bash tool runs. Sixty lines
# across ten skills spelled ${CLAUDE_PLUGIN_ROOT%/}/scripts/… and every one of
# them expanded to `/scripts/…` — including the first command of every session,
# which using-cue insisted be run exactly as written. The path is injected by
# hooks/session-start now, which computes it from $0 and therefore knows it.
leaked_root=$(grep -rn 'CLAUDE_PLUGIN_ROOT' "$PLUGIN/skills" || true)
if [ -z "$leaked_root" ]; then
    pass "no skill reaches for CLAUDE_PLUGIN_ROOT"
else
    fail "no skill reaches for CLAUDE_PLUGIN_ROOT" "$leaked_root"
fi

# The token is worth nothing if nothing defines it, and the definition has exactly
# one home.
if grep -q '<cue>/<script>' "$PLUGIN/hooks/session-start"; then
    pass "the hook defines what <cue> means"
else
    fail "the hook defines what <cue> means" "hooks/session-start names no scripts directory"
fi

# --- the scripts skills call have to be runnable ---
#
# Assets are exempt by extension. Anything that is not a script lives beside the
# scripts for the same reason `common` does: every script finds its siblings
# through its own $(dirname "$0"), and a harness that installs the skill installs
# the whole directory. A shebang on a stylesheet would be nonsense; what matters
# is that nothing *executable* is missing one.
bad_exec=""
for s in "$SCRIPTS"/*; do
    [ -f "$s" ] || continue
    case "$s" in *.css|*.js|*.md) continue ;; esac
    head -1 "$s" | grep -q '^#!' || bad_exec="$bad_exec\n    $s: no shebang"
done
if [ -z "$bad_exec" ]; then
    pass "the cue-dev scripts have shebangs"
else
    fail "the cue-dev scripts have shebangs" "$(printf '%b' "$bad_exec")"
fi

# --- the plugin root carries nothing a harness would drop ---
# The installable set is .claude-plugin/, skills/, hooks/ and assets/. A directory
# outside it is a directory nothing reaches: <cue> names one scripts folder, and a
# second one anywhere else is called by a relative path resolved against wherever
# the Bash tool was standing — `command not found`, on the first command of a
# dispatch loop. That is why scripts/ sits under skills/using-cue/, and this is
# what keeps a later convenience directory from silently undoing it.
stray=""
for d in "$PLUGIN"/*/ "$PLUGIN"/.*/; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in
        .|..|.claude-plugin|skills|hooks|assets) ;;
        *) stray="$stray\n    $d" ;;
    esac
done
if [ -z "$stray" ]; then
    pass "the plugin root holds only directories a harness installs"
else
    fail "the plugin root holds only directories a harness installs" \
        "nothing reaches these:$(printf '%b' "$stray")"
fi

# --- has anything deleted come back? ---
# Paths are relative to the repository root (do NOT prefix $PLUGIN — doing so makes
# every path nonexistent and the whole check spin uselessly).
gone="plugins/cue-dev/skills/executing-plans
plugins/cue-dev/skills/design/visual-companion.md
plugins/cue-dev/skills/design/scripts
plugins/cue-dev/skills/implement/scripts
plugins/cue-dev/skills/using-cue/references
plugins/cue-dev/skills/writing-skills
plugins/cue-dev/skills/dispatching-parallel-agents
plugins/cue-dev/skills/design/spec-document-reviewer-prompt.md
plugins/cue-dev/skills/plan/plan-document-reviewer-prompt.md
plugins/cue-dev/skills/implement/model-selection.md
plugins/cue-dev/skills/explain
plugins/cue-dev/skills/using-cue/scripts/explain-facts
plugins/cue-dev/skills/using-cue/scripts/explain-package
plugins/cue-dev/skills/using-cue/scripts/explain-render
plugins/cue-dev/skills/using-cue/scripts/explain-page.css
plugins/cue-dev/skills/using-cue/scripts/explain-page.js
plugins/cue-dev/.codex-plugin
plugins/cue-dev/hooks/hooks.codex.json
tools/package-codex-plugin.sh
tests/brainstorm-server
package.json"
resurrected=""
while IFS= read -r p; do
    [ -e "$p" ] && resurrected="$resurrected\n    $p"
done <<< "$gone"
if [ -z "$resurrected" ]; then
    pass "nothing that was deleted exists"
else
    fail "nothing that was deleted exists" "$(printf '%b' "$resurrected")"
fi

# --- namespace leftovers ---
# LICENSE is the one place the fork's name belongs: MIT requires the notice, and
# that is the whole of the obligation. Everywhere else the name is a leftover, so
# this check is case-insensitive and takes no exception for a comment, a test
# fixture or an environment variable — every one of those has been a leftover
# here at some point.
#
# handoff.md is excluded because it is gitignored and `git grep` would not reach
# it either way. What this check defends is cue-dev's own shipped surfaces.
leftover=$(git grep -Iin 'superpowers' -- . \
    ':!LICENSE' ':!handoff.md' ':!tests/cue-dev/test-plugin-infra.sh' 2>/dev/null || true)
if [ -z "$leftover" ]; then
    pass "zero superpowers namespace leftovers"
else
    fail "zero superpowers namespace leftovers" "$leftover"
fi

# --- telemetry ---
# Only files that execute. A URL in SKILL.md prose is a documentation link, not a
# call.
net=$(git grep -Inw -E '(curl|wget|nc|ncat|telnet)' \
    -- "$PLUGIN" 2>/dev/null || true)
if [ -z "$net" ]; then
    pass "no outbound network calls in executable files"
else
    fail "no outbound network calls in executable files" "$net"
fi

# --- LICENSE ---
if grep -q 'Copyright (c) 2025 Jesse Vincent' LICENSE; then
    pass "LICENSE keeps the original copyright notice"
else
    fail "LICENSE keeps the original copyright notice"
fi

if grep -q 'Copyright (c) 2026 FrogBaek' LICENSE; then
    pass "LICENSE carries the cue-dev copyright notice"
else
    fail "LICENSE carries the cue-dev copyright notice"
fi

# --- the record directory must not be ignored ---
# A trailing-slash rule matches directories only, so ask about a file path inside it
# rather than the (nonexistent) directory itself.
if git check-ignore -q .cue/dev/SOME-KEY/demand.md 2>/dev/null; then
    fail "records under .cue/dev are not ignored" "the records would not be committed"
else
    pass "records under .cue/dev are not ignored"
fi

if git check-ignore -q .cue/dev/sdd/some-plan/progress.md 2>/dev/null; then
    pass "the scratch under .cue/dev/sdd is ignored"
else
    fail "the scratch under .cue/dev/sdd is ignored"
fi

# --- is there a skill that actually commits each of the four markers? ---
# The markers are the only basis for stage detection and rewinding. If a commit step
# drops out while editing a skill, scripts/status never sees that stage again and
# scripts/redo loses its rewind point.
#
# We look for scripts/marker calls, not marker strings. The prefix can differ per
# repository (.cue/dev/config), so skills must not assemble the string — and this is
# what enforces that they do not.
missing_marker=""
for stage in demand design plan outcome; do
    grep -qF "<cue>/marker $stage " $PLUGIN/skills/*/SKILL.md \
        || missing_marker="$missing_marker\n    no skill commits the $stage marker"
done
if [ -z "$missing_marker" ]; then
    pass "all four stage markers are committed by some skill"
else
    fail "all four stage markers are committed by some skill" "$(printf '%b' "$missing_marker")"
fi

# --- does the outcome row format agree between the skeleton and the skill? ---
# The implement controller finds and replaces the placeholder scripts/outcome-init
# writes. Change one side only and the controller cannot find the row to replace,
# and outcome.md comes out empty.
if grep -q "unrecorded" "$SCRIPTS/outcome-init" && grep -q "unrecorded" "$PLUGIN/skills/implement/SKILL.md"; then
    pass "the skeleton and the implement skill share the outcome placeholder"
else
    fail "the skeleton and the implement skill share the outcome placeholder" \
        "'unrecorded' is missing from either scripts/outcome-init or skills/implement/SKILL.md"
fi

# --- no usage() reads its own help by line number ----------------------------
#
# Five scripts printed their Usage block with `sed -n '<a>,<b>p' "$0"`, correct on
# the day each was written and nothing keeping it so. scripts/integration's header
# then grew nine lines, and a real session that ran `integration --actions <KEY>`
# — a fair guess, the sibling subcommand takes a KEY — was answered with a
# paragraph out of the middle of a design note: "Two questions, and the second is
# the reason this is a script rather than a paragraph…". Nothing in it named a form
# the script accepts. scripts/work-branch had slipped one line and was dropping its
# own `Usage:` heading.
#
# A line number into a comment block is a reference nothing checks — which is the
# thing this file exists to check.
numbered=""
for f in "$SCRIPTS"/*; do
    [ -f "$f" ] || continue
    grep -qE "sed -n '[0-9]+,[0-9]+p' \"\\$0\"" "$f"         && numbered="$numbered
    $(basename "$f")"
done
if [ -z "$numbered" ]; then
    pass "no script prints its usage by line number"
else
    fail "no script prints its usage by line number" "$(printf '%b' "$numbered")"
fi

# And what each one prints still starts where it should. A matcher can miss too —
# it just cannot go stale silently.
# Each entry is the shortest invocation that reaches usage() in that script. An
# unknown flag will not do it for the work-* four: they take a KEY positionally
# and read the flag as one, which is its own kind of correct.
badusage=""
while read -r f args; do
    [ -n "$f" ] || continue
    # shellcheck disable=SC2086
    out=$(bash "$SCRIPTS/$f" $args 2>&1 || true)
    case "$out" in
        Usage:*) ;;
        *) badusage="$badusage
    $f: $(printf '%s' "$out" | head -1)" ;;
    esac
done <<'CASES'
integration --landed
work-base
work-branch
work-check
work-path
CASES
if [ -z "$badusage" ]; then
    pass "every usage block still begins at its own heading"
else
    fail "every usage block still begins at its own heading" "$(printf '%b' "$badusage")"
fi

finish
