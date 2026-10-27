---
title: Structural detachment, toppling and reversible solid-body handoff
status: Approved design
document-kind: design
scope: Issue 12 owner priority and execution contract for native solid terrain becoming dynamic Rapier aggregates independently of global settled-region acceleration
canonical-for: [soliding-structural-detachment, soliding-tree-acceptance]
last-reviewed: 2026-10-27
related-documents: [soliding-programme.md, soliding-stage3b-production-plan.md, ../architecture/soliding-lifecycle.md, ../architecture/rigid-body-and-cellular-coupling.md, soliding-macro-fracture-fixture.md, ../audits/2026-10-27-issue12-stage3b-reassessment.md]
---

# Structural detachment and reversible solid-body handoff

## Approved owner intent — 2026-10-27

**Approved priority, implementation Planned.** The primary *near-term gameplay*
outcome of [issue #12](https://github.com/techrote/cybersand/issues/12) is:
**an existing solid structure made of real native terrain pixels can have its
support cut or removed, then fall, topple, roll and collide under real Rapier
physics.** A tree is the first visually inspectable example.
[SOL-DETACH-001 / #281](https://github.com/techrote/cybersand/issues/281)
tracks the first bounded end-to-end implementation and qualification.

A pre-authored rigid tree, an already-created sleeping Rapier body or scripted
rotation may be used as an *illustrative control*, but **cannot pass** the
native-cell-to-dynamic-body acceptance gate. The original material must actually
be World-authoritative native cells before the support-loss event, and one
explicitly verified transfer must occur. A disappearing tree replaced by a
visually similar prefab also fails.

September's long-term performance and macro-physics objectives both remain
first-class. The October instruction changes **priority and dependencies for
the first playable milestone**, not the conservation/failure or eventual
large-world optimization requirements.

| Track | Primary objective | Relationship |
|---|---|---|
| **A: dynamic structural detachment (first)** | Native cohesive solid → support-loss witness → real Rapier motion → eventually coherent fracture and safe demotion | **Does not automatically wait** for Stage 3B #66–#70, Stage 4 acceleration or global settled-region admission |
| **B: settled-region acceleration (parallel)** | Incremental read-only discovery → measured stationary skip/compact/proxy tiers → prompt native reactivation | Keeps #66 → #67 → #68 → #70, frozen #69 campaign and separate parent Stage-4 gates; no accidental granular cohesion |

Track A may reuse settled-discovery witnesses or typed local observations if
they are actually necessary and economical. A shared dependency must be proven
against current source, not inferred from the old serial stage ladder. Track
A success cannot qualify Track B's world-scale performance, nor may Track B
closure be assumed by demonstrating a moving tree.
[2026-10-27 Stage-3B reassessment](../audits/2026-10-27-issue12-stage3b-reassessment.md)
records the source and historical boundary.

## Representation terminology

- **Native/static terrain:** material/state/temperature held in authoritative
  native cells, whether currently awake or ordinarily sleeping. Its hard
  surface may have a *derived* static Rapier collider.
- **Structural cohesion:** a versioned, material/attachment-policy assertion,
  distinct from complete tuple equality, direct pixel adjacency, support,
  scheduler quietness or granular rest. A valid heterogeneous Wood/bark
  structure may be cohesive; loose Sand must not become a rigid block.
- **Detachment:** a source-bound event (cut, excavation, destruction, explosion,
  removed brace) eliminates a structure's last admitted anchor/support path,
  proven for a *bounded, closed* candidate. This does not imply full free space:
  the falling piece may subsequently collide with adjacent terrain.
- **Soliding / dynamic promotion:** native cells transfer their exact payload
  into an aggregate store with Rapier owning transform, inertia and contact.
  No stationary-compaction or global-quietness tier is a compulsory precursor.
- **Sleeping Rapier body:** still aggregate-owned and capable of waking; **not**
  desoliding to native cells.
- **Desoliding:** explicit, capacity-checked aggregate-to-native material
  transfer, including a valid destination, reaction/heat continuity and
  contact switch. A destination conflict may leave the aggregate asleep.
- **Resoliding:** future new promotion after an eligible restored component is
  independently admitted; no automatic weld-back on first rest.
- **Fracture:** exact material partition into coherent child bodies and only
  genuinely loose cells. Fragment momentum inheritance must be measured.

The native aggregate owns the **material payload** during motion; Rapier
owns body **motion/contact**. No per-cell Rapier objects. Material and
body/contact ownership are different concepts and must not be double-counted.

## Current source and nonclaims

**Inspected baseline:** `main`
[`c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59`](https://github.com/techrote/cybersand/commit/c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59),
not a run-qualified future candidate.

- `native/include/cybersand/world.hpp` `WorldConfig` disables
  `settled_discovery_enabled` and `settled_region_connectivity_enabled`
  by default; both service budgets default to zero. `World::advance_settled_regions`
  currently yields **observations**, never permission to erase cells,
  sleep an operator, create a dynamic body or transfer ownership.
- `native/include/cybersand/settled_regions.hpp` builds exact region
  observations by `material/state_a/state_b/temperature`. That equality
  is **not a structural cohesion law**, particularly for wood, bark, hot
  members and damage states. A `SettledRegionSnapshot` carries
  area/bounds/digests, not transfer-capable authoritative payload.
- `native/include/cybersand/soliding_lifecycle.hpp` is explicitly
  an isolated **contract model** disconnected from live World, Rapier,
  runtime queues and saves.
- `godot/native_extension/cyber_native_cell_world.cpp` and
  `godot/scripts/rapier_physics_bridge.gd` own copied transient-body masks,
  current static-hard-terrain colliders and live Rapier body/RID operations;
  their existence does not implement native static→dynamic conversion.
- `godot/scripts/simulation_worker.gd` is the **existing asynchronous
  desktop cellular owner**, with main-thread Rapier and copied rendezvous
  documented in `docs/architecture/simulation-tick-and-threading.md`.
  Reuse it, following [PLAY #263](https://github.com/techrote/cybersand/issues/263),
  rather than adding a separate Worker/clock/Rapier scene.
- PR #23/ADR-012 proves a **historical isolated** bounded rectangular
  near-rest transfer/reversal. It is not merged general native-tree
  promotion, collision handoff or fracture acceptance. Current material
  reactions, packed Stone behaviour, body/granular coupling and future
  GEN-006 persistence/residency remain separate authorities.

**All event-driven structural membership, generalized dynamic handoff,
real tree physics, fracture, aggregate continuation and safe desoliding
below are Planned, not Current implementation.**

## Source-triggered local detachment and eligibility

The first implementation must begin with an **actually applied native
material mutation**, not a precomputed animation trigger. A finite candidate
may be extracted at or after the authoritative tick boundary using:

1. An **explicit cohesive material and attachment policy**. Begin with a
   narrow homogeneous Wall/RedBrick reference if necessary. Later
   Wood/bark/branches may be mixed *only after* their attachment rule and
   reaction/temperature continuity are justified. Decorative leaves and
   ordinary Sand do not inherit rigid cohesion.
2. **Structural anchor evidence** independent of the exact per-cell tuple.
   A cut trunk can release the crown/trunk above it without releasing the
   ground plane; reaching the search limit or a possibly attached exterior
   makes the result **unknown**, not a detachable region.
3. **Closed boundary, source incarnation/revision, inclusion and current
   pending-event/body-mask witnesses**, not stale image or render dirtiness.
   A region observed only locally cannot masquerade as globally unsupported.
   An unknown boundary, cold/untracked tile, failed World or stale token
   must defer/refuse promotion with the original material intact.
4. **Explicit finite budgets** for traversal, members, shapes/contours,
   body slots, ack/result queues, scratch, collision changes and eventual
   return destinations. Deterministic, bounded service; no unbounded
   flood-fill or allocation inside an ordinary tick.
5. No change to current MAT/INT chemical rules, support policy, heat,
   granular wake or material ownership solely to make the tree fall.

[#68](https://github.com/techrote/cybersand/issues/68)'s future
ClosedLocal/unknown/global distinction is relevant, but the original
[#66](https://github.com/techrote/cybersand/issues/66) →
[#67](https://github.com/techrote/cybersand/issues/67) dependency belongs
to Track B. Track A can qualify its **smallest exact local witness** without
representing #68 complete or rewriting its issue evidence. If an actual
shared dependency is found, amend the issue/plan explicitly with source
and test evidence.

## Exclusive ownership and collision transition

The current live World and derived static-terrain Rapier collision
must not coexist as a second solid object after a dynamic transfer.
Transfer includes the exact native material and state payload, contact
topology, renderer visibility and the body/cell synchronization protocol.

| Phase | Required state and failure behaviour |
|---|---|
| **Candidate** | Native cells remain sole material owner and normal static collision remains. Observation never deletes pixels. |
| **Prepare** | On the exclusive native owner, reserve aggregate payload, source witness, collision-shape/body resources and bounded ack/result capacity. Reserve cancellation/failure path **before** work begins. |
| **Acknowledge** | Main thread prepares a Rapier body/shape in an **inactive or contact-safe staged** state. Workers never touch Godot/Rapier RIDs. Missing resource or stale ack returns refusal without retiring native cells. |
| **Commit** | Recheck source revision/material/support/mask/event. Switch sole material authority from native cells to native aggregate; stage an **exclusive** static-terrain-to-dynamic contact change across the same agreed epoch/fence. Neither simultaneous double support nor unsignalled contact absence is acceptable. |
| **Motion** | Rapier integrates gravity, inertia, torque, rotation, contacts and friction. Worker consumes only copied body state; frame-pacing lag does not grant mutable shared ownership. |
| **Fracture (later)** | Preflight and partition all exact members. Coherent children inherit relevant parent point velocities; refused split retains a valid parent and payload. |
| **Rest / demotion (later)** | A sleeping aggregate remains aggregate-owned. True desoliding validates transformed pixel destinations, occupancy, material semantics, reaction state and new static contact **before** retiring the old body. Refusal leaves a safe body, not missing cells. |

On a failed, cancelled, capacity-refused or stale prepare/ack, preserve
authoritative source and contact. A commit-time, render, event or lifecycle
failure must have an explicitly reviewed fail-stop/quarantine policy.
No double material ownership, double collision solving, stale body revival,
silent particle duplication or fake position teleportation. Preserve reset,
pause/re-entry, same-material reaction deadlines and eventual GEN-006
residency pins and versioned aggregate-save refusal.

Before implementation, independently audit whether the existing native
adapter can prepare a non-conflicting body and retire derived terrain
colliders with these fences. If not, implement the **smallest reviewed
handoff bridge**, not an unqualified ad hoc erase→spawn sequence.

## Implementation and fixture ladder

| Gate | Bounded deliverable | Evidence that closes it |
|---|---|---|
| **A0 — visual control** | Authored or sleeping Rapier tree for movement/feel | Visual reference **only**; explicitly not native detachment |
| **A1 — native transfer kernel** | Genuine cells in a small authored solid supported by a removable anchor; homogeneous 8×14 rectangle permitted | Native cut → exact fenced transfer → real Rapier gravity/contact/rotation, plus source-stale/capacity refusal; **not** full tree acceptance |
| **A2 — real tree (first feature)** | Rooted *native-cell* tree with a cuttable trunk, explicitly qualified cohesive policy, asymmetric crown and ground/obstacle | **Cut existing pixels → only unsupported tree piece falls, topples and rolls naturally**; ground and nearby tree remain; exact material inventory and one collision owner |
| **A3 — heterogeneous/irregular solid** | Bounded branch contours, shape approximation and approved mixed cohesive materials | No unsupported bond, shape tunnelling, invalid inertia, lost state or wrongful whole-ground promotion |
| **A4 — fracture** | Impact/damage partitions into at least two coherent moving children plus loose cell members | Inherited linear/angular motion, stable ID epochs, conservation and bounded resource refusal |
| **A5 — desoliding/repeat** | Safe rest/sleep policy, checked body→cells return, subsequent valid re-promotion | Multiple cycles without overlap, motionless-pixel cloud, new-body churn or dropped reactions |
| **B — acceleration** | Separate quiet-region skip/compact/proxy bake-off | Measured **net** cost reduction against ordinary sleep; not implied by the tree demo |

The tree fixture needs an **intact nonfalling control**, a partial cut
with surviving support, a severing cut, an alternate attachment and a
loose-Sand control. The falling geometry must generate real off-axis
torque/contact, not repeated direct `set_transform` writes. Record actual
centre-of-mass translation, angle/angular velocity, collision with ground,
subsequent rolling and time spent dynamic. No global terrain conversion.

## Failure matrix and platform qualification

Preregister source, recipe, material policy, cut/input schedule, exact
tree-cell payload ledger, actor/collision setup and expected outcomes.
Required cases include: source-mutation ABA, shape and queue saturation,
large/unknown/excluded continuation, cross-chunk seam and support anchor,
body mask overlap, hot/reactive branch, failing Godot/Rapier body creation,
stale result or reset, partial native tick failure, delayed main-thread
acks, insufficient fragment/return capacity, and interaction wake
without material loss or double contact.

For *implementation* run focused exact-owner native and actual
Windows/Linux Rapier/Godot host conformance with source-matched runtime
artifacts, worker 1/4 parity where applicable, ASan/UBSan/TSan as feasible,
body-motion numerical checks, real rendered review and independent
ownership review. Record source/runtime hashes, platform, thread mode,
capacity/refusal, latency, work/allocations/memory high-water and
uncontended ordinary-sleep baseline. CI green or a native-only registry
test is not owner visual/feel acceptance. Web/browser production release
is not claimed; current Web work remains separately scoped.

Track B's existing #69 6,488-record preregistration and #70
large-world acceptance remain historically frozen. Do **not**
overwrite past results or call them a tree proof.

## Noita evidence: what was actually established

The 2019 [GDC talk by Petri Purho](https://www.gdcvault.com/play/1025695/Exploring-the-Tech-and-Design/)
([recording](https://www.youtube.com/watch?v=prXuyMCgbTc);
[08:26 tree section](https://www.youtube.com/watch?v=prXuyMCgbTc&t=506s))
demonstrates coherent tree rotation. A prior frame-accurate review marked
approximately **08:26.333** first clear rotation; approximately
**08:55.667** is a **demo reset**, *not* evidence of welded
body-to-terrain restoration. Rigid body and coupling sections are
approximately **05:42–07:18** and **07:18–09:19**.

The [April 2019 interview with Petri Purho](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation/)
explicitly describes selecting candidate static/collapsing material,
**carving shapes and creating falling rigid bodies**; pixels retain
body-local membership and damage can rebuild/split the body. Thus
selective material→body creation is supported by the developer account,
**not established by the isolated tree footage itself**. Neither source
establishes automatic re-anchoring, exact CyberSand payload accounting,
Rapier API semantics or safe collision handoff. Noita is inspiration,
not copied implementation authority.

## Ownership, non-goals and handoff

[#12](https://github.com/techrote/cybersand/issues/12) stays parent;
[#281](https://github.com/techrote/cybersand/issues/281) owns the first
Track-A slice. #66–#70 stay open separately; #69's protocol remains
unchanged. Do not create a duplicate desktop gameplay worker, general
structural-integrity simulation, infinite global flood fill, universal
compound mesh, per-cell Rapier bodies, default liquid solver change or
Water-sheet dependency. Do not self-admit full fracture or stationary
acceleration based on the first tree.

Read `AGENTS.md`, live PR ownership, current source and relevant
material/physics/GEN-006 contracts before implementation. This page
documents **Approved intent and Planned mechanisms**, not executed code,
performance acceptance or user-feel approval.
