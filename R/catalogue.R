# catalogue.R -- document reference models/methods/results.
# %||% is defined in provenance.R.

#' Summarise references as a data frame
#' @param refs A named list of references.
#' @return A data frame with one row per reference.
#' @export
qual_catalogue <- function(refs) {
  do.call(rbind, lapply(refs, function(r) data.frame(
    id = r$id, model = r$model$name, method = r$method$est,
    threads = as.integer(r$reference$threads),
    description = r$model$description %||% "",
    ofv = r$reference$ofv,
    converged = isTRUE(r$reference$converged),
    stochastic = isTRUE(r$reference$stochastic),
    n_params = nrow(as.data.frame(r$reference$params)),
    nlmixr2_version = r$provenance$software$nlmixr2 %||% NA_character_,
    created = r$provenance$created %||% "",
    stringsAsFactors = FALSE)))
}

#' Render the reference catalogue as a Markdown table
#' @param refs A named list of references.
#' @return A length-1 character string of Markdown.
#' @export
qual_catalogue_md <- function(refs) {
  df <- qual_catalogue(refs)[, c("id", "model", "method", "threads", "ofv",
                                 "stochastic", "nlmixr2_version")]
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  body <- apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  paste(c(header, sep, body), collapse = "\n")
}
