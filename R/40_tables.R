# 40_tables.R — manuscript tables (Word .docx, HTML and CSV)
#
# Usage: Rscript R/40_tables.R [full|pilot]   (simulation tables use that run; default full)
#   Table 1   Sample description and missingness (observed data)
#   Table 2   Stunting and wasting prevalence by method: national, region, wealth (RQ1, main)
#   Table S2  As Table 2, sensitivity analysis (flagged z-scores excluded)
#   Table 3   Simulation: bias, RMSE and 95% CI coverage by mechanism x rate x method (RQ3)
#   Table S3  Simulation: full performance measures with Monte Carlo SEs
#   Table S4  Simulation: regional ranking recovery
#   Table S5  Simulation: MI-RF ntree sub-study
# Every number is read from pipeline outputs; nothing is typed in by hand.

source(here::here("R", "00_setup.R"))
source(here::here("R", "04_design.R"))
suppressPackageStartupMessages(library(gt))

args <- commandArgs(trailingOnly = TRUE)
SIM_MODE <- if (length(args) && args[1] %in% c("pilot", "full")) args[1] else "full"

# gt's Word export needs pandoc; fall back to the copy bundled with RStudio if not on PATH
if (!rmarkdown::pandoc_available()) {
  rs <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools"
  if (dir.exists(rs)) Sys.setenv(RSTUDIO_PANDOC = rs)
}
CAN_DOCX <- rmarkdown::pandoc_available()

METHOD_LEVELS <- c("CCA", "CCA (outcome + covariates)", "IPW", "MI-PMM", "MI-RF")
SIM_METHODS   <- c("Complete data", "CCA", "IPW", "MI-PMM", "MI-RF")
MECH_LEVELS   <- c("MCAR", "MAR", "MAR-strong", "MNAR")
OUTCOME_LAB   <- c(stunted = "Stunting", wasted = "Wasting")

# round before formatting (+ 0 turns -0 into 0, so no "-0.00")
f1 <- function(x) formatC(round(x, 1) + 0, format = "f", digits = 1)
f2 <- function(x) formatC(round(x, 2) + 0, format = "f", digits = 2)
fmt_ci <- function(p, lo, hi) sprintf("%s (%s–%s)", f1(p), f1(lo), f1(hi))

save_table <- function(g, data, name) {
  out <- function(ext) file.path(paths$tables, paste0(name, ext))
  # gtsave -> pandoc fails ("Unknown output format doc") when the target .docx already
  # exists, so remove previous outputs before writing
  unlink(c(out(".csv"), out(".html"), out(".docx"), out(".tex")))
  write.csv(data, out(".csv"), row.names = FALSE)
  gtsave(g, out(".html"))
  if (CAN_DOCX) gtsave(g, out(".docx"))
  # LaTeX fragment for the manuscript build (R/51_manuscript_latex.R inputs these).
  # Long tables must break across pages, with the header repeated.
  g_tex <- g %>% tab_options(latex.use_longtable = TRUE, latex.header_repeat = TRUE)
  writeLines(as.character(as_latex(g_tex)), out(".tex"), useBytes = TRUE)
  message("40: wrote ", name)
}

style_gt <- function(g) {
  g %>%
    tab_options(table.font.size = px(11), data_row.padding = px(2),
                row_group.font.weight = "bold", heading.align = "left",
                footnotes.font.size = px(10), source_notes.font.size = px(10)) %>%
    opt_table_font(font = list(default_fonts()))
}

# =============================================================================================
# Table 1 — sample description and missingness
# =============================================================================================
kids <- readRDS(file.path(paths$derived, "kids.rds"))

desc_rows <- function(var, label) {
  kids %>%
    mutate(level = as.character(.data[[var]])) %>%
    group_by(level) %>%
    summarise(n = n(), w = sum(wt),
              haz_nv = sum(wt[is.na(haz)]) / sum(wt), whz_nv = sum(wt[is.na(whz)]) / sum(wt),
              .groups = "drop") %>%
    mutate(pct = 100 * w / sum(w), characteristic = label,
           level = factor(level, levels(kids[[var]]))) %>%
    arrange(level) %>%
    transmute(characteristic, level = as.character(level), n, pct = f1(pct),
              haz_not_valid = f1(100 * haz_nv), whz_not_valid = f1(100 * whz_nv))
}

t1a <- bind_rows(
  kids %>% summarise(characteristic = "All children", level = "", n = n(), pct = "100.0",
                     haz_not_valid = f1(100 * sum(wt[is.na(haz)]) / sum(wt)),
                     whz_not_valid = f1(100 * sum(wt[is.na(whz)]) / sum(wt))),
  desc_rows("sex", "Sex"), desc_rows("age_grp", "Age (months)"),
  desc_rows("residence", "Residence"), desc_rows("region", "Region"),
  desc_rows("wealth", "Wealth quintile"), desc_rows("mother_status", "Mother's interview status"),
  desc_rows("mother_edu", "Mother's education")
)

g1 <- t1a %>%
  gt(groupname_col = "characteristic", rowname_col = "level") %>%
  cols_label(n = "n", pct = "Weighted %", haz_not_valid = "HAZ", whz_not_valid = "WHZ") %>%
  tab_spanner("No valid z-score, weighted %", c(haz_not_valid, whz_not_valid)) %>%
  sub_missing(missing_text = "—") %>%
  tab_header(title = "Table 1. Characteristics of de facto children aged 0–59 months and outcome missingness, Madagascar DHS 2021") %>%
  tab_source_note(sprintf(paste0(
    "n unweighted; percentages weighted by the DHS sample weight. No valid z-score = not measured or WHO-flagged. ",
    "HAZ: %d not measured/missing, %d flagged. WHZ: %d not measured/missing, %d flagged. ",
    "Mother's age unknown (mother in household, not linked): %d. Mother's education 'don't know': %d."),
    sum(kids$haz_status == "missing"), sum(kids$haz_status == "flagged"),
    sum(kids$whz_status == "missing"), sum(kids$whz_status == "flagged"),
    sum(is.na(kids$mother_age)), sum(is.na(kids$mother_edu)))) %>%
  style_gt()
save_table(g1, t1a, "table1_sample_missingness")

# =============================================================================================
# Table 2 / S2 — prevalence by method (RQ1)
# =============================================================================================
rq1   <- read.csv(file.path(paths$tables, "rq1_prevalence_by_method.csv"), stringsAsFactors = FALSE)
flags <- read.csv(file.path(paths$tables, "rq2_worst_affected_flags.csv"), stringsAsFactors = FALSE)
region_order <- levels(kids$region); wealth_order <- levels(kids$wealth)

prevalence_table <- function(an, title, name) {
  d <- rq1 %>%
    filter(analysis == an, outcome %in% names(OUTCOME_LAB)) %>%
    left_join(flags %>% filter(analysis == an) %>% select(outcome, axis, group, top_k_status),
              by = c("outcome", "axis", "group")) %>%
    mutate(cell = fmt_ci(pct, lo, hi),
           method = factor(method, METHOD_LEVELS),
           axis_lab = recode(axis, National = "National", region = "Region", wealth = "Wealth quintile"),
           group_lab = ifelse(!is.na(top_k_status) & top_k_status == "METHOD-DEPENDENT",
                              paste0(group, " †"), group),
           ord = case_when(axis == "National" ~ 0,
                           axis == "region" ~ 100 + match(group, region_order),
                           axis == "wealth" ~ 200 + match(group, wealth_order)))
  wide <- d %>%
    select(outcome, axis_lab, group_lab, ord, n_total, n_observed, method, cell) %>%
    tidyr::pivot_wider(names_from = method, values_from = cell) %>%
    mutate(row_group = paste(OUTCOME_LAB[outcome], "—", axis_lab),
           n = sprintf("%d / %d", n_observed, n_total)) %>%
    arrange(match(outcome, names(OUTCOME_LAB)), ord) %>%
    select(row_group, group_lab, n, all_of(METHOD_LEVELS))

  g <- wide %>%
    gt(groupname_col = "row_group", rowname_col = "group_lab") %>%
    cols_label(n = "n valid / n") %>%
    tab_spanner("Prevalence, % (95% CI)", all_of(METHOD_LEVELS)) %>%
    tab_header(title = title) %>%
    tab_source_note(paste0(
      "CCA, complete-case analysis (DHS definition); CCA (outcome + covariates), additionally requires observed ",
      "mother's age and education; IPW, inverse probability weighting; MI-PMM, multiple imputation by predictive ",
      "mean matching; MI-RF, random-forest multiple imputation (m = 20). All estimates survey-weighted; CIs on the ",
      "logit scale. † Top-5 worst-affected status differs between methods.")) %>%
    style_gt()
  save_table(g, wide, name)
}

prevalence_table("Main (flagged = missing)",
                 "Table 2. Prevalence of stunting and wasting by missing-data method, Madagascar DHS 2021",
                 "table2_prevalence_by_method")
prevalence_table("Sensitivity (flagged excluded)",
                 "Table S2. Prevalence by missing-data method, sensitivity analysis excluding WHO-flagged z-scores",
                 "tableS2_prevalence_sensitivity")

# =============================================================================================
# Table 3 / S3 / S4 / S5 — simulation (RQ3)
# =============================================================================================
perf_file <- file.path(paths$tables, sprintf("rq3_performance_national_%s.csv", SIM_MODE))
if (!file.exists(perf_file)) {
  message("40: ", basename(perf_file), " not found — simulation tables skipped (run 21_simulation_summary.R ",
          SIM_MODE, " first)")
} else {
  perf <- read.csv(perf_file, stringsAsFactors = FALSE)
  rankr <- read.csv(file.path(paths$tables, sprintf("rq3_ranking_recovery_%s.csv", SIM_MODE)),
                    stringsAsFactors = FALSE)
  truth <- read.csv(file.path(paths$tables, "rq3_truth.csv"), stringsAsFactors = FALSE)
  pilot_note <- if (SIM_MODE == "pilot") " PILOT RUN — NOT FOR PUBLICATION." else ""
  n_sim_range <- range(perf$n_sim[perf$method %in% SIM_METHODS])
  th <- truth %>% filter(axis == "National")

  main <- perf %>%
    filter(method %in% SIM_METHODS) %>%
    mutate(mechanism = factor(mechanism, MECH_LEVELS), method = factor(method, SIM_METHODS))

  # Table 3
  t3 <- main %>%
    transmute(mechanism, rate = sprintf("%d%%", round(100 * rate)), method, outcome,
              bias = f2(100 * bias), rmse = f2(100 * rmse), coverage = f1(100 * coverage)) %>%
    tidyr::pivot_wider(names_from = outcome, values_from = c(bias, rmse, coverage)) %>%
    arrange(mechanism, rate, method) %>%
    mutate(row_group = paste0(mechanism, ", ", rate, " missing")) %>%
    select(row_group, method, bias_stunted, rmse_stunted, coverage_stunted,
           bias_wasted, rmse_wasted, coverage_wasted)

  mc <- main %>% filter(method != "Complete data") %>%
    summarise(bias = max(bias_mcse), cov = max(coverage_mcse))

  g3 <- t3 %>%
    gt(groupname_col = "row_group", rowname_col = "method") %>%
    cols_label(bias_stunted = "Bias (pp)", rmse_stunted = "RMSE (pp)", coverage_stunted = "Coverage (%)",
               bias_wasted = "Bias (pp)", rmse_wasted = "RMSE (pp)", coverage_wasted = "Coverage (%)") %>%
    tab_spanner(sprintf("Stunting (true %s%%)", f2(100 * th$truth[th$outcome == "stunted"])),
                ends_with("_stunted")) %>%
    tab_spanner(sprintf("Wasting (true %s%%)", f2(100 * th$truth[th$outcome == "wasted"])),
                ends_with("_wasted")) %>%
    tab_header(title = "Table 3. Simulation study: bias, RMSE and 95% CI coverage of national prevalence estimates") %>%
    tab_source_note(sprintf(paste0(
      "%s replicates per scenario (Rao–Wu PSU bootstrap of a pseudo-population of %s children, then imposed missingness). ",
      "pp, percentage points. Complete data: estimate before deletion (benchmark). Maximum Monte Carlo SE across ",
      "missing-data methods: bias %s pp, coverage %s percentage points. MI m = 10.%s"),
      if (n_sim_range[1] == n_sim_range[2]) n_sim_range[1] else paste(n_sim_range, collapse = "–"),
      format(readRDS(file.path(paths$derived, "sim_setup.rds"))$n_pop, big.mark = ","),
      f2(100 * mc$bias), f1(100 * mc$cov), pilot_note)) %>%
    style_gt()
  save_table(g3, t3, paste0("table3_simulation", if (SIM_MODE == "pilot") "_PILOT"))

  # Table S3 — full measures with MCSE
  s3 <- perf %>%
    mutate(mechanism = factor(mechanism, MECH_LEVELS), method = factor(method, c(SIM_METHODS, "MI-RF (ntree=50)"))) %>%
    arrange(outcome, mechanism, rate, method) %>%
    transmute(outcome = OUTCOME_LAB[outcome], scenario = label, method, n_sim,
              bias = sprintf("%s (%s)", f2(100 * bias), f2(100 * bias_mcse)),
              rel_bias_pct = f1(100 * rel_bias),
              emp_se = sprintf("%s (%s)", f2(100 * emp_se), f2(100 * emp_se_mcse)),
              mod_se = sprintf("%s (%s)", f2(100 * mod_se), f2(100 * mod_se_mcse)),
              se_ratio = f2(se_ratio),
              rmse = sprintf("%s (%s)", f2(100 * rmse), f2(100 * rmse_mcse)),
              coverage = sprintf("%s (%s)", f1(100 * coverage), f1(100 * coverage_mcse)),
              ci_width = f2(100 * ci_width),
              fmi = ifelse(is.na(mean_fmi), "—", f2(mean_fmi)))
  gs3 <- s3 %>%
    mutate(row_group = paste(outcome, "—", scenario)) %>% select(-outcome, -scenario) %>%
    gt(groupname_col = "row_group", rowname_col = "method") %>%
    cols_label(n_sim = "R", bias = "Bias (MCSE)", rel_bias_pct = "Rel. bias (%)",
               emp_se = "Empirical SE (MCSE)", mod_se = "Model SE (MCSE)", se_ratio = "SE ratio",
               rmse = "RMSE (MCSE)", coverage = "Coverage % (MCSE)", ci_width = "CI width", fmi = "FMI") %>%
    tab_header(title = paste0("Table S3. Simulation study: full performance measures (percentage points unless stated)",
                              pilot_note)) %>%
    style_gt()
  save_table(gs3, s3, paste0("tableS3_simulation_full", if (SIM_MODE == "pilot") "_PILOT"))

  # Table S4 — ranking recovery
  s4 <- rankr %>%
    filter(method %in% SIM_METHODS) %>%
    mutate(mechanism = factor(mechanism, MECH_LEVELS), method = factor(method, SIM_METHODS)) %>%
    arrange(outcome, mechanism, rate, method) %>%
    transmute(row_group = sprintf("%s — %s %d%%", OUTCOME_LAB[outcome], mechanism, round(100 * rate)),
              method, spearman = f2(mean_spearman), topk = f2(mean_topk_overlap),
              topk_exact = f1(100 * p_topk_exact), rank1 = f1(100 * p_rank1_correct))
  gs4 <- s4 %>%
    gt(groupname_col = "row_group", rowname_col = "method") %>%
    cols_label(spearman = "Mean Spearman ρ", topk = "Mean top-5 overlap",
               topk_exact = "Top-5 exactly recovered (%)", rank1 = "Worst region correct (%)") %>%
    tab_header(title = paste0("Table S4. Simulation study: recovery of the true regional ranking (23 regions)",
                              pilot_note)) %>%
    style_gt()
  save_table(gs4, s4, paste0("tableS4_simulation_ranking", if (SIM_MODE == "pilot") "_PILOT"))

  # Table S5 — ntree sub-study (MI-RF ntree 10 vs 50, MAR 30%)
  s5 <- perf %>%
    filter(mechanism == "MAR", abs(rate - 0.3) < 1e-9, method %in% c("MI-RF", "MI-RF (ntree=50)")) %>%
    transmute(outcome = OUTCOME_LAB[outcome], method, n_sim,
              bias = sprintf("%s (%s)", f2(100 * bias), f2(100 * bias_mcse)),
              emp_se = f2(100 * emp_se), mod_se = f2(100 * mod_se), se_ratio = f2(se_ratio),
              coverage = sprintf("%s (%s)", f1(100 * coverage), f1(100 * coverage_mcse)))
  if (nrow(s5)) {
    gs5 <- s5 %>% gt(groupname_col = "outcome", rowname_col = "method") %>%
      cols_label(n_sim = "R", bias = "Bias, pp (MCSE)", emp_se = "Empirical SE", mod_se = "Model SE",
                 se_ratio = "SE ratio", coverage = "Coverage % (MCSE)") %>%
      tab_header(title = paste0("Table S5. MI-RF with 10 versus 50 trees (MAR, 30% missing)", pilot_note)) %>%
      style_gt()
    save_table(gs5, s5, paste0("tableS5_ntree_substudy", if (SIM_MODE == "pilot") "_PILOT"))
  }
}
