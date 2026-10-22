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

## 5. Authentication and authorisation

The brief is to use the same approach and infrastructure as the Shiny app.
That is right for *identity*, but the app's mechanism cannot be reused
verbatim, and its *authorisation* layer has no counterpart in the API yet.

### How the app does it today

| Layer | Mechanism |
|---|---|
| Authentication | Platform SSO injects `window.NIBRIam` into the page; `www/auth.js` forwards it to Shiny as `input$current_user` |
| Authorisation | `ava2` reads `www/config.json` — division/department rules, plus allow/deny lists of 521 IDs |
| Identity in output | `app.R` takes `NIBRFull` / `NIBR521` from that input for the report footer |

### Why it does not transfer directly

**`window.NIBRIam` is a browser global.** It is injected into an HTML page and
read by JavaScript. An API client has no browser and no page, so there is
nothing to inject into. The same is true of any interactive SSO redirect: a
scripted caller cannot complete a login flow designed for a human.

This is a property of SSO generally, not a gap in the app. The standard
resolution is to keep the *identity provider* and change the *grant*:

| Caller | Grant |
|---|---|
| Human in a browser | SSO redirect, as now |
| Script or pipeline | API key or service-account token, issued against the same LDAP identity |

On Posit Connect that is its per-user API keys: a user signs in through SSO,
generates a key, and callers send `Authorization: Key …`. The key carries that
user's LDAP-derived identity and permissions, so access stays governed by the
same directory — no second user store.

If `window.NIBRIam` is injected by a Novartis layer in front of Connect rather
than by Connect itself, that layer is the authority and the API must integrate
with it instead. Worth confirming before building anything.

### The authorisation gap

`ava2` enforces `config.json`; `ava2` is **not installed for the API** — it is
UI-only and unavailable off the Novartis network. So the org/department rules
and the allow/deny lists currently govern the Shiny app and nothing else.

Three ways to close it, in rough order of preference:

1. **Platform-level.** Restrict the API's Connect content to the same LDAP
   group that may use the app. No application code, and the rule lives where
   the other access rules live.
2. **Gateway-level.** If a proxy already enforces `config.json`, put the API
   behind the same one.
3. **In the API.** Read `config.json` and apply the same checks to the
   authenticated principal. Only worth it if the rules must hold independently
   of where the API is hosted — and it duplicates logic that `ava2` owns.

### What this improves

Author identity is currently a request *parameter* — the caller asserts who
they are, and the report footer records whatever they send. Once calls are
authenticated, `author_name` and `author_id` should be derived from the
authenticated principal instead, with the parameters ignored or rejected.

In a validated context that matters: the report would then record who actually
ran the analysis rather than whoever typed a name. Connect forwards the
authenticated visitor's identity to content via request headers, which is the
hook for this; the exact header depends on the Connect version and should be
confirmed against yours.

**Not yet built.** Today the API authenticates nothing and trusts the author
parameters. Items 1 and 2 in §6 cover the work.

---

## 6. Before production

1. **Authentication.** Nothing authenticates today. Use the same LDAP
   identities as the app, with API keys rather than SSO redirects for
   programmatic callers — see §5.
2. **Authorisation.** `ava2` enforces `config.json` for the app and is not
   installed for the API, so those rules do not currently apply to it.
3. **The R tier must never be public.** It executes analysis requests with no
   checks. Loopback, or Connect access limited to the FastAPI service account.
4. **Author identity.** Derive it from the authenticated principal rather than
   trusting the `author_name` / `author_id` parameters.
5. **Upload cap.** `LINEARITY_MAX_UPLOAD` defaults to 25 MB.
6. **Concurrency.** One R process = one concurrent analysis. Size accordingly.
7. **`plumber` is not in `renv.lock`**, deliberately, so the validated
   lockfile stays as-validated. Connect restores from `manifest.json`, so the
   API's manifest must be generated with `plumber` present in the library.

---

## 7. Environment

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

## 8. Open questions

- Does your Connect have a Python runtime with FastAPI content enabled?
  This decides between Option A and Option B.
- Is `window.NIBRIam` injected by Connect, or by a Novartis layer in front of
  it? That layer is where the API must authenticate.
- Can service accounts or per-user API keys be issued against the same LDAP
  directory, and who owns issuing them?
- Should the `config.json` authorisation rules apply to the API, and if so,
  enforced at the platform or in the application?
- Expected request volume — does one R process suffice?
- Is PDF output needed later? That adds a LaTeX toolchain to the image.
