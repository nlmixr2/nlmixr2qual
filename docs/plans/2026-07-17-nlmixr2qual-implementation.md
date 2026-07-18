# nlmixr2qual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an R package that qualifies an nlmixr2 installation by re-fitting 20–30 real `nlmixr2lib` models against a shipped single-threaded canonical baseline and rendering a Quarto qualification report with a PASS/FAIL verdict.

**Architecture:** A data-driven registry declares each model (source, frozen dataset, primary method, tolerances, stochastic/deterministic flag, strict/informational). Pure machinery — extraction, comparison, verdict, provenance, version gate, thread-budget control — is unit-tested against synthetic fit fixtures so it needs no live fits. A runner glues registry → fit → extract → compare; a serial thread-invariance stage re-fits anchor models multi-threaded. testthat 3e drives the strict stage in parallel worker processes; a thread-budget controller keeps process-level and thread-level parallelism from colliding. A Quarto template renders the primary report; occamsqual-style plain-text verdict/summary are emitted for pipeline continuity.

**Tech Stack:** R (== 4.6.1), nlmixr2 / nlmixr2est / nlmixr2lib / nlmixr2data / rxode2, testthat 3e, withr, quarto/rmarkdown, ggplot2, jsonlite, qs2.

**Reference spec:** `docs/specs/2026-07-17-nlmixr2qual-design.md`

**Conventions used throughout:**
- A fit **fingerprint** is the normalized structure the comparator consumes:
  ```r
  list(
    model     = "PK_1cmt",              # registry name
    method    = "focei",                # est= method
    category  = "Linearized",           # nlmixr2AllEstType() category (display)
    stochastic = FALSE,                 # reproducibility axis (§6.3)
    threads   = 1L,                     # inner threads used for this fit
    ofv       = 123.45,                 # numeric objective function value
    params    = data.frame(             # one row per estimated parameter
                  name = character(),    #   parameter name (from parFixedDf rownames)
                  ptype = character(),   #   "theta" | "omega" | "sigma"
                  estimate = numeric(),
                  se = numeric(),        #   NA when covariance step absent
                  rse = numeric(),       #   percent RSE, NA when absent
                  stringsAsFactors = FALSE),
    shrink    = data.frame(             # one row per shrinkage entry
                  name = character(),    #   parameter/eta name
                  stype = character(),   #   "eta" | "eps"
                  value = numeric(),
                  stringsAsFactors = FALSE),
    converged = TRUE,                   # convergence/minimization success
    covMethod = "r,s"                   # covariance method string, "" if none
  )
  ```
- Baseline files: `inst/baseline/<model>__<method>.qs2` holding one fingerprint. Global `inst/baseline/provenance.json`.
- All thread settings flow through `qual_set_threads()` (Task 6). Nothing else calls `setRxThreads`/`setDTthreads`/`Sys.setenv`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `DESCRIPTION`, `NAMESPACE`, `LICENSE` | Package metadata |
| `R/fingerprint.R` | `qual_extract_fit()` — nlmixr2 fit → fingerprint |
| `R/tolerance.R` | `qual_tolerance()` — relative tolerance by quantity class + stochastic/invariance mode |
| `R/compare.R` | `qual_compare()` — fingerprint vs baseline → deviation table + per-model pass |
| `R/registry.R` | `qual_registry()`, `qual_registry_entry()` — read/validate model+method specs |
| `R/threads.R` | `qual_set_threads()`, `qual_thread_plan()` — the only thread setter |
| `R/provenance.R` | `qual_provenance()` — environment + thread provenance capture |
| `R/versiongate.R` | `qual_version_gate()` — installed vs qualified package versions |
| `R/fit.R` | `qual_fit_entry()` — load model + frozen data, fit, return fingerprint |
| `R/run.R` | `qual_run()` — orchestrate strict + invariance stages → results object |
| `R/capture.R` | `qual_capture_baseline()` — deliberate baseline recut |
| `R/verdict.R` | `qual_verdict()`, `qual_write_text()` — verdict + plain-text artifacts |
| `R/report.R` | `qual_report()` — assemble results, render Quarto |
| `R/data-io.R` | `qual_read_dataset()` — load a frozen dataset by ref |
| `inst/models/registry.csv` | The declarative model registry |
| `inst/models/methods.csv` | The method-coverage matrix (26 methods) |
| `inst/data/*.csv` | Permanently frozen datasets |
| `inst/baseline/*.qs2` + `provenance.json` | Canonical baseline |
| `inst/qualified_baseline.csv` | Package-version gate baseline |
| `inst/report/qualification.qmd` | Quarto template |
| `data-raw/simulate-datasets.R` | ONE-TIME provenance script (never re-run) |
| `tests/testthat/*` | testthat 3e suites |
| `run_qualification.R`, `qualify.bat` | Top-level entry points |

---

## Phase 0 — Package scaffold

### Task 0: Create the package skeleton

**Files:**
- Create: `nlmixr2qual/DESCRIPTION`
- Create: `nlmixr2qual/NAMESPACE`
- Create: `nlmixr2qual/LICENSE`
- Create: `nlmixr2qual/tests/testthat.R`
- Create: `nlmixr2qual/.Rbuildignore`

- [ ] **Step 1: Write `DESCRIPTION`**

```
Package: nlmixr2qual
Title: Qualification Suite for nlmixr2
Version: 0.0.0.9000
Authors@R:
    person("Justin", "Wilkins", , "justin.wilkins@occams.com", role = c("aut", "cre"))
Description: Reproducibility qualification of an nlmixr2 installation. Re-fits a
    curated set of nlmixr2lib models against a shipped single-threaded canonical
    baseline, checks parameter/OFV/SE reproduction within tolerance across all
    estimation methods, qualifies multi-threaded fitting by a thread-invariance
    check, and renders a Quarto qualification report with an overall PASS/FAIL
    verdict.
License: file LICENSE
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
Depends:
    R (== 4.6.1)
Imports:
    jsonlite,
    stats,
    utils
Suggests:
    nlmixr2,
    nlmixr2est,
    nlmixr2lib,
    nlmixr2data,
    rxode2,
    qs2,
    ggplot2,
    quarto,
    testthat (>= 3.0.0),
    withr
Config/testthat/edition: 3
Config/testthat/parallel: true
Config/roxygen2/version: 8.0.0
```

- [ ] **Step 2: Write `NAMESPACE`** (roxygen will regenerate; seed minimally)

```
# Generated by roxygen2: do not edit by hand
```

- [ ] **Step 3: Write `LICENSE`**

```
YEAR: 2026
COPYRIGHT HOLDER: Occams
```

- [ ] **Step 4: Write `tests/testthat.R`**

```r
library(testthat)
library(nlmixr2qual)

test_check("nlmixr2qual")
```

- [ ] **Step 5: Write `.Rbuildignore`**

```
^.*\.Rproj$
^\.Rproj\.user$
^docs$
^data-raw$
^run_qualification\.R$
^qualify\.bat$
^qualification_output$
```

- [ ] **Step 6: Verify the package loads**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); cat('OK\n')"`
Expected: `OK` (no errors; empty package is valid).

- [ ] **Step 7: Commit**

```bash
git add nlmixr2qual/DESCRIPTION nlmixr2qual/NAMESPACE nlmixr2qual/LICENSE nlmixr2qual/tests/testthat.R nlmixr2qual/.Rbuildignore
git commit -m "chore: scaffold nlmixr2qual package"
```

---

## Phase 1 — Fingerprint extraction (pure, TDD)

### Task 1: `qual_extract_fit()` — nlmixr2 fit → fingerprint

**Files:**
- Create: `nlmixr2qual/R/fingerprint.R`
- Test: `nlmixr2qual/tests/testthat/test-fingerprint.R`
- Create (fixture): `nlmixr2qual/tests/testthat/helper-fakefit.R`

- [ ] **Step 1: Write the fake-fit fixture helper**

The extractor must not require a live nlmixr2 fit. Build a minimal object that
carries the accessors `qual_extract_fit()` reads: `$objf`, `$parFixedDf`,
`$omega`, `$sigma`, `$shrink`, `$covMethod`, `$message`.

```r
# helper-fakefit.R
fake_fit <- function(objf = 100,
                     parFixedDf = data.frame(
                       Estimate = c(0.5, 1.0, 3.4),
                       SE = c(0.05, 0.1, 0.2),
                       `%RSE` = c(10, 10, 6),
                       row.names = c("lka", "lcl", "lvc"),
                       check.names = FALSE),
                     omega = matrix(c(0.09, 0, 0, 0.04), 2, 2,
                                    dimnames = list(c("eta.cl","eta.vc"),
                                                    c("eta.cl","eta.vc"))),
                     sigma = c(propSd = 0.5),
                     shrink = data.frame(
                       eta.cl = 12, eta.vc = 20, row.names = "IWRES(%)"),
                     covMethod = "r,s",
                     message = "") {
  structure(
    list(objf = objf, parFixedDf = parFixedDf, omega = omega,
         sigma = sigma, shrink = shrink, covMethod = covMethod,
         message = message),
    class = "fakeNlmixrFit")
}

`$.fakeNlmixrFit` <- function(x, name) x[[name]]
```

- [ ] **Step 2: Write the failing test**

```r
# test-fingerprint.R
test_that("qual_extract_fit produces a normalized fingerprint", {
  fit <- fake_fit()
  fp <- qual_extract_fit(fit, model = "PK_1cmt", method = "focei",
                         category = "Linearized", stochastic = FALSE,
                         threads = 1L)

  expect_identical(fp$model, "PK_1cmt")
  expect_identical(fp$method, "focei")
  expect_identical(fp$threads, 1L)
  expect_equal(fp$ofv, 100)
  expect_true(fp$converged)

  # thetas from parFixedDf
  thetas <- fp$params[fp$params$ptype == "theta", ]
  expect_equal(nrow(thetas), 3)
  expect_equal(thetas$estimate[thetas$name == "lcl"], 1.0)
  expect_equal(thetas$se[thetas$name == "lcl"], 0.1)

  # omega diagonal captured as ptype "omega"
  omegas <- fp$params[fp$params$ptype == "omega", ]
  expect_equal(omegas$estimate[omegas$name == "eta.cl"], 0.09)

  # sigma captured
  sigmas <- fp$params[fp$params$ptype == "sigma", ]
  expect_equal(sigmas$estimate[sigmas$name == "propSd"], 0.5)

  # shrinkage
  expect_equal(fp$shrink$value[fp$shrink$name == "eta.cl"], 12)
})

test_that("empty covariance step yields NA SEs and covMethod ''", {
  fit <- fake_fit(parFixedDf = data.frame(
                    Estimate = 1.0, SE = NA_real_, `%RSE` = NA_real_,
                    row.names = "lcl", check.names = FALSE),
                  covMethod = "")
  fp <- qual_extract_fit(fit, "M", "nlminb", "Optimizer (NLM family)",
                         stochastic = FALSE, threads = 1L)
  expect_true(is.na(fp$params$se[1]))
  expect_identical(fp$covMethod, "")
})

test_that("non-empty message marks non-convergence", {
  fit <- fake_fit(message = "gradient failure")
  fp <- qual_extract_fit(fit, "M", "focei", "Linearized",
                         stochastic = FALSE, threads = 1L)
  expect_false(fp$converged)
})
```

- [ ] **Step 3: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-fingerprint.R')"`
Expected: FAIL — `could not find function "qual_extract_fit"`.

- [ ] **Step 4: Implement `qual_extract_fit()`**

```r
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-fingerprint.R')"`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add nlmixr2qual/R/fingerprint.R nlmixr2qual/tests/testthat/test-fingerprint.R nlmixr2qual/tests/testthat/helper-fakefit.R
git commit -m "feat: fit fingerprint extraction"
```

---

## Phase 2 — Tolerance policy (pure, TDD)

### Task 2: `qual_tolerance()`

**Files:**
- Create: `nlmixr2qual/R/tolerance.R`
- Test: `nlmixr2qual/tests/testthat/test-tolerance.R`

- [ ] **Step 1: Write the failing test**

```r
# test-tolerance.R
test_that("deterministic tolerances follow spec 6.4 defaults", {
  expect_equal(qual_tolerance("ofv",   stochastic = FALSE), 1e-3)
  expect_equal(qual_tolerance("theta", stochastic = FALSE), 1e-3)
  expect_equal(qual_tolerance("omega", stochastic = FALSE), 1e-3)
  expect_equal(qual_tolerance("sigma", stochastic = FALSE), 1e-3)
  expect_equal(qual_tolerance("se",    stochastic = FALSE), 0.05)
  expect_equal(qual_tolerance("rse",   stochastic = FALSE), 0.05)
  expect_equal(qual_tolerance("shrink",stochastic = FALSE), 0.05)
})

test_that("stochastic tolerances are looser", {
  expect_equal(qual_tolerance("ofv",   stochastic = TRUE), 1e-2)
  expect_equal(qual_tolerance("se",    stochastic = TRUE), 0.10)
})

test_that("invariance mode overrides to the thread-invariance tolerance", {
  expect_equal(qual_tolerance("theta", stochastic = FALSE, invariance = TRUE), 1e-2)
})

test_that("explicit override wins", {
  expect_equal(qual_tolerance("theta", stochastic = FALSE, override = 5e-4), 5e-4)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-tolerance.R')"`
Expected: FAIL — `could not find function "qual_tolerance"`.

- [ ] **Step 3: Implement `qual_tolerance()`**

```r
# tolerance.R

.qual_tol_defaults <- list(
  deterministic = c(ofv = 1e-3, theta = 1e-3, omega = 1e-3, sigma = 1e-3,
                    se = 0.05, rse = 0.05, shrink = 0.05),
  stochastic    = c(ofv = 1e-2, theta = 1e-2, omega = 1e-2, sigma = 1e-2,
                    se = 0.10, rse = 0.10, shrink = 0.10)
)
.qual_tol_invariance <- 1e-2

#' Relative tolerance for a quantity class
#'
#' @param class One of "ofv","theta","omega","sigma","se","rse","shrink".
#' @param stochastic Logical; use the looser stochastic defaults.
#' @param invariance Logical; use the thread-invariance tolerance instead.
#' @param override Optional explicit numeric tolerance (wins if supplied).
#' @return A single numeric relative tolerance.
#' @export
qual_tolerance <- function(class, stochastic = FALSE, invariance = FALSE,
                           override = NULL) {
  if (!is.null(override)) return(as.numeric(override))
  if (isTRUE(invariance)) return(.qual_tol_invariance)
  tab <- if (isTRUE(stochastic)) .qual_tol_defaults$stochastic
         else .qual_tol_defaults$deterministic
  stopifnot(class %in% names(tab))
  unname(tab[[class]])
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-tolerance.R')"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add nlmixr2qual/R/tolerance.R nlmixr2qual/tests/testthat/test-tolerance.R
git commit -m "feat: quantity-class tolerance policy"
```

---

## Phase 3 — Comparator (pure, TDD)

### Task 3: `qual_compare()` — fingerprint vs baseline

**Files:**
- Create: `nlmixr2qual/R/compare.R`
- Test: `nlmixr2qual/tests/testthat/test-compare.R`

- [ ] **Step 1: Write the failing test**

```r
# test-compare.R
test_that("identical fingerprints pass on every quantity", {
  fp <- qual_extract_fit(fake_fit(), "PK_1cmt", "focei", "Linearized",
                         stochastic = FALSE, threads = 1L)
  cmp <- qual_compare(fp, fp)
  expect_true(cmp$pass)
  expect_true(all(cmp$detail$pass))
  expect_true("ofv" %in% cmp$detail$quantity)
})

test_that("a theta beyond tolerance fails that quantity and the model", {
  base <- qual_extract_fit(fake_fit(), "PK_1cmt", "focei", "Linearized",
                           stochastic = FALSE, threads = 1L)
  drift <- fake_fit()
  drift$parFixedDf$Estimate[2] <- 1.0 * (1 + 5e-3)  # lcl +0.5%, tol 1e-3
  run <- qual_extract_fit(drift, "PK_1cmt", "focei", "Linearized",
                          stochastic = FALSE, threads = 1L)
  cmp <- qual_compare(run, base)
  expect_false(cmp$pass)
  bad <- cmp$detail[cmp$detail$quantity == "theta:lcl", ]
  expect_false(bad$pass)
  expect_gt(bad$reldiff, 1e-3)
})

test_that("convergence mismatch fails regardless of numbers", {
  base <- qual_extract_fit(fake_fit(), "M", "focei", "Linearized", FALSE, 1L)
  run  <- qual_extract_fit(fake_fit(message = "boundary"), "M", "focei",
                           "Linearized", FALSE, 1L)
  cmp <- qual_compare(run, base)
  expect_false(cmp$pass)
  expect_false(cmp$detail$pass[cmp$detail$quantity == "converged"])
})

test_that("invariance mode applies the looser tolerance", {
  base <- qual_extract_fit(fake_fit(), "M", "focei", "Linearized", FALSE, 1L)
  drift <- fake_fit(); drift$parFixedDf$Estimate[2] <- 1.0 * (1 + 5e-3)
  run <- qual_extract_fit(drift, "M", "focei", "Linearized", FALSE, threads = 4L)
  expect_true(qual_compare(run, base, invariance = TRUE)$pass)   # 5e-3 < 1e-2
  expect_false(qual_compare(run, base, invariance = FALSE)$pass) # 5e-3 > 1e-3
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-compare.R')"`
Expected: FAIL — `could not find function "qual_compare"`.

- [ ] **Step 3: Implement `qual_compare()`**

```r
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

  # params matched by (ptype,name); missing on either side -> Inf reldiff
  keyed <- function(fp) setNames(seq_len(nrow(fp$params)),
                                 paste0(fp$params$ptype, ":", fp$params$name))
  bk <- keyed(base); rk <- keyed(run)
  for (k in union(names(bk), names(rk))) {
    ptype <- sub(":.*$", "", k)
    b <- if (k %in% names(bk)) base$params$estimate[bk[[k]]] else NA_real_
    o <- if (k %in% names(rk)) run$params$estimate[rk[[k]]] else NA_real_
    add(k, ptype, b, o)
    # SE row (only where baseline has one)
    if (k %in% names(bk) && !is.na(base$params$se[bk[[k]]])) {
      ose <- if (k %in% names(rk)) run$params$se[rk[[k]]] else NA_real_
      add(paste0("se:", k), "se", base$params$se[bk[[k]]], ose)
    }
  }

  # shrinkage matched by name
  bs <- setNames(base$shrink$value, base$shrink$name)
  rs <- setNames(run$shrink$value, run$shrink$name)
  for (nm in union(names(bs), names(rs))) {
    add(paste0("shrink:", nm), "shrink",
        if (nm %in% names(bs)) bs[[nm]] else NA_real_,
        if (nm %in% names(rs)) rs[[nm]] else NA_real_)
  }

  detail <- do.call(rbind, rows)
  # convergence is an exact-match quantity
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-compare.R')"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add nlmixr2qual/R/compare.R nlmixr2qual/tests/testthat/test-compare.R
git commit -m "feat: baseline comparator with per-quantity tolerances"
```

---

## Phase 4 — Registry (TDD)

### Task 4: `qual_registry()` — model + method specs

**Files:**
- Create: `nlmixr2qual/R/registry.R`
- Create: `nlmixr2qual/inst/models/registry.csv` (seed with 2 rows for the test)
- Create: `nlmixr2qual/inst/models/methods.csv` (seed with 2 rows for the test)
- Test: `nlmixr2qual/tests/testthat/test-registry.R`

- [ ] **Step 1: Seed `inst/models/registry.csv`**

```
name,source,dataset,domain,method,stochastic,strict,anchor,tol_override
PK_1cmt,lib,PK_1cmt_sim.csv,popPK,focei,FALSE,TRUE,TRUE,
PK_2cmt,lib,PK_2cmt_sim.csv,popPK,focei,FALSE,TRUE,TRUE,
```

- [ ] **Step 2: Seed `inst/models/methods.csv`**

```
method,category,stochastic,strict,needs_reff
focei,Linearized,FALSE,TRUE,TRUE
nlminb,Optimizer (NLM family),FALSE,TRUE,FALSE
```

- [ ] **Step 3: Write the failing test**

```r
# test-registry.R
test_that("qual_registry reads and validates model rows", {
  reg <- qual_registry()
  expect_s3_class(reg, "data.frame")
  expect_true(all(c("name","source","dataset","domain","method",
                    "stochastic","strict","anchor") %in% names(reg)))
  expect_type(reg$stochastic, "logical")
  expect_type(reg$strict, "logical")
  expect_true("PK_1cmt" %in% reg$name)
})

test_that("qual_methods reads the 26-method matrix schema", {
  m <- qual_methods()
  expect_true(all(c("method","category","stochastic","strict","needs_reff")
                  %in% names(m)))
  expect_type(m$needs_reff, "logical")
})

test_that("duplicate model names are rejected", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("name,source,dataset,domain,method,stochastic,strict,anchor,tol_override",
               "M,lib,d.csv,popPK,focei,FALSE,TRUE,FALSE,",
               "M,lib,d.csv,popPK,saem,TRUE,TRUE,FALSE,"), tmp)
  expect_error(qual_registry(path = tmp), "duplicate")
})
```

- [ ] **Step 4: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-registry.R')"`
Expected: FAIL — `could not find function "qual_registry"`.

- [ ] **Step 5: Implement `registry.R`**

```r
# registry.R

.qual_pkg_file <- function(...) {
  f <- system.file(..., package = "nlmixr2qual")
  if (nzchar(f)) return(f)
  # pkgload::load_all dev path
  file.path("inst", ...)
}

#' Read and validate the model registry
#' @param path Optional explicit path to the registry CSV.
#' @return A validated data frame, one row per qualified model.
#' @export
qual_registry <- function(path = .qual_pkg_file("models", "registry.csv")) {
  reg <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
  req <- c("name","source","dataset","domain","method","stochastic",
           "strict","anchor","tol_override")
  miss <- setdiff(req, names(reg))
  if (length(miss)) stop("registry missing columns: ", paste(miss, collapse = ", "))
  if (anyDuplicated(reg$name)) stop("duplicate model name(s) in registry")
  reg$stochastic <- as.logical(reg$stochastic)
  reg$strict     <- as.logical(reg$strict)
  reg$anchor     <- as.logical(reg$anchor)
  reg
}

#' Read and validate the method-coverage matrix
#' @param path Optional explicit path to the methods CSV.
#' @return A validated data frame, one row per estimation method.
#' @export
qual_methods <- function(path = .qual_pkg_file("models", "methods.csv")) {
  m <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
  req <- c("method","category","stochastic","strict","needs_reff")
  miss <- setdiff(req, names(m))
  if (length(miss)) stop("methods missing columns: ", paste(miss, collapse = ", "))
  m$stochastic <- as.logical(m$stochastic)
  m$strict     <- as.logical(m$strict)
  m$needs_reff  <- as.logical(m$needs_reff)
  m
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-registry.R')"`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add nlmixr2qual/R/registry.R nlmixr2qual/inst/models/registry.csv nlmixr2qual/inst/models/methods.csv nlmixr2qual/tests/testthat/test-registry.R
git commit -m "feat: model + method registry with validation"
```

---

## Phase 5 — Thread-budget controller (TDD)

### Task 5: `qual_thread_plan()` and `qual_set_threads()`

**Files:**
- Create: `nlmixr2qual/R/threads.R`
- Test: `nlmixr2qual/tests/testthat/test-threads.R`

- [ ] **Step 1: Write the failing test**

`qual_thread_plan()` is pure arithmetic (testable without rxode2).
`qual_set_threads()` applies it; test only its recorded effect on env + a stub.

```r
# test-threads.R
test_that("thread plan never oversubscribes cores", {
  expect_equal(qual_thread_plan(cores = 8, workers = 8, mode = "single")$inner, 1)
  expect_equal(qual_thread_plan(cores = 8, workers = 1, mode = "multi")$inner, 8)
  expect_equal(qual_thread_plan(cores = 8, workers = 4, mode = "multi")$inner, 2)
  # workers exceeding cores still yields >=1 inner thread
  expect_equal(qual_thread_plan(cores = 4, workers = 8, mode = "single")$inner, 1)
})

test_that("qual_set_threads writes the env var and OMP/MKL vars", {
  withr::local_envvar(c(NLMIXR2QUAL_INNER_THREADS = NA,
                        OMP_NUM_THREADS = NA, MKL_NUM_THREADS = NA))
  qual_set_threads(inner = 3L, apply_rx = FALSE)
  expect_identical(Sys.getenv("NLMIXR2QUAL_INNER_THREADS"), "3")
  expect_identical(Sys.getenv("OMP_NUM_THREADS"), "3")
  expect_identical(Sys.getenv("MKL_NUM_THREADS"), "3")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-threads.R')"`
Expected: FAIL — `could not find function "qual_thread_plan"`.

- [ ] **Step 3: Implement `threads.R`**

```r
# threads.R

#' Compute an inner-thread count that does not oversubscribe cores
#'
#' @param cores Available cores.
#' @param workers Number of outer (testthat) worker processes.
#' @param mode "single" (inner = 1) or "multi" (share cores across workers).
#' @return `list(cores, workers, mode, inner)`.
#' @export
qual_thread_plan <- function(cores = parallel::detectCores(),
                             workers = 1L, mode = c("single", "multi")) {
  mode <- match.arg(mode)
  inner <- if (mode == "single") 1L else max(1L, cores %/% max(1L, workers))
  list(cores = as.integer(cores), workers = as.integer(workers),
       mode = mode, inner = as.integer(inner))
}

#' Apply the inner-thread count to every thread control (the ONLY setter)
#'
#' Sets `NLMIXR2QUAL_INNER_THREADS`, `OMP_NUM_THREADS`, `MKL_NUM_THREADS`, and
#' (when `apply_rx`) `rxode2::setRxThreads()` + `data.table::setDTthreads()`.
#' @param inner Integer inner-thread count.
#' @param apply_rx Logical; call rxode2/data.table setters (FALSE in unit tests).
#' @return Invisibly, the applied inner count.
#' @export
qual_set_threads <- function(inner, apply_rx = TRUE) {
  inner <- as.integer(inner)
  Sys.setenv(NLMIXR2QUAL_INNER_THREADS = as.character(inner),
             OMP_NUM_THREADS = as.character(inner),
             MKL_NUM_THREADS = as.character(inner))
  if (isTRUE(apply_rx)) {
    if (requireNamespace("rxode2", quietly = TRUE)) rxode2::setRxThreads(inner)
    if (requireNamespace("data.table", quietly = TRUE)) data.table::setDTthreads(inner)
  }
  invisible(inner)
}

#' Read the inner-thread count a worker should use
#' @return Integer inner-thread count (default 1 if unset).
#' @export
qual_inner_threads <- function() {
  v <- Sys.getenv("NLMIXR2QUAL_INNER_THREADS", "1")
  max(1L, as.integer(v))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-threads.R')"`
Expected: PASS (2 tests).

- [ ] **Step 5: Add the testthat worker setup helper**

Create `nlmixr2qual/tests/testthat/setup.R`:

```r
# Every parallel worker pins its inner-thread count from the runner's env var,
# so process-level (worker) and thread-level (rx) parallelism never multiply.
qual_set_threads(qual_inner_threads())
```

- [ ] **Step 6: Commit**

```bash
git add nlmixr2qual/R/threads.R nlmixr2qual/tests/testthat/test-threads.R nlmixr2qual/tests/testthat/setup.R
git commit -m "feat: thread-budget controller and worker setup"
```

---

## Phase 6 — Provenance + version gate (TDD)

### Task 6: `qual_provenance()`

**Files:**
- Create: `nlmixr2qual/R/provenance.R`
- Test: `nlmixr2qual/tests/testthat/test-provenance.R`

- [ ] **Step 1: Write the failing test**

```r
# test-provenance.R
test_that("provenance captures environment and thread config", {
  p <- qual_provenance(inner_threads = 1L, workers = 4L)
  expect_true(all(c("os","arch","r_version","blas","lapack","compiler",
                    "inner_threads","workers","nlmixr2") %in% names(p)))
  expect_equal(p$inner_threads, 1L)
  expect_equal(p$workers, 4L)
})

test_that("provenance round-trips through json", {
  p <- qual_provenance(inner_threads = 2L, workers = 1L)
  f <- withr::local_tempfile(fileext = ".json")
  qual_write_provenance(p, f)
  q <- qual_read_provenance(f)
  expect_equal(q$inner_threads, 2L)
  expect_equal(q$os, p$os)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-provenance.R')"`
Expected: FAIL — `could not find function "qual_provenance"`.

- [ ] **Step 3: Implement `provenance.R`**

```r
# provenance.R

#' Capture environment + thread provenance
#' @param inner_threads,workers Integers recorded verbatim.
#' @return A named list of provenance fields.
#' @export
qual_provenance <- function(inner_threads = qual_inner_threads(), workers = 1L) {
  si <- utils::sessionInfo()
  bl <- si$BLAS; if (is.null(bl)) bl <- ""
  la <- si$LAPACK; if (is.null(la)) la <- ""
  nlv <- tryCatch(as.character(utils::packageVersion("nlmixr2")),
                  error = function(e) NA_character_)
  list(
    os = utils::sessionInfo()$running %||% Sys.info()[["sysname"]],
    arch = R.version$arch,
    r_version = R.version.string,
    blas = bl,
    lapack = la,
    compiler = R.version$`system` ,
    inner_threads = as.integer(inner_threads),
    workers = as.integer(workers),
    nlmixr2 = nlv,
    captured = as.character(Sys.time())
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' @rdname qual_provenance
#' @param p A provenance list. @param path Output path.
#' @export
qual_write_provenance <- function(p, path) {
  jsonlite::write_json(p, path, auto_unbox = TRUE, pretty = TRUE)
  invisible(path)
}

#' @rdname qual_provenance
#' @export
qual_read_provenance <- function(path) {
  p <- jsonlite::read_json(path, simplifyVector = TRUE)
  p$inner_threads <- as.integer(p$inner_threads)
  p$workers <- as.integer(p$workers)
  p
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-provenance.R')"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add nlmixr2qual/R/provenance.R nlmixr2qual/tests/testthat/test-provenance.R
git commit -m "feat: environment and thread provenance capture"
```

### Task 7: `qual_version_gate()`

**Files:**
- Create: `nlmixr2qual/R/versiongate.R`
- Create: `nlmixr2qual/inst/qualified_baseline.csv` (seed)
- Test: `nlmixr2qual/tests/testthat/test-versiongate.R`

- [ ] **Step 1: Seed `inst/qualified_baseline.csv`**

```
package,version
nlmixr2,3.0.0
nlmixr2est,3.0.0
rxode2,3.0.0
```

- [ ] **Step 2: Write the failing test**

```r
# test-versiongate.R
test_that("version gate flags mismatches and missing packages", {
  base <- data.frame(package = c("A","B","C"),
                     version = c("1.0","2.0","3.0"), stringsAsFactors = FALSE)
  installed <- c(A = "1.0", B = "2.1")  # B differs, C missing
  g <- qual_version_gate(base, installed = installed)
  expect_false(g$pass)
  expect_true(g$detail$pass[g$detail$package == "A"])
  expect_false(g$detail$pass[g$detail$package == "B"])
  expect_equal(g$detail$status[g$detail$package == "C"], "missing")
})

test_that("all matching versions pass", {
  base <- data.frame(package = "A", version = "1.0", stringsAsFactors = FALSE)
  expect_true(qual_version_gate(base, installed = c(A = "1.0"))$pass)
})
```

- [ ] **Step 3: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-versiongate.R')"`
Expected: FAIL — `could not find function "qual_version_gate"`.

- [ ] **Step 4: Implement `versiongate.R`**

```r
# versiongate.R

#' Compare installed package versions against the qualified baseline
#' @param baseline Data frame with columns package, version.
#' @param installed Optional named character vector (pkg -> version); by default
#'   queried live from the session.
#' @return `list(pass, detail)`; detail has package, expected, observed, status, pass.
#' @export
qual_version_gate <- function(baseline = utils::read.csv(
                                .qual_pkg_file("qualified_baseline.csv"),
                                stringsAsFactors = FALSE),
                              installed = NULL) {
  get_v <- function(pkg) {
    if (!is.null(installed)) return(if (pkg %in% names(installed)) installed[[pkg]] else NA_character_)
    tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
  }
  rows <- lapply(seq_len(nrow(baseline)), function(i) {
    pkg <- baseline$package[i]; exp <- baseline$version[i]; obs <- get_v(pkg)
    status <- if (is.na(obs)) "missing" else if (identical(obs, exp)) "match" else "mismatch"
    data.frame(package = pkg, expected = exp, observed = obs,
               status = status, pass = status == "match", stringsAsFactors = FALSE)
  })
  detail <- do.call(rbind, rows)
  list(pass = all(detail$pass), detail = detail)
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-versiongate.R')"`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add nlmixr2qual/R/versiongate.R nlmixr2qual/inst/qualified_baseline.csv nlmixr2qual/tests/testthat/test-versiongate.R
git commit -m "feat: package version gate"
```

---

## Phase 7 — Verdict + plain-text artifacts (TDD)

### Task 8: `qual_verdict()` and `qual_write_text()`

**Files:**
- Create: `nlmixr2qual/R/verdict.R`
- Test: `nlmixr2qual/tests/testthat/test-verdict.R`

- [ ] **Step 1: Write the failing test**

```r
# test-verdict.R
make_result <- function(model, method, pass, strict) {
  list(model = model, method = method, pass = pass, strict = strict,
       detail = data.frame())
}

test_that("verdict is PASS only if every strict result passes", {
  res <- list(make_result("A","focei", TRUE, TRUE),
              make_result("B","saem",  FALSE, FALSE),  # informational fail: ignored
              make_result("C","nlminb",TRUE, TRUE))
  v <- qual_verdict(res, version_gate = list(pass = TRUE))
  expect_equal(v$verdict, "PASS")
})

test_that("a strict failure forces FAIL", {
  res <- list(make_result("A","focei", FALSE, TRUE))
  v <- qual_verdict(res, version_gate = list(pass = TRUE))
  expect_equal(v$verdict, "FAIL")
})

test_that("version gate failure forces FAIL", {
  res <- list(make_result("A","focei", TRUE, TRUE))
  v <- qual_verdict(res, version_gate = list(pass = FALSE))
  expect_equal(v$verdict, "FAIL")
})

test_that("qual_write_text emits verdict and summary files", {
  d <- withr::local_tempdir()
  res <- list(make_result("A","focei", TRUE, TRUE))
  v <- qual_verdict(res, version_gate = list(pass = TRUE))
  qual_write_text(v, res, dir = d)
  expect_identical(readLines(file.path(d, "qualification_verdict.txt")), "PASS")
  expect_true(any(grepl("OVERALL: PASS",
                        readLines(file.path(d, "qualification_summary.txt")))))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-verdict.R')"`
Expected: FAIL — `could not find function "qual_verdict"`.

- [ ] **Step 3: Implement `verdict.R`**

```r
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
#' @param v The [qual_verdict()] result. @param results Result records.
#' @param dir Output directory.
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-verdict.R')"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add nlmixr2qual/R/verdict.R nlmixr2qual/tests/testthat/test-verdict.R
git commit -m "feat: overall verdict and plain-text artifacts"
```

---

## Phase 8 — Fit driver + one real integration (live nlmixr2)

### Task 9: `qual_read_dataset()` and the frozen dataset for the anchor model

**Files:**
- Create: `nlmixr2qual/R/data-io.R`
- Create: `nlmixr2qual/data-raw/simulate-datasets.R` (provenance-only)
- Create: `nlmixr2qual/inst/data/PK_1cmt_sim.csv` (generated once by the script)
- Test: `nlmixr2qual/tests/testthat/test-data-io.R`

- [ ] **Step 1: Write the one-time simulation script**

This runs ONCE to produce the frozen CSV, then is never executed by any workflow.

```r
# data-raw/simulate-datasets.R  (provenance only; do not re-run in CI)
library(nlmixr2); library(nlmixr2lib); library(rxode2)
set.seed(20260717)
rxode2::setRxThreads(1L)
mod <- readModelDb("PK_1cmt")
ev <- et(amt = 100, ii = 24, until = 96) |> et(seq(0, 120, by = 4))
ev <- do.call(rbind, lapply(1:30, function(id) { e <- ev; e$id <- id; e }))
sim <- rxSolve(mod, ev, nSub = 30)
df <- as.data.frame(sim)[, c("id","time","Cc")]
names(df) <- c("ID","TIME","DV")
df$AMT <- 0; df$EVID <- 0
# dosing rows
dose <- data.frame(ID = 1:30, TIME = 0, DV = NA, AMT = 100, EVID = 1)
out <- rbind(dose, df)
out <- out[order(out$ID, out$TIME, -out$EVID), ]
write.csv(out, "inst/data/PK_1cmt_sim.csv", row.names = FALSE)
```

- [ ] **Step 2: Generate the dataset once**

Run: `cd nlmixr2qual && Rscript data-raw/simulate-datasets.R`
Expected: `inst/data/PK_1cmt_sim.csv` created, non-empty, with columns ID,TIME,DV,AMT,EVID.
Commit the CSV now; it is henceforth immutable.

- [ ] **Step 3: Write the failing test**

```r
# test-data-io.R
test_that("qual_read_dataset loads a frozen dataset by ref", {
  d <- qual_read_dataset("PK_1cmt_sim.csv")
  expect_s3_class(d, "data.frame")
  expect_true(all(c("ID","TIME","DV","AMT","EVID") %in% names(d)))
  expect_gt(nrow(d), 0)
})

test_that("missing dataset errors clearly", {
  expect_error(qual_read_dataset("nope.csv"), "not found")
})
```

- [ ] **Step 4: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-data-io.R')"`
Expected: FAIL — `could not find function "qual_read_dataset"`.

- [ ] **Step 5: Implement `data-io.R`**

```r
# data-io.R

#' Load a frozen dataset by file reference
#' @param ref The dataset file name under inst/data/ (or an absolute path).
#' @return A data frame.
#' @export
qual_read_dataset <- function(ref) {
  path <- if (file.exists(ref)) ref else .qual_pkg_file("data", ref)
  if (!file.exists(path)) stop("dataset not found: ", ref)
  utils::read.csv(path, stringsAsFactors = FALSE)
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-data-io.R')"`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add nlmixr2qual/R/data-io.R nlmixr2qual/data-raw/simulate-datasets.R nlmixr2qual/inst/data/PK_1cmt_sim.csv nlmixr2qual/tests/testthat/test-data-io.R
git commit -m "feat: frozen dataset loader + PK_1cmt frozen data"
```

### Task 10: `qual_fit_entry()` — load model, fit, fingerprint (live)

**Files:**
- Create: `nlmixr2qual/R/fit.R`
- Test: `nlmixr2qual/tests/testthat/test-fit-live.R`

This test is **skipped unless nlmixr2 is installed** (it runs a real fit).

- [ ] **Step 1: Write the failing test (skips without nlmixr2)**

```r
# test-fit-live.R
test_that("qual_fit_entry fits an augmented population model and returns a fingerprint", {
  skip_if_not_installed("nlmixr2")
  skip_if_not_installed("nlmixr2lib")
  qual_set_threads(1L)
  entry <- list(name = "PK_1cmt", source = "lib", dataset = "PK_1cmt_sim.csv",
                method = "focei", stochastic = FALSE, eta = "lcl,lvc")
  fp <- qual_fit_entry(entry, category = "Linearized")
  expect_identical(fp$model, "PK_1cmt")
  expect_identical(fp$method, "focei")
  expect_true(is.finite(fp$ofv))
  expect_true(any(fp$params$ptype == "theta"))
  # augmentation added IIV, so there must be at least one omega
  expect_true(any(fp$params$ptype == "omega"))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-fit-live.R')"`
Expected: FAIL — `could not find function "qual_fit_entry"` (or SKIP if nlmixr2 absent — then temporarily install to validate before proceeding).

- [ ] **Step 3: Implement `fit.R`**

```r
# fit.R

#' Prepare a model: load it and augment with IIV per the registry `eta` spec
#'
#' The SINGLE source of model augmentation (spec 3.0 / D9). Simulation, fitting,
#' and baseline capture all call this so they use an identical model.
#' @param entry A registry row as a list (name, source, eta).
#' @return An nlmixr2/rxode2 UI model, augmented with random effects if `eta` set.
#' @export
qual_prepare_model <- function(entry) {
  model <- switch(entry$source,
    lib  = nlmixr2lib::readModelDb(entry$name),
    file = eval(parse(file = .qual_pkg_file("models", paste0(entry$name, ".R")))),
    stop("unknown model source: ", entry$source))
  eta <- entry$eta
  if (!is.null(eta) && !is.na(eta) && nzchar(trimws(eta))) {
    params <- trimws(strsplit(eta, ",")[[1]])
    model <- nlmixr2lib::addEta(model, params)
  }
  model
}

#' Load a model, attach its frozen data, fit, and return a fingerprint
#' @param entry A registry row as a list (name, source, dataset, method, stochastic, eta).
#' @param category The method's display category (from qual_methods()).
#' @param threads Inner-thread count (defaults to the controller's current value).
#' @return A fingerprint (see [qual_extract_fit()]).
#' @export
qual_fit_entry <- function(entry, category, threads = qual_inner_threads()) {
  stopifnot(requireNamespace("nlmixr2", quietly = TRUE))
  model <- qual_prepare_model(entry)
  data <- qual_read_dataset(entry$dataset)
  fit <- nlmixr2est::nlmixr2(model, data, est = entry$method)  # nlmixr2() lives in nlmixr2est
  qual_extract_fit(fit, model = entry$name, method = entry$method,
                   category = category, stochastic = entry$stochastic,
                   threads = threads)
}
```

Note: `qual_prepare_model()` also handles `source = "file"` (used by the
no-random-effect optimizer anchor in Task 15), so the Task 17 `switch` extension
is already covered here — do not duplicate it.

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-fit-live.R')"`
Expected: PASS (or SKIP if nlmixr2 not installed on the dev box).

- [ ] **Step 5: Commit**

```bash
git add nlmixr2qual/R/fit.R nlmixr2qual/tests/testthat/test-fit-live.R
git commit -m "feat: live model fit driver returning a fingerprint"
```

---

## Phase 9 — Baseline capture + run orchestration

### Task 11: `qual_capture_baseline()`

**Files:**
- Create: `nlmixr2qual/R/capture.R`
- Test: `nlmixr2qual/tests/testthat/test-capture.R`

- [ ] **Step 1: Write the failing test (uses a stub fitter)**

`qual_capture_baseline()` takes a `fitter` argument (defaults to `qual_fit_entry`)
so it is testable without live fits.

```r
# test-capture.R
test_that("capture writes one baseline file per model and provenance", {
  d <- withr::local_tempdir()
  reg <- data.frame(name = c("A","B"), source = "lib",
                    dataset = c("a.csv","b.csv"), domain = "popPK",
                    method = "focei", stochastic = FALSE, strict = TRUE,
                    anchor = FALSE, tol_override = NA, stringsAsFactors = FALSE)
  stub <- function(entry, category, threads = 1L)
    qual_extract_fit(fake_fit(), entry$name, entry$method, "Linearized",
                     FALSE, threads)
  qual_capture_baseline(reg, dir = d, fitter = stub, methods = NULL)
  expect_true(file.exists(file.path(d, "A__focei.qs2")))
  expect_true(file.exists(file.path(d, "B__focei.qs2")))
  expect_true(file.exists(file.path(d, "provenance.json")))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-capture.R')"`
Expected: FAIL — `could not find function "qual_capture_baseline"`.

- [ ] **Step 3: Implement `capture.R`**

```r
# capture.R

#' Recut the canonical baseline (deliberate; single-threaded)
#'
#' Uses the EXISTING frozen datasets; never regenerates data.
#' @param registry The model registry (from [qual_registry()]).
#' @param dir Output baseline directory.
#' @param fitter Function(entry, category, threads) -> fingerprint.
#' @param methods Optional method matrix (for the anchor coverage matrix).
#' @return Invisibly, the baseline directory.
#' @export
qual_capture_baseline <- function(registry, dir = .qual_pkg_file("baseline"),
                                  fitter = qual_fit_entry, methods = qual_methods()) {
  qual_set_threads(1L)  # baseline is always single-threaded
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  for (i in seq_len(nrow(registry))) {
    entry <- as.list(registry[i, ])
    fp <- fitter(entry, category = "Linearized", threads = 1L)
    qs2::qs_save(fp, file.path(dir, paste0(entry$name, "__", entry$method, ".qs2")))
  }
  qual_write_provenance(qual_provenance(inner_threads = 1L, workers = 1L),
                        file.path(dir, "provenance.json"))
  invisible(dir)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-capture.R')"`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add nlmixr2qual/R/capture.R nlmixr2qual/tests/testthat/test-capture.R
git commit -m "feat: deliberate single-threaded baseline capture"
```

### Task 12: `qual_run()` — strict + invariance orchestration

**Files:**
- Create: `nlmixr2qual/R/run.R`
- Test: `nlmixr2qual/tests/testthat/test-run.R`

- [ ] **Step 1: Write the failing test (stub fitter, stub baseline)**

```r
# test-run.R
test_that("qual_run compares each model to baseline and builds results", {
  d <- withr::local_tempdir()
  reg <- data.frame(name = "A", source = "lib", dataset = "a.csv",
                    domain = "popPK", method = "focei", stochastic = FALSE,
                    strict = TRUE, anchor = FALSE, tol_override = NA,
                    stringsAsFactors = FALSE)
  base_fp <- qual_extract_fit(fake_fit(), "A", "focei", "Linearized", FALSE, 1L)
  qs2::qs_save(base_fp, file.path(d, "A__focei.qs2"))
  # run fitter reproduces baseline exactly -> PASS
  stub <- function(entry, category, threads = 1L)
    qual_extract_fit(fake_fit(), entry$name, entry$method, "Linearized",
                     FALSE, threads)
  out <- qual_run(reg, baseline_dir = d, fitter = stub,
                  run_invariance = FALSE)
  expect_length(out$results, 1)
  expect_true(out$results[[1]]$pass)
  expect_true(out$results[[1]]$strict)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-run.R')"`
Expected: FAIL — `could not find function "qual_run"`.

- [ ] **Step 3: Implement `run.R`**

```r
# run.R

.load_baseline <- function(dir, model, method) {
  f <- file.path(dir, paste0(model, "__", method, ".qs2"))
  if (!file.exists(f)) stop("baseline missing: ", basename(f))
  qs2::qs_read(f)
}

#' Run the qualification: strict single-threaded stage + invariance stage
#' @param registry Model registry. @param baseline_dir Baseline directory.
#' @param fitter Function(entry, category, threads) -> fingerprint.
#' @param run_invariance Logical; run the serial multi-threaded stage.
#' @param anchor_threads Inner threads for the invariance stage.
#' @return `list(results, invariance, provenance)`.
#' @export
qual_run <- function(registry, baseline_dir = .qual_pkg_file("baseline"),
                     fitter = qual_fit_entry, run_invariance = TRUE,
                     anchor_threads = max(2L, parallel::detectCores())) {
  # --- strict stage: single-threaded ---
  qual_set_threads(1L)
  results <- lapply(seq_len(nrow(registry)), function(i) {
    entry <- as.list(registry[i, ])
    fp <- fitter(entry, category = "Linearized", threads = 1L)
    base <- .load_baseline(baseline_dir, entry$name, entry$method)
    cmp <- qual_compare(fp, base)
    list(model = entry$name, method = entry$method, strict = entry$strict,
         pass = cmp$pass, detail = cmp$detail)
  })

  # --- invariance stage: serial, multi-threaded, anchors only ---
  invariance <- NULL
  if (isTRUE(run_invariance)) {
    anchors <- registry[registry$anchor %in% TRUE, , drop = FALSE]
    qual_set_threads(anchor_threads)
    invariance <- lapply(seq_len(nrow(anchors)), function(i) {
      entry <- as.list(anchors[i, ])
      fp <- fitter(entry, category = "Linearized", threads = anchor_threads)
      base <- .load_baseline(baseline_dir, entry$name, entry$method)
      cmp <- qual_compare(fp, base, invariance = TRUE)
      informational <- isTRUE(entry$stochastic)
      list(model = entry$name, method = entry$method, threads = anchor_threads,
           pass = cmp$pass, informational = informational, detail = cmp$detail)
    })
    qual_set_threads(1L)
  }

  list(results = results, invariance = invariance,
       provenance = qual_provenance(inner_threads = 1L, workers = 1L))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-run.R')"`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add nlmixr2qual/R/run.R nlmixr2qual/tests/testthat/test-run.R
git commit -m "feat: strict + thread-invariance run orchestration"
```

---

## Phase 10 — Quarto report

### Task 13: `qual_report()` + Quarto template

**Files:**
- Create: `nlmixr2qual/R/report.R`
- Create: `nlmixr2qual/inst/report/qualification.qmd`
- Test: `nlmixr2qual/tests/testthat/test-report.R`

- [ ] **Step 1: Write the failing test (renders only if quarto present)**

```r
# test-report.R
test_that("qual_report assembles a results bundle and writes it", {
  d <- withr::local_tempdir()
  res <- list(results = list(list(model = "A", method = "focei",
                strict = TRUE, pass = TRUE, detail = data.frame(
                  quantity = "ofv", baseline = 1, observed = 1,
                  reldiff = 0, tol = 1e-3, pass = TRUE))),
              invariance = NULL,
              provenance = qual_provenance(1L, 1L))
  vg <- list(pass = TRUE, detail = data.frame(package = "nlmixr2",
              expected = "3.0.0", observed = "3.0.0", status = "match", pass = TRUE))
  bundle <- qual_report(res, version_gate = vg, dir = d, render = FALSE)
  expect_true(file.exists(file.path(d, "qualification_bundle.rds")))
  expect_equal(bundle$verdict$verdict, "PASS")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-report.R')"`
Expected: FAIL — `could not find function "qual_report"`.

- [ ] **Step 3: Implement `report.R`**

```r
# report.R

#' Assemble the results bundle and (optionally) render the Quarto report
#' @param run The [qual_run()] output.
#' @param version_gate The [qual_version_gate()] output.
#' @param dir Output directory.
#' @param render Logical; render the Quarto report (needs quarto + nlmixr2 fits done).
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
```

- [ ] **Step 4: Write the Quarto template**

`inst/report/qualification.qmd`:

````markdown
---
title: "nlmixr2 Qualification Report"
format:
  html:
    toc: true
    embed-resources: true
params:
  bundle: ""
---

```{r setup, include=FALSE}
bundle <- readRDS(params$bundle)
knitr::opts_chunk$set(echo = FALSE)
```

# Executive summary

**Overall verdict: `r bundle$verdict$verdict`**

This is a *reproducibility* qualification: a PASS means this installation
reproduces the qualified single-threaded canonical reference within tolerance.
It does **not** assert scientific correctness or accuracy against a known truth.

Results are not guaranteed bit-identical across operating systems, CPU
architectures, compilers, or BLAS/LAPACK backends; tolerances absorb that noise
and the environment is recorded below for comparison against the baseline.

```{r}
p <- bundle$provenance
knitr::kable(data.frame(Field = names(unlist(p)), Value = unlist(p)))
```

# Environment & version gate

```{r}
knitr::kable(bundle$version_gate$detail)
```

# Per-model results

```{r results='asis'}
for (r in bundle$results) {
  cat("\n## ", r$model, " (", r$method, ") — ",
      if (r$pass) "PASS" else "FAIL", "\n\n", sep = "")
  print(knitr::kable(r$detail))
}
```

# Thread-invariance (multi-threaded re-fit vs single-threaded baseline)

```{r results='asis'}
if (is.null(bundle$invariance)) {
  cat("Not run.\n")
} else {
  for (r in bundle$invariance) {
    cat("\n## ", r$model, " @ ", r$threads, " threads — ",
        if (r$pass) "PASS" else "FAIL",
        if (isTRUE(r$informational)) " (informational)" else "", "\n\n", sep = "")
    print(knitr::kable(r$detail))
  }
}
```

# Appendix: session info

```{r}
sessionInfo()
```
````

- [ ] **Step 5: Run test to verify it passes**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-report.R')"`
Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add nlmixr2qual/R/report.R nlmixr2qual/inst/report/qualification.qmd nlmixr2qual/tests/testthat/test-report.R
git commit -m "feat: results bundle + Quarto qualification report"
```

---

## Phase 11 — Populate the full model registry (data entry)

### Task 14: Add the remaining ~22 models and their frozen datasets

**Files:**
- Modify: `nlmixr2qual/inst/models/registry.csv`
- Modify: `nlmixr2qual/data-raw/simulate-datasets.R`
- Create: `nlmixr2qual/inst/data/<model>_sim.csv` (one per simulated model)
- Modify: `nlmixr2qual/tests/testthat/test-registry.R`

Each model is one registry row + one frozen dataset, following the **exact
pattern** proven in Tasks 4 and 9. No new code.

- [ ] **Step 1: Extend `simulate-datasets.R` with one block per model**

For every model below, add a block modelled precisely on the augmented PK_1cmt
block from Task 9: load `readModelDb(<name>)`, **augment per the `eta` column via
`qual_prepare_model()` / `addEta()`** so the simulated data carry a between-subject
signal, a domain-appropriate `et()` design, a fixed `set.seed()`, `rxSolve()`,
then write `inst/data/<name>_sim.csv`. Where a canonical real dataset is used
instead (marked *real*), source it from `nlmixr2data` and write it out verbatim
once. **Simulate from the SAME augmented model the fit will use** (both derive
from the registry `eta` column) so data and fit are consistent.

The `eta` column below (spec §3.0 / D9): comma-separated parameter names to add
IIV to. Values are given for the bare PK templates; for every literature/PD
model, **inspect `readModelDb(name)$iniDf` first** — if it already has `eta`
terms (most literature models do), leave `eta` **empty** (use verbatim); only add
`eta` (typically on clearance + central volume, or the model's primary
disposition parameters) if it has none. Confirm the augmented model actually fits
before committing its dataset.

Full model list (registry `name`, domain, primary `method`, dataset, eta):

| name | domain | method | dataset | eta |
|------|--------|--------|---------|-----|
| PK_1cmt | popPK | focei | PK_1cmt_sim.csv | lcl,lvc |
| PK_2cmt | popPK | focei | PK_2cmt_sim.csv | lcl,lvc |
| PK_3cmt | popPK | focei | PK_3cmt_sim.csv | lcl,lvc |
| PK_1cmt_des | popPK | focei | PK_1cmt_des_sim.csv | lcl,lvc |
| PK_2cmt_no_depot | popPK | focei | PK_2cmt_no_depot_sim.csv | lcl,lvc |
| PK_1cmt_tmdd_qss | popPK | focei | PK_1cmt_tmdd_qss_sim.csv | (inspect iniDf) |
| PK_2cmt_mAb_Davda_2014 | popPK | focei | PK_2cmt_mAb_Davda_2014_sim.csv | (inspect iniDf) |
| Beal_2001_iv1cmt_bql | popPK | saem | Beal_2001_iv1cmt_bql_sim.csv | (inspect iniDf) |
| indirect_1cpt_stim_kin | PKPD | focei | indirect_1cpt_stim_kin_sim.csv | (inspect iniDf) |
| indirect_1cpt_inhi_kout | PKPD | focei | indirect_1cpt_inhi_kout_sim.csv | (inspect iniDf) |
| indirect_1cpt_stim_kout | PKPD | focei | indirect_1cpt_stim_kout_sim.csv | (inspect iniDf) |
| indirect_1cpt_inhi_kin | PKPD | focei | indirect_1cpt_inhi_kin_sim.csv | (inspect iniDf) |
| Hansson_2013_sunitinib_myelosuppression | PKPD | saem | Hansson_2013_myelo_sim.csv | (inspect iniDf) |
| Venisse_2008_caspofungin | PKPD | focei | Venisse_2008_caspofungin_sim.csv | (inspect iniDf) |
| Delor_2013_alzheimer | disease | focei | Delor_2013_alzheimer_sim.csv | (inspect iniDf) |
| Lee_2011_parkinson_progression | disease | focei | Lee_2011_parkinson_sim.csv | (inspect iniDf) |
| VelezdeMendizabal_2013_multipleSclerosis | disease | saem | VelezdeMendizabal_2013_ms_sim.csv | (inspect iniDf) |
| Choy_2016_T2DM_WHIG | disease | focei | Choy_2016_t2dm_sim.csv | (inspect iniDf) |
| Hamuro_2017_DMD_6MWT | disease | focei | Hamuro_2017_dmd_sim.csv | (inspect iniDf) |
| Schindler_2017_sunitinib_fatigue | ER | focei | Schindler_2017_fatigue_sim.csv | (inspect iniDf) |
| Schindler_2017_sunitinib_hfs | ER | focei | Schindler_2017_hfs_sim.csv | (inspect iniDf) |
| Schindler_2017_likert_pain | ER | saem | Schindler_2017_likert_sim.csv | (inspect iniDf) |
| Chen_2017_TB_MTP_GPDI_mouse | ER | focei | Chen_2017_tb_mtp_sim.csv | (inspect iniDf) |
| PerezRuixo_2015_oxaliplatin_platelet_dynamics | ER | focei | PerezRuixo_2015_platelet_sim.csv | (inspect iniDf) |

- [ ] **Step 2: Verify each `readModelDb(name)` resolves before adding its row**

Run: `Rscript -e 'library(nlmixr2lib); for (n in c("PK_1cmt","PK_2cmt","PK_3cmt","PK_1cmt_des","PK_2cmt_no_depot","PK_1cmt_tmdd_qss","PK_2cmt_mAb_Davda_2014","Beal_2001_iv1cmt_bql","indirect_1cpt_stim_kin","indirect_1cpt_inhi_kout","indirect_1cpt_stim_kout","indirect_1cpt_inhi_kin","Hansson_2013_sunitinib_myelosuppression","Venisse_2008_caspofungin","Delor_2013_alzheimer","Lee_2011_parkinson_progression","VelezdeMendizabal_2013_multipleSclerosis","Choy_2016_T2DM_WHIG","Hamuro_2017_DMD_6MWT","Schindler_2017_sunitinib_fatigue","Schindler_2017_sunitinib_hfs","Schindler_2017_likert_pain","Chen_2017_TB_MTP_GPDI_mouse","PerezRuixo_2015_oxaliplatin_platelet_dynamics")) { r <- tryCatch({readModelDb(n); "ok"}, error=function(e) paste("MISSING:", conditionMessage(e))); cat(n, r, "\n") }'`
Expected: every line ends `ok`. For any `MISSING`, substitute the nearest model from the same `inst/modeldb/<domain>` directory (the library has 50 PD, 22 therapeuticArea, 20 endogenous candidates) and update the table.

- [ ] **Step 3: Write `registry.csv` with all rows**

Replace `inst/models/registry.csv` so it contains the header (including the
`eta` column added in Task 9) plus one row per model from Step 1. Set
`stochastic=TRUE` for rows whose `method` is `saem` (and any other stochastic
primary method); set `anchor=TRUE` only for `PK_1cmt` and `PK_2cmt`;
`strict=TRUE` for all; `tol_override` blank unless a model is known-noisy; `eta`
per the Step 1 table (quote values containing commas, e.g. `"lcl,lvc"`).

- [ ] **Step 4: Generate all frozen datasets once, then commit them**

Run: `cd nlmixr2qual && Rscript data-raw/simulate-datasets.R`
Expected: every `inst/data/*_sim.csv` in the table exists and is non-empty.

- [ ] **Step 5: Add a registry count assertion to the test**

```r
test_that("registry covers all four domains and >= 20 models", {
  reg <- qual_registry()
  expect_gte(nrow(reg), 20)
  expect_setequal(unique(reg$domain), c("popPK","PKPD","disease","ER"))
  expect_true(all(reg$name[reg$anchor] %in% c("PK_1cmt","PK_2cmt")))
})
```

- [ ] **Step 6: Run the registry tests**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-registry.R')"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add nlmixr2qual/inst/models/registry.csv nlmixr2qual/data-raw/simulate-datasets.R nlmixr2qual/inst/data/ nlmixr2qual/tests/testthat/test-registry.R
git commit -m "feat: full 24-model registry with frozen datasets"
```

---

## Phase 12 — Populate the 26-method coverage matrix (data entry)

### Task 15: Complete `methods.csv` and the no-random-effect anchor variant

**Files:**
- Modify: `nlmixr2qual/inst/models/methods.csv`
- Create: `nlmixr2qual/inst/models/PK_1cmt_fixed.R` (no-random-effect anchor for optimizers)
- Modify: `nlmixr2qual/tests/testthat/test-registry.R`

- [ ] **Step 1: Write the full `methods.csv` (all 26 methods)**

```
method,category,stochastic,strict,needs_reff
fo,Linearized,FALSE,TRUE,TRUE
foi,Linearized,FALSE,TRUE,TRUE
foce,Linearized,FALSE,TRUE,TRUE
focei,Linearized,FALSE,TRUE,TRUE
focep,Linearized,FALSE,TRUE,TRUE
nlme,Linearized,FALSE,TRUE,TRUE
laplace,Integral approximation,FALSE,TRUE,TRUE
agq,Integral approximation,FALSE,TRUE,TRUE
imp,Integral approximation,TRUE,TRUE,TRUE
impmap,Integral approximation,TRUE,TRUE,TRUE
saem,Stochastic EM,TRUE,TRUE,TRUE
fsaem,Stochastic EM,TRUE,TRUE,TRUE
qrpem,Stochastic EM,TRUE,TRUE,TRUE
npag,Nonparametric,TRUE,TRUE,TRUE
npb,Nonparametric,TRUE,TRUE,TRUE
advi,Machine learning,TRUE,TRUE,TRUE
vae,Machine learning,TRUE,TRUE,TRUE
nlm,Optimizer (NLM family),FALSE,TRUE,FALSE
nlminb,Optimizer (NLM family),FALSE,TRUE,FALSE
bobyqa,Optimizer (NLM family),FALSE,TRUE,FALSE
newuoa,Optimizer (NLM family),FALSE,TRUE,FALSE
uobyqa,Optimizer (NLM family),FALSE,TRUE,FALSE
n1qn1,Optimizer (NLM family),FALSE,TRUE,FALSE
lbfgsb3c,Optimizer (NLM family),FALSE,TRUE,FALSE
optim,Optimizer (NLM family),FALSE,TRUE,FALSE
nls,Optimizer (NLM family),FALSE,TRUE,FALSE
```

- [ ] **Step 2: Cross-check the matrix against the live method list**

Run: `Rscript -e 'library(nlmixr2est); m <- read.csv("nlmixr2qual/inst/models/methods.csv"); live <- nlmixr2AllEstType()$est; cat("in csv not live:", setdiff(m$method, live), "\n"); cat("in live not csv:", setdiff(live, m$method), "\n")'`
Expected: `in csv not live:` empty. `in live not csv:` may list `posthoc`/`rxSolve`/`simulate` (utility, intentionally excluded) — confirm nothing else appears; if a new estimation method appears, add it.

- [ ] **Step 3: Create the no-random-effect anchor variant for optimizers**

`inst/models/PK_1cmt_fixed.R` — PK_1cmt with the between-subject variability
removed so `needs_reff = FALSE` optimizers can fit fixed effects only:

```r
PK_1cmt_fixed <- function() {
  ini({
    lka <- 0.45; lcl <- 1; lvc <- 3.45; propSd <- 0.5
  })
  model({
    ka <- exp(lka); cl <- exp(lcl); vc <- exp(lvc)
    Cc <- linCmt()
    Cc ~ prop(propSd)
  })
}
```

- [ ] **Step 4: Add the method-matrix schema test**

```r
test_that("method matrix has all 26 methods across 6 categories", {
  m <- qual_methods()
  expect_equal(nrow(m), 26)
  expect_setequal(unique(m$category),
    c("Linearized","Integral approximation","Stochastic EM",
      "Nonparametric","Machine learning","Optimizer (NLM family)"))
  expect_true(all(m$stochastic[m$method %in% c("imp","impmap")]))  # spec 6.3
})
```

- [ ] **Step 5: Run the tests**

Run: `Rscript -e "pkgload::load_all('nlmixr2qual'); testthat::test_file('nlmixr2qual/tests/testthat/test-registry.R')"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add nlmixr2qual/inst/models/methods.csv nlmixr2qual/inst/models/PK_1cmt_fixed.R nlmixr2qual/tests/testthat/test-registry.R
git commit -m "feat: complete 26-method coverage matrix + no-reff anchor"
```

---

## Phase 13 — Top-level entry points + baseline cut

### Task 16: `run_qualification.R`, `qualify.bat`, and cut the shipped baseline

**Files:**
- Create: `nlmixr2qual/run_qualification.R`
- Create: `nlmixr2qual/qualify.bat`
- Create: `nlmixr2qual/inst/baseline/*.qs2` (generated by the capture step)
- Create: `nlmixr2qual/inst/baseline/provenance.json`

- [ ] **Step 1: Write `run_qualification.R`**

```r
#!/usr/bin/env Rscript
# Top-level qualification runner. Single entry point for a qualification run.
suppressMessages(pkgload::load_all("."))

cores   <- parallel::detectCores()
workers <- max(1L, cores)            # testthat parallel workers (one per file)
qual_set_threads(qual_thread_plan(cores, workers, mode = "single")$inner)

registry <- qual_registry()
vg <- qual_version_gate()
run <- qual_run(registry, run_invariance = TRUE,
                anchor_threads = max(2L, cores))
bundle <- qual_report(run, version_gate = vg,
                      dir = "qualification_output",
                      render = TRUE, formats = "html")
cat("OVERALL:", bundle$verdict$verdict, "\n")
quit(status = if (bundle$verdict$verdict == "PASS") 0 else 1)
```

- [ ] **Step 2: Write `qualify.bat`**

```bat
@echo off
REM Windows convenience wrapper for the nlmixr2 qualification run.
Rscript run_qualification.R
```

- [ ] **Step 3: Cut the shipped canonical baseline (single-threaded, live fits)**

Run: `cd nlmixr2qual && Rscript -e "pkgload::load_all('.'); qual_set_threads(1L); qual_capture_baseline(qual_registry())"`
Expected: `inst/baseline/<model>__<method>.qs2` for every registry row, plus
`inst/baseline/provenance.json`. This is the deliberate baseline recut (spec D2).

- [ ] **Step 4: Smoke-run the full qualification**

Run: `cd nlmixr2qual && Rscript run_qualification.R`
Expected: prints `OVERALL: PASS`; `qualification_output/qualification.html`,
`qualification_verdict.txt` (`PASS`), and `qualification_summary.txt` written.

- [ ] **Step 5: Commit**

```bash
git add nlmixr2qual/run_qualification.R nlmixr2qual/qualify.bat nlmixr2qual/inst/baseline/
git commit -m "feat: top-level runner, wrapper, and shipped canonical baseline"
```

---

## Phase 14 — Test harness wiring + package check

### Task 17: Group tests by domain into parallel testthat files

**Files:**
- Create: `nlmixr2qual/tests/testthat/test-qual-popPK.R`
- Create: `nlmixr2qual/tests/testthat/test-qual-PKPD.R`
- Create: `nlmixr2qual/tests/testthat/test-qual-disease.R`
- Create: `nlmixr2qual/tests/testthat/test-qual-ER.R`
- Create: `nlmixr2qual/tests/testthat/test-qual-methods.R`

Each file runs one domain's strict comparisons in its own worker process. They
share the pattern below; only the `domain` filter differs.

- [ ] **Step 1: Write `test-qual-popPK.R`**

```r
# One worker process per domain -> process isolation for compiled solvers.
test_that("popPK models reproduce the canonical baseline", {
  skip_if_not_installed("nlmixr2")
  qual_set_threads(qual_inner_threads())  # pinned by setup.R / runner
  reg <- qual_registry()
  reg <- reg[reg$domain == "popPK", , drop = FALSE]
  for (i in seq_len(nrow(reg))) {
    entry <- as.list(reg[i, ])
    fp <- qual_fit_entry(entry, category = "Linearized",
                         threads = qual_inner_threads())
    base <- nlmixr2qual:::.load_baseline(.qual_pkg_file("baseline"),
                                         entry$name, entry$method)
    cmp <- qual_compare(fp, base)
    expect_true(cmp$pass,
      info = paste(entry$name, "-", paste(cmp$detail$quantity[!cmp$detail$pass],
                                          collapse = ", ")))
  }
})
```

- [ ] **Step 2: Write the other three domain files**

Copy `test-qual-popPK.R` to `test-qual-PKPD.R`, `test-qual-disease.R`,
`test-qual-ER.R`, changing the `domain ==` filter to `"PKPD"`, `"disease"`,
`"ER"` and the test description accordingly. (Repeated in full rather than
factored, so each worker file is self-contained.)

- [ ] **Step 3: Write `test-qual-methods.R` (anchor coverage matrix)**

```r
test_that("all 26 methods fit the anchor models and match baseline", {
  skip_if_not_installed("nlmixr2")
  qual_set_threads(qual_inner_threads())
  m <- qual_methods()
  for (i in seq_len(nrow(m))) {
    meth <- as.list(m[i, ])
    anchor <- if (meth$needs_reff) "PK_1cmt" else "PK_1cmt_fixed"
    entry <- list(name = anchor,
                  source = if (anchor == "PK_1cmt") "lib" else "file",
                  dataset = "PK_1cmt_sim.csv", method = meth$method,
                  stochastic = meth$stochastic,
                  # augment the mixed-effects anchor with IIV; the fixed anchor gets none
                  eta = if (anchor == "PK_1cmt") "lcl,lvc" else "")
    base_file <- file.path(.qual_pkg_file("baseline"),
                           paste0(anchor, "__", meth$method, ".qs2"))
    skip_if_not(file.exists(base_file),
                paste("no baseline for", anchor, meth$method))
    fp <- qual_fit_entry(entry, category = meth$category,
                         threads = qual_inner_threads())
    cmp <- qual_compare(fp, qs2::qs_read(base_file))
    if (meth$strict) expect_true(cmp$pass, info = meth$method)
    else expect_true(TRUE)  # informational: recorded, never fails verdict
  }
})
```

- [ ] **Step 4: Confirm `source = "file"` anchors already load**

No code change needed — `qual_prepare_model()` (built in Task 10) already handles
`source = "file"` by parsing `inst/models/<name>.R`, and an empty `eta` means no
augmentation. Just confirm `qual_prepare_model(list(name = "PK_1cmt_fixed",
source = "file", eta = ""))` returns a model without error before running the
suite.

- [ ] **Step 5: Run the full test suite (parallel)**

Run: `cd nlmixr2qual && Rscript -e "testthat::test_local()"`
Expected: all pure-machinery tests PASS; live tests PASS if nlmixr2 installed and
the baseline exists (else SKIP). No worker oversubscribes (each pins threads via
`setup.R`).

- [ ] **Step 6: Commit**

```bash
git add nlmixr2qual/tests/testthat/test-qual-popPK.R nlmixr2qual/tests/testthat/test-qual-PKPD.R nlmixr2qual/tests/testthat/test-qual-disease.R nlmixr2qual/tests/testthat/test-qual-ER.R nlmixr2qual/tests/testthat/test-qual-methods.R nlmixr2qual/R/fit.R
git commit -m "feat: domain-grouped parallel qualification tests"
```

### Task 18: Documentation + R CMD check

**Files:**
- Create: `nlmixr2qual/README.md`
- Modify: `nlmixr2qual/NAMESPACE` (via roxygen)

- [ ] **Step 1: Generate documentation and NAMESPACE**

Run: `cd nlmixr2qual && Rscript -e "roxygen2::roxygenise()"`
Expected: `man/*.Rd` created, `NAMESPACE` populated with the `qual_*` exports.

- [ ] **Step 2: Write `README.md`**

Cover: what it qualifies (reproducibility, not correctness), the environment and
threading caveats (spec §1.2, §7.3), how to run (`Rscript run_qualification.R`),
how to recut the baseline on an nlmixr2 upgrade (`qual_capture_baseline()`), and
the output artifacts (Quarto report + verdict/summary text). Mirror the tone and
structure of `occamsqual/README.md`.

- [ ] **Step 3: Run R CMD check**

Run: `cd nlmixr2qual && Rscript -e "devtools::check(document = FALSE)"`
Expected: 0 errors, 0 warnings. Notes about Suggested packages not installed are
acceptable on a dev box without the full nlmixr2 stack.

- [ ] **Step 4: Commit**

```bash
git add nlmixr2qual/README.md nlmixr2qual/NAMESPACE nlmixr2qual/man/
git commit -m "docs: README and generated documentation"
```

---

## Self-Review Notes (completed during authoring)

- **Spec coverage:** D1 frozen baseline (Tasks 11–12, 16), D2 shipped canonical + recut (Task 11, 16 step 3), D3 compared quantities (Task 1 fingerprint, Task 3 comparator), D4 nlmixr2lib models (Task 14), D5 permanently frozen data (Task 9, 14; `data-raw` provenance-only), D6 26-method matrix + anchors (Task 15, 17), D7 Quarto-primary + text (Task 13), D8 single-threaded canonical + invariance + no-collision (Tasks 5, 12, 17). §1.1/§1.2 scope+environment (Task 13 template), §6.2 category-appropriate quantities (comparator dispatches on ptype; ML/nonparametric extension noted below), §6.3 stochastic axis (Task 15 flags), version gate (Task 7).
- **Known extension point:** §6.2 category-appropriate quantities for nonparametric/ML methods (distribution summaries / ELBO) are handled structurally by the `ptype`-keyed comparator, but `qual_extract_fit()` currently reads the parametric accessors. When `npag`/`npb`/`advi`/`vae` baselines are first cut, extend `qual_extract_fit()` with category-specific extraction — add this as a follow-up task once those methods' fit-object shapes are confirmed live (they were not exercised on the dev box during planning).
- **Placeholder scan:** none — every code step contains complete code; the two data-entry tasks (14, 15) show the full pattern plus the concrete enumerated list.
- **Type consistency:** fingerprint fields, `qual_compare()` quantity keys (`ptype:name`, `se:ptype:name`, `shrink:name`, `converged`), and the `qs2` baseline filename convention `<model>__<method>.qs2` are used identically across Tasks 1, 3, 11, 12, 16, 17.
