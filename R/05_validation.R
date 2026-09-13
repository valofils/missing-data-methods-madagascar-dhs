# 05_validation.R — CLAUDE.md §10 validation gate (CCA + design weights)
#
# Reference: INSTAT & ICF. Enquête Démographique et de Santé à Madagascar (EDSMD-V) 2021,
#   Table 11.1 (child nutritional status) and Appendix B, Tables B.2-B.28 (sampling errors).
#   Published values transcribed to data/reference/*.csv.
# Gate criteria:
#   G1  every Table 11.1 cell (6 indicators x 41 groups) within rounding (|diff| <= 0.1 pp)
#   G2  national unweighted and weighted denominators equal the published Ns
#   G3  no out-of-range z-scores; weights scaled (hv005 / 1e6)
#   G4  standard errors: national SE equal to 3 d.p.; subgroup M +/- 2SE bounds within 0.002
# The script stops with an error if any criterion fails.

source(here::here("R", "00_setup.R"))
source(here::here("R", "04_design.R"))
kids   <- readRDS(file.path(paths$derived, "kids.rds"))
kr_raw <- readRDS(file.path(paths$derived, "kr_raw.rds"))

pub_tab <- read.csv(here("data", "reference", "edsmd2021_published_nutrition.csv"),
                    check.names = FALSE, stringsAsFactors = FALSE)
pub_se  <- read.csv(here("data", "reference", "edsmd2021_published_sampling_errors.csv"),
                    stringsAsFactors = FALSE)

# ---- survey-weighted CCA prevalence ------------------------------------------------------
est <- function(data, outcome, by = NULL) {
  obs <- data[!is.na(data[[outcome]]), ]
  d <- make_design(obs)
  f <- as.formula(paste0("~", outcome))
  if (is.null(by)) {
    m <- svymean(f, d)
    data.frame(axis = "National", group = "National", outcome = outcome,
               n = nrow(obs), n_w = sum(obs$wt),
               pct = 100 * unname(coef(m)), se = 100 * unname(SE(m)))
  } else {
    m <- svyby(f, as.formula(paste0("~", by)), d, svymean)
    g <- as.character(m[[by]])
    data.frame(axis = by, group = g, outcome = outcome,
               n = as.integer(table(as.character(obs[[by]]))[g]),
               n_w = as.numeric(tapply(obs$wt, as.character(obs[[by]]), sum)[g]),
               pct = 100 * m[[outcome]], se = 100 * m[["se"]])
  }
}

outcomes <- c("sev_stunted", "stunted", "sev_wasted", "wasted", "sev_underweight", "underweight")
axes     <- c(Age = "age_grp", Sex = "sex", Residence = "residence", Region = "region",
              Wealth = "wealth")

ours <- bind_rows(
  lapply(outcomes, est, data = kids),
  unlist(lapply(outcomes, function(o) lapply(axes, function(a) est(kids, o, a))),
         recursive = FALSE) %>% bind_rows()
) %>%
  mutate(axis = ifelse(axis == "National", "National", names(axes)[match(axis, axes)]))

# ---- G1: Table 11.1 point estimates --------------------------------------------------------
g1 <- pub_tab %>%
  pivot_longer(all_of(outcomes), names_to = "outcome", values_to = "pub_pct") %>%
  left_join(ours, by = c("axis", "group", "outcome")) %>%
  mutate(ours_1dp = round(pct, 1), diff = round(ours_1dp - pub_pct, 1),
         pass = !is.na(pct) & abs(diff) <= 0.1 + 1e-9)

# ---- G2: denominators ----------------------------------------------------------------------
pub_n <- data.frame(outcome = c("stunted", "wasted", "underweight"),
                    pub_n = c(6402, 6478, 6422), pub_n_w = c(6317, 6392, 6335))
g2 <- ours %>% filter(axis == "National", outcome %in% pub_n$outcome) %>%
  select(outcome, n, n_w) %>% left_join(pub_n, by = "outcome") %>%
  mutate(pass = n == pub_n & abs(round(n_w) - pub_n_w) <= 1)

# ---- G3: z-score ranges and weights -------------------------------------------------------
g3 <- data.frame(
  check = c("HAZ within [-6, 6]", "WAZ within [-6, 5]", "WHZ within [-6, 5]",
            "no residual codes >= 9996", "weights scaled (max < 100)"),
  pass = c(all(abs(kids$haz) <= 6, na.rm = TRUE),
           all(kids$waz >= -6 & kids$waz <= 5, na.rm = TRUE),
           all(kids$whz >= -6 & kids$whz <= 5, na.rm = TRUE),
           all(c(kids$haz, kids$waz, kids$whz) < 99, na.rm = TRUE),
           max(kids$wt) < 100)
)

# ---- G4: sampling errors (Appendix B) ------------------------------------------------------
g4 <- pub_se %>%
  left_join(ours, by = c("axis", "group", "outcome")) %>%
  mutate(
    prop = pct / 100, se_p = se / 100,
    ours_lo = round(pmax(0, prop - 2 * se_p), 3), ours_hi = round(prop + 2 * se_p, 3),
    prop_ok = abs(round(prop, 3) - pub_prop) <= 0.001 + 1e-9,
    se_ok = ifelse(is.na(pub_se),
                   abs(ours_lo - pub_lo_2se) <= 0.002 + 1e-9 & abs(ours_hi - pub_hi_2se) <= 0.002 + 1e-9,
                   abs(round(se_p, 3) - pub_se) <= 0.001 + 1e-9),
    pass = prop_ok & se_ok
  ) %>%
  select(table, axis, group, outcome, pub_prop, ours_prop = prop, pub_se, ours_se = se_p,
         pub_lo_2se, ours_lo, pub_hi_2se, ours_hi, prop_ok, se_ok, pass)

# ---- KR cross-check (informational) --------------------------------------------------------
kr <- kr_raw %>% filter(!is.na(hw70), hw70 >= -600, hw70 <= 600) %>%
  mutate(wt = v005 / 1e6, psu = v021, stratum = v022, stunted = as.integer(hw70 < -200))
kr_st <- svymean(~stunted, make_design(kr))

# ---- write and report ----------------------------------------------------------------------
write.csv(ours, file.path(paths$validate, "cca_all_groups.csv"), row.names = FALSE)
write.csv(g1,   file.path(paths$validate, "G1_table11_1_comparison.csv"), row.names = FALSE)
write.csv(g2,   file.path(paths$validate, "G2_denominators.csv"), row.names = FALSE)
write.csv(g3,   file.path(paths$validate, "G3_ranges.csv"), row.names = FALSE)
write.csv(g4,   file.path(paths$validate, "G4_sampling_errors.csv"), row.names = FALSE)

status <- c(
  sprintf("G1 Table 11.1 point estimates: %d/%d cells within rounding (max |diff| = %.1f pp)",
          sum(g1$pass), nrow(g1), max(abs(g1$diff), na.rm = TRUE)),
  sprintf("G2 denominators: %d/%d match", sum(g2$pass), nrow(g2)),
  sprintf("G3 ranges/weights: %d/%d pass", sum(g3$pass), nrow(g3)),
  sprintf("G4 sampling errors: %d/%d match (prop %d, SE/CI %d)",
          sum(g4$pass), nrow(g4), sum(g4$prop_ok), sum(g4$se_ok)),
  sprintf("KR cross-check (info only): stunting %.1f%%, n = %d", 100 * coef(kr_st), nrow(kr))
)
gate_pass <- all(g1$pass, g2$pass, g3$pass, g4$pass)
status <- c(paste("VALIDATION GATE:", ifelse(gate_pass, "PASS", "FAIL")), status)
writeLines(c(format(Sys.time()), status), file.path(paths$validate, "gate_status.txt"))
cat(status, sep = "\n")

if (!all(g1$pass)) print(g1[!g1$pass, ])
if (!all(g2$pass)) print(g2[!g2$pass, ])
if (!all(g3$pass)) print(g3[!g3$pass, ])
if (!all(g4$pass)) print(g4[!g4$pass, ])
if (!gate_pass) stop("Validation gate failed — do not proceed to scripts 10+.")
