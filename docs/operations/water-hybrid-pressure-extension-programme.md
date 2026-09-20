---
title: Water hybrid, saturated-head and compartment-pressure extension programme
status: Planned
document-kind: design
scope: Parallel/extension research for deep-Water bulk response, generic Rapier↔cellular coupling, bounded solided-Water sheet proofs, saturated-head requirement reassessment, lumped gas regions and optional decompression events; no production architecture adoption
canonical-for: [water-hybrid-pressure-extension-programme]
last-reviewed: 2026-09-20
related-documents: [architecture-programme.md, soliding-programme.md, ../systems/water-design.md, ../architecture/rigid-body-and-cellular-coupling.md, ../decisions/ADR-005-water-model.md, ../decisions/ADR-007-rigid-body-cellular-coupling.md, ../reference/product-intent-and-priorities.md]
---

# Water hybrid, saturated-head and compartment-pressure extension programme

## Status and authority

This is a **Planned extension/parallel investigation**, not an adopted Water solver,
not a production migration and not permission to weaken existing ownership,
conservation, bounded-work or failure contracts.

It records owner clarification and a reviewed follow-up programme arising after the
2026-09-19 Water work and the 2026-09-20 soliding/hybrid discussion. It exists so
future work does not silently collapse several different questions into one
"pressure solver" task.

Current executable behavior remains defined by source and the focused subsystem
contracts. Existing staged architecture authority remains in
[architecture-programme.md](architecture-programme.md). Existing Water successor
apparatus work remains owned by #49 and existing saturated-head architecture work
remains owned by #45. Existing scalable reversible soliding remains owned by #12.

This programme extends those tracks; it does not duplicate them.

## Owner clarifications recorded 2026-09-20

These statements are owner intent and scope clarification, not retrospective
rewrites of historical evidence.

### CyberSand remains an engine-backend project first

The near-term goal is a reusable native Godot backend whose physics and ownership
contracts are trustworthy enough for games to be built on. Fine player/gameplay
feel is not the current priority when foundational soliding, hybrid ownership and
Water architecture are still changing.

That does **not** make physics quality optional. Conservation, topology, body↔cell
handoff, collision ownership, material displacement, support loss and stable
bounded behavior are foundational engine concerns.

### A barrel is only a generic Rapier reference body

The red "barrel" is not a special gameplay object or a separate physics subsystem.
It is a small rectangular Rapier solid body used as simple reference material and
a sanity-check fixture for generic rigid-body↔cellular interaction.

The owner does **not** recall accepting historical barrel-support behavior as a
finished target. A later rework improved how rigid bodies interacted with Water
and that improvement remains useful current evidence, but neither that fact nor a
bounded historical fixture means broad barrel/body behavior was owner-accepted.

Future hybrid work must therefore avoid a barrel-only support path. The useful
barrel cases become generic Rapier-body regression fixtures for the same coupling
that solided material will use.

### Water and other native liquids still use distinct motion/quantity paths

Completed #15 characterization remains the relevant scoped evidence:

- native Water uses the fractional conserved **FreeMass** path;
- most other native liquids use whole-cell **CellularYield**-style motion;
- Oil retains additional specialization;
- no universal FreeMass conversion, liquid unification or new generalized yield
  solver was selected.

A new explicit hydrostatic/depth-pressure transport mechanism would therefore add
another liquid-specific bulk-motion authority. This is one reason to measure what
generic soliding/hybrid coupling can already provide before adding a new Water
solver layer.

## Problem statement

### Current liked behavior

Shallow Water, fast local fronts, airborne spray and supported film can look good.
A generic Rapier body entering Water in the current build can create a convincing
splash/wave response. That observation is significant because it demonstrates that
existing body↔Water coupling can already turn rigid-body motion into visually
credible bulk Water displacement.

The observed barrel example also exposes a separate correctness defect: when the
body reaches the container bottom, Water can be displaced through hard floor
geometry, and in at least one observed run the body itself phased through the floor
with the Water. That boundary/ownership failure must not be mistaken for desirable
fluid behavior and must be fixed or fenced before hybrid-Water evidence is trusted.

### Current deep-Water weakness

The owner-observed dominant bulk defect is different:

- shallow volumes generally behave reasonably;
- a deep body of Water released on one side tends to form a slowly draining slope;
- the desired deep response is a substantially faster outward surge, ideally a
  wave and at minimum something resembling storm surge;
- the useful qualitative distinction is depth-dependent bulk response, not
  universal exact continuum-fluid fidelity.

Earlier #26/#45 work described the missing effect in terms of head/pressure
transmission through saturated connected Water. That remains one possible
architecture explanation, but it is no longer the only candidate mechanism that
must be considered.

## Core hypothesis: generic hybrid soliding may supply part of the missing bulk response

The current barrel splash suggests that a Rapier-owned mass pressing into cellular
Water can produce useful outward displacement. Upcoming #12 soliding/hybrid work
will already need a generic ownership and conversion path between authoritative
cells and Rapier solid bodies.

The extension hypothesis is therefore:

> Before adding a separate Water pressure/momentum solver, test whether a very
> small number of bounded, upper-volume solided Water carriers can reuse the
> generic Rapier↔cellular coupling to provide coarse depth-dependent loading and
> momentum.

This is a hypothesis, not a selected design.

### Precise sheet concept

The intended proof is **not**:

- one monolithic solid Water core;
- rigidifying an entire reservoir;
- repeating lamination throughout the full depth;
- one reservoir-spanning unbreakable plate;
- a Water-specific second rigid-body engine.

The intended candidate is approximately:

- zero sheets for shallow Water;
- at most roughly **3-5 tiers** for very deep Water;
- tiers concentrated in the **upper volume**, while preserving a few cellular
  layers at the actual free surface;
- each tier made of bounded/segmented local carriers rather than one unbounded slab;
- tier count or eligibility derived conservatively from local depth/support;
- promotion/demotion performed through the same generic hybrid ownership machinery
  used by other solided material;
- aggressive split/desolid behavior around unsupported edges, rapidly changing
  surfaces, constrictions, excessive rotation, topology change or invalid support.

The intended coarse mechanism is:

`depth -> eligible tier count/load -> Rapier gravity/contact -> cellular displacement -> outward surge`.

Three useful qualitative tiers may be enough; the ceiling exists to keep both
cost and mechanical influence bounded.

### Why near-surface placement matters

Upper-volume placement offers two possible benefits:

1. **bulk loading:** tier weight/vertical constraint may force cellular Water
   underneath to displace outward when geometry permits;
2. **surface interaction:** a near-surface carrier may allow transient planing,
   skimming/slap-like rigid-body interaction if desolid behavior is tuned well.

Aquaplaning here is a possible emergent hydrodynamic-looking outcome, not a mandate
to implement a dedicated aquaplaning rule or a non-Newtonian solver.

### Decisive failure modes

The proof must actively try to falsify the idea. Important failure modes include:

- tier weight resolving almost entirely as floor reaction with little extra lateral flow;
- rigid plugs, slabs or membrane-like tensile strength;
- a carrier bridging unsupported openings or narrow gaps;
- visible rigid-body rotation of large Water surfaces;
- blocking ordinary vertical Water exchange;
- promotion/demotion chatter or threshold hysteresis;
- energy or momentum creation/loss during cell↔Rapier conversion;
- exact Water mass loss/duplication, especially because Water cells carry fractional
  mass rather than one whole-cell unit;
- state loss for Water coherence/other relevant payload;
- collision double-ownership between a Water carrier and cellular Water;
- excessive wake amplification or main-thread Rapier cost;
- container/floor penetration or material teleport;
- sheet topology persisting longer than the useful fluid illusion.

A negative result is a successful experiment if it shows that the hybrid mechanism
cannot provide the needed bulk response cleanly.

## Required generic hybrid contract before a production-like sheet proof

The sheet experiment must not build a duplicate hybrid backend while #12 owns
production soliding.

Before a production-like proof modifies runtime soliding, there must be a usable
generic cell↔Rapier ownership substrate or an explicitly isolated experimental
facsimile that cannot be mistaken for production integration.

The contract must account for at least:

- one authoritative material owner at every transition phase;
- exact Water integer mass carried across promotion/demotion;
- material/state/temperature payload needed by the selected Water subset;
- geometry and mass distinguished when partially filled Water cells are involved;
- deterministic, bounded promotion/demotion ordering;
- main-thread Rapier ownership;
- capacity/refusal without material deletion;
- collision ownership with no double-contact authority;
- motion/energy accounting at the declared approximation level;
- stale/cancelled/failed transition handling;
- hard-terrain and foreign-body boundaries;
- exclusion/re-entry and relevant save/refusal semantics.

If #12 has not yet supplied an appropriate generic substrate, the sheet issue may
freeze fixtures and characterization but must stop before creating a competing
production handoff architecture.

## Relationship to #49 and #45

### #49 remains valuable and independent

#49 repairs the successor Water experiment apparatus: equilibrium/coverage metrics,
censored outcomes, the clean communicating-head fixture, active/sleep timing and
runner durability. None of this extension invalidates that work.

#49 can proceed in parallel and remains the sole owner of those corrections.

### #45 is no longer treated as an inevitable pressure implementation

#45 remains the existing owner of the saturated-head architecture question, but
its implementation decision must consume the extension evidence before assuming a
new head/pressure carrier is necessary.

The corrected communicating-head fixture should be treated as an explicit physical
control whose boundary assumptions are stated. In particular, equal free-surface
levels are not a universal target when the gas volumes above the liquids are sealed
at different pressures.

After #49 and the relevant hybrid evidence, the acceptable #45 dispositions include:

- the hybrid mechanism supplies enough intended deep-release behavior and no
  additional saturated-head mechanism is justified;
- #45 remains necessary, but only under explicit vented/open-head boundary assumptions;
- a bounded Water head mechanism is still valuable while sealed-space behavior is
  deliberately outside scope;
- compartment pressure must become an explicit optional boundary condition before
  a sealed-head fixture has a meaningful target;
- the generic feature is not worth its complexity for the intended game domain,
  and rare set-piece effects such as a rising-water chase are better authored with
  explicit material sources/sinks/spawners.

A no-go/defer is a legitimate architecture result. Do not implement #45 merely
because the issue exists.

## Parallel feasibility branch: lumped compartment gas pressure

The owner considers trapped-gas/pressure research valuable even if it never
integrates into production. This branch is deliberately independent from the sheet
proof and may run in parallel because a useful result can be a research-only
prototype and cost model.

### Intended abstraction

Do **not** begin with per-pixel gas CFD.

The candidate is a lumped/zone-style compartment record, conceptually containing:

- stable region/compartment identity;
- free gas volume;
- conserved/owned gas amount or another explicit amount proxy;
- cached/derived pressure;
- vented/exterior relationship;
- topology revision/generation;
- bounded opening/portal adjacency.

For a minimal isothermal proof, pressure may be derived from gas amount and free
volume. A one-byte pressure value may be useful as a cache/presentation quantity,
but it should not be the sole authoritative state if merges, splits and
compression/decompression must conserve information.

### Connectivity, not wall-boundary tracing

The initial owner idea proposed a "travelability trace" along the boundary to
detect a broken room. Review rejects that as the primary topology invariant.

Airtightness depends on whether **gas space is connected to another gas region or
to an exterior/vent**, not whether one can trace along a wall boundary from one end
to another.

The proof should therefore track connected gas space:

- static/lazy flood or macro-cell classification assigns gas-region IDs;
- opening a connection usually causes a cheap merge;
- connection to exterior/vent marks or couples the region to an atmospheric/vacuum
  boundary;
- closing an opening can cause a split and is the expensive case;
- split reconstruction is performed lazily/on-demand and only for the affected
  region;
- coarse macro-cells, portal metadata or conservative occupancy summaries may be
  used if narrow openings remain explicit;
- pre-authored room IDs may seed the system, but dynamic topology must be able to
  invalidate them truthfully.

This is conceptually similar to other dynamic-connectivity problems in CyberSand:
additions/merges are cheap, while deletions/closures require proving whether a
component split.

### Water coupling boundary

Compartment pressure does **not** by itself solve saturated Water transmission.
It supplies a boundary condition at a free liquid surface.

For a vented reservoir, surface pressure may be treated as atmospheric. For a
sealed compartment, the Water surface sees that compartment's derived pressure.

A sealed two-reservoir fixture therefore should not blindly require equal Water
levels. Its equilibrium depends on both hydrostatic head and gas pressure. The
explicit Water bulk mechanism and the gas-region model remain separate questions.

## Conditional space/decompression extension

Space/vacuum scenes make the compartment model potentially useful beyond Water,
but this remains conditional research.

Do not model "negative absolute pressure". Vacuum approaches zero absolute
pressure; negative **gauge** pressure is only relative to a chosen reference.

If a pressurized compartment opens toward a much lower-pressure region, a cheap
game-engine approximation may create a bounded decompression event at the opening
instead of simulating cellular air.

A candidate event may carry:

- opening identity, location, effective area and direction;
- source/destination region and pressure differential;
- bounded mass/impulse budget;
- duration/decay;
- local spatial horizon;
- explicit generation/revision so stale openings cannot continue applying force.

A bounded local flow/distance/occlusion field may then apply impulses to loose
cellular material, debris and generic Rapier bodies. The research question is
whether this can look and behave plausibly without becoming full gas CFD or a
magical radial "suction" force.

This branch is optional and executes only after the lumped-region feasibility
issue records a positive admission.

## Programme graph

The keys below are stable programme labels. GitHub issue numbers are recorded in
the issue index after creation.

```text
                         existing #12 soliding/hybrid substrate
                                      |
                                      v
WEX-001 current generic Rapier<->Water baseline
                                      |
                                      v
WEX-002 bounded upper-volume Water-sheet proof
                                      |
                                      +----------------------+
                                                             |
existing #49 corrected Water apparatus ----------------------+--> WEX-005 synthesis
                                                             |         |
existing #45 architecture question <-------------------------+         v
                                                                      #45 disposition/
WEX-003 lumped gas-region feasibility -----------------------+         updated #14 route
          |
          +--> WEX-004 decompression proof only if admitted -+
```

#49 may run in parallel with WEX-001/WEX-003. WEX-002 waits for a suitable generic
hybrid substrate and must not duplicate #12. WEX-004 is conditional. WEX-005 is a
decision/reconciliation issue, not an automatic implementation issue.

#84 formal blind-study capture, #85/#86 broad remediation and unrelated
MicroScenario work are separate. Do not make them blanket prerequisites for this
physics research.

## WEX-001 — current generic Rapier↔Water baseline

Purpose: freeze source-matched evidence for the current useful splash/displacement
behavior and the current hard-boundary failure before hybrid architecture changes.

Required evidence should include:

- ordinary generic rectangular Rapier body entering Water at several velocities;
- splash/front displacement and settling measurements;
- shallow versus deep Water controls;
- hard floor/container boundary;
- the observed failure class where Water is displaced through the floor;
- body-floor nonpenetration;
- conservation ledger distinguishing Water movement from loss;
- body/sample latency and coupling work;
- source/runtime/worker/platform identity.

The issue must phrase these as **generic body** fixtures. "Barrel" may remain a
human-readable fixture name but cannot imply a barrel-specific production path.

Exit: a bounded reproducible baseline and regression pack, with the good response
and the defect both retained. No semantic Water tuning is required to complete the
baseline.

## WEX-002 — bounded upper-volume Water-sheet proof

Entry:

- WEX-001 baseline available;
- inspect live #12 owner/branches/write sets;
- a suitable generic cell↔Rapier transition substrate exists, or an explicitly
  isolated proof can be built without competing with production ownership.

Preregister before candidate implementation:

- tier policy: 0..3 primary tiers, with 4..5 only as bounded stress/extension arms;
- minimum depth and upper-volume placement;
- number of ordinary cellular surface rows retained;
- maximum segment span/area/body count;
- segmentation/split policy;
- promotion/desolid hysteresis;
- support-loss, edge, constriction and rotation invalidation;
- exact Water mass/state transfer rules;
- intended collision/contact ownership.

Required scenarios:

1. static shallow tank — must remain ordinary cellular Water;
2. static deep tank — no spontaneous slab/oscillation behavior;
3. dam-break/deep side release — decisive surge/front test;
4. falling solided Water mass into Water — displacement comparison against generic body;
5. generic Rapier body entry — preserve useful splash behavior;
6. body travelling across near-surface tier — observe planing/skimming possibility
   without making it an acceptance requirement;
7. narrow opening/constriction — reject bridge/membrane artifacts;
8. local support loss/hole — force prompt split/desolid;
9. hard-floor/container boundaries — no Water/body teleport;
10. repeated solidify/desolid cycles — conservation, energy and churn stress.

Measure exact Water mass every applicable tick; body/tier counts; promoted payload;
demoted payload; velocity/momentum/energy proxies with declared units/limits;
front position/COM; tier lifetime; wake amplification; Rapier/main-thread work;
native work; split/desolid causes; capacity/refusal; one/four-worker determinism
where relevant.

Exit outcomes:

- promising bounded proof worth a separately authorized production decision;
- useful only for a narrow scenario and retained experimental;
- mechanically plausible but too expensive/unstable;
- no-go because floor reaction/slab artifacts dominate;
- blocked because the generic hybrid substrate is not ready.

No outcome silently edits ADR-005 or adopts the candidate.

## WEX-003 — lumped gas-region feasibility

This may run independently of WEX-002.

Start with architecture research and a small off-production proof if justified.
Do not integrate a production atmosphere system by default.

Minimum proof cases:

1. sealed static room;
2. volume compression/decompression with constant gas amount;
3. door/window opening that merges/vents regions;
4. closing that requires split detection;
5. two reservoirs with both headspaces vented;
6. same geometry with sealed headspaces;
7. exterior/vacuum boundary;
8. topology churn and conservative failure/refusal.

Compare at least:

- full-resolution connectivity only where needed;
- coarse/lazy macro-cell connectivity with explicit narrow portals;
- pre-authored room seeds plus dynamic invalidation.

Report complexity, memory, dirty work, worst-case split cost, update cadence and
how off-camera/lazy assessment affects correctness.

Exit may be research-only. A useful cost model with a no-go conclusion is success.

## WEX-004 — conditional decompression-event proof

Execute only if WEX-003 explicitly admits it.

Use generic region pressure differences to create a bounded event, not cellular gas.
Test whether a local occlusion-aware impulse approximation can move:

- loose powder/debris;
- small generic Rapier bodies;
- optional Water/spray where physically sensible;

without global pathfinding every tick or full-room particle CFD.

Measure event work, affected area, momentum/energy budget, obstacle response,
multi-opening behavior, pressure decay and stale-topology cancellation.

Reject a simple magical radial attractor if it ignores intervening geometry badly
enough to break the engine abstraction.

## WEX-005 — evidence synthesis and #45 routing

This is the final extension decision issue.

Inputs:

- WEX-001;
- WEX-002 or an explicit blocked/no-go disposition;
- WEX-003;
- WEX-004 if admitted;
- merged #49 corrected successor apparatus;
- current #45/#14/#18 authority;
- current #12 hybrid ownership state.

It must answer separately:

1. Did generic hybrid coupling materially improve the owner-observed deep-release
   surge problem?
2. Are Water sheet tiers worth further production work?
3. Is an explicit saturated-head Water mechanism still required for intended engine
   scenarios?
4. Under what boundary assumptions is the corrected communicating-head fixture a
   valid acceptance control?
5. Is compartment pressure useful enough to warrant production integration, or
   retained as research?
6. Is decompression worth a later production issue?
7. Does #18 directional memory now have a concrete unmet target, or should it remain held/no-go?
8. What exact #45 disposition follows: proceed, narrow, recharter, defer or no-go?

A selected production migration requires a new/revised explicit implementation
authority. WEX-005 itself does not smuggle experimental code into Current.

## Autonomous issue execution contract

Every WEX child issue must contain this execution discipline or reference this
section plus the required issue-specific reading.

Before changes:

1. Fetch authoritative `main`; do not rely on the creation-time SHA.
2. Read root `AGENTS.md`, this programme, current Water/soliding/coupling contracts,
   the named ADRs and the issue's required evidence.
3. Inspect active branches/PRs/owners and actual write sets. Do not create duplicate
   implementation ownership.
4. Reconcile newer landed work before branching.
5. Register experiment question, controls, source/runtime identity, fixtures,
   acceptance/no-go criteria and capacity limits before candidate code.

During work:

- keep historical evidence immutable;
- retain negative/ambiguous results;
- preserve exact control binaries/identities where comparisons require them;
- do not weaken a fixture after seeing candidate results;
- distinguish native runtime, cross-build, Godot runtime, real browser/render and
  target-hardware evidence;
- stop on genuine ownership/authority collision rather than rewriting another lane;
- if the required generic hybrid substrate is absent, record the precise blocker
  instead of creating a duplicate backend.

Completion:

1. Run focused affected tests first.
2. For runtime/native changes run the applicable Native C++, sanitizer where relevant,
   GDExtension/Godot and documentation/provenance gates on the exact PR head.
3. For documentation/research-only changes run the repository-documented
   documentation, provenance, M11/history, retrieval and diff gates.
4. Open a focused PR with exact source/evidence identities and explicit limitations.
5. Repair only in-scope failures; stop and record unrelated blockers.
6. Merge only after required exact-head automated checks pass and current authority
   still permits the merge.
7. Verify the merge commit actually landed on `main`.
8. Update the WEX parent/RAG and all directly affected existing issue routing.
9. Close the child only when its stated research/implementation acceptance or
   evidence-backed no-go disposition is genuinely satisfied.

## Plan review and improvements applied before publication

The programme was critically reviewed before issue creation. The following changes
were made to the initial discussion concepts:

- replaced boundary-wall "travelability trace" as the room invariant with
  connected-gas-space topology;
- changed one-byte pressure from proposed authoritative room state to optional
  derived/cache state, retaining enough amount/volume information for merge/split;
- narrowed Water soliding from possible core/full-depth layers to at most roughly
  3-5 upper-volume segmented tiers, with three primary qualitative tiers;
- made exact fractional Water mass transfer an explicit hybrid requirement;
- separated current generic-body characterization from the later sheet proof so
  the good splash and bad floor penetration are frozen before architecture changes;
- made #49 parallel/independent rather than duplicating its apparatus scope;
- changed #45 from an assumed implementation step to an evidence-consuming
  architecture disposition that may legitimately defer/no-go;
- separated compartment pressure from Water bulk-head transport;
- separated optional decompression from the gas-region proof and made it conditional;
- rejected a barrel-specific support subsystem;
- kept player/gameplay feel outside the primary gate while retaining physics and
  integration quality as mandatory engine concerns;
- retained existing FreeMass/CellularYield separation rather than assuming liquid
  unification;
- avoided starting broad #84/#85/#86 remediation here; only current authority
  corrections needed to prevent wrong implementation routing belong in this checkpoint.

## Issue index

The GitHub issue numbers are populated after creation. Until then the stable keys are:

- WEX-000 — programme tracker;
- WEX-001 — current generic Rapier↔Water baseline;
- WEX-002 — bounded upper-volume Water-sheet proof;
- WEX-003 — lumped gas-region feasibility;
- WEX-004 — conditional decompression-event proof;
- WEX-005 — evidence synthesis and #45 routing.
