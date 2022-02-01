# Function returns a summary of a linear model

smmry_tbl_datatbl <- function(lm_fit) {
  glance(lm_fit) %>%
    select(sigma, r.squared, adj.r.squared, statistic, p.value, AIC, BIC) %>%
    datatable(
      options = list(
        searching = FALSE,
        paging = FALSE,
        ordering = FALSE,
        info = FALSE,
        lengthChange = FALSE
      ),
      rownames = FALSE,
      colnames = c(
        "S" = "sigma",
        "R-sq" = "r.squared",
        "R-sq (adj)" = "adj.r.squared",
        "F-value" = "statistic",
        "p-value" = "p.value",
        "AIC" = "AIC",
        "BIC" = "BIC"
      )
    ) %>% 
    formatRound(columns = c(1:7), digits = 4, mark = "")
}
