# report.R

#' Write a plain-text qualification verdict + per-reference summary
#' @param res An `nlmixr2qual_result`.
#' @param path Output `.txt` path.
#' @return `path`, invisibly.
#' @export
qual_summary_text <- function(res, path) {
  verdict <- if (isTRUE(res$overall)) "OVERALL: PASS" else "OVERALL: FAIL"
  s <- res$summary
  lines <- c(verdict, "",
             sprintf("%s  threads:%d  %s  %s",
                     format(s$id), s$threads,
                     ifelse(s$pass, "PASS", "FAIL"),
                     ifelse(s$strict, "(strict)", "(informational)")))
  writeLines(lines, path)
  invisible(path)
}

#' Render the qualification summary document (Quarto HTML)
#' @param res An `nlmixr2qual_result`.
#' @param path Output `.html` path.
#' @return `path`, invisibly.
#' @export
qual_summary_report <- function(res, path) {
  stopifnot(requireNamespace("quarto", quietly = TRUE))
  # Render in an isolated temp dir, never inside the (possibly read-only,
  # installed) package tree: quarto_render() writes its output -- and any
  # companion `_files` resource directory -- next to the source .qmd.
  qmd_src <- system.file("report", "qualification.qmd", package = "nlmixr2qual")
  render_dir <- tempfile("qualreport-"); dir.create(render_dir)
  qmd <- file.path(render_dir, "qualification.qmd")
  file.copy(qmd_src, qmd)
  rds <- tempfile(fileext = ".rds"); saveRDS(res, rds)
  quarto::quarto_render(qmd, output_file = basename(path),
                        execute_params = list(result_rds = rds), quiet = TRUE)
  rendered <- file.path(render_dir, basename(path))
  file.copy(rendered, path, overwrite = TRUE)
  files_dir <- sub("\\.[^.]+$", "_files", rendered)
  if (dir.exists(files_dir))
    file.copy(files_dir, dirname(path), recursive = TRUE)
  invisible(path)
}
