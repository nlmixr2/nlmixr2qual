# nlmixr2qual Reference-Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-architect `nlmixr2qual` from a frozen-fingerprint regression suite (internal `.qs2` baselines cut on simulated data) into an *import-based, organisation-extensible qualification tool*: references are known-good fits imported from `nlmixr2save` bundles, stored one-per-file as self-contained JSON, each **tagged with the thread count that produced it**; qualification re-fits each reference locally *at its own thread count* and compares against the stored reference results.

**Architecture:** A **reference** is a JSON file capturing one confirmed-good fit: model source, the embedded input dataset, the estimation method (+ optional control), the **thread count** used, and the reference result fingerprint. `qual_import_bundle()` builds one from an `nlmixr2save::saveFit()` `.zip`, with the caller asserting the thread count the bundle was fit at (a fit does not record it). `qualify()` selects references (shipped-internal or a user folder) and for each: reconstructs the model + data, pins the reference's thread count, **re-fits locally**, extracts a fingerprint, and diffs it against the stored reference fingerprint. Single- and multi-threaded runs are **separate references** (they may legitimately differ), compared like-for-like — never against each other — with the tolerance keyed to the reference's thread count (strict for `t1`, looser for `t>1`). `t1` is mandatory per method; `tx` is optional. The shipped-internal set ships a `t1` per method plus a `t4` where the build box supports it. The reusable comparison/tolerance/extraction engine and the thread-control engine (`threads.R`) are kept; the frozen-baseline subsystem (registry, method matrix, simulated data, `.qs2` capture) is retired.

**Tech Stack:** R package; `nlmixr2est`/`rxode2` (fitting + thread control), `nlmixr2save` (bundle import via `loadFit`), `jsonlite` (JSON I/O), `testthat` 3e (tests), Quarto (summary document). Windows-first dev box; POSIX CI.

---

## Decisions locked (from re-scope Q&A, 2026-08-13)

- **Compare mode:** re-fit locally, then compare against stored reference results.
- **Existing suite:** clean break — retire `.qs2` baselines, registry, method matrix, simulated datasets. Shipped-internal default is the **theophylline** model across **all methods that produce a valid fit**.
- **Data storage:** embedded inside each reference JSON (self-contained).
- **Import input:** a saved `nlmixr2save` `.zip` bundle.
- **Thread model:** each reference is a **single result, thread-tagged**. Qualify compares only at the reference's own thread count. Single- vs multi-threaded coverage = separate references.
- **Multi-threaded references obtained by importing one bundle per thread count** — every stored result is an independently confirmed fit (the tool never invents multi-threaded results).
- **Multi-threaded references are OPTIONAL; single-threaded is mandatory.** Every method ships a `t1` reference; a `tx` (multi-threaded) reference may or may not exist. The tooling must work correctly with a `t1`-only reference set — nothing may require `tx`. The shipped-internal set additionally includes a `t4` reference (the **default 4 cores**, `qual_default_multi_threads()`) for each method **where the build box can produce it** (≥ 4 cores).

## Thread-tolerance design (surface to reviewers)

Multi-threaded fits can differ across machines/BLAS even at the same thread count (non-associative parallel float reductions), so an exact match cannot be required for `threads > 1`. The comparison tolerance is therefore **keyed to the reference's thread count**:
- `threads == 1` → **strict** tolerance (`qual_compare(..., invariance = FALSE)`). Bit-portable; reproduces anywhere.
- `threads > 1` → **looser** tolerance (`qual_compare(..., invariance = TRUE)`), the existing knob sized for parallel-float variation. Still gates the verdict for deterministic methods; genuinely divergent environments exceed even this tolerance and fail informatively. Per-quantity `overrides` are available if a specific quantity needs loosening.

Stochastic methods are informational at every thread count. Multi-threaded references are **optional**: the default multi-thread count for the shipped set and generator is **4** (`qual_default_multi_threads()`), and the generator emits `t4` references only when the build box has ≥ 4 cores — otherwise it ships the mandatory `t1` set alone. When a `t4` reference IS present, a user qualifying on a machine with fewer cores still pins `threads = 4` (oversubscribed) so the comparison stays like-for-like; such a reference is best excluded from that machine's run (select `t1` pairs/ids, or a folder without `tx`).

## Verified facts (from spikes, do not re-derive)

- `nlmixr2save::saveFit(fit, "<base>", zip=TRUE)` → `<base>.zip` containing `<base>-ui.R` (model), `<base>-origData.csv` (input data), `<base>-objDf.csv` / `-parFixedDf.csv` / `-shrink.csv` (results), `<base>-env.R` (holds `est = "<method>"`), plus RDS/CSV internals.
- `nlmixr2save::loadFit("<base>")` round-trips to a full fit object **only when** (a) run on a normal filesystem — the `zip` package's `zip::unzip` fails to set mtime on some temp filesystems — and (b) the `.zip` file's base name matches its internal entry base names. It extracts into `getwd()` and cleans up after itself.
- A fit does **not** record its rxode2 thread count; the importer must be told it.
- A loaded fit exposes `$objDf[["OBJF"]]`, `$omega` (diag recoverable), `$shrink`, `$parFixedDf`, `$est`. `qual_extract_fit()` consumes these directly.
- Re-fitting `nlmixr2(ui, origData, est="focei")` single-threaded from a loaded reference reproduces the reference OFV to reldiff ≈ 9e-10.
- Robust manual read (avoids `zip::unzip`): `utils::unzip(zip, exdir=...)`, then `sys.source("<base>-ui.R")` → `ui`, `read.csv("<base>-origData.csv")` → data, parse `est` from `<base>-env.R`.

## Existing engine to REUSE unchanged (do not rewrite)

- `R/fingerprint.R` — `qual_extract_fit(fit, model, method, category, stochastic, threads)` → fingerprint `list(model, method, category, stochastic, threads, ofv, params[df: name,ptype,estimate,se,rse], shrink[df: name,stype,value], converged, covMethod)`.
- `R/compare.R` — `qual_compare(run, base, overrides=NULL, invariance=FALSE)` → `list(model, method, pass, detail[df])`. `base$stochastic` drives tolerance. (Called with `invariance = FALSE`; the invariance path is unused in the new architecture.)
- `R/tolerance.R` — `qual_tolerance(class, stochastic, invariance, override)`.
- `R/threads.R` — `qual_set_threads()`, `qual_inner_threads()`, `qual_invariance_threads(cores)` (capped, default 4), `qual_thread_plan()`. Used to **pin** a reference's thread count for re-fit and to pick a capped multi-thread count for tests.
- `R/provenance.R` — `qual_provenance()`, `qual_write_provenance()`.
- `R/verdict.R` — verdict roll-up helper.
- `R/report.R` + `inst/report/qualification.qmd` — adapted in Phase E.

## Files to RETIRE (Phase A)

- `R/capture.R`, `R/run.R`, `R/registry.R`, `R/versiongate.R`
- `R/data-io.R` (simulated-data reader) — replaced by embedded JSON data
- `inst/baseline/*.qs2`, `inst/models/registry.csv`, `inst/models/methods.csv`, `inst/models/*.R`
- `inst/extdata/*` simulated datasets, `inst/qualified_baseline.csv`
- `data-raw/simulate-datasets.R`, `data-raw/cut-method-baselines.R`
- Tests: `tests/testthat/test-capture.R`, `test-run.R`, `test-registry.R`, `test-versiongate.R`, `test-data-io.R`, `test-fit-live.R`, `test-qual-popPK.R`, `test-qual-disease.R`, `test-qual-PKPD.R`, `test-qual-methods.R`
- `run_qualification.R` (reworked in Phase E)

**KEEP** `R/threads.R` and `tests/testthat/test-threads.R` — the thread-control engine pins each reference's thread count for re-fit. `R/run.R` is retired; its single-threaded strict stage migrates into `qualify()`.

## New files (created across tasks)

- `R/reference.R` — reference object + JSON read/write/validate
- `R/import.R` — `qual_import_bundle()`
- `R/refit.R` — `qual_reference_refit()`
- `R/qualify.R` — `qualify()`, `qual_load_references()`, `qual_select()`
- `R/catalogue.R` — reference-catalogue documentation
- `inst/references/theophylline__*__t1.json` (mandatory) + optional `__t4.json` — shipped internal references
- `data-raw/make-theophylline-references.R` — generator for the shipped set
- `inst/report/qualification.qmd` — reworked summary template
- `tests/testthat/helper-references.R` + new `test-*.R` files per task

## Identity & selection conventions (used everywhere)

- **pair** = `"<model>__<method>"` (e.g. `theophylline__focei`). Computed from `ref$model$name` + `ref$method$est`.
- **id** = `"<model>__<method>__t<threads>"` (e.g. `theophylline__focei__t1`). Unique; used as the JSON filename stem and the key in the loaded reference list.
- `qual_select(refs, which)`: `which = "all"` selects everything; otherwise each entry of `which` matches either a **pair** (selects all its thread variants) or a full **id**.

---

## Task 0: Branch + dependency setup

**Files:**
- Modify: `DESCRIPTION`

- [x] **Step 1: Create the working branch**

Run:
```bash
git checkout -b nlmixr2qual-references
```

- [x] **Step 2: Add/adjust dependencies in DESCRIPTION**

Ensure `Imports:` includes `jsonlite` and `nlmixr2save` (keep `nlmixr2est`, `rxode2`, `utils`, `stats`):
```
Imports:
    jsonlite,
    nlmixr2save,
    nlmixr2est,
    rxode2,
    utils,
    stats
```
Add `nlmixr2save` (GitHub-only) to `Remotes:`:
```
Remotes:
    nlmixr2/nlmixr2save
```

- [x] **Step 3: Verify the package still loads**

Run: `Rscript -e 'pkgload::load_all(".", quiet=TRUE); cat("OK\n")'`
Expected: `OK` (warnings about soon-to-be-removed files are fine).

- [x] **Step 4: Commit**

```bash
git add DESCRIPTION
git commit -m "chore: branch + deps (jsonlite, nlmixr2save) for reference architecture"
```

---

## Task 1: Retire the frozen-baseline subsystem

**Files:**
- Delete: files under "Files to RETIRE" (NOT `R/threads.R` / `test-threads.R`).

- [x] **Step 1: Remove retired source, data, and tests**

```bash
git rm R/capture.R R/run.R R/registry.R R/versiongate.R R/data-io.R
git rm -r inst/baseline inst/models
git rm inst/qualified_baseline.csv
git rm data-raw/simulate-datasets.R data-raw/cut-method-baselines.R
git rm tests/testthat/test-capture.R tests/testthat/test-run.R tests/testthat/test-registry.R \
       tests/testthat/test-versiongate.R tests/testthat/test-data-io.R \
       tests/testthat/test-fit-live.R tests/testthat/test-qual-popPK.R tests/testthat/test-qual-disease.R \
       tests/testthat/test-qual-PKPD.R tests/testthat/test-qual-methods.R
git rm run_qualification.R
```
(Do NOT remove `R/threads.R` or `tests/testthat/test-threads.R`. If `inst/extdata` holds only simulated data, `git rm -r inst/extdata`; if it holds fixtures still needed, leave it.)

- [x] **Step 2: Remove now-dangling roxygen exports**

Run: `Rscript -e 'devtools::document()'`
Confirm `NAMESPACE` no longer exports `qual_run`, `qual_capture_baseline`, `qual_registry`, `qual_version_gate`, `qual_read_dataset`. The thread exports (`qual_set_threads`, `qual_thread_plan`, `qual_inner_threads`, `qual_invariance_threads`) are RETAINED.

- [x] **Step 3: Verify remaining engine still loads and its tests pass**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat", filter="compare|tolerance|fingerprint|provenance|verdict|report|threads")'`
Expected: all pass (these modules are untouched).

- [x] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: retire frozen-baseline subsystem (registry, method matrix, .qs2, sim data)"
```

---

## Task 2: JSON reference object — write/read/validate

**Files:**
- Create: `R/reference.R`
- Test: `tests/testthat/test-reference.R`

A reference is a plain list serialised to JSON. Fields:
`schema_version`, `id`, `model{name,code,description}`, `data{name,records}`, `method{est,control}`, `reference{threads,ofv,params,shrink,converged,covMethod,stochastic,category}`, `provenance{software,created,source_bundle,nlmixr2save_version}`.

- [x] **Step 1: Write the failing test**

```r
test_that("a reference round-trips through JSON unchanged", {
  ref <- list(
    schema_version = "1.0.0",
    id = "demo__focei__t1",
    model = list(name = "demo", code = "one <- function(){}", description = "d"),
    data = list(name = "dat", records = data.frame(ID = 1:2, DV = c(1.1, 2.2))),
    method = list(est = "focei", control = NULL),
    reference = list(
      threads = 1L, ofv = 116.8041,
      params = data.frame(name = "tka", ptype = "theta", estimate = 0.46,
                          se = 0.19, rse = 42.0, stringsAsFactors = FALSE),
      shrink = data.frame(name = "eta.ka", stype = "eta", value = 1.86,
                          stringsAsFactors = FALSE),
      converged = TRUE, covMethod = "r,s", stochastic = FALSE,
      category = "Linearized"),
    provenance = list(software = list(nlmixr2 = "6.0.0"),
                      created = "2026-08-13T00:00:00Z",
                      source_bundle = "demo.zip",
                      nlmixr2save_version = "0.1.0"))
  path <- tempfile(fileext = ".json")
  qual_reference_write(ref, path)
  back <- qual_reference_read(path)
  expect_equal(back$id, ref$id)
  expect_equal(back$reference$threads, 1L)
  expect_equal(back$reference$ofv, 116.8041)
  expect_equal(back$data$records$DV, c(1.1, 2.2))
  expect_equal(back$reference$params$estimate, 0.46)
  expect_true(qual_reference_validate(back))
})

test_that("validate rejects a reference missing required fields", {
  expect_error(qual_reference_validate(list(id = "x")), "schema_version")
})

test_that("pair and id helpers agree", {
  ref <- list(model = list(name = "demo"), method = list(est = "focei"),
              reference = list(threads = 4L))
  expect_equal(qual_reference_pair(ref), "demo__focei")
  expect_equal(qual_reference_id(ref), "demo__focei__t4")
})
```

- [x] **Step 2: Run to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-reference.R")'`
Expected: FAIL — `qual_reference_write` not found.

- [x] **Step 3: Implement `R/reference.R`**

```r
# reference.R -- the JSON reference object (one confirmed-good fit, thread-tagged).

.qual_ref_required <- c("schema_version", "id", "model", "data", "method",
                        "reference", "provenance")

#' Model-method pair key for a reference (no thread tag)
#' @param ref A reference list.
#' @return `"<model>__<method>"`.
#' @export
qual_reference_pair <- function(ref) {
  paste0(ref$model$name, "__", ref$method$est)
}

#' Unique, thread-tagged id for a reference
#' @param ref A reference list.
#' @return `"<model>__<method>__t<threads>"`.
#' @export
qual_reference_id <- function(ref) {
  paste0(qual_reference_pair(ref), "__t", as.integer(ref$reference$threads))
}

#' Write a qualification reference to a JSON file
#' @param ref A reference list.
#' @param path Output `.json` path.
#' @return `path`, invisibly.
#' @export
qual_reference_write <- function(ref, path) {
  qual_reference_validate(ref)
  json <- jsonlite::toJSON(ref, dataframe = "columns", null = "null",
                           na = "null", auto_unbox = TRUE, digits = NA,
                           pretty = TRUE)
  writeLines(json, path)
  invisible(path)
}

#' Read a qualification reference from a JSON file
#' @param path Path to a `.json` reference.
#' @return A reference list, with data-frame fields restored.
#' @export
qual_reference_read <- function(path) {
  ref <- jsonlite::fromJSON(path, simplifyVector = TRUE,
                            simplifyDataFrame = TRUE)
  if (is.null(ref$reference$params)) ref$reference$params <- data.frame()
  if (is.null(ref$reference$shrink)) ref$reference$shrink <- data.frame()
  ref
}

#' Validate a reference has the required structure
#' @param ref A reference list.
#' @return `TRUE` invisibly if valid; errors otherwise.
#' @export
qual_reference_validate <- function(ref) {
  miss <- setdiff(.qual_ref_required, names(ref))
  if (length(miss))
    stop("reference missing required field(s): ", paste(miss, collapse = ", "))
  if (is.null(ref$method$est) || !nzchar(ref$method$est))
    stop("reference method$est must be a non-empty method string")
  if (is.null(ref$reference$threads) || is.na(ref$reference$threads))
    stop("reference must record reference$threads")
  invisible(TRUE)
}
```

- [x] **Step 4: Run to verify pass**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-reference.R")'`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add R/reference.R tests/testthat/test-reference.R
git commit -m "feat: thread-tagged JSON reference object (write/read/validate)"
```

---

## Task 3: Fixture — a real single-threaded theophylline bundle

**Files:**
- Create: `tests/testthat/helper-references.R`
- Create: `tests/testthat/fixtures/theophylline_focei.zip` (single-threaded, committed)
- Create: `data-raw/make-fixture-bundle.R`

- [x] **Step 1: Write the fixture generator**

`data-raw/make-fixture-bundle.R`:
```r
# Generates tests/testthat/fixtures/theophylline_focei.zip from a real
# SINGLE-THREADED fit (portable across machines). Run once on a normal
# filesystem: Rscript data-raw/make-fixture-bundle.R
suppressMessages(library(nlmixr2est)); library(nlmixr2data)
rxode2::setRxThreads(1L)
one.cmt <- function() {
  ini({ tka <- 0.45; tcl <- log(c(0, 2.7, 100)); tv <- 3.45
        eta.ka ~ 0.6; eta.cl ~ 0.3; eta.v ~ 0.1; add.sd <- 0.7 })
  model({ ka <- exp(tka + eta.ka); cl <- exp(tcl + eta.cl); v <- exp(tv + eta.v)
          linCmt() ~ add(add.sd) })
}
dir <- "tests/testthat/fixtures"; dir.create(dir, showWarnings = FALSE, recursive = TRUE)
old <- setwd(dir); on.exit(setwd(old))
fit <- nlmixr2(one.cmt, theo_sd, est = "focei")
unlink("theophylline_focei.zip")
nlmixr2save::saveFit(fit, "theophylline_focei", zip = TRUE)
cat("wrote", file.path(dir, "theophylline_focei.zip"), "\n")
```

- [x] **Step 2: Generate the fixture**

Run: `Rscript data-raw/make-fixture-bundle.R`
Expected: `wrote tests/testthat/fixtures/theophylline_focei.zip`.

- [x] **Step 3: Add the shared helper**

`tests/testthat/helper-references.R`:
```r
fixture_bundle <- function(name = "theophylline_focei.zip") {
  testthat::test_path("fixtures", name)
}
skip_if_no_live <- function() {
  testthat::skip_if_not_installed("nlmixr2est")
  testthat::skip_if_not_installed("nlmixr2save")
  testthat::skip_if(!nzchar(Sys.getenv("NLMIXR2QUAL_RUN_LIVE")),
                    "set NLMIXR2QUAL_RUN_LIVE=1 for live fitting tests")
}
# Build a bundle from a live fit at a given thread count, into `dir`. Returns
# the .zip path. Used for multi-threaded (machine-specific) tests.
build_bundle <- function(dir, base, est = "focei", threads = 1L) {
  suppressMessages(library(nlmixr2est)); library(nlmixr2data)
  rxode2::setRxThreads(as.integer(threads))
  one.cmt <- function() {
    ini({ tka <- 0.45; tcl <- log(c(0, 2.7, 100)); tv <- 3.45
          eta.ka ~ 0.6; eta.cl ~ 0.3; eta.v ~ 0.1; add.sd <- 0.7 })
    model({ ka <- exp(tka + eta.ka); cl <- exp(tcl + eta.cl); v <- exp(tv + eta.v)
            linCmt() ~ add(add.sd) })
  }
  fit <- nlmixr2est::nlmixr2(one.cmt, nlmixr2data::theo_sd, est = est)
  old <- setwd(dir); on.exit(setwd(old))
  unlink(paste0(base, ".zip"))
  nlmixr2save::saveFit(fit, base, zip = TRUE)
  file.path(dir, paste0(base, ".zip"))
}
```

- [x] **Step 4: Commit**

```bash
git add data-raw/make-fixture-bundle.R tests/testthat/fixtures/theophylline_focei.zip tests/testthat/helper-references.R
git commit -m "test: single-threaded theophylline bundle fixture + helpers"
```

---

## Task 4: Import a bundle into a reference (thread-tagged)

**Files:**
- Create: `R/import.R`
- Test: `tests/testthat/test-import.R`

`qual_import_bundle()` extracts the bundle, gets a fit via `loadFit`, and builds the thread-tagged reference. The caller asserts `threads` (a fit does not store it).

- [x] **Step 1: Write the failing test**

```r
test_that("import builds a valid thread-tagged reference from a bundle", {
  skip_if_no_live()
  ref <- qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                            method = "focei", threads = 1L,
                            description = "1-cmt oral PK")
  expect_true(qual_reference_validate(ref))
  expect_equal(ref$method$est, "focei")
  expect_equal(ref$reference$threads, 1L)
  expect_equal(ref$id, "theophylline__focei__t1")
  expect_gt(nrow(ref$data$records), 100)          # embedded data
  expect_equal(ref$reference$ofv, 116.8041, tolerance = 1e-2)
  expect_true(any(ref$reference$params$ptype == "omega"))
  expect_true(ref$reference$converged)
  e <- new.env(); eval(parse(text = ref$model$code), envir = e)
  expect_true(exists("theophylline", envir = e))   # model source reconstructs
})

test_that("import requires an explicit thread count", {
  skip_if_no_live()
  expect_error(qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                                  method = "focei"),
               "threads")
})
```

- [x] **Step 2: Run to verify it fails**

Run: `NLMIXR2QUAL_RUN_LIVE=1 Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-import.R")'`
Expected: FAIL — `qual_import_bundle` not found.

- [x] **Step 3: Implement `R/import.R`**

```r
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

  # model source (deparsed rxUi reconstruction script); rename `ui` -> model_name
  model_code <- paste(readLines(file.path(ex$dir, paste0(ex$base, "-ui.R")),
                                warn = FALSE), collapse = "\n")
  model_code <- gsub("(^|\\n)ui\\s*<-", paste0("\\1", model_name, " <-"),
                     model_code)

  records <- utils::read.csv(file.path(ex$dir, paste0(ex$base, "-origData.csv")),
                             check.names = FALSE)

  # reconstruct + fingerprint (loadFit needs cwd == extract dir)
  old <- setwd(ex$dir); on.exit(setwd(old), add = TRUE)
  fit <- nlmixr2save::loadFit(ex$base)
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

.qual_pkg_ver <- function(pkg) {
  tryCatch(as.character(utils::packageVersion(pkg)),
           error = function(e) NA_character_)
}

# Stochastic estimators (compared under the looser tolerance, reported
# informational). Extend as new methods are qualified.
.qual_stochastic_methods <- c("saem", "fsaem", "imp", "impmap", "qrpem",
                              "npag", "npb", "advi", "vae")
.qual_method_is_stochastic <- function(method) method %in% .qual_stochastic_methods
```

- [x] **Step 4: Run to verify pass**

Run: `NLMIXR2QUAL_RUN_LIVE=1 Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-import.R")'`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add R/import.R tests/testthat/test-import.R
git commit -m "feat: import an nlmixr2save bundle into a thread-tagged JSON reference"
```

---

## Task 5: Re-fit a reference locally (at its own thread count)

**Files:**
- Create: `R/refit.R`
- Test: `tests/testthat/test-refit.R`

- [x] **Step 1: Write the failing test**

```r
test_that("re-fitting a reference at its own thread count reproduces its OFV", {
  skip_if_no_live()
  ref <- qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                            method = "focei", threads = 1L)
  fp <- qual_reference_refit(ref)
  expect_equal(fp$ofv, ref$reference$ofv, tolerance = 1e-3)
  expect_equal(fp$method, "focei")
  expect_equal(fp$threads, 1L)             # pinned to the reference's threads
  expect_true(fp$converged)
})
```

- [x] **Step 2: Run to verify it fails**

Run: `NLMIXR2QUAL_RUN_LIVE=1 Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-refit.R")'`
Expected: FAIL — `qual_reference_refit` not found.

- [x] **Step 3: Implement `R/refit.R`**

```r
# refit.R -- reconstruct a reference's model + data and re-fit at its thread count.

#' Re-fit a reference in the local environment and return its fingerprint
#'
#' Pins the reference's own thread count (results can differ across thread
#' counts, so the comparison is always like-for-like).
#' @param ref A reference list.
#' @param threads Thread count to pin; defaults to the reference's own count.
#' @return A fingerprint (see [qual_extract_fit()]).
#' @export
qual_reference_refit <- function(ref, threads = ref$reference$threads) {
  qual_reference_validate(ref)
  threads <- as.integer(threads)
  qual_set_threads(threads)                        # pin rxode2 inner threads
  e <- new.env()
  eval(parse(text = ref$model$code), envir = e)
  model <- get(ref$model$name, envir = e)
  data <- as.data.frame(ref$data$records, stringsAsFactors = FALSE)
  est <- ref$method$est
  control <- .qual_build_control(est, ref$method$control)
  fit <- if (is.null(control)) {
    nlmixr2est::nlmixr2(model, data, est = est)
  } else {
    nlmixr2est::nlmixr2(model, data, est = est, control = control)
  }
  qual_extract_fit(fit, model = ref$model$name, method = est,
                   category = ref$reference$category,
                   stochastic = ref$reference$stochastic, threads = threads)
}

# Turn a stored control list into the method-appropriate control object.
# NULL (no stored control) re-fits on the estimator default.
.qual_build_control <- function(est, control) {
  if (is.null(control) || !length(control)) return(NULL)
  do.call(nlmixr2est::foceiControl, control)  # extend per method family as needed
}
```

- [x] **Step 4: Run to verify pass**

Run: `NLMIXR2QUAL_RUN_LIVE=1 Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-refit.R")'`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add R/refit.R tests/testthat/test-refit.R
git commit -m "feat: re-fit a reference locally at its own thread count"
```

---

## Task 6: Reference loading + selection

**Files:**
- Create: `R/qualify.R` (loading + selection portion)
- Test: `tests/testthat/test-select.R`

- [x] **Step 1: Write the failing test**

```r
mk_ref <- function(model, method, threads) list(
  schema_version="1.0.0",
  id=paste0(model,"__",method,"__t",threads),
  model=list(name=model, code="x<-1", description=""),
  data=list(name="d", records=data.frame(ID=1)),
  method=list(est=method, control=NULL),
  reference=list(threads=threads, ofv=1, params=data.frame(), shrink=data.frame(),
                 converged=TRUE, covMethod="", stochastic=FALSE, category=""),
  provenance=list(software=list(), created="", source_bundle="",
                  nlmixr2save_version=""))

test_that("qual_load_references reads a folder keyed by id", {
  dir <- tempfile(); dir.create(dir)
  for (r in list(mk_ref("a","focei",1), mk_ref("a","focei",4), mk_ref("b","saem",1)))
    qual_reference_write(r, file.path(dir, paste0(r$id, ".json")))
  refs <- qual_load_references(source = dir)
  expect_setequal(names(refs), c("a__focei__t1", "a__focei__t4", "b__saem__t1"))
})

test_that("qual_select: all, by pair (all thread variants), and by full id", {
  refs <- list("a__focei__t1"=mk_ref("a","focei",1),
               "a__focei__t4"=mk_ref("a","focei",4),
               "b__saem__t1" =mk_ref("b","saem",1))
  expect_length(qual_select(refs, "all"), 3)
  expect_setequal(names(qual_select(refs, "a__focei")),        # pair -> both threads
                  c("a__focei__t1", "a__focei__t4"))
  expect_equal(names(qual_select(refs, "a__focei__t4")), "a__focei__t4")  # full id
  expect_error(qual_select(refs, "zzz__nope"), "no reference")
})
```

- [x] **Step 2: Run to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-select.R")'`
Expected: FAIL — `qual_load_references` not found.

- [x] **Step 3: Implement loading + selection in `R/qualify.R`**

```r
# qualify.R -- load, select, and run references.

.qual_internal_dir <- function() system.file("references", package = "nlmixr2qual")

#' Default multi-thread count for the shipped reference set and generators
#' @return Integer thread count (4).
#' @export
qual_default_multi_threads <- function() 4L

#' Load references from the internal set or a folder of JSON files
#' @param source `"internal"` (shipped set) or a path to a folder of `.json`.
#' @return A named list of references, keyed by thread-tagged `id`.
#' @export
qual_load_references <- function(source = "internal") {
  dir <- if (identical(source, "internal")) .qual_internal_dir() else source
  if (!dir.exists(dir)) stop("reference source folder not found: ", dir)
  files <- list.files(dir, pattern = "\\.json$", full.names = TRUE)
  refs <- lapply(files, qual_reference_read)
  stats::setNames(refs, vapply(refs, function(r) r$id, character(1)))
}

#' Select references to qualify, by pair or full id
#' @param refs A named list of references (from [qual_load_references()]).
#' @param which `"all"` (default), or a vector of pairs (`"<model>__<method>"`,
#'   selecting all thread variants) and/or full ids (`"...__t<n>"`).
#' @return The filtered named list.
#' @export
qual_select <- function(refs, which = "all") {
  if (identical(which, "all")) return(refs)
  pair <- vapply(refs, qual_reference_pair, character(1))
  id   <- names(refs)
  keep <- id %in% which | pair %in% which
  matched_targets <- union(id[keep], pair[keep])
  miss <- setdiff(which, matched_targets)
  if (length(miss)) stop("no reference(s) for: ", paste(miss, collapse = ", "))
  refs[keep]
}
```

- [x] **Step 4: Run to verify pass**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-select.R")'`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add R/qualify.R tests/testthat/test-select.R
git commit -m "feat: reference loading + pair/id selection (internal or folder)"
```

---

## Task 7: The qualify() run engine

**Files:**
- Modify: `R/qualify.R` (add `qualify()`)
- Test: `tests/testthat/test-qualify.R`

- [x] **Step 1: Write the failing test**

```r
test_that("qualify re-fits each reference at its thread count and reports a verdict", {
  skip_if_no_live()
  dir <- tempfile(); dir.create(dir)
  ref <- qual_import_bundle(fixture_bundle(), model_name = "theophylline",
                            method = "focei", threads = 1L)
  qual_reference_write(ref, file.path(dir, paste0(ref$id, ".json")))

  res <- qualify(which = "all", source = dir)
  expect_s3_class(res, "nlmixr2qual_result")
  expect_equal(nrow(res$summary), 1L)
  expect_equal(res$summary$id[1], "theophylline__focei__t1")
  expect_equal(res$summary$threads[1], 1L)
  expect_true(res$summary$pass[1])            # local re-fit reproduces reference
  expect_true(res$overall)                    # OVERALL PASS
})

test_that("qualify supports a multi-threaded reference (same machine)", {
  skip_if_no_live()
  n <- qual_invariance_threads()
  skip_if(n <= 1L, "single-core box: no multi-threaded stage to test")
  dir <- tempfile(); dir.create(dir)
  zip <- build_bundle(dir, "theo_focei_multi", est = "focei", threads = n)
  ref <- qual_import_bundle(zip, model_name = "theophylline", method = "focei",
                            threads = n)
  qual_reference_write(ref, file.path(dir, paste0(ref$id, ".json")))
  file.remove(zip)                            # keep only the JSON references
  res <- qualify("theophylline__focei", dir)  # selects the tN variant
  expect_equal(res$summary$threads[1], as.integer(n))
  expect_true(res$summary$pass[1])            # reproduces at N threads, same box
  expect_true(res$overall)
})
```

- [x] **Step 2: Run to verify it fails**

Run: `NLMIXR2QUAL_RUN_LIVE=1 Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-qualify.R")'`
Expected: FAIL — `qualify` not found.

- [x] **Step 3: Implement `qualify()`**

```r
#' Qualify the local install against reference model-method pairs
#'
#' For each selected reference, pins the reference's thread count, re-fits the
#' model locally, and compares the fresh fingerprint against the stored reference
#' fingerprint. Deterministic methods are strict and gate the verdict; stochastic
#' methods are compared under the looser tolerance and reported but never gate.
#' Single- and multi-threaded references are distinct entries, each compared only
#' against itself.
#' @param which `"all"` (default), or pairs/ids (see [qual_select()]).
#' @param source `"internal"` or a folder of `.json` references.
#' @return An `nlmixr2qual_result`: `list(summary, details, provenance, overall)`.
#' @export
qualify <- function(which = "all", source = "internal") {
  refs <- qual_select(qual_load_references(source), which)
  rxode2::rxClean()                 # start from a clean compiled-model cache
  rows <- list(); details <- list()
  for (id in names(refs)) {
    ref <- refs[[id]]
    fp <- qual_reference_refit(ref)                 # pinned to ref's threads
    base <- .qual_ref_fingerprint(ref)
    # tolerance keyed to thread count: strict for single-threaded (bit-portable),
    # looser for multi-threaded (absorbs cross-machine parallel-float variation).
    cmp <- qual_compare(fp, base, invariance = ref$reference$threads > 1L)
    strict <- !isTRUE(ref$reference$stochastic)
    rows[[id]] <- data.frame(
      id = id, model = ref$model$name, method = ref$method$est,
      threads = as.integer(ref$reference$threads), strict = strict,
      pass = cmp$pass, ofv_ref = ref$reference$ofv, ofv_local = fp$ofv,
      stringsAsFactors = FALSE)
    details[[id]] <- cmp$detail
  }
  summary <- do.call(rbind, rows); rownames(summary) <- NULL
  overall <- all(summary$pass[summary$strict])       # only strict pairs gate
  structure(list(summary = summary, details = details,
                 provenance = qual_provenance(),
                 overall = overall),
            class = "nlmixr2qual_result")
}

# Rebuild the fingerprint list qual_compare expects from a reference's stored
# `reference` block.
.qual_ref_fingerprint <- function(ref) {
  r <- ref$reference
  list(model = ref$model$name, method = ref$method$est, category = r$category,
       stochastic = isTRUE(r$stochastic), threads = as.integer(r$threads),
       ofv = r$ofv, params = as.data.frame(r$params, stringsAsFactors = FALSE),
       shrink = as.data.frame(r$shrink, stringsAsFactors = FALSE),
       converged = isTRUE(r$converged), covMethod = r$covMethod)
}
```

**Env-robustness note (OpenMP instability):** multi-threaded fitting has intermittently crashed the OpenMP solver on the dev box. `rxClean()` at the start handles the model-cache-corruption mode. If a multi-threaded re-fit still crashes the R process in CI, wrap only that re-fit in an isolated child (`callr::r(function(ref) { library(nlmixr2qual); nlmixr2qual:::qual_reference_refit(ref) }, args=list(ref=ref))`), which needs `callr` in `Suggests` and the package installed. Keep the in-process version as default; add isolation only if a crash is observed (YAGNI).

- [x] **Step 4: Run to verify pass**

Run: `NLMIXR2QUAL_RUN_LIVE=1 Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-qualify.R")'`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add R/qualify.R tests/testthat/test-qualify.R
git commit -m "feat: qualify() engine -- re-fit each reference at its thread count, roll up verdict"
```

---

## Task 8: Generate the shipped theophylline reference set (t1 mandatory, t4 optional)

**Files:**
- Create: `data-raw/make-theophylline-references.R`
- Create: `inst/references/theophylline__*__t1.json` (mandatory) and `__t4.json` (optional, when built on ≥ 4 cores)
- Test: `tests/testthat/test-internal-references.R`

Ship a mandatory single-threaded (`t1`, strict, bit-portable) reference per method, and — only when the build box has ≥ 4 cores — an optional multi-threaded (`t4` = `qual_default_multi_threads()`, looser tolerance) reference. Tests must not require `t4` to exist.

- [x] **Step 1: Write the generator**

`data-raw/make-theophylline-references.R`:
```r
# Build the shipped internal reference set: theophylline across every method that
# produces a valid fit, at BOTH thread counts (1 and qual_default_multi_threads()).
# Each (method, threads) is fit + saved + imported as one thread-tagged reference.
# Run on a >=4-core normal filesystem: Rscript data-raw/make-theophylline-references.R
suppressMessages(rxode2::rxClean())
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressMessages(library(nlmixr2est)); library(nlmixr2data)

one.cmt <- function() {
  ini({ tka <- 0.45; tcl <- log(c(0, 2.7, 100)); tv <- 3.45
        eta.ka ~ 0.6; eta.cl ~ 0.3; eta.v ~ 0.1; add.sd <- 0.7 })
  model({ ka <- exp(tka + eta.ka); cl <- exp(tcl + eta.cl); v <- exp(tv + eta.v)
          linCmt() ~ add(add.sd) })
}

# Methods confirmed to fit theophylline in prior work. Stochastic ones
# (saem/fsaem/imp/impmap/qrpem) qualify as informational. Extend as coverage grows.
methods <- c("focei", "foce", "focep", "laplace", "agq",
             "saem", "fsaem", "imp", "impmap", "qrpem")
# t1 is always produced; t4 only when this box can run 4 cores natively (optional).
thread_counts <- c(1L)
if (parallel::detectCores() >= qual_default_multi_threads())
  thread_counts <- c(thread_counts, qual_default_multi_threads())

outdir <- "inst/references"; dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
tmp <- file.path(tempdir(), "theo-bundles"); dir.create(tmp, showWarnings = FALSE)

for (nthr in thread_counts) {
  for (m in methods) {
    message("fitting theophylline / ", m, " @ ", nthr, " thread(s)")
    rxode2::rxClean(); rxode2::setRxThreads(nthr)
    fit <- tryCatch(nlmixr2(one.cmt, theo_sd, est = m),
                    error = function(e) { message("  skip: ", conditionMessage(e)); NULL })
    if (is.null(fit)) next
    old <- setwd(tmp); base <- paste0("theophylline_", m, "_t", nthr)
    unlink(paste0(base, ".zip")); nlmixr2save::saveFit(fit, base, zip = TRUE)
    setwd(old)
    ref <- qual_import_bundle(file.path(tmp, paste0(base, ".zip")),
                              model_name = "theophylline", method = m, threads = nthr,
                              description = "1-compartment oral PK, theophylline")
    qual_reference_write(ref, file.path(outdir, paste0(ref$id, ".json")))
  }
}
cat("wrote references:\n"); print(list.files(outdir))
```

- [x] **Step 2: Generate the reference set**

Run: `Rscript data-raw/make-theophylline-references.R`
Expected: `inst/references/theophylline__focei__t1.json` per fitting method (mandatory), plus `theophylline__*__t4.json` when run on a ≥ 4-core box (optional).

- [x] **Step 3: Write the failing test**

```r
test_that("shipped internal references include the mandatory t1 set and validate", {
  refs <- qual_load_references("internal")
  expect_true("theophylline__focei__t1" %in% names(refs))    # t1 mandatory
  for (r in refs) expect_true(qual_reference_validate(r))
  # thread counts are always 1 (mandatory) or the optional default multi (t4)
  expect_true(all(vapply(refs, function(r) r$reference$threads, integer(1))
                  %in% c(1L, qual_default_multi_threads())))
})

test_that("internal references re-fit and match on this box (strict methods)", {
  skip_if_no_live()
  refs <- qual_load_references("internal")
  # only qualify references whose thread count this box can run natively; a t4
  # reference is optional and only reproduces on a >= 4-core machine.
  cap <- qual_invariance_threads()
  runnable <- names(refs)[vapply(refs, function(r) r$reference$threads,
                                 integer(1)) <= cap]
  res <- qualify(runnable, "internal")
  strict <- res$summary[res$summary$strict, ]
  expect_true(all(strict$pass),
              info = paste(strict$id[!strict$pass], collapse = ", "))
  expect_true(res$overall)
})
```

- [x] **Step 4: Run to verify pass**

Run: `NLMIXR2QUAL_RUN_LIVE=1 Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-internal-references.R")'`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add data-raw/make-theophylline-references.R inst/references tests/testthat/test-internal-references.R
git commit -m "feat: shipped theophylline reference set (t1 + t4) across fitting methods"
```

---

## Task 9: Reference-catalogue documentation

**Files:**
- Create: `R/catalogue.R`
- Test: `tests/testthat/test-catalogue.R`

- [x] **Step 1: Write the failing test**

```r
test_that("catalogue summarises references as a data frame", {
  refs <- qual_load_references("internal")
  cat_df <- qual_catalogue(refs)
  expect_true(all(c("id", "model", "method", "threads", "ofv", "stochastic",
                    "nlmixr2_version") %in% names(cat_df)))
  expect_equal(nrow(cat_df), length(refs))
})

test_that("catalogue renders a Markdown table", {
  refs <- qual_load_references("internal")
  md <- qual_catalogue_md(refs)
  expect_true(grepl("\\| id \\|", md))
})
```

- [x] **Step 2: Run to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-catalogue.R")'`
Expected: FAIL — `qual_catalogue` not found.

- [x] **Step 3: Implement `R/catalogue.R`**

```r
# catalogue.R -- document reference models/methods/results.

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Summarise references as a data frame
#' @param refs A named list of references.
#' @return A data frame with one row per reference.
#' @export
qual_catalogue <- function(refs) {
  do.call(rbind, lapply(refs, function(r) data.frame(
    id = r$id, model = r$model$name, method = r$method$est,
    threads = as.integer(r$reference$threads),
    description = r$model$description %||% "",
    ofv = r$reference$ofv,
    converged = isTRUE(r$reference$converged),
    stochastic = isTRUE(r$reference$stochastic),
    n_params = nrow(as.data.frame(r$reference$params)),
    nlmixr2_version = r$provenance$software$nlmixr2 %||% NA_character_,
    created = r$provenance$created %||% "",
    stringsAsFactors = FALSE)))
}

#' Render the reference catalogue as a Markdown table
#' @param refs A named list of references.
#' @return A length-1 character string of Markdown.
#' @export
qual_catalogue_md <- function(refs) {
  df <- qual_catalogue(refs)[, c("id", "model", "method", "threads", "ofv",
                                 "stochastic", "nlmixr2_version")]
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  body <- apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  paste(c(header, sep, body), collapse = "\n")
}
```

- [x] **Step 4: Run to verify pass**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-catalogue.R")'`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add R/catalogue.R tests/testthat/test-catalogue.R
git commit -m "feat: reference-catalogue documentation (data frame + Markdown)"
```

---

## Task 10: Qualification summary document

**Files:**
- Modify: `R/report.R` (add `qual_summary_text()` + `qual_summary_report()`)
- Rewrite: `inst/report/qualification.qmd`
- Test: `tests/testthat/test-summary-report.R`

- [x] **Step 1: Write the failing test**

```r
fake_result <- function(pass = TRUE, overall = TRUE, threads = 1L) {
  structure(list(
    summary = data.frame(
      id = sprintf("theophylline__focei__t%d", threads), model = "theophylline",
      method = "focei", threads = as.integer(threads), strict = TRUE,
      pass = pass, ofv_ref = 116.8, ofv_local = 116.8, stringsAsFactors = FALSE),
    details = list(), provenance = qual_provenance(), overall = overall),
    class = "nlmixr2qual_result")
}

test_that("summary report writes an HTML file from a result", {
  skip_if_not_installed("quarto")
  out <- tempfile(fileext = ".html")
  qual_summary_report(fake_result(), out)
  expect_true(file.exists(out))
})

test_that("plain-text verdict reports per-reference pass with thread count", {
  txt <- tempfile(fileext = ".txt")
  qual_summary_text(fake_result(threads = 4L), txt)
  body <- paste(readLines(txt), collapse = "\n")
  expect_match(body, "OVERALL: PASS")
  expect_match(body, "threads:4")
  expect_match(body, "PASS")
})

test_that("verdict shows FAIL when a strict reference fails", {
  txt <- tempfile(fileext = ".txt")
  qual_summary_text(fake_result(pass = FALSE, overall = FALSE), txt)
  expect_match(paste(readLines(txt), collapse = "\n"), "OVERALL: FAIL")
})
```

- [x] **Step 2: Run to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-summary-report.R")'`
Expected: FAIL — `qual_summary_text` not found.

- [x] **Step 3: Implement `qual_summary_text()` + `qual_summary_report()` in `R/report.R`**

```r
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
  qmd <- system.file("report", "qualification.qmd", package = "nlmixr2qual")
  rds <- tempfile(fileext = ".rds"); saveRDS(res, rds)
  quarto::quarto_render(qmd, output_file = basename(path),
                        execute_params = list(result_rds = rds), quiet = TRUE)
  file.rename(file.path(dirname(qmd), basename(path)), path)
  invisible(path)
}
```

- [x] **Step 4: Rewrite `inst/report/qualification.qmd`**

````markdown
---
title: "nlmixr2qual Qualification Summary"
format: html
params:
  result_rds: ""
---

```{r}
#| echo: false
res <- readRDS(params$result_rds)
knitr::kable(res$summary)
```

**`r if (isTRUE(res$overall)) "OVERALL: PASS" else "OVERALL: FAIL"`**

```{r}
#| echo: false
str(res$provenance)
```
````

- [x] **Step 5: Run to verify pass**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-summary-report.R")'`
Expected: PASS (HTML test skips if `quarto` not installed).

- [x] **Step 6: Commit**

```bash
git add R/report.R inst/report/qualification.qmd tests/testthat/test-summary-report.R
git commit -m "feat: qualification summary document (HTML + thread-aware text verdict)"
```

---

## Task 11: Top-level runner + README + docs

**Files:**
- Create: `run_qualification.R`
- Modify: `README.md`, `NEWS.md`; rename `docs/models-and-methods.md` → `docs/references.md`

- [x] **Step 1: Write `run_qualification.R`**

```r
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
```

- [x] **Step 2: Update README.md**

Replace the "how it works" section with: create references by importing a confirmed-good fit (`nlmixr2save::saveFit()` → `qual_import_bundle(zip, model_name, method, threads=…)`), ship/point-to a folder of JSON references, run `qualify()` / `Rscript run_qualification.R [folder]`. Document `which` (default `"all"`, or pairs/ids) and `source` (`"internal"` default, or a folder). Explain the thread model: each reference is thread-tagged and re-fit at that count; `t1` is mandatory and `tx` optional; the shipped set includes a `t1` reference (strict, bit-portable) per method and, where the build box supports it, an optional `t4` reference (default 4 cores, compared under the looser thread tolerance); orgs add their own references at any thread count by importing one bundle per count.

- [x] **Step 3: Rework docs/models-and-methods.md → docs/references.md**

```bash
git mv docs/models-and-methods.md docs/references.md
```
Rewrite to describe: the JSON reference schema (incl. `reference$threads`), the shipped theophylline set (mandatory `t1`, optional `t4`; from the catalogue table), that multi-threaded references are optional (a `t1`-only set is valid), how an org imports one bundle per thread count to create references at any thread count, and the thread-tolerance design (strict for `t1`, looser for `t>1`).

- [x] **Step 4: Verify the full runner end-to-end**

Run: `NLMIXR2QUAL_RUN_LIVE=1 Rscript run_qualification.R`
Expected: prints `OVERALL: PASS`, exit 0, writes `qualification_output/verdict.txt`.

- [x] **Step 5: Commit**

```bash
git add run_qualification.R README.md docs/references.md NEWS.md
git commit -m "feat: top-level qualification runner + docs for reference architecture"
```

---

## Task 12: Green R CMD check

**Files:**
- Modify: `.Rbuildignore`, `DESCRIPTION` as needed

- [x] **Step 1: Ignore data-raw + docs from the build**

Ensure `.Rbuildignore` contains `^data-raw$`, `^docs$`, `^run_qualification\.R$`, `^qualification_output$`.

- [x] **Step 2: Document + check**

Run:
```bash
Rscript -e 'devtools::document()'
Rscript -e 'res <- rcmdcheck::rcmdcheck(".", args=c("--no-manual","--as-cran"), error_on="never"); cat(sprintf("E=%d W=%d N=%d\n", length(res$errors), length(res$warnings), length(res$notes)))'
```
Expected: `E=0 W=0` (a benign CRAN-incoming `New submission`/version NOTE is acceptable). Fix any undocumented-export or NAMESPACE warnings.

- [x] **Step 3: Run the non-live test suite**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat")'`
Expected: all pass (live tests skip without `NLMIXR2QUAL_RUN_LIVE=1`).

- [x] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: green R CMD check for reference architecture"
```

---

## Self-Review (against the re-scoped spec)

**Spec coverage:**
- *References created by importing nlmixr2save objects, one JSON per pair* → Tasks 2, 4, 8.
- *Package runs references to compare local vs reference results (re-fit)* → Tasks 5, 7.
- *Some references shipped (theophylline), others org-internal* → Task 8 (internal) + `source=<folder>` (Task 6).
- *Default list includes theophylline saem, focei* → Task 8 ships both (and all other fitting methods).
- *Document references + comparisons* → Task 9 (catalogue) + Task 10 (summary with per-reference comparison detail).
- *Create a qualification summary document* → Task 10.
- *Users select which pairs; default "all"; flag internal (default) or a folder of JSON* → Tasks 6, 7 (`which`, `source`), Task 11 (runner arg).
- *Single- and multi-threaded functionality, results may differ* → thread-tagged references (Task 2), thread-pinned re-fit (Task 5), like-for-like compare with thread-keyed tolerance (Task 7). `t1` mandatory / `tx` optional: shipped set = mandatory `t1` (strict) per method plus optional `t4` (looser tolerance, default 4 cores) where the build box supports it (Task 8); tooling works with t1-only sets; orgs add other thread counts by importing one bundle each (Task 11). `qual_default_multi_threads()` = 4.

**Open items deferred (note in NEWS):**
- Imported org bundles may lack a pinned seed for stochastic methods; those references qualify under the stochastic tolerance and are reported informational (never gate). `.qual_build_control` currently rebuilds focei-family control only — extend per family as stochastic references are added.
- Nonparametric/ML methods (`npag`/`npb`/`advi`/`vae`) excluded from the shipped set pending confirmation their fingerprints extract cleanly.
- If a multi-threaded re-fit crashes the R process in CI, add the `callr` isolation shown in Task 7 (guarded, not pre-emptive).

**Type consistency check:** fingerprint fields (`ofv`, `params{name,ptype,estimate,se,rse}`, `shrink{name,stype,value}`, `converged`, `covMethod`, `stochastic`, `category`, `threads`) are used identically in `qual_import_bundle` (Task 4), `qual_reference_refit` (Task 5), `.qual_ref_fingerprint` (Task 7), matching the existing `qual_extract_fit`/`qual_compare` contract. `reference$threads` is written (Task 2/4), read (Task 5/7), and surfaced in catalogue (Task 9), summary (Task 10). Pair = `"<model>__<method>"` and id = `"<model>__<method>__t<threads>"` are produced by `qual_reference_id`/`qual_reference_pair` and consumed consistently by `qual_select` (Task 6), `qualify` (Task 7), and the generators (Tasks 4, 8).
