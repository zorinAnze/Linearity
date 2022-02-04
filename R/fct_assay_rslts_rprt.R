# Function returns a flextable with the assay results

assay_rslts_rprt <- function(df, lvl, conc, pk_area, unit_conc, unit_pk_area) {
  # Modify data frame
  df <- df %>%
    select(all_of(c(lvl, conc, pk_area))) %>%
    rename(
      C1 = all_of(lvl),
      C2 = all_of(conc),
      C3 = all_of(pk_area)
    )

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
  ft <- ft %>%
    set_header_labels(
      C1 = "[%]",
      C2 = paste0("[", unit_conc, "]"),
      C3 = paste0("[", unit_pk_area, "]")
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
    ) %>%
    hline(
      i = nrow(df),
      border = fp_border(color = "black", width = 0.5),
      part = "body"
    ) %>%
    padding(padding.bottom = 2, padding.top = 1, part = "all") %>%
    set_table_properties(layout = "autofit", width = 1) %>%
    fontsize(size = 9, part = "all") %>%
    bold(i = 1, part = "header") %>%
    font(fontname = "Arial", part = "all")

  return(ft)
}
