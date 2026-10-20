#!/usr/bin/env bash
# One-time setup for the Linearity API on a fresh Ubuntu / WSL machine.
#
#   ./api/setup.sh
#
# Installs R 4.5.1 (the version renv.lock pins), the system libraries the
# package set needs, the R packages, plumber, and the Python venv. Needs
# sudo. Safe to re-run: every step is skipped if already satisfied.
#
# Package source is chosen automatically:
#   * on the Novartis network, the validated mirrors in renv.lock -- which
#     also provides ava2, so the Shiny app itself will run, not just the API
#   * otherwise the public Posit mirror snapshot below, which matches 200 of
#     the 202 locked packages exactly. The three it cannot supply (ava2,
#     rsconnect, snowflakeauth) are all UI- or deploy-only and are skipped.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R_VERSION="4.5.1"
# Chosen by comparing candidate dates against renv.lock; see api/README.md.
P3M_SNAPSHOT="2025-09-11"
NOVARTIS_PROBE="https://rspm.apps.dit-prdocp.novartis.net/exploratory/latest"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
info() { printf '    %s\n' "$1"; }
die()  { printf '\n\033[31mERROR:\033[0m %s\n' "$1" >&2; exit 1; }

[ -f "$ROOT/renv.lock" ] || die "renv.lock not found -- run this from the repo."

# ---------------------------------------------------------------- 1. checks
step "1/7  Checking prerequisites"
command -v sudo >/dev/null || die "sudo is required."
sudo -v || die "sudo authentication failed."

codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
[ -n "$codename" ] || die "Could not determine the Ubuntu codename."
info "Ubuntu codename: $codename"

# ----------------------------------------------------------------- 2. apt
step "2/7  Base tooling"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg dirmngr software-properties-common python3-venv

# ----------------------------------------------------------------- 3. rig
step "3/7  Installing rig (R version manager)"
if command -v rig >/dev/null 2>&1; then
  info "already present: $(rig --version 2>&1 | head -1)"
else
  sudo curl -fsSL -o /etc/apt/trusted.gpg.d/rig.gpg https://rig.r-pkg.org/deb/rig.gpg
  echo "deb http://rig.r-pkg.org/deb rig main" \
    | sudo tee /etc/apt/sources.list.d/rig.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y r-rig
fi

# ------------------------------------------------------------------- 4. R
step "4/7  Installing R $R_VERSION"
# The lockfile pins this version, and Posit's Linux binaries are built per R
# minor version -- a different R would silently fall back to compiling 200
# packages from source.
if [ -x "/opt/R/$R_VERSION/bin/R" ]; then
  info "already installed"
else
  sudo rig add "$R_VERSION"
fi
sudo rig default "$R_VERSION"
info "$(R --version | head -1)"

# ------------------------------------------------------- 5. system libraries
step "5/7  System libraries"
# Needed by curl/httr, openssl, xml2, gert, stringi, systemfonts, textshaping,
# ragg, gdtools/flextable and RSQLite; pandoc is for rmarkdown.
pkgs=(
  build-essential gfortran make cmake pkg-config
  libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev
  zlib1g-dev libbz2-dev liblzma-dev libicu-dev
  libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev
  libpng-dev libjpeg-dev libcairo2-dev libsqlite3-dev
  pandoc
)
# Renamed after jammy.
if apt-cache show libtiff5-dev >/dev/null 2>&1; then
  pkgs+=(libtiff5-dev)
else
  pkgs+=(libtiff-dev)
fi
sudo apt-get install -y --no-install-recommends "${pkgs[@]}"

# ------------------------------------------------------------ 6. R packages
step "6/7  R packages"
# renv will warn that huxtable wants texlive. That is only for PDF output,
# which this API does not offer, and the binary installs fine without it.
info "(a 'texlive required by huxtable' warning here is expected and harmless)"
if curl -sf --max-time 10 -o /dev/null "$NOVARTIS_PROBE" 2>/dev/null; then
  REPO_SOURCE="novartis"
  info "Novartis mirrors reachable -- restoring exactly per renv.lock (incl. ava2)."
else
  REPO_SOURCE="public"
  SNAPSHOT_URL="https://packagemanager.posit.co/cran/__linux__/$codename/$P3M_SNAPSHOT"
  info "Novartis mirrors unreachable -- using the public snapshot:"
  info "  $SNAPSHOT_URL"
  curl -sf --max-time 20 -o /dev/null "$SNAPSHOT_URL/src/contrib/PACKAGES.gz" \
    || die "Public snapshot unreachable for '$codename'. Check the network/proxy."
  export RENV_CONFIG_REPOS_OVERRIDE="$SNAPSHOT_URL"
fi

# plumber is not in the validated set, so keep the public snapshot available
# as a fallback for it even when restoring from the Novartis mirrors.
SNAPSHOT_URL="https://packagemanager.posit.co/cran/__linux__/$codename/$P3M_SNAPSHOT"
if curl -sf --max-time 20 -o /dev/null "$SNAPSHOT_URL/src/contrib/PACKAGES.gz" 2>/dev/null; then
  export LINEARITY_FALLBACK_REPO="$SNAPSHOT_URL"
fi

cd "$ROOT"
REPO_SOURCE="$REPO_SOURCE" Rscript - <<'RSCRIPT'
source_kind <- Sys.getenv("REPO_SOURCE")
override <- Sys.getenv("RENV_CONFIG_REPOS_OVERRIDE", unset = "")

# Posit serves Linux *binaries* only when the User-Agent advertises the R
# version and platform; without this every package compiles from source.
options(
  HTTPUserAgent = sprintf(
    "R/%s R (%s)", getRversion(),
    paste(getRversion(), R.version$platform, R.version$arch, R.version$os)
  ),
  Ncpus = max(1L, parallel::detectCores() - 1L)
)
if (nzchar(override)) {
  options(repos = c(P3M = override), renv.config.repos.override = c(P3M = override))
}

# ava2 is Novartis-internal and UI-only; rsconnect and snowflakeauth are
# deploy-only and the lockfile pins versions the public snapshot lacks.
exclude <- if (identical(source_kind, "public")) {
  c("ava2", "rsconnect", "snowflakeauth")
} else {
  character()
}
if (length(exclude)) {
  cat("    skipping:", paste(exclude, collapse = ", "), "\n")
}

renv::restore(prompt = FALSE, exclude = exclude)

# plumber runs the HTTP backend but is deliberately absent from renv.lock,
# so the validated lockfile stays untouched.
#
# The validated Novartis mirror is a curated set and need not carry plumber,
# so fall back to the public snapshot for this one package rather than
# leaving the backend unrunnable.
if (!requireNamespace("plumber", quietly = TRUE)) {
  cat("    installing plumber\n")
  installed <- tryCatch({
    renv::install("plumber", prompt = FALSE)
    requireNamespace("plumber", quietly = TRUE)
  }, error = function(e) {
    cat("    primary repo failed:", conditionMessage(e), "\n")
    FALSE
  })

  if (!installed && !nzchar(Sys.getenv("LINEARITY_FALLBACK_REPO", ""))) {
    cat("    no fallback configured\n")
  } else if (!installed) {
    fallback <- Sys.getenv("LINEARITY_FALLBACK_REPO")
    cat("    retrying from", fallback, "\n")
    tryCatch(
      renv::install("plumber", prompt = FALSE, repos = c(P3M = fallback)),
      error = function(e) cat("    fallback failed:", conditionMessage(e), "\n")
    )
  }
}

# Verify rather than assume: without plumber the R backend cannot start, and
# failing here is far clearer than a missing-package error at run time.
if (!requireNamespace("plumber", quietly = TRUE)) {
  stop("plumber could not be installed -- the R backend will not start. ",
       "Install it by hand, from a repository this machine can reach:\n",
       "  Rscript -e 'renv::install(\"plumber\")'",
       call. = FALSE)
}

cat("    plumber:", as.character(packageVersion("plumber")), "\n")
cat("    R library ready:",
    nrow(installed.packages(lib.loc = renv::paths$library())), "packages\n")
RSCRIPT

# --------------------------------------------------------------- 7. Python
step "7/7  Python environment"
if [ ! -x "$ROOT/api/.venv/bin/python" ]; then
  python3 -m venv "$ROOT/api/.venv"
fi
"$ROOT/api/.venv/bin/pip" install -q --upgrade pip
"$ROOT/api/.venv/bin/pip" install -q -r "$ROOT/api/requirements.txt"
info "$("$ROOT/api/.venv/bin/python" --version)"

# ---------------------------------------------------------------- finished
cat <<EOF

$(printf '\033[1m==> Setup complete.\033[0m')

    Start the API:   ./api/run.sh
    Then test it:    ./api/smoke_test.sh
    Docs:            http://127.0.0.1:8000/docs
EOF
if [ "$REPO_SOURCE" = "public" ]; then
  cat <<'EOF'

    Note: ava2, rsconnect and snowflakeauth were skipped (unavailable off
    the Novartis network). The API does not need them, but the Shiny app
    will not start without ava2, and renv::status() will report them
    missing. That is expected, not drift.
EOF
fi
