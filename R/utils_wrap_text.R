#' Wrap text using an algorithm which minimizes raggedness
#'
#' `wrap_text()` estimates how many lines wrapped text occupies.
#'
#' @param text single character value. String which should be wrapped
#' @param width_inch numeric value. Available space in inch
#' @param bold boolean value. If TRUE, bold text is wrapped

#'
#' @return a numeric vector
#' @export
#'
wrap_text <- function(text, width_inch, bold = FALSE) {
  words <- text %>%
    replace_na("") %>% 
    stringr::str_replace_all(c(
      "s\\\\textsubscript\\{rel\\}" = "srel",
      "\\$\\\\Delta\\$" = "D", "\\\\%" = "%"
    )) %>%
    stringr::str_split(" |_|-") %>%
    # stringr::str_split("(?<=[\\_\\-\\s])") %>%
    unlist()

  # This section is used to calculate the ratio between a letter in monospace
  # and helvetica. It is commented out because it has to be calculated only
  # once and not every time the function is called.

  # letter_quotient <- c()
  # for (letter in all_letters) {
  #   letter_quotient <- append(letter_quotient, (gdtools::m_str_extents(
  #     letter,
  #     fontname = "monospace",
  #     fontsize = 9, bold = TRUE
  #   )[, 1] / 96) /
  #     (gdtools::m_str_extents(
  #       letter,
  #       fontname = "helvetica",
  #       fontsize = 9, bold = TRUE
  #     )[, 1] / 96))
  # }
  # mean(letter_quotient)

  # All these values are true for font size 9
  char_width_mono <- 0.05644226
  mono_helvetica <- 1.161217
  mono_helvetica_bold <- 1.070061


  if (bold) {
    width <- floor(width_inch / (char_width_mono * mono_helvetica_bold))
  } else {
    width <- floor(width_inch / (char_width_mono * mono_helvetica))
  }


  count <- length(words)
  offsets <- c(0)

  for (w in words) {
    offsets <- append(offsets, (nchar(w) + tail(offsets, n = 1)))
  }

  minima <- c(0, rep(10^20, count))
  breaks <- rep(0, count + 1)

  for (i in 1:count) {
    j <- i + 1
    while (j <= count + 1) {
      w <- offsets[j] - offsets[i] + j - i - 1
      if (w > width) {
        break
      }
      cost <- minima[i] + (width - w)^2
      if (cost < minima[j]) {
        minima[j] <- cost
        breaks[j] <- i - 1
      }
      j <- j + 1
    }
  }

  lines <- c()
  j <- count
  while (j > 0) {
    j <- j + 1
    i <- breaks[j]
    lines <- append(lines, paste(words[(i + 1):(j - 1)], collapse = " "))
    j <- i
  }

  # return(rev(lines))
  return(length(lines))
}
