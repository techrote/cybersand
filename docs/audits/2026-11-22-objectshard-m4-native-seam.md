# OBJECTSHARD-M4-NATIVE-001 — Owner-local same-World seam and mutable-body handoff
Date: 2026-11-22
Status: **Draft/HOLD — independently review before merging**
Basis: frozen #741 `febfad1b0b1ee93dac8d5b5a76f145b9ab80ad0a`
Scope: native-only, no ordinary Workbench GDScript changes, no default changes

## Evidence and ownership graph

These findings are grounded in the frozen M3 source, not inferred from UI naming.

| Node | Source locus | Actual authority |
| --- | --- | --- |
| Ordinary worker | `godot/scripts/simulation_worker.gd:39-44,1053-1058,1094-1129,2412-2445,2705-2761` | One Godot `Thread`, holds `_world`, calls `prepare_workbench_coupling` and exactly the native `simulation_tick` |
| Ordinary native World | `godot/native_extension/cyber_native_cell_world.hpp:224-229`; `cyber_native_cell_world.cpp:306-340,494-515` | `CyberNativeCellWorld` owns `std::unique_ptr<World>`; existing tick owns `World::tick()` |
| Existing immutable GCR | `godot/native_extension/workbench_granular_coupling.inc:14-115,118-141` | Owner roster and geometry/mass/inertia locked after first valid sample. Must not be weakened for ObjectShard |
| Ordinary transient mask | `godot/native_extension/cyber_native_cell_world.cpp:598-632`; `native/src/world.cpp:2447-2494` | GCR clears and reconstructs the *entire* shared World obstacle mask twice. This would erase ObjectShard occupancy |
| Scenario replacement | `godot/native_extension/cyber_demo_bridge.hpp:113-130`; `godot/native_extension/cyber_native_cell_world.cpp:409-439,1933-2052`; `simulation_worker.gd:650,699,779,875,2665` | Candidate-and-swap replaces the owned World, changes generation; borrowed aliases cannot survive |
| M3 Lab | `godot/native_extension/cyber_object_shard_lab.hpp:13-49`, `cyber_object_shard_lab.cpp:126,161-200` | Binds a separate exclusive thread and constructs a private Coordinator |
| M3 coordinator | `native/include/cybersand/object_shard_coordinator.hpp:136-175`, `native/src/object_shard_coordinator.cpp:89-148,886-930,1373-1402` | Owns another `unique_ptr<World>`, seeds scenario, ticks it itself, destroys/recreates it on reset |
| Native journal | `native/include/cybersand/world.hpp:522-534`; `native/src/world.cpp:955-971`; `native/include/cybersand/object_shard_mutation.hpp:13-110` | Opt-in bounded mutation tracking on the exact World. Not activated in ordinary World by default |
| M3 physical masks | `native/src/object_shard_coordinator.cpp:708-841` | Produces and installs its own one-World occupancy field. Cannot coexist with GCR's clear/rebuild without a unified composer |

The M3 final qualification explicitly calls the owner ZIP a **separate-World real-worker rehearsal**, not an ordinary Workbench attachment (`docs/audits/2026-11-22-objectshard-m3-final-qualification.md:13-25,284-318,457-460`). Preserve that distinction.

## Native engineering contribution

`native/include/cybersand/object_shard_m4_mutable_adapter.hpp` introduces an opt-in, header-only
`cybersand::object_shard::m4::MutableBodyGate`; its primary value is the **separately versioned mutable-body contract**, which cannot be smuggled into GCR's immutable roster.

A gate is created with **the same live `World&` and `Coordinator&`**, an explicit `OwnerIdentity`, and the one invoking native owner thread. A new non-borrowing `Coordinator::world_available()` preflight fails closed if an exceptional native reset left no World; untrusted cross-thread diagnostics cannot read changing gate slots. A new `Coordinator::m4_owner_readback()` returns a fixed-size, copied, three-body owner proof (`session`, `incarnation`, `tick`, `active_count`, `promotion_pending`, `paused`, `quarantined`, `truncated`, `BodyView`s) without touching the expensive full World presentation snapshot. Four-or-more native bodies are expressly marked truncated/capacity-refused. The gate stores a World address only as a **private, never-dereferenced identity token**. Every operation receives fresh, live references; compares both identities; validates thread and native session/world incarnation; and returns an explicit `Verdict`. No World or Godot pointer is returned to a caller. This is not a public `attach_world` API.

`OwnerIdentity` fences five identities: host session, host epoch, World generation, coordinator session, and World incarnation. `BodyRevision` copies native Handle and body-generation; material/geometry/pose revisions; exact mask/shape digests; structural, product and cargo counts; mass, COM and inertia. `GeometryTicket` binds those values to one proposal sequence and completed native tick. The tickets are copied values and contain no mutable aliases.

The admission contract is:

1. `stage_geometry`: only a real, active, native inventory-owning body may be staged. A previously acknowledged body must have strictly newer geometry **or** material revision for a new installation; an unchanged-geometry material-only change must preserve mass/COM/inertia and all geometry digests. No earlier install may be outstanding. Staging *revokes* an existing physical-time permit without resetting the per-tick step budget. Preserve native shape capacity, add a separate conservative 512-shape/three-body gate, and do not touch the GCR eight-shape/proxy schema.
2. `acknowledge_geometry`: must match the **entire** issued ticket, current native body, current native geometry/material revisions, current native tick and a previously applied native geometry revision with `geometry_pending == false`. Does **not** itself install a collider or modify mass.
3. `grant_completed_tick`: invoked by the exclusive owner only after `CyberSimulationWorker`'s existing successful semantic tick; exact real completed native World tick must be newer than gate construction and any prior permit. It synchronizes the pose serials which that tick already applied, but refuses geometry/material drift. A revoked permit cannot be regranted for the same tick. This method never calls `tick`.
4. `issue_motion`: one complete roster-wide ticket (maximum three native bodies), at most 16 real segments per permitted native tick, only if every body's geometry is installed, unchanged and unblocked. The host must separately advance real Rapier physics. A second issue with the first segment outstanding is held.
5. `accept_applied_motion`: refuses until the M3 native coordinator's actual `accept_motion(full_roster)` has updated **every** authoritative body pose serial on the **same** semantic tick. Exact token reuse, stale/modified identities, changed geometry and reset cannot release a second step.
6. `release_when_empty`: only after no native registry shard `owns_inventory()` and no motion is outstanding. A draining product or cargo carrier is still authoritative; even a material-empty native body must have its physical retirement acknowledged before release. An uncommitted cancellation owns none and does not block release.

This gate does not create, delete, edit, replicate, rescue or burn any material. Actual World debit, material accounting and native installed-geometry receipts continue to be governed by frozen M3's `Coordinator::commit_prepared` (`native/src/object_shard_coordinator.cpp:516-566`), `acknowledge` (587-660), `cancel` (663-674), `Registry::quarantine_partial_commit` and `Shard::acknowledge_geometry` (`native/src/object_shard.cpp:369-376,494-540`). Existing conservation and Fire-opportunity treatment remains exactly untouched.

## Why *not* a borrowed Coordinator or immediate Workbench switch

The current Coordinator is not a freestanding ObjectShard policy component: its constructor (`initialize_world`) constructs a new SerialInPlace World and ticks it; `step` calls `World::tick` directly; `reset` replaces the World. Simply replacing its `unique_ptr` with a borrowed raw pointer would create competing tick owners and leave reset with destructive aliasing.

- **Owner capability** is preferred: the existing `CyberNativeCellWorld`, invoked exclusively by `CyberSimulationWorker`, will eventually host a constrained coordinator sharing its actual World. Only this owner may invoke the native admission protocol and issue successful semantic tick permits. It already knows when candidate-and-swap invalidates the World.
- A **separately instantiated attached coordinator** remains possible only if constructed by the ordinary owner, with explicit non-ownership lifetime, split `before_tick`/`after_tick`, no own World construction, no `reset` that destroys World, and zero independent ticks. These preconditions are not met in frozen M3.
- **Moving World ownership into the standalone Lab**, or running two Worlds and synchronizing their cells, is rejected: ordinary actor/equipment/GCR clients and render snapshots already retain their original owner. Such copying would break exact material authority.
- **Composing transient obstacles** must precede activation. GCR currently clears all masks at `prepare_body_coupling`; M3 separately rebuilds masks. Requires one deterministic roster/proxy allocator for ordinary GCR + mutable ObjectShard owners, admission of union occupancy, no pressure/contact double-counting, and unchanged proxy semantics for existing clients. The adapter deliberately does not pretend to implement it.

The mutating capacity stays conservative and independent of ordinary GCR's established frozen immutable sample contract. Full Workbench adoption cannot be concluded merely because the gate compiles.

## Changed files and reproducible native qualification

Changed on the isolated M4 branch ([Draft PR #751](https://github.com/techrote/cybersand/pull/751)):

- `native/include/cybersand/object_shard_m4_mutable_adapter.hpp` — bounded owner-bound receipts; no changed World or material laws.
- `native/include/cybersand/object_shard_coordinator.hpp` — non-borrowing `world_available()` plus copied, bounded `OwnerReadback` contract.
- `native/src/object_shard_coordinator.cpp` — constant-bound value-only native readback; the original `snapshot()` API and its published materials remain unchanged.
- `native/tests/test_object_shard_coordinator.cpp` — adds real Coordinator/World-based M4 tests to the existing source-bound native `coordinator` suite.
- `docs/audits/2026-11-22-objectshard-m4-native-seam.md` — this evidence/handoff.

Focused added tests exercise: same-World pointer identity through native promotion/activation; real Wood material conservation (world+shard) through one irreversible debit; forged mass/inertia/material/geometry receipt refusal; mandatory completed-tick permit; exact M3 `accept_motion` and old/stale/duplicate motion receipt refusal; one outstanding segment; uncommitted cancellation retaining native World inventory; explicit release/retirement; two-World refusal; wrong-thread refusal; old session invalid after native reset; four real native owners versus three-slot M4 gate capacity; the exact 16-segment ceiling; real state-only Wood ignition requiring material re-ticketing and a new semantic tick; and an interrupted post-debit physics promotion retaining Wood through quarantine until authoritative reset disposal. All original M3 tests remain in the same native translation unit and run unchanged when the native coordinator suite is invoked.

Reproduce on a runner with the complete Git tree and g++-13:

```sh
python3 tools/objectshard/run_native_tests.py --compiler g++-13 \
  --output build/objectshard-m4-native --suite coordinator --sanitize
python3 tools/objectshard/run_native_tests.py --compiler g++-13 \
  --output build/objectshard-m4-native-world --suite world --world-filter object_shard
```

The runner freezes all native inputs and records compiler, source hashes and log receipts; no build log is an accepted proof until the exact candidate's execution result is examined. The existing unmodified test harness disables LeakSanitizer; do not claim leak coverage from its ASan/UBSan run. These tests do **not** simulate actual Rapier, Godot threading, persistent area transfer or Windows physical acceptance.

## Godot-side integration prerequisites and HOLD gates

The separate Workbench contributor/integration lead must:

- Extract the M3 coordinator's World-agnostic policy from native scenario construction/step/reset without losing exact transaction accounting; make the **existing ordinary World** the sole authority and sole semantic tick site. No independent worker, hidden World, or raw long-lived borrowed reference.
- Add a native owner-local coordinator capability to `CyberNativeCellWorld` that creates/retains/destroys this gate on its own Worker thread; verify same World address and host+native session/epoch/generation before every operation. Ensure the Godot facade carries only copied values.
- Implement a merged transient-obstacle mask with explicit body/proxy-slot reservation and no hidden remapping of ordinary actor/equipment clients. Preserve water solver, pressure, Wave, ballistic/soliding and published snapshot behavior; refuse unsupported runtime policies rather than rewriting them.
- Preserve M3 two-phase promotion: reserve real Rapier body disabled; commit exact World material debit; install touched terrain colliders with exact digest; activate only after native receipt. Geometry changes must update Rapier shapes **and mass/inertia/COM** before the accepted native geometry receipt; keep movements held throughout.
- From main-thread Rapier, send genuine applied full-roster substep poses; only the worker's `accept_applied_motion` success authorizes another real substep. Respect current host's PUBPRES callback permit and single-use presentation identity; no independent clock advances.
- On every World candidate-and-swap, area retirement, pause/reset, navigation/shutdown, retire all pending tickets and native owned material through explicit total disposal accounting, join any worker before replacement, then create a fresh session/World generation. Gate refusal `Held` cannot be treated as silent success.
- Publish material, terrain, geometry, mass, body pose and World generation from the same consumed native snapshot. Never use previously queued UI or Rapier states to bless native activity.
- Expand exact host regression for legacy GCR, actor/equipment, swapped World, attempted double/duplicate ownership, every ObjectShard capacity case, and source-bound Windows GPU build before proposed merge.

Explicit unresolved risks: alias-free World replacement, mask arbitration, versioned GCR coexistence, high-volume geometry install/snapshot cost, overlapping Sand/Water/Fire/Smoke opportunity ownership, transaction rollback under failed external collider install, persistent-area/save authority, source-provenance mismatches and physical Windows 11/NVIDIA acceptance.

No default, native material law, performance budget, predecessor PR, or owner acceptance gate is changed. **This is a deliberately bounded native M4 contribution; not an M4 finished integration, not production-ready, and no merge authority.**

## Source-bound verification status

The branch-qualified initial native validation attempt is [ObjectShard workflow run 45066504893](https://github.com/techrote/cybersand/actions/runs/45066504893) on an isolated verification ref. It began on native compilation inputs preceding the final lifecycle/material-permit hardening; its result is **not** sufficient to accept current PR #751. Rerun the same `--suite coordinator --sanitize` command on the final frozen native SHA before independent merge review. The primary PR remains an actual GitHub Draft/HOLD and is based on #741, not main.
