---
title: CyberSand architecture synthesis and experimental programme
status: Planned
document-kind: design
scope: Evidence gates for Cell representation, liquid state and transport, presentation, and conditional sparse motion; no production architecture selection
canonical-for: [architecture-experimental-programme]
last-reviewed: 2026-09-13
related-documents: [architecture-programme-source-ledger.md, physics-characterisation.md, physics-characterisation-plan.md, ../decisions/ADR-005-water-model.md, ../decisions/ADR-007-rigid-body-cellular-coupling.md]
---

# CyberSand architecture experimental programme

## Issue 12 / G-R scoped admission, 2026-09-13

The combined source baseline is `f32faa93cbaaef08f7eb8cf9d5e445e9113db73c`, merging
current main/#19 and accepted #11. The #11 support prerequisite remains satisfied
only in its documented ordinary rectangle/load envelope. Registered candidate and
stationary evidence supports [ADR-012](../decisions/ADR-012-bounded-soliding-ownership.md).
After an independent Sol challenge, Astra admits one isolated manual-step near-rest
Wall aggregate, with native payload authority and a symmetric topology fence.

For #14, **G-R admits only this bounded proof** and consumes its dated ownership,
conservation, capacity and negative results. It does not adopt a production
representation ladder, satisfy G-final, admit #18/#20, or imply human H occurred.
Dynamic asynchronous/gameplay integration remains Deferred. Final tested results
and any remaining review/platform gaps are in [issue 12 evidence](../audits/2026-09-13-issue-12-soliding.md).


## Integrated source qualification, 2026-09-13

**Current source:** merged #19 uses the eight-byte `detail::PrecisionStorage`
carrier (`World::Chunk::Cell`), with default mass8/coherence12 semantics. Older
four-byte baseline statements describe the programme reference or dated intake,
not the physical storage in this checkout. This inherited experimental carrier
is not a G-final production-layout choice and is not a new #12 packing migration.

**Current #11:** source `d5f0de687283ec366ed4ff33160a274e2a35ddc6` repairs
masked-source authority, barrier/body-aware ejection and ordinary rectangle bearing.
The #11 support prerequisite is satisfied within the documented ordinary
rectangle/load envelope. Earlier intake defect/issue-state claims below are
historical and are superseded by the [repair evidence](../audits/2026-09-13-issue-11-repair.md).

**Planned programme, not an adopted replacement architecture.** Establish what
useful state costs, what behavior it enables, and where that state should live.
Keep the executable current baseline available throughout. A sound negative
result completes an experiment successfully; ambiguous evidence leaves the
decision open. No Cell migration, solver change, ballistic system, generated
body, promotion, fracture or production integration is implemented by this plan.

The [source synthesis and ledger](architecture-programme-source-ledger.md) records
all four complete conversations, later refinements, rejected alternatives and
repository conflicts. It is the traceability record; this page owns the programme.
Future implementers use the linked prompts without needing those conversations.

## Current staged status, after G-P (2026-09-11)

C/G-C, L/G-L and P/G-P are complete. [Issue17 evidence](../audits/2026-09-11-issue-17-state-precision.md)
retains mass8 and proves Water-specific delay4 equivalence for controlled downstream
budgets. Current4-byte production baseline remains pending G-final. M still needs
a concrete measured motion-target admission; V independent; B blocked; G-final open.
Earlier dated staged decisions below retain their original prerequisite context.

## A. Current relevant architecture and accepted decisions

Intake is local `8f4ffb96e03dc50cb43ab9c84de17ccb44c03774` in
`C:/kybersand/source`. The existing rebuilt Windows DLL is deliberately dirty;
its identity is in the ledger. Remote main is older. Source changes and runtime
evidence from #9/#10/#13 plus September 10 Water work are local baseline inputs,
not silently certified by GitHub issue closure or a profile hash.

| Authority | Relevant baseline |
|---|---|
| CURRENT / VALIDATED within dated fixtures | Native `World::Chunk::Cell` is 4 bytes: 8-bit material, state_a, state_b, updated_epoch. Material state is typed by each material's behavior; temperature is optional persistent chunk SoA state. |
| ACCEPTED / ADR-001/003/007/009 | Native owns material; Rapier owns independent bodies on the main thread. Packed values cross owner boundaries. Separate transient body-ID occupancy is stable during cellular work. Retained immutable render payloads never expose mutable cells. |
| CURRENT with known limitations | Rectangle coupling accepts at most 16 bodies, bounded sweep/ejection, capped central impulses and stale-sample handling. Failed ejection retains material and reports overlap. The #11 repair preserves masked material authority, rejects hard-terrain/body-crossing ejection, and supplies bounded ordinary bearing; general-shape/high-energy scope remains open. |
| ACCEPTED / ADR-002/004/010 | Phased in-place four-phase worker execution; excluded regions pause without catch-up. A failed World is quarantined until reset/replacement; no global transaction/automatic retry. Buffered is not executable rollback. |
| ACCEPTED / ADR-005; CURRENT POLICY | FreeMass Water has exact closed-operation integer conservation and stable equilibrium. Current lateral request is floor(3*imbalance/4), with one-unit tolerance, gravity first, 12-tick coherent delay and supported film at mass <=48/255. |
| CURRENT | Water alone has fractional quantity. Other liquids use whole-cell paths, generally CellularYield; Oil has specialized movement. A mobility roll and scheduler sleep are not an explicit stress/yield model. No generic persistent cellular vx/vy exists. |
| CURRENT POLICY / ADR-011 and #13 | Powder density sorting is excluded, player packing/support is separate, Mercury permeability defaults to period 30. Motion-driven mixing/carrying is opt-in; gameplay Baseline remains disabled. Horizontal candidates 2 and cadence 1 are protected defaults. |
| ACCEPTED / ADR-008 | Explicit bounded approximation does not waive occupancy, ownership, capacity or current conservation contracts. New approximation needs its own measured policy. |

Storage chunk 128², activity block 32², scheduling core 64², and radius-two
expanded write domain 68² are independent units. At 4/8 bytes their cell-only
payloads are respectively 64/128 KiB, 4/8 KiB, 16/32 KiB, and
18.0625/36.125 KiB. These exclude temperature, occupancy, metadata, stacks,
snapshots and allocator overhead and are **not measured cache conclusions**.
Current ordinary liquid writes remain adjacent; transport hooks may reach radius
two. A 64² hard-terrain collider packet is yet another unit.

## B. Decision ledger and authority rules

Use these statuses claim by claim, not one label for a whole workstream:

| Status | Meaning here |
|---|---|
| CURRENT / VALIDATED | Implemented and supported by identified retained evidence, only in its measured scope. |
| CURRENT POLICY | Deliberately selected versioned tuning/behavior; changing it requires new evidence and a policy decision. |
| ACCEPTED / ADR | Explicit architectural authority; experiments cannot silently supersede it. |
| ISSUE-SCOPED | Temporary restriction belonging to an issue, such as #13's no general velocity field. |
| EXPERIMENT | Candidate requiring controlled measurement. |
| OPEN | Unresolved question or insufficient evidence. |
| SUPERSEDED | Earlier claim or preference displaced by identified later reasoning/source. |
| REJECTED | Explicitly declined hypothesis/design, with its rejection scope preserved. |
| DEFERRED | Deliberately postponed, not rejected or already implemented. |

Key dispositions: retain ADR-007; do not place occupancy in persistent Cell.
Conservation flexibility from W is an OPEN proposed revision, not a revoked
ADR-005. Compact history is an EXPERIMENT; neither universally required nor
permanently prohibited. W's bottom-fill-everywhere suggestion is SUPERSEDED by
local oriented reconstruction; its early preference for only transient direction
is refined by the final request to test persistent material-local memory.
I's four-byte preference and D0–D5 sequence remain proposals, constrained by the
later width/state experiments. Native coherent bodies belong to existing #12,
not Current architecture. Fracture/torque/anchors/rebaking stay DEFERRED.

The detailed ledger also resolves two easy misreadings: state_b is Water's
coherence countdown, not a universal calm/stability field; and the source's
epoch-zero reservation makes repeated wrap clears 255 ticks apart, or 63 for
an otherwise comparable 6-bit design, after the first clear at 256/64.

### May extra Cell bits hold occupancy or relax exact Water conservation?

No. **ACCEPTED ADR-007** keeps transient rigid-body occupancy separate from
persistent material state, regardless of spare bits. **ACCEPTED ADR-005** retains
exact closed Water conservation. The programme can investigate deliberately
bounded numerical error only where a candidate demonstrates a reason to need it,
with an exact control, explicit error ledger and later architecture decision.
No experiment silently amends either ADR; shared or missing material ownership
is never numerical approximation.

### What does issue #11 prove for the soliding support gate?

The [2026-09-13 current-source repair](../audits/2026-09-13-issue-11-repair.md)
supersedes the earlier negative disposition while preserving its historical facts.
**#11 support prerequisite is satisfied within the documented ordinary
rectangle/load envelope.** This admits only that support-dependent prerequisite
for #12; it does not approve soliding, promotion/reversal ownership, general
shapes, high-energy impacts or structural behavior. Issue state alone is not
runtime acceptance.

## C. Questions and bounded outcomes

| Key | One meaningful outcome | Live question / why it exists |
|---|---|---|
| C — Liquid characterization | Evidence map and minimum missing measurements for present FreeMass/CellularYield | Which observed behavior belongs to quantity, transport, mobility, special rules or sleep, and which merits changing? |
| L — Layout and epoch cost | Controlled cost/compatibility comparison of current, padded, packed and sidecar layouts | What does raw width cost; what do masks/accessors and epoch frequency add; what state/ID capacity is actually justified? |
| P — State precision | Quantity/auxiliary precision response curves at fixed layout and algorithm | What do 4/6/8/10-bit mass and separately packed delay buy or lose, including active lifetime and films? |
| M — Compact motion | Controlled no-history versus local flow-memory comparison, inline versus sidecar | Can a small decaying direction/strength field improve a named jet/spray deficit with bounded local writes, and at what cost? |
| V — Fractional presentation | Oriented fractional-interface visual/cost comparison on frozen authoritative states | Can existing mass information improve surfaces, underfaces, edges and droplets without new simulation state? |
| B — Conditional sparse motion | Small bounded ballistic promotion/demotion feasibility result, or documented no-go | Is high-speed/event motion still worth a distinct representation after compact-history evidence and transfer design? |
| G — Decision record | Cross-workstream evidence review, retained-baseline or selected next increment | Which measured combination warrants a scoped follow-up and what must remain open? This does not itself implement migration. |

Existing **#12** remains the coherent-body/soliding research owner. This programme
provides a self-contained execution supplement, not a duplicate aggregate issue.
Its diagnostics/design can proceed from existing #9 evidence. The #11 support
prerequisite is satisfied within the documented ordinary rectangle/load envelope.
Dynamic membership still requires an explicit reviewed ownership ADR first.
A near-rest restricted prototype does not need B if it can state its momentum
limits honestly; energetic reversal must wait for a selected motion representation.

## D. Candidate matrix and controlled variables

| Question | Baseline / candidates | Change versus fixed controls | Required measurement |
|---|---|---|---|
| Raw Cell width | Current 4 B; 8 B with four original bytes and four unused bytes | Change stride only. Same semantics, epoch width, geometry, traversal, input, descriptors and compact snapshots. Verify compiler actually emits an 8-byte stride. | Equal content/events/work; tick distribution, ns/visited cell, memory/traffic, worker scaling. |
| Packed access | Packed 8/16/8 control; 16/40/8 with only legacy state used; padded 8 B control | Access arrangement/ID extraction; fixed semantic values, epoch and unused capacity. | Masks/read-modify-write cost, size/alignment, no truncation, generated access path, normalized semantic equality. |
| Short epoch | Packed 8/16/8 versus 8/18/6, extra two state bits unused | Epoch width/clear period only after access cost is known. | Per-clear duration and exact ticks, p99/max, double-update prevention over wraps/sleep/re-entry. |
| Optional state allocation | 4 B plus chunk/block SoA or bounded sparse indexed sidecar versus 8 B inline | First legacy-equivalent storage/access; later identical M semantics and state precision. Same populated positions, lifetimes and work policy. | Zero/1/5/15/50/100% use, clustered versus dispersed use, lookup/move/reclaim cost, total bytes incl metadata and saturated capacity. |
| Material ID headroom | Current 8-bit IDs; 10-bit 10/14/8 alternative; 16-bit candidate | Access cost separated from catalogue expansion. 10/14/8 cannot be a full legacy control unless every material's state is losslessly representable. | Actual catalogue/ID needs and adapter/render/profile/save migration surface. No new material pack loader. |
| Water mass | 8-bit reference; 4/6/10; 3/12 optional only to locate an observed failure boundary | Fixed tested layout, three-quarter local solver, mass-normalized thresholds, no history. Auxiliary delay remains 12 ticks. | Initial quantization ledger, exact integer mass per precision, normalized levelness/front/rest/film, work and timing. |
| Auxiliary precision | Original 8-bit Water delay versus 4-bit representation | Only packing; same 0..12 countdown, max-on-merge, pre-decrement suppression. Other materials retain their own full state range. | Exact behavioral equality and bit access cost. Combined budgets only after isolated results. |
| Yield versus sleeping | Actual Water and representative yield liquids; default quiet threshold 3 versus threshold exceeding fixture horizon | Change sleep diagnostic only; same liquid, viscosity, scene and input. Zero is invalid, not a sleep-disable option. | Late mobility failures, eligible attempts, active-block time, residual slope and wake response. |
| Flow memory | No history versus small direction/strength/age; inline versus sidecar | First fixed mass precision, solver and layout; next same memory semantics across storage. No new pressure/velocity solver. | Jet COM/range/asymmetry, split/merge/decay accounting, rest, active lifetime, CPU/memory. |
| Presentation | Current stable dither/binary view; fractional coverage; local-gradient oriented interface | Same frozen mass frames and simulation inputs. Optional render flux only as separately measured second stage. | Area error, seam/orientation artifacts, temporal flicker, CPU/snapshot/upload/GPU cost. |
| Sparse motion | Selected local/history control; bounded native pool with position/velocity/material/state | Matched event input, mass and environment. New representation explicitly changes semantics, never labeled a layout benchmark. | Trajectory/range, swept barrier contact, singular owner, refused reinsertion, conservation, peak pool/queue/scratch and time. |

No full Cartesian product is required. Screen isolated variables, reject dominated
or unsafe candidates, then compare only interactions whose independent results
justify them. No 16/32-byte universal baseline, full velocity field, broad liquid
unification or geometry resize is created merely because it appeared in discussion.

## E. Cross-workstream dependency and conflict matrix

| Cross-link | Constraint / evidence flow |
|---|---|
| L → P/M and P/M → L | Measure representation tax before spending capacity; measured useful state then tells whether universal width or sparse state pays. A raw benchmark does not select a solver. |
| L ↔ geometry | Keep 128/32/64/radius-2 fixed for width screen. A 64² storage-chunk experiment is a separate registered interaction only if cache evidence warrants it; never quietly shrink scheduling cores or halos. |
| C → P/M/V | Reuse measured fronts/rest/films and attribute special cases before testing precision/history/reconstruction. Retained #9/#13 are not complete sleep/precision studies. |
| Quantity ↔ algorithm | Partial quantity does not mandate equalization; equalization does not justify all liquids becoming fractional. Generalization needs unlike-liquid capacity, density and reaction source/sink contracts. |
| C/P/M ↔ #10/#13 policy | Keep Mercury period 30, powder/player policy and protected profile defaults. Compare intentional Water/mixing deltas separately from regressions; changed flux can change pickup without any profile change. |
| Occupancy ↔ L/M/B/#12 | Derived body mask remains outside Cell. Adding bits changes neither Rapier ownership nor material authority. Body/event velocity is a possible motion source, not generic cell state. |
| M ↔ B | Local decaying memory can address directional persistence without continuous coordinates; high-speed travel may still need sparse promotion. Neither evidence result logically settles the other requirement. |
| B ↔ L | Sparse motion may avoid ubiquitous state but adds pools/lookups/transfer cost; wider cells may simplify state transfer but do not provide continuous trajectories. Measure density crossover. |
| #12 ↔ B/M | Energetic demotion needs an explicit motion carrier; near-rest restriction may avoid it. Preserve payload/mass/temperature and parent v + omega cross r if inheriting rigid motion. |
| #12 ↔ coupling/terrain | Terrain collider removal, dynamic activation and endpoint mask installation need acknowledged topology handover; ordinary aged transform samples cannot authorize it. |
| V ↔ P/M | Rendering may use existing normalized mass; it does not block on wider cells or motion adoption. Only after M shows useful history should V test exposing a narrow derived field. |
| Error policy ↔ every transfer | Exact current Water oracle stays intact. Candidate drift must have explicit numerical budget and benefit; ownership loss/duplication is never classified as numerical approximation. |

## F. Regression baselines and retained evidence

Use the [ledger's checkpoint table](architecture-programme-source-ledger.md#repository-intake-and-evidence-reuse)
and the canonical [physics runbook](physics-characterisation.md). Do not commission
another #9 audit. C first extracts existing results; it instruments/runs only
unanswered cases. New candidates later require focused source-matched comparisons.

| Baseline / actual touchpoints | Required preservation or explicit delta |
|---|---|
| `native/tests/test_world.cpp`: conserved_water_levels_and_sleeps, water_surface_column_mass_is_level, water_conserves_across_storage_boundaries, water_lateral_front_and_leveling_speed | Exact closed integer totals, stable content after rest, current front/level bounds, signed seams and one/four-worker parity. Use content_hash for rest, not advancing state_hash. |
| `native/bench/water_leveling.cpp`, `tools/physics/water_leveling.py`, September 10 audit | Current three-quarter and historical half controls are distinct. Reuse 48/96-wide, shifted/mirrored basins; initial 97,920 mass is that fixture, not a universal constant. |
| `native/bench/transport_characterisation.cpp`, `tools/physics/issue13.py`, transport_matrix/report/knobs/permeability | Baseline/Gentle/Erosion, sustained/sparse release, films/barriers, successful-motion counts and Mercury packed/poured/powder references. Do not replay known erroneous injector/erosion-depth measurements. |
| `native/bench/physics_characterisation.cpp`, `godot/tests/test_physics_characterisation.gd`, `tools/physics/water-accounting.json` | Stored material versus masked proxy, crop outflow versus world loss, contact saturation, barrier-aware ejection failure as known control. |
| `godot/tests/test_interaction_policy.gd`, `test_interaction_async.gd`, `test_transport_probe.gd` | Player support, real void collapse, indirect Mercury changes and distinct desktop/native Web/fallback scope. |
| Native failure/region fixtures and `godot/tests/test_render_patch_handoff_regression.gd` | Quarantine, no partial success publication, exclusion/re-entry, immutable delayed-consumer payloads, no catch-up. |

Water films/spray and state/temperature preservation already have tests; use
their existing fixture bodies. New scenarios are limited to missing sleep
isolation, precision error, epoch-tail/sidecar density, directional jets,
oriented frozen frames and bounded promotion failure cases. Serial and fallback
are alternate semantics; do not require their bytes to match phased native.
Native/Wasm current state hashes include platform-width fields; compare normalized
semantic records across ABI rather than claiming cross-ABI full-hash equality.

## G. Measurement protocol

Before candidate implementation, commit a small experiment registration: question,
variants, semantic comparator, selected seeds/scenes, physical units, fixed knobs,
run horizon, capacity limits, instrumentation cost check, primary metric and gate.
Use fresh worlds and pinned release builds. Record source HEAD plus delta,
compiler/flags, CPU/OS, artifact/profile hashes, worker count and exact commands.
Do not measure while other builds run. Keep raw logs in
`C:/kybersand/validation/local/<dated-experiment>/`; retain compact tables and
interpretation under source documentation. Missing PMU/GPU counters are named
gaps, never estimated misses presented as measurements.

Default bounded screen: 5 deterministic seed/translation cases, 1 and 4 workers,
1,800 fixed ticks for behavior; epoch tests at least 2,048 ticks with sleepers
and retained inactive chunks. Performance uses 7 interleaved baseline/candidate
process pairs after a declared 120-tick warmup in the steady workload; startup
and initial settling are measured separately. Registration can reduce redundant
cases using retained evidence, with reasons recorded before candidate results.
Finalists use up to 20 seeds/7,200 ticks only for a specific unresolved long-tail
or drift concern, not an automatic broad campaign.

**Performance:** p50/p95/p99/max microseconds per completed tick and total cost;
ns/visited cell; processed/visited distinction; aggregate active blocks and actual
visited-cell ticks (do not relabel blocks*1024 as exact active cells); successful
transfers/writes/lateral probes; scheduled cores and worker scaling; wake/sleep
churn; epoch clear duration/frequency; cell/sidecar/metadata/snapshot bytes and
total process memory; preparation versus worker allocation, pool high-water and
overflow; stage times/cache/bandwidth where instrumented. Separate render upload,
coupling and full frame pacing from core tick timing.

**Behavior:** exact material ledger and explicit reaction/ROI source/sinks;
normalized Water column-mass spread and levelness; front/discharge/spread;
content-stable time and residual work; supported-film lifetime and tiny residues;
jet range/COM/direction persistence; spray size distribution; species interface
mixing/transport/deposition; penetration/barrier/overlap results; repeat/parity;
render coverage error and temporal artifacts. For B/#12 account for material in
cells, promoted pool/membership, retained pending owner and explicit outputs.
Record momentum separately from intentionally decaying bias.

Research screening defaults (new programme proposals, not existing physics policy):
flag >15% paired p95 core cost regression, >1 ms additional epoch-clear excess
over neighboring ordinary ticks, or unbounded active lifetime for explicit review.
For M/B register a concrete target such as directional COM displacement/range
and a minimum useful improvement before runs; there is no evidence-backed universal
jet-distance target yet. If no target can be justified, return no-go at admission.
Report paired distributions/ranges and measurement noise, not just one percentage.
These flags do not prove a candidate unacceptable for every feature; G compares
benefit and whole cost. A changed budget is a new registered experiment, not a
post-hoc waiver. No production migration is authorized by passing these screens.

## H. Dependency graph

Logical keys were defined before new issue numbers. Solid prerequisites consume
evidence; conditional branches must have a recorded admission or no-go outcome.

```text
Current source + retained ADR/#9/#10/#13/Water evidence
          |                              |
          v                              v
 C: characterize missing facts     L: isolate layout/packing/epoch cost
          | evidence                     | evidence
          v                              v
 G-C: admit a behavior question     G-L: valid equivalent-semantics comparison
          |                   \          /
          |                    v        v
          |                   P: precision / auxiliary allocation
          |                              | evidence -> G-P
          v                              v
 V: frozen-frame presentation      M: local memory, inline vs sidecar
          |                              | evidence -> G-M
          |                              v
          |                        G-B admission: unmet motion requirement?
          |                          | yes                  | no
          |                          v                      v
          |                     B: bounded proof       recorded no-go
          |                          | evidence              |
          +--------------------------+-----------------------+
                                     v
                         G: architecture decision record
                         /             |                 \
               retain baseline    bounded next test     selected migration
               or defer           with new charter     separately scoped later

 Existing coherent-body research:
 retained evidence -> #12 candidate/design stage -> ownership ADR gate
                     -> conditional near-rest prototype
 support prerequisite satisfied only for the #11 ordinary rectangle/load envelope
 energetic reversal requires selected M/B transfer capability, not a ladder
```

V uses C's documented mass/presentation cases and can run alongside L/P.
M waits for L/P to avoid spending unknown capacity. B initially owns only
admission/transfer design; code is conditional on G-B. G is one decision issue
with staged gate entries; its final disposition waits for every admitted branch
or explicit no-go/defer record. #12 is linked context, not a required finish
before a Cell/liquid decision, and does not block C/L/P/V.

## I. Decision gates and conditional work

| Gate | Evidence required | Allowed next step / negative branch |
|---|---|---|
| G-C | Extracted #9/#10/#13/current evidence, exact specialization map, missing sleep/film/flow answers, identified behavior target | Admit P/M/V. Retain separate liquids if no demonstrated need. Quantity/transport generalization or genuine yielding gets a narrowly chartered later issue only for a specific gap. |
| G-L | Semantic equality for stride/access comparisons; epoch differences isolated; wrap safety; full memory and hardware scope | Use candidate layouts as experimental controls. Reject broken packing, retain alternatives; no layout adoption. |
| G-P | Exact per-precision accounting, normalized versus one-unit-threshold separation, retained delay and non-Water range safety | Select state budgets for M or retain 8-bit mass. If precision effects are ambiguous, M uses reference precision. |
| G-M | Named useful motion gain, bounded decay to stable equilibrium, split/merge semantics, cost and storage-density crossover | Retain no history, test viable memory, or admit a distinct high-speed B question. Quantized vx/vy is a later experiment only if cheap memory cannot meet a defined need. |
| G-B | Specific high-speed/body-event use case; comparison versus M/current path; reviewed singular-owner transfer charter; predeclared pool/collision/reinsertion limits | Execute small proof or close B with no-go. No automatic conversion of all failed ejections; no new body system required. |
| G-R for existing #12 | Verified support prerequisite where needed; reviewed ownership ADR; retained source state until capacity/geometry/terrain readiness acknowledgement | One coherent island/one barrel near-rest proof. On failure or missing support evidence remain in design/diagnostics; no deletion or self-collision gap. |
| G-final | Comparable L/P/M/V plus B evidence or no-go, relevant #12 findings, policy/compatibility/platform impacts, remaining uncertainties | Publish retain/defer/next-test/conditional-migration decision. Create a separate production migration issue only with a selected candidate, full prompt, ADR delta and compatibility plan. |

If generalizing FreeMass is admitted later, first specify quantity transactions:
partial unlike liquids sharing/replacing cells, density interpretation, reactions,
product amounts, displacement, films, ledger units and source/sinks. Test one
nonreactive analogue before reactive liquids. If testing genuine yield, vary
yield eligibility independently from lateral mobility and scheduler sleep;
retain current Paste/Slush as controls. Neither branch requires unification.

If an alternative needs numerical drift, register mass error (absolute/relative,
per-operation and accumulated), horizon and benefit before code. Preserve an exact
control and distinguish explicit pruning from rounding and from bugs. ADR-005/008
may only change via an explicit decision; extra state alone is no reason to relax
conservation. These are conditional extensions, not uncreated mandatory backlog.

## J. Integration gates

Changing Current policy requires a separate reviewed decision with scenario-based
benefit, honest negative evidence, representational total cost, supported target
hardware and preserved invariants. Required affected-platform coverage is native
core, desktop asynchronous owner and real Web compatibility/threaded profiles;
document fallback scope deliberately. Check snapshot lifetime and bounded queues
where interfaces change. No visual-only win can waive conservation or ownership.
No raw timing result revises ADRs. Missing target-device/performance evidence
means experimental status, even if native correctness passes.

Any selected ID/state layout migration must inventory C ABI, adapter packets,
material tables, 81-entry profiles/pair matrices, RG8 ID encoding, palette lookup,
hash schema and CYSD1 compatibility. Preserve existing saves or introduce a
versioned converter with explicit refusal of unsupported states. Do not serialize
compiler struct bytes or claim complete replay. Narrow render-derived snapshots
can remain independent of simulation width; 16-bit IDs still need an explicit
render encoding decision before deployment.

For B/#12: define owner before/during/after transfer, state/quantity/temperature,
identity/generation, motion units/inheritance, deterministic order, capacity,
collision/overlap, failure/deferral/cancel/retry, region exit/re-entry and the
chosen save/load boundary. Preflight and reserve destinations before removing
source authority. Reservation is not dual ownership. Do not infer global rollback
from a local transition protocol. Failed ticks continue to use ADR-010 quarantine.

## K. Baseline, rollback and comparison strategy

Keep intake source and each experiment as recoverable commits/branches, with
reference fixtures and full registered input identity. Build candidates separately;
never overwrite the only reference executable or the owner's loaded DLL. Preserve
the intentional dirty DLL and all unrelated work. Raw outputs stay in the active
workspace; `C:/cybersand` remains the functional-deliverables directory.

Use fresh-world A/B selection or distinct binaries, not unsafe live state-layout
switching. Normalize layout-specific state into semantic records for comparison;
epoch-shortening variants intentionally differ in raw bookkeeping but must retain
equivalent material behavior. Keep observer-off controls so instrumentation cannot
silently become the improvement. Preserve failed and ambiguous runs. If a candidate
loses, retain the control and close its experiment with the evidence; do not
generate a migration by momentum. Serial, fallback and unavailable Buffered are
not interchangeable exact rollback implementations.

## Issue and prompt index

The programme above was written before creation. The index records actual
GitHub issues and locally durable prompts after a second overlap check.

| Key | Issue | Self-contained prompt |
|---|---|---|
| C | [#15: Architecture experiment: characterize FreeMass and CellularYield from retained evidence](https://github.com/techrote/cybersand/issues/15) | [Liquid characterization](architecture-programme-prompts/liquid-characterization.md) |
| L | [#16: Architecture experiment: isolate Cell layout, packing, sidecar and epoch costs](https://github.com/techrote/cybersand/issues/16) | [Layout and epoch](architecture-programme-prompts/cell-layout.md) |
| P | [#17: Architecture experiment: measure liquid state precision at fixed layout and semantics](https://github.com/techrote/cybersand/issues/17) | [State precision](architecture-programme-prompts/state-precision.md) |
| M | [#18: Architecture experiment: compare compact liquid flow memory inline and in sidecars](https://github.com/techrote/cybersand/issues/18) | [Compact motion](architecture-programme-prompts/compact-motion.md) |
| V | [#19: Architecture experiment: reconstruct fractional liquid interfaces without changing simulation](https://github.com/techrote/cybersand/issues/19) | [Fractional presentation](architecture-programme-prompts/fractional-presentation.md) |
| B | [#20: Architecture experiment: gate and test bounded sparse ballistic material transfer](https://github.com/techrote/cybersand/issues/20) | [Sparse motion](architecture-programme-prompts/sparse-motion.md) |
| G | [#14: Architecture decision: reconcile Cell, liquid and sparse-motion experiment evidence](https://github.com/techrote/cybersand/issues/14) | [Decision review](architecture-programme-prompts/decision-review.md) |
| R | Existing [#12](https://github.com/techrote/cybersand/issues/12), reused | [Soliding supplement](architecture-programme-prompts/soliding-supplement.md) |

Seven new boundaries are justified: two independent initial evidence questions,
precision before semantics, one compact-history question, independent presentation,
a separately gated sparse-motion proof, and the decision that consumes evidence.
Keeping ballistic and history distinct prevents a continuous-motion algorithm
from masquerading as state-layout cost. A decision issue is separate from code so
measurements do not silently adopt policy. Existing #12 prevents a duplicate
coherent-body backlog. D0–D5, general yield/reactions, registry expansion, torque,
fracture, anchors, rebaking and streaming are not automatically issued.

## Final quality and documentation gate

Review the [ledger](architecture-programme-source-ledger.md) and every prompt for
the user's 30 requirements: full four-source trajectory; Current/proposal and
ADR/issue-local distinctions; occupancy/material separation; no external-source
reanalysis or mandatory ladder; independent width/packing/epoch/precision/solver;
independent geometry; characterizing both liquids; conservation and retained
physics policy; cross-dependencies, negative/ambiguous/no-go outcomes; master
before issues and overlap check; self-contained prompts; conditional downstream
work; bounded ownership/determinism; no production edits.

Documentation synchronization: programme owns only future research, with ledger
and prompts excluded from ordinary Current answers. Navigation, roadmap and
retrieval manifest route to it. Existing subsystem/ADR/runtime/evidence claims
are unchanged. Run documentation, historical M11, repository, frozen retrieval,
supplementary programme questions and diff checks; report inherited provenance
failures separately. No physics/runtime campaign is needed for this planning-only
change. Final issue readback, link/section/dependency checks and source-scope
inspection complete this task. The [planning execution report](../audits/2026-09-10-architecture-programme.md)
records created issues, exact remote/dependency readback, manual quality review
and separate documentation/retrieval versus inherited publication-check outcomes.

## G-L staged decision, 2026-09-11

**G-L: COMPLETE / evidence admitted.** Recorded by Codex from verified result
`4726f8d0fae72f959926a47ab37f7244e9399638`; this is a staged review under
[#14](https://github.com/techrote/cybersand/issues/14), not invented owner approval
or the final architecture decision. The [complete retained L evidence](../audits/2026-09-10-issue-16-cell-layout.md)
and [registration](cell-layout-experiment.md) preserve positive, negative and
ambiguous results, including rejected preparation and all cost flags.

**Retain the current layout as the experimental/production baseline pending
G-final. Retaining the current Cell as the baseline is a programme control
decision pending G-final, not a permanent architectural selection by Issue #16.**

- Current 4-byte Cell remains the baseline. L1 doubles Cell arrays at 8 bytes
  (sleeping fixture 72.25 to 144.5 MiB), with workload-sensitive penalties;
  sleeping one-worker median paired p95 rises 15.04%.
- Packed controls establish valid experimental carriers, with modest or adverse
  access costs and no universal production winner. Optional SoA/sparse carriers
  remain evidence/tools for later real payloads and semantic features; their
  density-dependent memory crossovers accompany active-access costs.
- Shortened epoch is not selected: 32 versus 8 all-resident clears over 2048 ticks,
  sleeping p99 3.81–3.99 times the 8-bit control. No epoch or scheduler change.
- Wider IDs are deferred for lack of demonstrated demand: 175 byte codes remain;
  ABI, rendering, profiles, saves and state-carried IDs require broader migration.
- Generic 10/14/8-style state compression is not admitted as lossless current-state
  equivalence. L6 geometry remains non-admitted; no locality evidence supports it,
  clear cell count is unchanged, and the large reservation would exceed capacity.
- No production migration, Cell width selection, sidecar API, storage geometry,
  ID expansion or other architecture change is authorized.

Limits remain one Windows host, pinned Clang/toolchain, no PMU/cache/bandwidth
capture, no fresh Linux/Wasm/desktop/Web migration acceptance, incomplete
allocator/OS allocation attribution, and L4's neutral four-byte payload instead
of a real production feature. Strided placement and tiny-worker-batch noise also
limit generalization. A negative result successfully completes the experiment.

At this G-L-only checkpoint, #17's remaining formal prerequisite was #15/G-C;
the subsequent G-C decision below resolves it. Its fixed
experimental carrier isolates precision; production width remains outside P's
authority. #14 stays open for G-final. [Reconciliation identities](../audits/2026-09-11-programme-gate-reconciliation.md)
separate the documentation checkpoint from experimental source and raw evidence.

## G-C staged decision, 2026-09-11

This records the C review before P execution. The later [G-P decision](#g-p-staged-decision-2026-09-11)
completes #17 and satisfies M's precision prerequisite; its target admission remains required.

**G-C: COMPLETE / evidence reviewed.** Recorded by Codex after G-L and #16
reconciliation, from verified #15 result `cdb4c2a6df0248c76e7957fd09cae77655ec974f`.
The [complete acceptance matrix](../audits/2026-09-11-issue-15-coverage.md) and
[characterization summary](liquid-characterization.md) retain all11 liquids,
source-matched #9/#10/#13/current Water reuse,352 behavior and224 timed processes.
No new measurements are needed and no remaining gap blocks this scoped gate.

**Findings:** current specialization explains Water quantity/adhesion/emission,
Oil's protected motion, Mercury's separate permeability, and material reaction
state/order. Controlled quiet3/4096 comparisons establish scheduler-dependent
rest for Brine/Paste/Slush/Mercury in the support fixtures; failed deterministic
mobility, material cadence and genuine stable Water rest remain distinct.
Every tested Water trajectory is unchanged by the sleep threshold. The96-wide
418..435-unit residual remains active at1800; narrow46-unit rest and48-unit film
remain stable. This rules out that quiet threshold within the measured horizon,
not finite-time relaxation, threshold effects or precision as competing causes.

| Downstream work | Reviewed disposition and reason |
|---|---|
| #17/P | **Unblocked by C and L.** Admit the existing fixed-carrier normalized mass4/6/8/10 and separate delay4/8 diagnostic for residual, films, front/rest/work. Initial quantization, physical threshold normalization and longer-time completion stay distinct. No lower-precision win is expected or required; a negative result is valid. No Cell-width authority or implementation here. |
| #18/M | **Implementation held.** C shows no measured unmet jet/spray target. Still waits on #17/G-P and a concrete directional-persistence target/no-go review; no automatic history admission when P closes. A later named deficit may justify bounded research. |
| #19/V | **C prerequisite satisfied; independent research remains justified.** Stable film/basin authority supplies frozen cases for existing orientation/coverage/cost comparisons. C supplies no visual-benefit or renderer acceptance result. No production layout selection is required; no render migration is authorized. |
| #20/B | **Still blocked by #18/G-M and G-B admission.** No ballistic implementation or admission follows from C/L completion. |
| General liquid unification / quantity / yield | **Deferred / not admitted.** Reaction quantity units, desired material rest and a specific unwanted behavior are missing; distinct current semantics remain. No universal FreeMass or new general yield solver. |
| G-final / #14 | **Open.** Staged C/L review is not final architecture or owner migration approval. |

No production Cell widening, velocity/history, sidecar, solver/default change or
instrumentation integration is authorized. The diagnostic4096 quiet threshold
buys no Water improvement and incurs substantial scheduled work;85/112 timing
pairs flag review. Preserve all tails and semantically neutral but cost-uncertain
observer/source controls. Limits: one Windows core host/pinned compiler,
five translations/registered geometries, no new desktop/Web/Linux/sanitizer or
migration acceptance, incomplete process/PMU/GPU and exact wake/write attribution,
no heap-scale stress law or new chemistry units. These limit future admission;
they do not invalidate successful characterization.

## G-P staged decision, 2026-09-11

**G-P: COMPLETE / evidence reviewed.** [Completed P1/P2/P3 evidence](../audits/2026-09-11-issue-17-state-precision.md)
and [registration](state-precision-experiment.md) use one fixed8-byte 16/40/8-class
carrier, epoch8 and unchanged local Water algorithm. All1328 behavior processes
conserve exact per-arm integer quantity; worker/repeat and Water delay4/8 comparisons
pass. Eight supplementary concurrent-worker configurations pass. All392 timing
processes and36 extended verification processes are retained; no failed runtime or
candidate rescue. Windows/native-only evidence, with shared-desktop timing limits.

**Result: retain mass8 as the reference experimental quantity budget.** Coarse4/6
retain films but lose meaningful levelness/discharge and erase1/255,2/255 inputs at
initial quantization. Mass10 improves narrow levelness modestly and extends active
work, while leaving the wide finite-horizon residual near mass8. Lower precision's
apparent speed mostly reflects reduced work/early stalls; no Cell byte saving exists.
P2 shows4/6 normalized-zero versus literal-one tolerance gives identical trajectories;
10-bit literal-one improvements belong to threshold policy and add narrow/ledge work.

Water coherent delay4 preserves every existing0..12 value, max merge, pre-decrement,
creation/reset and movement semantic. **Mass8 + delay4 is a Water-specific12-bit
semantic budget for subsequent controlled research**, not generic state compression.
Other materials retain full-byte state. Delay4 has no demonstrated speed benefit
inside this fixed carrier. The G-P result selects, at most, an experimental state
budget for downstream controlled work. It does not select a production Cell layout
or authorize production Water migration.

| Work | Disposition after G-P |
|---|---|
| #17/P | Complete: all main mass, separate threshold and delay arms have reviewed accounting, behavior and cost results. |
| #18/M | Precision prerequisite satisfied. Implementation still requires a concrete measured directional-persistence target and its own G-M admission; no target is invented by P. This is a controlled experimental budget for evaluating motion/history semantics, not a production Water precision migration. |
| #19/V | Independent frozen-authority presentation work; useful P frozen states may be supplementary inputs only. |
| #20/B | Still blocked by M/G-M and separate ballistic admission; no implementation. |
| #12 | Independent near-rest/coherent-body design path remains unchanged. |
| #14/G-final | Open; no final architecture selection or production approval. |

No permanent width/epoch/ID selection, sidecar, velocity/history, scheduler change,
liquid unification, relaxed conservation or production migration. No fresh
Web/Linux/Godot/PMU/GPU, general reactive accounting or visual acceptance is inferred.
