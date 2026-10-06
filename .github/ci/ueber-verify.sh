#!/usr/bin/env bash
# Run Ueber's verification (as in make test) and decide pass/fail.
#
# The exit status of swipl alone is not reliable: if the final directive in
# main.pro fails (e.g., a syntax error in a .term file), swipl falls through to
# its toplevel, reads end-of-file from stdin and exits with status 0 although
# nothing was verified. Hence the run also fails if the log shows an error,
# a failed directive, megamodel problems, or lacks the final summary line.
#
# Usage: ueber-verify.sh [LOGFILE]   (default: ueber-verification.log)

set -u
log="${1:-ueber-verification.log}"

swipl --version
# Same command as the Makefile's test target; called directly because the
# swipl images do not ship make (and old ones cannot apt-get it any more).
swipl -q -f main.pro < /dev/null 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

fail=0
if [ "$status" -ne 0 ]; then
  echo "::error::swipl exited with status $status"; fail=1
fi
if grep -q '^ERROR' "$log"; then
  echo "::error::errors reported while loading or verifying:"
  grep -A1 '^ERROR' "$log"; fail=1
fi
if grep -q 'Goal (directive) failed' "$log"; then
  echo "::error::a directive in main.pro failed; verification did not complete"; fail=1
fi
if grep -q 'Megamodel problems' "$log"; then
  echo "::error::megamodel problems:"
  sed -n '/Megamodel problems/,$p' "$log" | grep '^ \* '; fail=1
fi
if ! grep -qE '^[0-9]+ function applications\.$' "$log"; then
  echo "::error::summary line missing; the run did not get through collection"; fail=1
fi

echo "==================== YAS / Ueber verification ===================="
grep -E '^[0-9]+ (languages|files|membership tests|functions|function applications)\.$' "$log" || true
if [ "$fail" -eq 0 ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
echo "=================================================================="
exit "$fail"
