# test-capture.R
test_that("capture writes one baseline file per model and provenance", {
  d <- withr::local_tempdir()
  reg <- data.frame(name = c("A","B"), source = "lib",
                    dataset = c("a.csv","b.csv"), domain = "popPK",
                    method = "focei", stochastic = FALSE, strict = TRUE,
                    anchor = FALSE, tol_override = NA, eta = "",
                    stringsAsFactors = FALSE)
  stub <- function(entry, category, threads = 1L)
    qual_extract_fit(fake_fit(), entry$name, entry$method, category,
                     FALSE, threads)
  qual_capture_baseline(reg, dir = d, fitter = stub,
                        methods = data.frame(method = "focei",
                                             category = "Linearized",
                                             stringsAsFactors = FALSE))
  expect_true(file.exists(file.path(d, "A__focei.qs2")))
  expect_true(file.exists(file.path(d, "B__focei.qs2")))
  expect_true(file.exists(file.path(d, "provenance.json")))
  # category was resolved from the methods table, not hardcoded
  fp <- qs2::qs_read(file.path(d, "A__focei.qs2"))
  expect_identical(fp$category, "Linearized")
})
