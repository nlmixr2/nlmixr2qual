# run.R

.load_baseline <- function(dir, model, method) {
  f <- file.path(dir, paste0(model, "__", method, ".qs2"))
  if (!file.exists(f)) stop("baseline missing: ", basename(f))
  qs2::qs_read(f)
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

# Serial, multi-threaded re-fit of the anchor models, compared to the
# single-threaded baseline under the looser invariance tolerance. Factored out
# so it can be run either in-process or in an isolated child process.
.qual_invariance_stage <- function(registry, baseline_dir, anchor_threads,
                                   methods = qual_methods(),
                                   fitter = qual_fit_entry) {
  anchors <- registry[registry$anchor %in% TRUE, , drop = FALSE]
  qual_set_threads(anchor_threads)
  on.exit(qual_set_threads(1L), add = TRUE)
  lapply(seq_len(nrow(anchors)), function(i) {
    entry <- as.list(anchors[i, ])
    category <- .qual_method_category(entry$method, methods)
    fp <- fitter(entry, category = category, threads = anchor_threads)
    base <- .load_baseline(baseline_dir, entry$name, entry$method)
    cmp <- qual_compare(fp, base, invariance = TRUE)
    informational <- isTRUE(entry$stochastic)
    list(model = entry$name, method = entry$method, threads = anchor_threads,
         pass = cmp$pass, informational = informational, detail = cmp$detail)
  })
}

# Run the invariance stage in a fresh child R process (callr). Isolation both
# contains a solver crash -- the multi-threaded OpenMP path is intermittently
# unstable on some many-core machines -- and starts the multi-threaded fits from
# a clean process rather than one that has already run many single-threaded
# fits. Returns NULL (with a warning) if callr is unavailable or the child
# fails; the invariance stage does not gate the overall verdict, so a failure
# here degrades gracefully to "not completed".
.qual_invariance_isolated <- function(registry, baseline_dir, anchor_threads,
                                      pkg_dir) {
  if (!requireNamespace("callr", quietly = TRUE)) {
    warning("callr not available; running invariance stage in-process")
    return(.qual_invariance_stage(registry, baseline_dir, anchor_threads))
  }
  tryCatch(
    callr::r(
      function(registry, baseline_dir, anchor_threads, pkg_dir) {
        if (nzchar(pkg_dir) && requireNamespace("pkgload", quietly = TRUE)) {
          suppressMessages(pkgload::load_all(pkg_dir, quiet = TRUE))
        } else {
          suppressMessages(library(nlmixr2qual))
        }
        stage <- utils::getFromNamespace(".qual_invariance_stage",
                                         "nlmixr2qual")
        stage(registry, baseline_dir, anchor_threads)
      },
      args = list(registry = registry, baseline_dir = baseline_dir,
                  anchor_threads = anchor_threads, pkg_dir = pkg_dir),
      show = FALSE
    ),
    error = function(e) {
      warning("invariance stage failed in isolated process: ",
              conditionMessage(e))
      NULL
    }
  )
}

#' Run the qualification: strict single-threaded stage + invariance stage
#' @param registry Model registry.
#' @param baseline_dir Baseline directory.
#' @param fitter Function(entry, category, threads) -> fingerprint.
#' @param run_invariance Logical; run the serial multi-threaded stage.
#' @param anchor_threads Inner threads for the invariance stage (capped for
#'   stability by default; see [qual_invariance_threads()]).
#' @param methods Method table (method->category); defaults to qual_methods().
#' @param isolate_invariance Logical; run the multi-threaded invariance stage in
#'   an isolated child process (crash-resilient). Ignored when a non-default
#'   `fitter` is supplied (e.g. unit-test stubs), which always run in-process.
#' @param pkg_dir Package source directory for the isolated child to load in dev
#'   mode; "" means the child loads the installed package.
#' @return `list(results, invariance, provenance)`.
#' @export
qual_run <- function(registry, baseline_dir = .qual_pkg_file("baseline"),
                     fitter = qual_fit_entry, run_invariance = TRUE,
                     anchor_threads = qual_invariance_threads(),
                     methods = qual_methods(),
                     isolate_invariance = TRUE,
                     pkg_dir = if (file.exists("DESCRIPTION")) normalizePath(".") else "") {
  # --- strict stage: single-threaded ---
  qual_set_threads(1L)
  results <- lapply(seq_len(nrow(registry)), function(i) {
    entry <- as.list(registry[i, ])
    category <- .qual_method_category(entry$method, methods)
    fp <- fitter(entry, category = category, threads = 1L)
    base <- .load_baseline(baseline_dir, entry$name, entry$method)
    cmp <- qual_compare(fp, base)
    list(model = entry$name, method = entry$method, strict = entry$strict,
         pass = cmp$pass, detail = cmp$detail)
  })

  # --- invariance stage: serial, multi-threaded, anchors only ---
  invariance <- NULL
  if (isTRUE(run_invariance)) {
    default_fitter <- identical(fitter, qual_fit_entry)
    invariance <- if (isTRUE(isolate_invariance) && default_fitter) {
      .qual_invariance_isolated(registry, baseline_dir, anchor_threads, pkg_dir)
    } else {
      .qual_invariance_stage(registry, baseline_dir, anchor_threads,
                             methods = methods, fitter = fitter)
    }
  }

  list(results = results, invariance = invariance,
       provenance = qual_provenance(inner_threads = 1L, workers = 1L))
}
