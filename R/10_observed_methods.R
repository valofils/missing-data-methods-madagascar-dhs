# 10_observed_methods.R — RQ1: prevalence by missing-data method on the observed data
#
# MAIN ANALYSIS
#   Target population: all de facto children 0-59 months (n = 6,682). An outcome is missing
#   when there is no valid z-score: not measured (NA) or WHO-flagged (9996-9998). Flagged
#   values are a distinct, plausibly MNAR missingness type (the child belongs to the target
#   population but the measurement is implausible); MI and IPW treat them as missing.
#   CCA follows the DHS definition (validated in 05_validation.R).
# SENSITIVITY ANALYSIS
#   Flagged children excluded from the target population (DHS/WHO convention), separately
#   per index: stunting outcomes exclude flagged-HAZ children, wasting outcomes exclude
#   flagged-WHZ children. CCA point estimates are therefore identical in both analyses.
#
# Methods: CCA; CCA additionally requiring observed covariates; IPW; MI-PMM; MI-RF
#   (mice, m = 20, 20 iterations, run in parallel; RF = ranger, 100 trees).

source(here::here("R", "00_setup.R"))
source(here::here("R", "04_design.R"))
source(here::here("R", "fn_methods.R"))

kids <- readRDS(file.path(paths$derived, "kids.rds"))
dir.create(file.path(paths$figures, "diagnostics"), showWarnings = FALSE)

M_IMP <- 20
MAXIT <- 20
METHOD_LEVELS <- c("CCA", "CCA (outcome + covariates)", "IPW", "MI-PMM", "MI-RF")

spec_st <- list(stunted = c("region", "wealth"), sev_stunted = character(0))
spec_wa <- list(wasted = c("region", "wealth"), sev_wasted = character(0))

analyses <- list(
  main           = list(label = "Main (flagged = missing)", data = kids, spec = c(spec_st, spec_wa)),
  sens_stunting  = list(label = "Sensitivity (flagged excluded)",
                        data = filter(kids, haz_status != "flagged"), spec = spec_st),
  sens_wasting   = list(label = "Sensitivity (flagged excluded)",
                        data = filter(kids, whz_status != "flagged"), spec = spec_wa)
)

run_analysis <- function(a, key) {
  dat <- a$data; spec <- a$spec
  message("\n-- ", key, ": n = ", nrow(dat))
  res_cca  <- method_cca(dat, spec)
  res_ccac <- method_cca(dat, spec, covariates = TRUE)
  res_ipw  <- method_ipw(dat, spec)

  t0 <- Sys.time()
  imp_pmm <- run_mice(dat, "pmm", m = M_IMP, maxit = MAXIT, seed = SEED)
  message("   MI-PMM: ", format(Sys.time() - t0, digits = 3))
  t0 <- Sys.time()
  imp_rf <- run_mice(dat, "rf", m = M_IMP, maxit = MAXIT, seed = SEED)
  message("   MI-RF:  ", format(Sys.time() - t0, digits = 3))
  saveRDS(list(pmm = imp_pmm, rf = imp_rf), file.path(paths$derived, paste0("mice_", key, ".rds")))

  for (nm in c("pmm", "rf")) {
    png(file.path(paths$figures, "diagnostics", sprintf("trace_%s_%s.png", key, nm)),
        width = 1000, height = 700)
    print(plot(list(pmm = imp_pmm, rf = imp_rf)[[nm]], c("haz", "whz", "mother_age"),
               layout = c(2, 3)))
    dev.off()
  }

  counts <- bind_rows(lapply(names(spec), function(o) {
    bind_rows(
      data.frame(outcome = o, axis = "National", group = "National",
                 n_total = nrow(dat), n_observed = sum(!is.na(dat[[o]]))),
      lapply(spec[[o]], function(ax) dat %>% group_by(group = as.character(.data[[ax]])) %>%
               summarise(n_total = n(), n_observed = sum(!is.na(.data[[o]])), .groups = "drop") %>%
               mutate(outcome = o, axis = ax))
    )
  }))

  results <- bind_rows(res_cca, res_ccac, res_ipw,
                       method_mi(dat, spec, imp_pmm, "MI-PMM"),
                       method_mi(dat, spec, imp_rf, "MI-RF")) %>%
    left_join(counts, by = c("outcome", "axis", "group")) %>%
    transmute(analysis = a$label, method = factor(method, METHOD_LEVELS), outcome, axis, group,
              n_total, n_observed, pct = 100 * p, se = 100 * se_p, lo = 100 * lo, hi = 100 * hi,
              df, fmi)

  # imputed z-scores by missingness type
  imp_summary <- bind_rows(lapply(list(`MI-PMM` = imp_pmm, `MI-RF` = imp_rf), function(imp) {
    bind_rows(lapply(intersect(c("haz", "whz"), unique(Z_OF[names(spec)])), function(z) {
      st <- dat[[paste0(z, "_status")]][is.na(dat[[z]])]
      bind_rows(lapply(split(seq_along(st), st), function(i) {
        v <- unlist(imp$imp[[z]][i, ])
        data.frame(zscore = z, n_children = length(i), imputed_mean = mean(v),
                   pct_below_m2 = 100 * mean(v < -2), pct_below_m3 = 100 * mean(v < -3))
      }), .id = "missing_type") %>%
        bind_rows(data.frame(missing_type = "observed", zscore = z,
                             n_children = sum(!is.na(dat[[z]])),
                             imputed_mean = mean(dat[[z]], na.rm = TRUE),
                             pct_below_m2 = 100 * mean(dat[[z]] < -2, na.rm = TRUE),
                             pct_below_m3 = 100 * mean(dat[[z]] < -3, na.rm = TRUE)))
    }))
  }), .id = "method") %>% mutate(analysis = a$label, .before = 1)

  list(results = results,
       ipw = attr(res_ipw, "diagnostics") %>% mutate(analysis = a$label, .before = 1),
       imp = imp_summary)
}

out <- Map(run_analysis, analyses, names(analyses))

results <- bind_rows(lapply(out, `[[`, "results")) %>%
  arrange(outcome, analysis, axis, group, method)
ipw_diag    <- bind_rows(lapply(out, `[[`, "ipw"))
imp_summary <- bind_rows(lapply(out, `[[`, "imp"))

# ---- CCA reproduces the validated baseline (main analysis) ---------------------------------
val <- read.csv(file.path(paths$validate, "cca_all_groups.csv"))
chk <- results %>%
  filter(method == "CCA", outcome %in% c("stunted", "wasted")) %>%
  mutate(axis = recode(axis, region = "Region", wealth = "Wealth")) %>%
  inner_join(val %>% select(axis, group, outcome, pct_val = pct), by = c("axis", "group", "outcome"))
stopifnot(nrow(chk) == 2 * 2 * (1 + 23 + 5), max(abs(chk$pct - chk$pct_val)) < 1e-8)

# ---- differences from CCA within each analysis --------------------------------------------
vs_cca <- results %>%
  left_join(results %>% filter(method == "CCA") %>%
              select(analysis, outcome, axis, group, pct_cca = pct),
            by = c("analysis", "outcome", "axis", "group")) %>%
  mutate(diff_pp = pct - pct_cca)

diff_summary <- vs_cca %>% filter(method != "CCA") %>%
  group_by(analysis, method, outcome,
           level = ifelse(axis == "National", "National", "Subgroups")) %>%
  summarise(n_groups = n(), mean_abs_diff_pp = mean(abs(diff_pp)),
            max_abs_diff_pp = max(abs(diff_pp)), .groups = "drop")

# ---- write ---------------------------------------------------------------------------------
write.csv(results,      file.path(paths$tables, "rq1_prevalence_by_method.csv"), row.names = FALSE)
write.csv(vs_cca,       file.path(paths$tables, "rq1_difference_vs_cca.csv"), row.names = FALSE)
write.csv(diff_summary, file.path(paths$tables, "rq1_difference_summary.csv"), row.names = FALSE)
write.csv(ipw_diag,     file.path(paths$tables, "rq1_ipw_diagnostics.csv"), row.names = FALSE)
write.csv(imp_summary,  file.path(paths$tables, "rq1_imputation_summary.csv"), row.names = FALSE)
unlink(file.path(paths$derived, c("mice_observed.rds", "conv_test_pmm_nowaz.rds")))

options(width = 180)
r2 <- function(x) mutate(x, across(where(is.numeric), ~ round(.x, 2)))
cat("\n== National estimates ==\n")
print(results %>% filter(axis == "National") %>% select(-axis, -group) %>% r2())
cat("\n== Difference from CCA (pp) ==\n"); print(r2(diff_summary), n = 100)
cat("\n== IPW diagnostics ==\n"); print(r2(ipw_diag))
cat("\n== Imputed z-scores by missingness type ==\n"); print(r2(imp_summary))
