---
title: Semantic four-plane generation and bounded interlayer contracts
status: Current
document-kind: contract
scope: GEN-005 immutable semantic projections, typed links, finite native fixtures and transactional opt-in depth owner
canonical-for: [semantic-plane-generation, semantic-link-classification, generated-fixture-lifecycle]
keywords: [GEN-005, semantic depth, four planes, refinery, flooded cavern, fixture, interlayer, atomic admission, play, scripted, effects, background]
last-reviewed: 2026-10-21
related-documents: [procedural-hierarchical-generation.md, depth-layers-and-parallax.md, ../operations/semantic-depth-authoring.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../reference/invariants.md, ../decisions/ADR-014-semantic-plane-admission.md, ../audits/2026-10-21-gen005-semantic-planes.md]
---

# Semantic four-plane generation and bounded interlayer contracts

## What does GEN-005 implement?

**Current source / [#192](https://github.com/techrote/cybersand/issues/192):**
`PlanePlan` compiles one existing GEN-004 hierarchy into four coherent material
proposals and copied feature, projection, fixture and link records. Its native
API is [generation_planes.hpp](../../native/include/cybersand/generation_planes.hpp);
its compiler is [generation_planes.cpp](../../native/src/generation_planes.cpp).
The optional `semantic_planes` member of a schema-3 recipe has its own schema 1
and algorithm 1. It does not renumber the retained GEN-001/002/003/004 schemas.

A canonical feature owns every projection. The compiler uses the same stable
feature IDs, parent hierarchy, seeds, absolute rectangles, named structural
routes and material intent on all planes. It cannot generate four unrelated
layouts and subsequently label them as one place. The geometry reference in each
projection points to the actual feature or canonical route it sampled.

| Role | Plane | Source and authority |
|---|---|---|
| Play | `play` | Existing generator proposal or authored semantic projections; material collision and admitted actor placements belong to this plane. |
| Rear | `scripted` | Shared shells, service geometry and machinery interiors, plus finite independently clocked native reagents. |
| Atmosphere | `effects` | Explicit empty-space policy, bounded gas/particle projections and finite sources/drains. |
| Far | `background` | Shared silhouettes and architectural masses in a frozen native World. |

The opt-in [semantic depth scene](../../godot/semantic_depth.tscn) and
[owner](../../godot/scripts/depth/semantic_plane_runtime.gd) demonstrate the
contract. The ordinary asynchronous sandbox, material kernels, Rapier backend,
physics clocks and retained depth comparison hosts keep their existing owners.
GEN-006 still owns persistent streaming, eviction and mutation reconciliation.
A finite preview bundle does not provide those mechanisms.

## How are planes projected and rasterized?

A plane policy declares its uncovered material, rate, whether play consumes the
existing generator, and an explanation of intentionally empty space. Only play
may use `base_generator`. A projection template selects an authored grammar rule
or `$region`, chooses a plane, and references `feature` or `routes` geometry.
Feature projections use the canonical rectangle, or an explicitly contained
feature-relative rectangle. Route projections reuse a region's actual passage,
service or liquid polyline and its width; an override must remain bounded.

`fill` paints the selected geometry. `shell` uses explicit wall/interior material
and thickness. `omit` preserves an explicit composition decision and reason.
Material overrides use ordinary valid native IDs; material 10 remains invalid.
Density is a deterministic feature/coordinate mask in absolute world space.
Optional `application` and `exclusion` reference the same immutable GEN-003
graph as `spatial:<expanded.id>`. Only dimensionless normalized or boolean
outputs are admitted; raw scalar, distance, vector and category outputs need an
explicit typed conversion. Effective density is
`density * application * (1 - exclusion)`, with absent masks equal to one/zero.
The shared graph is evaluated once per affected plane and coordinate, charged
to raster work, and its transitive input identity is retained in projection
revisions. Both examples share a weathering field between rear and far geometry.
Ascending priority and stable projection ID determine raster precedence. Final
play hard-material overrides remain final. An authored empty passage projection
can deliberately carve the semantic route through decorative geometry.

Every region needs explicit atmosphere and far-plane projection records, even
when the intended composition is empty. Per-feature omissions are not runtime
permissions. Static appearance is produced by the existing material renderer,
not by generated bitmap textures or a second material catalogue.

Parallax, pan, zoom and visibility live only in `CyberDepthCompositor`. They are
absent from native schema input, seed selection, ownership and hashes. Admission
translates absolute semantic coordinates into the local finite World only once;
all retained IDs and geometry still refer to the absolute plan.

## Which semantic links are allowed?

Every link has a stable ID, adapter/template ID, source and target feature IDs,
planes, classification, permitted effect, bounded target rectangle, material,
parameters, revision and lifecycle. Endpoints must exist and have a non-omitted
projection on the named plane. Target rule selection is local to the source's
canonical region and must resolve unambiguously.

| Family | Classification | Admitted meaning |
|---|---|---|
| `explosion` | Runtime | `play → scripted`, `blast`, Fire, bounded disc inside the declared rear damage zone. |
| `vent` | Static | Play/rear vent or drain corresponds to a named effects source/drain fixture. |
| `vent` | Runtime | `scripted → effects`, `burst`, admitted effects material and bounded disc. |
| `window` | Presentation | `play → background`, `visibility` composition region. No background mutation permission. |
| `pipe` | Static | `play → scripted`, `correspondence` between projections of declared pipe/service geometry. |
| `waterfall` | Static | Play Water source plus a named effects spray source in the target zone. |
| `machinery` | Static | Play material collision/interaction geometry and corresponding rear fixture/shell. |

Static means generation/registration correspondence. Presentation means copied
composition metadata. Runtime means an explicit owner-mediated command route.
Those classes are validated separately; a link cannot gain runtime authority by
changing a label. Unsupported families, reversed routes, arbitrary cross-plane
writes, runtime background writes and mismatched fixture references reject.

The host issues a copied observation for an installed runtime link. A command
must match its bundle/reset generation, link revision, endpoint revisions,
source plane/tick and one-use observation serial. Only the permitted center and
radius may vary, within the registered zone and maximum radius. The existing
owner enqueues and applies the approved blast/burst. Pixel overlap and ordinary
native reactions never issue events. A consumer must explicitly request and
submit an observation; the examples' event controls exercise that path.

## How do finite fixtures own native reactions?

A fixture belongs to one semantic feature and one dynamic plane. Its declaration
names an ordinary material, contained bounds, mode, target clock, first tick,
period, finite positive repeat count and optional cleanup tick. `setup` is once
at tick zero; `source` and `drain` start after installation. A drain writes Empty.
Cleanup must follow the last scheduled application. Expected products are copied
diagnostic expectations; the source programme never paints them.

The refinery and cavern use native Salt/Water fixtures. Rear Water transport and
Brine production are observed after ordinary native ticks; expected Brine is not
an authoring material in those fixtures. Separate Water/spray and vent/drain
programmes demonstrate the other responsibilities. The complete authored set is
accounted by fixture ID and application count. Tests retain controls with
programmes inactive or reaction partners absent, and require every helper/section
to complete; zero exit with a script error is a failure.

The owner retains bounded install, activate, reset and retire receipts for
fixtures and links. An identical validated bundle retry is idempotent: it neither
resets clocks nor duplicates a source or replays setup. A conflicting payload
with the same identity/revision rejects. A deliberate whole-bundle reset creates
a new generation and permits a new setup in those new Worlds. Retirement blocks
future application, invalidates issued link observations and preserves its last
receipt. Completed finite feeds remain spent unless the owner explicitly resets.

Fixture ownership is assigned by the canonical semantic region. The request
tile containing the record's canonical anchor carries its registration ID.
Reordered independently requested tiles therefore produce exactly one union of
registrations without needing the owner chunk to be resident first. The current
host installs complete regions only; per-tile records are data for GEN-007/006,
not authorization for partial live replacement.

## Where is atomic admission enforced?

The native compiler validates the complete bounded plan before returning it.
A `PlaneGenerationJob` privately stages all four material arrays. `advance`
respects its cell slice; Pending, Cancelled and Failed jobs expose no partial
material publication. Ready results bind the plan fingerprint, revision, bounds,
content hashes and registration receipt. Stale or modified native results fail
`accepts`. The adapter copies output and compresses nonempty row runs into
vertically merged local rectangles before handing over a full bundle.

`CyberWorldGenerator.configure` prepares a candidate generator and plane plan
before replacing its previous configuration. The authored plane revision is
separate from the adapter's monotonic request serial, so an identical authored
configuration retains the same semantic bundle identity. Changing configuration
retires pending adapter jobs; a rejected configuration preserves them and the
last valid configuration.

`CyberSemanticPlaneRuntime.install_bundle` validates copied geometry, materials,
metadata, fixtures, links, budgets and any actor proposals before replacement.
The inherited depth owner constructs all four candidate native Worlds privately.
Only a successful complete preparation publishes the new set and its
registries, synchronously at one owner boundary. No renderer can obtain a mixed
feature revision from the middle of that operation. Failed admission retains the
previous Worlds, clocks, publications, registries and generation.

A differing replacement after initial admission needs the expected current
owner generation. The finite retired-revision ledger rejects an old bundle
resubmission. It has an explicit capacity outcome rather than silently evicting
history and reopening a stale-admission path. Existing per-plane packet identity,
monotonic serial, independent clocks, failed-world quarantine and frozen
background caching still apply.

## What remains bounded and what remains separate?

The [configuration reference](../reference/configuration-reference.md#semantic-plane-generation-limits)
owns exact native and adapter/host caps. Limits cover templates, expanded
projections, fixtures, links, semantic preparation, raster logical work,
per-plane cells, copied diagnostics/publication, scheduled cell writes, queued
observations/events and finite lifecycle storage. Native limits and the Godot
owner limits are distinct; passing native compilation does not waive the host's
stricter run-rectangle or metadata capacity.

Preparation and rasterization have no live World pointer, engine clock, Godot
API, actor object or shared mutable RNG. Generation produces value proposals;
existing owners install material and actor data. The background has no runtime
clock, source, drain, actor or event target. No implicit Z physics is introduced.

The examples qualify finite deterministic composition and the actual listed
native reaction mechanisms. Their free camera is not a traversal qualification
for every actor; the retained hierarchy's route profile does not automatically
prove the projected final play layout. Browser execution, target-PC movement
feel, persistent world edits and streaming remain separately qualified work.
Executed source/runtime/platform results are recorded in the
[dated audit](../audits/2026-10-21-gen005-semantic-planes.md), not inferred from
schema or workflow existence.
