---
title: Architectural and simulation invariants
document-kind: contract
canonical-for: [invariant-register]
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
keywords: [invariants, ownership, threading, replay, conservation, capacity, body mask, interest defect]
related-documents: [../architecture/principles-and-non-goals.md, interfaces-and-message-contracts.md, validation-evidence.md, status-and-roadmap.md]
last-reviewed: 2026-09-08
---

# Architectural and simulation invariants

Use these stable IDs in reviews and fixtures. **Current** identifies inspected
scope; **Approved** requires implementation where incomplete. **Planned**,
**Deferred** and **Rejected** keep their normal meanings. Contract/source links
below explain enforcement and detecting fixtures; only the
[validation ledger](validation-evidence.md) establishes dated execution.
Existing IDs are retained, including when an earlier description was corrected.

## Current baseline invariants

| ID | Status and narrow claim | Authoritative contract |
|---|---|---|
| CUR-001 | Current: desktop owner and Web main-thread owner each coordinate one selected world/character | [Threading](../architecture/simulation-tick-and-threading.md) |
| CUR-002 | Current: rendering consumes copied bytes, never mutable cells | [Lifetimes](../architecture/data-ownership-and-lifetimes.md) |
| CUR-003 | Current: phased core/phase/effect order is deterministic | [Ordering](../architecture/determinism-and-boundary-transfers.md) |
| CUR-004 | Current: native default chunk size is 128; compatible configured sizes are permitted | [Geometry](../architecture/chunk-tile-and-buffer-model.md) |
| CUR-005 | Current: desktop may select fallback; Web requires native; no synchronized second authority | [Architecture](../architecture/overview.md) |
| CUR-006 | Current: every valid catalogue ID has a descriptor/kernel selection and radius ≤2; inert entries use no rule | [Materials](../systems/materials-and-rule-kernels.md) |
| CUR-007 | Current: accepted external explosions commit in enqueue order at tick entry and are hashed while pending | [Ordering](../architecture/determinism-and-boundary-transfers.md) |
| CUR-008 | Current: native leased bytes stay immutable; publication pressure retains dirty state | [Lifetimes](../architecture/data-ownership-and-lifetimes.md) |
| CUR-009 | Current: rectangle samples create separate endpoint occupancy and bounded observations | [Coupling](../architecture/rigid-body-and-cellular-coupling.md) |
| CUR-010 | Current correction: fallback forces adaptive stride=1 and deferred count=0; old load-driven block deferral is absent; optional sparse flight remains | [Activity](../systems/activity-dirty-regions-and-waking.md) |
| CUR-011 | Current fallback: downward Empty movement leaves the vacated source unstamped, enabling fill chains | [Fallback rules](../systems/materials-and-rule-kernels.md) |
| CUR-012 | Current: themed 38–80 are hard surfaces; inert radius zero, Oak/Thatch radius-one combustible | [Construction](../systems/themed-construction-materials.md) |
| CUR-013 | Current: flair uses immutable display inputs and cannot write Cell state | [Appearance](../systems/material-appearance-and-rendering.md) |
| CUR-014 | Current: neighbor relief samples the existing uploaded texture without a second authoritative image/readback | [Appearance](../systems/material-appearance-and-rendering.md) |
| SAVE-001 | Current: CYSD1 reconstructs a level and selected metadata; no exact continuation | [Saves/replay](level-saves-and-replay.md) |
| REPLAY-001 | Approved, incomplete: replay must capture every future-affecting input; current hash coverage is partial | [Hash coverage](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage) |
| WEB-001 | Current: pthread jobs do not remove Web's synchronous main-thread tick wait | [Threading](../architecture/simulation-tick-and-threading.md) |

## Authority and module invariants

Contracts: [module boundaries](../architecture/module-boundaries.md),
[resource ownership](../architecture/data-ownership-and-lifetimes.md).
Sources: [World](../../native/include/cybersand/world.hpp),
[MaterialRules](../../native/include/cybersand/material_rules.hpp).

| ID | Status and requirement |
|---|---|
| AUTH-001 | Approved; Current native authority: one production cellular truth through storage |
| AUTH-002 | Approved; Current native core/pool scope: no Godot API dependency; Godot adapter remains outside core |
| MOD-001 | Approved, incomplete extraction: scheduler coordinates work rather than owning material policy |
| MOD-002 | Current descriptors; Approved execution separation: immutable rule data owns no threads/per-cell object containers |
| MOD-003 | Approved, partial: storage owns chunk/field lifetime and capacity; general serialization is Planned |

## Timing and threading invariants

Contract/source: [tick order and failures](../architecture/simulation-tick-and-threading.md),
[World](../../native/src/world.cpp). Fixtures: [native tests](../../native/tests/test_world.cpp).

| ID | Status and requirement |
|---|---|
| TIME-001 | Approved: authoritative changes occur at defined fixed-tick/setup/loading boundaries; Current painting/reset can occur while paused under exclusive ownership |
| THREAD-001 | Current: native jobs have no Godot/object access; historical sanitizer scope is separate from current source |
| THREAD-002 | Current fixture scope: exact one/multiworker phased comparisons; no desktop/Web/Rapier equivalence implication |
| THREAD-003 | Current: native workers persist across ticks; no per-material or per-tick pool construction |
| TIME-002 | Current: a failed attempt is non-atomic and quarantined; completed identity/publication cannot advance, owners stop and require explicit clear/reset or validated replacement; no partial-world retry/event replay |

## Spatial, buffer, and transfer invariants

Contracts: [geometry](../architecture/chunk-tile-and-buffer-model.md),
[ordering](../architecture/determinism-and-boundary-transfers.md).
Sources/tests: [SchedulerGeometry](../../native/src/scheduler_geometry.cpp),
[native fixtures](../../native/tests/test_world.cpp).

| ID | Status and requirement |
|---|---|
| SPACE-001 | Current defaults: 128 storage, 32 activity, 64 core; these are independent units |
| PHASE-001 | Current: same-phase complete write domains do not overlap |
| PHASE-002 | Current: deterministic phase/scan/random inputs and declared radius; type-enforced RuleContext is Planned |
| BUF-001 | Approved; backend Planned: isolate only active regions/required fields when buffering |
| BUF-002 | Approved; backend Planned: buffered jobs write assigned output and bounded transfers only |
| XFER-001 | Approved buffered staging; Current phased movement requires ownership of every affected cell |
| XFER-002 | Approved; unimplemented transfers: canonical merge cannot depend on worker timing |

## Activity and interest invariants

Contract: [interest region](../systems/world-storage-and-interest-region.md),
[activity](../systems/activity-dirty-regions-and-waking.md).
Source: [World `finish_tick`, `set_simulation_region`, `gather_active_cores`](../../native/src/world.cpp).

| ID | Status and requirement |
|---|---|
| ACT-001 | Current: sleeping blocks retain material/compact field content |
| ACT-002 | Current local scope: writes/crossings wake local and edge neighbors |
| ACT-003 | Approved: sleeping groups must receive relevant boundary changes; broad buried-volume/interest acceptance is incomplete |
| INT-001 | Approved/Ambiguous: proposed 10%/20% margin semantics unresolved; Current desktop/Web use explicit pixel pairs |
| INT-002 | Approved: region exit/re-entry must preserve meaningful state/eligibility; Current phased exclusion ages blocks into sleep and does not wake on return; serial ignores the region |

The interest page links the focused defect probe. No recorded broad native
suite pass overrides this failing behavior; it remains implementation work.

## Fidelity invariants

Contract: [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md).

| ID | Status and requirement |
|---|---|
| FID-001 | Approved, incomplete: policies must be explicit, bounded, observable and reversible; current fixed lanes lack a universal disable switch |
| FID-002 | Approved: local occupancy, ownership, closed conservation and capacity checks cannot be sampled away |
| FID-003 | Current: fixed-policy native fixtures compare exact hashes; full strict/replay mode remains Planned |
| FID-004 | Rejected: naive coarsening that alters local topology or creates checkerboard holes |

## Bridge invariants

Contracts: [bridge behavior](../architecture/rendering-and-gameplay-bridges.md),
[lifetimes](../architecture/data-ownership-and-lifetimes.md).
Fixtures: [native bridge](../../godot/tests/test_native_render_bridge_regression.gd),
[handoff](../../godot/tests/test_render_patch_handoff_regression.gd).

| ID | Status and requirement |
|---|---|
| BRIDGE-001 | Current native publication; Approved general boundary: Godot gets no mutable World storage |
| BRIDGE-002 | Current: leases/copies describe serialized post-mutation state and survive consumer delay |
| BRIDGE-003 | Approved generalized queue: identified command boundaries and immutable results; production schemas/pressure are Planned |
| BRIDGE-004 | Approved; Current presentation path: render-only state must not affect authoritative hashes/wake |
| BRIDGE-005 | Current: live body Nodes/RIDs remain on main-thread adapter; workers receive complete value samples |
| BRIDGE-006 | Current: LUT variation, temporal blending and glow do not write derived colour/frame noise into cells |

## Rigid-body coupling invariants

Contract: [coupling](../architecture/rigid-body-and-cellular-coupling.md).
Source/tests: [native adapter](../../godot/native_extension/cyber_native_cell_world.cpp),
[Rapier runbook](../operations/rapier-2d-migration-runbook.md).

| ID | Status and requirement |
|---|---|
| BODY-001 | Current rectangles: body occupancy and material identity remain separate |
| BODY-002 | Current: movement/non-empty painting cannot target occupied body-mask cells |
| BODY-003 | Current: native ascending body IDs, fallback input order; bounded ejection retains/counts unresolved material |
| BODY-004 | Current bounded impulse/correction; Planned torque: observations cross through values rather than live worker physics access |
| BODY-005 | Current capped sweep and per-body cast-shape CCD; generalized selective substeps/CCD policy is Planned |
| BODY-006 | Current configuration: Rapier2D is the sole backend; no production toggle |
| BODY-007 | Current manual owner: automatic space stepping is disabled while the bridge owns explicit steps |
| BODY-008 | Current: direct server state, not stale scene transforms, owns post-step body results |

## Capacity and allocation invariants

Contract: [capacity budgets](../operations/configuration-and-capacity-budgets.md).
Source/tests: [WorldConfig](../../native/include/cybersand/world.hpp),
[native fixtures](../../native/tests/test_world.cpp).

| ID | Status and requirement |
|---|---|
| CAP-001 | Approved: explicit serializable/observable budgets; construction fields Current, general serialization Planned |
| CAP-002 | Approved: reservations need not be permanent architectural limits; live growth remains Planned |
| CAP-003 | Current native task/snapshot storage bounded/reused; transfer storage Planned, Godot emission queue dynamic |
| CAP-004 | Current: native capacity failures are explicit; partial progress is quarantined until reset/replacement, without rollback or automatic event replay |
| CAP-005 | Approved, unimplemented live transition: structural growth only after affected jobs/views drain |

## Water invariants

Contract: [Water](../systems/water-design.md).
Fixtures: [native](../../native/tests/test_world.cpp),
[fallback](../../godot/tests/test_cell_world.gd).

| ID | Status and requirement |
|---|---|
| WATER-001 | Current pure closed fixtures: exact 8-bit mass conservation; generalized reaction accounting Planned |
| WATER-002 | Current: mass lives in the common material grid, without a second authority |
| WATER-003 | Current: transfer cannot exceed source mass or destination 255 capacity |
| WATER-004 | Current: adjacent difference ≤1 rests; settled content hash is the correct time-independent oracle |
| WATER-005 | Current leveling-fixture scope: free Water has no exhausted-history equilibrium rule |
| WATER-006 | Current: mass-based display dither does not mutate mass/activity |
| WATER-007 | Current fallback only: coherent emission preserves its supported-flow restrictions; native uses a distinct 12-tick delay |
| WATER-008 | Current: adhesion differs between fallback dispersion and native supported-film threshold; neither is viscosity or yield |

## GPU and rejected-approach invariants

Rationale: [principles](../architecture/principles-and-non-goals.md),
[ADR-006](../decisions/ADR-006-gpu-compute-deferral.md).

| ID | Status and requirement |
|---|---|
| GPU-001 | Approved; Current native path: CPU cellular terrain/collision authority |
| GPU-002 | Deferred: GPU fields initially non-authoritative unless superseded by an explicit ADR |
| REJ-001 | Rejected: per-cell mutex scheme |
| REJ-002 | Rejected: material-specific threads or growing per-material inheritance |
| REJ-003 | Rejected: full-stored-world double buffering as normal operation |
| REJ-004 | Rejected: unbounded mixed in-place/buffered ownership of one field/stage |
