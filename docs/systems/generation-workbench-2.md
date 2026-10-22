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

**Current implementation, GEN-007 / #193:** the opt-in
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

## Which controls open the tools and retained captures?

Use the page selector at the top of the left sidebar. The controls below are the
labels in the current UI; the linked images are actual Workbench viewports.

| Task | Controls | Retained capture |
|---|---|---|
| Edit a graph | **Graph canvas → Open graph canvas…**. Choose **Typed spatial** or **Scalar fields** and a namespace. Select a node to edit its numeric controls/JSON, then **Validate node**; **New operator → New node draft** starts a new operator. Drag ports to submit a connection. | [Graph canvas](../images/gen007/workbench/workbench-graph-canvas.png) |
| Inspect fields and stages | Select a field in the lower **Inspect** selector. The upper overlay selector offers **Vector arrows** and **Bounded streamlines**. Use **Stage** for applicable native boundaries. | [Vector arrows](../images/gen007/workbench/workbench-vector-arrows.png), [streamlines](../images/gen007/workbench/workbench-streamlines.png), [candidate stage](../images/gen007/workbench/workbench-candidate-stage.png) |
| Inspect semantic planes | Use **Plane → Play / Rear / Atmosphere / Far / Four-plane composite**. These correspond to native `play`, `scripted`, `effects` and `background` data. | [Composite](../images/gen007/workbench/workbench-four-plane-composite.png), [isolated play](../images/gen007/workbench/workbench-isolated-play.png) |
| Inspect or edit hierarchy | **Hierarchy / planes** shows accepted features. Select a feature for its copied record and parent chain; edit rule or plane JSON, then **Validate and apply selected rule** or **Validate and apply plane data**. The overlay selector exposes **Feature bounds / sockets / routes**. | [Hierarchy, sockets and routes](../images/gen007/workbench/workbench-route-socket-hierarchy.png) |
| Explain a cell | Leave the upper **Inspect** toggle on and click a ready cell, or Ctrl-click. Read **Why is this here?** for native replay and the accepted-material comparison. | [Cell provenance](../images/gen007/workbench/workbench-cell-provenance.png) |
| Review density and work | Open **Quality / comparisons** for counts; choose **Semantic feature density**, **Measured chunk time** or **Charged logical work** in the overlay selector. | [Density](../images/gen007/workbench/workbench-feature-density.png), [measured time](../images/gen007/workbench/workbench-measured-chunk-time.png), [charged work](../images/gen007/workbench/workbench-logical-work.png) |
| Browse seeds or compare edits | In **Quality / comparisons**, enter up to four seeds and select **Generate seed cards**. For a comparison, **Pin current recipe and view**, make an accepted edit, then **Compare pinned / accepted**. | [Seed cards](../images/gen007/workbench/workbench-seed-browser.png), [before/after](../images/gen007/workbench/workbench-before-after.png) |

Right/middle drag pans; the wheel or **− / +** zooms. **Origin → Go** and **Home**
set the viewport location. Turn **Inspect** off to draw with **Brushes / contextual
sculpt**. The header supplies **Undo**, **Redo** and **Cancel edit**;
**Cancel auxiliary jobs** in **Quality / comparisons** retires seed/compare work.

The [18-capture manifest](../images/gen007/workbench/workbench-render-evidence.json)
and [display test](../../godot/tests/test_gen007_workbench_render.gd) bind these
feature cases to bounded GEN-003/004/005 data: the
[typed vector utilities](../../examples/worldgen/typed-vector-utilities.json) and
[semantic refinery](../../examples/worldgen/semantic-refinery.json), with deliberate
local changes for the comparison. They do not depict the complete qualification
recipe. To load that recipe, use **Graph canvas → Load GEN-007 Deepworks recipe**.
The additional [qualification viewport](../images/gen007/workbench/workbench-qualification-viewport.png)
shows the actual final, 61,845-byte
[GEN-007 recipe](../../examples/worldgen/gen007-deepworks.json), at seed `19337`
after rapid replacement. It shows a bounded current viewport of the 1024 × 1024
place; the separate qualification scene owns full-region visual acceptance.

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

### What responsiveness was measured?

The 2026-10-21 [latency receipt](../audits/gen007/workbench-latency.json) measures
the actual final qualification recipe in an open Workbench. The
[portable probe](../audits/gen007/workbench-latency-probe.gd) retains the same
frame/service measurement loop. **Committing accepted content still caused a
108–129 ms main-thread service call, with a worst observed frame gap of 166.333 ms.**
The sub-millisecond native adoption time alone does not describe that UI hitch.
The separate RSS verification below increased the observed maxima to
**136.857 ms for the complete UI service call and 170.958 ms for a frame gap**.

| Operation | Observed local result |
|---|---|
| Prepare and accept seed `19301` | Submission 2.403 ms; private preparation 2,456.247 ms; native adoption 0.562 ms. Complete commit/UI service 108.158 ms; largest frame gap 152.194 ms. The previous accepted cache remained intact until commit. |
| Cancel a running full-recipe candidate | Cancel call 0.025 ms; the private worker took a further 2,536.583 ms to quiesce. Accepted recipe identity and preview remained intact. Cancellation retires publication immediately; it does not synchronously stop the worker. |
| Replace a pending edit with seed `19337` | Two submission calls totalled 3.260 ms; the newest candidate was accepted after 4,861.329 ms, including retired work. Complete commit/UI service 128.995 ms; largest frame gap 166.333 ms. |
| Complete the first four-plane viewport | A 256 × 192 view used twelve 64 × 64 chunks and retained 196,608 material bytes. Completion took 1,127.129 ms; native generation calls totalled 54.382 ms. Largest preview service call 18.883 ms; largest frame gap 61.819 ms. |

The receipt includes min/median/95th-percentile/maximum frame and service times,
including the frame after each final service call. It records exact recipe,
runtime and editor input hashes. This isolated Linux run used Godot 4.7, X11 and
llvmpipe on an AMD EPYC 9V74, with `LIBGL_ALWAYS_SOFTWARE=1`, `LP_NUM_THREADS=2`
and `GALLIVM_PERF=nopt`. XDG directories were fresh; the starter 128 × 128 view
and 20 rendered frames were warmed before measurement. Operating-system file
caches were uncontrolled, and this original run imposed no explicit memory
limit. These are local interaction measurements, not cold-start, target-hardware
frame-rate or full-map rendering guarantees. The [dated ledger](../audits/2026-10-21-gen007-workbench-qualification.md)
owns the publication/source binding and remaining platform evidence.

#### Separate process-memory verification

A second isolated run of the portable probe on source
`2f7f65bf6e80c7258f2bdda19f949760d211b59e` retained a
[memory receipt](../audits/gen007/workbench-memory.json) and its own
[timing receipt](../audits/gen007/workbench-rss-latency.json). Godot's peak resident
memory was **405,815,296 bytes (387.016 MiB)**, below the 4 GiB comparison bound.
The [Python wrapper](../audits/gen007/workbench-memory-wrapper.py) used Linux
`resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` after its sole Godot child exited.
This measures that process's high-water RSS; Xvfb and the parent Python process
are excluded. It imposed no additional RLIMIT or cgroup memory limit.

Both the process and the probe completed successfully. This run retained the
same final recipe/runtime bytes and canonical renderer flags, with fresh XDG
paths and the same starter-view warmup. Private preparation took 2,472.113 ms;
cancellation returned in 0.024 ms while retaining the accepted state. The rapid
replacement's **136.857 ms UI service and 170.958 ms frame gap** are larger than
the original receipt and remain part of the evidence. The original latency JSON
is unchanged; the portable probe changes output-path selection and self-hashing,
with the measurement loop preserved.

The memory receipt contains the exact tested Godot child command, environment,
180-second timeout and artifact hashes. To reproduce the workload, use the
recorded native/editor input bytes and run from the repository root. Set
`GEN007_GODOT` to the pinned Godot executable and `GEN007_OUTPUT_DIR` to an output
directory. The command below records the actual checkout revision; the resulting
runtime/input hashes identify a new measurement, even when the implementation
bytes match the retained run.

```sh
GEN007_XDG_ROOT="$(mktemp -d)"
LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 GALLIVM_PERF=nopt \
XDG_DATA_HOME="$GEN007_XDG_ROOT/data" XDG_CONFIG_HOME="$GEN007_XDG_ROOT/config" \
XDG_CACHE_HOME="$GEN007_XDG_ROOT/cache" \
xvfb-run -a -s '-screen 0 1920x1200x24' \
python3 docs/audits/gen007/workbench-memory-wrapper.py \
  --godot "$GEN007_GODOT" --project godot \
  --probe docs/audits/gen007/workbench-latency-probe.gd \
  --output-dir "$GEN007_OUTPUT_DIR" \
  --source "$(git rev-parse HEAD)"
```

The tested portable probe SHA256 is
`3a533ca91170766bfe2b1f1ab4e62c4314a18eb7e41f485a92f52fcddc61b3a3`;
the wrapper SHA256 is
`4272ea6b86fe7f4f4be21f09db853e2ff598e22700fe7db9d08788d6bdd71165`.
The probe also accepts an absolute report path through `--output=…` after Godot's
`--` separator, or `CYBERSAND_WORKBENCH_EVIDENCE_OUTPUT`.

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
