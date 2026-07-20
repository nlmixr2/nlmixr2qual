# data-io.R

#' Load a frozen dataset by file reference
#' @param ref The dataset file name under inst/extdata/ (or an absolute path).
#' @return A data frame.
#' @export
qual_read_dataset <- function(ref) {
  path <- if (file.exists(ref)) ref else .qual_pkg_file("extdata", ref)
  if (!file.exists(path)) stop("dataset not found: ", ref)
  utils::read.csv(path, stringsAsFactors = FALSE)
}
