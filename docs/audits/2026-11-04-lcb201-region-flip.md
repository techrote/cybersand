---
title: LCB-002 #201 desktop worker simulation-region flip
status: Current
document-kind: evidence
scope: Diagnosis, fix and in-app before/after evidence for the desktop worker writing the camera window and then a fixed-interest MicroScenario region on every step, which discarded the PressureFlow derived cache; camera-pan characterization; no native, runtime, default or pressure-law change
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-lcb201-pressure-idle-cost.md, 2026-11-04-lcb201-p1-wake-summaries.md, ../architecture/pressure-optimization.md, ../architecture/simulation-tick-and-threading.md]
---

# LCB-002 #201 desktop worker region flip — 4 November 2026

## Result

In the real desktop host, the cached and cached_dormant PressureFlow variants
were **slower than reference**. The cause was a worker ordering fault, not
pressure physics. Every step, `CyberSimulationWorker` wrote the window-enabled
flag and the camera simulation window. Then `CyberMicroScenarioHost.apply_interest()`
wrote the scenario's fixed region. Whenever the two regions selected different
scheduling cores, `World::set_simulation_region` ran `pressure_->cache->cold()`,
which happened twice per step. The cache therefore rebuilt its index and redid a
full reference preparation on every tick.

The fix leaves a fixed-interest scenario as the only writer of the window flag
and region. The region the World ends each step on is unchanged; only the
transient camera write is gone. On main's unchanged runtime, the in-app cached
quiet-pool worker step falls from **≈36 ms to ≈10 ms**, and simulation rises
from ≈27 Hz to its **60 Hz** cap. Reference and FreeMass are unchanged.

## Source and change

| | Identity |
|---|---|
| Base | main `01f9b7c8e382ca6bdbaf0bf70c7847adc12fe0bc` (#374 merged) |
| Runtime | main's committed Windows DLL `ee09f7ab…7199a`, unchanged. No native source changed |
| Change | [`simulation_worker.gd`](../../godot/scripts/simulation_worker.gd): the per-step settings writes move into `apply_world_execution_settings()`. With `_micro_active and fixed_interest()`, it skips `simulation_window_enabled` and `set_simulation_window`. Cadence, adhesion and interest-centre writes are unchanged, and `apply_interest()` still runs afterwards |
| Test | [`test_simulation_worker_interest_ownership.gd`](../../godot/tests/test_simulation_worker_interest_ownership.gd) |
| Host case | [`lcb201_pressure_host_case.gd`](../../godot/tests/lcb201_pressure_host_case.gd), byte-identical to #382's copy; not a CI regression |

`set_frame_state` still records the camera view. When the scenario ends, the
next ordinary step writes the camera window as before. `before_tick()` calls
`apply_interest()` again with the same region, which is a no-op.

## Regression

The test has two parts:

- **Recording fake.** It pins the exact call sequence. Ordinary interest keeps
  all five previous writes in order; a fixed-interest scenario receives no
  window flag or camera region.
- **Actual native check.** It uses `CyberNativeCellWorld` with the #370 quiet
  pool installed through the controlled prepared-liquid route under **cached**
  PressureFlow, with explicit `water-normalize-v1`. It is driven with the
  worker's per-step settings, `apply_interest()` and `advance()`. After 12
  settle ticks, the new ordering adds **0** pressure-index rebuilds over 16
  quiet ticks. The previous ordering, kept as a negative control, adds **16**.

Local run: 57 assertions, 0 failures.

## In-app before/after

Same host case and Godot 4.7 headless Windows binary, run once per row: 64
settle ticks, then 240 measured ticks, with no bodies. Worker step is
`worker_step_time_ms`; desktop simulation is paced at 60 Hz.

| Worker | Variant | Native Hz | Worker step p50 / p95 / max ms | Snapshot age p50 / p95 ms | Failures |
|---|---|---:|---|---|---:|
| main (before) | reference | 27.5 | 35.02 / 42.13 / 44.96 | 7.11 / 14.44 | 0 |
| main (before) | cached | 26.6 | 36.21 / 43.02 / 46.79 | 7.65 / 14.87 | 0 |
| main (before) | cached_dormant | 26.0 | 37.14 / 44.51 / 49.44 | 7.76 / 14.41 | 0 |
| main (before) | freemass | 59.6 | 0.28 / 0.36 / 0.65 | 1.22 / 2.03 | 0 |
| fixed (after) | reference | 27.5 | 35.10 / 42.80 / 48.15 | 7.05 / 14.28 | 0 |
| fixed (after) | cached | 60.0 | 10.30 / 13.08 / 20.13 | 6.36 / 12.63 | 0 |
| fixed (after) | cached_dormant | 60.2 | 10.05 / 12.69 / 14.27 | 6.49 / 12.58 | 0 |
| fixed (after) | freemass | 60.3 | 0.26 / 0.36 / 1.31 | 1.17 / 1.71 | 0 |

Raw logs, the fixed worker copy and SHA-256 receipts are kept outside Git
(`flipfix/`).

## Camera motion (not fixed here)

A scratch native bench pans a 768×488 simulation window over the quiet pool at
4 cells per tick (receipts in `flipfix/pan_*`). Cached/dormant rebuild the index
on 11 of 96 ticks. Mean tick rises from ≈9.7 to ≈13.5 ms, with ≈35–43 ms spikes;
reference stays ≈34 ms. So ordinary camera movement with the simulation window
enabled still discards the cache at every selected-core change.

Whether `cold()` on a region change can be narrowed is a native question in
`World::set_simulation_region`. Heads and gas topology span all resident chunks,
but paused/interest-dependent gas proofs and certificates need their own proof.
`world.cpp` is in #358's write set. This is a recorded follow-up, not part of
this change.

## Limits

- One headless Windows run per row; no Linux host rerun, no moving body and no
  rendered FPS.
- The P1 wake summaries (#382) are not included. With both changes, the earlier
  local measurement reached ≈0.7 ms.
- Web, and any other host that writes regions, was not audited for the same
  pattern.
