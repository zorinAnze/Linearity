# Function returns a scatter plot with the a regression line fitted to the data

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
    coord_cartesian(xlim = c(0, max(df[[conc]]) * 1.05),
                    ylim = c(0, max(df[[pk_area]]) * 1.05)
                    ) +
    labs(
      x = lab_x_axis,
      y = lab_y_axis
    ) +
    theme_bw(base_size = text_size)

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
