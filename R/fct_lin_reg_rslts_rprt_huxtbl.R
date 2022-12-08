# Function returns a huxtable with the linear regression results

lin_reg_rslts_rprt_huxtbl <- function(lm_fit, conc, ref_conc, declared_content) {
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
  
  
  # Define number of decimals
  num_dec <- function(num){
    case_when(num >= 0.01 ~ 4,
              num >= 0.001 ~ 5,
              num >= 0.0001 ~ 6,
              TRUE ~ 7)
  }
  
  decimals_a <- num_dec(abs(a))
  format_a <- glue("%.{decimals_a}f")
  
  decimals_b <- num_dec(abs(b))
  format_b <- glue("%.{decimals_b}f")
  
  min_res <- min(abs(res_sd), abs(res_ss))
  decimals_res <- num_dec(min_res)
  format_res <- glue("%.{decimals_res}f")
  
  # Numbers only calculated when required input is provided in the app
  if (ref_conc != 0 && declared_content != 0) {
    y_100 <- predict(lm_fit, new_data = tibble(!!conc := ref_conc)) %>%
      pull(.pred)
    
    b_rel <- b / y_100 * 100
    
    res_rel <- res_sd / y_100 * 100
    
    # Number of decimals
    decimals_y_100 <- num_dec(abs(y_100))
    format_y_100 <- glue("%.{decimals_y_100}f")
  }
  
  # Final data frame containing data in the right format
  df[1, 2] <- R
  df[2, 2] <- R2
  df[4, 2] <- sprintf(format_a, round(a, decimals_a))
  df[5, 2] <- sprintf(format_a, round(a_se, decimals_a))
  df[6, 2] <- paste0(
    sprintf(format_a, round(a_ci_l, decimals_a)), " – ",
    sprintf(format_a, round(a_ci_h, decimals_a))
  )
  df[7, 2] <- sprintf("%.4f", round(a_pval, 4))
  df[8, 2] <- a_sig
  df[10, 2] <- sprintf(format_b, round(b, decimals_b))
  df[11, 2] <- sprintf(format_b, round(b_se, decimals_b))
  df[12, 2] <- paste0(
    sprintf(format_b, round(b_ci_l, decimals_b)), " – ",
    sprintf(format_b, round(b_ci_h, decimals_b))
  )
  df[13, 2] <- sprintf("%.4f", round(b_pval, 4))
  df[14, 2] <- b_sig
  
  if (ref_conc != 0 && declared_content != 0) {
    df[15, 2] <- paste0(sprintf("%.1f", round(b_rel, 1)), "%")
    df[17, 2] <- sprintf(format_res, round(res_sd, decimals_res))
    df[18, 2] <- paste0(sprintf("%.1f", round(res_rel, 1)), "%")
    df[19, 2] <- sprintf(format_res, round(res_ss, decimals_res))
    df[20, 2] <- sprintf(format_y_100, round(y_100, decimals_y_100))
  } else {
    df[15, 2] <- sprintf(format_res, round(res_sd, decimals_res))
    df[16, 2] <- sprintf(format_res, round(res_ss, decimals_res))
  }

  # Convert data frame to huxtable
  ht <- as_huxtable(df)

  # Format huxtable
  ht <- ht %>%
    # Some Latex is needed for the superscript
    set_contents(
      3, 1,
      "Coefficient of determination (R\\textsuperscript{2})"
    ) %>%
    set_escape_contents(3, 1, FALSE) %>%
    set_contents(1, 1:2, c(
      "Statistical parameter",
      "Result"
    )) %>%
    set_top_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(nrow(ht), everywhere, brdr(0.5, "solid", "black")) %>%
    set_top_padding(1) %>%
    set_bottom_padding(2) %>%
    set_font_size(9) %>%
    set_bold(1, everywhere) 

  if (ref_conc != 0 && declared_content != 0) {
    ht <- ht %>%
      set_left_padding(c(5:9, 11:16, 18:19), 1, 14) %>%
      set_bold(c(2:4, 10, 17, 20:21), 1)
  } else {
    ht <- ht %>%
      set_left_padding(c(5:9, 11:15), 1, 14) %>%
      set_bold(c(2:4, 10, 16:17), 1)
  }

  return(ht)
}
