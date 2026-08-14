test_that("a reference round-trips through JSON unchanged", {
  ref <- list(
    schema_version = "1.0.0",
    id = "demo__focei__t1",
    model = list(name = "demo", code = "one <- function(){}", description = "d"),
    data = list(name = "dat", records = data.frame(ID = 1:2, DV = c(1.1, 2.2))),
    method = list(est = "focei", control = NULL),
    reference = list(
      threads = 1L, ofv = 116.8041,
      params = data.frame(name = "tka", ptype = "theta", estimate = 0.46,
                          se = 0.19, rse = 42.0, stringsAsFactors = FALSE),
      shrink = data.frame(name = "eta.ka", stype = "eta", value = 1.86,
                          stringsAsFactors = FALSE),
      converged = TRUE, covMethod = "r,s", stochastic = FALSE,
      category = "Linearized"),
    provenance = list(software = list(nlmixr2 = "6.0.0"),
                      created = "2026-08-13T00:00:00Z",
                      source_bundle = "demo.zip",
                      nlmixr2save_version = "0.1.0"))
  path <- tempfile(fileext = ".json")
  qual_reference_write(ref, path)
  back <- qual_reference_read(path)
  expect_equal(back$id, ref$id)
  expect_equal(back$reference$threads, 1L)
  expect_equal(back$reference$ofv, 116.8041)
  expect_equal(back$data$records$DV, c(1.1, 2.2))
  expect_equal(back$reference$params$estimate, 0.46)
  expect_true(qual_reference_validate(back))
})

test_that("validate rejects a reference missing required fields", {
  expect_error(qual_reference_validate(list(id = "x")), "schema_version")
})

test_that("pair and id helpers agree", {
  ref <- list(model = list(name = "demo"), method = list(est = "focei"),
              reference = list(threads = 4L))
  expect_equal(qual_reference_pair(ref), "demo__focei")
  expect_equal(qual_reference_id(ref), "demo__focei__t4")
})
