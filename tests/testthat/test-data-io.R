# test-data-io.R
test_that("qual_read_dataset loads a frozen dataset by ref", {
  d <- qual_read_dataset("PK_1cmt_sim.csv")
  expect_s3_class(d, "data.frame")
  expect_true(all(c("ID","TIME","DV","AMT","EVID") %in% names(d)))
  expect_gt(nrow(d), 0)
})

test_that("missing dataset errors clearly", {
  expect_error(qual_read_dataset("nope.csv"), "not found")
})
