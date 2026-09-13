# fn_simulation.R — data-generating mechanism and single-replicate runner for RQ3
# Protocol: docs/simulation_protocol.md (approved 2026-09-13: low-tail MNAR, delta = log 2,
# rates 10/30/50%, R = 500, MI m = 10 / maxit = 10, MI-RF ntree = 10; ntree = 50 sub-study;
# strong-MAR mechanism added after the pilot).

SIM <- list(
  mechanisms = c("MCAR", "MAR", "MAR-strong", "MNAR"),
  rates      = c(0.10, 0.30, 0.50),
  kappa      = log(2),          # MAR-strong: odds x2 per 1 SD higher covariate-predicted risk
                                #   of stunting and of wasting (mirror image of MNAR)
  delta      = log(2),          # MNAR: odds of missingness x2 per 1 SD lower HAZ and WHZ
  m          = 10,
  maxit      = 10,
  ntree      = 10,
  spec       = list(stunted = c("region", "wealth"), wasted = c("region", "wealth"))
)

sim_scenarios <- function() {
  sc <- expand.grid(mechanism = SIM$mechanisms, rate = SIM$rates, stringsAsFactors = FALSE) %>%
    arrange(match(mechanism, SIM$mechanisms), rate) %>%
    mutate(ntree = SIM$ntree)
  # ntree sub-study: MAR 30% with ntree = 50 (MI-RF only)
  sc <- bind_rows(sc, data.frame(mechanism = "MAR", rate = 0.30, ntree = 50))
  sc %>% mutate(scenario = seq_len(n()),
                label = sprintf("%s %d%%%s", mechanism, round(100 * rate),
                                ifelse(ntree != SIM$ntree, sprintf(" (ntree=%d)", ntree), "")))
}

# ---- pseudo-population and truth ------------------------------------------------------------
build_sim_setup <- function(kids) {
  pop <- kids %>%
    filter(!is.na(haz), !is.na(whz), !is.na(mother_edu), !is.na(mother_age)) %>%
    mutate(mother_status = droplevels(mother_status)) %>%
    derive_outcomes()

  # collapse strata with < 3 PSUs into the other-residence stratum of the same region
  psu_n <- pop %>% distinct(stratum, psu, region, residence) %>% count(stratum, region, residence)
  small <- psu_n %>% filter(n < 3)
  collapse_map <- small %>%
    left_join(psu_n %>% select(region, partner_residence = residence, partner = stratum, partner_n = n),
              by = "region", relationship = "many-to-many") %>%
    filter(partner != stratum) %>%
    group_by(stratum) %>% slice_max(partner_n, n = 1, with_ties = FALSE) %>% ungroup()
  pop <- pop %>%
    left_join(collapse_map %>% select(stratum, partner), by = "stratum") %>%
    mutate(stratum_sim = ifelse(is.na(partner), stratum, partner)) %>% select(-partner)

  # MAR linear predictor: real missingness model on the full analysis sample
  kids$any_miss <- as.integer(is.na(kids$haz) | is.na(kids$whz))
  cal <- glm(any_miss ~ region + residence + wealth + sex + age_grp + mother_status + hh_size,
             family = binomial, data = kids)
  eta <- predict(cal, newdata = pop %>% mutate(mother_status = factor(as.character(mother_status),
                                                                      levels(kids$mother_status))))
  # MAR-strong linear predictor: covariate-predicted risk of stunting and of wasting in the
  # pseudo-population, using only covariates available to the IPW and MI models
  risk_formula <- ~ region + residence + wealth + sex + age_grp + mother_status + mother_edu + hh_size
  fit_st <- glm(update(risk_formula, stunted ~ .), family = binomial, data = pop)
  fit_wa <- glm(update(risk_formula, wasted ~ .), family = binomial, data = pop)
  std <- function(x) (x - mean(x)) / sd(x)

  pop <- pop %>% mutate(
    eta = eta - mean(eta),
    risk_st_std = std(predict(fit_st)),
    risk_wa_std = std(predict(fit_wa)),
    haz_std = std(haz),
    whz_std = std(whz)
  )

  truth <- estimate_set(make_design(pop), SIM$spec) %>%
    transmute(outcome, axis, group, truth = p)

  list(pop = pop, truth = truth, calibration = broom_coefs(cal),
       risk_models = list(stunted = broom_coefs(fit_st), wasted = broom_coefs(fit_wa)),
       collapse = collapse_map, n_pop = nrow(pop))
}

broom_coefs <- function(fit) data.frame(term = names(coef(fit)), estimate = unname(coef(fit)))

# ---- one replicate ---------------------------------------------------------------------------
rao_wu <- function(d) {
  psus <- d %>% distinct(stratum_sim, psu)
  draws <- psus %>% group_by(stratum_sim) %>%
    group_modify(function(s, key) {
      n <- nrow(s)
      tibble(psu = sample(s$psu, n - 1, replace = TRUE), mult = n / (n - 1))
    }) %>%
    ungroup() %>% mutate(psu_rep = row_number())
  draws %>%
    inner_join(d, by = c("stratum_sim", "psu"), relationship = "many-to-many") %>%
    mutate(wt = wt * mult, psu = psu_rep, stratum = stratum_sim) %>%
    select(-psu_rep, -mult)
}

impose_missing <- function(d, mechanism, rate, delta = SIM$delta, kappa = SIM$kappa) {
  lp <- switch(mechanism,
               MCAR         = rep(0, nrow(d)),
               MAR          = d$eta,
               `MAR-strong` = kappa * d$risk_st_std + kappa * d$risk_wa_std,
               MNAR         = d$eta - delta * d$haz_std - delta * d$whz_std)
  alpha <- uniroot(function(a) mean(plogis(a + lp)) - rate, c(-30, 30), tol = 1e-8)$root
  miss <- runif(nrow(d)) < plogis(alpha + lp)
  d$haz[miss] <- NA
  d$whz[miss] <- NA
  derive_outcomes(d)
}

safely <- function(expr, method) {
  t0 <- proc.time()[["elapsed"]]
  out <- tryCatch(expr, error = function(e) structure(list(), error = conditionMessage(e)))
  secs <- proc.time()[["elapsed"]] - t0
  if (!is.data.frame(out)) {
    return(data.frame(method = method, error = attr(out, "error"), seconds = secs))
  }
  out %>% mutate(method = method, error = NA_character_, seconds = secs)
}

run_replicate <- function(setup, sc, rep, seed_base = SEED) {
  task_seed <- seed_base + sc$scenario * 1e5 + rep
  set.seed(task_seed)
  b <- rao_wu(setup$pop)                                  # sample
  d <- impose_missing(b, sc$mechanism, sc$rate)           # missingness
  spec <- SIM$spec
  keep_cols <- c("outcome", "axis", "group", "p", "se_p", "lo", "hi", "df", "fmi")

  rf_only <- sc$ntree != SIM$ntree
  res <- list()
  if (!rf_only) {
    res$full <- safely(finish(estimate_set(make_design(derive_outcomes(b)), spec),
                              degf(make_design(b)), "Complete data")[, keep_cols], "Complete data")
    res$cca  <- safely(method_cca(d, spec)[, keep_cols], "CCA")
    res$ipw  <- safely(method_ipw(d, spec)[, keep_cols], "IPW")
    res$pmm  <- safely({
      imp <- run_mice(d, "pmm", m = SIM$m, maxit = SIM$maxit, seed = task_seed, n_workers = 1)
      method_mi(d, spec, imp, "MI-PMM")[, keep_cols]
    }, "MI-PMM")
  }
  res$rf <- safely({
    imp <- run_mice(d, "rf", m = SIM$m, maxit = SIM$maxit, seed = task_seed, n_workers = 1,
                    ntree = sc$ntree, rf_threads = 1)
    method_mi(d, spec, imp, "MI-RF")[, keep_cols]
  }, if (rf_only) sprintf("MI-RF (ntree=%d)", sc$ntree) else "MI-RF")

  bind_rows(res) %>%
    mutate(scenario = sc$scenario, mechanism = sc$mechanism, rate = sc$rate, ntree = sc$ntree,
           rep = rep, seed = task_seed, n = nrow(d), miss_rate = mean(is.na(d$haz)),
           miss_rate_w = sum(d$wt[is.na(d$haz)]) / sum(d$wt), .before = 1)
}
