# provenance.R

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Capture environment + thread provenance
#' @param inner_threads,workers Integers recorded verbatim.
#' @return A named list of provenance fields.
#' @export
qual_provenance <- function(inner_threads = qual_inner_threads(), workers = 1L) {
  si <- utils::sessionInfo()
  bl <- si$BLAS; if (is.null(bl)) bl <- ""
  la <- si$LAPACK; if (is.null(la)) la <- ""
  nlv <- tryCatch(as.character(utils::packageVersion("nlmixr2")),
                  error = function(e) NA_character_)
  list(
    os = si$running %||% Sys.info()[["sysname"]],
    arch = R.version$arch,
    r_version = R.version.string,
    blas = bl,
    lapack = la,
    compiler = R.version$system,
    inner_threads = as.integer(inner_threads),
    workers = as.integer(workers),
    nlmixr2 = nlv,
    captured = as.character(Sys.time())
  )
}

#' @rdname qual_provenance
#' @param p A provenance list.
#' @param path Output path.
#' @export
qual_write_provenance <- function(p, path) {
  jsonlite::write_json(p, path, auto_unbox = TRUE, pretty = TRUE)
  invisible(path)
}

#' @rdname qual_provenance
#' @export
qual_read_provenance <- function(path) {
  p <- jsonlite::read_json(path, simplifyVector = TRUE)
  p$inner_threads <- as.integer(p$inner_threads)
  p$workers <- as.integer(p$workers)
  p
}
