# B4-008 — Producer-derived sample-admission falsifier

**10 November 2026. Research-only / Draft / HOLD on native performance and physics.**

## Exact provenance and scope

- Accepted CyberSand main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
- Independently inspected current accepted profiler: `godot/scripts/hard_surface_packet_profile.gd`, Git blob `e5d226c946157410e256ba24fe6de0a34f32c883`. This file is **read-only** for B4.
- Original actual same-host #470 A/B/B/A capture: 6 November 2026, [Actions run 42302283599, job 128182806453](https://github.com/techrote/cybersand/actions/runs/42302283599/job/128182806453). Control source `4a80af2a891332176a3912a235582d77d076a185`, candidate `6aa03fe21dbe88b308793f377e4d223a90e4da8f`. The pre-existing raw 12-record fixture `hs470_abba_profiles.json` retains Git blob `40e0813ed6b80bef6feb8d721c196e43ea8d0517`; no measurement was regenerated.
- Research reducer before this change: Git blob `f0b56703ab88888fd06b606a2370891b3af7f710`. This change is solely to `research/solver-certificates/performance/reduce_hs470_abba.py`, its tests and this report. B2 #556 / B3 #555 are independent unmerged research; #470/#471/#522 accepted controls, #533 gas optimisation and #553 equipment still Draft. No source edits to protected World, Rapier, worker, pressure, UI or MAT-AUTH.

## Preregistered falsifier and producer-derived invariant

**Question:** Can correctly labelled source, binary, host and A/B/B/A metadata nonetheless pass B4's original reduction with a statistically impossible profile, and thereby spuriously promote the stress-canvas stage evidence gate?

In the accepted profiler, for each new snapshot serial beyond the warmup, exactly one value is appended to each of `simulation`, `snapshot_copy_total` and `publication`. The `hard_packet` and `render_exchange` arrays also receive one value, but their reported `_summary(..., positive_only=true)` sample counts are filtered **subsets**. Thus for every complete report with `N=observed_snapshots`:

```text
simulation.samples = snapshot_copy_total.samples = publication_build.samples = N
0 <= hard_surface_packet_executed.samples <= N
0 <= render_exchange_executed.samples <= N
0 <= every timing mean <= corresponding max (+ rounding allowance)
```

These are source-specific feasibility constraints, **not** a claim that every profiler or future instrumentation shares the same schema.

**Falsifier:** On all four stress-canvas records (indices 2,5,8,11), change only `hard_surface_packet_executed.samples` to `observed_snapshots + 1`; keep real source hashes, binary hashes, host, order and percentile values unchanged. The original reducer's individual `checked_stats` guards accept these values; its `min(packet samples) >= 100` rule changes stress from `HOLD_LOW_SAMPLE` to **`STAGE_ONLY`**, despite the producer being unable to emit that event count. An independent second control sets one measured stage mean to `max_ms + 1`, which also passed the original mean-unconstrained predicate.

## Deterministic experiment: actual historical fixture plus adversarial mutations

A read-only JavaScript reconstruction of the published reduction predicates was executed on **all 12 original JSON records fetched from their pinned Git blob**; it did not claim to run Python from the original repository or native/Godot. Results:

| Control | Result |
|---|---|
| Original real 12 profiles meet all new source-derived constraints | 12/12 |
| Original stress packet counts | 4 / 1 / 4 / 3 |
| Forged counts = observed snapshots + 1 | 233 / 233 / 236 / 237 |
| Old reducer's count and percentile predicates on forged fixture | All accepted |
| Old stress stage decision after count inflation | Incorrect `STAGE_ONLY` |
| New source-feasibility predicates | `REFUSE` |
| Separate `mean > max` forgery | Refused by new predicate |
| Actual native timing / physical hash / worker participation / RSS / allocations | Not run / unavailable |

Positive baseline `observed_snapshots` by arm/canvas order: `256,259,232,256,255,232,256,256,235,255,255,236`. The factual historical stress stage remains **HOLD**.

## Implemented additive research guard and replay

The reducer now validates bounded positive integer snapshot count, exact whole-snapshot metric cardinality, executed-event subset counts and `mean <= max`. Five new unittest methods cover unmodified fixture controls, four-arm stress gate forgery, impossible mean, all three whole-snapshot sample sources and executed render count forgery. Existing checks of source, native hash, host, order, sample window and percentile ordering are retained.

```sh
cd research/solver-certificates/performance
python3 -m unittest -v test_reduce_hs470_abba.py
python3 reduce_hs470_abba.py hs470_abba_profiles.json
```

**Execution disclosure:** The 12-record and mutated-data checks above were actually executed in a read-only JavaScript oracle against source-pinned JSON. The new Python regression methods were **authored but the complete exact updated Python module has not been executed** in this environment; independent exact-head Python replay is requested. Existing downstream scripts that pin the raw JSON blob already reject a modified fixture; this change independently strengthens the public reducer's semantic admissibility when given externally supplied data. No historical source or evidence blob was changed.

## Disposition and handoff

- **GO (narrow):** Provenance-admission hardening. A profile meeting ID/hash checks can still contradict the *actual source instrumentation*; reject before performance classification. The real 12-record fixture satisfies the stronger guards.
- **HOLD:** End-to-end tick/FPS causality, stress-canvas packet stage (1–4 original events), new B2/B3 solver performance, same-host native worker/hash/quantity/contact parity, p50/p95/tail generality and RSS/allocations. Keep the zero-packet negative control and B2's 3.089x high-churn abstract-work regression.
- **B5 request:** independently execute the updated exact Python test suite, check that the producer's positive-only sampling invariant is complete, and require these feasibility/provenance constraints in any future B2/B3 measurement manifests before scoreboarding alleged savings. This is not a new optimisation, a new physics law, or an authorised production integration.
