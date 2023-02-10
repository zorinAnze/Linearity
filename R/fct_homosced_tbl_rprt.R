#' Create summary table for homoscedasticity check for Word report
#'
#' `homosced_tbl_rprt()` creates a table containing all relevant
#' parameters for homoscedasticity check
#'
#' @param lm_fit a `model_fit` object from a linear regression
#' @param c_test a list with class `htest`; is the output of the function
#'  `cochran.test()` from the `{outliers}` package
#' @param anova_res an object of class `anova`
#'
#' @return a `flextable` object
#' @export
#'
homosced_tbl_rprt <- function(lm_fit, c_test, anova_res) {

  # Combine data to data frame
  df <- data_prep_homosced(lm_fit, c_test, anova_res)

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
  ft <- ft %>%
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
    ) %>%
    padding(padding.bottom = 2, padding.top = 1, part = "all") %>%
    padding(
      i = 5, j = 1,
      padding.left = 14, part = "body"
    ) %>%
    set_table_properties(layout = "autofit", width = 1) %>%
    fontsize(size = 9, part = "all") %>%
    flextable::bold(part = "header") %>%
    flextable::font(fontname = "Arial", part = "all")

  return(ft)
}
