# B4-006 — Exposure-adjusted packet work and wall-cost attribution boundary

**10 November 2026 · research-only / Draft / HOLD.** No native execution, new optimiser, changed laws, or production acceptance. The negative observations below are retained.

## Exact baseline, question and falsifier

- Accepted main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`, rechecked 10 Nov. B4 branch before this increment: `665e7e05be06b829d5f4e0163b0a80019a0c37aa`.
- Historical **real** same-host hosted A/B/B/A: 6 November 2026, [#470 Actions 42302283599 / job 128182806453](https://github.com/techrote/cybersand/actions/runs/42302283599/job/128182806453). AMD EPYC 9V45, Linux, Godot 4.7-stable headless, four logical CPUs, 30 warmup/180 requested sample ticks; 12 records, three canvases per arm.
- Source-locked raw profile file `hs470_abba_profiles.json`, Git blob `40e0813ed6b80bef6feb8d721c196e43ea8d0517`. Control source `4a80af2a891332176a3912a235582d77d076a185` / native binary SHA-256 `f47c0d6313bd6aa79767d2683c9273172822e6a04220a7a609f4c6d85dfb96a4`; candidate source `6aa03fe21dbe88b308793f377e4d223a90e4da8f` / native SHA-256 `1409f2799da6335892a414ba2e87770549081602e5fb8528cdb2905af1ac30ea`.
- Question: **How much measured packet-stage work per snapshot was exposed in each arm, and can packet-stage work alone explain the observed wall difference?** Prespecified falsifier of *stage-only attribution*: a no-packet canvas whose wall changes, an opposite-sign reverse comparison, or an observed wall delta larger than measured packet-stage delta, under a fixed-other-cost assumption.
- This is not a falsifier of the accepted narrow packet-stage speed improvement, nor of indirect effects that may arise elsewhere in the candidate.

For each arm the measured packet work is `S = packet_samples × packet_mean_ms`. Exposure-normalized work is `E = S / observed_snapshots`; recorded whole-run wall fraction is `100S / wall_ms`. This **descriptive accounting** does not imply that profiler timer events are on the critical path, that `wall_ms` is exclusively simulated ticks, or that differences in total wall time are caused by the packet kernel. The A/B/B/A arms have different packet counts; event-conditional p50 is not a same-event counterfactual.

## Actual historical input: independently recomputed

All entries come from the source-checked 12-record real-host capture (not synthetic timings). Source/binary/host/order/30+180 checks, 12/12 parsed records, finite stage/wall checks were independently replayed in a read-only GitHub-data computation this run.

| Canvas / arm order | Measured packet events | Packet total, ms | Packet work per snapshot, ms | Packet fraction of recorded wall |
|---|---:|---:|---:|---:|
| bench C1 | 122 | 46.540 | 0.179691 | 1.2008% |
| bench A2 | 142 | 3.256 | 0.012769 | 0.0920% |
| bench A3 | 143 | 3.529 | 0.013785 | 0.0991% |
| bench C4 | 143 | 53.576 | 0.210102 | 1.5144% |
| stress C1/A2/A3/C4 | 4 / 1 / 4 / 3 | 6.389 / 0.093 / 0.619 / 5.235 | 0.027539 / 0.000401 / 0.002634 / 0.022182 | 0.0607% / 0.0009% / 0.0059% / 0.0495% |
| my-canvas C1/A2/A3/C4 | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |

C=control, A=candidate. Measured packet-stage work falls substantially on bench even after event-frequency adjustment; the **qualifier remains packet-stage only**, not native tick, end-to-end FPS or physical equivalence.

| Paired comparison | Recorded wall difference (control minus candidate) | Packet-stage sum difference | Unexplained by direct stage subtraction |
|---|---:|---:|---:|
| bench C1→A2 | +335.806 ms (+8.6639% wall) | +43.284 ms | +292.522 ms |
| bench C4→A3 | −21.660 ms (−0.6122% wall) | +50.047 ms | −71.707 ms |
| my-canvas C1→A2 | +7.054 ms | 0 ms | +7.054 ms |
| my-canvas C4→A3 | −7.536 ms | 0 ms | −7.536 ms |
| stress C1→A2 | −9.438 ms | +6.296 ms | −15.734 ms |
| stress C4→A3 | +128.004 ms | +4.616 ms | +123.388 ms |

**Result:** a stage-only explanation of the wall delta is falsified under fixed-other-cost assumptions. The bench forward measured direct packet-stage saving is only 43.284 ms of the observed 335.806 ms wall difference; the reverse bench comparison has an **opposite-sign** wall delta despite positive packet-stage savings. My-canvas has zero packet events yet nonzero, order-reversing wall differences. This is evidence of uncontrolled wall variance and/or non-packet effects, not evidence that the #470 packet stage was slower or the new code is unsound.

Stress has just 1–4 packet calls per arm; any percentage estimate is intrinsically weak. The published profile does not capture raw paired per-tick costs, actual worker participation, physical hashes, RSS, allocations or identical-event sequences. **No B2/B3/native speedup or whole-game acceleration is established here.**

## Checker, execution and adversarial limits

- New [`hs470_stage_wall_budget.py`](hs470_stage_wall_budget.py) reuses the existing strict `reduce_hs470_abba.py` host/provenance reducer, rejects any mutated input Git blob and emits machine-readable arm/pair budgets with explicit limitations. From this directory:

  `python3 hs470_stage_wall_budget.py --self-test`

  `python3 hs470_stage_wall_budget.py hs470_abba_profiles.json`

- In this run the **exact checker source bytes** were authored and executed locally for self-test (arithmetic, seven invalid-input refusals and Git blob control): **PASS**; Python compilation **PASS**. Source Git blob was subsequently matched to the published file. A separate in-tool calculation on the **actual published 12 input records** reproduced the table and checked source identities. **The complete published Python checker was not itself run on the exact GitHub JSON file in one local checkout**, because the full remote data file was not mounted in the execution environment. That remains an independent replay requirement; the source and dataset are both published and hash-pinned.
- The newly committed checker inherits the legacy reducer's publication and sample gates; does not alter or replace previous B4 tail, alias or native evidence.
- Best challenge for B5: independently replay this source-locked exposure reduction, then demand same-run instrumented per-tick wall/pipeline breakdown, active native 1/4 workers, physical-hash identity and RSS/allocations before admitting **any** solver-cache or cross-solver runtime performance claim.

## Current research boundaries

Accepted [#470](https://github.com/techrote/cybersand/pull/470), [#471](https://github.com/techrote/cybersand/pull/471), [#522](https://github.com/techrote/cybersand/pull/522), [#406](https://github.com/techrote/cybersand/pull/406) and [#474](https://github.com/techrote/cybersand/pull/474) remain unchanged. Draft B2 [#556](https://github.com/techrote/cybersand/pull/556) and B3 [#555](https://github.com/techrote/cybersand/pull/555) still require independent source-exact model replay; earlier B4 B3 mutable-seed and B2 accepted-payload falsifiers remain distinct unresolved integration review items. The high-churn B2 abstract-work regression is not masked by these data. All new files remain within `research/solver-certificates/performance/**`; no default solver, native World, worker, Rapier, MAT-AUTH, physical hash or saved-state contract changed.
