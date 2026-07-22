# Deferred scope — follow-up phases

The initial build ships a **robust core** that qualifies cleanly and
reproducibly single-threaded. The items below were deliberately deferred because
they need bespoke work well beyond the "one registry row + one `et()` block"
pattern the core uses. They are captured here so a later phase can pick them up
with full context.

## 0. Next actions — requested 2026-07-21

Three specific changes to make before the broader deferred work below. Each
touches the frozen datasets and/or the shipped baseline, so each ends with a
deliberate recut and a refresh of [`models-and-methods.md`](models-and-methods.md).

### 0.1 Replace the Hamuro dataset design — no invalid (negative) simulated data — ✅ DONE 2026-07-21 (option 3: model replacement)

Resolved by **option 3** — replaced `Hamuro_2017_DMD_6MWT` with
**`Friberg_2002_paclitaxel`** (the classic semi-mechanistic myelosuppression
model, domain PKPD). Its endpoint is a circulating WBC count with a proportional
residual, so simulated values are non-negative by construction. Frozen dataset:
32 subjects, single moderate paclitaxel dose (8/12/16 — kept mild so the 7-ODE
system stays non-stiff and the WBC nadir clears zero), WBC sampled to day 28,
individual PK as `VC/CL/VP_INDIV` covariate columns, `stopifnot(all(DV > 0))`
guard. Baseline `Friberg_2002_paclitaxel__focei.qs2` cut (OFV 924.58, converged,
analytic covariance). Added a PKPD domain + `test-qual-PKPD.R`; Hamuro dataset,
baseline, figure, and sim block removed. The original options are kept below for
the record.



**Problem.** The frozen `Hamuro_2017_dmd_sim.csv` contains negative 6-minute-walk
distances for the steepest decliners: the verbatim model uses an **additive**
residual (`walkDist ~ add(addSd)`, SD ≈ 57 m) and a steep decline arm, so at older
ages prediction + noise crosses zero. A qualification test suite must not ship
physically invalid data, even as a regression reference.

**Constraint.** The model is used *verbatim* (it carries its own IIV), so the
error model (`add`) cannot be changed without abandoning the "verbatim template"
principle. Only the **simulation design** (age range, follow-up, n) is ours to
choose.

**Approach — in order of preference:**

1. **Bounded-age recut.** Restrict the baseline age and follow-up so the whole
   simulated population stays comfortably positive. The decline arm
   (`walk_decl = 1298 − 84.9·AGE`, with IIV widening the slope to roughly
   −67…−107 m/yr) drops toward the noise floor past ~age 11–12; keeping
   **max age ≲ 10** leaves even the steepest decliner (worst-case IIV − 3σ noise)
   above zero while still exercising the dev/decline `min()` crossover (~age 9.8).
   Add `stopifnot(all(DV > 0))` to the sim block so an out-of-range design fails
   loudly.
2. **Truncated-at-zero resampling.** If a positive design that still exercises the
   decline arm proves too tight, resample any subject-observation whose simulated
   `DV ≤ 0` (a truncated-normal residual). Keeps the model and the age range but
   slightly perturbs the residual distribution — acceptable for a regression
   reference, note it in provenance.
3. **Replace the model.** If neither is satisfactory, swap Hamuro for an
   alternative disease-progression model with a naturally non-negative endpoint
   (candidate short-list to be drawn from the `nlmixr2lib` PD/therapeuticArea sets,
   verified to fit cleanly single-threaded like Lee/Hamuro were).

Recommendation: try (1) first — it is the smallest change and keeps the model.
After the recut, re-cut `Hamuro_2017_DMD_6MWT__focei.qs2`, regenerate the
spaghetti plot, and drop the "negative values" caveat from `models-and-methods.md`.

### 0.2 Add the theophylline one-compartment model as a base case (real data) — ✅ DONE 2026-07-21

Implemented: `theo_1cmt` — the canonical nlmixr2 one-compartment oral model
(solved `linCmt()`, IIV on Ka/CL/V, additive residual), fit to the **real**
`nlmixr2data::theo_sd` dataset frozen verbatim to `inst/extdata/theo_sd.csv`
(144 rows, 12 subjects). Shipped as `source = "file"`
(`inst/models/theo_1cmt.R`), registry row `theo_1cmt` (popPK, focei, strict,
**non-anchor** — kept non-anchor so the anchor set stays `{PK_1cmt, PK_2cmt}` and
its registry-test assertion is unchanged). Baseline `theo_1cmt__focei.qs2` cut
(OFV 116.80, converged, cov `r,s`); reproduces its baseline (compare pass). Added
to `models-and-methods.md` with a spaghetti plot. R CMD check remains OK.

### 0.3 Drop FOCE as the anchor method; use SAEM instead — ✅ DONE 2026-07-22

Implemented. `theo_1cmt__foce.qs2` removed; `theo_1cmt__saem.qs2` cut instead
(OFV 122.01, converged, cov `linFim`). `qual_fit_control()` now returns a pinned
`saemControl(seed = 99, nBurn = 200, nEm = 300)` for `est = "saem"`, so the
stochastic run is reproducible (a same-machine re-fit gave a bit-identical OFV
and passed `qual_compare` under the stochastic tolerance). `saem` is marked
`strict = FALSE` (informational) in `methods.csv` — it is reported but does not
gate the verdict, since seeded SAEM is not guaranteed to reproduce across
platforms. Docs (`models-and-methods.md`) updated. Original notes kept below.



- Remove the `theo_1cmt__foce.qs2` anchor baseline; cut `theo_1cmt__saem.qs2` instead.
- **SAEM is stochastic**, so reproducibility requires a **pinned seed** (and fixed
  `nBurn`/`nEm` iteration counts) via `saemControl(seed = …)`. Extend
  `qual_fit_control()` to return the pinned SAEM control for `est = "saem"` (it
  currently only special-cases the FOCE-conditional family → `bobyqa`).
- Qualify SAEM under the **looser stochastic tolerance** (`qual_tolerance(...,
  stochastic = TRUE)`); it is already flagged `stochastic = TRUE` in
  `methods.csv`. Decide whether it gates the verdict (strict) or is
  informational — recommend **informational** first (spec §6.3), tighten to strict
  only if seed-pinned reproduction proves tight across a couple of runs.
- Update `test-qual-methods.R`, the coverage table and prose in
  `models-and-methods.md`, and note the seed in the baseline provenance.

## 1. Additional models (registry breadth)

The core registry covers 7 models across 2 domains (popPK, disease). The
following `nlmixr2lib` models were evaluated but deferred; all resolve via
`readModelDb()` but resist the generic simulate-and-fit pattern:

| Model | Domain | Why deferred |
|---|---|---|
| `indirect_1cpt_stim_kin` / `_inhi_kout` / `_stim_kout` / `_inhi_kin` | PKPD | Templates observe only plasma `Cc`; the PD parameters (kin/kout/ec50/emax) are unidentifiable from that single endpoint, so they are poor reproducibility anchors. Needs a model variant that also observes the effect compartment. |
| `Venisse_2008_caspofungin` | PKPD | Tumour growth/kill PD dynamics; the covariance step fell back and the fit did not report cleanly with a generic dose design. Needs a tuned dosing/observation schedule. |
| `PK_1cmt_tmdd_qss`, `PK_2cmt_mAb_Davda_2014` | popPK | TMDD / mAb models with specific dosing regimens and correlated-eta blocks. |
| `Beal_2001_iv1cmt_bql` | popPK | Below-quantification-limit (M3) handling — needs censored-data simulation and CENS columns. |
| `Choy_2016_T2DM_WHIG` | disease | Four simultaneous endpoints (WGT/FSI/FPG/HbA1c), 21 thetas, multiple covariates — needs a multi-endpoint dataset with correct CMT/DVID coding. |
| `Chen_2017_TB_MTP_GPDI_mouse` | ER | Four-drug, 33-theta multi-scale TB model with no IIV — needs multi-drug dosing and a covariate-rich design. |
| `Schindler_2017_sunitinib_fatigue` / `_hfs` / `_likert_pain` | ER | Ordered-categorical / Likert outcomes — integer category simulation and fitting, not continuous DV. |
| `Hansson_2013_sunitinib_myelosuppression` | PKPD | Myelosuppression with a JAPANESE covariate and a feedback loop. |
| `Delor_2013_alzheimer`, `Lee_2011_parkinson` (extra scales), `VelezdeMendizabal_2013_multipleSclerosis`, `Hamuro_2017` (extra endpoints) | disease | Multi-scale / count-outcome disease models. |

`nlmixr2data` ships **no** matching real datasets for these literature models, so
each needs a bespoke simulation design (verified to fit before its dataset is
frozen).

## 2. Full 26-method coverage matrix

`inst/models/methods.csv` catalogues all 26 estimators across 6 categories, but
the shipped anchor baselines cover only the reliable conditional-estimation
methods (`focei`, `foce`). To complete the matrix, cut `<anchor>__<method>.qs2`
baselines for the remaining methods and confirm each fits the anchor cleanly:

- **Linearized**: `fo`, `foi` (first-order — note they reject
  `foceiControl(outerOpt=)`, so `qual_fit_control()` leaves them on their default
  control), `focep`, `nlme`.
- **Integral approximation**: `laplace`, `agq`, `imp`, `impmap`.
- **Stochastic EM**: `saem`, `fsaem`, `qrpem` (stochastic — seed control needed;
  qualify under the looser stochastic tolerance, likely informational).
- **Nonparametric** (`npag`, `npb`) and **Machine learning** (`advi`, `vae`):
  their fit objects do **not** expose the standard parametric accessors
  (`parFixedDf`/`omega`/`sigma`). `qual_extract_fit()` needs category-specific
  extraction (distribution summaries / ELBO) before these can be fingerprinted —
  flagged in the original plan's self-review as an unexercised extension point.
- **Optimizer (NLM family)**: `nlm`, `nlminb`, `bobyqa`, `newuoa`, `uobyqa`,
  `n1qn1`, `lbfgsb3c`, `optim`, `nls` — fit the fixed-effect-only anchor
  `theo_1cmt_fixed` (`needs_reff = FALSE`).

## 3. Environment robustness

Multi-threaded fitting is intermittently unstable on the many-core development
box (OpenMP solver crash). Mitigations already in place: the invariance thread
count is capped (`qual_invariance_threads()`, default 4) and the invariance stage
runs in an isolated `callr` child process. If parallel `testthat` remains
unstable in CI, keep running the live qualification via `run_qualification.R`
(fresh process per stage) rather than the in-process test runner.

**Corrupted rxode2 model cache → strict-stage crashes.** Running many
concurrent nlmixr2 fits (parallel test files, `devtools::check`, and the
baseline cut at the same time) can corrupt the shared rxode2 compiled-model
cache (`rxode2::rxTempDir()` / `AppData/Local/R/cache/R/rxode2`), after which even
the single-threaded strict stage crashes part-way through. Symptom: the runner
dies mid-fit with no verdict and no `qualification_output/`. Remedy: run
`rxode2::rxClean()` once, then re-run `run_qualification.R`. Avoid running the
suite concurrently with other processes that compile the same models.
