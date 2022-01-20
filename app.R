# Libraries -------------------------------------------------------------------
library(shiny)
library(ava2)
library(shinycssloaders)
library(shinyFeedback)
library(shinyjs)
library(shinyWidgets)
library(tidyverse)
library(tidymodels)
library(gridExtra)
library(DT)
library(flextable)
library(officer)
library(reactable)


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
              selectInput("conc_lvl", "Concentration level column:",
                choices = c(Choose = "")
              )
            ),
            conditionalPanel(
              "input.conc_lvl",
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
            # Action button for calculation
            conditionalPanel(
              "input.conc_sol",
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
              withSpinner(reactableOutput("mod_coef"),
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
              withSpinner(reactableOutput("mod_anova"),
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
              withSpinner(reactableOutput("mod_smmry"),
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
          textInput("Batch", "Batch:", value = "Batch"),
          textInput(
            "file_name",
            "File Name:",
            value = paste(format(Sys.time(), "%y%m%d"), "Report", sep = "_")
          ),
          awesomeCheckboxGroup(
            "inc_report", "Include in Report:",
            choices = c("Summary Comparison", "ANOVA Results"),
            selected = c("Summary Comparison", "ANOVA Results"),
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
      "conc_lvl",
      choices = c(Choose = "", names(data$orig_df))
    )
  })

  observeEvent(input$conc_lvl,
    {
      if (is.numeric(data$orig_df[[input$conc_lvl]])) {
        hideFeedback("conc_lvl")
        choices <- names(data$orig_df)[!(names(data$orig_df) %in%
          c(
            input$conc_lvl
          ))]
        updateSelectInput(
          session,
          "conc_sol",
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
        choices <- names(data$orig_df)[!(names(data$orig_df) %in%
          c(
            input$conc_lvl,
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


  # Reset inputs when new file is uploaded ------------------------------------
  observeEvent(input$upload, {
    reset("conc_lvl")
    reset("conc_sol")
    reset("pk_area")
    reset("calc")
  })


  # Disable download button if inputs are missing -----------------------------
  shiny::observe(if (is.null(input$inc_report) |
    input$pk_area == "" | is.null(input$pk_area)) {
    disable("gen_report_bttn")
    disable("gen_report")
  } else {
    enable("gen_report_bttn")
    enable("gen_report")
  })

  shiny::observe(if (input$Batch == "") {
    showFeedbackWarning(
      inputId = "Batch",
      text = "Please enter a batch name!",
      color = "#EC9A1E",
      icon = NULL
    )
    disable("gen_report_bttn")
    disable("gen_report")
  } else {
    hideFeedback("Batch")
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
    disable("gen_report_bttn")
    disable("gen_report")
  } else {
    hideFeedback("file_name")
    enable("gen_report_bttn")
    enable("gen_report")
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

  output$mod_coef <- renderReactable({
    coef_tbl(lm_fit())
  })

  # Model Summary
  output$mod_smmry <- renderReactable({
    smmry_tbl(lm_fit())
  })

  # Analysis of variance
  anova_fit <- eventReactive(input$calc, {
    anova(lm_fit()$fit)
  })

  output$mod_anova <- renderReactable({
    anova_tbl(anova_fit())
  })

  # Plots ---------------------------------------------------------------------
  # Plot fitted line
  plt_ftd_line <- eventReactive(input$calc, {
    line_plot(data$orig_df, input$conc_sol, input$pk_area)
  })
  output$plt_line <- renderPlot(plt_ftd_line())

  # Plot residuals
  plt_sum_resid <- eventReactive(input$calc, {
    residual_plots(data$orig_df, lm_fit())
  })
  output$plt_resid <- renderPlot(plt_sum_resid())


  # Source data ---------------------------------------------------------------
  src_data <- eventReactive(input$calc, {
    data$orig_df
  })
  output$data_table <- renderDT(
    src_data(),
    options = list(
      pageLength = 15
    )
  )


  # Final report --------------------------------------------------------------
  # Report generation
  output$gen_report <- downloadHandler(
    filename = function() {
      fs::path_sanitize(paste0(input$file_name, ".docx"))
    },
    content = function(file) {
      smmry_tbl <- smmry_rprt(
        data$modif_df, input$Id_var, input$Value_var, input$Day_var,
        input$Site_var, input$Analyst_var, input$HPLC_var, input$Lot_var,
        input$Batch
      )

      anova_tbl <- anova_rprt(
        data$modif_df, input$Id_var, input$Value_var, input$Analyst_var,
        mod_orig(), input$Batch
      )

      if ("Summary Comparison" %in% input$inc_report &&
        "ANOVA Results" %in% input$inc_report) {
        read_docx("www/template_officer.docx") %>%
          body_add_flextable(smmry_tbl) %>%
          body_add_break() %>%
          body_add_par("") %>%
          body_add_flextable(anova_tbl) %>%
          print(target = file)
      } else if ("Summary Comparison" %in% input$inc_report) {
        read_docx("www/template_officer.docx") %>%
          body_add_flextable(smmry_tbl) %>%
          print(target = file)
      } else {
        read_docx("www/template_officer.docx") %>%
          body_add_flextable(anova_tbl) %>%
          print(target = file)
      }
    }
  )
}



# Run app =====================================================================
shinyApp(ui, server)
