# Function returns a scatter plot with the a regression line fitted to the data

line_plot <- function(df, conc, pk_area, unit_conc, unit_pk_area, app = TRUE) {
  if (app == TRUE) {
    text_size <- 16
    dot_size <- 3
  } else {
    text_size <- 10
    dot_size <- 1.5
  }

  df %>%
    ggplot(aes(get(conc), get(pk_area))) +
    geom_smooth(method = lm, color = "#0460A9", se = TRUE) +
    geom_point(size = dot_size) +
    labs(
      x = paste0("Concentration [", unit_conc, "]"),
      y = paste0("Peak area [", unit_pk_area, "]")
    ) +
    theme_bw(base_size = text_size)
}
