# Function returns a huxtable with the results from homoscedasticity check
# (required by ANVISA)

homosced_tbl_rprt_huxtbl <- function(lm_fit, c_test, anova_res) {
  C1 <- c(
    "Regression Intercept P-Value",
    "Regression Slope P-Value",
    "ANOVA for Regression P-Value",
    "Cochran Test P-Value",
    "Homogeneity of Variance",
    "Normality Test for External Studentized Residuals P-Value"
  )

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
    "Variance is Heteroscedastic"
  )

  normal_pval <- shapiro.test(rstudent(lm_fit$fit))$p.value

  # Final data frame containing data in the right format
  df[1, 2] <- sprintf("%.4f", round(b_pval, 4))
  df[2, 2] <- sprintf("%.4f", round(a_pval, 4))
  df[3, 2] <- sprintf("%.4f", round(anova_pval, 4))
  df[4, 2] <- sprintf("%.4f", round(c_test_pval, 4))
  df[5, 2] <- homo_var
  df[6, 2] <- sprintf("%.4f", round(normal_pval, 4))

  # Convert data frame to huxtable
  ht <- as_huxtable(df)

  # Format flextable
  ht <- ht %>%
    set_contents(1, 1:2, c(
      "Statistical parameter",
      "Result"
    )) %>%
    set_top_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(nrow(ht), everywhere, brdr(0.5, "solid", "black")) %>%
    set_top_padding(1) %>%
    set_bottom_padding(2) %>%
    set_left_padding(6, 1, 14) %>%
    set_font_size(9) %>%
    set_bold(1, everywhere)

  return(ht)
}
