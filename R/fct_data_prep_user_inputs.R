#' Combine user inputs in table
#'
#' `data_prep_user_inputs()` prepares user inputs for reference value 
#'   and unit of reference value in a data frame in a
#'   way that it can be styled afterwards by table generating packages.
#'
#' @param ref_conc numeric value. Reference value
#' @param ref_unit single character value. Unit of reference value
#'
#' @return a `data.frame`
#' @export
#'
data_prep_user_inputs <- function(ref_conc, ref_unit) {
  df <- tibble(
    Parameter = c(
      "Reference value"
    ),
    Value = c(NA)
  )

  if (ref_conc != 0 && ref_unit != "") {
    df[1, 2] <- glue("{ref_conc} {ref_unit}")
  }

  return(df)
}
