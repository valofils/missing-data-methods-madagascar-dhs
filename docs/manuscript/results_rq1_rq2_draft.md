---
title: "Results — RQ1 and RQ2 (draft)"
subtitle: "Missing-data methods and equity estimates of child undernutrition: Madagascar DHS 2021"
date: "Draft of 13 September 2026 — for author review"
---

> **Drafting notes (delete before submission).** Every number was read from pipeline outputs
> (`outputs/tables/rq1_*`, `rq2_*`, `outcome_missingness_by_covariate.csv`, `table1_*`) and
> re-extracted on 13 September 2026; none was transcribed from earlier summaries. Prevalences
> are survey-weighted unless stated. Simulation results (RQ3) will follow when the full run
> completes. Items marked **[CONFIRM]** need an author decision.

## Results

### Study population and missing data

The analysis included 6,682 de facto children aged 0–59 months (Table 1). A valid height-for-age
z-score was unavailable for 280 children (weighted 4.2%): 257 were not measured and 23 had a flagged
value. A valid weight-for-height z-score was unavailable for 204 children (weighted 3.1%): 178 not
measured and 26 flagged. All 178 children without a WHZ measurement had not been measured at all
(not present, 140; refused, 18; other, 17; result not recorded, 3) and therefore also lacked HAZ.
Both z-scores were valid for 6,378 children. Among the auxiliary variables, only mother's age
(223 children, 3.3%) and mother's education (6 children) had genuinely missing values.

Missingness was not completely at random. The proportion of children without a valid HAZ was
strongly associated with mother's interview status (Rao–Scott p < 0.001). It was 2.4% when the
mother had been interviewed, 9.9% when the mother did not live in the household, and 44.6% when the
mother's interview was incomplete. HAZ missingness also varied by region (p < 0.001), from 1.1% in
Ihorombe to 9.9% in Androy and 9.8% in Sava. It varied by residence (urban 6.3%, rural 3.9%;
p = 0.009) and by age (highest at 48–59 months, 6.9%; p < 0.001), and was higher when the mother had no
education (6.3%) than with primary or secondary education (2.9% each; p < 0.001). It was not
associated with wealth quintile (p = 0.62) or sex (p = 0.82). WHZ missingness was likewise associated
with mother's interview status (p < 0.001) and residence (p = 0.002), but not with region (p = 0.19).

### Prevalence by missing-data method (RQ1)

Complete-case estimates of national prevalence were 39.8% (95% CI 38.0–41.7) for stunting,
12.7% (11.6–14.0) for severe stunting, 7.7% (6.9–8.6) for wasting and 1.5% (1.2–1.9) for severe
wasting, matching the published survey figures (Table 2). National estimates barely changed with
the missing-data method. The largest difference from CCA for any method was 0.12 percentage points
(pp), for stunting with CCA restricted to complete covariates (39.7%). Estimates under IPW, MI-PMM
and MI-RF were within 0.03 pp of CCA for all four indicators. Confidence intervals were almost identical across methods. The estimated fraction of missing
information in the MI analyses was 0.02–0.05 for national estimates and at most 0.12 for any
subgroup estimate.

Subgroup estimates differed more, but differences remained small relative to their sampling
uncertainty (Table 2). Across the 56 regional and wealth-quintile estimates of stunting and wasting,
the mean absolute difference from CCA was 0.04–0.27 pp, depending on method and outcome. All MI-PMM
estimates were within 0.5 pp of CCA, as were 96% of IPW and MI-RF estimates and 89% of estimates from
CCA with complete covariates. The largest differences all concerned regional stunting:

- IPW lowered stunting prevalence in Androy from 45.3% to 43.7% (−1.6 pp). Androy had the highest
  proportion of children without a valid HAZ (47 of 476).
- MI-RF raised stunting prevalence in Sava from 31.0% to 32.0% (+1.1 pp).

All other differences were below 0.9 pp.

Diagnostics did not indicate unstable adjustment. The largest IPW adjustment factor, the inverse of
the estimated response probability, was 7.1 for HAZ and 3.2 for WHZ. IPW reduced the Kish effective
sample size of respondents only from 4,727 to 4,569 (HAZ) and from 4,785 to 4,728 (WHZ). Imputed
values resembled the observed distribution. Among children with missing HAZ, 41.0% (MI-PMM) and 40.1%
(MI-RF) of imputed values were below −2, compared with 39.3% of observed values (unweighted). For
children with flagged HAZ, the figures were 38.9% and 41.7%. For WHZ, 8.4% (MI-PMM) and 7.1% (MI-RF) of
imputed values for unmeasured children were below −2, against 7.8% of observed values.
Chains for both MI methods mixed well (Additional file 1 **[CONFIRM numbering]**).

Excluding flagged children from the target population left conclusions unchanged (Table S2). National
estimates changed by about 0.05 pp or less for any method, and subgroup estimates by at most 0.8 pp.

### Equity ordering of regions and wealth quintiles (RQ2)

Rankings of regions and wealth quintiles were highly concordant across methods (Figure 1). For
regional stunting, Spearman's ρ between any two methods was at least 0.993 and Kendall's τ-b at least
0.953, and no region moved by more than two ranks. For regional wasting, ρ was at least 0.987 and τ-b
at least 0.937, with a largest shift of three ranks. The ranking of wealth quintiles was identical
under all methods for both outcomes.

The five worst-affected regions were the same under CCA, IPW, MI-PMM and MI-RF for both outcomes;
the top-five set changed only under CCA with complete covariates.

- **Stunting.** Analamanga (excluding Antananarivo) replaced Atsimo Atsinanana in fifth place under CCA
  with complete covariates. The two regions differed by 0.02 pp under that method (48.28% vs 48.26%).
- **Wasting.** Under CCA with complete covariates, Vatovavy Fitovinany fell from fifth to eighth
  (10.2% to 9.5%) and Anosy entered the top five.
- **First place.** The worst-affected region for stunting differed under one method only: IPW ranked
  Itasy (51.57%) above Vakinankaratra (51.56%). Androy ranked first for wasting under every method.

Method-induced reordering was small compared with the uncertainty that sampling error alone places on
the rankings. When CCA estimates were re-drawn from their sampling distributions, the median agreement
with the CCA point ranking was ρ = 0.93 for stunting and 0.88 for wasting. The median overlap of the
top five was three of five regions for stunting and four of five for wasting. By contrast, agreement
between methods was ρ ≥ 0.987 with a top-five overlap of at least four of five.

No region's position among the five most stunted was secure under CCA. The highest probability of
belonging to the top five was 0.82 (Vakinankaratra), and the probability of ranking first was 0.31 for
Vakinankaratra and 0.30 for Itasy. The 95% rank intervals of seven regions included first place. For
wasting, only Androy was clearly among the worst-affected: its probability of being in the top five was
0.97 and of ranking first 0.58, with a 95% rank interval of 1–6. The 95% rank intervals of five regions
included first place. The regions whose worst-affected status depended on the method were among the
least certain. Their probabilities of top-five membership under CCA were 0.53–0.57 for stunting and
0.30–0.36 for wasting.

Among wealth quintiles, stunting prevalence under CCA was highest in the second-poorest quintile,
43.4% (40.3–46.6), not the poorest, 42.8% (39.8–45.9). The probability that the second-poorest
quintile truly ranked first was 0.57. The richest quintile was clearly the least affected, 30.0%
(25.7–34.7), and ranked last in at least 97.5% of simulated rankings. Wasting prevalence was highest in the poorest
quintile, 9.9% (8.2–11.9), with a probability of ranking first of 0.90; the gradient across the other
quintiles was not monotone. These orderings were unaffected by the choice of missing-data method.

The flagged-excluded sensitivity analysis gave the same concordance measures to within one rank shift
and identified the same method-dependent regions (Figure S1).
