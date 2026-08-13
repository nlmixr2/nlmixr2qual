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

# Conditional / integral-approximation methods driven by the FOCEi engine that
# accept foceiControl(outerOpt=). First-order fo/foi are handled by the same
# engine but reject the outerOpt control ("cannot find fo related control
# object"), so they are deliberately excluded here and use their default control.
# laplace and agq are deterministic integral approximations that also take the
# foceiControl outer optimizer and benefit from the same stable-convergence pin.
.qual_focei_control_family <- c("foce", "focei", "focep", "laplace", "agq")

# STOCHASTIC estimators need their random seed (and iteration budget, for the EM
# methods) pinned so a baseline cut and every re-fit reproduce exactly on the
# same machine; the looser stochastic tolerance (qual_tolerance(stochastic =
# TRUE)) absorbs residual cross-platform variability. The SAEM family
# (saem/fsaem) is seeded through saemControl(seed=); the importance-sampling
# family (imp/impmap/qrpem) through impmapControl(impSeed=).
.qual_saem_family   <- c("saem", "fsaem")
.qual_impmap_family <- c("imp", "impmap", "qrpem")
.qual_saem_seed  <- 99L
.qual_saem_nburn <- 200L
.qual_saem_nem   <- 300L
.qual_imp_seed   <- 99L

#' Stable estimation control for a method (or NULL for the method default)
#'
#' The conditional FOCE(i) / integral-approximation methods' default outer
#' optimizer (nlminb) reports a tolerance-sensitive "false convergence (8)"
#' advisory at the optimum, which the fingerprint would record as
#' `converged = FALSE` and makes the convergence check meaningless (and brittle
#' across platforms). bobyqa reaches the identical optimum with a clean exit
#' (convergence code 0), so it is pinned for that family. Stochastic estimators
#' are pinned to a fixed seed (and iteration budget for the EM methods) so their
#' estimation is reproducible. Other methods use their default control (NULL).
#' @param method The est= method string.
#' @return A control object accepted by [nlmixr2est::nlmixr2()], or NULL.
#' @keywords internal
qual_fit_control <- function(method) {
  if (method %in% .qual_focei_control_family) {
    return(nlmixr2est::foceiControl(outerOpt = "bobyqa"))
  }
  if (method %in% .qual_saem_family) {
    return(nlmixr2est::saemControl(seed = .qual_saem_seed,
                                   nBurn = .qual_saem_nburn,
                                   nEm = .qual_saem_nem))
  }
  if (method %in% .qual_impmap_family) {
    return(nlmixr2est::impmapControl(impSeed = .qual_imp_seed))
  }
  NULL
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
  control <- qual_fit_control(entry$method)
  # nlmixr2() the estimation entry point is defined in nlmixr2est and
  # re-exported onto the search path by library(nlmixr2), but not exported
  # from the nlmixr2 namespace itself, so it must be called via nlmixr2est::.
  fit <- if (is.null(control)) {
    nlmixr2est::nlmixr2(model, data, est = entry$method)
  } else {
    nlmixr2est::nlmixr2(model, data, est = entry$method, control = control)
  }
  qual_extract_fit(fit, model = entry$name, method = entry$method,
                   category = category, stochastic = entry$stochastic,
                   threads = threads)
}
