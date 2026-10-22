#' Plumber backend for the Linearity analysis
#'
#' This is an internal service, not the public API. FastAPI owns the REST
#' contract, validation and file handling; this process exists only to keep R
#' warm (startup + package loading costs several seconds) and to run the app's
#' own functions.
#'
#' Every data-taking endpoint accepts either inline rows (`data`) or an
#' uploaded file (`path` + `ext`); see `df_from_body()`.
#'
#' Bind to loopback only -- it performs no authentication.

local({
  root <- Sys.getenv("LINEARITY_ROOT", unset = "/home/adnan/projects/shiny")
  source(file.path(root, "api", "r", "analysis.R"))
  source(file.path(root, "api", "r", "report.R"))
})

library(plumber)

# Shared secret for the hop from FastAPI. Unset means no check, which is
# right for loopback with nothing in between. Set it whenever this process
# is reachable by anything other than the FastAPI tier -- on Connect, access
# control is the platform's job and this is defence in depth.
R_API_KEY <- Sys.getenv("LINEARITY_R_API_KEY", unset = "")

#* @apiTitle Linearity R backend (internal)

#* @filter require-key
function(req, res) {
  if (!nzchar(R_API_KEY) || identical(req$PATH_INFO, "/health")) {
    return(plumber::forward())
  }
  supplied <- sub("^(Key|Bearer)\\s+", "", req$HTTP_AUTHORIZATION %||% "",
                  ignore.case = TRUE)
  # Compare every character so the time taken does not reveal the prefix.
  ok <- nchar(supplied) == nchar(R_API_KEY) &&
    !as.logical(sum(utf8ToInt(supplied) != utf8ToInt(R_API_KEY)))
  if (!isTRUE(ok)) {
    res$status <- 401
    return(list(error = "unauthorized",
                detail = "Missing or invalid Authorization header."))
  }
  plumber::forward()
}

#* Liveness probe
#* @get /health
#* @serializer unboxedJSON
function() {
  list(
    status      = "ok",
    r_version   = paste0(R.version$major, ".", R.version$minor),
    app_version = APP_VERSION,
    pid         = Sys.getpid()
  )
}

#* Inspect a data file's columns (mirrors the app's column dropdowns)
#* @post /columns
#* @serializer unboxedJSON
function(req, res) {
  tryCatch({
    df <- df_from_body(req$body)
    list(
      n_rows = nrow(df),
      columns = lapply(names(df), function(n) list(
        name       = n,
        type       = class(df[[n]])[1],
        numeric    = is.numeric(df[[n]]),
        n_distinct = length(unique(df[[n]]))
      ))
    )
  }, error = function(e) {
    res$status <- 400
    list(error = "read_failed", detail = conditionMessage(e))
  })
}

#* Run the linearity analysis
#* @post /analyze
#* @serializer json list(auto_unbox = TRUE, digits = NA, na = "null", null = "null")
function(req, res) {
  body <- req$body
  tryCatch({
    run_analysis(
      df        = df_from_body(body),
      conc_lvl  = body$conc_lvl,
      conc_sol  = body$conc_sol,
      pk_area   = body$pk_area,
      ref_conc  = if (is.null(body$ref_conc)) 0 else as.numeric(body$ref_conc),
      ref_unit  = if (is.null(body$ref_unit)) "mg/mL" else body$ref_unit,
      lab_x     = if (is.null(body$lab_x)) "Concentration [mg/mL]" else body$lab_x,
      lab_y     = if (is.null(body$lab_y)) "Peak Area [mAU*min]" else body$lab_y,
      plt_title = if (is.null(body$plt_title)) "" else body$plt_title,
      style     = if (is.null(body$style)) "report" else body$style
    )
  }, error = function(e) {
    res$status <- 422
    list(error = "analysis_failed", detail = conditionMessage(e))
  })
}

#* Generate the Word report
#*
#* Writes a .docx to a temp file and returns its path. FastAPI streams the
#* file back to the client and removes it; both run on the same host, so
#* there is no reason to base64 the bytes through this hop.
#* @post /report
#* @serializer unboxedJSON
function(req, res) {
  body <- req$body
  tryCatch({
    out <- tempfile(pattern = "linearity_report_", fileext = ".docx")
    build_report(
      df          = df_from_body(body),
      conc_lvl    = body$conc_lvl,
      conc_sol    = body$conc_sol,
      pk_area     = body$pk_area,
      ref_conc    = if (is.null(body$ref_conc)) 0 else as.numeric(body$ref_conc),
      ref_unit    = if (is.null(body$ref_unit)) "mg/mL" else body$ref_unit,
      lab_x       = if (is.null(body$lab_x)) "Concentration [mg/mL]" else body$lab_x,
      lab_y       = if (is.null(body$lab_y)) "Peak Area [mAU*min]" else body$lab_y,
      plt_title   = if (is.null(body$plt_title)) "" else body$plt_title,
      sections    = if (is.null(body$sections)) REPORT_SECTIONS else unlist(body$sections),
      author_name = if (is.null(body$author_name)) "" else body$author_name,
      author_id   = if (is.null(body$author_id)) "" else body$author_id,
      out_path    = out
    )
    list(path = out, size = as.numeric(file.size(out)))
  }, error = function(e) {
    res$status <- 422
    list(error = "report_failed", detail = conditionMessage(e))
  })
}

#* Valid report section names, in the order the report lays them out
#* @get /report/sections
#* @serializer unboxedJSON
function() {
  list(sections = REPORT_SECTIONS)
}
