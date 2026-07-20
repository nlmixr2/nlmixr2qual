# One worker process per domain -> process isolation for the compiled solvers.
# Live qualification: re-fit each popPK model single-threaded and check it
# reproduces the shipped canonical baseline within tolerance.
test_that("popPK models reproduce the canonical baseline", {
  skip_if_not_installed("nlmixr2")
  skip_if(!nzchar(Sys.getenv("NLMIXR2QUAL_RUN_LIVE")),
          "set NLMIXR2QUAL_RUN_LIVE=1 to run live qualification tests")
  skip_if_not_installed("nlmixr2lib")
  qual_set_threads(qual_inner_threads())  # pinned by setup.R / runner

  reg <- qual_registry()
  reg <- reg[reg$domain == "popPK", , drop = FALSE]
  methods <- qual_methods()
  skip_if_not(nrow(reg) > 0, "no popPK models in registry")

  for (i in seq_len(nrow(reg))) {
    entry <- as.list(reg[i, ])
    base_file <- file.path(.qual_pkg_file("baseline"),
                           paste0(entry$name, "__", entry$method, ".qs2"))
    skip_if_not(file.exists(base_file),
                paste("no baseline for", entry$name, entry$method))
    category <- methods$category[methods$method == entry$method]
    fp <- qual_fit_entry(entry, category = category,
                         threads = qual_inner_threads())
    cmp <- qual_compare(fp, qs2::qs_read(base_file))
    expect_true(cmp$pass,
      info = paste(entry$name, "-",
                   paste(cmp$detail$quantity[!cmp$detail$pass],
                         collapse = ", ")))
  }
})
