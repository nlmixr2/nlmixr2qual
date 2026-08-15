# Build the shipped internal reference set: theophylline across every method that
# produces a valid fit, at BOTH thread counts (1 and qual_default_multi_threads()).
# Each (method, threads) is fit + saved + imported as one thread-tagged reference.
# Run on a >=4-core normal filesystem: Rscript data-raw/make-theophylline-references.R
suppressMessages(rxode2::rxClean())
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressMessages(library(nlmixr2est)); library(nlmixr2data)

one.cmt <- function() {
  ini({ tka <- 0.45; tcl <- log(c(0, 2.7, 100)); tv <- 3.45
        eta.ka ~ 0.6; eta.cl ~ 0.3; eta.v ~ 0.1; add.sd <- 0.7 })
  model({ ka <- exp(tka + eta.ka); cl <- exp(tcl + eta.cl); v <- exp(tv + eta.v)
          linCmt() ~ add(add.sd) })
}

# Methods confirmed to fit theophylline in prior work. Stochastic ones
# (saem/fsaem/imp/impmap/qrpem) qualify as informational. Extend as coverage grows.
methods <- c("focei", "foce", "focep", "laplace", "agq",
             "saem", "fsaem", "imp", "impmap", "qrpem")
# t1 is always produced; t4 only when this box can run 4 cores natively (optional).
thread_counts <- c(1L)
if (parallel::detectCores() >= qual_default_multi_threads())
  thread_counts <- c(thread_counts, qual_default_multi_threads())

# Stochastic methods are pinned to a fixed seed so a same-machine re-fit is
# exactly reproducible rather than only tolerance-compared (see
# qual_import_bundle()'s `seed` argument / R/refit.R's control building).
.qual_stochastic_control <- function(m, seed = 99L) {
  switch(m,
        saem = , fsaem = nlmixr2est::saemControl(seed = seed),
        imp = nlmixr2est::impControl(impSeed = seed),
        impmap = nlmixr2est::impmapControl(impSeed = seed),
        qrpem = nlmixr2est::qrpemControl(impSeed = seed),
        NULL)
}

outdir <- "inst/references"; dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
tmp <- file.path(tempdir(), "theo-bundles"); dir.create(tmp, showWarnings = FALSE)

for (nthr in thread_counts) {
  for (m in methods) {
    message("fitting theophylline / ", m, " @ ", nthr, " thread(s)")
    rxode2::rxClean(); rxode2::setRxThreads(nthr)
    ctl <- .qual_stochastic_control(m)
    fit <- tryCatch(
      if (is.null(ctl)) nlmixr2(one.cmt, theo_sd, est = m)
      else nlmixr2(one.cmt, theo_sd, est = m, control = ctl),
      error = function(e) { message("  skip: ", conditionMessage(e)); NULL })
    if (is.null(fit)) next
    old <- setwd(tmp); base <- paste0("theophylline_", m, "_t", nthr)
    unlink(paste0(base, ".zip")); nlmixr2save::saveFit(fit, base, zip = TRUE)
    setwd(old)
    ref <- qual_import_bundle(file.path(tmp, paste0(base, ".zip")),
                              model_name = "theophylline", method = m, threads = nthr,
                              description = "1-compartment oral PK, theophylline")
    qual_reference_write(ref, file.path(outdir, paste0(ref$id, ".json")))
  }
}
cat("wrote references:\n"); print(list.files(outdir))
