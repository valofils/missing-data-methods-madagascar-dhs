# 01_load_recode.R — read DHS recode files (only the columns the pipeline uses)

source(here::here("R", "00_setup.R"))

pr_vars <- c(
  # identifiers and design
  "hv001", "hv002", "hvidx", "hv005", "hv021", "hv022", "hv023",
  # household
  "hv024", "hv025", "hv270", "hv042", "hv009",
  # member
  "hv103", "hv104", "hv105", "hv120",
  # child anthropometry (PR, "HC" block)
  "hc1", "hc13", "hc27", "hc60", "hc61", "hc70", "hc71", "hc72"
)

pr_raw <- read_dta(files$pr, col_select = all_of(pr_vars))

# KR file is loaded only for the PR-vs-KR anthropometry cross-check in 05_validation.R
kr_raw <- read_dta(files$kr, col_select = c("v005", "v021", "v022", "b5", "hw1", "hw70", "hw72"))

saveRDS(pr_raw, file.path(paths$derived, "pr_raw.rds"))
saveRDS(kr_raw, file.path(paths$derived, "kr_raw.rds"))
message("01: PR rows = ", nrow(pr_raw), "; KR rows = ", nrow(kr_raw))
