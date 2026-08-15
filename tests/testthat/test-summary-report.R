fake_result <- function(pass = TRUE, overall = TRUE, threads = 1L) {
  structure(list(
    summary = data.frame(
      id = sprintf("theophylline__focei__t%d", threads), model = "theophylline",
      method = "focei", threads = as.integer(threads), strict = TRUE,
      pass = pass, ofv_ref = 116.8, ofv_local = 116.8, stringsAsFactors = FALSE),
    details = list(), provenance = qual_provenance(), overall = overall),
    class = "nlmixr2qual_result")
}

test_that("summary report writes an HTML file from a result", {
  skip_if_not_installed("quarto")
  out <- tempfile(fileext = ".html")
  qual_summary_report(fake_result(), out)
  expect_true(file.exists(out))
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
