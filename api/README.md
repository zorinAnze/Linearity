# Linearity REST API

A headless HTTP interface to the Linearity app's analysis. Upload a data file,
name the three columns, get JSON back.

Nothing in `app.R` or `R/` is modified. The API calls the app's own functions,
so its numbers are the app's numbers.

## Layout

```
api/
  r/analysis.R      run_analysis(): the app's pipeline, no Shiny, no ava2
  r/report.R        build_report(): the app's Word report, same template
  r/plumber.R       internal R service (loopback only, no auth)
  r/run_backend.R   starts the R service
  python/main.py    FastAPI: the public REST surface
  python/models.py  request schemas
  client/plots.py   redraw the report figures from a JSON response
  client/example.py worked end-to-end example
  run.sh            start both tiers
```

### Why two processes

R needs several seconds to start and load ~25 packages, which is too slow to
pay per request. The R service stays resident; FastAPI owns the REST contract,
validation, file handling and OpenAPI docs, and forwards to it over loopback.

The R service performs no authentication and must stay bound to `127.0.0.1`.
Anything public-facing belongs in front of FastAPI.

## Requirements

* **Python 3.10+** — `models.py` evaluates a PEP 604 union at import time, so
  3.9 and earlier cannot load it. Developed and tested on 3.10.12.
* **R 4.5.1** — pinned by `renv.lock`; Posit's Linux binaries are built per R
  minor version, so another R silently compiles everything from source.
* Ubuntu **20.04, 22.04 or 24.04**. `setup.sh` handles the differences.

### Ubuntu 20.04

Supported, with two accommodations `setup.sh` applies automatically:

* Focal ships Python 3.8, and deadsnakes dropped focal when it went EOL, so
  apt cannot supply a newer one. Setup installs [uv] and uses it to fetch a
  standalone CPython 3.12 — no sudo, and it only needs glibc 2.17+ (focal has
  2.31).
* Focal's `libgit2` is 0.28, below `git2r`'s `>= 1.0`, so `git2r` can neither
  be built there nor fetched as a binary (Posit has no focal build, for the
  same reason). Only `ava2` depends on it, and `ava2` is UI-only, so both are
  skipped. The API is unaffected; the Shiny app will not run on 20.04.

Everything else the API needs has a focal binary.

[uv]: https://docs.astral.sh/uv/

## Setting up a new machine

```bash
./api/setup.sh          # needs sudo; safe to re-run
```

Installs R 4.5.1 (the version `renv.lock` pins), the system libraries, the R
packages, `plumber`, and the Python venv. None of these live in git — the
repo carries `renv.lock` and `requirements.txt`, not the packages.

The package source is chosen automatically: the validated Novartis mirrors
when they're reachable (which also brings `ava2`, so the Shiny app runs too),
otherwise the public Posit snapshot described under *Environment notes*.

## Running

```bash
./api/run.sh            # both tiers; Ctrl-C stops them
./api/run.sh --stop     # clean up
```

Interactive docs at <http://127.0.0.1:8000/docs>.

## Testing

```bash
./api/smoke_test.sh              # against http://127.0.0.1:8000
./api/smoke_test.sh http://host:8000
```

18 checks across every endpoint; exits non-zero on any failure. Beyond status
codes it asserts the things that actually matter:

* R² and slope match known-good values for the shipped `Template.csv`, so a
  numerical regression fails the run rather than passing as a 200.
* Inline JSON (both records and columns) reproduces the file-upload result
  **exactly** across `model`, `plots` and `report_tables`.
* Generated `.docx` files are unzipped and inspected for the expected heading
  and image counts, full report and section subset alike.
* All five figures redraw from the JSON.
* Error paths return 415/422 rather than 500.

To run the tiers separately:

```bash
Rscript api/r/run_backend.R 8001
cd api/python && ../.venv/bin/uvicorn main:app --port 8000
```

| Variable | Default | Meaning |
|---|---|---|
| `LINEARITY_ROOT` | `/home/adnan/projects/shiny` | repo root (R side) |
| `LINEARITY_R_PORT` | `8001` | R backend port |
| `LINEARITY_API_PORT` | `8000` | FastAPI port |
| `LINEARITY_R_BACKEND` | `http://127.0.0.1:8001` | where FastAPI finds R |
| `LINEARITY_R_TIMEOUT` | `120` | per-request timeout, seconds |
| `LINEARITY_MAX_UPLOAD` | `26214400` | upload cap, bytes |
| `LINEARITY_R_API_KEY` | unset | credential sent to the R tier, and required by it when set |
| `LINEARITY_REQUIRE_AUTH` | unset | reject callers with no authenticated identity |
| `LINEARITY_IDENTITY_HEADER` | `RStudio-Connect-Credentials` | header carrying the authenticated user |

### Identity

Behind Posit Connect the platform authenticates the caller and forwards the
result in a header; `GET /whoami` echoes back what arrived, which is how you
confirm the header name for your deployment rather than assuming it.

When a request carries an identity, the Word report's author is taken from it
and the `author_name` / `author_id` parameters are ignored — a caller cannot
credit a validated report to someone else. With nothing configured the API
behaves exactly as before, which keeps local development unchanged.

See `api/connect/publish.md` for deployment.

## Endpoints

### `GET /health`

Reports this API and the R backend. `status` is `degraded` if R is unreachable.

Every endpoint that takes measurements comes in two forms: a multipart upload,
and a `/json` variant taking the points inline. They run the same code and
return identical results — pick whichever suits the caller.

| Upload a file | Post points inline |
|---|---|
| `POST /columns` | `POST /columns/json` |
| `POST /analyze` | `POST /analyze/json` |
| `POST /report` | `POST /report/json` |

### `POST /columns`

Multipart upload (`file`). Lists columns with type and distinct count —
the equivalent of the app's dropdowns. Call it first if you don't know the
column names.

### `POST /analyze`

Multipart upload plus form fields:

| Field | Required | Default | Meaning |
|---|---|---|---|
| `file` | yes | — | `.csv`, `.tsv` or `.xlsx` |
| `conc_lvl` | no | 1st numeric column | concentration *level* column (grouping for variance tests) |
| `conc_sol` | no | 2nd numeric column | concentration column (regression x) |
| `pk_area` | no | 3rd numeric column | response column (regression y) |
| `ref_conc` | no | `0` | reference concentration; `0` disables reference output |
| `ref_unit` | no | `mg/mL` | unit label |
| `lab_x`, `lab_y` | no | app defaults | axis labels |
| `plt_title` | no | `""` | title |
| `style` | no | `report` | `report` matches the Word report's sizing; `app` the larger on-screen sizing |

```bash
# Columns taken positionally -- nothing to name:
curl -X POST http://127.0.0.1:8000/analyze \
  -F "file=@www/Template.csv" -F "ref_conc=0.15"

# Or name them explicitly:
curl -X POST http://127.0.0.1:8000/analyze \
  -F "file=@www/Template.csv" \
  -F "conc_lvl=Concentration_level_perc" \
  -F "conc_sol=Concentration_of_solution_mg_ml" \
  -F "pk_area=Peak_area_mAU_min" \
  -F "ref_conc=0.15"
```

### Column resolution

Naming the three columns is optional. Any left blank are filled from the
**numeric** columns in order of appearance, skipping any column another
parameter already claims:

* `conc_lvl` → 1st numeric column
* `conc_sol` → 2nd numeric column
* `pk_area` → 3rd numeric column

Only numeric columns are candidates, so artefacts like the empty trailing
column a stray delimiter produces are never picked. Partial naming works —
name just `pk_area` and the other two fill in around it.

A name that *is* supplied but does not exist is an error rather than a silent
fallback, so typos surface instead of quietly analysing the wrong column.

`inputs.auto_mapped` in the response lists which parameters were inferred, and
`inputs.conc_lvl` / `conc_sol` / `pk_area` always echo the columns actually
used — worth recording, since the choice affects the numbers.

### `POST /analyze/json`

The same analysis with the points in the request body instead of a file.
`data` accepts **row records** (the usual shape):

```bash
curl -X POST http://127.0.0.1:8000/analyze/json \
  -H 'Content-Type: application/json' -d '{
    "data": [
      {"lvl": 70, "conc": 0.10495, "area": 57.133},
      {"lvl": 70, "conc": 0.10498, "area": 57.2796},
      {"lvl": 80, "conc": 0.11960, "area": 65.228}
    ],
    "conc_lvl": "lvl", "conc_sol": "conc", "pk_area": "area",
    "ref_conc": 0.15
  }'
```

or **equal-length columns**:

```jsonc
{ "data": { "lvl":  [70, 70, 80],
            "conc": [0.10495, 0.10498, 0.11960],
            "area": [57.133, 57.2796, 65.228] },
  "conc_lvl": "lvl", "conc_sol": "conc", "pk_area": "area" }
```

Column names go through R's `make.names()`, exactly as on file import, so
`"Peak Area"` becomes `Peak.Area`. The same sanitising is applied to
`conc_lvl` / `conc_sol` / `pk_area`, so you can pass the original spelling and
it will still match.

### `POST /report` and `POST /report/json`

Returns the **`.docx`** — the same document the app's "Generate Report" button
produces: same template, section order, page breaks and header/footer.

Beyond the `/analyze` fields:

| Field | Default | Meaning |
|---|---|---|
| `sections` | all four | sections to include; repeat the field (multipart) or pass an array (JSON) |
| `author_name`, `author_id` | `""` | footer identity — the app reads these from the SSO session, so supply them here |
| `file_name` | `YYMMDD_Report` | download filename, without extension |

Valid `sections` (also at `GET /report/sections`), in layout order:

1. `Linear Regression Results`
2. `Linear Regression Plot`
3. `Diagnostic Plots`
4. `Homoscedasticity Assessment (ANVISA)`

The data table is always included. Selection order is ignored — the report
always uses the order above, because its page breaks depend on which section
lands last.

```bash
curl -X POST http://127.0.0.1:8000/report \
  -F "file=@www/Template.csv" \
  -F "conc_lvl=Concentration_level_perc" \
  -F "conc_sol=Concentration_of_solution_mg_ml" \
  -F "pk_area=Peak_area_mAU_min" \
  -F "ref_conc=0.15" \
  -F "author_name=A Zorin" -F "author_id=NIBR123" \
  -F "sections=Linear Regression Results" \
  -F "sections=Diagnostic Plots" \
  -o report.docx
```

PDF is not offered. The app renders it through `www/report.Rmd`, which needs a
LaTeX toolchain; the Word branch needs nothing beyond `officer`.

## Response

```jsonc
{
  "meta":    { "app_version", "r_version", "generated_at", "n_obs", "formula" },
  "inputs":  { ...echoed parameters... },

  "model": {
    "coefficients": [ { "term", "estimate", "std_error", "statistic",
                        "p_value", "conf_low", "conf_high" } ],
    "glance":       { "r_squared", "adj_r_squared", "sigma", "statistic",
                      "p_value", "df", "df_residual", "deviance",
                      "logLik", "AIC", "BIC", "nobs" },
    "correlation_r", "y_at_ref",
    "anova":     [ { "term", "df", "sum_sq", "mean_sq", "statistic", "p_value" } ],
    "fitted":    [ ... ],
    "residuals": [ ... ]
  },

  "homoscedasticity": {
    "cochran":          { "statistic", "p_value", "method", "verdict" },
    "levene":           { ... },
    "fligner":          { ... },
    "shapiro_rstudent": { "statistic", "p_value", "method" }
  },

  "report_tables": {
    "linear_regression": [ { "label", "value" } ],
    "homoscedasticity":  [ { "label", "value" } ],
    "user_inputs":       [ { "label", "value" } ]
  },

  "plots": { "regression", "qq", "residuals_vs_x",
             "residual_histogram", "residuals_vs_order", "style" }
}
```

Two kinds of number come back, deliberately:

* **`model` / `homoscedasticity`** — full double precision, for computation.
* **`report_tables`** — strings formatted exactly as the Word report renders
  them. The app **truncates** rather than rounds (`trunc_number_char()`), with
  the decimal count varying by magnitude. Use these when a result has to match
  a report; use the raw values for anything downstream.

A `value` of `null` in a report table marks a section heading row (e.g. "Slope
of the regression line (a)"), matching the report's layout.

## Redrawing the figures

The API returns plot *geometry*, not images: the coordinates ggplot2 itself
computed, harvested via `ggplot_build()` — the 80-point smooth grid with its
confidence band, the histogram's bin edges, the Q-Q quantiles and fitted line,
and the rendered equation string. Redrawing from those reproduces the report's
figures without shipping PNGs.

```python
from plots import save_all, plot_all

result = httpx.post(".../analyze", files=..., data=...).json()
save_all(result, "figures/")      # five PNGs
figs = plot_all(result)           # or matplotlib Figures to tweak
```

```bash
python api/client/plots.py result.json --outdir figures --fmt pdf

# upload the file
python api/client/example.py www/Template.csv --ref-conc 0.15

# post the points inline, and fetch the Word report too
python api/client/example.py www/Template.csv --ref-conc 0.15 \
    --json --report report.docx --author-name "A Zorin" --author-id NIBR123
```

Figures: `regression`, `qq`, `residuals_vs_x`, `residual_histogram`,
`residuals_vs_order`.

Geometry is exact. Styling approximates `theme_bw()` — marker sizes and fonts
are a close visual match, not pixel-identical, because point sizes don't map
one-to-one between ggplot2 and matplotlib. Values ggplot censored for falling
outside a scale's limits arrive as `null` and are drawn as gaps, as ggplot
does.

## Errors

| Status | Cause |
|---|---|
| 415 | file extension not csv/tsv/xlsx |
| 413 | upload over the size cap |
| 422 | column missing, column not numeric, too few rows, <2 distinct x, a concentration level with no replicate, or an unknown report section |
| 500 | R reported a report file that is missing |
| 503 | R backend unreachable |
| 504 | R backend timed out |

Validation mirrors the app's UI guards: all three columns must be numeric, and
the variance tests need at least two replicates per concentration level.

## Environment notes

* R **4.5.1**, pinned to match `renv.lock`, installed via `rig`.
* Packages restored from the public Posit mirror snapshot **2025-09-11**, which
  matches 200 of the 202 locked packages exactly. All binaries, no compilation.
* Three lockfile packages are **not** installed: `ava2` (Novartis-internal,
  UI-only), `rsconnect` and `snowflakeauth` (deploy-only, versions unavailable
  publicly). None is needed for the analysis. `renv.lock` is unchanged;
  `renv::status()` will therefore report them missing, which is expected.
* `plumber` is installed in the project library but intentionally **not** added
  to `renv.lock`, to leave the validated lockfile untouched.
