#' Summarize Cochran test results for displaying in datatable
#'
#' `cochran_tbl_datatbl()` creates a summary table of Cochran test results.
#' Cochran’s C test is used to evaluate the variance of analytical responses.
#'
#' @param c_test a list with class `htest`; is the output of the function
#'  `cochran.test()` from the `{outliers}` package
#'
#' @return a datatable
#' @export
#'
cochran_tbl_datatbl <- function(c_test) {
  tibble(
    Method = c_test$method,
    C = unname(c_test$statistic),
    DF = unname(c_test$parameter[1]),
    k = unname(c_test$parameter[2]),
    `p-value` = c_test$p.value
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
    formatRound(columns = c(2, 5), digits = 4, mark = "")
}
