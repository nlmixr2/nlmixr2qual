# test-run.R
test_that("qual_run compares each model to baseline and builds results", {
  d <- withr::local_tempdir()
  reg <- data.frame(name = "A", source = "lib", dataset = "a.csv",
                    domain = "popPK", method = "focei", stochastic = FALSE,
                    strict = TRUE, anchor = FALSE, tol_override = NA, eta = "",
                    stringsAsFactors = FALSE)
  base_fp <- qual_extract_fit(fake_fit(), "A", "focei", "Linearized", FALSE, 1L)
  qs2::qs_save(base_fp, file.path(d, "A__focei.qs2"))
  # run fitter reproduces baseline exactly -> PASS
  stub <- function(entry, category, threads = 1L)
    qual_extract_fit(fake_fit(), entry$name, entry$method, category,
                     FALSE, threads)
  out <- qual_run(reg, baseline_dir = d, fitter = stub,
                  run_invariance = FALSE,
                  methods = data.frame(method = "focei", category = "Linearized",
                                       stringsAsFactors = FALSE))
  expect_length(out$results, 1)
  expect_true(out$results[[1]]$pass)
  expect_true(out$results[[1]]$strict)
})

test_that("qual_run runs the invariance stage for anchors only", {
  d <- withr::local_tempdir()
  reg <- data.frame(name = c("A","B"), source = "lib",
                    dataset = c("a.csv","b.csv"), domain = "popPK",
                    method = "focei", stochastic = FALSE, strict = TRUE,
                    anchor = c(TRUE, FALSE), tol_override = NA, eta = "",
                    stringsAsFactors = FALSE)
  for (nm in c("A","B")) {
    fp <- qual_extract_fit(fake_fit(), nm, "focei", "Linearized", FALSE, 1L)
    qs2::qs_save(fp, file.path(d, paste0(nm, "__focei.qs2")))
  }
  stub <- function(entry, category, threads = 1L)
    qual_extract_fit(fake_fit(), entry$name, entry$method, category,
                     FALSE, threads)
  out <- qual_run(reg, baseline_dir = d, fitter = stub,
                  run_invariance = TRUE, anchor_threads = 2L,
                  methods = data.frame(method = "focei", category = "Linearized",
                                       stringsAsFactors = FALSE))
  expect_length(out$results, 2)          # strict: both models
  expect_length(out$invariance, 1)       # invariance: anchor A only
  expect_identical(out$invariance[[1]]$model, "A")
})
