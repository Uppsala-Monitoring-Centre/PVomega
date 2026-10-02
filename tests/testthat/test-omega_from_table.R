test_that("omega_from_table gives the same result as omega_from_counts", {
  x <- data.frame(
    n111 = 10,
    "n11." = 23,
    "n1.1" = 10,
    "n.11" = 19,
    "n1.." = 39,
    "n.1." = 1489,
    "n..1" = 39,
    "n..." = 5503,
    check.names = FALSE
  )

  from_table <- omega_from_table(x)

  from_counts <- omega_from_counts(
    n111 = 10,
    n11. = 23,
    n1.1 = 10,
    n.11 = 19,
    n1.. = 39,
    n.1. = 1489,
    n..1 = 39,
    n... = 5503
  )

  expect_equal(from_table, from_counts)
})

test_that("omega_from_table is vectorised over rows", {
  x <- data.frame(
    n111 = c(10, 5),
    "n11." = c(23, 20),
    "n1.1" = c(10, 8),
    "n.11" = c(19, 7),
    "n1.." = c(39, 45),
    "n.1." = c(1489, 1200),
    "n..1" = c(39, 50),
    "n..." = c(5503, 6000),
    check.names = FALSE
  )

  out <- omega_from_table(x)

  expect_s3_class(out, "data.table")
  expect_equal(nrow(out), 2L)

  expected <- omega_from_counts(
    n111 = x[["n111"]],
    n11. = x[["n11."]],
    n1.1 = x[["n1.1"]],
    n.11 = x[["n.11"]],
    n1.. = x[["n1.."]],
    n.1. = x[["n.1."]],
    n..1 = x[["n..1"]],
    n... = x[["n..."]]
  )

  expect_equal(out, expected)
})

test_that("omega_from_table reports multiple missing columns", {
  x <- data.frame(
    n111 = 10,
    "n11." = 23,
    check.names = FALSE
  )

  expect_error(
    omega_from_table(x),
    "Missing required columns:"
  )

  expect_error(
    omega_from_table(x),
    "`n1.1`"
  )

  expect_error(
    omega_from_table(x),
    "`n...`"
  )
})

test_that("omega_from_table accepts objects coercible to data.frame", {
  x <- list(
    n111 = 10,
    "n11." = 23,
    "n1.1" = 10,
    "n.11" = 19,
    "n1.." = 39,
    "n.1." = 1489,
    "n..1" = 39,
    "n..." = 5503
  )

  out <- omega_from_table(x)

  expect_s3_class(out, "data.table")
  expect_equal(nrow(out), 1L)
})

test_that("omega_from_table rejects objects that cannot be converted to data.frame", {
  x <- environment()

  expect_error(
    omega_from_table(x),
    "`x` must be a data frame, data.table, or coercible to a data frame.",
    fixed = TRUE
  )
})

test_that("omega_from_table returns NA with a warning for invalid rows only", {
  x <- data.frame(
    label = c("valid", "no D1 without D2"),
    n111 = c(10, 2),
    "n11." = c(23, 10),
    "n1.1" = c(10, 2),
    "n.11" = c(19, 4),
    "n1.." = c(39, 10),
    "n.1." = c(1489, 40),
    "n..1" = c(39, 50),
    "n..." = c(5503, 1000),
    check.names = FALSE
  )

  expect_warning(out <- omega_from_table(x), "n10. = 0", fixed = TRUE)
  expect_equal(as.list(out[1, -1]), as.list(omega_from_table(x[1, -1])))
  expect_true(is.na(out$omega[2]))
})
