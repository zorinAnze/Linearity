# Function returns a datatable with coefficients of a linear model

coef_tbl_datatbl <- function(lm_fit) {
  tidy(lm_fit, conf.int = TRUE) %>%
    select(
      term, estimate, std.error, conf.low, conf.high, statistic,
      p.value
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
      rownames = FALSE,
      colnames = c(
        "Term" = "term",
        "Coef" = "estimate",
        "SE Coef" = "std.error",
        "95% CI (low)" = "conf.low",
        "95% CI (high)" = "conf.high",
        "t-statistic" = "statistic",
        "p-value" = "p.value"
      )
    ) %>%
    formatRound(columns = c(2:7), digits = 4, mark = "")
}
