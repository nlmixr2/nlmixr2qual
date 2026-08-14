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
