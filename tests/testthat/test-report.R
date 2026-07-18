# test-report.R
test_that("qual_report assembles a results bundle and writes it", {
  d <- withr::local_tempdir()
  res <- list(results = list(list(model = "A", method = "focei",
                strict = TRUE, pass = TRUE, detail = data.frame(
                  quantity = "ofv", baseline = 1, observed = 1,
                  reldiff = 0, tol = 1e-3, pass = TRUE))),
              invariance = NULL,
              provenance = qual_provenance(1L, 1L))
  vg <- list(pass = TRUE, detail = data.frame(package = "nlmixr2",
              expected = "3.0.0", observed = "3.0.0", status = "match", pass = TRUE))
  bundle <- qual_report(res, version_gate = vg, dir = d, render = FALSE)
  expect_true(file.exists(file.path(d, "qualification_bundle.rds")))
  expect_equal(bundle$verdict$verdict, "PASS")
  # pipeline-compat text artifacts are emitted too
  expect_true(file.exists(file.path(d, "qualification_verdict.txt")))
})
