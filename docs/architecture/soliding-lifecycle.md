---
title: Scalable soliding representation lifecycle
status: Approved design
document-kind: contract
scope: Issue12 successor state machine, eligibility boundaries and bounded identity/ownership invariants; executable model is separate from production runtime
canonical-for: [soliding-representation-lifecycle, soliding-eligibility-tiers]
last-reviewed: 2026-09-19
related-documents: [data-ownership-and-lifetimes.md, rigid-body-and-cellular-coupling.md, ../reference/level-saves-and-replay.md, ../systems/granular-interaction-policy.md]
---

# Scalable soliding representation lifecycle

## What is implemented, and what is the approved direction?

**Approved requirement:** [issue #12](https://github.com/techrote/cybersand/issues/12)
requires both cheaper representation of quiescent regions and useful coherent-body
macro dynamics followed by fracture into coherent children and local loose material.
These purposes are co-equal. The historical [PR #23](https://github.com/techrote/cybersand/pull/23)
and its ADR-012 are a one-slot Phase 0 proof, not production soliding or completion
of this programme. They remain on their original source identity.

**Current runtime:** World owns cellular material. Ordinary scheduler sleep,
immutable copied snapshots, main-thread Rapier ownership, failed-world quarantine
and interest-region pause/re-entry keep their existing contracts. Main has no
production aggregate registry or representation handoff from this document.
The Current ownership and collision contracts remain
[ownership](data-ownership-and-lifetimes.md) and
[coupling](rigid-body-and-cellular-coupling.md).

**Current standalone contract model:**
[`soliding_lifecycle.hpp`](../../native/include/cybersand/soliding_lifecycle.hpp)
implements bounded slot identities, synthetic exact payload accounting, staged
ownership transfers, refusal/cancel/quarantine and observation witnesses. It has
no dependency on World, Godot, Rapier, adapters, runtime queues or save code.
[`test_soliding_lifecycle.cpp`](../../native/tests/test_soliding_lifecycle.cpp)
exercises that model. Passing these tests does not implement any runtime tier,
prove thread safety, choose a stationary representation, or establish conservation
of physical energy. Model arrays are copied synthetic membership records, not a
second canonical copy of live World cells.

**Planned runtime:** each state, reservation, material admission and fence below
must be connected to its actual native/main-thread owner and revalidated before
promotion becomes possible. Discovery may first produce read-only summaries with
cells retaining sole authority; it must not treat this model as runtime admission.

## Which representation owns the material?

**Approved production contract, exercised by the standalone model:** a region has
one representation and one sole material owner. A summary, collision shape,
occupancy mask or render snapshot never owns material. The representative payload
contains membership, material ID, admitted material-specific state and temperature;
no generic velocity is added to cells. Epochs/activity metadata are reconstructed
under their own scheduler contract and are not preserved as fictitious replay state.

| Stable representation | Sole material owner | Boundary and contact meaning | Runtime status |
|---|---|---|---|
| Active cells | Native cells | Current cellular neighborhood and derived terrain/contact | Current |
| Ordinary sleeping cells | Native cells | Current wake rules; sleep alone proves no soliding eligibility | Current |
| Tracked settled summary | Native cells | Derived stability/connectivity observations; ordinary boundaries remain authoritative | Planned, model only |
| Stationary cells with skip/proxy metadata | Native cells | Must preserve active neighboring rules and one hard-contact owner | Planned alternative, model only |
| Stationary compact payload | Native region store | Exact reversible payload and admitted boundary interface; cannot silently read Empty interior as terrain truth | Planned alternative, model only |
| Dynamic coherent aggregate | Native aggregate store | Rapier alone owns transform/contact/motion; cellular mask is descriptive occupancy | Planned, model only |

The two stationary alternatives are candidates for a later measured bake-off,
not a selection of both for production. Model transitions between them test owner
accounting without asserting either reduces work. No per-tick erase/rasterize/
restore scheme is admitted for moving bodies. Coherent aggregate material remains
in native storage while Rapier moves it continuously.

| Transition phase | Material owner | Step/publication policy |
|---|---|---|
| Stable | Owner in the representation table | Normal behavior only after the tier's real admission |
| Prepared | Old owner | Both affected solvers fenced; disabled replacement owns nothing |
| Acknowledged | Old owner | Same fence, exact proposal/resources acknowledged |
| Committed, topology pending | Target owner | One logical transfer under exclusive ownership; no steps or ordinary publication |
| Finalized | Target owner | Resume only after complete topology/occupancy and publication verification |
| Quarantine | Last committed owner, or old owner if no commit occurred | Fence retained, diagnostic census only; no inferred rollback or retry |

The fence applies to the affected native work and relevant Rapier space/bodies.
Its production desktop rendezvous is Planned; stopping a local model call does
not stop an asynchronous World or a live physics server.

## How are summary, stationary and dynamic eligibility separated?

**Approved:** external material/state policy supplies semantic admission; this
contract does not create a new material or intermaterial rules engine. Ordinary
sleep is one scheduling observation, never an automatic cohesion or rest proof.

| Tier | Required evidence | Evidence that is insufficient |
|---|---|---|
| Summary | Healthy included observations; current payload/state/temperature and mutation revisions; activity, events, support/topology and transient occupancy accounted for | Sleep flag, old render cleanliness, elapsed excluded time |
| Stationary acceleration | Summary plus preserved neighbor/boundary behavior, prompt bounded invalidation, admitted contact owner and measured worthwhile cost | A collider exists, interior is visually static, low material count |
| Dynamic cohesive | Stationary obligations plus explicit cohesive material/state policy, admitted geometry, mass/inertia/units, motion source and safe transition resources | Sand/Stone packing, long rest, support, bracing alone, or stationary eligibility |

**Current model:** `Eligibility` contains separately supplied witnesses, with
`summary()`, `stationary()` and `dynamic()` predicates. Dynamic requires an
explicit cohesive policy and intrinsic-cohesive category; loose granular,
stateful granular, reactive and mixed categories refuse even if every other
witness is true. The model does not map material IDs to categories or implement
the upstream policy. Tests of these categories are not a claim that a production
Wall, Stone variant or any other material has been newly authorized.

**Planned:** real admission obtains versioned facts from existing material policy.
Large Sand beds may eventually qualify for summary/stationary acceleration while
remaining dynamically noncohesive. Stone state/bracing is governed by its own
material policy, not inferred structural rigidity. Heat, reactions, unsupported
states and mixed boundaries conservatively refuse unless explicitly supported.
The [granular policy](../systems/granular-interaction-policy.md) remains its owner;
#26 material programs and #29 intermaterial semantics are not redefined here.

**Planned hysteresis:** derive quiet-duration, area and churn entry thresholds
from Current ordinary-sleep control and later break-even measurements. Require
consecutive healthy included observations with complete witnesses. Invalidation
is prompt even when discovery/promotion is deferred. A minimum useful residence
or cooldown may decline churn-heavy promotion, but cannot delay a correctness
wake. Phase 0's 300 observations is historical scope, not a selected universal
threshold. Model quiet counters saturate; elapsed wall time never earns rest.

## What invalidates a region, and what happens on exclusion?

**Approved:** edit, reaction, heat, body contact/occupancy, support loss, topology,
activity, pending event, observation gap and exclusion invalidate the relevant
membership/boundary witness. Dirty-render consumption is not a mutation witness:
change-and-restore must invalidate stale work even when tuple bytes return to the
same values. Invalidation must also reach required boundary/halo dependents.

For cells-owned summaries, invalidation drops derived eligibility and restores
ordinary activity. Retain unaffected regions only where their local witnesses
remain valid. A stored or moving payload cannot be dissolved simply because it
received an invalidation: defer/reject the event under an explicit contract or
perform an admitted partition/reactivation transaction. Events are neither
silently dropped nor applied to a duplicate hidden cell representation.

**Current model:** `invalidate()` advances a nonwrapping revision, cancels
precommit work and zeros quiet observations. Cells-owned tiers return to active
cells. Stored payload remains with its previous owner, unchanged. This synthetic
invalidation does not apply a real edit/heat/contact to material or update shapes.
A stable model snapshot after it is diagnostic copied state only: `publishable()`
cannot authorize a live collider/render packet after real topology changed.
Postcommit invalidation quarantines instead of inventing a rollback.

**Approved exclusion/re-entry:** serialize exclusion through the owner; cancel
precommit work or finish the existing fence before resuming anything. Preserve
aggregate payload and copied/direct-server motion while paused. Excluded time
cannot accumulate rest; re-entry validates occupancy, residency, dependencies and
fresh observations before admission. No catch-up work or inherited quiet age.
**Current model:** repeated exclusion has zero quiet observations and re-entry
resets the window; it does not implement regional Rapier pausing or streaming.

## What are the identity and bounded transaction rules?

**Approved:** handles include world/session incarnation, slot index and generation.
Replace/reset cannot revive an old handle. Slot generations, transition serials
and mutation revisions refuse at exhaustion rather than wrap. Payload hashes may
be integrity witnesses but cannot substitute for identity or exact membership.

**Current model:** fixed arrays allocate the lowest available slot, increment its
generation, and reject duplicate membership IDs. `Token` binds the complete handle,
transition sequence, mutation revision and target representation. Rejected stale
or duplicated operations cannot advance the phase. Retired handles remain stale
when their slot is reused; exhausted slots are unavailable. The constructor
requires a caller-supplied nonzero incarnation; uniqueness across registry instances
is a caller obligation, not a model-provided process/durable ID allocator. Registry copy and move are
disabled so a copied registry cannot clone live identities or pending owners.

**Approved future arbitration order; runtime queues remain Planned:** after
native job barriers, consume proposals in ascending lexicographic order of
`(causal_tick, incarnation, slot, generation, policy_version, target_kind, request_sequence)`.
Use the complete region handle fields; target kinds are versioned fixed IDs in
the representation-table order (0 through 5). The serialized native owner assigns
request sequences after stable source-event ordering, never worker completion
order. Policy-version changes require fresh admission. This tuple also determines
which request receives scarce shared capacity; completion timing cannot decide it.
Requests/ACK/results and membership/payload/shape/body/destination resources must
all be reserved before prepare. Finite overflow refuses or defers the complete
request, retains the old representation and reports counters. No partial candidate
publication, truncation or unbounded retry/flood-fill is permitted. Required
cancellation/result capacity cannot depend on a later best-effort queue insertion.

**Current model:** compile-time bounds limit slots, members and outstanding
transition reservations. `Preflight` requires every reservation and health/fence/
inclusion/topology/event guard. These booleans represent assertions supplied by a
future runtime owner; they do not allocate real queues or collision resources.
`create()` does bounded duplicate-membership checks, suitable for a small contract
model, not a proposed scalable discovery/registry lookup algorithm. `untrack()`
only retires stable cells-owned metadata; cells remain the owner outside tracking.
It refuses stored payload and pending transactions.

## How does prepare / acknowledge / commit / finalize fail safely?

**Approved; logical owner switches exercised by the model:**

1. Prepare exact membership/destination witnesses and reserve all resources while
   the old material and collision representation stay valid. Require an exclusive
   no-step fence. Preparation and acknowledgement cannot transfer authority.
2. Main thread builds disabled replacement shapes/bodies and acknowledges the exact
   immutable token. Workers access copied values only, never Godot/Rapier objects.
3. Exclusive native owner rechecks token, revisions, health, inclusion, complete
   payload, empty/admitted destinations and reservations before commit. A bounded
   no-fail transfer changes the sole material owner once. Logical atomicity under
   the fence is required; simultaneous multiword hardware atomicity is not claimed.
4. Only confirmed commit allows retiring old collision and activating replacement
   collision/occupancy. Finalization verifies the target contact representation,
   retirement of obsolete contact, complete occupancy and immutable publication.
   Health, inclusion/halo and absence of pending events are checked again; failed
   postcommit checks quarantine rather than publish the new representation.
   No simulation step may observe a collision hole or duplicate stale contact.
5. Construction/ACK/commit refusal and explicit precommit cancellation dispose only
   unowned disabled resources, preserving the old owner and exact payload. Stale
   tokens cannot cancel a newer transaction. Cancel after commit is forbidden.
6. An unexpected postcommit failure quarantines the last committed owner with its
   fence and reservations retained. Failure is neither rollback nor retry. Recovery
   requires a separately validated replacement/reset policy, preserving diagnostic
   accounting and prior immutable snapshots.

**Current model:** all exact payload tuples stay byte/value-identical through
transitions; it changes only the logical ownership label. `Topology` guards stand
for a future verified collision census; they do not inspect Rapier. The tests prove
this pure model's state transitions and conservation ledger only. Real partial
writes, async cancellation and topology/rendezvous races require Stage 6 tests.

## How must split, merge and fracture preserve identity and motion?

**Planned Stage 6/7 implementation; Approved invariants now:** partition the exact
parent membership, then classify each child separately. Every original member
appears once in a child aggregate, a stationary child or admitted cellular output,
except explicitly accounted reaction/source/sink changes. Capacity refusal keeps
the parent representation intact; one damaged corner must not automatically emit
the entire slab as loose pixels.

Reserve new child/merged handles before retiring parents. A split retires its
parent handle and publishes fresh generation-bearing child handles; a merge
retires every parent and publishes one fresh handle. No child silently inherits
the parent's identity. Retain bounded provenance edges from retired parents to
children and the causing revision/event; exhaustion defers the transaction.
Prepared children own nothing until one atomic fenced ownership commit. Do not
recycle a parent slot early to pretend that destination capacity existed. The
single-region model does not implement split/merge transactions; these rules
remain required inputs to their later dedicated tests and capacity preflight.

Rapier supplies an immutable sampled parent COM `c`, velocity `v` and angular
velocity `omega` at the transition fence. In consistent 2D axes/units, child COM
`c_i` inherits `v_i = v + omega * (-(c_i.y-c.y), c_i.x-c.x)` and, where admitted,
`omega_i = omega`. Recompute child mass, COM and inertia from exact membership and
shape. Account for fracture impulses and their source; test total linear/angular
momentum and kinetic-energy error in a declared common frame. Geometry/contact
approximation errors must be measured and bounded, not silently reset to rest.

Near-rest promotion may use zero/known initial velocity because cellular storage
has no general historical momentum. A moving parent cannot return to stationary
cells merely by discarding its motion: require an admitted near-rest screen or
explicit motion/error policy. The model uses `safe_motion_return` for that external
proof, without calculating mechanics. Child collision separation must avoid
pathological overlap. Only genuinely loose output becomes ordinary cells; its
lost/carried motion is explicitly measured. Coherent fracture is not conditional
on #20's possible sparse high-speed carrier. Full motion and fracture fixtures,
including off-centre force/impact and two-/three-child splits, remain Planned.

## What may snapshots and persistence claim?

**Approved:** publish immutable copied representation identity, membership/render
truth and admitted sampled transform. Consumers cannot borrow mutable cells or
infer payload ownership from pixels drawn. Existing successful leases remain
valid during transitions/quarantine; retire old topology/publication only after
complete acknowledged consumption where required. Current desktop asynchronous
and Web synchronous outer ownership remain distinct platform contracts.

**Current model:** `snapshot()` returns a value copy. Ordinary publication is
suppressed in every nonstable phase; diagnostic copies remain available for owner
census. This is not a runtime render exchange or lease implementation.

**Current runtime:** [CYSD1](../reference/level-saves-and-replay.md) restores cellular
levels, not complete motion/replay state. **Approved/Planned:** unsupported stored
payload, pending transitions, exclusion and quarantine must explicitly refuse or
safely drain before a cellular-only save; never omit aggregate-owned material.
The model's `cell_save_admissible()` is a logical ownership boundary query and
performs no export. Future schema must version representation policy, identities,
sole payload and required motion/state, validate loads before replacement, and
record source/config/profile provenance. Struct-byte dumps and implied exact
replay are rejected. Stage 8 owns production persistence implementation.
