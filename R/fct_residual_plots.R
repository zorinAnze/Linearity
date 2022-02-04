# Function returns a combination of four diagnostic residual plots

residual_plots <- function(df, lm_fit, app = TRUE) {
  if (app == TRUE) {
    text_size <- 16
    dot_size <- 3
    dot_size_p4 <- 3.5
    stroke_size <- 1.5
  } else {
    text_size <- 10
    dot_size <- 1.5
    dot_size_p4 <- 2
    stroke_size <- 0.75
  }

  p1 <- ggplot(
    data = df,
    aes(sample = lm_fit$fit$residuals)
  ) +
    geom_qq(size = dot_size) +
    geom_qq_line(colour = "#0460A9") +
    labs(
      x = "Theoretical Quantiles",
      y = "Sample Quantiles"
    ) +
    theme_bw(base_size = text_size)


  p2 <- ggplot(
    data = df,
    aes(lm_fit$fit$fitted, lm_fit$fit$residuals)
  ) +
    geom_point(size = dot_size) +
    geom_abline(
      intercept = 0,
      slope = 0,
      color = "gray20",
      linetype = "dashed"
    ) +
    labs(
      x = "Fitted value",
      y = "Residual"
    ) +
    theme_bw(base_size = text_size)

  p3 <- ggplot(
    data = df,
    aes(x = lm_fit$fit$residuals)
  ) +
    geom_histogram(binwidth = 0.1, color = "black", fill = "#0460A9") +
    labs(
      x = "Residual",
      y = "Frequency"
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    theme_bw(base_size = text_size)

  p4 <- ggplot(
    data = df,
    aes(
      x = as.numeric(names(lm_fit$fit$residuals)),
      y = lm_fit$fit$residuals
    )
  ) +
    geom_line() +
    geom_point(
      shape = 21,
      size = dot_size_p4,
      stroke = stroke_size,
      fill = "black",
      color = "white"
    ) +
    geom_abline(
      intercept = 0,
      slope = 0,
      color = "gray20",
      linetype = "dashed"
    ) +
    labs(
      x = "Observation Order",
      y = "Residual"
    ) +
    theme_bw(base_size = text_size)

  p_comb <- grid.arrange(p1, p2, p3, p4, nrow = 2)

  return(p_comb)
}
