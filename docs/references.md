# nlmixr2qual — references

This document describes the JSON reference schema, the shipped internal
reference set, how an organisation creates its own references, and the
thread-tolerance design.

> **Reproducibility, not correctness.** A reference is a *confirmed-good
> fit*, not a ground truth. A qualification PASS means an installation
> reproduces the reference's stored result within tolerance — it does not
> assert the model is physiologically correct or the parameter values are
> "true".

## The JSON reference schema

A reference is one confirmed-good fit, serialised as a self-contained JSON
file (model source, embedded input data, estimation method, thread count,
and result fingerprint):

```
schema_version
id                                  "<model>__<method>__t<threads>"
model    { name, code, description }
data     { name, records }          the fit's input dataset, embedded
method   { est, control, seed }
reference {
  threads, ofv, params, shrink, converged, covMethod, stochastic, category,
  initial_estimates                 starting values for re-fitting
}
provenance { software, created, source_bundle, nlmixr2save_version }
```

`reference$initial_estimates` defaults to the bundle's own pre-fit priors
(`fit$iniDf0`, preserved by `nlmixr2save::saveFit()`), not the fitted values
baked into the reconstructed model source — this is what lets a local re-fit
reproduce the *original* optimizer trajectory (cold start) rather than
warm-starting from the answer. See `qual_import_bundle()`.

`method$seed` is an optional integer random seed for stochastic methods
(`saem`, `fsaem`, `imp`, `impmap`, `qrpem`). If present, `qual_reference_refit()`
injects it into the method-appropriate control object (`saemControl(seed=)`
for saem/fsaem; `impControl()`/`impmapControl()`/`qrpemControl()`'s
`impSeed=` for imp/impmap/qrpem), making a same-seed re-fit exactly
reproducible rather than only tolerance-compared. `qual_import_bundle()`'s
`seed` argument sets it explicitly; if omitted, it is read off the bundle's
own fit control when the bundle was itself fit with one.

**Identity:**

- **pair** = `"<model>__<method>"` (e.g. `theophylline__focei`) — computed
  from `model$name` + `method$est`.
- **id** = `"<model>__<method>__t<threads>"` (e.g.
  `theophylline__focei__t1`) — unique; the JSON filename stem and the key
  used to load references.

## Creating a reference

Import a fit saved with `nlmixr2save`:

```r
fit <- nlmixr2est::nlmixr2(model, data, est = "focei")
nlmixr2save::saveFit(fit, "my_fit", zip = TRUE)

ref <- qual_import_bundle("my_fit.zip", model_name = "my_model",
                          method = "focei", threads = 1L,
                          description = "one-line model description")
qual_reference_write(ref, "my_references/my_model__focei__t1.json")
```

`threads` is required — a fit does not record its own rxode2 thread count,
so the caller asserts the count the bundle was fit at.

## The shipped internal reference set

The internal set (`inst/references/`) covers the theophylline model
(`nlmixr2data::theo_sd`) across every estimation method that produces a
valid fit on the build box, at `threads = 1` (mandatory) and, where the
build box has at least `qual_default_multi_threads()` (4) cores,
`threads = 4` (optional). `fsaem` is not currently a supported `nlmixr2est`
estimation method and is skipped by the generator
(`data-raw/make-theophylline-references.R`).

```r
qual_catalogue_md(qual_load_references("internal"))
```

| id | model | method | threads | ofv | stochastic | nlmixr2_version |
| --- | --- | --- | --- | --- | --- | --- |
| theophylline__agq__t1 | theophylline | agq | 1 | 118.4826 | FALSE | 7.0.1 |
| theophylline__agq__t4 | theophylline | agq | 4 | 118.4826 | FALSE | 7.0.1 |
| theophylline__foce__t1 | theophylline | foce | 1 | 116.8037 | FALSE | 7.0.1 |
| theophylline__foce__t4 | theophylline | foce | 4 | 116.8037 | FALSE | 7.0.1 |
| theophylline__focei__t1 | theophylline | focei | 1 | 116.8038 | FALSE | 7.0.1 |
| theophylline__focei__t4 | theophylline | focei | 4 | 116.8038 | FALSE | 7.0.1 |
| theophylline__focep__t1 | theophylline | focep | 1 | 116.8037 | FALSE | 7.0.1 |
| theophylline__focep__t4 | theophylline | focep | 4 | 116.8037 | FALSE | 7.0.1 |
| theophylline__imp__t1 | theophylline | imp | 1 | 116.8312 | TRUE | 7.0.1 |
| theophylline__imp__t4 | theophylline | imp | 4 | 116.8312 | TRUE | 7.0.1 |
| theophylline__impmap__t1 | theophylline | impmap | 1 | 116.8291 | TRUE | 7.0.1 |
| theophylline__impmap__t4 | theophylline | impmap | 4 | 116.8291 | TRUE | 7.0.1 |
| theophylline__laplace__t1 | theophylline | laplace | 1 | 116.8038 | FALSE | 7.0.1 |
| theophylline__laplace__t4 | theophylline | laplace | 4 | 116.8038 | FALSE | 7.0.1 |
| theophylline__qrpem__t1 | theophylline | qrpem | 1 | 116.8727 | TRUE | 7.0.1 |
| theophylline__qrpem__t4 | theophylline | qrpem | 4 | 116.8727 | TRUE | 7.0.1 |
| theophylline__saem__t1 | theophylline | saem | 1 | 122.8436 | TRUE | 7.0.1 |
| theophylline__saem__t4 | theophylline | saem | 4 | 122.8436 | TRUE | 7.0.1 |

`focei`, `foce`, `focep`, `laplace`, and `agq` are deterministic and
**strict** — they gate the qualification verdict. `saem`, `imp`, `impmap`,
and `qrpem` are stochastic; they are re-fit and compared under the looser
stochastic tolerance and reported, but never gate the verdict. All four are
seed-pinned (seed 99, via `data-raw/make-theophylline-references.R`'s
`.qual_stochastic_control()`) for same-machine reproducibility, and all four
reproduce cleanly (bit-identical OFV) under the pinned seed.

`saem`/`fsaem` fit a slightly different model than the other eight methods:
`tcl` (clearance) has no explicit bound (`log(2.7)` instead of
`log(c(0, 2.7, 100))`; `one.cmt.saem` in the generator). SAEM internally
reparameterizes a *bounded* theta onto its own unconstrained transform scale
and reports it in `fit$iniDf0` only under an internal `rxBoundedTr.tcl`
alias, whose value is on that transform's scale rather than `tcl`'s own —
`nlmixr2qual` cannot safely invert it, so it used to drop that entry rather
than risk applying the wrong number, leaving `tcl` unable to reset to its
true cold-start prior and the seeded re-fit unable to reproduce the original
run. An unbounded `tcl` sidesteps the reparameterization entirely (`cl <-
exp(tcl + eta.cl)` is already positive-constrained by construction, so the
bound was never load-bearing for model validity, only for the optimizer's
search region) and `fit$iniDf0` reports a plain `tcl` like every other
method.

Regenerate the set (e.g. after an `nlmixr2est` upgrade) with:

```sh
Rscript data-raw/make-theophylline-references.R
```

## Multi-threaded references are optional

Only `t1` is mandatory per method. `tx` (any `threads > 1`) is entirely
optional, and `qualify()`/`qual_load_references()`/`qual_select()` all work
correctly with a `t1`-only reference set — nothing requires a `tx` reference
to exist. An organisation adds coverage at any thread count by importing one
bundle per count; the tool never invents a multi-threaded result from a
single-threaded one.

A user qualifying on a machine with fewer cores than a shipped `t4`
reference still pins `threads = 4` for that reference (oversubscribed) so
the comparison stays like-for-like — such a reference is best excluded from
that machine's run (`qualify(which = "theophylline__focei", ...)` to select
only the `t1` id, or point `source` at a folder without `tx` references).

## Thread-tolerance design

Multi-threaded fits can differ across machines/BLAS even at the same thread
count (non-associative parallel float reductions), so an exact match cannot
be required for `threads > 1`. The comparison tolerance is keyed to the
reference's thread count:

- `threads == 1` → **strict** tolerance
  (`qual_compare(..., invariance = FALSE)`). Deterministic methods need to
  reproduce closely, but not to full bit-portability: `qual_reference_refit()`
  necessarily starts from the reference's `initial_estimates` (the bundle's
  cold-start priors) rather than a warm start, and a derivative-free
  optimizer (e.g. `bobyqa`) can land at a measurably different — but fully
  deterministic — point than the original run even from identical starting
  conditions and data, particularly for theta/omega estimates near zero.
  `qual_tolerance()`'s deterministic theta/omega/sigma default (1%) reflects
  this; `ofv` stays at 0.1% since it is flat near the optimum.
- `threads > 1` → **looser** tolerance
  (`qual_compare(..., invariance = TRUE)`), sized for parallel-float
  variation. `qual_tolerance(invariance = TRUE)` floors at
  `max(class default, 1%)` — it is never *tighter* than the deterministic
  default for a class (e.g. `shrink`'s 5% deterministic default stays 5%
  under invariance, not 1%). Per-quantity `overrides` are available to
  `qual_compare()` if a specific quantity needs loosening further.

Shrinkage is reported in every comparison's detail table but never gates the
verdict at any thread count: near-zero shrinkage estimates can swing by a
large *relative* amount from tiny absolute noise, which no percentage
tolerance can reliably absorb without weakening the check for larger shrink
values.

Stochastic methods are informational at every thread count regardless of
this tolerance design.
