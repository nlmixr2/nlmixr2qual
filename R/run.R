# run.R

.load_baseline <- function(dir, model, method) {
  f <- file.path(dir, paste0(model, "__", method, ".qs2"))
  if (!file.exists(f)) stop("baseline missing: ", basename(f))
  qs2::qs_read(f)
}

#' Run the qualification: strict single-threaded stage + invariance stage
#' @param registry Model registry. @param baseline_dir Baseline directory.
#' @param fitter Function(entry, category, threads) -> fingerprint.
#' @param run_invariance Logical; run the serial multi-threaded stage.
#' @param anchor_threads Inner threads for the invariance stage.
#' @param methods Method table (method->category); defaults to qual_methods().
#' @return `list(results, invariance, provenance)`.
#' @export
qual_run <- function(registry, baseline_dir = .qual_pkg_file("baseline"),
                     fitter = qual_fit_entry, run_invariance = TRUE,
                     anchor_threads = max(2L, parallel::detectCores()),
                     methods = qual_methods()) {
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
    anchors <- registry[registry$anchor %in% TRUE, , drop = FALSE]
    qual_set_threads(anchor_threads)
    invariance <- lapply(seq_len(nrow(anchors)), function(i) {
      entry <- as.list(anchors[i, ])
      category <- .qual_method_category(entry$method, methods)
      fp <- fitter(entry, category = category, threads = anchor_threads)
      base <- .load_baseline(baseline_dir, entry$name, entry$method)
      cmp <- qual_compare(fp, base, invariance = TRUE)
      informational <- isTRUE(entry$stochastic)
      list(model = entry$name, method = entry$method, threads = anchor_threads,
           pass = cmp$pass, informational = informational, detail = cmp$detail)
    })
    qual_set_threads(1L)
  }

  list(results = results, invariance = invariance,
       provenance = qual_provenance(inner_threads = 1L, workers = 1L))
}
