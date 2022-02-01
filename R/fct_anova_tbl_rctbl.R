# Function returns a reactable of anova results from a linear model

anova_tbl_rctbl <- function(anova_fit) {
  tidy(anova_fit) %>%
    reactable(
      columns = list(
        term = colDef(
          name = "Term",
          minWidth = 200
        ),
        df = colDef(
          name = "DF",
          minWidth = 55
        ),
        sumsq = colDef(
          name = "Sum Sq",
          format = colFormat(digits = 4),
          minWidth = 90
        ),
        meansq = colDef(
          name = "Mean Sq",
          format = colFormat(digits = 4),
          minWidth = 90
        ),
        statistic = colDef(
          name = "F-value",
          format = colFormat(digits = 4),
          minWidth = 90
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
