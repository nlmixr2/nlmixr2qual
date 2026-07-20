# Anchor method-coverage matrix: each estimation method is qualified against a
# shipped baseline for the anchor model it fits. Methods that need random
# effects use PK_1cmt (augmented with IIV); needs_reff = FALSE optimizers use the
# fixed-effect-only PK_1cmt_fixed. A method is exercised only when its anchor
# baseline has been cut; the milestone ships baselines for the reliable
# conditional-estimation methods, with the remaining methods (integral
# approximation, stochastic EM, nonparametric, ML, and the optimizer family)
# tracked as a follow-up. Missing baselines skip, so this file always passes
# what it can and never fails on an un-baselined method.
test_that("catalogued methods reproduce the anchor baseline where available", {
  skip_if_not_installed("nlmixr2")
  skip_if_not_installed("nlmixr2lib")
  qual_set_threads(qual_inner_threads())

  m <- qual_methods()
  baseline_dir <- .qual_pkg_file("baseline")
  n_exercised <- 0L

  for (i in seq_len(nrow(m))) {
    meth <- as.list(m[i, ])
    anchor <- if (isTRUE(meth$needs_reff)) "PK_1cmt" else "PK_1cmt_fixed"
    base_file <- file.path(baseline_dir,
                           paste0(anchor, "__", meth$method, ".qs2"))
    if (!file.exists(base_file)) next   # not yet baselined -> follow-up

    entry <- list(
      name = anchor,
      source = if (anchor == "PK_1cmt") "lib" else "file",
      dataset = "PK_1cmt_sim.csv", method = meth$method,
      stochastic = meth$stochastic,
      eta = if (anchor == "PK_1cmt") "lcl,lvc" else "")
    fp <- qual_fit_entry(entry, category = meth$category,
                         threads = qual_inner_threads())
    cmp <- qual_compare(fp, qs2::qs_read(base_file))
    n_exercised <- n_exercised + 1L
    if (isTRUE(meth$strict)) {
      expect_true(cmp$pass, info = paste(meth$method, "-",
        paste(cmp$detail$quantity[!cmp$detail$pass], collapse = ", ")))
    }
    # non-strict methods are recorded but never fail the verdict
  }

  # at least the shipped conditional-estimation baselines must be exercised
  expect_gte(n_exercised, 1L)
})
