# report.R

#' Assemble the results bundle and (optionally) render the Quarto report
#' @param run The `qual_run()` output.
#' @param version_gate The `qual_version_gate()` output.
#' @param dir Output directory.
#' @param render Logical; render the Quarto report (needs quarto + fits done).
#' @param formats Character vector of Quarto formats (default "html").
#' @return The assembled bundle (invisibly also written to disk).
#' @export
qual_report <- function(run, version_gate, dir = "qualification_output",
                        render = TRUE, formats = "html") {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  verdict <- qual_verdict(run$results, version_gate)
  bundle <- list(results = run$results, invariance = run$invariance,
                 provenance = run$provenance, version_gate = version_gate,
                 verdict = verdict)
  saveRDS(bundle, file.path(dir, "qualification_bundle.rds"))
  qual_write_text(verdict, run$results, dir = dir)  # pipeline-compat artifacts
  if (isTRUE(render) && requireNamespace("quarto", quietly = TRUE)) {
    qmd <- .qual_pkg_file("report", "qualification.qmd")
    file.copy(qmd, file.path(dir, "qualification.qmd"), overwrite = TRUE)
    quarto::quarto_render(
      file.path(dir, "qualification.qmd"),
      output_format = formats,
      execute_params = list(bundle = normalizePath(file.path(dir, "qualification_bundle.rds"))))
  }
  invisible(bundle)
}
