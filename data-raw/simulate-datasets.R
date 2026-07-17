# data-raw/simulate-datasets.R  (provenance only; do not re-run in CI)
#
# Generates the frozen, single-threaded, fixed-seed dataset(s) committed under
# inst/data/. Each dataset is simulated ONCE and then never regenerated -- it
# is a static artifact for the life of the package, independent of platform/
# R/nlmixr2 version. This script is provenance documentation, not a runtime
# dependency of the package.
#
# PK_1cmt: the shipped nlmixr2lib template has NO random effects (fixed
# effects only: lka, lcl, lvc, propSd). Per the registry's `eta` column
# (inst/models/registry.csv), PK_1cmt is qualified as a genuine population
# model by adding IIV on lcl and lvc via nlmixr2lib::addEta() -- this augmented
# model (with etaLcl/etaLvc random effects and a real omega) is both the model
# the data is simulated from AND the model used for fitting/qualification, so
# there is a real between-subject signal for the omegas to estimate and a
# valid (non-degenerate) covariance step.

library(nlmixr2)
library(nlmixr2lib)
library(rxode2)
library(lotri)

rxode2::setRxThreads(1L)
set.seed(20260717)

# ---- PK_1cmt --------------------------------------------------------------

mod <- readModelDb("PK_1cmt")

# Augment with IIV per registry$eta ("lcl,lvc") so the model is a genuine
# population model (etaLcl, etaLvc random effects with estimable omegas).
aug <- nlmixr2lib::addEta(mod, c("lcl", "lvc"))

# True data-generating values (deliberately offset from the model's ini
# starting values -- lka=0.45, lcl=1, lvc=3.45, propSd=0.5 -- so the fit has
# real work to do recovering them).
true_lka    <- 0.4     # ka  = exp(0.4)  ~= 1.49 /hr
true_lcl    <- 0.9     # cl  = exp(0.9)  ~= 2.46 L/hr (population typical)
true_lvc    <- 3.3     # vc  = exp(3.3)  ~= 27.1 L    (population typical)
true_propSd <- 0.15    # 15% CV proportional residual error

# Between-subject variability: ~30% CV (log-normal SD 0.3, variance 0.09) on
# both CL and Vc, uncorrelated.
omega <- lotri::lotri(etaLcl + etaLvc ~ c(0.09, 0, 0.09))

n_subjects <- 32
dose_levels <- c(50, 100, 150, 200)                          # mg, oral
obs_times   <- c(0.25, 0.5, 1, 2, 4, 8, 12, 24)               # hr

# Build a single oral dose (depot, CMT=1) + observation schedule (CMT=2) per
# subject, cycling dose level across subjects for exposure-range coverage.
recs <- vector("list", n_subjects)
for (i in seq_len(n_subjects)) {
  dose <- dose_levels[((i - 1) %% length(dose_levels)) + 1]
  dose_rec <- data.frame(ID = i, TIME = 0, AMT = dose, EVID = 1, CMT = 1)
  obs_rec  <- data.frame(ID = i, TIME = obs_times, AMT = 0, EVID = 0, CMT = 2)
  recs[[i]] <- rbind(dose_rec, obs_rec)
}
ev <- do.call(rbind, recs)
ev <- ev[order(ev$ID, ev$TIME, -ev$EVID), ]

# Simulate individual PK (BSV via omega) + proportional residual error in one
# pass; rxSolve returns a `sim` column carrying the simulated DV with prop()
# residual noise applied on top of the individual (BSV) predictions.
sol <- rxSolve(
  aug, ev,
  params = c(lka = true_lka, lcl = true_lcl, lvc = true_lvc, propSd = true_propSd),
  omega = omega, nSub = n_subjects
)
solDf <- as.data.frame(sol)

# solDf contains only the observation rows (dosing rows are consumed, not
# echoed), in the same ID/TIME order as the observation subset of `ev`.
final <- data.frame(
  ID = ev$ID, TIME = ev$TIME, AMT = ev$AMT, EVID = ev$EVID, CMT = ev$CMT,
  DV = NA_real_
)
final$DV[final$EVID == 0] <- solDf$sim
final$DV[final$EVID == 1] <- 0

stopifnot(all(final$DV[final$EVID == 0] > 0))

out_path <- file.path("inst", "data", "PK_1cmt_sim.csv")
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
write.csv(final, out_path, row.names = FALSE)

# ---- verify: PK_1cmt (augmented with IIV on lcl, lvc) must cleanly fit ----
# via est="focei", with a finite OFV, estimated omegas, and a successful
# covariance step (SEs). The default nlminb outer optimizer converges to the
# same optimum as bobyqa here but reports "false convergence (8)" as an
# advisory; bobyqa reaches the identical OFV/estimates with a clean "Normal
# exit" message, so it is used for this verification run.
fit <- nlmixr2(
  aug, read.csv(out_path), est = "focei",
  control = nlmixr2est::foceiControl(outerOpt = "bobyqa")
)
print(fit)
stopifnot(is.finite(fit$objf))
stopifnot(identical(fit$covMethod, "r,s"))
cat("\nPK_1cmt_sim.csv verification: OBJF =", fit$objf,
    " covMethod =", fit$covMethod, "\n")
