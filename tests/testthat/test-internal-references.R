test_that("shipped internal references include the mandatory t1 set and validate", {
  refs <- qual_load_references("internal")
  expect_true("theophylline__focei__t1" %in% names(refs))    # t1 mandatory
  for (r in refs) expect_true(qual_reference_validate(r))
  # thread counts are always 1 (mandatory) or the optional default multi (t4)
  expect_true(all(vapply(refs, function(r) r$reference$threads, integer(1))
                  %in% c(1L, qual_default_multi_threads())))
})

test_that("internal references re-fit and match on this box (strict methods)", {
  skip_if_no_live()
  refs <- qual_load_references("internal")
  # only qualify references whose thread count this box can run natively; a t4
  # reference is optional and only reproduces on a >= 4-core machine.
  cap <- qual_invariance_threads()
  runnable <- names(refs)[vapply(refs, function(r) r$reference$threads,
                                 integer(1)) <= cap]
  res <- qualify(runnable, "internal")
  strict <- res$summary[res$summary$strict, ]
  expect_true(all(strict$pass),
              info = paste(strict$id[!strict$pass], collapse = ", "))
  expect_true(res$overall)
})
