#' Create summary table of a linear regression model for Word report
#'
#' `lin_reg_rslts_rprt()` creates a table containing all relevant parameters of
#' a linear regression model
#'
#' @param lm_fit a `model_fit` object from a linear regression
#' @param conc single character value. Column name of column containing
#'  concentrations
#' @param ref_conc numeric value. Reference value
#' @param unit single character value. Unit of reference value
#'
#' @return a `flextable` object
#' @export
#'
lin_reg_rslts_rprt <- function(lm_fit, conc, ref_conc, unit) {
  # Generate initial data frame
  df <- data_prep_lin_reg(lm_fit, conc, ref_conc)

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
  ft <- ft %>%
    compose(i = 2, j = 1, value = as_paragraph(
      "Coefficient of determination (R", as_sup("2"), ")"
    )) %>%
    set_header_labels(
      C1 = "Statistical parameter",
      C2 = "Result"
    ) %>%
    border_remove() %>%
    hline_top(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    ) %>%
    hline_bottom(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    ) %>%
    hline_bottom(
      border = fp_border(color = "black", width = 0.5),
      part = "body"
    )

  if (ref_conc != 0) {
    ft <- ft %>%
      footnote(
        i = c(15, 18),
        j = 1,
        value = as_paragraph(c(" referred to the y-value of the regression line (calculated response) for the reference value")),
        ref_symbols = c("a")
      ) %>%
      footnote(
        i = 20,
        j = 1,
        value = as_paragraph(paste(" reference value =", ref_conc, unit)),
        ref_symbols = c("b")
      ) %>%
      padding(
        i = c(4:8, 10:15, 17:18), j = 1,
        padding.left = 14, part = "body"
      ) %>%
      flextable::bold(i = c(1:3, 9, 16, 19:20), j = 1)
  } else {
    ft <- ft %>%
      padding(
        i = c(4:8, 10:14), j = 1,
        padding.left = 14, part = "body"
      ) %>%
      flextable::bold(i = c(1:3, 9, 15:16), j = 1)
  }

  ft <- ft %>%
    padding(padding.bottom = 2, padding.top = 1, part = "all") %>%
    set_table_properties(layout = "autofit", width = 1) %>%
    fontsize(size = 9, part = "all") %>%
    flextable::bold(part = "header") %>%
    flextable::font(fontname = "Arial", part = "all")

  return(ft)
}
