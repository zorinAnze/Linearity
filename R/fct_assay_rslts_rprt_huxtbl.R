#' Create summary table of dataset for PDF report
#'
#' `assay_rslts_rprt_huxtbl()` creates a summary table of the input dataset for
#' PDF reports. Table is included in the report to guarantee reproducibility of
#' the analysis.
#'
#' @param df dataset
#' @param lvl single character value. Column name of column containing
#'  concentration levels
#' @param conc single character value. Column name of column containing
#'  concentrations
#' @param pk_area single character value. Column name of column containing
#'  measured values, usually peak area
#' @param title_conc single character value. Column name displayed in final
#'  table for concentration column
#' @param title_pk_area single character value. Column name displayed in final
#'  table for measured value column
#' @param prjct_title single character value. Project title displayed as title
#'  of the final table. If `prjct_title` = "" no title is displayed
#' @param ref_conc numeric value. Reference value
#' @param ref_unit single character value. Unit of reference value
#' @param max_width numeric value. Text width in inches of PDF file, corresponds
#'  to page width - margin left - margin right
#' @param rows_first_page numeric value. Maximal number of rows on the first
#'  page
#' @param max_rows_per_page numeric value. Maximal number of rows on all the
#'  following pages
#'
#' @return a `huxtable` object
#' @export
#'
assay_rslts_rprt_huxtbl <- function(df, lvl, conc, pk_area, title_conc,
                                    title_pk_area, prjct_title, ref_conc,
                                    ref_unit, max_width,
                                    rows_first_page, max_rows_per_page) {

  # Determine maximal number of decimal places in numeric columns
  max_decimals <- df %>%
    pivot_longer(where(is.numeric),
      names_to = "variable",
      values_to = "value"
    ) %>%
    mutate(N_digits = nchar(gsub(
      ".*\\.|^[^.]+$", "",
      as.character(value)
    ))) %>%
    group_by(variable) %>%
    summarise(max_N_digits = max(N_digits)) %>%
    pivot_wider(names_from = variable, values_from = max_N_digits)

  # Modify data frame
  df <- df %>%
    select(all_of(c(lvl, conc, pk_area))) %>%
    arrange(.data[[lvl]]) %>%
    rename(
      C1 = all_of(lvl),
      C2 = all_of(conc),
      C3 = all_of(pk_area)
    )

  if (ref_conc != 0 && ref_unit != "") {
    df$C4 <- NA
    df[1, 4] <- ref_conc
  }

  # Convert data frame to huxtable
  ht <- as_huxtable(df)

  # Format huxtable
  if (ref_conc != 0 && ref_unit != "") {
    ht <- ht %>%
      set_contents(1, 1:4, c(
        "Concentration level [%]",
        title_conc,
        title_pk_area,
        glue("Reference value [{ref_unit}]")
      ))
  } else {
    ht <- ht %>%
      set_contents(1, 1:3, c(
        "Concentration level [%]",
        title_conc,
        title_pk_area
      ))
  }


  # Add project title, if provided
  if (prjct_title != "") {
    ht <- ht %>%
      insert_row(prjct_title, rep("", ncol(ht) - 1), after = 0) %>%
      merge_cells(1, 1:ncol(ht))
  }

  ht <- ht %>%
    set_align(everywhere, everywhere, "center") %>%
    set_top_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(1, everywhere, brdr(0.5, "solid", "black")) %>%
    set_bottom_border(nrow(ht), everywhere, brdr(0.5, "solid", "black"))


  # Add horizontal line after project title
  if (prjct_title != "") {
    ht <- ht %>%
      set_bottom_border(2, everywhere, brdr(0.5, "solid", "black"))
  }

  ht <- ht %>%
    set_top_padding(1) %>%
    set_bottom_padding(2) %>%
    set_font_size(9)

  if (prjct_title != "") {
    ht <- ht %>%
      set_bold(1:2, everywhere) %>%
      set_number_format(1:2, 1:ncol(ht), NA) %>%
      set_number_format(3:nrow(ht), 1, glue("%.{max_decimals[[lvl]]}f")) %>%
      set_number_format(3:nrow(ht), 2, glue("%.{max_decimals[[conc]]}f")) %>%
      set_number_format(3:nrow(ht), 3, glue("%.{max_decimals[[pk_area]]}f"))
  } else {
    ht <- ht %>%
      set_bold(1, everywhere) %>%
      set_number_format(1, 1:ncol(ht), NA) %>%
      set_number_format(2:nrow(ht), 1, glue("%.{max_decimals[[lvl]]}f")) %>%
      set_number_format(2:nrow(ht), 2, glue("%.{max_decimals[[conc]]}f")) %>%
      set_number_format(2:nrow(ht), 3, glue("%.{max_decimals[[pk_area]]}f"))
  }

  # 6.29 inch is approximately the text width in the markdown file
  if (sum(dim_pretty(as_flextable(ht))$widths) > max_width) {
    ht <- ht %>%
      set_wrap(everywhere, everywhere, TRUE) %>%
      set_width(1)

    if (prjct_title != "") {
      ht <- ht %>%
        # is inverted for some unknown reasons, "bottom" means top of the cell
        set_valign(1:2, everywhere, "bottom") %>%
        set_bottom_padding(2, everywhere, 4)
    } else {
      ht <- ht %>%
        set_valign(1, everywhere, "bottom") %>%
        set_bottom_padding(1, everywhere, 4)
    }
  }

  # Values for max_width, rows_first_page and max_rows_per_page need to be
  # changed if the margins in the markdown file change
  splits <- hux_split(
    ht, max_width, prjct_title, rows_first_page, max_rows_per_page
  )

  if (length(splits) != 0) {
    ht <- ht %>%
      split_across(after = splits)
  }

  return(ht)
}
