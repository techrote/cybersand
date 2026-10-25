---
title: Architectural and simulation invariants
document-kind: contract
canonical-for: [invariant-register]
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
keywords: [invariants, ownership, threading, replay, conservation, capacity, body mask, interest defect]
related-documents: [../architecture/principles-and-non-goals.md, interfaces-and-message-contracts.md, validation-evidence.md, status-and-roadmap.md, ../architecture/pressure-optimization.md]
last-reviewed: 2026-10-25
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
| CUR-006 | Current default catalogue: every valid ID has descriptor/kernel selection and radius ≤2; inert entries use no rule. Opt-in Brine IN and isolated Water IN separately require radius3 | [Materials](../systems/materials-and-rule-kernels.md) |
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

## Semantic generation invariants

Contract: [four-plane generation](../systems/procedural-semantic-planes.md).
Sources: [native plan](../../native/src/generation_planes.cpp),
[owner](../../godot/scripts/depth/semantic_plane_runtime.gd).
Fixtures: [native determinism](../../native/tests/test_generation_planes.cpp),
[adapter](../../godot/tests/test_worldgen_planes.gd),
[owner rejection/lifecycle](../../godot/tests/test_semantic_planes_runtime.gd),
[actual example reactions](../../godot/tests/test_semantic_planes_examples.gd)
and [render isolation](../../godot/tests/test_semantic_depth_render.gd).

| ID | Status and narrow claim |
|---|---|
| GEN-PLANE-001 | Current: all four planes reference one immutable semantic hierarchy, canonical geometry and shared typed fields; absolute coordinates and semantic IDs do not depend on camera or request order |
| GEN-PLANE-002 | Current: pending/failed/cancelled generation publishes no partial plane arrays; complete host replacement stages four Worlds, registries and the existing play actor owner before one commit |
| GEN-PLANE-003 | Current: play, scripted and effects own separate native clocks; background has no runtime ticks, source/drain, actor or event writes |
| GEN-PLANE-004 | Current: only copied identity-checked play→scripted blast and scripted→effects burst observations authorize bounded interlayer commands; static/presentation links and pixel overlap confer no authority |
| GEN-PLANE-005 | Current: finite source/drain/setup declarations feed ordinary materials; expected products remain diagnostics produced by native kernels |
| GEN-PLANE-006 | Current: canonical anchors yield one tiled registration union; identical validated admission is idempotent, reset retires old commands, and retired revisions cannot replace current state |
| GEN-PLANE-007 | Current: all expansion, material, diagnostic, publication, schedule and observation budgets fail explicitly; native acceptance does not waive stricter host caps |
| GEN-PLANE-008 | Current finite-preview scope: no streaming eviction, durable mutation reconciliation, implicit Z physics or direct generation-worker Rapier access is introduced |

## Timing and threading invariants

Contract/source: [tick order and failures](../architecture/simulation-tick-and-threading.md),
[World](../../native/src/world.cpp). Fixtures: [native tests](../../native/tests/test_world.cpp).

| ID | Status and requirement |
|---|---|
| TIME-001 | Approved: authoritative changes occur at defined fixed-tick/setup/loading boundaries; Current painting/reset can occur while paused under exclusive ownership |
| THREAD-001 | Current: native jobs have no Godot/object access; historical sanitizer scope is separate from current source |
| THREAD-002 | Current fixture scope: exact one/multiworker phased comparisons; no desktop/Web/Rapier equivalence implication |
| THREAD-003 | Current: native workers persist across ticks; no per-material or per-tick pool construction |
| TIME-002 | Current: a failed attempt is non-atomic and quarantined; completed identity/publication cannot advance, owners stop and require explicit clear/reset or validated replacement; no partial-world retry/event replay; region requests cannot revive a failed world and recovery uses fresh activity under the latest region |

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
| INT-002 | Approved: region exit/re-entry must preserve meaningful state/eligibility; Current phased exclusion retains activity/quiet state; newly included resident blocks wake once at tick entry without catch-up; unchanged/equivalent coverage does not wake; serial ignores the region |

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

## Physical actor invariants

Contract: [articulated actors](../systems/physical-actor-rigs.md),
[physical commands](interfaces-and-message-contracts.md#physical-actor-control-and-effects).
Sources: [session](../../godot/scripts/physical_actor_session.gd),
[runtime](../../godot/scripts/physical_actor_rig.gd),
[effects](../../godot/scripts/physical_actor_effects.gd),
[equipment owner](../../godot/scripts/physical_usable_equipment.gd),
[physical usable runtime](../../godot/scripts/physical_usable_runtime.gd).
Focused catalogue, Rapier, session, effects and integration runners detect the
listed boundaries; execution evidence remains separately dated.

| ID | Status and narrow claim |
|---|---|
| RIG-001 | Current: main-thread Rapier owns every live part/joint; the cellular owner receives copied values and alone writes native materials |
| RIG-002 | Current: physical actor graphics use actual declared rectangle/circle collider dimensions and published transforms; authored leg, rotor and held parts are physical bodies; SetP circles explicitly retain conservative square native masks |
| RIG-003 | Current: installation checks at most eight actors, eight parts per actor including held objects, and 64 total coupled bodies before activation |
| RIG-004 | Current: human, demo and policy producers use one normalized action path; run/actor/epoch/sequence/issued-observation leases prevent stale authority from controlling a replacement |
| RIG-005 | Current: cancellation clears stored launch intent and pending effects without interpreting it as charged release or deleting physical velocity |
| RIG-006 | Approved and Current authored policy: bounded gyro assistance, approximate slides and controlled flex/play are permitted; finite gyro momentum and exact mechanical joint emulation are not required |
| RIG-007 | Current: physical command/environment version 2 is distinct from sampled actor rows and Thunderbowl v1; no tag, metal, neural-service or reward equivalence is implied |
| RIG-008 | Current: new desktop assemblies wait for matching reset/epoch and installed initial terrain; a retired world's cached geometry cannot release the fence |
| RIG-009 | Current: worker effect batches are admitted wholly within eight pending requests or explicitly refused; bounded copied admission diagnostics are separate from actual-cell receipts |
| RIG-010 | Current: ACT-005 equipment is one real coupled part whose body ID survives held, released, fixed, deployed and nearby pickup transitions; selection/lifecycle epochs revoke superseded authority without teleporting the part or erasing momentum |
| RIG-011 | Current: physical usable requests carry run, actor, generation, equipment epoch, instance, body and request identity; one pending request per actor includes extracted work, and a whole batch is admitted within eight slots or explicitly refused |
| RIG-012 | Current: physical source clearance and target protection use actual native per-part occupancy; tools/projectiles/processors cannot derive an alternative virtual muzzle or write through a protected collider |
| RIG-013 | Current: the cellular owner accounts accepted usable work; only a matching accepted, consumed receipt can apply bounded physical recoil once, and cancellation, expiry, rearm, selection and reset fence stale results |
| RIG-014 | Current: physical processors must settle and fix their real body before worker admission; rotated nonoverlapping exterior ports preflight complete batches, and blocked outputs consume no input |
| RIG-015 | Current: bounded per-actor/per-processor history preserves stock, age, cycles and cooldown across pickup, redeployment and selection; an exhausted physical device remains observable and inert until its physical owner retires it |

### Physical free-flight invariants

Contract: [4LY single-chassis flight](../systems/physical-free-flight.md).
Sources: [profile](../../godot/scripts/physical_flight_profile.gd),
[pure controller](../../godot/scripts/physical_flight_controller.gd),
[rig](../../godot/scripts/physical_actor_rig.gd) and
[session](../../godot/scripts/physical_actor_session.gd).

| ID | Status and narrow claim |
|---|---|
| FLY-001 | Current: the explicit no-equipment profile installs one rectangular body, no joints/mounts and no hidden held chassis through the ordinary physical owner |
| FLY-002 | Current: `4ly_velocity_v1` admits exactly two finite in-range `move` components under the retained version-2 observation-relative lease; legacy profile meanings are unchanged |
| FLY-003 | Current: the stabilizer receives only requested velocity and sampled own velocity/attitude, with no position, goal, terrain, route, reward or World authority |
| FLY-004 | Current: gravity compensation shares bounded total thrust; acceleration/braking, force response/slew and torque bounds are explicit, without an integral or extra extreme-motion actuator |
| FLY-005 | Current: desired speed limits do not overwrite collision momentum; cancellation/expiry discard command/filter state and select passive assistance without deleting physical velocity |
| FLY-006 | Current: copied capabilities and resolved profile/controller hashes identify tuning and controller code separately from requested/admitted/applied input and actual sampled motion |
| FLY-007 | Current scope: four stable IDs share initial conformance numbers; three are uncalibrated placeholders, and neither profile identity nor a fixture supplies four-profile handling or learned-policy acceptance |
| FLY-008 | Current: a flight session binds immutable prepared receipts to the actual bridge step counter; cancellation cannot invent consumption or reattribute a completed step to a later producer, and unexpected physical steps require replacement |

### Player material field invariants

Contract: [player playground](../systems/player-control-playground.md) and
[native field interface](interfaces-and-message-contracts.md#player-material-field-control).
Sources: [World relocation](../../native/src/world.cpp) and
[dedicated owner](../../godot/scripts/player_playground_runtime.gd).

| ID | Status and narrow claim |
|---|---|
| PLAY-001 | Current: a serialized between-tick native field selects local Sand/Water and moves complete stored cells; no per-cell Rapier object, repaint, hidden cohort or material-kernel replacement |
| PLAY-002 | Current: source scan, parcel count and axis-adjacent relocation are bounded; invalid input or a failed/in-tick World refuses mutation; occupied destinations and unavailable storage retain the source |
| PLAY-003 | Current: per-call relocation preserves compact state, temperature and exact Water quantity; subsequent ordinary chemistry/transport is outside that field-only conservation claim |
| PLAY-004 | Current: material command leases bind issued observations to run/epoch/generation/sequence; expiry/cancel stops field calls, while normal native material stepping may continue |

## Typed procedural generation invariants

Contract: [typed spatial fields](../systems/procedural-typed-spatial-fields.md).
Sources/tests: [typed API](../../native/include/cybersand/generation_typed_fields.hpp),
[analytical regressions](../../native/tests/test_generation_typed.cpp),
[structured primitives](../../native/include/cybersand/generation_spatial.hpp).

| ID | Status and narrow claim |
|---|---|
| FIELD-001 | Current: retained schema-1 normalized fields/material fixtures keep their semantics; schema-2 typed spatial computation is explicit |
| FIELD-002 | Current: signed values and exact category tuples are not silently clamped/interpolated into masks; normalized mask conversion is explicit |
| FIELD-003 | Current: derivatives/transforms/coarse samples use immutable absolute-world functions, with no resident-neighbor or per-cell-context dependency |
| FIELD-004 | Current: nonuniform/warped/coarse distance fields carry qualified/general output instead of an unsupported exact Euclidean-distance claim |
| FIELD-005 | Current: compilation validates unused declarations, namespaces, cycles, bounds and bounded preparation; a failed finite solver exposes no partial assignment |
| FIELD-006 | Current: caller-owned bounded cache identity includes transitive source/parameter/scale identity and coordinates; cache warmth cannot alter results |
| FIELD-007 | Current: pending chunk materials and typed diagnostics stay private; failure/cancellation clears payloads and hashes before publication |
| FIELD-008 | Current: finite curve traversal is not an infinite physical route; finite region assignment has cross-tile guarantees only for explicit wrap constraints |

## Hierarchical generation invariants

Contract: [hierarchical places and routes](../systems/procedural-hierarchical-generation.md).
Source: [semantic API](../../native/include/cybersand/generation_grammar.hpp),
[planner](../../native/src/generation_grammar.cpp), and
[generator](../../native/src/world_generation.cpp).

| ID | Status and narrow claim |
|---|---|
| GRAMMAR-001 | Current: semantic region/rule/slot identities exclude storage-chunk size, request order, recipe revision and finite window; a region-grid-size change explicitly changes identity |
| GRAMMAR-002 | Current: region-contained features may cross storage chunks; canonical boundary/socket ownership and explicit routes do not require either owning chunk to have been generated |
| GRAMMAR-003 | Current: hard layout requirements precede preferences; bounded priority search may reject a feasible alternative rather than silently relaxing a constraint |
| GRAMMAR-004 | Current: omitted features require authored fallback receipts; required neighbors and support are rechecked after omission |
| GRAMMAR-005 | Current: finite curve order controls placement/inspection but never substitutes for explicit route edges, matching sockets or final-cell clearance |
| GRAMMAR-006 | Current: exported geometry is immutable declared context; semantic planning and typed fields do not read partial raster output or live World state |
| GRAMMAR-007 | Current: final hard material overrides preserve authority and can fail a route report; geometric clearance is qualified for the declared floating square profile, not an actor/controller |
| GRAMMAR-008 | Current: compile/budget failure publishes no partial plan, material or diagnostic packet; semantic inspection does not grant World admission or streaming authority |
| GRAMMAR-009 | Current: final support qualification is separate from route success; each declared floor/ceiling/wall check needs at least one final Solid contact and reports partial missing contacts without claiming gravity stability or apparatus preservation |

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
| WATER-001 | Current default pure closed fixtures conserve exact 8-bit mass. Residual native #200 additionally closes world-wide visible+PF-overfill Water against explicit setup/edit/generation/event/reaction/kernel source-sink aggregates; this preserves #160 chemistry rather than asserting reaction conservation |
| WATER-002 | Current default FreeMass: visible mass lives in the common material grid; opt-in PF overfill remains native solver-owned cell state, without a second World authority |
| WATER-003 | Current default mass8 FreeMass transfer cannot exceed source mass or destination 255 capacity; selected-precision and PF visible/overfill bounds follow their family contracts |
| WATER-004 | Current default FreeMass fixture: adjacent difference ≤1 rests; settled content hash is time-independent, while complete physical hash includes clock and policy |
| WATER-005 | Current leveling-fixture scope: free Water has no exhausted-history equilibrium rule |
| WATER-006 | Current: mass-based display dither does not mutate mass/activity |
| WATER-007 | Current fallback only: coherent emission preserves its supported-flow restrictions; native uses a distinct 12-tick delay |
| WATER-008 | Current: adhesion differs between fallback dispersion and native supported-film threshold; neither is viscosity or yield |

Residual native #200 invariants are owned in detail by
[prepared setup and receipts](../architecture/liquid-prepared-setup-and-receipts.md)
and [family material hooks](../architecture/liquid-solver-family-policy.md).

| ID | Status and requirement |
|---|---|
| WATER-009 | Current main native: W-CY holds `maximum()` Water per cell; fractional ingress refuses or uses explicit setup-only normalization, never a silent FreeMass fallback |
| WATER-010 | Current main native: same-material reaction products reset family state and book gross actual Water inputs/products; species cell counts are separate units |
| WATER-011 | Current main native: fixed job aggregates merge serially; checked external/generated overflow refuses before authority changes, while tick overflow quarantines partial progress |
| WATER-012 | Current main native: typed-v1 setup/run/attempt/accounting codecs and physical hash/CYPS2 preserve immutable native facts; historical CYPS1 explicitly refuses; historical content/state hashes and C64-E8 layout are unchanged |
| WATER-013 | Current main native: caller source/runtime claims cannot select verified provenance or full matched eligibility; the old Godot dictionary getter is not typed native-v1 proof |
| WATER-014 | Current #201 branch source, pending acceptance: a Water motion certificate preserves failed-motion body contacts, mandatory material/cadence/event work and unrelated liquids; it proves a no-op instead of freezing nonzero flow and grants no #12 skip ownership ([contract](../architecture/pressure-optimization.md)) |
| WATER-015 | Current #201 source: incomplete derived heads/index/member proofs select complete admitted reference evaluation; no stale/partial summary is consumed as a valid cached head |
| WATER-016 | Current #201 source: gas fixed point includes final labels and zero discovery allocation; component reuse retains global seed order, identity/history and relabelling, including paused contributors |
| WATER-017 | Current #201 execution3: cold/invalidated inputs take ordinary warmup; failed proof defers eight eligible visits; only the exact valid tag skips motion. Usable heads/prior Water work admit bounded8-tick cost trials; deficit/uncertainty suspends32 eligible-head ticks. Off/cold invalidation never scans certificates; reactivation resets them before reading. Derived state is cold on restore and execution identity is separate from physical authority |
| WATER-018 | Current #201 diagnostic interface: copied prepared heads may be stale after transport/edits; complete roster coverage and exact numerical errors do not grant freshness or rest authority. Net ROI Water balance is not gross face flux |
| WATER-020 | Current repair branch, pending acceptance: final gas relabel changes unvisited labels absent from the new live table to vacuum, retains still-live masked identity, preserves already-reduced amounts/history, and treats sanitation as a non-fixed-point label change; CYPS still refuses dangling gas labels ([contract](../architecture/pressure-flow-v1.md#gas-compartments)) |
| WATER-019 | Current #201 adapter source: copied unsigned budget/capacity/counter values use decimal strings without signed-u64 truncation; all adapter observations remain exclusive-owner calls, not worker-owned Godot APIs |

## Water IN isolated native invariants

| ID | Status and requirement |
|---|---|
| IN-WATER-001 | Current isolated source: Water/reference executes retained IN with actual precision maximum; the shared CY-or-IN whole-Water predicate refuses partial live/CYSD/CYPS ingress without rounding. Setup-only normalization keeps native gross counters and digest |
| IN-WATER-002 | Current isolated source: immediate coupling returns the actual carrier after each pickup; subsequent submoves/probes/final state follow the Water tuple, with grain/vacancy state zero and exact compact/thermal payloads |
| IN-WATER-003 | Current isolated source: complete original-owner helper reads/writes are bounded3/2, including second packing census and exchange bracing; explicit radius3 never expands protected Current2 automatically |
| IN-WATER-004 | Current isolated source: original coherence and cadence gate horizontal-only opportunities; mandatory gravity, WaterUpdate, body/material/future work remain. Retained velocity and bounded q16 phase do not accrue catch-up debt |
| IN-WATER-005 | Current isolated evidence: capability admission changes policy-bound hashes, while Current tuple/temperature bytes, quantity ledger and historical content/state controls remain exact. Actual sourceaa8af247 Windows/Linux publication is separately qualified; final ready CI/review, scientific and full-host acceptance remain separate |

[Water semantics and qualification](../architecture/inertial-cellular-v1.md#water-in-native-successor--2026-10-25)
own these rules; [dated evidence](../audits/2026-10-25-water-inertial-native.md)
records actual execution and retained failures.

## Brine IN standalone adapter invariants

| ID | Status and requirement |
|---|---|
| IN-ADAPTER-001 | Current #212 branch: hash/save versions and IN parameters/digest are copied from the actual applied World; policy-only predictions are labelled separately |
| IN-ADAPTER-002 | Current #212 branch: legacy factory defaults2, IN explicitly requests3, and ordinary/default/CYSD1 reconstruction resets2; insufficient/unsupported geometry preserves the old session |
| IN-ADAPTER-003 | Current #212 branch: returned motion/parameter dictionaries own their copies; native pool workers call no Godot API; old dictionary receipt identity remains separate from qualified typed native-v1 host evidence |

The [standalone IN contract](../architecture/inertial-cellular-v1.md#standalone-godot-readback-and-explicit-geometry)
owns the exact interfaces. Local Windows execution does not qualify the full
application, actual browsers or released runtimes.

The bounded unmerged #202 [articulated host contract](../architecture/liquid-prepared-setup-and-receipts.md#staged-articulated-physical-owners)
additionally owns these application preparation invariants:

| ID | Status and requirement |
|---|---|
| LCBH-001 | Current on branch: actual main-thread body poses stay frozen in their permanent private physics space until complete terrain readiness and native/worker commit; accepted adoption performs no rebind |
| LCBH-002 | Current on branch: strict copied initial body input produces native masks before receipt capture; canonical physical hash binds those masks, while body digest/count remain qualified host metadata |
| LCBH-003 | Current on branch: exact continuation binding and final request/settings/reset/stop fences preserve the retained World/owners/receipt on refusal; already-admitted work keeps its explicit mailbox disposition |
| LCBH-004 | Planned full host evidence remains separate: frozen native-v1 qualifications and false full-match eligibility cannot be relabeled by a panel, caller claim or unverified host envelope |
| LCBH-005 | Current on integrated branch: IN instance versions, effective parameter identity and actual damping come from native World readback; geometry3 is explicit for candidate and comparator, while Original Current restores protected2 |
| LCBH-006 | Current on branch: ordinary Tower prepares final floor/player/camera/profile before capture, retains ordinary control routing and accepted reset/profile selection, and treats a committed observer failure as an installed fault; refusal retains old owner/World/receipt/UI |
| LCBH-007 | Current qualified foundation on branch: API-reported library path/current file hash, manifest/current script files and caller claims keep their distinct observation scopes; editor shadow paths require explicit qualification. Immutable host observation values preserve native-v1 qualifications15 and false native/host full-match eligibility; complete executed host verification and matching publication remain open |
| LCBH-008 | Current subsequent owner slice: token-bound copied run encoding stays explicitly prepared; immutable observation collection precedes final guard and only successful commit adopts it. Refusal/defer retains old World/owner/graph/record; restart records actual new generation, accepted defaults retire identity, and only explicit capture copies full record. Complete verified host/publication eligibility remains open |
| LCBH-009 | Current bounded Water Feel route: explicit unblinded sampled Exploratory rebuild retains original policy/recipe/player/actions/ledger, with exact serial/applied/definition success acknowledgement. The later desktop reference-body stage follows LCBH-012. Initial normalization never rewrites future sources; CY Water fractional scheduled sources, blind and unsupported body routes refuse before mutation. Original Current/blind defaults remain separate |
| LCBH-010 | Current apparatus/export boundary: an exporter identifies an unqualified build; explicit Web terminal JSON, successful POST, earliest console/network and ordinary visual execution are separately evidenced. Native headless Web-scene passes never become actual Wasm/browser acceptance |
| LCBH-011 | Current native adapter slice: decoded CYSD thermal tuples, including nonambient Empty, prepare under the existing one-use commit fence; actual source bytes bind payload-only identity, fractional whole-cell Water requires explicit normalization, and refusal retains old World/receipt/generation. Legacy Current import is unchanged; ordinary importer/host/platform qualification remains open |
| LCBH-012 | Current desktop reference-body route: original three Water Feel bodies remain frozen with actual initial masks until terrain/readiness and final native/worker fences pass; success adopts the same permanent space. Optional helper poses are copied and require exactly three finite entries before private allocation; omitted arrays preserve exact Water defaults and do not admit another constructor. Refusal retains the old graph/World/receipt/record. Normal unpaused feedback obeys age rejection and exact Water accounting; actual Wasm/visual qualification and host-mask CYPS continuation remain open |
| LCBH-013 | Current bounded synchronous import route: explicit Exploratory arming changes only the next-import selection. Unsupported inherited interaction/diagnostic laws and independent transport refuse before preparation; known private Baseline exemption binds actual component/generation/applied receipt. Native thermal preparation, private sampled player, final execution and qualified record precede final serial/native commit. Refusal retains old World/owners/receipt/record; restart retains accepted input. Physical/Tower/showcase imports refuse and unarmed Current remains available; no persisted policy/full-host/browser qualification follows |
| LCBH-015 | Current native default-demo API: ordinary reset and prepared compilation consume one native ordered recipe. Water/transport settings inherit; production interaction/diagnostic/gain/editing lifecycle resets on success. Candidate masks and copied receipts precede the one-use fence. Native origin binds actual generation and retires on other World replacements; imports with equal tuples cannot acquire it. Later bounded owner/capacity proof is LCBH-019; complete host and final platforms remain Planned |
| LCBH-014 | Current bounded synchronous ordinary-demo route: only four authored body-free recipes gain Exploratory rebuilding, with exact ordered tuples, privately staged sampled player and actual final quality/view/cadence before serial/native commit. Authored identity binds source ID and native generation, never an imported save label. Refusal retains World/owners/receipt/record; healthy Restart reconstructs accepted recipe/policy/geometry. Quarantined prepared Restart refuses, with truthful explicit Current/unarmed-import recovery; no implicit fallback or full-host/browser/rest-contact qualification follows |
| LCBH-017 | Current bounded synchronous Physics Pit route: exact authored recipe and original three poses stage in one permanent frozen space with copied same-request/token ownership and final execution before capture. At least two actual physics frames and bounded terrain readiness precede final serial/source/generation/settings/lifetime plus native commit fences. Refusal/cancel retains old World/player/graph/receipt/record and copies actual native attempt only; success adopts the same graph and Restart retains accepted recipe/selection. Imported same-label bodies gain no authored identity; runtime Web ownership and final platform/full-host gaps stay unchanged |
| LCBH-018 | Current bounded synchronous Water Feel body route: checked original recipe/actions/player and original y90 poses stage in the existing frozen permanent graph with final fixed Water view and retained quality/cadence. Actual native source generation/semantic identity, configured Baseline component/applied-receipt binding, copied settings/mode/profile, serial/lifetime/readiness and native retained-state fences precede commit. Refusal preserves old World/graph/receipt/record/cursors, including accepted old-world edits; success adopts without rebind. Restart and body-free change retain explicit family/normalization, and same-label generic imports gain no constructor identity. Actual native family/variant readback is required for multi-arm evidence; final Web/publication/full-host/Water-IN gaps remain separate |
| LCBH-019 | Current unmerged desktop native-default owner: copied native origin selects the shared recipe; actual sampled inputs, initial masks and frozen permanent bodies precede final request/settings/native/token guards and observation capture. Only success adopts owners, F7/PENV preferences and copied identity; R retains selection. Initial PF gas-capacity excess returns typed native refusal before swap, retaining the healthy World/graph/receipt/record. Future dynamic exhaustion quarantines. Local Windows proof and explicit Controlled/actor refusals do not establish final union/platform/full-host acceptance |
| LCBH-020 | Current unmerged union: Water CY and Water IN both trigger fractional future-source refusal before preparation; setup-only normalization never rewrites those actions. Actual desktop and synchronous refusal retains World/owner/body graph/native receipt/host record/reset input. Exact legacy default vectors remain immutable; capability-changed default physical hashes require the separately frozen policy/capability/hash-version namespace and unknown identities refuse |

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

## What must physics characterization preserve?

**Current:** opt-in observation must preserve exact matching-configuration cell
states and coupled trajectories. [Measurement checks](../operations/physics-characterisation.md)
cover observer toggles, phased worker parity, duplicate rejection, stored Water
under occupancy masks and explicit telemetry overflow. Failed-world quarantine,
interest-region pause/re-entry, conservation and exclusive ownership still apply.

**Current:** restricted powder exchange and sampled player support follow the
[versioned policy](../systems/granular-interaction-policy.md). **Planned:** persistent
powder bearing and roughly half-depth barrel support remain future behavior.
The [baseline](../audits/2026-09-09-physics-characterisation.md)
records failures of those proposed gates; it does not promote them to current
invariants or treat deep hard-floor rest as granular support.

## Granular character boundary

**Current:** Material-aware player support derives from local packing and last-tick stability. Unresolved enclosure is explicit, preserves cells and does not prove global connectivity. See the [granular/player policy](../systems/granular-interaction-policy.md).

Powder/powder density swaps are forbidden, while real void motion remains valid.
Optional [flow transport](../systems/flow-transport-and-profiles.md) is a distinct
conservative path: actual successful motion must precede mixing/pickup; resting
activity or state changes cannot stand in for flow. It preserves the existing
radius-two reads, radius-one writes, body/path exclusions and whole-cell state.
Profile tables are validated before exclusive-owner replacement, never mutated
inside a tick. Reduced sampling cannot weaken collision or conservation checks.
Mercury exchange cannot reuse a written destination or multiply its shared tick
lane across alternate directions/initiators. A pending deadline survives sleep
and exclusion without catch-up; explicit recovery abandons it with the world.

## Soliding successor invariants

The [lifecycle contract](../architecture/soliding-lifecycle.md) owns the detailed
state/eligibility table; the standalone model tests logical transitions only.

| ID | Scope and requirement |
|---|---|
| SOL-001 | Approved: exactly one cells/region/aggregate material owner; precommit refusal preserves it and postcommit failure quarantines the committed owner |
| SOL-002 | Approved: summary and stationary eligibility never manufacture dynamic granular cohesion |
| SOL-003 | Current standalone journal: bounded complete tile publication, ABA revision, explicit capacity/failure and starvation protection; real producer completeness remains Planned |
| SOL-004 | Approved future fracture: partition exact membership into coherent children and only genuinely loose cells; account inherited momentum/rotation and any motion loss |

## Generation authoring invariants

The [Workbench 2 contract](../systems/generation-workbench-2.md) requires truthful
bounded native replay tied to accepted identity and explicit unavailable/truncated
detail. Actual intermediate stage cells must agree with the normal native sampler;
turning off controls in a separate final recipe is not a stage implementation.
Invalid candidates preserve accepted recipe, preview and undo/redo history.
Successful edits, including history navigation and seed changes, invalidate old
preview/trace/comparison jobs through fresh session/revision identity.

Generated four-plane scene clearance is checked on the final projected play
materials after overrides. Native fixture feeds never paint their expected
reaction products; every required helper must complete and no-op/aborted cases
must fail. Counts, logical work, local timing, actual rendered pixels and visual
quality judgments remain separately labelled evidence.
