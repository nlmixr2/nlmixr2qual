# import.R -- build a thread-tagged JSON reference from an nlmixr2save .zip.

# Extract a bundle to a fresh normal-filesystem temp dir with base R unzip
# (avoids the zip:: mtime bug), preserving the base name loadFit needs.
.qual_extract_bundle <- function(zip) {
  stopifnot(file.exists(zip))
  base <- sub("\\.zip$", "", basename(zip))
  exdir <- file.path(tempdir(), paste0("qualref-", base, "-",
                                       as.integer(stats::runif(1, 1, 1e9))))
  dir.create(exdir, recursive = TRUE)
  utils::unzip(zip, exdir = exdir)
  list(dir = exdir, base = base)
}

# Parse `est = "<method>"` out of the bundle's -env.R reconstruction script.
.qual_bundle_method <- function(dir, base) {
  envR <- readLines(file.path(dir, paste0(base, "-env.R")), warn = FALSE)
  hit <- grep("^\\s*est\\s*=\\s*\"", envR, value = TRUE)
  if (!length(hit)) return(NA_character_)
  sub(".*est\\s*=\\s*\"([^\"]+)\".*", "\\1", hit[1])
}

#' Import an nlmixr2save bundle as a thread-tagged qualification reference
#'
#' Reconstructs the fit with [nlmixr2save::loadFit()], extracts a fingerprint,
#' and embeds the model source and input data so the reference is self-contained.
#' A fit does not record its rxode2 thread count, so `threads` must be supplied
#' by the caller (the count the bundle was fit at).
#' @param zip Path to a `.zip` from [nlmixr2save::saveFit()].
#' @param model_name Human name for the model (used in the reference id).
#' @param threads Integer thread count the bundle was fit at (REQUIRED).
#' @param method Optional est method override; default read from the bundle.
#' @param control Optional named list of fit-control settings for re-fits.
#' @param description Optional model description string.
#' @param stochastic Optional logical; default inferred from the method.
#' @param category Optional method-family label for tolerance reporting.
#' @return A reference list (see [qual_reference_write()]).
#' @export
qual_import_bundle <- function(zip, model_name, threads, method = NULL,
                               control = NULL, description = "",
                               stochastic = NULL, category = "") {
  if (missing(threads) || is.null(threads) || is.na(threads))
    stop("qual_import_bundle(): `threads` (fit thread count) is required")
  threads <- as.integer(threads)

  ex <- .qual_extract_bundle(zip)
  on.exit(unlink(ex$dir, recursive = TRUE), add = TRUE)

  if (is.null(method)) method <- .qual_bundle_method(ex$dir, ex$base)
  stopifnot(is.character(method), nzchar(method))

  # model source (deparsed rxUi reconstruction script). The script builds up
  # its result through a chain of reassignments to a bare `ui` identifier
  # (ui <- rxode2::rxode2(ui); ui <- rxUiDecompress(ui); ... rm(envir = ui) ...),
  # so every occurrence -- not just assignment targets -- must be renamed to
  # model_name for the chain to keep resolving.
  model_code <- paste(readLines(file.path(ex$dir, paste0(ex$base, "-ui.R")),
                                warn = FALSE), collapse = "\n")
  model_code <- gsub("\\bui\\b", model_name, model_code)

  records <- utils::read.csv(file.path(ex$dir, paste0(ex$base, "-origData.csv")),
                             check.names = FALSE)

  # nlmixr2save::loadFit() sources a reconstruction script containing
  # unqualified calls (lotri(), foceiControl(), tableControl(), ...) that only
  # resolve if nlmixr2est is ATTACHED to the search path -- requireNamespace()
  # alone is not enough, since the script is sourced inside loadFit()'s own
  # (package-namespaced) call frame, not the user's global environment.
  suppressMessages(requireNamespace("nlmixr2est", quietly = TRUE))
  suppressMessages(library("nlmixr2est", character.only = TRUE))

  # reconstruct + fingerprint (loadFit needs cwd == extract dir)
  old <- setwd(ex$dir); on.exit(setwd(old), add = TRUE)
  fit <- nlmixr2save::loadFit(ex$base)
  .qual_patch_loaded_fit(fit)
  if (is.null(stochastic)) stochastic <- .qual_method_is_stochastic(method)
  fp <- qual_extract_fit(fit, model = model_name, method = method,
                         category = category, stochastic = stochastic,
                         threads = threads)
  setwd(old)

  ref <- list(
    schema_version = "1.0.0",
    id = NA_character_,                    # filled below via qual_reference_id
    model = list(name = model_name, code = model_code, description = description),
    data = list(name = tools::file_path_sans_ext(basename(zip)),
                records = records),
    method = list(est = method, control = control),
    reference = list(threads = threads, ofv = fp$ofv, params = fp$params,
                     shrink = fp$shrink, converged = fp$converged,
                     covMethod = fp$covMethod, stochastic = fp$stochastic,
                     category = fp$category),
    provenance = list(
      software = list(nlmixr2 = .qual_pkg_ver("nlmixr2"),
                      nlmixr2est = .qual_pkg_ver("nlmixr2est"),
                      rxode2 = .qual_pkg_ver("rxode2"),
                      R = as.character(getRversion())),
      created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
      source_bundle = basename(zip),
      nlmixr2save_version = .qual_pkg_ver("nlmixr2save")))
  ref$id <- qual_reference_id(ref)
  ref
}

# nlmixr2save::loadFit()-reconstructed fits resolve fit$nlme to the `nlme`
# package's nlme() function instead of NULL (a freshly-fit object correctly
# gets NULL) -- an environment-resolution quirk in how the reconstructed `ui`
# dispatches through rxode2's rxUiGet, not something nlmixr2qual controls.
# That corrupted value then breaks nlmixr2est's internal $sigma accessor
# (.sigma() does x$nlme, expects NULL, gets a function). Patch the binding
# directly so a reconstructed fit's accessors match a fresh fit's.
.qual_patch_loaded_fit <- function(fit) {
  if (!exists("nlme", envir = fit$env, inherits = FALSE))
    assign("nlme", NULL, envir = fit$env)
  invisible(fit)
}

.qual_pkg_ver <- function(pkg) {
  tryCatch(as.character(utils::packageVersion(pkg)),
           error = function(e) NA_character_)
}

# Stochastic estimators (compared under the looser tolerance, reported
# informational). Extend as new methods are qualified.
.qual_stochastic_methods <- c("saem", "fsaem", "imp", "impmap", "qrpem",
                              "npag", "npb", "advi", "vae")
.qual_method_is_stochastic <- function(method) method %in% .qual_stochastic_methods
