test_that("re-fitting a reference at its own thread count reproduces its OFV", {
  skip_if_no_live()
  ref <- qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                            method = "focei", threads = 1L)
  fp <- qual_reference_refit(ref)
  expect_equal(fp$ofv, ref$reference$ofv, tolerance = 1e-3)
  expect_equal(fp$method, "focei")
  expect_equal(fp$threads, 1L)             # pinned to the reference's threads
  expect_true(fp$converged)
})

test_that("a pinned seed makes a stochastic re-fit exactly reproducible", {
  skip_if_no_live()
  dir <- tempfile(); dir.create(dir)
  zip <- build_bundle(dir, "theo_saem_pinned", est = "saem",
                      control = nlmixr2est::saemControl(seed = 99L, nBurn = 5, nEm = 5))
  ref <- qual_import_bundle(zip, model_name = "theophylline", method = "saem",
                            threads = 1L)
  expect_equal(ref$method$seed, 99L)
  fp1 <- qual_reference_refit(ref)
  fp2 <- qual_reference_refit(ref)
  expect_identical(fp1$ofv, fp2$ofv)       # same seed -> bit-identical re-fits
})
