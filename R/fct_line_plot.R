# Function returns a scatter plot with the a regression line fitted to the data

line_plot <- function(df, conc, pk_area, lab_x_axis, lab_y_axis,
                      lm_fit, ref_conc, app = TRUE) {
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

  df %>%
    ggplot(aes(get(conc), get(pk_area))) +
    annotate("segment",
      x = ref_conc, xend = ref_conc, y = -Inf, yend = y_100,
      colour = "gray20", size = line_size, linetype = "dashed"
    ) +
    annotate("segment",
      x = -Inf, xend = ref_conc, y = y_100, yend = y_100,
      colour = "gray20", size = line_size, linetype = "dashed"
    ) +
    geom_smooth(method = lm, color = "#0460A9", size = line_size, se = TRUE) +
    geom_point(size = dot_size) +
    labs(
      x = lab_x_axis,
      y = lab_y_axis
    ) +
    theme_bw(base_size = text_size)
}
