# qualify.R -- load, select, and run references.

.qual_internal_dir <- function() system.file("references", package = "nlmixr2qual")

#' Default multi-thread count for the shipped reference set and generators
#' @return Integer thread count (4).
#' @export
qual_default_multi_threads <- function() 4L

#' Load references from the internal set or a folder of JSON files
#' @param source `"internal"` (shipped set) or a path to a folder of `.json`.
#' @return A named list of references, keyed by thread-tagged `id`.
#' @export
qual_load_references <- function(source = "internal") {
  dir <- if (identical(source, "internal")) .qual_internal_dir() else source
  if (!dir.exists(dir)) stop("reference source folder not found: ", dir)
  files <- list.files(dir, pattern = "\\.json$", full.names = TRUE)
  refs <- lapply(files, qual_reference_read)
  stats::setNames(refs, vapply(refs, function(r) r$id, character(1)))
}

#' Select references to qualify, by pair or full id
#' @param refs A named list of references (from [qual_load_references()]).
#' @param which `"all"` (default), or a vector of pairs (`"<model>__<method>"`,
#'   selecting all thread variants) and/or full ids (`"...__t<n>"`).
#' @return The filtered named list.
#' @export
qual_select <- function(refs, which = "all") {
  if (identical(which, "all")) return(refs)
  pair <- vapply(refs, qual_reference_pair, character(1))
  id   <- names(refs)
  keep <- id %in% which | pair %in% which
  matched_targets <- union(id[keep], pair[keep])
  miss <- setdiff(which, matched_targets)
  if (length(miss)) stop("no reference(s) for: ", paste(miss, collapse = ", "))
  refs[keep]
}

#' Qualify the local install against reference model-method pairs
#'
#' For each selected reference, pins the reference's thread count, re-fits the
#' model locally, and compares the fresh fingerprint against the stored reference
#' fingerprint. Deterministic methods are strict and gate the verdict; stochastic
#' methods are compared under the looser tolerance and reported but never gate.
#' Single- and multi-threaded references are distinct entries, each compared only
#' against itself.
#' @param which `"all"` (default), or pairs/ids (see [qual_select()]).
#' @param source `"internal"` or a folder of `.json` references.
#' @return An `nlmixr2qual_result`: `list(summary, details, provenance, overall)`.
#' @export
qualify <- function(which = "all", source = "internal") {
  refs <- qual_select(qual_load_references(source), which)
  rxode2::rxClean()                 # start from a clean compiled-model cache
  rows <- list(); details <- list()
  for (id in names(refs)) {
    ref <- refs[[id]]
    fp <- qual_reference_refit(ref)                 # pinned to ref's threads
    base <- .qual_ref_fingerprint(ref)
    # tolerance keyed to thread count: strict for single-threaded (bit-portable),
    # looser for multi-threaded (absorbs cross-machine parallel-float variation).
    cmp <- qual_compare(fp, base, invariance = ref$reference$threads > 1L)
    strict <- !isTRUE(ref$reference$stochastic)
    rows[[id]] <- data.frame(
      id = id, model = ref$model$name, method = ref$method$est,
      threads = as.integer(ref$reference$threads), strict = strict,
      pass = cmp$pass, ofv_ref = ref$reference$ofv, ofv_local = fp$ofv,
      stringsAsFactors = FALSE)
    details[[id]] <- cmp$detail
  }
  summary <- do.call(rbind, rows); rownames(summary) <- NULL
  overall <- all(summary$pass[summary$strict])       # only strict pairs gate
  structure(list(summary = summary, details = details,
                 provenance = qual_provenance(),
                 overall = overall),
            class = "nlmixr2qual_result")
}

# Rebuild the fingerprint list qual_compare expects from a reference's stored
# `reference` block.
.qual_ref_fingerprint <- function(ref) {
  r <- ref$reference
  list(model = ref$model$name, method = ref$method$est, category = r$category,
       stochastic = isTRUE(r$stochastic), threads = as.integer(r$threads),
       ofv = r$ofv, params = as.data.frame(r$params, stringsAsFactors = FALSE),
       shrink = as.data.frame(r$shrink, stringsAsFactors = FALSE),
       converged = isTRUE(r$converged), covMethod = r$covMethod)
}
