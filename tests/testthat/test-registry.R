# test-registry.R
test_that("qual_registry reads and validates model rows", {
  reg <- qual_registry()
  expect_s3_class(reg, "data.frame")
  expect_true(all(c("name","source","dataset","domain","method",
                    "stochastic","strict","anchor") %in% names(reg)))
  expect_type(reg$stochastic, "logical")
  expect_type(reg$strict, "logical")
  expect_true("PK_1cmt" %in% reg$name)
})

test_that("qual_methods reads the method matrix schema", {
  m <- qual_methods()
  expect_true(all(c("method","category","stochastic","strict","needs_reff")
                  %in% names(m)))
  expect_type(m$needs_reff, "logical")
})

test_that("duplicate model names are rejected", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("name,source,dataset,domain,method,stochastic,strict,anchor,tol_override",
               "M,lib,d.csv,popPK,focei,FALSE,TRUE,FALSE,",
               "M,lib,d.csv,popPK,saem,TRUE,TRUE,FALSE,"), tmp)
  expect_error(qual_registry(path = tmp), "duplicate")
})
