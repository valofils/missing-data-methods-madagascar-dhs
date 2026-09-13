# 02_derive_variables.R — analysis population, z-scores, flags, outcomes, covariates
#
# ANTHROPOMETRY SOURCE DECISION
#   Source: PR (household member) file, HC70/HC71/HC72, de facto children (hv103 == 1)
#   aged 0-59 months (hc1 < 60). This is the DHS Guide to Statistics (DHS-8) definition
#   used for the Final Report nutrition tables. It also covers children whose mother is
#   not interviewed/not in the household, which the KR file omits.
#   Cross-check against KR (HW70) is reported in 05_validation.R.
#   STATUS: reproduces EDSMD-V 2021 Final Report Table 11.1 and Appendix B sampling
#   errors (see R/05_validation.R, outputs/validation/).
#
# FLAG / MISSING CODES (confirmed in MDPR81FL.MAP, HC70-HC72):
#   -600:600 (HAZ) / -600:500 (WAZ, WHZ)  valid, stored x100
#   9996  Height out of plausible limits
#   9997  Age in days out of plausible limits
#   9998  Flagged cases (WHO implausible z-score)
#   9999  Missing (read by haven as NA)  |  (na) Not applicable -> NA
#   Flagged (9996-9998) and not-measured (NA) are kept distinct in *_status.

source(here::here("R", "00_setup.R"))
pr_raw <- readRDS(file.path(paths$derived, "pr_raw.rds"))

z_status <- function(x) {
  x <- zap_labels(x)
  case_when(
    is.na(x)             ~ "missing",
    x %in% 9996:9998     ~ "flagged",
    x >= -600 & x <= 600 ~ "valid",
    TRUE                 ~ "other_code"
  )
}
z_value <- function(x) {
  x <- zap_labels(x)
  ifelse(!is.na(x) & x >= -600 & x <= 600, x / 100, NA_real_)
}
lab <- function(x) droplevels(as_factor(x))

# hv024 codes. The Final Report (Table 11.1, Appendix B.5-B.6) treats Antananarivo (code 10)
# as its own domain; code 11, labelled "Analamanga" in the MAP file, is the report's
# "Analamanga sans Antananarivo" (48.3% stunted in both). The report's combined
# "Analamanga" row is not a separate code and is not used as a subgroup here.
region_labels <- c(
  "10" = "Antananarivo", "11" = "Analamanga (excl. Antananarivo)", "12" = "Vakinankaratra",
  "13" = "Itasy", "14" = "Bongolava", "21" = "Haute Matsiatra", "22" = "Amoron'i Mania",
  "23" = "Vatovavy Fitovinany", "24" = "Ihorombe", "25" = "Atsimo Atsinanana",
  "31" = "Atsinanana", "32" = "Analanjirofo", "33" = "Alaotra Mangoro", "41" = "Boeny",
  "42" = "Sofia", "43" = "Betsiboka", "44" = "Melaky", "51" = "Atsimo Andrefana",
  "52" = "Androy", "53" = "Anosy", "54" = "Menabe", "61" = "Diana", "62" = "Sava"
)

kids <- pr_raw %>%
  filter(hv103 == 1, !is.na(hc1), hc1 < 60) %>%
  # mother's age: from the mother's own PR roster line (hc60 = line number, if in household)
  left_join(
    pr_raw %>% transmute(hv001, hv002, hc60 = hvidx, mother_age = zap_labels(hv105)),
    by = c("hv001", "hv002", "hc60")
  ) %>%
  mutate(
    # design (weights divided by 1,000,000)
    wt      = hv005 / 1e6,
    psu     = hv021,
    stratum = hv022,
    # subgroup axes and auxiliary covariates
    region    = factor(zap_labels(hv024), levels = names(region_labels), labels = region_labels),
    residence = factor(zap_labels(hv025), levels = 1:2, labels = c("Urban", "Rural")),
    wealth    = factor(zap_labels(hv270), levels = 1:5,
                       labels = c("Poorest", "Poorer", "Middle", "Richer", "Richest")),
    sex       = factor(zap_labels(hc27), levels = 1:2, labels = c("Male", "Female")),
    age_m     = as.numeric(hc1),
    # age bands as in Final Report Table 11.1
    age_grp   = cut(age_m, c(-Inf, 5, 8, 11, 17, 23, 35, 47, 59),
                    labels = c("<6", "6-8", "9-11", "12-17", "18-23", "24-35", "36-47", "48-59")),
    # MOTHER COVARIATES — structural vs. genuine missingness (hc60 codes, MDPR81FL.MAP)
    #   hc60 1:50  mother listed and interviewed (line number known -> age from roster)
    #   hc60 993   mother in household but not de facto   -> age unknown (impute)
    #   hc60 994   mother's interview incomplete           -> age unknown (impute)
    #   hc60 995   mother not in household (incl. deceased) -> STRUCTURAL: not applicable
    # Structural cases get their own level ("Not in household") / placeholder age 0 and are
    # never imputed; mother_status carries that information in every model.
    # hc61 == 8 ("Don't know", n = 6) is genuine missingness -> NA, imputed.
    mother_status = factor(
      case_when(hc60 %in% 1:50 ~ "Interviewed", hc60 == 993 ~ "Not de facto",
                hc60 == 994 ~ "Interview incomplete", hc60 == 995 ~ "Not in household"),
      levels = c("Interviewed", "Not de facto", "Interview incomplete", "Not in household")),
    mother_edu = factor(
      case_when(hc60 == 995 ~ "Not in household",
                hc61 %in% 0 ~ "None", hc61 %in% 1 ~ "Primary",
                hc61 %in% 2:3 ~ "Secondary+", TRUE ~ NA_character_),
      levels = c("None", "Primary", "Secondary+", "Not in household")),
    mother_age = case_when(hc60 == 995 ~ 0, mother_age %in% 15:95 ~ as.numeric(mother_age),
                           TRUE ~ NA_real_),
    hh_size    = as.numeric(hv009),
    measure_result = lab(hc13),
    # z-scores and their status
    haz = z_value(hc70), haz_status = z_status(hc70),
    waz = z_value(hc71), waz_status = z_status(hc71),
    whz = z_value(hc72), whz_status = z_status(hc72),
    # outcomes (NA when z-score not valid)
    stunted     = as.integer(haz < -2), sev_stunted = as.integer(haz < -3),
    wasted      = as.integer(whz < -2), sev_wasted  = as.integer(whz < -3),
    underweight = as.integer(waz < -2), sev_underweight = as.integer(waz < -3)
  ) %>%
  select(hv001, hv002, hvidx, wt, psu, stratum, region, residence, wealth, sex, age_m,
         age_grp, mother_status, mother_edu, mother_age, hh_size, measure_result,
         haz, haz_status, waz, waz_status, whz, whz_status,
         stunted, sev_stunted, wasted, sev_wasted, underweight, sev_underweight)

stopifnot(!anyNA(kids$region), !anyNA(kids$wealth), !anyNA(kids$residence), !anyNA(kids$sex),
          !anyNA(kids$mother_status),
          # structural cases never NA; genuine NAs only among mothers in the household
          all(!is.na(kids$mother_edu[kids$mother_status == "Not in household"])),
          all(is.na(kids$mother_age) == (kids$mother_status %in% c("Not de facto", "Interview incomplete"))))

# Guards: no impossible z-scores survive; outcomes defined only where z valid
stopifnot(
  all(abs(kids$haz) <= 6, na.rm = TRUE), all(abs(kids$whz) <= 6, na.rm = TRUE),
  all(is.na(kids$haz) == (kids$haz_status != "valid")),
  all(is.na(kids$whz) == (kids$whz_status != "valid")),
  !any(kids$haz_status == "other_code"), !any(kids$whz_status == "other_code"),
  all(kids$wt > 0)
)

saveRDS(kids, file.path(paths$derived, "kids.rds"))
message("02: de facto children 0-59 m = ", nrow(kids))
