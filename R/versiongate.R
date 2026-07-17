# versiongate.R

#' Compare installed package versions against the qualified baseline
#' @param baseline Data frame with columns package, version.
#' @param installed Optional named character vector (pkg -> version); by default
#'   queried live from the session.
#' @return `list(pass, detail)`; detail has package, expected, observed, status, pass.
#' @export
qual_version_gate <- function(baseline = utils::read.csv(
                                .qual_pkg_file("qualified_baseline.csv"),
                                stringsAsFactors = FALSE),
                              installed = NULL) {
  get_v <- function(pkg) {
    if (!is.null(installed)) return(if (pkg %in% names(installed)) installed[[pkg]] else NA_character_)
    tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
  }
  rows <- lapply(seq_len(nrow(baseline)), function(i) {
    pkg <- baseline$package[i]; exp <- baseline$version[i]; obs <- get_v(pkg)
    status <- if (is.na(obs)) "missing" else if (identical(obs, exp)) "match" else "mismatch"
    data.frame(package = pkg, expected = exp, observed = obs,
               status = status, pass = status == "match", stringsAsFactors = FALSE)
  })
  detail <- do.call(rbind, rows)
  list(pass = all(detail$pass), detail = detail)
}
