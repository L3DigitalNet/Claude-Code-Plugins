#!/usr/bin/env bats
# read-counter.bats — Cross-cutting Mechanical: PostToolUse counter contract.
# Counts file reads per-session via $PPID; warns at thresholds (10, 20, 30, ...).
#
# NOTE on $PPID: the script uses $PPID to identify the session. Each `run bash ...`
# from bats spawns a different subshell, so each call would see a different PPID.
# To exercise the counter, all invocations must be in a single subshell.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  SCRIPT="$SCRIPTS_DIR/read-counter.sh"
}
teardown() {
  # Clean up any per-PID counter files this test created.
  rm -f /tmp/da-reads-*
  teardown_test_env
}

@test "first invocation: count=1, silent (RC1)" {
  result=$(bash -c '
    SCRIPT="$1"
    rm -f "/tmp/da-reads-$$"
    out=$("$SCRIPT")
    count=$(cat "/tmp/da-reads-$$")
    rm -f "/tmp/da-reads-$$"
    echo "count=$count out=[$out]"
  ' _ "$SCRIPT")
  [[ "$result" == "count=1 out=[]" ]]
}

@test "10th invocation emits CONTEXT NOTICE (RC2)" {
  result=$(bash -c '
    SCRIPT="$1"
    rm -f "/tmp/da-reads-$$"
    for i in $(seq 1 9); do "$SCRIPT" >/dev/null; done
    out=$("$SCRIPT")
    rm -f "/tmp/da-reads-$$"
    echo "$out"
  ' _ "$SCRIPT")
  [[ "$result" == *"CONTEXT NOTICE"* ]]
}

@test "20th invocation emits CONTEXT PRESSURE (RC3)" {
  result=$(bash -c '
    SCRIPT="$1"
    rm -f "/tmp/da-reads-$$"
    echo "19" > "/tmp/da-reads-$$"
    out=$("$SCRIPT")
    rm -f "/tmp/da-reads-$$"
    echo "$out"
  ' _ "$SCRIPT")
  [[ "$result" == *"CONTEXT PRESSURE"* ]]
}

@test "11 (off-threshold) does NOT emit warning (RC4 throttling)" {
  result=$(bash -c '
    SCRIPT="$1"
    rm -f "/tmp/da-reads-$$"
    echo "10" > "/tmp/da-reads-$$"
    out=$("$SCRIPT")
    rm -f "/tmp/da-reads-$$"
    echo "[$out]"
  ' _ "$SCRIPT")
  [ "$result" = "[]" ]
}

@test "30, 40 re-emit CONTEXT PRESSURE (RC5)" {
  for n in 29 39; do
    result=$(bash -c '
      SCRIPT="$1"
      n="$2"
      rm -f "/tmp/da-reads-$$"
      echo "$n" > "/tmp/da-reads-$$"
      out=$("$SCRIPT")
      rm -f "/tmp/da-reads-$$"
      echo "$out"
    ' _ "$SCRIPT" "$n")
    [[ "$result" == *"CONTEXT PRESSURE"* ]]
  done
}

@test "set -e safety: increment from 0 does not trigger ((var++)) pitfall (RC6)" {
  # Documented gotcha — script uses var=$((var+1)) instead of ((var++)) which
  # exits 1 when var=0 under set -e. (Script doesn't actually use set -e but
  # the pattern is the marketplace-wide convention.)
  result=$(bash -c '
    SCRIPT="$1"
    rm -f "/tmp/da-reads-$$"
    "$SCRIPT" >/dev/null
    echo $?
  ' _ "$SCRIPT")
  [ "$result" = "0" ]
}
