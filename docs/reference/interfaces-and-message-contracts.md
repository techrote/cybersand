---
title: Interfaces and message contracts
document-kind: contract
canonical-for: [public-and-adapter-interface-layouts]
status: Current
scope: Current C ABI, procedural-generation C++/Godot surfaces and private packed layouts; proposed gameplay/reconfiguration contracts remain distinct
keywords: [C API v2, material_info_v3, material_info_v4, body packet, INPUT_STRIDE, RG8, gameplay command]
related-documents: [../architecture/data-ownership-and-lifetimes.md, ../architecture/simulation-tick-and-threading.md, ../architecture/rendering-and-gameplay-bridges.md, level-saves-and-replay.md, ../architecture/pressure-optimization.md]
last-reviewed: 2026-10-25
---

# Interfaces and message contracts

The [actual common-Water Web terminal result](../audits/2026-10-25-lcb003-web-common-water.md)
uses the same source4948 JSON contract: compat77 checks (extra one-worker
assertion), threaded76, six Water and four mixed rows. Original POST201 bodies
and native/source equivalence are bound independently. A successful terminal
value still does not establish an ordinary rendered/manual control walkthrough.

The [final application union](../architecture/liquid-prepared-setup-and-receipts.md#final-application-source-union)
keeps existing native APIs/receipt-v1 unchanged. The native Web prerequisite now
reports `water_runs`: six ordered FM/CY/PF0/PF1/PF2/IN Water rows with copied
policy/receipt/payload hashes, radius/hash version, gross normalization,
30-tick quantity and whole-cell/IN-motion readback. All76 named checks and the
four original mixed rows are required by the003 parser; native process success
does not substitute for an actual browser terminal POST or visible user flow.

The private synchronous reference continuation now also owns a checked, copied
[supported-body Water Feel request](../architecture/liquid-prepared-setup-and-receipts.md#synchronous-supported-body-water-feel).
It captures the actual Water constructor kind, result/recipe, final480×270
execution and initial body values before native receipt creation, retaining
the existing one-use token and final guards. Its Water-specific installed tail
adopts the permanent graph and original actions; a refused construction never
reports successful installation. Known Baseline exemption binds actual source
generation/semantic hash/native component/applied receipt, never an import label.

## Explicit LCB application Web apparatus

`?test=1&liquid-host-test=1` runs a bounded startup apparatus through existing
synchronous application-owner APIs. It pauses normal processing only for this
explicit test. `cybersand-liquid-host-result` contains a terminal JSON value
with `schema_version`, `ok`, `terminal`, every named check/failure and copied
native identities/quantity/variant observations. The same terminal value is
POSTed to `/physics-results`; failed POST is an explicit console error. A DOM
readiness message is not a completed result or successful capture.

Native Windows headless execution qualifies the apparatus only. Browser
console/network and successful result receipt, actual compat/threaded execution
and ordinary user walkthrough are separate gates. Export identity has status
`source-built-web-export-unqualified` and
`browser_execution_status=not-established-by-export`; it supplies build target,
artifact hash and source claim without a validated-platform assertion. Read the
[qualified combined checkpoint](../audits/2026-10-25-lcb003-combined-host-web-prerequisite.md).

## Exploratory actor replacement acknowledgement

**Current desktop:** `scenario_reset` may carry copied
`exploratory_actor_definitions`, validated by the owner against the explicit map
allowlist, non-Benchmark mode and sampled-player ownership before installation.
`scenario_request_serial` identifies each reset; immutable `lab_context` publishes
that serial and `scenario_request_applied`. Desktop acknowledgement requires both
the request serial and definition hash, including when a sampled-to-sampled switch
leaves the map hash unchanged. Ordinary `queue_actor_prototype_reset` accepts an
optional `sampled_enabled` flag (default true); false requires an empty sampled
session and supports physical sandbox trials. See the
[programme](../operations/physical-actor-programme.md) for controls and limits.

## Current public surfaces

### Native procedural generation and fresh-chunk admission

**Current GEN-001/GEN-002 source:**
[`generation::Generator`](../../native/include/cybersand/world_generation.hpp)
compiles a value-only recipe into immutable theme/field/aggregate/module state.
`begin(ChunkCoord, diagnostic="")` creates a private `GenerationJob`; `advance(cell_budget)`
limits work, and `result()` refuses access while pending. Ready results contain
copied row-major materials, coordinates, revision, recipe fingerprint, content
hash and an admission receipt binding those identities and optional diagnostic
channel/float data. Failed/cancelled jobs expose neither cell nor diagnostic
payload. `accepts(result)` checks complete current recipe/receipt
identity; it does not identify the lifetime of a separate mutable World.

[`World::install_generated_chunk`](../../native/src/world.cpp) takes a coordinate
and immutable material span under the existing exclusive owner, between ticks.
It validates the whole payload and admits only an absent storage chunk; resident
empty, reserved and edited-then-cleared chunks remain protected. Its explicit
outcomes cover refusal/capacity/ownership conditions. This material-only method
does not perform generator-revision or World/reset-session checks: the caller
must establish both before admission. It is a C++ primitive, not a new C ABI or
an automatic desktop streaming command.

[`CyberWorldGenerator`](../../godot/native_extension/cyber_world_generator.hpp)
is a separate serialized Godot `RefCounted` owner with `configure`,
`get_configuration`, `get_catalogue`, `generate_chunk`, `begin_chunk` and
`advance` methods. It returns copied dictionaries/bytes and retains the last
valid configuration on validation failure. Its single pending job is retired
when a new accepted configuration replaces the generator. The opt-in workbench
consumes these proposals for preview; it never acquires a live World reference.
The two chunk methods accept an optional `field:<id>`, `modifier:<id>` or
`module:<id>` channel. Ready packets include `diagnostic` and copied
`PackedFloat32Array` `diagnostics` alongside `PackedByteArray` `cells`; no channel
means an empty array. Native receipt validation precedes copying, while the UI
also checks its current identity, expected coordinate, channel and normalized
shape. The [field contract](../systems/procedural-generation-fields-and-modifiers.md)
owns scalar DAG/context semantics and catalogue descriptors.
The [generation contract](../systems/procedural-world-generation.md) owns exact
schema and packet fields, module trust and source/runtime limits.

**Current schema-2 / GEN-003 extension:** recipes may additionally contain
`spatial` (`nodes`, `subgraphs`, `instances`, `geometries`, `assignments`) and
`spatial_limits`. Native `SpatialGraph` returns a typed `SpatialValues` array
with per-output `SpatialInfo`; its evaluation takes absolute coordinates and
optional caller-owned bounded `SpatialScratch`, with no initial-context or live
World input. `Generator::spatial_graph()` exposes const compiled metadata.

`spatial:<expanded.id>` requests a typed diagnostic. Native results store
`diagnostic_info` and `typed_diagnostics` exclusively from the legacy float
diagnostic array. The adapter copies numeric values to `PackedFloat64Array`
`diagnostic_values` (one scalar or interleaved x/y vector components per cell).
Exact category tuples use `PackedStringArray` `diagnostic_categories`: signed
decimal x, signed decimal y and a 16-digit hexadecimal domain per cell.
`diagnostic_info` identifies type, unit exponent, component bounds, distance
factors, scale, fingerprint and declared work. The receipt binds those values
and rejects malformed/mismatched payloads before adapter publication.

The same `spatial:<id>` reference in a modifier, module, mapping or aggregate
accepts only an explicitly `normalized` output. This is distinct from selecting
a diagnostic of any type. Workbench colours are presentation; raw signed,
vector and exact category data remain inspectable. `get_catalogue` adds
`spatial_kinds` and accepted `spatial_nodes`. Complete configuration roundtrips
retain subgraphs, typed bindings, immutable inputs and explicit schema selection.
GDScript JSON writers must request `full_precision=true`, for example
`JSON.stringify(recipe, "  ", true, true)`, to preserve accepted double values
and `get_catalogue().spatial_fingerprint`. Reconfiguration advances the adapter
revision and overall recipe fingerprint even when the spatial graph is unchanged.
See the [typed graph contract](../systems/procedural-typed-spatial-fields.md) and
[operator inventory](procedural-spatial-operators.md) for exact semantics.

### Native semantic plans and copied hierarchy inspection

**Current schema-3 / GEN-004 extension:** `Recipe::grammar` is a versioned
`GrammarDefinition`. `GrammarPlan::compile(definition, seed)` returns immutable
features, sockets, routes and constraint receipts, with finite `bounds()`,
`fingerprint()`, work/storage metadata, ID lookup, bounded rectangle `query()`
and `ancestry()` APIs. Feature IDs include the world namespace, region grid size,
signed region address, parent path, rule ID and stable numeric slot. Content
revision, recipe revision and receipt identity are separate values.

`Generator::semantic_plan()` exposes the const plan. `validate_routes()` returns
the complete retained report for final material cells and the declared odd square
clearance profile. `RouteValidation::passed` records the aggregate required-route
result; `supports_passed` independently records final solid contact for declared
floor/ceiling/wall constraints. The named profiles are `floating-square-v1` and
`static-solid-contact-v1`. `SupportOutcome` carries `feature_id`, `constraint`,
`passed`, `checked_cells`, `missing_cells`, `first_missing_x/y` and `detail`.
One surviving contact suffices for a support check; the wall check scans both
vertical sides. The report records success/failure per required explicit route;
intentional final hard material blockers remain in the material output and fail
their route checks. `explain(x,y)` returns a bounded `CellProvenance` value with
final material, semantic ancestry, constraint receipts, stage contributions and
scalar/typed field values. Native query pointers borrow only their immutable
plan, so callers must retain that plan's lifetime.

Godot adds `get_semantic_plan()`, `inspect_cell(Vector2i)` and
`validate_routes()` to the separate `CyberWorldGenerator`. They return copied
dictionaries/arrays; no live World or feature pointer crosses the adapter.
The copied report includes `support_profile`, `supports_passed` and a `supports`
array using those same outcome fields. `configure` includes this report for accepted grammar recipes, while
`get_configuration` preserves the authored `grammar` declaration. The grammar's
`district_assignment` wraps GEN-003 `specification` and optional `limits`, and
`district_themes` uses exact 16-digit lowercase hexadecimal keys. Typed feature
parameters use the existing `SpatialValue` JSON encoding. Unknown fields and
malformed inputs reject transactionally, preserving the previous configuration.
The [hierarchy contract](../systems/procedural-hierarchical-generation.md) and
[grammar JSON schema](../../examples/worldgen/schemas/grammar-v1.schema.json)
own exact semantic meaning and relational checks.

### Semantic plane proposals and owner admission

**Current GEN-005 extension:**
[`PlanePlan::compile`](../../native/include/cybersand/generation_planes.hpp)
takes shared immutable ownership of one `Generator` plus a versioned
`PlaneDefinition`. It exposes copied/value features, projections, fixtures,
links and actors through the adapter, together with `bounds`, `fingerprint`,
`preparation_work`, `operations_per_cell` and `storage_bytes`. Native const
record references borrow the plan lifetime. `sample`/`explain` use absolute
world coordinates; projection records retain geometry references, application
and exclusion fields, transitive field fingerprints and semantic feature IDs.

`begin(RectI64)` produces a private `PlaneGenerationJob`;
`advance(cell_budget)` counts staged plane cells. Pending, Cancelled and Failed
states expose no material arrays. Ready results include bounds, revision, plan
fingerprint, four content hashes, four row-major material arrays, operation
accounting, fixture/link/actor registration IDs and a receipt hash.
`accepts(result)` checks the complete current plan/result binding. Canonical
registration anchors give disjoint requested tiles exactly one union of IDs.

The serialized `CyberWorldGenerator` adds `get_plane_plan`,
`generate_plane_bundle`, `generate_plane_region(Rect2i)`,
`begin_plane_region(Rect2i)`, `advance_plane_region(cell_budget)`,
`cancel_plane_region` and `inspect_plane_cell(plane, Vector2i)`.
`semantic_planes` configuration remains transactional. Its explicit authored
revision keeps identical retries stable; `adapter_serial` separately records
the monotonic configuration request. Accepted reconfiguration retires pending
jobs, while validation failure preserves the last valid plan.
Ordinary `generate_chunk`/`begin_chunk`/`advance` packets retain the monotonic
adapter revision returned by `configure`, including for semantic recipes, so
the existing workbench's current-request check remains compatible.

A complete copied dictionary has `ok`, `schema`, `algorithm`, `id`, hexadecimal
`revision`/`definition_revision`/`fingerprint`, `bounds`, `plan_bounds`, rates,
budgets, policies, feature/projection/fixture/link/actor arrays, copied
`materials` (`PackedByteArray` per plane), `hashes`, registration ID arrays and
`receipt_hash`. Only whole-bundle output has `complete=true` and `layers`
(`PackedInt32Array` local `x,y,width,height,material` rectangles). Tile output
has `complete=false` and cannot be submitted as a host replacement. Inspection
returns copied material and feature→projection→fixture/link/actor provenance;
no mutable native World or Godot object is exported.

[`CyberSemanticPlaneRuntime`](../../godot/scripts/depth/semantic_plane_runtime.gd)
validates a complete packet, reconstructs and checks its materials, then stages
all four Worlds plus the existing play actor session before one synchronous
publication boundary. `install_bundle(candidate, expected_generation)` returns
false with `last_error` on rejection. A differing replacement requires the
current generation; an identical fully validated retry is idempotent. Reset,
activate and retire calls return copied identity-bound lifecycle receipts.
`lifecycle_stats()` exports per-fixture applications, cleanup, active/retired
state and aggregate accounting. `actor_snapshot()` copies the existing session
with semantic IDs and bundle/reset identity; actor commands use its existing
leased mailbox, exclusively on play.

`event_observation(link_id)` issues a copied one-use observation with bundle,
generation, link and endpoint revisions, planes, source tick, serial, bounded
cell/radius and permitted material. `submit_event` checks those identities;
only center/radius may vary within the registered zone. Accepted commands use
the retained play→scripted `blast` or scripted→effects `burst` owner routes.
Static/presentation links issue no runtime authority. Reset or retirement
invalidates observations; raw painting/event bypass methods reject on this
owner. See the [semantic contract](../systems/procedural-semantic-planes.md)
for classification and the [limits](configuration-reference.md#semantic-plane-generation-limits)
for finite capacity outcomes.

### Native C API

**Current:** [c_api.h](../../native/include/cybersand/c_api.h) defines the
exported `cybersand_` functions; [c_api.cpp](../../native/src/c_api.cpp) defines
validation and failures. The header is the source of exact C types/alignment.
These host-ABI structs are not a portable serialized file/network format.
Signed `int64_t` positions and rectangle dimensions are cell coordinates;
`size_t` capacity/stride/offset widths depend on the target ABI.

Start v2 construction from `cybersand_default_config_v2()`. `create_v2` checks
`struct_size >= sizeof(cybersand_config_v2)`, `abi_version == 2`, valid backend
range and checked conversion of 64-bit capacities to host `size_t`, then World
validates geometry/capacities. It returns null on invalid configuration or
caught construction failure. Buffered is a representable backend value, but
its tick implementation throws.

| Versioned surface | Current additional fields/behavior |
|---|---|
| `cybersand_config_v2` | Size/version; chunk/activity/core/radius; sleep and ambient temperature; backend/workers; chunk reserve, job threshold, active-core/chunk/max-chunk/event capacities and maximum explosion radius |
| `cybersand_tick_stats_v2` | Legacy tick/visited/moved/active/dirty counts plus scheduled cores, four phase-job counts, owned chunk/temperature allocations and committed deferred events |
| `cybersand_material_info_v2` | Base material metadata plus kernel, initial state bytes and write radius |
| `cybersand_material_info_v3` | v2 base plus density-motion direction, target exchange acceptance and lateral-flow mode |
| `cybersand_material_info_v4` | v3 base plus dimensionless 0–255 viscosity index |

Material-info v3/v4 are additive query layouts; they do not change the config
ABI version from 2. Valid material queries return 1; invalid ID or null output
returns 0. Density metadata is a gameplay scale, not a declared physical density
unit. Native optional temperature is signed 16-bit storage; physical thermal
calibration/conduction is not defined by this API.

Checked set/tick/reservation/explosion/copy methods return 1/0; legacy set/tick
surfaces provide weaker error reporting. `tick_v2` zeroes output after a caught
exception, but **does not roll World back**. Null input/output also fails; no
structured C error reason is returned. Additive `has_failed`,
`completed_tick_index` and `clear` queries/operation expose quarantine and explicit
reset without changing v2 struct layout. Native `tick_index` remains attempted
identity; `completed_tick_index` is the last successful tick. Hash and resident-byte queries are
[scoped diagnostics](../architecture/determinism-and-boundary-transfers.md),
not complete replay capture or process-memory accounting.

### Godot worker surface

**Current desktop:** `start_worker`/`stop_worker`, `set_frame_state`,
`set_rigid_body_states`, `queue_emit_disc`/`queue_paint`, `queue_reset`,
`take_latest_snapshot`, `acknowledge_render_snapshot` and
`request_render_full_refresh` are GDScript methods, not a stable native ABI.
Web calls its exclusive native adapter synchronously and does not instantiate
this worker protocol. Source: [simulation_worker.gd](../../godot/scripts/simulation_worker.gd).
Ownership and timing are defined by [lifetimes](../architecture/data-ownership-and-lifetimes.md)
and [step order](../architecture/simulation-tick-and-threading.md).

### Optional actor prototype control surface

**Current, experimental desktop:** `queue_actor_prototype_reset`,
`submit_actor_action`, `submit_actor_rig_action` and `cancel_actor_input` are
GDScript worker methods for the bounded [actor rig session](../systems/actor-rigs.md).
Reset definitions are copied; the reset method returns zero on refusal or a
positive request receipt. Snapshot reset-serial/applied/status fields separately
report the owner outcome after it rechecks scenario authority. Action admission validates actor/producer, epoch,
sequence and observation-derived expiry before retaining a bounded input value.
`CyberSimulationSnapshot.actor_prototypes` carries copied session identity,
capabilities and fixed-stride observation rows. The [SetA compatibility page](../systems/actor-control-prototypes.md)
owns the original two-button command and 16-float order. The
[v2 rig contract](../systems/actor-rigs.md#what-action-does-a-player-or-neural-policy-submit)
adds independent aim, effort, trim, reel and auxiliary, plus 40-float rig rows.
The old fields remain additive-compatible; SetA still instantiates its original motor.

`sequences` reports latest admitted input. `applied_sequences` and ten-float
`applied_actions` rows identify the last consumed live command; `applied_flags`
retains held, pressed and cancellation bits so brief taps are not lost from
readback. The v2 contract owns the exact field order and flag values. These
publications remain observations rather than complete replay state. `rig_capabilities`
converts catalog body/color values to numeric arrays for structured JSON retention.

This is an in-process adapter seam, not a network protocol, native C ABI, trained
policy or Web input implementation. Existing native material/collision interfaces
and main-thread Rapier ownership are unchanged. New-rig tools may invoke the
existing owner-local single-cell emission adapter under explicit per-update
budgets; a policy cannot supply an arbitrary World operation or effect footprint.


### Optional actor usable control surface

**Current, retained sampled USABLE-001:** `submit_actor_usable_action` and
`cancel_actor_usable_input` are a second copied-value input domain beside sampled
movement. Physical ACT-005 control uses the issued-observation envelope in
[physical equipment actions](#physical-equipment-actions-and-results) instead.
A submission carries actor ID, actor epoch, an equipment-local monotonic sequence,
observed actor tick, usable index, finite aim, power, two held buttons, lease and
the assigned producer identity. `usable_index=-1` means unequipped.

The owner retains the latest held values and latched rise edges rather than an
unbounded FIFO. Changing equipment while either trigger is already held requires
both buttons to be released before a later press can activate the new item.
Expiry/cancellation neutralizes held equipment without deleting committed
projectiles or deployed processors.

`CyberSimulationSnapshot.actor_usables` is copied readback containing selection,
charge/cooldown/result, committed entities, effect/hit receipts and bounded-work
counters. It exposes no World, motor, scene-tree node or Rapier RID. Exact item
semantics and capacities belong to the
[actor-usables contract](../systems/actor-usables.md) and
[configuration reference](configuration-reference.md#actor-usable-values).

### Direct actuator lane and Thunderbowl envelopes

**Current, experimental ACT-003:** actor definitions may add `control_mode`
(`wire` by default, or `metal`). Metal requires a declared Ripper, Copter or
Gemini profile and a human/policy producer; unsupported combinations are refused.
The worker value seam is:

```gdscript
submit_actor_actuator_action(actor_id: int, epoch: int, sequence: int,
    observed_tick: int, actuators: Vector4, lease_ticks: int = 12,
    producer: StringName = &"policy") -> bool
```

The session method is `submit_actuator_action`. It retains the existing
producer/epoch/sequence/observed-tick lease checks, with held latest values and
no action-button edges. Raw profile channels map to forces/torques without the
intent motor's steering, stabilization or traversal assistance. Passive physics,
resource gates and the existing bounded collision path still constrain motion.
The session adds `control_modes`, `actuation_version:1`, `actuation_stride:32`,
`actuation_states`, `actuation_profiles` and copied `actuation_capabilities`.
Wire rows in that new array are zero; metal rows in `applied_actions` are zero.
`applied_sequences` continues to identify the consumed lane's command. Existing
16/40/10 strides and their meanings are unchanged.

The standalone arena wraps this typed seam in strict version-1 JSON envelopes.
It issues opaque run/observation identities, derives producer assignment from
configuration and checks lane, liveness, monotonically increasing sequence,
observation issuance/freshness, communication privilege and command capacity
before admitting values. Command admission is not a hit or movement guarantee.
Its copied self/local/oracle observation formats, human device frames, typed
messages, slow model intentions and JSON Schema files are owned by the
[Thunderbowl reference](../systems/thunderbowl-control-reference.md).

### Sampled-player granular disturbance adapter

**Current private Godot adapter:** `character_disturb_granular(origin, size,
impact_speed)` is a serialized owner operation used only by
`CyberSampledCharacter` and its `CyberActorPrototype` subclass after an accepted
downward granular collision. It is not
part of the public C ABI or the rigid-body packed result format. Position/size are
finite finite-adapter cell/pixel coordinates; impact speed is downward
cells/pixels per second. Malformed/out-of-world input, failed worlds, impact below
24, hard-surface involvement or the absence of supported foot-edge grains returns
zero moved cells.

The operation has a fixed maximum of one move for impact speed 24..<72 and two
moves at >=72. Each move is one whole stored granular cell to an outward/up
diagonal Empty destination through the existing conservative relocation machinery;
state/temperature and wake/dirty semantics are retained. It creates no queue,
unbounded search, material ownership transfer or Rapier contact. The GDScript
fallback mirrors the same bounded surface. See
[granular/player policy](../systems/granular-interaction-policy.md#rem-003-sampled-player-landing-response)
for the gameplay semantics and owner-acceptance boundary.

## Gameplay command contract

**Current desktop emission encoding:** `Vector4i(x, y, radius, packed)` where
`packed = (material_id & 255) | (emission_flags << 8)`. `queue_paint` forwards to
`queue_emit_disc`; consecutive identical pending emissions are coalesced.
The only defined option is coherent-liquid emission. UI slots never cross this
boundary. The dynamic queue has no production capacity, target-tick ID or
target-tick acceptance acknowledgement. `queue_emit_disc` now returns false
when the published owner is failed (true only admits/coalesces a pending command,
not a promise of application). Failure/reset clears pending emissions without
replay. Reset/frame inputs are separate latched fields.

**Approved:** future commands need bounded immutable value data, deterministic
accepted ordering and explicit failure. **Planned:** the generalized schema,
queue/backpressure policy and exact target-tick semantics. Do not infer them
from this prototype encoding.

<a id="rigid-body-coupling-contract"></a>

## What crosses the rigid-body bridge, and which limits apply?

**Current private adapter format:** `PackedFloat32Array`, not a versioned C ABI.
Source: [rigid_body_coupling.gd](../../godot/scripts/rigid_body_coupling.gd),
[native parser/results](../../godot/native_extension/cyber_native_cell_world.cpp).
Offsets below are float indices within each record.

| Input stride 11 | Field | Result stride 9 | Field |
|---|---|---|---|
| 0 | Body ID | 0 | Body ID |
| 1–2 | Centre x/y | 1–2 | Central impulse x/y |
| 3 | Rotation | 3–4 | Positional correction x/y |
| 4–5 | Full rectangle size x/y | 5 | Contact count |
| 6–7 | Linear velocity x/y | 6 | Displaced-cell count |
| 8 | Angular velocity | 7 | Unresolved-cell count |
| 9 | Mass | 8 | Sample serial |
| 10 | Sample serial | — | — |

Positions/sizes/corrections use pixels/cells, rotation radians, velocities
pixels/second and radians/second. Mass/impulse use the Godot adapter's quantities;
production physical-unit calibration remains unresolved. IDs/counts/serials
travel as floats. ACT-004 parsing considers at most 64 complete records, accepts
integer IDs 1–64 and integer sample serials 0–16,777,215, rejects any nonfinite
field or nonpositive size/mass, ignores trailing partial records and retains
the first duplicate. Accepted full sizes clamp to at least one cell and mass to
0.001. The same finite-record predicate is used by the fallback and bridge.
The physical session rejects a complete assembly beyond capacity before spawning.
SetP circular wheels supply their diameter as a circumscribed square in this
unchanged rectangle layout. Rapier hard contact and graphics use circles;
native masks and displacement retain the explicit conservative approximation.
General contours and cellular torque feedback remain Planned; these private
packed records are not an unrestricted public network protocol. Numerical response and sample-age policy belong in
[coupling](../architecture/rigid-body-and-cellular-coupling.md).

## Immutable dirty snapshot contract

**Current native:** `cybersand_render_patch` stores `int64_t` x/y/width/height
plus byte offset and row stride. Payload is two bytes/cell: material ID and
read-only condition projection. `take_dirty_chunks` with null/insufficient
output returns required count without clearing; failure uses
`CYBERSAND_SIZE_ERROR`, not zero.

`cybersand_world_publish_render_snapshot` returns call success (1/0), separately
from its output status: NoChanges=0, Published=1, Backpressure=2,
CapacityExceeded=3. Call success therefore does not mean a snapshot published.
Result includes serial and required patch/byte counts. `acquire_latest(after_serial)`
returns a lease or null; lease bytes remain valid until lease destruction even
if the exchange handle is destroyed. Publication must serialize with World.

**Current Godot:** six `PackedInt32Array` values per patch are x, y, width,
height, byte offset, row stride. Snapshot also carries render serial, channels,
full-refresh flag and copied byte array. Native is RG8; fallback is R8. The
adapter selects three slots, 64 patches/slot and 2,097,152 bytes/slot for its
finite world. These are prototype defaults, not universal production budgets.

**Current desktop additive metadata:**
`CyberSimulationSnapshot.render_world_generation` identifies the accepted
World/reset incarnation represented by the retained render bytes. The exclusive
owner increments its counter after successful reset/replacement, then copies it
into the pending render generation only when those replacement bytes are
published. It is independent of native revision numbers, actor/body epochs,
render serials and `render_full_refresh`. Full-image transport resyncs and
ordinary R8 fallback frames retain the same World generation. Consumers update
their displayed generation only after successful upload of the corresponding
render serial; main uses that transition to invalidate vapour history. This is
private GDScript snapshot metadata and does not change the native C ABI.

See [snapshot fields](../../godot/scripts/simulation_snapshot.gd),
[lifetime](../architecture/data-ownership-and-lifetimes.md) and
[consumption/failure](../architecture/rendering-and-gameplay-bridges.md).

## Gameplay result contract

**Current:** copied character metrics/body observations. **Approved:** generalized
results must be immutable with explicit IDs, capacity and retention.
**Planned:** final categories and full-result pressure behavior.

## Interest-region update contract

Current native/Godot setters are documented in the
[interest contract](../systems/world-storage-and-interest-region.md), including
backend differences and the bounded pause/resume contract. Region requests latch
requested core coverage; newly included resident blocks wake at tick entry, not
in the setter. Failed-world requests cannot step or wake partial state. **Approved:** explicit requested bounds
and diagnosed capacity. **Planned/Ambiguous:** serialized percentage semantics,
multi-camera policy and live reconfiguration responses.

## TileJob contract

Current jobs are internal core indices and local effects. **Approved:** bounded
views, exclusive phased writes and no retained views after a barrier.
**Planned:** a public type-enforced job/rule context. See
[geometry](../architecture/chunk-tile-and-buffer-model.md).

## Boundary-transfer contract

**Planned:** buffered cross-output records, bounded assigned storage and
canonical merge. No generalized schema/sort tuple exists. Ordinary phased
movement is direct; the Current external explosion queue is a separate narrow
contract. See [ordering](../architecture/determinism-and-boundary-transfers.md).

## Capacity reconfiguration transition

**Approved, unimplemented:** drain affected views, replace capacity intentionally,
then resume with valid state and explicit outcome. No state-machine/API or
failure policy is defined. [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
records the decision; current tick exceptions do not implement this guarantee.

## World serialization contract

The canonical [level saves versus exact replay](level-saves-and-replay.md)
contract owns CYSD1 fields, validation, exclusive export/import, omissions and
future replay requirements. Level reconstruction is Current; general streamed
persistence and exact replay are Planned. This stable route intentionally avoids
a second copy of the format specification.

## Failed-tick adapter status

**Current:** native Godot `simulation_tick()` returns false on first failure and
all later calls until recovery. `has_failed()` is independent of user pause;
`get_tick_index()` reports completed identity, `get_attempted_tick_index()` reports
the failed attempt. First error/count persist; repeat rejection does not increment
the count. Tick statistics are zero on failure, and body results are empty.
`reset_demo_world()` returns bool and swaps a prepared candidate on success.
Validated `CyberDemoBridge` import/construction is another recovery path; invalid
replacement preserves the fault. Explosion enqueue returns false with a bridge
error while failed. Render packet failure has `failed` and `error` with no payload.

`CyberSimulationSnapshot.simulation_failed` and `failed_tick_index` distinguish
failure status from its retained last-valid `tick_index`/display payload. Desktop
`CyberSimulationWorker.has_failed()` reads that status under its mutex. No caller
may treat the failed attempted identity as a successful publication. See
[tick/recovery semantics](../architecture/simulation-tick-and-threading.md).

## Which physics diagnostic interfaces are opt-in?

**Current:** `CyberNativeCellWorld` exposes `diagnostic_reset(options)`,
`diagnostic_fill_rect(origin,size,material,state_b=0)`,
`diagnostic_snapshot(origin,size,include_histogram=false)` and
`diagnostic_body_metrics()`. Their bounded schemas, units and valid options are
owned by the [measurement runbook](../operations/physics-characterisation.md).
Reset constructs a fresh empty fixture; invalid options preserve the old world.
These calls must use the existing serialized adapter owner.

The ordinary body sample/result ABI, C header, immutable gameplay snapshots and
CYSD1 format are unchanged. No diagnostic options are persisted as gameplay
configuration or advertised as a complete replay format.

## Directional player query

Both adapters expose `character_box_collides(origin, size, mode)` under the
exclusive owner. `box_collides` is full-volume mode 0. The [player policy](../systems/granular-interaction-policy.md)
owns modes and limits. Body messages and saves retain their existing schemas.


## Issue #13 experiment checkpoint

`CyberSimulationWorker.queue_lab(Dictionary)` is a developer-lab command boundary: reset/floor, single-step, release and a two-release schedule. `CyberSimulationSnapshot.lab_context` publishes copied status/input metadata. [Tower controls](../operations/experiment-tower.md) own semantics; this is separate from CYSD1 and the C ABI.

### Desktop Water exit receipts

**Current:** [main.gd](../../godot/scripts/main.gd) records a fresh positive
per-controller serial in `pending_water_exit.request_serial` for both Fresh tower
and ordinary profile resets. The reset command and copied
`CyberSimulationSnapshot.lab_context` use the following fields:

| Field | Producer and meaning |
|---|---|
| Command `water_exit_request_serial` | Controller-issued identity of this reset/Water-exit request |
| Context `water_exit_request_serial` | Worker echo of the reset it actually processed; zero is untracked |
| Context `water_exit_request_applied` | Worker initializes false before any reset failure path and sets true only after successful native candidate installation |

[Worker `_apply_lab` and `_publish_snapshot`](../../godot/scripts/simulation_worker.gd)
publish the outcome through the existing snapshot copy. Controller
`_reconcile_water_exit` requires an exact positive serial match and a present
outcome. A matching false result clears the pending request while preserving
blind state; a matching true result also requires `water_active=false` and a
`profile` before ending/restoring the blind session. Missing or stale receipts
leave the pending request intact. Human-readable `status` is never an exit
acknowledgement. This is a desktop control message; native ABI, saves, Water
policy schema and the synchronous Web path are unchanged.


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## MicroScenario control and capture messages

**Current MS-000:** desktop reuses the existing bounded one-pending-lab-command
slot. `scenario_reset` carries a complete validated definition; `scenario_mode`
is Play/Inspect/Benchmark. `scenario_capture` requests an owner-boundary record
and `identity` carries main-thread file fingerprints. No arbitrary callback or
live World reference crosses this interface. The UI prevents step/capture from
replacing a pending generic reset, and waits for the matching definition hash
before acknowledging it. The legacy lab slot otherwise retains its documented
newest-command behavior; this is not a general queue redesign.

The immutable lab context adds `micro_active`, `microscenario`,
`micro_capture_serial` and `micro_capture`. The synchronous Web controller invokes
the same owner-local host directly. Existing #19 keys are compatibility projections
of the host's action ledger. Full schema, units, capacities and export limitations:
[MicroScenarios](../operations/microscenarios.md).

### LCB-001 liquid solver policy adapter (experimental)

`CyberDemoBridge.build_liquid_policy_world(world, rectangles, profile, policy,
water_fills, liquid_policy)` is `build_water_feel_world` plus a flat
`PackedInt32Array` policy request. The request is decoded and admitted before any
World is built. A refusal returns false, keeps the live World, its receipt and its
`session_generation`, and exposes `{code, material, detail}` through
`get_last_liquid_policy_refusal()`. `validate_liquid_policy()` has no side
effects, and `default_liquid_policy()` returns the build's explicit default
request. `CyberNativeCellWorld.get_liquid_solver_policy()` returns the applied
receipt. These calls share the serialized-owner rule of the other bridge
construction methods. The canonical contract, refusal table and receipt fields are
in the [family policy](../architecture/liquid-solver-family-policy.md#native-policy-foundation-current-2026-10-24);
the C entry points are experimental and not a frozen ABI.

### LCB-001 pressure reference inspection and persistence (experimental)

**Current pressure APIs from #245, with shared hash2/CYPS2 accepted on main in #246.** These calls
serve the opt-in [`pressure_flow_v1/reference`](../architecture/pressure-flow-v1.md)
and follow the same serialized-owner rule as the bridge calls above. Results own
their dictionaries; none exposes live World storage.

| Call | Result |
|---|---|
| `CyberNativeCellWorld.get_physical_state_hash()` / `get_physical_state_hash_version()` | 16-hex-digit FNV-1a `World::physical_state_hash()`; Current main version 2 includes exact shared accounting. Historical #245 version 1 is retained evidence; `content_hash`/`state_hash` are unchanged |
| `inspect_gas_compartments()` | `available` (false outside pressure Worlds), parameters, `topology_revision`, `next_id`, `completed_tick`, `compartments` (id, generation, ancestry, amount, volume, anchor, created tick, topology revision, `gauge_mass`, `vent_state`), retirement `history` with reason and successors, and the `ledger` with `closes` |
| `inspect_pressure_cell(point)` | `available`, material, `state_a`, `overfill`, `flow`, `gas` (`compartment`/`atmosphere`/`vacuum`/`unresolved`) and `gas_compartment` |
| `get_pressure_flow_ledger()` | overfill converted/external, flow remainder, contact loss, relief cells and `last_tick` diagnostics |
| `get_liquid_run_receipt(setup)` | older experimental dictionary/string hash and components, including actual simulation-region and physics-changing diagnostic overrides; this is not the typed native-v1 receipt ([fields](../architecture/liquid-solver-family-policy.md#native-policy-foundation-current-2026-10-24)) |
| `get_liquid_solver_policy()` | adds `family_parameters` and `physical_state_hash_version`; `admission` is `current_defaults_only` or `qualified_candidate` |
| `water_experiment_observation` | adds `water_visible` and `water_overfill`; `water_integer` = visible + overfill (overfill is 0 outside pressure Worlds) |
| `CyberDemoBridge.inspect_cell(world, point)` | adds `family_state` (`family`, `overfill`, `flow`, `gas_label`) in pressure Worlds |
| `CyberDemoBridge.export_physical_state(world)` / `import_physical_state(world, bytes)` | Current main writes CYPS2 and explicitly refuses historical CYPS1; import re-admits saved policy and preserves the running World on refusal ([persistence](../architecture/pressure-flow-v1.md#persistence-cyps-v2)) |

Native counterparts on `World` are `pressure_flow_enabled`,
`pressure_flow_parameters`, `pressure_cell`, `gas_compartments`, `gas_history`,
`gas_ledger`, `gas_topology_revision`, `gas_next_id`, `pressure_flow_ledger`,
`pressure_flow_diagnostics`, `water_quantity`, `physical_state_hash` and
`save_physical_state`/`restore_physical_state` (`kPhysicalStateFormatVersion` 2)
in [`world.hpp`](../../native/include/cybersand/world.hpp) and
[`pressure_flow.hpp`](../../native/include/cybersand/pressure_flow.hpp). No C API
entry point exposes them. The C API/global ABI is not frozen by these additions.

### LCB-005 standalone instance readback

Current #212 branch source exposes copied `get_physical_state_format_version()`
and `inspect_inertial_cell(point)` beside the actual instance hash-version
getter. Non-IN instances report2 and IN instances3. Applied policy readback
includes the actual IN damping/extension digest and execution radius; policy-only
validation labels its values as predictions. The old dictionary run identity
binds actual version and IN parameter identity without becoming typed host proof.

`build_liquid_policy_world(..., maximum_rule_radius=2)` accepts exactly2/3 and
requires explicit3 for Brine IN. Ordinary/default/CYSD1 reconstruction returns
to2. CYPS continuation retains saved geometry. Calls remain serialized to the
exclusive adapter owner; outputs expose no mutable World storage. The
[IN reference](../architecture/inertial-cellular-v1.md#standalone-godot-readback-and-explicit-geometry)
owns fields, refusal behavior and the local Windows-only qualification.

CYPS omits host-owned transient masks and body graphs. Exact body-coupled
continuation requires separate restoration of the same mask configuration and
future sampled body inputs; the adapter physical-import call alone does not
provide that complete prepared owner restoration. The
[moving-mask gas repair record](../audits/2026-10-25-pressure-moving-mask-gas-retirement.md)
retains this #202/#203 qualification and the strict native live-label invariant.

The isolated Water successor adds native `World::whole_cell_water_enabled()`:
true for Water CY or Water IN, distinct from the CY-only dispatch accessor.
Internal/live ingress, CYSD preflight, final legacy overlays and CYPS validation
share that regime. `mix_after_motion` now returns the actual native carrier
coordinate, which IN consumes immediately after each physical Empty move.
These are engine-internal ownership interfaces, not host mutation/value APIs.
Outer receipts, IN sidecar fields, parameter schemas and saved versions retain
their contracts; capability/policy digests are freshly regenerated.

### LCB-002 copied pressure optimization observations

**Current in #201 branch source, pending runtime and final CI:** the exclusive
adapter owner serializes these calls with ticks. No result exposes mutable
World/cache storage or authorizes simulation skipping.

| Call | Copied result |
|---|---|
| `CyberNativeCellWorld.get_liquid_comparison_hash(1 or 2)` | Sixteen hexadecimal digits in the named same-tick or quiescent diagnostic domain; unknown IDs/unavailable World return an empty string. Complete continuation hashes retain their separate meaning. |
| `CyberNativeCellWorld.inspect_pressure_optimization()` | Schema1 status, actual cached/dormant flags, execution3/identity-encoding1, requested budgets, observed capacities and cumulative work. Unsigned fields are decimal strings; status/version fields are small integers. Attempts count actual proofs; declines include warmup/backoff and obligation deferrals. |
| `World::prepared_pressure_head(x, y)` | A value/status copy of the last prepared slot: family unavailable, nonresident, no head, unresolved encoded sentinel, or prepared numeric head. Valid zero differs from no head. It can be stale after transport/edits and unprepared after restore; it is not current cell pressure or certificate authority. |
| `World::copy_pressure_head_chunk_coordinates(span)` | Required actual resident chunk count in a pressure World, including chunks allocated by gas discovery; sufficient caller storage receives copied coordinates, while a short span receives no partial result. A World without pressure returns zero. The call allocates and mutates nothing; the caller can sort its own roster and verify complete sampling. |

Native `pressure_optimization_snapshot()` and `pressure_optimization_identity()`
provide the underlying copied values. The [canonical optimization page](../architecture/pressure-optimization.md)
owns the fields and limits. `get_pressure_flow_ledger().last_tick` reports work
diagnostics and can legitimately differ across variants; compare authoritative
PF fields separately. Prepared-head errors and declared-region net Water
balances are diagnostic observations, not gross per-face flux or Rapier forces.

### Native prepared liquid setup and receipts

**Current on main through accepted PR #246:** `PreparedWorldBuilder`
validates final unique tuples, optionally normalizes Water and builds an
unexposed candidate. Its native-issued `ConstructionRefusal` distinguishes
policy/setup refusal from preparation failure, binding exact raw request scope
only where that request was actually received. A refused attempt is separate
from the applied run and cannot replace its World, receipt or generation.

`World::stored_temperature`, selected/applied core getters and `quantity_ledger`
provide copied completed-boundary native facts. Exclusive-owner capture creates
the immutable `NativeFacts`; caller setup dictionaries cannot construct it.
Typed native-v1 applied/attempt receipts bind actual policy/configuration,
setup/normalization identities, complete hash2 and exact accounting. Shaped
source/runtime values remain caller claims and full matched eligibility stays
false until #202 supplies actual verification. The older Godot dictionary
getter above remains a different encoding; no Godot typed normalization opt-in
or full comparison host is supplied by that residual native checkpoint. Detailed shapes, absence rules,
capacities and the narrow native codec freeze belong to
[native prepared setup and receipts](../architecture/liquid-prepared-setup-and-receipts.md).

**Subsequent #202 source slice:** `CyberDemoBridge.prepare_liquid_world(world,
rectangles, profile, policy, water_fills, liquid_policy, options)` returns one
positive opaque token or zero. Options bind the definition SHA256 claim, seed,
final four-word region, cadence/adhesion and explicit normalization rule. The
unchanged native builder supplies normalization and typed outcomes. No pending
World is exposed. `commit_liquid_world(world, token)` consumes that token at the
exclusive owner boundary after a retained-state fence; `discard_liquid_world`
retires it. There is one pending candidate per adapter.

The separate `prepare_liquid_level(world, payload, profile, policy, liquid_policy,
options)` shares that pending slot and commit API for decoded CYSD1 bytes.
It binds actual raw payload SHA256 in NativeCellFixture/schema1, keeps payload-only
coverage/all gaps, preserves signed thermal tuples and explicitly normalizes only
on opt-in. `definition_hash` is refused; import-only copied `setup_kind` and
`source_payload_sha256` distinguish source bytes from canonical native setup hashes.
Legacy immediate `import_level` remains Current/default radius2. The [thermal
preparation contract](../architecture/liquid-prepared-setup-and-receipts.md#imported-cysd-payload-preparation)
owns exact lane/refusal/identity limits. The subsequent bounded
[ordinary importer](../architecture/liquid-prepared-setup-and-receipts.md#explicit-ordinary-level-import-and-retained-restart)
is explicit Exploratory/body-free, retaining copied metadata/player/receipt and
its accepted reset input. Physical import and final platforms remain open.

The synchronous owner adds `liquid_comparison_arm_import(policy, normalize_water,
exploratory, radius=2)`, `liquid_comparison_clear_import()` and copied
`liquid_comparison_import_state()`. Arming changes only a next-import request.
`restart_world()` reconstructs an accepted imported setup or follows the ordinary
demo reset. `liquid_level_host_observation_record()` explicitly copies the
qualified imported-owner record; it grants no full-host eligibility. Final
owner serial/lifetime and native one-use commit fences precede adoption.
Native run-component v1 preflight refuses unsupported inherited interaction or
diagnostic law and independent transport before issuing a token. The accepted
level's configured Baseline exemption binds actual copied transport component,
native generation and immutable applied receipt hash. No new native codec or
configuration mutator is added; observational telemetry remains the existing
prepared-builder behavior.

The later synchronous four-demo route supplies a copied schema2
`CyberMicroScenarioCatalogue.prepared_ordinary_demo(id)` through the existing
`liquid_comparison_active_definition()`/`liquid_comparison_apply_active(...)`
owner interface. It uses `prepare_liquid_world` with the existing one-use token,
private sampled stage, final actual execution and serial/lifetime/native fences;
there is no new native codec or constructor API. The owner keeps an accepted
copied recipe/selection and source-ID/native-generation identity for Restart.
Its configured Baseline exemption additionally binds actual transport component
and applied receipt hash. Imported demo labels never supply that source identity.
See [ordinary demo rebuilding](../architecture/liquid-prepared-setup-and-receipts.md#explicit-ordinary-synchronous-demo-rebuilding)
for the four-route allowlist, retained refusal and healthy-World recovery limit.

`prepared_reference_body_session.gd.prepare_reference(parent, templates, size,
positions=PackedVector2Array(), rotations=PackedFloat32Array())` is a main-thread
private-graph helper, not a native or worker message API. Each optional array is
copied; nonempty arrays require exactly three finite entries before viewport
allocation. Omitted positions/rotations retain the Water Feel defaults. Actual
captured packed body values still cross the owner boundary as immutable values;
no Node/RID is published to native workers, and constructor admission remains
the calling owner's responsibility.

The later `prepared_synchronous_reference_session.gd` retains one exact copied
request and native preparation token privately across main-thread construction
frames for authored Physics Pit. Its existing host commit guard first defers
with token-bound copied terrain and staged sampled/body owners, then revalidates
the same stored request after frozen-frame/terrain readiness. No caller token is
accepted as a reusable request. Existing pending-owner acknowledgement carries
serial/applied status to the panel; final native commit consumes the token.
Only packed body/terrain values cross the native adapter boundary. See the
[synchronous reference-body contract](../architecture/liquid-prepared-setup-and-receipts.md#synchronous-physics-pit-reference-bodies)
for retained-state, settings/cancellation and qualification limits.

`get_applied_liquid_construction_receipt()` and
`get_liquid_construction_attempt()` return distinct owned dictionaries containing
the original native canonical `PackedByteArray`, its SHA256, qualifications and
eligibility. Applied readback includes the actual tick-zero policy, prepared
payload/setup, generation, final region, execution selections and optional
normalization digest/counters. Both application owners accept
`microscenario_apply_controlled_liquid(definition, policy, normalize_water,
mode, maximum_rule_radius=2)` for the fixed actor-free schema-2 route. Desktop commands carry
`controlled_liquid_setup`; the worker issues its own queue revision and fences
the actual native commit against newer requests/reset/stop. Details and current
gaps belong to the [bounded host contract](../architecture/liquid-prepared-setup-and-receipts.md#controlled-application-host-preparation-slice).

The subsequent normal comparison panel calls
`liquid_policy_assignment_choices(request, material)` for native-decoded,
catalogue-declared family/variant choices. Each owns a copied request and actual
validator result/refusal plus material/family/variant/Current metadata. Editing a
choice preserves foreign assignments/blocks and retires blocks whose owner no longer applies;
invalid or incompatible blocks remain explicit refusals. This value API reads
no World and changes no applied policy. GDScript owns pending selection and
observes the existing owner acknowledgement before treating it as applied. See
the [normal UI and constructor coverage](../operations/lcb-manual-comparison-ux.md)
for actual supported routes and retained qualification.

`microscenario_apply_exploratory_liquid(definition, policy, normalize_water,
mode, actor_configuration, maximum_rule_radius=2)` is the subsequent schema-2 route; desktop
stages allowlisted sampled rigs/equipment, while the synchronous controller
stages its existing sampled character. Native preparation options additionally
select `intent` (`controlled`/`exploratory`), `pacing`
(`fixed_steps`/`host_paced`) and `simulation_window_enabled`; disabled window
requires the full finite World region. Readback copies these actual encoded
native execution/intent values. The frozen native codec and its qualifications
remain unchanged.

`prepared_liquid_character_box_collides(world, token, origin, size, mode)` reads
only the matching native candidate, using the existing live collision law;
missing/retired tokens and invalid queries fail closed. It exposes no native
World or edit/tick API. The worker's final commit swaps the privately prepared
sampled owners under the same mutex fence as native replacement. Matching
`acknowledge_prepared_liquid_configuration(serial)` releases the initial
accepted owner frame only after main installs its new camera/configuration.
Details belong to the [staged owner contract](../architecture/liquid-prepared-setup-and-receipts.md#staged-sampled-actors-and-exploratory-owners).

The desktop articulated route additionally supplies copied `initial_bodies`
(maximum 64 existing 11-float records) before native facts capture.
`prepared_liquid_world_values(world, token)` returns owned pending terrain, body
values/digest and physical hash. The exclusive worker publishes these copied
facts through `prepared_physical_liquid_values()`; main completes the permanent
physics-space setup and calls `complete_prepared_physical_liquid(identity, ready,
reason)`. Token/request/epoch/instance/body-digest identity and the final owner
fence bind this continuation. No scene node, RID or mutable World crosses it.
Native canonical bytes bind actual initial masks; the copied body digest remains
host metadata with existing qualifications. See [physical ownership and queued-work disposition](../architecture/liquid-prepared-setup-and-receipts.md#staged-articulated-physical-owners).

The integrated IN adapter adds native
`liquid_policy_with_inertial_damping(request, numerator)` for an active IN family
and integer numerator0..16. It returns copied native-validated request/receipt or
typed refusal without mutating a World. Applied `get_liquid_solver_policy()` adds
actual `maximum_rule_radius`, instance hash/format versions and IN
`family_parameters` with the native effective identity and `readback_source`.
`get_physical_state_hash_version()` and `get_physical_state_format_version()`
query the actual instance (IN3, non-IN2). `inspect_inertial_cell(point)` copies
healthy finite cell material/family/availability and signed motion/accumulators.
Invalid points or failed Worlds return an explicit error.

Prepared options admit explicit rule radius2 or3, default2; IN never silently
upgrades it. Construction readback additionally copies actual
`solver_state_extensions` and rule radius from native facts. Hex physical-hash
metadata is consistently sixteen digits; the canonical hash value/bytes do not
change. See [IN host scope and qualifications](../architecture/liquid-prepared-setup-and-receipts.md#inertial-application-readback-and-explicit-geometry).

The subsequent ordinary Tower route exposes
`liquid_comparison_active_definition()` and
`liquid_comparison_apply_active(policy, normalize_water, exploratory, mode,
radius)` to the existing panel. The copied preparation definition keeps the
actual Tower recipe/profile and final selected floor. Desktop `reset` commands
carry the same explicit policy/setup and owner-issued request revision; copied
scenario serial/applied acknowledgement identifies successful ordinary Tower
installation without setting `micro_active`. Existing reset/profile controls
retain accepted selection. Default construction retires typed setup metadata.
See [Tower owner lifetime and scope](../architecture/liquid-prepared-setup-and-receipts.md#ordinary-experiment-tower-preparation).

### Read-only native MicroScenario inspection

The subsequent ordinary Water Feel route passes explicit `liquid_policy`,
`controlled_liquid_setup` with Exploratory intent and `scenario_request_serial`
through `water_reset`, retaining `water_active` rather than entering MicroScenario
mode. The same serial/applied/definition acknowledgement used by prepared owners
qualifies success; the semantic Water policy hash alone cannot. The original
default/blind command route remains available. See [Water Feel route restrictions,
source actions and ownership](../architecture/liquid-prepared-setup-and-receipts.md#ordinary-water-feel-preparation).

The subsequent desktop reference-body route adds owner-internal
`physical_owner = {kind: reference_body, epoch: 0, instance_id, initial_bodies}`
to the same prepared command. The packed three-body input is copied from the
actual frozen Rapier space. Native candidate identity, main-thread terrain and
pose readiness, exact continuation binding and final owner fences precede
installation. Refusal retains the old graph/receipt/record; success adopts the
permanent space without rebind. It carries no actor/equipment authority. The
later synchronous controller has its own staged supported-body Water route with its original y90 poses. See [reference-body lifetime and actual feedback](../architecture/liquid-prepared-setup-and-receipts.md#prepared-water-feel-reference-bodies).

The subsequent qualified host observation API
`CyberDemoBridge.loaded_native_runtime_values()` accepts no caller path/hash and
returns copied version1 API-reported library path/current file SHA256/size, with
mapped-module binding explicitly unverified. The separately versioned
`liquid_host_evidence.gd.collect(bridge, native_readback, host_claims)` preserves
native canonical bytes and frozen qualifications, collects actual manifest/config
and bounded current script-file observations, labels caller values unverified and
returns an immutable copied value or explicit refusal. Its native-byte checksum
check is not an independent native codec decoder. Normal owner integration and
full evidence eligibility remain open at that foundation checkpoint; see the [qualified foundation](../architecture/liquid-prepared-setup-and-receipts.md#qualified-host-observation-foundation).

The subsequent `prepared_liquid_run_capture(world, token)` returns a copied
`{schema_version:1, lifecycle:"prepared", token, native_run_encoding}` wrapper
for that pending candidate only. It exposes no World or installation claim.
`CyberMicroScenarioHost` collects the qualified record before its final guard,
adopts it only after successful commit and retains the old record on refusal.
`liquid_host_observation()` returns compact copied identity;
`liquid_host_observation_record()` and explicit capture return full copied
canonical values. Default construction/generation retirement clears readback;
native and host eligibility remain false. See [owner lifetime](../architecture/liquid-prepared-setup-and-receipts.md#owner-bound-construction-observation).

The MS-001 adapter preparation adds `CyberDemoBridge.inspect_cell(world, point)`
and `inspect_statistics(world)`. Call these only from the same serialized external
owner that may call `simulation_tick`; they are not concurrent-reader APIs.
Results own their dictionaries/arrays and contain no live World storage. Point
queries are one cell inside the finite 1024-square demo. Quarantined or absent
owners are rejected, with no retry, reset or partial-tick success publication.

Cell inspection returns stored material/state and raw temperature availability,
plus body-mask identity and chunk/activity-block coordinates. A masked temperature
is unavailable: the underlying occupancy-aware query's ambient fallback is not
represented as the hidden cell's temperature. There is no new heat solver or
per-cell awake flag. Statistics export existing completed-tick counters and
actual configured limits; missing utilization/queue/allocation counters remain
explicitly unavailable.

INT-000 extends the same serialized read-only bridge with
`inspect_interaction_profile()` and
`inspect_interaction(source_id, target_id, probability_roll)`. The profile result
owns copied schema/profile/channel/layer/family/rule/coverage/tuning-pass data plus
catalogue conflict-validation status. Pair inspection reports match kind,
orientation, selected products/probability, stable rule/version/supersession,
selected-pass parent/disposition/change declaration, revalidation tags and
provenance chain. It also reports represented specialized world-kernel authority
without claiming those mechanisms executed for the queried pair. These calls do not
mutate the World or constitute a second material authority.

Schema-2 host summaries/captures additionally preserve a read-only
`kinetic_contact_baseline`: source/runtime identity, transport hash, Water
semantics/effective policy, execution/interest settings and worker count. It is
provenance for targeted revalidation, not ownership transfer to INT-000.

See the [MS-001 execution ledger](../audits/2026-09-19-issue-28-ms001.md)
for the original observation adapter and the
[INT-000 contract](../systems/intermaterial-interactions.md) for interaction
provenance/coverage semantics.

## Soliding model and discovery values

**Current standalone modules only:** [lifecycle](../architecture/soliding-lifecycle.md)
uses incarnation/slot/generation handles and immutable transaction tokens;
[discovery](../systems/settled-region-discovery.md) returns complete copied tile
classifications under an independent revision witness. Neither adds a C API,
GDExtension method, worker message or live runtime admission. Real World producer
witnesses and cross-owner queues remain Planned.

The [physical Blacksite experiment](../operations/physical-actor-programme.md) reuses the current body input/result ABI with one rectangle. `apply_trial_impulses` is a main-thread bridge method; no native field layout or sampled actor action/observation stride changes.

## Player material field control

**Current experimental, dedicated playground:** the GDExtension method is
`apply_player_material_field(center: Vector2i, direction: Vector2,
material_id: int, mode: int, phase: int) -> Dictionary`.
Only the exclusive native-World owner may call it, outside native ticks. It is
not forwarded through the ordinary desktop worker. The
[playground contract](../systems/player-control-playground.md) owns user behavior;
[configuration](configuration-reference.md#player-playground-values) owns limits.

`center` must lie inside the adapter's 1024² domain. Direction must be finite and
unit-bounded; material is Sand (2) or Water (3), mode is 0–3, and phase is an
integer from 0 through 2,147,483,647. Modes are normal cohesion/loft (0), surge
(1), dry spread/liquid squeeze (2), and gather (3). The owner uses the current
tick as phase. Invalid commands, failed Worlds and in-tick calls refuse mutation.
The native C++ command additionally carries an explicitly validated finite domain.

Every receipt includes `accepted` and `reason`; reasons are `applied`,
`invalid_command`, `world_failed` or `tick_in_progress`. Once native validation
is reached, it also returns `scanned_cells`, `observed_cells`,
`controlled_cells`, `moved_cells`, `movement_steps`, `blocked_steps`,
`storage_refusals`, `quantity`, `centroid`, `truncated` and `radius`.
An applied call may move zero cells. `quantity` counts all matching material
observed in the starting circle: one per Sand cell, raw mass units per Water
cell. The quantity-weighted centroid includes this call's successful moves,
including the unmoved observed material when control is truncated. It is a
per-call receipt, not a global inventory or a post-tick query.

The native operation moves the complete stored tuple through existing relocation
and wake bookkeeping. It never exchanges with an occupied destination, allocates
missing chunks/thermal storage, or creates a persistent cohort or new material
kernel. After the call, normal simulation proceeds under its existing rules.

The separate scene command is version 1 with exactly ten fields:

```json
{
  "version": 1, "kind": "player_material_field_action",
  "run_id": "issued-run-id", "epoch": 1, "actor_id": 0, "sequence": 1,
  "observed_tick": 0, "observation_id": "issued-observation-id",
  "lease_ticks": 6,
  "action": {"move": [1, 0], "primary": true}
}
```

`CyberPlayerPlaygroundRuntime.make_command` copies an issued observation. Submit
checks run/epoch/actor, exact finite integer identities, a newer sequence, issued
observation token and an unexpired observation-relative lease of one through six
ticks. Cancellation changes control generation and retires issuance history;
replacement additionally changes the run and epoch. Actions admit only `move`,
`aim`, `effort`, `trim`, `primary`, `secondary` and `auxiliary`, normalized by
the shared physical session. Move and buttons drive this fixed-strength field;
aim, effort and trim are compatibility values without field effects. Mode
priority is auxiliary, secondary, primary, neutral. Lease expiry removes the
command, so even neutral hover assistance stops until fresh input is admitted.

Sources: [native command and result](../../native/include/cybersand/world.hpp),
[World operation](../../native/src/world.cpp),
[adapter binding](../../godot/native_extension/cyber_native_cell_world.cpp) and
[scene owner](../../godot/scripts/player_playground_runtime.gd).

## Physical actor control and effects

**Current experimental ACT-004 / ACT-005:**
[`CyberPhysicalActorSession`](../../godot/scripts/physical_actor_session.gd)
is the main-thread physical owner shared by desktop F5 and physical Thunderbowl.
Configuration identifies a catalogue `model`, one producer (`human`, `demo` or
`policy`) and a finite spawn position per actor. The F5 picker prefixes physical
choices with `rapier/`; session model IDs are the bare catalogue IDs.

The physical command envelope is version 2 with exactly these top-level fields:

```json
{
  "version": 2, "kind": "physical_wire_action",
  "run_id": "issued-run-id", "actor_id": 0, "epoch": 1, "sequence": 1,
  "observed_tick": 0, "observation_id": "issued-observation-id",
  "lease_ticks": 12,
  "action": {"move": [1, 0], "aim": [1, -0.6], "effort": 0.8, "primary": false}
}
```

The identity strings above are illustrative. `make_command(view, sequence,
action, lease_ticks)` copies an actually issued `observation(actor_id)` view. `submit(command,
producer)` requires matching run, actor, epoch and producer ownership, a strictly
newer nonnegative sequence, and an observation still retained in the bounded
issuance history. Integer identity fields accept only exact finite integers.
Lease expiry is `observed_tick + lease_ticks`, never receipt time; future,
invented, stale and misaddressed views are refused. A queued model response cannot
extend its authority by arriving late. See the [configuration bounds](configuration-reference.md#physical-actor-values).

Legacy physical profiles admit `move`, `aim`, `effort`, `trim`, `reel`, `primary`, `secondary`,
`auxiliary`, `tool`, `release_usable`, `attach_usable` and the optional
`equipment` dictionary described below. Unknown keys, wrong
types and nonfinite values are refused. Vectors accept `Vector2` or two numeric
array values and are length-clamped to one; effort is clamped to zero through
one, trim/reel to minus one through one. Missing action fields receive neutral
defaults; buttons must be Booleans. All producers reach the same normalized
action and bounded physical actuator path.

The additive [4LY velocity profile](#physical-free-flight-actions) retains this
envelope and ownership fence but admits only its declared `move` field. Existing
actor IDs and their action meanings are unchanged.

`observation(actor_id)` returns copied identity, tick, selected profile,
pose/velocity, contacts and local rays, resource/charge/cooldown, part and joint
states, attachment/tool state and lease status. These dictionaries do not change
the sampled actor state/observation strides. Physical actors currently expose
the wire lane only; sampled v1 tag, message, metal and NCA contracts remain
separate. Desktop exposes `physical_actor_observation(actor_id)` and
`submit_physical_actor_command(command)` and `cancel_physical_actor_command(actor_id)`
from `main.gd` for a policy-owned actor.
No network transport or model service is supplied by those methods.
Desktop command admission remains suspended until the selected native reset is
acknowledged and that epoch's initial hard-terrain colliders are installed.
A faulted rig reports `suspended=true` and `lease_remaining=0`; its session refuses
new commands with `actor_fault` and does not issue new control authority.

`cancel_input(actor_id, epoch, producer)` clears the command and calls runtime
cancellation; pause and close also revoke pending authority. Cancellation clears
charged launch intent, ropes, temporary grips and pending effects without
performing a charge release or erasing velocity. The same actor's held tool is
released only by its explicit release action or destruction of the session.
Cancellation and lease expiry also invalidate issued observations and emit the
session's `input_cancelled(actor_id, epoch)` notification. The desktop host uses
it to revoke the worker's queued and already-copied, not-yet-admitted effects for
that actor. Other actors retain their own command/effect generations. A fresh
observation immediately reports the cleared charge, grip, rope and action state.

### 4LY-003 policy episode/observation envelope

**Current implementation candidate:** The physical v2
`physical_wire_action` and `4ly_velocity_v1` plant contract remain
unchanged. The [Flight Lab contract](../systems/physical-flight-lab.md)
introduces a task-layer `4ly-episode/v1`, copied
`4ly-observation/v1`, `4ly-action/v1` and normalized
`4ly-flat-observation/v1` (54 floats). Only two admitted
desired-velocity outputs cross into the existing session;
each fresh decision is bound to a current issued observation and epoch
before consuming up to six real 60 Hz native/Rapier ticks. A missing fresh
decision may carry only an already-live lease to its unchanged physical deadline;
it submits no replacement command and cannot renew stale authority.
Task rewards, course geometry, evaluator contact count and terminal
status are not policy-readable. The prospective
[registration](../../godot/tests/fixtures/4ly003_qualification_registration.json)
does not grant final teacher qualification.

### Physical free-flight actions

**Current 4LY-001 contract / 4LY-002 profile candidates:** a session-installed `4ly_*` actor declares
`action_profile = "4ly_velocity_v1"`, `control_mode = "4ly_velocity_v1"` and
`profile_version = 1` in its copied observation. Its command still uses the
version-2 `physical_wire_action` envelope above. The action object must contain
exactly one field:

```json
{"move": [0.6, -0.8]}
```

The two finite numeric components must individually lie in `[-1, 1]` before
unit-disk normalization. `Vector2` is also accepted by the in-process API. A
finite oversized request is rejected in this profile; the retained legacy
normalizer still clamps its own vectors. Arrays of the wrong length, booleans,
NaN/infinity, missing movement and extra fields such as `effort`, `trim`,
abilities, goals or equipment are refused. Existing run/actor/epoch/producer,
sequence, issued-observation and lease checks apply before actuation.

The admitted vector is world-relative: `+x` right, `+y` down. Componentwise
multiplication by the resolved `desired_speed` gives cells/second. Diagonal
normalization precedes this mapping; unequal axis limits therefore describe an
ellipse of possible desired velocities. Desired speed is not an enforced cap
on physical motion after collisions or external impulses.

`Session.set_propulsion_enabled(actor_id, enabled)` is an explicit host/fixture
switch, outside the two-output action. It revokes existing input before changing
power. `Session.takeover(actor_id, expected_epoch, producer)` revokes old
capabilities before assigning a new authorized source; neither operation
reconstructs the body or deletes momentum. Suspension, cancellation, expiry and
reset retain their existing lifetime fences. The
[4LY lifecycle table](../systems/physical-free-flight.md#how-do-neutral-cancellation-power-off-and-suspension-differ)
distinguishes an authorized neutral request from passive fallback.

The resolved profile descriptor carries `profile_hash`, `controller_id`, units,
axes, speed mapping, empty default loadout, fallback, neutral and resource
semantics. Its **`capabilities`** subdescriptor is a deep-copied static physical
contract for collider dimensions, mass/inertia, desired-speed limits,
acceleration/braking authority, response/slew times, force/gravity margin,
drag and upright torque. That subdescriptor deliberately omits actor name,
evaluator label, goal, position and reward. Dynamic propulsion, lease/fallback
state and saturation remain separately observable. Controller receipts add
`controller_hash` and `fixed_delta`.
`profile_hash` is SHA-256 of the validated resolved profile serialized with
sorted keys and full float precision. `controller_hash` is the embedded SHA-256
of checked-in UTF-8 controller source with the `SOURCE_SHA256` value replaced
by the literal `<CONTROLLER_HASH>`; its conformance test checks the digest. The
embedded digest remains available when exported scripts omit source text.
Keep repository/runtime identity alongside these hashes; they are not an
attestation of the physics engine or a learned-policy result.

Controller receipts distinguish `requested_move`, `admitted_move`,
`desired_velocity`, `requested_acceleration`, `bounded_acceleration`,
`gravity_compensation`, `requested_force`, `target_force`, `applied_force`,
`requested_torque`, `target_torque` and `applied_torque`. Saturation and slew
flags expose the active bounds. The requested force already includes
acceleration limiting and gravity compensation; the target force additionally
includes total-thrust saturation, and applied force includes response/slew.
The session retains the raw requested action separately from its admitted
normalized action, plus accepted sequence/source/admission tick and the physical
step's consumed sequence/tick. A newly admitted command and the last applied
step are therefore distinguishable.

| Copied observation field | Meaning |
|---|---|
| `flight.mode` | `velocity`, `neutral`, `passive_no_lease`, `power_off` or `suspended` |
| `flight.propulsion_enabled` | Explicit host power state; distinct from possession of a live command |
| `flight.capabilities` | Deep-copied full resolved profile, static `capabilities` subdescriptor, units/semantics and profile/controller identities; no secret goal or evaluator label |
| `flight.controller` | Current pure controller response/receipt with requested/bounded/applied force and torque, saturation/slew flags and reason; cleared on revocation |
| `flight.command` | Raw `requested_action`, normalized `admitted_action`, `sequence`, `observed_tick` and `admitted_tick` for the accepted command; empty after revocation |
| `flight.command_live` | A current unexpired command exists and the actor is neither suspended nor faulted; host propulsion may still be disabled |
| `flight.applied` | Prepared actuator snapshot: `run_id`, `epoch`, `actor_id`, `producer`, `control_generation`, `sequence`, `observed_tick`, `step_tick`, expected `physics_step`, admitted `action` and `controller`; separate from a newly accepted command and cleared on revocation |
| `flight.last_step` | The same snapshot after the bridge counter proves its physical step occurred; retains the original source attribution across later cancellation/takeover and is cleared by close/replacement |
| `flight.fallback_reason` | Explicit lifecycle reason such as `not_commanded`, `cancelled`, `expired`, `suspended`, `resumed`, `power_changed`, `takeover`, `invalid_cadence`, `step_fault` or `fault`; `none` for an admitted command |
| `flight.step_fault` | Empty in a healthy session; a sticky physical-step ordering fault requires session replacement |

Top-level run/actor/epoch/tick, `control_generation`, `last_sequence`,
`lease_remaining` and pose/velocity retain the existing session meanings.
For 4LY, `applied_impulse` and `applied_torque_impulse` are the bounded actuator
force/torque multiplied by the admitted physical step duration. Sustained
assistance uses an owned constant-force/torque channel during Rapier integration;
the host clears that channel after each step or on cancellation. These fields
do not decompose passive damping, gravity, contact or native material impulses.
Preparing force does not itself prove that physics consumed it; use completed
`flight.last_step` attribution and sampled motion for completed-step evidence.
Expiry revokes the command at the completed deadline tick, before a delayed
reply can extend an old observation's authority. Passive assistance is not
represented as a synthetic fresh external command. The pure controller source
digest does not cover rig/session integration, plant construction or Rapier
itself; retain their source/runtime identities separately.

A session containing 4LY requires one `advance` preparation, one actual bridge
step and one `complete_step` accounting call in that order. The bridge's
`manual_step_count` binds prepared and completed receipts. Duplicate preparation
sets `last_error = "flight_step_already_prepared"`; completion without physics
sets `flight_step_not_completed`. Neither advances the flight clock. Unprepared
or extra physical steps, preparing before accounting for a step, or physics
advancing while suspended instead set a sticky step fault and suspend the
session. Cancellation before the native step discards pending force without
creating history; cancellation after it preserves the original completed
snapshot before clearing current authority. Paused views do not issue command
capabilities, and resume increments the flight control generation before a
fresh observation can be used.

Every descriptor, observation and receipt is copied. `equipment` reports
explicit absence (`preparation = "none"`, `usable_index = -1`, `body_id = 0`,
`available = false`); no equipment body or worker request is synthesized. The
[canonical 4LY contract](../systems/physical-free-flight.md) owns goal blindness,
neutral/fallback behavior, initial calibration scope and follow-up order. The
[configuration reference](configuration-reference.md#physical-free-flight-values)
owns numerical defaults and profile constraints.

### Retained direct physical effects

The ACT-004 direct mount/effect substrate remains available to the focused
physical regression fixtures. ACT-005 catalogue use follows the separate
equipment request/receipt seam below. Both use the same stable part IDs within
the 64-body bridge. Direct effect requests contain `actor_slot`, `epoch`, `sequence`,
`kind`, `source`, `origin`, `source_part`, `source_body_id`, `radius`, `strength`,
`material` and optional `pattern`. The physical rig applies recoil; the exclusive
cellular owner validates and applies cell edits through
[`CyberPhysicalActorEffects`](../../godot/scripts/physical_actor_effects.gd).
Freshness, source-body clearance, bounds and protected materials remain checked
even when the request originated in a local demo. Receipts report actual changed
cells or refusal. The worker copies requests alongside the corresponding body
publication and tags results with `rigid_body_epoch`; a retired actor epoch cannot
be applied to its replacement.

`SimulationWorker.set_rigid_body_states(states, body_epoch, effects)` publishes
body states independently of effect admission and returns a copied batch outcome.
A nonempty batch is admitted wholly or refused: at most eight requests can be
pending, and a newer batch never displaces older requests to make room. Outcome
fields are `epoch`, `status`, `reason`, `requested`, `queued` and `refused`.
`status` is `queued`, `refused` or `no_effects`; capacity refusals distinguish
`batch_capacity` from `pending_capacity`. Epoch, failed-world, pause, pending
reset/lab replacement and invalid actor-slot refusals remain explicit.

`physical_actor_effect_admission()` and the additive snapshot field of the same
name return copied `capacity`, `pending_requests`, accepted/refused batch and
request counts, `overflow_batches` and `last_batch`, bound to the current effect
epoch. Setting an actor epoch resets this bounded history; cancellation retains
it. Body-only publications do not erase the last nonempty outcome. These are
queue-admission diagnostics; later actual-cell receipts remain separate, and
neither admission nor refusal reverses already applied physical recoil.

This effect ingress trusts the main-thread session to assign the actor-to-body
mapping; it is not a public policy API. Policy actions cannot supply positions,
body IDs or arbitrary material requests. Desktop effects originate before its
Rapier step and travel with the subsequent body sample, so an empty cell at the
source is allowed; a foreign occupied cell is refused. The synchronous physical
arena samples the source mask before actuation and consumes effects before its
Rapier step. Neither schedule promises a perfectly simultaneous cross-thread
collision snapshot.

Desktop asynchronous publication and the physical arena's synchronous step have
distinct [schedules](../architecture/simulation-tick-and-threading.md#physical-actor-scheduling).
Neither grants a controller mutable World access or guarantees equivalence with
the historical sampled arena. Mechanism and usable semantics are owned by the
[physical actor contract](../systems/physical-actor-rigs.md).


### Physical equipment actions and results

**Current experimental ACT-005 source:** equipment actions share the physical
version-2 envelope, actor producer and issued-observation lease. The normalized
`action.equipment` dictionary has these fields:

| Field | Meaning and validation |
|---|---|
| `usable_index` | Required exact integer -1 through 31; -1 selects None |
| `instance_id` | Required nonempty String from the observed physical equipment |
| `equipment_epoch` | Required current positive exact integer; selection and lifecycle transitions advance it |
| `aim` | Optional finite Vector2/two-number array, length-limited to one; zero falls back to the enclosing locomotion aim |
| `power` | Optional finite number, clamped to 0–1; defaults to 1 |
| `trigger`, `alternate`, `drop`, `attach` | Optional Booleans, default false; transitions share bounded physical button-edge admission |

Unknown fields and wrong types are refused. `make_command` can fill the three
identity fields from its copied observation and maps local `tool`,
`release_usable` and `attach_usable` requests to this dictionary. Raw policy
packets cannot activate those legacy buttons without equipment identity.
Selecting another usable requires the existing chassis to be held; it does not
replace a released body. Holding a trigger during selection requires a neutral
release before a new activation.

The session owns one
[`CyberPhysicalUsableEquipment`](../../godot/scripts/physical_usable_equipment.gd)
per actor. It publishes copied `equipment` observations and prepares
`equipment_frame()` plus `drain_equipment_requests()` for the cellular owner.
The worker seam is:

```gdscript
set_physical_usable_state(
    frame: Dictionary, requests: Array = [],
    states: PackedFloat32Array = PackedFloat32Array()
) -> Dictionary
```

A version-1 frame binds `run_id`, actor `epoch`, physical `tick`, suspension,
actor rows and deployed-device rows. Actor rows contain control `generation`,
`equipment_epoch`, `instance_id`, selected usable, stable equipment `body_id`,
state, pose, extents, muzzle/direction, owning-part origin, lease deadline and
copied individual part records. Device rows retain the physical instance/body
and current fixed pose. Body-state values can be published at the same mutex
boundary, preserving their relationship with the source/muzzle frame. No node,
RID, live World or controller object crosses that boundary.

Each request has `version`, `run_id`, `epoch`, `actor_id`, `generation`,
`equipment_epoch`, `instance_id`, `usable_index`, `body_id`, `sequence`,
`request_id`, `operation` and `power`. Instance/request IDs are Strings. A
request references the owner-supplied frame; it cannot supply an arbitrary
position, material or footprint. Operations are `use`, `alternate` and `deploy`.
An entire incoming batch is admitted or refused, within eight requests and one
in-flight request per actor. Refusal leaves other pending requests intact.
Copied admission fields include status (`no_requests`, `queued`, `refused`),
reason, requested/queued/refused counts, capacity and pending count.

`CyberSimulationSnapshot.physical_usables` returns copied actor charge/cooldown,
projectiles, physical processors, effects, hit records, work counters, admission
and at most one retained result per actor. Result receipts echo request identity
and add `accepted`, `consumed`, `reason`, `changed_cells`, worker tick, charge and
cooldown. `accept_equipment_feedback` admits only matching current identity and
new readback; a matching pending token is consumed before applying recoil.
Refused use cannot apply recoil or silently change item ownership.

`observation.equipment` exposes the physical grip/body pose, current and requested
aim, limits, clearance, release/reattach readiness, selected usable, cooldown,
charge, pending token, last result/receipt, accepted/refused counts and recoil.
Owned projectiles, processor status and a bounded local material patch support
feedback controllers. Values are copied; mutating an old observation cannot
replenish charge, alter cooldown, move a body or restore retired equipment.

Cancellation retires pending requests and invalidates control generation; the
worker rechecks extracted work against its current admission state before
committing. Once cancellation returns, that pending work cannot later edit cells.
Committed projectiles and admitted deployed processors retain their autonomous
lifecycle, while reset/close clears the old run. Pausing freezes simulation time.
A released body retains its physical velocity, and collision grace continues to
age when physical stepping resumes. Exact catalogue effects and processor
semantics remain with [actor usables](../systems/actor-usables.md); execution and
merge acceptance remain with the [ACT-005 audit](../audits/2026-10-19-act005-physical-usables.md).

## Workbench replay and genuine stage interfaces

[GEN-007](../systems/generation-workbench-2.md) adds
`inspect_generation(position, plane, expected_revision, expected_fingerprint)`
to `CyberWorldGenerator`. The method rejects stale caller identities and returns
copied deterministic replay with native material, initial context, effective
parameters, scalar/typed values, ordered masks/modifiers/aggregate decisions,
semantic ancestry/constraints, plane projections, fixtures/links, precedence,
proposal identity and explicit truncation/unavailable metadata. It does not
read a live simulation World or imply a stored historical execution log.

`stage:<name>` chunk diagnostics keep final `cells` and actual intermediate
`stage_cells` separately and bind them in the native receipt. The six base names
are `candidate`, `guided_candidate`, `grammar`, `modifiers`, `connectivity` and
`final`. `begin_stage_region(bounds, plane, stage)`, `advance_stage_region(budget)`
and `cancel_stage_region()` supply bounded private finite-region stage jobs.
Plane stages also include `policy`, `base` and `projections`; a plane without the
base generator rejects its unavailable source stages. Stages are sampled from
the real pipeline, never from a modified final recipe.

Adapter revision, native recipe/plane fingerprint, UI session/view token and
owner World generation are distinct identities. Workbench comparison binds the
same seed and coordinates for both recipes and rejects stale result serials.
`adopt_configuration(prepared_owner, expected_revision)` transfers immutable
plans only after the caller has joined the private preparation worker. It rejects
null, self, unconfigured, pending or stale owners. The receiving adapter serial
advances; the native recipe revision and its material/diagnostic receipt remain
unchanged and are reported separately. Subsequent changes to the private owner
cannot mutate the adopted plans.
Neither explanation nor stage output supplies authority to install or mutate a
World; existing material/semantic admission interfaces keep that responsibility.


## Native default-demo construction values

The unmerged [native default-demo preparation API](../architecture/liquid-prepared-setup-and-receipts.md#native-desktop-default-demo-preparation)
accepts `(world, liquid_policy, options)` at the exclusive owner boundary. Its
one-use token is the same private candidate slot used by prepared rectangles and
thermal levels. No World storage crosses the adapter. Copied native constructor
origin reports recipe ID, session generation, prepared status and health; it is
retired by other World replacements and is not inferred from equal tuples or a
scene label. The later [desktop owner/capacity checkpoint](../architecture/liquid-prepared-setup-and-receipts.md#desktop-native-default-owner-and-initial-pressure-capacity)
uses copied origin/qualified observation slots and exact request/settings/native
guards for owner adoption. Actual initial pressure-capacity excess produces a
native typed refusal before capture/token/swap, with actual attempt readback.
Complete host binding and final platform publication remain separate.
