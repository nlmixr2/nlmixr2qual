# registry.R

.qual_pkg_file <- function(...) {
  f <- system.file(..., package = "nlmixr2qual")
  if (nzchar(f)) return(f)
  # pkgload::load_all dev path
  file.path("inst", ...)
}

#' Read and validate the model registry
#' @param path Optional explicit path to the registry CSV.
#' @return A validated data frame, one row per qualified model.
#' @export
qual_registry <- function(path = .qual_pkg_file("models", "registry.csv")) {
  reg <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
  req <- c("name","source","dataset","domain","method","stochastic",
           "strict","anchor","tol_override")
  miss <- setdiff(req, names(reg))
  if (length(miss)) stop("registry missing columns: ", paste(miss, collapse = ", "))
  if (anyDuplicated(reg$name)) stop("duplicate model name(s) in registry")
  reg$stochastic <- as.logical(reg$stochastic)
  reg$strict     <- as.logical(reg$strict)
  reg$anchor     <- as.logical(reg$anchor)
  reg
}

#' Read and validate the method-coverage matrix
#' @param path Optional explicit path to the methods CSV.
#' @return A validated data frame, one row per estimation method.
#' @export
qual_methods <- function(path = .qual_pkg_file("models", "methods.csv")) {
  m <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
  req <- c("method","category","stochastic","strict","needs_reff")
  miss <- setdiff(req, names(m))
  if (length(miss)) stop("methods missing columns: ", paste(miss, collapse = ", "))
  m$stochastic <- as.logical(m$stochastic)
  m$strict     <- as.logical(m$strict)
  m$needs_reff  <- as.logical(m$needs_reff)
  m
}
