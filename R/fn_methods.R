# fn_methods.R — missing-data estimators shared by 10_observed_methods.R and 20_simulation.R
#
# Every method returns one row per outcome x axis x group with the survey-weighted
# prevalence, its design-based SE, a 95% CI and the reference degrees of freedom.
#
# INFERENCE CONVENTIONS (all methods)
#   * Proportions are analysed on the logit scale: estimate q = logit(p), variance by the
#     delta method u = SE(p)^2 / (p(1-p))^2; CI = expit(q +/- t_df * sqrt(u)). This keeps
#     CIs inside [0, 1] for low-prevalence subgroups (e.g. regional wasting ~2-4%).
#   * t reference df: design df (PSUs - strata) for single analyses; Barnard-Rubin df with
#     complete-data df = design df for MI.
#   * Subgroup / respondent estimates use domain estimation (survey::subset keeps all PSUs
#     in the variance calculation).

suppressPackageStartupMessages(library(mice))

Z_OF <- c(stunted = "haz", sev_stunted = "haz", wasted = "whz", sev_wasted = "whz")

derive_outcomes <- function(d) {
  d %>% mutate(stunted = as.integer(haz < -2), sev_stunted = as.integer(haz < -3),
               wasted  = as.integer(whz < -2), sev_wasted  = as.integer(whz < -3))
}

# ---- estimation on one design --------------------------------------------------------------

svy_logit <- function(design, outcome, by = NULL) {
  f <- reformulate(outcome)
  if (is.null(by)) {
    m <- svymean(f, design)
    p <- unname(coef(m)); se <- unname(SE(m)); grp <- "National"; ax <- "National"
  } else {
    m <- svyby(f, reformulate(by), design, svymean)
    p <- m[[outcome]]; se <- m[["se"]]; grp <- as.character(m[[by]]); ax <- by
  }
  data.frame(outcome = outcome, axis = ax, group = grp, p = p,
             q = qlogis(p), u = (se / (p * (1 - p)))^2)
}

# spec: named list, outcome -> character vector of subgroup axes (character(0) = national only)
# keep: optional function(outcome) -> logical row filter (domain) applied before estimation
estimate_set <- function(design, spec, keep = NULL) {
  bind_rows(lapply(names(spec), function(o) {
    d <- if (is.null(keep)) design else subset(design, keep(o))
    bind_rows(svy_logit(d, o), lapply(spec[[o]], function(a) svy_logit(d, o, a)))
  }))
}

finish <- function(est, df, method) {
  est %>% mutate(
    method = method, df = df, fmi = NA_real_,
    se_p = sqrt(u) * p * (1 - p),
    lo = plogis(q - qt(0.975, df) * sqrt(u)),
    hi = plogis(q + qt(0.975, df) * sqrt(u))
  )
}

# Rubin's rules on the logit scale with Barnard-Rubin small-sample df
pool_rubin <- function(est_list, dfcom, method) {
  M <- length(est_list)
  bind_rows(est_list) %>%
    group_by(outcome, axis, group) %>%
    summarise(qbar = mean(q), ubar = mean(u), b = var(q), .groups = "drop") %>%
    mutate(
      t = ubar + (1 + 1 / M) * b,
      lambda = (1 + 1 / M) * b / t,
      nu_old = ifelse(lambda > 0, (M - 1) / lambda^2, Inf),
      nu_obs = (dfcom + 1) / (dfcom + 3) * dfcom * (1 - lambda),
      df = 1 / (1 / nu_old + 1 / nu_obs),
      r = (1 + 1 / M) * b / ubar,
      fmi = (r + 2 / (df + 3)) / (r + 1),
      p = plogis(qbar), q = qbar, u = t, method = method,
      se_p = sqrt(u) * p * (1 - p),
      lo = plogis(q - qt(0.975, df) * sqrt(u)),
      hi = plogis(q + qt(0.975, df) * sqrt(u))
    ) %>%
    select(outcome, axis, group, p, q, u, method, df, fmi, se_p, lo, hi)
}

# ---- 1. complete-case analysis -------------------------------------------------------------
# covariates = FALSE: records with an observed outcome (DHS published definition; validated)
# covariates = TRUE : additionally requires observed auxiliary covariates (mother_edu, mother_age)
method_cca <- function(dat, spec, covariates = FALSE) {
  des <- make_design(dat)
  keep <- function(o) {
    k <- !is.na(dat[[o]])
    if (covariates) k <- k & !is.na(dat$mother_edu) & !is.na(dat$mother_age)
    k
  }
  finish(estimate_set(des, spec, keep), degf(des),
         if (covariates) "CCA (outcome + covariates)" else "CCA")
}

# ---- 2. inverse probability weighting ------------------------------------------------------
# Response propensity per z-score (HAZ, WHZ): survey-weighted logistic regression of
# "z-score valid" on fully observed auxiliaries. Weight = design weight / fitted propensity.
# Estimated weights are treated as fixed in variance estimation (typically conservative).
IPW_FORMULA <- ~ region + residence + wealth + sex + age_grp + mother_status + mother_edu_ipw +
  hh_size

ipw_covariates <- function(dat) {
  # Complete covariate coding for the propensity model (no aliasing with mother_status):
  # "Not in household" rows take a constant education level (absorbed by mother_status);
  # the 6 "don't know" educations are set to the modal level.
  dat %>% mutate(mother_edu_ipw = factor(case_when(
    mother_edu %in% c("None", "Not in household") ~ "None",
    is.na(mother_edu) | mother_edu == "Primary" ~ "Primary",
    TRUE ~ "Secondary+"), levels = c("None", "Primary", "Secondary+")))
}

method_ipw <- function(dat, spec, formula = IPW_FORMULA) {
  dat <- ipw_covariates(dat)
  zs <- unique(Z_OF[names(spec)])
  res <- list(); diag <- list()
  for (z in zs) {
    dat$resp <- as.integer(!is.na(dat[[z]]))
    fit <- svyglm(update(formula, resp ~ .), design = make_design(dat), family = quasibinomial())
    ph <- as.numeric(fitted(fit))
    dat$w_ipw <- dat$wt / ph
    des <- make_design(dat, weights = ~w_ipw)
    sub_spec <- spec[names(spec) %in% names(Z_OF)[Z_OF == z]]
    res[[z]] <- finish(estimate_set(des, sub_spec, keep = function(o) dat$resp == 1),
                       degf(des), "IPW")
    r <- dat$resp == 1
    kish <- function(w) sum(w)^2 / sum(w^2)
    diag[[z]] <- data.frame(zscore = z, n_resp = sum(r), p_min = min(ph[r]), p_max = max(ph[r]),
                            adj_factor_max = max(1 / ph[r]),
                            ess_design = kish(dat$wt[r]), ess_ipw = kish(dat$w_ipw[r]))
  }
  structure(bind_rows(res), diagnostics = bind_rows(diag))
}

# ---- 3/4. multiple imputation (PMM or random forest) ---------------------------------------
# Custom univariate imputers that fit and impute only among children whose mother is in
# the household: structural "Not in household" values (mother_edu level / mother_age 0)
# are excluded from the imputation model's training rows and are never imputed.
# Parallel mice: m imputations split across PSOCK workers, one independent mice() call per
# worker with a worker-specific seed (seed + worker index), combined with ibind().
# Results are reproducible for a fixed (seed, m, n_workers).
N_WORKERS <- max(1L, min(4L, parallel::detectCores(logical = FALSE)))

mice_parallel <- function(args, m, seed, n_workers = N_WORKERS) {
  n_workers <- min(n_workers, m)
  if (n_workers == 1L) return(do.call(mice, c(args, list(m = m, seed = seed))))
  m_per <- as.integer(table(cut(seq_len(m), n_workers, labels = FALSE)))
  cl <- parallel::makePSOCKcluster(n_workers)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  parallel::clusterCall(cl, function(root) {
    source(file.path(root, "R", "00_setup.R")); source(file.path(root, "R", "04_design.R"))
    source(file.path(root, "R", "fn_methods.R")); NULL
  }, here::here())
  parts <- parallel::clusterApply(cl, seq_len(n_workers), function(k, args, m_per, seed) {
    do.call(mice, c(args, list(m = m_per[k], seed = seed + k)))
  }, args = args, m_per = m_per, seed = seed)
  Reduce(ibind, parts)
}

present_only <- function(base, is_structural, drop_levels) {
  function(y, ry, x, wy = NULL, ...) {
    if (is.null(wy)) wy <- !ry
    keep <- !(ry & is_structural(y))
    yy <- y[keep]
    if (drop_levels && is.factor(yy)) yy <- droplevels(yy)
    xx <- x[keep, , drop = FALSE]
    # predictors constant among the training rows (e.g. mother_status dummies that identify
    # structural or all-missing categories) carry no information and make X'X singular
    varying <- apply(xx[ry[keep], , drop = FALSE], 2, function(col) length(unique(col)) > 1)
    base(yy, ry[keep], xx[, varying, drop = FALSE], wy[keep], ...)
  }
}
edu_struct <- function(y) !is.na(y) & y == "Not in household"
age_struct <- function(y) !is.na(y) & y == 0
mice.impute.polyreg_present <- present_only(mice.impute.polyreg, edu_struct, TRUE)
mice.impute.pmm_present     <- present_only(mice.impute.pmm,     age_struct, FALSE)
mice.impute.rfedu_present   <- present_only(mice.impute.rf,      edu_struct, FALSE)
mice.impute.rfage_present   <- present_only(mice.impute.rf,      age_struct, FALSE)

# Imputation model: the two outcome z-scores (HAZ, WHZ; binary outcomes derived afterwards),
# genuinely missing auxiliaries, and complete predictors. Design information enters as
# predictors: region x residence (the sampling strata) and log design weight.
# WAZ is deliberately EXCLUDED: it is almost a deterministic function of HAZ and WHZ and is
# missing jointly with them for absent children; including it made PMM chains non-mixing
# with upward-drifting variance (diagnostic runs 2026-09-13, outputs/figures/diagnostics/).
run_mice <- function(dat, engine = c("pmm", "rf"), m = 20, maxit = 20, seed = SEED,
                     ntree = 100, n_workers = N_WORKERS, rf_threads = NULL) {
  engine <- match.arg(engine)
  idat <- dat %>% transmute(haz, whz, mother_edu, mother_age,
                            region, residence, wealth, sex, age_m, age_grp, hh_size,
                            mother_status, log_wt = log(wt))
  meth <- make.method(idat)
  if (engine == "pmm") {
    meth[c("haz", "whz")] <- "pmm"
    meth["mother_edu"] <- "polyreg_present"; meth["mother_age"] <- "pmm_present"
  } else {
    meth[c("haz", "whz")] <- "rf"
    meth["mother_edu"] <- "rfedu_present"; meth["mother_age"] <- "rfage_present"
  }
  meth[colSums(is.na(idat)) == 0] <- ""
  args <- list(data = idat, maxit = maxit, method = meth, printFlag = FALSE)
  if (engine == "rf") args <- c(args, list(ntree = ntree, rfPackage = "ranger"))
  if (engine == "rf" && !is.null(rf_threads)) args <- c(args, list(num.threads = rf_threads))
  mice_parallel(args, m = m, seed = seed, n_workers = n_workers)
}

IMPUTED_VARS <- c("haz", "whz", "mother_edu", "mother_age")

method_mi <- function(dat, spec, imp, label) {
  dfcom <- degf(make_design(dat))
  ests <- lapply(seq_len(imp$m), function(i) {
    ci <- complete(imp, i)
    d <- dat
    d[, IMPUTED_VARS] <- ci[, IMPUTED_VARS]
    estimate_set(make_design(derive_outcomes(d)), spec)
  })
  pool_rubin(ests, dfcom, label)
}
