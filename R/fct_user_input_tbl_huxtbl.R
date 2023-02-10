#' Create summary table with user inputs for PDF report
#'
#' `user_input_tbl_huxtbl()` creates a table containing user inputs for
#'  reference concentration, unit of reference concentration and declared
#'  content
#'
#' @param ref_conc numeric value. Reference concentration
#' @param ref_unit single character value. Unit of reference concentration
#' @param dclrd_content numeric value. Declared content corresponding to
#'  reference concentration. For detais see WP-7004559
#'
#' @return a `huxxtable` object
#' @export
#'
user_input_tbl_huxtbl <- function(ref_conc, ref_unit, dclrd_content) {

  # Combine user inputs in data frame
  df <- data_prep_user_inputs(ref_conc, ref_unit, dclrd_content)

  # Convert data frame to huxtable
  ht <- as_huxtable(df)

  # Format huxtable
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
