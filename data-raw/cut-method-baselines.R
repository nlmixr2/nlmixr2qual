# Cut method-coverage anchor baselines (deliberate; single-threaded).
#
# For every catalogued method (inst/models/methods.csv) this cuts the shipped
# `<anchor>__<method>.qs2` fingerprint the method-coverage test qualifies against,
# following the same anchor rule as tests/testthat/test-qual-methods.R:
#   needs_reff  -> both theophylline anchors: theo_1cmt (solved linCmt)
#                  and theo_1cmt_des (ODE form)
#   !needs_reff -> theo_1cmt_fixed (fixed-effects-only, optimizer family)
#
# It NEVER clobbers an existing baseline (baselines are frozen once cut, exactly
# like the simulated datasets), and it skips any (anchor, method) pair whose fit
# errors in this environment (e.g. fo/foi/nlme/npag/npb/advi/vae currently), so
# re-running is safe and only fills genuine gaps. Run from the package root:
#   Rscript data-raw/cut-method-baselines.R
suppressMessages(rxode2::rxClean())
suppressMessages(pkgload::load_all(".", quiet = TRUE))
qual_set_threads(1L)

# Methods this cutter is allowed to (re)cut. Everything else is deliberately
# deferred and left un-baselined so the coverage test skips it:
#   fo/foi/nlme      - error in this environment (reject controls / missing
#                      .nlmixrNlmeFun); revisit if the engine wiring changes.
#   npag/npb         - nonparametric; npag was observed to fit + extract via the
#                      standard accessors, so it is a strong future candidate,
#                      but deferred pending a deliberate extraction audit.
#   advi/vae         - machine-learning; slow/uncertain backend, not yet vetted.
enabled <- c(
  # already shipped (guarded by file.exists below)
  "focei", "saem", "laplace", "agq", "imp", "impmap", "fsaem", "qrpem",
  # linearized conditional (deterministic, strict)
  "foce", "focep",
  # optimizer (NLM) family on the fixed-effect anchor: clean-converging four
  # are strict, the rest informational (see inst/models/methods.csv)
  "nlm", "nlminb", "bobyqa", "newuoa", "uobyqa", "n1qn1", "lbfgsb3c", "optim", "nls")

methods      <- qual_methods()
methods      <- methods[methods$method %in% enabled, , drop = FALSE]
baseline_dir <- file.path("inst", "baseline")
dir.create(baseline_dir, showWarnings = FALSE, recursive = TRUE)

cut <- character(0); skipped <- character(0); failed <- character(0)

for (i in seq_len(nrow(methods))) {
  meth <- as.list(methods[i, ])
  anchors <- if (isTRUE(meth$needs_reff)) {
    c("theo_1cmt", "theo_1cmt_des")
  } else {
    "theo_1cmt_fixed"
  }
  for (anchor in anchors) {
    tag  <- paste0(anchor, "__", meth$method)
    file <- file.path(baseline_dir, paste0(tag, ".qs2"))
    if (file.exists(file)) { skipped <- c(skipped, tag); next }  # frozen -> leave

    entry <- list(name = anchor, source = "file", dataset = "theo_sd.csv",
                  method = meth$method, stochastic = meth$stochastic, eta = "")
    fp <- tryCatch(
      qual_fit_entry(entry, category = meth$category, threads = 1L),
      error = function(e) { message(sprintf("  skip %s: %s", tag, conditionMessage(e))); NULL })
    if (is.null(fp)) { failed <- c(failed, tag); next }
    qs2::qs_save(fp, file)
    cut <- c(cut, tag)
  }
}

cat(sprintf("\nCUT %d new baseline(s):\n  %s\n", length(cut),
            paste(cut, collapse = "\n  ")))
cat(sprintf("KEPT %d existing (frozen).\n", length(skipped)))
if (length(failed)) cat(sprintf("SKIPPED %d infeasible in this env:\n  %s\n",
                                 length(failed), paste(failed, collapse = "\n  ")))
