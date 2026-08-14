# refit.R -- reconstruct a reference's model + data and re-fit at its thread count.

#' Re-fit a reference in the local environment and return its fingerprint
#'
#' Pins the reference's own thread count (results can differ across thread
#' counts, so the comparison is always like-for-like).
#' @param ref A reference list.
#' @param threads Thread count to pin; defaults to the reference's own count.
#' @return A fingerprint (see [qual_extract_fit()]).
#' @export
qual_reference_refit <- function(ref, threads = ref$reference$threads) {
  qual_reference_validate(ref)
  threads <- as.integer(threads)
  qual_set_threads(threads)                        # pin rxode2 inner threads
  # ref$model$code uses the unqualified ini()/model() modeling DSL, which
  # only resolves if nlmixr2est is attached to the search path (see the same
  # requirement documented in qual_import_bundle()).
  suppressMessages(requireNamespace("nlmixr2est", quietly = TRUE))
  suppressMessages(library("nlmixr2est", character.only = TRUE))
  e <- new.env()
  eval(parse(text = ref$model$code), envir = e)
  model <- get(ref$model$name, envir = e)
  model <- .qual_apply_initial_estimates(model, ref$reference$initial_estimates)
  data <- as.data.frame(ref$data$records, stringsAsFactors = FALSE)
  est <- ref$method$est
  control <- .qual_build_control(est, ref$method$control)
  fit <- if (is.null(control)) {
    nlmixr2est::nlmixr2(model, data, est = est)
  } else {
    nlmixr2est::nlmixr2(model, data, est = est, control = control)
  }
  qual_extract_fit(fit, model = ref$model$name, method = est,
                   category = ref$reference$category,
                   stochastic = ref$reference$stochastic, threads = threads)
}

# Turn a stored control list into the method-appropriate control object.
# NULL (no stored control) re-fits on the estimator default.
.qual_build_control <- function(est, control) {
  if (is.null(control) || !length(control)) return(NULL)
  do.call(nlmixr2est::foceiControl, control)  # extend per method family as needed
}

# Override the reconstructed model's ini() starting values with the
# reference's recorded initial_estimates (the bundle's cold-start priors, by
# default -- see qual_import_bundle()) so the re-fit follows the same
# optimizer trajectory as the original fit instead of warm-starting from the
# post-fit values baked into the reconstructed model source. Absent/empty
# initial_estimates (e.g. a hand-built reference in tests) leaves the model's
# own ini() values untouched.
.qual_apply_initial_estimates <- function(model, initial_estimates) {
  if (is.null(initial_estimates) || !NROW(initial_estimates)) return(model)
  model <- rxode2::rxUiDecompress(model)
  vals <- stats::setNames(as.numeric(initial_estimates$value), initial_estimates$name)
  rxode2::ini(model, vals)
}
