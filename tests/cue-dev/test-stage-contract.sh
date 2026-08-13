#!/usr/bin/env bash
# The contract every stage skill has to keep (the parts of plan §10.5 that are
# decided by documents).
#
# The cycle test looks at how the scripts are wired. But several §10.5 items live
# only in the skill documents, not in scripts — does it stop when a prerequisite
# artifact is missing, does each stage point at the next one when it ends, does it
# refrain from running the next stage on its own?
#
# Verifying those by execution would require calling an LLM (that is §10.6's job),
# and then pass/fail wobbles. What can be checked deterministically instead is
# whether the instruction is still in the document. An instruction disappearing and
# an instruction not being followed are different problems; this catches the first.
# This repository really has renamed and rearranged its skills several times, and
# what most easily drops out silently each time is exactly this kind of one-line
# instruction.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS="$REPO_ROOT/plugins/cue-dev/skills"

# shellcheck source=tests/cue-dev/helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "=== Test: stage skill contract ==="

has() {  # has <skill> <pattern> <description>
    if grep -qE "$2" "$SKILLS/$1/SKILL.md"; then
        pass "$1: $3"
    else
        fail "$1: $3" "pattern not found: $2"
    fi
}

lacks() {  # lacks <skill> <pattern> <description>
    if grep -qE "$2" "$SKILLS/$1/SKILL.md"; then
        fail "$1: $3" "pattern must not be present: $2"
    else
        pass "$1: $3"
    fi
}

# --- Completion notice -----------------------------------------------------
# Each stage ends by giving both the next stage and how to rewind. With only the
# next one, the user can go forward but not back — and rewinding is what nobody
# remembers when they need it.
while read -r skill next undo; do
    has "$skill" "^ *next +/cue-dev:$next\$" "the notice points to $next as the next stage"
    has "$skill" "rewind +/cue-dev:redo $undo" "the notice offers redo $undo as the rewind"
done <<'MAP'
start     design    demand
design    plan      design
plan      implement plan
implement finish    implement
MAP

# finish is the last stage, so the only stage its notice may point at is itself.
#
# It used to point at nothing, and that was right while finish ran once. It is
# repeatable — it stamps no marker, so gate lets it run again — and the request
# path needs the repeat: the work is proposed today and lands next week, and
# something has to come back for the branch and the worktree. Naming any *other*
# stage here would be the old error, an arrow at a stage that does not follow.
stray_next=$(grep -E "^ *next +/cue-dev:" "$SKILLS/finish/SKILL.md" \
    | grep -vE "/cue-dev:finish" || true)
if [ -z "$stray_next" ]; then
    pass "finish: the only stage its notice points at is finish itself"
else
    fail "finish: the only stage its notice points at is finish itself" "$stray_next"
fi

has finish "^ *next +/cue-dev:finish" "its notice names the repeat that reclaims the workspace"

# --- The notice is drawn by the script, never typed out ---------------------
# The templates in these skills were 47 columns top and bottom, and stayed that
# way only until `<KEY>` was replaced with a real key. A 33-character KEY pushed
# the opening line 28 columns past a closing rule that is literal text — which is
# what users kept seeing. scripts/notice derives the closing rule from the title,
# so the width cannot drift; what remains is that the skill actually calls it.
for s in start design plan implement finish init; do
    has "$s" '<cue>/notice "' "it renders the notice with scripts/notice"
    has "$s" 'verbatim in your reply' "it requires the notice output to be reproduced verbatim"
done

# --- Records are written in the configured language -------------------------
# Every template and heading in this plugin is English, so a skill that says
# nothing about language produces an English record in a repository that asked
# for Korean. implement carried the directive to its subagents from the start;
# design and plan did not, and their outputs came out English while outcome.md —
# written through implement — came out Korean, in the same repository.
for s in design plan implement; do
    has "$s" 'config --get language' "it reads the record language from the settings"
done

# --- No automatic handoff --------------------------------------------------
# cue-dev is designed for a human to step in between stages. If a skill calls the
# next skill on its own, that opening disappears and the user loses the chance to
# check.
for s in start design plan implement; do
    has "$s" "[Dd]o not call .* automatically" "it forbids calling the next skill automatically"
done

# --- Prerequisite gate -----------------------------------------------------
# Every stage rests on the one before it, and the ordering lives in scripts/gate
# rather than in each skill's prose. It was prose once, and each skill discovered
# a violation separately, in the middle of doing something: /cue-dev:status in a
# repository where nothing had started printed `no KEY found ... Pass one:` and
# exited 2 — accurate, useless, and the controller went on to guess.
#
# redo is in this list because going back is as linear as going forward. It was
# not, and the asymmetry was invisible: forward, a stage that could not run named
# the one that could; backward, asking to rewind to a stage that had never run
# printed one line and exited, leaving the controller to improvise — the exact
# behaviour gate was built to end.
for s in design plan implement finish redo; do
    has "$s" '<cue>/gate '"$s" "it asks gate whether this stage may run"
    has "$s" 'exit 1' "it stops on gate's refusal"
    has "$s" '`now` lines' "it relays gate's way out rather than diagnosing"
done

# Every command is written `<cue>/<script>`, and the one place `<cue>` is given a
# value is hooks/session-start. A controller that assembled a Windows path of its
# own instead produced `d:cuepluginscue-devscriptsgate: command not found`,
# because the backslashes are escapes — so each gate says where the path comes
# from, at the point of use.
for s in design plan implement finish; do
    has "$s" 'scripts directory named in your session context' \
        "it says where the script path comes from"
done

# start's gate is not a previous stage but the repository's readiness. init-check
# makes that determination.
has start '<cue>/init-check' "it determines repository readiness before starting"
has start "/cue-dev:init" "it points at init when the repository is not ready"

# --- Markers are never assembled by hand -----------------------------------
# The prefix can differ per repository. A skill piecing the string together drifts
# in any repository that changed the setting, and a drifted marker fails silently —
# the commit succeeds and only that stage becomes invisible.
for s in start design plan implement; do
    has "$s" '<cue>/marker (demand|design|plan|outcome)' "it builds the marker with scripts/marker"
    lacks "$s" 'git commit -m "cue-dev\(' "it never writes the marker string literally"
done

# --- the outcome marker is implement's, and only implement's ----------------
# It used to be stamped by finish, which put it one stage past the record it
# names: implement committed the rows itself, so finish's `git add` had nothing to
# stage, the commit died on `nothing added to commit`, and the marker was never
# written at all. A whole item merged with no outcome marker, and gate went on
# letting implement run over finished work.
has implement '<cue>/marker outcome' "implement stamps the outcome marker"
has implement 'allow-empty' \
    "the stamp cannot fail on having nothing to stage"
lacks finish '<cue>/marker outcome' "finish no longer stamps the outcome marker"

# --- init asks; it does not settle ------------------------------------------
# The conventions init writes go into the git history and the branch list, which
# belong to the whole team. In a real session all three of the marker prefix, the
# branch prefix and the base branch were announced rather than asked — two of them
# because one message had carried two questions and come back with one answer.
has init 'One question per message' "it asks one question per message"
has init 'never a decision you may take on their behalf' \
    "it forbids applying a default without an answer"

# Two of those three are no longer init's to ask at all. Both belong to the work
# item — a git-flow hotfix comes off `main` and is called `hotfix/…` while the
# feature before it came off `develop` — so a repository-wide answer could not
# describe the second item without being rewritten under the first.
lacks init 'branch_prefix' "it no longer asks for a work branch prefix"
lacks init 'base_branch' "it no longer asks for a start point"

# --- the three irreversible questions end the turn --------------------------
# start's KEY, start point and branch name were all asked in prose, on the
# reasoning that one proposal plus one typed value makes a menu whose single entry
# duplicates the interface's own "Other". The logic held; the premise did not.
# A prose question does not end the turn — so the same turn carried on, needed an
# answer to carry on with, and supplied one: a real session wrote "User says yes,
# so I'll proceed with creating the worktree:" and cut the branch, having been
# told nothing.
#
# Each of the three names something that outlives the answer (a directory, the
# commit markers, a branch, the branch this merges back into), which is what
# separates them from init's marker prefix — a value one command can change
# tomorrow, and prose there is still right.
n=$(grep -c 'AskUserQuestion' "$SKILLS/start/SKILL.md" || true)
if [ "$n" -ge 3 ]; then
    pass "start: all three irreversible questions are asked with the tool ($n)"
else
    fail "start: all three irreversible questions are asked with the tool" "found $n, want 3"
fi
lacks start 'Ask in prose' "start no longer asks an irreversible question in prose"
has start 'does not end the turn' "it says why the tool is what matters, not the menu"

# The converse, so the rule stays a rule rather than a sweep. init keeps prose for
# the one value that is cheap to change again.
has init 'Do not use `AskUserQuestion` here' "init keeps prose where the value is reversible"
has init 'reversibility' "init names the rule that separates the two"

# --- the work branch is named per item and recorded -------------------------
# Until this line existed, the KEY was recovered by matching the branch name
# against the directories under .cue/dev/ — which made "the KEY must be in the
# branch name" a contract nobody had agreed to, and surfaced as a warning at the
# end of start, after the name had been chosen.
has start '<cue>/work-branch --line' "it records the branch the work was cut onto"
has start 'requires nothing of this name' "it states that the branch name is free"
lacks start 'config --get branch_prefix' "it does not read a branch prefix setting"

# The name is taken from git after the workspace exists, not from what was asked
# for. Native worktree tooling renames: `cue-dev/I18N` came back as
# `worktree-cue-dev+I18N`.
has start 'after.*the workspace exists|asks git what is checked out' \
    "it records the name git reports rather than the one requested"

# --- worktrees are cue-dev's, start to finish -------------------------------
# The harness tool takes a name or a path and nothing else, so the branch is cut
# from whatever worktree.baseRef says — an item that recorded "cut this from
# develop" gets origin/main, silently. And its own contract says a worktree
# entered by path is one it will keep rather than remove, so cleanup never left
# cue-dev either. What was left to gain was the session's working directory, and
# that is not worth eight harness-coupled call sites in a plugin whose work items
# outlive sessions.
has start 'git worktree add <the proposed path> -b' \
    "it cuts the branch itself, with the start point"
has using-git-worktrees 'never a start point' \
    "the worktree skill says the tool cannot carry a start point"
lacks using-git-worktrees 'EnterWorktree path=' \
    "it no longer hands the worktree to the harness tool"
# Naming the tool is allowed and wanted — both skills say plainly why it is not
# used, at the point where reaching for it is tempting. What must not appear is
# the call.
lacks start 'EnterWorktree path=' "start does not reach for the harness tool either"

# --- the path is proposed by a script, never chosen -------------------------
# A real session invented `.cue/worktrees/<KEY>`, a location named nowhere in this
# plugin, and every rule about who owned it was written against paths it did not
# match. The defence is not a firmer instruction; it is having nothing to invent.
has start '<cue>/work-path --propose' "start asks for the path rather than picking one"
has using-git-worktrees 'work-path --propose' "the worktree skill sends you to the same script"

# --- the session does not move, so every command names the path -------------
has start 'git -C' "start works in the worktree by path"
has using-git-worktrees 'git -C' "the worktree skill works by path"

# --- Merge Locally is the one repository-scope path -------------------------
# Everything else in cue-dev happens on this item's branch in its own worktree.
# Here finish leaves the worktree, takes over the main checkout and runs the tests
# there, so two sessions reaching it at once interleave — and git's own refusal
# lands three commands in, after the worktree has been left.
has finish '<cue>/branch-holder' "it checks the landing branch is free before merging"

# --- status is relayed, not summarized -------------------------------------
# The script's output lands in a tool result, which the interface collapses after
# a few lines. A user who ran /cue-dev:status and got a two-sentence summary back
# never saw the track, the task counts, or the isolation warning.
has status 'verbatim' "it requires the block to be relayed verbatim"
has status 'fenced code block' "it says where to put the block so it is not collapsed"

# --- finish cleans up what this work created, and nothing else --------------
# A worktree left behind is a second checkout someone edits by mistake, and a
# backup branch left behind is permanent: nothing else ever deletes them.
has finish '<cue>/backups' "it offers to clean up this item's backup branches"
has finish 'Only this KEY' "it scopes the backup cleanup to this work item"

# The observing and the reporting are one script now. Kept as prose, the report
# was written from intent: a real session printed `worktree preserved` on the path
# where the user had chosen to clean it up, having removed nothing, and no run in
# cue-dev's history had ever deleted the scratch directory.
has finish '<cue>/finish-cleanup' "it hands the workspace teardown to one script"
has finish 'finish-cleanup --verify' "it re-checks rather than trusting the removal"
lacks finish 'ExitWorktree' "it no longer calls a harness exit tool on cue-dev's behalf"
has finish '<cue>/finish-cleanup <KEY>' "teardown is addressed by KEY, so the record names the path"
has finish 'exit 1 the workspace is still there' "it refuses to report a cleanup that failed"

# --- every skill says which language to speak -------------------------------
#
# The 12th session's finding was structural, not a lapse: the hook speaks once at
# the top of the session and then a several-hundred-line English skill is loaded on
# top of it. The ten stage skills got a header for that reason. The six others did
# not — including two that dispatch subagents and one that asks the user for
# consent — so the longest English documents in the plugin were the ones with
# nothing in them about the output language.
#
# `using-cue` is the exception and stays one: it is what the hook injects, and the
# hook appends the language directive to it. A header there would be the directive
# arguing with itself.
missing_lang=""
for f in "$SKILLS"/*/SKILL.md; do
    name=$(basename "$(dirname "$f")")
    [ "$name" = using-cue ] && continue
    grep -q "Speak the repository's language" "$f" || missing_lang="$missing_lang\n    $name"
done
if [ -z "$missing_lang" ]; then
    pass "every skill but using-cue states the output language"
else
    fail "every skill but using-cue states the output language" "$(printf '%b' "$missing_lang")"
fi

# --- a step number names one step ------------------------------------------
#
# start had two `#### 4b`s — one for the fetch, one for naming the branch — and a
# `#### 4c` repeating the first one's title. Every reference in the step ("the
# branch is cut in 4c", "4a, 4b and 4d each end in an AskUserQuestion") then named
# something that was not unique, in the step 13th and 15th both had to repair. It
# also had `4d` at `###`, which makes a substep a sibling of step 5.
#
# Code fences are skipped, the same rule verify and task-graph parse tasks by: a
# shell comment reading `# 1. Preview` is not a heading, and init has three.
dup_steps=""
for f in "$SKILLS"/*/SKILL.md; do
    # `|| true` is load-bearing twice over, under `set -euo pipefail`. Half the
    # skills carry no numbered heading at all, so grep exits 1, pipefail hands that
    # to the substitution, and the suite dies — silently, at whichever assertion
    # came next, which is how this looked when it happened.
    d=$(awk '/^```/ { inf = !inf; next } !inf' "$f" \
        | grep -oE '^#+[[:space:]]+(Step[[:space:]]+)?[0-9]+[a-z]?[.:]' \
        | sed -E 's/^#+[[:space:]]+(Step[[:space:]]+)?//' | sort | uniq -d || true)
    # `if`, not `[ -n "$d" ] && …` — the test-and-assign is the loop body's last
    # command, so on the clean case it returns 1, the loop returns 1, and `set -e`
    # kills the suite the same way.
    if [ -n "$d" ]; then
        dup_steps="$dup_steps\n    ${f#"$SKILLS"/}: $(printf '%s' "$d" | tr '\n' ' ')"
    fi
done
if [ -z "$dup_steps" ]; then
    pass "no skill numbers two steps the same"
else
    fail "no skill numbers two steps the same" "$(printf '%b' "$dup_steps")"
fi

# --- the worktree is cut with git and worked in by path ---------------------
# 9th retired the EnterWorktree lease and start's 4c says so. Its rationalization
# table did not get the message — it still ended "Create with `git worktree add`,
# then enter with the tool", which is the sentence a model looks up when it wants
# permission, and it contradicted both the body above it and the sub-skill start
# hands the job to.
lacks start 'enter with the tool' "its rationalizations do not re-authorise the harness worktree tool"

# --- the box is last, and nothing goes under it -----------------------------
#
# Open from the 9th session to the 16th, because the plugin said two things. The
# skills said "add nothing under it"; the hook and docs/output-format.md said "at
# most one sentence, when it carries something the box does not"; and one stage
# said "add one line under it" outright. Each half had a failure to its name — a bare
# box a user read as caprice, and six restated lines under every box in a cycle.
#
# The rule is positional now, which is why it can be checked at all: where a
# sentence goes does not depend on what it says. Every skill that prints a box
# states it in the same words, so a seventh saying something else is a diff.
#
# The retired phrasing is matched as `nothing under it` and not as `add nothing
# under it`: it wrapped across a line break in every file that carried it ("…and
# add\nnothing under it."), and these greps are line-based, so the longer pattern
# never matched anything and the check passed on files that still had it. The new
# wording says "Nothing goes under it", which the shorter pattern does not hit.
for _s in start design plan implement init finish; do
    has "$_s" 'put it\s*$|put it last' "the box is the last thing in the reply"
    lacks "$_s" 'nothing under it' "it does not carry the retired phrasing"
done

# And the hook, which is the copy every session actually starts from.
if grep -q 'the last thing in your reply' "$REPO_ROOT/plugins/cue-dev/hooks/session-start"; then
    pass "the session hook states the same rule"
else
    fail "the session hook states the same rule" "hooks/session-start still authorises prose under the box"
fi

# --- the box is not the skill's to draw ------------------------------------
# A merge done after finish was reported inside a hand-rendered
# `━━━ MERGED · <KEY> ━━━` — a stage that does not exist, in the frame that means
# a script produced it.
has finish 'Do not draw a box' "it forbids inventing a notice for work after finish"
has finish "finish's .merge. path" "it sends a post-finish merge request back through finish"

# --- the integration act is the adapter's, not this skill's -----------------
# The menu used to be four options written out here, in the shape of GitHub — and
# the skill said in the same breath that two independent questions decided it.
# Adding merge requests made it six, Gerrit eight. What replaced it is a script
# that says what this repository can do, so the check is both halves: the skill
# asks, and the old shape is gone.
has finish '<cue>/integration' "it asks the repository which actions exist"
has finish 'not among .--actions.' "it offers the adapter's actions rather than its own list"
lacks finish 'present exactly these 4 options' "the four-option GitHub menu is gone"
lacks finish 'Keep both the branch and the worktree' "keep-both is not a path of its own"

# Which of the script's two answers finish reads, which is not the same question
# as whether it asks at all. The display prints a `request` line under every
# adapter — under `none` to say the action is unavailable — so a step branching on
# "did it print request" is true in the one repository where the action does not
# exist. Both steps that branch on it name --actions now.
has finish 'integration --actions' "it reads the action tokens, not the display"
lacks finish 'integration. printed .request.' "it does not branch on the display text"

# --- integration is asked after the item is finished ------------------------
# start opens a branch and a worktree; finish closes both, and that completes
# without anything being pushed or merged. Putting the pull request first made
# finishing conditional on answering an outward-facing question — a developer who
# wanted the PR immediately was served and nobody else was. The two integration
# acts are now one question after the notice, and `not now` ends the skill.
has finish 'Integration is a separate question, asked after the notice'     "integration comes after the item is finished"
has finish 'not now. is a complete answer' "declining integration is an ending, not a deferral"
has finish 'REQUEST done' "a request opened here reports in its own box"
has finish 'The branch is kept. That is not a question'     "Step 5 does not offer to delete the branch"

# --- every question is asked about the item, not about the shell ------------
# One run was lost to this: the implementation was committed in the main checkout,
# so the branch held six record commits and no code, and finish passed anyway —
# the suite ran in the main checkout (which did have the change) and the ancestor
# check asked whether the base branch was still on itself. The item's facts come
# from the item's record.
has finish 'Which tree every command in this skill runs against'     "it names the tree each command runs against, in one place"
has finish '<cue>/work-branch <KEY>' "the ancestor check reads the recorded branch"
lacks finish 'is-ancestor <that ref> HEAD' "the ancestor check no longer asks where the shell is"

# The landed question is the adapter's too, and for a sharper reason: a squash
# merge leaves no ancestry, so a controller computing it from git alone reports
# "not landed" for the most common way work lands.
has finish 'integration --landed' "it asks whether the work already landed"
has finish 'squash' "it says why git alone cannot answer that"
has finish 'Step 5r' "it has a path for work that has already landed"

# --- the option a skill would pick is first, and unlabelled -----------------
# AskUserQuestion's own instructions say to append "(Recommended)" to the label,
# and a session did — on the start point and the branch name, the two answers this
# plugin explicitly has no opinion about. A badge there reads as cue-dev requiring
# a team's branch convention, which is the exact coupling 4a and 4b exist to avoid.
has start 'Position is the recommendation' "the option order carries the recommendation"
has start 'do not mark it as recommended' "it forbids labelling an option recommended"
has start 'as a fact about this repository' "the reason goes in the description instead"

# The rule was asserted against start alone, so it was start's rule alone — and
# two badges survived elsewhere. init put one on "commit the records", a question
# cue-dev does have a view on, which is the reading the rule now closes off
# explicitly; finish put one on 5r while telling itself twice on the same page to
# recommend nothing.
#
# Matched as the label form (`**Option** (recommended)`) rather than the word, so
# that start's own paragraphs about the badge — which quote it — do not trip it.
badges=$(grep -rnoE '\*\*[^*]+\*\*[[:space:]]*\((R|r)ecommended\)' "$SKILLS" || true)
if [ -z "$badges" ]; then
    pass "no skill labels a menu option '(recommended)'"
else
    fail "no skill labels a menu option '(recommended)'" "$badges"
fi

# And both skills that lost a badge say so where the question is asked, pointing
# at the one full statement rather than carrying a third and fourth copy of it.
#
# Asserted on the pointer phrase, not on the word "recommended" and not on
# "cue-dev:start" — init names that skill a dozen times for other reasons, so a
# match on it would survive the pointer being deleted.
has init 'No option carries a "\(recommended\)" badge' "init says no option carries the badge"
has init 'head of step 4' "init points at the one place the reasoning lives"
has finish 'No option carries a "\(recommended\)"' "finish 5r says no option carries the badge"
has finish 'head of step 4' "finish points at the same place"

# --- the check-level options are facts, not sentences to translate ----------
# "Describe the mechanism, not the mood" was two English sentences, and a session
# asking in another language translated them into one option that said only
# "simple, intuitive change" and one that was not grammatical. Fields with values
# survive the trip; prose did not.
has start 'who reads the diff' "the check-level options are stated as fields"
has start 'how many agents' "the option names the isolation it is asking about"

# --- a requirement that moved during design is recorded ---------------------
# The only path was "the requirement is unclear, rewind" — which fits a
# requirement that cannot be designed against, not one that simply grew. So growth
# went unrecorded and demand.md and design.md described two different jobs.
has design 'Divergence from demand' "the design stage records divergence from demand"
# The heading itself lives in scripts/skeleton now — the template stopped being
# prose to copy when copying it kept producing translated field names.
if grep -q '^## Divergence from demand' "$REPO_ROOT/plugins/cue-dev/skills/using-cue/scripts/skeleton"; then
    pass "design: the generated frame carries that heading"
else
    fail "design: the generated frame carries that heading" "not in scripts/skeleton"
fi
has design '"none" is the normal answer' "an empty divergence section is not an option"
has design '[Dd]o not edit demand.md' "the requirement record itself is not rewritten"

# --- a commit subject is prose and follows the record language --------------
# The subagent directive said "commit messages are unaffected". It was written to
# protect the cue-dev markers, which scripts parse — and it swallowed every
# ordinary subject with them, so a `ko` repository committed
# "feat: add navigation links to pages 3 and 4".
# The directive itself sits in implement/independent-review.md — it is the text
# that goes into a dispatch prompt, and dispatching is that procedure's whole
# subject. `has_in` names the file so the assertion moves with it rather than
# going quietly green against the wrong one.
has_in() {  # has_in <skill>/<file> <pattern> <description>
    if grep -qE "$2" "$SKILLS/$1"; then
        pass "$1: $3"
    else
        fail "$1: $3" "pattern not found: $2"
    fi
}
# --- implement's SKILL.md holds no method -----------------------------------
#
# The property the split exists for. SKILL.md used to carry both procedures: the
# self-review one written out in full, the dispatch one as a table cell pointing
# at a linked file. An `independent-review` item read SKILL.md end to end, found a
# complete and usable procedure in it, and followed that one — eight tasks in the
# controller session, six of them in a single commit, no dispatch at all.
#
# So SKILL.md must name both files and must not contain the mechanics of either.
# The scripts below are the dispatch loop's own; if one appears in SKILL.md again,
# the method has leaked back into the file whose whole job is not to have one.
has implement 'independent-review\.md' "SKILL.md names the independent-review procedure"
has implement 'self-review\.md' "SKILL.md names the self-review procedure"
has implement 'does not contain the method' "SKILL.md says outright that it is not the method"
for script in sdd-workspace task-brief review-package; do
    lacks implement "<cue>/$script" "SKILL.md does not carry the dispatch loop's $script step"
done
for f in independent-review self-review; do
    if [ -f "$SKILLS/implement/$f.md" ]; then
        pass "implement: $f.md exists"
    else
        fail "implement: $f.md exists"
    fi
done

has_in implement/independent-review.md 'A commit subject is prose' \
    "the language directive covers commit subjects"
has_in implement/independent-review.md 'conventional-commit type prefix' \
    "only the machine-read prefix stays fixed"
lacks implement 'commit messages, and outcome.md status' "the blanket commit-message exemption is gone"
has plan 'is prose, not part of the command' "the string inside git commit -m follows the record language"

# --- the two outcome header fields stay two lines ---------------------------
# `checked-by: self-review evidence: manual` reached a real record. Both fields
# are matched anchored to a line start, so the join drops `evidence` entirely.
has implement 'never join them' "it says the two header fields stay on two lines"

# --- AskUserQuestion's own fields follow the record language ----------------
# They were exempted for one release, because on Windows the harness's rendering
# of them corrupts non-ASCII — a real session showed a Korean user menus with
# mangled syllables in the words for "merge" and "complete". The next session
# then got menus that were entirely in English in a `ko` repository, which is
# worse: a mangled syllable is recoverable from context and a language the reader
# does not have is not. What stays fixed is narrower than the field — a label
# that is a value.
for skill in start finish init redo; do
    has "$skill" 'is not an exception' "the menu fields follow the record language"
    has "$skill" 'a `label` that is a value' "only value labels are exempt"
    lacks "$skill" 'own fields stay in' "the blanket English-menu exemption is gone"
done
has start 'literal tokens `independent-review`' "the check-level labels stay the tokens work-check reads"
has start 'has to name agents' "the check-level description names subagent against single agent"

# --- neither stage transcribes its own template -----------------------------
# Both kept failing verify on a translated field name — `**목표:**` for
# `**Goal:**`, `없음` for `none`. Not carelessness: the skills said prose follows
# the record language and then handed over a template mixing prose with literals
# verify greps for, with nothing marking which was which. One session lost two
# rewrites of plan.md to it. The structure is generated now, so it is never typed.
has design 'skeleton design' "design asks for the frame instead of typing it"
has plan 'skeleton plan' "plan asks for the frame instead of typing it"
has design 'is structure and stays' "design says which half of the file is structure"
has plan 'is structure and stays' "plan says which half of the file is structure"

# --- plan asks before the file exists, like design does ---------------------
# plan wrote plan.md, asked over the top of it, then ran task-graph and
# outcome-init — so the user approved something that already existed, and the
# artifact was incomplete at the moment they were shown it.
has plan 'Get approval before the file exists' "plan's checkpoint is before the write"
has plan 'Present a summary, not the plan' "it presents a summary rather than the document"

# --- a check nobody ran is never reported as run ----------------------------
# The worst thing this plugin has produced: in a repository with no test runner,
# finish reported four browser observations that no session had made. `evidence:
# manual` had passed every gate, because a script cannot ask what was looked at.
has finish 'point at the tool call' "finish tests a claimed observation against the transcript"
has finish 'ask your human partner to run it' "an unrunnable check goes to the user, not into prose"

# The prose above was already there when a run wrote "there is no test suite, so
# I follow Step 1b" and went to Step 2 — no field relayed, no question asked.
# Naming a procedure reads the same as performing one, so the step starts with a
# command whose output cannot be read as permission to move on.
has finish 'evidence <KEY>' "Step 1 begins by asking what was claimed"
has finish 'Naming this step is not performing it' "the step names its own skipped run"
has implement 'no-commit' "a task with no commit of its own has a value to record"

# --- a record belongs to the stage that wrote it ----------------------------
# design has said "do not edit demand.md" since the beginning and the other two
# edges were never written down — so nothing stopped a plan from being rewritten
# to match what got built, which is the one divergence a reviewer cannot recover
# from the diff. The path back is a rewind the user consents to, in every case.
has design 'Do not edit demand.md' "design does not rewrite the requirement"
has plan 'Do not edit design.md' "plan does not rewrite the design"
has implement 'the only one of the four records this stage writes'     "implement writes outcome.md and nothing else"

# --- the evidence question is asked where the value is written --------------
# finish caught the invented observation, but by then `evidence: manual` was a
# fact of record: implement wrote it after three greps in a repository whose
# design named five browser checks. The duplication is the point — here it is
# still a question, there it is already committed.
has implement 'evidence <KEY>' "implement asks before writing checked-by and evidence"
has finish 'evidence <KEY>' "finish asks again over the committed claim"

# --- nothing runs from inside the directory finish is about to delete -------
# A shell sitting in a worktree makes its removal platform-specific: refused
# outright on Windows, silently succeeding into a nameless cwd on macOS and Linux.
# Both are states nothing downstream can reason from, and neither is reachable if
# the scripts are run from where they already work — anywhere, on a KEY.
has finish 'do not `cd` into the worktree to run them' "finish keeps the shell out of the worktree"
has finish 'Device or resource busy' "it names the Windows symptom"
has finish 'error retrieving current directory' "and the POSIX one, which is quieter"
has using-cue 'Anywhere. They take the KEY' "the rule travels with every session"


# --- the cleanup script's lines are not reworded ----------------------------
# `worktree none — this item has no worktree` went into a notice as `worktree
# none — removed`. The worktree was still there.
has finish 'When it contradicts the answer you were given' "a cleanup that disagrees with 5b stops the skill"

# --- gate's output is acted on, not relayed ---------------------------------
# Only the `━━━` block is reproduced. gate prints none, and a session pasted its
# raw lines — including the language directive addressed to itself.
has status 'Only the .━━━. block is relayed' "it relays the notice block and nothing else"
has status '[Dd]o not then run' "it does not re-run gate after status handed over to it"

# --- approval comes before the file, in both stages that write one ----------
# plan has had this checkpoint from the start; design had only a checklist line,
# and a real session collapsed it into step 4's trade-off menu — "structured
# architecture" against "simple conversion" — after which the worked example, the
# program design and the verification method went into design.md and into a commit
# with the user having seen none of them. One of the two stages having the rule is
# how it got skipped, so both carry it in the same shape.
has design 'Get approval before the file exists' "design buys the judgment before writing"
has plan 'Get approval before the file exists' "plan buys the judgment before writing"
has design 'Ask in prose, not as a menu' "design asks in prose"
has plan 'Ask in prose, not as a menu' "plan asks in prose"

# And prose does not stop the turn — the harness does that for a menu and for
# nothing else. A turn that continues past its own question is the turn that
# answers it: one session wrote "User says yes, so I'll proceed" and cut a branch.
has design 'the end of the reply' "design ends the turn on the question"
has plan 'the end of the reply' "plan ends the turn on the question"

# --- a failed question is not an answer -------------------------------------
# Menu corruption on Windows is documented as cosmetic — "a mangled syllable is
# recoverable from context". It is not always cosmetic: the same corruption
# produced invalid escapes and five calls were rejected outright, one of them the
# plan's approval gate, and the next turn opened "Good, I'll write the plan with
# these nine tasks". The rule lives in using-cue, which every session reads, and
# the four skills that ask menus point at it rather than restating it.
has using-cue 'A question that failed is not a question that was answered' "the rule is where every session reads it"
for s in start init finish redo; do
    has "$s" 'A question that failed is not a question that was answered' "$s points at the rule"
done

# --- a proposed branch name is not a repository convention ------------------
# init-check answers `no prefixed branches yet`, and a session that had read that
# line two minutes earlier proposed `feat/` and called it "the convention used in
# this repository". The repository had one branch. Same failure as a manufactured
# rejected alternative: a choice presented as settled by evidence that is not there.
has start 'no prefixed branches yet' "start knows what an empty branch_style says"
has start '[Dd]o not describe your suggestion as the repository.s convention'     "and does not let the suggestion borrow the repository's authority"

finish
