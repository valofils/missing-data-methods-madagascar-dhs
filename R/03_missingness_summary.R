# 03_missingness_summary.R — missingness by variable and outcome-status patterns

source(here::here("R", "00_setup.R"))
kids <- readRDS(file.path(paths$derived, "kids.rds"))

vars <- c("region", "residence", "wealth", "sex", "age_m", "mother_status", "mother_edu",
          "mother_age", "hh_size", "haz", "waz", "whz")

miss_by_var <- tibble(
  variable  = vars,
  n         = nrow(kids),
  n_missing = sapply(vars, function(v) sum(is.na(kids[[v]]))),
  pct_missing = round(100 * n_missing / n, 1)
)

status_tab <- kids %>%
  select(haz_status, waz_status, whz_status) %>%
  pivot_longer(everything(), names_to = "index", values_to = "status") %>%
  count(index, status) %>%
  group_by(index) %>% mutate(pct = round(100 * n / sum(n), 1)) %>% ungroup()

measure_tab <- kids %>% count(measure_result, haz_status)

write.csv(miss_by_var, file.path(paths$tables, "missingness_by_variable.csv"), row.names = FALSE)
write.csv(status_tab,  file.path(paths$tables, "zscore_status.csv"), row.names = FALSE)
write.csv(measure_tab, file.path(paths$tables, "measurement_result_by_haz_status.csv"), row.names = FALSE)

# Outcome missingness (not valid = missing or flagged) by covariate: survey-weighted %,
# with design-based Rao-Scott test of association (evidence against MCAR)
source(here::here("R", "04_design.R"))
kids <- kids %>% mutate(haz_miss = as.integer(is.na(haz)), whz_miss = as.integer(is.na(whz)))
des <- make_design(kids)
by_cov <- bind_rows(lapply(c("region", "residence", "wealth", "sex", "age_grp", "mother_status",
                             "mother_edu"), function(v) {
  bind_rows(lapply(c("haz_miss", "whz_miss"), function(o) {
    m <- svyby(as.formula(paste0("~", o)), as.formula(paste0("~", v)), des, svymean, na.rm = TRUE)
    p <- svychisq(as.formula(paste0("~", o, "+", v)), des)$p.value
    data.frame(covariate = v, level = as.character(m[[v]]), outcome = o,
               pct_missing = round(100 * m[[o]], 1), se = round(100 * m$se, 1),
               rao_scott_p = signif(unname(p), 3))
  }))
}))
write.csv(by_cov, file.path(paths$tables, "outcome_missingness_by_covariate.csv"), row.names = FALSE)

print(miss_by_var); print(status_tab); print(measure_tab)
print(by_cov %>% distinct(covariate, outcome, rao_scott_p))
