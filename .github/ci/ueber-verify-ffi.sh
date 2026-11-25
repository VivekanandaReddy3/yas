#!/usr/bin/env bash
# Run Ueber's verification with the foreign checks enabled (ffi mode).
#
# In default mode, Ueber skips every Java, Python and Haskell check and counts
# it as passed (if/2 in languages/Ueber/ueberFFI.pro). This script builds what
# those checks need and then runs ueber-verify.sh in ffi mode.
#
# Only the classes the .ueber files call are compiled, not the components'
# Makefiles: those also generate source files (e.g. BNL's *Conversion*.java)
# that Ueber would find in the tree and report as undeclared, which breaks the
# dump.term baseline. Python needs no build step.
#
# For Haskell, the FFI itself runs ghc before each check. The first run
# compiles and prints its progress into the middle of Ueber's result line,
# which the report cannot read; later runs find everything up to date and
# print nothing. So the same ghc command is run here first.
#
# Foreign checks called from .ueber files (keep in sync):
#   languages/FSML/Java/.ueber     java('org.softlang.fsml.FsmlAcceptor')
#   languages/BNL/ANTLR/.ueber     java('org.softlang.bnl.BnlEbnfAcceptor')
#   languages/FSML/Haskell/.ueber  haskell('FsmlAcceptor')
#   languages/FSML/Python/.ueber   python(...), no build step
#
# Usage: ueber-verify-ffi.sh [OUTDIR]   (default: current directory)
# Writes the files of ueber-verify.sh plus OUTDIR/ffi-toolchain.txt.

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
} > "$out/ffi-toolchain.txt" 2>&1
cat "$out/ffi-toolchain.txt"

build_failed=0
java_build() {  # SOURCEPATH CLASS-FILE
  if ! javac -nowarn -cp "$antlr" -sourcepath "$1" "$1/$2"; then
    echo "Build failed: $1/$2"
    build_failed=1
  fi
}
haskell_build() {  # DIRECTORY MODULE; same command as haskell/6 in ueberFFI.pro
  mkdir -p tmp
  if ! ghc -i.:"$1"/.:lib/Haskell -main-is "$2" "$2" -o "tmp/$2.run"; then
    echo "Build failed: $1/$2"
    build_failed=1
  fi
}
java_build languages/FSML/Java org/softlang/fsml/FsmlAcceptor.java
java_build languages/BNL/ANTLR org/softlang/bnl/BnlEbnfAcceptor.java
haskell_build languages/FSML/Haskell FsmlAcceptor
if [ "$build_failed" -ne 0 ]; then
  exit 1
fi

UEBER_MODE=ffi bash "$here/ueber-verify.sh" "$out"
