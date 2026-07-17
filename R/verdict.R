# verdict.R

#' Aggregate per-model results into an overall verdict
#' @param results List of result records (each has $pass, $strict).
#' @param version_gate The list returned by [qual_version_gate()].
#' @return `list(verdict = "PASS"/"FAIL", n_strict, n_strict_fail, n_info_fail)`.
#' @export
qual_verdict <- function(results, version_gate) {
  strict <- Filter(function(r) isTRUE(r$strict), results)
  info   <- Filter(function(r) !isTRUE(r$strict), results)
  n_strict_fail <- sum(vapply(strict, function(r) !isTRUE(r$pass), logical(1)))
  n_info_fail   <- sum(vapply(info,   function(r) !isTRUE(r$pass), logical(1)))
  ok <- n_strict_fail == 0 && isTRUE(version_gate$pass)
  list(verdict = if (ok) "PASS" else "FAIL",
       n_strict = length(strict), n_strict_fail = n_strict_fail,
       n_info_fail = n_info_fail)
}

#' Write occamsqual-style plain-text verdict + summary
#' @param v The [qual_verdict()] result.
#' @param results Result records.
#' @param dir Output directory.
#' @return Invisibly, the output directory.
#' @export
qual_write_text <- function(v, results, dir = ".") {
  writeLines(v$verdict, file.path(dir, "qualification_verdict.txt"))
  lines <- c(
    "nlmixr2qual qualification summary",
    paste("Date:", Sys.time()),
    "",
    sprintf("%-24s %-10s %-6s %s", "MODEL", "METHOD", "STRICT", "RESULT"),
    vapply(results, function(r)
      sprintf("%-24s %-10s %-6s %s", r$model, r$method,
              if (isTRUE(r$strict)) "yes" else "no",
              if (isTRUE(r$pass)) "PASS" else "FAIL"), character(1)),
    "",
    paste0("OVERALL: ", v$verdict)
  )
  writeLines(lines, file.path(dir, "qualification_summary.txt"))
  invisible(dir)
}
