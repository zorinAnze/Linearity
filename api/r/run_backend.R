#!/usr/bin/env Rscript
# Start the internal R analysis backend on loopback.
#   Rscript api/r/run_backend.R [port]
port <- as.integer(Sys.getenv("LINEARITY_R_PORT", unset = "8001"))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) port <- as.integer(args[1])

root <- Sys.getenv("LINEARITY_ROOT", unset = "/home/adnan/projects/shiny")
setwd(root)

cat(sprintf("Linearity R backend starting on http://127.0.0.1:%d\n", port))
plumber::pr(file.path(root, "api", "r", "plumber.R")) |>
  plumber::pr_run(host = "127.0.0.1", port = port)
