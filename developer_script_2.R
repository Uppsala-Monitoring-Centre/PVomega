# test 'omega_analysis' fct ----------------------------------------------------
# with numbers from Norén 2008

omega_t <- omega_from_counts(
  n111 = 10,
  n11. = 23,
  n1.1 = 10,
  n.11 = 19,
  n1.. = 33,
  n.1. = 1489,
  n..1 = 39,
  n... = 5503,
  alpha = 0.5,
  conf_level = 0.95,
  ci_method <- "gamma"
)

# test 'omega_analysis' fct ----------------------------------------------------

# on DiAna sample data
library(DiAna)

omega_analysis(
  drug1_selected = "paracetamol",
  drug2_selected = "ibuprofen",
  reac_selected = "overdose",
  temp_drug = DiAna::sample_Drug,
  temp_reac = DiAna::sample_Reac
)


# Import FAERS data
library(data.table)

data_dir <- Sys.getenv("FAERS_DATA_DIR")
Drug <- setDT(readRDS(file.path(data_dir, "DRUG.rds")))
Reac <- setDT(readRDS(file.path(data_dir, "REAC.rds")))

omega_analysis(
  drug1_selected = "gemfibrozil",
  drug2_selected = "cerivastatin",
  reac_selected = "rhabdomyolysis"
)

pidsD1 <- Drug[role_cod %in% c("PS", "SS", "I")][substance == "gemfibrozil"]$primaryid
pidsD2 <- Drug[role_cod %in% c("PS", "SS", "I")][substance == "cerivastatin"]$primaryid
pidsE <- Reac[pt == "rhabdomyolysis"]$primaryid

pidsD1D2E <- intersect(pidsD1, intersect(pidsD2, pidsE))

omega_analysis(
  drug1_selected = "gemfibrozil",
  drug2_selected = "cerivastatin",
  reac_selected = "rhabdomyolysis",
  temp_drug = Drug
)

omega_analysis(
  drug1_selected = "digoxin",
  drug2_selected = "clarithromycin",
  reac_selected = "drug level increased"
)

omega_analysis(
  drug1_selected = "ipilimumab",
  drug2_selected = "nivolumab",
  reac_selected = "hepatitis"
)


omega_analysis(
  drug1_selected = c("ipilimumab", "paracetamol"),
  drug2_selected = "nivolumab",
  reac_selected = "hepatitis"
)

omega_analysis(
  drug1_selected = c("ipilimumab", "paracetamol"),
  drug2_selected = list("PD1PDL1" = c(
    "nivolumab", "pembrolizumab", "atezolizumab",
    "avelumab", "durvalumab", "cemiplimab",
    "tislelizumab", "dostarlimab", "retifanlimab",
    "toripalimab", "cosibelimab"
  )),
  reac_selected = "hepatitis"
)

omega_analysis(
  drug1_selected = c("ipilimumab", "paracetamol"),
  drug2_selected = list("PD1PDL1" = c(
    "nivolumab", "pembrolizumab", "atezolizumab",
    "avelumab", "durvalumab", "cemiplimab",
    "tislelizumab", "dostarlimab", "retifanlimab",
    "toripalimab", "cosibelimab"
  )),
  reac_selected = list("hepatitis" = c("hepatitis", "liver injury"))
)
