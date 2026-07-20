# PK_1cmt_fixed: the PK_1cmt one-compartment oral template with between-subject
# variability removed (fixed effects only). This is the anchor model for the
# needs_reff = FALSE optimizer methods in the method-coverage matrix, which fit
# fixed effects only and cannot estimate random-effect variances. Used with
# source = "file" and an empty `eta` (no augmentation) so qual_prepare_model()
# loads it verbatim.
PK_1cmt_fixed <- function() {
  ini({
    lka <- 0.45
    lcl <- 1
    lvc <- 3.45
    propSd <- 0.5
  })
  model({
    ka <- exp(lka)
    cl <- exp(lcl)
    vc <- exp(lvc)
    Cc <- linCmt()
    Cc ~ prop(propSd)
  })
}
