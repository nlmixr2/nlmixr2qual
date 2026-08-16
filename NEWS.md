# nlmixr2qual 0.1.0

## Reference architecture (breaking change)

`nlmixr2qual` is re-architected from a frozen-fingerprint regression suite
(internal `.qs2` baselines cut on simulated data) into an import-based,
organisation-extensible qualification tool. References are known-good fits
imported from `nlmixr2save` bundles, stored one-per-file as self-contained
JSON, each tagged with the thread count that produced it; qualification
re-fits each reference locally at its own thread count and compares against
the stored reference fingerprint.

- New: `qual_import_bundle()`, `qual_reference_refit()`, `qualify()`,
  `qual_load_references()`, `qual_select()`, `qual_reference_read/write/validate()`,
  `qual_catalogue()`/`qual_catalogue_md()`, `qual_summary_text()`/`qual_summary_report()`.
- Removed: `qual_run()`, `qual_capture_baseline()`, `qual_registry()`,
  `qual_version_gate()`, `qual_read_dataset()`, `qual_prepare_model()`,
  `qual_verdict()`, `qual_write_text()`, the frozen `.qs2` baselines, the
  simulated-data registry, and the method matrix. Retained unchanged:
  the compare/tolerance/fingerprint/provenance engine and the thread-control
  engine (`R/threads.R`).
- Shipped internal reference set: the theophylline model
  (`nlmixr2data::theo_sd`) across 9 estimation methods (`agq`, `foce`,
  `focei`, `focep`, `imp`, `impmap`, `laplace`, `qrpem`, `saem`), each at
  `threads = 1` (mandatory, strict) and `threads = 4` (optional, looser
  thread-invariance tolerance). See `docs/references.md`.
- `qual_tolerance()` recalibrated: the invariance-mode floor no longer
  tightens a class's deterministic tolerance (it was backwards for
  `shrink`); deterministic `theta`/`omega`/`sigma` widened from 0.1% to 1%
  to absorb the warm-start-vs-cold-start drift inherent to re-fitting from a
  reconstructed model. Shrinkage comparisons are now reported but never gate
  the pass/fail verdict.
- `qual_import_bundle()` gains a `seed` argument for stochastic methods
  (`saem`, `fsaem`, `imp`, `impmap`, `qrpem`): explicit if supplied, else
  read off the bundle's own fit control if it was fit with one.
  `qual_reference_refit()` injects a stored seed into the method-appropriate
  control object, making a same-seed re-fit exactly reproducible. The
  shipped internal set's stochastic references are now seed-pinned (seed
  99) and all four reproduce cleanly (bit-identical OFV).
- `saem`/`fsaem`'s shipped model now fits `tcl` unbounded (`one.cmt.saem` in
  `data-raw/make-theophylline-references.R`), avoiding SAEM's internal
  bounded-theta reparameterization (`rxBoundedTr.tcl`) that previously kept
  the seeded re-fit from resetting `tcl` to its true cold-start prior. `saem`
  now reproduces exactly, like every other shipped method (see
  `docs/references.md`).
- The HTML report (`qual_summary_report()`) now includes a per-reference
  parameter/precision/OFV comparison table (reference vs. local re-fit),
  not just the coarse per-reference summary.
- New: `qual_import_fit()`, an in-memory alternative to `qual_import_bundle()`
  -- builds a reference directly from a live fit object still in the R
  session, with no `saveFit()`/`loadFit()` round-trip. Model source comes
  from `nlmixr2save::saveFitItem()` (the same code `saveFit()` uses for a
  bundle's `-ui.R`) called directly on `fit$ui`; input data and method come
  from `fit$origData`/`fit$est`. Shares `initial_estimates`/`seed`
  resolution and reference assembly with `qual_import_bundle()`.
- `Depends: R (>= 4.6.1)` -> `R (>= 4.6.0)`: a minimum-version floor should
  specify patchlevel 0 (R CMD check flags non-zero patchlevels in a `>=`
  constraint).
