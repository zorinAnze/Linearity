"""Request/response schemas for the Linearity REST API.

Response bodies from the R backend are passed through as-is: R is the source
of truth for the numbers, and re-validating them in Python would only risk
silently reshaping values. The models here cover the request surface and the
documented shape of the response.
"""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class AnalysisParams(BaseModel):
    """Analysis parameters, mirroring the Shiny app's inputs."""

    # All three are optional: a blank name is resolved positionally against
    # the numeric columns, in order of appearance. See resolve_columns() in
    # api/r/analysis.R. No `examples` here -- Swagger UI prefills inputs from
    # them, and a plausible-looking wrong column name is easy to miss.
    conc_lvl: str = Field(
        "",
        description="Column holding the analyte concentration *level* (the "
        "grouping variable used by the variance tests). Blank = 1st numeric "
        "column.",
    )
    conc_sol: str = Field(
        "",
        description="Column holding the analyte concentration (regression x). "
        "Blank = 2nd numeric column.",
    )
    pk_area: str = Field(
        "",
        description="Column holding the analyte response (regression y). "
        "Blank = 3rd numeric column.",
    )
    ref_conc: float = Field(
        0,
        description="Reference concentration. 0 disables all reference-value "
        "output (relative intercept, relative residual SD, y at reference).",
        examples=[0.15],
    )
    ref_unit: str = Field("mg/mL", description="Unit label for ref_conc.")
    lab_x: str = Field("Concentration [mg/mL]", description="X-axis label.")
    lab_y: str = Field("Peak Area [mAU*min]", description="Y-axis label.")
    plt_title: str = Field("", description="Plot/report title; empty for none.")
    style: Literal["report", "app"] = Field(
        "report",
        description="'report' matches the Word report's sizing (the default, "
        "and what you want if you are redrawing report figures); 'app' "
        "matches the larger on-screen Shiny sizing.",
    )


#: Report sections, in the order the report lays them out. Selection order
#: from the client is ignored -- page breaks depend on this ordering.
REPORT_SECTIONS = [
    "Linear Regression Results",
    "Linear Regression Plot",
    "Diagnostic Plots",
    "Homoscedasticity Assessment (ANVISA)",
]

#: Inline data: row records, or equal-length columns.
InlineData = list[dict[str, Any]] | dict[str, list[Any]]


class AnalyzeJsonRequest(AnalysisParams):
    """`POST /analyze/json` body: parameters plus the measurements inline."""

    data: InlineData = Field(
        ...,
        description="Either row records "
        '(`[{"conc": 0.1, "area": 57.1}, ...]`) or equal-length columns '
        '(`{"conc": [0.1, ...], "area": [57.1, ...]}`). Column names are '
        "sanitised with R's `make.names()`, exactly as on file import.",
    )


#: Swagger UI prefills an untouched array field with this literal.
PLACEHOLDER = "string"


def _usable_sections(values: list[str]) -> list[str]:
    """Drop entries that mean "nothing was chosen", defaulting to all sections.

    Covers blanks and Swagger UI's "string" placeholder. Neither can ever be
    a real section name, so treating them as unset beats failing a request
    whose only fault is an untouched form field.
    """
    cleaned = [
        v.strip() for v in values
        if v and v.strip() and v.strip() != PLACEHOLDER
    ]
    return cleaned or list(REPORT_SECTIONS)


class ReportOptions(BaseModel):
    """Word-report options beyond the analysis parameters."""

    sections: list[str] = Field(
        default_factory=lambda: list(REPORT_SECTIONS),
        description="Sections to include. The data table is always present. "
        f"Valid values: {REPORT_SECTIONS}",
    )
    author_name: str = Field(
        "", description="Author name for the footer (the app takes this from SSO)."
    )
    author_id: str = Field("", description="Author ID for the footer.")
    file_name: str = Field(
        "", description="Download filename, without extension. "
        "Defaults to 'YYMMDD_Report'."
    )

    @field_validator("sections")
    @classmethod
    def _drop_blank_sections(cls, v: list[str]) -> list[str]:
        """Blank entries mean "not specified", not a section named ''.

        Clients (Swagger UI among them) submit an untouched array field as a
        single empty string; an empty list after cleaning means every section.
        """
        return _usable_sections(v)


class ReportJsonRequest(AnalysisParams, ReportOptions):
    """`POST /report/json` body: parameters, report options and inline data."""

    data: InlineData = Field(..., description="See /analyze/json.")


class ColumnsJsonRequest(BaseModel):
    """`POST /columns/json` body."""

    data: InlineData


class ColumnInfo(BaseModel):
    name: str
    type: str
    numeric: bool
    n_distinct: int


class ColumnsResponse(BaseModel):
    n_rows: int
    columns: list[ColumnInfo]


class HealthResponse(BaseModel):
    status: str
    api_version: str
    r_backend: dict[str, Any] | None = None
    auth: dict[str, Any] | None = None
    detail: str | None = None


class ErrorResponse(BaseModel):
    error: str
    detail: str
