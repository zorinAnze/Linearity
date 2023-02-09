#' Add empty paragraph n-times
#'
#' `body_add_par_n()` adds an empty paragraph n-times to a doc file.
#'
#' @param doc a docx device created with the officer package
#' @param n integer value. Number of paragraphs to be added
#'
#' @return A rdocx object
#' @export
#'
body_add_par_n <- function(doc, n) {
  i <- 1 # initialize counter
  while (i <= n) { # control if the counter is less then desired n

    doc <- body_add_par(doc, "") # add paragraph to the object
    i <- i + 1 # increment the counter
  }

  doc # return the object
}
