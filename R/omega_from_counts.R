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
#' \deqn{\Omega = \log_2 \frac{n_{111} + \alpha}{E_{111} + \alpha}}
#'
#' Following the paper, the selected CI method is a Gamma distribution,
#' therefore the interval limits are log2 quantiles
#' of the posterior Gamma(shape = \eqn{n_{111} + \alpha}, rate =
#' \eqn{E_{111} + \alpha}) distribution (eq. 20).
#'
#' @param n111 Reports listing D1, D2 and the event.
#' @param n11. Reports listing D1 and D2.
#' @param n1.1 Reports listing D1 and the event.
#' @param n.11 Reports listing D2 and the event.
#' @param n1.. Reports listing D1.
#' @param n.1. Reports listing D2.
#' @param n..1 Reports listing the event.
#' @param n... Total number of reports.
#' @param alpha Shrinkage tuning parameter (default 0.5, as in the paper).
#'   Must be > 0.
#' @param conf_level Level of the two-sided credibility interval (default
#'   0.95, giving Omega025 and Omega975).
#' @param no_background Logical. If `TRUE`, also returns the robustness
#'   variant `omega_nb`, computed assuming no background risk
#'   (\eqn{g'_{11} = 1 - 1/(o_{10} + o_{01} + 1)}, Section 4 of the paper).
#'
#' @return A `data.table` with the input counts, the derived stratum
#'   denominators, `f00`, `f10`, `f01`, `f11`, `g11`, the expected count
#'   `E111`, `omega`, `omega_lower`, `omega_upper`, the unshrunk `omega0`,
#'   optionally `omega_nb`, and `omega_flag` (`"ok"`, `"zero_denominator"` or
#'   `"f_equals_one"`).
#'
#' @references Noren GN, Sundberg R, Bate A, Edwards IR. A statistical
#'   methodology for drug-drug interaction surveillance. Stat Med.
#'   2008;27(16):3057-70. \doi{10.1002/sim.3247}
#'
#' @seealso [omega_analysis()] to compute the counts from DiAna FAERS tables.
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
                              alpha = 0.5,
                              conf_level = 0.95,
                              no_background = FALSE) {

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
  if (!is.numeric(alpha) || length(alpha) != 1L || is.na(alpha) || alpha <= 0) {
    stop("`alpha` must be a single number > 0.", call. = FALSE)
  }
  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
    is.na(conf_level) || conf_level <= 0 || conf_level >= 1) {
    stop("`conf_level` must be a single number in (0, 1).", call. = FALSE)
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

  # ---- relative reporting rates --------------------------------------------
  safe_div <- function(num, den) ifelse(den > 0, num / den, NA_real_)
  f00 <- safe_div(n001, n00.)
  f10 <- safe_div(n101, n10.)
  f01 <- safe_div(n011, n01.)
  f11 <- safe_div(n111, n11.)

  odds <- function(f) ifelse(is.na(f), NA_real_, ifelse(f >= 1, Inf, f / (1 - f)))
  o00 <- odds(f00)
  o10 <- odds(f10)
  o01 <- odds(f01)

  # ---- expected relative reporting rate (eq. 16) ---------------------------
  den <- pmax(o00, o10) + pmax(o00, o01) - o00 + 1
  g11 <- ifelse(is.infinite(den), 1, 1 - 1 / den)

  zero_den <- n10. == 0 | n01. == 0
  f_one <- !is.na(f10) & f10 >= 1 | !is.na(f01) & f01 >= 1
  omega_flag <- ifelse(n00. == 0, "zero_denominator",
    ifelse(f_one, "f_equals_one", "ok")
  )

  E111 <- g11 * n11.

  # ---- Omega and credibility interval (eq. 19-20) --------------------------
  omega <- log2((n111 + alpha) / (E111 + alpha))
  q_low <- (1 - conf_level) / 2
  rate <- E111 + alpha
  omega_lower <- log2(stats::qgamma(q_low, shape = n111 + alpha, rate = rate))
  omega_upper <- log2(stats::qgamma(1 - q_low, shape = n111 + alpha, rate = rate))

  omega0 <- ifelse(n111 > 0 & E111 > 0, log2(n111 / E111), NA_real_)

  out <- data.table::data.table(
    n111 = n111, n11. = n11., n1.1 = n1.1, n.11 = n.11,
    n1.. = n1.., n.1. = n.1., n..1 = n..1, n... = n...,
    n00. = n00., n10. = n10., n01. = n01.,
    f00 = f00, f10 = f10, f01 = f01, f11 = f11,
    g11 = g11, E111 = E111,
    omega = omega, omega_lower = omega_lower, omega_upper = omega_upper,
    omega0 = omega0
  )

  if (isTRUE(no_background)) {
    den_nb <- o10 + o01 + 1
    g11_nb <- ifelse(is.infinite(den_nb), 1, 1 - 1 / den_nb)
    E_nb <- g11_nb * n11.
    data.table::set(out, j = "omega_nb", value = log2((n111 + alpha) / (E_nb + alpha)))
  }

  data.table::set(out, j = "omega_flag", value = omega_flag)
  out[]
}
