# pvOmega 0.0.0.9000

* Initial development version.
* `omega_from_counts()` returns `NA` with a warning, instead of `NA` or
  infinite intermediate values, for rows with an empty D1/D2 stratum or with
  `f00`, `f10` or `f01` equal to 1. `f11 = 1` is valid.
