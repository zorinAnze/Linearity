# Function returns a scatter plot with the a regression line fitted to the data

line_plot <- function(df, conc, pk_area) {
  df %>%
    ggplot(aes(get(conc), get(pk_area))) +
    geom_smooth(method = lm, color = "#0460A9", se = TRUE) +
    geom_point(size = 3) +
    labs(
      x = "Concentration [mg/ml]",
      y = "Peak area [mAU*min]"
    ) +
    theme_bw(base_size = 16)
}
