#!/usr/bin/env python3
"""End-to-end example: call the Linearity API and redraw its figures.

    # upload the file
    python api/client/example.py www/Template.csv --ref-conc 0.15

    # post the points inline as JSON instead, and fetch the Word report
    python api/client/example.py www/Template.csv --ref-conc 0.15 \
        --json --report report.docx
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any

import httpx

from plots import save_all

DEFAULT_URL = "http://127.0.0.1:8000"


def read_rows(path: Path) -> list[dict[str, Any]]:
    """Read a delimited file into row records, as the API's `data` field wants.

    Mirrors the app's delimiter sniffing. `utf-8-sig` matters: the shipped
    template carries a BOM, which would otherwise corrupt the first header.
    """
    if path.suffix.lower() == ".xlsx":
        raise SystemExit("--json reads csv/tsv only; upload .xlsx without --json.")

    with path.open(encoding="utf-8-sig") as fh:
        first = fh.readline()
        delim = "\t" if path.suffix.lower() == ".tsv" else (";" if ";" in first else ",")
        fh.seek(0)
        rows = []
        for raw in csv.DictReader(fh, delimiter=delim):
            row: dict[str, Any] = {}
            for k, v in raw.items():
                try:
                    row[k] = float(v)
                except (TypeError, ValueError):
                    row[k] = v
            rows.append(row)
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("datafile", help="csv, tsv or xlsx measurement file")
    ap.add_argument("--url", default=DEFAULT_URL)
    ap.add_argument("--conc-lvl", default="Concentration_level_perc")
    ap.add_argument("--conc-sol", default="Concentration_of_solution_mg_ml")
    ap.add_argument("--pk-area", default="Peak_area_mAU_min")
    ap.add_argument("--ref-conc", type=float, default=0.0)
    ap.add_argument("--ref-unit", default="mg/mL")
    ap.add_argument("--title", default="")
    ap.add_argument("--outdir", default="figures")
    ap.add_argument("--save-json", default="result.json")
    ap.add_argument(
        "--json", action="store_true",
        help="Post the points inline as JSON instead of uploading the file.",
    )
    ap.add_argument(
        "--report", metavar="PATH",
        help="Also download the Word report to PATH.",
    )
    ap.add_argument(
        "--section", action="append", dest="sections", metavar="NAME",
        help="Report section to include; repeatable. Default: all.",
    )
    ap.add_argument("--author-name", default="")
    ap.add_argument("--author-id", default="")
    args = ap.parse_args()

    path = Path(args.datafile)
    params = {
        "conc_lvl": args.conc_lvl,
        "conc_sol": args.conc_sol,
        "pk_area": args.pk_area,
        "ref_conc": args.ref_conc,
        "ref_unit": args.ref_unit,
        "plt_title": args.title,
    }

    with httpx.Client(base_url=args.url, timeout=180) as client:
        # 1. Inspect the columns, as the app's dropdowns would.
        if args.json:
            rows = read_rows(path)
            cols = client.post("/columns/json", json={"data": rows})
        else:
            with path.open("rb") as fh:
                cols = client.post("/columns", files={"file": (path.name, fh)})
        cols.raise_for_status()
        print(f"{path.name}: {cols.json()['n_rows']} rows")
        for c in cols.json()["columns"]:
            print(f"  {c['name']:38} {c['type']:9} distinct={c['n_distinct']}")

        # 2. Run the analysis.
        if args.json:
            resp = client.post("/analyze/json",
                               json={"data": rows, "style": "report", **params})
        else:
            with path.open("rb") as fh:
                resp = client.post("/analyze", files={"file": (path.name, fh)},
                                   data={"style": "report", **params})
        if resp.status_code >= 400:
            raise SystemExit(f"API error {resp.status_code}: {resp.text}")
        result = resp.json()

        # 3. Optionally fetch the Word report.
        if args.report:
            extras = {"author_name": args.author_name, "author_id": args.author_id}
            if args.json:
                body = {"data": rows, **params, **extras}
                if args.sections:
                    body["sections"] = args.sections
                rep = client.post("/report/json", json=body)
            else:
                # httpx emits repeated multipart fields from a list value.
                form: dict[str, Any] = {
                    k: str(v) for k, v in {**params, **extras}.items()
                }
                if args.sections:
                    form["sections"] = args.sections
                with path.open("rb") as fh:
                    rep = client.post("/report", files={"file": (path.name, fh)},
                                      data=form)
            if rep.status_code >= 400:
                raise SystemExit(f"Report error {rep.status_code}: {rep.text}")
            Path(args.report).write_bytes(rep.content)
            print(f"\nReport written to {args.report} ({len(rep.content):,} bytes)")

    # 4. Headline numbers.
    g = result["model"]["glance"]
    slope = next(c for c in result["model"]["coefficients"]
                 if c["term"] != "(Intercept)")
    icept = next(c for c in result["model"]["coefficients"]
                 if c["term"] == "(Intercept)")
    print(f"\nR^2       {g['r_squared']:.8f}")
    print(f"slope     {slope['estimate']:.8f}  (p = {slope['p_value']:.3e})")
    print(f"intercept {icept['estimate']:.8f}  (p = {icept['p_value']:.5f})")
    if result["model"]["y_at_ref"] is not None:
        print(f"y at ref  {result['model']['y_at_ref']:.8f}")

    print("\nVariance tests:")
    for name, t in result["homoscedasticity"].items():
        print(f"  {name:18} p = {t['p_value']:.4g}  {t.get('verdict', '')}")

    print("\nReport table (linear regression):")
    for row in result["report_tables"]["linear_regression"]:
        print(f"  {row['label']:45} {row['value'] or ''}")

    # 5. Redraw the report's figures locally.
    paths = save_all(result, args.outdir)
    print(f"\nFigures written to {args.outdir}/:")
    for p in paths:
        print(f"  {p.name}")

    Path(args.save_json).write_text(json.dumps(result, indent=2))
    print(f"\nFull JSON saved to {args.save_json}")


if __name__ == "__main__":
    main()
