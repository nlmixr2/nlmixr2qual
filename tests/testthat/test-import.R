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

test_that("import captures an explicit seed", {
  skip_if_no_live()
  ref <- qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                            method = "focei", threads = 1L, seed = 42L)
  expect_equal(ref$method$seed, 42L)
})

test_that("import extracts a seed already present in the bundle's control", {
  skip_if_no_live()
  dir <- tempfile(); dir.create(dir)
  zip <- build_bundle(dir, "theo_saem_seeded", est = "saem",
                      control = nlmixr2est::saemControl(seed = 777L, nBurn = 5, nEm = 5))
  ref <- qual_import_bundle(zip, model_name = "theophylline", method = "saem",
                            threads = 1L)
  expect_equal(ref$method$seed, 777L)
})

test_that("an explicit seed overrides the bundle's own control seed", {
  skip_if_no_live()
  dir <- tempfile(); dir.create(dir)
  zip <- build_bundle(dir, "theo_saem_seeded2", est = "saem",
                      control = nlmixr2est::saemControl(seed = 777L, nBurn = 5, nEm = 5))
  ref <- qual_import_bundle(zip, model_name = "theophylline", method = "saem",
                            threads = 1L, seed = 111L)
  expect_equal(ref$method$seed, 111L)
})

test_that("no seed is captured for a method that was not fit with one", {
  skip_if_no_live()
  ref <- qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                            method = "focei", threads = 1L)
  expect_null(ref$method$seed)
})

test_that("import_fit builds a valid reference directly from a live fit object", {
  skip_if_no_live()
  fit <- fresh_fit(est = "focei", threads = 1L)
  ref <- qual_import_fit(fit, model_name = "theophylline", threads = 1L,
                         description = "1-cmt oral PK")
  expect_true(qual_reference_validate(ref))
  expect_equal(ref$method$est, "focei")     # inferred from fit$est, not supplied
  expect_equal(ref$reference$threads, 1L)
  expect_equal(ref$id, "theophylline__focei__t1")
  expect_gt(nrow(ref$data$records), 100)    # embedded data (fit$origData)
  expect_true(any(ref$reference$params$ptype == "omega"))
  expect_true(ref$reference$converged)
  e <- new.env(); eval(parse(text = ref$model$code), envir = e)
  expect_true(exists("theophylline", envir = e))  # model source reconstructs
})

test_that("import_fit requires an explicit thread count", {
  skip_if_no_live()
  fit <- fresh_fit(est = "focei", threads = 1L)
  expect_error(qual_import_fit(fit, model_name = "theophylline"), "threads")
})

test_that("import_fit's reference re-fits and reproduces the source fit's OFV", {
  skip_if_no_live()
  fit <- fresh_fit(est = "focei", threads = 1L)
  ref <- qual_import_fit(fit, model_name = "theophylline", threads = 1L)
  fp <- qual_reference_refit(ref)
  expect_equal(fp$ofv, fit$objf, tolerance = 1e-3)
})

test_that("import_fit captures a seed already present in a live fit's control", {
  skip_if_no_live()
  fit <- fresh_fit(est = "saem", threads = 1L,
                   control = nlmixr2est::saemControl(seed = 321L, nBurn = 5, nEm = 5))
  ref <- qual_import_fit(fit, model_name = "theophylline", threads = 1L)
  expect_equal(ref$method$est, "saem")
  expect_equal(ref$method$seed, 321L)
})
