---
title: Configuration reference
document-kind: reference
canonical-for: [current-configuration-values, adapter-worker-policy]
status: Current
scope: Exact native, adapter, fallback, presentation, and Web defaults; construction constraints and unimplemented production schema
last-reviewed: 2026-10-25
related-documents: [../operations/configuration-and-capacity-budgets.md, ../systems/world-storage-and-interest-region.md, ../systems/depth-layers-and-parallax.md, ../operations/deepworks-exhibition.md, ../architecture/rigid-body-and-cellular-coupling.md, level-saves-and-replay.md, ../architecture/pressure-optimization.md]
---

# Configuration reference

The [final application union](../architecture/liquid-prepared-setup-and-receipts.md#final-application-source-union)
preserves Current default tuples/clocks, protected radius2 and explicit IN
radius3. Water capability admission changes the embedded policy namespace:
default policy4b7922ad…cab53a/capability33c608f8…276e237/hash-version2 uses its
separately frozen fixture, while the old6e005e61/55141a32 fixture is immutable.
Unknown namespaces refuse. CY/IN fractional future sources refuse despite an
initial normalization opt-in. The default PF gas-capacity limit remains1024;
the authored default's three PF choices return typed initial admission refusal.

Synchronous [supported-body Water Feel](../architecture/liquid-prepared-setup-and-receipts.md#synchronous-supported-body-water-feel)
retains its actual Current poses(124,90),(244,90),(384,90),8×14 bodies at rest,
fixed480×270 Water view, recipe camera/player/actions and actual quality buffers/
publication cadence. Low quality is explicitly tested with margins16/18 and
30Hz publication; selecting Water still keeps its original fixed view. The
existing two-frozen-frame/20,000ms readiness and per-frame terrain budgets stay.
These synchronous poses differ from desktop Water Feel helper defaults.

The bounded synchronous Physics Pit route preserves its actual original three
8×14 bodies at(124,90),(244,90),(384,90), zero angles/velocities and sampled
player(24,222). These differ from desktop Water Feel's default helper poses. Pending
terrain work uses the existing per-frame chunk/time budget, requires at least
two actual frozen physics frames and refuses after20,000ms readiness wait.
That construction bound is not a simulation-tick deadline or a Web ownership
change. Current view/quality/cadence/adhesion are captured before native receipt.

The shared prepared three-body helper accepts optional copied positions and
rotations. Empty arrays retain the existing Water Feel centers(160,176),
(212,176),(264,176) and zero angles independently; supplied arrays must each
contain exactly three finite values before any private viewport allocation.
This is caller-supplied constructor data, not a new global spawn/default or
admission route. Original size/mass/physical settings and readiness remain.

The unmerged #202 [four ordinary synchronous demo route](../architecture/liquid-prepared-setup-and-receipts.md#explicit-ordinary-synchronous-demo-rebuilding)
requires explicit Exploratory apply and copies its recipe/policy/normalization/
radius for Restart. It captures actual quality/view: tested quality0 gives
buffered region(0,0,336,198), quality2 gives(0,0,704,432), with original player
(24,222), camera(0,0) and unchanged render cadence. Explicit IN/control geometry3
and default Current geometry2 remain distinct. Unsupported inherited laws and
independent transport refuse; prepared-owned Baseline is component/generation/
receipt bound. No global policy default or settings persistence is introduced.

The unmerged #202 [explicit level-import selection](../architecture/liquid-prepared-setup-and-receipts.md#explicit-ordinary-level-import-and-retained-restart)
is initially unarmed. Exploratory opt-in copies the native-validated liquid
policy, empty or `water-normalize-v1` rule and explicit radius2/3 for the next
ordinary body-free import. Its accepted private reconstruction holds one fixed
5,242,880-byte decoded payload plus bounded CYSD metadata and copied selection;
it is not serialized policy configuration. Saved quality0/1/2 selects the existing
320×180/480×270/640×360 views, margins16×18/32×36/64×72 and publication30/45/60Hz.
Those values, final camera/region, current cadence and saved adhesion are applied
before native capture. Existing Current import/defaults and format limits remain.
Prepared import currently accepts production interaction component `8:9:30` and
diagnostic-law component `0:-1` only. Other support/period/exchange/viscosity or
independent transport settings refuse transactionally. A private accepted
configured Baseline is admitted only with matching native component/generation/
applied receipt identity. The prepared builder enables observational diagnostics;
this does not claim the telemetry flag is preserved from ordinary Current.

The explicit LCB Web apparatus flag is `?test=1&liquid-host-test=1`. It uses
actual synchronous prepared-owner calls and emits a terminal copied result;
normal startup is unchanged. This is a test selector, not a solver or gameplay
default. Browser execution/POST/ordinary walkthrough remain distinct from the
exporter's qualified build identity. The [combined host checkpoint](../audits/2026-10-25-lcb003-combined-host-web-prerequisite.md)
records the native prerequisite and remaining platform gates.

**Current:** the following values are inspected source/configuration at the
[secured checkpoint](../operations/source-checkpoint-and-recovery.md). They are
prototype/runtime values, not automatically approved production defaults or
proof that a retained binary was rebuilt. Exact saved general configuration
keys, migration, and live resize are **Planned**.

This page owns values. The [capacity runbook](../operations/configuration-and-capacity-budgets.md)
owns preparation/failure semantics. [Evidence](validation-evidence.md) owns
executed validation; [level saves](level-saves-and-replay.md) owns what CYSD1
actually persists.

## Opt-in procedural generation configuration

**Current GEN-001/GEN-002 source:** [`generation::Recipe`](../../native/include/cybersand/world_generation.hpp)
is separate from `WorldConfig` and the transport/Water profiles. Its native
defaults are schema version 1, algorithm version 2, seed 1, revision 1, candidate `strata`,
chunk edge 128 and the `natural` theme family. Generator chunk edges are admitted
from 8 through 256 cells; complete output must remain within
`-2^40 <= coordinate < 2^40`. Native World installation additionally requires its
own configured chunk geometry and exclusive owner boundary.

The logical operation limit defaults to 64,000,000 per chunk. Recipe capacities,
numeric parameter ranges, theme inheritance, global topology controls and the
different workbench starting preset belong to the
[procedural generation contract](../systems/procedural-world-generation.md),
with validation in [`Generator::compile`](../../native/src/world_generation.cpp).
The workbench offers narrower slider ranges for some controls while its JSON
editor accepts the validated native range. No general World configuration,
residency or replay serialization follows from saving a generation recipe.

GEN-002 optionally adds up to 64 fields, 32 aggregates and 64 modifiers. The scalar
graph caps depth at 16 and declared operations at 4096 per sample. Aggregates
admit 1..16 unique existing material IDs with strictly positive finite weights;
their grain size defaults to 4 and accepts integers 1..4096. Named variation
fields select per cell without grain quantization. Field defaults/arity/ranges
are exposed by native `field_kind_specs()` and copied by `get_catalogue`.
The [field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md)
owns these values, context meaning, masks and diagnostic bounds; these scalar
authoring fields do not allocate optional simulation temperature/pressure storage.

**Current GEN-003 opt-in schema 2:** the separate typed `spatial` graph uses
generator algorithm 3 and spatial algorithm 1. Schema 1 retains the preceding
algorithm and scalar contracts. `spatial_limits` defaults to 64 expanded nodes,
dependency depth 16, 1,000,000 logical operations per sample, 16,000,000 preparation
operations and 16 MiB preparation storage. Nodes declare scales 1/4/16/64 cells;
sampling uses a fixed 256-entry caller-owned cache. Subgraphs/instances have
bounded expansion and parameter counts; recursive definitions are rejected.

Internal resampling admits the bounded ±`2^44` footprint while public cells
remain in `[-2^40,2^40)`. Continuous component bounds stay within ±`1e100`;
unit exponents stay within −8..8. Derivative spacing is 1..64 cells and warp
displacement 0..4096 cells. Exact category IDs retain integer components.
Geometry has at most 256 points. Region assignment has at most 16×16 cells and
16 categories, a default 1,000,000-operation preparation budget, hard work
ceiling 64,000,000 and fixed bounded solver scratch. Repeated tiles require
explicit wrap constraints for cross-tile adjacency guarantees. The
[typed contract](../systems/procedural-typed-spatial-fields.md) and
[operator inventory](procedural-spatial-operators.md) own exact family ranges,
recursive cost composition, distance qualification and invalid-input behavior.

## Hierarchical generation limits

**Current GEN-004 opt-in schema 3:** generator algorithm 4 adds grammar schema 1,
algorithm 1. [`GrammarDefinition` and `GrammarLimits`](../../native/include/cybersand/generation_grammar.hpp)
are compiled before material rasterization. Schema-1/2 recipes retain their
previous algorithm identities. The JSON adapter normally permits lowering default limits. GEN-007 also exposes
the already supported native `max_raster_operations` ceiling of 16,000,000,000;
its default remains 1,000,000,000. Other native C++ increases remain bounded by
the hard ceilings below.

| Setting | Native default / JSON cap | Native hard ceiling or admitted range |
|---|---:|---:|
| `region_size` | 256 cells | Integer 64–2048 |
| `region_window` | `[0,0,1,1]` region addresses | Positive finite rectangle; at most 64 per axis and `max_regions` total |
| `max_regions` | 16 | 64 |
| `max_rules` | 64 | 128 |
| `max_depth` | 8 | 12 |
| `max_children` | 32 | 64 expanded children per parent |
| `max_candidates` | 64 | 256 per rule |
| `max_features` | 2,048 | 8,192 |
| `max_sockets` / `max_routes` | 4,096 each | 16,384 each |
| `max_work` | 16,000,000 logical planning operations | 1,000,000,000 |
| `max_prepared_bytes` | 16 MiB | 256 MiB |
| `max_raster_cells` | 4,194,304 | 16,777,216 |
| `max_raster_operations` | 1,000,000,000 | 16,000,000,000 |
| `curve` / `curve_order` | Hilbert / 2 | Hilbert, Morton or Peano; order 1–6 |
| `route_width` / `clearance` | 7 / 3 cells | Odd integers 1–31, route width ≥ clearance and ≤ region size/4 |
| `secondary_loop` / `service_trunk` / `liquid_trunk` | true / true / false | Explicit booleans |
| `curve_services` | false | Requires `service_trunk`; selected finite curve has at most 16 sites |
| `geometry_exports` | Empty map | At most 16 exact semantic route/feature aliases |

Planning coordinates preserve the generator's signed ±`2^40` domain with room
for canonical boundary geometry. Candidate rectangles have positive dimensions
through 16,384 cells and must fit their declared parent. Candidate finite-curve
addresses must lie in the selected order's domain. Semantic IDs use 1–64 ASCII
letters/digits/underscore/hyphen/dot per authored component; full generated paths
are distinct from those components.

Rules carry exact positive counts, priority within ±1,000,000, at most 16 tags,
16 theme entries, 32 typed parameters, 16 sockets and 16 preferences. Theme weights
are finite positive values through 1,000,000 and normalize canonically. Preference
weights are finite within ±1,000,000; negative weights invert a preference while
hard constraints remain mandatory. Separation and neighbor radii are 0–16,384
cells; inclusive occupancy fractions are within `[0,1]`. Socket aperture widths
are odd 1–31 and must fit the selected edge; passage widths also meet clearance.
The JSON adapter caps wall thickness at 64 while native declarations admit 128;
the selected rectangle must retain a nonempty interior for any positive shell.

`max_raster_operations` covers full final-cell sampling, square-clearance and
route connectivity work, plus scans along every declared floor/ceiling/wall
contact edge. `max_prepared_bytes` includes final-cell scratch and retained
route/support records. `static-solid-contact-v1` requires at least one surviving
solid contact on each declared side; it introduces no gravity or full-footprint
support threshold. Inspect `supports_passed` separately from route `passed`.

`district_assignment` reuses GEN-003's bounded finite solver and scratch contract.
`district_themes` is keyed by exact unsigned category IDs represented as sixteen
lowercase hexadecimal digits in JSON. Neither assignment nor feature metadata
allocates live World fields. The
[hierarchy contract](../systems/procedural-hierarchical-generation.md) owns
priority, fallback, semantic identity, canonical boundary ownership and geometric
traversal qualifications; the
[interfaces](interfaces-and-message-contracts.md#native-semantic-plans-and-copied-hierarchy-inspection)
own returned records.

## Semantic plane generation limits

**Current GEN-005 opt-in extension:** a schema-3 recipe may include
`semantic_planes` schema 1 / algorithm 1. It composes the existing hierarchy and
typed graph; it does not change the retained generator algorithms. Values below
come from [`PlaneLimits`](../../native/include/cybersand/generation_planes.hpp),
the [JSON adapter](../../godot/native_extension/generation_planes_adapter.inc)
and the [semantic owner](../../godot/scripts/depth/semantic_plane_runtime.gd).

| Limit | Native default | Godot JSON maximum | Native hard maximum |
|---|---:|---:|---:|
| Templates across projections, fixtures, links and actors | 128 | 128 | 512 |
| Expanded projections | 8,192 | 8,192 | 16,384 |
| Expanded fixtures | 1,024 | 1,024 | 4,096 |
| Expanded links | 2,048 | 2,048 | 8,192 |
| Play actors | 8 | 8 | 8 |
| Cells per plane | 1,048,576 | 1,048,576 | 4,194,304 |
| Logical preparation/raster operations | 250,000,000 | 4,000,000,000 | 4,000,000,000 |
| Prepared storage | 16 MiB | 64 MiB | 64 MiB |
| Publication storage | 64 MiB | 256 MiB | 256 MiB |
| Diagnostic storage | 4 MiB | 16 MiB | 16 MiB |
| Aggregate declared runtime event rate | 256 | 256 | 256 |
| Scheduled fixture cell writes over lifetime | 4,194,304 | 4,194,304 | 67,108,864 |

The retained GEN-005 examples explicitly request 2,000,000,000 logical operations.
GEN-007 replaces whole-list sample scans with bounded spatial candidate indices
and conservative maximum local-candidate charges. Raster work includes generator work
when play uses it, the shared typed graph once per affected plane/sample, and
final registration/receipt scans. `max_operations` independently bounds semantic
preparation and each requested raster/publication, not cumulative session work
or elapsed time. Prepared storage reports additional plane-compiler allocations;
the shared GEN-003/004 generator retains its own existing budgets.
Native declaration acceptance does not waive
the stricter host limits below.

| Host or authored bound | Admitted value |
|---|---|
| Complete finite world | Each axis 8–1024 cells; signed Godot `Rect2i` coordinates; all four planes required |
| Native material rectangles | At most 4,096 nonempty merged runs per plane; payload must exactly reconstruct copied material bytes |
| Complete copied packet | 64 MiB and 262,144 metadata nodes |
| Features / projections / fixtures / links / actors | 8,192 / 8,192 / 1,024 / 2,048 / 8 |
| Fixture rectangle | At most 512 cells, contained in its feature and plane |
| Simultaneous fixture writes | At most 8,192 cells per plane tick, including cleanup |
| Schedule / repeat | Through tick 360,000; 1–10,000 repetitions; positive period; cleanup after final application |
| Expected native products | At most 16 valid nonempty material IDs, distinct from the fixture's feed |
| Outstanding observations / queued commands | 32 each through the retained depth boundary |
| Runtime event radius / rate | At most 32 cells; 256 events per target-plane tick, additionally constrained by each link |
| Retired bundle revisions | 128; further replacement fails explicitly rather than evicting stale-admission history |
| Dynamic rates | 0–60 Hz; example play/rear/effects rates 30/20/15 Hz |
| Frozen background | Zero ticks, fixtures, actors and runtime event writes |
| Projection density / wall thickness / route width | Finite 0–1 / 0–128 cells / zero or odd 1–63 cells, with valid contained geometry |
| Projection masks | Optional `application`/`exclusion` `spatial:<expanded.id>`; normalized or boolean dimensionless output |

Lifecycle reset constructs a new bounded incarnation; it is not persistent
mutation rebasing. The [semantic contract](../systems/procedural-semantic-planes.md)
owns interpretation and [interfaces](interfaces-and-message-contracts.md#semantic-plane-proposals-and-owner-admission)
own copied packet fields. The [authoring guide](../operations/semantic-depth-authoring.md)
owns example controls and reproducible captures.

## Depth host and Deepworks configuration

**Current opt-in source:** these values belong to
[`CyberDepthLayerRuntime`](../../godot/scripts/depth/depth_layer_runtime.gd),
[`CyberDepthCompositor`](../../godot/scripts/depth/depth_compositor.gd),
[`CyberDepthLayerSurface`](../../godot/scripts/depth/depth_layer_surface.gd),
[`CyberDeepworksRuntime`](../../godot/scripts/exhibition/deepworks_runtime.gd)
and the [`Deepworks host`](../../godot/scripts/exhibition/deepworks.gd).
The [depth contract](../systems/depth-layers-and-parallax.md) owns rendering and
reset semantics; the [exhibition guide](../operations/deepworks-exhibition.md)
owns map content, source scheduling and controls.

| Setting | Current value or admitted bound |
|---|---|
| Depth authored dimensions | Each axis 8–1024 cells, including non-square worlds; omitted size defaults to 640 × 360 for Strata Theatre |
| Native storage and copied RG8 backing | 1024 × 1024 per plane, unchanged by authored ROI |
| Deepworks total composition | 1024 × 1024; sixteen 256 × 256 districts; four independent native worlds over the same map coordinates |
| Native worker policy | One worker per isolated plane; host serializes adapter calls |
| Strata default rates, play/scripted/effects/background | 60 / 20 / 30 / 0 Hz |
| Deepworks target rates, same order | 30 / 20 / 15 / 0 Hz |
| Dynamic rate and catch-up bounds | 0–60 Hz; at most two native steps per plane per `advance()`; background must remain at zero |
| Authoring per plane | At most 4,096 rectangles and 4,194,304 counted cell writes; valid current material IDs excluding reserved ID 10 |
| Guard | One cell around the complete accepted authored extent; commands/sources stay inside it and effects sinks preserve it |
| Explicit depth command queue | At most 32 pending commands; disc radius 0–32 cells |
| Effects material admission | Empty, Water, Dust, Steam, Spark and Smoke |
| Surface packet limits | RG8; at most 4,096 patches, 2,097,152 bytes and one backing's cumulative staged area; generation cannot move backwards |
| Whole-image texture upload | 2 MiB for each admitted changed plane |
| Deepworks source programme | At most 192 events; each rectangle at most 512 cells; conservative sum at most 8,192 source cell writes per plane per native tick |
| Event identity and district | Unique nonempty ID of at most 80 characters; district integer 0–15 |
| Event rectangle and plane | Positive rectangle wholly inside its declared district and map guard; `play`, `scripted` or `effects`; no `background` writes |
| Event tick and repetition | `first_tick` 0–36,000; `period` 1–36,000; `repeat` 0–10,000, where zero means unbounded repetitions |
| Event fields | Exactly `id`, `district`, `layer`, `rect`, `material`, `first_tick`, `period`, `repeat`; numeric IDs/ticks/repetitions must be integers |
| Deepworks views | Overview 1024 × 1024; district 256 × 256; apparatus focus 200 × 200; wheel zoom clamps width to 128–1024 |
| Deepworks layer scales | 1 / 1 / 1 / 1 |
| Deepworks raw parallax factors | 1 / 0.98 / 0.965 / 0.94, with strength 0.8 |
| Deepworks relief | Depth 5, four slices, pixel quantization 1 |
| Deepworks presentation | Haze 0.46, reflection 0.12, near-frame strength 0.30, cutaway radius 100 |
| Deepworks paint brush | UI radius 1–8, default 2; foreground or rear apparatus |
| Guided tour | Sixteen serpentine views, 14 running seconds each; nominal 224-second circuit |

Reset and programme installation validate the complete candidate before replacing
live worlds or generation. Event validation checks widened scalar coordinates
before rectangle-end arithmetic, so an overflowing rectangle is refused.
`configure(authored_size)` sets compositor/surface dimensions once;
`set_view(origin, extent)` validates then synchronizes the view and clamps its
camera. These are private Godot prototype APIs, with no new native ABI fields,
general World configuration schema or change to MicroScenario event capacities.

## Native WorldConfig defaults

Scene-specific exception: each of the four [Neon Reliquary district tiles](../operations/neon-reliquary-demo.md)
opens a 960 × 540 overview at `(32,16)`, with four 480 × 270 detail views and fixed
`[32,16,960,540]` simulation interest. The stack order is Neon Reliquary, Middle
Cyberberbia, Sewertech Alley, Industrial Underswamp. One finite 1024 × 1024 world
is installed at a time; district selection loads the original paused layout.
Each has no Rapier bodies or scheduled events and retains Baseline transport and
Water8/coherence12. Per-tile capacities and ordinary sandbox defaults are
unchanged. The scene guide owns viewpoints and controls.

The separate [Blacksite Nine complex](../operations/blacksite-nine-demo.md) uses
one 960 × 960 composition at `(32,32)` inside the same 1024 × 1024 native world.
Its nine camera tiles are 320 × 320, with twelve reciprocal 28-cell-wide clear
passages. Fixed interest is `[32,32,960,960]`; the ordinary owner execution policy
and transport controls remain. The overview is 960 × 960, individual tile views
are 320 × 320, and player follow uses 480 × 270. Camera selection preserves the
whole world; reset restores all nine tiles. The existing schema-2 limits apply
to the complete complex: 4,096 rectangles, eight world areas of construction
writes, 1 MiB JSON and at most twelve presentation regions (nine are used).

Source: [world.hpp::WorldConfig](../../native/include/cybersand/world.hpp).
All members are construction-time; `cybersand_config_v2` mirrors its declared
subset, with the separate liquid-policy entry point noted below.

| Member | Default | Meaning |
|---|---:|---|
| `chunk_size` | 128 | Storage chunk edge |
| `sleep_after_quiet_ticks` | 3 | Activity-block quiet threshold |
| `ambient_temperature` | 200 | Initial signed temperature; physical units undefined |
| `initial_chunk_reserve` | 64 | Initial reservation hint, not maximum/resident count |
| `backend` | `PhasedInPlace` | Serial and phased implemented; Buffered tick throws |
| `activity_block_size` | 32 | Activity/sleep block edge |
| `scheduling_core_size` | 64 | Four-phase core edge |
| `maximum_rule_radius` | 2 | Prepared write expansion; active catalogue requires at least 2 |
| `worker_threads` | 1 | Standalone worker count; adapter overrides below |
| `parallel_job_threshold` | 8 | Minimum phase jobs before pool dispatch |
| `active_core_capacity` | 4096 | Gathered core candidates/results; checked before deduplication |
| `active_chunk_capacity` | 4096 | Active-chunk scratch bound |
| `maximum_chunk_count` | 4096 | Resident chunk limit |
| `deferred_event_capacity` | 1024 | Accepted explosion queue bound |
| `maximum_explosion_radius` | 64 | Largest accepted radius |
| `liquid_solver_policy` | every liquid's current default | Immutable LCB-001 policy; construction refuses any mapping this build has not qualified ([foundation](../architecture/liquid-solver-family-policy.md#native-policy-foundation-current-2026-10-24)). Not mirrored by `cybersand_config_v2`; use `cybersand_world_create_with_liquid_policy_v1`. |

**LCB pressure family block (#245 law, retained by accepted #246 main; experimental).**
When `liquid_solver_policy` assigns Water to `pressure_flow_v1/reference`, the
optional family block `pressure_flow_v1` version 1 sets two construction-time
values. Omitting the block applies the defaults. Out-of-range values are refused
before construction.

| Field | Default | Range | Meaning |
|---|---:|---|---|
| `gas_enabled` | 1 | 0..1 | Resolve sealed gas compartments each tick; 0 skips gas resolution, so every Empty boundary has zero gauge (vented) |
| `atmospheric_head_rows` | 32 | 16..4096 | Atmospheric pressure in rows of saturated Water head (isothermal gauge scale) |

The fixed v1 kernel constants (`kFlowScale` 1024, acceleration 3/1, retain
256/256, friction 0, start/moving dead bands 128/10 per 255 of a row, overfill
limit `maximum()`, compartment volume limit 16 384, capacity 1024, history 64) are
not configurable; they are Proposed values recorded in the receipt's
`family_parameters` ([declared parameters](../architecture/pressure-flow-v1.md#declared-parameters-v1)).

**Accepted main #200 W-CY and setup codecs (#246, `ec58d919`).** Water × `cellular_yield_v1/reference` accepts
its own optional material block **v2**, one `viscosity_index` integer 0..255,
default 0. Its law version is 1; the illustrative material-block v1
`flow_rate_permille` schema is not reinterpreted. Whole-cell Water requires
`maximum()` at ingress. Explicit native `water-normalize-v1` preparation admits
3–8 mass bits, at most 1024 cells per domain side and 1,048,576 final unique tuple
records (caller may lower the record budget). The subsequent experimental
`codex/lcb003-application-host` slice adds typed normalization opt-in for fixed,
actor-free schema-2 MicroScenarios in both existing application owners. Its
`normalize_water` bool maps only to the explicit `water-normalize-v1` rule;
false never rounds silently. Unknown native rule strings refuse. There is one
pending preparation token per adapter, and Reset retains the accepted option.
See the [bounded host contract](../architecture/liquid-prepared-setup-and-receipts.md#controlled-application-host-preparation-slice)
for its constructor and platform limits. Subsequent explicit Exploratory source
stages body-free sampled ownership. Candidate collision queries keep the same
32×32 maximum box and four modes as the existing native owner query. Initial
owner interest uses the definition camera, existing 480×270 view and selected
buffers/window; request/settings/profile changes fence commit. The subsequent
desktop articulated route stages at most the existing 8 actors/64 body parts,
strict 11-float copied body records and actual masks before receipt capture.
Its permanent private physics space remains inactive with frozen bodies through
at least two distinct real physics frames and complete initial terrain setup.
The app retains its existing 32-chunk/750-microsecond collider budget. Other body
constructors remain open; see [staged physical ownership](../architecture/liquid-prepared-setup-and-receipts.md#staged-articulated-physical-owners).

**Integrated #202 IN application control:** prepared options accept explicit
`maximum_rule_radius`2 or3(default2). Brine IN requires3; its Current comparator
must select the same geometry. Original Current and ordinary default
reconstruction restore protected2. The native-backed panel edits the optional
family4/block2 `damping_numerator`0..16 over denominator16(default1), and Reset
retains accepted geometry/parameters. Actual World readback supplies the value,
effective identity and instance hash/CYPS3; non-IN remains version2. Water IN
still refuses. These controls do not complete the remaining constructor matrix
or full source/runtime/host qualification.

**Qualified #202 host-observation foundation:** collection runs only at evidence
boundaries. Version1 bounds manifests/current script files at2MiB each, the
manifest-listed script subset at1024 entries, claim depth at24, pure claim values
at131072, each container at32768, claim UTF8 text at2MiB, keys at256 characters
and canonical host bytes at4MiB. Signed integer claims become decimal strings.
Capacity or non-value claims refuse; no capacity outcome upgrades native/host
full matched eligibility. Library path/current-file observation is not mapped
module proof. See the [ownership and scope](../architecture/liquid-prepared-setup-and-receipts.md#qualified-host-observation-foundation).

The subsequent ordinary Water Feel family route retains the independent existing
Water semantic policy/recipe and requires explicit Exploratory with a body-free
sampled owner. It retains accepted policy/normalization/radius on reset and
semantic/scenario change. Blind/unstaged bodies and CY Water fractional future
sources refuse; initial normalization never changes scheduled actions. No new
Water policy field, body capacity or default is introduced. See [route bounds](../architecture/liquid-prepared-setup-and-receipts.md#ordinary-water-feel-preparation).

The later desktop reference-body stage retains that same policy/recipe and
requires Exploratory. It copies the original three 8×14, mass1 reference bodies
at (160,176), (212,176), (264,176) with epoch0 into a permanent physics space;
no geometry padding, automatic family selection or new body capacity is added.
Their actual poses stay frozen through terrain/native readiness and final
commit. The existing asynchronous response age limit still rejects old samples.
The later synchronous supported-body route uses its own actual poses; barrel owners and actual Web qualification remain open. See
[prepared reference-body ownership](../architecture/liquid-prepared-setup-and-receipts.md#prepared-water-feel-reference-bodies).

The ordinary Experiment Tower additionally accepts these explicit settings only
in Exploratory mode with its existing sampled owner. Selected floor0..4, landing,
camera and resolved transport profile are final preparation input. Native worker
and synchronous controller retain existing floor/release/schedule/manual tools;
reset and transport-profile rebuild keep accepted solver/normalization/radius.
Default constructors still retire that typed setup and use protected radius2.

The [native prepared setup/receipt/accounting contract](../architecture/liquid-prepared-setup-and-receipts.md)
owns these bounds, native-issued refusal/failure outcomes, source/host
qualifications and the narrow owner-requested codec freeze. Complete physical
hash/CYPS use version2 for non-IN and actual instance version3 for IN, with
unknown formats and historical CYPS1 refused.
Defaults, historical content/state hashes and the C64-E8 Cell ABI are unchanged.
Exact shared accounting adds fixed per-job scratch 3816 bytes: 15,630,336 bytes
at default `active_core_capacity` 4096, plus a 6088-byte World snapshot in the
measured x64 builds. These costs are separate from pressure storage and imply
no performance qualification.

The worker activity repair adds a signal-flag byte and one 64-bit earliest
deadline per ordinal slot, separate from the quantity/discovery/IN accounting
above. Two contiguous `ParallelState` vectors own the complete payload; each
scheduling slot has fixed disjoint spans into them. This uses two owning grid
allocations per World, independent of `active_core_capacity`, rather than two
owning vectors per job. Let `L = core + 2 * radius`.
When chunk edge is divisible by activity edge `B`, the reserved axis bound is
`ceil((L-1)/B)+1`; otherwise the safe axis bound is `L`, preserving single-worker
unaligned chunks and their partial tail blocks. The squared bound covers the
whole core/halo, including moved-carrier wake targets. Default 64/core,32/activity,
radius2 reserves 16 slots/job and 589,824 payload bytes for 4096 jobs. With activity1,
that same core/radius reserves 4624 slots/job and 170,459,136 payload bytes
(162.56MiB); explicit IN radius3 reserves 4900 slots/job and 180,633,600 bytes
(172.27MiB). The two vector owners, per-job spans/scalar grid metadata, allocator
overhead and existing job scratch are additional. Both the squared axis bound
and `active_core_capacity * slots_per_job` are checked before allocation and
span binding. Allocation/length failure occurs during construction;
there is no tick-time grid resize or fallback to the optional 64-report observer.
Each executed job clears its reserved flags; serial reduction scans its actual
rectangular ordinal slots. Worker signal recording is constant time, with no
linear deduplication search. Thus the repair has bounded setup memory and real
per-job bookkeeping cost even when no signal is emitted; older pressure timing
records do not measure this changed scheduler. The fresh publication/Native
benchmark and any later total-cost campaign retain separate source bindings.

Native pool construction also retains typed refusal if reserve or a later
worker startup throws. It stops, notifies and joins the already-started prefix
while its mutex and condition variables still live; it does not silently reduce
the requested worker count. The C API regression keeps complete one-worker
allocation-failure sweeps at capacities1/4096 and a complete four-worker sweep,
with the existing20000 convergence bound. Local allocation counts and the
reproduced partial-startup hang have
[dated source-bound evidence](../audits/2026-10-25-water-inertial-native.md#contiguous-activity-storage-and-constructor-retirement--2026-10-25).

[World::World](../../native/src/world.cpp) checks chunk edge 8–1024, activity edge
1–1024, workers 1–256, explosion maximum 1–256, and nonzero quiet/reservation/
capacity/dispatch values. Initial reserve cannot exceed resident capacity.
Multiple workers require phased backend and aligned chunk/core/activity sizes.
[SchedulerGeometry](../../native/src/scheduler_geometry.cpp) requires even core
edge at least 2 and radius from zero through half the core edge; descriptor
validation imposes the active-catalogue radius requirement.

These constraints do not make serial and phased interest filtering equivalent;
see the [region contract](../systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry).

## LCB-005 explicit standalone execution geometry

The #212 branch's Godot `build_liquid_policy_world` adds one optional final
`maximum_rule_radius` integer: default2, accepted values2 and3. Brine IN requires
explicit3; refusal preserves the live session. Ordinary World/demo/tuned/Water
Feel construction, reset and CYSD1 reconstruction use2 rather than inheriting
IN geometry. Exact CYPS imports use the saved geometry. Native scheduler/core
constraints still apply; this does not enlarge a protected Current comparator.
Actual applied radius and effective damping numerator0..16/denominator16 are
copied readback, not live settings. See the [IN binding contract](../architecture/inertial-cellular-v1.md#standalone-godot-readback-and-explicit-geometry).

The isolated Water IN successor also explicitly requires3. Its original-owner
MotionFootprint guards include repeated carrying packing and exchange bracing,
with actual read3/write2 witnesses. Water coherence0..12 gates horizontal-only
opportunities; retained vx and signed ax remainder follow the declared adapter.
Precision3..8 uses actual `maximum()` with no fractional adhesion or implicit
rounding. [Water adapter semantics](../architecture/inertial-cellular-v1.md#water-in-native-successor--2026-10-25)
add no material/family parameter schema, default geometry or Cell ABI change.

## LCB-002 derived pressure execution limits

**Current in `codex/lcb002-pressure-variants`; final acceptance pending.**
`WorldConfig::pressure_optimization` controls construction-only derived work,
not pressure calibration: `index_chunk_capacity` 4096 chunks,
`head_repair_cell_budget` 4,194,304 cells, `gas_member_capacity` 1,048,576
members and `gas_invalidation_pair_budget` 4,194,304 classification pairs.
Incomplete head/index or gas discovery selects the complete admitted reference
operator, with explicit status and charged fallback work.

Execution3 uses one eligible ordinary warmup visit and eight deferred eligible
visits after failed proof. Whole-layer admission requires usable heads and prior
Water work. Eight eligible-tick trials charge each invalidated/reset cell1,
complete proof40 and valid reuse1, crediting an actually saved motion call8; a
deficit or saturated uncertainty suspends the layer for32 eligible-head ticks.
Cold/off invalidation is constant work and admission resets stale certificates
before reading them. These fixed work credits are not wall-clock break-even
evidence and change no material cadence or physical law. The [optimization contract](../architecture/pressure-optimization.md)
owns mechanism, capacities, storage and the six-u64 native execution identity.
Godot copied budgets/capacities/counters use exact unsigned decimal strings;
they are not live settings or rest authority. Reference has no optimization
extension identity. Derived budgets and caches do not alter physical authority
or serialize certificates; restore rebuilds them cold.

## Finite native adapter overrides

Source: [CyberNativeCellWorld::create_world](../../godot/native_extension/cyber_native_cell_world.cpp)
and [header constants](../../godot/native_extension/cyber_native_cell_world.hpp).

| Value | Adapter setting |
|---|---:|
| Finite world | 1024×1024 |
| Backend / initial reserve | PhasedInPlace / 64 |
| Maximum resident chunks | 128 |
| Active-core / active-chunk capacity | 1024 / 128 |
| Parallel phase threshold | 2 |
| Native snapshot slots | 3 |
| Patch capacity per native snapshot slot | 64 |
| Byte capacity per native snapshot slot | 2,097,152 (1024×1024×2) |

The standalone snapshot constructor requires nonzero caller-supplied slot/patch/
byte limits and has no general defaults. Adapter choices are a separate layer.

## Adapter worker policy

The project setting is `cybersand/native_worker_threads=0`.
`auto_worker_threads` implements the owner's 2026-09-08 policy:

| Reported logical processors | Auto workers |
|---|---:|
| Below 4 | 2 |
| 4–11 | 4 |
| 12 or more | 6 |

A positive explicit request is clamped to 1 through
`min(32, reported logical processors)`; the adapter clamps its processor input
to at least 1. Nonpositive requests take Auto. Auto can intentionally choose two
on a one-processor report. Counts are resolved when constructing a world, not
retuned during play.

No-thread Web forces one cellular worker. Threaded Web keeps Auto and separately
stages `threads/emscripten_pool_size=32` plus `threads/godot_pool_size=2` in
[build_web.py](../../tools/build_web.py). Prewarmed slots are not all cellular
workers. Browser UI reports `navigator.hardwareConcurrency`; it does not detect
physical cores.

## Body coupling values

Source: [native adapter constants](../../godot/native_extension/cyber_native_cell_world.cpp),
[World::kMaximumTransientBodies](../../native/include/cybersand/world.hpp),
[fallback constants](../../godot/scripts/cell_world.gd), and
[packed contract](../../godot/scripts/rigid_body_coupling.gd).
These are gameplay tuning/bounds, not calibrated physical units.

| Native constant/concept | Value | Fallback counterpart |
|---|---:|---|
| Maximum transient body IDs | 64 | `MAX_BODIES=64` |
| Input/result float stride | 11 / 9 | Shared packed layout |
| `kMaximumBodySweepDistance` | 32.0 | `MAX_BODY_SWEEP_DISTANCE` |
| `kBodySweepSampleSpacing` | 1.0 | `BODY_SWEEP_SAMPLE_SPACING` |
| `kMaximumBodySweepSteps` | 24 | `MAX_BODY_SWEEP_STEPS` |
| `kMaximumEjectionDistance` | 8 | `MAX_BODY_PIXEL_EJECTION_DISTANCE` |
| `kBodyPixelContactImpulse` | 0.025 | `BODY_PIXEL_CONTACT_IMPULSE` |
| `kBodyDisplacementReactionImpulse` | 0.18 | `BODY_DISPLACEMENT_REACTION_IMPULSE` |
| `kBodyBoundaryPressureImpulse` | 0.19 | `BODY_BOUNDARY_PRESSURE_IMPULSE` |
| `kMaximumBodyImpulsePerTick` | 3.0 | `MAX_BODY_IMPULSE_PER_TICK` |

The retained three reference rectangles are 8×14. ACT-004 admits up to eight
physical rigs with eight total parts each, including held parts, through the
same 64-ID bound. Current authored rigs use one through seven parts before an
optional equipment chassis; prepared assemblies remain within eight. SetP
circle wheels use conservative square native samples with the same diameter.
Sweep truncation/sample limits and unresolved
overlap semantics belong to the [coupling contract](../architecture/rigid-body-and-cellular-coupling.md);
these numbers do not guarantee continuous collision detection.
Fallback-only `BODY_GRAVITY_SUPPORT_IMPULSE_PER_MASS=92/60` is retained in
source. Preferred hard-terrain contacts are Rapier-owned, without that support
impulse.

## Desktop fallback simulation constants

Source: [cell_world.gd](../../godot/scripts/cell_world.gd). These are not native
Water/activity semantics; the Web compatibility profile still uses native cells.

| Exact name | Value |
|---|---:|
| `WORLD_WIDTH` / `WORLD_HEIGHT` | 1024 / 1024 |
| `ACTIVITY_BLOCK_SIZE` / `CELL_SLEEP_TICKS` | 16 / 8 |
| `SPARSE_FLIGHT_ACTIVE_BLOCK_THRESHOLD` / `SPARSE_FLIGHT_DISTANCE` | 12 / 2 |
| `FREE_LIQUID_LATERAL_FLOW` | 255 (directed-flow sentinel, not native mass) |
| `YIELDING_LIQUID_LATERAL_BUDGET` / `YIELDING_LIQUID_PRESSURE_YIELD` | 6 / 1 |
| `PASTE_LIQUID_LATERAL_BUDGET` / `PASTE_LIQUID_PRESSURE_YIELD` | 3 / 3 |
| `WATER_VISCOSITY` / `SLUSH_VISCOSITY` / `PASTE_VISCOSITY` | 0 / 192 / 240 |
| `MAX_LIQUID_LATERAL_FLOW_RATE` | 24 cells per serial update |
| `COHERENT_LIQUID_LATERAL_FLOW_RATE` | 1 |
| `WATER_SURFACE_ADHESION` / `SLUSH_SURFACE_ADHESION` / `PASTE_SURFACE_ADHESION` | true / true / true |
| `LIQUID_PRESSURE_SAMPLE_DEPTH` / `LIQUID_LEVEL_SEARCH_DISTANCE` | 32 / 256 |

The threshold enables isolated-cell alternate-tick free flight, not the removed
load-derived block stride. Current fallback reports stride one and zero deferred
blocks; excluded blocks retain wake flags. Native Water's three-quarter lateral
mass-difference relaxation, 12-tick
coherence delay, 48-unit supported-film threshold and separate fallback mechanics
belong to the [Water contract](../systems/water-design.md). Material cadence,
including specialized Ice sampling, belongs to
[material kernels](../systems/materials-and-rule-kernels.md#kernel-execution-and-cadence).

## Desktop presentation and pacing

Sources: [main.gd](../../godot/scripts/main.gd),
[simulation_worker.gd](../../godot/scripts/simulation_worker.gd), and
[project.godot](../../godot/project.godot).

| Name/concept | Current value |
|---|---|
| `VIEW_SIZE_PRESETS` | 320×180; 480×270; 640×360; 960×540; default first |
| `SIMULATION_MARGIN_PRESETS` | Per side: 0×0; 32×36; 128×128; 256×256; default second |
| Output/window viewport | 1920×1080, logical view aspect-fitted |
| `SIMULATION_HZ` / `FIXED_TIMESTEP` | 60 / 1÷60 s |
| `TICK_INTERVAL_USEC` / `MAX_BACKLOG_TICKS` | 16667 / 3 |
| Render publication choices/default | 30/45/60 Hz; default 45 |
| `DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC` | 22222 |
| `HARD_SURFACE_SNAPSHOT_INTERVAL_USEC` | 250000, desktop extraction sampling |
| `HARD_SURFACE_REBUILD_INTERVAL` | 0.10 s, controller sync cooldown |
| `HARD_SURFACE_CHUNKS_PER_FRAME` | 32 queued chunks |
| `HARD_SURFACE_FRAME_BUDGET_USEC` | 750, checked between chunk rebuilds |
| `MAX_PENDING_RENDER_PATCHES` | 256 before full-refresh recovery |
| Pending render-byte recovery threshold | Greater than 2,097,152 bytes |
| `RENDER_PATCH_METADATA_STRIDE` | 6 integers |

The 750 µs check excludes extraction and packet validation/copy/queueing; a single
chunk can exceed it. Pending limits trigger recovery after accumulation and are
not process-wide allocation ceilings. Target pacing does not guarantee actual
60 ticks/s.

## Web quality

Source: [web_demo_controller.gd::set_quality](../../godot/scripts/web_demo_controller.gd).
Default quality is NORMAL.

| Quality | Logical view | Per-side margin | Publication target |
|---|---|---|---:|
| LOW | 320×180 | 16×18 | 30 Hz |
| NORMAL | 480×270 | 32×36 | 45 Hz |
| HIGH | 640×360 | 64×72 | 60 Hz |

Web tick ownership, maximum callback catch-up, and terrain gating belong to
[threading](../architecture/simulation-tick-and-threading.md).
These pixel presets do not implement a universal 10% horizontal/20% vertical
formula; that Approved proposal still has unresolved percentage semantics.

## Dependencies and unimplemented configuration

[rapier2d.lock.json](../../godot/third_party/rapier2d.lock.json) selects
`Rapier2D`, tag `v0.35.2`, official 2D single build, with a `4.7.x`
compatibility constraint. The exact tested editor is
`4.7.stable.official.5b4e0cb0f`. Upstream “cross-platform deterministic” build
wording is not a CyberSand replay proof. Full dependency hashes/build pins and
platform payload limits belong to the [build guide](../operations/github-development-and-release.md)
and [Rapier runbook](../operations/rapier-2d-migration-runbook.md).

**Approved concepts; Planned schema:** serializable interest and capacity,
bounded gameplay fidelity with a future strict mode, general command/transfer
reservations, and body/shape/substep policy. Final numeric units, production
memory/quality/acceptance thresholds, high-water reset conventions, automatic
live resizing, and configuration migration remain undecided. Do not invent keys
or confuse the existing fixed CYSD1 metadata with that future schema.

## Diagnostic construction capacity

**Current:** Godot `cybersand/native_active_core_capacity` defaults to 1024 and
clamps to 1–1024 at adapter construction. It uses the same real core-candidate
capacity check as production. The issue #1 regression uses one to force failure;
changing this setting does not resize an existing World. Worker/profile pins and
other adapter defaults are unchanged.

## Interest request accounting

Current native `set_simulation_region` rejects nonpositive sizes and inclusive
endpoint overflow. Null selects all cores; finite bounds normalize to intersecting
cores. Same-coverage requests are equivalent for activity. Region transitions
reuse existing resident metadata passes, and retained excluded activity still
counts toward active-chunk capacity. Candidate-core capacity is checked before
deduplication; a re-entry wake may explicitly fail under a small construction
budget. Failed regions cannot be retried by reducing the window. See the
[interest contract](../systems/world-storage-and-interest-region.md).

## Which settings belong only to physics experiments?

**Current:** [diagnostic_reset](../operations/physics-characterisation.md)
accepts immutable per-fixture telemetry, traversal/worker, Mercury viscosity,
powder-target exchange and coupling gain/cap options. The runbook owns their
exact bounds and the fixture definitions own scene variants. Ordinary World
construction disables telemetry/overrides; `reset_demo_world` restores production
gains. No UI slider, material descriptor, gravity default or save field changed.
The [dated results](../audits/2026-09-09-physics-characterisation.md) distinguish
existing constants from diagnostic rule vetoes and future support models.

## Granular policy configuration

**Current:** `InteractionPolicy` version 1 sets downward/side occupancy to 8/9 and
9/9 samples and Mercury eligibility to every 30 ticks. Diagnostic reset accepts
`support_cells` 1..9 and `mercury_period` 1..60 only during fresh construction;
normal reset restores defaults. The C ABI and CYSD1 schema are unchanged and use
compiled defaults. No live/UI setting is added. See the
[granular policy](../systems/granular-interaction-policy.md) and
[version decision](../decisions/ADR-011-granular-interaction-policy.md).


## Issue #13 experiment checkpoint

[Experiment Tower](../operations/experiment-tower.md) recipe v4 is 1024 by 1024, with five 198-cell floor pitches, a 4096-rectangle constructor bound, one pending lab command, two release deadlines and a 256-input observation bound. No new per-cell storage is added.


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## Soliding successor experiment capacities

**Current standalone tooling:** [lifecycle model](../architecture/soliding-lifecycle.md)
and [discovery journal](../systems/settled-region-discovery.md) use explicit template
capacities. The journal defaults to at most 1024 cells per registered block; a
producer must refuse or deliberately tile larger custom World geometry. There is
no WorldConfig flag or gameplay control for either module. These test capacities
are not selected production thresholds; ordinary runtime remains unchanged.


## Player/environment tuning profile

**Current:** `godot/scripts/player_environment_profiles.gd` owns version 1.
The exact-current preset uses effective mass 1.0, gravity acceleration 92,
terminal fall speed 86, jetpack acceleration 180, maximum rise speed 60,
granular-response sensitivity 1.0, liquid-response sensitivity 1.0, traversal
thresholds 1/1/1 px and knee/clamber speed factors 0.65/0.35. The latter factors
are unreachable in the exact-current profile because knee/clamber do not extend
beyond the historical one-pixel step.

The Earth-feel candidate changes gravity only to 184; terminal speed remains 86.
These values are existing gameplay-space cell/pixel units, not calibrated SI
gravity or mass. The desktop editor accepts bounded custom values and applies
them only through a fresh reset. See the
[player/environment contract](../systems/player-environment-profiles-and-traversal.md)
for field bounds, material-response ownership and traversal semantics.

## Exploratory actor selection

**Current desktop:** F5 exposes all 46 articulated Rapier rigs, 29 sampled rigs,
the sampled baseline and the two retained single-body hull trials in the ordinary
sandbox and five authored exploratory maps. Physical sessions admit at most eight
actors and 64 parts, with up to eight rigs in a set comparison. Sampled session
capacity remains eight. Switching restores the selected map and starts paused;
the physical owner also waits for matching reset and terrain readiness. See the
[physical values](#physical-actor-values) and
[programme](../operations/physical-actor-programme.md) for controls and protected
scenarios. This adds no authoritative per-cell actor representation.

## Actor control prototype values

**Current, experimental:** [`actor_prototype.gd`](../../godot/scripts/actor_prototype.gd)
owns fixed version-1 **SetA** Runner, Skimmer and Crawler tuning. These values do not
inherit live PENV player/environment edits. Positions and dimensions use cells
(the current gameplay pixels), speeds use cells/second and timing uses seconds;
energy is a normalized gameplay resource. None is an SI calibration.

| Shared limit | Value and meaning |
|---|---|
| Sampled body | 8 by 14 cells, shared by all three models |
| Accepted update duration | At most 1/30 second; longer updates are bounded rather than running an unlimited catch-up loop |
| Velocity magnitude | At most 120 cells/second |
| Downward gravity | 140 cells/second squared for ground models and unpowered Skimmer motion |
| Ordinary movement sweep | At most four one-cell increments per axis per accepted update |
| Traversal search | At most one ledge search per update, with a maximum four-cell rise and clearance along the intervening path |
| Occupancy-query budget | At most 32 adapter occupancy queries per actor update; quota refusal blocks further movement |
| Observation | 16 floats; schema/order belongs to the [actor contract](../systems/actor-control-prototypes.md#how-can-a-neural-policy-control-the-same-actor) |
| Material landing response | Existing REM-003 C1 hook at effective mass 1.0 and sensitivity 1.0 |
| Runtime enclosure recovery | Disabled for these prototypes; bounded explicit spawn repair remains separate |
| Session admission | At most eight actor slots |
| Human command lease | Six ticks (100 ms at 60 Hz), renewed from the latest published observation |
| Policy command lease | Default 12 ticks, maximum 18 ticks, based on observation tick; at 60 Hz this is 200/300 ms of simulation time |
| Pending input | One latest held state plus coalesced rising edges per actor, with epoch/producer/sequence validation |
| Scripted demonstration cadence | One bounded action decision every six actor ticks (10 Hz at the 60 Hz simulation rate) |

| Model | Version-1 movement/action settings |
|---|---|
| Runner | Walk 60; jump speed 78; jump-release rise-speed cutoff 32; coyote time 0.10 s; input buffer 0.12 s; dash speed 120 for 0.10 s with 0.65 s cooldown |
| Skimmer | Cruise 54; boost 90; normalized two-axis input; energy drain 0.10/s in powered flight plus 0.65/s while boosting; ground recharge 0.45/s; braking recharge 0.20/s; exhausted flight resumes after energy reaches 0.15 |
| Crawler | Walk 32; hop speed 48; supported clamber up to four cells; secondary action braces |

| Model | Acceleration and deceleration in cells/second squared |
|---|---|
| Runner | Ground acceleration 900; air acceleration 360; neutral ground deceleration 1100; neutral air deceleration 180 |
| Skimmer | Powered steering and horizontal exhaustion drag 360; explicit vector airbrake 720, followed by gravity |
| Crawler | Movement acceleration 720; neutral horizontal deceleration 1200; brace immediately clears horizontal velocity |

The Crawler's admitted clamber may add up to four cells of vertical relocation
beside the ordinary movement sweep; the four-cell sweep limit alone is not a
total vertical-displacement claim. Skimmer energy recharges while resting on
ground, braking or exhausted. Neutral airborne input uses powered hover until
energy is exhausted. Lease durations are simulation-time limits, not a guarantee
of wall-clock response when the world or host is overloaded.

These finite limits describe controller work, not accepted many-NPC throughput or
zero-allocation execution. Read the [actor contract](../systems/actor-control-prototypes.md)
for input lifetime, ownership, capabilities and remaining platform/acceptance gaps.

## Actor rig values

**Current, experimental ACT-002:** the 26 additional SetB/F/Y/U/V rigs use
[`actor_rig_motor.gd`](../../godot/scripts/actor_rig_motor.gd), while SetA retains
the preceding constants. Catalog metadata supplies fixed unrotated dimensions;
the motor owns movement/resource tuning. Effort is a bounded action input, not a
live PENV override. Units remain gameplay cells, seconds and radians.

| Shared new-rig limit | Value and meaning |
|---|---|
| Session capacity | Eight actors; the F5 compare-set option adds the other selected-set rigs, at most seven actors total |
| Update duration / speed norm | At most 1/30 second / 160 cells per second |
| Baseline gravity | 156 cells per second squared before rig-specific authored lift/braking/gravity factors |
| Translation | Six one-cell sweep increments per axis; six-cell absolute travel budget per axis includes admitted ledge/pivot movement |
| Angular motion | At most 6 radians per second and eight tested angular increments; interval envelopes include interior AABB maxima |
| Occupancy queries | At most 96 per actor update; refusal is treated as blocked movement |
| Surface ray queries | At most 64 material reads per actor update, shared by cast/revalidation/ground sensing and actor-to-effect-origin checks |
| Rope length / acquisition range | 6–44 cells / 44 cells; retained anchors are refused beyond 52 cells, and read-budget exhaustion may shorten the available cast |
| Rope work | One terrain anchor and straight segment; bounded spring force with no positional teleport; negative reel shortens and positive reel extends |
| Ripper / Digger / Lineshank tool radius | 3 / 4 / 2 cells |
| Rocketjumper / Dropbot blast radius | 4 / 3 cells |
| Rocketjumper surface reach | At most six cells beyond the current conservative collision proxy along aim; no surface means no energy spend/recoil/effect |
| Local effect work | At most one effect, 64 material reads and 64 single-cell adapter writes per actor update; fixed radius at most four cells |
| Effect retention | No deferred effect queue; cancellation drops armed effects and charge |
| Effect materials | Explicit whitelist in `CyberActorRigEffects.editable_material`; Wall, composed body masks, out-of-bounds and other noneditable cells are protected |
| Input bounds | Movement components -1..1; normalized nonzero aim or zero; effort 0..1; trim/reel -1..1; finite values required |
| Minimal adapter defaults | Aim follows movement, effort 0.7, trim/reel zero, auxiliary false |
| Leases and producer cadence | Existing six-tick human lease, 12-tick policy default/18-tick maximum, six-tick demo cadence; deadlines derive from observed actor tick |
| Publications | Legacy 16-float rows plus v2 40-float rows; consumed action rows of ten floats, consumed edge flags and admitted/applied sequence identities |

The 12/18-tick policy limits are 200/300 ms at the desktop 60 Hz actor cadence;
they are simulation-time limits rather than a wall-clock service guarantee.
The ten consumed action fields and 40 observation fields are defined only in the
[actor-rigs contract](../systems/actor-rigs.md#what-does-the-version-2-observation-contain).
The internal catalog's `parameters` dictionary is currently empty; it is not an
editable movement schema. Effect-strength telemetry is an authored fraction,
not a calibrated physical pressure or a promise to edit every cell in the radius.

Clamberer adhesion drains 0.025 energy/second, permitting roughly 40 seconds from
full energy with valid contact and no other action expenditure. Walljumper's
1.15/second drain deliberately allows a much shorter attachment window. These are
resource calculations, not guaranteed travel durations across changing terrain.
Lineshank's held blade drains 0.06/second and derives lift and drag from airspeed,
each capped at 240 cells/second squared; its separate initial pulse costs 0.09
with a 0.24-second cooldown. Its bungee stiffness is `24 + 20 * effort`.
Rocketjumper recoil is `(78 + 65 * effort) * (1 - 0.7 * gap / 6)` in the direction
opposite aim, with admitted gap clamped to 0–6 cells, cost 0.26 and cooldown
0.55 seconds. The final common speed bound still applies.

| Set | Unrotated body dimensions in catalog order, width × height |
|---|---|
| SetA | Runner 8×14; Skimmer 8×14; Crawler 8×14 |
| SetB | Scout 8×12; Scrabbler 14×10; Ripper 10×10; GroundEffect 14×7; Digger 6×6 |
| SetF | Copter 12×8; Pouncer 10×10; Dropbot 10×10; Lineshank 8×12 |
| SetY | Walljumper 8×14; Clamberer 8×12; Swinger 8×12; Rocketjumper 10×12 |
| SetU | Springjack 8×12; Gyrocrate 10×10; Bellows 10×10; Winchbug 10×8; Magpie 8×10; Skatesail 12×8 |
| SetV | Astra 8×12; Claude 8×12; Luna 8×10; Qwen 10×10; Bonsai 6×10; Jev 10×10; Gemini 12×8 |

Clamberer may hold an 8×6 tuck and Bonsai a 6×6 tuck. Both preserve their center
while resizing and restore the full hull only if its conservative occupied volume
is clear. The rotated occupancy envelope can exceed the listed unrotated width
or height; decorative extremities do not enlarge collision authority.

Bounds apply to owner-local controller work. They do not establish zero
allocations, complete native reaction cost, neural inference latency, target-PC
frame time or large NPC-population throughput. Source-owned movement details and
per-rig limitations remain in the [catalog contract](../systems/actor-rigs.md).

## Actor usable values

**Current experimental USABLE-001 / ACT-005:** [actor usables](../systems/actor-usables.md)
share the same catalogue/material budgets across physical and retained sampled
routes. Physical control uses the articulated session's issued-observation lease;
sampled control retains its separate equipment session. Units are gameplay cells,
seconds and authored charge; recipe accounting is authored cell slots.

| Boundary | Current value and consequence |
|---|---|
| Equipment actor slots | 8; follows the actor-session count |
| Committed projectiles | 64 globally |
| Fixed processors | 16 globally; at most 4 owned by one actor |
| Visual effects / hit receipts | 64 / 64 |
| Material work | At most 2,048 reads and 128 writes per equipment owner step |
| Swept projectile trace | At most 96 samples per movement segment |
| Accepted delta | At most 1/15 second |
| Shared equipment charge | 100 maximum; regenerates 6 per simulation second |
| Processor lifetime / stock | 45 seconds; normally 16 successful batches; Firewarden 12 pulses |
| Equipment leases | 12 ticks default, 18 maximum; desktop human input uses six ticks |
| Publications | Copied equipment selection, charge/cooldown/result, projectiles, devices, effects, hit receipts and work counters |
| Physical chassis | One per actor, reusing a held part or adding one jointed body before installation; included in the eight-part assembly limit |
| Physical request admission | At most eight requests, one pending/in-flight request per actor; atomic batch refusal preserves other pending work |
| Processor settling | Supported body at most 3 cells/s and 0.45 rad/s for eight consecutive physical ticks; stop automatic settling after 360 ticks |
| Physical processor ports | Local x = ±ceil(half-width + 2), local y = ±1; rotate by body angle and round to cell coordinates |
| Physical processor history | At most 8 × 10 actor/processor records; retain stock, age, cycles and cooldown across pickup and redeployment |
| Physical recoil | Accepted primary projectile use: 8 × power; tool use: 1.1 × power; tool alternate scales by 0.35; early projectile activation adds no launch recoil |
| Physical pickup / release grace | Owning grip within eight cells with clear path; released-body self-collision grace 0.2 seconds |

Capacity exhaustion refuses or defers bounded work. It does not silently replace
an existing projectile/device or authorize an unbounded catch-up queue. Exact
per-item speeds, fuses, recipes and controls belong to the
[usable contract](../systems/actor-usables.md).

## Thunderbowl values

**Current, experimental ACT-003:** the standalone
[arena/control reference](../systems/thunderbowl-control-reference.md) owns
behavior and schema meaning. These are fixed prototype constants, not live
world/PENV tuning or accepted population-throughput targets. Sources are
[`thunderbowl_arena.gd`](../../godot/scripts/thunderbowl_arena.gd),
[`thunderbowl_contract.gd`](../../godot/scripts/thunderbowl_contract.gd),
[`actor_rig_actuation.gd`](../../godot/scripts/actor_rig_actuation.gd) and the
[`example driver`](../../godot/examples/thunderbowl/thunderbowl_driver.gd).

| Boundary | Current value and consequence |
|---|---|
| Arena / population | One 256 by 144 cell training pit beginning at (96,96); 1–8 rigs; native workers=1 |
| Episode duration | 1–36,000 ticks; rig/material step 1/60 second; terminal scores freeze |
| Script / human cadence | Script, local reflex and graph-NCA decisions every six ticks (10 Hz); scene human sampling every tick (60 Hz) |
| Commands | At most eight envelopes per owner step, at most one admitted per actor; one latest held session packet |
| Input lease | Default 12, maximum 18 ticks, derived from the issued observation's tick; 19 issuance-history slots per actor |
| Local sensing | 9 by 9 material samples spaced four cells; at most seven actors within 64 cells and clear native-cell line of sight |
| Oracle sensing | Full copied actor states/virtual HP plus 32 by 18 global material samples at eight-cell spacing; no full-resolution native grid |
| Sensing budget | At most 8,192 reads per completed-state generation; at most 192 reads per line; conservative opaque result on exhaustion |
| Tag combat | Virtual HP=3, range=56 cells, aim dot threshold=0.94, rising-edge shot, cooldown=30 ticks, one target per shot |
| Tag work / reward | At most 10,752 line reads per step; +1/-1 per hit; elimination +2 shared among simultaneous contributors and -2 to victim; ring-out -2 |
| Local messages | One typed four-float message per admitted sender command; same team, radius/LOS gated, next-tick delivery; expiry is packet lease deadline; at most seven retained senders per receiver / 56 deliveries |
| Event history | Last 128 events retained with monotonic IDs and explicit dropped-event count |
| Smart-link requests | At most one pending request per actor, request interval at least 30 ticks; plan validity 1–120 ticks from original observation |
| JSON file boundary | At most 65,536 bytes for a loaded config/response; optional file I/O runs between arena steps and can delay the caller |
| Graph neural example | Four hidden channels per actor; one shared 12→8→4 residual MLP update per decision; 140 authored untrained weight/bias values clamped by schema to -4..4 |
| Metal profiles | Ripper: drive/torque/brake/zero; Copter: collective/lateral/torque/brake; Gemini: independent left/right/zero/zero; original motor geometry/query/speed caps remain |
| Direct readback | Version 1, 32 values per actor, separate from v1/v2 rig state; game-unit force/torque and mass/inertia, no SI/Rapier-force claim |
| Optional scene image | At most one copied 256 by 144 material region every six ticks (36,864 reads); no such full-region sampling in headless policy sensing |

`evaluation` declares `mechanics`, `matched`, `asymmetric` or `oracle_reference`.
The matched configuration gate requires equal rig, actuation lane and observation
profile and excludes human cadence; it does not prove equal effective compute,
training privilege or empirical fairness. The visible scene displays evaluator
information, so its human examples use mechanics/asymmetric classification.

## Physical actor values

**Current experimental ACT-004/ACT-005:** the
[catalogue](../../godot/scripts/physical_actor_catalog.gd),
[rig runtime](../../godot/scripts/physical_actor_rig.gd),
[session](../../godot/scripts/physical_actor_session.gd),
[effects owner](../../godot/scripts/physical_actor_effects.gd) and
[physical arena](../../godot/scripts/physical_actor_arena.gd) own these bounds.
Individual profiles intentionally vary; these are game units and capacity
limits, not calibrated real-world actuator specifications.

| Value | Current bound or default |
|---|---|
| Catalogue | 46 rigs in eight sets; all 29 original IDs plus twelve SetX and five SetP IDs |
| Assembly | At most eight parts, fourteen authored joints and three mounts per rig; current authored definitions use one through seven parts, and ACT-005 adds a chassis only where no held part exists |
| Population | One through eight actors and at most 64 total coupled parts; held/released objects retain their part slot |
| Physics / demo cadence | 60 Hz physical owner; demo decisions every six ticks, or 10 Hz |
| Command lease | One through eighteen ticks from the issued observation; helper/demo default twelve, desktop human six; nineteen issuance-history slots |
| Accepted physical delta | Positive finite delta, at most 1/30 second; oversized calls do not enlarge a control step |
| Profile gravity | Default 156 cells/s², applied through per-body gravity scale; profiles remain authored data |
| Actuation safeguards | Acceleration at most 1,200 cells/s², angular acceleration at most 100 rad/s², requested impulse at most 100 times the receiving part's mass |
| Local sensing | At most 24 rays per rig observation and eight reported contacts per part |
| Terrain rope | One straight attachment per rig; current runtime length clamp six through 96 cells; no wrapping |
| Effect batch | At most eight requests, one admitted request per actor, with epoch and sequence validation |
| Desktop pending effects | Eight requests total; atomic incoming-batch admission; over-capacity refusal preserves the existing queue and reports copied counters/last outcome |
| Per-effect work | At most 1,024 reads and 64 attempted writes; trace at most 100 cells; source-to-origin reach at most 32 cells; radius one through four |
| Deposition | Ordinary Sand ID 2; named `rocket_charge` permits Fire ID 6 and Gunpowder ID 26 in empty unmasked cells |
| Physical arena | Version 2; one native worker; one through 36,000 ticks; seed 0 through 2,147,483,647; local patch radius zero through eight, default six |
| Physical lab files | Config/action input at most 4 MiB per file; at most one scheduled action per actor/tick |

F5 comparisons include at most eight members from the selected set; selecting a
SetX actor cannot display all twelve SetX members simultaneously. The session
checks the complete assembly budget before installation. Its dictionary
observations and version-2 commands are separate from sampled actor packed rows.
Usable lifecycle, gyro/play semantics and producer limits belong to the
[physical actor contract](../systems/physical-actor-rigs.md).

## 4LY-003 flight laboratory configuration

The [flight lab](../systems/physical-flight-lab.md) is an additive
native/Rapier course mode, not a new physical profile or a configuration
change to the pre-existing 64-bit material cells. Its closed scenario
IDs are defined in
`godot/scripts/physical_flight_course.gd`; the existing ACT004 arena
accepts `course = "4ly-flight-course/v1"`,
`flight_scenario` and `flight_split` only with one actual 4LY body
at the registered start pose. The headless Episode accepts a model,
scenario, seed, split and producer and enforces 60 Hz physical steps,
a 6-tick decision interval, 12-tick action lease, arrival radius
12 cells (9 for hover), max final speed 2.5 cells/s and 36
consecutive dwell ticks. Scenario deadlines are bounded at
2400 real physics ticks; the prospective throughput pilot is
limited to 960. Source/profile/controller hashes and
`candidate_4ly002` calibration remain unchanged.

## Physical free-flight values

**Current experimental 4LY-001 controller + 4LY-002 candidate profiles:**
[`physical_flight_profile.gd`](../../godot/scripts/physical_flight_profile.gd)
owns all four complete validated parameter sets.
[`physical_flight_controller.gd`](../../godot/scripts/physical_flight_controller.gd)
owns one pure goal-blind local assistance implementation for every profile.
These are authored game-unit quantities, not SI propulsion constants.
The [4LY contract](../systems/physical-free-flight.md) owns behavior, supported
ordinary-game hosts and evidence boundaries. The table below retains Trainer's
4LY-001 conformance baseline as the schema reference, not as values shared
by the four new candidate plants.

| Profile field | Trainer 4LY-001 baseline | Admitted schema-1 bound or meaning |
|---|---|---|
| `version`, `family`, `topology` | `1`, `4ly`, `single_rectangle` | Exact declared identities |
| `id` | One of the four stable `4ly_*` IDs | `4ly_trainer`, `4ly_hauler`, `4ly_drifter`, `4ly_dart` |
| `action_profile` | `4ly_velocity_v1` | Exactly two normalized desired-velocity components in `move` |
| `fixed_delta` | 1/60 s | Requires the fixed 60 Hz physical cadence within an absolute 1e-9 s tolerance; a different cadence is refused |
| `collider_size` | `[10, 6]` cells | Two numeric dimensions, each 0.5–64 cells |
| `mass` | 1.2 authored mass units | 0.02–20 |
| `inertia` | 13.6 authored mass·cell² | 0.0001–14,000; must equal `mass * (width² + height²) / 12` within the declared numeric tolerance |
| `gravity` | 156 cells/s² downward | 0–500; declared compensation reference, implemented by per-body gravity scale |
| `friction`, `bounce` | 0.82, 0.04 | 0–1 and 0–0.6 respectively; real collider contact material, included in profile identity |
| `desired_speed` | `[48, 36]` cells/s | Each axis 0.1–240; unit-disk `move` is multiplied componentwise |
| `acceleration`, `braking` | 90, 135 cells/s² | Each 0.1–1,200; the opposed-velocity braking component and remaining drive share one normalized effort ellipse |
| `max_force` | 360 authored mass·cell/s² | 0.001–24,000, also at most `mass * 1200`; gravity compensation shares this total cap |
| `velocity_response_seconds` | 0.25 s | 1/600–5; velocity error divided by this time requests acceleration |
| `thrust_response_seconds` | 0.06 s | 1/600–5; first-order response toward already-saturated total force |
| `max_force_slew` | 2,400 force units/s | 0.001–1,000,000; actual force change per step is bounded by this value times `fixed_delta` |
| `linear_drag`, `angular_drag` | 0.05, 0.25 | 0–3 and 0–8 respectively; replace-mode passive Rapier damping |
| `attitude_kp`, `attitude_kd` | 18, 8 | 0–100 and 0–40; upright angular PD request scaled by chassis inertia |
| `max_torque` | 300 authored mass·cell²/s² | 0.001–1,400,000, also at most `inertia * 100` |
| `max_torque_slew` | 3,600 torque units/s | 0.001–10,000,000; actual torque change is bounded each physical step |
| `resource_mode` | `continuous_authored_power` | No fuel timer or reserve drain; explicit host power-off disables both force and torque |
| `calibration` | Profile-specific status above | `conformance_only`, `uncalibrated_placeholder`, `candidate_4ly002` or `measured_4ly002`; candidate status explicitly does **not** establish measured acceptance or learned-policy qualification |

**Authored 4LY-002 candidate values, resolved at the 60 Hz physical cadence**

| Parameter (unit) | Trainer | Hauler | Drifter | Dart |
|---|---:|---:|---:|---:|
| Body rectangle (cells) | 10 × 6 | 16 × 10 | 12 × 7 | 6 × 4 |
| Mass (authored units) | 1.20 | 3.60 | 1.55 | 0.55 |
| Planar inertia (mass·cell²) | 13.600 | 106.800 | 24.929167 | 2.383333 |
| Desired X/Y speed (cells/s) | 48 / 36 | 27 / 23 | 50 / 33 | 84 / 58 |
| Acceleration (cells/s²) | 90 | 38 | 64 | 250 |
| Braking (cells/s²) | 135 | 55 | 48 | 320 |
| Max total thrust (mass·cell/s²) | 360 | 1100 | 460 | 235 |
| Hover force, mass × gravity (force units) | 187.2 | 561.6 | 241.8 | 85.8 |
| Vertical force margin over hover (force units) | 172.8 | 538.4 | 218.2 | 149.2 |
| Velocity response (s) | 0.250 | 0.600 | 0.450 | 0.135 |
| Force response (s) | 0.060 | 0.180 | 0.100 | 0.035 |
| Max force slew (force units/s) | 2400 | 4800 | 2600 | 4600 |
| Passive linear / angular drag (s⁻¹) | 0.05 / 0.25 | 0.035 / 0.30 | 0.012 / 0.27 | 0.09 / 0.32 |
| Upright attitude Kp / Kd | 18 / 8 | 14 / 7 | 20 / 9 | 25 / 9 |
| Max stabilizing torque (mass·cell²/s²) | 300 | 3000 | 470 | 135 |
| Max torque slew (torque units/s) | 3600 | 16000 | 3800 | 2400 |

All four use gravity = **156 cells/s²** (world +y downward), friction
**0.82**, bounce **0.04**, identical `4ly_velocity_v1` command semantics and
`continuous_authored_power`: no fuel or reserve drain. All four have
`calibration = "candidate_4ly002"`. Inertia is computed exactly from the
selected mass and rectangle rather than rounding the input. Higher total
Hauler force largely compensates its higher mass; acceleration, response,
slew, braking and target speed **also** differ. Dart is not merely a
lighter collider, and Drifter retains bounded upright stabilization.

`Profile.descriptor` returns a **copied static `capabilities` subobject**:
collision dimensions, mass/inertia, axis desired-speed limits,
acceleration/braking, force budget, gravity, hover margin, response/slew,
passive drag and attitude authority. It carries no actor-name evaluator label,
world position, privileged goal or reward; the surrounding descriptor retains
the separately declared `id`, `profile_hash` and `controller_hash`.
Dynamic force saturation, propulsion/lease mode, applied assistance and
resource state remain separate observation fields. `profile_hash` is
SHA-256 of validated full-precision resolved profile JSON (sorted keys);
the controller's normalized source SHA-256 is
`fb86190c68c6a87e7d2ef7e845b1fb97305f188723a326f67f07caa6971cc8ae`.
Use actual observation hashes, runtime/physics identities and committed
source SHA in evidence; no static profile name is a compatibility token.

The [prospective thresholds](../../godot/tests/fixtures/4ly002_handling_thresholds.json)
were registered before the four-profile actual-Rapier run. The
[measured envelopes](../audits/2026-10-23-4ly002-measured-handling-qualification.md)
**passed** on Linux and Windows using exactly the source profile hashes published
in that record. The literal `candidate_4ly002` marker **must not be changed**
without new profile hash/plant compatibility qualification. This is a
source-bound measured physical candidate, **not** owner-feel, target-PC,
Web or downstream learning approval. The updated PR head's new visual
capture/test scope remains separately gated; do not silently treat the
earlier implementation-only checks as its final-head tests.

All fields are required. Unknown fields, wrong types, nonfinite numbers,
out-of-range values, inconsistent rectangular inertia and plant-envelope
violations are refused before installation. No implicit clamping resolves an
invalid profile. Resolved numeric values and sorted full-precision JSON define
the profile hash; identity and calibration status participate in that hash even
when numerical dynamics match.

Installation requires a finite positive project default gravity, exactly
downward default gravity direction and a 60 Hz project physics cadence. Both
the default gravity and the resulting per-body scale must remain representable
by the physics backend; otherwise installation is refused before allocation. The
profile supplies the controller's gravity reference; the controller does not
query local gravity areas or change its budget in response to environmental
fields. At fresh-step admission, zero, negative and nonfinite runtime deltas
revoke flight input, as does a positive delta outside the fixed-step tolerance.

Reset/cancellation/power cutoff clears force and torque response immediately;
ordinary enabled slew bounds do not delay revocation.

The no-equipment preparation is explicit (`equipment_preparation = "none"`,
empty loadout, one part and no joints/mounts). Session population/body limits
remain those of the shared physical owner. `Catalog.has_rig`/`entry` recognize
the four IDs, while ordinary `RIG_IDS` remains exactly 46. `SET_IDS` appends `set4LY`
after the original eight sets, exposing the four separate flight choices in
F5; former IDs and set indices (including SetP) retain their meaning.
Wire envelope version 2, one-through-eighteen-tick observation-relative leases
and six-tick demo decisions are retained. The separate profile cadence does not
redefine the legacy physical actor delta clamp above.

## Player playground values

**Current experimental source:** [course](../../godot/scripts/player_playground_course.gd),
[runtime](../../godot/scripts/player_playground_runtime.gd),
[input](../../godot/scripts/player_playground_input.gd),
[vehicle](../../godot/scripts/player_vehicle_controller.gd),
[acrobat](../../godot/scripts/player_acrobat_controller.gd) and
[native field](../../native/include/cybersand/world.hpp) own these values. The
[player guide](../systems/player-control-playground.md) owns controls and scope.

| Value | Current bound or default |
|---|---|
| Scene / presets | `res://player_playground.tscn`; seven, of which five mechanical entries also form F5 SetP; dry/liquid remain scene-only |
| Native world / course view | 1024 × 1024 cells; `Rect2i(128,128,512,256)` course view; follow view 256 × 128 |
| Local owner | One native worker, synchronous calls, simulation window and cadence LOD disabled for the dedicated course |
| Material seed | 16 × 16 = 256 cells centred near (178,304); Sand count 256 or full Water mass 65,280 at construction |
| Human material lease | 1–6 ticks from issued observation; seven issuance-history slots; sequence 0–9,007,199,254,740,991 and strictly increasing |
| Gamepad | First connected pad; left-stick radial deadzone 0.18; combined movement length capped at one |
| Field source scan | Fixed radius 32; 65 × 65 = 4,225 attempted positions per call, circle and domain filtered |
| Field source budget | At most 512 original parcels; phase-rotated scan then deterministic priority order; `truncated` if more observed |
| Field movement | At most four axis-adjacent steps per parcel, 2,048 attempts total; outer write reach at most radius 36, clipped to domain |
| Field storage | No missing chunk or thermal-storage allocation; unavailable storage refuses the step and increments its receipt counter |
| Field input | Finite direction components in −1..1 and squared length ≤1.000001; Sand/Water only; mode 0–3; phase 0–2,147,483,647 |
| Native C++ domain | Each span 1–4,096; origin in ±1,000,000,000; centre inside domain; Godot adapter fixes domain to 0..1,023 on each axis |
| Material centre following | At most four cells per owner step toward observed quantity-weighted centroid |
| Vehicle hop | Buggy requires support; bike preload reaches full at 0.42 s and requires supported release; 0.5 s hop cooldown |
| Acrobat jump timing | 0.11 s coyote; 0.14 s buffer; 0.05 s confirmed support; 0.14 s launch lock |
| Acrobat roll / glide | Roll 0.28 s; cooldown 0.32 s; grounded tap at most 0.15 s; glide reserve 1.6 s per confirmed landing |
| Acrobat airborne inventory | One extra jump, one bullet jump and one air roll per confirmed landing; cancel does not reload them |
| Acrobat control delta | At most 96 cells/s requested delta velocity per controller call; physical session's finite delta/impulse bounds still apply |
| Course timing | Four ordered checkpoints, reach radius 15 cells; simulation ticks divided by 60; best times last only for the scene |
| Mechanical course lifetime | Existing physical arena limit 36,000 ticks; restart creates a fresh owner; material lane does not reuse that arena limit |

No field receipt is a persistent parcel inventory. Native temperature/compact
state and partial Water mass survive each relocation, while the following
ordinary material tick retains its normal chemistry/transport semantics. Exact
receipt and admission fields are in
[interfaces](interfaces-and-message-contracts.md#player-material-field-control).

## Initial physical Blacksite trial

The [physical actor programme](../operations/physical-actor-programme.md) owns the reset-scoped barrel/Ripper control bounds, hull sizes, cooldown and desktop-only scope. Existing reference controls and registered definitions retain their defaults.

## Generation Workbench 2 limits

The [workbench owner](../../godot/scripts/worldgen_workbench.gd),
[tool controller](../../godot/scripts/worldgen_workbench_tools.gd),
[preview](../../godot/scripts/worldgen_preview.gd) and native adapter own these
finite authoring limits. They do not enlarge native recipe or live World caps.

| Resource | Bound |
|---|---:|
| Canonical authoring recipe | 1 MiB UTF-8 |
| Edit preparation | One exclusive worker and one newest pending candidate |
| Undo / redo | 16 canonical recipe entries in each direction |
| Preview cache / queue | 32 cached chunks / 24 queued chunks |
| Preview generation slice | 2,048 cells per owner service call |
| Auxiliary seed/comparison requests | At most 4; one active native owner |
| Auxiliary preparation | One exclusive worker; retirement cannot admit stale results |
| Auxiliary rectangle / slice | At most 128 × 128 cells per plane / 256 cells |
| Serialized UI trace | 256 KiB; overflow explicitly reported |
| Semantic comparison records | 4,096; counts cover retained records and truncation is explicit |
| Detailed semantic comparison changes | 64; retained-record counts reported separately |
| Graph canvas | 256 nodes; complete supported recipe remains in JSON |
| Vector arrows | 256 |
| Streamlines | 24 lines, at most 64 integration steps each |
| Native trace collection | 256 entries; omitted count and truncation reported |
| Native stage-region output | At most 256 × 256 cells; pending output remains private |

Grammar and projection sample indices use 64-cell bins. Candidate membership,
container capacity and index construction are charged to the existing prepared
memory/work limits. A conservative maximum local candidate charge bounds each
raster sample. Real geometry/mask checks and canonical ordering still select
materials. Measured index checks and local chunk durations are distinct from
these declared logical charges.
