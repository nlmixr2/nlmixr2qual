mk_ref <- function(model, method, threads) list(
  schema_version="1.0.0",
  id=paste0(model,"__",method,"__t",threads),
  model=list(name=model, code="x<-1", description=""),
  data=list(name="d", records=data.frame(ID=1)),
  method=list(est=method, control=NULL),
  reference=list(threads=threads, ofv=1, params=data.frame(), shrink=data.frame(),
                 converged=TRUE, covMethod="", stochastic=FALSE, category=""),
  provenance=list(software=list(), created="", source_bundle="",
                  nlmixr2save_version=""))

test_that("qual_load_references reads a folder keyed by id", {
  dir <- tempfile(); dir.create(dir)
  for (r in list(mk_ref("a","focei",1), mk_ref("a","focei",4), mk_ref("b","saem",1)))
    qual_reference_write(r, file.path(dir, paste0(r$id, ".json")))
  refs <- qual_load_references(source = dir)
  expect_setequal(names(refs), c("a__focei__t1", "a__focei__t4", "b__saem__t1"))
})

test_that("qual_select: all, by pair (all thread variants), and by full id", {
  refs <- list("a__focei__t1"=mk_ref("a","focei",1),
               "a__focei__t4"=mk_ref("a","focei",4),
               "b__saem__t1" =mk_ref("b","saem",1))
  expect_length(qual_select(refs, "all"), 3)
  expect_setequal(names(qual_select(refs, "a__focei")),        # pair -> both threads
                  c("a__focei__t1", "a__focei__t4"))
  expect_equal(names(qual_select(refs, "a__focei__t4")), "a__focei__t4")  # full id
  expect_error(qual_select(refs, "zzz__nope"), "no reference")
})
