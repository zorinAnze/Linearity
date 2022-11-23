# Function returns a flextable with the assay results

assay_rslts_rprt <- function(df, lvl, conc, pk_area, title_conc,
                             title_pk_area, prjct_title, ref_conc,
                             ref_unit, dclrd_content) {
  # Modify data frame
  df <- df %>%
    select(all_of(c(lvl, conc, pk_area))) %>%
    arrange(.data[[lvl]]) %>% 
    rename(
      C1 = all_of(lvl),
      C2 = all_of(conc),
      C3 = all_of(pk_area)
    )
  
  if (ref_conc != 0 && ref_unit != "" && dclrd_content != 0) {
    df$C4 <- NA
    df$C5 <- NA
    df[1, 4] <- ref_conc
    df[1, 5] <- dclrd_content
  }

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
  if (ref_conc != 0 && ref_unit != "" && dclrd_content != 0) {
    ft <- ft %>%
      set_header_labels(
        C1 = "Concentration level [%]",
        C2 = title_conc,
        C3 = title_pk_area,
        C4 = glue("Reference concentration [{ref_unit}]"),
        C5 = "% of declared content"
      ) %>%
      colformat_num(j = c(1:5), big.mark = "")
  } else {
    ft <- ft %>%
    set_header_labels(
      C1 = "Concentration level [%]",
      C2 = title_conc,
      C3 = title_pk_area
    ) %>%
    colformat_num(j = c(1:3), big.mark = "")
  }
  

  # Add project title, if provided
  if (prjct_title != "") {
    ft <- ft %>%
      add_header_lines(values = c(prjct_title))
  }

  ft <- ft %>%
    flextable::align(align = "center", part = "all") %>%
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
      flextable::bold(i = 1:2, part = "header")
  } else {
    ft <- ft %>%
      flextable::bold(i = 1, part = "header")
  }
  
  ft <- ft %>%
    flextable::font(fontname = "Arial", part = "all")

  return(ft)
}
