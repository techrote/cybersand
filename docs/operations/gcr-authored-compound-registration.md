---
title: Authored compound flyers and Scooper qualification registration
status: Approved design
document-kind: plan
scope: Bounded generic compound admission, preserved seven-flyer authoring and experimental Scooper across LA, events off and selective arrivals
canonical-for: [gcr-authored-compound-registration]
last-reviewed: 2026-11-04
related-documents: [../systems/granular-review-flight-fleet.md, ../architecture/compound-granular-coupling.md, gcr-selective-events-registration.md]
---

# GCR-AUTHORED-001 — registered before implementation/results

## Authority and checkpoints

The owner authorizes flyer authoring cleanup, real compound hull support and a
Scooper with Afterglow controls and stronger stabilization. All existing flyers
must be preserved and LA, events off and selective arrivals qualified. Sleep,
material-law tuning, structural-detachment changes, production promotion and
merges are excluded. The image sketches a left rear stop, thin deck and rising
right penetrator. Material stays in native cells while carried; it is not added
to an inventory or erased/restored as a body payload.

Start: PR381 source`b759e9ea05f274eb01eec7163b0cdc47c83b7c43` in isolated
codex/gcr-authored-compound-scooper-20261104. Fetched main is
`7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`. PR347 remains independently owned,
draft/unmerged at`957ce67df859315ed238b6bbec1eebc9a743aaba`; its latest structural
qualification remains physical NO-GO. This task does not import its branch or
reuse its detachment lease for an actor. Older checkouts and running builds stay
untouched. Native runtime856c4937 is the starting control; changed native inputs
require new source-matched Windows/Linux builds before execution claims.

The owner's latest qualitative C/E/S report finds ordinary resting safe in all
three, rapid LA burial but no reported E/S burial, too much incoming loading in
LA, too little in E and more credible deflection/loading in S. Powered resistance
is satisfactory overall. These observations do not replace earlier registered
selective failures or supply exact source/settings/trajectory receipts. The
latest turn attaches a mockup; no new frame ZIP is claimed inspected here.

## Frozen implementation boundary

1. A named, bounded per-flyer definition owns geometry, mass, controller mode,
   capabilities and motor settings. Reload validates atomically; the selected
   new definition constructs a fresh owner at the saved spawn. Runtime identity
   includes definition hash. Existing seven resolved scalar/shape defaults and
   controller arithmetic retain exact fallbacks. General roster code becomes
   count-driven; historical seven-flyer experimental populations remain seven.
2. An authored body has at most8 nonoverlapping axis-aligned local rectangles,
   bounded overall extent128 cells. One actual Rapier body owns all colliders,
   one actual mass, COM, inertia and impulse budget. The same rectangle union
   supplies copied graphics, native occupancy/contact/ejection and spawn bounds.
   No AABB is submitted as an additional body or response.
3. Native explicit construction option gcr_authored_compound=true preallocates
   the existing compound workspace. It is separate from conservative structural
   displacement, which requires a real native payload lease. Independent worlds
   and actual detached aggregates retain their existing paths.
4. New value admission is prepare_gcr_authored_compound_coupling(states17,
   geometry4,identity,resolve_overlaps,rest_context). Geometry repeats local
   cx,cy,width,height. Exact identity version1/session_id/body_generation and
   immutable geometry/mass/inertia/friction are bound for the owner. Finite,
   complete, nonoverlapping geometry and sample identity are validated before
   mutation. Reset/reconfigure retires it; mixed admission kinds refuse.
5. Existing compound solver/bridge supplies one version2 wrench about physical
   COM. Unique source accounting, load-aware budget, passivity, correction and
   sample-age rules remain owned there. Authored C/E/S applies the same event
   admission law as its independent control. Detachment's token authentication
   and current event-mode admission are not relaxed.

## Initial Scooper definition

Raw local Rect2(x,y,width,height), in order:
(-13,2,26,2),(-15,-5,2,9),(13,1,2,3),(15,0,1,3),(16,-1,1,3),(17,-2,1,3).
They meet without positive-area overlaps. Uniform area determines COM; all
rectangles are recentered about it. Actual mass is0.18 and actual inertia uses
the parallel-axis sum, approximately22.10 before overrides. Existing mass and
inertia multipliers apply once to the physical body.

Movement follows Afterglow: world-axis W/S lift and A/D strafe, Space lift burst,
Q/E attitude target, Shift propulsion boost, Ctrl brake and C assistance.
Acceleration125, speed95, turn-speed2.8, slew4, drag0.55 and force ceiling23 retain
the Afterglow linear baseline. Initial new motor parameters are attitude gain40,
angular damping12.5, angular-acceleration cap48, torque ceiling1200 and trim
target1.2rad. The original Afterglow retains10/4/12/36 and0.4rad. A torque ceiling
of96 would yield only about4.34rad/s² for Scooper, so it is not an appropriate
way to obtain the requested stronger response. All new values are experimental
actor authoring, not material-law calibration or production defaults.

## Registered mechanical and compatibility gates

All are required; failures are preserved rather than renamed as qualification:

- Exact original seven resolved physics/controller parameters and unchanged
  unboosted/boost/brake/effort outputs for identical copied input/pose fixtures.
- Definition finite/capacity/overlap/unknown-field validation, deterministic
  hash, failed reload preserving live owner and admitted definition, successful
  reload/reset at saved spawn; eight-craft selection/Tab/rendering without
  broadening ordinary player admission.
- One physical RID, six matching hard colliders, exact authored mass/COM/inertia
  and matching native union at level and rotated poses. Cavity occupancy is
  empty; no AABB fill. All three response choices reach the intended native mode.
- One result/wrench per boundary, duplicate/stale/malformed/mixed-owner refusal,
  reset retirement, no repeated per-proxy body mass or response budget. The
  accumulated event/passive budget obeys the existing load-aware allowance
  within1e-8 numerical tolerance; passive kinetic energy obeys existing tolerance
  excluding external motor/event/correction/gravity channels.
- Shared-source/seam/decomposition controls may differ in quadrature detail;
  they must not duplicate material sources, occupancy or capacity. No exact
  trajectory equivalence across arbitrary decompositions is assumed.
- Exact closed native quantities for nonreacting materials, exact Water quantity,
  no hard/foreign-mask teleport or hidden erase, support removal releases,
  zero Water-only bearing, hard terrain remains Rapier owned.
- Existing native core/sanitizer and relevant Godot actor/bridge, ejection,
  support, async/stale, negative and structural-detachment lease regressions.
  Current source-matched Windows/Linux runtime identity and provenance gates.

## Bounded physical population and decisions

Run all three responses synchronously with one native worker. The primary
material is Sand; Dust is the low-loading comparison and Salt is an additional
nonreacting granular policy control. Other admitted powder policies receive
bounded source/geometry smoke controls, not another full Cartesian population.
At most24 distinct scenario/response combinations per OS, at most900ticks each:

- unloaded landing/quiet motion;
- falling overhead burst and sustained stream;
- passive burial/support release;
- level cavity loading and commanded vertical lift/carry;
- Q/E commanded tip and spill;
- asymmetric/edge contact;
- Water-only and hard-only negative controls.

Use the same fixed geometry, mass, native law, seed and commands between C/E/S.
Record positions/velocities/angle, actual actuation, native quantities, cavity
contents, event/passive wrench/budget, unresolved overlap and probe/work counts.
Report mechanism-specific outcomes and timings; repeated events are not an
independent efficacy population. Carry demonstration starts with16 native grains:
at least8 must remain in the open cavity while the body rises8 cells; a later
tip should release at least half of the retained load within300ticks without
cell deletion. These are a bounded demonstration, not a guarantee for all loads.
If this gate fails, report it and characterize the mechanism before tuning.

Mechanical correctness can pass while a response has poor loading, burial or
spill behaviour. Compare tradeoffs separately. Preserve LA as the production
room control; do not promote S, infer subjective acceptance, close REM-004 or
merge. A source-labelled playable owner review remains required after tests.
