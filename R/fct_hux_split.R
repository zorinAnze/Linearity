#' Calculate optimal number of rows for splitting the table
#'
#' `hux_split()` estimates how many lines wrapped text occupies in the rows and
#' then calculates the maximum number of rows that can fit on a page without
#' causing table overflow.
#'
#' @param huxtbl a huxtable
#' @param max_width numeric value. Text width in inches of PDF file, corresponds
#'  to page width - margin left - margin right
#' @param prjct_title single character value. Project title. If
#'  `prjct_title` = "" it is not considered in the splitting algorithm
#' @param rows_first_page numeric value. Maximal number of rows on the first
#'  page
#' @param max_rows_per_page numeric value. Maximal number of rows on all the
#'  following pages
#'
#' @return a numeric vector
#' @export
#'
hux_split <- function(huxtbl, max_width, prjct_title, rows_first_page,
                      max_rows_per_page) {

  # All widths are calculated in inch!

  number_of_lines_per_row <- vector(mode = "numeric", length = nrow(huxtbl))

  # Check if project title is wrapped
  n <- 1

  if (prjct_title != "") {
    number_of_lines_per_row[n] <- max(unlist(purrr::map2(
      huxtbl[1, ], (max_width - 0.22), wrap_text,
      bold = TRUE
    )), na.rm = TRUE)
    n <- n + 1
  }

  # Calculate the width of each column
  col_width <- max_width / ncol(huxtbl)

  number_of_lines_per_row[n] <- max(unlist(purrr::map2(
    huxtbl[n, ], (col_width - 0.22), wrap_text,
    bold = TRUE
  )), na.rm = TRUE)

  for (i in (n + 1):nrow(huxtbl)) {
    number_of_lines_per_row[i] <- max(unlist(purrr::map2(
      huxtbl[i, ], (col_width - 0.22), wrap_text,
      bold = FALSE
    )), na.rm = TRUE)
  }

  splits <- vector(mode = "numeric")
  sum_lines <- 0

  for (i in 1:length(number_of_lines_per_row)) {
    if (sum_lines + number_of_lines_per_row[[i]] <= if_else(length(splits) == 0,
      rows_first_page,
      (max_rows_per_page - if_else(prjct_title != "",
        number_of_lines_per_row[2],
        number_of_lines_per_row[1]
      ))
    )) {
      sum_lines <- sum_lines + number_of_lines_per_row[[i]]
    } else {
      sum_lines <- number_of_lines_per_row[[i]]
      splits <- append(splits, i - 1)
    }
  }

  return(splits)
}
