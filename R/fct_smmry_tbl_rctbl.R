# Function returns a summary of a linear model

smmry_tbl_rctbl <- function(lm_fit) {
  glance(lm_fit) %>%
    select(sigma, r.squared, adj.r.squared, statistic, p.value, AIC, BIC) %>%
    reactable(
      columns = list(
        sigma = colDef(
          name = "S",
          format = colFormat(digits = 4)
        ),
        r.squared = colDef(
          name = "R-sq",
          format = colFormat(digits = 4)
        ),
        adj.r.squared = colDef(
          name = "R-sq (adj)",
          format = colFormat(digits = 4)
        ),
        statistic = colDef(
          name = "F-value",
          format = colFormat(digits = 4)
        ),
        p.value = colDef(
          name = "p-value",
          format = colFormat(digits = 4)
        ),
        AIC = colDef(format = colFormat(digits = 4)),
        BIC = colDef(format = colFormat(digits = 4))
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
