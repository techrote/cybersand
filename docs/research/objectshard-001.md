# OBJECTSHARD-001 — compact moving material domains

Status: implementation in progress; staged Draft/HOLD research. No production
default changes, merge, Ready promotion or release is authorized by this record.
The intended complete slice is M0–M2: chemically active, mutable, nonfracturing
rigid aggregates with bounded material exchange. M0 alone is not completion.

## Source and ownership

Fresh implementation base: `30e1cddd3d678456df10f52f7a2fb2210a9daaad`.
This is accepted main after CI-only #722. Its native/Godot production inputs
match the planning baseline `846fe0533b3170e7b01f690518da49fc40cc24d1`.

Donors #347 (`1598115c9065239cc1eaec11e99077274b457be1`), #283
(`254235ec4c3d58782bba44b478caca86bf57c856`) and #393
(`e4c2649e82d943554f4dc6a0634336770cda08f6`) remain historical evidence.
No donor branch was merged or copied over current shared files. The historical
520-cell RedBrick tree proved motion, not continuing chemistry. Its later
supported-Sand clearance failures remain failures under their original criteria.

Protected concurrent branches: SWARM #715/#716, CI #718, PUBPRES #719 and
`exp/gen006-persistent-areas-001-20261121`. The new Lab has its own facade,
scene, session and Rapier adapter; it does not modify their worker/rendering
or persistence implementations. Ordinary native Water remains opt-in for
Wave/ballistic; ordinary Godot gameplay keeps its existing Wave/spill/ballistic
selection. This independent bounded Lab explicitly selects SerialInPlace.

## Executable stage boundaries

| Stage | Behavior | Qualification at the M0 checkpoint |
| --- | --- | --- |
| M0 | Compact inventory, ordinary-mutation discovery, exact promotion, actual collider switch and Rapier motion | Native and actual Linux iteration executed; independent scoped review passed |
| M1 | Shared combustion, material products, mutable geometry and sleeping-body chemistry | World extraction parity passed; shard scheduler is subsequent work |
| M2 | Authentic output, physical Sand lodging, historical Water exposure, Windows evaluator | Subsequent work; not advertised by M0 capabilities |

## Native contract

`object_shard.hpp/.cpp` owns bounded row-major storage by bounding-box area,
structural/product/cargo roles, cell incarnations and deadlines, exact rectangle
geometry, connectivity and declared unit-cell mass properties. The local lattice
origin never changes as material erodes. Products do not create rigid shapes;
cargo contributes declared mass separately from cohesion.

`object_shard_coordinator.hpp/.cpp` is one exclusive owner for World and the
registry. The first implementation runs synchronously under the isolated Lab
owner; it creates no per-shard World or worker thread. Godot main alone owns RIDs
and manually steps an inactive private Rapier space.

`object_shard_mutation.hpp` is one bounded opt-in Lab journal, not one World
field per shard. Ordinary writes, movement, thermal/state changes and merged
worker reports update payload witnesses. Material changes also enqueue deduped
topology seeds. Full components either fit the discovery/storage bounds or are
refused; one erase can discover multiple disconnected components. Wood and
RedBrick cohere only with their own material; Wall is an explicit scenery anchor.
Sand adjacency is not a bond.

Promotion closes Lab mutation admission and pauses both semantic and physics
clocks. It captures exact payloads and witnesses after a healthy returned tick;
main reserves a real frozen body; native commits; main installs exact affected
terrain chunks and returns content receipts; native applies occupancy; main
activates the body and acknowledges activation. Chemistry cannot run at
`ReadyToActivate`. A queued terrain update is never an installed-content receipt.

Before commit, cancellation preserves World inventory. After unexpected partial
progress, only actually debited cells belong to the quarantined shard; undebited
cells remain World-owned. Transaction sequences never restart on reset. Detailed
receipt eviction never authorizes replay. Control receipts have reserved storage
independent of product carriers.

Geometry uses independently bounded exact rectangle covers rather than an
eight-shape assumption. Revision receipts bind occupied geometry and mass/COM/
inertia carrier identity. Disconnected islands will remain an explicitly
nonfracturing compound with `split_pending`; this is not fracture simulation.

## Shared chemistry seam

`material_lifecycle.hpp` extracts the existing Wood, Fire and Smoke decisions;
World retains rule ordering, traversal, transport, activity and accounting.
Wood uses `state_b` on its two-tick lane, emits real Fire with `state_a=32`, and
does not convert directly to Smoke. Fire expiry produces Smoke. Motion must not
change the logical random-coordinate anchor. Internal world-up gas transport is
not implied by retained product lifecycle support.

The original and extracted World wrappers were compared on immutable source
fixtures: **4,472 assertions, zero differences**, including serial/phased lanes,
tuples, products, temperature, accounting, signed coordinates and epoch wrap.
This baseline must be rerun on final combined source.

## M0 evidence and repaired findings

Storage/contact qualification: 8,045 and 44,727 checks with zero failures,
including sanitizer delta checks and zero measured steady storage allocations.
Repaired coordinator suite: 969 checks, zero failures. Independent partial-debit
fault injection: 229 checks, zero failures, throwing before/after debits 1, 4
and 9. The coordinator translation unit used UBSan; this is not a claim that
every World translation unit had sanitizer instrumentation.

Independent review repaired dropped neighbour discovery, stale reset cancellation,
partial-debit double ownership, pose/mask mismatch on refusal, coarse occupancy
overlap refusal, journal clear history and extreme-coordinate overflow. The
reviewed M0 coordinator SHA256 is
`34660ca23df135d45e06d30bb527d2cb71840fb1bc25938f326ba3298ef58053`.
Independent review manifest SHA256:
`e13ed952f5a15222736e9c390faf9fc119cb6d2042562e978fe7b9afc4149334`.
There is no unresolved Class A/B finding in that early protocol scope; final
combined source requires another independent review.

Actual local Godot iteration uses installed **4.7.2**, not the final pinned4.7
Windows acceptance runtime. The source-built extension and selected Rapier
execute real reservation, mass/shape readback, fall, impact and rotation. The
ordinary scenario contains570 Wood cells, erases44 through normal edits and
promotes526. No old native extension is reused. Full result/source manifests
are retained with qualification artifacts; local timings are not target-PC
performance or physical owner acceptance.

The final M0 iteration passed55 integration checks across120 actual Rapier
steps, tipped1.68452 radians and reached deepest occupied geometry109.99316
against the floor at110. The separate revisioned bridge passed28 checks;
package verifier adversarial fixtures passed8. These results establish the
local M0 mechanism, not M1/M2 or Windows completion.

## Delivery constraints

See [ObjectShard Lab playtest](../operations/objectshard-lab-playtest.md).
The final evaluator must bind committed source, native DLL, selected Rapier,
pinned Windows Godot, scenario identities and complete file inventory. Missing
or stale binaries must fail verification. Windows automation, rendered evidence
and owner Windows11/NVIDIA physical acceptance are separate statuses.

Unsupported scope remains explicit: arbitrary material admission, fractional
quantity transfers, Wave/pressure/inertial/ballistic sidecar transfer, general
internal transport, consuming Acid reactions, fracture and durable persistence.
