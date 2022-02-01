# Function returns a flextable with the assay results

assay_rslts_rprt <- function(df, lvl, conc, pk_area) {
  # if multiple peak areas per concentration level
  mult <- length(df[[lvl]]) / length(unique(df[[lvl]]))
  brdr_vec <- seq(mult, length(df[[lvl]]), mult)

  # Modify data frame
  df <- df %>%
    select(lvl, conc, pk_area) %>%
    rename(
      C1 = lvl,
      C2 = conc,
      C3 = pk_area
    )

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
  ft <- ft %>%
    set_header_labels(
      C1 = "[%]",
      C2 = "[mg/ml]",
      C3 = "[mAU∙min]"
    ) %>%
    add_header_row(
      values = c(
        "Concentration level",
        "Concentration of solution ",
        "Peak area"
      ),
      colwidths = c(1, 1, 1)
    ) %>%
    align(align = "center", part = "all") %>%
    border_remove() %>%
    hline_top(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    ) %>%
    hline_bottom(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    )

  if (mult > 1) {
    ft <- ft %>%
      hline(
        i = brdr_vec,
        border = fp_border(color = "black", width = 0.5),
        part = "body"
      )
  } else {
    ft <- ft %>%
      hline(
        i = nrow(df),
        border = fp_border(color = "black", width = 0.5),
        part = "body"
      )
  }

  ft <- ft %>%
    padding(padding.bottom = 2, padding.top = 1, part = "all") %>%
    set_table_properties(layout = "autofit", width = 1) %>%
    fontsize(size = 9, part = "all") %>%
    bold(i = 1, part = "header") %>%
    font(fontname = "Arial", part = "all")

  return(ft)
}
