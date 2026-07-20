#!/usr/bin/env Rscript
# Top-level qualification runner. Single entry point for a qualification run:
# loads the package, pins single-threaded fitting for the strict stage, runs the
# strict + thread-invariance stages against the shipped canonical baseline, and
# renders the Quarto report + plain-text verdict/summary. Exits non-zero on a
# FAIL verdict so it can gate a CI pipeline.

if (requireNamespace("pkgload", quietly = TRUE) &&
    file.exists("DESCRIPTION")) {
  suppressMessages(pkgload::load_all(".", quiet = TRUE))
} else {
  suppressMessages(library(nlmixr2qual))
}

cores   <- parallel::detectCores()
# Strict stage fits one model at a time, single-threaded, so the canonical
# baseline is reproduced under the exact conditions it was cut.
qual_set_threads(qual_thread_plan(cores, workers = 1L, mode = "single")$inner)

registry <- qual_registry()
vg       <- qual_version_gate()
# Invariance stage uses a stable, capped multi-thread count (not all cores):
# it only needs threads > 1 to be meaningful, and oversubscribing a small
# problem on a many-core box can crash the OpenMP solver.
run      <- qual_run(registry, run_invariance = TRUE,
                     anchor_threads = qual_invariance_threads(cores))
bundle   <- qual_report(run, version_gate = vg,
                        dir = "qualification_output",
                        render = TRUE, formats = "html")

cat("OVERALL:", bundle$verdict$verdict, "\n")
quit(status = if (identical(bundle$verdict$verdict, "PASS")) 0L else 1L)
