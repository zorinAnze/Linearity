#' Truncate a number to a specified number of decimal places
#'
#' `trunc_number_char()` function truncates a given number to a specified number
#' of decimal places. Note that it does not do rounding,
#' instead it outright truncates the number. This function has in comparison to
#' `trunc_number()` an additional conversion step to character and back to 
#' numeric. This should make it more robust to issues that arose due to the 
#' double-precision floating-point numbers used by R.
#'
#' @param number numeric value. Will be truncated
#' @param decimals integer value. Indicating the number of decimal places to 
#' which the number should be truncated.
#'
#' @return The number truncated to decimals number of decimal places.
#' @export
#'
trunc_number_char <- function(number, decimals) {
  trunc(as.numeric(as.character(number * 10^(decimals)))) * 10^-(decimals)
}