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
      n111 = 10, n11. = 23, n1.1 = 10, n.11 = 19, n1.. = 33,
      n.1. = 1489, n..1 = 39, n... = 5503, n00. = 4004, n10. = 10,
      n01. = 1466, f00 = 0.004995004995005, f10 = 0, f01 = 0.00613915416098226,
      f11 = 0.434782608695652, g11 = 0.00613915416098232, E111 = 0.141200545702593,
      omega = 4.03346986434757, omega_lower = 3.00332741843529,
      omega_upper = 4.79004083721906, omega0 = 6.14611052552184,
      omega_flag = "ok"
    )
  )
})
