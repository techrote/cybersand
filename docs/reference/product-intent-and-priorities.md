---
title: Product intent and priorities
status: Current
document-kind: reference
scope: Approved owner direction and deliberately preserved behavior; not current implementation or performance evidence
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-10-24
related-documents: [status-and-roadmap.md, ../decisions/ADR-008-bounded-approximate-fidelity.md, ../operations/microscenarios-programme.md, ../operations/water-hybrid-pressure-extension-programme.md]
---

# Product intent and priorities

This page carries forward owner direction recorded in the
[pre-rewrite handover](../audits/pre-rag-rewrite-2026-09-08/cybersand-codex-development-handover.md.txt)
at checkpoint `126175c`. It preserves intent separately from source and dated
validation; later approved decisions should update this canonical reference.

## Should all actors use Rapier physics?

**Approved owner direction (2026-10-18):** adapt or reimplement the entire actor
roster as physical Rapier objects, including articulated mechanisms where their
behaviour needs them. Exceptions require a specific impossible physical
behaviour/configuration and documented justification. Sampled rigs remain
labelled comparison controls during migration. See the
[physical actor programme](../operations/physical-actor-programme.md) for scope,
conversion sequence and preserved actor-specific notes. ACT-004 now supplies
[physical definitions for all 29 actors plus twelve extras](../systems/physical-actor-rigs.md),
with actual joints, scripted feedback and shared controls. The initial hull
trials remain reference arms.

**Owner fidelity clarification, 2026-10-18:** plausible gameplay may use bounded
gyro assistance, approximate joints, intentional compliance and controlled
flex/play. Finite gyro momentum accounting and perfect connection kinematics
are not requirements. Source-level implementation and headless tests do not
establish owner feel acceptance.

## What are we building toward?

**Approved owner direction:** a reusable native pixel-material simulation engine,
initially demonstrated by the material lab and intended for cyberpunk RPG and
exploration settings. Future locations may include underground/urban spaces,
vehicle interiors, orbit and vacuum. Those settings are product direction, not
claims of implemented streaming, orbital mechanics or vehicle systems.

Priorities are stable interactive pacing, meaningful material interactions,
reusable engine boundaries, visually rich materials, observable bounded
behavior under load, exact engineering comparisons and recoverable checkpoints.
60 FPS is a product target; it is not a performance guarantee established by
headless fixtures or a particular worker count.

## Procedural generation direction, 2026-10-18

**Approved owner direction:** create procedural chunk-generation framework/engine
candidates that support on-demand interconnected worlds, specific theme subsets
and supersets, and blends between them. Authoring should combine broad spatial
brushstroke guidance with fine tunable parameters, hard overrides and extensible
algorithmic hooks for complex architectural or computationally advanced zones.
The intended result is an engine foundation with reusable control/module
boundaries, not a single fixed generated level.

GEN-001 / [#163](https://github.com/techrote/cybersand/issues/163) supplies the
[current native candidate and preview-workbench scope](../systems/procedural-world-generation.md).
Its source, integration and platform evidence remain separate from product
acceptance and from the existing general World streaming/persistence roadmap.

### Fields, sidechains and context-aware authoring — 2026-10-18

**Approved owner extension:** add space-filling curves, structured noise, masks
and sidechains, masked modifiers, simple aggregate-material definitions and
context-aware generation guidance, sculpting and manipulation. Controls should
compose through reusable bounded interfaces and preserve explicit hard authority.
GEN-002 / [#171](https://github.com/techrote/cybersand/issues/171) implements the
[current field/modifier candidate scope](../systems/procedural-generation-fields-and-modifiers.md).
Its context is the immutable initial procedural proposal; aggregate definitions
select existing materials. General live World editing, new mixture physics and
production streamed residency require their own owner/validation contracts.

## Provisional actor controls — 2026-10-18

**Approved owner request:** create three provisional actor input/ruleset/model
and capability alternatives, keep them performant and reactive, and allow each
to serve either a player character or a neural-network-controlled NPC. ACT-001 /
#161 implements optional Runner, Skimmer and Crawler prototypes through a shared
action/observation boundary. The [actor contract](../systems/actor-control-prototypes.md)
owns Current capabilities and limitations; this request does not select a final
production character model or imply that neural inference/training already exists.

**Approved owner expansion, ACT-002 / #168:** retain those three as SetA, then
add SetB ground/near-ground machines (Scout, Scrabbler, Ripper, GroundEffect,
Digger), SetF unusual flight/descent (Copter, Pouncer, Dropbot, Lineshank), SetY
contact/rope/impulse traversal (Walljumper, Clamberer, Swinger, Rocketjumper), six
coherently themed SetU inventions and seven SetV interfaces imagined for Astra,
Claude, Luna, Qwen, Bonsai, Jev and Gemini. The interface personas are speculative
design prompts; they do not claim real model preferences or capabilities.

The [current rig contract](../systems/actor-rigs.md) owns the resulting 29-rig
catalog, shared action/observation seam and implementation limits. The expansion
preserves responsive bounded control for player or policy producers. Distinctive
movement can use authored sampled torque, adhesion, ropes and local tools without
implying general rigid-body simulation, a pressure solver or learned inference.

## Which material behavior should changes preserve?

**Owner clarification, 2026-10-18:** the reported problem across all four builds
resolved after restarting the computer. The requested next work is to investigate
and fix material behavior so it feels more game-like, realistic and consistent.
That report is no longer an unresolved build/performance blocker. MAT-001 / #158
starts with reproduced persistent-reaction and mask-wake consistency defects;
broader Water architecture still follows its separately approved decision gates.

| Owner preference | Implication for future changes |
|---|---|
| Fast Water fronts, airborne spray and a supported film | Preserve the liked feel while distinguishing native conserved mass from the fallback's long-range discrete rules. A correctness fix should not silently retune Water into a generic viscous liquid. |
| Foam collapsing bubbles | Retain the positive visual reference; Smoke collapse should be slower and leave a lingering volume. |
| Smoke cannot burn or host Fire | This is also Current native behavior; richer culling/appearance must remain bounded. |
| Oil wave pattern | Superseded 2026-10-18 (second pass): slowly scrolling hatched patterns, especially Oil and Mercury bulk, look bad; use pseudorandom, dynamic swirling. Keep material-specific liquid variation from existing inputs. |
| Living and atmospheric detail (2026-10-18) | Plants should carry procedural vines and flowers, Fungus mycelium and mushrooms; Mites glisten iridescently; activated fireworks glow/bloom; Steam is whiter and leaves a fading afterimage; Smoke's disappearance should feel gradual (visual change preferred); Rust should look like organic corrosion spills, not a chequerboard; Toxic Sludge deeper/darker green. |
| More building vocabulary (2026-10-18) | Several dozen more solid, texture-rich building materials including several woods (grain and bark) and many chemically and thermally reactive options. |
| Rough metals should not sparkle | Restrained glints belong to polished/coated/manufactured finishes; rough materials retain texture and shape. |
| Strong construction-material readability | Medieval masonry/timber/roofing and industrial panels/pipes/glass/metals/hazards should differ at pixel scale, beyond palette swaps. |

The native [Water contract](../systems/water-design.md),
[Smoke/field status](../systems/smoke-heat-pressure-roadmap.md) and
[appearance contract](../systems/material-appearance-and-rendering.md) own
Current semantics. Preferences do not authorize weakening conservation,
collision topology or lifetime safety.

## Physics direction recorded 2026-09-08

**Approved owner direction:** call the red test rectangles **barrels**. Improve
solid/powder mutual exclusion and powder interaction with the player. Dense
liquids should not freely cross settled powders; Mercury may retain much slower
penetration. Barrels should embed on ordinary granular impacts by no more than
roughly half their depth, then remain supported. Include eventual reversible
**soliding** of rested, mostly contiguous same-material areas for Rapier macro
motion and ballistics. Exact thresholds and representation changes are
**Planned**, not current physics. The [characterisation plan](../operations/physics-characterisation-plan.md)
owns experiments, candidate tuning and staged architecture decisions.

## Backend, generic-body and Water clarification, 2026-09-20

**Approved owner clarification:** CyberSand's current priority is the backend
engine itself. Fine player/gameplay tuning is secondary while foundational
soliding, hybrid ownership and Water architecture are still moving. Physics
correctness, conservation, collision topology and cell↔Rapier handoff quality are
still core engine requirements.

The red "barrel" should be understood as a deliberately simple **generic Rapier
reference body**, not as a special gameplay subsystem. The owner does not recall
accepting the historical barrel-support result as final behavior. Historical
bounded evidence remains useful, and a later Water/body rework visibly improved
splash/displacement behavior, but future work should generalize through the same
Rapier↔cellular coupling that solided material uses rather than add barrel-only
support rules. Earlier half-depth wording remains a historical/provisional fixture
target, not a mandate for a distinct barrel mechanic.

For Water, shallow behavior is generally liked while deep released volumes can
still drain as a slow slope instead of producing a convincing surge/wave. Before
adding another Water-specific pressure/momentum mechanism, the owner wants the
generic soliding/hybrid path tested as a possible contributor. The planned
[Water hybrid/pressure extension](../operations/water-hybrid-pressure-extension-programme.md)
therefore tests at most roughly 3-5 segmented upper-volume Water sheet tiers,
preserving ordinary cellular surface rows and exact Water quantity. This is a
research candidate, not an approved production solver.

Separate trapped-gas research is also considered worthwhile even if never
integrated: prefer lumped connected gas-region bookkeeping and lazy topology over
per-pixel gas CFD, and treat pressure as a boundary condition rather than assuming
it automatically solves saturated Water transmission. Space/vacuum decompression
is an optional later proof, not current production scope.

### Water approximation and liquid comparison, 2026-10-22

**Owner direction (dated, additive):** Water and air work should aim for a
performant, game-grade approximation. Small residual units, thin films or hidden
transient overfill are acceptable when the result is visually settled and cheap.
This is recorded in the archived `claude/water-pressure-prototype` README at
`7ef2aac`. The owner also approved an **opt-in Liquid Comparison Build** for manual
feel testing: four distinct liquid families with Water as a common controlled
test material, unchanged production defaults, and no preference yet among
algorithms ([#200](https://github.com/techrote/cybersand/issues/200) amendment,
[#213](https://github.com/techrote/cybersand/issues/213)).

This shapes tolerance choices at preregistration; it does not waive measurement
or select a production solver. The
[WEX-005 synthesis](../audits/2026-10-23-wex005-water-evidence-synthesis.md)
keeps #45 as the production owner (NARROW). The
[LCB-000 Gate A record](../audits/2026-10-23-lcb000-gate-a-water-pressure-admission.md)
keeps the comparison opt-in and experimental.

### Bounded LCB implementation authorization, 2026-10-24

**Owner decision (dated, additive):** the owner explicitly authorized the bounded
Liquid Comparison Build implementation, including the previously held
`pressure_flow_v1` reference (#200) and the inertial family
([#212](https://github.com/techrote/cybersand/issues/212)). The authorization
excludes changing production defaults, generic #12 Stage-4 cell↔Rapier ownership,
a production Cell-carrier migration and full GEN-006 streaming. It lifts the
execution holds, not the evidence obligations: candidates stay opt-in, version
identified and registered, and the comparison still selects no production solver
or #45 mechanism. Status and remaining scope are in the
[roadmap](status-and-roadmap.md#lcb-001-pressure-reference--2026-10-24).

## Exploratory MicroScenario workflow, 2026-09-18

**Approved owner direction:** use interesting playable MicroScenario worlds as an
active development instrument rather than postponing them until all material
physics is mature. Organic exploration is expected to reveal otherwise
mind-numbing or unanticipated edge cases across dozens of materials—for example,
unexpected product/support/permeability behavior or weak applications of
bridging/bracing.

Capture the observed anomaly first, reduce it to a reproducible fixture, then
triage it to the subsystem that actually owns the behavior. Scenario code must
not hide kinetic/contact defects inside bespoke interaction scripts. Rework of
provisional scenarios is acceptable when later architecture or physics changes;
retain old versioned evidence rather than rewriting it.

Intermaterial-interaction work means material/material semantics **other than
kinetic/material-motion physics**. Use sparse generalized rules plus explicit
exceptions and versioned tuning passes rather than manually authoring every N²
pair. The [canonical programme](../operations/microscenarios-programme.md) owns
the resulting development graph and evidence workflow.

## Where is approximation acceptable?

**Approved direction:** explicit bounded temporal/probabilistic work reduction
for slow or secondary interactions when it preserves plausible runtime behavior.
Protect exact local occupancy/collision, ownership, synchronization, capacities,
accepted commands and applicable conservation. Sampling must not hide thread
races. The [fidelity decision](../decisions/ADR-008-bounded-approximate-fidelity.md)
owns the decision and rejected shortcuts; the [threading contract](../architecture/simulation-tick-and-threading.md)
owns what currently runs.

Prefer GPU-derived variation, highlights, shimmer, glow, relief and transient
visual motion from stable IDs, coordinates, condition bytes and time. Adding
per-cell CPU state solely for visual animation requires a measured justification.
GPU presentation does not give the GPU authority over terrain or materials.

## What requires a new owner or architecture decision?

Preserve native cellular authority, replaceable backend boundaries and immutable
render handoff. Consult the relevant ADR before reversing a rejected design.
Material changes that remove liked feel, broad dependency upgrades, public
licensing/distribution, destructive workspace/history operations and publication
require their own task authority. Routine focused tests, documentation and
local checkpoints can proceed within the active request.

General streaming/distant aggregates and broad world-scale systems remain
**Deferred** until the local material foundation is compelling. Exact replay
capture, generalized coupling and artist-facing bounded material-program tools
remain **Planned** work. [Roadmap](status-and-roadmap.md) owns their implementation
status and unresolved decisions.

## Failure policy judgement, 2026-09-08

For issue #1 the owner delegated the unresolved recovery choice to engineering
judgement. The selected bounded policy is stop until explicit reset or validated
replacement, retaining partial state only for diagnosis. Rollback, automatic
retry and partial-world continuation are Rejected for this fix; see
[ADR-010](../decisions/ADR-010-failed-tick-quarantine.md).

## Delegated issue #2 activation choice, 2026-09-08

The owner also authorized engineering judgement for the separate region policy.
Chosen and Current: excluded phased work pauses and retains activity; newly
included resident blocks wake once, including sleepers, without catch-up. Serial
keeps its documented filter difference. This approval does not authorize general
field catch-up, automatic failure retry, rollback or state-preserving live resize.


## Issue #13 experiment checkpoint

Owner feedback for issue #13: Mercury through Sand is especially satisfying and must survive indirect Sand changes. The earlier reduction in fire cadence made Wood smoulder while Oil and Coal felt good. The [chemistry observation floor](../operations/experiment-tower.md) records current behavior without retuning reactions/fire in this physics issue.

## Physical actor preferences — 2026-10-18

The owner prefers the barrel’s kinetic feel, Vector/Jolt’s scripted energy, articulated machines, collider-matched polygon graphics and usable attachments tested in constrained maps. Preserve Gyrocrate and Bellows character. The [physical actor programme](../operations/physical-actor-programme.md) records the full dated preferences, implementation boundary and follow-up sequence.
