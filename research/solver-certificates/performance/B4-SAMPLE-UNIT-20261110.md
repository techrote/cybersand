# B4-010 — HS-PKT snapshot sample-unit falsifier (2026-11-10)

**Decision: NO-GO for interpreting the historical profile's `simulation` p50/p95 as independent native-tick distributions.** The existing narrowly measured **executed collider-packet stage** remains STAGE_ONLY, not rejected; this is not evidence of a production-physics defect or a changed #470 acceptance gate.

## Exact baseline and falsifier

- Accepted main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
- B4 preregistered source baseline (before this report): `78cd86cb804772ca7a5b7a9172e04d767f4f3b6b` (Draft #554).
- Actual producer: `godot/scripts/hard_surface_packet_profile.gd`, Git blob `e5d226c946157410e256ba24fe6de0a34f32c883`.
- Historical real same-host A/B/B/A source fixture: `hs470_abba_profiles.json`, Git blob `40e0813ed6b80bef6feb8d721c196e43ea8d0517`; source control `4a80af2a891332176a3912a235582d77d076a185`, candidate `6aa03fe21dbe88b308793f377e4d223a90e4da8f`; original [Actions 42302283599/job 128182806453](https://github.com/techrote/cybersand/actions/runs/42302283599/job/128182806453), run on **6 November 2026**.

**Falsifier:** A 180-tick sampling window cannot contain more than 181 **distinct monotone tick indices**, even allowing one post-await observation at the inclusive end. If `observed_snapshots > requested_sample_ticks + 1`, the records are not a one-sample-per-native-tick sequence; they include repeated-tick publications, or the source tick index rewound/restarted during the window. Both invalidate that stronger per-tick statistical interpretation unless the raw tick sequence is supplied and classified.

The producer sets `WARMUP_TICKS=30`, `SAMPLE_TICKS=180`; samples every distinct **snapshot.serial**, not every distinct **snapshot.tick_index** (source lines 93–119). The worker publishes new snapshot serials at `_publish_snapshot` even when a local cycle is paused or not ticked (worker lines 2181–2230, 2380–2384); the snapshot retains `_world.tick_index` and `_world.simulation_time_ms` (lines 2439 and 2459). Therefore source permits repeated per-tick measurements, including prior tick's native simulation time.

## Independently parsed original 12 profiles

| Canvas | Arm1 control | Arm2 candidate | Arm3 candidate | Arm4 control |
|---|---:|---:|---:|---:|
| my-canvas observed / minimum excess | 256 / 75 | 256 / 75 | 256 / 75 | 255 / 74 |
| bench-canvas | 259 / 78 | 255 / 74 | 256 / 75 | 255 / 74 |
| stress-canvas | 232 / 51 | 232 / 51 | 235 / 54 | 236 / 55 |

- All **12/12** original profiles exceed the maximum 181 distinct tick indices. Across the original records: **2,983 observed serial-publications**, with **at least 811 observations in excess** of the tick-window capacity (per-run minimum 51–78). This is a pigeonhole bound, not an observed classification of specific duplicate serials.
- Original `bench-canvas` packet-stage p50 reductions (94.41%, 94.07%) are still **narrowly valid as per-executed-packet observations**. The packet samples were 122/142 and 143/143. No native-tick p50 distribution can be reconstituted from the aggregate historical summaries.
- Existing B4 negative controls remain: `my-canvas` has zero packet events yet simulation p50 changes; the reverse `bench-canvas` run reduces packet stage while wall time **worsens by 21.660 ms** (3559.511 candidate vs 3537.851 control). Neither packet-stage improvement nor aggregate p50 is net causal whole-tick evidence.

## Reproduction and limits

```sh
# Within the exact B4 PR checkout:
python3 research/solver-certificates/performance/hs470_sample_unit_probe.py --self-test
python3 research/solver-certificates/performance/hs470_sample_unit_probe.py research/solver-certificates/performance/hs470_abba_profiles.json
python3 -m unittest discover -s research/solver-certificates/performance -p 'test_*.py' -v
```

The new checker rejects a different input blob, prints all per-arm excesses, and is independent of the reducer's admissions. Its **exact published source Git blob** was locally run with `--self-test` and syntax compiled on CPython; the local Git blob matched the published one. **The full original B4 Python suite and the source-pinned JSON CLI of this new checker were not executed in this runtime**: the connected GitHub source was inspectable, but no Git checkout/network transfer into the Python runtime or Godot/native binary was available. A separate B5 independent review of the **prior exact B4 head** reported direct 18/18 original reducer tests PASS; it is not misrepresented as this run's full-suite execution. CI on the original head was docs/provenance PASS, source-scope PASS, native/GDExtension Draft-skipped; current-head CI must be rechecked.

**Minimal consumer repair / smallest decisive native fixture:** publish `(world_generation, snapshot_serial, tick_index, paused, simulation_time_ms, hard_surface_packet_executed, worker_count, physical_hash)` for each raw observation. Compute native tick distributions on one verified completed-tick record per tick, separately compute packet-event timing and publication overhead. Run actual 1/4 native workers and source-matched A/B/B/A under high-churn, sparse/quiescent, pressure/gas, cross-chunk and body-contact scenarios; assert per-tick physical-hash/wake parity. Until independently qualified, `HOLD` for any new native net cost claim, **NO-GO** unconditional B2 hot-path adoption given the retained **3.089× abstract high-churn regression**.

No production code, physics, default policy, worker, Rapier, hash or persistence was altered. This additive record is not a request to rerun expensive campaigns or to reverse merged #470.