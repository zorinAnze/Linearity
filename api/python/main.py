"""Linearity REST API.

Public HTTP surface for the Linearity Shiny app's analysis. Upload a data
file, name the three columns, get JSON back: regression results, variance
tests, the Word report's tables as rendered strings, and enough plot geometry
to redraw every figure locally (see api/client/plots.py).

Runs in front of a warm R backend (api/r/plumber.R) which executes the app's
own functions from R/. R startup costs several seconds, so it stays resident
rather than being spawned per request.
"""

from __future__ import annotations

import os
import shutil
import tempfile
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import datetime as dt
import re

import httpx
from fastapi import (
    Depends, FastAPI, File, Form, HTTPException, Request, UploadFile,
)
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.openapi.utils import get_openapi
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from pydantic import ValidationError
from starlette.background import BackgroundTask

from identity import (
    IDENTITY_HEADER,
    REQUIRE_AUTH,
    Principal,
    current_principal,
    from_request,
    resolve_author,
)
from models import (
    REPORT_SECTIONS,
    _usable_sections,
    AnalysisParams,
    AnalyzeJsonRequest,
    ColumnsJsonRequest,
    ColumnsResponse,
    ErrorResponse,
    HealthResponse,
    ReportJsonRequest,
)

# Leave these blank and the columns are taken positionally -- see
# resolve_columns() in api/r/analysis.R. Deliberately no OpenAPI `example`:
# Swagger UI prefills inputs from it, and a plausible-looking default column
# name is easy to submit by reflex and harder to spot than a wrong one.
_POSITIONAL = (
    " Leave blank to use the {ord} numeric column in the file, in order of "
    "appearance. Call /columns to list them."
)
CONC_LVL_DESC = (
    "Column holding the concentration LEVEL -- the grouping variable for the "
    "variance tests." + _POSITIONAL.format(ord="1st")
)
CONC_SOL_DESC = (
    "Column holding the concentration, the regression x."
    + _POSITIONAL.format(ord="2nd")
)
PK_AREA_DESC = (
    "Column holding the response, the regression y."
    + _POSITIONAL.format(ord="3rd")
)

DOCX_MEDIA_TYPE = (
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
)

API_VERSION = "1.0.0"
R_BACKEND = os.environ.get("LINEARITY_R_BACKEND", "http://127.0.0.1:8001")
ALLOWED_EXT = {".csv", ".tsv", ".xlsx"}
MAX_UPLOAD_BYTES = int(os.environ.get("LINEARITY_MAX_UPLOAD", 25 * 1024 * 1024))

# R is single-threaded: plumber handles one request at a time. A generous
# per-request timeout matters more than concurrency here.
R_TIMEOUT = httpx.Timeout(float(os.environ.get("LINEARITY_R_TIMEOUT", 120)))

# Credential for the hop to the R tier. On Connect this is a Connect API key;
# on a sidecar it is a shared secret the plumber filter checks. Unset means
# loopback with nothing in between, which is the local-development case.
R_API_KEY = os.environ.get("LINEARITY_R_API_KEY", "")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Connect expects "Key <value>"; a plain shared secret is sent as-is.
    headers = {}
    if R_API_KEY:
        headers["Authorization"] = (
            R_API_KEY if R_API_KEY.lower().startswith(("key ", "bearer "))
            else f"Key {R_API_KEY}"
        )
    app.state.http = httpx.AsyncClient(
        base_url=R_BACKEND, timeout=R_TIMEOUT, headers=headers
    )
    try:
        yield
    finally:
        await app.state.http.aclose()


app = FastAPI(
    title="Linearity API",
    version=API_VERSION,
    lifespan=lifespan,
    description=__doc__,
)


def _as_binary_uploads(node: Any) -> Any:
    """Rewrite 3.1-style binary declarations to the 3.0 spelling.

    FastAPI emits `{"type": "string", "contentMediaType": "application/
    octet-stream"}` for an upload. Swagger UI renders that as a plain text
    box, so the bytes get submitted as a string with no filename and
    Starlette rejects them ("Expected UploadFile, received: <class 'str'>").
    `{"type": "string", "format": "binary"}` is the spelling it renders as a
    file-picker button.
    """
    if isinstance(node, dict):
        if (
            node.get("type") == "string"
            and node.get("contentMediaType") == "application/octet-stream"
        ):
            node = {k: v for k, v in node.items() if k != "contentMediaType"}
            node["format"] = "binary"
            return node
        node = {k: _as_binary_uploads(v) for k, v in node.items()}
        # Schema-level `examples: [...]` is 3.1 syntax; 3.0 uses `example`,
        # which is also the key Swagger UI prefills its inputs from. (A
        # Media Type Object's `examples` is a map, so only rewrite lists.)
        if isinstance(node.get("examples"), list) and node["examples"]:
            node["example"] = node.pop("examples")[0]
        return node
    if isinstance(node, list):
        return [_as_binary_uploads(v) for v in node]
    return node


def _collapse_nullable(node: Any) -> Any:
    """Turn 3.1's `anyOf: [X, {type: null}]` into 3.0's `X + nullable: true`.

    An optional field such as `list[str] | None` is emitted as a null union,
    which OpenAPI 3.0 has no notion of -- it spells nullability with a
    keyword. Collapsing also lifts the real schema to the top level, so
    `items` sits where other tooling expects it.
    """
    if isinstance(node, dict):
        node = {k: _collapse_nullable(v) for k, v in node.items()}
        any_of = node.get("anyOf")
        if isinstance(any_of, list) and len(any_of) == 2:
            non_null = [
                s for s in any_of
                if not (isinstance(s, dict) and s.get("type") == "null")
            ]
            if len(non_null) == 1 and isinstance(non_null[0], dict):
                rest = {k: v for k, v in node.items() if k != "anyOf"}
                return {**non_null[0], **rest, "nullable": True}
        return node
    if isinstance(node, list):
        return [_collapse_nullable(v) for v in node]
    return node


def _enumerate_sections(node: Any) -> Any:
    """Constrain the `sections` form field to the valid values.

    Swagger renders an enum as a dropdown, so the placeholder text cannot be
    submitted in the first place. The server still accepts plain strings, so
    non-browser clients are unaffected.
    """
    if isinstance(node, dict):
        sections = node.get("properties", {}).get("sections")
        if isinstance(sections, dict):
            items = sections.get("items")
            if isinstance(items, dict) and items.get("type") == "string":
                items["enum"] = list(REPORT_SECTIONS)
        return {k: _enumerate_sections(v) for k, v in node.items()}
    if isinstance(node, list):
        return [_enumerate_sections(v) for v in node]
    return node


def _openapi() -> dict[str, Any]:
    if app.openapi_schema:
        return app.openapi_schema
    schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
        openapi_version="3.0.3",
    )
    # Order matters: collapse null-unions first so `items` is lifted to
    # where the enum injection looks for it.
    schema = _collapse_nullable(schema)
    app.openapi_schema = _enumerate_sections(_as_binary_uploads(schema))
    return app.openapi_schema


app.openapi = _openapi  # type: ignore[method-assign]


def _save_upload(upload: UploadFile) -> Path:
    """Stream an upload to a temp file, enforcing extension and size limits."""
    suffix = Path(upload.filename or "").suffix.lower()
    if suffix not in ALLOWED_EXT:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type '{suffix or '(none)'}'. "
            f"Allowed: {', '.join(sorted(ALLOWED_EXT))}",
        )

    fd, tmp_path = tempfile.mkstemp(suffix=suffix, prefix="linearity_")
    size = 0
    try:
        with os.fdopen(fd, "wb") as out:
            while chunk := upload.file.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail=f"File exceeds {MAX_UPLOAD_BYTES} bytes.",
                    )
                out.write(chunk)
    except Exception:
        Path(tmp_path).unlink(missing_ok=True)
        raise
    return Path(tmp_path)


def _params(**kwargs: Any) -> AnalysisParams:
    """Build AnalysisParams from form fields.

    Pydantic only auto-converts validation errors to 422 while parsing the
    request; a ValidationError raised in the endpoint body would otherwise
    surface as a 500.
    """
    try:
        return AnalysisParams(**kwargs)
    except ValidationError as exc:
        raise HTTPException(
            status_code=422, detail=exc.errors(include_url=False)
        ) from exc


def _clean_sections(sections: list[str] | None) -> list[str]:
    """Normalise the `sections` form field, defaulting to every section."""
    return _usable_sections(sections or [])


async def _call_r(path: str, payload: dict[str, Any]) -> Any:
    """POST to the R backend, translating transport failures into 503."""
    try:
        resp = await app.state.http.post(path, json=payload)
    except httpx.ConnectError as exc:
        raise HTTPException(
            status_code=503,
            detail=f"R backend unreachable at {R_BACKEND}. "
            f"Start it with: Rscript api/r/run_backend.R ({exc})",
        ) from exc
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=504, detail=f"R backend timed out: {exc}"
        ) from exc

    body = resp.json()
    if resp.status_code >= 400:
        raise HTTPException(
            status_code=resp.status_code,
            detail=body.get("detail", body) if isinstance(body, dict) else body,
        )
    return body


@app.exception_handler(RequestValidationError)
async def _validation_handler(request: Request, exc: RequestValidationError):
    """Explain the "Expected UploadFile, received str" case in plain terms.

    It means the multipart part carried no filename, so the bytes were parsed
    as an ordinary form field. Raw errors echo the whole file back as `input`,
    which is unreadable when the file is binary.
    """
    for err in exc.errors():
        if "Expected UploadFile" in str(err.get("msg", "")):
            return JSONResponse(
                status_code=422,
                content={
                    "detail": "The 'file' part arrived without a filename, so "
                    "it was read as text rather than an upload. Use the file "
                    "picker in /docs (or `curl -F \"file=@path.csv\"`); "
                    "pasting the contents into the box will not work."
                },
            )
    # Anything else keeps FastAPI's own (useful) field-level detail.
    return JSONResponse(
        status_code=422,
        content={"detail": jsonable_encoder(exc.errors(), exclude={"input", "ctx"})},
    )


@app.get("/", include_in_schema=False)
async def root() -> RedirectResponse:
    """Send the bare base URL to the docs.

    Uvicorn prints http://127.0.0.1:8000 on startup, and there is otherwise
    nothing mounted there to greet someone who clicks it.
    """
    return RedirectResponse(url="/docs")


@app.get("/whoami", tags=["ops"])
async def whoami(request: Request) -> dict[str, Any]:
    """Report the identity this request carried, and where it came from.

    Use this to confirm which header your deployment actually sets before
    relying on it: the spelling varies by Connect version and by anything
    sitting in front of it.
    """
    principal = from_request(request)
    candidates = {
        name: value
        for name, value in request.headers.items()
        if "credential" in name.lower()
        or "user" in name.lower()
        or "auth" in name.lower()
    }
    return {
        "authenticated": principal is not None,
        "principal": principal.summary() if principal else None,
        "expected_header": IDENTITY_HEADER,
        "require_auth": REQUIRE_AUTH,
        # Values are redacted: an Authorization header would appear here.
        "identity_like_headers_present": sorted(candidates),
    }


@app.get("/health", response_model=HealthResponse, tags=["ops"])
async def health() -> HealthResponse:
    """Liveness of this API and of the R backend behind it."""
    try:
        resp = await app.state.http.get("/health")
        return HealthResponse(
            status="ok",
            api_version=API_VERSION,
            r_backend=resp.json(),
            auth={
                "require_auth": REQUIRE_AUTH,
                "identity_header": IDENTITY_HEADER,
                "r_backend_key_set": bool(R_API_KEY),
            },
        )
    except Exception as exc:
        return HealthResponse(
            status="degraded",
            api_version=API_VERSION,
            detail=f"R backend unreachable: {exc}",
        )


@app.post(
    "/columns",
    response_model=ColumnsResponse,
    tags=["analysis"],
    responses={415: {"model": ErrorResponse}},
)
async def columns(
    file: UploadFile = File(..., description="csv, tsv or xlsx"),
    principal: Principal | None = Depends(current_principal),
):
    """List a file's columns and types.

    Equivalent to the app's column dropdowns: call this first if you do not
    already know the column names, then pass them to `/analyze`.
    """
    tmp = _save_upload(file)
    try:
        return await _call_r(
            "/columns", {"path": str(tmp), "ext": tmp.suffix.lstrip(".")}
        )
    finally:
        tmp.unlink(missing_ok=True)


@app.post(
    "/analyze",
    tags=["analysis"],
    responses={
        415: {"model": ErrorResponse},
        422: {"model": ErrorResponse},
        503: {"model": ErrorResponse},
    },
)
async def analyze(
    file: UploadFile = File(..., description="csv, tsv or xlsx"),
    conc_lvl: str = Form("", description=CONC_LVL_DESC),
    conc_sol: str = Form("", description=CONC_SOL_DESC),
    pk_area: str = Form("", description=PK_AREA_DESC),
    ref_conc: float = Form(0),
    ref_unit: str = Form("mg/mL"),
    lab_x: str = Form("Concentration [mg/mL]"),
    lab_y: str = Form("Peak Area [mAU*min]"),
    plt_title: str = Form(""),
    style: str = Form("report"),
    principal: Principal | None = Depends(current_principal),
):
    """Run the linearity analysis and return the full result as JSON.

    Multipart form upload. The response carries:

    * `model` - coefficients, glance statistics, ANOVA, fitted values,
      residuals, all at full double precision.
    * `homoscedasticity` - Cochran, Levene, Fligner-Killeen and a Shapiro-Wilk
      test on externally studentised residuals, each with its verdict.
    * `report_tables` - the Word report's tables as rendered strings, with the
      app's truncation rules already applied.
    * `plots` - geometry for all five figures, harvested from ggplot itself.
    """
    params = _params(
        conc_lvl=conc_lvl, conc_sol=conc_sol, pk_area=pk_area,
        ref_conc=ref_conc, ref_unit=ref_unit, lab_x=lab_x, lab_y=lab_y,
        plt_title=plt_title, style=style,
    )

    tmp = _save_upload(file)
    try:
        payload = params.model_dump()
        payload |= {"path": str(tmp), "ext": tmp.suffix.lstrip(".")}
        return JSONResponse(await _call_r("/analyze", payload))
    finally:
        tmp.unlink(missing_ok=True)


@app.post("/columns/json", response_model=ColumnsResponse, tags=["analysis"])
async def columns_json(
    req: ColumnsJsonRequest,
    principal: Principal | None = Depends(current_principal),
):
    """List the columns of inline data, without uploading a file."""
    return await _call_r("/columns", req.model_dump())


@app.post(
    "/analyze/json",
    tags=["analysis"],
    responses={422: {"model": ErrorResponse}, 503: {"model": ErrorResponse}},
)
async def analyze_json(
    req: AnalyzeJsonRequest,
    principal: Principal | None = Depends(current_principal),
):
    """Run the analysis on measurements posted inline as JSON.

    Identical to `/analyze` except the data arrives in the body instead of as
    a file upload, which is usually easier to drive from code. Accepts either
    row records or equal-length columns; the response is byte-for-byte the
    same shape.

    ```json
    {
      "data": [{"lvl": 70, "conc": 0.10495, "area": 57.133}, ...],
      "conc_lvl": "lvl", "conc_sol": "conc", "pk_area": "area",
      "ref_conc": 0.15
    }
    ```
    """
    return JSONResponse(await _call_r("/analyze", req.model_dump()))


@app.get("/report/sections", tags=["report"])
async def report_sections() -> dict[str, list[str]]:
    """Valid `sections` values, in the order the report lays them out."""
    return {"sections": list(REPORT_SECTIONS)}


def _report_filename(file_name: str) -> str:
    """Sanitise a client-supplied download name, with the app's default."""
    name = file_name.strip() or f"{dt.date.today():%y%m%d}_Report"
    # Strip directory separators and anything awkward in a filename.
    name = re.sub(r"[^\w.\- ]+", "_", name).strip(". ")
    return f"{name or 'Report'}.docx"


async def _build_report(payload: dict[str, Any], file_name: str) -> FileResponse:
    """Ask R for a .docx, then stream it back and delete it."""
    result = await _call_r("/report", payload)
    path = Path(result["path"])
    if not path.is_file():
        raise HTTPException(
            status_code=500, detail=f"R reported a report at {path}, but it is missing."
        )
    return FileResponse(
        path,
        media_type=DOCX_MEDIA_TYPE,
        filename=_report_filename(file_name),
        background=BackgroundTask(path.unlink, missing_ok=True),
    )


@app.post(
    "/report",
    tags=["report"],
    response_class=FileResponse,
    responses={
        200: {"content": {DOCX_MEDIA_TYPE: {}}, "description": "The Word report"},
        415: {"model": ErrorResponse},
        422: {"model": ErrorResponse},
    },
)
async def report(
    file: UploadFile = File(..., description="csv, tsv or xlsx"),
    conc_lvl: str = Form("", description=CONC_LVL_DESC),
    conc_sol: str = Form("", description=CONC_SOL_DESC),
    pk_area: str = Form("", description=PK_AREA_DESC),
    ref_conc: float = Form(0),
    ref_unit: str = Form("mg/mL"),
    lab_x: str = Form("Concentration [mg/mL]"),
    lab_y: str = Form("Peak Area [mAU*min]"),
    plt_title: str = Form(""),
    sections: list[str] | None = Form(
        None, description="Repeat to select sections; leave blank for all."
    ),
    author_name: str = Form(""),
    author_id: str = Form(""),
    file_name: str = Form(""),
    principal: Principal | None = Depends(current_principal),
):
    """Generate the Word report and return the .docx.

    The same document the app's "Generate Report" button produces: same
    template, section order, page breaks and header/footer. The app takes the
    author from the SSO session, so pass `author_name` / `author_id` here if
    you want the footer filled in.

    Repeat the `sections` field to choose sections; omit it for all four. The
    data table is always included. PDF is not offered -- it renders through
    `report.Rmd` and needs a LaTeX toolchain.
    """
    params = _params(
        conc_lvl=conc_lvl, conc_sol=conc_sol, pk_area=pk_area,
        ref_conc=ref_conc, ref_unit=ref_unit, lab_x=lab_x, lab_y=lab_y,
        plt_title=plt_title, style="report",
    )

    tmp = _save_upload(file)
    try:
        payload = params.model_dump()
        name, user_id, _ = resolve_author(principal, author_name, author_id)
        payload |= {
            "path": str(tmp),
            "ext": tmp.suffix.lstrip("."),
            "sections": _clean_sections(sections),
            "author_name": name,
            "author_id": user_id,
        }
        return await _build_report(payload, file_name)
    finally:
        tmp.unlink(missing_ok=True)


@app.post(
    "/report/json",
    tags=["report"],
    response_class=FileResponse,
    responses={
        200: {"content": {DOCX_MEDIA_TYPE: {}}, "description": "The Word report"},
        422: {"model": ErrorResponse},
    },
)
async def report_json(
    req: ReportJsonRequest,
    principal: Principal | None = Depends(current_principal),
):
    """Generate the Word report from measurements posted inline as JSON."""
    payload = req.model_dump()
    file_name = payload.pop("file_name", "")
    payload["style"] = "report"
    name, user_id, _ = resolve_author(
        principal, payload.get("author_name", ""), payload.get("author_id", "")
    )
    payload["author_name"], payload["author_id"] = name, user_id
    return await _build_report(payload, file_name)
