# run_all.R — reproduces the full pipeline in order.
# 05_validation.R stops the pipeline if the validation gate fails, so 10+ never run on a
# pipeline that does not reproduce the Final Report.

scripts <- c(
  "00_setup.R",
  "01_load_recode.R",
  "02_derive_variables.R",
  "03_missingness_summary.R",
  "04_design.R",
  "05_validation.R",
  "10_observed_methods.R",
  "30_equity_ranking.R",
  "40_tables.R",     # simulation tables included once 21_simulation_summary.R full has run
  "41_figures.R"     # Figure 2 / S2 likewise
)

# RQ3 simulation (about 30-40 h on 4 cores; resumable) is run separately:
#   Rscript R/20_simulation.R full
#   Rscript R/21_simulation_summary.R full
# On a laptop, use the keep-awake wrapper (workers do not survive sleep), launched as its
# own process so it is not tied to the terminal or app that started it:
#   powershell -ExecutionPolicy Bypass -File R\run_simulation_awake.ps1 full

for (s in scripts) {
  message("\n===== ", s, " =====")
  source(here::here("R", s), echo = FALSE)
}
