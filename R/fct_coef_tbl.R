# Function returns a reactable with coefficients of a linear model

coef_tbl <- function(lm_fit) {
  tidy(lm_fit, conf.int = TRUE) %>%
    select(
      term, estimate, std.error, conf.low, conf.high, statistic,
      p.value
    ) %>%
    reactable(
      columns = list(
        term = colDef(
          name = "Term",
          minWidth = 200
        ),
        estimate = colDef(
          name = "Coef",
          format = colFormat(digits = 4),
          minWidth = 85
        ),
        std.error = colDef(
          name = "SE Coef",
          format = colFormat(digits = 4),
          minWidth = 85
        ),
        conf.low = colDef(
          name = "95% CI (low)",
          format = colFormat(digits = 4),
          minWidth = 85
        ),
        conf.high = colDef(
          name = "95% CI (high)",
          format = colFormat(digits = 4),
          minWidth = 85
        ),
        statistic = colDef(
          name = "t-statistic",
          format = colFormat(digits = 4),
          minWidth = 85
        ),
        p.value = colDef(
          name = "p-value",
          format = colFormat(digits = 4),
          minWidth = 75
        )
      ),
      sortable = FALSE,
      borderless = TRUE,
      striped = TRUE,
      class = "lm_tbl",
      rowClass = "lm_row",
      theme = reactableTheme(
        borderColor = "black",
        borderWidth = "1.5px"
      )
    )
}
