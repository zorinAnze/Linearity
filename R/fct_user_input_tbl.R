# Function returns a flextable with the user inputs from the linearity plot
user_input_tbl <- function(ref_conc, ref_unit, dclrd_content, thrtcl_conc,
                           thrtcl_unit) {
  df <- tibble(
    Parameters = c(
      "Reference concentration",
      "% of declared content",
      "Theoretical concentration"
    ),
    Values = c(NA, NA, NA)
  )

  if (ref_conc != 0 && ref_unit != "") {
    df[1, 2] <- glue("{ref_conc} {ref_unit}")
  }

  if (dclrd_content != 0) {
    df[2, 2] <- glue("{dclrd_content}%")
  }

  if (thrtcl_conc != 0 && thrtcl_unit != "") {
    df[3, 2] <- glue("{thrtcl_conc} {thrtcl_unit}")
  }



  ft <- flextable(df)

  ft <- ft %>%
    colformat_char(j = 2, na_str = "NA") %>%
    colformat_lgl(j = 2, na_str = "NA") %>% 
    hline_top(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    ) %>%
    hline_bottom(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    ) %>%
    hline_bottom(
      border = fp_border(color = "black", width = 0.5),
      part = "body"
    ) %>%
    padding(padding.bottom = 2, padding.top = 1, part = "all") %>%
    set_table_properties(layout = "autofit", width = 0.4) %>%
    fontsize(size = 9, part = "all") %>%
    bold(part = "header") %>%
    font(fontname = "Arial", part = "all")

  return(ft)
}
