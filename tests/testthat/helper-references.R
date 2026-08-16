fixture_bundle <- function(name = "theophylline_focei.zip") {
  testthat::test_path("fixtures", name)
}
skip_if_no_live <- function() {
  testthat::skip_on_cran()   # live model fitting is far too slow for CRAN's check
  testthat::skip_if_not_installed("nlmixr2est")
  testthat::skip_if_not_installed("nlmixr2save")
  testthat::skip_if(!nzchar(Sys.getenv("NLMIXR2QUAL_RUN_LIVE")),
                    "set NLMIXR2QUAL_RUN_LIVE=1 for live fitting tests")
}
.theo_one_cmt <- function() {
  ini({ tka <- 0.45; tcl <- log(c(0, 2.7, 100)); tv <- 3.45
        eta.ka ~ 0.6; eta.cl ~ 0.3; eta.v ~ 0.1; add.sd <- 0.7 })
  model({ ka <- exp(tka + eta.ka); cl <- exp(tcl + eta.cl); v <- exp(tv + eta.v)
          linCmt() ~ add(add.sd) })
}

# A live fit of the shared theophylline model, for tests that import directly
# from a fit object rather than a saved bundle.
fresh_fit <- function(est = "focei", threads = 1L, control = NULL) {
  suppressMessages(library(nlmixr2est)); library(nlmixr2data)
  rxode2::rxClean(); rxode2::setRxThreads(as.integer(threads))
  if (is.null(control)) {
    nlmixr2est::nlmixr2(.theo_one_cmt, nlmixr2data::theo_sd, est = est)
  } else {
    nlmixr2est::nlmixr2(.theo_one_cmt, nlmixr2data::theo_sd, est = est, control = control)
  }
}

# Build a bundle from a live fit at a given thread count, into `dir`. Returns
# the .zip path. Used for multi-threaded (machine-specific) tests, and for
# seed-related tests via `control`.
build_bundle <- function(dir, base, est = "focei", threads = 1L, control = NULL) {
  fit <- fresh_fit(est = est, threads = threads, control = control)
  suppressMessages(library(nlmixr2save))
  old <- setwd(dir); on.exit(setwd(old))
  unlink(paste0(base, ".zip"))
  nlmixr2save::saveFit(fit, base, zip = TRUE)
  file.path(dir, paste0(base, ".zip"))
}
