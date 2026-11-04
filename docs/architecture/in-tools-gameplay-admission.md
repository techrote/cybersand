---
title: IN-TOOLS gameplay command admission
status: Planned
document-kind: design
scope: Issue 361 source-qualified preparation for reversible liquid openings, explicit sinks, bounded sources and one existing usable; current primitives are distinguished from proposed commands and unqualified host integration
canonical-for: [in-tools-gameplay-admission, in-tools-command-ownership]
last-reviewed: 2026-11-04
related-documents: [inertial-cellular-v1.md, liquid-solver-family-policy.md, liquid-prepared-setup-and-receipts.md, ../systems/actor-usables.md, ../operations/in-tools-fixtures-and-playtest.md, ../audits/2026-11-04-in-tools-admission.md]
---

# IN-TOOLS gameplay command admission

## Decision and source boundary

**Planned; preparation complete does not mean gameplay implemented.** The next
bounded application slice should meter the existing `liquid_drain`, then add an
authored valve through the existing exclusive owner. Reuse #370's panel,
prepared-session route and immutable fixture inputs. A geometric source can
deposit whole cells without new physics. A velocity-directed source requires a
new native input contract; upward ballistic Water requires a separately approved
law change owned by #362. This task authorizes none of those production changes.

The inspected accepted source is `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`,
tree `36ce5a01e754a141c321f41cac7f1c6b6059c371`. The #359 reassessment is already
merged through #367. The inspected **unmerged** #370 head is
`fbe82bcab8f821aac442c2bf59eb57b279717873`. Its comparison guide and campaign are
branch evidence, not accepted-main files. The
[dated audit](../audits/2026-11-04-in-tools-admission.md) owns revalidation,
execution identities, reviews and limitations. Recheck live heads before coding.

**Current production constraints:** native C++ owns cells; the desktop simulation
owner serializes adapter operations; native pool jobs call no Godot API; Rapier
and live bodies remain main-thread owned. Production Water remains FreeMass.
Materials 132–137 from #358, new catalogue consumers, structural/contact changes
and pressure optimization are not imported by this admission.

## Capability and missing-interface map

| Capability | Current source authority | Availability and consequence |
|---|---|---|
| Water IN and Brine IN | `LiquidPolicyBuild::running()` in [liquid_solver_policy.hpp](../../native/include/cybersand/liquid_solver_policy.hpp) | Public native construction and prepared application routes; reference variant only. Water 3 admits FM/CY/PF/IN; Brine 24 admits CY/IN. Other liquids do not gain IN. |
| Whole Water ingress | `World::set_cell_state`, `set`, [world.cpp](../../native/src/world.cpp); `emit_disc`, [adapter](../../godot/native_extension/cyber_native_cell_world.cpp) | Existing source operations. IN Water is zero/deletion or the actual full-cell maximum. Raw writers are not gameplay authorization or finite supply. |
| Brine ingress/removal | Same native writers and `QuantityLedgerSnapshot.material_cells` | Existing native/adapter whole-cell edits. Brine quantity is a cell count; its state byte is not Water mass. MicroScenario schema 2 does not schedule Brine fills. |
| Prepared normalization | [water_normalization.hpp](../../native/include/cybersand/water_normalization.hpp), [prepared_world.hpp](../../native/include/cybersand/prepared_world.hpp) | Public construction-only `water-normalize-v1`; explicit source/sink delta, digest and receipt. It does not round later live commands. |
| Opening Wall | Adapter `water_experiment_erase_rect` and schema 2 `erase` | Implemented scheduled fixtures; destructive primitive has no material allowlist. Tool opening must authorize only its own Wall port. |
| Restoring Wall | `emit_disc(..., Wall)` / raw native writer | Primitive exists, but no schema 2 closure event or ready reversible valve. Occupied non-body cells may be overwritten by the raw primitive. New owner-side placement/precondition and effect accounting are required. |
| Explicit sink | `liquid_drain` in [usable catalogue](../../godot/scripts/usable_catalog.gd), `_edit_disc` / `_write` in [usable runtime](../../godot/scripts/usable_runtime.gd) and [physical override](../../godot/scripts/physical_usable_runtime.gd) | Ordinary gameplay effect exists. Sampled counters follow attempted writes; the physical override confirms material transitions. Neither supplies exact Water-unit receipts. |
| Aimed source / payload | `water_lance`, `water_capsule`, existing processors | Deposits fresh material; no carried projectile velocity enters Water. Existing rechargeable equipment energy is not a finite material reservoir. |
| IN velocity assignment | `diagnostic_set_inertial_cell` in [world_inertial.inc](../../native/src/world_inertial.inc) | Native diagnostic/fixture operation, not an admitted gameplay nozzle or Godot launch API. Do not promote it by calling it after paint. |
| Physical ownership fences | [physical_actor_session.gd](../../godot/scripts/physical_actor_session.gd), [physical_usable_equipment.gd](../../godot/scripts/physical_usable_equipment.gd), [simulation_worker.gd](../../godot/scripts/simulation_worker.gd) | Existing run/control/equipment/sequence/lease routes must be reused. A new ad-hoc command mailbox is unnecessary. |
| Applied policy and initial receipt | `get_liquid_solver_policy`, `get_applied_liquid_construction_receipt`, generation in adapter | Public copied native-backed readback. Initial receipt remains tick-zero and is not a per-tool-command result. |
| Exact command receipt | No current per-command native source/valve receipt | Host-local before/after observation is possible; label its authority honestly. A strong atomic native edit/result contract needs separate admission. |
| Full gameplay replay | Native CYPS3 plus separate application ownership | Native continuation exists, with restrictions; equipment stock, pending commands, bodies, input and host identity are not supplied by a comparison capture or level save. |

The [prepared receipt contract](liquid-prepared-setup-and-receipts.md) and
[IN reference](inertial-cellular-v1.md) remain the canonical owners of their
native formats. This document adds no replacement physics or receipt codec.

## Exact quantities, state and refusal semantics

### Quantity units and admission

**Current.** For Water precision `b` in 3..8, one full cell is `Q=(1<<b)-1`
native units: 7 at 3 bits and 255 at 8 bits. Live IN/CY Water admits a full Water
cell; `set_cell_state(Water,0,...)` means removal, not zero-dose injection.
Nonzero partial IN Water returns false before allocation or mutation. StateB
coherence must satisfy the actual Water policy. Brine is one stored cell per
unit, independently of its lifecycle stateA. Never add Brine counts to Water
units or multiply a FreeMass sink's edited-slot count by 255.

`water-normalize-v1` acts on resolved final setup tuples in a new candidate:
full cells stay full; a partial mass `m` becomes full when `2*m >= Q`, otherwise
Empty. It records gross positive and negative deltas, not only net change.
Prepared input is bounded by 1024 per side and 1,048,576 final tuples, with a
possibly smaller caller limit. Policy/capacity/normalization refusal discards
the candidate and keeps the existing World, body graph, selection and receipt.

The adapter's legacy `water_experiment_fill_rect` takes normalized 0..255-style
input (its accepted argument range is 1..255), converts using
`floor((2*n*Q+255)/(2*255))`, and may return **true with zero delta** at low
precision. It can also overwrite stored cells, and a later failure can follow
earlier mutations. Its boolean is not an actual dose, an empty-only source or an
atomic multi-cell promise. The proposed commands use actual native units and
explicit no-effect/refusal outcomes; do not reinterpret that legacy API.

**Planned minimum source:** selected material only,16 target cells maximum,
finite supply, deterministic row-major eligibility and debit of actual admitted
units. Empty/unmasked/resident destinations only. No replacing liquid, filling
a Wall, same-material repaint, hidden top-up or creating cells without a source
ledger. For fair FM/IN source arms, initially request full-cell doses on both;
record different admitted doses rather than declaring equal schedules equal
quantity. Exhausted/blocked/no-effect attempts retain supply and charge.

**Planned sink:** selected material only,16 inspected target cells maximum,
finite per-run removal budget. Remove whole selected cells, debiting the actual
stored Water amount for FM and `Q` for IN, or one for Brine. An empty cell is an
explicit no-effect refusal. A closed fixture obeys
`stored_end = stored_start + actual_source - actual_sink`; scene transfer through
a hole is neither a source nor a sink. Native `QuantityKind::ExternalEdit` and
whole material inventories provide independent cross-checks; reactions and
other external edits are disabled in the primary fixture and cannot be hidden
inside a residual.

### Motion, masks and boundaries

**Current.** IN stores signed 16-bit vx/vy and signed 8-bit ax/ay, six bytes per resident
cell when any material uses IN. Velocity uses 16 quanta per cell; vx is −32..32,
vy is 0..32 downward-positive, ax/ay are −15..15. Gravity is 4; default damping is
1/16. Motion may persist after shutoff, and low horizontal speed need not decay
to zero under integer truncation. A guaranteed finite flow tail is not part of
the current law. Every target along the native substep path is rechecked;
read 3 / write 2 requires explicit rule radius 3. A radius 2 IN request refuses.

Fresh external writes reset IN motion, even when a same-material write changes
only hidden family state. A source must therefore avoid repainting existing
Water to simulate acceleration. Body relocation carries the existing tuple;
it does not supply a launch impulse. Diagnostic velocity setters and arbitrary
tuple editing are excluded from gameplay input.

Raw nonempty placement refuses a body-mask cell. Raw Empty removal is not
equivalent protection: it can remove stored material beneath a mask. The
proposed source, sink and valve each preflight **all** relevant body cells,
including detached equipment, against the current owner-produced mask/pose
revision. Never manufacture a Wall inside a body or open a port by erasing
unrelated terrain. Preserve the existing coupled placement and no-crossing
contract; any change to mask publication or Rapier coupling belongs to #347.

Native sparse signed coordinates exist; the Godot adapter is bounded to 1024².
Native boundary tests may translate across negative/chunk/core seams. Desktop
fixtures remain in their actual adapter domain. A simulation ROI is not an
impermeable boundary: verify actual hard-wall positions and absence of liquid
on the protected side. Total Wall count alone is insufficient.

### What failure means

The prepared-session transaction already provides old-owner retention on
unsupported construction. It does **not** make arbitrary later rectangle edits
transactional. Raw `emit_disc` returns void and may skip refused cells; raw
rectangle helpers can partially edit before returning false. Sampled usable
slot counters optimistically follow that call; the physical override checks
the resulting material but still counts slots. These are concrete reasons to
avoid claiming an existing exact command receipt.

The future owner validates policy, finite budgets, health, generations, lease,
cell preconditions, complete mask and capacity **before** changing anything.
A normal `refused` result means unchanged authoritative content/motion/quantity,
no spent resource and no phantom successful activation. An unexpected exception
after execution begins is an execution fault, never a clean refusal or a reason
to retry a possibly applied command. Preserve actual partial accounting, mark
the application owner terminal/unpublishable and require the existing explicit
clear/reconstruction path. External-edit exceptions do not automatically set
native `has_failed()`; block further edits even while that flag remains false.
Native failed ticks themselves set the quarantine latch and have no rollback; distinguish
attempted `tick_index` from successful `completed_tick_index`.

For strong all-or-none multi-cell valves/sources, prove that the restricted
resident preflight eliminates every later failure, or obtain the native checked
edit contract below. Do not promise atomicity merely because commands are serial.

## Four bounded tools

| Tool | Proposed behavior and measurements | Admission rank |
|---|---|---|
| A: controllable leak | Authored port with closed/open state; preflight own Wall for opening and Empty/unmasked cells for closing. Width 1/2/4; open, conditional close, reopen. Record actual changed coordinates, quantity, first downstream flow, per-tick flux, motion tuple distribution, voids and tail. Occupied closure refuses without deleting liquid. | **Requires minor application integration** for a narrowly proved resident port; strong multi-cell native receipts require a new input contract. |
| B: bottom/side drain | Physical opening and authorized removal intake are distinct. Bounded sink can start/stop and exhaust; source-only or closed controls distinguish transport from removal. Record accepted sink units, complete remaining quantity, empty/blocked refusals and positional barriers. | **Ready with existing APIs** as native test primitives; **requires minor application integration** for honest metered gameplay and receipts. |
| C: geometric outlet | Finite whole-cell source at an authored port with guide walls; aim chooses geometry/source position. New motion is zero; gravity and collisions decide subsequent motion. Report actual dose and trajectory, including zero flow. | **Requires minor application integration**. A geometric outlet does not promise a pressure pump or directional launch. |
| C: velocity nozzle | Atomically admit a whole source cell with bounded non-upward IN motion, actual source/impulse accounting and replay identity. | **Requires new native input contract**, separately authorized. Upward spray is **a separately approved physics-law change**, #362; no implementation in this phase. |
| D: existing `liquid_drain` | Add explicit opt-in Water/Brine metering to U10; preserve equipment ID, body, action stream, charge and cooldown. Applied result binds native session/policy plus actual per-command quantities. | **Requires minor application integration** and exact real-host qualification. Native-issued command receipts remain a separate gap. |

### Reversible port contract

The authored port has a stable fixture/port ID, immutable cell list, expected
closed Wall fingerprint and accepted state. Opening verifies all port cells are
its Wall; closing requires every port cell be Empty, unmasked and authorized for
hard-terrain placement. Reject stale geometry revision, invalid material, unknown
port, already-open/closed, occupied liquid, body occupancy or lost session.
An occupied port stays open until a new explicit accepted close; the tool never
silently converts trapped Water into Wall. A stronger liquid-displacing valve
is deferred because it needs conservative displacement and contact ownership.

For the narrow application-only implementation, register at most 16 unique
resident cells during prepared construction; `inspect_cell` alone does not
prove residency. Reset invalidates that registration. Reserve the complete
read/write/post-read/receipt budget before mutation. Run preflight and commit
under the existing cancellation mutex in one exclusive-owner interval, without
`await`, ticking, mask updates or unrelated writes. Resident Wall↔Empty edits
avoid source allocation and Water conversion. Mandatory post-verification must
confirm the entire result before a successful publication. This supports
normal preflight refusal followed by a bounded serial commit; unexpected
execution failure still has the distinct stop/quarantine semantics above.

Closing halts future passage only after the closure is actually applied. It
does not remove downstream Water or cancel retained momentum. Startup/shutdown
latency is counted from accepted native boundary to observed effect. Distinguish
button intent, owner acceptance and visible publication. Reopen follows the
current state, not assumed historical success. The current schema 2 erase event
cannot encode this state machine.

### Ordinary usable contract

Reuse [actor-usables](../systems/actor-usables.md), physical U10 selection/aim and
the existing command lease. Catalogue U10 costs 0.85 charge, has 0.10 s cooldown,
range 29 and radius 4. Runtime bounds are 2048 reads/128 writes per step, charge 100,
recharge 6/s; the metered experiment adds a stricter 16-cell effect cap without
changing ordinary U10 defaults. Charge is the fixed 0.85 per accepted U10 activation; power and the 35%
precision pulse affect the effect, not that fixed cost. The integration must
test that acceptance and charging agree, preserving the equipment architecture.

Use existing physical equipment instance/epoch and actor control generation.
The strict existing physical usable request schema must be extended through an
explicit opt-in profile/version; silently appending fields can be refused by
its exact shape validation. Generic brush queues do not provide equivalent
native-generation or applied-command receipt fences. Bounded quantity metering
can use existing `CyberDemoBridge.inspect_cell`, which copies stored material,
stateA/stateB, body ID and completed tick. Inspect before and after in the same
exclusive-owner interval and reference actual native construction identity.

The exclusive worker accepts one effect once; main-thread equipment consumes
the matching receipt once. Keep tool aim distinct from locomotion. A blocked,
empty, unsupported-policy, exhausted, stale or failed-world pulse spends no new
effect budget. Release, focus loss, blocking UI, pause and reset cancel held
input and require release before rearming. Already committed payloads are a
different lifecycle; the chosen first implementation is U10, avoiding a new
capsule-flight integration.

Stop/reset retires pending requests. Fresh reconstruction retains only the
explicit chosen scenario/policy, resets the registered experiment inventory and
advances identities; an old queued activation cannot affect the new World.
Ordinary equipment-selection changes must not refill a live experiment budget.
No actual desktop/gamepad/focus or owner-feel qualification is inferred from the
native and synthetic tests in this package.

## Proposed command and native adapter additions

### Application envelope and receipt

The proposed fixture envelope is **not an implemented MicroScenario schema**.
It binds command ID, sequence, requested native generation, actor control
generation, equipment epoch, issued/expiry completed-tick boundaries, applied
policy digest, port/cell list, operation, material and requested quantity.
Only the existing owner fills source position, body identity and current masks.
Bound pending work; do not queue an unbounded held-input history or replay missed
boundaries as catch-up commands.

Apply at boundary k after k completed ticks and before k+1. Tick and mask cannot
advance between eligibility checks, mutation and copied after-observation.
The result includes accepted/refused/faulted outcome, actual native generation,
applied policy, native run/initial-construction receipt identity, accepted tick,
exact changed tuples/quantity, before/after authoritative identity, source/sink
budget before/after, port state and reason. A host-authored result is explicitly
host-authored; do not call its self-reported digest a native-issued receipt.

Preserve the original `lcb-feel-app-capture-v1` payload and add an outer
`in-tools-capture-v1` candidate envelope containing tool registration digest,
complete tool event ledger, actor/equipment identities and complete native
inventories. Existing MicroScenario Water capture covers scheduled edits only,
not arbitrary gameplay tools. #370's Water-centric IN completeness flag also
does not prove a complete Brine census. Require separate Brine coverage.
Leave `host_eligible_for_full_matched_evidence=false` unless its independently
owned missing source/runtime conditions are satisfied.

The [test-only validator](../../tools/lcb/in_tools_contract.py) checks copied
proposal consistency, stale/duplicate refusals, units, footprints, conservation
and explicit authority labels. It never authenticates native values or grants
gameplay acceptance. Unexpected execution faults fail the candidate; the
validator does not relabel them as successful/refused commands.

### Small checked-edit API if strong atomicity is required

**Planned and separately authorized.** Prefer a fixed value command/result,
`apply_liquid_tool_edit_v1`, on the exclusive owner, with at most 16 resident
cells and four explicit operations. Refuse `TickInProgress` or a missing owner
boundary; raw setters do not establish concurrent-call safety. Native validates material/policy, health,
coordinates, Empty/Wall/selected-liquid preconditions, masks, quantities and
ledger/capacity limits before publishing any write. Reserve all necessary
storage beforehand; no allocator in native pool work and no direct worker
mutation. Use copied native applied facts for the result. The adapter verifies
actual native session generation; application control/actor/equipment freshness
remains the existing host's responsibility.

This avoids changing the movement law while closing the gap left by void and
partially applied legacy writers. Implementation must prove all-or-none
semantics for normal refusals and explicitly retain failure/quarantine semantics.
Do not use rollback through painting: it loses hidden momentum, temperatures,
epochs, ledgers and activity.

### Small non-upward source-momentum API

**Planned and separately authorized.** A later `apply_inertial_source_v1` may
extend the checked-source result, not open arbitrary mutable slot access:

- Eligible Water 3/Brine 24 must actually use IN/reference at radius 3.
- One complete cell per accepted target; finite supply and at most 16 targets.
- Explicit direction: left, right, down, down-left or down-right. Up is refused.
- Proposed speed 0..32 q16 with `abs(vx)+vy <= 32`, `vy >= 0`, and ax=ay=0.
  For diagonal input, split the integer speed deterministically: horizontal
  magnitude=floor(speed/2), vertical=the remainder. This is a deliberately
  narrower input envelope than the existing per-component native bounds.
- Emit only into Empty/unmasked/resident targets; reject collision/out-of-domain,
  wrong generation, failed World, insufficient capacity and material/policy
  mismatch before write. Requested targets follow deterministic order.
- Debit actual liquid supply and record actual signed component input and L1
  input in native IN ledger units. These diagnostics are not a claim of
  physically conserved continuum momentum; keep liquid quantity separate.
- Atomically publish source tuple+motion+ledger. A sequence of paint followed
  by the diagnostic setter is not this contract.
- Persist resulting motion in existing CYPS3 fields; introduce explicit command
  version/identity and separately retain supply, pending commands and application
  replay state. Existing level saves/captures do not become complete replay.
- Prove 1/4-worker continuation, no-crossing, mask refusal and fresh-owner
  reconstruction on source-matched Windows/Linux. Workers consume the resulting
  native state at their ordinary deterministic phases.

No damping, gravity, transport, pressure or vertical-velocity-law change is
admitted. A speed bound is an input limit, not permission to retune the solver.

## Ownership, source guards and dependency-safe work breakdown

| Slice | Safe files / existing owner | Completion gate and boundary |
|---|---|---|
| Preparation (this package) | New docs, versioned plan, Python adversaries, standalone native test and runner | Source checks, actual bounded native qualification and independent review; draft only. No production files. |
| First implementation: metered U10 | Existing usable runtime/physical usable wrapper and narrow owner readback, coordinated with current actor/PLAY owner | Confirm accepted per-cell edits, Water/Brine units, existing charge/cooldown, stale/cancel/reset and normal FM unchanged. Can be built without world.cpp, adapter or Rapier changes if existing copied reads suffice; otherwise stop at the exact readback gap. |
| Reversible authored port | Existing owner command dispatch; one port definition and copied applied state; coordinate #370 Main/panel edits | Prove resident preflight and failure handling. No generic Wall-paint permission. Multi-cell atomicity/native receipt not demonstrated by serial GDScript. |
| Geometry source | Same bounded command/finite supply module, existing fresh-cell source primitive | Exact admitted dose, no overwrite/no new motion, blocked/exhausted and matching FM/IN evidence. Keep Brine event extension separate from schema 2 Water-only fill. |
| Strong edit receipt / velocity source | Native liquid owner #200/#212, #361 adapter integrator | Separate authorization for World/header/adapter changes and source-sensitive runtime rebuild/publication. #201 owns pressure; #347 owns mask/coupling; #362 owns impacts/upward law. |
| Final integration | #370 comparison owner, actor/PLAY owner and #361 integrator | Qualified union, no second host; Windows/Linux ordinary app and independent review, then owner playtest. No automatic merge or default promotion. |

Do not cherry-pick #358 to obtain a material catalogue. Future consumer admission
must supply authoritative valid IDs, per-material family eligibility, quantity
units and any bound-Water carrier readback. Require complete histograms and
carrier accounting on the **actual combined source**. Synthetic new-ID observer
tests from #370 are not a #358/#370 execution. #353-B owns consumer migration.

Any change to native/header/adapter compiled inputs invalidates their source
pins and applicable runtime provenance. Run existing capability/policy/normalizer
and receipt-vector checks; version changed semantic identities instead of
editing historical oracles. Rebuilding a library alone does not qualify loaded
runtime/module/script identity. Preserve fixed source maps and obtain actual
new platform evidence. No shared-source approval is granted by this design.

## Evaluation and implementation exit conditions

The [fixture and playtest runbook](../operations/in-tools-fixtures-and-playtest.md)
defines measurements and the test matrix. Water FM/IN comparisons use identical
actual geometry, initial quantity, seed, precision, radius 3, horizon and schedule;
the protected radius 2 Current control is separate. Brine's control is CY.
Record actual dose, complete stored quantity, sources/sinks and fixed wall
positions, not only visible pixels or accepted request counts.

Separate native tick cost, command work, owner step and main frame. Count configured
workers, phase jobs and observed task claimants; idle fixtures need not employ
four workers. For fully resident 1024²/2048² domains, IN's dense arrays cost 6 MiB/24 MiB;
allocation follows every resident chunk, including Empty chunks, excluding
base cells, per-job ledgers, allocator and host storage; a candidate plus old
World can temporarily double these owners. Use `inertial_storage_usage` for
actual native components and process RSS only as a separate measure.

Apparent bubbles are Empty-cell regions. Measure the historical column metric
and enclosed four-connected Empty components separately; neither establishes
IN gas pressure or buoyancy. Flow appearance, usefulness and preference need
source-bound human observation. All new graphical feel rows remain UNTESTED.
The entire #361 acceptance checklist remains open after this preparation PR.
