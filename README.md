
<!-- README.md is generated from README.Rmd. Please edit that file -->

# pvOmega

<!-- badges: start -->

<!-- badges: end -->

The goal of pvOmega is to detect drug-drug-event statistical patterns
supporting hypotheses generation on drug-drug interactions in databases
of adverse event reports.

## Installation

You can install the development version of pvOmega like so:

``` r
install.packages("devtools")
devtools::install_github("fusarolimichele/DiAna_package")
```

and upload the library like so:

``` r
library("pvOmega")
```

## What Omega measures

Omega (Noren et al. 2008) is a disproportionality measure for
drug-drug-event combination. It compares the observed number of reports
listing two drugs and an adverse event with the number expected if the
two drugs did not interact.

“No interaction” is defined by an **additive** model: the reporting rate
of the event under both drugs is the background reporting rate plus the
contribution attributable to each drug. This is the key difference from
logistic regression, whose interaction term assumes multiplicative
effects of separate drugs and misses well-established interactions such
as cerivastatin with gemfibrozil.

The steps are:

1.  Count the reports in each of the four exposure strata: neither drug,
    D1 only, D2 only, both drugs.
2.  Compute the relative reporting rate of the event in each stratum:
    `f00`, `f10`, `f01`, `f11`.
3.  Estimate the expected rate under both drugs, `g11`, from `f00`,
    `f10` and `f01` only (eq. 16 of the paper).
4.  Compute the expected count `E111 = g11 * n11.`.
5.  Compute the shrunk ratio `omega = log2((n111 + 0.5) / (E111 + 0.5))`
    and its Gamma credibility interval.

A potential interaction is highlighted when `omega_lower` is above 0.

## Starting from counts

`omega_from_counts()` works with any data source. The example below is
the first case study of the paper: delayed bleeding with itraconazole
and oral contraceptives.

``` r
res <- omega_from_counts(
  n111 = 10, n11. = 23, n1.1 = 10, n.11 = 19,
  n1.. = 39, n.1. = 1489, n..1 = 39, n... = 5503
)
res[, .(f00, f10, f01, f11, g11, E111, omega, omega_lower, omega_upper)]
#>            f00   f10         f01       f11         g11      E111   omega
#>          <num> <num>       <num>     <num>       <num>     <num>   <num>
#> 1: 0.005002501     0 0.006139154 0.4347826 0.006139154 0.1412005 4.03347
#>    omega_lower omega_upper
#>          <num>       <num>
#> 1:    3.003327    4.790041
```

## Starting from DiAna FAERS data

With the DiAna data and package imported, the DiAna function
`omega_analysis()` computes all counts and returns one row per
drug1-drug2-event combination (script not run).

``` r
library(DiAna)
FAERS_version <- "24Q4"
import("DEMO")
import("DRUG")
import("REAC")

res <- omega_analysis(
  drug1_selected = "miconazole",
  drug2_selected = "warfarin",
  reac_selected = c("international normalised ratio increased", "haemorrhage"),
  restriction = Demo[!RB_duplicates_only_susp]$primaryid
)
res
```

Groups of terms can be collapsed with lists, as in DiAna:

``` r
omega_analysis(
  drug1_selected = list(statins = c("simvastatin", "atorvastatin")),
  drug2_selected = "clarithromycin",
  reac_selected = list(muscle = c("rhabdomyolysis", "myopathy", "myalgia"))
)
```

## Methodological choices to report

Three choices for the parameters in the DiAna function
`omega_analysis()` change the counts, and should be stated in any
publication:

- **Drug roles** (`drug_roles`). By default only primary suspect,
  secondary suspect and interacting drugs count as exposure, as at
  Uppsala Monitoring Centre. Reports where a drug is only concomitant
  fall into the background stratum.
- **Deduplication** (`restriction`). FAERS contains duplicate reports.
  Pass the primary IDs retained by one of DiAna’s deduplication
  algorithms.
- **Report universe**. The total `n...` is the number of distinct
  reports in `temp_reac` (within `restriction`). Every count refers to
  this population.

## Interpreting results

As recommended in the original paper, do not read Omega in isolation.
The columns `f00`, `f10`, `f01` and `f11` show why a combination was
highlighted. For example, a large `f10` means D1 alone already explains
much of the reporting.

## References

Noren GN, Sundberg R, Bate A, Edwards IR. A statistical methodology for
drug-drug interaction surveillance. *Stat Med*. 2008;27(16):3057-70.

Hult S, Sartori D, Bergvall T, et al. A feasibility study of drug-drug
interaction signal detection in regular pharmacovigilance. *Drug Saf*.
2020;43:775-85.
