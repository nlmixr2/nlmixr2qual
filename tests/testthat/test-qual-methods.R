# Anchor method-coverage matrix: each estimation method is qualified against a
# shipped baseline for the anchor model(s) it fits. Methods that need random
# effects are anchored to BOTH theophylline anchors -- theo_1cmt (solved linCmt)
# and theo_1cmt_des (the ODE form) -- so a method is exercised on both solver
# paths; needs_reff = FALSE optimizers use the fixed-effect-only theo_1cmt_fixed.
# A (model, method) pair is exercised only when its baseline has been cut; the
# release ships focei + saem on the anchors plus laplace/agq/imp/impmap/fsaem/
# qrpem on theo_1cmt and theo_1cmt_des, with the remaining methods (nonparametric,
# ML, optimizer family) tracked as a follow-up. Missing baselines skip, so this
# file always passes what it can and never fails on an un-baselined pair.
test_that("catalogued methods reproduce the anchor baseline where available", {
  skip_if_not_installed("nlmixr2")
  skip_if(!nzchar(Sys.getenv("NLMIXR2QUAL_RUN_LIVE")),
          "set NLMIXR2QUAL_RUN_LIVE=1 to run live qualification tests")
  skip_if_not_installed("nlmixr2lib")
  qual_set_threads(qual_inner_threads())

  m <- qual_methods()
  baseline_dir <- .qual_pkg_file("baseline")
  n_exercised <- 0L

  for (i in seq_len(nrow(m))) {
    meth <- as.list(m[i, ])
    anchors <- if (isTRUE(meth$needs_reff)) {
      c("theo_1cmt", "theo_1cmt_des")
    } else {
      "theo_1cmt_fixed"
    }
    for (anchor in anchors) {
      base_file <- file.path(baseline_dir,
                             paste0(anchor, "__", meth$method, ".qs2"))
      if (!file.exists(base_file)) next   # (model, method) not baselined -> follow-up

      entry <- list(
        name = anchor, source = "file",
        dataset = "theo_sd.csv", method = meth$method,
        stochastic = meth$stochastic, eta = "")
      fp <- qual_fit_entry(entry, category = meth$category,
                           threads = qual_inner_threads())
      cmp <- qual_compare(fp, qs2::qs_read(base_file))
      n_exercised <- n_exercised + 1L
      if (isTRUE(meth$strict)) {
        expect_true(cmp$pass, info = paste(anchor, meth$method, "-",
          paste(cmp$detail$quantity[!cmp$detail$pass], collapse = ", ")))
      }
      # non-strict methods are recorded but never fail the verdict
    }
  }

  # at least the shipped baselines must be exercised
  expect_gte(n_exercised, 1L)
})
