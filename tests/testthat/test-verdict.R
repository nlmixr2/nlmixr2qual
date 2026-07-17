# test-verdict.R
make_result <- function(model, method, pass, strict) {
  list(model = model, method = method, pass = pass, strict = strict,
       detail = data.frame())
}

test_that("verdict is PASS only if every strict result passes", {
  res <- list(make_result("A","focei", TRUE, TRUE),
              make_result("B","saem",  FALSE, FALSE),  # informational fail: ignored
              make_result("C","nlminb",TRUE, TRUE))
  v <- qual_verdict(res, version_gate = list(pass = TRUE))
  expect_equal(v$verdict, "PASS")
})

test_that("a strict failure forces FAIL", {
  res <- list(make_result("A","focei", FALSE, TRUE))
  v <- qual_verdict(res, version_gate = list(pass = TRUE))
  expect_equal(v$verdict, "FAIL")
})

test_that("version gate failure forces FAIL", {
  res <- list(make_result("A","focei", TRUE, TRUE))
  v <- qual_verdict(res, version_gate = list(pass = FALSE))
  expect_equal(v$verdict, "FAIL")
})

test_that("qual_write_text emits verdict and summary files", {
  d <- withr::local_tempdir()
  res <- list(make_result("A","focei", TRUE, TRUE))
  v <- qual_verdict(res, version_gate = list(pass = TRUE))
  qual_write_text(v, res, dir = d)
  expect_identical(readLines(file.path(d, "qualification_verdict.txt")), "PASS")
  expect_true(any(grepl("OVERALL: PASS",
                        readLines(file.path(d, "qualification_summary.txt")))))
})
