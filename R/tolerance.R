# tolerance.R

.qual_tol_defaults <- list(
  deterministic = c(ofv = 1e-3, theta = 1e-3, omega = 1e-3, sigma = 1e-3,
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
  if (isTRUE(invariance)) return(.qual_tol_invariance)
  tab <- if (isTRUE(stochastic)) .qual_tol_defaults$stochastic
         else .qual_tol_defaults$deterministic
  stopifnot(class %in% names(tab))
  unname(tab[[class]])
}
