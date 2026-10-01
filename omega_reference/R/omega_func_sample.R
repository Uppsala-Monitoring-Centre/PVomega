# D1 = itraconazole
# D2 = oral contraceptives
# A = delayed bleeding

n111 <- 10
n11. <- 23
n1.1 <- 10
n.11 <- 19
n1.. <- 39
n.1. <- 1489
n..1 <- 39
n... <- 5503
f00 <- 0.005
f10 <- 0
f11 <- 0.43
g11 <- 0.0061

E111 = g11 * n11.


omega <- log2((n111+0.5)/(E111+0.5))


library(DiAna)
FAERS_version <- "24Q4"
import("DEMO")
import("DRUG")
import("REAC")

reac_selected <- "nausea"
drug_selected1 <- "miconazole"
drug_selected2 <- "ethinylestradiol"
temp_drug <- Drug[substance %in% c(drug_selected1, drug_selected2)]
temp_reac <- Reac[pt %in%  reac_selected]
pids_drug1 <- unique(temp_drug[substance == drug_selected1]$primaryid)
pids_drug2 <- unique(temp_drug[substance == drug_selected2]$primaryid)
pids_reac <- unique(temp_reac$primaryid)
pids_tot <- Demo$primaryid

n111 <- length(intersect(intersect(pids_drug1, pids_drug2), pids_reac))
n11. <- length(intersect(pids_drug1, pids_drug2))
n001 <- length(setdiff(pids_reac, union(pids_drug1, pids_drug2)))
n00. <- length(setdiff(pids_tot, union(pids_drug1, pids_drug2)))
n101 <- length(setdiff(intersect(pids_drug1, pids_reac), pids_drug2))
n10. <- length(setdiff(intersect(pids_drug1, pids_tot), pids_drug2))
n011 <- length(setdiff(intersect(pids_drug2, pids_reac), pids_drug1))
n01. <- length(setdiff(intersect(pids_drug2, pids_tot), pids_drug1))

f00 <-  n001/n00.
f10 <- n101/n10.
f01 <- n011/n01.

g11 <- 1 - 1/(max(f00/(1-f00), f10/(1-f10)) + max(f00/(1-f00), f01/(1-f01)) - f00/(1-f00) + 1)
E111 = g11 * n11.
omega <- log2((n111+0.5)/(E111+0.5))

