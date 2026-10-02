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

test_that("omega_from_counts validates omega and credibility interval against diverse scenarios", {
  test_data <- read.csv(
    test_path("fixtures/omega_validation_data.csv"),
    stringsAsFactors = FALSE
  )

  results <- omega_from_counts(
    n111 = test_data$nxyz,
    n11. = test_data$nxy,
    n1.1 = test_data$nxz,
    n.11 = test_data$nyz,
    n1.. = test_data$nx,
    n.1. = test_data$ny,
    n..1 = test_data$nz,
    n... = test_data$n
  )

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

  expect_true(all(results$omega_flag == "ok"),
    label = "No computation errors"
  )
})
