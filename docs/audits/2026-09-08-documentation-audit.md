---
title: Documentation audit before foundational simulation and physics work
status: Current
scope: Local source identity, documentation corrections, Windows checks, historical evidence boundaries, and unresolved foundational decisions as of 2026-09-08
keywords: [documentation audit, RAG, source identity, backup, threading, Rapier, CYSD1, replay, foundational work]
related-documents: [../README.md, ../reference/status-and-roadmap.md, ../operations/testing-validation-and-replay.md]
last-reviewed: 2026-09-08
implementation-state: Documentation audited against the local reconstructed source; no implementation, dependency, CI configuration, or historical result changes.
---

# Documentation audit — 2026-09-08

The focused RAG hierarchy is ready to guide foundational design and narrowly
scoped implementation. It does **not** certify a committed, fully backed-up,
cross-platform, exact-replay baseline. Establish an actual source checkpoint
and backup before relying on rollback, and address the explicit decisions below
when their subsystem work begins.

## Actual identity and backup coverage

Read-only Git checks ran in the active workspace, its source directory, and the
retained Documents workspace before documentation edits:

| Location or record | Observed scope |
|---|---|
| `C:/kybersand` and `C:/kybersand/source` | No `.git`; `git status` and HEAD queries fail. These are not Git checkouts. |
| `C:/Users/-/Documents/ChatGPT/cybersand` | Unborn `master`, zero commits; no configured remotes or tags, empty tracked LFS list; workspace files are untracked. |
| `C:/kybersand/SOURCE-PROVENANCE.json` | 244 acquired blobs attributed to `web-demo-m11`, base `e2892c54d4bd91aac60971e81c748bd49fbe2adb`; acquisition explicitly had no Git history or LFS payloads. This is provenance, not current HEAD. |
| Local changes at audit intake | 25 acquired files differ and 26 files are added, excluding generated imports/builds. No acquired path is missing. All 18 original `native/` files still match acquisition bytes; adapter, scripts, tooling, dependency metadata and runtime artifacts have later changes. |
| Retained backup source under `cybersand-m13-dev/source` | Of 267 inventoried files, 230 match, 20 differ, 17 are absent from the backup. The exact differing/absent paths are in the evidence record. Includes newer Web probes, benchmark fixtures, adapter changes and Rapier WASM payloads. |
| Current LFS payloads | 14 pointers remain, including Linux CyberSand and Rapier libraries. Windows x86_64 and the two Web Rapier payloads are materialized. |

No local implementation or documentation change is committed in either observed
repository. The older backup is partial, on the same host; remote/off-device
backup, remote ancestry, current CI and M13 ZIP integrity are unverified. No
repository was initialized, commit created, remote fetched, or backup overwritten
in this audit. `C:/cybersand` is the deliverable location, not source backup proof.

The [curated evidence record](2026-09-08-documentation-audit-evidence.json)
contains backup deltas, test commands, runtime hashes, export manifests and
local raw-log references. The intake fingerprint over 205 pre-existing
non-Markdown files (excluding generated trees) is
`0f07e1029418c0bca47a66f6c75b088a42f2871448794f9be2ca3971e1957b52`;
the record specifies the hashing algorithm. It is not a Git identity.

## Major documentation corrections

| Area | Corrected account and primary source/contract |
|---|---|
| Hierarchy and status | Repaired onboarding paths, retrieval answers and indexes. Pages distinguish inspected Current source from Approved direction, Planned implementation, Deferred experiments and Rejected shortcuts. Historical is an evidence scope. The canonical [update checklist](../../AGENTS.md#documentation-obligations) now covers reverse searches, independent retrieval, platform/artifact identity and deferred updates. |
| Simulation ownership | Native `World` owns cells; desktop `CyberSimulationWorker` owns a Godot Thread and invokes the native pool. Web synchronously ticks cells in `_physics_process`; pthread support is internal parallelism, not asynchronous Web ownership. Native pool workers call no Godot APIs; the desktop GDScript owner does invoke its exclusive adapter/value APIs. See [threading](../architecture/simulation-tick-and-threading.md), [simulation_worker.gd](../../godot/scripts/simulation_worker.gd), [web_demo_controller.gd](../../godot/scripts/web_demo_controller.gd). |
| Scheduling and rendering | Four-phase in-place native jobs are Current; buffered enum/transfer contracts remain unimplemented alternatives. Godot receives immutable copied dirty RG8 patches rather than a compulsory full-cell copy each tick. The GPU still receives a full backing-texture update. See [snapshot ownership](../architecture/data-ownership-and-lifetimes.md), [render_snapshot.cpp](../../native/src/render_snapshot.cpp), [native adapter](../../godot/native_extension/cyber_native_cell_world.cpp). |
| Rigid-body coupling | Rapier owns rigid bodies and hard-terrain contact; packed rectangle samples build a separate cellular mask and return bounded results. The Rapier path suppresses duplicate cellular Wall correction/support. Main-thread manual stepping is implemented. Shape generalization, common lockstep, torque and high-count guarantees remain open. See [coupling contract](../architecture/rigid-body-and-cellular-coupling.md), [rapier_physics_bridge.gd](../../godot/scripts/rapier_physics_bridge.gd), [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md). |
| Native/Web coverage | Windows has actual runtime evidence. Both local Web profiles include pinned Rapier 0.35.2 and Physics Pit; compatibility stays at one worker, threaded Auto selects 2/4/6 at logical-thread thresholds 4 and 12. Desktop can fall back to discrete GDScript; Web requires native cells. Historical Linux results do not materialize local LFS pointers. See [Web profiles](../operations/web-threading.md). |
| Saves and replay | CYSD1 reconstructs a fixed 1024² level plus selected metadata and up to three body records. Exact byte restoration is distinct from complete future-trajectory replay. Export requires exclusive ownership and clears the transient mask; it must be rebuilt before the next tick. See [contracts](../reference/interfaces-and-message-contracts.md), [demo_snapshot.hpp](../../native/include/cybersand/demo_snapshot.hpp), [demo_save_codec.gd](../../godot/scripts/demo_save_codec.gd). |
| Water, fields and budgets | Native Water uses conserved 8-bit pairwise mass; long lookahead/discrete vacancy rules belong to the fallback. Settled content uses `content_hash`, since `state_hash` includes time. Native secondary rules already use staggered cadence; temperature storage is present with a Rocket read but no field solver. The collider consumption cap is 32 chunks/750 µs, not a bound on the preceding full packet extraction. See [Water](../systems/water-design.md), [configuration](../reference/configuration-reference.md). |

The handover retains owner intent but no longer presents completed Smoke,
construction-palette and liquid-animation work as wholly future work. Current
focused documents own detailed contracts; legacy milestone pages and BUILD_ID
keep their historical measurements with visible scope notices.

## Fresh checks and evidence limits

Commands ran on Windows x86_64 using Godot
`4.7.stable.official.5b4e0cb0f` from `C:/Godot47`, Python 3.12.14,
SCons 4.10.1, LLVM-MinGW Clang 23.1.0 and Emscripten 4.0.20.
The local native drift override can relax dirty-binding/compiler checks; it is
not release attestation. Native and Web `godot-cpp` checkouts were independently
verified clean at
`101ae38034304346a46ea9ea84ae156d3e860496`.

| Check on 2026-09-08 | Result and boundary |
|---|---|
| `dev.cmd doctor` | 6/6 version checks; `validation/local/20260908-201008`. |
| `dev.cmd native-test` | 39/39; C11 header check and freshly compiled Debug C++ tests, 21.621 s; `validation/local/20260908-201010/native-test.json`. One existing unused-lambda-capture warning at `native/src/world.cpp:1419`; no sanitizer run. |
| `dev.cmd godot-test` | Import plus 15/15 fixtures; 48.473 s fixture total, 240 s import and 180 s per-fixture timeouts; `validation/local/20260908-201106/godot-fixtures.json`. Includes Auto policy, native render/lifetime, fallback, save rejection/restoration, worker parity and Rapier tests. |
| Physics Pit fixture within that suite | 600 ticks, 6 cellular workers, 308,087 contacts, 151 displaced cells, no fixture failures; maximum body centre y=160.317276, final floor centre y=159.000656. About 1.32 px transient floor penetration is permitted by this test; a pass is not zero-penetration proof. |
| Existing export integrity | Compatibility 18/18 and threaded 18/18 SHA256SUMS entries match. Source Rapier WASM hashes match the pinned variants. This is checksum verification, not a fresh build, HTTP test or browser execution. |
| Documentation checks | 70 Markdown files, 792 local links and 163 related-document targets checked; no missing links/anchors or metadata errors. All source/docs pages are reachable from the documentation index. |
| Source/history comparison | All pre-existing non-Markdown files remain unchanged; only documentation and a curated evidence record were added/edited. Six M11 report/JSON records remain byte-identical; setup-report text is unchanged beneath its banner. |
| M11 consistency checker | Fails with the same seven pre-existing BUILD_ID hash mismatches; no documentation link/status errors. Historical hash values were preserved. |

Godot fixtures used the retained Windows CyberSand DLL SHA-256
`402732d3b1625eace69e2130356137f0ebef14d9113d3d8d22716d9e4ea2bb17` and
Rapier DLL `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`.
The extension was not rebuilt, so these runs establish behavior of those
artifacts with current scripts, not complete source-to-binary reproducibility.
Tests generated local build/import caches; implementation files were not edited.

Raw records and check helpers are in
`C:/kybersand/validation/local/documentation-audit-20260908/`.
This audit did not rerun browsers, interactive visual approval, Linux/WSL,
macOS, Firefox/Safari, sanitizers, cold builds or clean-clone/restore tests.

## Preserved historical records

- [M11 evidence catalogue](m11/README.md): `05ea45f...`, August 2026;
  34 passed and one inconclusive LeakSanitizer result. Reports and JSON results
  remain unchanged. [BUILD_ID](../BUILD_ID.md) retains all 28 original hash rows.
- `C:/kybersand/LOCAL-DEV-SETUP-REPORT.md`: 2026-09-07 reconstruction and
  compatibility-only browser setup; a banner links later work without changing
  its original 11-fixture/16-pointer/disabled-Rapier-Web results.
- `validation/local/web-threading-20260908/browser-parity.json` and
  `validation/local/auto-workers-20260908/browser-reference.json`: earlier
  four-worker and later Auto evidence; do not substitute one profile for another.
- `validation/local/rapier-web-20260908/browser-results.json`: retained native
  and Chromium one/six-worker 600-tick results, scoped by the
  [Rapier runbook](../operations/rapier-2d-migration-runbook.md). It lacks a
  complete immutable source/export manifest, so it is checkpoint evidence,
  not exact-current-artifact browser certification.

## Unresolved contradictions and foundational decisions

1. **Checkpoint safety:** the active tree lacks Git history and the retained
   backup omits current changes. Establish and verify a source checkpoint and
   recoverable backup before destructive or substantial foundational edits.
2. **Web CI is inconsistent with its builder:**
   [web-demo.yml](../../.github/workflows/web-demo.yml) and
   [web-toolchain.yml](../../.github/workflows/web-toolchain.yml) select
   Emscripten 4.0.11; [build_web.py](../../tools/build_web.py) requires 4.0.20.
   The demo workflow also combines `--compile-only --native-tests` without the
   required separate `--native-cpp`; compile-only returns before runtime tests.
   Reconcile configuration and execute the intended gates in an implementation
   checkpoint; no CI result was invented here.
3. **Template/release metadata remains historical:**
   [godot-runtime.lock.json](../../third_party/godot-runtime.lock.json) still
   says export templates are absent/unpinned, whereas local official 4.7
   templates and exports exist. Local archive hashes are in the setup report.
   Release metadata/provenance needs reconciliation before claiming reproducible
   exports; do not rewrite historical native library hashes.
4. **Exact replay is incomplete:** `World::state_hash` includes tick/epoch but
   omits simulation region, adhesion setting, transient body inputs and compiled
   rule/source identity (the backend enum itself is hashed). CYSD1 omits scheduler queues/epoch and Rapier caches.
   Define complete inputs, ordering, versioning and strict-policy semantics
   before treating hash equality or save restoration as whole-engine replay.
5. **Desktop/Web coupling differs:** desktop character stepping precedes cells;
   Web follows cells. Desktop exchanges body samples asynchronously; Web pauses
   the coupled chain until queued terrain colliders drain. Desktop ignores the
   cellular tick's Boolean failure result; Web pauses and reports it. Choose an
   intended common contract and failure policy before foundational refactoring.
6. **Budget and contact limits:** collider rebuilding is bounded after packet
   extraction; extraction itself can scan/copy substantial terrain work. The
   rectangle proof allows small transient penetration and does not establish
   arbitrary-shape, high-body-count, exact torque or no-tunnelling guarantees.
   Set numerical/reference-fixture requirements before extending the proof.
7. **Design/schema uncertainty:** ADR-004
   [percentage margins](../decisions/ADR-004-interest-region-and-reconfiguration.md)
   specify an Approved 10%/20% direction, while controllers use explicit pixel
   presets; percentage interpretation is not implemented. CYSD1 validates
   lengths/material IDs and metadata, but a complete per-material state-byte
   validity schema is not defined. Preserve these distinctions until specified.
8. **Evidence gaps:** no current Linux binaries, current sanitizer/cold-build
   evidence, complete browser artifact binding, or cross-browser validation.
   Record unavailable evidence explicitly; do not infer a failure or success.

These issues are documented, not silently resolved by prose. No implementation,
lock, workflow or dependency file was changed; no push, publish or delivery ran.
