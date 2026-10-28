---
title: SOL-DETACH-001 exact-source no-target local topology census
status: Current
document-kind: audit
scope: Native-owner opt-in observational classification of failed ejection at dabe2b30, actual Linux/Windows Godot Rapier and sampled worker pacing; no production admission
canonical-for: [sol281-ejection-topology-census-evidence]
last-reviewed: 2026-10-28
related-documents: [../systems/solid-detachment.md, 2026-10-28-sol281-ejection-search-ab-result.md, 2026-10-28-sol281-ejection-search-preregistration.md, sol281-2026-10-28/topology-census-receipt.json]
---

# SOL281 — bounded local no-target topology census (2026-10-28)

## Preregistration, exact source and non-acceptance decision

The [frozen PR #283 preregistration](https://github.com/techrote/cybersand/pull/283#issuecomment-6463108213) preceded implementation. It asks whether a failed directional ejection search has any nearby empty, unmasked destination under the existing path predicate. This does **not** reopen the earlier [negative ejection-search experiment](2026-10-28-sol281-ejection-search-ab-result.md): expanding 81 probes to a 289-probe maximum failed its precommitted 20-percentage-point improvement on both OSes at source `2d623e1034075f26b5443997781a267f16eeee85`. B is **NO-GO** and remains opt-in and diagnostic-only; A remains the production default.

The [actual scoped Linux/Windows CI run 40649752504](https://github.com/techrote/cybersand/actions/runs/40649752504) passed on October 28, 2026 at exact execution commit `dabe2b30966e952ebadb84ab7f482d49ca500bb9`, Git tree `a9db6ff6136e06ac133063f3cfd4620f0216e38b`. The same source's [documentation/provenance run 40649759523](https://github.com/techrote/cybersand/actions/runs/40649759523) passed. The fixed 12-float rigid-body result ABI, native authoritative material storage, existing per-liquid construction policy and main-thread Rapier versus native-worker split remain unchanged.

## Bounded, non-mutating instrumentation

An explicit diagnostic-only `diagnostic_reset({"ejection_topology":true})` enables a **17×17 radius-8 read-only census** after the ordinary (A) or experimental (B) search fails. It scans at most the **first 16 no-target events per native-owner preparation** and exposes an explicit `skipped_capacity` for later attempts. A candidate void must be stored Empty and outside all transient masks. The existing straight-segment path predicate sorts each classified failure into `off_axis_direct_path`, `nearby_void_path_blocked` or `no_nearby_unmasked_void`. The counters travel through the exclusive-worker copied diagnostic command, never a mutable World pointer or worker-side Rapier API.

**Critical limitation:** the inherited path predicate can pass through *movable* material, and the selected void may be behind the outward normal. Consequently `off_axis_direct_path` does not establish physically connected free space, a valid displacement, or a safe opportunity to teleport a grain. The experiment only classifies a weak topological question; it must not be used to authorize any new search or cell-moving rule.

The two complete-owner identities are `no_target_events = classified + skipped_capacity` and `classified = off_axis_direct_path + nearby_void_path_blocked + no_nearby_unmasked_void`. In both OS/selector hosts these identities held with zero skipped events.

## Actual-host census — four non-equivalent asynchronous histories

| Owner-level no-target event | Linux A | Linux B | Windows A | Windows B |
|---|---:|---:|---:|---:|
| All failed search events | 2,307 | 619 | 3,125 | 1,206 |
| Classified | 2,307 | 619 | 3,125 | 1,206 |
| Off-axis void passes inherited straight-path check | 2,307 | 619 | 3,125 | 1,205 |
| Nearby void, direct path blocked | 0 | 0 | 0 | 1 |
| No nearby unmasked void | 0 | 0 | 0 | 0 |
| Skipped by per-preparation capacity | 0 | 0 | 0 | 0 |

**Finding:** across 7,257 owner-level failures, every event had an empty unmasked cell inside the local radius under this diagnostic definition; 7,256 had at least one passing the permissive path check. These are **repeated owner attempts, not unique cells or 360 physics frames**. Counts depend on native tick cadence, worker snapshots and host scheduling. The Linux/Windows A and B trajectories were not identical; comparing their raw no-target totals is **not** a new causal efficacy test. Accepted immutable proxy-result snapshots can omit native attempts, so those lower `unresolved` counters are deliberately not equated to native-owner census totals.

## Worker and headless frame pacing — sampled evidence

| Measurement | Linux A | Linux B | Windows A | Windows B |
|---|---:|---:|---:|---:|
| Observed worker-timing snapshots | 207 | 114 | 232 | 296 |
| Worker step p95 (ms), excluding publication | 0.699 | 0.926 | 0.312 | 0.396 |
| Native tick p95 (ms) | 0.284 | 0.244 | 0.099 | 0.100 |
| Snapshot-publication copy p95 (ms) | 51.218 | 51.542 | 17.549 | 17.893 |
| Main-thread Rapier step p95 (microseconds) | 217 | 219 | 262 | 295 |
| Headless physics-frame interval p95 (microseconds) | 20,719 | 20,708 | 20,709 | 20,712 |
| Frame intervals above 16,667 microseconds / 360 | 149 | 150 | 150 | 149 |
| Worker-overrun counter | 88 | 111 | 1 | 0 |

The native worker step measurement stops **before** copied snapshot publication, so it is not a full worker-loop cost. Linux's sampled publication-copy p95 above 51 ms with 88/111 worker overruns, versus Windows about 18 ms and 1/0, is a substantial separate qualification concern. The 360 physics-frame intervals come from a **headless manual Rapier fixture**, not representative interactive render FPS. Worker samples are **latest-only**; changes in sampled p95 or A/B sample count cannot be attributed causally to the diagnostic or to policy B without a new matched experiment.

## Source/archive rehash and preserved invariants

The retained Git source ZIP (`595dbf8e2ca27be30494091c81594f258384751767964eb09a71c1241cc86bde`) contains a tar archive with SHA-256 `9bdfa7f01c40524dee5615aeb4195d8982f6c457abbd86d641bf48f58ba98b94`, matching the archived Git source commit and tree. All **549 Windows build-manifest source-input SHA-256 hashes** independently match this tar; **zero mismatches**. Eight changed Git blob hashes were separately matched against current GitHub commit contents. Windows normalized 92 EOL-only checkout paths to the exact Git bytes before executing; no non-EOL divergence was admitted.

Source-bound runtime receipts: Linux native `.so` SHA-256 `9937b96f1e9fc6496cd64ab03b2c44f65540e863bf50328252917859a9848b6e`; Windows native `.dll` SHA-256 `7712af9322ac2e4da20e8bfea1a307ec121eb010fd52a9c6f6ff0ad51dc087cd`. Execution artifact ZIP SHA-256: Linux `d28c716499db64c685c0995bb4827bba0b9a3b99849b1113e84cb6dc20e8769d`, Windows `6b23fa214e34d189af11cf6ef9e77345e4629346011a85ebb0e7468f22ad9c82`; Windows build ZIP SHA-256 `777f2d970c5c43173071e32af02f4589316f4b91c008283b5bd397037bd47daf`. All downloaded artifact ZIPs passed CRC inspection. See the [compact machine receipt](sol281-2026-10-28/topology-census-receipt.json) and the [run artifacts](https://github.com/techrote/cybersand/actions/runs/40649752504#artifacts).

Each OS passed **943 scoped checks**: actual Rapier motion 21, failure cases 20, lifecycle 296, cause/ABI 43, deterministic native/fallback ejection policy 473, and two 45-check moving compound Sand/Water fixtures. Native/worker/physics ownership remained separate. Both selectors conserved all 520 native tree members exclusively in one six-proxy aggregate with explicit holes, 104 Sand cells and Water mass 1,020; no stale/unclassified results or unauthorized relocation appeared. Rotation, translation, supported Sand and falling Water were observed with genuine Rapier execution.

## Next gate — no new physical candidate admitted

Independently preregister a **physically admissible** local-relocation or chain-displacement experiment that distinguishes empty-only connectivity from crossing occupied movable material, classifies forward/lateral/rear hemispheres relative to the outward normal, refuses penetration of hard surfaces/foreign masks, conserves exact native-cell state and limits work per owner tick. Record bounded controlled counterexamples and matched Linux/Windows efficacy, worker-publication cost and actual frame pacing. This is not candidate-C implementation or authorization. Reactive Wood/heterogeneous bonds, fracture/desoliding, multiple aggregates, persistence, normal gameplay, complete native CI, independent review and release publication remain open. Issue #281 and PR #283 remain **open/draft**.
