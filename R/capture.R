# capture.R

# Resolve a method's display category from the methods table (default "Unknown").
.qual_method_category <- function(method, methods) {
  hit <- methods$category[methods$method == method]
  if (length(hit) == 0L) "Unknown" else hit[[1]]
}

#' Recut the canonical baseline (deliberate; single-threaded)
#'
#' Uses the EXISTING frozen datasets; never regenerates data. Writes one
#' fingerprint file per model to `dir`, plus a provenance record.
#' @param registry The model registry (from [qual_registry()]).
#' @param dir Output baseline directory.
#' @param fitter Function(entry, category, threads) -> fingerprint.
#' @param methods The method table (from [qual_methods()]); maps method->category.
#' @return Invisibly, the baseline directory.
#' @export
qual_capture_baseline <- function(registry, dir = .qual_pkg_file("baseline"),
                                  fitter = qual_fit_entry,
                                  methods = qual_methods()) {
  qual_set_threads(1L)  # baseline is always single-threaded
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  for (i in seq_len(nrow(registry))) {
    entry <- as.list(registry[i, ])
    category <- .qual_method_category(entry$method, methods)
    fp <- fitter(entry, category = category, threads = 1L)
    qs2::qs_save(fp, file.path(dir, paste0(entry$name, "__", entry$method, ".qs2")))
  }
  qual_write_provenance(qual_provenance(inner_threads = 1L, workers = 1L),
                        file.path(dir, "provenance.json"))
  invisible(dir)
}
