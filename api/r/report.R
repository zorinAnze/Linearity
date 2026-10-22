#' Word report generation
#'
#' `build_report()` reproduces the Word branch of the app's `downloadHandler`
#' (app.R, "Final report"): same template, same section order, same page
#' breaks, same header/footer substitutions. Only the author identity differs
#' -- the app reads it from the NIBR SSO session, so the API takes it as a
#' parameter.
#'
#' PDF output is deliberately not supported: it renders through
#' `www/report.Rmd` and needs a LaTeX toolchain.

suppressPackageStartupMessages({
  library(officer); library(flextable); library(huxtable)
  library(glue); library(lubridate); library(dplyr)
})

# The app exposes this through options(); the footer reads it back.
options(deployVersion = APP_VERSION)

#' Report sections, in the order the app's checkbox group lists them.
#'
#' The app decides page breaks with `tail(input$inc_report, n = 1)`, i.e.
#' relative to this order, so selection order from the client is ignored.
REPORT_SECTIONS <- c(
  "Linear Regression Results",
  "Linear Regression Plot",
  "Diagnostic Plots",
  "Homoscedasticity Assessment (ANVISA)"
)


#' Build the Word report
#'
#' @param df data frame of measurements
#' @param conc_lvl,conc_sol,pk_area column names
#' @param ref_conc,ref_unit reference concentration and unit
#' @param lab_x,lab_y axis labels (also the data table's column titles)
#' @param plt_title report title; "" falls back to "Linearity Report"
#' @param sections character vector; subset of `REPORT_SECTIONS`
#' @param author_name,author_id strings for the footer
#' @param out_path where to write the .docx
#' @return `out_path`
build_report <- function(df, conc_lvl = "", conc_sol = "", pk_area = "",
                         ref_conc = 0,
                         ref_unit = "mg/mL",
                         lab_x = "Concentration [mg/mL]",
                         lab_y = "Peak Area [mAU*min]",
                         plt_title = "",
                         sections = REPORT_SECTIONS,
                         author_name = "",
                         author_id = "",
                         out_path = tempfile(fileext = ".docx")) {

  resolved <- resolve_columns(df, conc_lvl, conc_sol, pk_area)
  conc_lvl <- resolved$columns$conc_lvl
  conc_sol <- resolved$columns$conc_sol
  pk_area  <- resolved$columns$pk_area

  errs <- validate_inputs(df, conc_lvl, conc_sol, pk_area)
  if (length(errs)) stop(paste(errs, collapse = " | "))

  unknown <- setdiff(sections, REPORT_SECTIONS)
  if (length(unknown)) {
    stop("Unknown report section(s): ", paste(unknown, collapse = ", "),
         ". Valid: ", paste(REPORT_SECTIONS, collapse = ", "))
  }
  # Normalise to the app's canonical order; page breaks depend on it.
  sections <- REPORT_SECTIONS[REPORT_SECTIONS %in% sections]

  root <- Sys.getenv("LINEARITY_ROOT", unset = "/home/adnan/projects/shiny")
  template <- file.path(root, "www", "template_officer.docx")
  if (!file.exists(template)) stop("Report template not found: ", template)

  # --- model ---------------------------------------------------------------
  lm_fit <- linear_reg() |>
    set_engine("lm") |>
    fit(as.formula(paste0(pk_area, "~", conc_sol)), data = df)

  anova_fit <- anova(lm_fit$fit)
  cochran <- cochran.test(as.formula(paste0(pk_area, "~", conc_lvl)), data = df)
  levene  <- leveneTest(
    as.formula(paste0(pk_area, "~", conc_lvl)),
    data = df |> mutate(across(all_of(conc_lvl), as.factor))
  )
  fligner <- fligner.test(as.formula(paste0(pk_area, "~", conc_lvl)), data = df)

  # The app refuses to emit a report if the fitted data drifted from the
  # uploaded data. Keep that guard.
  stopifnot(isTRUE(all.equal(
    as.data.frame(lm_fit$fit$model),
    as.data.frame(df |> select(colnames(lm_fit$fit$model))),
    check.attributes = FALSE
  )))

  # --- section content -----------------------------------------------------
  assay_rslts <- assay_rslts_rprt(df, conc_lvl, conc_sol, pk_area,
                                  lab_x, lab_y, plt_title, ref_conc, ref_unit)

  doc <- read_docx(template) |>
    body_add_par("Data Used for Linearity Assessment", style = "heading 1") |>
    body_add_par_n(2) |>
    body_add_flextable(assay_rslts, keepnext = FALSE) |>
    body_add_break() |>
    body_add_par("")

  last_section <- if (length(sections)) tail(sections, 1) else NA_character_
  # A trailing page break after every section except the final one.
  close_section <- function(doc, name) {
    if (identical(name, last_section)) doc
    else doc |> body_add_break() |> body_add_par("")
  }

  if ("Linear Regression Results" %in% sections) {
    doc <- doc |>
      body_add_par("Linear Regression Results", style = "heading 1") |>
      body_add_par_n(2) |>
      body_add_flextable(lin_reg_rslts_rprt(lm_fit, conc_sol, ref_conc, ref_unit)) |>
      close_section("Linear Regression Results")
  }

  if ("Linear Regression Plot" %in% sections) {
    reg_gg <- line_plot(df, conc_sol, pk_area, lab_x, lab_y, lm_fit,
                        ref_conc, plt_title, app = FALSE)
    doc <- doc |>
      body_add_par("Linear Regression Plot", style = "heading 1") |>
      body_add_par_n(2) |>
      body_add_gg(reg_gg, width = 6.3, height = 3.54) |>
      body_add_par_n(5) |>
      body_add_flextable(user_input_tbl(ref_conc, ref_unit)) |>
      close_section("Linear Regression Plot")
  }

  if ("Diagnostic Plots" %in% sections) {
    res_plots <- residual_plots(df, lm_fit, lab_x, app = FALSE)
    doc <- doc |>
      body_add_par("Diagnostic Plots", style = "heading 1") |>
      body_add_par_n(2) |>
      body_add_gg(res_plots$p1, width = 6.3, height = 3.54) |>
      body_add_par_n(5) |>
      body_add_gg(res_plots$p2, width = 6.3, height = 3.54) |>
      body_add_break() |>
      body_add_par("") |>
      body_add_gg(res_plots$p3, width = 6.3, height = 3.54) |>
      body_add_par_n(5) |>
      body_add_gg(res_plots$p4, width = 6.3, height = 3.54) |>
      close_section("Diagnostic Plots")
  }

  if ("Homoscedasticity Assessment (ANVISA)" %in% sections) {
    doc <- doc |>
      body_add_par(paste("Homoscedasticity Evaluation in Accordance with",
                         "ANVISA RDC 166/2017 Requirements"),
                   style = "heading 1") |>
      body_add_par_n(2) |>
      body_add_flextable(homosced_tbl_rprt(lm_fit, cochran, levene,
                                           fligner, anova_fit))
  }

  # --- header / footer -----------------------------------------------------
  header_title <- if (nzchar(plt_title)) plt_title else "Linearity Report"

  doc <- doc |>
    headers_replace_all_text("title", header_title, warn = FALSE) |>
    headers_replace_all_text("date", format(now(), "%d-%b-%y %H:%M:%S %Z"),
                             warn = FALSE) |>
    footers_replace_all_text(
      "author_name",
      glue("{as.character(author_name)} ({as.character(author_id)})"),
      warn = FALSE
    ) |>
    footers_replace_all_text(
      "version", glue("App Version: {getOption('deployVersion')}"),
      warn = FALSE
    )

  print(doc, target = out_path)
  out_path
}
