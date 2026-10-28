---
title: SOL281 worker render-versus-terrain snapshot stage attribution
status: Current
document-kind: audit
scope: Preregistered observational A/B source-matched Linux/Windows Godot/Rapier qualification of native-worker render and hard-surface preparation timing; excludes production and physical-ejection admission
canonical-for: [sol281-render-terrain-stage-attribution-evidence]
last-reviewed: 2026-10-28
related-documents: [../systems/solid-detachment.md, 2026-10-28-sol281-ejection-topology-census.md, sol281-2026-10-28/render-terrain-stage-receipt.json]
---

# SOL281 — render versus terrain snapshot preparation, actual Linux/Windows (2026-10-28)

## Frozen experiment and exact execution identity

The [preimplementation registration](https://github.com/techrote/cybersand/pull/283#issuecomment-6469867725) followed [exact-source publication assembly qualification](2026-10-28-sol281-ejection-topology-census.md#addendum--preregistered-snapshot-publication-stage-attribution-source-9c97dc09-2026-10-28). It asked which portion of the expensive *pre-assembly* worker interval was render snapshot/patch preparation versus hard-surface rectangle preparation, without changing either branch's conditions, native ownership, algorithms or cadence.

Implementation commit [`39aa2e4d`](https://github.com/techrote/cybersand/commit/39aa2e4d2c6f664b10a2a138989c769ccf63cce0) changed only `godot/scripts/simulation_worker.gd`, `simulation_snapshot.gd`, `solid_detachment_session.gd` and `test_solid_detachment_coupling.gd`. Subsequent [`9725885d`](https://github.com/techrote/cybersand/commit/9725885d6c3007376c7b192324514e8ca32fa880) changes only four expected assertion-count literals in the scoped workflow from 48 to 51; its executable logic is otherwise byte-identical. **The exact executed CI source is `9725885d6c3007376c7b192324514e8ca32fa880`, Git tree `cabe4c048534b6c82477a365c008e7702e3d5d1e`.** Actual scoped [run 40694663350](https://github.com/techrote/cybersand/actions/runs/40694663350) passed source, Linux Rapier, pinned Windows build, and Windows Rapier jobs. The [same-source documentation/provenance check 40694674219](https://github.com/techrote/cybersand/actions/runs/40694674219) passed.

The original `snapshot_copy_time_ms` still runs from `CyberSimulationWorker._publish_snapshot` entry to pre-assembly. This experiment partitions that existing interval into `snapshot_render_stage_time_ms` (entry, patch acknowledgement/cleanup, optional render packet and patch handling) and `snapshot_terrain_stage_time_ms` (revision read and optional hard-surface rectangle refresh). Their durations sum to the existing copy interval subject to a 0.002 ms float-rounding tolerance. The separate immutable boolean flags `snapshot_render_stage_active` and `snapshot_terrain_stage_active` mark the corresponding **refresh branch entered**, not guaranteed changed pixels/rectangles. All four scalars are copied before immutable snapshot publication; worker ownership and Rapier main-thread ownership are unchanged.

The diagnostic session retains its **latest-only, up-to-512 accepted sample** rule; the branch-active distributions are subsets of the same snapshots, not independent per-tick telemetry. The A/B host tests require finite, non-negative bounded stages, coherent sample counts, stage p95 no greater than copy p95 (tolerance) and no invalid samples. A no-refresh distribution of zero samples correctly reports p95=-1, **not a measured zero-duration hard-surface refresh**.

## Qualified real-host observations — separate, unpaired histories

| Runtime / opt-in probe policy | Latest-only samples | Render stage p95 | Terrain stage p95 | Render refresh samples | Terrain refresh samples | Pre-mutex total p95 | Worker overruns |
|---|---:|---:|---:|---:|---:|---:|---:|
| Linux A / 81 default | 273 | 30.751 ms | 0.002 ms | 97 | 0 | 30.994 ms | 52 |
| Linux B / 289 diagnostic-only | 237 | 31.154 ms | 0.002 ms | 121 | 0 | 31.391 ms | 58 |
| Windows A / 81 default | 282 | 24.420 ms | 0.001 ms | 104 | 0 | 24.646 ms | 29 |
| Windows B / 289 diagnostic-only | 292 | 24.437 ms | 0.002 ms | 137 | 0 | 24.668 ms | 35 |

**Finding within these four real-host fixture histories:** render-stage work accounts for almost all costly pre-assembly work; the hard-surface stage is practically idle and no hard-surface refresh branch was observed during the accepted samples. This narrows the performance investigation to the render path of `_publish_snapshot`, including `CyberNativeCellWorld::take_render_snapshot`, patch handling, native/GDScript copies and acknowledgement. **It does not identify which internal operation dominates**; the refresh counts and p95 values alone cannot separate native exchange publication from full/dirty cell copies, Godot packed-array allocations, patch aggregation, or thread interference. Earlier ~52ms Linux/~23ms Windows snapshot-preparation measurements are different asynchronous histories and are retained without replacing or averaging them. There was **no optimization**; p95 ratios must not be interpreted as a matched causal experiment.

Each OS passed **1,406 assertions, zero script failures**: 21 live motion, 20 failure/rollback, 296 lifecycle/18 replacements, 43 unresolved-ABI diagnostics, 924 deterministic bounded search/topology controls and 51 per actual moving compound A and B. The focused Linux native suite passed **13,074 checks** across eight groups (and retains its two existing warning sites). Every live compound retained exactly **520 native member cells**, one Rapier body with six non-filling proxies, both empty holes represented by the observed initial body-ID prefix `[2,0,0,6]`, Sand104 and Water mass1020 conserved, 12-field result ABI, zero stale results and zero unclassified/immovable/relocation-refused outcomes. All four A/B runs still have high **~95–99% unresolved overlap attempts**, entirely classified as no target. Worker overruns persist. Native default material/liquid construction policies were not edited; the source-preserving tests do not amount to an independent full-policy matrix.

## Provenance and retained negative result

Downloaded all four final-run ZIP artifacts, independently CRC-checked them and matched their GitHub Actions SHA-256 digests. Source ZIP `fb9a76a5c84c5919f696bbcd65b2676a609749480a5381bea955f720d03c9108` contains TAR.GZ SHA-256 `a7c61d0b29522aaed1bb5b576bfab3227487255cb77c12143792a275e74914ac` and its exact Git tree. Independently compared all **549/549 Windows build-manifest input hashes** against the exact archived Git-source bytes. Windows Git-byte validation recorded **92 explicit EOL-only checkout normalizations**, not unverified source drift. The built Windows DLL SHA-256 `c8a23b88c5c81aaf248dc2afd46b861ac79ba35d3b6edbc223a3e1aa74fbac3e` matches the Windows execution receipt; all eight recorded Windows log hashes and zero return codes match their bytes. The four ZIP IDs and hashes, platform assertions, stage samples and diagnostic counters are archived in the [machine receipt](sol281-2026-10-28/render-terrain-stage-receipt.json).

**Retained failed run:** the initial [`39aa2e4d` scoped run 40694452595](https://github.com/techrote/cybersand/actions/runs/40694452595) was **red on both live-host execution jobs**, despite the new GDScript returning 51 checks and zero failures for Linux A/B and Windows A. The CI wrapper still demanded 48; Windows failed at its A postcheck before B. Its execution/source artifacts remain archived and its failure is **not relabeled a pass**. The single workflow-literal correction at `9725885d` subsequently passed all four scoped jobs. This is a harness-contract repair, not evidence that physics, throughput or native behavior improved.

## Open acceptance gates and next bounded test

The dominant render-stage interval is **only part of pre-mutex worker preparation**. The published total excludes final mutex handoff, worker scheduling/sleep, derived owner command-reply path, main-thread Rapier/render and actual interactive frame delivery. Even headless physics-frame samples cannot establish representative 60 FPS. A new preregistered stage split inside native render publication, dirty/full snapshot selection and packed-cell/patch copy operations is the smallest next performance question; keep changed-pixel frequency and branch counts visible and compare same exact pinned source/runtime conditions. A separate **physically admissible bounded, material-conserving push/relocation candidate** requires independent preregistration and validation; the existing 289-probe B is still **NO-GO** under its previous 20pp efficacy criterion.

Reactive Wood, multiple live aggregates, fracture/restoration, persistence, normal-gameplay integration, representative frame pacing, full ready-PR CI and independent review remain unqualified. Issue #281 stays open; PR #283 stays draft and unmerged. No ejection target, mask, material ownership, solver policy or Rapier/main-worker lifetime contract is promoted by this study.
