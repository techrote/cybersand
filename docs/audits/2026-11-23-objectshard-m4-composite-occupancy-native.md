---
title: ObjectShard M4 native composite occupancy checkpoint
status: Draft/HOLD
document-kind: audit
scope: New native same-World collision primitive and executable conflict evidence; Workbench attachment NOT implemented
last-reviewed: 2026-11-23
---

# ObjectShard M4 — composite transient collision: source and qualification

**Decision: HOLD.** This checkpoint is a native precondition for M4; it is **not** a completed ObjectShard attachment, not a production-default or ordinary Workbench implementation, and is not eligible to merge without owner authorization. Keep #754 Draft. Never enable the existing standalone M3 coordinator as a second simulation owner.

## Implemented, source exact

- `World::compose_transient_obstacles` takes immutable-GCR and mutable-ObjectShard occupancy as separately complete, strictly row-major `std::span` value sets. Call only on the actual World owner thread between ticks. No extra World, independent tick, material copy or RID is introduced.
- The admission pass validates distinct GCR/shard ID domains, finite configured bounds, full reserved-mask capacity, duplicate coordinates, and cross-domain cell conflicts *before* calling the existing clear/set pipeline. A rejected transaction leaves all mask cells intact but **invalidates the prior composition receipt**; a partial installation quarantines the World. No stale mask may be treated as newly composed.
- The successful receipt contains a unique native-World lifetime token, monotonic composition revision, source cell counts, and the current completed tick. Legacy clear/set operations invalidate its currentness; the resulting receipt is not an authoritative material or Rapier installation acknowledgement.
- Tests exercise a real native `World`, not a mocked GCR field: positive two-domain publication, overlapping adversary, invalid body namespaces, duplicate coordinates, empty clean publication, stale receipt, and legacy-writer invalidation. A separate cross-World ABA test refuses an old receipt even if a replacement World publishes the same numeric revision. The **executable negative** replays GCR's legacy clear/rebuild against a composed field and verifies that the shard mask cells disappear. This is the unresolved runtime hazard—not a theoretical risk.
- The pre-existing native `Coordinator` remains privately World-owning, including a private `World::tick()` in its own `step`. Its M4 gate is a value protocol, not attachment. The ordinary `CyberSimulationWorker` still exclusively owns `CyberNativeCellWorld` and its `simulation_tick()`; its ObjectShard positive wrappers do not yet exist.

## Evidence, preserving failures

- Pre-existing focused corrective CI: [45070516485](https://github.com/techrote/cybersand/actions/runs/45070516485) — **PASS**, verifies restoration of omitted coordinator readback source, **prior to this change**.
- Initial local source composition (before rejected-update receipt fencing): Clang AddressSanitizer/UndefinedBehaviorSanitizer **3,517 checks, 0 failures**.
- Revised local source composition plus invalidation and actual legacy-writer negative: Clang ASan/UBSan **3,528 checks, 0 failures**, input digest `0cefe260ad6b2d83bbefae5c8cbbe8c0eab79ecf46fea20d15d39f7349ac3a90`. Local Clang compiles inherited unrelated unused-capture/constant warnings with `-Wno-error=unused-lambda-capture -Wno-error=unused-const-variable`; sanitizer leak detection was disabled. This is native coordinator qualification only, **not 192 existing World cases, Godot or Rapier**.
- Exact-commit Linux all ObjectShard native suites + existing World regression, strict GCC 13 and original failures are requested through the dedicated `.github/workflows/objectshard-m4-arbitration.yml` path. Any result must be checked against its actual commit SHA and retained artifact; no success is assumed before it runs. Historical CI [45067880867](https://github.com/techrote/cybersand/actions/runs/45067880867) and [45068629049](https://github.com/techrote/cybersand/actions/runs/45068629049) remain recorded build FAIL. Historical performance 10-of-74 timing-limit failures, six runtime-provenance mismatches and prior owner negatives remain outstanding and unmodified.
- M3 historical Windows artifacts, real Rapier movement and source-exact runtime prove only the **standalone** Lab; they cannot qualify this ordinary Workbench integration. No new Windows executable, live capture, local NVIDIA result or production runtime provenance is claimed.

## Required completion before positive ordinary Workbench test

1. Remove private `World` ownership and native tick from attached Coordinator policy. Attach the non-owning shard registry to the *existing* `CyberNativeCellWorld` owner with worker-bound generation/session/incarnation and no reset alias. Keep standalone M3 opt-in separately supported.
2. Make the ordinary GCR collector and shard occupancy collector submit their complete value sets to one owner-local composition call before contact processing. Reserve nonoverlapping body slots and route shard contact IDs separately from existing GCR body lookup; never let either collector clear the other's mask. Run Pressure/Wave Water coexistence.
3. Add source-authoritative cut/debit/terrain change, geometry and mass/COM/inertia receipts, main-thread Rapier installation acknowledgement, exact motion return, chemistry/Water/Fire exchange and settling handback. No generic painting fallback.
4. Implement the three positive `CyberSimulationWorker` methods required by `CyberObjectShardM4WorkbenchPort`, with bounded command/result queues, moving-cell witnesses, session + epoch + World generation + shard session + World/body incarnation fencing, reset/F2 and unknown-response HOLD.
5. Perform **non-skipped** actual Godot 4.7, both native platforms, Water/Fire/native World/actor/PUBPRES regressions and source-matched Windows evaluator packaging. Record material conservation, finite latency, real Rapier motion, re-editing and historical performance failures.

**Gate:** current owner-local occupancy primitive is executable and tested. End-to-end ordinary Workbench cut → detach → fall → settle → edit is **NOT implemented**. Preserve Draft/HOLD, no merge or release.
