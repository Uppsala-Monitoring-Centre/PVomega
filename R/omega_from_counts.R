#' Compute Omega from report counts
#'
#' Computes the Omega shrinkage observed-to-expected ratio for a drug-drug-event
#' triplet (Noren et al. 2008), together with its credibility interval and all
#' intermediate quantities. The function is vectorised: every count argument
#' can be a vector, and one row is returned per element.
#'
#' The expected relative reporting rate under the additive-risk baseline model
#' is (eq. 16 of Noren et al. 2008)
#'
#' \deqn{g_{11} = 1 - \frac{1}{\max(o_{00}, o_{10}) + \max(o_{00}, o_{01}) - o_{00} + 1}}
#'
#' where \eqn{o_{ij} = f_{ij} / (1 - f_{ij})} and \eqn{f_{ij}} is the relative
#' reporting rate of the event in the stratum exposed to D1 (`i`) and D2 (`j`).
#' The expected count is \eqn{E_{111} = g_{11} n_{11\cdot}} and
#'
#' \deqn{\Omega = \log_2 \frac{n_{111} + \alpha_1}{E_{111} + \alpha_2}}
#'
#' Following the paper, the interval limits are log2 quantiles of the posterior
#' Gamma(shape = \eqn{n_{111} + \alpha_1}, rate = \eqn{E_{111} + \alpha_2})
#' distribution (eq. 20).
#' The paper uses \eqn{\alpha_1 = \alpha_2 = 0.5}, a prior with mean 1 that
#' shrinks Omega towards 0. When \eqn{\alpha_1 \neq \alpha_2}, the prior mean
#' is \eqn{\alpha_1 / \alpha_2} and Omega is shrunk towards
#' \eqn{\log_2(\alpha_1 / \alpha_2)} instead of 0, which changes the meaning of
#' the `omega_lower > 0` signal criterion.
#'
#' Omega can only be computed when all four D1/D2 strata contain reports
#' (\eqn{n_{11\cdot}}, \eqn{n_{10\cdot}}, \eqn{n_{01\cdot}},
#' \eqn{n_{00\cdot}} > 0), so that the reporting rates are defined, and when
#' \eqn{f_{00}}, \eqn{f_{10}} and \eqn{f_{01}} are below 1, so that the odds
#' in eq. 16 are finite. \eqn{f_{11} = 1} is valid. Rows that violate these
#' conditions return `NA` for `g11`, `E111` and the Omega columns, and a single
#' warning lists the affected rows and the reason. Counts that cannot come from
#' one set of reports (e.g. a negative cell) raise an error.
#'
#' @param n111 Reports listing D1, D2 and the event.
#' @param n11. Reports listing D1 and D2.
#' @param n1.1 Reports listing D1 and the event.
#' @param n.11 Reports listing D2 and the event.
#' @param n1.. Reports listing D1.
#' @param n.1. Reports listing D2.
#' @param n..1 Reports listing the event.
#' @param n... Total number of reports.
#' @param alpha1 Shrinkage added to the observed count: the shape of the
#'   Gamma prior (default 0.5, as in the paper). Must be > 0.
#' @param alpha2 Shrinkage added to the expected count: the rate of the
#'   Gamma prior (default 0.5, as in the paper). Must be > 0.
#' @param cred_level Level of the two-sided credibility interval (default
#'   0.95, giving Omega025 and Omega975).
#'
#' @return A `data.table` with one row per element of the inputs and columns:
#'   * the input marginal counts `n1.1`, `n.11`, `n1..`, `n.1.`, `n..1`,
#'     `n...`;
#'   * the eight cells of the 2x2x2 contingency table, named by presence (1)
#'     or absence (0) of D1, D2 and the event: `n111`, `n110`, `n101`,
#'     `n100`, `n011`, `n010`, `n001`, `n000` (they sum to `n...`);
#'   * the four exposure strata totals `n11.`, `n10.`, `n01.`, `n00.`;
#'   * `f00`, `f10`, `f01`, `f11`, `g11`, the expected count `E111`, `omega`,
#'     `omega_lower`, `omega_upper`. Each `f` is `NA` when its stratum is
#'     empty; `g11`, `E111` and the Omega columns are `NA` for rows where
#'     Omega cannot be computed (see Details).
#'
#' @references Noren GN, Sundberg R, Bate A, Edwards IR. A statistical
#'   methodology for drug-drug interaction surveillance. Stat Med.
#'   2008;27(16):3057-70. doi: 10.1002/sim.3247
#'
#'
#' @examples
#' # Itraconazole + oral contraceptives, delayed bleeding
#' # (Table II of Noren et al. 2008)
#' omega_from_counts(
#'   n111 = 10, n11. = 23, n1.1 = 10, n.11 = 19,
#'   n1.. = 39, n.1. = 1489, n..1 = 39, n... = 5503
#' )
#' @export
omega_from_counts <- function(n111, n11., n1.1, n.11, n1.., n.1., n..1, n...,
                              alpha1 = 0.5, alpha2 = 0.5,
                              cred_level = 0.95) {
  # ---- input validation ----------------------------------------------------
  counts <- list(
    n111 = n111, n11. = n11., n1.1 = n1.1, n.11 = n.11,
    n1.. = n1.., n.1. = n.1., n..1 = n..1, n... = n...
  )
  for (nm in names(counts)) {
    x <- counts[[nm]]
    if (!is.numeric(x)) stop("`", nm, "` must be numeric.", call. = FALSE)
    if (any(x < 0, na.rm = TRUE)) stop("`", nm, "` must be non-negative.", call. = FALSE)
    if (any(abs(x - round(x)) > 1e-8, na.rm = TRUE)) {
      stop("`", nm, "` must contain whole numbers.", call. = FALSE)
    }
  }
  for (nm in c("alpha1", "alpha2")) {
    a <- get(nm)
    if (!is.numeric(a) || length(a) != 1L || is.na(a) || a <= 0) {
      stop("`", nm, "` must be a single number > 0.", call. = FALSE)
    }
  }
  if (!is.numeric(cred_level) || length(cred_level) != 1L ||
    is.na(cred_level) || cred_level <= 0 || cred_level >= 1) {
    stop("`cred_level` must be a single number in (0, 1).", call. = FALSE)
  }

  len <- max(lengths(counts))
  counts <- lapply(counts, function(x) rep_len(as.numeric(x), len))
  list2env(counts, envir = environment())

  # ---- cells of the 2x2x2 table (inclusion-exclusion) ----------------------
  n10. <- n1.. - n11.
  n01. <- n.1. - n11.
  n00. <- n... - n1.. - n.1. + n11.
  n101 <- n1.1 - n111
  n011 <- n.11 - n111
  n001 <- n..1 - n1.1 - n.11 + n111
  n110 <- n11. - n111
  n100 <- n10. - n101
  n010 <- n01. - n011
  n000 <- n00. - n001

  cells <- list(
    n10. = n10., n01. = n01., n00. = n00.,
    n101 = n101, n011 = n011, n001 = n001
  )

  bad <- vapply(cells, function(x) any(x < 0, na.rm = TRUE), logical(1))
  if (any(bad)) {
    stop("Inconsistent counts: negative cell(s) ",
      paste(names(cells)[bad], collapse = ", "),
      ". Check that the marginal counts refer to the same set of reports.",
      call. = FALSE
    )
  }
  if (any(n111 > n11. | n111 > n1.1 | n111 > n.11, na.rm = TRUE)) {
    stop("Inconsistent counts: `n111` exceeds a two-way count.", call. = FALSE)
  }

  # ---- Omega-specific validity (rows set to NA with a warning) --------------
  rules <- omega_validity(n11., n10., n01., n00., n001, n101, n011)
  ok <- !Reduce(`|`, rules)
  failed <- vapply(rules, function(x) any(x, na.rm = TRUE), logical(1))
  if (any(failed)) {
    details <- vapply(names(rules)[failed], function(rule) {
      paste0("  - ", rule, " in row(s) ", format_rows(which(rules[[rule]])))
    }, character(1))
    warning("Omega could not be computed for ", sum(!ok, na.rm = TRUE),
      " row(s); returning NA:\n", paste(details, collapse = "\n"),
      "\nOmega requires reports in all four D1/D2 strata and ",
      "f00, f10, f01 < 1 (eq. 16).",
      call. = FALSE
    )
  }

  # ---- relative reporting rates --------------------------------------------
  # Reported wherever the stratum is non-empty, so invalid rows can be
  # diagnosed from the output.
  rate <- function(num, den) ifelse(den > 0, num / den, NA_real_)
  f00 <- rate(n001, n00.)
  f10 <- rate(n101, n10.)
  f01 <- rate(n011, n01.)
  f11 <- rate(n111, n11.)

  # Only valid rows reach eq. 16, where f00, f10, f01 < 1 keeps the odds finite.
  odds <- function(f) ifelse(ok, f / (1 - f), NA_real_)
  o00 <- odds(f00)
  o10 <- odds(f10)
  o01 <- odds(f01)

  # ---- expected relative reporting rate (eq. 16) ---------------------------
  g11 <- 1 - 1 / (pmax(o00, o10) + pmax(o00, o01) - o00 + 1)

  E111 <- g11 * n11.

  # ---- Omega and credibility interval (eq. 19-20) --------------------------
  shape <- n111 + alpha1
  rate <- E111 + alpha2
  omega <- log2(shape / rate)
  q_low <- (1 - cred_level) / 2
  omega_lower <- log2(stats::qgamma(q_low, shape = shape, rate = rate))
  omega_upper <- log2(stats::qgamma(1 - q_low, shape = shape, rate = rate))

  out <- data.table::data.table(
    # input marginal counts
    n1.1 = n1.1, n.11 = n.11,
    n1.. = n1.., n.1. = n.1., n..1 = n..1, n... = n...,
    # full 2x2x2 contingency table (D1, D2, event; 1 = present, 0 = absent)
    n111 = n111, n110 = n110, n101 = n101, n100 = n100,
    n011 = n011, n010 = n010, n001 = n001, n000 = n000,
    # exposure strata totals
    n11. = n11., n10. = n10., n01. = n01., n00. = n00.,
    f00 = f00, f10 = f10, f01 = f01, f11 = f11,
    g11 = g11, E111 = E111,
    omega = omega, omega_lower = omega_lower, omega_upper = omega_upper
  )

  out[]
}

#' Check that report counts form a valid 2x2x2 table
#'
#' Two levels of checks, applied element-wise to vectorised counts:
#'
#' 1. Subset rules: a count can never exceed the count of a set that contains
#'    it (e.g. reports with D1, D2 and the event are a subset of reports with
#'    D1 and D2, so `n111 <= n11.`).
#' 2. Cell rules: the eight cells of the 2x2x2 table, derived by
#'    inclusion-exclusion, must all be non-negative. This catches
#'    inconsistencies the subset rules miss, e.g. `n1.. + n.1. - n11. > n...`.
#'
#' Together the cell rules are necessary and sufficient for the counts to come
#' from one set of reports; the subset rules are implied by them but give
#' clearer error messages. All violations are reported in one error, with the
#' affected rows. `NA` values are ignored.
#' @noRd
check_count_consistency <- function(n111, n11., n1.1, n.11, n1.., n.1., n..1, n...) {
  rules <- list(
    # three-way count within each two-way count
    "n111 <= n11." = n111 <= n11.,
    "n111 <= n1.1" = n111 <= n1.1,
    "n111 <= n.11" = n111 <= n.11,
    # two-way counts within each one-way count
    "n11. <= n1.." = n11. <= n1..,
    "n11. <= n.1." = n11. <= n.1.,
    "n1.1 <= n1.." = n1.1 <= n1..,
    "n1.1 <= n..1" = n1.1 <= n..1,
    "n.11 <= n.1." = n.11 <= n.1.,
    "n.11 <= n..1" = n.11 <= n..1,
    # one-way counts within the total
    "n1.. <= n..." = n1.. <= n...,
    "n.1. <= n..." = n.1. <= n...,
    "n..1 <= n..." = n..1 <= n...,
    # cells of the 2x2x2 table must be non-negative (inclusion-exclusion)
    "cell D1, D2, no event >= 0" = n11. - n111 >= 0,
    "cell D1, no D2, event >= 0" = n1.1 - n111 >= 0,
    "cell no D1, D2, event >= 0" = n.11 - n111 >= 0,
    "cell D1 only, no event >= 0" = n1.. - n11. - n1.1 + n111 >= 0,
    "cell D2 only, no event >= 0" = n.1. - n11. - n.11 + n111 >= 0,
    "cell event only, no drug >= 0" = n..1 - n1.1 - n.11 + n111 >= 0,
    "cell no drug, no event >= 0" =
      n... - n1.. - n.1. - n..1 + n11. + n1.1 + n.11 - n111 >= 0
  )

  failed <- vapply(rules, function(ok) any(!ok, na.rm = TRUE), logical(1))
  if (!any(failed)) {
    return(invisible(TRUE))
  }

  details <- vapply(names(rules)[failed], function(rule) {
    paste0("  - ", rule, " violated in row(s) ", format_rows(which(!rules[[rule]])))
  }, character(1))

  stop("Inconsistent counts:\n", paste(details, collapse = "\n"),
    "\nCheck that all counts refer to the same set of reports.",
    call. = FALSE
  )
}

#' Rows where Omega cannot be computed
#'
#' Omega needs all four D1/D2 strata to be non-empty (otherwise a reporting
#' rate is undefined) and `f00`, `f10`, `f01` < 1 (eq. 16 uses `f / (1 - f)`).
#' `f11 = 1` is valid. The rate rules are only tested where the stratum is
#' non-empty, so each invalid row is reported for its root cause. `>=` also
#' catches `f > 1` from counts the consistency checks do not cover.
#'
#' @return A named list of logical vectors, `TRUE` where the rule is violated.
#'   The names are used in the warning message.
#' @noRd
omega_validity <- function(n11., n10., n01., n00., n001, n101, n011) {
  list(
    "n11. = 0 (no reports with both D1 and D2)" = n11. == 0,
    "n10. = 0 (no reports with D1 but not D2)" = n10. == 0,
    "n01. = 0 (no reports with D2 but not D1)" = n01. == 0,
    "n00. = 0 (no reports with neither D1 nor D2)" = n00. == 0,
    "f00 = 1 (every report with neither D1 nor D2 lists the event)" =
      n00. > 0 & n001 >= n00.,
    "f10 = 1 (every report with D1 but not D2 lists the event)" =
      n10. > 0 & n101 >= n10.,
    "f01 = 1 (every report with D2 but not D1 lists the event)" =
      n01. > 0 & n011 >= n01.
  )
}

#' Format row numbers for messages, showing at most five
#' @noRd
format_rows <- function(rows) {
  shown <- paste(utils::head(rows, 5L), collapse = ", ")
  if (length(rows) > 5L) shown <- paste0(shown, ", ... (", length(rows), " rows)")
  shown
}
