# Linearity API — design and deployment

How the API is built, what it guarantees, and how to put it on a server
already running the Shiny app.

---

## 1. What it is

A headless HTTP interface to the Linearity analysis. Upload measurements or
post them as JSON; get back regression results, variance tests, the Word
report's tables, and enough plot geometry to redraw every figure — or the
`.docx` itself.

**`app.R` and `R/` are unmodified.** The API calls the app's own functions, so
its numbers are the app's numbers. This was the governing constraint: a
second implementation of the statistics would have to be validated separately.

---

## 2. Building blocks

```
   client  ──HTTP──▶  FastAPI (Python)  ──HTTP──▶  plumber (R)  ──▶  R/*.R
                      public surface      loopback   warm process    app's own
                      :8000                          :8001           functions
```

| Component | File | Responsibility |
|---|---|---|
| REST surface | `api/python/main.py` | routing, uploads, validation, OpenAPI |
| Request schemas | `api/python/models.py` | typed request bodies |
| R service | `api/r/plumber.R` | HTTP wrapper, loopback only |
| Analysis | `api/r/analysis.R` | `run_analysis()` — the app's pipeline, headless |
| Report | `api/r/report.R` | `build_report()` — the app's Word branch |
| Plot rebuild | `api/client/plots.py` | redraw figures from the JSON |
| Setup | `api/setup.sh` | provision a machine from a bare clone |
| Tests | `api/smoke_test.sh` | 21 checks across every endpoint |

### Why two processes

R takes several seconds to start and load ~25 packages — too slow per
request. The R tier stays resident. Python owns the REST contract because
that was the requirement, and because FastAPI gives typed validation and
OpenAPI docs for free.

The cost is a second process to supervise. The alternative — `rpy2`
in-process — pins the service to one R build and serialises on R's
single-threadedness anyway.

---

## 3. Characteristics

**Fidelity.** The `R/` functions have no Shiny coupling, so they run unchanged.
Inline-JSON and file-upload paths produce byte-identical results; the smoke
test asserts this rather than assuming it.

**Two kinds of number.** `model` and `homoscedasticity` carry full double
precision. `report_tables` carry the strings the Word report renders — the app
**truncates** rather than rounds, so these differ by design. Use the former
for computation, the latter when a result must match a report.

**Plots as geometry, not images.** The response carries the coordinates
ggplot itself computed (via `ggplot_build()`): the 80-point smooth grid with
its confidence band, histogram bin edges, Q-Q quantiles, the rendered equation
string. Clients redraw locally; the API ships no PNGs.

**Columns are optional.** Unnamed columns map to the numeric columns in order
of appearance. A *supplied* name that doesn't exist is an error, not a silent
fallback, so typos surface. `inputs.auto_mapped` records what was inferred.

**Single-threaded R.** plumber handles one request at a time. A run is ~1.7 s
(analysis) to ~2.7 s (report), so one process serves modest throughput;
concurrency needs more R processes behind a load balancer.

**No authentication.** Both tiers bind to `127.0.0.1`. This is correct for
local use and **must change before production** — see §5.

**Not offered: PDF reports.** That path renders through `www/report.Rmd` and
needs a LaTeX toolchain. The Word branch needs only `officer`.

---

## 4. Deploying alongside the existing Shiny app

The app is deployed to **Posit Connect** (`manifest.json`, `appmode: shiny`).
Deploying the API does not touch it: Connect content items are independent,
with their own environments. The Shiny app keeps its own `ava2` and renv
restore.

Three viable shapes, best first.

### Option A — both tiers as Connect content *(recommended)*

Connect hosts plumber APIs (`appmode: api`) and FastAPI (`appmode:
python-fastapi`) natively. You get authentication, TLS, process supervision
and scaling from the platform rather than building them.

```
Connect ├── Linearity (shiny)        ← existing, untouched
        ├── linearity-r   (api)      ← api/r/plumber.R
        └── linearity-api (fastapi)  ← api/python/main.py
```

1. Publish the R tier, note its content URL, and give it an API key.
2. Publish the FastAPI tier with `LINEARITY_R_BACKEND` set to that URL.
3. Restrict the R tier's access to the FastAPI tier's service account.

**Check first:** Connect must have a Python runtime configured and FastAPI
content enabled. If Python content isn't available, Option A collapses to
Option B.

**Change needed:** `_call_r()` must send the Connect API key as an
`Authorization` header. It's a few lines, but it isn't written yet.

### Option B — plumber only, no Python tier

Publish `api/r/plumber.R` as Connect content and let clients call it
directly. Simplest path: one content item, one language, Connect handles
auth. You lose the Python REST surface, its validation and its OpenAPI docs,
and the request contract becomes plumber's.

Worth considering if the Python tier is not itself a requirement.

### Option C — sidecar service on a VM

Run `./api/setup.sh` and `./api/run.sh` on a host next to Connect, behind
nginx with TLS and auth, both tiers under systemd.

Most control, most to maintain: you own the TLS, auth, restarts, log rotation
and patching that Connect would otherwise provide. Choose this only if the
API cannot live on Connect.

| | A: both on Connect | B: plumber only | C: sidecar VM |
|---|---|---|---|
| Auth, TLS | platform | platform | you build it |
| Python REST surface | yes | no | yes |
| Moving parts | 2 content items | 1 content item | VM + 2 services |
| Code changes | API-key header | none | none |

---

## 5. Before production

1. **Authentication.** Nothing authenticates today. On Connect this is
   platform config; on a VM it is nginx plus a credential scheme.
2. **The R tier must never be public.** It executes analysis requests with no
   checks. Loopback, or Connect access limited to the FastAPI service account.
3. **Author identity.** The app reads it from the SSO session; the API takes
   `author_name` / `author_id` as parameters. Decide who supplies them, or the
   report footer renders empty.
4. **Upload cap.** `LINEARITY_MAX_UPLOAD` defaults to 25 MB.
5. **Concurrency.** One R process = one concurrent analysis. Size accordingly.
6. **`plumber` is not in `renv.lock`**, deliberately, so the validated
   lockfile stays as-validated. Connect restores from `manifest.json`, so the
   API's manifest must be generated with `plumber` present in the library.

---

## 6. Environment

| | |
|---|---|
| R | 4.5.1, pinned by `renv.lock` |
| Python | 3.10+ (3.8 and 3.9 cannot import `models.py`) |
| Ubuntu | 20.04, 22.04, 24.04 — `setup.sh` handles the differences |
| R packages | 194 in the project library (190 restored from the 203 locked, plus `plumber` and its three dependencies; R's recommended packages come from R itself). The API's dependency closure is 122. |

Not installed, and not needed by the API: `ava2` (Novartis-internal, UI only),
`rsconnect` and `snowflakeauth` (deploy-only). On Ubuntu 20.04 `git2r` is also
skipped — focal's `libgit2` is too old to build it, and only `ava2` wants it.
`renv::status()` will report these as missing: expected, not drift.

**The Shiny app will not run on Ubuntu 20.04** (no `ava2` without `git2r`).
The API will. On 22.04 both work.

---

## 7. Open questions

- Does your Connect have a Python runtime with FastAPI content enabled?
  This decides between Option A and Option B.
- Who supplies `author_name` / `author_id` in an automated workflow?
- Expected request volume — does one R process suffice?
- Is PDF output needed later? That adds a LaTeX toolchain to the image.
