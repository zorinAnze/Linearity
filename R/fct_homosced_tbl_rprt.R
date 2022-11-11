# Function returns a flextable with the results from homoscedasticity check 
# (required by ANVISA)

homosced_tbl_rprt <- function (lm_fit, c_test, anova_res) {
  
  C1 <- c("Intercept P-Value",
          "Slope P-Value",
          "ANOVA P-Value",
          "Cochran Test P-Value",
          "Homogeneity of Variance",
          "Normality Test for External Studentized Residuals P-Value")
  
  C2 <- rep(NA, length(C1))
  
  df <- tibble(C1, C2)
  
  # Summarise model
  mod_coef <- tidy(lm_fit, conf.int = TRUE)
  
  # Extract individual parameters
  b_pval <- mod_coef %>%
    filter(term == "(Intercept)") %>%
    pull(p.value)
  
  a_pval <- mod_coef %>%
    filter(term != "(Intercept)") %>%
    pull(p.value)
  
  anova_pval <- tidy(anova_res) %>% 
    filter(term != "Residuals") %>%
    pull(p.value)
  
  # Cochran test p-value
  c_test_pval <- c_test$p.value
  
  homo_var <- if_else(c_test_pval > 0.05, "Variance is Homoscedastic",
                      "Variance is Heteroscedastic")
  
  normal_pval <- shapiro.test(rstudent(lm_fit$fit))$p.value
  
  # Final data frame containing data in the right format
  df[1, 2] <- sprintf("%.4f", round(b_pval, 4))
  df[2, 2] <- sprintf("%.4f", round(a_pval, 4))
  df[3, 2] <- sprintf("%.4f", round(anova_pval, 4))
  df[4, 2] <- sprintf("%.4f", round(c_test_pval, 4))
  df[5, 2] <- homo_var
  df[6, 2] <- sprintf("%.4f", round(normal_pval, 4))
  
  # Convert data frame to flextable
  ft <- flextable(df)
  
  # Format flextable
  ft <- ft %>%
    set_header_labels(
      C1 = "Statistical parameter",
      C2 = "Result"
    ) %>%
    border_remove() %>%
    hline_top(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    ) %>%
    hline_bottom(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    ) %>%
    hline_bottom(
      border = fp_border(color = "black", width = 0.5),
      part = "body"
    ) %>%
    padding(padding.bottom = 2, padding.top = 1, part = "all") %>% 
    padding(
      i = 5, j = 1,
      padding.left = 14, part = "body"
    ) %>% 
    set_table_properties(layout = "autofit", width = 1) %>%
    fontsize(size = 9, part = "all") %>%
    bold(part = "header") %>%
    font(fontname = "Arial", part = "all")
  
  return(ft)
}