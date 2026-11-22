---
title: ObjectShard M4 ordinary Workbench interface checkpoint
status: Current
document-kind: audit
scope: Draft/HOLD ordinary Workbench same-World seam, publication, latency, regressions and explicit blocked gates
last-reviewed: 2026-11-22
related-documents: [2026-11-22-objectshard-m3-final-qualification.md, ../research/objectshard-m3-preflight.md, ../operations/objectshard-m3-preflight-playtest.md]
---

# OBJECTSHARD-M4-WORKBENCH-001 — Workbench interface checkpoint

**Status: Draft/HOLD. Native same-World integration is BLOCKED.** This
contribution runs no second World, changes no native source or GDExtension,
and does not promote Workbench, Rapier, Water or renderer defaults.

## Source custody

| Source | Frozen/observed identity |
| --- | --- |
| Accepted main, observed 2026-11-22 | 00cdb02f103265b6dc5224c68283e9a0c8cb449f |
| M3 evidence HEAD / this branch base | febfad1b0b1ee93dac8d5b5a76f145b9ab80ad0a |
| Previously qualified M3 runtime | e034f2294663e0485cfb9adcc8ada46a6e977cee |
| PUBPRES #740, read-only | adedb2761bad6cce91002ffe50c50c39b5f63645 |
| Earlier PUBPRES #719 / #682, read-only | d316c281e0abb575eb6302afc12ec44f211460ba / 4302ba2058c1bdac1c3fc54540c078dfc9147573 |
| Workbench M4 branch | experiment/objectshard-m4-workbench-seam-20261122 |
| Native/GDExtension changes | NONE |

The M3 Windows owner guide, M3 final qualification, native source-ownership
ledger and PUBPRES implementation/evaluation records were inspected.
At the current ref refresh, immutable GCR source
godot/native_extension/workbench_granular_coupling.inc has **the identical Git
blob c0c8a8f2f927471cc57bd238ba37f7d9137cda9f** on accepted main,
M3 #741 and PUBPRES #740. The existing workbench_physics_bridge.gd is
also blob-identical (d82d511f112ebd37f18061bb9c9e21a88f662857).
Main's simulation_worker.gd (522e55d4d2e4a42d6b2a6f628a791fa768821e03),
main.gd (56b8e685f4f4c9eb4219c6ba02c2eca69e9c7bf1)
and simulation_snapshot.gd (5677152729f9676021e2d34945881e1a93dd7d48)
match frozen M3 #741. All three **differ** on unmerged PUBPRES #740:
worker 039eeb8723d20330ac6ca5300ec9416cc49bd649,
Main b439e43dfcf94efa139f9aee1b62dc34abbc05a6,
snapshot c6a4dbe3dae24c60598930d8710ebea1af80b708.
Rebasing or cherry-picking donor publication/worker files into M4 is
therefore not source-neutral and requires an integration lead's reconciliation.

M3 qualified an **independent native World**, a separate worker and a real
main-thread Rapier owner. It did **not** attach ObjectShard to ordinary
Workbench. Its optional receipt pump averaged approximately 17.14 semantic
ticks/s and a recorded adversarial Windows input-to-postdraw p95 was about
1,754 ms. Neither is ordinary Workbench M4 FPS or new timing evidence.

## Existing ordinary Workbench control and presentation flow

| Stage | Actual implementation | M4 requirement |
| --- | --- | --- |
| Pointer capture | shared_workbench.gd:setup/_world_input/paint, main.gd:handle_painting and queue_brush_footprint_mutation | Ordinary brush and paused transactional editor retain different admission contracts. Preserve paint and authored history. |
| Worker admission | simulation_worker.gd:queue_emit_disc/queue_emit_cells, bounded commands and mutex | Main never directly invokes mutable native World or body solver. Refusal remains visible. |
| Single native owner | simulation_worker.gd:_create_world/_worker_loop/_apply_emissions/simulation_tick | This is the single authoritative CyberNativeCellWorld. No CyberObjectShardLab replacement. |
| Prepared GCR | simulation_worker.gd:prepare_workbench_coupling, workbench_physics_bridge.gd:pack_sample/apply_packet | Existing immutable mass, geometry, roster and epoch refuse mutable shards. Separate revisioned native adapter required. |
| Rapier and terrain | main.gd:_physics_process/_workbench_terrain_installed/sync_hard_surface_colliders; workbench_physics_bridge.gd | Main owns RIDs and steps. Check installed terrain and native receipt before promotion/geometry/mass mutation. |
| Copy/publication | simulation_worker.gd:_publish_snapshot and simulation_snapshot.gd | Keep source generation, body epoch, native tick, render revision, hard-surface revision and sample identity separate. |
| Render authority | main.gd:consume_worker_snapshot/consume_render_snapshot/workbench_display_frame/upload_texture_patches | A visible moving-cell witness binds the **uploaded** material revision and corresponding applied pose. An upload ACK proves submission, not scanout. |
| Reset/exit | shared_workbench.gd:apply/_exit_tree/F2; main.gd:reset_world/_exit_tree, worker stop and Rapier shutdown | Retire pending shard port generation; do not admit stale deferred callbacks or spawn a replacement World during disposal. |
| Water | main.gd:workbench_apply and unified ordinary Water configuration | Preserve current selected native law/solver, especially Wave vs Pressure. New shard compatibility must be explicit. |

The existing executable native test
godot/tests/test_object_shard_workbench_contract.gd admits the immutable
production roster and refuses changes to mass, inertia, geometry, body
identity, session, epoch and omitted bodies without material mutation.
The M3 facade exposes no attach_world/set_world method.
Simply reenacting M3 worker publications inside Workbench would create
competing source owners and **does not satisfy M4**.

## Changes in this branch

- godot/scripts/object_shard_m4_workbench_port.gd: opt-in and fail-closed
  main-to-ordinary-worker protocol, 16 pending action cap, exact uploaded
  material/pose observation fence, exact moving-cell identity, source-owned
  receipt verification, terminal retirement and an ambiguous-admission hold.
  Missing same-World capability visibly refuses.
- godot/scripts/object_shard_m4_latency_probe.gd: bounded opt-in 512-event
  and 256-per-stage rings, worker reports labelled as potentially nested,
  actual Rapier step, texture submission, callback and post-draw timing.
  No synthetic native execution time, additive total, exact drawn-serial
  inference, GPU scanout claim or auto-written disk log.
- godot/scripts/main.gd: flag --objectshard-m4-workbench enables only
  observational sampling and lifecycle-safe post-draw registration. Existing
  Water and Rapier algorithms remain unchanged.
- godot/scripts/shared_workbench.gd: flag-gated M4 Erase/Ignite tools,
  explicit refused status, normal-brush queue measurement and owner
  retirement. The tools **intentionally do not mutate anything** while the
  native seam and actual visible target overlay are unavailable.
- godot/tests/test_object_shard_m4_workbench_port.gd: uses an actual
  ordinary CyberSimulationWorker and checks its World instance is unchanged;
  validates negative capability, stale publication and moving-target
  structures. Reports ZERO real same-World physics assertions.
- godot/tests/test_object_shard_m4_latency_probe.gd: value-only negative
  timing, stage overlap, bounded-resource, re-entry and deferred post-draw tests.
- godot/tests/test_object_shard_m4_workbench_scene_refusal.gd: actual mounted
  ordinary Workbench + native World; opt-in pointer controls refuse both while
  paused and during real semantic progression. No positive moving-body
  claim, no second World or mock physics. The source-matched runner exercises
  this real scene with the flag enabled.
- tools/objectshard/qualify_m4_workbench.py: source-exact Godot 4.7 test
  subprocess runner, case-by-case raw logs and JSON completion validation,
  including original native Workbench refusal, optional ordinary Water/physics
  regressions and M3 standalone controls.

### Native-specialist contract and Godot worker ownership

**Ownership split:** The native specialist must provide actual C++/registered
same-World primitives on the **already existing CyberNativeCellWorld**
for detached inventory, exact target edits, revisioned mutation/motion
receipts, lifecycle disposal and compatibility with active Water. They
must prove equality with the ordinary worker's _world instance rather
than construct CyberObjectShardLab beside it. This specialist does NOT
own godot/scripts/simulation_worker.gd.

The three interface methods below belong on the existing
CyberSimulationWorker as **Godot-side wrapper methods**, owned by this
Workbench scope or its integration lead **after** the native API has been
agreed and delivered. The current port detects their absence and refuses;
we do not create speculative script stubs or call nonexistent native
methods. Each wrapper must use copied, mutex-safe values; only the
worker's exclusive thread may invoke native World methods:


1. object_shard_same_world_capabilities() -> Dictionary. Must identify
   host=ordinary-workbench, owner=simulation-worker, mode=same-world,
   attached=true, worker_exclusive=true; positive worker_instance_id (equal
   to the current CyberSimulationWorker.get_instance_id()),
   native_instance_id (identity of **its actual _world**), world_generation
   (matching snapshot.render_world_generation), session, owner_epoch,
   shard_session, world_incarnation, transport_generation and operations
   erase, ignite, inspect. These additional native identity dimensions
   correspond to the five-field OwnerIdentity used by #751's native M4 gate;
   World generation alone does not prove that the Coordinator incarnation
   survived a candidate-and-swap or exceptional reset.
   The native specialist must prove source equivalence inside the worker;
   a self-reported field alone is not sufficient evidence.
2. object_shard_queue_workbench_action(request: Dictionary) -> Dictionary.
   Queue copied input only, bounded, using action_id, port_generation, native
   and worker owner identity, World/session/owner epoch/shard session/incarnation,
   uploaded observation
   and exact native moving-cell target. Return fenced affirmative admission
   or fenced refusal; malformed/uncertain delivery must HOLD rather than retry.
3. object_shard_take_workbench_results(maximum: int) -> Array[Dictionary].
   One terminal action receipt, with explicit Applied, TargetChanged,
   Capacity, Refused, Cancelled or Failed; matching session,
   transport_generation, owner_epoch, shard_session, world_incarnation,
   World/native instance, action_id and port_generation.
   A claimed Applied also needs an accepted same-World native_receipt
   matching operation/position, an exact copied pre-mutation source_target
   witness, positive transaction_id and revisioned resulting native material,
   geometry, body generation, cell incarnation, owner/cell, pose and applied
   physics revisions. Resulting incarnations may legitimately differ from the
   source witness. The native owner must revalidate expected material,
   state_a, state_b, temperature and incarnation at execution time.

The lead must separately reconcile actual promotion and material/physics:
authoritative source debit, committed terrain packet, verified main-thread
Rapier geometry/mass/shape readback, activation, native applied-motion receipt,
revisioned occupancy and coherent material/pose publication. This current
port cannot pretend to perform those operations. In particular, a positive
queue receipt **cannot** authorize physics installation.

## PUBPRES read-only conflicts and performance model

PUBPRES #740 retains workbench_native_rendezvous.gd,
workbench_same_frame_continuation.gd and
workbench_presentation_coherence.gd as unmerged donor files. Do NOT
cherry-pick or modify them here. Historical Wave2048 ON trials had zero
successful same-frame continuations; the narrower Wave512 result is not
large-canvas proof. Source evidence distinguishes native execution,
post-native mailbox waiting and Rapier. Main's material upload and
uploaded-frame pose are still the publication authority.

| Stage | Measurement | Non-additive caveat |
| --- | --- | --- |
| Input capture/queue | Input timestamp; measured ordinary brush worker submission | No native action ID yet |
| Worker execution | Future source-owned native receipt with monotonic start/end | Never synthesize from worker_step_time_ms |
| Snapshot and render preparation | Existing worker_step, snapshot copy, render exchange and snapshot publication source fields | Nested durations may overlap |
| Receipt delivery | Snapshot published_usec to Main observation | Includes scheduling/queue age |
| Physics | Actual main-thread rapier_bridge.step wall time | May include off-CPU wait |
| Texture upload | Actual upload_texture_patches submission interval and acceptance | No GPU completion timestamp |
| Main scene callback | Full Main._process duration | Encloses upload, not additional pipeline time |
| Post-draw | Accepted upload to deferred Godot frame_post_draw callback | Signal carries no render serial; callback need not display that exact upload; not monitor scanout |
| Input to presented | Requires the SAME action ID and material+pose publication all the way to displayed callback | **UNMEASURED** until native integration |

The opt-in report explicitly sets no_additive_stage_total=true and
input_to_post_draw_causally_proven=false and
frame_serial_coherence_proven=false. Bounded trace export must be
explicit and uses user:// only. The separate historical full-image GPU
publication stalls remain a significant independent risk.

## Qualification and acceptance matrix

From a full checkout with *matching built native extension, Rapier binaries*
and Godot 4.7, run the source-bound qualification command (replace the engine
path as necessary):

~~~sh
python tools/objectshard/qualify_m4_workbench.py \
  --godot /path/to/Godot_v4.7-stable_linux.x86_64 \
  --expected-source-sha "$(git rev-parse HEAD)" \
  --output build/objectshard-m4 \
  --regressions --m3-controls
~~~

The runner refuses wrong source SHA, non-4.7 Godot, process errors,
timeouts, missing/duplicate/failed M4 completion receipts, and retains
raw logs. Windows must use matching verified Windows Godot/native/Rapier.

| Test goal | Source status / requested real outcome |
| --- | --- |
| One ordinary native World and exact negative capability | New executable refusal test. Actual Godot execution pending |
| Paint/history and active Water defaults unchanged | Existing ordinary paint, Wave and live Water tests. Execution pending |
| Native immutable GCR refusal | Pre-existing real native contract test. New source execution pending |
| M3 standalone exact moving witnesses and 3 bodies | Prior M3 qualified; optional control. **Not** same-World evidence |
| Ordinary cut -> detach -> fall -> settle -> continue edit | BLOCKED until native same-World interface + main-thread body admission |
| Stale same-body target vs fresh witness on ordinary World | BLOCKED; structural contract only |
| Delayed physical receipt / sustained paint fairness | BLOCKED on ordinary World |
| Source debit exactly once and main RID shape/mass readback | BLOCKED |
| F2, reset, exit, re-entry and competing-owner exclusion | Negative port retirement exists; full integration test BLOCKED |
| Exact coherent material/pose frame and Windows input p95 | BLOCKED; no new actual M4 measurement |
| Three-body native capacity/explicit refused admission | M3 standalone control exists; ordinary World BLOCKED |

No Godot 4.7 runtime execution, Windows playtest, CI or real M4
same-World performance result may be inferred from this checkpoint alone.
Any later execution must be bound to a new exact commit and its actual
native and Rapier artifacts; success of negative tests is not success of
the integration programme.

## Lead integration recipe

1. Fetch new source heads, preserve immutable #741 and PUBPRES #740; compare
   all files with this branch's parent, and admit only owned Godot changes.
2. Review the native specialist's **same _world** adapter and reconcile its
   concrete method/receipt schema with this default-off port; retain original
   native GCR and Water semantics.
3. Supply an exact visible-frame moving-cell hit-test/overlay. Until then M4
   mouse tools must visibly refuse instead of writing ordinary terrain.
4. Implement bounded main-owned Rapier body lifecycle with native source debit,
   terrain installer, geometry/mass/shape revision readback and applied motion.
   Refuse on any disagreement or capacity exhaustion, and test reset/cleanup.
5. Execute actual source-bound ordinary World tests across continued material
   evolution, simultaneous three-body contact, concurrent edits, stale targets,
   F2/window close and Water variants; then separately run Windows/NVIDIA
   PUBPRES and performance qualification.
6. Keep **Draft/HOLD**, no Ready, merge, production promotion or auto-merge
   until native integration, all positive tests and owner acceptance are real.
