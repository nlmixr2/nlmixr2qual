# nlmixr2qual

Reproducibility qualification of an **nlmixr2** installation. `nlmixr2qual` is
an **import-based, organisation-extensible** qualification tool: references
are known-good fits imported from [`nlmixr2save`](https://github.com/nlmixr2/nlmixr2save)
bundles, stored one-per-file as self-contained JSON. Qualifying an install
re-fits each reference locally — at the reference's own thread count — and
compares the fresh result against the stored reference fingerprint, rendering
a Quarto summary with an overall **PASS/FAIL** verdict.

## What this qualifies (and what it does not)

This is a **reproducibility** qualification. A PASS means the installation
under test reproduces a reference's stored result within tolerance. It does
**not** assert scientific correctness or accuracy against a known ground
truth — a reference is a confirmed-good fit, not truth.

Results are **not** guaranteed bit-identical across operating systems, CPU
architectures, compilers, or BLAS/LAPACK backends. Tolerances (per quantity
class; see `qual_tolerance()`) absorb that numerical noise, and the full
environment is recorded in the report for comparison against the reference's
provenance.

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

   A fit does not record its rxode2 thread count, so the caller must assert
   the count the bundle was fit at (`threads =`). By default the reference's
   starting values (`initial_estimates`) are taken from the bundle's own
   pre-fit priors (`fit$iniDf0`, preserved by `saveFit()`), not the
   fitted/post-fit values — this makes a later re-fit reproduce the original
   optimizer trajectory instead of warm-starting from the answer. Pass a
   named list/vector or a compiled model object to `initial_estimates` to
   override this.

2. **Ship or point to a folder** of JSON references. `nlmixr2qual` ships an
   internal set under `inst/references/` (see [`docs/references.md`](docs/references.md));
   an organisation can maintain its own folder of references the same way.

3. **Qualify** the local install:

   ```r
   res <- qualify(which = "all", source = "internal")
   ```

   or from the shell:

   ```sh
   Rscript run_qualification.R              # internal references
   Rscript run_qualification.R path/to/dir  # or: qualify.bat (Windows)
   ```

   For each selected reference, `qualify()` pins the reference's own thread
   count, re-fits the model locally, and compares the fresh fingerprint
   against the stored one. Deterministic methods gate the verdict; stochastic
   methods (SAEM, importance sampling, …) are compared under a looser
   tolerance and reported but never gate.

   - `which` — `"all"` (default), or a vector of **pairs**
     (`"<model>__<method>"`, selecting every thread variant) and/or full
     **ids** (`"<model>__<method>__t<threads>"`).
   - `source` — `"internal"` (default, the shipped set) or a path to a
     folder of `.json` references.

## The thread model

Multi-threaded fits can differ across machines/BLAS even at the same thread
count (non-associative parallel float reductions), so an exact match cannot
be required for `threads > 1`. Each reference is a single result, **tagged
with the thread count that produced it**, and is only ever compared against
a re-fit at that same thread count — single- and multi-threaded results are
never compared against each other. The comparison tolerance is keyed to the
reference's thread count:

- `threads == 1` (`t1`) — **strict**, bit-portable tolerance. **Mandatory**:
  every method ships a `t1` reference.
- `threads > 1` (e.g. `t4`) — a **looser** tolerance sized for parallel-float
  variation. **Optional**: a method may or may not have a multi-threaded
  reference, and the tooling works correctly with a `t1`-only set. The
  default multi-thread count for the shipped set and for generators is
  `qual_default_multi_threads()` (4).

An organisation adds coverage at any thread count by importing one bundle
per count — the tool never invents a multi-threaded result from a
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
