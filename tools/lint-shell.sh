#!/usr/bin/env bash
#
# Lint shell scripts in this repository.
#
# Usage:
#   tools/lint-shell.sh [--all] [--format] [--strict] [file ...]
#
# By default, runs ShellCheck and shell syntax checks on changed shell scripts.
# Use --format to format with shfmt before linting. Use --all for the full tracked
# baseline, or pass files explicitly to lint a smaller set.
#
# Tracked files that start with a shebang must also be executable in the git
# index, which is the mode CI gets when it runs them.
set -euo pipefail

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "required tool '$1' is not on PATH"
}

has_shebang() {
  local path="$1"
  local first_line=""

  [[ -f "$path" ]] || return 1

  IFS= read -r first_line <"$path" || true
  [[ "$first_line" == '#!'* ]]
}

is_shell_file() {
  local path="$1"
  local first_line=""

  [[ -f "$path" ]] || return 1

  case "$path" in
    *.sh)
      return 0
      ;;
  esac

  IFS= read -r first_line <"$path" || true
  [[ "$first_line" =~ ^#!.*[/[:space:]](bash|dash|ksh|sh)([[:space:]]|$) ]]
}

ensure_git_work_tree() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "run this from inside a git work tree, or pass files explicitly"
}

add_shell_file() {
  local path
  local existing

  path="$1"
  if ! is_shell_file "$path"; then
    return 0
  fi

  if [[ "${#files[@]}" -gt 0 ]]; then
    for existing in "${files[@]}"; do
      if [[ "$existing" == "$path" ]]; then
        return 0
      fi
    done
  fi

  files+=("$path")
}

collect_all_shell_files() {
  local path

  ensure_git_work_tree

  while IFS= read -r -d '' path; do
    add_shell_file "$path"
  done < <(git ls-files -z)
}

collect_changed_shell_files() {
  local path

  ensure_git_work_tree

  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    while IFS= read -r -d '' path; do
      add_shell_file "$path"
    done < <(git diff --name-only -z --diff-filter=ACMR HEAD)

    while IFS= read -r -d '' path; do
      add_shell_file "$path"
    done < <(git diff --cached --name-only -z --diff-filter=ACMR)
  else
    collect_all_shell_files
  fi

  while IFS= read -r -d '' path; do
    add_shell_file "$path"
  done < <(git ls-files --others --exclude-standard -z)
}

collect_requested_shell_files() {
  local path

  for path in "$@"; do
    add_shell_file "$path"
  done
}

syntax_shell_for() {
  local path="$1"
  local first_line=""

  IFS= read -r first_line <"$path" || true

  case "$first_line" in
    *"/sh"* | *" env sh"* | *"/dash"* | *" env dash"*)
      printf 'sh'
      ;;
    *)
      printf 'bash'
      ;;
  esac
}

run_syntax_checks() {
  local file
  local shell_name

  for file in "$@"; do
    shell_name="$(syntax_shell_for "$file")"
    case "$shell_name" in
      sh)
        sh -n "$file"
        ;;
      bash)
        bash -n "$file"
        ;;
      *)
        die "unsupported shell for syntax check: $shell_name"
        ;;
    esac
  done
}

# A file that starts with a shebang is meant to be run, and CI runs some of them
# by path — `tools/lint-shell.sh --all` is one. What decides whether that works is
# the mode in the git index, not the one in the working tree: this repository is
# developed on Windows, where core.filemode is false and a chmod never reaches
# git, so a new script lands as 100644 and Linux answers it with exit 126,
# "Permission denied". Reading `git ls-files -s` is what makes the check mean the
# same thing on both platforms.
#
# A shebang is the usual evidence, but not the only one: hooks/run-hook.cmd is a
# cmd/sh polyglot whose first line has to stay `: << 'CMDBLOCK'` for cmd.exe, and
# Claude Code still runs it by path on macOS and Linux. Files like that are named
# here, because nothing in their content says they are executables.
run_by_path() {
  case "$1" in
    */hooks/run-hook.cmd) return 0 ;;
  esac
  has_shebang "$1"
}

# `$var` with a multi-byte character straight after it, which has to be written
# `${var}` instead.
#
# bash 3.2 — the one macOS ships — scans the leading byte of a UTF-8 character as
# part of the variable name, so `"$s━"` reads the variable `s━`. Under `set -u`
# that is fatal, and the error names `s━`, whose trailing bytes are invisible in a
# terminal and stripped by most log viewers. It reads as a complaint about `s`,
# which is set, sitting one line above. ShellCheck has no rule for this.
check_multibyte_refs() {
  local hits

  # Whole-line comments are skipped: the rule has to be written down somewhere,
  # and writing it down means quoting the form it forbids.
  hits=$(LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~[:space:]]' "$@" 2>/dev/null \
    | grep -vE '^([^:]*:)?[0-9]+:[[:space:]]*#' || true)

  if [[ -z "$hits" ]]; then
    return 0
  fi

  echo "error: \$var followed by a multi-byte character; write \${var} instead:" >&2
  printf '%s\n' "$hits" >&2
  return 1
}

check_exec_bits() {
  local entry mode path
  local offenders=()

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r -d '' entry; do
    mode=${entry%% *}
    path=${entry#*$'\t'}
    if [[ "$mode" == 100644 ]] && run_by_path "$path"; then
      offenders+=("$path")
    fi
    # The polyglot is neither a .sh file nor a shebang file, so it never reaches
    # the linted set and has to be added to the query directly. It is added on
    # every run, not only under --all: its mode is a repository-wide invariant,
    # and when it is wrong the session-start hook simply does nothing on macOS
    # and Linux, with no error anyone sees.
  done < <(git ls-files -s -z -- "$@" ':(top)plugins/*/hooks/run-hook.cmd')

  if [[ "${#offenders[@]}" -eq 0 ]]; then
    return 0
  fi

  echo "error: tracked files are run by path but are not executable in the git index:" >&2
  printf '  %s\n' "${offenders[@]}" >&2
  echo "fix with: git update-index --chmod=+x ${offenders[*]}" >&2
  return 1
}

format=false
strict=false
all=false
requested_files=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      all=true
      ;;
    --format)
      format=true
      ;;
    --strict)
      strict=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      requested_files+=("$@")
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      requested_files+=("$1")
      ;;
  esac
  shift
done

require_tool shellcheck
if [[ "$format" == true ]]; then
  require_tool shfmt
fi

files=()
if [[ "${#requested_files[@]}" -gt 0 ]]; then
  collect_requested_shell_files "${requested_files[@]}"
elif [[ "$all" == true ]]; then
  collect_all_shell_files
else
  collect_changed_shell_files
fi

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "No shell files found."
  exit 0
fi

if [[ "$format" == true ]]; then
  echo "Formatting ${#files[@]} shell files"
  shfmt_args=(-i 2 -ci -bn)
  shfmt "${shfmt_args[@]}" -w "${files[@]}"
fi

echo "Linting ${#files[@]} shell files"

shellcheck_args=(--severity=warning --external-sources --source-path=SCRIPTDIR)
if [[ "$strict" == true ]]; then
  shellcheck_args+=("--enable=check-extra-masked-returns,check-set-e-suppressed,quote-safe-variables,deprecate-which,avoid-nullary-conditions")
fi

shellcheck "${shellcheck_args[@]}" "${files[@]}"
run_syntax_checks "${files[@]}"
check_multibyte_refs "${files[@]}"
check_exec_bits "${files[@]}"
