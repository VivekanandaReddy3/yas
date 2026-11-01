#!/usr/bin/env python3
"""Build the static verification report page from a verification run.

Usage: health-page.py OUTDIR SITEDIR [--history-url URL]

OUTDIR is the directory written by ueber-verify.sh. SITEDIR receives index.html,
history.json and two badges. The history of earlier runs is read from URL (the
published history.json), if given, so no extra branch is needed.
Run it from the repository root; it reads dates from git. Standard library only.
"""
import argparse
import collections
import datetime
import html
import json
import re
import subprocess
import urllib.request
from pathlib import Path

CLASSES = [
    ("checked", "Checked", "A real check ran."),
    ("partly_checked", "Partly checked", "A real check ran; further Java, Python or Haskell checks were skipped."),
    ("skipped", "Skipped", "Only Java, Python or Haskell checks exist; they do not run in default mode."),
    ("loaded", "Loaded", "Prolog source consulted at start-up; a load error fails the run. Nothing else checks it."),
    ("parsed_only", "Parsed only", "The file was parsed; nothing else checks it. Parsing stops after the first value."),
    ("read_only", "Read only", "The file was read; nothing else checks it."),
    ("declaration", "Declaration", "Nothing to run (language, function, ...)."),
]
REAL = ("checked", "partly_checked")
TECH = {"hs": "Haskell", "java": "Java", "py": "Python", "pro": "Prolog", "dcg": "Prolog", "md": "Markdown",
        "term": "Prolog terms", "json": "JSON", "ueber": "Ueber metadata (.ueber)", "hinzu": "Hinzu metadata (.hinzu)"}
BASELINES = ["languages/Ueber/dump.term", "languages/Hinzu/dump.term", "languages/Ueber/functions.term",
             "languages/Ueber/functions.dgl", "languages/Ueber/functions.ppl", "languages/Ueber/languages.term"]
e = html.escape


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()


def last_change(path):
    return git("log", "-1", "--format=%cs", "--", path)


def read_classes(path):
    return [line.split("\t", 2) for line in Path(path).read_text().splitlines()]


def group(directory):
    return "/".join(directory.split("/")[:2])


def real_share(counts):
    runnable = sum(n for k, n in counts.items() if k != "declaration")
    return sum(counts.get(k, 0) for k in REAL), runnable


def pct(a, b):
    return f"{100 * a / b:.1f}%" if b else "-"


def tech_row(name, c, cls=""):
    cols = "".join(f'<td class="n">{c[k]:,}</td>' for k in ("checked", "partly_checked", "loaded", "parsed_only", "read_only", "skipped"))
    return f'<tr{cls}><td>{e(name)}</td><td class="n">{sum(v for k, v in c.items() if k != "declaration"):,}</td>{cols}</tr>'


def meter(a, b):
    width = 100 * a / b if b else 0
    return f'<div class="meter"><div style="width:{width:.1f}%"></div></div>'


def badge(left, right, color):
    lw, rw = 7 * len(left) + 14, 7 * len(right) + 14
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{lw + rw}" height="20" role="img" '
            f'aria-label="{e(left)}: {e(right)}"><rect width="{lw}" height="20" fill="#555"/>'
            f'<rect x="{lw}" width="{rw}" height="20" fill="{color}"/>'
            f'<g fill="#fff" font-family="Verdana,sans-serif" font-size="11" text-anchor="middle">'
            f'<text x="{lw / 2}" y="14">{e(left)}</text><text x="{lw + rw / 2}" y="14">{e(right)}</text></g></svg>')


def load_history(url, site):
    if url:
        try:
            with urllib.request.urlopen(url, timeout=15) as r:
                return json.load(r)
        except Exception as err:
            print(f"no earlier history at {url}: {err}")
    existing = site / "history.json"
    return json.loads(existing.read_text()) if existing.exists() else []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir")
    ap.add_argument("sitedir")
    ap.add_argument("--history-url")
    a = ap.parse_args()
    out, site = Path(a.outdir), Path(a.sitedir)
    site.mkdir(parents=True, exist_ok=True)
    report = json.loads((out / "ueber-report.json").read_text())
    rows = read_classes(out / "ueber-classes.tsv")
    assurance = report["assurance"]
    overall = {k: assurance[k] for k, _, _ in CLASSES}
    if sum(overall.values()) + assurance["failed"] + assurance["not_run"] != assurance["total"]:
        raise SystemExit("classes do not add up to the total")
    real, runnable = real_share(overall)
    # Checks that failed or were never reached still count against the share.
    runnable += assurance["failed"] + assurance["not_run"]
    commit = report.get("commit") or git("rev-parse", "HEAD")
    date = git("log", "-1", "--format=%cs", commit) or datetime.date.today().isoformat()
    passed = report["result"] == "PASS"

    by_group = collections.defaultdict(collections.Counter)
    by_tech = collections.defaultdict(collections.Counter)
    for cls, directory, decl in rows:
        by_group[group(directory)][cls] += 1
        m = re.match(r"(?:not)?[eE]lementOf\('([^']+)'", decl)
        if m:
            name = m.group(1).rsplit("/", 1)[-1]
            ext = name.rsplit(".", 1)[-1] if "." in name else ""
            key = TECH.get(ext, "Language artifacts")
        else:
            key = "Function applications (mapsTo)" if decl.startswith("mapsTo(") else None
        if key and cls != "declaration":
            by_tech[key][cls] += 1

    history = [h for h in load_history(a.history_url, site) if h.get("commit") != commit]
    history.append({"commit": commit, "date": date, "result": report["result"],
                    "real_percent": round(100 * real / runnable, 1), "really_checked": real,
                    "runnable": runnable, "seconds": report["seconds"], "assurance": assurance})
    (site / "history.json").write_text(json.dumps(history, indent=1))

    result_rows = "".join(
        f'<tr><td>{e(n)}</td><td class="n">{overall[k]:,}</td>'
        f'<td class="n">{pct(overall[k], assurance["total"])}</td><td>{e(d)}</td></tr>'
        for k, n, d in CLASSES)
    if assurance["failed"] or assurance["not_run"]:
        result_rows += (f'<tr><td>Failed</td><td class="n">{assurance["failed"]:,}</td><td></td><td></td></tr>'
                        f'<tr><td>Not reached</td><td class="n">{assurance["not_run"]:,}</td><td></td><td></td></tr>')
    tech_rows = "".join(tech_row(t, c) for t, c in sorted(by_tech.items(), key=lambda kv: -sum(kv[1].values())))
    tech_total = collections.Counter({k: overall[k] for k, _, _ in CLASSES if k != "declaration"})
    if sum(sum(c.values()) for c in by_tech.values()) != sum(tech_total.values()):
        raise SystemExit("file-type rows do not add up to the runnable checks")
    tech_rows += tech_row("Total", tech_total, ' class="total"')
    roots = collections.defaultdict(collections.Counter)
    for cls, directory, _ in rows:
        roots[directory.split("/")[0]][cls] += 1
    root_rows = "".join(
        f'<tr><td><code>{e(k)}/</code></td><td class="n">{real_share(c)[0]:,}</td><td class="n">{real_share(c)[1]:,}</td>'
        f'<td class="n">{pct(*real_share(c))}</td></tr>' for k, c in sorted(roots.items()))
    lang_rows = []
    for g, c in sorted(by_group.items(), key=lambda kv: -real_share(kv[1])[1]):
        r, n = real_share(c)
        changed = last_change(g)
        name = g if "/" in g else f"{g}/"
        share = f"{100 * r / n:.1f}" if n else "-1"
        small = ' class="small"' if n < 5 else ""
        lang_rows.append(
            f'<tr{small}><td data-v="{e(name.lower())}"><code>{e(name)}</code></td><td>{meter(r, n)}</td>'
            f'<td class="n" data-v="{share}">{pct(r, n)}</td><td class="n" data-v="{r}">{r:,}</td>'
            f'<td class="n" data-v="{n}">{n:,}</td><td class="n" data-v="{e(changed)}">{e(changed)}</td></tr>')
    base_rows = "".join(f'<tr><td><code>{e(p)}</code></td><td class="n">{e(last_change(p))}</td></tr>'
                        for p in BASELINES)
    run_rows = "".join(
        f'<tr><td><code>{e(h["commit"][:7])}</code></td><td>{e(h["date"])}</td><td>{e(h["result"])}</td>'
        f'<td class="n">{h["real_percent"]}%</td><td class="n">{h["really_checked"]:,}</td>'
        f'<td class="n">{h["runnable"]:,}</td><td class="n">{h["seconds"]}</td></tr>'
        for h in reversed(history[-20:]))
    problem = ""
    if not passed:
        items = [f"<li>{e(r)}</li>" for r in report["reasons"]]
        items += [f"<li><code>{e(f['relationship'])}</code> ({e(f['phase'])})</li>" for f in report["failures"][:50]]
        problem = f'<h2>Failures</h2><ul>{"".join(items)}</ul>'

    page = TEMPLATE
    for k, v in {
        "RESULT": "Passed" if passed else "Failed", "RESULT_CLASS": "ok" if passed else "bad",
        "FAILED": f"{assurance['failed']:,}", "NOTRUN": f"{assurance['not_run']:,}", "ROOTS": root_rows,
        "COMMIT": e(commit[:7]), "DATE": e(date), "SWI": e(report["swipl"]), "SECONDS": str(report["seconds"]),
        "SHARE": pct(real, runnable), "REAL": f"{real:,}", "RUNNABLE": f"{runnable:,}",
        "METER": meter(real, runnable), "TOTAL": f"{assurance['total']:,}",
        "ALLPCT": pct(real, assurance["total"]), "DECL": f"{overall['declaration']:,}",
        "DISTINCT": f"{report['distinct_relationships']:,}",
        "LANGUAGES": str(report["collected"]["languages"]), "FILES": f"{report['collected']['files']:,}",
        "RESULTS": result_rows, "TECH": tech_rows, "LANGS": "".join(lang_rows), "BASE": base_rows,
        "RUNS": run_rows, "PROBLEM": problem,
    }.items():
        page = page.replace("{{" + k + "}}", v)
    (site / "index.html").write_text(page)
    (site / "badge-status.svg").write_text(
        badge("ueber", "passing" if passed else "failing", "#2e7d32" if passed else "#c62828"))
    (site / "badge-checked.svg").write_text(badge("checked", pct(real, runnable), "#1565c0"))
    print(f"wrote {site}: {real}/{runnable} really checked, {len(history)} run(s) in history")


TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>YAS verification report</title>
<style>
body{margin:0 auto;max-width:900px;padding:12px 16px 40px;background:#fff;color:#000;
 font:14px/1.45 Helvetica,Arial,sans-serif}
h1{font-size:20px;margin:8px 0 4px}
h2{font-size:15px;margin:26px 0 6px;padding:3px 6px;background:#e6e6e6}
p{margin:6px 0}
table{border-collapse:collapse;width:100%;margin:6px 0}
th,td{border:1px solid #bbb;padding:3px 7px;text-align:left;vertical-align:top}
th{background:#f2f2f2;font-weight:bold;white-space:nowrap}
th a{color:#000;text-decoration:none;cursor:pointer}
th a:hover{text-decoration:underline}
.n{text-align:right;white-space:nowrap}
.scroll{overflow-x:auto}
.ok{color:#1b5e20;font-weight:bold}.bad{color:#b71c1c;font-weight:bold}
.meter{width:120px;height:11px;border:1px solid #888;background:#fff;margin-top:3px}
.meter div{height:100%;background:#4a7ebb}
code{font-family:Menlo,Consolas,monospace;font-size:13px;word-break:break-word}
.total td{font-weight:bold;background:#f2f2f2}.small td,.small code{color:#888}
.sum{width:auto}.sum td:first-child{background:#f2f2f2}
</style></head><body>
<h1>YAS verification report</h1>
<p>Ueber verification of commit <code>{{COMMIT}}</code> ({{DATE}})</p>

<table class="sum"><tbody>
<tr><td>Result</td><td><span class="{{RESULT_CLASS}}">{{RESULT}}</span>: {{FAILED}} failed, {{NOTRUN}} not reached. This covers only the checks that ran; see below.</td></tr>
<tr><td>Checked</td><td>{{SHARE}} ({{REAL}} of {{RUNNABLE}} runnable checks){{METER}}</td></tr>
<tr><td>Toolchain</td><td>SWI-Prolog {{SWI}}</td></tr>
<tr><td>Run time</td><td>{{SECONDS}} s</td></tr>
<tr><td>Files</td><td>{{FILES}}</td></tr>
<tr><td>Language declarations</td><td>{{LANGUAGES}}</td></tr>
<tr><td>Distinct relationships</td><td>{{DISTINCT}}</td></tr>
</tbody></table>

{{PROBLEM}}

<h2>Checks by result</h2>
<p>All {{TOTAL}} entries of the run, including repeats. "Runnable" leaves out the {{DECL}} declarations. Counted over all entries, {{ALLPCT}} are checked.</p>
<div class="scroll"><table>
<tr><th>Result</th><th class="n">Checks</th><th class="n">Share</th><th>Meaning</th></tr>
{{RESULTS}}
</table></div>

<h2>By top-level directory</h2>
<p><code>samples/</code> includes <code>samples/obsolete</code>. Whether it should count is still open.</p>
<div class="scroll"><table>
<tr><th>Directory</th><th class="n">Checked</th><th class="n">Runnable</th><th class="n">%</th></tr>
{{ROOTS}}
</table></div>

<h2>By file type</h2>
<p>All runnable checks. Checked and partly checked together give the {{REAL}} in the summary.</p>
<div class="scroll"><table>
<tr><th>Type</th><th class="n">Checks</th><th class="n">Checked</th><th class="n">Partly</th><th class="n">Loaded</th><th class="n">Parsed</th><th class="n">Read</th><th class="n">Skipped</th></tr>
{{TECH}}
</table></div>

<h2>By language</h2>
<p>Runnable checks per directory, largest first. Click a column to sort. Grey rows have fewer than 5 checks, so their percentage says little: most directories contain at least a <code>.ueber</code> and a <code>.hinzu</code> file, which are checked.</p>
<div class="scroll"><table id="langs">
<thead><tr><th><a data-c="0">Directory</a></th><th>Checked</th><th class="n"><a data-c="2">%</a></th><th class="n"><a data-c="3">Hit</a></th><th class="n"><a data-c="4">Total</a></th><th class="n"><a data-c="5">Last change</a></th></tr></thead>
<tbody>{{LANGS}}</tbody>
</table></div>

<h2>Baselines</h2>
<p>Stored expected outputs, with the date of their last update.</p>
<div class="scroll"><table>
<tr><th>File</th><th class="n">Last change</th></tr>
{{BASE}}
</table></div>

<h2>Recent runs</h2>
<div class="scroll"><table>
<tr><th>Commit</th><th>Date</th><th>Result</th><th class="n">Checked</th><th class="n">Hit</th><th class="n">Total</th><th class="n">Seconds</th></tr>
{{RUNS}}
</table></div>

<script>
var body=document.querySelector('#langs tbody'),last=-1,dir=1;
document.querySelectorAll('#langs th a').forEach(function(a){a.onclick=function(){
 var c=+a.dataset.c,num=c>=2&&c<=4;dir=last===c?-dir:1;last=c;
 [].slice.call(body.rows).sort(function(x,y){var p=x.cells[c].dataset.v,q=y.cells[c].dataset.v;
  return dir*(num?p-q:p.localeCompare(q))}).forEach(function(r){body.appendChild(r)})}});
</script>
</body></html>
"""

if __name__ == "__main__":
    main()
