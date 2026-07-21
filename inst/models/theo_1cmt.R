# theo_1cmt: the canonical nlmixr2 one-compartment oral model, fit to the real
# theophylline single-dose dataset (nlmixr2data::theo_sd, frozen to
# inst/extdata/theo_sd.csv). This is the textbook nlmixr2 example and serves as a
# well-behaved base/sanity popPK case built on genuine (not simulated) data.
# First-order absorption, one disposition compartment solved with linCmt(), IIV
# on Ka/CL/V, and an additive residual. Loaded verbatim via
# qual_prepare_model(source = "file"), so its `eta` in the registry is blank.
theo_1cmt <- function() {
  ini({
    ## You may label each parameter with a comment
    tka <- 0.45 # Log Ka
    tcl <- log(c(0, 2.7, 100)) # Log Cl
    ## This works with interactive models
    ## You may also label the preceding line with label("label text")
    tv <- 3.45; label("log V")
    ## the label("Label name") works with all models
    eta.ka ~ 0.6
    eta.cl ~ 0.3
    eta.v ~ 0.1
    add.sd <- 0.7
  })
  model({
    ka <- exp(tka + eta.ka)
    cl <- exp(tcl + eta.cl)
    v <- exp(tv + eta.v)
    linCmt() ~ add(add.sd)
  })
}
