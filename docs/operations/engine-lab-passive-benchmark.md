---
title: Engine Lab Phase A — passive Workbench clock benchmark
status: Planned
document-kind: guide
scope: Research-only bounded current-World timing observations, not physics control or solver selection
canonical-for: [engine-lab-passive-benchmark]
last-reviewed: 2026-11-14
related-documents: [../architecture/simulation-tick-and-threading.md, ../architecture/rendering-and-gameplay-bridges.md, ../reference/status-and-roadmap.md]
---

# Engine Lab Phase A — passive Workbench benchmark

**Prototype in Draft/HOLD [ENG-LAB-001 PR #602](https://github.com/techrote/cybersand/pull/602); not a production release.** Issue [#599](https://github.com/techrote/cybersand/issues/599) records the owner-requested ordering. RENDER-ACK-002 remains FURTHER RESEARCH on independent [#585](https://github.com/techrote/cybersand/pull/585); this tool neither enables it nor merges it.

## How to run

Open the Shared Workbench, start a chosen World, select the intended Water family and any flyer, then click **Engine Lab** next to Art batches. The floating window displays native target tickrate (60 Hz), recent actual native completed ticks/s, separately completed manually stepped Rapier steps/s, nominal Godot physics callback rate, actual Rapier manual timestep, current render serial/age and selected Workbench sample/collider hold counters.

Click **Benchmark current World / 10s** while unpaused. Allow the World to run without touching controls. **No input is injected, no World state is captured/replayed, no physics policy is changed.** A single JSON file is written when a run completes or is cancelled/invalidated; the resulting absolute path is printed as `ENGINE_LAB_PASSIVE_REPORT` and shown in the window. The Godot per-user data directory, not the extracted executable folder, owns the file.

Do not compare unrelated states. Save a named starting setup; in a separate fresh process, reload that setup, confirm policy/actors/dimensions, and start measuring after the same warm-up. This is **not** deterministic input replay or a certified identical native state reconstruction, because named starts describe authored setup, not the evolved simulation tick.

## Clock semantics and admitted observations

| Field | Exactly what it measures | Not evidence of |
| --- | --- | --- |
| `frame_interval_ms` | Intervals between Engine Lab's Main-thread UI samples | GPU execution completion, physical display scanout |
| `actual_native_hz` | Increase in the latest completed native tick index divided by wall seconds | Scheduler target rate, per-tick wall duration or perfect 60 Hz |
| `actual_rapier_hz` | Completed manual Rapier steps divided by wall seconds | Automatic built-in physics stepping or an absence of interpolation |
| Native/worker/step duration distributions | Last completed tick/step timing observed at each advancing sample | Complete every-tick history if worker progressed more than one tick between UI samples |
| `coupling_held_physics_frames` | Main callback early-return counts **only while the benchmark is armed** (Workbench sample/terrain/no-owner, desktop lockstep) | Held milliseconds, blocked native threads or guaranteed attribution of visible judder |
| `accepted_publications_observed` | Changes in Main's last accepted render serial | Native captures or GPU transfer completions |
| `render_payload_age_at_frame_ms` | Age of last generated material packet as observed at UI sample | Time since displayed frame or GPU scanout |
| `peak_static_memory_bytes` | Godot-reported static allocation high-water | Full process RSS, VRAM |

Native World material and Rapier physics remain independently owned. On Shared Workbench, the existing completed-sample/terrain fence governs whether Rapier may step; the separate default-off `--lockstep-coupling` mode does **not** apply there. Both native fixed timestep and nominal Rapier manual step are currently 1/60 second. Varying `Engine.physics_ticks_per_second` alone would mismatch Rapier's `ProjectSettings`-derived fixed delta and 60-Hz actor contracts. **This phase exposes no live tickrate/synchronisation controls.**

Recording is bounded to 4,096 samples and a maximum requested duration of 20 seconds (10 seconds from the UI). Counters are gated off when unused. On cancellation, pause, owner/reset epoch transition, time reversal, render-serial reversal or capacity refusal, a report is marked `incomplete` and retains available evidence instead of claiming a successful benchmark. One report is persisted at disposition, not one file write per frame.

The collector does not disable or police the user's keyboard, camera, other tools or unrelated background activity; it emits an explicit human-input-uncontrolled limitation. It never mutates the native World, Rapier RID, camera or GPU texture as part of the benchmark.

## Next controlled experiment — four Water families

After exact-source Linux and Windows qualification and human inspection of the passive readouts, compare:

1. PressureFlow / pressure dormant
2. FreeMass
3. Cellular Yield
4. Inertial

Run every family with the same actual host/GPU, matched window resolution, starting setup, actor model and 1/4 native-worker selection. Measure native ticks/s, Rapier steps/s, frame p50/p95/p99, coupling callback holds and material serial cadence separately. Keep raw JSON and the exact source/engine/runtime/policy identity. Use repeated balanced order where feasible, not one visual clip. A family that settles earlier may exhibit higher later FPS without having a cheaper active simulation at equal state.

Only after the rate/cost differences are attributable may an independent opt-in experiment consider a different Workbench sample fence or physics synchronisation. **A new nominal 60-Hz Rapier cap is not a fix: one already exists.**

## Evidence / limits

The scoped qualification workflow is `.github/workflows/eng-lab-passive.yml`, running `tools/engine_lab/qualify.py` with pinned Godot 4.7 and source-matched Windows/Linux native/Rapier runtime assets. Detached recorder regressions cover immutable samples, monotonic IDs, actual-rate arithmetic, refusal/cancellation and maximum bounded capacity. Mounted Workbench smoke exercises paused refusal, unpaused start, single completed JSON report, cancel and disposal. These are research tests; graphical CI uses Windows ANGLE Microsoft Basic and Linux llvmpipe software renderers, **not an NVIDIA hardware qualification**.

Source/branch validation and owner acceptance are separate from the existence of this document or a passing narrow test. No merge or production-default promotion is authorized.
