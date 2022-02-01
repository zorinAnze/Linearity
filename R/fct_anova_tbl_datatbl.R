# Function returns a datatable of anova results from a linear model

anova_tbl_datatbl <- function(anova_fit) {
  tidy(anova_fit) %>%
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
