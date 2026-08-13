#!/usr/bin/env bash
#
# Runs the test suites in parallel.
#
# The suites are independent — each builds its own fixture repository with
# mktemp -d and keeps no shared state. So there is no reason to run them
# sequentially, and sequentially they total about 8 minutes while the slowest
# single suite is about 2. Parallelism alone cuts wall-clock time to a quarter.
#
# The default concurrency is 6. This repository's tests are bound by process
# creation rather than CPU (particularly expensive on Windows), so a little above
# the core count works better.
#
# Usage:
#   tools/run-tests.sh                 every suite
#   tools/run-tests.sh -j 12           set the concurrency
#   tools/run-tests.sh tests/cue-dev   only under a path
#   tools/run-tests.sh tests/cue-dev/test-status.sh
#
#   exit 0  all passed
#   exit 1  one or more failed
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JOBS=${TEST_JOBS:-6}

targets=()
while [ $# -gt 0 ]; do
  case "$1" in
    -j) JOBS=$2; shift 2 ;;
    -j*) JOBS=${1#-j}; shift ;;
    -h|--help) sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) targets+=("$1"); shift ;;
  esac
done

# Collect targets. With no arguments, every test-*.sh under tests/.
#
# There is no exclusion list any more, and adding one back needs care: an
# exclusion is by directory, so a suite put in the wrong one runs nowhere and says
# nothing about it. Two suites were found parked behind the old exclusion for
# real-LLM tests, both of them plain shell.
collect() {
  local path
  if [ "${#targets[@]}" -eq 0 ]; then
    find "$REPO_ROOT/tests" -name 'test-*.sh' -type f | sort
    return
  fi
  for path in "${targets[@]}"; do
    [ -e "$path" ] || path="$REPO_ROOT/$path"
    if [ -d "$path" ]; then
      find "$path" -name 'test-*.sh' -type f | sort
    else
      printf '%s\n' "$path"
    fi
  done
}

suites=()
while IFS= read -r line; do
  [ -n "$line" ] && suites+=("$line")
done < <(collect)

if [ "${#suites[@]}" -eq 0 ]; then
  echo "no suites to run." >&2
  exit 1
fi

out_dir=$(mktemp -d)
trap 'rm -rf "$out_dir"' EXIT

echo "${#suites[@]} suites · concurrency $JOBS"
echo

started=$(date +%s)

# Only failing suites get their output shown. Hundreds of [PASS] lines from the
# ones that passed are not signal.
run_one() {
  local suite=$1 name log begin end rc=0
  name=$(printf '%s' "${suite#"$REPO_ROOT"/}" | tr '/' '_')
  log="$out_dir/$name.log"
  begin=$(date +%s)
  bash "$suite" > "$log" 2>&1 || rc=$?
  end=$(date +%s)
  if [ "$rc" -eq 0 ]; then
    printf 'PASS  %5ss  %s\n' "$((end - begin))" "${suite#"$REPO_ROOT"/}"
  else
    printf 'FAIL  %5ss  %s  (exit %s)\n' "$((end - begin))" "${suite#"$REPO_ROOT"/}" "$rc"
    printf '%s\n' "$log" > "$out_dir/failed.$name"
  fi
}
export -f run_one
export out_dir REPO_ROOT

printf '%s\n' "${suites[@]}" \
  | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}

finished=$(date +%s)
echo

failed=$(find "$out_dir" -maxdepth 1 -name 'failed.*' -type f | sort)
if [ -z "$failed" ]; then
  printf 'all passed — %s suites, %ss\n' "${#suites[@]}" "$((finished - started))"
  exit 0
fi

echo "─────────────────────────────────────────────"
while IFS= read -r marker; do
  log=$(cat "$marker")
  echo
  echo "▼ $(basename "$log" .log)"
  cat "$log"
done <<< "$failed"
echo "─────────────────────────────────────────────"
printf '%s of %s suites failed, %ss\n' "$(printf '%s\n' "$failed" | grep -c .)" \
  "${#suites[@]}" "$((finished - started))"
exit 1
