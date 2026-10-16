# Compute Omega from a table of report counts

Convenience wrapper around
[`omega_from_counts()`](https://Uppsala-Monitoring-Centre.github.io/PVomega/reference/omega_from_counts.md)
for tabular input. The input must contain one column for each of the
eight report counts required by
[`omega_from_counts()`](https://Uppsala-Monitoring-Centre.github.io/PVomega/reference/omega_from_counts.md).
Computation is vectorised, so one output row is returned for each input
row.

## Usage

``` r
omega_from_table(x, alpha1 = 0.5, alpha2 = 0.5, cred_level = 0.95)
```

## Arguments

- x:

  A data frame, `data.table`, or other object coercible to a
  `data.frame`, containing the required count columns.

- alpha1:

  Shrinkage tuning parameter for the observed count. Passed to
  [`omega_from_counts()`](https://Uppsala-Monitoring-Centre.github.io/PVomega/reference/omega_from_counts.md).

- alpha2:

  Shrinkage tuning parameter for the expected count. Passed to
  [`omega_from_counts()`](https://Uppsala-Monitoring-Centre.github.io/PVomega/reference/omega_from_counts.md).

- cred_level:

  Level of the two-sided credibility interval. Passed to
  [`omega_from_counts()`](https://Uppsala-Monitoring-Centre.github.io/PVomega/reference/omega_from_counts.md).

## Value

A `data.table` containing the input columns followed by the results from
[`omega_from_counts()`](https://Uppsala-Monitoring-Centre.github.io/PVomega/reference/omega_from_counts.md).

## See also

[`omega_from_counts()`](https://Uppsala-Monitoring-Centre.github.io/PVomega/reference/omega_from_counts.md)

## Examples

``` r
counts <- data.frame(
  drug1 = "itraconazole",
  drug2 = "oral contraceptives",
  event = "delayed bleeding",
  n111 = 10,
  `n11.` = 23,
  `n1.1` = 10,
  `n.11` = 19,
  `n1..` = 39,
  `n.1.` = 1489,
  `n..1` = 39,
  `n...` = 5503,
  check.names = FALSE
)

omega_from_table(counts)
#>           drug1               drug2            event  n1.1  n.11  n1..  n.1.
#>          <char>              <char>           <char> <num> <num> <num> <num>
#> 1: itraconazole oral contraceptives delayed bleeding    10    19    39  1489
#>     n..1  n...  n111  n110  n101  n100  n011  n010  n001  n000  n11.  n10.
#>    <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>
#> 1:    39  5503    10    13     0    16     9  1457    20  3978    23    16
#>     n01.  n00.         f00   f10         f01       f11         g11      E111
#>    <num> <num>       <num> <num>       <num>     <num>       <num>     <num>
#> 1:  1466  3998 0.005002501     0 0.006139154 0.4347826 0.006139154 0.1412005
#>      omega omega_lower omega_upper
#>      <num>       <num>       <num>
#> 1: 4.03347    3.003327    4.790041
```
