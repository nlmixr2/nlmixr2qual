# test-fingerprint.R
test_that("qual_extract_fit produces a normalized fingerprint", {
  fit <- fake_fit()
  fp <- qual_extract_fit(fit, model = "PK_1cmt", method = "focei",
                         category = "Linearized", stochastic = FALSE,
                         threads = 1L)

  expect_identical(fp$model, "PK_1cmt")
  expect_identical(fp$method, "focei")
  expect_identical(fp$threads, 1L)
  expect_equal(fp$ofv, 100)
  expect_true(fp$converged)

  thetas <- fp$params[fp$params$ptype == "theta", ]
  expect_equal(nrow(thetas), 3)
  expect_equal(thetas$estimate[thetas$name == "lcl"], 1.0)
  expect_equal(thetas$se[thetas$name == "lcl"], 0.1)

  omegas <- fp$params[fp$params$ptype == "omega", ]
  expect_equal(omegas$estimate[omegas$name == "eta.cl"], 0.09)

  sigmas <- fp$params[fp$params$ptype == "sigma", ]
  expect_equal(sigmas$estimate[sigmas$name == "propSd"], 0.5)

  expect_equal(fp$shrink$value[fp$shrink$name == "eta.cl"], 12)
})

test_that("empty covariance step yields NA SEs and covMethod ''", {
  fit <- fake_fit(parFixedDf = data.frame(
                    Estimate = 1.0, SE = NA_real_, `%RSE` = NA_real_,
                    row.names = "lcl", check.names = FALSE),
                  covMethod = "")
  fp <- qual_extract_fit(fit, "M", "nlminb", "Optimizer (NLM family)",
                         stochastic = FALSE, threads = 1L)
  expect_true(is.na(fp$params$se[1]))
  expect_identical(fp$covMethod, "")
})

test_that("non-empty message marks non-convergence", {
  fit <- fake_fit(message = "gradient failure")
  fp <- qual_extract_fit(fit, "M", "focei", "Linearized",
                         stochastic = FALSE, threads = 1L)
  expect_false(fp$converged)
})

test_that("numeric convergence code wins over a non-empty success message", {
  # nlmixr2 populates $message with the optimizer's exit string even on
  # success ("Normal exit from bobyqa"); the numeric $convergence code (0)
  # must take precedence so a converged fit is not flagged as failed.
  fit_ok <- fake_fit(message = "Normal exit from bobyqa")
  fit_ok$convergence <- 0L
  fp_ok <- qual_extract_fit(fit_ok, "M", "focei", "Linearized",
                            stochastic = FALSE, threads = 1L)
  expect_true(fp_ok$converged)

  fit_bad <- fake_fit(message = "")     # empty message but non-zero code
  fit_bad$convergence <- 8L
  fp_bad <- qual_extract_fit(fit_bad, "M", "focei", "Linearized",
                             stochastic = FALSE, threads = 1L)
  expect_false(fp_bad$converged)
})
