---
title: Physics characterisation and soliding plan
status: Planned
document-kind: runbook
scope: Proposed experiments for material penetration, player support, barrel settling and reversible aggregate physics; inspection is not runtime acceptance
canonical-for: [physics-characterisation-plan, soliding-investigation]
keywords: [powder, mercury, barrels, sinking, soliding, permeability, granular support]
last-reviewed: 2026-09-08
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ../systems/materials-and-rule-kernels.md, ../reference/product-intent-and-priorities.md, ../reference/status-and-roadmap.md]
---

# Physics characterisation and soliding plan

## Scope and evidence boundary

**Approved owner direction, 2026-09-08:** investigate solids passing through one
another, powders failing to support the player, dense liquids rapidly crossing
powders, and barrels continuing to sink into granular beds. The red test
rectangles are now called **barrels**. Mercury may retain much slower powder
penetration. Ordinary barrel impacts should embed by no more than roughly half
their depth and then stop. Include eventual reversible **soliding** of rested,
mostly contiguous same-material regions for Rapier macro motion and ballistics.

**Current evidence here is source inspection only**, against source HEAD
`b462e6b` on `codex/issues-1-2` in `C:/kybersand/source`. At inspection the only
source-tree delta was the installed Windows native DLL (LFS working-file hash
prefix `fda49d0`, versus tracked `402732d`); the workspace repository was clean.
This source commit is the existing recoverable baseline. The DLL has not been
rebuilt or run for this plan. Retain Godot 4.7 and pinned Rapier v0.35.2.
All experiments and candidate numbers below are **Planned**, not measured fixes
or new runtime configuration keys. Implementation and deployment are separate
checkpoints; no solver changes are part of this planning checkpoint.

## What the code already explains

Current contracts remain in [materials](../systems/materials-and-rule-kernels.md)
and [coupling](../architecture/rigid-body-and-cellular-coupling.md).

| Report | Current source mechanism | Hypothesis to test |
|---|---|---|
| Solids flow through solids | `MaterialRules::can_density_exchange` tests vertical direction, target permission and relative density, without a powder/powder exclusion. Sand, Stone, Dust and other powders accept exchange. | Denser grains can reorder through a packed lighter bed with no void or yielding threshold. Separate this from actual hard-surface tunnelling, chemistry and Stone's brace/granular modes. |
| Powders do not interact with player | Native `character_solid` and fallback `is_character_solid` accept hard surfaces or Sand specifically. Character movement samples the perimeter of its box. | Other powders are intentionally absent from that predicate, regardless of their density; also test initial enclosure because perimeter sampling is not full-volume recovery. |
| Mercury crosses powders rapidly | Mercury uses density 13,500 and the yielding-liquid kernel. Downward/diagonal exchange precedes the viscosity gate; viscosity 96 controls lateral motion. | A viscosity-only adjustment cannot slow downward penetration. Exchange needs an independent pair/material rate or yield condition. |
| Barrels sink indefinitely | Sand/powders are absent from hard-terrain colliders. The coupling ejects movable cells and supplies capped central pressure/contact/displacement impulses. | There is no persistent granular load-bearing/yield model. Opposing face impulses, saturation and stale-sample attenuation may reduce net support. Existing pressure should not be interpreted as calibrated buoyancy. |

Sources: [material rules](../../native/src/material_rules.cpp),
[descriptors](../../native/include/cybersand/material.hpp),
[`fall_as_powder` / `flow_as_yielding_liquid`](../../native/src/world.cpp),
[`character_solid`, `reconcile_overlap`, `accumulate_boundary_pressure`](../../godot/native_extension/cyber_native_cell_world.cpp),
[sampled player](../../godot/scripts/sampled_character.gd),
[fallback](../../godot/scripts/cell_world.gd),
[Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd).

## Phase 1: freeze the baseline and build measurements

1. Record HEAD, all local deltas, executable/DLL/Web artifact hashes, dependency
   versions, platform, native/fallback backend, solver traversal, workers, tick
   rates, actual completed ticks, body sample age and fixture seed. Rebuild the
   native adapter before claiming source-matched results. Keep raw output in
   `C:/kybersand/validation/local/<date>-physics/` and source fixtures in the
   active checkout. CYSD1 alone is not a complete deterministic replay.
2. Build small fixtures from explicit coordinates and input schedules; restart
   from fresh construction for every variant. Use a closed box, fixed camera
   interest, fixed tick stepping and no unrelated reactions initially. Define
   cells, pixels, seconds, mass and impulse conventions before interpreting
   force balance; measure effective barrel gravity rather than assuming it.
3. Add bounded, opt-in diagnostics: movement into Empty versus density swaps by
   ordered material pair/direction; rejection reasons; reaction conversions;
   per-material counts and Water mass; activity/quiet/wake state; player
   grounded state and contacts. For barrels log transform, velocity, rotation,
   contact material/face, displaced and unresolved counts, raw impulse terms,
   pre/post-cap impulse, sample identity/age, accepted impulse and terrain backlog.
   Do not emit per-cell text or allocate growing telemetry in hot kernels.
4. Produce depth-versus-time plots and representative video/overlays showing
   cells, body mask, colliders and contact normals. Separate measured simulation
   trajectories from visual appearance. Record p50/p95/max tick and coupling
   cost, capacity high-water marks and dropped/rejected telemetry.

Start at 60 completed ticks/s for 30 simulated seconds (1,800 ticks), then run
120-second creep tests on settled finalists. Use five fixed seeds for screening
and twenty for finalists, reporting median and worst case. These are proposed
fixture budgets; extend a window explicitly if a slow-rate case cannot yet move.

## Phase 2: isolate each behaviour

| Fixture | Variants | Measurements and proposed acceptance |
|---|---|---|
| P1: layered granular beds | All powder pairs in both vertical orders; first focus Sand/Dust, Stone/Sand, Rust/Sand. Dense packing, holes, slopes; supported and unsupported Stone. Hard Wall/Concrete controls. | Swaps/tick, interface width, centre of mass, settling/reordering time. Packed resting powders should not interpenetrate solely due to density; grains must still fall through actual voids and avalanche. Hard controls allow no material passage. |
| P2: liquid over powder | Mercury, Water, Oil, Brine, Paste and Lava over Sand/Dust; reverse layers; 16/32/64-cell beds, dry and saturated, confined and with open sides. Add reactive pairs separately. | Penetration front, breakthrough time, displaced grain flux, reaction accounting. Proposed Mercury target: 10–50 times slower front speed than baseline in the canonical packed Sand bed, while still making progress. Other liquids need explicit permeability policy; density alone must not imply unrestricted passage. |
| P3: player support | Walk, stand, fall, land on slopes and approach sides of each powder; settled versus falling grains, one-cell films, enclosed spawn, moving barrel and hard-floor controls. | Grounding, depth, jitter, blocked/passed cells and escape. Settled support-capable powders should stop ordinary downward passage; define loose-grain side resistance separately so airborne dust does not become an invisible wall. |
| P4: barrel impacts | Canonical 8×14 barrel onto deep flat Sand, Dust, Salt and mixed beds; place gently, drop from 1/4/8 body heights; then mass 0.5/1/2, upright/45°/sideways and 1×/2× size. Compare Water/Oil/Mercury and hard floors. | Peak/final depth, settle time, late creep, rebound, angular motion, ejection and unresolved overlap. Establish the half-depth envelope below; liquid controls need distinct equilibrium behaviour. |
| P5: loss of support | Excavate beneath a resting player/barrel, remove a supporting wall, impact the side, pour new grains, flood bed, explode nearby. | Support must disappear when the bed does; avoid permanent hover, invisible supports and stale collider trapping. Record displaced material and latency to wake/collapse. |
| P6: timing and boundaries | Repeat chosen cases across activity/core/chunk seams; sleep/wake and leave/re-entry; phased 1/4 workers; desktop async and real Web compatibility/threaded. Inject bounded delayed/duplicate samples. | Exact cellular comparisons where traversal/configuration match; explicit trajectory tolerances for coupled bodies. Serial is a separate reference, not assumed identical to phased. Preserve failed-tick quarantine and region semantics. |

For P4 define a baseline flat surface before impact and barrel projected vertical
extent `H = abs(cos(theta))*height + abs(sin(theta))*width`. With downward-positive
coordinates, depth is `max(0, bottom_y - initial_surface_y)`. Report this alongside
local deformed-surface depth, crater shape and rotation so changing terrain cannot
hide continued descent. Deep-bed fixtures must put the hard floor far enough
below the barrel that it cannot provide the apparent support.

**Proposed ordinary-impact gate:** peak depth at most `0.5 H + 1 cell`, final
depth no greater than that, and at most one additional cell of descent during
the last ten seconds of a 30-second run. Repeat for 120 seconds to expose creep.
Nonzero embedding is desired for ordinary drops, but gentle placement may remain
shallow. Start with baseline mass and 1/4-height drops; classify 8-height drops,
thin beds and unsupported piles as stress cases before extending that guarantee.
The one-cell tolerance and timing are testing proposals; the owner's roughly
half-depth preference is the requirement. Do not implement a fixed world-height
clamp: support must follow actual material and yield when excavated.

## Phase 3: parameter experiments, then model changes

Change one parameter family at a time, select finalists, then run a small
interaction matrix. Preserve fast Water/spray/film and existing material-specific
feel. Do not combine density, gravity and all impulse multipliers in one sweep.

| Lever and current source location | Proposed test range | Interpretation / limitation |
|---|---|---|
| Target `accepts_density_exchange` in descriptors; current powders accept | On/off diagnostic variant only | Confirms swap causality, but a global off switch also changes gas/liquid displacement; final policy should express allowed pairs and support state. |
| Mercury `viscosity_index` 96 | 96/160/224/248 | Lateral-flow control experiment; it will not gate vertical exchange. Do not lower Mercury density to fake low permeability. |
| Coupling displacement 0.18, boundary 0.19, pixel contact 0.025 | Individually 0.5×/1×/2×; disable one term for diagnosis | Distinguishes which term supplies support or bounce. Observe force direction and opposing faces before increasing gains. |
| Per-body per-tick impulse cap 3; density scale upper clamp 1.6 | Cap 1.5/3/6; clamp 1.6/3.2 diagnostically | Measure saturation first. This clamp makes Sand and denser materials similar in those response terms; raising it can destabilize dense-liquid contact. Normalize future force to `impulse = force * dt`. |
| Barrel scene mass 1, gravity scale 0.094, linear/angular damping 0.15/0.35, friction 0.78, bounce 0 | Mass 0.5/1/2; damping 0.5×/1×/2×; friction 0.4/0.78/1 | Mass tests load-bearing; friction requires contacts, and damping cannot supply static support at zero velocity. Keep gravity fixed for acceptance; gravity reduction is diagnostic only. Keep bounce zero initially. |
| Sample-age rejection 8; attenuation `1/(1+0.25*age)` | Controlled age 0/1/2/4/8/9 at unchanged production limits | Establish whether desktop latency changes effective support. Raising age limits is not a support fix. |
| Sweep cutoff 32 pixels, max 24 intervals; cast-shape CCD already enabled | Speeds on both sides of cutoff; separate 1/2/4 substep prototype | Diagnose fast/thin/rotating motion independently of static support. Respect the tick-work budget; do not assume more Rapier substeps automatically improve cell coupling. |

These are compiled/native or scene constants, not existing UI sliders. Candidate
values should enter a versioned fixture configuration at a later implementation
checkpoint; apply between runs, not through unsynchronized live descriptor edits.

**New rules required, with proposed screening parameters:**

- **Pair exchange/permeability:** separate movement into Empty, powder/powder
  rearrangement and liquid/powder exchange. Gate all relevant downward and
  diagonal exchange paths, including either direction that can perform the swap.
  Test deterministic eligibility once per 10/30/60 ticks for Mercury/powder,
  or an equivalent time-scaled rate. Coordinate/tick streams must preserve
  worker parity. Use one eligibility decision per intended pair opportunity so
  alternate movement attempts do not multiply the configured rate. Pending
  slow interactions need scheduled wake/progress; region
  exclusion must not accumulate surprise catch-up. A probability gate alone
  cannot express support, packing or pressure, so evaluate those separately.
- **Granular support:** introduce a material support policy and a bounded local
  packing/support measure. Screen support occupancy 0.65/0.8/0.95 in a fixed
  neighbourhood; measure angle-of-repose and collapse regressions. Keep support
  state separate from density and from the hard-surface list.
- **Barrel bearing response:** prototype depth/compaction-dependent yield and
  velocity-dependent penetration resistance, plus persistent static support.
  Calibrate the supported-load envelope so ordinary impacts stop before half
  depth. Screen embed target fractions 0.25/0.4/0.5 and yield load scales
  0.5×/1×/2× baseline barrel weight. Later add contact-point torque and friction.
  Avoid double-solving the same support through cellular impulses and Rapier
  colliders; designate one solver per contact mode.

## Phase 4: reversible soliding

**Planned investigation:** soliding is a representation/motion handoff, not a
thermodynamic phase change and not permission to cement every resting powder.
Test cohesion/packing eligibility per material: a loose unsupported pile must
still avalanche, while a coherent supported region may provide a collision proxy.

### A. Detect candidates without changing physics

Maintain bounded region summaries for same-material connectivity, occupancy,
support and mutation age. Start with face connectivity so diagonal touches do
not create bridges; holes stay holes. Test rest windows 0.5/2/5 simulated seconds,
occupancy 0.8/0.9/0.98 and minimum area 16/64/256 cells. These are candidate
values, not approved thresholds. Rest requires no movement/reaction/damage or
support change; activity-block sleep alone is insufficient. Offscreen exclusion
does not earn rest time. Use bounded dirty-region jobs, resumable component
discovery and explicit max area/shape/queue budgets; avoid world flood-fills in
one tick. Record candidate churn, false bridges and cost first.

### B. Stationary support proxies

Prototype merged rectangles or bounded contours for qualified stationary
regions, keeping native cells authoritative. Proxies are derived collision data,
with stable region IDs and revisions. Validate holes, seams, narrow necks and
deletion before enabling barrel/player support. Wake/invalidate on edits,
excavation, impacts, chemistry, melting or loss of support, with hysteresis and
promotion cooldown to prevent chatter. Character queries must use the same
support policy; creating Rapier shapes alone does not alter the sampled player.
Proxy contact and cellular support impulses must not both supply the same load.

### C. Dynamic macro objects and ballistics

Propose an ADR before implementation. Current [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
rejects erase/simulate/restore body pixels and defers membership data; dynamic
material aggregates need a new explicit representation contract. The candidate
design keeps material membership/state in engine-owned aggregate storage while
Rapier owns the aggregate transform, velocity and collisions. Cells must have
exactly one simulation owner; no copy may remain freely simulated in World.
The projected occupancy is separate from the authoritative material payload.

Use an exclusive tick-boundary, revision-checked prepare/acknowledge/commit
handoff: reserve membership, collider, ID and result capacity first; create a
disabled main-thread body; commit a coherent ownership/mask revision and enable
it only after acknowledgement. Reject stale candidates without mutation. Define
cancellation and failure handling so there is never a tick with missing or
double collision/mass. No live Rapier objects cross to workers.

Derive mass, centre of mass and inertia from membership under an explicit unit
mapping. Preserve material IDs, compact state, Water mass where applicable and
temperature. The current cell model has no general per-cell velocity: define
initial momentum from known inputs or rest, rather than inventing lost momentum.
Evaluate shape complexity, holes, concavity, contact-point torque, CCD and
bounded substeps through the pinned adapter before promising arbitrary shapes.

### D. Dissolve, fracture and recover

Return to cells when stress, damage, heat, chemistry or fragmentation exceeds
policy. Before release, reserve all destination cells and any bounded overflow
representation. Never overwrite existing cells. If placement cannot conserve
membership, retain the aggregate and report a deferred transition; do not delete
or silently truncate it. Rotated rasterization must not duplicate/lose cells.
Reconcile momentum explicitly: either support a bounded moving-fragment/particle
representation, or restrict demotion to near-rest with documented energy error.
Repeated promote/move/rotate/demote cycles must not create mass or energy.

Test unsupported collapse, bridges, split/merge, high-speed impacts, clustered
barrels, saturated capacity, out-of-order acknowledgements, failed ticks,
save/load and offscreen re-entry. Persist membership, representation state,
pending handoffs and policy versions in a new schema before claiming continuation.
Start with one small coherent material island and one barrel, then scale.

## Delivery order and exit gates

1. **Baseline checkpoint:** scripted P1–P4 fixtures, bounded metrics and a dated
   report separating reproduction from hypotheses. Extend existing native
   `test_world.cpp`, Godot `test_cell_world.gd` and Rapier manual-step coverage
   where appropriate; do not claim the old floor fixture proves granular support.
2. **Interaction checkpoint:** implement powder/player support policy and pair
   exchange control separately; preserve counts, Water conservation, meaningful
   reactions, wake/progress and matching-worker determinism.
3. **Barrel checkpoint:** choose a support model from measurements, meet ordinary
   half-depth/no-creep and excavation gates, then validate tilted/multiple/fast
   bodies and platform latency. Report trajectory tolerances explicitly.
4. **Soliding checkpoint:** candidate diagnostics, then stationary proxies, then
   an ownership ADR and one dynamic aggregate. Promotion is optional under load;
   defer safely when capacity is unavailable. Set numeric per-frame extraction,
   shape, membership and memory budgets from measured target-platform headroom.

Use `dev.cmd native-test`, a freshly rebuilt adapter and `dev.cmd godot-test`,
then build and actually execute affected Web compatibility/threaded fixtures.
Keep desktop async results distinct from headless Web-controller invocation and
real browser execution. Preserve F01/F02 regressions. Each implemented increment
must update canonical materials/coupling/ownership/interfaces/configuration,
ADRs, roadmap, tests, evidence and retrieval as applicable; save/UI documentation
changes only when those behaviours change. No production timing or generalized
replay guarantee follows from this plan.

## Planning checkpoint validation, 2026-09-08

**Current documentation-only evidence:** Windows PowerShell, bundled Python
3.12 environment, source baseline and pre-existing DLL delta identified above.
No physics runtime tests, rebuilds or visual acceptance were performed. The
canonical owner-intent, roadmap, coupling route, indexes and corpus were updated;
C05/C06 are new supplementary questions, separate from the frozen 32-question
set. Ownership/API/configuration/save formats, dependencies, UI and solver
implementation remain unchanged, so their implementation contracts need no edit.

Executed from the source root with ordinary 10-second command timeouts:
`tools/ci/check_docs.py` passed (49 documents, zero errors/warnings);
`tools/ci/check_m11_consistency.py` reported 12 historical BUILD_ID hash
mismatches; historical hashes were preserved. `tools/docs/retrieval_eval.py`
found canonical pages in the top five for 32/32 frozen and 6/6 supplementary
questions (top one: 23/32 and 5/6 respectively). C05 and C06 both route first to
this plan. Manual source/answer review confirmed the player predicate and
viscosity distinction; C06's first chunk alone does not explain the handoff,
so its soliding subsections are needed for an adequate answer. These lexical
hits are not semantic or runtime acceptance. `git diff --check` passed.

Raw checker logs and retrieval JSON are retained under
`C:/kybersand/validation/local/2026-09-08-physics-plan/`. This plan is a local,
uncommitted documentation delta to the recoverable source baseline, not a new
release or published checkpoint.

## Measured follow-up, 2026-09-09

The [issue #9 baseline report](../audits/2026-09-09-physics-characterisation.md)
and [implemented measurement runbook](physics-characterisation.md) now supply
fresh source/artifact-specific experiments. The planning checkpoint and its
historical failures above remain unchanged. The baseline reproduces density
exchange and restricted player sampling, rejects viscosity as a vertical Mercury
control, and identifies retained-mask downward contact feedback as an additional
barrel mechanism. Future half-depth support and soliding remain **Planned**.
