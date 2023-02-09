#' Summarize ANOVA for displaying in datatable
#'
#' `anova_tbl_datatbl()` creates a summary table of the ANOVA for
#' the linear regression model.
#'
#' @param anova_fit an object of class `anova`
#'
#' @return a datatable
#' @export
#'
anova_tbl_datatbl <- function(anova_fit) {
  tidy(anova_fit) %>%
    datatable(
      options = list(
        searching = FALSE,
        paging = FALSE,
        ordering = FALSE,
        info = FALSE,
        lengthChange = FALSE,
        scrollX = TRUE
      ),
      rownames = FALSE,
      colnames = c(
        "Term" = "term",
        "DF" = "df",
        "Sum Sq" = "sumsq",
        "Mean Sq" = "meansq",
        "F-value" = "statistic",
        "p-value" = "p.value"
      )
    ) %>%
    formatRound(columns = c(3:6), digits = 4, mark = "")
}
