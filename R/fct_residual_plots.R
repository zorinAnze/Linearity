# Function returns a combination of four diagnostic residual plots

residual_plots <- function(df, lm_fit, x_lab, app = TRUE) {
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
    theme_bw(base_size = text_size) +
    ggtitle("Quantile-Quantile Plot") +
    theme(plot.title = element_text(
      face = "bold",
      size = rel(1.4)
    ))


  p2 <- ggplot(
    data = df,
    aes(lm_fit$fit$model[, 2], lm_fit$fit$residuals)
  ) +
    geom_point(size = dot_size) +
    geom_abline(
      intercept = 0,
      slope = 0,
      color = "gray20",
      linetype = "dashed"
    ) +
    labs(
      x = x_lab,
      y = "Residual"
    ) +
    theme_bw(base_size = text_size) +
    ggtitle("Residuals vs Independent Values Plot") +
    theme(plot.title = element_text(
      face = "bold",
      size = rel(1.4)
    ))

  # Calculate optimal binwidth with Freedmann-Diaconis rule
  bw <- 2 * IQR(lm_fit$fit$residuals) / length(lm_fit$fit$residuals)^(1 / 3)

  p3 <- ggplot(
    data = df,
    aes(x = lm_fit$fit$residuals)
  ) +
    geom_histogram(binwidth = bw, color = "black", fill = "#0460A9") +
    labs(
      x = "Residual",
      y = "Frequency"
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    theme_bw(base_size = text_size) +
    ggtitle("Residual Histogram") +
    theme(plot.title = element_text(
      face = "bold",
      size = rel(1.4)
    ))

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
    theme_bw(base_size = text_size) +
    ggtitle("Residual vs Order Plot") +
    theme(plot.title = element_text(
      face = "bold",
      size = rel(1.4)
    ))
      
    return(list(p1 = p1, p2 = p2, p3 = p3, p4 = p4))
}
