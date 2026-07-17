# test-tolerance.R
test_that("deterministic tolerances follow spec 6.4 defaults", {
  expect_equal(qual_tolerance("ofv",   stochastic = FALSE), 1e-3)
  expect_equal(qual_tolerance("theta", stochastic = FALSE), 1e-3)
  expect_equal(qual_tolerance("omega", stochastic = FALSE), 1e-3)
  expect_equal(qual_tolerance("sigma", stochastic = FALSE), 1e-3)
  expect_equal(qual_tolerance("se",    stochastic = FALSE), 0.05)
  expect_equal(qual_tolerance("rse",   stochastic = FALSE), 0.05)
  expect_equal(qual_tolerance("shrink",stochastic = FALSE), 0.05)
})

test_that("stochastic tolerances are looser", {
  expect_equal(qual_tolerance("ofv",   stochastic = TRUE), 1e-2)
  expect_equal(qual_tolerance("se",    stochastic = TRUE), 0.10)
})

test_that("invariance mode overrides to the thread-invariance tolerance", {
  expect_equal(qual_tolerance("theta", stochastic = FALSE, invariance = TRUE), 1e-2)
})

test_that("explicit override wins", {
  expect_equal(qual_tolerance("theta", stochastic = FALSE, override = 5e-4), 5e-4)
})
