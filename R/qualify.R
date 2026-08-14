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
