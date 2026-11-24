---
title: ObjectShard M4 ordinary Workbench integration
status: Current
document-kind: contract
scope: Draft/HOLD same-World destructible architecture, main-space Rapier, composed occupancy, moving edits and scoped lifecycle; qualification is source-bound and physical owner acceptance is separate
canonical-for: [objectshard-m4-workbench-integration, objectshard-m4-owner-protocol, objectshard-m4-performance-evidence]
last-reviewed: 2026-11-24
related-documents: [objectshard-001.md, objectshard-m3-preflight.md, ../operations/objectshard-workbench-playtest.md, ../audits/2026-11-24-objectshard-m4-source-recovery.md, ../audits/2026-11-24-objectshard-m4-world-transition.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# ObjectShard M4 ordinary Workbench integration

**Draft/HOLD candidate in PR #754.** This contract describes the opt-in ordinary
Workbench implementation. It does not change accepted-main defaults, grant
merge or Ready authority, qualify retained production binaries, or record
physical Windows/NVIDIA acceptance. Use the
[ordinary Workbench playtest guide](../operations/objectshard-workbench-playtest.md)
for the user-facing controls and evaluator. The separate Lab and M3 rehearsal
remain independent facilities with their original evidence and limits.

## Same native World, ordinary worker and existing Rapier space

`CyberSimulationWorker` remains the exclusive caller of its ordinary
`CyberNativeCellWorld`. The native facade creates the ObjectShard coordinator
inside that owner and attaches it to the existing World. It does not allocate,
advance or reset a second World in attached mode. The facade must destroy the
coordinator, its mutation journal and cached carriers before replacing World.
No World address, native reference, mutable cell array or physics RID crosses
the worker interface. The independent Lab constructor retains its private World
only for that separate laboratory.

`object_shard_m4_runtime.gd` runs on Main and installs material bodies through
`object_shard_physics_bridge.gd` into Main's existing Rapier space. It does not
create or step a parallel physics authority. A Workbench with no authored
actors can initialize that same Main space with an empty immutable roster.
Copied native publications and receipts identify World generation, shard
session, World incarnation, publication sequence, tick and transaction. Main
owns all actual Rapier shape, mass, centre-of-mass, inertia and pose operations.

Source owners are [the native facade](../../godot/native_extension/cyber_native_cell_world.cpp),
[native coordinator](../../native/src/object_shard_coordinator.cpp),
[ordinary worker](../../godot/scripts/simulation_worker.gd),
[Main runtime](../../godot/scripts/object_shard_m4_runtime.gd) and
[physics adapter](../../godot/scripts/object_shard_physics_bridge.gd).

## Promotion and physical motion require actual installation

Promotion begins with an exact captured component and a prepared transaction.
Main reserves a disabled real body and installs its native geometry and mass.
The native owner accepts that reservation before debiting World inventory.
Main installs the resulting terrain revision and supplies exact chunk receipts;
only then may the native owner accept body activation. Queued work or a claimed
success cannot substitute for actual native or Rapier readback.

Every physical interval obtains an exact-frame motion permit while the worker
is idle. Acquisition precedes consumption of native forces, actor/controller
advance and the physics step. A changed publication, queued command, pending
geometry, replacement or ownership barrier refuses the permit without consuming
physical time or controls. The lease prevents native ticks and ordinary brush
mutations from overtaking the installed geometry. Receipt handling remains
available while the lease is held.

The existing Main space executes the admitted interval in bounded physical
segments. Native accepts the complete copied pose set for each real segment
before Main proceeds. Translation, rotation and corner-motion bounds constrain
the interval; exceeding them holds the candidate rather than inventing a pose.
The final completion command pins the exact copied ordinary GCR sample and
its matching equipment frame under the worker mutex. After every real segment
acknowledgement, the worker performs the final native coupling preparation
while the physical lease is still held. That preparation advances no native
time. Its positive receipt releases exactly one ordinary native tick, which
consumes the already prepared packet even if a newer Main observation arrives.
An older turn-local packet cannot replace it, and the final serial is not
submitted to native preparation a second time. Successful native progression
consumes this one-shot permission; a failed preparation retains the lease and
packet, and World retirement clears both. Zero-lease readiness and ordinary
duplicate samples grant no additional time.

The same final envelope captures the bounded existing actor equipment and
effect request sets. The worker consumes only those captured requests with the
pinned frame and epoch on that interval's native tick. Newer publications keep
their queued work for a later interval. An internal material-motion or geometry
wait must not run the equipment adapter as if the user had pressed Pause, even
with an empty request list: cooldowns and autonomous devices belong to the
admitted tick. Genuine user Pause, cancellation, changed actor generations and
World replacement retain the existing cancellation authority. This is shared
worker ordering; equipment request schemas, recipes and material laws are
unchanged, and no separate Equipment development branch is imported.

A geometry edit preserves the body's angular velocity and adjusts
linear velocity for the centre-of-mass shift; it must not restore an unrelated
sleep state or manufacture angular energy.

## Occupancy composition protects both body domains

Ordinary immutable GCR bodies retain IDs 1–48; attached mutable material bodies
use 49–64. Native stages the GCR mask and composes it with the current shard
mask before publishing either as the World's transient obstacle field.
Ordinary GCR clear/rebuild work cannot clear a valid shard mask first.

The strict World compositor validates domains, ordering, bounds, capacity and
cross-domain conflicts before mutation. Derived raster overlap is resolved
deterministically by the adapter with immutable GCR occupancy taking priority;
the overlap is counted and does not transfer or destroy cell inventory. The
adapter submits disjoint domains to the strict compositor. Refusal preserves
the last valid occupancy. A genuine partial application invalidates the receipt
and quarantines the owner instead of allowing further motion against a partly
installed mask. Receipts are fenced by World token, tick and revision, and
become invalid on retirement or replacement.

The admitted protected-source transition for this compositor is documented in
the [World transition review](../audits/2026-11-24-objectshard-m4-world-transition.md).
It is an append-only reviewed compatibility entry. The compatibility lock,
material IDs and refusal semantics were not refreshed or bypassed.

## Connected architecture, supported materials and budgets

Attached discovery follows connected supported structural cells, including
mixed materials. A component connected to the bounded canvas boundary remains
fixed. A severed Wall cap is part of its disconnected component; it cannot keep
a large facade fixed merely because it is Wall. This attached support policy
is distinct from the retained standalone Lab's historical any-Wall support
rule. Unknown boundaries and exhausted discovery work refuse promotion.

The explicit structural set is Wood, Wall, Red Brick, Concrete, Granite Block,
Industrial Brick, Reinforced Concrete, Steel Plate, Painted Steel, Corrugated
Steel, Steel Grating, Ceramic Tile, Chemical Glass and Dark Glass. Additional
inert materials are admitted by explicit checks against their ordinary kernel
and pair-rule metadata. An arbitrary hard-surface flag is not permission to
move material whose chemistry is unsupported. Other material stays under its
ordinary World owner.

| Attached limit | Bound |
| --- | --- |
| Canvas | 64–1,024 cells per dimension, within the prepared native simulation region |
| Mutable bodies | 16 |
| One shard's bounding area | 16,384 cells |
| Aggregate shard bounding area | 65,536 cells, further bounded by the canvas |
| Shapes in an admitted shard | 512 rectangles |
| Immutable GCR ID range | 1–48 |
| Mutable ObjectShard ID range | 49–64 |

Admission accounts for reserved and owned storage. Capacity refusal must leave
the preexisting World and shard ownership intact. These are candidate limits,
not claims of unlimited architecture or performance at every maximum.

## Fragmentation transfers a complete island

An attached active body with disconnected structural islands can stage a child
body. The largest connected island remains in the parent; a complete additional
island is selected in stable order. A bounded nearest-island assignment keeps
each product and lodged cargo carrier with exactly one resulting owner. The
child retains the copied payload, temperature, incarnation and reaction schedule.
Preparing a child reserves storage but does not make a second authoritative
inventory or remove the parent's cells.

After actual child physics reservation, native revalidates the parent's material,
geometry, pose and payload identity plus every copied tuple and schedule. It
preflights the remaining parent shape cover before atomically moving authority
from parent to child. World inventory is neither debited nor credited by this
operation. Main installs the changed parent geometry while the child remains
disabled; exact parent installation is required before child activation.

Both bodies inherit the prior rigid velocity field at their new centres of
mass: the original linear velocity plus the rotational contribution at the
centre displacement. The transfer does not inject an arbitrary angular impulse.
An exhausted body, bounding-area or shape budget retains the disconnected cells
under their existing owner and reports a fragmentation refusal. Such a refusal
does not authorize deleting an island or replacing it with decorative particles.

Source and native witnesses live in [registry transfer](../../native/src/object_shard.cpp),
[coordinator handoff](../../native/src/object_shard_coordinator.cpp),
[storage tests](../../native/tests/test_object_shard_storage.cpp) and
[coordinator tests](../../native/tests/test_object_shard_coordinator.cpp).
Passing those witnesses does not substitute for actual ordinary Workbench child
body installation and motion in the platform qualification campaign.

## Continuing chemistry and witnessed moving edits

Moving Wood retains its complete material state, temperature, incarnation and
native reaction schedule. It uses the existing shared Wood lifecycle. Products
remain in exactly one owned carrier until a validated native transfer commits
them to World. Sand cargo, historical Water exposure and output transfers retain
their existing bounded native contracts; this is not arbitrary fluid solver
state transfer or an internal gas-transport simulation.

The [ordinary long-burn witness](../../godot/tests/test_object_shard_m4_long_burn.gd)
tracks an enclosed moving Wood cell through its full natural countdown and the
resulting acknowledged geometry/mass change. The surrounding Brick prevents
fresh emitted Fire from restarting that cell's lifetime. A separate four-cell
structure is removed through exact displayed moving-cell cuts to verify final
collider and inventory retirement. These are distinct observations: continuous
combustion in a large building does not promise a fixed whole-building burnout
time when neighbouring Fire can ignite surviving Wood again.

The admitted material interaction is displacement/exclusion, bounded Sand
lodging and its contribution to mass, and witnessed Water/Fire chemistry.
Rapier supplies gravity and rigid contacts. Native fluid/granular impulse
feedback is still routed through the ordinary immutable actor roster; mutable
shards do not receive that feedback as buoyancy, drag or Sand impact forces.
The eventual seam is a source-bound mutable-body feedback receipt, rather than
importing another programme's actor, equipment or force-law development branch.

Overlap relocation preflights every destination before moving any material.
The attached Workbench searches at most 64 cells in Chebyshev distance, with
at most 1,048,576 examined destination candidates per complete composition.
The retained standalone laboratory keeps its eight-cell radius. The search
excludes occupied, reserved, shard-covered, immutable GCR and protected ingress
cells, preserving deterministic ring order and native World sidecars. Exhausted
work returns `Capacity`; no valid bounded destination returns
`DestinationUnavailable`. Both refuse before any material or mask commit.
The `relocated_cells`, `relocated_water_cells` and `relocated_sand_cells`
counters count successfully committed carrier-move events, including repeated
moves of the same cell; they are not inventory censuses or momentum-transfer
witnesses. The separate probe and limit-hit counters include refused preflight
work. Since Rapier has
already completed that segment, the session holds for Restore; it does not
claim to roll physics back or discard the obstructing inventory. Partial
post-commit failure quarantines the owner. This bound must remain visible in
mixed-material qualification and the owner evaluator.

Cut and ignite requests retain the displayed native publication and exact
local-cell witness, including body generation, pose, geometry and material
revisions, material state, temperature and incarnation. The ordinary worker
revalidates them against its native owner. A changed target produces an explicit
refusal; it is never re-hit against a different World cell. Successful receipts
copy the original target and separately identify the resulting transaction and
post-edit revisions. Geometry changes must be installed before more motion.

The ordinary pointer tools expose that cell-level authority directly: a
one-cell cursor, disabled ordinary paint radius and at most one outstanding
moving-cell request. A held pointer supplies only its current position after
each native/geometry barrier. Release, tool change, pan, resize and navigation
cancel the intent. A stationary igniter does not repeatedly reset an already
burning cell's reaction lifetime.

The native snapshot supplies owned inventory and material counts independently
of the displayed World raster. That raster is a material projection: ballistic
Water overlays and fractional-Water dithering do not constitute additional grid
carriers. Conservation witnesses must count authoritative stored cells and
owned shard cells without counting a prepared component twice, then account
separately for airborne quantities, pressure-held Water, authoring, reactions,
transfers and reset disposal. A self-reported zero ledger residual alone is not
an independent material witness.

An explicit on-demand inventory inspection uses the existing exclusive worker
and native read APIs at a paused, no-motion, no-edit boundary. It captures raw
stored material cells, owning-shard payloads, an independent Water-region scan,
all bounded ballistic parcel quantities and the ordinary quantity ledger.
Exact owner, publication, tick and revision identities fence the request and
the completed copy. Resume, edits, replacement, stale identity, an occupied
single-result slot or an incomplete parcel copy refuse the read. This is a
bounded diagnostic transaction outside timed profiles, not another simulation
owner or a full rasterization on each frame. Ordinary **Save diagnostics**
continues to produce its compact operational report.

## Ordinary authoring and lifecycle

The ordinary Workbench exposes an explicit **Structures…** panel. Its five
starts are native material recipes: a multi-storey tower, three-span viaduct,
timber workshop, mixed structure with Sand/Water/Fire and eight-body collapse.
Bodies are discovered and promoted from those cells after support removal;
the scenes do not pre-spawn animated substitutes. Ordinary paint, camera and
tool controls continue through the existing Workbench.

Admitted brush commands retain their order across normal ownership and motion
barriers, within the existing bounded queues. Native void setters cannot be
used as evidence that a fenced edit succeeded. Main displays shard material at
the acknowledged native pose only when its World generation and revision agree
with the uploaded ordinary World texture. It does not combine an unacknowledged
live Rapier transform with an older material publication.

Pause drains already admitted receipts and stops semantic and physical
progression. Reset and authored-start reopening use the existing World
replacement transaction; accepted replacement retires old native inventory,
physics RIDs, commands and receipts. Generic actor shutdown is not itself
authority to discard live shard inventory. Same-World detach refuses while
owned inventory or a prepared transaction remains.

The explicit **Settle into canvas** tool can return a slow, nearly grid-aligned
body to native terrain. Native admits speed at most 0.25 cells/s, angular speed
at most 0.01 rad/s and rotation within 0.001 rad of a quarter-turn. The origin is
snapped to the nearest grid point as part of this deliberate authoring operation.
Every occupied carrier needs a unique empty resident destination, with no other
shard or GCR overlap and no pending external exposure. An oblique settled body
stays physically owned and receives a clear refusal; it is not lossy-rasterized.

The native request stages the entire return, then Main freezes and reads back
the real body. That receipt permits the exclusive native owner to withdraw only
the body's derived mask and transfer each complete payload and temperature into
World while debiting its shard carrier. Main then removes the actual RID and
installs the new native terrain; their terminal receipts retire the shard.
Neither a staged request nor a queued operation is reported as completed return.
Refusal before transfer preserves inventory; a partial failure quarantines the
owner. Cancellation cannot resurrect a body after World has received its cells.

Return preserves the same World's completed tick and the cells' material,
state and temperature, including remaining burn or product lifetime. Once
returned, those cells use the ordinary World scheduler at their destination
coordinates. The shard's private per-cell scheduling cache is retired with its
owner; it is not installed as a second scheduler inside World. Fragmentation
between shard owners, in contrast, copies the source reaction schedule.

**Save start** persists the current authored recipe. Ordinary paint and Erase
stamps remain part of that recipe, including support cuts made during play.
Reopening or **Restore start** reconstructs those authored cells in a fresh
World; a recipe with severed supports can detach again when resumed. Reload a
named Structures scene to obtain its pristine uncut demonstration, or save a
custom start before cutting it. Moving-body cuts, evolved combustion, live
body poses, owned carriers and replay state are not saved as a live checkpoint.
Flatten or preserve-cell operations that would omit shard material must refuse
visibly. The candidate does not claim durable exact live-state persistence.

## Performance evidence has separate clocks

Compact owner publications omit the redundant World raster already supplied by
the ordinary worker. Packed shard cells and colours are reused until their
material revision changes. Hard terrain rebuilds follow its source revision.
The bounded Main receipt rendezvous services admitted transactions without
creating extra cellular ticks or allowing unbounded waits.

The rendezvous has an eight-millisecond budget and at most 48 operations per
Main poll. It can finish several already admitted segments in one poll. Initial
physics binding still requires a positive native readiness receipt. After that
binding, a completed native publication and installed geometry/terrain establish
local readiness without another zero-lease worker round trip. The next physical
interval still needs the exclusive worker's exact-publication motion permit,
and every completed segment still needs its exact native pose acknowledgement.
The suppressed-readiness counter measures only the redundant control commands;
it is not a count of skipped physical or native acknowledgements.

The moving-material texture cache includes World generation, World incarnation,
session, shard identity and generation, body generation, material revision and
dimensions. A new owner cannot reuse retired pixels merely because its small
revision counter matches. Pixel-update qualification runs with an actual Godot
renderer; the headless dummy renderer cannot establish texture replacement.

The latency probe separates native progress observed by Main, renderer
post-draw intervals and individual work durations. Its cheap ordinary cohorts
identify owned material-body count (including sleeping bodies), pause state and
camera mode. The independent scene profiler samples actual Rapier sleeping state
for separate awake-body cohorts. Coalesced publications retain their native
tick delta; they are not labelled as worker execution cadence. A pause or cohort
change breaks the interval clock. Headless callback cadence is explicitly
labelled headless, and all callback summaries report hardware presentation as
unverified.

The [source recovery ledger](../audits/2026-11-24-objectshard-m4-source-recovery.md)
preserves the November 23 evidence: 44 physical-chain checks, 134 Windows checks,
eliminated full rasterizations and approximately 26–30 headless semantic ticks/s
with bounded rendezvous. Those measurements are historical. They do not prove
ordinary Workbench completion or resolve the owner's earlier active-body
display rate below 10 FPS. Current qualification must use the current complete
source, actual loaded runtime and ordinary Workbench path.

The completion workflow runs native/sanitizer, Linux, Windows, graphical,
ordinary Water/actor/equipment regressions and the delivered launcher. Its
profiles vary scene, body population and camera while retaining material,
native/Rapier and rendering witnesses. Hosted or software-rendered post-draw
results remain distinct from a physical Windows/NVIDIA display observation.
Do not turn an incomplete or failed campaign into a performance acceptance.

## Programme boundaries and remaining qualification

The implementation does not import PUBPRES, Equipment, Actor Compose or RAMCACHE
development branches. Shared native occupancy and Main ordering changes are
local integration seams. Any future adoption into those programmes requires
their own reviewed source union, roster/domain agreement and fresh regressions.

The source-bound evaluator manifest and final qualification receipts must name
the actual published source commit, tree, complete native build inputs, loaded
native library, engine, Rapier and package inventory. A local development build
or a retained production binary is not an interchangeable identity. Final
evidence must separately state implementation failures, passing engineering
checks and physical owner questions. No document or passing automation confers
default activation, runtime publication, Ready or merge authority.
