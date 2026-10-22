#!/usr/bin/env bash
# Exercise every endpoint against a running stack and check the results.
#
#   ./api/smoke_test.sh                     # against http://127.0.0.1:8000
#   ./api/smoke_test.sh http://host:8000
#
# Exits non-zero if any check fails.
set -uo pipefail

URL="${1:-http://127.0.0.1:8000}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="$ROOT/www/Template.csv"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PY="$ROOT/api/.venv/bin/python"
[ -x "$PY" ] || PY=python3

# Reference values from the shipped Template.csv. A mismatch means the
# numerics moved, which matters more than any endpoint returning 200.
EXPECT_R2="0.999325714203279"
EXPECT_SLOPE="549.988783811166"

pass=0; fail=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# expect_code <label> <expected> <curl args...>
expect_code() {
  local label="$1" want="$2"; shift 2
  local got; got=$(curl -sS -o /dev/null -w '%{http_code}' "$@" 2>/dev/null)
  [ "$got" = "$want" ] && ok "$label ($got)" || bad "$label: expected $want, got $got"
}

jqp() { "$PY" -c "import json,sys;d=json.load(sys.stdin);print($1)" 2>/dev/null; }

FORM=(-F "conc_lvl=Concentration_level_perc"
      -F "conc_sol=Concentration_of_solution_mg_ml"
      -F "pk_area=Peak_area_mAU_min" -F "ref_conc=0.15")

head_ "Target: $URL"

# ---------------------------------------------------------------- liveness
head_ "1. Liveness"
H=$(curl -sS --max-time 5 "$URL/health" 2>/dev/null)
if [ -z "$H" ]; then
  bad "API unreachable at $URL -- start it with ./api/run.sh"
  echo; echo "1 check failed."; exit 1
fi
[ "$(echo "$H" | jqp "d['status']")" = "ok" ] \
  && ok "API healthy" || bad "API status: $H"
[ "$(echo "$H" | jqp "d['r_backend']['status']")" = "ok" ] \
  && ok "R backend healthy (R $(echo "$H" | jqp "d['r_backend']['r_version']"))" \
  || bad "R backend unhealthy: $H"

N=$(curl -sS "$URL/report/sections" | jqp "len(d['sections'])")
[ "$N" = "4" ] && ok "4 report sections listed" || bad "expected 4 sections, got $N"

# ----------------------------------------------------------------- columns
head_ "2. Column inspection"
C=$(curl -sS -X POST "$URL/columns" -F "file=@$DATA")
[ "$(echo "$C" | jqp "d['n_rows']")" = "24" ] \
  && ok "/columns: 24 rows" || bad "/columns rows: $C"
[ "$(echo "$C" | jqp "len(d['columns'])")" = "3" ] \
  && ok "/columns: 3 columns" || bad "/columns count: $C"

# Build inline JSON bodies from the same file.
"$PY" - "$DATA" "$WORK" <<'EOF'
import csv, json, sys
path, work = sys.argv[1], sys.argv[2]
rows, cols = [], {}
with open(path, encoding="utf-8-sig") as fh:
    for r in csv.DictReader(fh, delimiter=";"):
        row = {k: float(v) for k, v in r.items()}
        rows.append(row)
        for k, v in row.items():
            cols.setdefault(k, []).append(v)
params = dict(conc_lvl="Concentration_level_perc",
              conc_sol="Concentration_of_solution_mg_ml",
              pk_area="Peak_area_mAU_min", ref_conc=0.15)
json.dump({"data": rows, **params},  open(f"{work}/records.json", "w"))
json.dump({"data": cols, **params},  open(f"{work}/columns.json", "w"))
json.dump({"data": rows, **params, "sections": ["Linear Regression Results",
           "Homoscedasticity Assessment (ANVISA)"], "author_name": "Smoke",
           "author_id": "TEST"}, open(f"{work}/report_subset.json", "w"))
EOF

CJ=$(curl -sS -X POST "$URL/columns/json" -H 'Content-Type: application/json' \
     -d "$("$PY" -c "import json;print(json.dumps({'data':json.load(open('$WORK/records.json'))['data']}))")")
[ "$(echo "$CJ" | jqp "d['n_rows']")" = "24" ] \
  && ok "/columns/json: 24 rows" || bad "/columns/json: $CJ"

# ---------------------------------------------------------------- analysis
head_ "3. Analysis"
curl -sS -X POST "$URL/analyze" -F "file=@$DATA" "${FORM[@]}" -o "$WORK/file.json"
R2=$(jqp "repr(d['model']['glance']['r_squared'])" < "$WORK/file.json")
SL=$(jqp "repr(d['model']['coefficients'][1]['estimate'])" < "$WORK/file.json")
[ "$R2" = "$EXPECT_R2" ] && ok "/analyze R2 = $R2" \
  || bad "/analyze R2 drifted: got $R2, expected $EXPECT_R2"
[ "$SL" = "$EXPECT_SLOPE" ] && ok "/analyze slope = $SL" \
  || bad "/analyze slope drifted: got $SL, expected $EXPECT_SLOPE"

curl -sS -X POST "$URL/analyze/json" -H 'Content-Type: application/json' \
     -d @"$WORK/records.json" -o "$WORK/rec.json"
curl -sS -X POST "$URL/analyze/json" -H 'Content-Type: application/json' \
     -d @"$WORK/columns.json" -o "$WORK/col.json"

# The strongest check here: both inline forms must reproduce the upload path
# exactly, not merely return 200.
if "$PY" -c "
import json,sys
w='$WORK'
f=json.load(open(w+'/file.json')); r=json.load(open(w+'/rec.json')); c=json.load(open(w+'/col.json'))
ks=('model','plots','report_tables')
sys.exit(0 if all(f[k]==r[k] for k in ks) and all(f[k]==c[k] for k in ks) else 1)"; then
  ok "inline JSON (records + columns) identical to file upload"
else
  bad "inline JSON differs from file upload"
fi

# With no column names at all, the three must map to the numeric columns in
# order of appearance and give the same answer as naming them explicitly.
# ref_conc must match the explicit run, or y_at_ref alone would differ.
curl -sS -X POST "$URL/analyze" -F "file=@$DATA" -F "ref_conc=0.15" \
  -o "$WORK/pos.json"
if "$PY" -c "
import json,sys
w='$WORK'
a=json.load(open(w+'/file.json')); b=json.load(open(w+'/pos.json'))
auto=set(b['inputs'].get('auto_mapped') or [])
same=(a['model']==b['model']
      and b['inputs']['conc_lvl']==a['inputs']['conc_lvl']
      and b['inputs']['conc_sol']==a['inputs']['conc_sol']
      and b['inputs']['pk_area']==a['inputs']['pk_area'])
sys.exit(0 if same and auto=={'conc_lvl','conc_sol','pk_area'} else 1)"; then
  ok "positional mapping matches explicit column names"
else
  bad "positional mapping differs from explicit column names"
fi

NP=$(jqp "len(d['plots']['regression']['smooth']['x'])" < "$WORK/file.json")
[ "$NP" = "80" ] && ok "plot geometry present (80-point smooth)" \
  || bad "smooth grid: expected 80 points, got $NP"

# ------------------------------------------------------------------ report
head_ "4. Word report"
expect_code "/report returns 200" 200 -X POST "$URL/report" -F "file=@$DATA" "${FORM[@]}"
curl -sS -X POST "$URL/report" -F "file=@$DATA" "${FORM[@]}" \
     -F "author_name=Smoke" -F "author_id=TEST" -o "$WORK/full.docx"
curl -sS -X POST "$URL/report/json" -H 'Content-Type: application/json' \
     -d @"$WORK/report_subset.json" -o "$WORK/subset.docx"

check_docx() {  # <file> <expected headings> <expected images> <label>
  "$PY" - "$1" "$2" "$3" <<'EOF'
import re, sys, zipfile
path, want_h, want_i = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
try:
    with zipfile.ZipFile(path) as z:
        x = z.read("word/document.xml").decode("utf8")
except Exception as e:
    print(f"unreadable docx: {e}"); sys.exit(1)
h = len(re.findall(r"<w:p\b(?:(?!</w:p>).)*?Heading1(?:(?!</w:p>).)*?</w:p>", x, re.S))
i = x.count("<a:blip")
if h == want_h and i == want_i:
    print(f"{h} headings, {i} images"); sys.exit(0)
print(f"expected {want_h} headings / {want_i} images, got {h} / {i}"); sys.exit(1)
EOF
}

if OUT=$(check_docx "$WORK/full.docx" 5 5); then
  ok "full report: $OUT"
else
  bad "full report: $OUT"
fi
if OUT=$(check_docx "$WORK/subset.docx" 3 0); then
  ok "subset report (2 table sections): $OUT"
else
  bad "subset report: $OUT"
fi

# ------------------------------------------------------------- plot rebuild
head_ "5. Local plot rebuild"
if "$PY" "$ROOT/api/client/plots.py" "$WORK/file.json" --outdir "$WORK/figs" \
     >/dev/null 2>&1; then
  n=$(ls "$WORK/figs"/*.png 2>/dev/null | wc -l)
  [ "$n" = "5" ] && ok "rebuilt 5 figures from JSON" \
    || bad "expected 5 figures, got $n"
else
  bad "plots.py failed (is matplotlib installed in api/.venv?)"
fi

# ------------------------------------------------------------ error handling
head_ "6. Error handling"
expect_code "unknown column -> 422" 422 -X POST "$URL/analyze" -F "file=@$DATA" \
  -F "conc_lvl=Nope" -F "conc_sol=Concentration_of_solution_mg_ml" \
  -F "pk_area=Peak_area_mAU_min"
echo "x" > "$WORK/bad.txt"
expect_code "wrong file type -> 415" 415 -X POST "$URL/columns" -F "file=@$WORK/bad.txt"
# Swagger UI submits an untouched array field as a single empty string, and
# a ValidationError raised in an endpoint body used to escape as a 500.
expect_code "blank sections -> 200 (not 422)" 200 -X POST "$URL/report" \
  -F "file=@$DATA" "${FORM[@]}" -F "sections="
expect_code "bad style -> 422 (not 500)" 422 -X POST "$URL/analyze" \
  -F "file=@$DATA" "${FORM[@]}" -F "style=garbage"
expect_code "unknown section -> 422" 422 -X POST "$URL/report/json" \
  -H 'Content-Type: application/json' \
  -d "$("$PY" -c "import json;b=json.load(open('$WORK/records.json'));b['sections']=['Bogus'];print(json.dumps(b))")"
printf 'lvl;conc;area\n1;0.1;10\n2;0.2;20\n3;0.3;30\n' > "$WORK/norep.csv"
expect_code "no replicates -> 422" 422 -X POST "$URL/analyze" -F "file=@$WORK/norep.csv" \
  -F "conc_lvl=lvl" -F "conc_sol=conc" -F "pk_area=area"

# ----------------------------------------------------------------- summary
head_ "Summary"
printf '  %d passed, %d failed\n\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
