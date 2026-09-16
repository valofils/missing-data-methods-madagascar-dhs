---
title: "Results — RQ3 simulation (draft)"
subtitle: "Missing-data methods and equity estimates of child undernutrition: Madagascar DHS 2021"
date: "Draft of 16 September 2026 — for author review"
---

> **Drafting notes (delete before submission).** All numbers were read from
> `outputs/tables/rq3_performance_national_full.csv`, `rq3_performance_subgroups_full.csv` and
> `rq3_ranking_recovery_full.csv` (full run: 12 scenarios x 500 replicates, plus the 200-replicate
> ntree sub-study; completed 16 September 2026, no failed replicates). This section follows the
> RQ1/RQ2 results. Items marked **[CONFIRM]** need an author decision.

## Results (continued)

### Simulation study (RQ3)

All 6,200 replicates completed without error, and the imposed missingness proportions matched their
targets in every scenario (mean achieved 10.0%, 30.0% and 50.0% unweighted). The complete-data
benchmark, the estimate from each bootstrap sample before deletion, behaved as intended throughout:
absolute bias never exceeded 0.07 percentage points (pp), the ratio of model-based to empirical
standard error lay between 0.92 and 1.05, and coverage of nominal 95% intervals ranged from 92.8% to
96.2%. Departures from nominal coverage below therefore reflect the missing-data methods, not the
resampling design (Table 3, Table S3; Figure 2).

**MCAR and calibrated MAR.** When missingness was completely at random, or followed the mechanism
calibrated to the survey's own missingness pattern, every method was essentially unbiased at all
three rates. For national stunting, absolute bias was at most 0.14 pp under MCAR and 0.10 pp under
MAR (Monte Carlo SE 0.05 pp), and coverage stayed within 92.2–97.0% under MCAR. The exception was
MI-RF at 50% MAR missingness, where standard errors were too small (model-to-empirical SE ratio 0.85)
and coverage fell to 88.6%. These scenarios reproduce the near-identical estimates seen on the observed
data, where about 4% of outcomes were missing.

**Strong MAR.** When missingness depended strongly on covariate-predicted undernutrition risk, the
methods separated sharply (Figure 2, Table 3). For national stunting:

| Missingness | CCA | IPW | MI-PMM | MI-RF |
|---|---|---|---|---|
| 10% | −0.73 pp (86.4%) | 0.00 pp (95.6%) | −0.16 pp (95.0%) | −0.24 pp (94.0%) |
| 30% | −2.18 pp (44.2%) | −0.01 pp (96.0%) | −0.52 pp (91.8%) | −0.86 pp (84.2%) |
| 50% | −3.68 pp (11.0%) | −0.04 pp (94.8%) | −0.90 pp (86.4%) | −1.69 pp (63.4%) |

*Bias in percentage points, with coverage of nominal 95% CIs in parentheses.*

IPW removed essentially all of the bias and maintained nominal coverage at every rate, at the cost of
a modest increase in variance (empirical SE 1.26 pp versus 1.17 pp for CCA at 50%). Complete-case
analysis was substantially biased downwards and its intervals were badly miscalibrated: at 50%
missingness its 95% CI covered the true prevalence in 11% of replicates, because its standard errors
were correct for the wrong estimand (SE ratio 1.01). Both imputation methods removed most but not all
of the bias, MI-PMM more successfully than MI-RF. Root mean squared error at 50% missingness was
1.26 pp for IPW, 1.52 pp for MI-PMM, 2.05 pp for MI-RF and 3.87 pp for CCA. The same ordering held
for wasting, where CCA bias reached −1.11 pp (coverage 54.2%) at 50% missingness while IPW remained
unbiased (−0.04 pp, coverage 95.2%).

**MNAR.** When missingness depended on the child's own z-score given covariates, no method recovered
the truth, as expected: all four rely on the missing-at-random assumption. For national stunting,
bias at 10%, 30% and 50% missingness was −2.31, −6.25 and −10.30 pp for CCA and −1.99, −5.69 and
−9.61 pp for MI-RF, with the other methods in between; coverage was 33.6–45.2% at 10% missingness and
0% at both higher rates. Differences between methods were small relative to the bias they all shared:
IPW and MI reduced CCA's bias by at most 8%. The corresponding figures for wasting were −1.19 to
−3.52 pp for CCA, with coverage of 25.4% at 10% missingness and 0% thereafter.

**Variance estimation under multiple imputation.** MI-RF understated uncertainty whenever the fraction
of missing information was substantial: its SE ratio fell to 0.81–0.87 in the 50% scenarios, against
0.87–0.94 for MI-PMM and 0.93–1.03 for IPW. In the sub-study (MAR, 30% missingness, 200 replicates),
increasing the number of trees from 10 to 50 left bias unchanged (−0.10 pp versus −0.09 pp for
stunting) but improved calibration: the SE ratio rose from 0.93 to 0.99 and coverage from 93.4% to
96.5% (Table S5). The shortfall in MI-RF's variance therefore reflects too few trees rather than the
random-forest imputer as such, but the bias it leaves under strong MAR does not.

**Subgroup estimates.** Regional estimates showed the same ordering with larger errors (Table S3).
At 50% missingness under strong MAR, mean absolute bias across the 23 regions was 0.19 pp for IPW,
1.58 pp for MI-PMM, 2.37 pp for MI-RF and 2.76 pp for CCA, and mean coverage was 93.6%, 93.6%, 90.8%
and 89.7% respectively. Under MCAR and calibrated MAR, where CCA is unbiased, imputation was noticeably
noisier at regional level: mean absolute bias was 0.19 pp for CCA against 1.14 pp for MI-PMM and
1.95 pp for MI-RF under MCAR at 50% missingness, although coverage remained near nominal for all
methods. Imputation therefore bought robustness to selective missingness at the price of precision in
small domains.

**Recovery of the equity ranking.** Recovering the true ordering of the 23 regions was difficult even
with complete data: the mean Spearman correlation between estimated and true regional rankings was
0.92, the mean overlap of the estimated and true five worst-affected regions was 0.69 (3.5 of 5
regions), the true top-five set was recovered exactly in 5–8% of replicates, and the truly
worst-affected region was identified in 28–37%. Missingness and the choice of method changed this
little: at 30% missingness the mean correlation was 0.90–0.92 in every mechanism and method, and even
at 50% MNAR missingness it fell only to 0.84–0.87. The dominant obstacle to correct targeting was
therefore sampling variability in a survey designed for 23 domains, not the treatment of missing data
(Table S4).
