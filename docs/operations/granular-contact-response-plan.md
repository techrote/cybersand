---
title: Combined granular resistance, friction and torque plan
status: Planned
document-kind: runbook
scope: GCR-001 generic rigid-body contact with the granular material category; proposed implementation and qualification, with sleep deferred
canonical-for: [granular-contact-response-plan]
last-reviewed: 2026-11-01
related-documents: [y1-granular-bearing-qualification.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/granular-interaction-policy.md, ../systems/player-control-playground.md, ../reference/product-intent-and-priorities.md, development-claims-remediation-programme.md]
---

# Combined granular resistance, friction and torque plan

## What is authorized, and what remains a proposal?

**Approved owner direction, 2026-11-01:** improve foundational pixel-engine
contact between generic Rapier bodies and **all sandlike/powder/granular solid
materials**. The owner's plural “sands” denotes that category, not special
treatment for yellow `Sand`. Preserve the satisfying actor/player playground
momentum, friction and rocket-barrel control while addressing easy horizontal
penetration. Develop resistance, friction and their turning effects together.

**Planned GCR-001:** one bounded, experimental granular contact response under
REM-004/#83, developed as a coherent mechanism and qualified through isolated
ablations. This document is a concrete development/qualification plan, not an
implemented law, selected coefficients or a passing production envelope.
Ordinary B0 and experimental Y1 remain unchanged at this planning checkpoint.

**Deferred beyond this phase:** sleep admission/wake changes, persistent rest or
support caches, freezing, body-to-cells conversion and soliding/desoliding.
There is no sleep work package or sleep-based acceptance shortcut here. Late
motion is observed for regressions; zero motion is not manufactured to pass.

No wider ejection search, compaction, push chains, A2 combination, material-law
retuning, new per-cell physics objects, backend replacement or general cell
velocity field is included. Coherent-aggregate lifecycle/fracture stays with
#12/#281. General contours and exact circular native occupancy remain separate.
First geometry is real rotated rectangles, including independently coupled
rectangular actor parts; existing circle-as-rectangle occupancy is an explicit
compatibility limitation, not silently promoted to an exact contact shape.

## Which evidence constrains the design?

| Retained evidence | Consequence for GCR-001 |
|---|---|
| [#9 parameter results](../audits/2026-09-09-physics-characterisation.md#controlled-parameter-results): friction0.4/0.78/1 left historical Sand trajectories unchanged; damping supplied no static support | Add a contact mechanism, not a global damping or collider-friction workaround. Historical results remain source-specific. |
| [#10 policy](../systems/granular-interaction-policy.md), historical #11 and [REM-002 reconciliation](../audits/2026-09-24-rem002-issue11-integration-forensics.md) | Stored cells are material authority; reuse material/state admission and support-loss controls. The old #11 repair was never integrated; its adapted successor is on main through PR #128, not a missing patch to import again. |
| [PR #23 reuse audit](../audits/2026-09-19-issue-12-phase0-reuse.md#material-findings-before-reuse) | Exact fenced payload transfer is useful evidence; externally imposed quarter-turns with free rotation disabled do not qualify contact torque. No independent barrel-to-terrain handoff follows. |
| [Frozen #283 source](https://github.com/techrote/cybersand/blob/254235ec4c3d58782bba44b478caca86bf57c856/godot/scripts/solid_detachment_session.gd#L696-L715), [#282](https://github.com/techrote/cybersand/pull/282), [#281](https://github.com/techrote/cybersand/issues/281) | Six proxy-centred impulses already exercise coarse aggregate torque under a shared budget. Reuse the single-owner/budget lessons, not the branch or a claim of calibrated contact-point torque. Its rotating fixtures do not isolate cellular torque from hard contact. |
| #283 wider-search NO-GO, [#336](https://github.com/techrote/cybersand/pull/336)/[#338](https://github.com/techrote/cybersand/pull/338) topology/displacement results | Nearby visible void is not a legal relocation route. Retain bounded ejection and its exact refusal outcomes; resistance must act upstream of deep overlap. |
| [#339](https://github.com/techrote/cybersand/pull/339), [#341](https://github.com/techrote/cybersand/pull/341), [#342](https://github.com/techrote/cybersand/pull/342), [Y1 envelope and owner comparison](y1-granular-bearing-qualification.md) | Y1 is the preferred impact reference. Preserve its embedding improvement; do not optimize only the canonical8×14 mass1 fixture or relabel retained clearance/async/performance failures. |
| [Generic-body owner clarification](https://github.com/techrote/cybersand/issues/83#issuecomment-5749978861) | No barrel-specific contact rule. One generic coupling owner, real current-source owner review, honest unsupported envelope. |

The archived #282/#283/#23 heads remain read-only. Render-copy/ACK successes in
those archives do not qualify physical displacement, torque or rest.

## What source and ownership must be reconciled first?

Planning checkout: `C:/Users/_/.codex/worktrees/y1-production-envelope/khybersand`,
branch `codex/y1-production-envelope-20261101`, pre-plan head
`a6f17723ddd9be2ab7cf849fdef4a3017738fd0c`, tree
`0e3b63d5dd4531010b5f5ccad299c318155a3be2`.
The unrelated dirty `C:/khybersand` material work remains untouched.

Freshly fetched main is now `809fd30dfac0c5e127302997075be9c4b279e5aa`, tree
`863db60c767bf00a215b9e4064d6bccb71eb69ab`: PR #344 merged after the Y1 base
`25ce0731d89b9540c2d95cfa8bae321c37e6e118`. Its production change is chunk-run
render copying, with Main/worker observation seams and new source-matched
runtimes. It does not implement granular friction/torque. **Old Y1 runtime
receipts do not qualify a future #344+GCR source composition.**

At implementation intake, fetch main again and record SHA/tree, actual delta,
dependency pins, LFS/runtime identity and live write sets. Construct an isolated
current-main worktree; reconstruct only the minimal experimental Y1 reference
and admitted apparatus needed for the new comparison. Do not wholesale stack
the investigation branches or overwrite #344's render/provenance changes.
Keep #343 as the unmerged qualification/evidence draft; determine the focused
implementation PR disposition under the same #83 owner before source edits.

The current material capability covers Sand, Stone, Dust, Seed, Salt, Sodium,
Gunpowder, Coal and Rust. The implementation consumes that policy/category,
never a `material == Sand` special case. State behavior remains authoritative:
Stone bracing versus granular state, Seed→Plant, reactive grains and mixed
interfaces need explicit coverage. A descriptor/capability mismatch is an intake
finding to reconcile, not permission to silently classify new material IDs.

Native cells retain material authority. Native workers publish bounded values;
only the main-thread bridge applies body impulses/torques. The material policy
owner remains [granular policy](../systems/granular-interaction-policy.md);
non-kinetic reactions remain #29/INT-000 authority. There is no blanket #12
Stage-3B dependency, nor permission to duplicate its aggregate owner.

## How will sideways granular resistance, friction and contact torque work together?

**Candidate design, to be frozen at Gate0 before result acquisition:**

### Contact geometry and material admission

1. **Current material and actual geometry define contacts.** Reuse the bounded
   body-boundary traversal. Admit packed contacts through stored material and
   the existing stable downward8/9 or side9/9 policy, with moving-grain impacts
   a separately attributed event channel. Hard terrain is excluded from new
   granular response and stays Rapier-owned. One-cell films and loose grains
   must not become rigid support. Side resistance is a primary mechanism,
   rather than friction added to a downward-only bearing law.
2. **Keep positions and normals until response is computed.** For rectangles,
   use actual geometric face normals/contact projections, not display-outline
   pixels or the stair-step raster edge as a succession of hard corners.
   Freeze corner tie-breaking and the mapping from a qualified stored cell to
   a geometric face. Use at most8 contact bins/body: two spatial bins per face.
   Retain their counts, material/state, support weights and moments. Compare
   reduction against an unreduced test-only oracle; do not silently drop excess
   samples or assign every force to a proxy centre.
### Coupled normal resistance, friction and contact torque

3. **Use contact-point velocity and real inertia.** For body COM `c`, contact
   offset `r`, velocity `v`, angular velocity `omega`, normal `n` and tangent `t`:

   ```text
   u_contact = v + omega × r - u_material
   effective_inverse_mass(d) = inverse_mass + (r × d)^2 * inverse_inertia
   J_contact = J_normal * n + J_tangent * t
   J_body = sum(J_contact)
   L_body = sum(r × J_contact)
   ```

   Mass, inertia and COM come from the actual Rapier part, including authored
   flight inertia; they are not inferred from a drawing AABB. Stable admitted
   packed grains initially use a stationary-bed reference. That is an explicit
   approximation, not a new native grain velocity field. Moving-grain events
   retain source position/direction and separate accounting; their current
   density-weighted feedback is not physical parcel momentum conservation.
4. **Normal resistance yields within one body budget.** Start from Y1's full
   velocity-braking reference. Preserve its2-units-per-supported-sample and20
   body-per-tick normal-capacity scale as the initial reference, shared across
   all faces rather than renewed per point or per proxy. Resolve closing
   normal speed using effective mass; separating contacts get no attractive
   normal impulse. Gravity is already integrated by Rapier: do not add another
   gravity arrest term at every contact. Freeze the exact mapping of Y1's
   arrest/yield/cap terms into this distribution before comparison runs.
   At coefficient1.0 the current vertical Y1 expression simplifies to
   `min(mass * max(v_y,0), capacity)`; prove that equivalence in the reference
   tests. Admit each stored-cell contact once with deterministic face ties;
   unresolved interior overlap is not a second external support contact.
5. **Friction and moment are part of that same solve.** Oppose tangential slip,
   including angular motion, with `abs(J_tangent) <= mu * J_normal` per contact.
   Start with the unchanged body's existing friction value as an explicitly
   experimental common category coefficient; material multiplier1.0, no
   density-to-friction mapping or per-powder tuning. This is not selection of
   final granular coefficients. A bounded four-pass normal/tangent evaluator
   updates provisional linear/angular velocity together. No extra Rapier step,
   free-air drag or independent “make it topple” impulse is added. The zero-mu
   ablation retains normal-contact torque; a flat sliding body need not topple
   where its contact distribution balances the turning effect.
### One granular response owner and shared impulse budget

6. **One contribution per physical mechanism.** Inventory current granular
   boundary-pressure, displacement, kernel-contact and bearing contributions.
   In the GCR arm, route/replace their overlapping normal reaction through one
   ledger; do not retain legacy granular pressure then add full new resistance
   on top. Preserve ejection quantities and refusal semantics. Non-granular
   feedback keeps its existing path. Carry contact moments before aggregation,
   including grains striking a body off-centre; net x/y alone cannot recover
   their angular impulse. World contact accumulators currently have no moment
   channel, so this needs deliberate native value-data work, not a bridge-only
   `body_apply_torque_impulse` patch.
   Retain the reference's bounded low-speed downward position-correction policy
   and account for it separately; add no horizontal teleport, angular pose
   correction or fixed embedding-depth clamp to manufacture resistance.
7. **Limit the complete response coherently.** Record raw, accepted and rejected
   normal/tangent/linear/angular contributions. With normal budget `B` and
   coefficient `mu`, total impulse magnitude is bounded by
   `B*sqrt(1+mu^2)` and moment by that value times maximum contact radius; this
   explicitly permits a derived tangential budget, not an undisclosed duplicate
   normal cap. Any additional safety scaling applies consistently to normal,
   friction and moment. For stationary passive contacts, independently check
   body kinetic-energy change; reject energy injection beyond registered
   numeric tolerance. Moving-cell input, gravity, controller thrust, correction
   and hard contact have separate ledgers; no total-system energy claim follows.

The normal/tangential/lever-arm mechanics follow the ordinary principles in
[Rapier impulses](https://rapier.rs/docs/user_guides/rust/rigid_bodies/#forces-and-impulses)
and [friction](https://rapier.rs/docs/user_guides/rust/colliders/#friction).
Their current online guide is newer than the repository pin; verify concrete
APIs against Godot4.7, godot-rapier addonv0.35.2 and rapier2d crate0.35.1 with
the retained cooperative BVH patch. The
[runtime manifest](../../godot/addons/godot-rapier2d/runtime-provenance.windows.json)
owns those exact inputs. These links
do not validate CyberSand's discrete contact approximation.

## What changes at the value-data boundary?

Gate1 must specify a versioned opt-in input/result protocol. The existing11/9
record remains the B0/Y1 reference ABI. Do not reinterpret old offsets, borrow a
diagnostic count for torque, or apply both old and new response to one sample.
New values include actual COM/inverse inertia, dt, body/session/sample identity,
policy version and a linear impulse plus angular impulse about an explicit
reference COM. Construction rejects incompatible native/fallback consumers
before replacing an existing World. Fallback may explicitly refuse GCR; it must
not silently run central-only response under a GCR label.

GCR must be selectable only through a fresh development/test construction and
an explicit experiment token; the exact option/ABI names are frozen at Gate1.
No ordinary user path or persisted setting activates it. One normal capacity
budget belongs to one body/physical step; worker passes, proxies and duplicate
delivery cannot mint more capacity. Different native/main cadence is measured,
not repaired by an unregistered catch-up impulse for unobserved steps.

Define one main-thread application of the accepted `(J_body,L_body)` and one
body sample per intended boundary. For delayed values, record sampled/current
COM and pose, age, acceptance and application. Transporting a world-space
wrench to a new reference COM requires its corresponding moment translation;
torque cannot be independently rotated/scaled without the impulse geometry.
The existing age8 ceiling and correction-age1 rule are ceilings, not proof that
new contact moments are safe. Freeze a geometry-validity/age rule at Gate1,
then test real delivery delays; stale or duplicate refusal must be atomic for
the new contact response. Do not extend age limits to conceal weak support.

Use fixed-capacity per-body/bin data and deterministic reduction. Extend the
existing contact accumulation under its native job barriers; no per-cell locks,
floating atomic-order dependence, live backend calls or hot-path allocation.
Document integer/float precision, accumulator overflow refusal and memory cost.
At64 bodies,8 bins and4 passes, the new evaluator is at most4096 scalar
normal/tangent updates per accepted boundary. Existing raster/sample bounds
still apply; any unsupported geometry/capacity refuses explicitly.

## What are the implementation checkpoints and exit gates?

| Gate | Concrete deliverable | Required exit before continuing |
|---|---|---|
| 0 — reconcile and register | Current-main/source/runtime manifest; all-nine material/state admission table; exact scenario IDs/parameters; reference B0/Y1 captures; coefficient, normal/cap mapping, tolerances and limits committed before GCR results | Reproduce selected current-source Y1 impact and playground controls; explain source drift; no stale runtime premise. |
| 1 — contact data and protocol | Bounded face/bin producer, independent reference geometry/moment oracle, versioned input/result/refusal contract, component/double-count ledger | Mirrored and analytic geometry tests pass; old B0/Y1 and hard/Water behavior unchanged; API/units/age policy frozen. No gameplay law comparison yet. |
| 2 — combined response | Pure native normal+tangent+moment evaluator and one main-thread application, with `mu=0` and central-application diagnostic ablations | Analytic impulse/energy/torque tests, finite budgets, deterministic reduction and all-negative controls pass. Do not tune torque independently of its impulse. |
| 3 — category and envelope | Registered synchronous matrix, real asynchronous arms, support-change/state-change controls, bounded work/timing repeats | Generalized resistance/torque/friction evidence with exact failures and unsupported envelope; no isolated yellow-Sand success accepted as category qualification. |
| 4 — preserve playground feel | Actual same-source rocket barrel and representative articulated rigs, unchanged controllers, source-bound playable comparison | Hard/air controls equivalent, granular resistance improves without unacceptable sticking/loss of yielding; actual owner gameplay preference recorded. |
| 5 — review and handoff | Independent technical review; exact-head relevant native/sanitizer/host/REM/replay/docs gates; fresh Windows/Linux runtimes whenever production native inputs change | Honest scoped disposition and current-source review package. Draft and unmerged; explicit owner acceptance/default decision and later explicit merge authorization remain separate. |

Gate0 and Gate1 are necessary specification work, not discretionary permission
prompts. Complete their reviewable artifacts before result acquisition. If a
needed law/age/geometry choice cannot meet them, record the conflict and amend
the registration before proceeding; do not select it after looking at outcomes.

## What is the bounded physical matrix?

Primary comparison is **Y1 versus full GCR**. Keep B0 as a historical/control
arm on six representative cases, not a second complete Cartesian campaign.
Use fresh Worlds/spaces, fixed1/60 stepping, synchronous one-worker baseline,
1800 samples/case, identical replay inputs and frozen protocol identities.

| Stratum | Population and purpose |
|---|---|
| M1 category coverage —36 pairs | Each of all9 capable powders: moderate vertical entry, horizontal bank entry, glancing impact, supported slide/push. Same geometry/mass/commands and common response settings. This is minimum category coverage, not nine independent tuning projects. |
| M2 load/geometry —12 pairs | Moderate-entry mass0.5/2 on Sand/Dust/Rust (6); half/double size, fixed mass1, on Sand/Rust (4);90-degree entry on Sand/Rust (2). |
| M3 mechanisms/topology —12 pairs | Edge and slope on Sand/Dust/Rust (6); one-sided excavation on Sand/granular Stone (2); off-centre falling-grain impact on Sand/Rust (2); mixed-grain seam/re-entry and granular-Stone support removal (2). |
| M4 Y1 preservation —6 pairs | Gentle and high anchor entry, light/heavy high entry,45-degree moderate entry, half-size high entry. Preserve selected prior impact strengths and stress weaknesses without reoptimizing the anchor. |

That is **66 paired physical cases /132 primary captures**, with no additional
seed sweep unless a registered repeat/failure investigation requires it. M2 uses
moderate entry, so it does not duplicate M4's high-entry mass/scale cases. Gate0
must expand every row to exact body pose, speed, material/state, bed dimensions,
duration, input timeline and edit ledger before execution.

Additional bounded controls, separate from that efficacy population:

- All-nine capability/state admission; Stone intact/braced versus granular,
  Seed→Plant and one ordinary reactive loss-of-support transition using existing
  fixture/reaction APIs. Respect defined reaction sources/sinks; exact per-ID
  conservation applies only to closed nonreacting fixtures.
- Hard floor/wall/glancing contact, Empty flight and Water: zero new granular
  response without grains, unchanged old response/quantities. Add one mixed
  Water+grain interface to detect accidental liquid-law contamination.
- Thin films/loose falling grains: no static wall/bearing admission; legitimate
  grain-impact impulses remain distinct. Existing bounded ejection/hard barrier/
  foreign-mask replay and exact material/state/temperature conservation remain.
- Six real delayed-worker scenarios per arm: moderate vertical, high vertical,
  lateral bank entry, glancing impact, off-centre grain stream and excavation.
  Reuse real immutable mailbox delivery; separate sample age from throttled
  response cadence. Include stale/duplicate/reset/exclusion refusal tests.
- One/two-body and64-record capacity tests; matching-worker native reductions
  at1/4 workers, signed seams and failed-world quarantine. Do not claim coupled
  trajectory identity across OSes or asynchronous schedules.

## Which measurements and decision rules apply?

Gate0 freezes the exact thresholds below and numerical tolerances in a compact
machine-readable registration before GCR results. These are **proposed experiment
gates**, not newly approved universal material constants:

- **Mechanics:** analytic one-contact impulse matches mass/inertia/lever arm;
  mirror tests reverse angular sign; normal-contact torque exists at zero mu;
  zero slip/frictionless cases remove the corresponding tangent term. Symmetric
  flat support must not acquire a systematic unforced turning bias. Verify
  dissipation for passive fixed contacts and exact consistency of accepted
  linear/angular impulses after limiting.
- **Normal resistance:** in the registered Sand/Dust/Rust moderate bank-entry
  cases, reduce peak horizontal entry by at least25% versus Y1; no material may
  worsen that entry by more than max(0.5cell,10% of Y1). Report other powders
  individually, including films/loose material. Do not demand that legitimate
  above-capacity forcing stop: measure yielding/displacement rather than make
  powders an immovable wall.
- **Impact preservation:** peak vertical entry and pre/post-ejection overlap
  may not worsen by more than max(0.5cell,10%) and max(1cell,10%) respectively
  in the registered preservation rows. Publish all rebounds, clearance,
  unresolved-overlap/no-target onset and late motion, including inherited
  failures. Do not claim this focused gate closes the entire earlier envelope.
- **Friction/rotation:** report local slip, accepted normal/tangent impulse,
  contact moment, angular velocity/orientation and support distribution. Use
  isolated controlled sliding tests for friction bounds/dissipation, not an
  assumption that every long rolling trajectory is monotone in mu. In edge,
  glancing and grain-stream cases, attribute angular change before any hard
  floor contact; use mirrored/no-grain/central-application controls. A rotating
  fixture alone is not a torque-causality pass.
- **Support removal:** retire the new supported-contact response on the next
  accepted fresh sample after full excavation, with no stale correction/lift.
  Partial support retains only real admitted contacts. Re-bearing requires
  fresh valid material. No support witness survives reset/exclusion unnoticed.
- **Work/performance:** record probes, bins, reductions, limiter distribution,
  ejection attempts/refusals, active/scanned work and p50/p95/p99/max native
  coupling, main/Rapier and total worker/publication time. Use at least3 paired
  fresh-process AB/BA timing repeats after120 warmup ticks. A p95 increase both
  >25% and >25us, or >2x work amplification, triggers a retained investigation;
  no promotion until it is explained and an admitted budget is met. New work
  need not have Y1's coefficient-only cost, but must remain explicitly bounded.

Capture the candidate/mu/ablation/policy/ABI/source/runtime/backend identities in
every receipt. Keep compact scenario summaries, selected traces and raw-bundle
hashes; do not commit another enormous per-event corpus. Repeated displacement
events are work observations, not independent efficacy trials.

## How is the liked playground feel protected?

Freeze the existing actor/player definitions, controller hashes, thrust,
rotation control, braking, air/angular damping, hard friction/restitution,
gravity, CCD and joint settings. The rocket barrel's controller drag/airbrake
is distinct from granular contact friction; preserve both their identities.
Do not compensate for weak/overstrong contact by retuning locomotion.

Use the actual actor/player host, not only synthetic impulses: rocket barrel,
one ground-driven articulated rig and one freely coasting reference rectangle.
Run identical recorded commands through Empty flight, hard floor/ramp, packed
granular floor, side bank, slope/edge and glancing contact. Use at least Sand,
Dust and Rust in this bounded playground set; the full category matrix remains
mandatory. Preserve existing shared asynchronous owner, input cancellation,
reset/ACK/terrain readiness, native material fields and Main pacing controls.

The source-matched review surface switches Y1/GCR only at fresh reset and keeps
presentation identical across physical arms. Original vector versus cell-grid
display is a separate recorded presentation choice; it cannot change physics.
Ask the owner whether momentum/jet control remains satisfying, sideways entry
has credible resistance, grains yield under sufficient force, corner/glancing
contacts turn naturally, and sliding avoids both skating and excessive sticking.
Record the actual verdict; automated trajectories cannot provide it.

**Stop this phase at the contact-response handoff.** Accepted contact mechanics
would be scoped progress under #83, not sleep/soliding completion or a production
default decision. PR #343 remains draft and unmerged. No candidate advance or
implementation success is claimed by this planning document.
