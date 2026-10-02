#' Compute Omega from a table of report counts
#'
#' Convenience wrapper around [omega_from_counts()] for tabular input. The
#' input must contain one column for each of the eight report counts required
#' by `omega_from_counts()`. Computation is vectorised, so one output row is
#' returned for each input row.
#'
#' @param x A data frame, `data.table`, or other object coercible to a
#'   `data.frame`, containing the required count columns.
#' @param alpha1 Shrinkage tuning parameter for the observed count. Passed to [omega_from_counts()].
#' @param alpha2 Shrinkage tuning parameter for the expected count. Passed to [omega_from_counts()].
#' @param cred_level Level of the two-sided credibility interval. Passed to
#'   [omega_from_counts()].
#'
#' @return A `data.table` containing any retained input columns followed by
#'   the results from [omega_from_counts()].
#'
#' @examples
#' counts <- data.frame(
#'   drug1 = "itraconazole",
#'   drug2 = "oral contraceptives",
#'   event = "delayed bleeding",
#'   n111 = 10,
#'   `n11.` = 23,
#'   `n1.1` = 10,
#'   `n.11` = 19,
#'   `n1..` = 39,
#'   `n.1.` = 1489,
#'   `n..1` = 39,
#'   `n...` = 5503,
#'   check.names = FALSE
#' )
#'
#' omega_from_table(counts)
#'
#' @seealso [omega_from_counts()]
#' @export
omega_from_table <- function(x,
                             alpha1 = 0.5,
                             alpha2 = 0.5,
                             cred_level = 0.95) {

  if (!is.data.frame(x)) {
    x <- tryCatch(
      as.data.frame(x),
      error = function(e) {
        stop(
          "`x` must be a data frame, data.table, or coercible to a data frame.",
          call. = FALSE
        )
      }
    )
  }

  required <- c(
    "n111", "n11.", "n1.1", "n.11",
    "n1..", "n.1.", "n..1", "n..."
  )

  missing_cols <- setdiff(required, names(x))

  if (length(missing_cols)) {
    stop(
      "Missing required column",
      if (length(missing_cols) > 1L) "s" else "",
      ": ",
      paste0("`", missing_cols, "`", collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  result <- omega_from_counts(
    n111 = x[["n111"]],
    n11. = x[["n11."]],
    n1.1 = x[["n1.1"]],
    n.11 = x[["n.11"]],
    n1.. = x[["n1.."]],
    n.1. = x[["n.1."]],
    n..1 = x[["n..1"]],
    n... = x[["n..."]],
    alpha1 = alpha1,
    alpha2 = alpha2,
    cred_level = cred_level
  )

  extra_cols <- setdiff(names(x), required)

  if (!length(extra_cols)) {
    return(result[])
  }

  extra <- data.table::as.data.table(x[, extra_cols, drop = FALSE])

  cbind(extra, result)[]
}

