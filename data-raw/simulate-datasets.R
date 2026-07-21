# data-raw/simulate-datasets.R  (provenance only; do not re-run in CI)
#
# Generates the frozen, single-threaded, fixed-seed dataset(s) committed under
# inst/data/. Each dataset is simulated ONCE and then never regenerated -- it
# is a static artifact for the life of the package, independent of platform/
# R/nlmixr2 version. This script is provenance documentation, not a runtime
# dependency of the package.
#
# Each block writes its CSV only when the file does not already exist, so a
# re-run can regenerate a NEW model's data without clobbering the datasets that
# are already frozen and committed (spec D5: permanently frozen data). Seeds are
# fixed per block, so regeneration is deterministic in any case.
#
# Scope note (2026-07-20): this build ships a robust CORE of models that
# simulate and fit cleanly single-threaded -- the five bare PK templates
# (augmented with IIV per the registry `eta` column) and two continuous
# disease-progression models that already carry their own IIV. The heavier
# literature models (indirect-response PKPD whose templates observe only plasma
# Cc, multi-endpoint / ordered-categorical / multi-drug models) are tracked as
# a follow-up phase; they need bespoke, covariate-aware or categorical
# simulation designs that the "one et() block" pattern below does not cover.

library(nlmixr2)
library(nlmixr2lib)
library(rxode2)
library(lotri)

rxode2::setRxThreads(1L)

out_dir <- file.path("inst", "extdata")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Write only if not already frozen; keeps committed datasets immutable.
write_frozen <- function(df, file) {
  path <- file.path(out_dir, file)
  if (file.exists(path)) {
    message("skip (already frozen): ", file)
    return(invisible(path))
  }
  write.csv(df, path, row.names = FALSE)
  message("wrote: ", file, "  (", nrow(df), " rows)")
  invisible(path)
}

# ---- PK family helper ------------------------------------------------------
#
# The shipped bare PK templates (PK_2cmt, PK_3cmt, PK_2cmt_no_depot) have NO
# random effects. Per the registry `eta` column they
# are augmented with IIV on lcl and lvc via nlmixr2lib::addEta() -- this
# augmented model (real etaLcl/etaLvc random effects and a real omega) is both
# the model the data is simulated from AND the model qualified against the
# baseline, so there is a genuine between-subject signal for the omegas and a
# valid (non-degenerate) covariance step.
#
# Oral templates dose the depot (CMT=1) and observe central (CMT=2). The IV
# template (PK_2cmt_no_depot) doses and observes central (CMT=1).
sim_pk_family <- function(name, file, oral = TRUE, seed = 20260717,
                          true = c(lka = 0.4, lcl = 0.9, lvc = 3.3, propSd = 0.15)) {
  set.seed(seed)
  # addEta() returns an UNEVALUATED UI function; evaluate to an rxUi so $iniDf
  # is inspectable and rxSolve/nlmixr2 get a concrete model.
  aug <- rxode2::rxode2(nlmixr2lib::addEta(readModelDb(name), c("lcl", "lvc")))
  # ~30% CV BSV on CL and Vc, uncorrelated.
  omega <- lotri::lotri(etaLcl + etaLvc ~ c(0.09, 0, 0.09))

  n_subjects <- 32
  dose_levels <- c(50, 100, 150, 200)                # mg
  obs_times   <- c(0.25, 0.5, 1, 2, 4, 8, 12, 24)     # hr
  dose_cmt <- 1L
  obs_cmt  <- if (oral) 2L else 1L

  recs <- vector("list", n_subjects)
  for (i in seq_len(n_subjects)) {
    dose <- dose_levels[((i - 1) %% length(dose_levels)) + 1]
    dose_rec <- data.frame(ID = i, TIME = 0, AMT = dose, EVID = 1, CMT = dose_cmt)
    obs_rec  <- data.frame(ID = i, TIME = obs_times, AMT = 0, EVID = 0, CMT = obs_cmt)
    recs[[i]] <- rbind(dose_rec, obs_rec)
  }
  ev <- do.call(rbind, recs)
  ev <- ev[order(ev$ID, ev$TIME, -ev$EVID), ]

  # true[] only carries the params present in the (augmented) model; drop any
  # names the model does not use so rxSolve does not complain.
  mp <- aug$iniDf$name
  params <- true[names(true) %in% mp]

  sol <- rxSolve(aug, ev, params = params, omega = omega, nSub = n_subjects)
  solDf <- as.data.frame(sol)

  final <- data.frame(ID = ev$ID, TIME = ev$TIME, AMT = ev$AMT,
                      EVID = ev$EVID, CMT = ev$CMT, DV = NA_real_)
  final$DV[final$EVID == 0] <- solDf$sim
  final$DV[final$EVID == 1] <- 0
  stopifnot(all(final$DV[final$EVID == 0] > 0))
  write_frozen(final, file)
}

# The one-compartment slots (solved + ODE) are now covered by the theo_1cmt /
# theo_1cmt_des models on real theophylline data, so no bare 1-cmt template is
# simulated here.
sim_pk_family("PK_2cmt",          "PK_2cmt_sim.csv",          oral = TRUE)
sim_pk_family("PK_3cmt",          "PK_3cmt_sim.csv",          oral = TRUE)
sim_pk_family("PK_2cmt_no_depot", "PK_2cmt_no_depot_sim.csv", oral = FALSE)

# ---- Lee_2011_parkinson_progression (disease) ------------------------------
#
# Disease-progression model of the Unified Parkinson's Disease Rating Scale
# change from baseline (deltaUPDRS), algebraic in time with a symptomatic drug
# effect. It already carries its own IIV (etaslope, etasymeff) so it is used
# verbatim (registry eta blank). Needs the binary ON_TREATMENT covariate; half
# the cohort is randomised to active treatment. No dosing compartment -- every
# record is an observation.
local({
  set.seed(20260717)
  ui <- rxode2::rxode2(readModelDb("Lee_2011_parkinson_progression"))
  n <- 40
  times <- c(0, 3, 6, 9, 12, 18, 24)                 # months
  recs <- lapply(seq_len(n), function(i)
    data.frame(ID = i, TIME = times, EVID = 0L, DV = NA_real_,
               ON_TREATMENT = as.integer(i %% 2 == 0)))
  ev <- do.call(rbind, recs)
  sol <- rxSolve(ui, ev, nSub = n)
  ev$DV <- as.data.frame(sol)$sim
  stopifnot(all(is.finite(ev$DV)))
  write_frozen(ev, "Lee_2011_parkinson_sim.csv")
})

# ---- Hamuro_2017_DMD_6MWT (disease) ----------------------------------------
#
# Duchenne muscular dystrophy 6-minute-walk-test (walkDist) progression: a
# rise-then-decline bilinear function of AGE (min of a developmental gain line
# and a decline line). Carries its own IIV (etalslope_dev, etalslope_decl), so
# used verbatim. Needs a time-varying AGE covariate; each child enters at a
# baseline age (5-10 yr) and is followed over 3 years. No dosing.
local({
  set.seed(20260717)
  ui <- rxode2::rxode2(readModelDb("Hamuro_2017_DMD_6MWT"))
  n <- 40
  visits <- c(0, 0.5, 1, 1.5, 2, 2.5, 3)             # years from entry
  recs <- lapply(seq_len(n), function(i) {
    base_age <- 5 + (i %% 6)
    data.frame(ID = i, TIME = visits, EVID = 0L, DV = NA_real_,
               AGE = base_age + visits)
  })
  ev <- do.call(rbind, recs)
  sol <- rxSolve(ui, ev, nSub = n)
  ev$DV <- as.data.frame(sol)$sim
  stopifnot(all(is.finite(ev$DV)))
  write_frozen(ev, "Hamuro_2017_dmd_sim.csv")
})

message("done: dataset generation")
