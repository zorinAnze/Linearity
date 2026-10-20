"""Redraw the Linearity report figures from an /analyze JSON response.

The API returns plot *geometry* rather than images: the exact coordinates
ggplot2 computed when building each figure (smooth grid and confidence band,
histogram bin edges, Q-Q quantiles, the fitted equation string). Redrawing
from those numbers reproduces the report's figures without the API having to
ship PNGs around.

Styling approximates ggplot2's `theme_bw()`. Geometry is exact; marker sizes
and fonts are a close visual match rather than pixel-identical, since point
sizes do not map one-to-one between ggplot2 and matplotlib.

Usage
-----
    from plots import plot_all, save_all

    result = requests.post(".../analyze", ...).json()
    figs = plot_all(result)          # dict[str, matplotlib Figure]
    save_all(result, "figures/")     # or straight to PNG files

Or from the shell:

    python plots.py result.json --outdir figures
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.figure import Figure  # noqa: E402

ACCENT = "#0460A9"
GRID = "#EBEBEB"
PANEL_BORDER = "#333333"
REF_GREY = "#333333"  # R's gray20
SE_FILL = "#999999"  # R's grey60, geom_smooth's default ribbon fill


def _arr(values: list[Any]) -> np.ndarray:
    """Series -> float array, mapping JSON nulls to NaN.

    ggplot censors values that fall outside a scale's limits, which arrive as
    nulls. Matplotlib skips NaN the same way ggplot drops censored points, so
    the gaps land in the same places.
    """
    return np.array([np.nan if v is None else float(v) for v in values],
                    dtype=float)


def _theme_bw(ax, style: dict[str, Any], title: str | None = None) -> None:
    """Approximate ggplot2's theme_bw() on a matplotlib axes."""
    base = style.get("text_size", 10)

    ax.set_facecolor("white")
    ax.grid(True, which="major", color=GRID, linewidth=0.6, zorder=0)
    ax.grid(True, which="minor", color=GRID, linewidth=0.3, zorder=0)
    ax.minorticks_on()
    ax.set_axisbelow(True)

    for spine in ax.spines.values():
        spine.set_color(PANEL_BORDER)
        spine.set_linewidth(0.6)

    ax.tick_params(labelsize=base * 0.8, color=PANEL_BORDER, width=0.6)
    ax.xaxis.label.set_size(base)
    ax.yaxis.label.set_size(base)

    if title:
        # ggplot uses face="bold", size=rel(1.4) for these titles.
        # ggtitle() left-aligns by default.
        ax.set_title(title, fontsize=base * 1.4, fontweight="bold", loc="left")


def _marker_area(ggplot_size: float) -> float:
    """Convert a ggplot2 point `size` to a matplotlib scatter area (pt^2)."""
    # ggplot sizes are diameters in mm; ~2.845 pt per mm.
    return (ggplot_size * 2.845) ** 2


def plot_regression(result: dict[str, Any]) -> Figure:
    """Scatter + fitted line with 95% confidence band, equation and reference."""
    p = result["plots"]["regression"]
    style = result["plots"]["style"]
    axes = p["axes"]

    fig, ax = plt.subplots(figsize=(6.3, 3.54), dpi=150)

    sm = p["smooth"]
    sx, sy = _arr(sm["x"]), _arr(sm["y"])
    smin, smax = _arr(sm["ymin"]), _arr(sm["ymax"])
    band = ~(np.isnan(smin) | np.isnan(smax))
    ax.fill_between(sx[band], smin[band], smax[band], color=SE_FILL,
                    alpha=0.4, linewidth=0, zorder=1)
    ax.plot(sx, sy, color=ACCENT, linewidth=style["line_size"] * 2, zorder=2)

    ref = p.get("reference")
    if ref:
        # Dashed guides from each axis to (ref_conc, y_at_ref).
        ax.plot([ref["ref_conc"], ref["ref_conc"]],
                [axes["y_range"][0], ref["y_at_ref"]],
                color=REF_GREY, linestyle="--",
                linewidth=style["line_size"] * 2, zorder=3)
        ax.plot([axes["x_range"][0], ref["ref_conc"]],
                [ref["y_at_ref"], ref["y_at_ref"]],
                color=REF_GREY, linestyle="--",
                linewidth=style["line_size"] * 2, zorder=3)

    pts = p["points"]
    ax.scatter(_arr(pts["x"]), _arr(pts["y"]),
               s=_marker_area(style["dot_size"]), color="black", zorder=4)

    eq = p.get("equation")
    if eq:
        ax.text(eq["x"], eq["y"], eq["label"],
                ha="left", va="top", fontsize=style["text_size"] * 0.9,
                zorder=5)

    ax.set_xlim(*axes["x_range"])
    ax.set_ylim(*axes["y_range"])
    ax.set_xlabel(axes["x_lab"])
    ax.set_ylabel(axes["y_lab"])
    _theme_bw(ax, style, axes.get("title"))

    fig.tight_layout()
    return fig


def plot_qq(result: dict[str, Any]) -> Figure:
    """Normal Q-Q plot of the model residuals."""
    p = result["plots"]["qq"]
    style = result["plots"]["style"]

    fig, ax = plt.subplots(figsize=(6.3, 3.54), dpi=150)
    ax.plot(_arr(p["line"]["x"]), _arr(p["line"]["y"]), color=ACCENT,
            linewidth=style["line_size"] * 2, zorder=2)
    ax.scatter(_arr(p["points"]["x"]), _arr(p["points"]["y"]),
               s=_marker_area(style["dot_size"]), color="black", zorder=3)

    ax.set_xlabel(p["axes"]["x_lab"])
    ax.set_ylabel(p["axes"]["y_lab"])
    _theme_bw(ax, style, p["axes"]["title"])
    fig.tight_layout()
    return fig


def plot_residuals_vs_x(result: dict[str, Any]) -> Figure:
    """Residuals against the independent variable."""
    p = result["plots"]["residuals_vs_x"]
    style = result["plots"]["style"]

    fig, ax = plt.subplots(figsize=(6.3, 3.54), dpi=150)
    ax.axhline(p["hline"], color=REF_GREY, linestyle="--",
               linewidth=style["line_size"] * 2, zorder=2)
    ax.scatter(_arr(p["points"]["x"]), _arr(p["points"]["y"]),
               s=_marker_area(style["dot_size"]), color="black", zorder=3)

    ax.set_xlabel(p["axes"]["x_lab"])
    ax.set_ylabel(p["axes"]["y_lab"])
    _theme_bw(ax, style, p["axes"]["title"])
    fig.tight_layout()
    return fig


def plot_residual_histogram(result: dict[str, Any]) -> Figure:
    """Histogram of residuals, using ggplot's computed bins."""
    p = result["plots"]["residual_histogram"]
    style = result["plots"]["style"]
    bins = p["bins"]

    fig, ax = plt.subplots(figsize=(6.3, 3.54), dpi=150)
    xmin, xmax, counts = _arr(bins["xmin"]), _arr(bins["xmax"]), _arr(bins["y"])
    ax.bar(xmin, counts, width=xmax - xmin, align="edge",
           color=ACCENT, edgecolor="black", linewidth=0.5, zorder=2)

    # ggplot expands the y axis by 5% at the top only.
    ax.set_ylim(0, float(np.nanmax(counts)) * 1.05 if counts.size else 1)
    ax.set_xlabel(p["axes"]["x_lab"])
    ax.set_ylabel(p["axes"]["y_lab"])
    _theme_bw(ax, style, p["axes"]["title"])
    fig.tight_layout()
    return fig


def plot_residuals_vs_order(result: dict[str, Any]) -> Figure:
    """Residuals in observation order, to expose drift."""
    p = result["plots"]["residuals_vs_order"]
    style = result["plots"]["style"]

    fig, ax = plt.subplots(figsize=(6.3, 3.54), dpi=150)
    ax.axhline(p["hline"], color=REF_GREY, linestyle="--",
               linewidth=style["line_size"] * 2, zorder=2)
    ax.plot(_arr(p["points"]["x"]), _arr(p["points"]["y"]), color="black",
            linewidth=style["line_size"] * 2, zorder=3)
    # Filled circles with a white rim, matching shape = 21 in the report.
    ax.scatter(_arr(p["points"]["x"]), _arr(p["points"]["y"]),
               s=_marker_area(style["dot_size"] * 1.2),
               facecolor="black", edgecolor="white",
               linewidth=style["line_size"] * 1.5, zorder=4)

    ax.set_xlabel(p["axes"]["x_lab"])
    ax.set_ylabel(p["axes"]["y_lab"])
    _theme_bw(ax, style, p["axes"]["title"])
    fig.tight_layout()
    return fig


PLOTTERS = {
    "regression": plot_regression,
    "qq": plot_qq,
    "residuals_vs_x": plot_residuals_vs_x,
    "residual_histogram": plot_residual_histogram,
    "residuals_vs_order": plot_residuals_vs_order,
}


def plot_all(result: dict[str, Any]) -> dict[str, Figure]:
    """Redraw every figure. Returns {name: Figure}."""
    return {name: fn(result) for name, fn in PLOTTERS.items()}


def save_all(result: dict[str, Any], outdir: str | Path,
             fmt: str = "png") -> list[Path]:
    """Redraw every figure and write it to `outdir`. Returns the paths."""
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for name, fig in plot_all(result).items():
        path = out / f"{name}.{fmt}"
        fig.savefig(path, bbox_inches="tight")
        plt.close(fig)
        paths.append(path)
    return paths


def main() -> None:
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("result", help="JSON file from POST /analyze")
    ap.add_argument("--outdir", default="figures")
    ap.add_argument("--fmt", default="png", choices=["png", "pdf", "svg"])
    args = ap.parse_args()

    with open(args.result) as fh:
        result = json.load(fh)

    for path in save_all(result, args.outdir, args.fmt):
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
