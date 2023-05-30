#' Round always up at .5
#'
#' `round2()` always rounds up values ending with .5, in contrast to the 
#' default R function `round()`.
#' 
#' @param x a numeric vector
#' @param digits integer indicating the number of decimal places to be used
#' 
#' @return a numeric vector
#' @export

round2 <- function(x, digits) {
  posneg <- sign(x)
  z <- abs(x)*10^digits
  z <- z + 0.5 + sqrt(.Machine$double.eps)
  z <- trunc(z)
  z <- z/10^digits
  return(z*posneg)
}