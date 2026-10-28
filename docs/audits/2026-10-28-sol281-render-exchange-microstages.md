---
title: SOL281 worker render exchange, accumulation and copy attribution
status: Current
document-kind: audit
scope: Source-matched observational-only Linux and Windows Rapier qualification of render publication microstages in the bounded headless solid-detachment laboratory; not interactive production throughput
canonical-for: [sol281-render-exchange-microstages-evidence]
last-reviewed: 2026-10-28
related-documents: [../systems/solid-detachment.md, 2026-10-28-sol281-render-terrain-stage-attribution.md, sol281-2026-10-28/render-exchange-microstages-receipt.json]
---

# SOL281 — render exchange / accumulation / copy, 28 October 2026

## Frozen question and exact source

The [preregistration](https://github.com/techrote/cybersand/pull/283#issuecomment-6474373870) froze the previous draft-PR head `b2f37b39f4f76a5227a0fc5bad79e51cdcbcbe25` and its scoped [Linux/Windows predecessor](https://github.com/techrote/cybersand/actions/runs/40694663350). The previous study established that render preparation, not the nearly idle hard-surface rectangle refresh branch, dominated snapshot preparation. The next question was how much of the render interval lies in native-adapter packet exchange, GDScript accumulation, material-buffer duplicate, or remaining housekeeping. It **did not authorize a change to render exchange/copy behavior**.

The exact executable and qualification-source commit is [`d441a8a593f001d944d5f0691eab63d7614023c5`](https://github.com/techrote/cybersand/commit/d441a8a593f001d944d5f0691eab63d7614023c5), tree `5f5ed3d5071be0f6c917db6c69d1ee5708f54d39`; it changes only `simulation_worker.gd`, `simulation_snapshot.gd`, `solid_detachment_session.gd`, the existing compound test and four corresponding scoped-workflow assertion-count literals. [Run 40724802526](https://github.com/techrote/cybersand/actions/runs/40724802526) **passed source, actual Linux Godot/Rapier, pinned Windows native build and actual Windows Godot/Rapier**. [Documentation/provenance run 40724811601](https://github.com/techrote/cybersand/actions/runs/40724811601) passed at this executed source. All four original ZIPs were downloaded, independently SHA-256/CRC checked and matched their GitHub Actions digests; see [machine receipt](sol281-2026-10-28/render-exchange-microstages-receipt.json).

## What the instrumentation actually partitions

Within the existing `CyberSimulationWorker._publish_snapshot` render stage:

- **Exchange:** time inside the existing `_world.take_render_snapshot(...)` call, counted once or twice if the pre-existing overflow retry executes. Native `CyberNativeCellWorld::take_render_snapshot` internally performs `RenderSnapshotExchange::publish`, dirty/full cell extraction, packed-array construction and Godot value conversion. The timing **cannot distinguish those internal native substeps**.
- **Accumulation:** existing `_append_native_render_packet` calls, including packed patch and metadata aggregation.
- **Full-material copy:** the existing `_pending_render_patch_cells.duplicate()`, or the fallback material read and packed-copy.
- **Residual:** all remaining render-stage time, including patch acknowledgements and cleanup, mutex/metadata, timing and control flow.

These are **disjoint, nonoverlapping per-snapshot intervals** with a nonnegative residual. Their *per-snapshot sum* equals the existing render interval to a 0.002 ms tolerance, validated on every accepted latest-only sample. Do not add the separate p95 percentiles. Added packet-byte and per-refresh call counters expose full/dirty and retry behavior without extra native work. Immutable snapshot publication remains worker-owned; tests and consumers operate on copied scalars only. The original 512-latest-sample cap remains.

## Source-matched observations

All p95 values are milliseconds, from separate asynchronous latest-only histories of the same frozen source. A = 81 default search candidates; B = 289 diagnostic-only candidates, **not admitted to production**. The table does not imply matched A/B causal comparisons.

| OS / policy | Samples / refresh | Render p95 | Native exchange p95 | Accumulation p95 | Material copy p95 | Residual p95 | Pre-mutex total p95 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Linux A | 165 / 89 | 51.918 | 51.642 | 0.251 | 0.002 | 0.026 | 52.174 |
| Linux B | 118 / 112 | 51.647 | 51.392 | 0.239 | 0.002 | 0.025 | 51.886 |
| Windows A | 303 / 111 | 22.207 | 21.424 | 0.787 | 0.002 | 0.030 | 22.508 |
| Windows B | 297 / 164 | 22.176 | 21.427 | 0.769 | 0.002 | 0.028 | 22.456 |

Every arm's hard-surface stage p95 is 0.002 ms. The exchange accounts for almost the entire expensive render-stage p95. The call counters are unusually informative:

| OS / policy | Native exchange calls | Two-call refreshes | Payload bytes returned by both calls | Worker overruns |
|---|---:|---:|---:|---:|
| Linux A | 178 | 89 / 89 | 186,722,120 | 100 |
| Linux B | 224 | 112 / 112 | 234,952,628 | 111 |
| Windows A | 222 | 111 / 111 | 232,820,088 | 23 |
| Windows B | 328 | 164 / 164 | 343,974,622 | 27 |

**Critical fixture limitation / negative interpretation:** `godot/scripts/solid_detachment_session.gd` consumes the latest worker snapshot for physics but **never acknowledges a successfully uploaded render packet**, because this is a headless Rapier test with no render upload. In normal desktop `godot/scripts/main.gd`, render acknowledgements occur *after successful texture upload*. In the worker, patches are retained until acknowledged; the pending patch buffer can exceed the fixed byte limit and trigger the existing **second forced-full native render call**. In all four observed arms, **every refresh sampled exactly two native exchange calls**. This strongly identifies repeated unacknowledged/overflow native exchange work in the headless test path, **not representative production rendering cost and not yet a demonstrated causal or fixable 60 FPS bottleneck**. No render packets are silently acknowledged or dropped by the new source.

The next performance experiment should independently preregister a genuinely **render-consumed, acknowledgement-correct** control against this deliberately unacknowledged negative fixture, on identical pinned source and real Linux/Windows hosts. Do not insert an acknowledgement before consumption merely to improve benchmark numbers. If the native exchange remains expensive with correct acknowledgements, only then split native `publish` / full-vs-dirty extraction / packed copy and inspect active visual update rates under representative frame pacing.

## Exact-source safety, artifacts and exclusions

Both OSes passed **1,414 assertions, zero script failures per OS**: real motion 21, rollback/failure 20, lifecycle 296 across 18 replacement cycles, unresolved ABI 43, deterministic controlled search/topology 924, and 55 checks each for default A and diagnostic B live six-proxy coupling. All arms retain exactly 520 aggregate-held native member cells, one Rapier aggregate with six non-filling proxies and two open holes, Sand 104, Water mass 1,020, a 12-field body-result ABI, zero stale results and zero invalid timing samples. Native C++, actual cell edits/mass, material/liquid construction and per-proxy masks were not changed. This scoped execution is not an independent general liquid-policy matrix.

The independent ZIP SHA-256 digests are source `ddf3a91f5f3a01047f2b54a1c261628ba24a7e726ea2c8e1f45b8cd7e8af04eb`, Linux execution `d7538d0960eddf7176d7c3aa81dbef7c37fbc9c88903d3f9cfc99bbc930e5aa7`, Windows build `83da6779f96919540a9c001b8641f0fd5f2466559a76a91b7621c1f3f8dad55e`, and Windows execution `b50634dd55ce4cdcc774a192a310f2aa3a7d48c36fac4464c27c3798441f35f7`. Archived Git-source TAR.GZ SHA-256 is `a18f67f39ac85f06449c996c56a91a67f747ffd00545bee671ac9080f05bcbab`. The Linux runtime SHA-256 is `244b0270f31c37135256524a5ca1d27afac32d1afbbf02c88b215e4e2fdb85bb`; the pinned Windows DLL has SHA-256 `40ab0b82a0d118ca027baec1a099afdea9704f46fb57a0ebc42c450007fbca8f` in both build and execution receipts. Independently matched all **549/549** Windows source-manifest input bytes against the archived Git tree, zero mismatches; the Windows execution reported 92 explicit EOL-only checkout restorations. All eight Windows execution log SHA-256 digests matched their raw ZIP contents with return code zero. The four ZIPs passed CRC checks.

The previous [render-versus-terrain study](2026-10-28-sol281-render-terrain-stage-attribution.md) and the prior failed [count-literal CI run 40694452595](https://github.com/techrote/cybersand/actions/runs/40694452595) remain distinct historical evidence; no previous failure is relabelled or overwritten. The earlier 289-probe B movement candidate remains **NO-GO** against its preregistered 20-percentage-point efficacy threshold; this instrumentation makes **no physical relocation, search/mask/material/policy, native ownership, or Rapier threading changes**. Unresolved dense-bank overlaps remain high and worker overruns persist.

**Unqualified and blocking:** a physically admissible, mass-conserving bounded relocation policy; representative complete worker/main-thread/render pacing; reactive Wood/heterogeneous structural bonds; multiple aggregates, desoliding/fracture and persistence; independent code/architecture review; full ready-PR matrices and formal runtime publication. Issue #281 remains open; PR #283 remains draft/unmerged, stacked on draft #282. Nothing here qualifies Stage 3B or production soliding.
