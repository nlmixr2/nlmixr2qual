# tolerance.R

.qual_tol_defaults <- list(
  # theta/omega/sigma are 1e-2, not 1e-3: qual_reference_refit() necessarily
  # warm-starts from the reference's already-fitted values (nlmixr2save only
  # ever stores a fit's post-fit state, never its original cold-start priors),
  # so bobyqa's derivative-free trust-region search can land at a measurably
  # different (but fully deterministic, reproducible) point than the original
  # cold-start fit even at threads == 1. OFV stays tight since it is flat near
  # the optimum; per-parameter estimates -- especially near-zero omegas --
  # need the looser figure to absorb that warm-start drift.
  deterministic = c(ofv = 1e-3, theta = 1e-2, omega = 1e-2, sigma = 1e-2,
                    se = 0.05, rse = 0.05, shrink = 0.05),
  stochastic    = c(ofv = 1e-2, theta = 1e-2, omega = 1e-2, sigma = 1e-2,
                    se = 0.10, rse = 0.10, shrink = 0.10)
)
.qual_tol_invariance <- 1e-2

#' Relative tolerance for a quantity class
#'
#' @param class One of "ofv","theta","omega","sigma","se","rse","shrink".
#' @param stochastic Logical; use the looser stochastic defaults.
#' @param invariance Logical; use the thread-invariance tolerance instead.
#' @param override Optional explicit numeric tolerance (wins if supplied).
#' @return A single numeric relative tolerance.
#' @export
qual_tolerance <- function(class, stochastic = FALSE, invariance = FALSE,
                           override = NULL) {
  if (!is.null(override)) return(as.numeric(override))
  tab <- if (isTRUE(stochastic)) .qual_tol_defaults$stochastic
         else .qual_tol_defaults$deterministic
  stopifnot(class %in% names(tab))
  base_tol <- unname(tab[[class]])
  # Invariance mode absorbs multi-threaded parallel-float variance, so it must
  # never be tighter than the class's own default (e.g. shrink's 5% deterministic
  # tolerance is already looser than the flat 1% invariance floor).
  if (isTRUE(invariance)) return(max(.qual_tol_invariance, base_tol))
  base_tol
}
