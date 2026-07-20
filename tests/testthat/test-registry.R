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

test_that("registry ships the robust core: >= 7 models, valid domains, PK anchors", {
  reg <- qual_registry()
  # Robust core shipped in this milestone: popPK (5) + disease (2). PKPD and ER
  # domains, plus the heavier literature models, are a tracked follow-up.
  expect_gte(nrow(reg), 7)
  expect_true(all(reg$domain %in% c("popPK", "PKPD", "disease", "ER")))
  expect_true(all(c("popPK", "disease") %in% reg$domain))
  # anchors (the thread-invariance re-fit set) are the two simplest popPK models
  expect_setequal(reg$name[reg$anchor], c("PK_1cmt", "PK_2cmt"))
  # every registry dataset must be present under inst/data/
  for (ds in reg$dataset) {
    expect_true(file.exists(.qual_pkg_file("data", ds)), info = ds)
  }
})

test_that("duplicate model names are rejected", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("name,source,dataset,domain,method,stochastic,strict,anchor,tol_override,eta",
               "M,lib,d.csv,popPK,focei,FALSE,TRUE,FALSE,,",
               "M,lib,d.csv,popPK,saem,TRUE,TRUE,FALSE,,"), tmp)
  expect_error(qual_registry(path = tmp), "duplicate")
})
