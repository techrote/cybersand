---
title: Product intent and priorities
status: Approved design
document-kind: reference
authority: owner-confirmed-intent
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-25
related-documents: [status-and-roadmap.md, ../decisions/2026-11-14-owner-authoring-intent.md, ../decisions/ADR-008-bounded-approximate-fidelity.md, ../operations/microscenarios-programme.md]
---

# Product intent and priorities

CyberSand is intended to be a **paint-and-play engine used as an authoring
system**. Workbench is the creative workshop, control centre and monitoring
outpost: useful capabilities should be accessible there, with approachable
controls and deeper optional manipulation. The
[14 November owner clarification](../decisions/2026-11-14-owner-authoring-intent.md)
is the direct recorded source for this direction and its limits.

This page synthesizes approved intent. It does not claim that every desired
feature is implemented. The [current-state register](status-and-roadmap.md) owns
availability; subsystem contracts own actual behavior; dated evidence owns
qualification. An old execution permission applies to its original task, not to
every later reader of this page.

## What the owner wants Workbench to become

**Approved:** combine painting, simulation, generation, material experimentation,
actors and model-assisted creation through a coherent ordinary Workbench. Painting
should grow toward the useful range between classic MSPaint and GIMP/Krita.
Preserve simple paths for exploration while making advanced controls available.

The engine should support varied experiments: a passive plasma chamber, a forest
drone game, a digging game, industrial/urban exploration and future cyberpunk
settings. Underground spaces, interiors, orbit or vacuum are possible settings,
not claims of finished RPG systems, orbital mechanics or world streaming.
**Game-facing scoring and consequential actor combat damage wait until the
arrangements, materials and actors feel fun.** Internal diagnostics and training
metrics are not prohibited by that preference.

Useful convergence is already implemented in parts, including ordinary painting,
Art drawing, native generation and actor composition. The current extent belongs
to the [authoring contract](../architecture/shared-workbench-authoring-data.md).
Do not revive the obsolete “#548 design only” or “Workbench unavailable”
instructions from the original integration handovers.

## Convincing physical behavior and prepared destruction

**Approved principle:** “convincing>consistent.” Authored effects, bounded
approximations, selectable behaviors, compliant joints and assistance can improve
appearance, feel, performance and creative possibility. Representative scenes
and continued owner evaluation matter. This preference does not turn failed
measurements into passes or excuse data loss, unsafe ownership or false receipts.

**Desired outcome:** cutting or blasting coherent pieces loose so that they move,
roll or topple is useful without first solving automatic whole-building structural
stability. “Prepare then declare,” with authored break conditions and piece sizes,
is an exploratory suggestion. A fracture piece need not equal a storage chunk;
no algorithm or universal fragment size was selected by that suggestion.

The earlier cutter experiments retain their pauses and results within their own
scope. The current ObjectShard successor is identified in the
[candidate register](status-and-roadmap.md#active-candidates-and-integration-boundaries).
The source of intent is the
[physical-character clarification](../decisions/2026-11-14-owner-authoring-intent.md#physical-character-and-destructible-structures),
not an obsolete requirement copied from an abandoned branch.

## Save, Flatten and compatibility

**Approved desired behavior:** save the intended evolved material arrangement
without unexpectedly destroying the live session's Undo history. Settled Oil
should reopen where it was saved; original Acid strokes should not reappear after
the user has damaged and cleaned up a scene. This is intent, not a claim that
ordinary current Save already captures all evolved state.

**Explicit Flatten:** capture material occupancy using two bytes per cell so
burdensome construction history can be discarded. Flatten is not a physical
checkpoint and does not require that normal saves always flatten. The accepted
implementation leaves the live World and physical state in place while adopting
a new authored material baseline and retiring old construction/history. Loading
that material-only baseline later cannot restore omitted temperature, velocity,
reaction energy, solver state or live body state. Consult
[the actual save contracts](level-saves-and-replay.md) and
[saving walkthrough](../operations/workbench-saving.md).

The owner did not require serialization of the entire Undo stack or advanced
cross-version compatibility for every old map. Flatten may recover useful
material layouts across versions, subject to material identity and container
compatibility. It does not guarantee interpretation of every future/old ID.
Material Flatten is also distinct from merging Strata's visual/semantic layers.

## Live materials and layered presentation

**Approved:** Materials Lab should offer approachable material modification and
audition in the Workbench scene. Existing isolated comparison tabs are valuable,
but they do not alone satisfy the requested current-scene interaction. Which
properties have real consumers and can be changed safely remains an engineering
question. Never represent an ineffective specialized-kernel property as editable
physics. [Materials Lab](../operations/materials-lab-authoring.md) owns current
functionality; its audition successor remains separately identified.

**Approved:** four-layer **Strata Theatre** should be an available Workbench option.
Historical integration exclusions are not permanent rejection. The standalone
prototype's exact clocks and event links are not automatically the future
Workbench contract. The [depth contract](../systems/depth-layers-and-parallax.md)
owns the existing demonstration and
[the candidate register](status-and-roadmap.md#active-candidates-and-integration-boundaries)
identifies ordinary Workbench integration work.

## World extent, persistence and time

**Approved:** one fixed canvas plus persistent areas loaded while travelling
should cover most intended uses. Broad continuous canvases should support biomes
or small towns; presentation can later disguise boundaries. Non-square/broad
maps do not imply a change to the display-pixel scale.

A useful simulated border around the active view, potentially extended in the
travel direction, is desirable. On returning to an area, approximate headless
catch-up is preferred to a visibly frozen room. Use **game time**, not elapsed
real-world offline time. Occasional transitions lasting a few seconds and an
optional deliberate **simulate ahead** control are acceptable. Quantized or
approximate catch-up can be useful.

Retained state, cross-area exchanges, safe workload budgets, activity margins and
policy evolution need their own contracts. Track last accounted simulation time
when an area can continue running in a border. Headless work still costs compute.
Persistent-area/RAMCACHE candidates are not accepted-main guarantees merely
because this intent is approved.

## Generation and model-assisted authoring

The recorded generation direction combines broad spatial strokes with tunable
parameters, hard overrides, reusable modules and algorithmic hooks. Fields,
curves, masks, context guidance and aggregate choices are authoring mechanisms;
they do not automatically create new mixture physics. Current implementations
have separate [generation](../systems/procedural-world-generation.md),
[typed spatial](../systems/procedural-typed-spatial-fields.md),
[hierarchy](../systems/procedural-hierarchical-generation.md) and
[architectural-generator](../systems/architectural-generator.md) contracts.

The owner is interested in conversational autofill, automated feature/flavour/item
generation, tiny/local models for detailing and texture, NPC controllers, Rapier
actors and drone training. These roles may evolve. Persona/model names in old
experiments are creative prompts, not factual capability claims or permanent
dispatch defaults. No documentation page authorizes training, paid inference or
new schedules by implication. Art, Batch, Gremlin and external model-research
repositories retain their distinct owners and implementation status.

## Actors and physical feel

The 18 October direction favors adapting the actor roster to Rapier, including
articulated mechanisms where useful. Exceptions need a concrete physical
configuration limitation and a documented rationale. Sampled rigs remain labelled
comparison controls; this is not permission to erase their evidence.

Bounded gyro assistance, approximate joints, intentional compliance and controlled
play are acceptable. Finite gyro-momentum accounting and perfect kinematic
connections are not universal requirements. Preserve the barrel's kinetic feel,
Vector/Jolt's scripted energy, Gyrocrate and Bellows character, articulated
machines, collider-matched polygon graphics and usable attachments in constrained
maps. The [physical actor programme](../operations/physical-actor-programme.md)
and [rig contract](../systems/physical-actor-rigs.md) retain detailed scope.

The red barrel is a generic Rapier reference body. Earlier half-depth support
targets were provisional fixture guidance, not acceptance of general body physics
or a mandate for barrel-only mechanics. Shared coupling should own physical
interaction. Current actor implementation and later sandbox/pilot work must stay
separate from subjective owner acceptance.

## Which material behavior should changes preserve?

These recorded preferences guide deliberate changes. They do not substitute for
source-backed claims about current material laws.

| Preference | Consequence for authoring and review |
|---|---|
| Fast Water fronts, airborne spray and a supported film | Preserve the liked motion while naming the actual solver and quantity policy. Do not silently turn Water into a generic viscous liquid. |
| Convincing deep release | Evaluate a released volume as its own scene; a shallow-film or settling pass does not establish a convincing surge. |
| Mercury moving through Sand | Preserve this liked interaction when changing Sand indirectly. |
| Foam bubble collapse and lingering Smoke | Foam is a positive visual reference; Smoke should disappear more gradually. Smoke burning/hosting Fire is not desired. |
| Liquid visual variation | Slowly scrolling hatched bulk patterns were disliked; favor pseudorandom dynamic swirling, while retaining material-specific appearance. |
| Living detail | Procedural vines/flowers, fungal mycelium/mushrooms and iridescent Mites are desired visual character. |
| Atmospheric and reactive detail | Whiter Steam with a fading afterimage, activated fireworks glow, gradual Smoke disappearance, organic Rust corrosion and deeper/darker Toxic Sludge are recorded preferences. |
| Building vocabulary | Masonry, timber, roofs, industrial panels, pipes, glass, metals and hazards should read distinctly at pixel scale, beyond palette swaps. |
| Rough metals | Restrained glints belong to polished/coated finishes; rough surfaces should keep texture and shape without sparkle. |
| Fire behavior | Earlier reduced cadence made Wood smoulder while Oil/Coal felt good. Preserve source-specific observations when retuning, rather than treating one trial as universal acceptance. |

The [Water contract](../systems/water-design.md),
[appearance contract](../systems/material-appearance-and-rendering.md),
[effects register](material-effects-register.md) and
[field roadmap](../systems/smoke-heat-pressure-roadmap.md) own implementation.
The exact older preference records remain in
[the preserved source](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/reference/product-intent-and-priorities.md).

## Approximation, evidence and safeguards

[ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) permits explicit
bounded temporal/probabilistic reduction for slow or secondary work where the
result remains plausible. Protect occupancy/collision, ownership, synchronization,
capacity, accepted commands and applicable conservation. Sampling cannot hide
thread races. GPU appearance can derive variation from stable IDs, coordinates,
condition and time; visual animation does not give GPU output material authority.
New per-cell state solely for appearance needs a measured justification.

The PLAY programme's 30 October decision accepted #302 for its bounded mandatory
busy responsiveness/shutdown requirement and made #304's stronger framebuffer
diagnostic non-blocking. It did not certify all later physical progression or
Windows feel. Keep original failures and the
[recorded acceptance boundary](../systems/player-control-playground.md#current-play-acceptance-boundary--2026-10-30).

Earlier LCB authorization was opt-in and excluded production-default changes in
that task. It does not override later accepted gameplay Water changes. Historical
Water-sheet and gas-region experiments remain scoped alternatives; they are not
universal prerequisites for all current authoring. The owning
[Water programme](../operations/water-hybrid-pressure-extension-programme.md)
and [family policy](../architecture/liquid-solver-family-policy.md) retain the
separate evidence/admission boundaries.

For failures, [ADR-010](../decisions/ADR-010-failed-tick-quarantine.md) retains
stop-until-reset-or-validated-replacement; no automatic retry/rollback follows.
The delegated region policy preserves paused phased activity and wakes re-entered
resident blocks without general field catch-up or state-preserving live resize.

## Authority, unfinished work and historical attempts

### Disposable Web experiments

The [owner-directed closure of issue #3](https://github.com/techrote/cybersand/issues/3#issuecomment-5593128559)
makes Web builds occasional disposable experiments. Ongoing browser support,
maintained Web CI and reproducible long-term Web releases are not standing
requirements or blockers for desktop work. A newly authorized experiment may
repair the specific prerequisites it needs. Any experiment cited as evidence
still needs an honest source, artifact and coverage record. This policy does
not waive the separate native provenance and documentation checks completed
through PRs #6 and #7.

### Current work and preserved attempts

The owner welcomes interesting playable MicroScenarios before all physics is
mature. Capture an anomaly, reduce it to a reproducible fixture, and route it to
the owning subsystem. Scenario scripts must not conceal a kinetic/contact defect.
[Intermaterial work](../operations/microscenarios-programme.md) uses bounded
general rules and explicit exceptions; it is broader than chemistry, and distinct
from material-motion physics.

A stopped attempt is not automatically a rejected idea. Preserve purpose,
implementation, stopping reason when known, empirical results and possible
surviving value separately. Past effort also does not establish present merit.
The [historical index](../history/engineering/README.md) supports deliberate
research without becoming the ordinary instruction corpus.

Public licensing/distribution, dependency changes, protected-source transitions,
default promotion, merge and destructive history actions need the authority of
their actual task. Approved intent alone does not grant them. The original
[14 November record](../decisions/2026-11-14-owner-authoring-intent.md) remains
unchanged; its historical phase permissions are not generalized here. Current
availability and unresolved implementation choices belong to
[the status register](status-and-roadmap.md).
