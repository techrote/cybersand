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

## Controlled capacity-overflow regression — source 71e93488

A test-only successor at source `71e93488571a7644c155b86e11821ae9fc7aebe1`,
tree `21efe1ea6b4ce63a91c23f57c6ef02966d9695a7`, adds an
explicit **diagnostic-only saturated-source counterexample** to
`godot/tests/test_solid_detachment_ejection_policy.gd`. The compare from
the preceding docs head `929f94949f60cde84672a49cf077a5bbff37df15`
changes **only that test file** (90 additions); no native-owner
algorithm, Rapier object/worker split, aggregate transfer, liquid policy or
material handling changes. This is a separate qualification from the
four-arm moving-tree census above.

The [source-matched Linux and Windows scoped run 40651847470](https://github.com/techrote/cybersand/actions/runs/40651847470)
completed successfully in all **four** scoped jobs. Each platform passed
**1,021 checks / 0 failures**: native-to-Rapier motion 21, failure paths
20, 18-cycle session lifetime 296, cause/ABI 43, deterministic
native/fallback protocol including the new saturation cases **551**, and
moving compound A/B coupling **45 each**. The complete ordinary ready-PR
Native/GDExtension/Water matrices are still **draft-skipped**.

The controlled extra case fills a 64×64 native region with 4,096 Sand cells,
applies one fixed 8×8-class rectangular body input twice with no native
tick between preparations, and checks both selector values (0/1) and
worker settings (1/4). **On each Linux and Windows case**, each preparation
reports 81 no-target contacts. After two owner preparations the cumulative
census is exactly **162 events = 32 classified + 130 skipped** (the
fixed cap is 16 per preparation). All **32** classified events are
`no_nearby_unmasked_void`, with zero in the other two bins. All 4,096
Sand cells remain native-held and conserved, the copied body-result ABI
remains 12 fields, and the no-target count and bounded-cap partition
match exactly across worker configurations and selectors. These are
**controlled diagnostic native-owner preparations**, not 162 distinct
cells, an actual dynamic Rapier contact bank or a new efficacy result.
The earlier moving-tree census and **B=289 NO-GO decision stand unchanged**.

### Source/runtime archive identity for the overflow qualification

| GitHub Actions artifact | ID | Verified ZIP SHA-256 |
|---|---:|---|
| Exact source | 12800205877 | `191cdabe91c9f1938d5d0875ff4c9ff53567d1db11f56d25e50df7a1bfad1233` |
| Linux native/actual host | 12800376349 | `4c500ad76dc76dfb181845b5f157c6c54e181c5c4121039cf94a9f50a630a676` |
| Windows pinned DLL build | 12799822554 | `7627ea98b1d8af2fb435840ecf6c82b4ab3dc98d994c08e6165caa11c9698155` |
| Windows actual host execution | 12800266918 | `5dc009422da0b17db63b26b2a29dc788291ad51ca837c6212d9ba822e6711a98` |

The source archive's tar SHA-256 is
`ccb4dbaa8302733e58856ef4513df9a02dbc3db418440e0fc8d0a094da3f9f3b`.
The Linux runtime reports SHA-256
`9937b96f1e9fc6496cd64ab03b2c44f65540e863bf50328252917859a9848b6e`.
The Windows DLL build and actual-host report both identify
`70c3f52218e97c0aff3df5f69d245ff9aebdde6e734ba96b3e68573fb850c2a4`.
After independently inspecting all four downloaded ZIP files, their
CRCs, all **549** Windows build-manifest source paths against the archived
Git source (**zero mismatches**), and all **eight** Windows execution-log
hashes (**eight matches**), no artifact-source mismatch was found.
The Windows runner restored 92 checkout paths only after proving
pure EOL differences; no unrelated drift was admitted.

**Disposition:** the formerly unexercised census capacity/skip branch is
now source-matched qualified in a deliberately saturated controlled
regression on both actual host platforms. This is *not* evidence of
production-safe ejection, fast full worker publication, fully connected
free-space paths or release readiness. Empty-only connectivity, normal
orientation, deterministic chain displacement, representative frame
pacing, reactive Wood, fracture/restoration, persistence and independent
full review remain unqualified.

## Addendum — separately preregistered *strict* empty-only topology; later source

**Historical data above remains scoped to executed source `dabe2b30` and four original A/B async hosts. It is not reinterpreted or recomputed.**

[Preimplementation frozen registration](https://github.com/techrote/cybersand/pull/283#issuecomment-6466395909) required distinguishing a permissive line through movable material from an actual locally four-connected sequence of stored Empty cells outside **every** transient proxy mask, split forward/lateral/rear relative to the real outward normal. This is observational only. First source [`b68074d7`](https://github.com/techrote/cybersand/commit/b68074d715e04f3a2e37613239d5322fd1f3d1ee) added a fixed 289-slot BFS, preserving the existing 16 events per owner preparation, old weak three-way bins, 12-field result stride and ejection motion. It exposes exclusive forward > lateral > rear > none counters, plus the subset where a weak direct route exists but no strict empty route does.

**Retained initial negative:** [actual Linux scoped run 40671639353](https://github.com/techrote/cybersand/actions/runs/40671639353), executable source `b68074d7`, successfully built its native kernel and GDExtension but failed the controlled ejection-policy test. The script's `material_at()` check queried masked *visible* occupancy under a transient body rather than the authoritative stored Sand; the rear fixture's exposed upper band also admitted a lateral reachable sector. The first log recorded failures and the native owner counters; they must not be presented as passing conformance. Invariant-preserving controlled test repairs: [`a37df69f`](https://github.com/techrote/cybersand/commit/a37df69ff51e761f5529b8635c95e00e82b5c944) carves the rear void, [`e09c497b`](https://github.com/techrote/cybersand/commit/e09c497bc998545458a508db5852696eede4df59) caps it against lateral escape, and [`ecacca3e`](https://github.com/techrote/cybersand/commit/ecacca3e701489d58a13793c038968d36f16bb03) asserts the copied stored snapshot. The later three commits only modify controlled GDScript fixtures, not C++ physical code, generic liquid construction, or native aggregate ownership.

**Qualification status at this checkpoint:** the [`ecacca3e` Linux/Windows source-matched actual Rapier run 40672040365](https://github.com/techrote/cybersand/actions/runs/40672040365) is pending; *no* new platform pass, efficacy improvement, conservation acceptance or frame-cost conclusion is asserted. Await the exact runtime, complete logs, controlled sector partitions, full 520-member/six-proxy/Sand/Water live host readbacks, artifact hashes and independent code review. The baseline B=289 physical search experiment remains a published **NO-GO**, and no candidate is licensed for real cell relocation. The next gate is source-matched qualification and representative worker-loop/publishing cost, not broadening to Wood or automatic desoliding.

## Executed strict-route source qualification (subsequent to the pending checkpoint above)

**Frozen inputs:** commit `ecacca3e701489d58a13793c038968d36f16bb03`, tree `94842a127df278655eb049383c52b7e61036a5b1`. Source archive [artifact 12809730349](https://github.com/techrote/cybersand/actions/runs/40672040365/artifacts/12809730349) has ZIP SHA-256 `ca629964833279317268b37358b30e86ddf7128b6597279eafb2174f1007f8a0`, TAR.GZ SHA-256 `329ba8f0b019e8b5436cf7a3317bdbc0cc87a217144dcf0728529cdbba889167`. Independent manifest-to-archive rehash confirmed **549/549 exact inputs**, no missing or hash drift, and archive tree equals the Git commit tree. Windows source verifier reported all 549 and **92 accepted exact-Git-byte restores** for line-ending normalization, not arbitrary drift. Independently CRC-checked Linux and Windows execution/build ZIPs and their metadata SHA-256, rehashed the Windows DLL against build manifest and execution receipt, and verified all **8 Windows execution-log hashes** and zero exit codes.

The exact [scoped workflow 40672040365](https://github.com/techrote/cybersand/actions/runs/40672040365) **passed** Linux native/GDExtension + real Rapier, Windows native build + real Rapier, and source-identity jobs. Both OS reports contain **1,394 passing checks each**: motion 21; failure paths 20; real lifecycle 296 with 18 replacements; unresolved cause partition 43; ejection and strict-route controls **924**, including 22 controlled strict-route cases across 1/4 workers, 40 earlier policy cases, cap replay; live compound **45 each** for A/B. Both retain the 520-member six-proxy real Rapier aggregate with holes, native stored Sand=104, Water mass=1,020, zero immovable/relocation/unclassified reasons, sample/epoch handling and async native-worker/Rapier-main ownership. Linux and Windows controlled strict-route material/sector signatures match exactly. The first failed `b68074d7` run above remains a negative, *not* erased by this repair.

**Observed native-owner cumulative no-target censuses (not the latest-only accepted main-thread result aggregates):**

| Platform / source policy | Failed attempts | Old permissive direct | Strict empty-only absent | Forward | Lateral | Rear | Capacity skips |
|---|---:|---:|---:|---:|---:|---:|---:|
| Linux A / 81 | 2,247 | 2,247 | 2,247 | 0 | 0 | 0 | 0 |
| Linux B / 289 diagnostic | 773 | 773 | 772 | 0 | 1 | 0 | 0 |
| Windows A / 81 | 3,486 | 3,485 | 3,296 | 1 | 0 | 189 | 0 |
| Windows B / 289 diagnostic | 1,578 | 1,578 | 1,577 | 0 | 0 | 1 | 0 |

**Descriptive sum, not paired causality:** 8,084 failures, 7,892 with no strict local four-connected Empty/unmasked route and 7,891 permissive-direct false positives. One Windows A weak scan classified a void as path-blocked; all other old weak events had permissive paths. Windows A's 190 strictly connected sectors and Linux B's one lateral sector do **not** imply admissible ejection: a path can wind, violate trajectory/body constraints, and require moving intervening material. A strict-absence result only rejects *this restricted empty-only* pathway inside radius 8; it does not rule out conservation-preserving bounded push-chain physics. A/B clocks and cross-platform trajectories are not matched; no efficacy improvement is claimed.

| Host | Worker step p95 | Native tick p95 | Render/terrain copy-segment p95 | Worker overruns | Main-thread coupling p95 |
|---|---:|---:|---:|---:|---:|
| Linux A | 0.458 ms | 0.183 ms | 40.161 ms | 66 | 206 μs |
| Linux B | 0.639 ms | 0.188 ms | 40.255 ms | 73 | 205 μs |
| Windows A | 0.389 ms | 0.151 ms | 13.913 ms | 0 | 261 μs |
| Windows B | 0.429 ms | 0.128 ms | 13.933 ms | 0 | 257 μs |

The `snapshot_copy_time_ms` sampling in `godot/scripts/simulation_worker.gd::_publish_snapshot` ends *before* construction and publication of the full snapshot object; it covers the initial render/terrain-preparation segment, not all worker-loop or main-thread costs. Headless physics-frame p95 was ~20.7 ms on both platforms. Samples are *not* a 60 FPS or representative interactive acceptance. The older B=289 policy remains **NO-GO**, and neither strict connectivity nor the cross-host green supports any new physical relocation, persistent aggregate, reactive Wood, fracture/desoliding, production policy or merge. Next: preregister and measure a truly **physically admissible bounded material-conserving displacement candidate**, and instrument **total worker-loop and publication cost** without conflating the pre-assembly copy segment with end-to-end latency. Independent review and full release matrices remain open.

Machine-readable hashes, runtimes, exact source and all counter partitions: [`strict-empty-route-receipt.json`](sol281-2026-10-28/strict-empty-route-receipt.json). The latest docs-only successor does not alter the executed program.

## Addendum — preregistered snapshot publication-stage attribution (source 9c97dc09, 2026-10-28)

This is a **new, subsequent source-specific timing qualification**, not a reinterpretation of any preceding topology, B=289 negative efficacy or `b68074d7` failed-host results. The [frozen before-edit registration](https://github.com/techrote/cybersand/pull/283#issuecomment-6466960679) and [actual scoped Linux/Windows run 40675020082](https://github.com/techrote/cybersand/actions/runs/40675020082) bind executed commit `9c97dc09eb15631e286ae4519075e389feb3e354`, tree `b94248b486623ce3f670f320671b940ab16bf6f6`. All four scoped jobs (source, Linux Rapier, pinned Windows DLL build, Windows Rapier) **passed**. Both real Godot/Rapier platforms passed **1,400 checks with zero failures**: 21 real tree motion, 20 failed/rollback transitions, 296 lifecycle checks/18 replacements, 43 unresolved-cause/ABI checks, 924 controlled search/strict-route assertions, 48 moving six-proxy compound A, 48 B. The focused Linux native C++ test adds **13,074 source-matched checks**. The 520 exact native members remain held by one six-shape Rapier aggregate, with open crown/AABB holes `[2,0,0,6]`, conserved Sand104 and Water mass1020, original 12-field body-result ABI, zero stale results, material/solver policy and native-worker/main-thread Rapier ownership unchanged. This result is **timing observability, not a physical ejection or production fix**.

The code retains historical `snapshot_copy_time_ms` unmodified (the worker's render/terrain preparation interval), and adds `snapshot_assembly_time_ms` (immediately after that interval, through metadata/copy assembly) plus `snapshot_publish_total_time_ms` (entry into `_publish_snapshot` through the pre-mutex endpoint). Both are immutable scalar values assigned **before** publication and sampled through the existing latest-only 512-cap SOL281 worker snapshot path. The new tests reject negative/non-finite readings, missing stage samples or per-sample `publish < copy/assembly`, and verify p95 monotonicity.

| Host | A/B probe policy | Samples | Worker step p95 (ms) | Old render/terrain p95 (ms) | Assembly p95 (ms) | Pre-mutex publication p95 (ms) | Worker overruns |
|---|---|---:|---:|---:|---:|---:|---:|
| Linux | A / 81 | 121 | 0.876 | 52.021 | 0.291 | 52.378 | 108 |
| Linux | B / 289 (diagnostic) | 139 | 1.216 | 52.161 | 0.280 | 52.407 | 97 |
| Windows | A / 81 | 307 | 0.478 | 22.600 | 0.270 | 22.845 | 29 |
| Windows | B / 289 (diagnostic) | 298 | 0.556 | 22.920 | 0.267 | 23.161 | 33 |

**Finding:** pre-mutex total sampled publication preparation is dominated by render/terrain preparation (**Linux p95 52.378/52.407 ms** and **Windows 22.845/23.161 ms**), not the newly isolated snapshot-assembly stage (**0.291/0.280 and 0.270/0.267 ms**). This attributes the previously misleading “snapshot-copy” number to its broader preparation region, but it **does not identify one underlying memcpy/kernel or demonstrate an optimization**. The native tick/worker-step p95 stops before this region; the totals above omit final mutex handoff, `CyberSolidDetachmentWorker` reply, wait/sleep/backlog handling, main-thread Rapier/render and true interactive frame delivery. Linux 108/97 and Windows 29/33 observed worker overruns are concerning and not per-unique-cell counts. A/B and cross-OS sampled headless trajectories are not matched causal performance trials; frame p95 remains a ~20.7ms **headless manual physics** observation, not 60 FPS acceptance.

**Independent source/runtime readback:** all four artifact ZIP SHA-256s and ZIP CRCs were verified, archived source TAR.GZ SHA-256 `40c0043e735b4b1c2f0f44fd11e4911c14662d120ff052651c281cfce273943c` and Git tree match the recorded commit; **549/549** Windows build-manifest inputs independently match the exact Git archive (zero missing/mismatched). The Windows runtime DLL SHA-256 `9b78958b3f2ce4af23d40507ef24930e8399916be711f37e79ba95b5ce1557fe` matches both build artifact and actual host report; Windows restored exactly 92 EOL-only checkout files to canonical Git bytes. All eight Windows execution logs have individually matching SHA-256 and zero exits. Linux runtime SHA-256 `244b0270f31c37135256524a5ca1d27afac32d1afbbf02c88b215e4e2fdb85bb`. Full four-ZIP SHA-256s, report hashes, per-arm counters and scope limitations are retained in the [additive machine receipt](sol281-2026-10-28/snapshot-publication-stages-receipt.json).

**Still open:** actual full worker-loop/publish interval, render/terrain breakdown and representative interactive frame pacing; physically admissible bounded relocation/chain motion; B=289 **NO-GO** (earlier only +0.4302/+0.6119pp versus +20pp threshold); Wood/bark/heterogeneous chemistry, fracture/desoliding, multiple aggregates, persistence, normal gameplay, independently reviewed ready-PR matrices and formal runtime publication. #281 stays open; PR #283 stays draft/unmerged. Historical negative results above are not rewritten.
