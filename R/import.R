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
#' @param seed Optional integer random seed for stochastic methods (`saem`,
#'   `fsaem`, `imp`, `impmap`, `qrpem`). `NULL` (default) uses the seed
#'   already present in the bundle's own fit control, if any (e.g. the
#'   bundle was fit with `saemControl(seed = 99)`); an explicit value
#'   overrides that. [qual_reference_refit()] passes the stored seed into the
#'   method-appropriate control constructor, making a same-seed re-fit of a
#'   stochastic method exactly reproducible rather than merely
#'   tolerance-compared.
#' @param initial_estimates Starting values for re-fitting this reference.
#'   `NULL` (default) uses the bundle's own pre-fit priors (`fit$iniDf0`,
#'   preserved by `nlmixr2save::saveFit()`) -- NOT the fitted/post-fit values
#'   baked into the reconstructed model source, so a local re-fit reproduces
#'   the original cold-start optimizer trajectory instead of warm-starting
#'   from the answer. Otherwise a named numeric vector/list overriding
#'   specific parameter names (unnamed ones keep the bundle's iniDf0 value),
#'   or a compiled rxode2/nlmixr2 model object (or an unevaluated model
#'   function) whose own `$iniDf` starting values are used instead.
#' @return A reference list (see [qual_reference_write()]).
#' @export
qual_import_bundle <- function(zip, model_name, threads, method = NULL,
                               control = NULL, description = "",
                               stochastic = NULL, category = "",
                               seed = NULL, initial_estimates = NULL) {
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

  .qual_attach_nlmixr2est()

  # reconstruct + fingerprint (loadFit needs cwd == extract dir)
  old <- setwd(ex$dir); on.exit(setwd(old), add = TRUE)
  fit <- nlmixr2save::loadFit(ex$base)
  .qual_patch_loaded_fit(fit)
  if (is.null(stochastic)) stochastic <- .qual_method_is_stochastic(method)
  fp <- qual_extract_fit(fit, model = model_name, method = method,
                         category = category, stochastic = stochastic,
                         threads = threads)
  ie <- .qual_resolve_initial_estimates(initial_estimates, fit)
  seed <- .qual_resolve_seed(seed, fit, method)
  setwd(old)

  ref <- list(
    schema_version = "1.0.0",
    id = NA_character_,                    # filled below via qual_reference_id
    model = list(name = model_name, code = model_code, description = description),
    data = list(name = tools::file_path_sans_ext(basename(zip)),
                records = records),
    method = list(est = method, control = control, seed = seed),
    reference = list(threads = threads, ofv = fp$ofv, params = fp$params,
                     initial_estimates = ie,
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

# nlmixr2save::loadFit()-reconstructed fits resolve some unset accessor
# fields to a same-named function elsewhere on the search path instead of
# NULL (a freshly-fit object correctly gets NULL for these) -- an
# environment-resolution quirk in how the reconstructed `ui` dispatches
# through rxode2's rxUiGet/nmObjGet, not something nlmixr2qual controls.
# Confirmed for:
#   - fit$nlme -> the nlme package's nlme() function, breaking $sigma
#     (.sigma() does x$nlme, expects NULL, gets a function)
#   - fit$message -> base::message(), breaking the convergence fallback in
#     qual_extract_fit() (does nzchar(fit$message), errors coercing a closure)
# Patch each binding directly so a reconstructed fit's accessors match a
# fresh fit's. Extend this list if another method surfaces the same pattern
# on a different field.
.qual_patch_loaded_fit <- function(fit) {
  for (field in c("nlme", "message")) {
    if (!exists(field, envir = fit$env, inherits = FALSE))
      assign(field, NULL, envir = fit$env)
  }
  invisible(fit)
}

# A pre-fit iniDf (fit$iniDf0, or a model's own $iniDf) -> name/ptype/value.
# iniDf rows are theta (ntheta set) or eta/omega (neta1/neta2 set); there is
# no separate pre-fit "sigma" category -- residual-error thetas (e.g. add.sd)
# only become "sigma"-classed post-fit, matching qual_extract_fit()'s params.
#
# SAEM's iniDf0 reports bounded thetas (e.g. tcl <- log(c(0, 2.7, 100))) under
# an internal "rxBoundedTr.<name>" alias with a value on SAEM's own bounded-to-
# unconstrained transform scale, not the plain parameter's scale the
# reconstructed model actually uses -- reusing that value as an override would
# silently apply the wrong number. Since the transform is method-internal and
# not something nlmixr2qual can safely invert, these rows are dropped; the
# affected parameter keeps whatever value the reconstructed model already has.
.qual_iniDf_to_estimates <- function(iniDf) {
  keep <- !grepl("^rxBoundedTr\\.", iniDf$name)
  iniDf <- iniDf[keep, , drop = FALSE]
  ptype <- ifelse(!is.na(iniDf$ntheta), "theta", "omega")
  data.frame(name = as.character(iniDf$name), ptype = ptype,
             value = as.numeric(iniDf$est), stringsAsFactors = FALSE)
}

# Resolve the `initial_estimates` argument into a name/ptype/value data frame.
# Default source is the bundle's own pre-fit priors (fit$iniDf0); a named
# list/vector overrides individual entries on top of that baseline, and a
# compiled (or unevaluated) model object supplies its own $iniDf instead.
.qual_resolve_initial_estimates <- function(initial_estimates, fit) {
  base <- .qual_iniDf_to_estimates(fit$iniDf0)
  if (is.null(initial_estimates)) return(base)

  if (is.function(initial_estimates) || inherits(initial_estimates, "rxUi")) {
    model <- if (is.function(initial_estimates)) rxode2::rxode2(initial_estimates)
             else initial_estimates
    return(.qual_iniDf_to_estimates(model$iniDf))
  }

  ov <- initial_estimates
  nm <- names(ov)
  if (is.null(nm) || any(!nzchar(nm)))
    stop("qual_import_bundle(): initial_estimates must be a named list/vector, ",
        "a compiled model object, or NULL")
  unknown <- setdiff(nm, base$name)
  if (length(unknown))
    stop("qual_import_bundle(): initial_estimates has unknown parameter name(s): ",
        paste(unknown, collapse = ", "))
  base$value[match(nm, base$name)] <- as.numeric(unlist(ov))
  base
}

# nlmixr2save::loadFit() sources a reconstruction script containing
# unqualified calls (lotri(), foceiControl(), tableControl(), ...) that only
# resolve if nlmixr2est is ATTACHED to the search path -- requireNamespace()
# alone is not enough, since the script is sourced inside loadFit()'s own
# (package-namespaced) call frame, not the user's global environment. Uses
# attachNamespace() (what library() calls internally) rather than library()
# itself so this doesn't trip R CMD check's "library()/require() call not
# declared" warning, which exists for a different concern (needlessly
# attaching a dependency the package itself could reference via ::) that
# doesn't apply here -- we need the SEARCH PATH side effect for a third
# party's (loadFit()'s) internal, unqualified symbol resolution, not for our
# own code. Guarded because attachNamespace() errors if already attached.
.qual_attach_nlmixr2est <- function() {
  if (!"package:nlmixr2est" %in% search()) {
    suppressMessages(requireNamespace("nlmixr2est", quietly = TRUE))
    attachNamespace("nlmixr2est")
  }
  invisible(NULL)
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

# The seed field name a method family's control object uses. saem/fsaem take
# saemControl(seed=); imp/impmap/qrpem all validate against impmapControl()
# internally (see nlmixr2est's getValidNlmixrCtl.imp/.qrpem) and share its
# impSeed= field. Methods without a seed concept (e.g. focei) are absent.
# A named LIST (not a vector): `[[` on a missing name returns NULL for a
# list but errors ("subscript out of bounds") for an atomic vector.
.qual_seed_field <- list(saem = "seed", fsaem = "seed",
                         imp = "impSeed", impmap = "impSeed", qrpem = "impSeed")

# Resolve the seed to store on a reference: an explicit `seed` wins; otherwise
# fall back to whatever seed the bundle's own fit control already used (if
# any), read off fit$control -- the generic accessor that works for both
# fresh and loadFit()-reconstructed fits (see .qual_patch_loaded_fit()'s
# comment for the general pattern of loadFit() accessor quirks; $control
# itself has not shown that quirk in testing).
.qual_resolve_seed <- function(seed, fit, method) {
  if (!is.null(seed)) return(as.integer(seed))
  field <- .qual_seed_field[[method]]
  if (is.null(field)) return(NULL)
  ctl <- tryCatch(fit$control, error = function(e) NULL)
  val <- if (is.null(ctl)) NULL else ctl[[field]]
  if (is.null(val)) NULL else as.integer(val)
}
