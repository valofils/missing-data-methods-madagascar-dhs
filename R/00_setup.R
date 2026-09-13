# 00_setup.R — packages, options, seed, paths
# Sourced by run_all.R and by every numbered script (idempotent).

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
  library(survey)
  library(here)
})

options(survey.lonely.psu = "adjust")

# Global RNG seed for all stochastic steps (MI, simulation). Record in the paper.
SEED <- 20210301L
set.seed(SEED)

paths <- list(
  raw      = here("data", "raw"),
  derived  = here("data", "derived"),
  tables   = here("outputs", "tables"),
  figures  = here("outputs", "figures"),
  validate = here("outputs", "validation")
)
invisible(lapply(paths, dir.create, recursive = TRUE, showWarnings = FALSE))

# DHS-8 Madagascar 2021 recode files (version suffix confirmed from download: 81FL)
files <- list(
  pr = file.path(paths$raw, "MDPR81DT", "MDPR81FL.DTA"),
  kr = file.path(paths$raw, "MDKR81DT", "MDKR81FL.DTA")
)
stopifnot(all(file.exists(unlist(files))))
