# Compute Omega from report counts

Computes the Omega shrinkage observed-to-expected ratio for a
drug-drug-event triplet (Noren et al. 2008), together with its
credibility interval and all intermediate quantities. The function is
vectorised: every count argument can be a vector, and one row is
returned per element.

## Usage

``` r
omega_from_counts(
  n111,
  n11.,
  n1.1,
  n.11,
  n1..,
  n.1.,
  n..1,
  n...,
  alpha1 = 0.5,
  alpha2 = 0.5,
  cred_level = 0.95
)
```

## Arguments

- n111:

  Reports listing D1, D2 and the event.

- n11.:

  Reports listing D1 and D2.

- n1.1:

  Reports listing D1 and the event.

- n.11:

  Reports listing D2 and the event.

- n1..:

  Reports listing D1.

- n.1.:

  Reports listing D2.

- n..1:

  Reports listing the event.

- n...:

  Total number of reports.

- alpha1:

  Shrinkage added to the observed count: the shape of the Gamma prior
  (default 0.5, as in the paper). Must be \>= 0.

- alpha2:

  Shrinkage added to the expected count: the rate of the Gamma prior
  (default 0.5, as in the paper). Must be \>= 0.

- cred_level:

  Level of the two-sided credibility interval (default 0.95, giving
  Omega025 and Omega975).

## Value

A `data.table` with one row per element of the inputs and columns:

- the input marginal counts `n1.1`, `n.11`, `n1..`, `n.1.`, `n..1`,
  `n...`;

- the eight cells of the 2x2x2 contingency table, named by presence (1)
  or absence (0) of D1, D2 and the event: `n111`, `n110`, `n101`,
  `n100`, `n011`, `n010`, `n001`, `n000` (they sum to `n...`);

- the four exposure strata totals `n11.`, `n10.`, `n01.`, `n00.`;

- `f00`, `f10`, `f01`, `f11`, `g11`, the expected count `E111`, `omega`,
  `omega_lower`, `omega_upper`. Each `f` is `NA` when its stratum is
  empty; `g11`, `E111` and the Omega columns are `NA` for rows where
  Omega cannot be computed (see Details).

## Details

The expected relative reporting rate under the additive-risk baseline
model is (eq. 16 of Noren et al. 2008)

\$\$g\_{11} = 1 - \frac{1}{\max(o\_{00}, o\_{10}) + \max(o\_{00},
o\_{01}) - o\_{00} + 1}\$\$

where \\o\_{ij} = f\_{ij} / (1 - f\_{ij})\\ and \\f\_{ij}\\ is the
relative reporting rate of the event in the stratum exposed to D1 (`i`)
and D2 (`j`). The expected count is \\E\_{111} = g\_{11} n\_{11\cdot}\\
and

\$\$\Omega = \log_2 \frac{n\_{111} + \alpha_1}{E\_{111} + \alpha_2}\$\$

Following the paper, the interval limits are log2 quantiles of the
posterior Gamma(shape = \\n\_{111} + \alpha_1\\, rate = \\E\_{111} +
\alpha_2\\) distribution (eq. 20). The paper uses \\\alpha_1 = \alpha_2
= 0.5\\, a prior with mean 1 that shrinks Omega towards 0. When
\\\alpha_1 \neq \alpha_2\\, the prior mean is \\\alpha_1 / \alpha_2\\
and Omega is shrunk towards \\\log_2(\alpha_1 / \alpha_2)\\ instead of
0, which changes the meaning of the `omega_lower > 0` signal criterion.

Omega can only be computed when all four D1/D2 strata contain reports
(\\n\_{11\cdot}\\, \\n\_{10\cdot}\\, \\n\_{01\cdot}\\, \\n\_{00\cdot}\\
\> 0), so that the reporting rates are defined, and when \\f\_{00}\\,
\\f\_{10}\\ and \\f\_{01}\\ are below 1, so that the odds in eq. 16 are
finite. \\f\_{11} = 1\\ is valid. Rows that violate these conditions
return `NA` for `g11`, `E111` and the Omega columns, and a single
warning lists the affected rows and the reason. Counts that cannot come
from one set of reports (e.g. a negative cell) raise an error.

## References

Noren GN, Sundberg R, Bate A, Edwards IR. A statistical methodology for
drug-drug interaction surveillance. Stat Med. 2008;27(16):3057-70. doi:
10.1002/sim.3247

## Examples

``` r
# Itraconazole + oral contraceptives, delayed bleeding
# (Table II of Noren et al. 2008)
omega_from_counts(
  n111 = 10, n11. = 23, n1.1 = 10, n.11 = 19,
  n1.. = 39, n.1. = 1489, n..1 = 39, n... = 5503
)
#>     n1.1  n.11  n1..  n.1.  n..1  n...  n111  n110  n101  n100  n011  n010
#>    <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num> <num>
#> 1:    10    19    39  1489    39  5503    10    13     0    16     9  1457
#>     n001  n000  n11.  n10.  n01.  n00.         f00   f10         f01       f11
#>    <num> <num> <num> <num> <num> <num>       <num> <num>       <num>     <num>
#> 1:    20  3978    23    16  1466  3998 0.005002501     0 0.006139154 0.4347826
#>            g11      E111   omega omega_lower omega_upper
#>          <num>     <num>   <num>       <num>       <num>
#> 1: 0.006139154 0.1412005 4.03347    3.003327    4.790041
```
