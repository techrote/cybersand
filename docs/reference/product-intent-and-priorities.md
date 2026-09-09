---
title: Product intent and priorities
status: Current
document-kind: reference
scope: Approved owner direction and deliberately preserved behavior; not current implementation or performance evidence
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-09-08
related-documents: [status-and-roadmap.md, ../decisions/ADR-008-bounded-approximate-fidelity.md]
---

# Product intent and priorities

This page carries forward owner direction recorded in the
[pre-rewrite handover](../audits/pre-rag-rewrite-2026-09-08/cybersand-codex-development-handover.md.txt)
at checkpoint `126175c`. It preserves intent separately from source and dated
validation; later approved decisions should update this canonical reference.

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

## Which material behavior should changes preserve?

| Owner preference | Implication for future changes |
|---|---|
| Fast Water fronts, airborne spray and a supported film | Preserve the liked feel while distinguishing native conserved mass from the fallback's long-range discrete rules. A correctness fix should not silently retune Water into a generic viscous liquid. |
| Foam collapsing bubbles | Retain the positive visual reference; Smoke collapse should be slower and leave a lingering volume. |
| Smoke cannot burn or host Fire | This is also Current native behavior; richer culling/appearance must remain bounded. |
| Oil wave pattern | Retain and preferably animate material-specific liquid variation in shaders, using existing inputs. |
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
