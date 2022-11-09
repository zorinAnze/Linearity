# Function returns a flextable with the assay results (without concentration
# levels)

assay_rslts_rprt_smpl <- function(df, conc, pk_area, title_conc,
                                  title_pk_area, prjct_title) {

  # Modify data frame
  df <- df %>%
    select(all_of(c(conc, pk_area))) %>%
    rename(
      C1 = all_of(conc),
      C2 = all_of(pk_area)
    )

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
  ft <- ft %>%
    set_header_labels(
      C1 = title_conc,
      C2 = title_pk_area
    ) %>%
    colformat_num(j = 1, big.mark = "")

  # Add project title, if provided
  if (prjct_title != "") {
    ft <- ft %>%
      add_header_lines(values = c(prjct_title))
  }

  ft <- ft %>%
    align(align = "center", part = "all") %>%
    border_remove() %>%
    hline_top(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    )

  # Add horizontal line after project title
  if (prjct_title != "") {
    ft <- ft %>%
      hline(
        i = 1,
        border = fp_border(color = "black", width = 0.5),
        part = "header"
      )
  }

  ft <- ft %>%
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
    fontsize(size = 9, part = "all")
  
  if (prjct_title != "") {
    ft <- ft %>%
      bold(i = 1:2, part = "header")
  } else {
    ft <- ft %>%
      bold(i = 1, part = "header")
  }
  
  ft <- ft %>%
    font(fontname = "Arial", part = "all")

  return(ft)

  # add_header_row
}
