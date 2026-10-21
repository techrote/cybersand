---
title: Generation Workbench 2 inspection and transactional authoring
status: Current
document-kind: contract
scope: GEN-007 native provenance replay, genuine intermediate stages, visual authoring, bounded previews and revision-safe history
canonical-for: [generation-workbench-inspection, generation-workbench-transactions, generation-workbench-visual-tools]
keywords: [GEN-007, why is this here, workbench, graph, undo, redo, provenance, stages, seeds, comparison]
last-reviewed: 2026-10-21
related-documents: [procedural-world-generation.md, procedural-generation-fields-and-modifiers.md, procedural-typed-spatial-fields.md, procedural-hierarchical-generation.md, procedural-semantic-planes.md, ../operations/procedural-qualification.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../audits/2026-10-21-gen007-workbench-qualification.md]
---

# Generation Workbench 2 inspection and transactional authoring

## What is the current scope?

**Current implementation candidate, GEN-007 / #193:** the opt-in
[workbench](../../godot/scripts/worldgen_workbench.gd) edits the same native
GEN-001/002/003/004/005 recipe consumed by production generation APIs. Its
[tool controller](../../godot/scripts/worldgen_workbench_tools.gd) supplies the
graph, hierarchy, replay inspector, plane/stage selection, seed cards and
comparison. Its [preview](../../godot/scripts/worldgen_preview.gd) consumes copied
native cells, typed diagnostics and semantic records. No second procedural
algorithm, mutable World access or simulation tick is used to explain a preview.

Launch `res://worldgen_workbench.tscn` from Godot or the existing feature launcher.
The separate [procedural qualification scene](../operations/procedural-qualification.md)
exercises a complete 1024 × 1024 four-plane place. The workbench itself uses a
bounded movable viewport; it does not keep an unlimited world or trace history.
Execution and visual acceptance are recorded in the
[dated ledger](../audits/2026-10-21-gen007-workbench-qualification.md), separately
from source feature availability. Runtime residency and persistence remain GEN-006.

## Why is this cell or feature here?

`CyberWorldGenerator.inspect_generation(position, plane, expected_revision,
expected_fingerprint)` rejects requests that no longer identify its accepted
configuration. It returns **deterministic on-demand replay** from the immutable
accepted generator, not a stored historical execution trace. The result includes
absolute coordinates, plane, recipe/algorithm identity, proposal identity and
the native material. The workbench separately checks available copied preview
material and identifies its receipt. Uncached material is reported as unavailable
for that readback comparison, rather than being invented from its colour.

The native sampler records the initial candidate, initial material/context,
effective parameters, actual scalar and typed field values, masks and exclusions,
context predicate outcomes, ordered modifiers, selection draws and realized
aggregate weights/material. Semantic detail identifies the accepted feature,
ancestry, producing rule, constraints, sockets and routes. Plane replay records
policy, base generator, ordered projections, masks, material contributors,
associated fixture/link metadata and final hard override precedence. Rejected
decisions and unavailable information are explicit.

Trace collections are bounded; `truncated`, `omitted_entries` and the declared
collection limit distinguish incomplete detail from a complete explanation.
`omitted_entries` counts omissions from native per-cell trace collections;
separately bounded semantic metadata also sets `truncated`, without adding those
omissions to that counter. Do not read the counter as a total for every array.
The UI imposes an additional serialized trace limit. Ordinary generation stores
no complete per-cell event log. Replay cannot observe subsequent simulation,
claim that a fixture has already produced its expected products, or recover an
unrecorded historical decision. Fixture expectations and execution receipts have
different owners.

The native implementation lives in
[world_generation.cpp](../../native/src/world_generation.cpp),
[generation_planes.cpp](../../native/src/generation_planes.cpp) and the
[Godot adapter](../../godot/native_extension/cyber_world_generator.hpp).
The public older `inspect_cell` and `inspect_plane_cell` routes remain available;
the unified method adds caller-supplied identity validation.

## What do the generation stages show?

Stage selection captures the actual normal sampler at named boundaries. It does
not delete controls from a recipe and run a different final algorithm.

| Base generation stage | Meaning |
|---|---|
| `candidate` | Initial candidate using initial brush, theme and hard-parameter settings, before modifier guidance. |
| `guided_candidate` | Candidate with effective guidance, parameters and theme choices. |
| `grammar` | Semantic material proposal immediately after grammar, before registered native modules. |
| `modifiers` | Registered native modules and then ordered material modifiers, before structural route clearing. |
| `connectivity` | Material after native route clearance. |
| `final` | Material after final hard overrides. |

Semantic planes additionally expose `policy`, `base`, `projections` and `final`.
A plane that does not consume the base generator cannot claim its unused base
generation stages. Four-plane composite mode selects final material. The stage
selector reports only applicable native stages.

For base chunks, `stage:<name>` diagnostics retain final `cells` separately from
`stage_cells`; the result receipt binds both. For finite plane stages,
`begin_stage_region`, `advance_stage_region` and `cancel_stage_region` return
complete copied results only after bounded work finishes. Their results identify
the selected plane/stage, current adapter revision and plan. Invalid stages,
oversized regions and stale configuration reject without an invented result.

## How do visual authoring and JSON roundtrip?

The graph canvas displays typed spatial nodes and retained scalar fields with
ports, native types/units and declared sampling work. Named subgraphs have their
own selectable namespace. Node parameters and connections are submitted through
the same candidate transaction as other edits; invalid types, dependencies,
cycles or capacity fail native validation. Advanced instance bindings and outputs
remain in the full Spatial JSON editor. Form edits preserve other supported
fields that the selected form does not expose.

The hierarchy tree presents accepted native feature IDs and parent relationships.
Selecting a feature frames its bounds and replays its provenance. Rule editing
changes declarative grammar; plane editing changes policies, projection templates,
fixture schedules and links together. The existing brushes compile gestures into
bounded strokes, exclusions, paths, modifiers, modules or hard material rectangles.
They never paint cached output directly.

The diagnostic selector solos scalar masks and typed fields. False colours are
presentation of returned values, not an alternative source of field values.
Vector arrows and bounded streamlines sample the copied diagnostic grid; missing
samples terminate a line. Feature bounds, socket directions and route overlays
consume the accepted semantic plan. Route colours qualify the native base
generator report; the qualification scene separately checks its final projected
play plane. Neither graph clearance nor a green line proves a particular actor's
gravity/controller traversal.

Feature histograms and density views count actual semantic records. Cost views
separate conservative charged work from measured local chunk generation time.
Inspection `logical_cost` is the normal generation per-cell bound; it excludes
constructing and copying the explanation. Stage `projection_checks` counts
examined spatial-index entries, while prepared `spatial_index` counts describe
the actual bins and candidates. None is a measured replay CPU duration.
The generation-only plane composite combines real plane materials at the same
absolute coordinates. The scene's rendered material compositor owns parallax,
lighting and actual four-plane graphical qualification.

## How do failed edits, undo and redo preserve state?

Interactive edits copy and validate a candidate on one exclusive worker with a
private native adapter. At most one worker and one newest pending candidate exist;
newer requests retire older serials without blocking the preview. The joined
worker transfers its immutable compiled plans through `adopt_configuration`,
which checks the receiving revision and increments its adapter serial. Native
recipe revision and receipts retain their original identity; adoption does not
rewrite them to imitate a new native execution. Scripted `apply_recipe` uses the
same preparation and commit boundary synchronously. A bounded material/plane preflight catches
exhausted generation budgets before the accepted recipe changes. Invalid JSON,
native rejection or an exhausted budget preserves the accepted recipe, preview,
pending preview job and undo/redo stacks. Draft text may remain invalid for correction.
Cancellation invalidates the request immediately; already-running bounded
preparation may finish privately and its result is discarded. Closing the scene
joins its owned workers before releasing them.

Only a successful commit pushes canonical recipe content into bounded history.
Graph, rule, parameter, plane and brush edits all use this boundary. Undo/redo
restores canonical recipe content and deterministic material/semantic output,
while configuration receives a fresh adapter revision and UI session token.
Those fresh identities prevent old asynchronous results from re-entering merely
because the recipe content matches an earlier version.

Recipe acceptance retires old jobs, cache entries, traces and comparison results.
View changes have their own token. Preview admission checks the expected chunk,
extent, revision, fingerprint, plane/stage and copied payload shape. Auxiliary
jobs carry their request serial and recipe session. Cancellation publishes no
partial seed or comparison data. Trace admission checks its captured token again.

These are finite authoring transactions. They do not rebase player edits into
new generation or replace an active gameplay World's ownership contract.

## How do seed and before/after comparisons work?

Seed cards run the same accepted declarative recipe at one to four explicitly
entered portable integer seeds. Each job owns a private native generator and
advances under a cell slice. Results are bounded to a 128 × 128 rectangle per
plane. Cards display the seed, measured preparation/generation time and charged
logical work alongside the four images. The retained result also identifies its
bounds; the cards do not expose a material hash. The browser does not imply
full-map qualification for an untested seed.

Pinning stores a canonical recipe and rectangle. A later comparison uses that
rectangle and the **same current seed for both recipes**, so it isolates recipe
changes. Material differences are exact cell counts/masks. Semantic differences
compare stable IDs and copied records, reporting additions, removals and changed
records. Semantic record admission is bounded to 4,096 records, with explicit
truncation above that limit; addition/removal/change counts cover the retained
records, not an unbounded plan. Detailed change lists have their own smaller
cap, separate from those retained-record counts. Introduced/removed planes
without aligned data are labelled unavailable.

The comparison buffer, seed queue, trace size, graph canvas, preview cache and
streamlines are explicitly bounded by the
[configuration reference](../reference/configuration-reference.md#generation-workbench-2-limits).
Measured timings include the reported local scope and environment. Logical
charges and sampled visual density are not target-hardware performance claims.
