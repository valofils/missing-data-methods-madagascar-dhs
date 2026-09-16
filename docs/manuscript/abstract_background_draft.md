---
title: "Abstract and Background (draft)"
subtitle: "Missing-data methods and equity estimates of child undernutrition: Madagascar DHS 2021"
date: "Draft of 16 September 2026 — for author review"
---

> **Drafting notes (delete before submission).** Project numbers come from pipeline outputs
> (`rq1_*`, `rq2_*`, `rq3_*`). References 32–37 are new here; earlier numbers refer to the Methods and
> Discussion drafts, and the whole manuscript must be renumbered in order of first citation when
> assembled. **Verify every reference before submission.** Items marked **[CONFIRM]** need an author
> decision. The abstract is about 340 words. **[CONFIRM the journal's abstract limit.]**

## Abstract

**Background.** Household surveys such as the Demographic and Health Surveys (DHS) are the main source
of subnational estimates of child undernutrition, and are used to decide which regions and which
socioeconomic groups are targeted first. Anthropometric measurements are incomplete in every survey,
yet the analytical treatment of those missing values is rarely examined, and its effect on the
resulting equity ordering is essentially unknown.

**Methods.** We analysed the 2021 Madagascar DHS (6,682 de facto children aged 0–59 months),
comparing four approaches to missing anthropometry under the survey design: complete-case analysis,
inverse probability weighting (IPW), multiple imputation by predictive mean matching (MI-PMM) and
random-forest multiple imputation (MI-RF). We estimated stunting and wasting prevalence nationally and
for 23 regions and 5 wealth quintiles, measured cross-method agreement in subgroup rankings against a
benchmark of sampling variability, and ran a simulation (12 scenarios, 500 replicates each) combining
a survey bootstrap with imposed MCAR, MAR, strong-MAR and MNAR missingness at 10–50%.

**Results.** A valid height-for-age z-score was unavailable for 4.2% of children and a
weight-for-height z-score for 3.1%. Missingness was strongly patterned (44.6% where the mother's
interview was incomplete versus 2.4% where she was interviewed), yet national estimates differed
across methods by at most 0.12 percentage points (complete-case stunting 39.8%, 95% CI 38.0–41.7;
wasting 7.7%, 6.9–8.6). Regional rankings agreed closely across methods (Spearman ρ ≥ 0.987), far more
closely than rankings redrawn from sampling uncertainty alone (median ρ 0.88–0.93). In simulation, all
methods were unbiased under MCAR and under missingness calibrated to the survey itself; under strong
MAR at 50% missingness complete-case analysis was biased by −3.7 percentage points with 11% CI
coverage, while IPW remained unbiased with 95% coverage; under MNAR no method recovered the truth.

**Conclusions.** Here the choice of missing-data method was immaterial, and sampling uncertainty, not
missing data, limited equity targeting. That equivalence reflects low, weakly outcome-related
missingness rather than a general result: when missingness tracked undernutrition risk, only response
weighting remained valid.

**Keywords.** missing data; multiple imputation; inverse probability weighting; complex surveys; child
stunting; health equity; Demographic and Health Surveys; Madagascar

## Background

Child undernutrition remains one of the largest contributors to child mortality and to lifelong
deficits in health, schooling and earnings [32,33]. Stunting, or low height-for-age, affects about one
in five children under 5 worldwide, and progress is uneven both between and within countries [34,35].
Reducing it is a global commitment under the World Health Assembly targets and the Sustainable
Development Goals [36]. In Madagascar, 40% of children under 5 are stunted, among the highest
prevalences in the world **[CONFIRM ranking against the 2023 joint malnutrition estimates]**, and
regional prevalence ranges from about 22% to 52% [1].

Because national averages hide this heterogeneity, nutrition programmes are increasingly targeted
subnationally, and the evidence for those decisions comes almost entirely from household surveys,
above all the DHS [37]. These surveys measure the height and weight of children in sampled households
and publish prevalence by region and wealth quintile; the resulting tables are used to rank areas and
prioritise resources. Two features of such estimates deserve more scrutiny than they usually receive.
First, they carry sampling uncertainty that is substantial in small domains, so the ordering of regions
is itself uncertain. Second, anthropometric data are never complete: children are absent, carers
refuse, and some measurements are implausible and flagged. Reviews of DHS anthropometry show that
incompleteness and flagging vary appreciably between surveys [25,26], and cleaning rules alone can
shift estimated malnutrition prevalence [24].

How missing anthropometry is handled is therefore a methodological choice with potential consequences
for who is identified as worst affected. In practice the choice is usually implicit: survey reports
present complete-case estimates restricted to children with valid measurements, which are unbiased
only if missingness is unrelated to nutritional status given the design and the covariates used [6].
Alternatives are well established in the statistical literature — inverse probability weighting for
nonresponse [7] and multiple imputation, including machine-learning variants [8,12,13] — and guidance
exists on reporting them [23]. What is missing is evidence on what difference they make in this
setting: for prevalence under a complex survey design, for the subnational ranking that drives
targeting, and under missingness mechanisms realistic for anthropometry.

Related work has approached parts of this problem separately. Methodological studies of survey
nonparticipation have concentrated on HIV prevalence, where selection models have been used to correct
estimates for people who decline testing [31], and the statistical literature on ranking has long
warned that league tables of institutions or areas are far less reliable than their point estimates
suggest [27,28]. Studies of DHS anthropometry, in turn, have focused on data quality: how often
measurements are missing, flagged or heaped, and how cleaning rules change prevalence [24,25,26]. What
has not been examined, to our knowledge, is the combination that matters for programme targeting:
whether the analytical treatment of missing anthropometry changes which subnational groups a survey
identifies as worst affected, and how any such change compares with the ranking uncertainty already
present from sampling.

This study addresses that gap using the 2021 Madagascar DHS. We ask three questions. First, how much
do survey-weighted stunting and wasting prevalence differ between complete-case analysis, IPW and two
forms of multiple imputation, nationally and by region and wealth quintile? Second, does the choice of
method change the equity ordering — which regions and quintiles are identified as worst affected — and
how does any such change compare with the uncertainty that sampling error alone places on those
rankings? Third, in a simulation in which the truth is known and the mechanism is controlled, what are
the bias, precision and confidence-interval coverage of each method under MCAR, MAR and MNAR
missingness at rates from 10% to 50%? Throughout, we keep estimation inside the survey design,
distinguish structurally inapplicable values from genuinely missing ones, and validate the pipeline by
reproducing the published survey estimates before any method is compared.

## References (new in this section)

32. Black RE, Victora CG, Walker SP, Bhutta ZA, Christian P, de Onis M, et al. Maternal and child
    undernutrition and overweight in low-income and middle-income countries. Lancet.
    2013;382(9890):427–51.
33. de Onis M, Branca F. Childhood stunting: a global perspective. Matern Child Nutr.
    2016;12(Suppl 1):12–26.
34. UNICEF, World Health Organization, World Bank Group. Levels and trends in child malnutrition:
    UNICEF/WHO/World Bank Group joint child malnutrition estimates, key findings of the 2023 edition.
    Geneva: World Health Organization; 2023.
35. Victora CG, Christian P, Vidaletti LP, Gatica-Domínguez G, Menon P, Black RE. Revisiting maternal
    and child undernutrition in low-income and middle-income countries: variable progress towards an
    unfinished agenda. Lancet. 2021;397(10282):1388–99.
36. World Health Organization. Global nutrition targets 2025: stunting policy brief. Geneva: World
    Health Organization; 2014.
37. Corsi DJ, Neuman M, Finlay JE, Subramanian SV. Demographic and health surveys: a profile. Int J
    Epidemiol. 2012;41(6):1602–13.
