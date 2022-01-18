# Function returns a combination of four diagnostic residual plots

residual_plots <- function(df, lm_fit) {
  p1 <- ggplot(
    data = df,
    aes(sample = lm_fit$fit$residuals)
  ) +
    geom_qq(size = 3) +
    geom_qq_line(colour = "#0460A9") +
    labs(
      x = "Theoretical Quantiles",
      y = "Sample Quantiles"
    ) +
    theme_bw(base_size = 16)


  p2 <- ggplot(
    data = df,
    aes(lm_fit$fit$fitted, lm_fit$fit$residuals)
  ) +
    geom_point(size = 3) +
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
    theme_bw(base_size = 16)

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
    theme_bw(base_size = 16)

  p4 <- ggplot(
    data = df,
    aes(
      x = as.numeric(names(lm_fit$fit$residuals)),
      y = lm_fit$fit$residuals
    )
  ) +
    geom_point(size = 3) +
    geom_line() +
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
    theme_bw(base_size = 16)
  
  p_comb <- grid.arrange(p1, p2, p3, p4, nrow = 2)
  
  return(p_comb)
}
