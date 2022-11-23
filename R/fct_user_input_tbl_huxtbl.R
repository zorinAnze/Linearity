# Function returns a huxtable with the user inputs from the linearity plot

user_input_tbl_huxtbl <- function(ref_conc, ref_unit, dclrd_content) {
  df <- tibble(
    Parameters = c(
      "Reference concentration",
      "% of declared content"
    ),
    Values = c(NA, NA)
  )

  if (ref_conc != 0 && ref_unit != "") {
    df[1, 2] <- glue("{ref_conc} {ref_unit}")
  }

  if (dclrd_content != 0) {
    df[2, 2] <- glue("{dclrd_content}%")
  }


  ht <- as_huxtable(df)

  ht <- ht %>%
    set_na_string(2:3, 2, "NA") %>%
    set_top_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(nrow(ht), everywhere, brdr(0.5, "solid", "black")) %>%
    set_top_padding(1) %>%
    set_bottom_padding(2) %>%
    set_font_size(9) %>%
    set_bold(1, everywhere)

  return(ht)
}
