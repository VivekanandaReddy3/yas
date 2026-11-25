#!/usr/bin/env bash
# Run Ueber's verification and report pass/fail.
#
# Ueber runs in verbose mode, which prints the outcome of every relationship
# in both phases (well-formedness: OK/FAIL, verification: VERIFIED/FAIL).
# ueber-classify.pl records what each check actually does (see there), and
# ueber-report.pl combines both into ueber-report.json and ueber-report.md and
# decides the result; see there for what counts as a failure.
#
# Usage: ueber-verify.sh [OUTDIR]   (default: current directory)
# UEBER_MODE=ffi runs the foreign (Java, Python, Haskell) checks as well; the
# components must have been built first (see ueber-verify-ffi.sh).
# Writes OUTDIR/ueber-verification.log, ueber-classes.tsv, ueber-report.json,
# ueber-report.md.

set -u
out="${1:-.}"
mkdir -p "$out"
log="$out/ueber-verification.log"
here="$(dirname "$0")"

swipl --version
start=$(date +%s)
# Same as the Makefile's verbose target; called directly because the swipl
# images do not ship make (and old ones cannot apt-get it any more).
# shellcheck disable=SC2086  # UEBER_MODE is empty or a single word
swipl -q -f main.pro -- ${UEBER_MODE:-} verbose < /dev/null > "$log" 2>&1
status=$?
seconds=$(( $(date +%s) - start ))

classes="$out/ueber-classes.tsv"
swipl -q -f main.pro -g "['$here/ueber-classify.pl'],classify('$classes'),halt" -- session \
  < /dev/null > "$out/ueber-classify.log" 2>&1

swipl "$here/ueber-report.pl" "$log" "$status" "$seconds" "$out" "$classes"
