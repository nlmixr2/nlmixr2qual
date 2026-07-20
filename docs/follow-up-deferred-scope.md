# Deferred scope — follow-up phases

The initial build ships a **robust core** that qualifies cleanly and
reproducibly single-threaded. The items below were deliberately deferred because
they need bespoke work well beyond the "one registry row + one `et()` block"
pattern the core uses. They are captured here so a later phase can pick them up
with full context.

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
  `PK_1cmt_fixed` (`needs_reff = FALSE`).

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
