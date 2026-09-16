---
title: "Methods (draft)"
subtitle: "Missing-data methods and equity estimates of child undernutrition: Madagascar DHS 2021"
date: "Draft of 13 September 2026 — for author review"
---

> **Drafting notes (delete before submission).** Every design detail below was checked against the
> analysis code in this repository or the EDSMD-V 2021 Final Report. Items marked **[CONFIRM]** need
> an author decision or external check. Verify all references against PubMed/publisher records before
> submission. Results-dependent statements (e.g. simulation findings) are deliberately absent.

## Methods

### Data source and survey design

We used data from the 2021 Madagascar Demographic and Health Survey (Enquête Démographique et de
Santé à Madagascar, EDSMD-V), a nationally representative household survey conducted by the Institut
National de la Statistique (INSTAT) with technical assistance from ICF through The DHS Program [1].
The survey was designed to produce estimates for the nation, for urban and rural areas, and for 23
study domains: the 22 administrative regions that existed at survey design (with Vatovavy and
Fitovinany forming a single region), with the capital, Antananarivo, and the remainder of Analamanga
region treated as separate domains [1].

The sample was a stratified two-stage cluster sample drawn from the 2018 General Population and
Housing Census (RGPH-3) frame. Each domain was divided into urban and rural strata (the capital is
urban only), giving 45 sampling strata. In the first stage, 657 enumeration areas were selected with
probability proportional to size; in the second stage, 34 households were selected systematically with
equal probability in each enumeration area, and 20,510 households were interviewed [1]. In a random
half of households, all children under 5 years were weighed and measured [1]. Fieldwork, launched in
March 2020 and suspended because of the COVID-19 pandemic, restarted on 3 March 2021 and lasted
143 days [1]. All 650 clusters in the released dataset were interviewed between March and July 2021:
the 56 clusters completed before the 2020 suspension are not part of it.

### Study population and outcomes

The analytic population comprised de facto children aged 0–59 months (children who slept in the
household the night before the interview) listed in the household member (PR) recode file, the
population used for the survey's published nutrition indicators [1,3] (n = 6,682 children in 649
primary sampling units and 45 strata).

Height-for-age (HAZ), weight-for-height (WHZ) and weight-for-age z-scores had been calculated by DHS
using the WHO Child Growth Standards [2]. The recode stores z-scores multiplied by 100 and uses
separate codes for values that are missing (not measured) and for measurements that fall outside
plausible limits: 9996 (height out of plausible limits), 9997 (age out of plausible limits) and 9998
(WHO-flagged z-score). We kept these two types of missingness distinct throughout. Stunting and severe
stunting were defined as HAZ < −2 and < −3, and wasting and severe wasting as WHZ < −2 and < −3 [2].

### Covariates and structural versus genuine missingness

Auxiliary variables were study domain (hereafter "region"), place of residence, household wealth
quintile, child's sex, child's age in months (and in the eight age bands used in the Final Report),
household size, mother's interview status, mother's education (none, primary, secondary or higher)
and mother's age. Mother's age was taken from the mother's own household roster line.

Two sources of incomplete maternal information were distinguished. For children whose mother did not
live in the household (including children whose mother had died; n = 569), maternal education and age
are not applicable. These were coded as a separate category ("not in household"), were never imputed,
and were represented in every model through mother's interview status. Genuine missingness comprised
mother's age for children whose mother lived in the household but could not be linked to a roster line
(mother not de facto, n = 30; incomplete women's interview, n = 193) and mother's education recorded
as "don't know" (n = 6).

### Complex survey design

All estimates accounted for sampling weights (the DHS household weight divided by 10⁶), stratification
and clustering. Variances were estimated by Taylor linearisation [4], with primary sampling units nested
within strata; single-PSU strata were handled by centring at the grand mean. Subgroup prevalences were
estimated as domain estimates, retaining all sampling units in the variance calculation. Because many
subgroup prevalences are low, 95% confidence intervals (CIs) were constructed on the logit scale
(delta-method variance) and back-transformed, with a t reference distribution on the design degrees of
freedom (number of PSUs minus number of strata, 604). Associations between outcome missingness and
covariates were assessed with design-based Rao–Scott tests [5].

**Pipeline validation.** Before applying any missing-data method, we checked that the complete-case,
design-based estimates reproduced the published survey figures. Estimates reproduced all 246 cells of
Final Report Table 11.1 (moderate and severe stunting, wasting and underweight by age, sex, residence,
23 regions and wealth quintile) to the published precision, the national unweighted and weighted
denominators, and the 53 stunting, wasting and underweight entries of the sampling-error appendix
(national standard errors and ±2 SE intervals for residence and the 23 regions) [1]. The analysis
pipeline stops automatically if any of these checks fails.

### Estimand and missing-data methods (RQ1)

The target estimand was the survey-weighted prevalence of each outcome among all de facto children aged
0–59 months, nationally and by region and wealth quintile. An outcome was considered missing when no
valid z-score was available, whether because the child was not measured or because the value was
flagged. We compared five approaches, chosen to span the estimators most often used for incomplete survey
outcomes [6].

1. **Complete-case analysis (CCA).** Children with a valid z-score, analysed with the design weights. This
   is the definition used in DHS reports [3].
2. **CCA with complete covariates.** As above, additionally requiring observed mother's age and education,
   representing the common practice of restricting to records complete for all analysis variables.
3. **Inverse probability weighting (IPW).** For each index separately, the probability of a valid z-score
   was modelled by survey-weighted logistic regression on region, residence, wealth quintile, sex, age
   band, mother's interview status, mother's education and household size. Each responding child's
   design weight was divided by the fitted response probability [7]. To avoid collinearity with
   mother's interview status, children whose mother was not in the household were assigned a constant
   education level in this model, and the six "don't know" values were set to the modal category.
   Variance estimation treated the estimated weights as fixed.
4. **Multiple imputation by chained equations with predictive mean matching (MI-PMM)** [8,9]. HAZ, WHZ
   and mother's age were imputed by predictive mean matching [10], and mother's education by
   polytomous logistic regression. Imputation models included all other variables, including
   the survey strata (region and residence) and the log design weight, so that the imputation model
   reflected the sampling design [11]. Weight-for-age was excluded from the imputation model: it is
   close to a deterministic function of HAZ and WHZ and is usually missing jointly with them, and its
   inclusion produced non-mixing chains with drifting variance in diagnostic runs. Imputation models for
   the maternal variables were fitted only to children whose mother lived in the household, so that
   structurally inapplicable values were neither used as donors nor imputed. We generated 20 imputed
   datasets with 20 iterations each; convergence was assessed from trace plots of chain means and
   standard deviations. Binary outcomes were derived from the imputed z-scores after imputation.
5. **Random-forest multiple imputation (MI-RF)** [12,13]. As for MI-PMM, but with every incompletely
   observed variable imputed by random forests (100 trees; ranger implementation [14]). Unlike single
   random-forest imputation, this procedure propagates imputation uncertainty through multiple imputed
   datasets.

For both MI approaches, the survey design was applied to each completed dataset, and estimates were
combined with Rubin's rules [15] on the logit scale [17]. Inference used Barnard–Rubin small-sample
degrees of freedom [16] with the design degrees of freedom as the complete-data value.

**Sensitivity analysis.** Because implausible measurements may reflect measurement error, not
genuinely extreme values, we repeated all analyses with flagged children excluded from the target
population, following the DHS and WHO convention. Exclusions were made separately for each index:
flagged-HAZ children for stunting outcomes and flagged-WHZ children for wasting outcomes. By
construction, CCA estimates are identical in the main and sensitivity analyses.

### Equity ranking analysis (RQ2)

Within each method, regions and wealth quintiles were ranked by prevalence of stunting and of wasting
(rank 1 = highest). Agreement between methods was summarised for every pair of methods by Spearman's
ρ, Kendall's τ-b, the largest absolute rank shift and, as a targeting-relevant measure, the overlap of the
"worst-affected" set: the five highest-prevalence regions (about the top fifth of 23) and the
highest-prevalence wealth quintile. A subgroup was classified as having method-dependent worst-affected
status if it belonged to this set under some but not all methods.

Because rankings of survey estimates are themselves uncertain, we quantified sampling uncertainty in
ranks by Monte Carlo simulation. For each method, 10,000 sets of estimates were drawn from the
estimated sampling distributions (logit scale, t distribution with the method's degrees of freedom), and
we recorded each subgroup's probability of being among the worst-affected, its probability of ranking
first and its 95% rank interval. Draws were independent across subgroups; this is exact for regions,
whose sampling strata are nested within region, and approximate for wealth quintiles. The median
agreement between the CCA point ranking and rankings re-drawn from the CCA sampling distribution
provided a sampling-noise benchmark against which method-induced reordering was judged.

### Simulation study (RQ3)

The simulation study was planned and is reported following the ADEMP framework (aims, data-generating
mechanisms, estimands, methods, performance measures) [18]. The full protocol, including a documented
amendment made after the pilot, is available with the analysis code.

**Aims.** To estimate the bias, precision and CI coverage of each method for survey-weighted stunting and
wasting prevalence under MCAR, MAR and MNAR outcome missingness, and the recovery of the true regional
ranking.

**Data-generating mechanisms.** A pseudo-population was formed from the children with valid HAZ and WHZ
and observed maternal covariates (n = 6,247), and its survey-weighted prevalences were taken as the true
values. Each replicate proceeded in two steps. First, a new survey sample was drawn by the Rao–Wu
rescaling bootstrap [19]: within each stratum, n_h − 1 PSUs were drawn with replacement from the
n_h available and weights were rescaled, so that replicate-to-replicate variation reflects the complex
sampling design as well as missingness. One stratum with only two PSUs was merged with the rural
stratum of the same region for this purpose. Second, HAZ and WHZ were deleted jointly, mirroring the
dominant pattern in the survey, where all 178 children with missing (non-flagged) WHZ had not been
measured and also lacked HAZ. The probability of missingness followed a logistic model under four
mechanisms:

- **MCAR:** constant probability.
- **MAR:** the linear predictor of a logistic regression of observed missingness on region, residence,
  wealth quintile, sex, age band, mother's interview status and household size, fitted to the 6,682
  children, calibrating the mechanism to the survey's actual missingness pattern.
- **Strong MAR:** log(2) multiplied by each of the standardised covariate-predicted logits of stunting
  and of wasting, from pseudo-population logistic regressions on the auxiliary variables used by the
  IPW and MI models. The odds of missingness therefore doubled per standard deviation of predicted
  undernutrition risk.
- **MNAR:** the MAR linear predictor plus log(2) multiplied by each of the negative standardised HAZ and
  WHZ, so that the odds of missingness doubled per standard deviation lower z-score, given covariates.

The intercept was solved numerically in each replicate to give expected missingness proportions of
10%, 30% and 50%, yielding 12 scenarios. The strong-MAR mechanism was added after a pilot (20
replicates per scenario) showed that the calibrated MAR mechanism induced negligible CCA bias; it
has the same structure and strength as the MNAR mechanism, driven by predicted risk and not by the
outcome itself.

**Estimands.** National stunting and wasting prevalence (primary); prevalence by region and wealth
quintile, and the true regional ranking and top-five set (secondary).

**Methods.** CCA, IPW, MI-PMM and MI-RF as described above, except that MI used 10 imputations and 10
iterations, and MI-RF used 10 trees (the mice default), to make the study computationally feasible.
Because no covariates are missing in the pseudo-population, CCA with complete covariates coincides with
CCA and was omitted. The estimate from each bootstrap sample before deletion ("complete data") served as
a benchmark for the calibration of the resampling and variance estimation. In a sub-study (MAR, 30%
missing; 200 replicates), MI-RF was repeated with 50 trees.

**Performance measures.** Bias, relative bias, empirical and average model-based standard errors, their
ratio, root mean squared error, 95% CI coverage and mean CI width, each with Monte Carlo standard errors
[18]; and, for regions, mean absolute bias and coverage across subgroups, the mean Spearman correlation
between estimated and true rankings, mean top-five overlap and the proportion of replicates recovering
the true top five and the true worst-affected region. With 500 replicates per scenario, the Monte Carlo
standard error of coverage is 0.97 percentage points at a true coverage of 95% and at most 2.2 percentage
points. Each replicate used its own random-number seed and was stored on completion, so that any
replicate can be reproduced individually.

### Software and reproducibility

Analyses were conducted in R 4.5.1 [20] using survey 4.5 [4], mice 3.19.0 [8], ranger 0.18.0 [14],
haven 2.5.5, dplyr 1.2.1, ggplot2 4.0.2 and gt 1.3.0; package versions are recorded with renv. The
global random seed was 20210301. The complete pipeline, from reading the recode files to producing every
table and figure, is scripted; apart from the published reference values used for validation, no number
was entered by hand. Analysis code is available at
https://github.com/valofils/missing-data-methods-madagascar-dhs; the DHS microdata are available from The DHS Program on registration and
are not redistributed.

## Declarations (excerpt)

**Ethics approval and consent to participate.** This study is a secondary analysis of anonymised
survey data. The EDSMD-V 2021 protocol, including biomarker collection, was reviewed and approved by the
Biomedical Research Ethics Committee of the Ministry of Public Health of Madagascar and by the ICF
ethics committee, and informed consent was obtained before biomarker measurement, as described in the
survey report [1]. Data were obtained from The DHS Program under its terms of use. The present
analysis used anonymised data and required no additional ethical approval.

## References

1. Institut National de la Statistique (INSTAT), ICF. Enquête Démographique et de Santé à Madagascar,
   2021. Antananarivo, Madagascar and Rockville, Maryland, USA: INSTAT and ICF; 2022.
2. WHO Multicentre Growth Reference Study Group. WHO Child Growth Standards based on length/height,
   weight and age. Acta Paediatr Suppl. 2006;450:76–85.
3. Croft TN, Allen CK, Zachary BW, et al. Guide to DHS Statistics: DHS-8. Rockville, Maryland, USA: ICF;
   2023.
4. Lumley T. Analysis of complex survey samples. J Stat Softw. 2004;9(8):1–19.
5. Rao JNK, Scott AJ. On chi-squared tests for multiway contingency tables with cell proportions
   estimated from survey data. Ann Stat. 1984;12(1):46–60.
6. Little RJA, Rubin DB. Statistical analysis with missing data. 3rd ed. Hoboken, NJ: Wiley; 2019.
7. Seaman SR, White IR. Review of inverse probability weighting for dealing with missing data. Stat
   Methods Med Res. 2013;22(3):278–95.
8. van Buuren S, Groothuis-Oudshoorn K. mice: Multivariate Imputation by Chained Equations in R. J Stat
   Softw. 2011;45(3):1–67.
9. White IR, Royston P, Wood AM. Multiple imputation using chained equations: issues and guidance for
   practice. Stat Med. 2011;30(4):377–99.
10. Morris TP, White IR, Royston P. Tuning multiple imputation by predictive mean matching and local
    residual draws. BMC Med Res Methodol. 2014;14:75.
11. Reiter JP, Raghunathan TE, Kinney SK. The importance of modeling the sampling design in multiple
    imputation for missing data. Surv Methodol. 2006;32(2):143–9.
12. Doove LL, Van Buuren S, Dusseldorp E. Recursive partitioning for missing data imputation in the
    presence of interaction effects. Comput Stat Data Anal. 2014;72:92–104.
13. Shah AD, Bartlett JW, Carpenter J, Nicholas O, Hemingway H. Comparison of random forest and
    parametric imputation models for imputing missing data using MICE: a CALIBER study. Am J Epidemiol.
    2014;179(6):764–74.
14. Wright MN, Ziegler A. ranger: a fast implementation of random forests for high dimensional data in
    C++ and R. J Stat Softw. 2017;77(1):1–17.
15. Rubin DB. Multiple imputation for nonresponse in surveys. New York: Wiley; 1987.
16. Barnard J, Rubin DB. Small-sample degrees of freedom with multiple imputation. Biometrika.
    1999;86(4):948–55.
17. Marshall A, Altman DG, Holder RL, Royston P. Combining estimates of interest in prognostic modelling
    studies after multiple imputation: current practice and guidelines. BMC Med Res Methodol. 2009;9:57.
18. Morris TP, White IR, Crowther MJ. Using simulation studies to evaluate statistical methods. Stat Med.
    2019;38(11):2074–102.
19. Rao JNK, Wu CFJ. Resampling inference with complex survey data. J Am Stat Assoc.
    1988;83(401):231–41.
20. R Core Team. R: a language and environment for statistical computing. Vienna, Austria: R Foundation
    for Statistical Computing; 2025.
