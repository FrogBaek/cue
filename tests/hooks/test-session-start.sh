#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_UNDER_TEST="$REPO_ROOT/plugins/cue-dev/hooks/session-start"
WRAPPER_UNDER_TEST="$REPO_ROOT/plugins/cue-dev/hooks/run-hook.cmd"

FAILURES=0
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

make_home() {
    local name="$1"
    local home="$TEST_ROOT/$name/home"
    mkdir -p "$home"
    printf '%s\n' "$home"
}

assert_command_output() {
    local description="$1"
    local shape="$2"
    local contains="$3"
    local not_contains="$4"
    local home="$5"
    shift 5

    local output
    if ! output="$(env -i PATH="${PATH:-}" HOME="$home" "$@" 2>&1)"; then
        fail "$description"
        echo "    hook exited non-zero"
        echo "$output" | sed 's/^/      /'
        return
    fi

    if printf '%s' "$output" | \
        EXPECT_SHAPE="$shape" \
        EXPECT_CONTAINS="$contains" \
        EXPECT_NOT_CONTAINS="$not_contains" \
        node -e '
const fs = require("fs");

const input = fs.readFileSync(0, "utf8");
let payload;
try {
  payload = JSON.parse(input);
} catch (error) {
  console.error(`invalid JSON: ${error.message}`);
  process.exit(1);
}

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

const shape = process.env.EXPECT_SHAPE;
let context;

if (shape === "nested") {
  if (!hasOwn(payload, "hookSpecificOutput")) {
    fail("missing hookSpecificOutput");
  }
  if (hasOwn(payload, "additional_context") || hasOwn(payload, "additionalContext")) {
    fail("nested output also included a top-level context field");
  }
  const hookOutput = payload.hookSpecificOutput;
  if (!hookOutput || typeof hookOutput !== "object" || Array.isArray(hookOutput)) {
    fail("hookSpecificOutput is not an object");
  }
  if (hookOutput.hookEventName !== "SessionStart") {
    fail(`unexpected hookEventName: ${hookOutput.hookEventName}`);
  }
  context = hookOutput.additionalContext;
} else if (shape === "cursor") {
  if (hasOwn(payload, "hookSpecificOutput")) {
    fail("cursor output included hookSpecificOutput");
  }
  if (!hasOwn(payload, "additional_context")) {
    fail("cursor output missing additional_context");
  }
  if (hasOwn(payload, "additionalContext")) {
    fail("cursor output included additionalContext");
  }
  context = payload.additional_context;
} else if (shape === "sdk") {
  if (hasOwn(payload, "hookSpecificOutput")) {
    fail("sdk output included hookSpecificOutput");
  }
  if (!hasOwn(payload, "additionalContext")) {
    fail("sdk output missing additionalContext");
  }
  if (hasOwn(payload, "additional_context")) {
    fail("sdk output included additional_context");
  }
  context = payload.additionalContext;
} else {
  fail(`unknown expected shape: ${shape}`);
}

if (typeof context !== "string" || context.trim() === "") {
  fail("injected context was empty");
}

// Split on the same separator the forbidden list uses. A caller with one string
// gets a one-element list, so this is only ever additive — and a directive worth
// asserting usually has more than one part that must survive (the token, and the
// value it is given).
const expectedTexts = (process.env.EXPECT_CONTAINS || "")
  .split("")
  .filter(Boolean);
for (const expectedText of expectedTexts) {
  if (!context.includes(expectedText)) {
    fail(`context did not contain expected text: ${expectedText}`);
  }
}

const forbiddenTexts = (process.env.EXPECT_NOT_CONTAINS || "")
  .split("\u001f")
  .filter(Boolean);
for (const forbiddenText of forbiddenTexts) {
  if (context.includes(forbiddenText)) {
    fail(`context contained forbidden text: ${forbiddenText}`);
  }
}
'; then
        pass "$description"
    else
        fail "$description"
        echo "    output:"
        echo "$output" | sed 's/^/      /'
    fi
}

echo "SessionStart hook output tests"

# Registration shape: the hook must declare shell:"bash" so Claude Code on
# Windows dispatches via Git Bash (or fails with an actionable error) instead
# of PowerShell/cmd.exe, whose parsers break on the quoted command string
# (PowerShell ParserError; cmd.exe quote-stripping on paths with metacharacters).
if node -e '
const hooks = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const entry = hooks.hooks.SessionStart[0].hooks[0];
if (entry.shell !== "bash") {
  console.error(`SessionStart hook shell is ${JSON.stringify(entry.shell)}, expected "bash"`);
  process.exit(1);
}
if (!/run-hook\.cmd" session-start$/.test(entry.command)) {
  console.error(`unexpected SessionStart command shape: ${entry.command}`);
  process.exit(1);
}
' "$REPO_ROOT/plugins/cue-dev/hooks/hooks.json"; then
    pass "hooks.json registers SessionStart with shell:bash dispatch"
else
    fail "hooks.json registers SessionStart with shell:bash dispatch"
fi

claude_home="$(make_home claude-code)"
assert_command_output \
    "Claude Code emits nested SessionStart additionalContext" \
    "nested" \
    "" \
    "" \
    "$claude_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    bash "$HOOK_UNDER_TEST"

wrapper_home="$(make_home run-hook-wrapper)"
assert_command_output \
    "run-hook.cmd wrapper dispatches to the named session-start script" \
    "nested" \
    "" \
    "" \
    "$wrapper_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    bash "$WRAPPER_UNDER_TEST" session-start

# Every case above runs the dispatcher as `bash <path>`, which works whatever the
# file mode is. Claude Code does not: the registered command is the quoted path
# itself, so on macOS and Linux the file has to carry the exec bit or the hook
# dies with "Permission denied" and the session simply starts without cue-dev.
# The mode has to be read out of the index, because on Windows the working tree
# never has it to begin with.
wrapper_mode=$(git -C "$REPO_ROOT" ls-files -s plugins/cue-dev/hooks/run-hook.cmd | cut -d' ' -f1)
if [ "$wrapper_mode" = "100755" ]; then
    pass "run-hook.cmd is executable in the index"
else
    fail "run-hook.cmd is executable in the index" "mode is $wrapper_mode"
fi

cursor_home="$(make_home cursor)"
assert_command_output \
    "Cursor emits top-level additional_context only" \
    "cursor" \
    "" \
    "" \
    "$cursor_home" \
    CURSOR_PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    bash "$HOOK_UNDER_TEST"

copilot_home="$(make_home copilot-cli)"
assert_command_output \
    "Copilot CLI emits top-level additionalContext only" \
    "sdk" \
    "" \
    "" \
    "$copilot_home" \
    COPILOT_CLI=1 \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    bash "$HOOK_UNDER_TEST"

legacy_home="$(make_home legacy-warning-removed)"
mkdir -p "$legacy_home/.config/cue/skills"
assert_command_output \
    "SessionStart omits obsolete legacy custom-skill warning" \
    "nested" \
    "" \
    "cue-dev now uses"$'\037'"~/.config/cue/skills"$'\037'"~/.claude/skills"$'\037'"legacy" \
    "$legacy_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    bash "$HOOK_UNDER_TEST"

# --- scripts directive ---
#
# The skills write every command as `<cue>/<script>` and nothing else defines what
# `<cue>` is. Before this line existed they spelled ${CLAUDE_PLUGIN_ROOT%/}/scripts/…
# instead, which is set for hook commands and not for the shell the Bash tool runs:
# the first command of every session expanded to `/scripts/status` and died.
#
# So the path must be absolute and it must be the real one. A directive that named
# a relative path, or named nothing, would put the session back where it started.
scripts_home="$(make_home scripts-directive)"
assert_command_output \
    "SessionStart names the scripts directory <cue> stands for" \
    "nested" \
    "cue-dev's scripts are at"$'\037'"$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts"$'\037'"<cue>/<script>" \
    "" \
    "$scripts_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    bash "$HOOK_UNDER_TEST"

# --- language directive ---
#
# This hook is the only place a main session learns the repo's language
# setting. If the directive drops out here, `language` in .cue/dev/config
# reaches nothing.
#
# It is injected unconditionally, including for the default. Silence is not
# neutral: every skill body and template in this plugin is English, so a session
# told nothing writes English no matter what language the user is typing in. That
# is what the `auto` value did, and it is why there is no longer one.
lang_repo="$TEST_ROOT/lang-repo"
git init -q "$lang_repo"
git -C "$lang_repo" -c user.email=t@example.com -c user.name=t \
    commit -q --allow-empty -m "init"

lang_home="$(make_home language-default)"
assert_command_output \
    "SessionStart injects the default language directive with no config" \
    "nested" \
    'Output language: `en` (from .cue/dev/config).' \
    "" \
    "$lang_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    CLAUDE_PROJECT_DIR="$lang_repo" \
    bash "$HOOK_UNDER_TEST"

mkdir -p "$lang_repo/.cue/dev"
printf 'language=auto\n' > "$lang_repo/.cue/dev/config"

# A config file left over from before `auto` was removed. The value is no longer
# valid, and the hook must not pass it through as a language code — it resolves to
# the default rather than telling Claude to write in a language called "auto".
lang_home="$(make_home language-legacy-auto)"
assert_command_output \
    "SessionStart resolves a leftover language=auto to the default" \
    "nested" \
    'Output language: `en` (from .cue/dev/config).' \
    "" \
    "$lang_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    CLAUDE_PROJECT_DIR="$lang_repo" \
    bash "$HOOK_UNDER_TEST"

printf 'language=fr\n' > "$lang_repo/.cue/dev/config"

lang_home="$(make_home language-set)"
assert_command_output \
    "SessionStart injects the configured language directive" \
    "nested" \
    'Output language: `fr` (from .cue/dev/config).' \
    "" \
    "$lang_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    CLAUDE_PROJECT_DIR="$lang_repo" \
    bash "$HOOK_UNDER_TEST"

# The directive tells Claude to relay the scripts' meaning rather than paste their
# output — and that instruction, applied to the notice block, is what turned a
# /cue-dev:status run into a two-sentence summary while the block itself stayed
# folded away in a tool result. The carve-out has to travel with the rule.
lang_home="$(make_home language-notice-exception)"
assert_command_output \
    "SessionStart carves the notice block out of the relay rule" \
    "nested" \
    'The notice block is the exception — reproduce it verbatim' \
    "" \
    "$lang_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    CLAUDE_PROJECT_DIR="$lang_repo" \
    bash "$HOOK_UNDER_TEST"

# The carve-out used to end with "and then add what it means", and against a block
# whose every line is already label-and-value, "what it means" had nothing left to
# be except a translation of the labels. A real session printed six such lines
# under every box in the cycle. The rule now caps the addition and says when it is
# worth making at all.
lang_home="$(make_home language-no-restatement)"
assert_command_output \
    "SessionStart forbids restating the block's labels in prose" \
    "nested" \
    'Do not then walk its labels in prose' \
    "" \
    "$lang_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    CLAUDE_PROJECT_DIR="$lang_repo" \
    bash "$HOOK_UNDER_TEST"

# Restating the labels was only half of it. What went above the box was a list of
# achievements, and two entries in one real session were false: "branch and
# workspace cleaned up" over a workspace still on disk, and "14 clean commits"
# over a number nobody had counted. That slot is the one place in the reply where
# a sentence enters that no script produced and no gate checked.
lang_home="$(make_home language-no-summary)"
assert_command_output     "SessionStart forbids an achievement summary above the block"     "nested"     'no achievement summary above it either'     ""     "$lang_home"     CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev"     CLAUDE_PROJECT_DIR="$lang_repo"     bash "$HOOK_UNDER_TEST"

# The frame means "a cue-dev stage produced this". scripts/notice enforces that on
# the titles it is given; nothing enforces it on a box Claude draws by hand, which
# is how a merge performed outside /cue-dev:finish came to be reported inside
# `━━━ MERGED · <KEY> ━━━`. The prohibition has to travel with the session.
lang_home="$(make_home language-no-forgery)"
assert_command_output \
    "SessionStart forbids drawing the notice block by hand" \
    "nested" \
    'never draw the box yourself' \
    "" \
    "$lang_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    CLAUDE_PROJECT_DIR="$lang_repo" \
    bash "$HOOK_UNDER_TEST"

# The hook's cwd is not guaranteed to be the project root. CLAUDE_PROJECT_DIR
# is the answer, and without it the hook must still emit a directive rather than
# fail — a hook that fails takes the whole session start with it. Which language
# it lands on depends on the cwd it fell back to, so that is not asserted here.
lang_home="$(make_home language-no-project-dir)"
assert_command_output \
    "SessionStart still emits a language directive when the project dir is unknown" \
    "nested" \
    "Output language:" \
    "" \
    "$lang_home" \
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/cue-dev" \
    bash "$HOOK_UNDER_TEST"

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
