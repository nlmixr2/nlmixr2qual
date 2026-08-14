# threads.R
#
# This suite must never let process-level parallelism (testthat workers)
# and thread-level parallelism (rxode2 OpenMP threads inside a fit) both
# run at full width: that oversubscribes cores AND makes results
# non-reproducible (parallel reductions sum in thread-count-dependent
# order). This file is the ONLY code in the package allowed to set
# thread counts. Everything else must call qual_inner_threads() to read
# the budget, never set it directly.

#' Compute an inner-thread count that does not oversubscribe cores
#'
#' @param cores Available cores.
#' @param workers Number of outer (testthat) worker processes.
#' @param mode "single" (inner = 1) or "multi" (share cores across workers).
#' @return `list(cores, workers, mode, inner)`.
#' @export
qual_thread_plan <- function(cores = parallel::detectCores(),
                             workers = 1L, mode = c("single", "multi")) {
  mode <- match.arg(mode)
  inner <- if (mode == "single") 1L else max(1L, cores %/% max(1L, workers))
  list(cores = as.integer(cores), workers = as.integer(workers),
       mode = mode, inner = as.integer(inner))
}

#' Apply the inner-thread count to every thread control (the ONLY setter)
#'
#' Sets `NLMIXR2QUAL_INNER_THREADS`, `OMP_NUM_THREADS`, `MKL_NUM_THREADS`, and
#' (when `apply_rx`) `rxode2::setRxThreads()` + `data.table::setDTthreads()`.
#' @param inner Integer inner-thread count.
#' @param apply_rx Logical; call rxode2/data.table setters (FALSE in unit tests).
#' @return Invisibly, the applied inner count.
#' @export
qual_set_threads <- function(inner, apply_rx = TRUE) {
  inner <- as.integer(inner)
  Sys.setenv(NLMIXR2QUAL_INNER_THREADS = as.character(inner),
             OMP_NUM_THREADS = as.character(inner),
             MKL_NUM_THREADS = as.character(inner))
  if (isTRUE(apply_rx)) {
    if (requireNamespace("rxode2", quietly = TRUE)) rxode2::setRxThreads(inner)
    if (requireNamespace("data.table", quietly = TRUE)) data.table::setDTthreads(inner)
  }
  invisible(inner)
}

#' Read the inner-thread count a worker should use
#' @return Integer inner-thread count (default 1 if unset).
#' @export
qual_inner_threads <- function() {
  v <- Sys.getenv("NLMIXR2QUAL_INNER_THREADS", "1")
  max(1L, as.integer(v))
}

#' A stable multi-thread count for the thread-invariance stage
#'
#' The invariance check only needs inner threads > 1 to be meaningful; it does
#' not benefit from all cores, and pinning the count to the full core count
#' oversubscribes small problems and can crash the OpenMP/rxode2 solver on
#' many-core machines. Cap it to a modest, stable value (default 4).
#' @param cores Available cores.
#' @param cap Maximum inner threads to use.
#' @return An integer inner-thread count for the invariance stage.
#' @export
qual_invariance_threads <- function(cores = parallel::detectCores(), cap = 4L) {
  max(1L, min(as.integer(cap), as.integer(cores)))
}
