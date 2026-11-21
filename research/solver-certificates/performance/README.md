# B4 — Independent source-matched HS-PKT A/B/B/A evidence reduction

Status: **research-only, Draft / HOLD for whole-tick and solver claims**. Captured 9 November 2026, from a real hosted execution **6 November 2026**. No new native simulation was run in this study. This report independently re-reduces the original `HARD_SURFACE_PROFILE` records, rather than accepting PR-summary percentages or constructing an artificial fast microbenchmark.

## Source identity and reproduction

- Production repository: `techrote/cybersand`. Research branch based on accepted `main`; no production implementation or default modified.
- Original experiment: [#470 hard-surface packet optimisation](https://github.com/techrote/cybersand/pull/470), merged 7 November 2026; [source/qualification audit](https://github.com/techrote/cybersand/blob/main/docs/audits/2026-11-06-hard-surface-packet-incremental.md).
- [Actions run 42302283599](https://github.com/techrote/cybersand/actions/runs/42302283599), [job 128182806453](https://github.com/techrote/cybersand/actions/runs/42302283599/job/128182806453), explicitly same-host `control/candidate/candidate/control`.
- Control source `4a80af2a891332176a3912a235582d77d076a185`, loaded Linux binary SHA-256 `f47c0d6313bd6aa79767d2683c9273172822e6a04220a7a609f4c6d85dfb96a4`.
- Candidate source `6aa03fe21dbe88b308793f377e4d223a90e4da8f`, loaded Linux binary SHA-256 `1409f2799da6335892a414ba2e87770549081602e5fb8528cdb2905af1ac30ea`.
- Each arm: three built-in canvases; Godot 4.7-stable headless; Linux AMD EPYC 9V45 runner, 4 logical CPUs; 30 warmup ticks, 180 requested sample ticks. The captured records contain 12 full per-canvas JSON profiles, their full diagnostics and actual identities.
- Script uses only Python standard library. From this directory:

```sh
python3 reduce_hs470_abba.py hs470_abba_profiles.json
python3 -m unittest -v test_reduce_hs470_abba.py
```

The reducer checks arm order, paired source/native hashes, capture window, host identity, 12-record completeness, sample counts, percentile consistency and a 100-packet-samples-per-arm *research* threshold. This threshold qualifies only the measured packet stage; it does not override repository acceptance criteria. There is no causal claim from simulation timings. Neither physical hashes nor actual participating native worker count were in these profiles. The independent #470 full packed-byte oracle and native tests are separately documented; this small experiment does not rerun them.

## Independent reductions

| Canvas | Control/Candidate packet sample count, first then reverse pair | Control/Candidate packet p50 (ms) | Packet p50 reduction | Simulation p50 change | Admission |
|---|---|---|---|---|---|
| bench-canvas, A/B | 122 / 142 | 0.376 / 0.021 | **94.41%** | 8.3004 → 8.0941 ms (**2.49%**) | STAGE ONLY |
| bench-canvas, B/A | 143 / 143 | 0.371 / 0.022 | **94.07%** | 8.2848 → 8.1985 ms (**1.04%**) | STAGE ONLY |
| stress-canvas, A/B | 4 / 1 | 1.598 / 0.093 | 94.18% (unreliable) | 31.4577 → 31.6767 ms (**-0.70%**) | HOLD, 1–4 packet samples |
| stress-canvas, B/A | 3 / 4 | 1.784 / 0.159 | 91.09% (unreliable) | 32.0016 → 31.2369 ms (**2.39%**) | HOLD, 1–4 packet samples |
| my-canvas, both comparisons | 0 / 0 | 0 / 0 | not measurable | 4.4659 → 4.2579 (**4.66%**), then 4.3704 → 4.3023 (**1.56%**) | NO PACKET EVENTS |

**Interpretation:** The large packet-stage improvement on `bench-canvas` is corroborated by actual same-host source-matched logs and qualifies as an existing **packet-stage-only** observation. The apparent simulation-p50 benefit is smaller, and the negative-control `my-canvas` records show a simulation-p50 reduction **without any executed collider packet**. Consequently a naive attribution of the bench-canvas tick-time difference to this packet change is unsupported by these records. Stress-canvas packet ratios have too few observations to support a robust performance claim. These are per-arm summary distributions, not paired per-tick timings; do not sum medians across stages.

**Independent disposition:** GO for preserving #470's narrow source-bound packet-stage result; HOLD on universal native tick/FPS claims, cross-configuration generality and any new B2/B3 solver speedup inferred from it. The existing #470 PR does not claim global tick improvement either. A configured 4-CPU host does not prove four simulation workers actually participated.

## Source-critical research constraints for B2/B3

1. **B2 influence-region admissibility:** [accepted pressure-motion certificate contract](https://github.com/techrote/cybersand/blob/main/docs/architecture/pressure-optimization.md) says gas resolution revokes Water motion certificates because remote gauge/volume change can alter local gradients. Local chunk hashes alone cannot authorize a general PressureFlow sleep: preregister a remote gas-volume, component-union and moving-body-mask invalidation falsifier. Conservative `UNKNOWN -> RECOMPUTE` is mandatory.
2. **B2 benchmark identity:** demand real native work avoidance, invalidation accounting, exact hash/ledger parity for same-law modes, 1/4 worker participation evidence, bounded memory, sparse and active cases, and full tick time. A microbenchmark may fail to predict wall-clock improvement.
3. **B3 transfer identity:** adversarially duplicate/replay an old parcel-release receipt across a reset or epoch/World change, alter body-contact ownership, and verify quantity ledger, exactly-one owner and signed momentum/collision receipts. A physical hash match without receipt/session epoch agreement must not automatically establish replay equivalence.
4. **Existing baselines:** [#471 same-chunk cursor](https://github.com/techrote/cybersand/pull/471) and [#522 PF gas integration](https://github.com/techrote/cybersand/pull/522) are merged. Their source/fixture-bound results should be controls, not stacked as independent guaranteed improvements. Ballistic [#406](https://github.com/techrote/cybersand/pull/406) is experimental and separately qualified.

## What was and was not done

**Done:** Retrieved and independently checked the original hosted job logs; retained all 12 raw profile JSON objects; produced reproducible source/hash/order-aware reduction and nine adversarial evidence-integrity tests; distinguished actual packet-stage evidence from whole simulation claims.

**Not done:** Built a new native binary; captured native physical-hash/worker-participation traces; measured RAM/allocations; tested B2/B3 implementations not yet available in an owned candidate; established CyberSand global physics/FPS acceptance or universal throughput improvement. This is not a new performance speedup.

**B5 review request:** Independently reproduce the stage gate from the raw job, verify the conservative interpretation of the no-packet negative control, and reuse this admission rubric (not #470's historical source SHAs) when B2 and B3 supply a real candidate. Preserve all negative evidence.
