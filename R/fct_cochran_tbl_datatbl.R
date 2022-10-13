# Function returns a datatable of Cochran test results for a linear model

cochran_tbl_datatbl <- function(c_test) {
  tibble(Method = c_test$method,
                    C = unname(c_test$statistic),
                    DF = unname(c_test$parameter[1]),
                    k = unname(c_test$parameter[2]),
                    `p-value` = c_test$p.value) %>% 
    datatable(
      options = list(
        searching = FALSE,
        paging = FALSE,
        ordering = FALSE,
        info = FALSE,
        lengthChange = FALSE,
        scrollX = TRUE
      ),
      rownames = FALSE) %>% 
    formatRound(columns = c(2,5), digits = 4, mark = "")

}
