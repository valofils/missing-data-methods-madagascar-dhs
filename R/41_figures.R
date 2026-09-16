# 41_figures.R — manuscript figures
#
# Figure 1 (RQ2): subgroup prevalence under each missing-data method, with CCA 95% CIs and
#   cross-method ranking concordance. Main analysis; Figure S1 = flagged-excluded sensitivity.
# Palette: categorical slots 1-5 of the reference palette, validated for colour-vision
#   deficiency (worst adjacent CVD dE 9.1); three slots are < 3:1 contrast on white, so every
#   method also has a distinct marker shape and the legend is always present.

source(here::here("R", "00_setup.R"))
suppressPackageStartupMessages({ library(ggplot2); library(patchwork) })

METHOD_LEVELS <- c("CCA", "CCA (outcome + covariates)", "IPW", "MI-PMM", "MI-RF")
METHOD_COLS   <- setNames(c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"), METHOD_LEVELS)
METHOD_SHAPES <- setNames(c(16, 17, 15, 18, 25), METHOD_LEVELS)
INK <- "#0b0b0b"; INK2 <- "#52514e"; MUTED <- "#898781"; GRID <- "#e1e0d9"; CI_COL <- "#c3c2b7"

ranks <- read.csv(file.path(paths$tables, "rq2_ranks_by_method.csv"), stringsAsFactors = FALSE)
flags <- read.csv(file.path(paths$tables, "rq2_worst_affected_flags.csv"), stringsAsFactors = FALSE)
agree <- read.csv(file.path(paths$tables, "rq2_rank_agreement_summary.csv"), stringsAsFactors = FALSE)

theme_fig <- function() {
  theme_minimal(base_size = 8.5) +
    theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
          panel.grid.major.x = element_line(colour = GRID, linewidth = 0.3),
          axis.text = element_text(colour = INK2), axis.title = element_text(colour = INK2),
          plot.title = element_text(colour = INK, face = "bold", size = 9),
          plot.subtitle = element_text(colour = INK2, size = 7.5),
          legend.position = "bottom", legend.title = element_blank(),
          legend.text = element_text(colour = INK2),
          plot.caption = element_text(colour = MUTED, hjust = 0, size = 7))
}

equity_panel <- function(an, oc, ax, title) {
  d <- ranks %>% filter(analysis == an, outcome == oc, axis == ax) %>%
    mutate(method = factor(method, METHOD_LEVELS))
  f <- flags %>% filter(analysis == an, outcome == oc, axis == ax)
  cca <- d %>% filter(method == "CCA")
  k <- f$k[1]
  lab <- f %>% transmute(group, label = ifelse(top_k_status == "METHOD-DEPENDENT",
                                               paste0(group, " †"), group))
  ord <- cca %>% arrange(pct) %>% pull(group)
  d <- d %>% mutate(group = factor(group, ord))
  cca <- cca %>% mutate(group = factor(group, ord))
  a <- agree %>% filter(analysis == an, outcome == oc, axis == ax)
  sub <- if (ax == "region") {
    sprintf("Methods: ρ ≥ %.3f; top-%d overlap ≥ %d/%d\nSampling noise: ρ = %.2f; top-%d overlap %d/%d",
            a$min_spearman, k, round(a$min_topk_overlap * k), k,
            a$noise_spearman_median, k, round(a$noise_topk_overlap_median * k), k)
  } else {
    sprintf("Methods: identical ranking (ρ = %.2f)\nSampling noise: ρ = %.2f",
            a$min_spearman, a$noise_spearman_median)
  }

  p <- ggplot(d, aes(y = group)) +
    geom_linerange(data = cca, aes(xmin = lo, xmax = hi), colour = CI_COL, linewidth = 1.6,
                   lineend = "round") +
    geom_point(aes(x = pct, colour = method, fill = method, shape = method),
               position = position_dodge(width = 0.7, orientation = "y"), size = 1.5) +
    scale_colour_manual(values = METHOD_COLS, drop = FALSE) +
    scale_fill_manual(values = METHOD_COLS, drop = FALSE) +
    scale_shape_manual(values = METHOD_SHAPES, drop = FALSE) +
    scale_y_discrete(labels = setNames(lab$label, lab$group)) +
    labs(title = title, subtitle = sub, x = "Prevalence (%)", y = NULL) +
    theme_fig()
  if (ax == "region") {
    p <- p + geom_hline(yintercept = length(ord) - k + 0.5, colour = MUTED, linewidth = 0.3,
                        linetype = "22")
  }
  p
}

make_figure <- function(an) {
  p1 <- equity_panel(an, "stunted", "region", "A  Stunting by region")
  p2 <- equity_panel(an, "wasted",  "region", "B  Wasting by region")
  p3 <- equity_panel(an, "stunted", "wealth", "C  Stunting by wealth quintile")
  p4 <- equity_panel(an, "wasted",  "wealth", "D  Wasting by wealth quintile")
  # Captions are not drawn inside the image: they are written to figure_captions.csv and used by
  # the manuscript (\caption in LaTeX), so each caption has a single source.
  (p1 | p2) / (p3 | p4) +
    plot_layout(heights = c(23, 5.5), guides = "collect") &
    theme(legend.position = "bottom")
}

CAPTIONS <- list()
add_caption <- function(name, title, caption) {
  CAPTIONS[[name]] <<- data.frame(figure = name, title = title, caption = caption)
  invisible(NULL)
}

save_fig <- function(p, name, w = 180, h = 205) {
  ggsave(file.path(paths$figures, paste0(name, ".png")), p, width = w, height = h, units = "mm",
         dpi = 300, bg = "white", device = ragg::agg_png)
  ggsave(file.path(paths$figures, paste0(name, ".pdf")), p, width = w, height = h, units = "mm",
         bg = "white", device = cairo_pdf)
}

save_fig(make_figure("Main (flagged = missing)"), "figure1_equity_ranking")
save_fig(make_figure("Sensitivity (flagged excluded)"), "figureS1_equity_ranking_sensitivity")

equity_caption <- function(analysis_note) paste0(
  "Prevalence of stunting and wasting by region and wealth quintile under each missing-data method",
  analysis_note,
  ". Grey bars: 95% confidence interval for complete-case analysis (CCA). Points: point estimates under ",
  "each method. Groups are ordered by CCA prevalence; the dashed line marks the five worst-affected ",
  "regions under CCA. Daggers mark subgroups whose top-5 worst-affected status differs between methods. ",
  "Panel subtitles give the minimum Spearman correlation and top-k overlap across all method pairs, and ",
  "the sampling-noise benchmark: the median agreement between the CCA point ranking and rankings re-drawn ",
  "from the CCA sampling distribution (10,000 draws).")
add_caption("figure1_equity_ranking",
            "Subgroup prevalence and equity ranking under each missing-data method", equity_caption(""))
add_caption("figureS1_equity_ranking_sensitivity",
            "Subgroup prevalence and equity ranking, sensitivity analysis",
            equity_caption(", excluding children with WHO-flagged z-scores from the target population"))

# =============================================================================================
# Figure 2 (RQ3): 95% CI coverage vs missingness rate, by mechanism; Figure S2: bias
# Usage: Rscript R/41_figures.R [full|pilot]   (default full; skipped if summary not present)
# Colours follow the method entity used in Figure 1; "Complete data" benchmark in neutral grey.
# =============================================================================================
args <- commandArgs(trailingOnly = TRUE)
SIM_MODE <- if (length(args) && args[1] %in% c("pilot", "full")) args[1] else "full"
perf_file <- file.path(paths$tables, sprintf("rq3_performance_national_%s.csv", SIM_MODE))

SIM_METHODS <- c("Complete data", "CCA", "IPW", "MI-PMM", "MI-RF")
SIM_COLS   <- c(`Complete data` = MUTED, METHOD_COLS[c("CCA", "IPW", "MI-PMM", "MI-RF")])
SIM_SHAPES <- c(`Complete data` = 1, METHOD_SHAPES[c("CCA", "IPW", "MI-PMM", "MI-RF")])
SIM_LTY    <- c(`Complete data` = "22", CCA = "solid", IPW = "solid", `MI-PMM` = "solid", `MI-RF` = "solid")
MECH_LEVELS <- c("MCAR", "MAR", "MAR-strong", "MNAR")

if (!file.exists(perf_file)) {
  message("41: ", basename(perf_file), " not found — Figure 2 skipped")
} else {
  perf <- read.csv(perf_file, stringsAsFactors = FALSE) %>%
    filter(method %in% SIM_METHODS) %>%
    mutate(method = factor(method, SIM_METHODS),
           mechanism = factor(mechanism, intersect(MECH_LEVELS, unique(mechanism))),
           outcome = factor(c(stunted = "Stunting", wasted = "Wasting")[outcome], c("Stunting", "Wasting")),
           rate_pct = 100 * rate)
  n_sim <- max(perf$n_sim)
  pilot_tag <- if (SIM_MODE == "pilot") "  [PILOT — not for publication]" else ""
  dodge <- position_dodge(width = 3)

  sim_panel <- function(yvar, lovar, hivar, ylab, ref, ref_band = NULL, title) {
    p <- ggplot(perf, aes(x = rate_pct, y = .data[[yvar]], colour = method, shape = method,
                          linetype = method, group = method))
    if (!is.null(ref_band)) {
      p <- p + annotate("rect", xmin = -Inf, xmax = Inf, ymin = ref_band[1], ymax = ref_band[2],
                        fill = "#f0efec")
    }
    p + geom_hline(yintercept = ref, colour = MUTED, linewidth = 0.4) +
      geom_linerange(aes(ymin = .data[[lovar]], ymax = .data[[hivar]]), position = dodge,
                     linewidth = 0.4, linetype = "solid", show.legend = FALSE) +
      geom_line(position = dodge, linewidth = 0.6) +
      geom_point(position = dodge, size = 1.8, fill = "white", stroke = 0.7) +
      facet_grid(outcome ~ mechanism, scales = if (yvar == "bias_pp") "free_y" else "fixed") +
      scale_x_continuous(breaks = c(10, 30, 50), labels = function(x) paste0(x, "%"),
                         expand = expansion(add = 6)) +
      scale_colour_manual(values = SIM_COLS) + scale_shape_manual(values = SIM_SHAPES) +
      scale_linetype_manual(values = SIM_LTY) +
      labs(x = "Proportion of children with missing anthropometry", y = ylab,
           # manuscript captions carry the figure title; the image only flags pilot output
           title = if (nzchar(pilot_tag)) trimws(pilot_tag) else NULL) +
      theme_fig() +
      theme(panel.grid.major.y = element_line(colour = GRID, linewidth = 0.3),
            panel.border = element_rect(colour = GRID, fill = NA, linewidth = 0.4),
            strip.text = element_text(colour = INK, face = "bold"),
            legend.key.width = unit(18, "pt"))
  }

  perf <- perf %>% mutate(
    cov_pct = 100 * coverage,
    cov_lo = pmax(0, 100 * (coverage - 1.96 * coverage_mcse)),
    cov_hi = pmin(100, 100 * (coverage + 1.96 * coverage_mcse)),
    bias_pp = 100 * bias, bias_lo = 100 * (bias - 1.96 * bias_mcse), bias_hi = 100 * (bias + 1.96 * bias_mcse)
  )
  band <- 100 * (0.95 + c(-1, 1) * 1.96 * sqrt(0.95 * 0.05 / n_sim))

  fig2 <- sim_panel("cov_pct", "cov_lo", "cov_hi", "Coverage of nominal 95% CI (%)", 95, band,
                    "Figure 2. Confidence-interval coverage by missingness mechanism and rate") +
    scale_y_continuous(breaks = c(0, 25, 50, 75, 95)) +
    coord_cartesian(ylim = c(0, 100))     # zoom, not limits: keeps the reference band and bars
  save_fig(fig2, paste0("figure2_simulation_coverage", if (SIM_MODE == "pilot") "_PILOT"), w = 180, h = 120)

  figS2 <- sim_panel("bias_pp", "bias_lo", "bias_hi", "Bias (percentage points)", 0, NULL,
                     "Figure S2. Bias of national prevalence by missingness mechanism and rate")
  save_fig(figS2, paste0("figureS2_simulation_bias", if (SIM_MODE == "pilot") "_PILOT"), w = 180, h = 120)

  sim_caption <- function(what, extra) sprintf(paste0(
    "%s of survey-weighted national prevalence of stunting (top row) and wasting (bottom row) by ",
    "missingness mechanism (columns) and missingness rate, from %d simulation replicates per scenario. ",
    "Error bars: plus or minus 1.96 Monte Carlo standard errors. Complete data: the estimate from each ",
    "bootstrap sample before deletion (benchmark). %s"), what, n_sim, extra)
  add_caption(paste0("figure2_simulation_coverage", if (SIM_MODE == "pilot") "_PILOT"),
              "Confidence-interval coverage by missingness mechanism and rate",
              sim_caption("Coverage of nominal 95% confidence intervals",
                          paste("The shaded band is the range expected under nominal coverage",
                                "(95% plus or minus 1.96 Monte Carlo standard errors).")))
  add_caption(paste0("figureS2_simulation_bias", if (SIM_MODE == "pilot") "_PILOT"),
              "Bias of national prevalence by missingness mechanism and rate",
              sim_caption("Bias, in percentage points,", "Vertical scales differ between outcomes."))
}

caption_file <- file.path(paths$figures, "figure_captions.csv")
if (length(CAPTIONS)) {
  write.csv(do.call(rbind, CAPTIONS), caption_file, row.names = FALSE)
  message("41: wrote ", basename(caption_file), " (", length(CAPTIONS), " captions)")
}
message("41: figures written to ", paths$figures)
