# theo_1cmt_des: the canonical nlmixr2 one-compartment oral theophylline model
# written as explicit differential equations (the ODE-solver counterpart of the
# solved theo_1cmt). Same real dataset (nlmixr2data::theo_sd, frozen to
# inst/extdata/theo_sd.csv) and the same Ka/CL/V structure with IIV on each and
# an additive residual, but evaluated through the ODE solver rather than
# linCmt(), so the qualification exercises that code path on real data. Loaded
# verbatim via qual_prepare_model(source = "file"); its `eta` in the registry is
# blank.
theo_1cmt_des <- function() {
  ini({
    tka <- 0.45 # Log Ka
    tcl <- 1 # Log Cl
    tv <- 3.45    # Log V
    eta.ka ~ 0.6
    eta.cl ~ 0.3
    eta.v ~ 0.1
    add.sd <- 0.7
  })
  model({
    ka <- exp(tka + eta.ka)
    cl <- exp(tcl + eta.cl)
    v <- exp(tv + eta.v)
    d/dt(depot) = -ka * depot
    d/dt(center) = ka * depot - cl / v * center
    cp = center / v
    cp ~ add(add.sd)
  })
}
