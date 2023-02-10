#' Summarize linear regression model for displaying in datatable
#'
#' `smmry_tbl_datatbl()` creates a summary table of a linear regression model
#'
#' @param lm_fit a `model_fit` object from a linear regression
#'
#' @return a datatable
#' @export
#'
smmry_tbl_datatbl <- function(lm_fit) {
  glance(lm_fit) %>%
    mutate(r = sqrt(r.squared)) %>%
    select(sigma, r, r.squared, statistic, p.value, AIC, BIC) %>%
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
        "S" = "sigma",
        "R" = "r",
        "R-sq" = "r.squared",
        "F-value" = "statistic",
        "p-value" = "p.value",
        "AIC" = "AIC",
        "BIC" = "BIC"
      )
    ) %>%
    formatRound(columns = c(1:7), digits = 4, mark = "")
}
