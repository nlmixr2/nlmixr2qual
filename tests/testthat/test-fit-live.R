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

test_that("qual_prepare_model augments a bare template with random effects", {
  skip_if_not_installed("nlmixr2lib")
  # readModelDb() returns an unevaluated UI model function; rxode2::rxode2()
  # evaluates it into an rxUi object so $iniDf can be inspected (same
  # evaluation qual_prepare_model performs internally).
  bare <- rxode2::rxode2(nlmixr2lib::readModelDb("PK_1cmt"))
  aug  <- qual_prepare_model(list(name = "PK_1cmt", source = "lib", eta = "lcl,lvc"))
  # the augmented model's parameter table has more omega/eta entries than the bare one
  expect_gt(sum(grepl("eta", aug$iniDf$name, ignore.case = TRUE)),
            sum(grepl("eta", bare$iniDf$name, ignore.case = TRUE)))
})
