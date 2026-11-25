#!/usr/bin/env bash
# Run Ueber's verification with the foreign checks enabled (ffi mode).
#
# In default mode, Ueber skips every Java, Python and Haskell check and counts
# it as passed (if/2 in languages/Ueber/ueberFFI.pro). This script prepares
# what those checks need and then runs ueber-verify.sh in ffi mode.
#
# Which foreign implementations exist is taken from Ueber's own declarations
# (ueber-ffi-checks.pl), so a newly declared Java, Haskell or Python check is
# picked up without editing this script. For each one:
#   java     compile the declared class from its declaring directory; only
#            that class and what it uses, not the component's Makefile, which
#            also generates sources that Ueber would find in the tree and
#            report as undeclared (dump.term then disagrees)
#   haskell  run the FFI's own ghc command once beforehand: the first
#            compilation prints its progress into the middle of Ueber's result
#            line, which the report cannot read; later runs print nothing
#   python   check that the declared module exists; nothing to build
# A declared implementation without a source file stops the run here with a
# message that names it, instead of a failing check later.
#
# Usage: ueber-verify-ffi.sh [OUTDIR]   (default: current directory)
# Writes the files of ueber-verify.sh plus OUTDIR/ffi-toolchain.txt (tool and
# package versions) and OUTDIR/ffi-checks.tsv (the foreign implementations).

set -u
out="${1:-.}"
mkdir -p "$out"
here="$(dirname "$0")"
antlr=lib/Java/antlr-4.5.3-complete.jar

{
  java -version 2>&1 | head -1
  ghc --version
  python3 --version
  python3 -c 'import importlib.metadata as m; print("antlr4-python3-runtime", m.version("antlr4-python3-runtime"))'
  echo
  echo "Debian packages:"
  dpkg-query -W -f '${Package} ${Version}\n'
} > "$out/ffi-toolchain.txt" 2>&1
head -5 "$out/ffi-toolchain.txt"

checks="$out/ffi-checks.tsv"
swipl -q -f main.pro -g "['$here/ueber-ffi-checks.pl'],ffi_checks('$checks'),halt" -- session \
  < /dev/null > "$out/ffi-checks.log" 2>&1
if [ ! -s "$checks" ]; then
  echo "Could not list the foreign implementations; see ffi-checks.log"
  exit 1
fi
echo "Foreign implementations declared in Ueber:"
cat "$checks"

failed=0
fail() { echo "FFI preparation failed: $*"; failed=1; }

while IFS=$'\t' read -r lang dir name; do
  case "$lang" in
    java)
      src="$dir/${name//.//}.java"
      if [ ! -f "$src" ]; then fail "java('$name') declared in $dir, but $src does not exist"
      elif ! javac -nowarn -cp "$antlr" -sourcepath "$dir" "$src"; then fail "javac $src"
      fi ;;
    haskell)
      # Same command as haskell/6 in languages/Ueber/ueberFFI.pro.
      mkdir -p tmp
      if [ ! -f "$dir/$name.hs" ]; then fail "haskell('$name') declared in $dir, but $dir/$name.hs does not exist"
      elif ! ghc -i.:"$dir":lib/Haskell -main-is "$name" "$name" -o "tmp/$name.run"; then fail "ghc $dir/$name.hs"
      fi ;;
    python)
      if [ ! -f "$dir/$name.py" ]; then fail "python('$name') declared in $dir, but $dir/$name.py does not exist"
      fi ;;
    *)
      fail "no preparation known for foreign language '$lang' ($dir, $name)" ;;
  esac
done < "$checks"

if [ "$failed" -ne 0 ]; then
  exit 1
fi

UEBER_MODE=ffi bash "$here/ueber-verify.sh" "$out"
