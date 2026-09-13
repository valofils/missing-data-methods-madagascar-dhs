# 21_simulation_summary.R — RQ3 performance measures from stored replicates
#
# Usage: Rscript R/21_simulation_summary.R pilot | full
# Performance measures and Monte Carlo SEs follow Morris, White & Crowther (Stat Med 2019):
#   bias, relative bias, empirical SE, model SE (root mean squared SE), SE ratio, RMSE,
#   coverage of 95% CIs, mean CI width; ranking recovery for regions.

source(here::here("R", "00_setup.R"))

args <- commandArgs(trailingOnly = TRUE)
MODE <- if (length(args) && args[1] %in% c("pilot", "full")) args[1] else "pilot"
in_dir <- file.path(paths$derived, paste0("sim_", MODE))
TOP_K <- 5

files <- list.files(in_dir, pattern = "^s\\d+_r\\d+\\.rds$", full.names = TRUE)
raw   <- bind_rows(lapply(files, readRDS))
truth <- read.csv(file.path(paths$tables, "rq3_truth.csv"), stringsAsFactors = FALSE)
# scenario labels come from the replicate files themselves (robust to scenario renumbering)
scen <- raw %>% filter(!is.na(mechanism)) %>% distinct(scenario, mechanism, rate, ntree) %>%
  mutate(label = sprintf("%s %d%%%s", mechanism, round(100 * rate),
                         ifelse(ntree != 10, sprintf(" (ntree=%d)", ntree), "")))

METHOD_LEVELS <- c("Complete data", "CCA", "IPW", "MI-PMM", "MI-RF", "MI-RF (ntree=50)")

# ---- run diagnostics -------------------------------------------------------------------------
errors <- raw %>% filter(!is.na(error)) %>% distinct(scenario, rep, method, error)
run_diag <- raw %>%
  distinct(scenario, rep, method, seconds, miss_rate, miss_rate_w) %>%
  group_by(scenario, method) %>%
  summarise(n_reps = n_distinct(rep), mean_seconds = mean(seconds, na.rm = TRUE),
            mean_miss_rate = mean(miss_rate), mean_miss_rate_weighted = mean(miss_rate_w),
            .groups = "drop") %>%
  left_join(errors %>% count(scenario, method, name = "n_errors"), by = c("scenario", "method")) %>%
  mutate(n_errors = coalesce(n_errors, 0L)) %>%
  left_join(scen %>% select(scenario, label), by = "scenario")

est <- raw %>%
  filter(is.na(error)) %>%
  left_join(truth, by = c("outcome", "axis", "group")) %>%
  mutate(method = factor(method, METHOD_LEVELS),
         covered = lo <= truth & truth <= hi,
         degenerate = !is.finite(lo) | !is.finite(hi))

# ---- national performance --------------------------------------------------------------------
perf <- est %>%
  filter(axis == "National") %>%
  group_by(scenario, mechanism, rate, method, outcome) %>%
  summarise(
    n_sim = n(), theta = first(truth),
    mean_est = mean(p),
    bias = mean_est - theta,               bias_mcse = sd(p) / sqrt(n_sim),
    rel_bias = bias / theta,
    emp_se = sd(p),                        emp_se_mcse = sd(p) / sqrt(2 * (n_sim - 1)),
    mod_se = sqrt(mean(se_p^2)),
    mod_se_mcse = sqrt(var(se_p^2) / (4 * n_sim * mean(se_p^2))),
    se_ratio = mod_se / emp_se,
    mse = mean((p - theta)^2),
    rmse = sqrt(mse),
    rmse_mcse = sqrt(sum(((p - theta)^2 - mse)^2) / (n_sim * (n_sim - 1))) / (2 * sqrt(mse)),
    coverage = mean(covered, na.rm = TRUE), coverage_mcse = sqrt(coverage * (1 - coverage) / n_sim),
    ci_width = mean(hi - lo, na.rm = TRUE),
    mean_fmi = mean(fmi, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  select(-mse) %>%
  left_join(scen %>% select(scenario, label), by = "scenario") %>%
  arrange(outcome, scenario, method)

# ---- subgroup performance (averaged over groups) ---------------------------------------------
perf_sub <- est %>%
  filter(axis != "National") %>%
  group_by(scenario, mechanism, rate, method, outcome, axis, group) %>%
  summarise(theta = first(truth), bias = mean(p) - theta, coverage = mean(covered, na.rm = TRUE),
            n_degenerate = sum(degenerate), .groups = "drop") %>%
  group_by(scenario, mechanism, rate, method, outcome, axis) %>%
  summarise(n_groups = n(), mean_abs_bias = mean(abs(bias)), max_abs_bias = max(abs(bias)),
            mean_coverage = mean(coverage), min_coverage = min(coverage),
            n_degenerate_ci = sum(n_degenerate), .groups = "drop")

# ---- ranking recovery (regions) --------------------------------------------------------------
true_rank <- truth %>% filter(axis == "region") %>%
  group_by(outcome) %>% mutate(true_rank = rank(-truth, ties.method = "min")) %>% ungroup()

rank_rec <- est %>%
  filter(axis == "region") %>%
  left_join(true_rank %>% select(outcome, group, true_rank), by = c("outcome", "group")) %>%
  group_by(scenario, mechanism, rate, method, outcome, rep) %>%
  summarise(spearman = cor(p, truth, method = "spearman"),
            topk_overlap = sum(rank(-p, ties.method = "min") <= TOP_K & true_rank <= TOP_K) / TOP_K,
            rank1_correct = group[which.max(p)] == group[true_rank == 1][1],
            .groups = "drop") %>%
  group_by(scenario, mechanism, rate, method, outcome) %>%
  summarise(n_sim = n(), mean_spearman = mean(spearman), mean_topk_overlap = mean(topk_overlap),
            p_topk_exact = mean(topk_overlap == 1), p_rank1_correct = mean(rank1_correct),
            .groups = "drop")

# ---- write -----------------------------------------------------------------------------------
sfx <- paste0("_", MODE)
write.csv(perf,     file.path(paths$tables, paste0("rq3_performance_national", sfx, ".csv")), row.names = FALSE)
write.csv(perf_sub, file.path(paths$tables, paste0("rq3_performance_subgroups", sfx, ".csv")), row.names = FALSE)
write.csv(rank_rec, file.path(paths$tables, paste0("rq3_ranking_recovery", sfx, ".csv")), row.names = FALSE)
write.csv(run_diag, file.path(paths$tables, paste0("rq3_run_diagnostics", sfx, ".csv")), row.names = FALSE)
if (nrow(errors)) write.csv(errors, file.path(paths$tables, paste0("rq3_errors", sfx, ".csv")), row.names = FALSE)

options(width = 220)
r <- function(x, d = 3) mutate(x, across(where(is.numeric), ~ round(.x, d)))
cat("replicate files:", length(files), " errors:", nrow(errors), "\n")
cat("\n== Run diagnostics ==\n"); print(r(run_diag), n = 100)
cat("\n== National performance (percentage points; coverage as proportion) ==\n")
print(perf %>% transmute(outcome, label, method, n_sim, bias_pp = 100 * bias, bias_mcse_pp = 100 * bias_mcse,
                         emp_se_pp = 100 * emp_se, mod_se_pp = 100 * mod_se, se_ratio, rmse_pp = 100 * rmse,
                         coverage, coverage_mcse, mean_fmi) %>% r(2), n = 200)
cat("\n== Region ranking recovery ==\n"); print(r(rank_rec, 2), n = 200)
