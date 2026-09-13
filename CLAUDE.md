# CLAUDE.md — Missing-data methods on the 2021 Madagascar DHS

Project context for Claude Code. This file drives the build of a fully reproducible
analysis pipeline supporting a methods paper for the *BMC Public Health* Collection
**"Epidemiologic methods for addressing missing data in public health research"**
(submission deadline: 30 March 2027).

---

## 1. Objective

Quantify how the choice of missing-data method changes (a) the estimated prevalence of
child stunting and wasting in Madagascar and (b) the **equity ordering** of subgroups —
which regions and wealth quintiles are identified as most affected — under the survey's
complex design. Evaluate estimator bias and confidence-interval coverage under a known,
simulated missingness mechanism.

### Research questions

- **RQ1.** Across complete-case analysis, multiple imputation (MI), inverse probability
  weighting (IPW), and a machine-learning imputer, how much does survey-weighted
  stunting/wasting prevalence differ, nationally and by subgroup?
- **RQ2.** Does the method change the *ranking* of regions and wealth quintiles by
  prevalence (i.e. the targeting conclusion)?
- **RQ3.** Under simulated MCAR / MAR / MNAR mechanisms calibrated to the observed data,
  what are the bias, RMSE, and 95% CI coverage of each method?

Do **not** fabricate estimates, coverage rates, or figures. Every number in the eventual
Results section must come from code run on the real data in this repo.

---

## 2. Data

- **Source.** 2021 Madagascar Demographic and Health Survey (DHS-8), obtained by the
  analyst under DHS registered-user access. Files are Stata `.DTA` (or SPSS `.SAV`).
- **Country/phase file prefix:** `MD****81FL` — typical files (confirm exact version
  suffix from the download):
  - `MDPR81FL` — household member (person) recode → child anthropometry (`HC7x`)
  - `MDKR81FL` — children's (kids) recode → also carries anthropometry (`HW7x`) + maternal covariates
  - `MDHR81FL` — household recode
  - `MDIR81FL` — individual (women's) recode
  - `MDBR81FL` — births recode
- **Anthropometry source — DECISION POINT.** DHS anthropometry can be taken from the
  PR file (`HC70`/`HC71`/`HC72` on the de facto child population, `HV103==1`) or from the
  KR file (`HW70`/`HW71`/`HW72`). Confirm which the **Madagascar 2021 Final Report** used
  for its nutrition tables and match it, so our baseline reproduces the published figures.
  Document the choice in `R/02_derive_variables.R`.

### Ethics / terms of use — non-negotiable

- Raw DHS microdata **must never be committed to git, shared, or uploaded anywhere.**
  `.gitignore` must exclude `data/raw/`. Only derived, non-redistributable summaries and
  code are versioned. This is a DHS terms-of-use requirement and matters for the public
  GitHub portfolio.

---

## 3. Key variables (typical DHS names — confirm against the `.MAP`/`.DO` manual)

| Concept | KR file | PR file | Notes |
|---|---|---|---|
| Sample weight | `v005` | `hv005` | **divide by 1,000,000** |
| Cluster / PSU | `v021` (or `v001`) | `hv021` (or `hv001`) | |
| Stratum | `v022` or `v023` | `hv022` or `hv023` | confirm which defines strata |
| Region | `v024` | `hv024` | subgroup axis |
| Wealth quintile | `v190` | `hv270` | subgroup axis |
| Height-for-age z (HAZ) | `hw70` | `hc70` | **stored ×100** → divide by 100 |
| Weight-for-age z (WAZ) | `hw71` | `hc71` | |
| Weight-for-height z (WHZ) | `hw72` | `hc72` | |
| Child age (months) | `hw1`/`b19` | `hc1` | |
| Mother's education, age, etc. | `v106`, `v012` | — | auxiliary covariates for MI/IPW |

- **Flag / missing codes.** WHO-flagged (biologically implausible) and missing z-scores are
  stored as special values (commonly `9996`, `9997`, `9998`, `9999`). **Confirm the exact
  codes in the recode manual** and convert to `NA` in `02_derive_variables.R`. Keep flagged
  vs. genuinely-missing distinguishable — they are different phenomena.
- **Outcomes.** Stunting = HAZ < −2; severe stunting = HAZ < −3. Wasting = WHZ < −2;
  severe wasting = WHZ < −3.

---

## 4. Methods to implement

All estimators must respect the survey design (weights, stratification, clustering).

1. **Complete-case analysis (CCA)** — baseline; survey-weighted prevalence on records with
   observed outcome and covariates.
2. **Multiple imputation (MI)** — chained equations (`mice`), imputing outcomes and
   auxiliary covariates. Fit the survey design on each completed dataset and pool with
   Rubin's rules (`mitools::MIcombine` or `mice::pool` with `svyby` per imputation).
   Include the design/weight information as predictors or use a weighted imputation approach;
   document the choice.
3. **Inverse probability weighting (IPW)** — model response propensity (logistic regression
   of "observed" on auxiliary covariates), multiply the design weight by the inverse of the
   estimated response probability, then estimate prevalence with the combined weights.
4. **Machine-learning imputation** — use `mice` with `method = "rf"` (random-forest MI, which
   *does* propagate uncertainty). If `missForest` is used for comparison, flag explicitly
   that single RF imputation understates variance — do not report its naive CIs as valid.

---

## 5. Simulation layer (RQ3)

Purpose: create a setting where the truth is known so bias and coverage are measurable.

- **Pseudo-population / truth.** Take the subset of records with fully observed key variables
  and non-flagged z-scores; treat its survey-weighted prevalence as the target.
- **Impose missingness** on the outcome (and optionally covariates), R replications each:
  - **MCAR** — remove a random fraction (e.g. 10%, 30%, 50%).
  - **MAR** — removal probability a function of observed covariates (wealth, region,
    mother's education).
  - **MNAR** — removal probability a function of the z-score value itself (extremes more
    likely missing).
- For each replication × mechanism × rate, run all four methods and record the point
  estimate and 95% CI.
- **Metrics.** Bias, empirical SE, RMSE, and CI coverage vs. the known target.

---

## 6. Equity-ranking analysis (RQ2)

- Compute prevalence by region (`v024`) and by wealth quintile (`v190`) under each method.
- Rank subgroups within each method.
- Measure cross-method rank agreement (Spearman's ρ and Kendall's τ), and flag any subgroup
  whose "worst-affected" status is method-dependent.

---

## 7. Toolchain

- **Primary language: R** (cleanest integration of MI + complex survey estimation).
- Packages: `haven` (read `.DTA`/`.SAV`), `survey`, `srvyr`, `mice`, `mitools`,
  `ranger`/`missForest`, `WeightIt` (optional for IPW), `dplyr`, `tidyr`, `ggplot2`,
  `gt`/`gtsummary` (tables), `here` (paths), `renv` (lockfile).
- Always set `options(survey.lonely.psu = "adjust")`.
- Reproducibility: `renv::init()` and commit `renv.lock`. Set a global RNG seed for the
  simulation and record it.

---

## 8. Repository layout to create

```
dhs-missingdata-mdg/
├── CLAUDE.md            # this file
├── README.md            # public-facing summary (no data)
├── renv.lock
├── run_all.R            # sources R/ scripts in order
├── .gitignore           # MUST ignore data/raw/
├── data/
│   ├── raw/             # DHS .DTA files — gitignored, never shared
│   └── derived/         # cleaned analysis datasets
├── R/
│   ├── 00_setup.R           # packages, options, seed, paths
│   ├── 01_load_recode.R     # read DHS files
│   ├── 02_derive_variables.R# z-scores /100, flag→NA, outcomes, covariates
│   ├── 03_missingness_summary.R
│   ├── 04_design.R          # svydesign / srvyr object
│   ├── 10_observed_methods.R# CCA, MI, IPW, ML on real data (RQ1)
│   ├── 20_simulation.R      # MCAR/MAR/MNAR × methods (RQ3)
│   ├── 30_equity_ranking.R  # RQ2
│   ├── 40_tables.R
│   └── 41_figures.R
└── outputs/
    ├── tables/
    └── figures/
```

---

## 9. Deliverables (outputs the paper will cite)

- **Table 1** — sample description and missingness summary by variable.
- **Table 2** — survey-weighted stunting/wasting prevalence by method, national + by region
  and wealth quintile (RQ1).
- **Table 3** — simulation results: bias, RMSE, 95% CI coverage by method × mechanism × rate (RQ3).
- **Figure 1** — subgroup prevalence across methods (caterpillar/dot plot) with ranking
  concordance (RQ2).
- **Figure 2** — coverage vs. missingness rate by mechanism.

---

## 10. Validation gate before writing Results

1. Reproduce the **published Madagascar 2021 stunting/wasting prevalence** with CCA + design
   weights. If it doesn't match the Final Report within rounding, the pipeline is wrong —
   stop and fix before proceeding.
2. Confirm flag/missing codes were correctly converted (no impossible z-scores survive).
3. Confirm weights divided by 1,000,000 and design object reproduces DHS standard errors.

Only once these pass do we populate Table 2 and beyond.

**Status (2026-09-13): PASS.** `R/05_validation.R` reproduces all 246 cells of Final Report
Table 11.1 (6 indicators × 41 groups) with zero difference at 1 d.p., the national unweighted
and weighted Ns, and all 53 Appendix B sampling-error entries checked (national SE; subgroup
M ± 2SE). Published values are transcribed in `data/reference/`.

### Resolved decisions
- **Anthropometry source:** PR file, `hc70–hc72`, de facto children (`hv103 == 1`, `hc1 < 60`).
- **Design:** PSU `hv021`, strata `hv022` (45), weight `hv005 / 1e6`.
- **Codes:** 9996 height implausible, 9997 age implausible, 9998 flagged, 9999/NA missing.
- **Regions:** 23 `hv024` domains; code 10 = Antananarivo, code 11 = "Analamanga sans
  Antananarivo" (the report's combined Analamanga row is not a subgroup here).
- **Wealth axis for PR-based analysis:** `hv270` (not `v190`).
- **Flagged z-scores (2026-09-13, option a):** main analysis treats flagged values as missing
  (target = all de facto children 0–59 m); sensitivity analysis excludes flagged children per
  index (DHS/WHO convention). CCA always follows the DHS definition.
- **Mother covariates:** "mother not in household" (`hc60 == 995`) is structural — own
  category, never imputed. Mother's age for `hc60` 993/994 and education "don't know" are
  genuine missingness, imputed with custom `*_present` imputers in `R/fn_methods.R`.
- **Imputation model:** HAZ + WHZ (WAZ excluded — near-deterministic with HAZ/WHZ, caused
  non-mixing PMM chains), m = 20, maxit = 20, predictors include region, residence, wealth,
  sex, age, household size, mother status/education/age, log design weight. Rubin's rules on
  the logit scale with Barnard–Rubin df (complete-data df = design df 605).
- **IPW:** survey-weighted logistic response model per z-score; weights treated as fixed.
- **Runtime:** parallel mice (4 workers); RQ1 script ≈ 46 min, MI-RF dominates.

---

## 11. Working conventions

- Formal, reproducible, script-driven; numbered scripts, `run_all.R` reproduces everything.
- No invented numbers anywhere. Uncertain DHS specifics are confirmed against the recode
  manual, not guessed.
- Article language: English, formal academic register. References: NLM/Vancouver.
