#' Create summary table of dataset for Word report
#'
#' `assay_rslts_rprt()` creates a summary table of the input dataset for
#' Word reports. Table is included in the report to guarantee reproducibility of
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
#'
#' @return a `flextable` object
#' @export
#'
assay_rslts_rprt <- function(df, lvl, conc, pk_area, title_conc,
                             title_pk_area, prjct_title, ref_conc,
                             ref_unit) {
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

  # Convert data frame to flextable
  ft <- flextable(df)

  # Format flextable
  if (ref_conc != 0 && ref_unit != "") {
    ft <- ft %>%
      set_header_labels(
        C1 = "Concentration level [%]",
        C2 = title_conc,
        C3 = title_pk_area,
        C4 = glue("Reference value [{ref_unit}]")
      ) %>%
      colformat_num(j = c(1:4), big.mark = "")
  } else {
    ft <- ft %>%
      set_header_labels(
        C1 = "Concentration level [%]",
        C2 = title_conc,
        C3 = title_pk_area
      ) %>%
      colformat_num(j = c(1:3), big.mark = "")
  }


  # Add project title, if provided
  if (prjct_title != "") {
    ft <- ft %>%
      add_header_lines(values = c(prjct_title))
  }

  ft <- ft %>%
    flextable::align(align = "center", part = "all") %>%
    border_remove() %>%
    hline_top(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    )

  # Add horizontal line after project title
  if (prjct_title != "") {
    ft <- ft %>%
      hline(
        i = 1,
        border = fp_border(color = "black", width = 0.5),
        part = "header"
      )
  }

  ft <- ft %>%
    hline_bottom(
      border = fp_border(color = "black", width = 0.5),
      part = "header"
    ) %>%
    hline(
      i = nrow(df),
      border = fp_border(color = "black", width = 0.5),
      part = "body"
    ) %>%
    padding(padding.bottom = 2, padding.top = 1, part = "all") %>%
    set_table_properties(layout = "autofit", width = 1) %>%
    fontsize(size = 9, part = "all")

  if (prjct_title != "") {
    ft <- ft %>%
      flextable::bold(i = 1:2, part = "header")
  } else {
    ft <- ft %>%
      flextable::bold(i = 1, part = "header")
  }

  ft <- ft %>%
    flextable::font(fontname = "Arial", part = "all")

  return(ft)
}
