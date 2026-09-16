---
title: "Discussion (draft)"
subtitle: "Missing-data methods and equity estimates of child undernutrition: Madagascar DHS 2021"
date: "Draft of 13 September 2026 — for author review"
---

> **Drafting notes (delete before submission).**
>
> 1. RQ1/RQ2 statements are consistent with `results_rq1_rq2_draft.md` and RQ3 statements with
>    `results_rq3_draft.md` (full run: 12 scenarios x 500 replicates, completed 16 September 2026).
>    Numbers are repeated only where needed for interpretation.
> 2. References continue the numbering of the Methods draft (1-20) and must be renumbered in order of
>    first citation when the manuscript is assembled. **Verify every reference before submission.**
> 3. Items marked **[CONFIRM]** need an author decision.

## Discussion

### Principal findings

In the 2021 Madagascar DHS, the choice of missing-data method barely affected estimates of child
undernutrition. National stunting and wasting prevalence under inverse probability weighting and two
forms of multiple imputation differed from complete-case estimates by a few hundredths of a
percentage point, and CIs were practically identical. Subgroup estimates moved more, by up to
1.6 percentage points for regional stunting, but concordance between regional and wealth-quintile
rankings was very high. The five worst-affected regions were identical under CCA, IPW, MI-PMM and
MI-RF. The two changes to that set occurred only when analysis was restricted to children with complete
maternal covariates, an approach that changes the target population, not the estimator.

The more consequential finding concerns uncertainty, not bias. Sampling error alone reordered
regional rankings far more than any change of method: the median Spearman correlation between the
complete-case ranking and rankings re-drawn from its own sampling distribution was 0.93 for stunting
and 0.88 for wasting, whereas agreement between methods never fell below 0.987. No region's place
among the five most stunted was secure, and the regions whose worst-affected status depended on the
method were precisely those with the most uncertain rank. For decisions about geographic targeting,
the uncertainty inherent in ranking 23 survey domains outweighed the choice of missing-data method in
this survey.

The simulation showed when that agreement can be expected and when it cannot. Under MCAR and under
the mechanism calibrated to the survey's own missingness, all four methods were essentially unbiased
at 10-50% missingness, reproducing what we observed empirically. Under strong MAR, where missingness
depended on covariate-predicted undernutrition risk, the methods diverged sharply: at 50% missingness
complete-case analysis under-estimated stunting by 3.68 pp with 11% CI coverage, IPW was unbiased
(-0.04 pp) with 94.8% coverage, and multiple imputation removed most but not all of the bias
(-0.90 pp for MI-PMM, -1.69 pp for MI-RF). Under MNAR no method recovered the truth: all were biased
by about -10 pp at 50% missingness with zero coverage. Recovery of the regional ranking, by contrast,
was poor in every scenario, including with complete data.

### Why the methods agreed

Three features of these data explain the agreement, and they indicate when it cannot be assumed.
First, outcome missingness was low: about 4% of children lacked a valid HAZ and 3% a valid WHZ.
The bias of a complete-case estimate is bounded by the proportion missing, so with so few missing
outcomes even a selective mechanism can shift national prevalence only slightly. Second, although
missingness was clearly not completely at random, it was concentrated in small groups. It reached
44.6% among children whose mother's interview was incomplete, but that group comprised 193 children,
whereas missingness was 2.4% among the large majority whose mother was interviewed. Such concentrated
selection has little leverage on the national estimate unless those groups differ greatly in outcome.
Third, IPW and both MI methods drew on largely the same auxiliary information, so under MAR given those
covariates they target the same estimand and would be expected to agree with each other. They differ
from CCA only to the extent that the covariates predicting missingness also predict the outcome.

The largest subgroup differences arose where these conditions weakened. Androy had the highest
proportion of children without a valid HAZ, and IPW lowered its stunting estimate by 1.6 percentage
points. That region-specific correction is plausible, but it rests entirely on the MAR assumption
within a single domain of fewer than 500 children, and its magnitude was well within the region's
sampling uncertainty. It illustrates that national agreement does not guarantee agreement within
subgroups where missingness is concentrated.

These findings agree with guidance that the proportion of missing data alone is a poor guide to
analysis strategy, and that complete-case analysis can be adequate when missingness is low and
plausibly unrelated to the outcome given the design [21,22]. They also show that such adequacy should
be demonstrated, not assumed, particularly for subnational estimates. A framework such as TARMOS,
which asks analysts to state the plausible missingness mechanisms and check the robustness of
conclusions, fits this purpose well [23].

The simulation supports this reading. The mechanism calibrated to the survey's own missingness
produced almost no bias in complete-case estimates (at most 0.09 pp for stunting at 50% missingness),
which is why the methods agreed on the observed data. Selective missingness only became consequential
when it was tied to the outcome's own predictors: the strong-MAR mechanism, with the same structure
and strength but driven by predicted undernutrition risk, produced complete-case bias of -2.18 pp at
30% missingness. The practical implication is that the observed agreement is a property of this
survey's missingness pattern, not a general result.

### Flagged measurements

Flagged z-scores are handled inconsistently in practice. DHS reports exclude them, and cleaning
criteria are known to change malnutrition prevalence estimates [24]. We treated them as a distinct form
of missingness in the main analysis and excluded them in a sensitivity analysis. With 23 flagged HAZ
and 26 flagged WHZ values among 6,682 children, the choice made no material difference here: national
estimates changed by about 0.05 percentage points or less. In surveys with poorer anthropometric data
quality, where flag rates are higher [25,26], the choice could matter more. Imputing flagged values
under MAR assumes that the plausible range of the true measurement can be predicted from covariates.
That assumption is questionable if flags arise from extreme true values, and less so if they arise
from recording error.

### Implications for survey analysis and targeting

Our results suggest three practical recommendations for analysts using DHS-type surveys to rank
subnational units.

1. **Report rank uncertainty.** Point rankings of survey domains should be accompanied by probabilities
   of membership in the targeted set or by rank intervals, as has long been recommended for league
   tables of institutional performance [27,28]. In this survey, even the region with the highest
   stunting prevalence had only about a one-in-three probability of truly ranking first.
2. **Check robustness at the subgroup level.** Missing-data sensitivity analyses should be reported for
   the subgroup estimates used for targeting, not only for national prevalence. Regions with the
   highest missingness are those where methods are most likely to diverge.
3. **Avoid restricting to complete covariates.** Restricting to records complete for auxiliary
   variables changed the worst-affected set in both outcomes. Here it excluded children whose mother
   lived in the household but could not be linked to an interview, a group with very high outcome
   missingness, and it changes the population to which estimates apply. Structurally inapplicable
   values, such as maternal characteristics for children whose mother lives elsewhere, should be coded
   as such, not treated as missing.

4. **Prefer response weighting, or imputation with well-calibrated variance, when missingness is
   selective.** In the simulation IPW was the only method that stayed unbiased with nominal coverage
   under strong MAR, while both imputation approaches retained residual bias. MI-RF additionally
   understated uncertainty: its standard errors were 13-19% too small in the highest-missingness
   scenarios, and coverage fell to 63% under strong MAR at 50% missingness. Where random-forest
   imputation is used, the number of trees should be checked: raising it from 10 (the mice default)
   to 50 restored calibration in our sub-study, though it did not remove the bias.

Where ranking precision is itself the problem, borrowing strength across areas through small-area
estimation methods may be more useful than refining the treatment of a few percent of missing
outcomes [29].

### Strengths and limitations

The analysis has several strengths:

- **Validated baseline.** Before any method was applied, the complete-case baseline reproduced every
  cell of the survey's published nutrition table and its sampling errors.
- **Design-based inference throughout,** including within multiple imputation.
- **Missingness taxonomy.** Structural missingness (children whose mother does not live in the
  household) was distinguished from genuine missingness, and flagged values from unmeasured children.
- **Transparent simulation.** The simulation followed a pre-specified protocol that recorded one
  amendment made after the pilot.
- **Reproducibility.** The whole pipeline is scripted and openly available; no microdata are
  redistributed.

The study also has limitations:

- **Untestable MAR assumption.** IPW and MI assume MAR given the auxiliary variables. The observed
  data cannot rule out MNAR, for example if children who were absent at measurement were systematically
  more or less undernourished than similar children who were measured. The observed-data analyses
  therefore compare methods that share this assumption; they do not establish that any is unbiased.
  Sensitivity analyses that relax MAR, such as delta-adjusted multiple imputation [30] or selection
  models [31], would complement this work. The MNAR simulation quantifies what is at stake rather
  than resolving it: when missingness depended on the z-score itself, every method was biased by a
  similar amount and no confidence interval covered the truth at 30% missingness or above, with IPW
  and MI reducing complete-case bias by at most 8%.
- **Imputation model.** The model included stratum-defining variables and the design weight but not
  cluster-level random effects, which may slightly understate between-cluster variation in imputed
  values. Weight-for-age was excluded to achieve convergence.
- **Variance estimation.** IPW treated estimated weights as fixed. MI used 20 imputations, and we did not
  quantify the Monte Carlo error of MI point estimates, so differences of a few hundredths of a
  percentage point between methods should not be interpreted.
- **Ranking analysis.** The top-five threshold is a convenient illustration, not a policy rule, and
  simulated rankings of wealth quintiles assumed independence across quintiles.
- **Survey scope.** The survey's 23 domains predate the division of Vatovavy Fitovinany into two
  regions. The findings come from a single survey with low missingness and may not transfer to surveys
  with higher or differently structured missingness. The simulation extends the range of missingness
  studied to 50%, but within the same pseudo-population and design, and it deletes HAZ and WHZ
  together; the smaller HAZ-only pattern seen in the survey (1.2% of children) was not simulated.

### Conclusions

In the 2021 Madagascar DHS, complete-case analysis, inverse probability weighting and multiple
imputation gave practically identical national estimates of stunting and wasting and nearly identical
subnational rankings. The worst-affected set changed only under restriction to complete covariates.
Sampling uncertainty in subnational rankings was substantially larger than the effect of the
missing-data method, and should be reported alongside any ranking used for targeting.
In simulation, this equivalence held under missingness completely at random and under the mechanism
calibrated to the survey, but not when missingness was strongly tied to covariate-predicted
undernutrition risk: there only inverse probability weighting remained unbiased with valid coverage,
while complete-case analysis was substantially biased. No method compensated for missingness that
depended on the measurement itself.

## References (continuing from Methods, 1–20)

21. Hughes RA, Heron J, Sterne JAC, Tilling K. Accounting for missing data in statistical analyses:
    multiple imputation is not always the answer. Int J Epidemiol. 2019;48(4):1294–304.
22. Jakobsen JC, Gluud C, Wetterslev J, Winkel P. When and how should multiple imputation be used for
    handling missing data in randomised clinical trials – a practical guide with flowcharts. BMC Med Res
    Methodol. 2017;17:162.
23. Lee KJ, Tilling KM, Cornish RP, Little RJA, Bell ML, Goetghebeur E, et al. Framework for the
    treatment and reporting of missing data in observational studies: the Treatment And Reporting of
    Missing data in Observational Studies framework. J Clin Epidemiol. 2021;134:79–88.
24. Crowe S, Seal A, Grijalva-Eternod C, Kerac M. Effect of nutrition survey 'cleaning criteria' on
    estimates of malnutrition prevalence and disease burden: secondary data analysis. PeerJ.
    2014;2:e380.
25. Assaf S, Kothari MT, Pullum T. An assessment of the quality of DHS anthropometric data, 2005–2014.
    DHS Methodological Reports No. 16. Rockville, Maryland, USA: ICF International; 2015.
26. Perumal N, Namaste S, Qamar H, Aimone A, Bassani DG, Roth DE. Anthropometric data quality assessment
    in multisurvey studies of child growth. Am J Clin Nutr. 2020;112(Suppl 2):806S–815S.
27. Goldstein H, Spiegelhalter DJ. League tables and their limitations: statistical issues in comparisons
    of institutional performance. J R Stat Soc Ser A Stat Soc. 1996;159(3):385–443.
28. Marshall EC, Spiegelhalter DJ. Reliability of league tables of in vitro fertilisation clinics:
    retrospective analysis of live birth rates. BMJ. 1998;316(7146):1701–5.
29. Mercer LD, Wakefield J, Pantazis A, Lutambi AM, Masanja H, Clark S. Space–time smoothing of complex
    survey data: small area estimation for child mortality. Ann Appl Stat. 2015;9(4):1889–905.
30. Leacy FP, Floyd S, Yates TA, White IR. Analyses of sensitivity to the missing-at-random assumption
    using multiple imputation with delta adjustment: application to a tuberculosis/HIV prevalence survey
    with incomplete HIV-status data. Am J Epidemiol. 2017;185(4):304–15.
31. Bärnighausen T, Bor J, Wandira-Kazibwe S, Canning D. Correcting HIV prevalence estimates for survey
    nonparticipation using Heckman-type selection models. Epidemiology. 2011;22(1):27–35.
