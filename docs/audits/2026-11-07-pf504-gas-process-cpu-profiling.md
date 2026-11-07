---
title: PF504 workbench stress-canvas gas-stage process CPU attribution
status: Planned
document-kind: audit
scope: Exact-source same-host Linux CPU profiling of 2048x1024 authored workbench stress-canvas
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf504-actual-workbench-stress-ab.md, ../architecture/pressure-optimization.md]
---

# PR #504 — full workbench gas-stage process CPU profiling

## Motivation

Source-matched [native synthetic comparison](https://github.com/techrote/cybersand/actions/runs/42333533560) found +14.10% native tick and +19.36% gas-phase wall improvement. The earlier [half-scale Windows real application screen](https://github.com/techrote/cybersand/actions/runs/42340715185) found -2.71%; the subsequently completed [full 2048x1024 actual workbench B-C-C-B](https://github.com/techrote/cybersand/actions/runs/42342604239) found +2.1686%. These are different workloads, hosts and clocks; their ratios must not be averaged or treated as CPU measurements.

## Exact-source isolated instrumentation

- Pinned **accepted C2048 baseline**: `24a8bbe8ccf0d17196ebbab580b924930a964584`.
- Pinned **optimized #504 source**: `186452b9f035961325ad71917a76ba8834e30bcf`. Later #504 revisions are deliberately excluded.
- After verifying protected source LF SHA-256 and identical production source scope, apply **the same test-only clock and observation overlay** to both independent checkouts. Nothing is committed to production protected files; the base and candidate Git source identities and pre-/post-overlay LF hashes are archived.
- Linux C++ `std::clock()` clocks measure **process-wide cumulative CPU time**. Samples bracket `resolve_gas_topology` + gas decision, the pressure-head/certificate preparation and the complete native `World::tick` call. They include unrelated process threads scheduled concurrently, so bracketed **process CPU is not isolated gas-worker CPU**. Existing pressure `gas_nanoseconds`, `head_nanoseconds` and workbench `simulation_time_ms` remain separate wall-clock quantities.
- Copy only cumulative native counters/worker participation into the workbench's immutable snapshot on the exclusive worker thread while `PF504_STAGE_PROFILE=1`; no mutable World reference crosses threads.
- Preserve original pressure law, material rules, C2048 opt-in, CYPS5/hash5, default FreeMass, native active-body masks and the existing paired workload.

## Workload and acceptance

One Linux host, two separately compiled source-matched native GDExtensions, **B-C-C-B**, fresh actual Godot 4.7 workbench and Rapier sessions. Use the original `workbench_setup.gd::stress_canvas` (2048x1024, eight barrels), PF gas `cached_dormant` explicit C2048, ballistic face/jet/spray, hard wall/erase edits every two native ticks, 24 warmup and 240 requested native sample ticks.

Independent readback fails closed on missing source/overlay SHA, absent native worker or pressure CPU counters, no gas work, too few actual actor/collider/edit samples, stage CPU exceeding complete native tick CPU, mismatched toolchain/runtime identity, or incomplete B-C-C-B. Retain raw per-run Godot logs, original build logs, exact binary hashes, profiler overlay manifest, and the full JSON report.

Report paired gas wall and gas process CPU per native tick, head wall/head process CPU, total native process CPU, gas fraction of native tick CPU, seed/BFS/relabel work, reference/reuse/fallback counts, observed workers and actual workbench p50/p95. Use those to test the Amdahl/workload-mix explanation without *asserting* the cause until the evidence supports it.

## Release/physics limits

Ordinary asynchronous native/Rapier actor and jet timing may differ, and the inherited workbench lacks a complete native physical-state hash/quantity replay. The process-CPU clocks cannot prove that other Godot threads did no work during the gas-stage bracket. This bounded profiling experiment cannot authorize #504 merge, production LFS publication or a full 1080x2 factorial. Any physical source change after this pinned revision requires a fresh independent exact-source campaign.

**Status:** planned; no result claimed before the hosted comparison actually executes.
