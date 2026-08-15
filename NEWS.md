# nlmixr2qual 0.0.0.9000

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
