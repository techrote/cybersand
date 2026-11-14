---
title: ENG-LAB-001 Phase B — active Needle four-family Water comparison
status: Planned
document-kind: guide
scope: Repeated same-host real Workbench/Rapier/native four-family clocks, independent of production timing policy
canonical-for: []
last-reviewed: 2026-11-14
related-documents: [engine-lab-passive-benchmark.md, lcb-manual-comparison-ux.md, ../architecture/liquid-solver-family-policy.md, ../architecture/simulation-tick-and-threading.md]
---

# Phase B — matched four-family Water + active Needle

**Isolated stacked Draft/HOLD experiment.** Phase A [#602](https://github.com/techrote/cybersand/pull/602) supplies the read-only Engine Lab recorder. This follow-up is based on its exact qualified head `4ae1f82a7ec5c156e3d931af14c543cd53deda6d` and must not modify or merge that parent. Issue [#599](https://github.com/techrote/cybersand/issues/599) owns the sequencing. RENDER-ACK-002 [#585](https://github.com/techrote/cybersand/pull/585) remains FURTHER RESEARCH, excluded from this source.

## Real executable path

`godot/tests/bench_engine_lab_water_family.gd` constructs a **fresh Shared Workbench Main**, pins the requested native worker count before construction, builds the same 1024×1024 authored start, admits one real human-controlled **Needle** flyer at (459,215), installs the real native Water policy with positive per-material family/variant readback, and checks the physical sample/collider owner has been adopted. The initial water reservoirs, fixed Sand shelves, hard walls and divider, spawn, camera (960×540 at 16,155), requested graphical window (1600×900; actual OS-clamped size recorded and required identical within each host), engine 60-FPS cap, 1-second wall warmup and passive 10-second capture do not vary. No input is injected or simulated; gravity and fluid forces may move the actor. The test refuses a paused, stale, missing or failed native owner and requires positive *measured* native ticks and Rapier steps. Every arm creates a new Godot process and its own sandboxed user data.

Four explicit native Water choices:

| Label | Required actual applied family | Variant |
| --- | --- | --- |
| FreeMass | `freemass_v1` | `reference` |
| Pressure | `pressure_flow_v1` | `cached_dormant` |
| Cellular Yield | `cellular_yield_v1` | `reference` |
| Inertial | `inertial_cellular_v1` | `reference` |

**Non-equivalence that cannot be hidden:** Inertial requires native rule radius **3**, while normal non-IN policies use radius **2**. The fixture hash explicitly excludes the requested policy *and* radius so that identical authored cell geometry/actor starting setup can be checked. Each report also retains the separate required native radius. The four-family comparison is therefore a comparison of **legally configured solver families**, not a one-parameter-only A/B of the same physical radius.

The campaign includes **1 and 4 worker** variants, with **two fresh-process repetitions** per family/worker pair (16 measurements per platform). Per-worker runs use forward and reverse family orders to reduce drift/order bias. Pinned Windows Godot 4.7 ANGLE Microsoft Basic Render Driver and Linux llvmpipe demonstrate software-rendered behaviour only, **not NVIDIA hardware**. Their absolute times need not agree.

## Evidence and interpretation

Every per-case receipt includes native applied-policy hash and positive construction receipt, the physically adopted one-Needle source, actual worker readback, body state and session tick, source/engine/native binary hashes, renderer/adapter, window/camera/extent, and complete raw Engine Lab per-frame samples. The offline reducer reports:

- Real-time native completed ticks/s, manually completed Rapier steps/s, and the rates' relationship to the nominal 60-Hz target
- Complete Main callback interval p50/p95/p99/max; last-completed native/worker/Rapier cost p95 and accepted material snapshot age
- Workbench native-sample, terrain and no-owner held-physics-callback counts
- Main accepted material render serial increments and their timing
- One-second wall bins and the first **observed** native/Rapier/presentation divergence, labelled as *advisory association*, not demonstrated causality
- Actual timeouts/failures, preserved as failures; one failing process stops the campaign rather than silently excluding it from averages

`tools/engine_lab/run_water_family_matrix.py` first supports a one-case FreeMass smoke to establish native policy + actor adoption before expanding to the complete matrix. Its summaries must not promote a preferred Water solver solely because one family naturally settles earlier, or because a software backend overload produces different presentation.

**Owner follow-up:** Repeat qualified scenarios on Windows 11 NVIDIA, with the same window and native worker count. An active native performance advantage can coexist with worse physical visual continuity; check both clocks and render cadence. Alternative Workbench sample-fence or native/Rapier synchronization policies remain **deferred** until these observations localize the limiting stage.

## No scope expansion

This is new research harness/CI and source documentation only. No changes to native cells, Rapier code, native timing parameters, worker/texture ACK semantics, production default, #585/#583/#578 source, or independently owned UI/physics features. Do not merge the stacked PR. Complete exact-head Windows/Linux provenance and application tests before treating the results as a qualified comparison.
