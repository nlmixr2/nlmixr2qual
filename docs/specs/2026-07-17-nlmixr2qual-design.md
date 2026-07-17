# nlmixr2qual — Design Specification

**Date:** 2026-07-17
**Author:** Justin Wilkins
**Status:** Draft for review

---

## 1. Purpose

`nlmixr2qual` is an R package that **qualifies an nlmixr2 installation** by
re-fitting a curated set of 20–30 real models drawn from `nlmixr2lib`, comparing
each fit against a **shipped canonical baseline**, and rendering a **Quarto
report** (HTML/PDF/DOCX) as the primary deliverable. The report carries the
overall **PASS/FAIL verdict** and per-model interpretation of any deviation.

It is the nlmixr2-specific sibling of the existing `occamsqual` installation
qualification suite, and deliberately reuses that suite's conventions (testthat
3e, process-isolated parallel tests, a version gate, a machine-readable verdict)
so it slots into the same downstream QR workflow.

### 1.1 Scope of the qualification claim (stated up front in every report)

This suite performs a **reproducibility / regression** qualification. A PASS
means:

> *This installation reproduces the qualified reference results within the
> defined tolerances.*

A PASS does **not** assert that the estimates are scientifically correct, nor
that the estimation algorithms are accurate against a known truth. It asserts
only that nothing has **drifted** from the frozen canonical reference cut on a
qualified nlmixr2 version. This limitation is printed in the report's executive
summary so the downstream QR cannot overclaim. (Accuracy-against-known-truth and
external-reference qualification are explicitly out of scope for this version;
see §11.)

### 1.2 Environment sensitivity (stated in every report)

nlmixr2 compiles model C/C++ through rxode2 and links against
platform-provided numerical libraries, so results are **not guaranteed to be
bit-identical across environments**. Legitimate, non-defect numerical
differences arise from:

- **Operating system** (Windows / macOS / Linux) and its math library.
- **CPU architecture** (x86-64 vs arm64/Apple Silicon), including differing
  floating-point rounding and SIMD behaviour.
- **Compiler and toolchain** (Rtools/gcc, clang, MSVC) and optimisation flags.
- **BLAS/LAPACK backend** (reference, OpenBLAS, MKL, Accelerate) and its
  threading.
- **R and package build** provenance.

The report therefore does two things:

1. **Records the full environment** it ran in — OS, architecture, compiler,
   BLAS/LAPACK backend, R version, and the qualified package set — in the
   executive summary and the `sessionInfo()` appendix, alongside the same
   provenance recorded for the **baseline** so the two are directly comparable.
2. **States the reproducibility boundary explicitly:** the canonical baseline is
   cut on one qualified reference environment; tolerances (§6) are sized to
   absorb cross-environment numerical noise, and a PASS means "reproduces the
   reference **within tolerance on this environment**." A report from an
   environment that differs from the baseline's flags this prominently, so a
   near-tolerance deviation is read as environment difference, not defect.

Where a program requires bit-identical reproduction, it must qualify on an
environment matching the baseline's recorded provenance.

---

## 2. Design decisions (locked)

| # | Decision | Choice |
|---|----------|--------|
| D1 | Reference truth | **Frozen baseline** (regression / reproducibility) |
| D2 | Baseline origin | **Shipped canonical baseline**, committed to the repo, re-cut deliberately on nlmixr2 upgrade |
| D3 | Compared quantities | **OFV + thetas + omegas + sigmas + SEs/RSEs + shrinkage + convergence status** |
| D4 | Model source | **Real example models from `nlmixr2lib`** across popPK, PKPD, disease, exposure–response |
| D5 | Data provenance | **Simulate-then-fit with permanently frozen, bundled datasets** — generated once, never regenerated on any platform/R/nlmixr2 change (real datasets where a canonical one exists) |
| D6 | Method coverage | **Primary method per model + a small method-coverage matrix** exercising every applicable estimation method |
| D7 | Reporting | **Quarto report as the primary artifact**, verdict embedded; occamsqual-style plain-text verdict also emitted for pipeline compatibility |
| D8 | Threading | **Single-threaded canonical baseline + multi-threaded thread-invariance check**; two parallelism layers never both active (§7.3) |
| D9 | Model prep | **Bare PK templates augmented with IIV via `nlmixr2lib::addEta()`** per a registry `eta` column; same augmentation used for simulation, fit, and baseline (§3.0) |

---

## 3. Data provenance (D5)

### 3.0 Model augmentation with random effects (D9)

The bare `PK_*` templates in `nlmixr2lib` are **fixed-effects skeletons** — they
carry `ini` starting values and a residual-error term but **no between-subject
random effects (IIV)**. Fitting them as-is is a naive-pooled fit: no omegas to
compare, a failing covariance step, and no exercise of what the population
methods (SAEM/FOCEI/…) exist to do. A *population* qualification must fit genuine
mixed-effects models.

Therefore each registry entry carries an **`eta` specification** (the parameters
that receive IIV), and the model is augmented before use via
**`nlmixr2lib::addEta()`**. The **same augmentation is applied in all three
places** so they stay identical: the one-time dataset simulation, the
qualification-time fit (`qual_fit_entry`), and the baseline cut — all derive the
augmented model from the registry `eta` column, the single source of truth. An
empty `eta` means the model already carries its own random-effects structure
(true of most literature models: Hansson, Schindler, the disease/therapeutic-area
models) and is used verbatim.

Augmentation makes the simple PK anchors real population models (estimable
omegas, a working covariance step, meaningful SEs) while keeping them small and
robust enough to fit under all 26 estimation methods.

### 3.1 Pairing models with data

Models in `nlmixr2lib` are **structural templates**: they carry initial
parameter estimates and residual-error structure but **no data**. Fitting
requires data (using the augmented model of §3.0), so each model is paired with a
dataset by one of two routes:

1. **Frozen simulated dataset (default).** Each model's dataset is simulated
   **exactly once, at package inception**, with a fixed seed via `rxode2` from
   the template's own parameters over a defined dosing/observation design. The
   resulting dataset is **committed to `inst/data/` as a static file and never
   regenerated** — regardless of platform, R version, or nlmixr2 version. Every
   qualification run, on every environment, fits these identical bundled bytes.
   - Generalises to all four domains (real datasets exist only for a few PK
     models).
   - **Decouples the simulator's own platform dependence from the
     qualification.** Simulation runs through rxode2, which is itself
     platform/version-dependent; by freezing the output once, that dependence is
     removed entirely and never re-enters the suite.
   - Pairs with D1/D2: the data are a fixed input, so the **only** moving part
     between a run and its baseline is the estimation acting on identical bytes.
2. **Canonical real dataset.** Where an established dataset exists (e.g.
   `theo_sd`, `warfarin` from `nlmixr2data`), the model is paired with it
   instead of a simulated one. Recorded per-model in the registry. These are
   equally static.

**Datasets are immutable for the life of the package.** They are **not**
regenerated on nlmixr2 upgrade, on a baseline recut, or on any platform change.
The simulation designs and the generation script are retained in the repo
**solely as provenance** — documenting how the bundled data were produced — not
as a step that any run, recut, or platform port re-executes. A baseline recut
(D2) re-fits the **existing** frozen data on the new nlmixr2 version; it does not
touch the data.

---

## 4. Method coverage (D6)

nlmixr2 exposes **26 user-facing estimation methods across 6 mathematical
categories** (authoritative source: `nlmixr2est:::.nlmixr2EstTypeInfo`, exposed
via `nlmixr2AllEstType()`):

| Category | Methods |
|----------|---------|
| **Linearized** | `fo`, `foi`, `foce`, `focei`, `focep`, `nlme` |
| **Integral approximation** | `laplace`, `agq`, `imp`, `impmap` |
| **Stochastic EM** | `saem`, `fsaem`, `qrpem` |
| **Nonparametric** | `npag`, `npb` |
| **Machine learning** | `advi`, `vae` |
| **Optimizer (NLM family)** | `nlm`, `nlminb`, `bobyqa`, `newuoa`, `uobyqa`, `n1qn1`, `lbfgsb3c`, `optim`, `nls` |

(`posthoc`, `rxSolve`, `simulate` are post-processing / utility methods, not
estimation methods, and are excluded from method coverage. Internal algorithmic
variants such as `ifocei`, `mfocei`, `focef` are not user-facing `est=` values
and are exercised implicitly through their parent method.)

"All estimation methods" is **not** a full model × method cross-product (that
would be a ~24 × 26 explosion of stochastic fits). Coverage is achieved in two
layers.

### 4.1 Primary method per model
Every model in the set has one **designated primary method** — the natural fit
for that model (typically `focei` or `saem`). This is the fit reproduced in full
against baseline and shown in the per-model report section.

### 4.2 Category-structured method-coverage matrix
**All 26 methods** are exercised on a small set of well-behaved **anchor models**
and baselined, organised by the 6 categories:

- Population-style methods (Linearized, Integral approximation, Stochastic EM)
  are exercised on the mixed-effect anchor models.
- **Nonparametric** (`npag`, `npb`) and **Machine learning** (`advi`, `vae`)
  methods are exercised on an anchor model but compared with
  **category-appropriate quantities** (see §6.2), since they do not produce the
  same point-parameter set.
- **Optimizer (NLM family)** methods are exercised on a **no-random-effect**
  variant of an anchor model (they fit fixed effects only; they do not estimate
  a full population model).

This guarantees **every registered method appears in the qualification**, with
baselines, without a combinatorial blow-up. The report renders this as a
category-grouped method × anchor matrix of PASS/FAIL cells.

### 4.3 Per-method strict/informational flag
Each method carries a strict-vs-informational flag in the registry, defaulting
to **strict**. A method whose output is inherently non-reproducible even under a
fixed seed (a risk for some ML/variational methods) may be marked
**informational** — run and reported, but not failing the overall verdict — the
same discipline occamsqual applies to its non-reproducible tests. The intent is
that all 26 are strict unless a method is demonstrably non-reproducible on the
qualified toolchain.

---

## 5. Model set (~24, all from nlmixr2lib)

Final selection confirmed at planning time; target 20–30. Indicative set:

### 5.1 Population PK (~8)
`PK_1cmt`, `PK_2cmt`, `PK_3cmt`, `PK_1cmt_des` (ODE form),
`PK_2cmt_no_depot`, `PK_1cmt_tmdd_qss` (TMDD), `PK_2cmt_mAb_Davda_2014` (mAb),
`Beal_2001_iv1cmt_bql`.

### 5.2 PKPD (~6)
Indirect-response `indirect_1cpt_stim_kin` and `indirect_1cpt_inhi_kout`,
an effect-compartment model, an Emax model, and
`Hansson_2013_sunitinib_myelosuppression`.

### 5.3 Disease modeling (~5)
`Delor_2013_alzheimer`, `Lee_2011_parkinson_progression`,
`VelezdeMendizabal_2013_multipleSclerosis`, `Choy_2016_T2DM_WHIG`,
`Hamuro_2017_DMD_6MWT`.

### 5.4 Exposure–response (~5)
`Schindler_2017_sunitinib_fatigue`, `Schindler_2017_sunitinib_hfs`,
`Schindler_2017_likert_pain`, a TB MTP model (`Chen_2017_TB_MTP_GPDI_mouse`),
and one continuous/TTE exposure–response model.

Models are loaded via `nlmixr2lib::readModelDb(name)`; the registry records the
exact `name` (or an inline definition when a needed model is not in the shipped
`modeldb`).

---

## 6. Compared quantities and tolerances (D3)

### 6.1 Default comparison set (parametric methods)

For a standard parametric fit (Linearized, Integral approximation, Stochastic EM
categories) the runner extracts and compares against baseline:

| Quantity | Notes |
|----------|-------|
| Objective function value (OFV) | Tightest tolerance |
| Fixed effects (thetas) | Tight tolerance |
| Random-effect variances (omegas) | Tight tolerance |
| Residual error (sigmas) | Tight tolerance |
| Standard errors / RSEs | Looser tolerance (compiler-noise sensitive) |
| Shrinkage (eta, eps) | Looser tolerance |
| Convergence / minimization status | Exact match |

### 6.2 Category-appropriate comparison quantities

The default set does not map onto every category. The comparator selects a
**quantity profile by method category**:

- **Parametric** (Linearized, Integral approximation, Stochastic EM) — the full
  §6.1 set.
- **Optimizer (NLM family)** — OFV/objective and fixed effects only (no random
  effects estimated); convergence status.
- **Nonparametric** (`npag`, `npb`) — the estimated **support-point
  distribution** summaries (e.g. distribution means/variances and the objective)
  rather than point omegas.
- **Machine learning** (`advi`, `vae`) — the **variational objective / ELBO** and
  the resulting parameter summaries the method does expose.

The registry records each method's category, and the comparator dispatches on it
so a method is only ever compared on quantities it actually produces.

### 6.3 Reproducibility axis (independent of display category)

Seed handling and noise tolerance are driven by whether a method is
**stochastic** or **deterministic**, *not* by the upstream display category. The
two do not coincide: `imp` and `impmap` are labelled "Integral approximation" by
nlmixr2est but are, by their own source, **Monte Carlo importance-sampling EM** —
seeded, iterative, stochastic. Keying reproducibility handling off the display
category would wrongly treat them as deterministic.

The registry therefore tags each method on a `stochastic` axis independently:

- **Deterministic:** the Linearized family (`fo`, `foi`, `foce`, `focei`,
  `focep`, `nlme`), the deterministic integral methods (`laplace`, `agq`), and
  the Optimizer (NLM family) methods. Reproducible up to platform numerical
  noise; no seed dependence.
- **Stochastic (Monte Carlo):** `saem`, `fsaem`, `qrpem`, **`imp`, `impmap`**,
  `npag`, `npb`, `advi`, `vae`. Each sets a **fixed seed** so run-to-run
  variation is removed and only installation drift remains, and each carries a
  looser default tolerance.

The report still **displays** each method under nlmixr2's own category (from
`nlmixr2AllEstType()`), so the matrix matches upstream documentation; only the
seed and tolerance logic use the `stochastic` tag.

### 6.4 Tolerance policy
- **Relative tolerance by quantity class.** Default deterministic values:
  `1e-3` for OFV / thetas / omegas / sigmas, `0.05` for SEs / RSEs / shrinkage.
- **Stochastic methods carry a looser class default** (per §6.3): `1e-2` for
  OFV / point parameters, `0.10` for SEs / RSEs / shrinkage.
- **Thread-invariance tolerance** (§7.3): a separate, looser relative tolerance
  applied when comparing a multi-threaded re-fit against the single-threaded
  canonical baseline (default `1e-2`), reflecting thread-count-dependent
  reduction order; informational for stochastic methods.
- **Convergence / minimization status** must match **exactly** regardless of
  tolerance class.
- **Per-model / per-method override** in the registry for cases that are
  legitimately noisier.
- A deviation exceeding tolerance on any **strict** quantity fails that model;
  the report shows the observed vs baseline value and the relative deviation.

---

## 7. Architecture

```
nlmixr2qual/
├── DESCRIPTION / NAMESPACE / LICENSE
├── R/
│   ├── registry.R        # read/validate the model spec registry
│   ├── run.R             # load spec → fit → extract quantities
│   ├── compare.R         # extracted fit vs baseline → deviation table
│   ├── capture.R         # baseline-capture entry point (deliberate recut)
│   ├── threads.R         # thread-budget controller (the ONLY thread setter)
│   ├── report.R          # assemble results → render Quarto
│   ├── verdict.R         # overall PASS/FAIL + plain-text emit
│   └── versiongate.R     # installed vs qualified package versions
├── data-raw/
│   └── simulate-datasets.R  # ONE-TIME provenance script that produced inst/data/
│                            #   (documentation only; never re-run by any workflow)
├── inst/
│   ├── models/           # model spec registry (one entry per model)
│   ├── data/             # permanently frozen simulated + real datasets (committed)
│   ├── baseline/         # committed canonical baseline (one file per model)
│   │                     #   + provenance.json (baseline environment)
│   ├── qualified_baseline.csv   # package-version gate baseline
│   └── report/           # Quarto template (.qmd) + assets
├── tests/
│   └── testthat/         # 3e, one file per model group, process-isolated
├── qualification_output/ # per-run artifacts (rendered report, plots)
├── run_qualification.R   # top-level runner (mirrors occamsqual)
└── qualify.bat           # Windows convenience wrapper
```

### 7.1 Components (single responsibility each)

- **Registry** — declarative list of models: `name`, source (`readModelDb` id or
  inline), dataset ref (frozen sim / real), primary method, tolerance overrides,
  domain, strict-vs-informational flag.
- **Runner** — for one registry entry: load model, attach dataset, fit with the
  specified method and fixed seed, extract the §6 quantities into a normalized
  structure. No comparison logic here.
- **Comparator** — pure function: `(extracted, baseline, tolerances) →`
  per-quantity deviation table with a PASS/FAIL per quantity and per model.
- **Baseline capture** — the *only* code path that writes to `inst/baseline/`.
  Run deliberately on the qualified machine when nlmixr2 is upgraded; never
  during a qualification run.
- **Dataset simulator** — a **one-time, provenance-only** script that produced
  the frozen `inst/data/` files at package inception. It is **not** part of the
  runner or the recut path and is never re-executed to regenerate data; it is
  retained only to document how the bundled datasets were made (§3).
- **Report builder** — collects comparator output + version gate + verdict and
  renders the Quarto report; also emits the plain-text verdict.
- **Version gate** — installed package versions vs `qualified_baseline.csv`
  (same mechanism as occamsqual test-00).
- **Thread-budget controller** (`threads.R`) — the *single* owner of all thread
  settings (`setRxThreads`, `setDTthreads`, `OMP_NUM_THREADS`,
  `MKL_NUM_THREADS`). Reads `NLMIXR2QUAL_INNER_THREADS`, enforces
  workers × inner-threads ≤ cores, and is invoked by a testthat setup helper in
  every worker and by the serial thread-invariance stage. No other component
  touches thread settings (§7.3).
- **Environment provenance** — captured at both baseline-recut and run time (OS,
  architecture, compiler/toolchain, BLAS/LAPACK backend, R version) into a
  `provenance.json` committed alongside the baseline (`inst/baseline/`), so the
  report can diff the run environment against the baseline environment (§8.1).

### 7.2 Test harness
testthat 3e, one file per model group, `Config/testthat/parallel: true` — one
subprocess per file to restore the process isolation the legacy `R CMD BATCH
--vanilla` model provided and to isolate compiled-solver state. Fits that are
inherently machine-variable (if any) are marked **informational**: their failure
is reported but does not fail the overall verdict; every other model is
**strict**.

### 7.3 Threading and parallelism (single- vs multi-threaded fitting)

nlmixr2/rxode2 fitting has **thread-level** parallelism inside each fit
(`rxode2::setRxThreads()`, `data.table::setDTthreads()`, `OMP_NUM_THREADS`,
`MKL_NUM_THREADS`), while the test harness has **process-level** parallelism
(testthat workers, one per file). These are two independent layers, and they
**must never both run at full width** — otherwise cores are oversubscribed
(workers × threads ≫ cores) and, critically, results become non-reproducible:
parallel reductions sum per-subject contributions in a thread-count-dependent
order (OFV/gradients differ at ~1e-10), and stochastic methods partition their
per-thread RNG streams by thread count.

**Thread count is therefore a qualification axis, not just a performance knob.**

#### Thread-budget controller
A single controller function owns all four thread settings and is the *only*
code that sets them. It reads one environment variable,
`NLMIXR2QUAL_INNER_THREADS`, set by the top-level runner with knowledge of how
many testthat workers it launched, and applies it via
`setRxThreads()` / `setDTthreads()` / `OMP_NUM_THREADS` / `MKL_NUM_THREADS` so
that **workers × inner-threads ≤ available cores** always holds. A testthat
setup helper calls the controller at the start of every worker process, so no
worker can independently oversubscribe.

#### The non-collision guarantee (the two layers are never both active)
- **Strict baseline comparison runs single-threaded** (`inner-threads = 1`)
  under the parallel testthat workers: fixed reduction order (deterministic),
  K workers × 1 thread ≤ cores. This is the canonical, portable qualification.
- **Multi-threaded fitting is qualified serially** (workers = 1), *outside* the
  parallel testthat context, so a single process may use all cores with no
  collision.

#### Canonical baseline + thread-invariance check (locked, D8)
- The **canonical baseline is cut single-threaded** — maximally reproducible,
  reduction order fixed, portable across core counts.
- **Multi-threaded fitting is qualified by a thread-invariance check:** re-fit
  the anchor models with `N > 1` threads and confirm they reproduce the
  single-threaded canonical baseline **within a looser thread-invariance
  tolerance** (§6.4). This directly qualifies that multi-threaded fitting works
  and does not change results beyond tolerance, without a second baseline. For
  stochastic methods, where thread count repartitions the RNG stream, the
  invariance check is **informational** unless the method is demonstrably
  thread-count-reproducible.
- **Provenance records the thread configuration** at both recut and run time:
  the baseline is stamped single-threaded; each run records its inner-thread
  count and worker count in `provenance.json` and the report.

---

## 8. Reporting (D7)

### 8.1 Primary artifact — Quarto report
Rendered to HTML (and PDF/DOCX as configured), structured as:

1. **Executive summary** — overall PASS/FAIL verdict, R/nlmixr2 versions, host,
   date, the §1.1 scope-of-claim statement, and the §1.2 environment-sensitivity
   statement.
2. **Environment & version gate** — this run's environment provenance (OS,
   architecture, compiler/toolchain, BLAS/LAPACK backend, R version) shown
   **side by side with the baseline's recorded provenance**, with any difference
   flagged; plus installed vs qualified package versions and any mismatch.
3. **Per-domain sections** (popPK, PKPD, disease, exposure–response) — for each
   model: the fit summary, a **parameter-vs-baseline table** (observed,
   baseline, relative deviation, tolerance, PASS/FAIL) and a **deviation plot**.
4. **Method-coverage matrix** — category-grouped method × anchor-model PASS/FAIL
   grid, covering all 26 registered methods across the 6 categories.
5. **Thread-invariance section** — for each anchor model, the multi-threaded
   re-fit vs the single-threaded canonical baseline, its inner-thread count, the
   thread-invariance tolerance applied, and PASS/FAIL (or informational for
   stochastic methods), per §7.3.
6. **Interpretation** — for any failing model, the specific quantities that
   deviated and by how much, to direct investigation.
7. **Appendix** — full `sessionInfo()` and the run's thread configuration.

### 8.2 Pipeline-compatibility artifacts
For continuity with the occamsqual/QR workflow, the run also writes:
- `qualification_verdict.txt` — a single word, `PASS` or `FAIL`.
- `qualification_summary.txt` — a plain-text mirror of the verdict, version
  gate, and per-model result table.

---

## 9. Execution flow

```
run_qualification.R
  → version gate (installed vs qualified_baseline.csv)
  → set NLMIXR2QUAL_INNER_THREADS so workers × inner-threads ≤ cores
  --- STRICT STAGE (single-threaded, parallel testthat workers) ---
  → each worker: thread-budget controller pins inner-threads = 1
  → for each registry entry (parallel by group):
        load model + frozen dataset
        fit (primary method, fixed seed, single-threaded)
        extract §6 quantities
        compare vs inst/baseline/<model>
  → method-coverage matrix (anchor models × all 26 methods, single-threaded)
  --- THREAD-INVARIANCE STAGE (serial, workers = 1, all cores) ---
  → for each anchor model: re-fit multi-threaded (inner-threads = N)
        compare vs single-threaded canonical baseline @ invariance tolerance
        (informational for stochastic methods)
  → aggregate → overall verdict (strict models only)
  → render Quarto report → qualification_output/
  → emit qualification_verdict.txt + qualification_summary.txt
```

The two stages run **sequentially**: the parallel-worker strict stage completes
before the serial multi-threaded stage begins, so the process-level and
thread-level parallelism layers are never active simultaneously (§7.3).

Baseline recut (separate, deliberate):

```
capture.R
  → use the EXISTING frozen inst/data/ datasets (never regenerated)
  → fit every registry entry on the qualified nlmixr2 version
  → write inst/baseline/<model>, refresh qualified_baseline.csv + provenance.json
  → commit as the new canonical reference
```

The frozen datasets are never an input a recut modifies — a recut only re-fits
them.

---

## 10. Dependencies

- **Runtime:** `nlmixr2`, `nlmixr2est`, `nlmixr2lib`, `rxode2`, `nlmixr2data`,
  `qs2` (modeldb read), `quarto` / `rmarkdown`, `ggplot2`.
- **Harness:** `testthat` (≥ 3.0.0), `pkgload`, `withr`.
- **Report:** Quarto CLI; a LaTeX engine only if PDF output is enabled.
- Version-gated package baseline captured at qualification time (as occamsqual).

---

## 11. Explicitly out of scope (this version)

- **Accuracy-against-known-truth** (parameter recovery from simulation) — a
  different qualification class; may layer on later.
- **External reference comparison** (NONMEM/Monolix OFV/parameter agreement) —
  strongest regulatory claim but requires curating external reference results;
  deferred.
- **Per-install self-captured baselines** — rejected (a broken install would
  bless its own wrong answers).
- **Full model × method cross-product** — rejected in favour of the §4 coverage
  strategy.

---

## 12. Open items for planning

- Final model list frozen to exactly N (20–30) with confirmed `nlmixr2lib`
  availability of each `name`.
- Concrete default tolerance values per quantity class.
- Simulation design parameters (N, dosing, sampling) per model.
- Anchor-model selection and the exact method-to-category applicability map
  (which of the 26 methods run on which anchor, and each one's comparison
  quantity profile per §6.2).
- Confirmation of `nlmixr2AllEstType()` as the runtime source of the method list
  so the suite tracks methods added to nlmixr2est over time.
- Whether PDF/DOCX report outputs are in the default run or HTML-only.
