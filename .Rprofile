source("renv/activate.R")

local({
  r <- getOption("repos")
  r["CRAN"] <- "https://rspm.apps.dit-prdocp.novartis.net/validated-R-4.1.0/2023-03-06+MTI6MzYxMjs5QzhDRjM3Qg"
  r["AVA"] <- "http://ava-web.apps.busdevocp.novartis.net/cran"
  r["RSPM"] <- "https://rspm.apps.dit-prdocp.novartis.net/exploratory/latest"
  options(repos = r) 
})

Sys.setenv("no_proxy" = ".novartis.net,novartis.intra")
