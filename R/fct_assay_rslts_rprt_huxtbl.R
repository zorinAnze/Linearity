# Function returns a huxtable with the assay results

assay_rslts_rprt_huxtbl <- function(df, lvl, conc, pk_area, title_conc,
                                    title_pk_area, prjct_title, ref_conc,
                                    ref_unit, dclrd_content, max_width, 
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

  if (ref_conc != 0 && ref_unit != "" && dclrd_content != 0) {
    df$C4 <- NA
    df$C5 <- NA
    df[1, 4] <- ref_conc
    df[1, 5] <- dclrd_content
  }

  # Convert data frame to huxtable
  ht <- as_huxtable(df)

  # Format huxtable
  if (ref_conc != 0 && ref_unit != "" && dclrd_content != 0) {
    ht <- ht %>%
      set_contents(1, 1:5, c(
        "Concentration level [%]",
        title_conc,
        title_pk_area,
        glue("Reference concentration [{ref_unit}]"),
        "% of declared content"
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
