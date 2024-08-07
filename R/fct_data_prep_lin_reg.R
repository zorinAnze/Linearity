#' Prepare data from linear regression model in a data frame
#'
#' `data_prep_lin_reg()` prepares results of linear regression model in a data
#'  frame in a way that it can be styled afterwards by table generating
#'  packages.
#'
#' @param lm_fit a `model_fit` object from a linear regression
#' @param conc single character value. Column name of column containing
#'  concentrations
#' @param ref_conc numeric value. Reference value
#' @param unit single character value. Unit of reference value
#'
#' @return a `data.frame`
#' @export
#'
data_prep_lin_reg <- function(lm_fit, conc, ref_conc) {
  if (ref_conc != 0) {
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
      "relative",
      "Residual standard deviation",
      "absolute",
      "relative",
      "Residual sum of squares",
      "y for reference value (y = a * x + b)"
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
  R <- sprintf("%.6f", trunc_number_char(sqrt(mod_sum$r.squared), 6))

  R2 <- sprintf("%.6f", trunc_number_char(mod_sum$r.squared, 6))

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
  num_dec <- function(num) {
    case_when(
      num >= 0.01 ~ 5,
      num >= 0.001 ~ 6,
      num >= 0.0001 ~ 7,
      TRUE ~ 8
    )
  }

  decimals_a <- num_dec(abs(a))
  format_a <- glue("%.{decimals_a}f")

  decimals_b <- num_dec(abs(b))
  format_b <- glue("%.{decimals_b}f")

  min_res <- min(abs(res_sd), abs(res_ss))
  decimals_res <- num_dec(min_res)
  format_res <- glue("%.{decimals_res}f")

  # Numbers only calculated when required input is provided in the app
  if (ref_conc != 0) {
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
  df[4, 2] <- sprintf(format_a, trunc_number_char(a, decimals_a))
  df[5, 2] <- sprintf(format_a, trunc_number_char(a_se, decimals_a))
  df[6, 2] <- paste0(
    sprintf(format_a, trunc_number_char(a_ci_l, decimals_a)), " – ",
    sprintf(format_a, trunc_number_char(a_ci_h, decimals_a))
  )
  df[7, 2] <- sprintf("%.5f", trunc_number_char(a_pval, 5))
  df[8, 2] <- a_sig
  df[10, 2] <- sprintf(format_b, trunc_number_char(b, decimals_b))
  df[11, 2] <- sprintf(format_b, trunc_number_char(b_se, decimals_b))
  df[12, 2] <- paste0(
    sprintf(format_b, trunc_number_char(b_ci_l, decimals_b)), " – ",
    sprintf(format_b, trunc_number_char(b_ci_h, decimals_b))
  )
  df[13, 2] <- sprintf("%.5f", trunc_number_char(b_pval, 5))
  df[14, 2] <- b_sig

  if (ref_conc != 0) {
    df[15, 2] <- paste0(sprintf("%.5f", trunc_number_char(b_rel, 5)), "%")
    df[17, 2] <- sprintf(format_res, trunc_number_char(res_sd, decimals_res))
    df[18, 2] <- paste0(sprintf("%.5f", trunc_number_char(res_rel, 5)), "%")
    df[19, 2] <- sprintf(format_res, trunc_number_char(res_ss, decimals_res))
    df[20, 2] <- sprintf(format_y_100, trunc_number_char(y_100, decimals_y_100))
  } else {
    df[15, 2] <- sprintf(format_res, trunc_number_char(res_sd, decimals_res))
    df[16, 2] <- sprintf(format_res, trunc_number_char(res_ss, decimals_res))
  }

  return(df)
}
