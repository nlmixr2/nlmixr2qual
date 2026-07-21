# theo_1cmt_fixed: the theophylline one-compartment oral model with
# between-subject variability removed (fixed effects only). This is the anchor
# for the needs_reff = FALSE optimizer methods in the method-coverage matrix,
# which fit fixed effects only and cannot estimate random-effect variances. It
# replaces the earlier PK_1cmt_fixed anchor now that theo_1cmt is the shipped
# one-compartment anchor. Used with source = "file" and an empty `eta` so
# qual_prepare_model() loads it verbatim.
theo_1cmt_fixed <- function() {
  ini({
    tka <- 0.45   # log Ka
    tcl <- 1      # log CL
    tv  <- 3.45   # log V
    add.sd <- 0.7 # additive residual SD
  })
  model({
    ka <- exp(tka)
    cl <- exp(tcl)
    v  <- exp(tv)
    linCmt() ~ add(add.sd)
  })
}
