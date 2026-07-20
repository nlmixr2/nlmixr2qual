# compare.R

.rel_diff <- function(run, base) {
  if (is.na(run) && is.na(base)) return(0)
  if (is.na(run) || is.na(base)) return(Inf)
  denom <- max(abs(base), .Machine$double.eps)
  abs(run - base) / denom
}

#' Compare a run fingerprint against a baseline fingerprint
#'
#' @param run,base Fingerprints from [qual_extract_fit()].
#' @param overrides Named numeric vector of per-quantity tolerance overrides,
#'   keyed by quantity label (e.g. `c("theta:lcl" = 5e-4)`).
#' @param invariance Logical; use the thread-invariance tolerance (spec 7.3).
#' @return `list(model, method, pass, detail)` where `detail` is a data frame
#'   with columns quantity, class, baseline, observed, reldiff, tol, pass.
#' @export
qual_compare <- function(run, base, overrides = NULL, invariance = FALSE) {
  stoch <- isTRUE(base$stochastic)
  rows <- list()
  add <- function(quantity, class, b, o) {
    tol <- qual_tolerance(class, stochastic = stoch, invariance = invariance,
                          override = if (!is.null(overrides)) overrides[[quantity]] else NULL)
    rd <- .rel_diff(o, b)
    rows[[length(rows) + 1L]] <<- data.frame(
      quantity = quantity, class = class, baseline = b, observed = o,
      reldiff = rd, tol = tol, pass = rd <= tol, stringsAsFactors = FALSE)
  }

  add("ofv", "ofv", base$ofv, run$ofv)

  keyed <- function(fp) stats::setNames(seq_len(nrow(fp$params)),
                                 paste0(fp$params$ptype, ":", fp$params$name))
  bk <- keyed(base); rk <- keyed(run)
  for (k in union(names(bk), names(rk))) {
    ptype <- sub(":.*$", "", k)
    b <- if (k %in% names(bk)) base$params$estimate[bk[[k]]] else NA_real_
    o <- if (k %in% names(rk)) run$params$estimate[rk[[k]]] else NA_real_
    add(k, ptype, b, o)
    if (k %in% names(bk) && !is.na(base$params$se[bk[[k]]])) {
      ose <- if (k %in% names(rk)) run$params$se[rk[[k]]] else NA_real_
      add(paste0("se:", k), "se", base$params$se[bk[[k]]], ose)
    }
  }

  bs <- stats::setNames(base$shrink$value, base$shrink$name)
  rs <- stats::setNames(run$shrink$value, run$shrink$name)
  for (nm in union(names(bs), names(rs))) {
    add(paste0("shrink:", nm), "shrink",
        if (nm %in% names(bs)) bs[[nm]] else NA_real_,
        if (nm %in% names(rs)) rs[[nm]] else NA_real_)
  }

  detail <- do.call(rbind, rows)
  conv <- data.frame(quantity = "converged", class = "status",
                     baseline = as.numeric(base$converged),
                     observed = as.numeric(run$converged),
                     reldiff = NA_real_, tol = NA_real_,
                     pass = identical(base$converged, run$converged),
                     stringsAsFactors = FALSE)
  detail <- rbind(detail, conv)
  rownames(detail) <- NULL

  list(model = run$model, method = run$method,
       pass = all(detail$pass), detail = detail)
}
