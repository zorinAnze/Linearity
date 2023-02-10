#' Create summary table with user inputs for Word report
#'
#' `user_input_tbl()` creates a table containing user inputs for
#'  reference concentration, unit of reference concentration and declared
#'  content
#'
#' @param ref_conc numeric value. Reference concentration
#' @param ref_unit single character value. Unit of reference concentration
#' @param dclrd_content numeric value. Declared content corresponding to
#'  reference concentration. For detais see WP-7004559
#'
#' @return a `flextable` object
#' @export
#'
user_input_tbl <- function(ref_conc, ref_unit, dclrd_content) {

  # Combine user inputs in data frame
  df <- data_prep_user_inputs(ref_conc, ref_unit, dclrd_content)

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
