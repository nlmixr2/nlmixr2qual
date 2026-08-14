# reference.R -- the JSON reference object (one confirmed-good fit, thread-tagged).

.qual_ref_required <- c("schema_version", "id", "model", "data", "method",
                        "reference", "provenance")

#' Model-method pair key for a reference (no thread tag)
#' @param ref A reference list.
#' @return `"<model>__<method>"`.
#' @export
qual_reference_pair <- function(ref) {
  paste0(ref$model$name, "__", ref$method$est)
}

#' Unique, thread-tagged id for a reference
#' @param ref A reference list.
#' @return `"<model>__<method>__t<threads>"`.
#' @export
qual_reference_id <- function(ref) {
  paste0(qual_reference_pair(ref), "__t", as.integer(ref$reference$threads))
}

#' Write a qualification reference to a JSON file
#' @param ref A reference list.
#' @param path Output `.json` path.
#' @return `path`, invisibly.
#' @export
qual_reference_write <- function(ref, path) {
  qual_reference_validate(ref)
  json <- jsonlite::toJSON(ref, dataframe = "columns", null = "null",
                           na = "null", auto_unbox = TRUE, digits = NA,
                           pretty = TRUE)
  writeLines(json, path)
  invisible(path)
}

#' Read a qualification reference from a JSON file
#' @param path Path to a `.json` reference.
#' @return A reference list, with data-frame fields restored.
#' @export
qual_reference_read <- function(path) {
  ref <- jsonlite::fromJSON(path, simplifyVector = TRUE,
                            simplifyDataFrame = TRUE)
  if (is.null(ref$reference$params)) ref$reference$params <- data.frame()
  if (is.null(ref$reference$shrink)) ref$reference$shrink <- data.frame()
  if (is.null(ref$reference$initial_estimates))
    ref$reference$initial_estimates <- data.frame()
  ref
}

#' Validate a reference has the required structure
#' @param ref A reference list.
#' @return `TRUE` invisibly if valid; errors otherwise.
#' @export
qual_reference_validate <- function(ref) {
  miss <- setdiff(.qual_ref_required, names(ref))
  if (length(miss))
    stop("reference missing required field(s): ", paste(miss, collapse = ", "))
  if (is.null(ref$method$est) || !nzchar(ref$method$est))
    stop("reference method$est must be a non-empty method string")
  if (is.null(ref$reference$threads) || is.na(ref$reference$threads))
    stop("reference must record reference$threads")
  invisible(TRUE)
}
