#' Create summary table for homoscedasticity check for PDF report
#'
#' `homosced_tbl_rprt_huxtbl()` creates a table containing all relevant
#' parameters for homoscedasticity check
#'
#' @param lm_fit a `model_fit` object from a linear regression
#' @param c_test a list with class `htest`; is the output of the function
#'  `cochran.test()` from the `{outliers}` package
#' @param anova_res an object of class `anova`
#'
#' @return a `huxtable` object
#' @export
#'
homosced_tbl_rprt_huxtbl <- function(lm_fit, c_test, anova_res) {

  # Combine data to data frame
  df <- data_prep_homosced(lm_fit, c_test, anova_res)

  # Convert data frame to huxtable
  ht <- as_huxtable(df)

  # Format flextable
  ht <- ht %>%
    set_contents(1, 1:2, c(
      "Statistical parameter",
      "Result"
    )) %>%
    set_top_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(nrow(ht), everywhere, brdr(0.5, "solid", "black")) %>%
    set_top_padding(1) %>%
    set_bottom_padding(2) %>%
    set_left_padding(6, 1, 14) %>%
    set_font_size(9) %>%
    set_bold(1, everywhere)

  return(ht)
}
