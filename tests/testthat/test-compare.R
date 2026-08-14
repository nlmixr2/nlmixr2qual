# test-compare.R
test_that("identical fingerprints pass on every quantity", {
  fp <- qual_extract_fit(fake_fit(), "PK_1cmt", "focei", "Linearized",
                         stochastic = FALSE, threads = 1L)
  cmp <- qual_compare(fp, fp)
  expect_true(cmp$pass)
  expect_true(all(cmp$detail$pass))
  expect_true("ofv" %in% cmp$detail$quantity)
})

test_that("a theta beyond tolerance fails that quantity and the model", {
  base <- qual_extract_fit(fake_fit(), "PK_1cmt", "focei", "Linearized",
                           stochastic = FALSE, threads = 1L)
  drift <- fake_fit()
  drift$parFixedDf$Estimate[2] <- 1.0 * (1 + 2e-2)  # lcl +2%, tol 1e-2
  run <- qual_extract_fit(drift, "PK_1cmt", "focei", "Linearized",
                          stochastic = FALSE, threads = 1L)
  cmp <- qual_compare(run, base)
  expect_false(cmp$pass)
  bad <- cmp$detail[cmp$detail$quantity == "theta:lcl", ]
  expect_false(bad$pass)
  expect_gt(bad$reldiff, 1e-2)
})

test_that("convergence mismatch fails regardless of numbers", {
  base <- qual_extract_fit(fake_fit(), "M", "focei", "Linearized", FALSE, 1L)
  run  <- qual_extract_fit(fake_fit(message = "boundary"), "M", "focei",
                           "Linearized", FALSE, 1L)
  cmp <- qual_compare(run, base)
  expect_false(cmp$pass)
  expect_false(cmp$detail$pass[cmp$detail$quantity == "converged"])
})

test_that("shrink drift is reported but never gates the verdict", {
  base <- qual_extract_fit(fake_fit(), "M", "focei", "Linearized", FALSE, 1L)
  drift <- fake_fit()
  drift$shrink$eta.cl <- 0.3   # 12 -> 0.3: >90% relative drift, tol 5%
  run <- qual_extract_fit(drift, "M", "focei", "Linearized", FALSE, 1L)
  cmp <- qual_compare(run, base)
  bad <- cmp$detail[cmp$detail$quantity == "shrink:eta.cl", ]
  expect_false(bad$pass)          # still flagged in the detail table
  expect_true(cmp$pass)           # but does not fail the overall verdict
})

test_that("invariance mode applies the looser tolerance", {
  # ofv keeps a tight deterministic tolerance (1e-3) below the invariance
  # floor (1e-2), unlike theta/omega/sigma (1e-2 default == the floor).
  base <- qual_extract_fit(fake_fit(), "M", "focei", "Linearized", FALSE, 1L)
  drift <- fake_fit(objf = 100 * (1 + 5e-3))
  run <- qual_extract_fit(drift, "M", "focei", "Linearized", FALSE, threads = 4L)
  expect_true(qual_compare(run, base, invariance = TRUE)$pass)   # 5e-3 < 1e-2
  expect_false(qual_compare(run, base, invariance = FALSE)$pass) # 5e-3 > 1e-3
})
