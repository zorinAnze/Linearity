#' Summarize parameters relevant for homoscedasticity check
#'
#' `data_prep_homosced()` prepares parameters from linear regression model,
#'  Cochran test and ANOVA in a data frame in a way that it can be styled
#'  afterwards by table generating packages.
#'
#' @param lm_fit a `model_fit` object from a linear regression
#' @param c_test a list with class `htest`; is the output of the function
#'  `cochran.test()` from the `{outliers}` package
#' @param l_test a data.frame; is the output of the function
#'  `leveneTest()` from the `{car}` package
#' @param f_test a list with class `htest`; is the output of the function
#'  `fligner.test()` from the `{stats}` package
#' @param anova_res an object of class `anova`
#'
#' @return a `data.frame`
#' @export
#'
data_prep_homosced <- function(lm_fit, c_test, l_test, f_test, anova_res) {
  C1 <- c(
    "Regression Intercept P-Value",
    "Regression Slope P-Value",
    "ANOVA for Regression P-Value",
    "Cochran Test P-Value",
    "Homogeneity of Variance (Cochran Test)",
    "Levene Test P-Value",
    "Homogeneity of Variance (Levene Test)",
    "Fligner-Killeen Test P-Value",
    "Homogeneity of Variance (Fligner-Killeen Test)",
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

  c_homo_var <- if_else(c_test_pval > 0.05, "Variance is Homoscedastic",
    "Variance is Heteroscedastic"
  )
  
  l_test_pval <- l_test$`Pr(>F)`[1]
  
  l_homo_var <- if_else(l_test_pval > 0.05, "Variance is Homoscedastic",
                        "Variance is Heteroscedastic"
  )
  
  f_test_pval <- f_test$p.value
  
  f_homo_var <- if_else(f_test_pval > 0.05, "Variance is Homoscedastic",
                        "Variance is Heteroscedastic"
  )
  

  normal_pval <- shapiro.test(rstudent(lm_fit$fit))$p.value

  # Final data frame containing data in the right format
  df[1, 2] <- sprintf("%.4f", trunc_number(b_pval, 4))
  df[2, 2] <- sprintf("%.4f", trunc_number(a_pval, 4))
  df[3, 2] <- sprintf("%.4f", trunc_number(anova_pval, 4))
  df[4, 2] <- sprintf("%.4f", trunc_number(c_test_pval, 4))
  df[5, 2] <- c_homo_var
  df[6, 2] <- sprintf("%.4f", trunc_number(l_test_pval, 4))
  df[7, 2] <- l_homo_var
  df[8, 2] <- sprintf("%.4f", trunc_number(f_test_pval, 4))
  df[9, 2] <- f_homo_var
  df[10, 2] <- sprintf("%.4f", trunc_number(normal_pval, 4))

  return(df)
}
