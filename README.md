# nlmixr2qual

**`nlmixr2qual`** porvides support for reproducibility qualification of an **nlmixr2** installation. It is an import-based, organisation-extensible qualification tool -  reference models are known-good fits imported from [`nlmixr2save`](https://github.com/nlmixr2/nlmixr2save) bundles, stored one-per-file as self-contained JSON. Qualifying an install re-fits each reference locally, using the reference's own thread count, and
compares the fresh result against the stored reference fingerprint. A Quarto summary with an overall **PASS/FAIL** verdict is provided once complete.

## What `nlmixr2qual` does and does not do

This is a reproducibility qualification. A PASS means the installation
under test reproduces a reference's stored results, within a tolerance range (since some of our methods are stochastic, and results are heavily dependent on local conditions). It does not assert scientific correctness or accuracy against a known ground truth, since a reference is a confirmed-good fit, not (necessarily) reality.

Results are not guaranteed to be identical across operating systems, CPU
architectures, compilers, versions of R, or BLAS/LAPACK backends. Tolerances allow for some numerical noise in the results, and the full
environment is recorded in the report for comparison against the reference.

## How it works

1. **Create a reference** by fitting and saving a model with `nlmixr2save`,
   then importing the bundle:

   ```r
   fit <- nlmixr2est::nlmixr2(model, data, est = "focei")
   nlmixr2save::saveFit(fit, "my_fit", zip = TRUE)

   ref <- qual_import_bundle("my_fit.zip", model_name = "my_model",
                             method = "focei", threads = 1L)
   qual_reference_write(ref, "my_references/my_model__focei__t1.json")
   ```

   A fit does not record its `rxode2` thread count, so the function call must specify
   the count the bundle was fit at (`threads =`). By default the reference's
   starting values (`initial_estimates`) are taken from the bundle's own
   pre-fit priors (`fit$iniDf0`, preserved by `saveFit()`), not the
   fitted/post-fit values. To override this, you can pass a
   named list/vector or a compiled model object to `initial_estimates` instead.

2. **Point to a folder** of JSON references. `nlmixr2qual` ships an
   internal default set under `inst/references/` (see [`docs/references.md`](docs/references.md));
   an organisation can maintain its own folder of favourite reference models the same way.

3. **Qualify** the local install:

   ```r
   res <- qualify(which = "all", source = "internal")
   ```

   or from the shell:

   ```sh
   Rscript run_qualification.R              # internal references
   Rscript run_qualification.R path/to/dir  # or: qualify.bat (Windows)
   ```

   For each selected reference, `qualify()` sets the reference's own thread
   count, re-fits the model locally, and compares the fresh fingerprint
   against the stored one. Deterministic methods are expected to match, within tolerances, while stochastic methods (SAEM, importance sampling, et al) are compared under a looser tolerance and reported, but never kill the test process.

   - `which` — `"all"` (default), or a vector of **pairs**
     (`"<model>__<method>"`, selecting every thread variant) and/or full
     **ids** (`"<model>__<method>__t<threads>"`).
   - `source` — `"internal"` (default, the shipped set) or a path to a
     folder of `.json` references.

## Threading

Multi-threaded fits can differ across machines/BLAS even at the same thread
count (thanks to non-associative parallel float reductions), so an exact match cannot
realistically be produced for `threads > 1`. Each reference is a single result, tagged
with the thread count that produced it, and is only ever compared against
a re-fit at that same thread count. Single- and multi-threaded results are
never compared against each other. The comparison tolerance is keyed to the
reference's thread count:

- `threads == 1` (`t1`) — strict. Mandatory: every method ships a `t1` reference.
- `threads > 1` (e.g. `t4`) — a looser tolerance suitable for parallel-float
  variation. Optional: a method may or may not have a multi-threaded
  reference, and the test machinery works just as well with a `t1`-only set. The
  default multi-thread count for the shipped set and for generators is 4.

You can add coverage for any number of threads by importing one bundle
per count. `nlmixr2qual` never infers a multi-threaded result from a
single-threaded one.

## Output

`Rscript run_qualification.R` writes to `qualification_output/`:

- **`verdict.txt`** — `OVERALL: PASS`/`FAIL` plus a per-reference line
  (id, thread count, pass/fail, strict/informational).
- **`qualification.html`** — the Quarto summary report (skipped if the
  `quarto` package/CLI isn't available).

## Environment notes

- Locked to **R == 4.6.1**.
- `R/threads.R` is the only code allowed to set thread counts
  (`qual_set_threads()`); everything else reads the budget via
  `qual_inner_threads()`. This keeps process-level parallelism (e.g.
  testthat workers) and rxode2's OpenMP threads from oversubscribing cores
  at the same time.
