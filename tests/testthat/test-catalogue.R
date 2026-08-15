test_that("catalogue summarises references as a data frame", {
  refs <- qual_load_references("internal")
  cat_df <- qual_catalogue(refs)
  expect_true(all(c("id", "model", "method", "threads", "ofv", "stochastic",
                    "nlmixr2_version") %in% names(cat_df)))
  expect_equal(nrow(cat_df), length(refs))
})

test_that("catalogue renders a Markdown table", {
  refs <- qual_load_references("internal")
  md <- qual_catalogue_md(refs)
  expect_true(grepl("\\| id \\|", md))
})
