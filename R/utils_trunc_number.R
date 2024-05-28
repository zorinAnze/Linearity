#' Truncate a number to a specified number of decimal places
#'
#' `trunc_number()` function truncates a given number to a specified number
#' of decimal places. Note that it does not do rounding,
#' instead it outright truncates the number.
#'
#' @param number numeric value. Will be truncated
#' @param decimals integer value. Indicating the number of decimal places to 
#' which the number should be truncated.
#'
#' @return The number truncated to decimals number of decimal places.
#' @export
#'
trunc_number <- function(number, decimals) {
  trunc(number * 10^(decimals)) * 10^-(decimals)
}