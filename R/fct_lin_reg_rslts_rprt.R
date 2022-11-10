# Function returns a flextable with the linear regression results

lin_reg_rslts_rprt <- function(lm_fit, conc, ref_conc, declared_content) {
  # Generate initial data frame
  if (ref_conc != 0 && declared_content != 0) {
    C1 <- c(
      "Correlation coefficient (R)",
      "Coefficient of determination (R2)",
      "Slope of the regression line (a)",
      "absolute",
      "Standard error",
      "Confidence interval (P = 0.95)",
      "P-Value",
      "Significantly different from 0?",
      "y-intercept (b)",
      "absolute",
      "Standard error",
      "Confidence interval (P = 0.95)",
      "P-Value",
      "Significantly different from 0?",
      paste0("relative to ", declared_content, "% of declared content"),
      #paste0("y for x = ", declared_content, "% (y = a * x + b)"),
      "Residual standard deviation",
      "absolute",
      paste0("relative to ", declared_content, "% of declared content"),
      "Residual sum of squares",
      paste0("y for x = ", declared_content, "% (y = a * x + b)")
    )
  } else {
    C1 <- c(
      "Correlation coefficient (R)",
      "Coefficient of determination (R2)",
      "Slope of the regression line (a)",
      "absolute",
      "Standard error",
      "Confidence interval (P = 0.95)",
      "P-Value",
      "Significantly different from 0?",
      "y-intercept (b)",
      "absolute",
      "Standard error",
      "Confidence interval (P = 0.95)",
      "P-Value",
      "Significantly different from 0?",
      "Residual standard deviation",
      "Residual sum of squares"
    )
  }

  C2 <- rep(NA, length(C1))

  df <- tibble(C1, C2)

  # Summarise model
  mod_coef <- tidy(lm_fit, conf.int = TRUE)
  mod_sum <- glance(lm_fit)

  # Extract individual parameters
  R <- sprintf("%.5f", round(sqrt(mod_sum$r.squared), 5))

  R2 <- sprintf("%.5f", round(mod_sum$r.squared, 5))

  a <- mod_coef %>%
    filter(term != "(Intercept)") %>%
    pull(estimate)

  a_se <- mod_coef %>%
    filter(term != "(Intercept)") %>%
    pull(std.error)

  a_ci_l <- mod_coef %>%
    filter(term != "(Intercept)") %>%
    pull(conf.low)

  a_ci_h <- mod_coef %>%
    filter(term != "(Intercept)") %>%
    pull(conf.high)
  
  a_pval <- mod_coef %>%
    filter(term != "(Intercept)") %>%
    pull(p.value)
  
  a_sig <- if_else(a_pval <= 0.05, "yes", "no")

  b <- mod_coef %>%
    filter(term == "(Intercept)") %>%
    pull(estimate)

  b_se <- mod_coef %>%
    filter(term == "(Intercept)") %>%
    pull(std.error)

  b_ci_l <- mod_coef %>%
    filter(term == "(Intercept)") %>%
    pull(conf.low)

  b_ci_h <- mod_coef %>%
    filter(term == "(Intercept)") %>%
    pull(conf.high)
  
  b_pval <- mod_coef %>%
    filter(term == "(Intercept)") %>%
    pull(p.value)
  
  b_sig <- if_else(b_pval <= 0.05, "yes", "no")

  res_sd <- mod_sum %>%
    pull(sigma)

  res_ss <- mod_sum %>%
    pull(deviance)

  if (ref_conc != 0 && declared_content != 0) {
    y_100 <- predict(lm_fit, new_data = tibble(!!conc := ref_conc)) %>%
      pull(.pred)

    b_rel <- b / y_100 * 100

    res_rel <- res_sd / y_100 * 100
  }

  # Final data frame containing data in the right format
  df[1, 2] <- R
  df[2, 2] <- R2
  df[4, 2] <- sprintf("%.4f", round(a, 4))
  df[5, 2] <- sprintf("%.4f", round(a_se, 4))
  df[6, 2] <- paste0(
    sprintf("%.4f", round(a_ci_l, 4)), " – ",
    sprintf("%.4f", round(a_ci_h, 4))
  )
  df[7, 2] <- sprintf("%.4f", round(a_pval, 4))
  df[8, 2] <- a_sig
  df[10, 2] <- sprintf("%.4f", round(b, 4))
  df[11, 2] <- sprintf("%.4f", round(b_se, 4))
  df[12, 2] <- paste0(
    sprintf("%.4f", round(b_ci_l, 4)), " – ",
    sprintf("%.4f", round(b_ci_h, 4))
  )
  df[13, 2] <- sprintf("%.4f", round(b_pval, 4))
  df[14, 2] <- b_sig

  if (ref_conc != 0 && declared_content != 0) {
    df[15, 2] <- paste0(sprintf("%.1f", round(b_rel, 1)), "%")
    df[17, 2] <- sprintf("%.4f", round(res_sd, 4))
    df[18, 2] <- paste0(sprintf("%.1f", round(res_rel, 1)), "%")
    df[19, 2] <- sprintf("%.4f", round(res_ss, 4))
    df[20, 2] <- sprintf("%.4f", round(y_100, 4))
  } else {
    df[15, 2] <- sprintf("%.4f", round(res_sd, 4))
    df[16, 2] <- sprintf("%.4f", round(res_ss, 4))
  }

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
  ft <- ft %>%
    compose(i = 2, j = 1, value = as_paragraph(
      "Coefficient of determination (R", as_sup("2"), ")"
    )) %>%
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
    padding(padding.bottom = 2, padding.top = 1, part = "all")

  if (ref_conc != 0 && declared_content != 0) {
    ft <- ft %>%
      padding(
        i = c(4:8, 10:15, 17:18), j = 1,
        padding.left = 14, part = "body"
      ) %>% 
      bold(i = c(1:3, 9, 16, 19:20), j = 1)
  } else {
    ft <- ft %>%
      padding(
        i = c(4:8, 10:14), j = 1,
        padding.left = 14, part = "body"
      ) %>% 
      bold(i = c(1:3, 9, 15:16), j = 1)
  }

  ft <- ft %>%
    set_table_properties(layout = "autofit", width = 1) %>%
    fontsize(size = 9, part = "all") %>%
    bold(part = "header") %>%
    font(fontname = "Arial", part = "all")

  return(ft)
}
