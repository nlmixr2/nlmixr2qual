# test-threads.R
test_that("thread plan never oversubscribes cores", {
  expect_equal(qual_thread_plan(cores = 8, workers = 8, mode = "single")$inner, 1)
  expect_equal(qual_thread_plan(cores = 8, workers = 1, mode = "multi")$inner, 8)
  expect_equal(qual_thread_plan(cores = 8, workers = 4, mode = "multi")$inner, 2)
  # workers exceeding cores still yields >=1 inner thread
  expect_equal(qual_thread_plan(cores = 4, workers = 8, mode = "single")$inner, 1)
})

test_that("qual_set_threads writes the env var and OMP/MKL vars", {
  withr::local_envvar(c(NLMIXR2QUAL_INNER_THREADS = NA,
                        OMP_NUM_THREADS = NA, MKL_NUM_THREADS = NA))
  qual_set_threads(inner = 3L, apply_rx = FALSE)
  expect_identical(Sys.getenv("NLMIXR2QUAL_INNER_THREADS"), "3")
  expect_identical(Sys.getenv("OMP_NUM_THREADS"), "3")
  expect_identical(Sys.getenv("MKL_NUM_THREADS"), "3")
})
