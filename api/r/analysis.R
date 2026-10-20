#' Headless linearity analysis
#'
#' `run_analysis()` reproduces the computation the Shiny app performs, with no
#' Shiny and no `ava2` dependency. It reuses the functions in `R/` verbatim, so
#' the numbers it returns are the numbers the app would show and the Word
#' report would contain.
#'
#' Plot geometry is extracted with `ggplot_build()` rather than recomputed, so
#' a client can redraw exactly what ggplot2 would have rendered into the
#' report (same smooth grid, same confidence band, same histogram bins).

suppressPackageStartupMessages({
  library(readr); library(readxl); library(dplyr); library(tibble); library(tidyr)
  library(broom); library(parsnip); library(ggplot2)
  library(outliers); library(car); library(glue); library(lubridate)
})

APP_VERSION <- "1.0.2"

# Source the app's own analysis functions.
local({
  root <- Sys.getenv("LINEARITY_ROOT", unset = "/home/adnan/projects/shiny")
  for (f in list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)) {
    source(f)
  }
})


#' Read an uploaded data file the way the app's upload handler does
#'
#' @param path path to a .csv/.tsv/.xlsx file
#' @param ext file extension
#' @return a tibble with `make.names()`-sanitised column names
read_upload <- function(path, ext) {
  ext <- tolower(ext)

  # plumber runs with its own working directory, so resolve relative paths
  # against the project root rather than whatever cwd happens to be.
  if (!startsWith(path, "/")) {
    path <- file.path(
      Sys.getenv("LINEARITY_ROOT", unset = "/home/adnan/projects/shiny"),
      path
    )
  }
  if (!file.exists(path)) stop("File not found: ", path)

  df <- switch(ext,
    csv = {
      delim <- if (grepl(";", readLines(path, n = 1, warn = FALSE))) ";" else ","
      read_delim(path, delim = delim, show_col_types = FALSE)
    },
    tsv  = read_delim(path, delim = "\t", show_col_types = FALSE),
    xlsx = readxl::read_excel(path, col_names = TRUE),
    stop("Unsupported file type: '", ext, "'. Use csv, tsv or xlsx.")
  )
  colnames(df) <- make.names(colnames(df), unique = TRUE)
  df
}


#' Build a data frame from an inline JSON payload
#'
#' Accepts either row records (`[{"a": 1, "b": 2}, ...]`, the usual shape) or
#' columns (`{"a": [1, 2], "b": [3, 4]}`). Column names are passed through
#' `make.names()` so inline data behaves exactly like an uploaded file, where
#' the app sanitises headers on import.
#'
#' @param data parsed JSON: a data frame, a list of records, or a list of columns
#' @return a tibble
df_from_json <- function(data) {
  if (is.null(data)) stop("No data supplied.")

  # plumber's JSON parser already simplifies an array of flat objects.
  df <- if (is.data.frame(data)) {
    as_tibble(data)
  } else if (is.list(data) && length(data) && is.null(names(data))) {
    rows <- lapply(data, function(r) as_tibble(lapply(r, function(v) {
      if (is.null(v) || (length(v) == 1 && is.na(v))) NA else v
    })))
    bind_rows(rows)
  } else if (is.list(data) && !is.null(names(data))) {
    lens <- lengths(data)
    if (length(unique(lens)) != 1) {
      stop("Columns have differing lengths: ",
           paste(sprintf("%s=%d", names(data), lens), collapse = ", "))
    }
    as_tibble(lapply(data, unlist))
  } else {
    stop("Unrecognised 'data' shape; expected an array of row objects ",
         "or an object of equal-length column arrays.")
  }

  if (!nrow(df)) stop("'data' contained no rows.")
  colnames(df) <- make.names(colnames(df), unique = TRUE)
  df
}


#' Resolve a request body to a data frame: inline `data`, or an uploaded file
#'
#' @param body parsed request body with either `data`, or `path` + `ext`
#' @return a tibble
df_from_body <- function(body) {
  if (!is.null(body$data)) {
    df_from_json(body$data)
  } else if (!is.null(body$path)) {
    read_upload(body$path, body$ext)
  } else {
    stop("Supply either 'data' (inline rows) or 'path' (an uploaded file).")
  }
}


#' Validate inputs before fitting, mirroring the app's UI guards
#' Resolve the three analysis columns, filling blanks by position
#'
#' A name that is supplied is used as given (after `make.names()`); a name
#' left blank is filled from the numeric columns in order of appearance,
#' skipping any column already claimed by another parameter. Only numeric
#' columns are candidates, so artefacts like the empty trailing column a
#' stray delimiter produces are never selected.
#'
#' @param df data frame of measurements
#' @param conc_lvl,conc_sol,pk_area column names; "" or NULL to infer
#' @return list(columns = list(conc_lvl=, conc_sol=, pk_area=),
#'              auto_mapped = character())
resolve_columns <- function(df, conc_lvl = "", conc_sol = "", pk_area = "") {
  is_blank <- function(x) is.null(x) || !length(x) || !nzchar(trimws(x[1]))

  given <- list(conc_lvl = conc_lvl, conc_sol = conc_sol, pk_area = pk_area)
  given <- lapply(given, function(x) {
    if (is_blank(x)) "" else make.names(trimws(x[1]))
  })

  numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  claimed <- unlist(given, use.names = FALSE)
  available <- setdiff(numeric_cols, claimed[nzchar(claimed)])

  auto <- character()
  for (nm in names(given)) {
    if (nzchar(given[[nm]])) next
    if (!length(available)) {
      stop(sprintf(
        paste("Cannot infer '%s': no unused numeric column left.",
              "Numeric columns found: %s. Name the columns explicitly."),
        nm,
        if (length(numeric_cols)) paste(numeric_cols, collapse = ", ") else "none"
      ))
    }
    given[[nm]] <- available[1]
    available <- available[-1]
    auto <- c(auto, nm)
  }

  list(columns = given, auto_mapped = auto)
}


validate_inputs <- function(df, conc_lvl, conc_sol, pk_area) {
  errs <- character()

  given <- c(conc_lvl = conc_lvl, conc_sol = conc_sol, pk_area = pk_area)
  absent <- given[!given %in% names(df)]

  # Report each missing name once, listing the parameters that asked for it,
  # rather than repeating an identical message per parameter.
  for (nm in unique(unname(absent))) {
    params <- names(absent)[absent == nm]
    msg <- sprintf("Column '%s' not found (given for %s). Available: %s",
                   nm, paste(params, collapse = ", "),
                   paste(names(df), collapse = ", "))
    if (identical(nm, "string")) {
      msg <- paste(msg, "-- 'string' is Swagger UI's placeholder text;",
                   "replace it with a real column name.")
    }
    errs <- c(errs, msg)
  }
  if (length(errs)) return(errs)

  # The app disables "Calculate" unless all three columns are numeric.
  for (lbl in c("conc_lvl", "conc_sol", "pk_area")) {
    nm <- get(lbl)
    if (!is.numeric(df[[nm]])) {
      errs <- c(errs, sprintf("Column '%s' (%s) must be numeric.", nm, lbl))
    }
  }
  if (length(errs)) return(errs)

  if (nrow(df) < 3) {
    errs <- c(errs, sprintf("Need at least 3 rows, got %d.", nrow(df)))
  }
  if (length(unique(df[[conc_sol]])) < 2) {
    errs <- c(errs, sprintf("Column '%s' must have >= 2 distinct values.", conc_sol))
  }
  # Cochran/Levene/Fligner need replicates within each concentration level.
  grp <- table(df[[conc_lvl]])
  if (length(grp) < 2) {
    errs <- c(errs, sprintf("Column '%s' must define >= 2 groups.", conc_lvl))
  } else if (any(grp < 2)) {
    errs <- c(errs, sprintf(
      "Variance tests need >= 2 replicates per level; these have 1: %s",
      paste(names(grp)[grp < 2], collapse = ", ")
    ))
  }
  errs
}


#' Extract built layer data from a ggplot, keyed by geom class
#'
#' @param p a ggplot object
#' @return list with `layers` (named list of data frames) and `panel`
build_layers <- function(p) {
  b <- ggplot2::ggplot_build(p)
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  names(b$data) <- make.unique(geoms)
  pp <- b$layout$panel_params[[1]]
  list(
    layers = b$data,
    panel = list(
      x_range = as.numeric(pp$x.range),
      y_range = as.numeric(pp$y.range)
    )
  )
}

# Pull a layer by geom name, NULL if absent.
lyr <- function(built, name) built$layers[[name]]

# Drop ggplot's internal bookkeeping columns and keep it JSON-friendly.
clean_cols <- function(d, keep) {
  keep <- intersect(keep, names(d))
  out <- as.list(d[keep])
  lapply(out, function(col) if (is.factor(col)) as.character(col) else col)
}


#' Run the full linearity analysis
#'
#' @param df data frame of measurements
#' @param conc_lvl,conc_sol,pk_area column names (level, concentration, response)
#' @param ref_conc numeric reference concentration; 0 disables reference output
#' @param ref_unit unit label for the reference concentration
#' @param lab_x,lab_y axis labels
#' @param plt_title plot/report title; "" for none
#' @param style "report" matches the Word report (app = FALSE); "app" matches
#'   the on-screen Shiny sizing
#' @return a list ready for JSON serialisation
run_analysis <- function(df, conc_lvl = "", conc_sol = "", pk_area = "",
                         ref_conc = 0,
                         ref_unit = "mg/mL",
                         lab_x = "Concentration [mg/mL]",
                         lab_y = "Peak Area [mAU*min]",
                         plt_title = "",
                         style = "report") {

  resolved <- resolve_columns(df, conc_lvl, conc_sol, pk_area)
  conc_lvl <- resolved$columns$conc_lvl
  conc_sol <- resolved$columns$conc_sol
  pk_area  <- resolved$columns$pk_area

  errs <- validate_inputs(df, conc_lvl, conc_sol, pk_area)
  if (length(errs)) stop(paste(errs, collapse = " | "))

  app_style <- identical(style, "app")

  # --- model, exactly as the app builds it ---------------------------------
  lm_fit <- linear_reg() |>
    set_engine("lm") |>
    fit(as.formula(paste0(pk_area, "~", conc_sol)), data = df)

  anova_fit <- anova(lm_fit$fit)
  cochran <- cochran.test(as.formula(paste0(pk_area, "~", conc_lvl)), data = df)
  levene  <- leveneTest(
    as.formula(paste0(pk_area, "~", conc_lvl)),
    data = df |> mutate(across(all_of(conc_lvl), as.factor))
  )
  fligner <- fligner.test(as.formula(paste0(pk_area, "~", conc_lvl)), data = df)
  shapiro <- shapiro.test(rstudent(lm_fit$fit))

  mod_coef <- tidy(lm_fit, conf.int = TRUE)
  mod_sum  <- glance(lm_fit)

  y_at_ref <- if (ref_conc != 0) {
    predict(lm_fit, new_data = tibble(!!conc_sol := ref_conc)) |> pull(.pred)
  } else {
    NULL
  }

  # --- plots: build then harvest the rendered geometry ---------------------
  p_line <- line_plot(df, conc_sol, pk_area, lab_x, lab_y, lm_fit,
                      ref_conc, plt_title, app = app_style)
  p_res  <- residual_plots(df, lm_fit, lab_x, app = app_style)

  b_line <- build_layers(p_line)
  b_qq   <- build_layers(p_res$p1)
  b_rvx  <- build_layers(p_res$p2)
  b_hist <- build_layers(p_res$p3)
  b_ord  <- build_layers(p_res$p4)

  eq_layer <- lyr(b_line, "GeomText")
  resid <- unname(lm_fit$fit$residuals)

  plots <- list(
    regression = list(
      points = clean_cols(lyr(b_line, "GeomPoint"), c("x", "y")),
      smooth = clean_cols(lyr(b_line, "GeomSmooth"), c("x", "y", "ymin", "ymax")),
      equation = if (!is.null(eq_layer)) list(
        label = as.character(eq_layer$label[1]),
        x     = as.numeric(eq_layer$x[1]),
        y     = as.numeric(eq_layer$y[1]),
        hjust = 0, vjust = 1
      ) else NULL,
      reference = if (ref_conc != 0) list(
        ref_conc = ref_conc,
        ref_unit = ref_unit,
        y_at_ref = y_at_ref
      ) else NULL,
      axes = list(
        x_lab = lab_x, y_lab = lab_y,
        title = if (nzchar(plt_title)) plt_title else NULL,
        x_range = b_line$panel$x_range,
        y_range = b_line$panel$y_range
      )
    ),
    qq = list(
      points = clean_cols(lyr(b_qq, "GeomPoint"), c("x", "y")),
      line   = clean_cols(lyr(b_qq, "GeomPath"), c("x", "y")),
      axes = list(x_lab = "Theoretical Quantiles", y_lab = "Sample Quantiles",
                  title = "Quantile-Quantile Plot")
    ),
    residuals_vs_x = list(
      points = clean_cols(lyr(b_rvx, "GeomPoint"), c("x", "y")),
      hline  = 0,
      axes = list(x_lab = lab_x, y_lab = "Residual",
                  title = "Residuals vs Independent Values Plot")
    ),
    residual_histogram = list(
      bins = clean_cols(lyr(b_hist, "GeomBar"), c("x", "xmin", "xmax", "y", "count")),
      binwidth = 2 * IQR(resid) / length(resid)^(1 / 3),
      axes = list(x_lab = "Residual", y_lab = "Frequency",
                  title = "Residual Histogram")
    ),
    residuals_vs_order = list(
      points = clean_cols(lyr(b_ord, "GeomPoint"), c("x", "y")),
      hline  = 0,
      axes = list(x_lab = "Observation Order", y_lab = "Residual",
                  title = "Residual vs Order Plot")
    ),
    style = list(
      mode = if (app_style) "app" else "report",
      text_size = if (app_style) 16 else 10,
      dot_size  = if (app_style) 3 else 1.5,
      line_size = if (app_style) 1 else 0.5,
      accent_colour = "#0460A9",
      theme = "theme_bw"
    )
  )

  # --- the Word report's tables, as rendered strings -----------------------
  tbl_lin <- as.data.frame(data_prep_lin_reg(lm_fit, conc_sol, ref_conc))
  tbl_hom <- as.data.frame(data_prep_homosced(lm_fit, cochran, levene,
                                              fligner, anova_fit))
  tbl_usr <- as.data.frame(data_prep_user_inputs(ref_conc, ref_unit))

  as_rows <- function(d) {
    lapply(seq_len(nrow(d)), function(i) {
      list(label = as.character(d[i, 1]),
           value = if (is.na(d[i, 2])) NULL else as.character(d[i, 2]))
    })
  }

  homo_verdict <- function(p) {
    if (p > 0.05) "Variance is Homoscedastic" else "Variance is Heteroscedastic"
  }

  list(
    meta = list(
      app_version  = APP_VERSION,
      r_version    = paste0(R.version$major, ".", R.version$minor),
      generated_at = format(now(), "%Y-%m-%dT%H:%M:%S%z"),
      n_obs        = nrow(df),
      formula      = paste0(pk_area, " ~ ", conc_sol)
    ),
    inputs = list(
      conc_lvl = conc_lvl, conc_sol = conc_sol, pk_area = pk_area,
      # Which of the three were inferred from column order rather than named
      # by the caller -- worth recording, since the choice affects results.
      auto_mapped = as.list(resolved$auto_mapped),
      ref_conc = ref_conc, ref_unit = ref_unit,
      lab_x = lab_x, lab_y = lab_y, plt_title = plt_title,
      style = if (app_style) "app" else "report"
    ),
    model = list(
      coefficients = lapply(seq_len(nrow(mod_coef)), function(i) list(
        term      = mod_coef$term[i],
        estimate  = mod_coef$estimate[i],
        std_error = mod_coef$std.error[i],
        statistic = mod_coef$statistic[i],
        p_value   = mod_coef$p.value[i],
        conf_low  = mod_coef$conf.low[i],
        conf_high = mod_coef$conf.high[i]
      )),
      glance = list(
        r_squared     = mod_sum$r.squared,
        adj_r_squared = mod_sum$adj.r.squared,
        sigma         = mod_sum$sigma,
        statistic     = mod_sum$statistic,
        p_value       = mod_sum$p.value,
        df            = mod_sum$df,
        df_residual   = mod_sum$df.residual,
        deviance      = mod_sum$deviance,
        logLik        = as.numeric(mod_sum$logLik),
        AIC           = mod_sum$AIC,
        BIC           = mod_sum$BIC,
        nobs          = mod_sum$nobs
      ),
      correlation_r = sqrt(mod_sum$r.squared),
      y_at_ref      = y_at_ref,
      anova = lapply(seq_len(nrow(anova_fit)), function(i) list(
        term      = rownames(anova_fit)[i],
        df        = anova_fit$Df[i],
        sum_sq    = anova_fit$`Sum Sq`[i],
        mean_sq   = anova_fit$`Mean Sq`[i],
        statistic = anova_fit$`F value`[i],
        p_value   = anova_fit$`Pr(>F)`[i]
      )),
      fitted    = unname(lm_fit$fit$fitted.values),
      residuals = resid
    ),
    homoscedasticity = list(
      cochran = list(statistic = unname(cochran$statistic),
                     p_value = unname(cochran$p.value),
                     method = cochran$method,
                     verdict = homo_verdict(cochran$p.value)),
      levene  = list(statistic = levene$`F value`[1],
                     p_value = levene$`Pr(>F)`[1],
                     method = "Levene's Test for Homogeneity of Variance",
                     verdict = homo_verdict(levene$`Pr(>F)`[1])),
      fligner = list(statistic = unname(fligner$statistic),
                     p_value = unname(fligner$p.value),
                     method = fligner$method,
                     verdict = homo_verdict(fligner$p.value)),
      shapiro_rstudent = list(statistic = unname(shapiro$statistic),
                              p_value = unname(shapiro$p.value),
                              method = shapiro$method)
    ),
    report_tables = list(
      linear_regression = as_rows(tbl_lin),
      homoscedasticity  = as_rows(tbl_hom),
      user_inputs       = as_rows(tbl_usr)
    ),
    plots = plots
  )
}
