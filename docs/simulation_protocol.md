# Simulation protocol — RQ3 (DRAFT for approval)

Structured with the ADEMP framework (Aims, Data-generating mechanisms, Estimands, Methods,
Performance measures; Morris, White & Crowther, *Stat Med* 2019). Timings in §7 come from a
benchmark on this machine (2026-09-13); nothing here is a result.

---

## 1. Aims

Quantify the bias, empirical and model-based SE, RMSE and 95% CI coverage of complete-case
analysis, IPW, MI-PMM and MI-RF for survey-weighted stunting and wasting prevalence in the
Madagascar 2021 DHS under MCAR, MAR and MNAR outcome missingness at 10%, 30% and 50%, and
how well each method recovers the true regional ranking (links RQ3 to RQ2).

## 2. Data-generating mechanism

### 2.1 Pseudo-population (fixed)
- De facto children 0–59 m with **valid (non-flagged) HAZ and WHZ and observed mother
  covariates**: **n = 6,247**, 648 PSUs, 45 strata (435 children excluded from the
  6,682: missing/flagged anthropometry, or mother's age/education unknown).
- Consequence: mother_status in the pseudo-population takes only "Interviewed" (5,735) and
  "Not in household" (512); no covariate is missing, so "CCA (outcome + covariates)" is
  identical to CCA and is dropped from the simulation.

### 2.2 Per replicate
1. **Resample the survey (Rao–Wu bootstrap).** Within each stratum draw m_h = n_h − 1 PSUs
   with replacement; multiply weights by n_h/(n_h − 1) × (times selected); relabel each draw
   as a distinct PSU. This gives replicate-to-replicate sampling variability, so CI coverage
   tests the complete design-based uncertainty, not missingness alone.
   *Stratum 2 (Analamanga excl. Antananarivo, urban) has only 2 PSUs.* It is collapsed with
   the rural stratum of the same region for the simulation only; 3 other strata have 3 PSUs.
2. **Impose missingness** on the child's anthropometry. HAZ and WHZ are deleted together,
   mirroring the dominant observed pattern: all 178 children with a missing (non-flagged) WHZ
   were unmeasured (not present 140, refused 18, other 17, result missing 3) and all lack HAZ.
   The simulation omits the smaller HAZ-only pattern (79 measured children with missing HAZ
   but valid WHZ, 1.2%). Missingness probability:

   | Mechanism | logit P(missing) |
   |---|---|
   | MCAR | α |
   | MAR  | α + η, where η is the linear predictor of a logistic model of the **real** missingness (any of HAZ/WHZ not valid) on region, residence, wealth, sex, age group, mother status and household size, fitted to the 6,682 children and centred (SD of η in the pseudo-population = 0.80) |
   | MAR-strong (added after pilot) | α + κ·S\* + κ·W\*, where S\*, W\* are the standardised covariate-predicted logits of stunting and of wasting (pseudo-population logistic models on region, residence, wealth, sex, age group, mother status, mother education, household size); κ = log(2) |
   | MNAR | α + η + δ·(−HAZ\*) + δ·(−WHZ\*), where HAZ\*, WHZ\* are pseudo-population-standardised z-scores |

   α is solved numerically in each replicate so that the expected missingness rate equals the
   target (10%, 30%, 50%). **Proposed δ = log(2):** odds of missingness double per 1 SD lower
   z-score, conditional on η ("sicker/more malnourished children more often absent").

Design grid: 4 mechanisms × 3 rates = **12 scenarios**, plus the complete-data estimate in every
replicate as a benchmark.

**Amendment after pilot (2026-09-13).** In the pilot (R = 20), the calibrated MAR mechanism gave
negligible CCA bias. The expected CCA bias in the pseudo-population is ≤ 0.08 pp for stunting
at 50%, because the real predictors of missingness are only weakly related to the outcomes.
MAR-strong was added as the MAR counterpart of MNAR: the same structure and strength, driven
by covariate-predicted risk, not the z-score itself. Expected CCA bias under MAR-strong:
stunting −0.72 / −2.17 / −3.64 pp and wasting −0.28 / −0.72 / −1.10 pp at 10 / 30 / 50%. Under
MNAR: stunting −2.27 / −6.30 / −10.21 pp and wasting −1.19 / −2.57 / −3.53 pp.
Pilot checks: no errors; target missingness rates achieved; the complete-data benchmark,
pooled over 180 replicates, had coverage of 94.4% (stunting) and 96.7% (wasting), with SE
ratios of 0.93 and 1.13.

## 3. Estimands

Finite-population parameters of the pseudo-population (survey-weighted, design weights):

| Estimand | Truth |
|---|---|
| National stunting prevalence (primary) | 39.64% |
| National wasting prevalence (primary) | 7.62% |
| Stunting and wasting by region (23) and wealth quintile (5) (secondary) | computed once from the pseudo-population |
| True regional ranking; true top-5 worst-affected regions (secondary) | derived from the above |

## 4. Methods compared

Same implementation as RQ1 (`R/fn_methods.R`), single-threaded per replicate:

| Method | Settings in simulation | Settings in RQ1 |
|---|---|---|
| Complete data (before deletion) | benchmark | — |
| CCA | design-based, logit CI, design df | same |
| IPW | survey-weighted logistic response model on region, residence, wealth, sex, age group, mother status, mother education, household size; weights fixed | same |
| MI-PMM | m = 10, maxit = 10 | m = 20, maxit = 20 |
| MI-RF | m = 10, maxit = 10, ntree = 10 (mice default), ranger 1 thread | m = 20, maxit = 20, ntree = 100 |

Reduced MI settings are justified by the RQ1 traces (WAZ-free chains stationary within about
5 iterations) and by Barnard–Rubin df, which account for finite m in the CIs. The IPW model
**deliberately omits the outcome**: under MNAR it is misspecified by design, as are MI models.

**ntree sub-study:** MI-RF with ntree = 50 in one scenario (MAR 30%), R = 200, to show whether
ntree = 10 changes bias or coverage.

## 5. Performance measures

National estimands, per method × scenario (with Monte Carlo SEs):
bias, relative bias, empirical SE, mean model-based SE, SE ratio (model/empirical), RMSE,
95% CI coverage, mean CI width.

Subgroup estimands: mean absolute bias and mean coverage across the 23 regions and 5 quintiles.

Ranking: mean Spearman ρ between estimated and true regional ranking; proportion of
replicates in which the estimated top-5 equals the true top-5; mean top-5 overlap.

Reference line for coverage: the complete-data benchmark's coverage shows how the Rao–Wu
resampling and linearisation SE combine without any missing data (expected close to, but
not exactly, 95%).

## 6. Number of replicates

Monte Carlo SE of coverage at 95%: R = 250 → 1.4 pp; R = 500 → 0.97 pp; R = 1000 → 0.69 pp.
Worst case (coverage 50%): R = 500 → 2.2 pp. Bias MCSE = empirical SE/√R; for national stunting
(SE about 1 pp) R = 500 gives about 0.05 pp.

## 7. Runtime (measured)

Single-core benchmark, one replicate, MAR 30%, bootstrap n = 5,996:

| Step | Seconds |
|---|---|
| Bootstrap + impose missingness | 0.1 |
| Complete-data estimate | ≈0.4 |
| CCA | 0.36 |
| IPW | 0.79 |
| MI-PMM, m = 10, maxit = 10 (imputation 7.7 + estimation/pooling 3.7) | 11.4 |
| MI-RF, m = 10, maxit = 10, ntree = 10 (33.3 + 3.7) | 37.0 |
| MI-RF, ntree = 25 | 70.3 |
| MI-RF, ntree = 50 | 127.7 |
| **Replicate total, RF ntree = 10** | **≈50** |

Budget options (4 parallel workers, one per physical core; assumes near-linear scaling):

| Option | Replicates | Core-hours | Wall-clock |
|---|---|---|---|
| **A (recommended)**: all methods R = 500, ntree = 10 | 4,500 | 62.5 | **≈16 h** |
| B: all methods R = 1000, ntree = 10 | 9,000 | 125 | ≈31 h |
| C: all methods R = 500, ntree = 25 | 4,500 | 104 | ≈26 h |
| D: CCA/IPW/PMM R = 1000; RF on first 250 replicates | 9,000 / 2,250 | 56 | ≈14 h |
| + ntree sub-study (ntree = 50, one scenario, R = 200) | 200 | 7.1 | ≈1.8 h |

**Pilot-measured timings (4 parallel workers):** about 87 s per replicate (MI-PMM 18 s, MI-RF
66 s) and 237 s for MI-RF with ntree = 50. **Approved run:** 12 scenarios × 500 plus the ntree
sub-study × 200, about 36 h + 3.3 h ≈ 39 h.
The budget table above is from a single timed single-core replicate (±25%). Engineering options, if needed:
a vectorised estimation layer (replacing svyby) could save about 7 s per replicate; running on
8 logical cores may gain another ~20–30%.

## 8. Implementation and reproducibility

- `R/20_simulation.R`: scenario grid × replicate index; seed per task = SEED + scenario × 10⁵ +
  replicate (L'Ecuyer-CMRG streams), so any single replicate can be regenerated.
- Each replicate's estimates are written to `data/derived/sim/` (one `.rds` per scenario ×
  chunk) as it completes, so a run can be interrupted and resumed. Per-replicate outputs
  contain only estimates, not microdata.
- Summaries (Table 3, Figure 2) are built by `R/21_simulation_summary.R` from the stored results.
- Pilot first: R = 20 per scenario (≈40 min) to check code, missingness rates and
  convergence, and to refine timings before the full run.

## 9. Decisions needed

1. **MNAR form.** Low-tail (proposed: lower z raises missingness) or symmetric "extremes more
   likely missing" (δ·|z|, as worded in CLAUDE.md)? Both = +3 scenarios, +33% runtime.
2. **MNAR strength.** δ = log(2) per SD proposed; alternatives log(1.5) or log(3).
3. **Budget:** option A, B, C or D.
4. **Rates:** keep 10/30/50%, or add a 5% scenario close to the observed 4.5%?
