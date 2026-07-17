# fingerprint.R

#' Extract a normalized fingerprint from an nlmixr2 fit
#'
#' @param fit A fitted nlmixr2 object (or a compatible fixture).
#' @param model,method,category Identifying strings for the fit.
#' @param stochastic Logical reproducibility-axis flag (see spec 6.3).
#' @param threads Integer inner-thread count used for the fit.
#' @return A fingerprint list (see plan conventions).
#' @export
qual_extract_fit <- function(fit, model, method, category, stochastic, threads) {
  pf <- fit$parFixedDf
  thetas <- data.frame(
    name = rownames(pf),
    ptype = "theta",
    estimate = as.numeric(pf$Estimate),
    se = as.numeric(pf$SE),
    rse = as.numeric(pf[["%RSE"]]),
    stringsAsFactors = FALSE)

  om <- fit$omega
  omegas <- if (!is.null(om)) {
    data.frame(name = colnames(om), ptype = "omega",
               estimate = as.numeric(diag(om)),
               se = NA_real_, rse = NA_real_, stringsAsFactors = FALSE)
  } else NULL

  sg <- fit$sigma
  sigmas <- if (!is.null(sg) && length(sg) > 0) {
    data.frame(name = names(sg), ptype = "sigma",
               estimate = as.numeric(sg),
               se = NA_real_, rse = NA_real_, stringsAsFactors = FALSE)
  } else NULL

  params <- do.call(rbind, Filter(Negate(is.null), list(thetas, omegas, sigmas)))
  rownames(params) <- NULL

  sh <- fit$shrink
  shrink <- if (!is.null(sh) && ncol(sh) > 0) {
    data.frame(name = colnames(sh), stype = "eta",
               value = as.numeric(sh[1, ]), stringsAsFactors = FALSE)
  } else data.frame(name = character(), stype = character(),
                    value = numeric(), stringsAsFactors = FALSE)

  msg <- fit$message
  converged <- is.null(msg) || !nzchar(msg)
  cm <- fit$covMethod
  covMethod <- if (is.null(cm)) "" else as.character(cm)

  list(model = model, method = method, category = category,
       stochastic = isTRUE(stochastic), threads = as.integer(threads),
       ofv = as.numeric(fit$objf), params = params, shrink = shrink,
       converged = isTRUE(converged), covMethod = covMethod)
}
