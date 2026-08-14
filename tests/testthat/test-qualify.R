test_that("qualify re-fits each reference at its thread count and reports a verdict", {
  skip_if_no_live()
  dir <- tempfile(); dir.create(dir)
  ref <- qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                            method = "focei", threads = 1L)
  qual_reference_write(ref, file.path(dir, paste0(ref$id, ".json")))

  res <- qualify(which = "all", source = dir)
  expect_s3_class(res, "nlmixr2qual_result")
  expect_equal(nrow(res$summary), 1L)
  expect_equal(res$summary$id[1], "theophylline__focei__t1")
  expect_equal(res$summary$threads[1], 1L)
  expect_true(res$summary$pass[1])            # local re-fit reproduces reference
  expect_true(res$overall)                    # OVERALL PASS
})

test_that("qualify supports a multi-threaded reference (same machine)", {
  skip_if_no_live()
  n <- qual_invariance_threads()
  skip_if(n <= 1L, "single-core box: no multi-threaded stage to test")
  dir <- tempfile(); dir.create(dir)
  zip <- build_bundle(dir, "theo_focei_multi", est = "focei", threads = n)
  ref <- qual_import_bundle(zip, model_name = "theophylline", method = "focei",
                            threads = n)
  qual_reference_write(ref, file.path(dir, paste0(ref$id, ".json")))
  file.remove(zip)                            # keep only the JSON references
  res <- qualify("theophylline__focei", dir)  # selects the tN variant
  expect_equal(res$summary$threads[1], as.integer(n))
  expect_true(res$summary$pass[1])            # reproduces at N threads, same box
  expect_true(res$overall)
})
