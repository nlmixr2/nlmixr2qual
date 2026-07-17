# test-provenance.R
test_that("provenance captures environment and thread config", {
  p <- qual_provenance(inner_threads = 1L, workers = 4L)
  expect_true(all(c("os","arch","r_version","blas","lapack","compiler",
                    "inner_threads","workers","nlmixr2") %in% names(p)))
  expect_equal(p$inner_threads, 1L)
  expect_equal(p$workers, 4L)
})

test_that("provenance round-trips through json", {
  p <- qual_provenance(inner_threads = 2L, workers = 1L)
  f <- withr::local_tempfile(fileext = ".json")
  qual_write_provenance(p, f)
  q <- qual_read_provenance(f)
  expect_equal(q$inner_threads, 2L)
  expect_equal(q$os, p$os)
})
