# 30_equity_ranking.R — RQ2: does the missing-data method change the equity ordering?
#
# Input: outputs/tables/rq1_prevalence_by_method.csv (from 10_observed_methods.R).
# For each analysis x outcome (stunting, wasting) x axis (23 regions, 5 wealth quintiles):
#   1. Rank subgroups by point prevalence within each method (1 = highest prevalence).
#   2. Pairwise cross-method agreement: Spearman rho, Kendall tau-b, largest rank shift,
#      overlap of the "worst-affected" set (top 5 regions; top 1 wealth quintile).
#   3. Flag subgroups whose worst-affected status is method-dependent.
#   4. Rank uncertainty from sampling error: Monte Carlo draws from each estimate's
#      approximate sampling distribution (logit scale, t with the method's df), giving
#      P(worst-affected), P(rank 1) and 95% rank intervals. Draws are independent across
#      subgroups: exact for regions (sampling strata are nested within regions), an
#      approximation for wealth quintiles (which cut across strata and clusters).
#   5. Sampling-noise floor: agreement between CCA point ranks and ranks re-drawn from CCA's
#      own sampling distribution, the benchmark against which method-induced reordering is
#      judged.

source(here::here("R", "00_setup.R"))

N_DRAWS <- 10000
TOP_K   <- c(region = 5, wealth = 1)
METHOD_LEVELS <- c("CCA", "CCA (outcome + covariates)", "IPW", "MI-PMM", "MI-RF")

res <- read.csv(file.path(paths$tables, "rq1_prevalence_by_method.csv"), stringsAsFactors = FALSE) %>%
  filter(axis %in% names(TOP_K), outcome %in% c("stunted", "wasted")) %>%
  mutate(method = factor(method, METHOD_LEVELS), k = TOP_K[axis])

# ---- 1. point ranks ------------------------------------------------------------------------
ranks <- res %>%
  group_by(analysis, outcome, axis, method) %>%
  mutate(rank = rank(-pct, ties.method = "min"), n_groups = n()) %>%
  ungroup()

# ---- 4. rank uncertainty (Monte Carlo) -----------------------------------------------------
draw_ranks <- function(d, n = N_DRAWS) {
  p <- d$pct / 100
  q <- qlogis(p)
  se_q <- (d$se / 100) / (p * (1 - p))
  z <- matrix(rt(n * nrow(d), df = rep(d$df, each = n)), nrow = nrow(d), byrow = TRUE)
  sims <- q + se_q * z                                   # groups x draws
  apply(-sims, 2, rank, ties.method = "min")             # groups x draws of ranks
}

set.seed(SEED)
mc <- ranks %>%
  group_by(analysis, outcome, axis, method) %>%
  group_modify(function(d, key) {
    r <- draw_ranks(d)
    k <- d$k[1]
    point <- rank(-d$pct, ties.method = "min")
    tibble(
      group = d$group,
      p_top_k = rowMeans(r <= k),
      p_rank1 = rowMeans(r == 1),
      rank_lo95 = apply(r, 1, quantile, 0.025, type = 1),
      rank_hi95 = apply(r, 1, quantile, 0.975, type = 1),
      # sampling-noise floor, stored once per set (same value on every row)
      noise_spearman_median = median(apply(r, 2, cor, y = point, method = "spearman")),
      noise_topk_overlap_median = median(apply(r, 2, function(x) sum(x <= k & point <= k) / k))
    )
  }) %>%
  ungroup()

ranks <- ranks %>% left_join(mc %>% select(-starts_with("noise")),
                             by = c("analysis", "outcome", "axis", "method", "group"))

noise_floor <- mc %>%
  distinct(analysis, outcome, axis, method, noise_spearman_median, noise_topk_overlap_median)

# ---- 2. pairwise agreement -----------------------------------------------------------------
agreement <- ranks %>%
  group_by(analysis, outcome, axis) %>%
  group_modify(function(d, key) {
    wide <- d %>% select(group, method, pct) %>%
      tidyr::pivot_wider(names_from = method, values_from = pct)
    k <- d$k[1]
    ms <- intersect(METHOD_LEVELS, names(wide))
    bind_rows(combn(ms, 2, simplify = FALSE, FUN = function(ab) {
      a <- wide[[ab[1]]]; b <- wide[[ab[2]]]
      ra <- rank(-a, ties.method = "min"); rb <- rank(-b, ties.method = "min")
      tibble(method_a = ab[1], method_b = ab[2],
             spearman = cor(a, b, method = "spearman"),
             kendall = cor(a, b, method = "kendall"),
             max_rank_shift = max(abs(ra - rb)),
             n_groups_rank_changed = sum(ra != rb),
             topk_overlap = sum(ra <= k & rb <= k) / k,
             same_rank1 = wide$group[which(ra == 1)][1] == wide$group[which(rb == 1)][1])
    }))
  }) %>%
  ungroup()

# ---- 3. method-dependent worst-affected status ---------------------------------------------
flags <- ranks %>%
  group_by(analysis, outcome, axis, group) %>%
  summarise(
    k = first(k),
    pct_cca = pct[method == "CCA"],
    rank_cca = rank[method == "CCA"],
    rank_min = min(rank), rank_max = max(rank),
    n_methods = n(),
    n_methods_top_k = sum(rank <= k),
    n_methods_rank1 = sum(rank == 1),
    methods_top_k = paste(method[rank <= k], collapse = "; "),
    p_top_k_cca = p_top_k[method == "CCA"],
    rank95_cca = sprintf("%d-%d", rank_lo95[method == "CCA"], rank_hi95[method == "CCA"]),
    .groups = "drop"
  ) %>%
  mutate(top_k_status = case_when(
    n_methods_top_k == n_methods ~ "Worst-affected under all methods",
    n_methods_top_k == 0         ~ "Not worst-affected",
    TRUE                         ~ "METHOD-DEPENDENT"
  )) %>%
  arrange(analysis, outcome, axis, rank_cca)

# ---- summaries -----------------------------------------------------------------------------
agree_summary <- agreement %>%
  group_by(analysis, outcome, axis) %>%
  summarise(min_spearman = min(spearman), min_kendall = min(kendall),
            max_rank_shift = max(max_rank_shift), min_topk_overlap = min(topk_overlap),
            rank1_identical_all_pairs = all(same_rank1), .groups = "drop") %>%
  left_join(noise_floor %>% filter(method == "CCA") %>%
              select(analysis, outcome, axis, noise_spearman_median, noise_topk_overlap_median),
            by = c("analysis", "outcome", "axis"))

# ---- write ---------------------------------------------------------------------------------
write.csv(ranks,         file.path(paths$tables, "rq2_ranks_by_method.csv"), row.names = FALSE)
write.csv(agreement,     file.path(paths$tables, "rq2_rank_agreement_pairwise.csv"), row.names = FALSE)
write.csv(agree_summary, file.path(paths$tables, "rq2_rank_agreement_summary.csv"), row.names = FALSE)
write.csv(flags,         file.path(paths$tables, "rq2_worst_affected_flags.csv"), row.names = FALSE)
write.csv(noise_floor,   file.path(paths$tables, "rq2_sampling_noise_floor.csv"), row.names = FALSE)

options(width = 200)
r3 <- function(x) mutate(x, across(where(is.numeric), ~ round(.x, 3)))
cat("\n== Rank agreement across methods vs. sampling-noise floor ==\n"); print(r3(agree_summary))
cat("\n== Pairwise agreement vs CCA (main analysis) ==\n")
print(agreement %>% filter(grepl("^Main", analysis), method_a == "CCA") %>% r3(), n = 50)
cat("\n== Worst-affected status: all groups in top-k under any method ==\n")
print(flags %>% filter(n_methods_top_k > 0) %>%
        select(analysis, outcome, axis, group, pct_cca, rank_cca, rank_min, rank_max,
               n_methods_top_k, top_k_status, p_top_k_cca, rank95_cca) %>% r3(), n = 100)
