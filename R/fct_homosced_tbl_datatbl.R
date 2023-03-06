#' Summarize homoscedasticity test results for displaying in datatable
#'
#' `homosced_tbl_datatbl()` creates a summary table of homoscedasticity test
#' results. Homoscedasticity tests are used to evaluate the variance of
#' analytical responses.
#'
#' @param c_test a list with class `htest`; is the output of the function
#'  `cochran.test()` from the `{outliers}` package
#' @param l_test a data.frame; is the output of the function
#'  `leveneTest()` from the `{car}` package
#' @param f_test a list with class `htest`; is the output of the function
#'  `fligner.test()` from the `{stats}` package
#'
#' @return a datatable
#' @export
#'
homosced_tbl_datatbl <- function(c_test, l_test, f_test) {
  tibble(
    Method = c("Cochran Test", "Levene Test", "Fligner-Killeen Test"),
    `p-value` = c(c_test$p.value, l_test$`Pr(>F)`[1], f_test$p.value)
  ) %>%
    datatable(
      options = list(
        searching = FALSE,
        paging = FALSE,
        ordering = FALSE,
        info = FALSE,
        lengthChange = FALSE,
        scrollX = TRUE
      ),
      rownames = FALSE
    ) %>%
    formatRound(columns = 2, digits = 4, mark = "")
}
