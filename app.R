# Libraries -------------------------------------------------------------------
library(shiny)
library(ava2)
library(shinycssloaders)
library(shinyFeedback)
library(shinyjs)
library(shinyWidgets)
library(tidyverse)
library(tidymodels)
library(ggplotify)
library(gridExtra)
library(DT)
library(flextable)
library(officer)
library(waiter)


# Options ---------------------------------------------------------------------
options(readr.show_progress = FALSE)
options(readxl.show_progress = FALSE)
options(
  appName = "Method Validation",
  appDesc = "",
  deployVersion = "Beta",
  email = "dominic.schaerer@novartis.com",
  author = "Dominic Schärer"
)


# Source function files -------------------------------------------------------
R.utils::sourceDirectory("R")



# UI ==========================================================================
ui <- dashboardPage(
  dashboardHeader(),
  dashboardSidebar(
    width = "275px",
    fixed = TRUE,
    skin = "light",
    minified = FALSE,
    includeCSS("www/style.css"),
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
        box(includeHTML("www/information.html"),
          id = "info_box",
          width = 12,
          headerBorder = FALSE
        )
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
              selectInput("conc_sol", "Concentration of solution column:",
                choices = c(Choose = "")
              )
            ),
            conditionalPanel(
              "input.conc_sol",
              selectInput("pk_area", "Peak area column:",
                choices = c(Choose = "")
              )
            ),
            conditionalPanel(
              "input.pk_area",
              textInput(
                "unit_conc", "Unit concentration of solution:",
                "mg/ml"
              )
            ),
            conditionalPanel(
              "input.pk_area",
              textInput(
                "unit_pk_area", "Unit peak area:",
                "mAU*min"
              )
            ),
            conditionalPanel(
              "input.pk_area",
              numericInput(
                "ref_conc", "Reference concentration:",
                0,
                step = 0.01
              )
            ),
            # Action button for calculation
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
          box(conditionalPanel(
            "input.calc",
            withSpinner(plotOutput("plt_line"),
              type = 8,
              color = "#0460A9"
            )
          ),
          title = "Fitted Line Plot",
          width = 6,
          status = "primary",
          solidHeader = TRUE
          ),
          box(conditionalPanel(
            "input.calc",
            withSpinner(plotOutput("plt_resid"),
              type = 8,
              color = "#0460A9"
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
          )
        )
      ),
      tabItem(
        tabName = "report",
        box(
          materialSwitch(
            inputId = "det_res_swtch",
            label = "Detailed Assay Results",
            value = FALSE,
            status = "primary"
          ),
          selectInput("conc_lvl", "Concentration level column:",
            choices = c(Choose = "")
          ),
          textInput(
            "file_name",
            "File Name:",
            value = paste(format(Sys.time(), "%y%m%d"), "Report", sep = "_")
          ),
          awesomeCheckboxGroup(
            "inc_report", "Include in Report:",
            choices = c(
              "Assay Results", "Linear Regression Results",
              "Linear Regression Plot",
              "Diagnostic Plots"
            ),
            selected = c(
              "Assay Results", "Linear Regression Results",
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
  data <- reactiveValues()


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
          delim = ";",
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
      session,
      "conc_sol",
      choices = c(Choose = "", names(data$orig_df))
    )
  })

  observeEvent(input$conc_sol,
    {
      if (is.numeric(data$orig_df[[input$conc_sol]])) {
        hideFeedback("conc_sol")
        choices <- names(data$orig_df)[!(names(data$orig_df) %in%
          c(
            input$conc_sol
          ))]
        updateSelectInput(
          session,
          "pk_area",
          choices = c(Choose = "", choices)
        )
        disable("calc")
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

  observeEvent(input$calc, {
    choices <- names(data$orig_df)[!(names(data$orig_df) %in%
      c(
        input$conc_sol,
        input$pk_area
      ))]
    updateSelectInput(
      session,
      "conc_lvl",
      choices = c(Choose = "", choices)
    )
  })

  observeEvent(input$conc_lvl,
    {
      if (is.numeric(data$orig_df[[input$conc_lvl]])) {
        hideFeedback("conc_lvl")
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


  # Reset inputs when new file is uploaded ------------------------------------
  observeEvent(input$upload, {
    reset("conc_lvl")
    reset("conc_sol")
    reset("pk_area")
    reset("unit_conc")
    reset("unit_pk_area")
    reset("ref_conc")
    reset("calc")
  })


  # Show/Hide inputs for detailed report --------------------------------------
  shiny::observe(if (input$det_res_swtch == FALSE) {
    shinyjs::hide("conc_lvl")
  } else {
    shinyjs::show("conc_lvl")
  })


  # Disable calculate button when inputs are missing ---------------------------
  shiny::observe(if (input$unit_conc == "" || input$unit_pk_area == "") {
    disable("calc")
  } else {
    enable("calc")
  })

  shiny::observe(if (input$unit_conc == "") {
    showFeedbackWarning(
      inputId = "unit_conc",
      text = "Please enter a unit!",
      color = "#EC9A1E",
      icon = NULL
    )
  } else {
    hideFeedback("unit_conc")
  })

  shiny::observe(if (input$unit_pk_area == "") {
    showFeedbackWarning(
      inputId = "unit_pk_area",
      text = "Please enter a unit!",
      color = "#EC9A1E",
      icon = NULL
    )
  } else {
    hideFeedback("unit_pk_area")
  })


  # Disable download button when inputs are missing ---------------------------
  shiny::observe(if (is.null(input$inc_report) || input$pk_area == "" ||
    is.null(input$pk_area) || input$file_name == "" ||
    (input$conc_lvl == "" && input$det_res_swtch == TRUE) ||
    (!is.numeric(data$orig_df[[input$conc_lvl]]) &&
      input$det_res_swtch == TRUE)) {
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


  # Models --------------------------------------------------------------------
  # Model coefficients
  lm_spec <- linear_reg() %>%
    set_engine("lm")

  lm_fit <- eventReactive(input$calc, {
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
  anova_fit <- eventReactive(input$calc, {
    anova(lm_fit()$fit)
  })

  output$mod_anova <- renderDT({
    anova_tbl_datatbl(anova_fit())
  })

  # Plots ---------------------------------------------------------------------
  # Plot fitted line
  plt_ftd_line <- eventReactive(input$calc, {
    line_plot(data$orig_df, input$conc_sol, input$pk_area, input$unit_conc,
      input$unit_pk_area, lm_fit(), input$ref_conc,
      app = TRUE
    )
  })
  output$plt_line <- renderPlot(plt_ftd_line())

  # Plot residuals
  plt_sum_resid <- eventReactive(input$calc, {
    residual_plots(data$orig_df, lm_fit(), app = TRUE)
  })
  output$plt_resid <- renderPlot(plt_sum_resid())


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
      fs::path_sanitize(paste0(input$file_name, ".docx"))
    },
    content = function(file) {
      w$show()
      if (input$det_res_swtch) {
        assay_rslts <- assay_rslts_rprt(
          data$orig_df, input$conc_lvl, input$conc_sol, input$pk_area,
          input$unit_conc, input$unit_pk_area
        )
      } else {
        assay_rslts <- assay_rslts_rprt_smpl(
          data$orig_df, input$conc_sol, input$pk_area,
          input$unit_conc, input$unit_pk_area
        )
      }

      lin_reg_rslts <- lin_reg_rslts_rprt(
        lm_fit(), input$conc_sol,
        input$ref_conc
      )

      doc <- read_docx("www/template_officer.docx")

      if ("Assay Results" %in% input$inc_report &&
        "Assay Results" == tail(input$inc_report, n = 1)) {
        doc <- doc %>%
          body_add_flextable(assay_rslts)
      } else if ("Assay Results" %in% input$inc_report) {
        doc <- doc %>%
          body_add_flextable(assay_rslts) %>%
          body_add_break() %>%
          body_add_par("")
      }

      if ("Linear Regression Results" %in% input$inc_report &&
        "Linear Regression Results" == tail(input$inc_report, n = 1)) {
        doc <- doc %>%
          body_add_flextable(lin_reg_rslts)
      } else if ("Linear Regression Results" %in% input$inc_report) {
        doc <- doc %>%
          body_add_flextable(lin_reg_rslts) %>%
          body_add_break() %>%
          body_add_par("")
      }

      if ("Linear Regression Plot" %in% input$inc_report &&
        "Linear Regression Plot" == tail(input$inc_report,
          n = 1
        )) {
        doc <- doc %>%
          body_add_gg(line_plot(
            data$orig_df, input$conc_sol, input$pk_area, input$unit_conc,
            input$unit_pk_area, lm_fit(), input$ref_conc,
            app = FALSE
          ),
          width = 6.3,
          height = 3.54
          )
      } else if ("Linear Regression Plot" %in% input$inc_report) {
        doc <- doc %>%
          body_add_gg(line_plot(
            data$orig_df, input$conc_sol, input$pk_area, input$unit_conc,
            input$unit_pk_area, lm_fit(), input$ref_conc,
            app = FALSE
          ),
          width = 6.3,
          height = 3.54
          ) %>%
          body_add_break() %>%
          body_add_par("")
      }

      if (
        "Diagnostic Plots" %in% input$inc_report
      ) {
        doc <- doc %>%
          body_add_gg(
            ggplot_conv(
              residual_plots(data$orig_df, lm_fit(), app = FALSE)
            ),
            width = 6.3,
            height = 3.54
          )
      }

      print(doc, target = file)

      on.exit({
        w$hide()
      })
    }
  )
}



# Run app =====================================================================
shinyApp(ui, server)
