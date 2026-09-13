# 04_design.R — survey design helper
# Two-stage stratified cluster sample: PSU = hv021, strata = hv022 (sample strata for
# sampling errors, 45 strata; hv023 is identical in count), weight = hv005 / 1e6.

source(here::here("R", "00_setup.R"))

make_design <- function(data, weights = ~wt) {
  svydesign(ids = ~psu, strata = ~stratum, weights = weights, data = data, nest = TRUE)
}
