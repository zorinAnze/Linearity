#' Create regression plot
#'
#' `line_plot()` creates a scatter plot with a fitted linear regression line.
#' Reference concentration is also represented in the plot.
#'
#' @param df dataset
#' @param conc single character value. Column name of column containing
#'  concentrations
#' @param pk_area single character value. Column name of column containing
#'  measured values, usually peak area
#' @param lab_x_axis single character value. X-axis label
#' @param lab_y_axis single character value. Y-axis label
#' @param lm_fit a `model_fit` object from a linear regression
#' @param ref_conc numeric value. Reference concentration
#' @param plt_title single character value. Title of the plot
#' @param app if FALSE, font size, line size and dot size are decreased e.g.
#'  for including plot in report.
#'
#' @return a `ggplot` object
#' @export
#'
line_plot <- function(df, conc, pk_area, lab_x_axis, lab_y_axis,
                      lm_fit, ref_conc, plt_title, app = TRUE) {
  if (app == TRUE) {
    text_size <- 16
    dot_size <- 3
    line_size <- 1
  } else {
    text_size <- 10
    dot_size <- 1.5
    line_size <- 0.5
  }

  # Summarise model
  mod_coef <- tidy(lm_fit, conf.int = TRUE)
  mod_sum <- glance(lm_fit)

  # Extract individual parameters

  # Define number of decimals
  num_dec <- function(num) {
    case_when(
      num >= 0.01 ~ 4,
      num >= 0.001 ~ 5,
      num >= 0.0001 ~ 6,
      TRUE ~ 7
    )
  }

  R <- sprintf("%.5f", round2(sqrt(mod_sum$r.squared), 5))

  a <- mod_coef %>%
    filter(term != "(Intercept)") %>%
    pull(estimate)

  decimals_a <- num_dec(abs(a))
  format_a <- glue("%.{decimals_a}f")

  a <- sprintf(format_a, round2(a, decimals_a))

  b <- mod_coef %>%
    filter(term == "(Intercept)") %>%
    pull(estimate)

  decimals_b <- num_dec(abs(b))
  format_b <- glue("%.{decimals_b}f")

  b_abs <- sprintf(format_b, round2(abs(b), decimals_b))
  b_sign <- if_else(b >= 0, "+", "-")

  # Equation of regression line
  eq <- glue("y = {a}x {b_sign} {b_abs}\nR = {R}")

  y_100 <- predict(lm_fit, new_data = tibble(!!conc := ref_conc)) %>%
    pull(.pred)

  p1 <- df %>%
    ggplot(aes_string(conc, pk_area))

  if (ref_conc != 0) {
    p1 <- p1 +
      annotate("segment",
        x = ref_conc, xend = ref_conc, y = -Inf, yend = y_100,
        colour = "gray20", size = line_size, linetype = "dashed"
      ) +
      annotate("segment",
        x = -Inf, xend = ref_conc, y = y_100, yend = y_100,
        colour = "gray20", size = line_size, linetype = "dashed"
      )
  }

  p1 <- p1 +
    geom_smooth(
      method = lm, formula = y ~ x,
      color = "#0460A9", size = line_size, se = TRUE,
      fullrange = TRUE, na.rm = TRUE
    ) +
    geom_point(size = dot_size) +
    # Extend the regression line and the CIs to 0 (scale_x_continuous,
    # scale_y_continuous, coord_cartesian)
    scale_x_continuous(expand = c(0, 0), limits = c(
      (0 - min(df[[conc]])),
      max(df[[conc]]) * 1.5
    )) +
    scale_y_continuous(expand = c(0, 0), limits = c(
      (0 - min(df[[pk_area]])),
      max(df[[pk_area]]) * 1.5
    )) +
    coord_cartesian(
      xlim = c(0, max(df[[conc]]) * 1.05),
      ylim = c(0, max(df[[pk_area]]) * 1.05)
    ) +
    labs(
      x = lab_x_axis,
      y = lab_y_axis
    ) +
    theme_bw(base_size = text_size) +
    annotate("text",
      label = eq,
      x = 0.05 * max(df[[conc]]),
      y = 0.95 * max(df[[pk_area]]),
      size = text_size * 0.36,
      hjust = 0, vjust = 1
    )

  if (plt_title != "") {
    p1 <- p1 +
      ggtitle(plt_title) +
      theme(plot.title = element_text(
        face = "bold",
        size = rel(1.4)
      ))
  }

  return(p1)
}
