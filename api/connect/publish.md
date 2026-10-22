# Publishing to Posit Connect

Option A from `api/DEPLOYMENT.md`: both tiers as Connect content, alongside
the existing Shiny app and without touching it.

```
Connect ├── Linearity        (shiny)         ← existing, untouched
        ├── linearity-r      (api)           ← api/r/plumber.R
        └── linearity-api    (python-fastapi)← api/python/main.py
```

Manifests are **not committed**: `rsconnect` writes the exact package
versions found in the library at the moment it runs, so a stale manifest
would pin whatever was installed the day it was generated. Generate them at
publish time.

---

## Before you start

- [ ] Connect has a Python runtime with FastAPI content enabled. If not, this
      becomes Option B (plumber only) — see `api/DEPLOYMENT.md` §4.
- [ ] You can publish content and read your own API key.
- [ ] You know which LDAP group may use the app, to mirror it on the API.

---

## 1. The R tier

`plumber` is deliberately absent from `renv.lock`, so the manifest must be
written from a library where it *is* installed — which `api/setup.sh`
arranges.

```r
# from the repo root
rsconnect::writeManifest(
  appDir      = ".",
  appPrimaryDoc = "api/r/plumber.R",
  appFiles    = c(
    "api/r/plumber.R", "api/r/analysis.R", "api/r/report.R",
    list.files("R", full.names = TRUE),
    "www/template_officer.docx"
  )
)
```

`rsconnect` itself is not installed by `setup.sh` — the lockfile pins a
version the public snapshot lacks. Install any recent one first:

```r
renv::install("rsconnect")
```

Then publish the bundle, and set on the content:

| Setting | Value |
|---|---|
| Access | the FastAPI tier's service account only |
| `LINEARITY_ROOT` | the content's working directory |
| `LINEARITY_R_API_KEY` | optional; Connect access control is the real gate |

**Do not** make this tier accessible to users. It runs the analysis with no
checks of its own.

## 2. The FastAPI tier

```bash
rsconnect deploy fastapi \
  --entrypoint main:app \
  --title "Linearity API" \
  api/python
```

Environment:

| Variable | Value |
|---|---|
| `LINEARITY_R_BACKEND` | the R tier's content URL |
| `LINEARITY_R_API_KEY` | a Connect API key that can reach the R tier |
| `LINEARITY_REQUIRE_AUTH` | `1` |
| `LINEARITY_ROOT` | only if R runs on the same host |

Access: the same LDAP group that may use the Shiny app. That is how the
app's authorisation rules get applied to the API — see `DEPLOYMENT.md` §5.

## 3. Verify

```bash
curl -H "Authorization: Key $CONNECT_API_KEY" https://<connect>/<api>/health
curl -H "Authorization: Key $CONNECT_API_KEY" https://<connect>/<api>/whoami
```

`/health` reports whether the R tier is reachable and what the auth posture
is. **`/whoami` is the one that matters here**: it echoes back the identity
that actually arrived, so you can confirm the header your Connect sets
rather than trusting the default.

If `authenticated` is `false` but `identity_like_headers_present` lists
something, set `LINEARITY_IDENTITY_HEADER` to that name and redeploy.

Then run the suite against it:

```bash
./api/smoke_test.sh https://<connect>/<api>
```

Expect the identity checks to exercise the real thing rather than a
simulated header.

---

## Notes

**Concurrency.** One R process serves one analysis at a time. Raise the R
tier's max processes in Connect if you need more; the FastAPI tier is async
and is not the bottleneck.

**Author identity.** With `LINEARITY_REQUIRE_AUTH=1`, the report footer is
taken from the authenticated principal and the `author_name` / `author_id`
parameters are ignored. A caller cannot attribute a report to someone else.

**The Shiny app is unaffected.** Its `manifest.json` pins an explicit file
list that contains no `api/` paths, so its bundle does not change.
