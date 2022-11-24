# Function estimates how many lines wrapped text occupies in the rows and then 
# calculates the maximum number of rows that can fit on a page without causing 
# table overflow.

hux_split <- function(huxtbl, max_width, prjct_title, rows_first_page,
                      max_rows_per_page) {

  # All widths are calculated in inch!

  number_of_lines_per_row <- vector(mode = "numeric", length = nrow(huxtbl))

  # Check if project title is wrapped
  n <- 1

  if (prjct_title != "") {
    number_of_lines_per_row[n] <- ceiling((gdtools::m_str_extents(prjct_title,
      fontname = "arev", fontsize = 9,
      bold = TRUE
      # space left and right from the text in the cell: 2 * 0.11 inch = 0.22
    )[[1]] / 72) / (max_width - 0.22)) # 1 inch = 72px, 
    n <- n + 1              
  }

  # Calculate the width of each column
  col_width <- max_width / ncol(huxtbl)
  
  number_of_lines_per_row[n] <- max(unlist(purrr::map(
    huxtbl[n, ],
    function(x) {
      ceiling((gdtools::m_str_extents(x,
        fontname = "arev", fontsize = 9,
        bold = TRUE
      )[[1]] / 72) / (col_width - 0.22))
    }
  )), na.rm = TRUE)

  for (i in (n + 1):nrow(huxtbl)) {
    number_of_lines_per_row[i] <- max(unlist(purrr::map(
      huxtbl[i, ],
      function(x) {
        ceiling((gdtools::m_str_extents(x,
          fontname = "arev", fontsize = 9,
          bold = FALSE
        )[[1]] / 72) / (col_width - 0.22))
      }
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
