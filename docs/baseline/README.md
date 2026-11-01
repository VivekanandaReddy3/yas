# Baseline: `make test` on a modern SWI-Prolog (before any changes)

Recorded 2026-10-05 on commit `fbc01cc` (branch `thesis/setup`), unmodified sources.

| | |
|---|---|
| Toolchain | SWI-Prolog 10.0.2 (arm64-darwin, Homebrew) |
| Command | `make test` (= `swipl -q -f main.pro`) |
| Log | [`make-test-swipl-10.0.2-macos.log`](make-test-swipl-10.0.2-macos.log) (absolute paths shortened to `./`) |

## Result

Collection completes:

```
139 languages.
1854 files.
1854 membership tests.
126 functions.
397 function applications.
```

**Verification stops partway.** Well-formedness checking completes, but during
verification, reading `languages/DDL/cs.term` raises a syntax error, the final directive
in `main.pro` fails, `halt` is never reached, and `swipl` drops into its interactive
toplevel. Run from a terminal, the process therefore waits for input indefinitely; the
run above was stopped by hand (hence the trailing `make: *** [test] Terminated: 15`).
With stdin closed, `swipl` exits with status 0.

Repeating the run in verbose mode on the same commit shows how far it gets: all 2660
relationship checks pass well-formedness. In verification, 839 pass, 1 fails
(`mapsTo(mapping, small-world.term, small-world.tree)` in BL), and the run stops at the
next check, leaving about 1820 unchecked.

Load errors reported during collection:

| File | Error |
|---|---|
| `languages/BL/blToTbl.pro:7` | Arguments are not sufficiently instantiated |
| `languages/DDL/ddlAbstract.pro:6:6` | Syntax error: Operand expected, unquoted comma or bar found |
| `languages/LAL/lalNorm.pro:7` | No permission to modify static procedure `sort/2` |
| `languages/LAL/lalPp.pro:8` | Type error: `callable` expected, found `[]` |
| `languages/LAL/lalPp.pro:77` | No permission to modify static procedure `var/1` |
| `languages/DDL/cs.term:1:43` | Syntax error: Operand expected, unquoted comma or bar found (aborts the run) |

The same errors and the same abort occur on SWI-Prolog 9.0.4 (Ubuntu package) in
the CI run of 2026-09-01 (GitHub Actions run 33475345626); that job was green
only because the step used `continue-on-error`.
