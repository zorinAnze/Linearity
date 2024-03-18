#' Create summary table with user inputs for PDF report
#'
#' `user_input_tbl_huxtbl()` creates a table containing user inputs for
#'  reference value and unit of reference value
#'
#' @param ref_conc numeric value. Reference value
#' @param ref_unit single character value. Unit of reference value
#'
#' @return a `huxtable` object
#' @export
#'
user_input_tbl_huxtbl <- function(ref_conc, ref_unit) {

  # Combine user inputs in data frame
  df <- data_prep_user_inputs(ref_conc, ref_unit)

  # Convert data frame to huxtable
  ht <- as_huxtable(df)

  # Format huxtable
  ht <- ht %>%
    set_na_string(2, 2, "NA") %>%
    set_top_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(nrow(ht), everywhere, brdr(0.5, "solid", "black")) %>%
    set_top_padding(1) %>%
    set_bottom_padding(2) %>%
    set_font_size(9) %>%
    set_bold(1, everywhere)

  return(ht)
}
