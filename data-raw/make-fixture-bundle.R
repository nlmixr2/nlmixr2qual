# Generates tests/testthat/fixtures/theophylline_focei.zip from a real
# SINGLE-THREADED fit (portable across machines). Run once on a normal
# filesystem: Rscript data-raw/make-fixture-bundle.R
suppressMessages(library(nlmixr2est)); library(nlmixr2data)
rxode2::setRxThreads(1L)
one.cmt <- function() {
  ini({ tka <- 0.45; tcl <- log(c(0, 2.7, 100)); tv <- 3.45
        eta.ka ~ 0.6; eta.cl ~ 0.3; eta.v ~ 0.1; add.sd <- 0.7 })
  model({ ka <- exp(tka + eta.ka); cl <- exp(tcl + eta.cl); v <- exp(tv + eta.v)
          linCmt() ~ add(add.sd) })
}
dir <- "tests/testthat/fixtures"; dir.create(dir, showWarnings = FALSE, recursive = TRUE)
old <- setwd(dir); on.exit(setwd(old))
fit <- nlmixr2(one.cmt, theo_sd, est = "focei")
unlink("theophylline_focei.zip")
nlmixr2save::saveFit(fit, "theophylline_focei", zip = TRUE)
cat("wrote", file.path(dir, "theophylline_focei.zip"), "\n")
