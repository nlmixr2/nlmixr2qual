# fit.R

#' Prepare a model: load it and augment with IIV per the registry `eta` spec
#'
#' The SINGLE source of model augmentation (spec 3.0 / D9). Simulation, fitting,
#' and baseline capture all call this so they use an identical model.
#' @param entry A registry row as a list (name, source, eta).
#' @return An nlmixr2/rxode2 UI model, augmented with random effects if `eta` set.
#' @export
qual_prepare_model <- function(entry) {
  model <- switch(entry$source,
    lib  = nlmixr2lib::readModelDb(entry$name),
    file = eval(parse(file = .qual_pkg_file("models", paste0(entry$name, ".R")))),
    stop("unknown model source: ", entry$source))
  eta <- entry$eta
  if (!is.null(eta) && !is.na(eta) && nzchar(trimws(eta))) {
    params <- trimws(strsplit(eta, ",")[[1]])
    model <- nlmixr2lib::addEta(model, params)
  }
  # readModelDb()/addEta() return an unevaluated UI model function; evaluate
  # it into an rxUi object so downstream code (e.g. $iniDf) can inspect it.
  rxode2::rxode2(model)
}

#' Load a model, attach its frozen data, fit, and return a fingerprint
#' @param entry A registry row as a list (name, source, dataset, method, stochastic, eta).
#' @param category The method's display category (from qual_methods()).
#' @param threads Inner-thread count (defaults to the controller's current value).
#' @return A fingerprint (see [qual_extract_fit()]).
#' @export
qual_fit_entry <- function(entry, category, threads = qual_inner_threads()) {
  stopifnot(requireNamespace("nlmixr2", quietly = TRUE))
  model <- qual_prepare_model(entry)
  data <- qual_read_dataset(entry$dataset)
  # nlmixr2() the estimation entry point is defined in nlmixr2est and
  # re-exported onto the search path by library(nlmixr2), but not exported
  # from the nlmixr2 namespace itself, so it must be called via nlmixr2est::.
  fit <- nlmixr2est::nlmixr2(model, data, est = entry$method)
  qual_extract_fit(fit, model = entry$name, method = entry$method,
                   category = category, stochastic = entry$stochastic,
                   threads = threads)
}
