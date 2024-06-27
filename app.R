# Libraries -------------------------------------------------------------------
library(shiny)
library(ava2)
library(shinycssloaders)
library(shinyFeedback)
library(shinyjs)
library(shinyWidgets)
library(readr)
library(readxl)
library(broom)
library(dplyr)
library(tibble)
library(ggplot2)
library(tidyr)
library(parsnip)
library(DT)
library(flextable)
library(officer)
library(waiter)
library(outliers)
library(glue)
library(shinyglide)
library(lubridate)
library(huxtable)
library(car)

# Options ---------------------------------------------------------------------
options(readr.show_progress = FALSE)
options(readxl.show_progress = FALSE)
options(
  appName = "Linearity",
  appDesc = "Linearity",
  deployVersion = "1.0",
  email = "ard_r_shiny_PRJ@dl.mgd.novartis.com",
  author = "ARD Data Science Team"
)



# UI ==========================================================================
ui <- dashboardPage(
  dashboardHeader(),
  dashboardSidebar(
    width = "275px",
    fixed = TRUE,
    skin = "light",
    minified = FALSE,
    includeCSS("www/style.css"),
    includeScript("www/auth.js"),
    includeScript("www/resize_images.js"),
    sidebarMenu(
      br(),
      p("DataScience@", class = "title title_gray"),
      p(strong("ARD"), class = "title"),
      br(),
      p("Information", class = "menu_title"),
      menuItem("Home", tabName = "home", icon = icon("home")),
      p("Import", class = "menu_title"),
      menuItem(
        "Data Import",
        tabName = "data_import", icon = icon("file-upload")
      ),
      p("Results", class = "menu_title"),
      menuItem(
        "Developing Unit",
        tabName = "rslt",
        icon = icon("flask")
      ),
      p("Report", class = "menu_title"),
      menuItem(
        "Download Report",
        tabName = "report", icon = icon("file-download")
      )
    )
  ),
  dashboardBody(
    useShinyFeedback(),
    useShinyjs(),
    useWaiter(),
    tabItems(
      tabItem(
        tabName = "home",
        box(h1("Linearity", class = "info_title"),
          p(paste(
            "By using this application, the user acknowledges reading and",
            "understanding of SOP-7039603, WP-7004559, and the user",
            "instructions below."
          ), class = "disclaimer"),
          box(includeHTML("www/objectives.html"),
            title = "Objectives",
            status = "primary", width = 12
          ) %>%
            tagAppendAttributes(class = "info_sub_box"),
          box(includeHTML("www/statistical_methods.html"),
            title = "Statistical Methods",
            status = "primary", width = 12, collapsed = TRUE
          ) %>%
            tagAppendAttributes(class = "info_sub_box"),
          box(includeHTML("www/user_instructions.html"),
            title = "User Instructions",
            status = "primary", width = 12, collapsed = TRUE
          ) %>%
            tagAppendAttributes(class = "info_sub_box"),
          box(includeHTML("www/results.html"),
            title = "Results",
            status = "primary", width = 12, collapsed = TRUE
          ) %>%
            tagAppendAttributes(class = "info_sub_box"),
          width = 12,
          headerBorder = FALSE
        ) %>%
          tagAppendAttributes(class = "info_box"),
      ),
      tabItem(
        tabName = "data_import",
        fluidRow(
          box(
            # Input file
            fileInput(
              inputId = "upload",
              label = "Upload file:",
              accept = c(".csv", ".tsv", ".xlsx")
            ),
            conditionalPanel(
              "output.import_ready",
              selectInput("conc_lvl", "Analyte concentration level column:",
                choices = c(Choose = "")
              )
            ),
            conditionalPanel(
              "input.conc_lvl",
              selectInput("conc_sol", "Analyte concentration column:",
                choices = c(Choose = "")
              )
            ),
            conditionalPanel(
              "input.conc_sol",
              selectInput("pk_area", "Analyte response column:",
                choices = c(Choose = "")
              )
            ),
            conditionalPanel(
              "input.pk_area",
              actionBttn(
                "calc",
                "Calculate",
                icon = icon("calculator"),
                style = "simple",
                color = "primary",
                size = "sm"
              )
            ),
            title = "Import settings",
            width = 4,
            status = "primary",
            solidHeader = TRUE
          ),
          box(
            conditionalPanel(
              "input.calc",
              DTOutput("data_table")
            ),
            title = "Imported data",
            width = 8,
            status = "primary",
            solidHeader = TRUE
          )
        )
      ),
      tabItem(
        tabName = "rslt",
        fluidRow(
          box(
            conditionalPanel(
              "input.calc",
              withSpinner(plotOutput("plt_line", height = "454px"),
                type = 8,
                color = "#0460A9"
              )
            ),
            sidebar = boxSidebar(
              id = "line_plt_sidebar",
              background = "#fff",
              startOpen = FALSE,
              width = 50,
              icon = icon("chart-bar"),
              textInput(
                "plt_title", "Title:",
                ""
              ),
              textInput(
                "lab_x", "X-axis label:",
                "Concentration [mg/mL]"
              ),
              textInput(
                "lab_y", "Y-axis label:",
                "Peak Area [mAU*min]"
              ),
              div(
                class = "conc-container",
                numericInput(
                  "ref_conc", "Reference value:",
                  0,
                  step = 0.01,
                  width = validateCssUnit("calc(70% - 10px)")
                ),
                textInput("ref_unit", "Unit:", "mg/mL",
                  width = "30%"
                )
              ),
              # div around actionBttn is used to align them on one line
              div(
                class = "sidebar-buttons",
                actionBttn(
                  "update_plot",
                  "Update Plot",
                  icon = icon("redo-alt"),
                  style = "simple",
                  color = "primary",
                  size = "sm"
                ),
                actionBttn(
                  "reset_input",
                  "Reset Inputs",
                  icon = icon("eraser"),
                  style = "simple",
                  color = "primary",
                  size = "sm"
                )
              )
            ),
            title = "Fitted Line Plot",
            width = 6,
            status = "primary",
            solidHeader = TRUE
          ) %>%
            tagAppendAttributes(class = "reverse-tool-order"),
          box(
            conditionalPanel(
              "input.calc",
              glide(
                shinyglide::screen(
                  withSpinner(plotOutput("plt_resid_1"),
                    type = 8,
                    color = "#0460A9"
                  )
                ),
                shinyglide::screen(
                  withSpinner(plotOutput("plt_resid_2"),
                    type = 8,
                    color = "#0460A9"
                  )
                ),
                shinyglide::screen(
                  withSpinner(plotOutput("plt_resid_3"),
                    type = 8,
                    color = "#0460A9"
                  )
                ),
                shinyglide::screen(
                  withSpinner(plotOutput("plt_resid_4"),
                    type = 8,
                    color = "#0460A9"
                  )
                )
              )
            ),
            title = "Residual Plots",
            width = 6,
            status = "primary",
            solidHeader = TRUE
          )
        ),
        fluidRow(
          box(
            conditionalPanel(
              "input.calc",
              withSpinner(DTOutput("mod_coef"),
                type = 8,
                color = "#0460A9"
              )
            ),
            title = "Model Coefficients",
            width = 6,
            status = "primary",
            solidHeader = TRUE
          ),
          box(
            conditionalPanel(
              "input.calc",
              withSpinner(DTOutput("mod_anova"),
                type = 8,
                color = "#0460A9"
              )
            ),
            title = "Analysis of Variance",
            width = 6,
            status = "primary",
            solidHeader = TRUE
          )
        ),
        fluidRow(
          box(
            conditionalPanel(
              "input.calc",
              withSpinner(DTOutput("mod_smmry"),
                type = 8,
                color = "#0460A9"
              )
            ),
            title = "Model Summary",
            width = 6,
            status = "primary",
            solidHeader = TRUE
          ),
          box(
            conditionalPanel(
              "input.calc",
              withSpinner(DTOutput("mod_hmscdstcty"),
                type = 8,
                color = "#0460A9"
              )
            ),
            title = "Homoscedasticity",
            width = 6,
            status = "primary",
            solidHeader = TRUE
          )
        )
      ),
      tabItem(
        tabName = "report",
        box(
          textInput(
            "file_name",
            "File Name:",
            value = paste(format(Sys.time(), "%y%m%d"), "Report", sep = "_")
          ),
          awesomeRadio(
            inputId = "doc_format",
            label = "Document Format:",
            choices = c("PDF", "Word"),
            selected = "PDF",
            inline = TRUE
          ),
          awesomeCheckboxGroup(
            "inc_report", "Include in Report:",
            choices = c(
              # "Assay Results",
              "Linear Regression Results",
              "Linear Regression Plot",
              "Diagnostic Plots", "Homoscedasticity Assessment (ANVISA)"
            ),
            selected = c(
              # "Assay Results",
              "Linear Regression Results",
              "Linear Regression Plot",
              "Diagnostic Plots"
            ),
            status = "primary"
          ),
          downloadBttn(
            "gen_report",
            "Generate Report",
            style = "simple",
            color = "primary",
            size = "sm"
          ),
          title = "Report",
          status = "primary",
          solidHeader = TRUE,
          id = "download_box"
        )
      )
    )
  ),
  # remove switch for dark skin
  dark = NULL
)



# Server ======================================================================
server <- function(input, output, session) {
  # Reactive values for data
  data <- reactiveValues()
  # Reactive values for plot inputs
  plot_inputs <- reactiveValues(
    title_plt = "",
    label_x = "Concentration [mg/mL]",
    label_y = "Peak Area [mAU*min]",
    ref_concentration = 0,
    ref_conc_unit = "mg/mL"
  )


  # Store name of user --------------------------------------------------------
  rvalues <- reactiveValues(
    author_name = NULL,
    author_id = NULL
  )
  
  observeEvent(input$current_user, {
    rvalues$author_name <- input$current_user$NIBRFull
    rvalues$author_id <- input$current_user$NIBR521
  })
  

  # Hide ava2 profile picture since it is not properly working ----------------
  runjs("document.querySelector('.profile-pic').style.display='none';")


  # Load file -----------------------------------------------------------------
  observeEvent(input$upload, {
    ext <- tools::file_ext(input$upload$name)

    if (ext %in% c("csv", "tsv", "xlsx")) {
      hideFeedback("upload")
      # Use javascript to change progress bar color
      runjs('document.querySelector("#upload_progress > div").style.setProperty("background-color", "#0460A9", "important");')
      tmp <- switch(ext,
        csv = read_delim(
          input$upload$datapath,
          delim = if_else(grepl(";", readLines(input$upload$datapath, n = 1)),
            ";", ","
          ),
          show_col_types = FALSE
        ),
        tsv = read_delim(
          input$upload$datapath,
          delim = "\t",
          show_col_types = FALSE
        ),
        xlsx = readxl::read_excel(
          input$upload$datapath,
          col_names = TRUE
        )
      )
      colnames(tmp) <- make.names(colnames(tmp), unique = TRUE)
      data$orig_df <- tmp
    } else {
      showFeedbackWarning(
        inputId = "upload",
        text = "Invalid file format",
        color = "#EC9A1E",
        icon = NULL
      )
    }
  })


  # Check file import ---------------------------------------------------------
  output$import_ready <- reactive({
    return(!is.null(input$upload))
  })

  outputOptions(output, "import_ready", suspendWhenHidden = FALSE)


  # Update the dropdown menus for the column variables ----------------------
  observeEvent(input$upload, {
    updateSelectInput(
      inputId = "conc_lvl",
      choices = c(Choose = "", names(data$orig_df))
    )
  })

  observeEvent(input$conc_lvl,
    {
      if (is.numeric(data$orig_df[[input$conc_lvl]])) {
        hideFeedback("conc_lvl")
        choices <- setdiff(
          names(data$orig_df),
          c(
            input$conc_lvl
          )
        )
        updateSelectInput(
          inputId = "conc_sol",
          choices = c(Choose = "", choices)
        )
      } else if (input$conc_lvl == "") {
        hideFeedback("conc_lvl")
      } else {
        showFeedbackWarning(
          inputId = "conc_lvl",
          text = "Values must be numeric!",
          color = "#EC9A1E",
          icon = NULL
        )
      }
    },
    ignoreInit = TRUE
  )

  observeEvent(input$conc_sol,
    {
      if (is.numeric(data$orig_df[[input$conc_sol]])) {
        hideFeedback("conc_sol")
        choices <- setdiff(
          names(data$orig_df),
          c(
            input$conc_lvl,
            input$conc_sol
          )
        )
        updateSelectInput(
          inputId = "pk_area",
          choices = c(Choose = "", choices)
        )
      } else if (input$conc_sol == "") {
        hideFeedback("conc_sol")
      } else {
        showFeedbackWarning(
          inputId = "conc_sol",
          text = "Values must be numeric!",
          color = "#EC9A1E",
          icon = NULL
        )
      }
    },
    ignoreInit = TRUE
  )

  observeEvent(input$pk_area,
    {
      if (is.numeric(data$orig_df[[input$pk_area]])) {
        hideFeedback("pk_area")
        enable("calc")
      } else if (input$pk_area == "") {
        hideFeedback("pk_area")
        disable("calc")
      } else {
        showFeedbackWarning(
          inputId = "pk_area",
          text = "Values must be numeric!",
          color = "#EC9A1E",
          icon = NULL
        )
        disable("calc")
      }
    },
    ignoreInit = TRUE
  )


  # Reset inputs when new file is uploaded ------------------------------------
  observeEvent(input$upload, {
    reset("conc_lvl")
    reset("conc_sol")
    reset("pk_area")
    reset("plt_title")
    reset("lab_x")
    reset("lab_y")
    reset("ref_conc")
  })


  # Disable download button when inputs are missing ---------------------------
  shiny::observe(if (is.null(input$inc_report) || input$pk_area == "" ||
    is.null(input$pk_area) || input$file_name == "") {
    disable("gen_report_bttn")
    disable("gen_report")
  } else {
    enable("gen_report_bttn")
    enable("gen_report")
  })

  shiny::observe(if (input$file_name == "") {
    showFeedbackWarning(
      inputId = "file_name",
      text = "Please enter a file name!",
      color = "#EC9A1E",
      icon = NULL
    )
  } else {
    hideFeedback("file_name")
  })


  # Reset plot inputs when reset button is pressed
  observeEvent(input$reset_input, {
    updateTextInput(inputId = "plt_title", value = "")
    updateTextInput(inputId = "lab_x", value = "Concentration [mg/mL]")
    updateTextInput(inputId = "lab_y", value = "Peak Area [mAU*min]")
    updateNumericInput(inputId = "ref_conc", value = 0)
    updateTextInput(inputId = "ref_unit", value = "mg/mL")
  })


  # Models --------------------------------------------------------------------
  # Model coefficients
  lm_spec <- linear_reg() %>%
    set_engine("lm")

  lm_fit <- eventReactive(input$calc, {
    req(input$pk_area, input$conc_sol, data$orig_df)
    lm_spec %>%
      fit(as.formula(paste0(input$pk_area, "~", input$conc_sol)),
        data = data$orig_df
      )
  })

  output$mod_coef <- renderDT({
    coef_tbl_datatbl(lm_fit())
  })

  # Model Summary
  output$mod_smmry <- renderDT({
    smmry_tbl_datatbl(lm_fit())
  })

  # Analysis of variance
  anova_fit <- reactive({
    anova(lm_fit()$fit)
  })

  output$mod_anova <- renderDT({
    anova_tbl_datatbl(anova_fit())
  })

  # Homoscedasticity
  cochran <- reactive({
    cochran.test(as.formula(paste0(input$pk_area, "~", input$conc_lvl)),
      data = data$orig_df
    )
  })

  levene <- reactive({
    leveneTest(as.formula(paste0(input$pk_area, "~", input$conc_lvl)),
      data = data$orig_df %>% mutate(across(.data[[input$conc_lvl]], as.factor))
    )
  })

  fligner <- reactive({
    fligner.test(as.formula(paste0(input$pk_area, "~", input$conc_lvl)),
      data = data$orig_df
    )
  })

  output$mod_hmscdstcty <- renderDT({
    homosced_tbl_datatbl(cochran(), levene(), fligner())
  })

  # Plots ---------------------------------------------------------------------
  # Plot fitted line
  plt_ftd_line <- eventReactive(
    c(input$calc, input$update_plot),
    # ignoreInit = TRUE,
    {
      # Store the inputs made in the plot settings. This is required so that
      # the values are only used in the report when the update button has
      # actually been pressed.
      plot_inputs$title_plt <- input$plt_title
      plot_inputs$label_x <- input$lab_x
      plot_inputs$label_y <- input$lab_y
      plot_inputs$ref_concentration <- input$ref_conc
      plot_inputs$ref_conc_unit <- input$ref_unit

      line_plot(data$orig_df, input$conc_sol, input$pk_area,
        plot_inputs$label_x, plot_inputs$label_y, lm_fit(),
        plot_inputs$ref_concentration, plot_inputs$title_plt,
        app = TRUE
      )
    }
  )

  output$plt_line <- renderPlot(plt_ftd_line())

  # Plot residuals
  plt_sum_resid <- eventReactive(input$calc, {
    residual_plots(data$orig_df, lm_fit(), plot_inputs$label_x, app = TRUE)
  })

  output$plt_resid_1 <- renderPlot(plt_sum_resid()$p1)
  output$plt_resid_2 <- renderPlot(plt_sum_resid()$p2)
  output$plt_resid_3 <- renderPlot(plt_sum_resid()$p3)
  output$plt_resid_4 <- renderPlot(plt_sum_resid()$p4)

  # Source data ---------------------------------------------------------------
  src_data <- eventReactive(input$calc, {
    data$orig_df
  })

  output$data_table <- renderDT(
    src_data(),
    options = list(
      pageLength = 15,
      scrollX = TRUE
    )
  )


  # Waiter when report is generated -------------------------------------------
  w <- Waiter$new(
    id = "download_box", html = spin_loaders(id = 5, color = "#0460A9"),
    color = transparent(0.5)
  )


  # Final report --------------------------------------------------------------
  # Report generation
  output$gen_report <- downloadHandler(
    filename = function() {
      fs::path_sanitize(paste(input$file_name, sep = ".", switch(input$doc_format,
        PDF = "pdf",
        Word = "docx"
      )))
    },
    content = function(file) {

      # Show waiter animation during report generation
      w$show()

      # List of parameters for the pdf report
      params <- list()

      # Prepare tables and plots for the report
      # if ("Assay Results" %in% input$inc_report) {
      if (input$doc_format == "Word") {
        assay_rslts <- assay_rslts_rprt(
          data$orig_df, input$conc_lvl, input$conc_sol, input$pk_area,
          plot_inputs$label_x, plot_inputs$label_y, plot_inputs$title_plt,
          plot_inputs$ref_concentration, plot_inputs$ref_conc_unit
        )
      } else {
        assay_rslts <- assay_rslts_rprt_huxtbl(
          data$orig_df, input$conc_lvl, input$conc_sol, input$pk_area,
          plot_inputs$label_x, plot_inputs$label_y, plot_inputs$title_plt,
          plot_inputs$ref_concentration, plot_inputs$ref_conc_unit,
          6.29, 38, 38
        )
      }

      params <- append(params, list(
        assay_rslts = assay_rslts,
        eval_assay = TRUE
      ))
      # } else {
      #   params <- append(params, list(eval_assay = FALSE))
      # }

      if ("Linear Regression Results" %in% input$inc_report) {
        if (input$doc_format == "Word") {
          lin_reg_rslts <- lin_reg_rslts_rprt(
            lm_fit(), input$conc_sol,
            plot_inputs$ref_concentration,
            plot_inputs$ref_conc_unit
          )
        } else {
          lin_reg_rslts <- lin_reg_rslts_rprt_huxtbl(
            lm_fit(), input$conc_sol,
            plot_inputs$ref_concentration,
            plot_inputs$ref_conc_unit
          )
        }

        params <- append(params, list(
          lin_reg_rslts = lin_reg_rslts,
          eval_reg_rslts = TRUE
        ))
      } else {
        params <- append(params, list(eval_reg_rslts = FALSE))
      }

      if ("Linear Regression Plot" %in% input$inc_report) {
        reg_gg <- line_plot(
          data$orig_df, input$conc_sol, input$pk_area, plot_inputs$label_x,
          plot_inputs$label_y, lm_fit(), plot_inputs$ref_concentration,
          plot_inputs$title_plt,
          app = FALSE
        )

        if (input$doc_format == "Word") {
          user_inputs <- user_input_tbl(
            plot_inputs$ref_concentration, plot_inputs$ref_conc_unit
          )
        } else {
          user_inputs <- user_input_tbl_huxtbl(
            plot_inputs$ref_concentration, plot_inputs$ref_conc_unit
          )
        }

        params <- append(params, list(
          reg_gg = reg_gg,
          user_inputs = user_inputs,
          eval_reg_plot = TRUE
        ))
      } else {
        params <- append(params, list(eval_reg_plot = FALSE))
      }

      if ("Diagnostic Plots" %in% input$inc_report) {
        res_plots <- residual_plots(data$orig_df, lm_fit(),
          plot_inputs$label_x,
          app = FALSE
        )

        params <- append(params, list(
          res_plots = res_plots,
          eval_res_plots = TRUE
        ))
      } else {
        params <- append(params, list(eval_res_plots = FALSE))
      }

      if ("Homoscedasticity Assessment (ANVISA)" %in% input$inc_report) {
        if (input$doc_format == "Word") {
          anvisa_tbl <- homosced_tbl_rprt(
            lm_fit(), cochran(), levene(),
            fligner(), anova_fit()
          )
        } else {
          anvisa_tbl <- homosced_tbl_rprt_huxtbl(
            lm_fit(), cochran(), levene(), fligner(),
            anova_fit()
          )
        }

        params <- append(params, list(
          anvisa_tbl = anvisa_tbl,
          eval_anvisa_tbl = TRUE
        ))
      } else {
        params <- append(params, list(eval_anvisa_tbl = FALSE))
      }

      # Code chunk for creating the word report
      if (input$doc_format == "Word") {
        doc <- read_docx("www/template_officer.docx")

        # if ("Assay Results" %in% input$inc_report &&
        #   "Assay Results" == tail(input$inc_report, n = 1)) {
        #   doc <- doc %>%
        #     body_add_par("Data Verification Report for Linearity Assessment",
        #       style = "heading 1"
        #     ) %>%
        #     body_add_par_n(2) %>%
        #     body_add_flextable(assay_rslts, keepnext = FALSE)
        # } else if ("Assay Results" %in% input$inc_report) {
        doc <- doc %>%
          body_add_par("Data Used for Linearity Assessment",
            style = "heading 1"
          ) %>%
          body_add_par_n(2) %>%
          body_add_flextable(assay_rslts, keepnext = FALSE) %>%
          body_add_break() %>%
          body_add_par("")
        # }

        if ("Linear Regression Results" %in% input$inc_report &&
          "Linear Regression Results" == tail(input$inc_report, n = 1)) {
          doc <- doc %>%
            body_add_par("Linear Regression Results",
              style = "heading 1"
            ) %>%
            body_add_par_n(2) %>%
            body_add_flextable(lin_reg_rslts)
        } else if ("Linear Regression Results" %in% input$inc_report) {
          doc <- doc %>%
            body_add_par("Linear Regression Results",
              style = "heading 1"
            ) %>%
            body_add_par_n(2) %>%
            body_add_flextable(lin_reg_rslts) %>%
            body_add_break() %>%
            body_add_par("")
        }

        if ("Linear Regression Plot" %in% input$inc_report &&
          "Linear Regression Plot" == tail(input$inc_report,
            n = 1
          )) {
          doc <- doc %>%
            body_add_par("Linear Regression Plot",
              style = "heading 1"
            ) %>%
            body_add_par_n(2) %>%
            body_add_gg(reg_gg,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_par_n(5) %>%
            body_add_flextable(user_inputs)
        } else if ("Linear Regression Plot" %in% input$inc_report) {
          doc <- doc %>%
            body_add_par("Linear Regression Plot",
              style = "heading 1"
            ) %>%
            body_add_par_n(2) %>%
            body_add_gg(reg_gg,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_par_n(5) %>%
            body_add_flextable(user_inputs) %>%
            body_add_break() %>%
            body_add_par("")
        }

        if (
          "Diagnostic Plots" %in% input$inc_report &&
            "Diagnostic Plots" == tail(input$inc_report,
              n = 1
            )) {
          doc <- doc %>%
            body_add_par("Diagnostic Plots",
              style = "heading 1"
            ) %>%
            body_add_par_n(2) %>%
            body_add_gg(res_plots$p1,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_par_n(5) %>%
            body_add_gg(res_plots$p2,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_break() %>%
            body_add_par("") %>%
            body_add_gg(res_plots$p3,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_par_n(5) %>%
            body_add_gg(res_plots$p4,
              width = 6.3,
              height = 3.54
            )
        } else if ("Diagnostic Plots" %in% input$inc_report) {
          doc <- doc %>%
            body_add_par("Diagnostic Plots",
              style = "heading 1"
            ) %>%
            body_add_par_n(2) %>%
            body_add_gg(res_plots$p1,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_par_n(5) %>%
            body_add_gg(res_plots$p2,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_break() %>%
            body_add_par("") %>%
            body_add_gg(res_plots$p3,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_par_n(5) %>%
            body_add_gg(res_plots$p4,
              width = 6.3,
              height = 3.54
            ) %>%
            body_add_break() %>%
            body_add_par("")
        }

        if ("Homoscedasticity Assessment (ANVISA)" %in% input$inc_report) {
          doc <- doc %>%
            body_add_par("Homoscedasticity Evaluation in Accordance with ANVISA RDC 166/2017 Requirements",
              style = "heading 1"
            ) %>%
            body_add_par_n(2) %>%
            body_add_flextable(anvisa_tbl)
        }

        # Add title and author name in the doc header
        header_title <- if_else(
          plot_inputs$title_plt == "",
          "Linearity Report", plot_inputs$title_plt
        )

        doc <- doc %>%
          headers_replace_all_text("title", header_title,
            warn = FALSE
          ) %>%
          headers_replace_all_text("date", format(now(), "%d-%b-%y %H:%M:%S %Z"),
            warn = FALSE
          ) %>%
          footers_replace_all_text("author_name", glue(
            "{as.character(rvalues$author_name)} ({as.character(rvalues$author_id)})"
          ),
          warn = FALSE
          ) %>%
        footers_replace_all_text("version",
          glue("App Version: {getOption('deployVersion')}"),
          warn = FALSE
        )

        print(doc, target = file)
      } else {
        # Copy the report file to a temporary directory before processing it, in
        # case we don't have write permissions to the current working dir
        tempReport <- file.path(tempdir(), "report.Rmd")
        file.copy("www/report.Rmd", tempReport, overwrite = TRUE)

        # Set parameters for header and footer
        params <- append(params, list(
          title = plot_inputs$title_plt,
          date = format(now(), "%d-%b-%y %H:%M:%S %Z"),
          author_name = glue(
            "{as.character(rvalues$author_name)} ({as.character(rvalues$author_id)})"
          ),
          version = glue("App Version: {getOption('deployVersion')}")
        ))


        # Knit the document, passing in the `params` list, and eval it in a
        # child of the global environment (this isolates the code in the document
        # from the code in this app).
        rmarkdown::render(tempReport,
          output_file = file,
          params = params,
          envir = new.env(parent = globalenv())
        )
      }

      on.exit({
        w$hide()
      })
    }
  )
}



# Run app =====================================================================
shinyApp(ui, server)
