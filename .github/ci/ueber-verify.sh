#!/usr/bin/env bash
# Run Ueber's verification and report pass/fail.
#
# Ueber runs in verbose mode, which prints the outcome of every relationship
# in both phases (well-formedness: OK/FAIL, verification: VERIFIED/FAIL).
# ueber-report.pl turns that log into ueber-report.json and ueber-report.md
# and decides the result; see there for what counts as a failure.
#
# Usage: ueber-verify.sh [OUTDIR]   (default: current directory)
# Writes OUTDIR/ueber-verification.log, ueber-report.json, ueber-report.md.

set -u
out="${1:-.}"
mkdir -p "$out"
log="$out/ueber-verification.log"
here="$(dirname "$0")"

swipl --version
start=$(date +%s)
# Same as the Makefile's verbose target; called directly because the swipl
# images do not ship make (and old ones cannot apt-get it any more).
swipl -q -f main.pro -- verbose < /dev/null > "$log" 2>&1
status=$?
seconds=$(( $(date +%s) - start ))

swipl "$here/ueber-report.pl" "$log" "$status" "$seconds" "$out"
