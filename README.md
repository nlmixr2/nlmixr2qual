# nlmixr2qual

Reproducibility qualification of an **nlmixr2** installation. `nlmixr2qual`
re-fits a curated set of `nlmixr2lib` models against a shipped single-threaded
**canonical baseline**, checks that each installation reproduces the reference
parameter estimates, objective function value, standard errors and shrinkage
**within tolerance**, qualifies multi-threaded fitting by a thread-invariance
check, and renders a Quarto qualification report with an overall **PASS/FAIL**
verdict.

## What this qualifies (and what it does not)

This is a **reproducibility** qualification. A PASS means the installation under
test reproduces the qualified single-threaded canonical reference within
tolerance. It does **not** assert scientific correctness or accuracy against a
known ground truth — the baseline is a frozen regression reference, not truth.

Results are **not** guaranteed bit-identical across operating systems, CPU
architectures, compilers, or BLAS/LAPACK backends. Tolerances (per quantity
class; see `qual_tolerance()`) absorb that numerical noise, and the full
environment is recorded in the report for comparison against the baseline
provenance (`inst/baseline/provenance.json`).

## What it checks

- **Version gate** — installed package versions vs. the qualified baseline
  (`inst/qualified_baseline.csv`: nlmixr2, nlmixr2est, nlmixr2lib, nlmixr2data,
  rxode2). A mismatch fails the verdict.
- **Strict stage** — every model in the registry (`inst/models/registry.csv`) is
  re-fit single-threaded and compared to its canonical baseline fingerprint. Any
  strict-model deviation beyond tolerance fails the verdict.
- **Thread-invariance stage** — the anchor models (`PK_1cmt`, `PK_2cmt`) are
  re-fit multi-threaded and compared to the single-threaded baseline under a
  looser tolerance. This stage runs in an **isolated child process** and is
  **informational**: it is reported but does not gate the verdict.

### Models qualified in this release

A robust core that fits cleanly and reproducibly single-threaded:

| Domain | Models |
|---|---|
| popPK | `PK_1cmt`, `PK_2cmt`, `PK_3cmt`, `PK_1cmt_des`, `PK_2cmt_no_depot` (augmented with IIV on CL and Vc) |
| disease | `Lee_2011_parkinson_progression`, `Hamuro_2017_DMD_6MWT` (verbatim; own IIV) |

The estimation-method coverage matrix (`inst/models/methods.csv`) catalogues all
26 nlmixr2 estimators across 6 categories; this release ships anchor baselines
for the reliable conditional-estimation methods (`focei`, `foce`). The remaining
methods and the heavier literature models (PKPD indirect-response, multi-endpoint,
ordered-categorical, and multi-drug models) are a tracked follow-up — see
`docs/`.

## How to run

From the package directory, with the nlmixr2 stack installed:

```sh
Rscript run_qualification.R      # or: qualify.bat   (Windows)
```

This runs the strict + invariance stages against the shipped baseline, writes the
report and artifacts to `qualification_output/`, prints `OVERALL: PASS`/`FAIL`,
and exits non-zero on FAIL (for CI gating).

## Output

Written to `qualification_output/`:

- **`qualification.html`** — the primary Quarto report: executive summary and
  verdict, environment + version gate, per-model deviation tables, and the
  thread-invariance section.
- **`qualification_verdict.txt`** — a single word, `PASS` or `FAIL`.
- **`qualification_summary.txt`** — the per-model result table and `OVERALL:` line
  (occamsqual-style plain text for pipeline continuity).
- **`qualification_bundle.rds`** — the full results object.

## Recutting the baseline (on an nlmixr2 upgrade)

The canonical baseline is deliberately frozen and only recut on purpose — e.g.
when qualifying a new nlmixr2 stack. The frozen **datasets** are never
regenerated (`data-raw/simulate-datasets.R` is provenance only and guards
against overwriting committed data).

```r
pkgload::load_all(".")
qual_set_threads(1L)
qual_capture_baseline(qual_registry())   # writes inst/baseline/*.qs2 + provenance.json
```

Then update `inst/qualified_baseline.csv` to the versions the new baseline was
cut with.

## Environment notes

- Locked to **R == 4.6.1**.
- The strict stage and baseline are single-threaded for determinism. The
  invariance stage uses a **capped** multi-thread count (`qual_invariance_threads()`,
  default 4) — the check only needs threads > 1, and oversubscribing a small
  problem on a many-core machine can crash the OpenMP solver. It runs in an
  isolated `callr` child process so any solver instability there cannot take down
  the qualification.
- The conditional FOCE(i) methods are fit with `outerOpt = "bobyqa"` for a stable,
  cross-platform convergence signal (the default `nlminb` emits a
  tolerance-sensitive "false convergence" advisory at the optimum).
