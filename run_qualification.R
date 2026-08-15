#!/usr/bin/env Rscript
# Qualify the local install against the shipped internal references (or a folder
# passed as the first argument) and write the summary document + verdict. Each
# reference is re-fit at its own recorded thread count.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
source <- if (length(args) >= 1 && nzchar(args[1])) args[1] else "internal"
res <- qualify(which = "all", source = source)
dir.create("qualification_output", showWarnings = FALSE)
qual_summary_text(res, "qualification_output/verdict.txt")
try(qual_summary_report(res, "qualification_output/qualification.html"), silent = TRUE)
cat(readLines("qualification_output/verdict.txt"), sep = "\n")
quit(status = if (isTRUE(res$overall)) 0L else 1L)
