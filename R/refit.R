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
  # only resolves if nlmixr2est is attached to the search path (see
  # .qual_attach_nlmixr2est() in import.R for why and how).
  .qual_attach_nlmixr2est()
  e <- new.env()
  eval(parse(text = ref$model$code), envir = e)
  model <- get(ref$model$name, envir = e)
  model <- .qual_apply_initial_estimates(model, ref$reference$initial_estimates)
  data <- as.data.frame(ref$data$records, stringsAsFactors = FALSE)
  est <- ref$method$est
  control <- .qual_build_control(est, ref$method$control, ref$method$seed)
  fit <- if (is.null(control)) {
    nlmixr2est::nlmixr2(model, data, est = est)
  } else {
    nlmixr2est::nlmixr2(model, data, est = est, control = control)
  }
  qual_extract_fit(fit, model = ref$model$name, method = est,
                   category = ref$reference$category,
                   stochastic = ref$reference$stochastic, threads = threads)
}

# Turn a stored control list (+ optional seed) into the method-appropriate
# control object. NULL (no stored control, no seed) re-fits on the
# estimator default. `seed` is injected under the method's own seed field
# (see .qual_seed_field in import.R) so a pinned seed makes a stochastic
# re-fit exactly reproducible rather than merely tolerance-compared.
.qual_build_control <- function(est, control, seed = NULL) {
  args <- if (is.null(control)) list() else control
  field <- .qual_seed_field[[est]]
  if (!is.null(seed) && !is.null(field)) args[[field]] <- as.integer(seed)
  if (!length(args)) return(NULL)
  ctl_fn <- switch(est,
                   saem = ,
                   fsaem = nlmixr2est::saemControl,
                   imp = nlmixr2est::impControl,
                   impmap = nlmixr2est::impmapControl,
                   qrpem = nlmixr2est::qrpemControl,
                   nlmixr2est::foceiControl)  # extend per method family as needed
  do.call(ctl_fn, args)
}

# Override the reconstructed model's ini() starting values with the
# reference's recorded initial_estimates (the bundle's cold-start priors, by
# default -- see qual_import_bundle()) so the re-fit follows the same
# optimizer trajectory as the original fit instead of warm-starting from the
# post-fit values baked into the reconstructed model source. Absent/empty
# initial_estimates (e.g. a hand-built reference in tests) leaves the model's
# own ini() values untouched. Names not present in this particular model are
# skipped rather than erroring -- some methods (e.g. SAEM) can report a
# bounded parameter under a method-internal alias not shared by the
# reconstructed model's own ini() block (see .qual_iniDf_to_estimates()); that
# one parameter then simply keeps the reconstructed model's existing value.
.qual_apply_initial_estimates <- function(model, initial_estimates) {
  if (is.null(initial_estimates) || !NROW(initial_estimates)) return(model)
  model <- rxode2::rxUiDecompress(model)
  known <- initial_estimates$name %in% model$iniDf$name
  if (!any(known)) return(model)
  vals <- stats::setNames(as.numeric(initial_estimates$value[known]),
                          initial_estimates$name[known])
  rxode2::ini(model, vals)
}
