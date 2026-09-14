# Missing-data methods and child undernutrition equity estimates — Madagascar DHS 2021

Reproducible R pipeline for a methods study on how the choice of missing-data method
(complete-case analysis, inverse probability weighting, multiple imputation by predictive mean
matching, and random-forest multiple imputation) affects survey-weighted estimates of child
stunting and wasting — and the ranking of regions and wealth quintiles — in the 2021
Madagascar Demographic and Health Survey (EDSMD-V), with a simulation study of bias and
confidence-interval coverage under MCAR, MAR and MNAR mechanisms.

## Data access

This repository contains **no DHS microdata**. The survey data are available free of charge to
registered users from [The DHS Program](https://dhsprogram.com/data/). To reproduce:

1. Request access to the Madagascar 2021 DHS (MDxx81FL, Stata format).
2. Place the recode folders in `data/raw/` (e.g. `data/raw/MDPR81DT/MDPR81FL.DTA`,
   `data/raw/MDKR81DT/MDKR81FL.DTA`).
3. Run `Rscript run_all.R` from the repository root.

`data/raw/` and `data/derived/` are git-ignored in line with the DHS terms of use.

## Pipeline

| Script | Purpose |
|---|---|
| `R/00_setup.R` | packages, options, global seed, paths |
| `R/01_load_recode.R` | read PR and KR recodes |
| `R/02_derive_variables.R` | analysis population, z-scores, flag codes, outcomes, covariates |
| `R/03_missingness_summary.R` | missingness by variable and by covariate |
| `R/04_design.R` | survey design (PSU `hv021`, strata `hv022`, weight `hv005/1e6`) |
| `R/05_validation.R` | validation gate against the EDSMD-V 2021 Final Report (stops on failure) |
| `R/fn_methods.R` | estimators: CCA, IPW, MI-PMM, MI-RF, Rubin's rules |
| `R/10_observed_methods.R` | RQ1 — prevalence by method (main + flagged-excluded sensitivity) |
| `R/30_equity_ranking.R` | RQ2 — subgroup rankings, cross-method concordance, rank uncertainty |
| `R/fn_simulation.R`, `R/20_simulation.R` | RQ3 — simulation (protocol: `docs/simulation_protocol.md`; resumable) |
| `R/run_simulation_awake.ps1` | Windows wrapper that keeps the machine from idle-sleeping while the simulation runs |
| `R/21_simulation_summary.R` | RQ3 — performance measures with Monte Carlo SEs |
| `R/40_tables.R` | Tables 1–3 and S2–S5 (.docx, .html, .csv) |
| `R/41_figures.R` | Figures 1, 2 and S1, S2 |

## Validation

Complete-case, design-weighted estimates reproduce every cell of Final Report Table 11.1
(stunting, wasting, underweight; moderate and severe; by age, sex, residence, 23 regions and
wealth quintile) and the Appendix B sampling errors. Published reference values are in
`data/reference/`.

## Software

R 4.5.1; key packages `survey`, `mice`, `ranger`, `haven`, `dplyr`. Package versions are
recorded in `renv.lock`.
