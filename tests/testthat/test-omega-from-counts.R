test_that("Omega from counts works against article example", {
  expect_equal(
    omega_from_counts(
      n111 = 10,
      n11. = 23,
      n1.1 = 10,
      n.11 = 19,
      n1.. = 33,
      n.1. = 1489,
      n..1 = 39,
      n... = 5503,
      alpha1 = 0.5,
      alpha2 = 0.5,
      cred_level = 0.95
    ),
    data.table::data.table(
      n1.1 = 10, n.11 = 19, n1.. = 33, n.1. = 1489,
      n..1 = 39, n... = 5503, n111 = 10, n110 = 13, n101 = 0, n100 = 10,
      n011 = 9, n010 = 1457, n001 = 20, n000 = 3984, n11. = 23,
      n10. = 10, n01. = 1466, n00. = 4004, f00 = 0.004995004995005,
      f10 = 0, f01 = 0.00613915416098226, f11 = 0.434782608695652,
      g11 = 0.00613915416098232, E111 = 0.141200545702593, omega = 4.03346986434757,
      omega_lower = 3.00332741843529, omega_upper = 4.79004083721906
    )
  )
})

# Valid base counts: n10. = 20, n01. = 30, n00. = 940
base_counts <- list(
  n111 = 2, n11. = 10, n1.1 = 5, n.11 = 4,
  n1.. = 30, n.1. = 40, n..1 = 50, n... = 1000
)
omega_with <- function(...) {
  do.call(omega_from_counts, utils::modifyList(base_counts, list(...)))
}
omega_cols <- c("g11", "E111", "omega", "omega_lower", "omega_upper")

test_that("empty D1/D2 strata give NA with a warning naming the stratum", {
  cases <- list(
    "n11. = 0" = list(n111 = 0, n11. = 0),
    "n10. = 0" = list(n1.. = 10, n1.1 = 2),
    "n01. = 0" = list(n.1. = 10, n.11 = 2),
    "n00. = 0" = list(n... = 60, n..1 = 7)
  )
  for (stratum in names(cases)) {
    expect_warning(
      out <- do.call(omega_with, cases[[stratum]]),
      stratum,
      fixed = TRUE
    )
    for (col in omega_cols) expect_true(is.na(out[[col]]), info = paste(stratum, col))
  }
})

test_that("several empty strata are reported in one warning", {
  expect_warning(
    out <- omega_with(n1.. = 10, n1.1 = 2, n.1. = 10, n.11 = 2),
    "n10. = 0.*\n.*n01. = 0"
  )
  expect_true(is.na(out$omega))
})

test_that("f00, f10 or f01 equal to 1 give NA with a warning naming the rate", {
  cases <- list(
    f00 = list(n..1 = 947),
    f10 = list(n1.1 = 22),
    f01 = list(n.11 = 32)
  )
  for (f in names(cases)) {
    expect_warning(
      out <- do.call(omega_with, cases[[f]]),
      paste0(f, " = 1"),
      fixed = TRUE
    )
    expect_equal(out[[f]], 1)
    for (col in omega_cols) expect_true(is.na(out[[col]]), info = paste(f, col))
  }
})

test_that("invalid rows in a vector are NA and valid rows are unaffected", {
  # row 1 valid, row 2 has n10. = 0, row 3 has f01 = 1
  mixed <- function() {
    omega_from_counts(
      n111 = c(2, 2, 2), n11. = c(10, 10, 10), n1.1 = c(5, 2, 5),
      n.11 = c(4, 4, 32), n1.. = c(30, 10, 30), n.1. = c(40, 40, 40),
      n..1 = c(50, 50, 50), n... = c(1000, 1000, 1000)
    )
  }
  out <- suppressWarnings(mixed())
  expect_equal(as.list(out[1, ]), as.list(omega_with()))
  for (col in omega_cols) expect_true(all(is.na(out[[col]][2:3])), info = col)

  msg <- tryCatch(mixed(), warning = conditionMessage)
  expect_match(msg, "for 2 row(s)", fixed = TRUE)
  expect_match(msg, "n10. = 0 (no reports with D1 but not D2) in row(s) 2", fixed = TRUE)
  expect_match(msg, "f01 = 1 (every report with D2 but not D1 lists the event) in row(s) 3", fixed = TRUE)
})

test_that("f11 = 1 is valid", {
  expect_no_warning(
    out <- omega_from_counts(
      n111 = 10, n11. = 10, n1.1 = 12, n.11 = 11,
      n1.. = 30, n.1. = 40, n..1 = 50, n... = 1000
    )
  )
  expect_equal(out$f11, 1)
  for (col in omega_cols) expect_true(is.finite(out[[col]]), info = col)
})

test_that("f00 = f10 = f01 = 0 gives g11 = 0 and a finite Omega", {
  expect_no_warning(out <- omega_with(n1.1 = 2, n.11 = 2, n..1 = 2))
  expect_equal(c(out$f00, out$f10, out$f01), c(0, 0, 0))
  expect_equal(out$g11, 0)
  expect_equal(out$E111, 0)
  expect_equal(out$omega, log2(2.5 / 0.5))
})

test_that("reporting rates just below 1 give finite results", {
  expect_no_warning(out <- omega_with(n1.1 = 21))
  expect_equal(out$f10, 19 / 20)
  for (col in omega_cols) expect_true(is.finite(out[[col]]), info = col)
})

test_that("omega_from_counts validates omega and credibility interval against diverse scenarios", {
  test_data <- read.csv(
    test_path("fixtures/omega_validation_data.csv"),
    stringsAsFactors = FALSE
  )

  # all scenarios are valid, so no row should be set to NA
  expect_no_warning(results <- omega_from_counts(
    n111 = test_data$nxyz,
    n11. = test_data$nxy,
    n1.1 = test_data$nxz,
    n.11 = test_data$nyz,
    n1.. = test_data$nx,
    n.1. = test_data$ny,
    n..1 = test_data$nz,
    n... = test_data$n
  ))

  omega_match <- abs(results$omega - test_data$expected_omega) < 1e-3
  ci_match <- abs(results$omega_lower - test_data$expected_ci) < 1e-3

  for (i in seq_len(nrow(test_data))) {
    expect_true(
      omega_match[i],
      label = paste("Omega match:", test_data$name[i])
    )
    expect_true(
      ci_match[i],
      label = paste("CI lower bound match:", test_data$name[i])
    )
  }
})
