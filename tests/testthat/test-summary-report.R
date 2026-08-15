fake_result <- function(pass = TRUE, overall = TRUE, threads = 1L) {
  id <- sprintf("theophylline__focei__t%d", threads)
  details <- stats::setNames(list(data.frame(
    quantity = c("ofv", "theta:tka", "omega:eta.ka"),
    class = c("ofv", "theta", "omega"),
    baseline = c(116.8, 0.45, 0.40),
    observed = c(116.8, 0.451, 0.403),
    reldiff = c(0, 0.0022, 0.0075),
    tol = c(1e-3, 1e-2, 1e-2),
    pass = c(TRUE, TRUE, TRUE), stringsAsFactors = FALSE)), id)
  structure(list(
    summary = data.frame(
      id = id, model = "theophylline",
      method = "focei", threads = as.integer(threads), strict = TRUE,
      pass = pass, ofv_ref = 116.8, ofv_local = 116.8, stringsAsFactors = FALSE),
    details = details, provenance = qual_provenance(), overall = overall),
    class = "nlmixr2qual_result")
}

test_that("summary report writes an HTML file with per-reference comparison detail", {
  skip_on_cran()   # depends on the external quarto CLI, not just the R package
  skip_if_not_installed("quarto")
  out <- tempfile(fileext = ".html")
  qual_summary_report(fake_result(), out)
  expect_true(file.exists(out))
  body <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(body, "theophylline__focei__t1", fixed = TRUE)
  expect_match(body, "theta:tka", fixed = TRUE)
  expect_match(body, "omega:eta.ka", fixed = TRUE)
})

test_that("plain-text verdict reports per-reference pass with thread count", {
  txt <- tempfile(fileext = ".txt")
  qual_summary_text(fake_result(threads = 4L), txt)
  body <- paste(readLines(txt), collapse = "\n")
  expect_match(body, "OVERALL: PASS")
  expect_match(body, "threads:4")
  expect_match(body, "PASS")
})

test_that("verdict shows FAIL when a strict reference fails", {
  txt <- tempfile(fileext = ".txt")
  qual_summary_text(fake_result(pass = FALSE, overall = FALSE), txt)
  expect_match(paste(readLines(txt), collapse = "\n"), "OVERALL: FAIL")
})
