---
title: WEX-002 Water-sheet proof blocked disposition
status: Current
document-kind: evidence
scope: Final current-source blocked disposition for issue #92 WEX-002; no Water-sheet implementation or production migration
canonical-for: [wex-002-blocked-disposition]
last-reviewed: 2026-09-24
related-documents: [../operations/water-hybrid-pressure-extension-programme.md, ../operations/soliding-programme.md, ../architecture/soliding-lifecycle.md, ../architecture/rigid-body-and-cellular-coupling.md, 2026-09-20-issue-91-wex001-water-body-baseline.md]
---

# WEX-002 Water-sheet proof blocked disposition

## Disposition

**BLOCKED — missing admitted generic dynamic cell↔Rapier ownership substrate.**

This is not a no-go result for the Water-sheet hypothesis. No registered sheet arm
has been executed, so there is no evidence that the proposed upper-volume segmented
tiers fail mechanically, are too expensive, or cannot improve deep-release surge.

The issue is blocked at its explicit hard entry gate: current CyberSand does not
yet contain an admitted production-capable generic material ownership transition
that WEX-002 can reuse for cells → native aggregate payload → main-thread Rapier
body → reversible demotion.

Creating a Water-only handoff backend to bypass that gate would duplicate #12's
production ownership and violate WEX-002's governing contract.

## Authoritative source inspected

Disposition source:

`723656c9b5920bd7c404a98ccdd3bbb12daa863f`

This is PR #105 / WEX-004 landed main. Its landed-main validation is green:

- Documentation/provenance **36022716134** — success;
- GDExtension/Godot **36022716215** — success;
- Native C++ validation **36022716413** — success.

The disposition changes documentation/decision routing only. It does not modify
Water, soliding, Rapier, native runtime, retained binaries or CI.

## WEX-001 baseline consumed

WEX-001 / #91 completed through PR #102 / merge
`3fa6728d6a6fbadbe19111102bf292648782b04c`.

Canonical baseline:
`docs/audits/2026-09-20-issue-91-wex001-water-body-baseline.md`.

The result required by #92 is retained rather than reinterpreted:

- a generic rectangular Rapier body can produce useful Water splash/displacement;
- exact Water mass remained conserved in the registered closed fixtures;
- hard-boundary behavior is not trustworthy: the baseline reproduced Water
  crossing the forbidden floor band;
- that failure is defect evidence, not an accepted Water/body contact model.

WEX-002 therefore starts from a useful coupling hypothesis and a known boundary
correctness defect. It does not start from an accepted material↔Rapier handoff.

## Current generic coupling is not the required substrate

Current
`docs/architecture/rigid-body-and-cellular-coupling.md`
states that native World owns cellular materials while Rapier owns **independent**
rigid bodies. Bodies are projected into a transient body-ID occupancy field; they
are never erased from or restored into the material array.

That mechanism supports body↔cell displacement/impulse observation. It does not:

- remove a selected material region from cell authority;
- place its exact payload under a native aggregate owner;
- create/acknowledge a corresponding disabled Rapier body;
- atomically change sole material ownership;
- install an endpoint occupancy/collision representation;
- later reverse the transaction and demote exact payload back into cells.

The WEX-004 diagnostic relocation adapter also does not provide this substrate. It
moves one already-cell-owned loose cell through existing
`World::relocate_stored_cell()`; it never promotes material into a Rapier-owned
dynamic aggregate.

## #12 / soliding authority is still pre-dynamics

Current
`docs/operations/soliding-programme.md`
classifies Stage 3A and Stage 3B as **read-only, cells-owned observation**.

The current Stage-3B route is:

`#66 -> #67 -> #68 -> #70 -> supervising-parent admission`

with #56-#65 and #69 complete. Stage 4 remains blocked.

The canonical stage ladder then places:

1. Stage 4 — stationary representation bake-off;
2. Stage 5 — eligibility;
3. Stage 6 — **production dynamics**;
4. Stage 7 — geometry/fracture;
5. Stage 8 — persistence.

Therefore completing current #66-#70 is necessary progress, but it is not itself
the dynamic substrate #92 requires.

## Lifecycle contract is model-only, not runtime admission

`docs/architecture/soliding-lifecycle.md` deliberately separates the approved
logical ownership contract from runtime implementation.

Its representation table currently labels:

- dynamic coherent aggregate material owner: native aggregate store;
- Rapier transform/contact/motion owner: Rapier;
- runtime status: **Planned, model only**.

The document also states that the production desktop rendezvous/fence is Planned.
Its standalone lifecycle tests exercise logical transitions over copied synthetic
membership records; they do not allocate live Rapier bodies, stop an asynchronous
World, transfer current material payload or prove real collision-topology handoff.

That is exactly the distinction WEX-002's hard entry gate was written to preserve.

## Missing reusable prerequisites

Before a production-like WEX-002 sheet arm can be executed honestly, the generic
owner must provide or explicitly admit all of the following on live source:

1. **Singular material owner transaction**
   - exact source membership/payload is retained until all resources are ready;
   - one atomic fenced commit changes material owner once;
   - no erase/simulate/restore duplicate ownership.

2. **Exact fractional Water transfer**
   - Water `state_a` FreeMass is transferred as quantity, not inferred from
     occupied geometry;
   - relevant `state_b` and optional temperature/payload survive promotion and
     demotion;
   - partially filled Water cells are not treated as unit-mass cells.

3. **Real main-thread Rapier handoff**
   - immutable proposal/value packets;
   - main-thread body/shape creation in a disabled/prepared state;
   - acknowledgement against exact generation/revision/token;
   - safe final enable/finalize ordering.

4. **Collision/topology ownership**
   - terrain/contact owner is unique through transition;
   - old cellular collision authority and new Rapier authority cannot overlap;
   - endpoint occupancy/masks cannot expose a transient hole or double-contact
     interval.

5. **Bounded capacity/refusal/quarantine**
   - body, shape, payload, destination, request/result and cancellation capacity
     are reserved before commit;
   - exhaustion leaves the old representation authoritative;
   - postcommit uncertainty quarantines rather than guessing rollback.

6. **Reversible demotion**
   - exact payload can return to admitted cells;
   - parent transform/motion is handled under a declared approximation;
   - split/desolid/support-loss invalidation has a bounded owner.

7. **Boundary correctness**
   - #91's forbidden-floor Water ejection class is fixed or explicitly fenced from
     the sheet experiment;
   - #11/#81 currently remain live authority for generic body↔cellular semantics
     relevant to barrier-aware ejection/bearing reconciliation.

8. **Source-matched validation**
   - actual native + Rapier/Godot ownership path, not a standalone model, passes
     the applicable exact-head correctness, sanitizer, GDExtension and provenance
     gates.

No current-main component supplies this complete reusable contract.

## Why no isolated facsimile is built

WEX-002 permits an isolated mock only if it cannot be mistaken for the production
ownership path. Such a mock is not useful enough to justify implementation now.

The decisive WEX-002 questions are coupled directly to the missing substrate:

- S2 asks whether real sheet weight/contact creates additional lateral dam-break
  surge rather than floor reaction;
- S3/S4 compare real generic Rapier↔Water displacement;
- S6/S7 require real constriction, split, support-loss and prompt desolid behavior;
- S8 requires trustworthy real hard-floor/container ownership;
- S9 requires exact repeated promotion/demotion conservation and churn;
- performance acceptance needs real main-thread Rapier/body/shape/contact cost.

A facsimile could preregister tier geometry or synthesize forces, but it could not
answer those questions. A positive mock would remain conditional on the exact
missing integration work and could create false confidence; a negative mock could
reject the concept for defects in the facsimile rather than the concept.

The correct bounded action is therefore to stop at the entry gate.

## Registered design retained for later re-entry

The existing issue remains the design record for a future proof:

- shallow Water: zero sheets;
- 0..3 primary upper-volume tiers;
- optional bounded 4..5 stress arms;
- segmented local carriers, never a reservoir-spanning plate;
- several ordinary cellular free-surface rows retained;
- prompt split/desolid on support/topology/edge/rotation/constriction invalidation;
- exact Water quantity/payload accounting;
- S0-S10 controls and falsification matrix unchanged.

These are **registered future experiment requirements**, not evidence that any arm
has executed.

## Re-entry gate

Do not reopen implementation merely because Stage 3B closes.

WEX-002 may be reconsidered only when current main contains an explicitly admitted
generic dynamic cell↔Rapier substrate satisfying the ownership transaction above,
or a newer authority supersedes this requirement with an equally explicit
production-capable contract.

At re-entry:

1. fetch current main and live #12/hybrid owners;
2. prove the generic substrate is actually implemented/integrated/verified, not
   merely modeled or planned;
3. verify #91's boundary defect is fixed or fenced for the proposed fixtures;
4. refresh the preregistration against the landed API/units/capacities;
5. execute S0-S10 without changing the frozen arm after observing results.

No automatic reactivation follows from issue numbers or stage completion alone.

## WEX-005 input

WEX-005 should consume #92 as:

**still blocked by missing generic hybrid substrate.**

Consequences:

- Q1 deep-release: the Water-sheet hypothesis remains **untested/unknown**; do not
  infer that generic hybrid coupling failed to improve surge;
- Q2 production value: **blocked**, not promising/narrow/expensive/no-go;
- #45 routing must be decided using the evidence that actually exists (#49, #91,
  #93, #94 and current Water), while preserving the missing hybrid experiment as
  an uncertainty;
- no production Water-sheet migration issue is justified now;
- a future #12 dynamic substrate may justify reopening the hypothesis, but #95
  does not need to wait for speculative future implementation.

This blocked disposition satisfies #95's explicit prerequisite form: “#92 or an
explicit blocked/no-go disposition for #92.”

## Completion interpretation

WEX-002's issue text explicitly says that if no suitable generic substrate exists,
record the precise blocker and stop rather than creating a second backend. Its
required outputs also permit an **explicit blocked/no-go record**.

Accordingly, closing #92 after this record lands means:

- the **current WEX-002 research attempt is dispositioned**;
- the Water-sheet concept is not rejected;
- S0-S10 experimental acceptance items are **not claimed passed**;
- implementation can return only through the explicit re-entry gate above.

That distinction must be preserved in #90/#95 and future retrieval.
