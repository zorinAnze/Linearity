# Linearity API — local deployment and testing

## 1. Start it

```bash
cd ~/projects/shiny
./api/run.sh
```

Ready in ~4 seconds. It starts both tiers, waits for R to finish loading before bringing up FastAPI, and `Ctrl-C` stops both. If R dies during startup it prints the last 20 log lines and exits rather than leaving you with a half-up stack.

```
==> R backend  : http://127.0.0.1:8001  (log: api/logs/r_backend.log)
    ready.
==> FastAPI    : http://127.0.0.1:8000  (docs at /docs)
```

To run it detached: `nohup ./api/run.sh > api/logs/run.log 2>&1 &`, and `./api/run.sh --stop` to clean up.

## 2. Test it

```bash
./api/smoke_test.sh
```

18 checks, exits non-zero on failure. It asserts more than status codes — a 200 that returns wrong numbers is the failure mode that matters here. It pins R² and slope to known-good values for `Template.csv`, verifies inline JSON reproduces the upload path *exactly*, unzips the generated `.docx` files to count headings and images, redraws all five figures, and confirms errors come back as 415/422 rather than 500.

If the stack is down it tells you so and stops, instead of cascading 17 failures.

## 3. Poke at it by hand

The interactive docs at **http://127.0.0.1:8000/docs** are the easiest way in — every endpoint has a "Try it out" button with `Template.csv`-shaped examples prefilled.

For a full round trip from the command line:

```bash
cd api/client
../.venv/bin/python example.py ../../www/Template.csv \
    --json --ref-conc 0.15 --title "Linearity Report" \
    --author-name "A Zorin" --author-id NIBR123 \
    --report report.docx
```

That inspects columns, runs the analysis, prints headline numbers and the report table, downloads the `.docx`, and writes all five PNGs — exercising every piece in one go. Drop `--json` to use file upload instead.

## After a reboot

`./api/run.sh` is all you need. R 4.5.1 and the 190 packages are installed on disk, and the venv persists. The system install script was a one-time thing.

## Troubleshooting

**`API unreachable`** — not running, or the R tier died. Check `api/logs/r_backend.log`.

**404 at `http://127.0.0.1:8000`** — expected. Uvicorn prints the bare base URL, but the API serves `/docs`, `/health`, `/analyze` and so on; `/` only redirects there. Go to **`/docs`**.

**`Column '…' not found`** — the name you gave isn't in the file. You can leave `conc_lvl` / `conc_sol` / `pk_area` **blank**, in which case they map to the 1st, 2nd and 3rd numeric columns in order of appearance. `POST /columns` lists what's available.

**Port already in use** — `./api/run.sh --stop`, or override: `LINEARITY_API_PORT=8080 ./api/run.sh`.

**`renv::status()` complains about missing packages** — expected, not drift. `ava2`, `rsconnect` and `snowflakeauth` are deliberately not installed; none affects the analysis.

**Slow first request after startup** — shouldn't happen, since `run.sh` waits on the health probe before exposing FastAPI. If you start the tiers manually, give R ~7 seconds.

## Security caveat

Both tiers bind to `127.0.0.1` and there is **no authentication anywhere**. That's correct for local use. Before this goes anywhere other machines can reach, it needs auth in front of FastAPI, and the R tier must stay on loopback regardless — it executes analysis requests with no checks at all.
