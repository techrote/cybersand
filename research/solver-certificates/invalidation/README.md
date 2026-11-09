# B2-REGION-001 — bounded fixed-point certificates and dependency-cone invalidation

**Status:** experimental mathematical model; **not a CyberSand optimisation, accepted physics result, runtime benchmark, or production implementation.** 9 November 2026. Repository source context: accepted `main` commit `d4b18e7f06839b35c8f6a66195206da0f33c5fa3` (merge #542). This experiment intentionally modifies **no** native World, pressure, worker, physics, Rapier, rendering, authoring, test harness or global authority code. Python standard library only.

## Research question and preregistered falsifiers

Can a discrete, phase-dependent, bounded-read system avoid *all* update evaluations for a certified fixed-point tile, yet match a full-step reference through arbitrary local mutations and conservative global invalidations?

Falsifier (correct algorithm): any exact state difference between cached and full recompute at **any** tick of the deterministic adversarial tapes, for either 1 or 4 logical worker partitions. Additional necessary negative controls must **fail**: omission of the radius-one halo on a cross-tile moving actor; omission of nonlocal pressure invalidation. A zero-mismatch test corpus is empirical evidence, **not** a general theorem for the actual CyberSand engine.

## Bounded lemma: two-phase fixed-point reuse

Let `S_t` be a finite grid state at tick `t`, `u_t` external inputs, and `F_p(S_t,u_t)` a deterministic, **synchronous** whole-grid transition at phase `p=t mod 2`. For a tile `R`, let `D(R)` be the union of exact read footprints of all its cells under both phases, and `G(R)` the external-input dependencies (including dynamic body obstacle masks and every global dependency).

A certificate `C(R,S,u)` is admitted iff for **both** phases `p` and every cell `z` in `R`, `F_p(S,u)[z] = S[z]`. The cache skips computing `F_p` on `R` only while the contents of `D(R)` and every input in `G(R)` remain unchanged since that certificate was admitted, and all unknown dependencies trigger a full fallback. Any source edit, worker-committed cell change or transient-body-mask update affecting `D(R)` invalidates `C` *before the next visit*; the next transition reads a consistent immutable pre-tick snapshot. On restoration, certificates are discarded and re-established from the restored authoritative state.

**Proof (induction over synchronous ticks):** Initially the certificate means both possible phase outputs equal the stored state on `R`. If the certificate is still valid at tick `t`, its entire read footprint and external inputs equal the admitted values; pure determinism gives the same output, hence retaining `S_t|R` is equivalent to computing `F_p|R`. All other tiles are evaluated against the same pre-tick state, so the full next states are equal. Every modified input is invalidated at the proper barrier before it can be read under a surviving certificate. Thus the invariant holds at `t+1` until a source or unknown dependency causes fallback. QED under the stated assumptions. No claim is made about asynchronous, in-place, stochastic, nonlocal, untracked or unbounded CyberSand updates.

Two-phase proof is stronger than inspecting only the currently selected phase: a tile can be fixed under one phase but move under the next. `D(R)` is one-cell Chebyshev halo in this toy model; **it is not CyberSand's actual radius**, which depends on the material, Water family, stage and global preparation. The global pressure flag deliberately invalidates *every* certificate because this toy dependency is nonlocal.

### Proven scope and explicit non-scope

The standalone grid contains Empty, Sand, Water, Rock, Wood, Fire, Ash and Steam labels; a phase-alternating disjoint vertical pair-swap, four-neighbour reaction, actor overlap as a transient movement obstacle, and a deliberately global pressure influence. The rule is **not physically conservative**, not the native source's scheduler and not Rapier. Its exact-state oracle is a byte-for-byte equality of structured model state, independently repeated at every tick (hashes are supplementary evidence). Logical 1/4 partitions are sequential shards of immutable-snapshot work, **not actually running 1/4 native worker threads**.

The lemma does **not** authorize skipping general material lifecycle, chemistry, body-contact impulses, wake probes, pressure-gas topology, quantity ledgers, render exchange, Rapier integration, global input preparation or other mandatory CyberSand side effects. Ordinary source and pressure authority continue to dominate. For actual CyberSand, missing or stale read provenance, an untracked global coupling, budget overflow, uncertain gas identity, unknown actor effects, failed worker barrier or exhausted epoch capacity must all mean `UNKNOWN => RECOMPUTE` (or fail/quarantine as the existing contract requires).

## Deterministic experiment

Run from this directory:

```sh
python3 -m unittest discover -s . -p 'test_*.py' -v
python3 model.py > /tmp/b2-region-001-local.json
```

The 12 unit tests cover: 1/4 partition equality, exact post-tick oracle, phase parity, quiescent region reuse, cross-tile moving-body wake, a deliberately broken halo wake **producing a mismatch**, remote global pressure wake, a deliberately broken global pressure wake **producing a mismatch**, material reaction, explosion, ABA write-and-reverse events, UNKNOWN full fallback, rollback/certificate rebuild and high-churn cost regression. The mixed/dense runs use a fixed 64-tick input tape, 24×16 cells, 4×4 tiles, fixed random seeds. Full world updates cover 384 cells per tick. Reproducible machine-independent summary is `evidence.json`, excluding wall-clock timings.

### Result — local CPython 3.13.5, 9 November 2026

Each profile also passed 4 logical shards with identical final state/hash and the same model counts.

| Profile | Full cell calls | Cached cell calls | Avoided | Cert probe calls | Halo-site checks | Total abstract units / full | Revocations | Semantically unnecessary revocations* |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Quiet | 24,576 | 0 | 100.00% | 1,536 | 0 | 0.063× | 0 | 0 |
| Mixed | 24,576 | 7,584 | 69.14% | 5,632 | 3,725 | 0.689× | 121 | 82 |
| Dense | 24,576 | 7,712 | 68.62% | 5,649 | 3,847 | 0.700× | 122 | 66 |
| Churn / UNKNOWN every tick | 24,576 | 24,576 | 0% | 13,169 | 3,429 | **1.675×** | 381 | 379 |

*Offline diagnostic: revoked regions that still passed the two-phase fixed-point check **immediately after that particular input change**. This is not a claim that retaining their original certificates would have been legal: their assumptions changed, including ABA/provenance changes. The independent diagnostic recomputation is **excluded** from the abstract work accounting; see `diagnostic_probe_calls` in `evidence.json`. The abstract cost counts each rule evaluation, proof evaluation and tested halo site equally; the units do **not** represent equal CPU costs, allocations, wall-clock speedups or CyberSand native performance. The Python timed path includes analysis-only diagnostics and has no native comparability.

Final state SHA-256 prefixes: quiet `b80f5cda755286700a04`, mixed `bf5c6f469a3ebb174848`, dense/churn `31e9731f5eca98914dba`. Every tick uses exact `State` dataclass equality, not just those hashes. Corpus/source identifiers, counts, full input tape and algorithm are preserved here so an independent reviewer can repeat and extend the experiment.

**Negative result:** high-churn/unknown workloads always fall back and pay extra proof/invalidator work; a blanket region-certificate layer is therefore not automatically beneficial. Even mixed/dense abstract units are optimistic relative to CPU: bookkeeping, caches, allocation and real solver kernels have different costs.

## Real CyberSand relationship and independent handoffs

- [#470 incremental hard-surface collider invalidation](https://github.com/techrote/cybersand/pull/470) is already **merged**. It avoids rebuilding unchanged packed rectangles and maintains a distinct hard-surface dirty-tile owner. This model must not re-implement #470.
- [#471 local neighbour read cursor](https://github.com/techrote/cybersand/pull/471) and [#522 accepted pressure/gas fastpaths](https://github.com/techrote/cybersand/pull/522) are **merged**; these already reduce specific read or derived-work costs. The generic model is not evidence that either can skip any extra native work.
- [Pressure optimisation contract](https://github.com/techrote/cybersand/blob/main/docs/architecture/pressure-optimization.md) explicitly states existing `cached_dormant` certificates skip only the *Water pressure motion stage*, not general chunk/region work. They must preserve a 5×5 body stencil, lifecycle, chemistry, pressure preparation, impulses and gas revisions. A remote gas-volume or gauge change may invalidate distant local gradients. Therefore a generic region skip would be **unsound without new authoritative dependency and side-effect inventories**.
- [Draft #533](https://github.com/techrote/cybersand/pull/533) already explores individual sealed-gas-component reuse under global topology churn. Its exact controls and HOLD must not be displaced by this speculative work.
- [#406 ballistic Water](https://github.com/techrote/cybersand/pull/406) and [#474 optional lockstep](https://github.com/techrote/cybersand/pull/474) are merged, but physics/defaults and host/worker ownership still demand versioned inputs and source-pinned replay; the model contains none of their actual costs.

**B4 performance-lab handoff:** first determine actual per-stage read/side-effect sets and authoritative wake domains on accepted source; construct three bounded native fixtures (quiet pool, remote pressure/gas perturbation, moving Rapier contact) and a high-churn rejection control. Demand every-tick physical-hash/quantity/gas ledger parity at 1/4 actual workers; compare *complete* native tick p50/p95, actual worker participation, CPU/RSS, allocation and certificate work cost in same-host A/B/B/A against current main. Do not promote these toy savings as performance.

**B5 integration handoff:** keep the present contract research-only. The potentially useful reusable result is a **typed dependency + certificate invalidation interface** with explicit local halo, global dependency and UNKNOWN cases at owner barriers. Seek an inventory of side effects that would prevent whole-region skipping; constrain first production consumer to one already identified independently skippable stage (not the entire world). Require independent review of soundness/counterexample controls, then source-locked native tests and owner admission before any production experiment. This does not change Water defaults or the MC-B/MC-1 geometry research gates.

## Independent challenge requested

Review the proof's assumption that every required read and side effect is represented; demand a counterexample for any proposed real CyberSand stage whose dependency closure omits pressure global state, transient body contact, phase identity, persistent sidecar state, explosion/producer writes, worker effects or rollback. Verify the two deliberately incorrect variants **actually diverge** on their targeted fixtures. If either does not, regard the falsifier as ineffective and HOLD the research. No evidence of universal novel mathematical discovery is claimed; the lemma is standard deterministic-dependency reasoning applied to a controlled model.
