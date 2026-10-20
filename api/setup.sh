#!/usr/bin/env bash
# One-time setup for the Linearity API on a fresh Ubuntu / WSL machine.
#
#   ./api/setup.sh                      # auto-detect package source
#   LINEARITY_FORCE_PUBLIC=1 ./api/setup.sh   # force Posit binaries
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
# Posit's binaries link against these at *run* time, so a missing one shows
# up as a load failure during restore, not a compile error -- e.g. ragg
# needs libwebp-dev, and without it fails with "libwebpmux.so.3: cannot open
# shared object file".
#
# This list is Posit's own answer for every package in renv.lock, and is
# identical for Ubuntu 22.04 and 24.04. Regenerate it with:
#
#   curl -sS "https://packagemanager.posit.co/__api__/repos/cran/sysreqs\
#?distribution=ubuntu&release=22.04&pkgname=ragg&pkgname=..."
#
# It is baked in rather than queried at run time so setup still works where
# packagemanager.posit.co is blocked.
pkgs=(
  cmake git make
  libcairo2-dev libcurl4-openssl-dev libfontconfig1-dev libfreetype6-dev
  libfribidi-dev libgit2-dev libharfbuzz-dev libicu-dev libjpeg-dev
  libpng-dev libssh2-1-dev libssl-dev libtiff-dev libuv1-dev libwebp-dev
  libx11-dev libxml2-dev zlib1g-dev
  pandoc
  # Not in Posit's list, but needed whenever a package falls back to source.
  build-essential gfortran pkg-config
)
# Posit also lists texlive, for huxtable's PDF output. This API does not
# offer PDF reports, and texlive is a multi-GB install, so it is left out.

# Tolerate renames across releases: install what exists, report what does not.
available=(); missing=()
for p in "${pkgs[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then available+=("$p"); else missing+=("$p"); fi
done
[ ${#missing[@]} -eq 0 ] || info "not in this release's archive, skipping: ${missing[*]}"
sudo apt-get install -y --no-install-recommends "${available[@]}"

# ------------------------------------------------------------ 6. R packages
step "6/7  R packages"
# renv will warn that huxtable wants texlive. That is only for PDF output,
# which this API does not offer, and the binary installs fine without it.
info "(a 'texlive required by huxtable' warning here is expected and harmless)"
SNAPSHOT_URL="https://packagemanager.posit.co/cran/__linux__/$codename/$P3M_SNAPSHOT"

reachable() { curl -sf --max-time 15 -o /dev/null "$1" 2>/dev/null; }

novartis_ok=false; posit_ok=false
reachable "$NOVARTIS_PROBE/src/contrib/PACKAGES.gz" && novartis_ok=true
reachable "$SNAPSHOT_URL/src/contrib/PACKAGES.gz" && posit_ok=true
info "reachable -- novartis: $novartis_ok, posit: $posit_ok"

if [ -n "${LINEARITY_FORCE_PUBLIC:-}" ] && [ "$posit_ok" = false ]; then
  die "LINEARITY_FORCE_PUBLIC is set but packagemanager.posit.co is not
    reachable from here$([ -n "${https_proxy:-}" ] && echo " (https_proxy=$https_proxy)" || echo " (no https_proxy set)").
    Either export https_proxy/http_proxy for your corporate proxy, or drop
    the flag to use the Novartis mirrors instead."
fi

if [ -n "${LINEARITY_FORCE_PUBLIC:-}" ] || { [ "$novartis_ok" = false ] && [ "$posit_ok" = true ]; }; then
  REPO_SOURCE="public"
  info "Using the public snapshot: $SNAPSHOT_URL"
  export RENV_CONFIG_REPOS_OVERRIDE="$SNAPSHOT_URL"
elif [ "$novartis_ok" = true ]; then
  REPO_SOURCE="novartis"
  info "Using the Novartis mirrors, per renv.lock."
  if [ "$posit_ok" = false ]; then
    info "Posit is not reachable, so packages without a Novartis binary will"
    info "compile from source. Expect this to take a while."
  fi
else
  die "No package repository is reachable.
    Tried: $NOVARTIS_PROBE
           $SNAPSHOT_URL
    Proxy: http_proxy=${http_proxy:-unset} https_proxy=${https_proxy:-unset}
    If this machine needs a proxy for external hosts, export http_proxy and
    https_proxy and re-run. On the Novartis network, connect to the VPN."
fi

# plumber is absent from renv.lock, so it needs a repository of its own.
# Prefer Posit; fall back to the Novartis RSPM, which mirrors CRAN more
# broadly than the validated set does.
if [ "$posit_ok" = true ]; then
  export LINEARITY_FALLBACK_REPO="$SNAPSHOT_URL"
elif [ "$novartis_ok" = true ]; then
  export LINEARITY_FALLBACK_REPO="$NOVARTIS_PROBE"
fi

cd "$ROOT"
REPO_SOURCE="$REPO_SOURCE" UBUNTU_CODENAME="$codename" Rscript - <<'RSCRIPT'
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

# Ubuntu 20.04 carries libgit2 0.28, below git2r's ">= 1.0", so git2r can
# neither be built there nor downloaded as a binary (Posit has no focal
# build for the same reason). Nothing but ava2 depends on it, and ava2 is
# UI-only, so dropping both leaves the API complete.
if (identical(Sys.getenv("UBUNTU_CODENAME"), "focal")) {
  exclude <- union(exclude, c("git2r", "ava2"))
  cat("    focal: excluding git2r and ava2 (libgit2 too old; API unaffected)\n")
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
# 3.10 is a hard floor: models.py evaluates a PEP 604 union (`X | Y`) at
# import time, which older interpreters cannot parse.
PYBIN="python3"
if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
  info "python3: $(python3 --version 2>&1 | awk '{print $2}')"
else
  # Ubuntu 20.04 ships 3.8, and deadsnakes dropped focal when it went EOL,
  # so apt cannot help. uv fetches a standalone CPython that only needs
  # glibc 2.17+ (focal has 2.31) and installs under $HOME, no sudo.
  info "python3 is $(python3 --version 2>&1 | awk '{print $2}'); need >= 3.10"
  if ! command -v uv >/dev/null 2>&1; then
    info "installing uv to provide a newer Python"
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 \
      || die "Could not install uv. Install Python 3.10+ another way, then re-run."
  fi
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  command -v uv >/dev/null 2>&1 || die "uv installed but not on PATH."
  uv python install 3.12 >/dev/null 2>&1 || die "uv could not install Python 3.12."
  PYBIN="$(uv python find 3.12)"
  [ -x "$PYBIN" ] || die "uv reported no usable Python 3.12."
  info "using $("$PYBIN" --version 2>&1 | awk '{print $2}') from uv at $PYBIN"
fi

# Rebuild the venv if it exists but is too old to import the app.
if [ -x "$ROOT/api/.venv/bin/python" ] && \
   ! "$ROOT/api/.venv/bin/python" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
  info "existing venv is too old -- recreating"
  rm -rf "$ROOT/api/.venv"
fi
if [ ! -x "$ROOT/api/.venv/bin/python" ]; then
  "$PYBIN" -m venv "$ROOT/api/.venv"
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
