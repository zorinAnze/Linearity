#' Create summary table with user inputs for Word report
#'
#' `user_input_tbl()` creates a table containing user inputs for
#'  reference value and unit of reference value
#'
#' @param ref_conc numeric value. Reference value
#' @param ref_unit single character value. Unit of reference value
#'
#' @return a `flextable` object
#' @export
#'
user_input_tbl <- function(ref_conc, ref_unit) {

  # Combine user inputs in data frame
  df <- data_prep_user_inputs(ref_conc, ref_unit)

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
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
    flextable::bold(part = "header") %>%
    flextable::font(fontname = "Arial", part = "all")

  return(ft)
}
