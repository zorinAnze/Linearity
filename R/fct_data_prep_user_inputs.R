#' Combine user inputs in table
#'
#' `data_prep_user_inputs()` prepares user inputs for reference concentration,
#'   unit of reference concentration and declared content in a data frame in a
#'   way that it can be styled afterwards by table generating packages.
#'
#' @param ref_conc numeric value. Reference concentration
#' @param ref_unit single character value. Unit of reference concentration
#' @param dclrd_content numeric value. Declared content corresponding to
#'  reference concentration. For detais see WP-7004559
#'
#' @return a `data.frame`
#' @export
#'
data_prep_user_inputs <- function(ref_conc, ref_unit, dclrd_content) {
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

  return(df)
}
