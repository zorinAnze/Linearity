#' Create summary table of a linear regression model for PDF report
#'
#' `lin_reg_rslts_rprt_huxtbl()` creates a table containing all relevant
#' parameters of a linear regression model
#'
#' @param lm_fit a `model_fit` object from a linear regression
#' @param conc single character value. Column name of column containing
#'  concentrations
#' @param ref_conc numeric value. Reference value
#' @param unit single character value. Unit of reference value
#'
#' @return a `huxtable` object
#' @export
#'
lin_reg_rslts_rprt_huxtbl <- function(lm_fit, conc, ref_conc, unit) {
  # Generate initial data frame
  df <- data_prep_lin_reg(lm_fit, conc, ref_conc)

  # Convert data frame to huxtable
  ht <- as_huxtable(df)

  # Format huxtable
  ht <- ht %>%
    # Some Latex is needed for the superscript
    set_contents(
      3, 1,
      "Coefficient of determination (R\\textsuperscript{2})"
    ) %>%
    set_escape_contents(3, 1, FALSE) %>%
    set_contents(1, 1:2, c(
      "Statistical parameter",
      "Result"
    )) %>%
    set_top_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(nrow(ht), everywhere, brdr(0.5, "solid", "black"))

  if (ref_conc != 0) {
    ht <- ht %>%
      set_contents(
        c(16, 19), 1,
        "relative\\textsuperscript{a}"
      ) %>%
      set_escape_contents(c(16, 19), 1, FALSE) %>%
      set_contents(
        21, 1,
        "y for reference value (y = a * x + b)\\textsuperscript{b}"
      ) %>%
      set_escape_contents(21, 1, FALSE) %>%
      set_left_padding(c(5:9, 11:16, 18:19), 1, 14) %>%
      set_bold(c(2:4, 10, 17, 20:21), 1) %>%
      add_footnote(
        "\\textsuperscript{a} referred to the y-value of the regression line (calculated response) for the reference value",
        border = NULL
      ) %>%
      set_escape_contents(
        22,
        everywhere, FALSE
      ) %>%
      add_footnote(
        paste("\\textsuperscript{a} reference value =", ref_conc, unit),
        border = NULL
      ) %>%
      set_escape_contents(
        23,
        everywhere, FALSE
      )
  } else {
    ht <- ht %>%
      set_left_padding(c(5:9, 11:15), 1, 14) %>%
      set_bold(c(2:4, 10, 16:17), 1)
  }

  ht <- ht %>%
    set_top_padding(1) %>%
    set_bottom_padding(2) %>%
    set_font_size(9) %>%
    set_bold(1, everywhere)

  return(ht)
}
