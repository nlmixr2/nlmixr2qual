test_that("import builds a valid thread-tagged reference from a bundle", {
  skip_if_no_live()
  ref <- qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                            method = "focei", threads = 1L,
                            description = "1-cmt oral PK")
  expect_true(qual_reference_validate(ref))
  expect_equal(ref$method$est, "focei")
  expect_equal(ref$reference$threads, 1L)
  expect_equal(ref$id, "theophylline__focei__t1")
  expect_gt(nrow(ref$data$records), 100)          # embedded data
  expect_equal(ref$reference$ofv, 116.8041, tolerance = 1e-2)
  expect_true(any(ref$reference$params$ptype == "omega"))
  expect_true(ref$reference$converged)
  e <- new.env(); eval(parse(text = ref$model$code), envir = e)
  expect_true(exists("theophylline", envir = e))   # model source reconstructs
})

test_that("import requires an explicit thread count", {
  skip_if_no_live()
  expect_error(qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                                  method = "focei"),
               "threads")
})
