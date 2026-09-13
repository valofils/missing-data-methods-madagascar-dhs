# 20_simulation.R — RQ3 simulation driver (protocol: docs/simulation_protocol.md)
#
# Usage:  Rscript R/20_simulation.R pilot     (R = 20 per scenario; ntree sub-study R = 4)
#         Rscript R/20_simulation.R full      (R = 500 per scenario; ntree sub-study R = 200)
# Each (scenario, replicate) task writes one .rds of estimates to data/derived/sim_<mode>/;
# existing files are skipped, so an interrupted run resumes where it stopped.
# Every task has its own seed (SEED + scenario * 1e5 + replicate) and is reproducible alone.

source(here::here("R", "00_setup.R"))
source(here::here("R", "04_design.R"))
source(here::here("R", "fn_methods.R"))
source(here::here("R", "fn_simulation.R"))

args <- commandArgs(trailingOnly = TRUE)
MODE <- if (length(args) && args[1] %in% c("pilot", "full")) args[1] else "pilot"
N_REP     <- c(pilot = 20, full = 500)[[MODE]]
N_REP_SUB <- c(pilot = 4,  full = 200)[[MODE]]
N_SIM_WORKERS <- max(1L, parallel::detectCores(logical = FALSE))

out_dir <- file.path(paths$derived, paste0("sim_", MODE))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
log_file <- file.path(out_dir, "progress.log")

# ---- setup (pseudo-population, truth, calibration) --------------------------------------------
kids <- readRDS(file.path(paths$derived, "kids.rds"))
setup <- build_sim_setup(kids)
saveRDS(setup, file.path(paths$derived, "sim_setup.rds"))
scen <- sim_scenarios()
write.csv(scen, file.path(paths$tables, "rq3_scenarios.csv"), row.names = FALSE)
write.csv(setup$truth, file.path(paths$tables, "rq3_truth.csv"), row.names = FALSE)
message("20: pseudo-population n = ", setup$n_pop, "; truth stunting = ",
        round(100 * setup$truth$truth[setup$truth$outcome == "stunted" & setup$truth$axis == "National"], 2),
        "%, wasting = ",
        round(100 * setup$truth$truth[setup$truth$outcome == "wasted" & setup$truth$axis == "National"], 2), "%")
if (nrow(setup$collapse)) message("20: collapsed strata: ",
                                  paste(setup$collapse$stratum, "->", setup$collapse$partner, collapse = ", "))

# ---- task list --------------------------------------------------------------------------------
tasks <- bind_rows(lapply(seq_len(nrow(scen)), function(i) {
  n <- if (scen$ntree[i] != SIM$ntree) N_REP_SUB else N_REP
  data.frame(scenario = scen$scenario[i], rep = seq_len(n))
})) %>%
  mutate(file = file.path(out_dir, sprintf("s%02d_r%04d.rds", scenario, rep)))
todo <- tasks %>% filter(!file.exists(file))
message("20: mode = ", MODE, "; tasks = ", nrow(tasks), "; remaining = ", nrow(todo),
        "; workers = ", N_SIM_WORKERS)

# ---- run --------------------------------------------------------------------------------------
if (nrow(todo)) {
  # interleave scenarios so partial results cover every scenario
  todo <- todo %>% group_by(scenario) %>% mutate(k = row_number()) %>% ungroup() %>% arrange(k, scenario)
  cl <- parallel::makePSOCKcluster(N_SIM_WORKERS)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  parallel::clusterCall(cl, function(root) {
    suppressMessages({
      source(file.path(root, "R", "00_setup.R")); source(file.path(root, "R", "04_design.R"))
      source(file.path(root, "R", "fn_methods.R")); source(file.path(root, "R", "fn_simulation.R"))
    })
    RNGkind("L'Ecuyer-CMRG")
    assign("setup", readRDS(file.path(root, "data", "derived", "sim_setup.rds")), envir = globalenv())
    NULL
  }, here::here())

  t0 <- Sys.time()
  invisible(parallel::parLapplyLB(cl, split(todo, seq_len(nrow(todo))), function(tk, scen, log_file) {
    sc <- scen[scen$scenario == tk$scenario, ]
    t1 <- Sys.time()
    res <- tryCatch(run_replicate(setup, sc, tk$rep),
                    error = function(e) data.frame(scenario = tk$scenario, rep = tk$rep,
                                                   method = "REPLICATE", error = conditionMessage(e)))
    saveRDS(res, tk$file)
    cat(sprintf("%s s%02d r%04d %.1fs errors=%d\n", format(Sys.time(), "%H:%M:%S"), tk$scenario, tk$rep,
                as.numeric(difftime(Sys.time(), t1, units = "secs")),
                sum(!is.na(res$error) & !duplicated(res$method))),
        file = log_file, append = TRUE)
    NULL
  }, scen = scen, log_file = log_file))
  message("20: finished ", nrow(todo), " tasks in ", format(Sys.time() - t0, digits = 3))
}
