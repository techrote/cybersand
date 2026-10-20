---
title: Polished map production workflow for agents
status: Current
document-kind: guide
scope: Recommended end-to-end map workflow; inspected main fc015a7 contracts remain authoritative for that baseline, with Deepworks 7590316 as a separately pinned worked example
canonical-for: [map-production-workflow, polished-map-agent-guide]
last-reviewed: 2026-10-20
related-documents: [map-exhibition-design.md, map-layer-polish-and-validation.md, documentation-maintenance.md, local-build-and-validation.md, source-checkpoint-and-recovery.md, ../systems/building-material-catalogue.md, ../systems/depth-layers-and-parallax.md]
---

# Polished map production workflow for agents

Use this guide when asked to create a detailed authored map with themed districts,
native material exhibits, scripted sources and complete depth coverage. It owns
the **recommended production process**, from intake to a reviewable PR. The
[exhibit playbook](map-exhibition-design.md) owns apparatus design and native
reaction proof; the [layer and polish playbook](map-layer-polish-and-validation.md)
owns visual composition and actual-renderer acceptance. Material semantics,
engine ownership, capacities and release policy retain their canonical homes.
The [guide review](../audits/2026-10-20-map-production-guide.md) records this
documentation package's source and retrieval scope.

For a complete map, inspect the actual checkout, runtime and material rules;
turn the brief into total dimensions, district purposes, layer roles and
acceptance criteria; finish one working district; then expand the connected
composition within its budgets. Add detail after the native apparatus and
viewing apertures work. Verify the final map with separate native, controller
and actual-renderer gates.

The final handoff includes launch/inspection instructions, layer clocks and
reset/replay behavior, a district/exhibit guide, reproducible captures, and dated
source/runtime/recipe identities with materialized runtime/tool hashes, commands,
timeouts, results and remaining limits. Update canonical documentation and
retrieval routes together while preserving frozen questions and historical
evidence. Review the final diff before committing. A review-ready PR
is an open review state: record the exact published head and applicable hosted
checks, distinguish skipped or stale jobs from completed execution, and state
merge and platform acceptance separately. The
[packaging procedure](#package-the-map-as-a-retrievable-reviewable-checkpoint)
and [handoff worksheet](#completion-and-handoff-worksheet) give the full checklist.

**Source scope, reviewed 2026-10-20:** this guide was written against accepted
main `fc015a77d3b851fef4ea7734923bcdb3762a19a5`. Deepworks
[PR #185](https://github.com/techrote/cybersand/pull/185) was open at review;
its worked example is pinned to
[`7590316e01f0b6efbcc11598fc454656f38f8558`](https://github.com/techrote/cybersand/commit/7590316e01f0b6efbcc11598fc454656f38f8558).
The guide does not make that branch's additions available on an older checkout.
Inspect the actual source before reusing a class, command or numeric limit.
Future integration changes availability; it does not change what the pinned
example's evidence proves.

## Start with the checkout and material rules

Read [AGENTS.md](../../AGENTS.md), the [handover](cybersand-codex-development-handover.md),
[roadmap](../reference/status-and-roadmap.md) and
[source checkpoint guide](source-checkpoint-and-recovery.md). Inspect the actual
Git root, HEAD, branch, status, remotes and dependency locks. Preserve unrelated
edits; use an isolated branch or worktree when another map is already in progress.
Record the source revision and any relevant working-tree delta before testing.
A source checkout, the companion workspace and a retained runtime are different
inputs.

Read requested material changes **before selecting exhibits or painting the
architecture**. Start with the [building material catalogue](../systems/building-material-catalogue.md),
[native material kernels](../systems/materials-and-rule-kernels.md),
[intermaterial interaction contract](../systems/intermaterial-interactions.md)
and [appearance contract](../systems/material-appearance-and-rendering.md).
Follow each important behavior to the native source and its tests. A metal-like
finish, a new material name or a colored screenshot is not evidence of
conductivity, resistance or a particular chemical reaction.

For every reference, extract a reusable design decision and retain its scope:

| Reference | What to study | What to establish separately for a new map |
|---|---|---|
| [PR #179, MAT-002](https://github.com/techrote/cybersand/pull/179) and the current [building catalogue](../systems/building-material-catalogue.md) | New building IDs, actual reaction partners/products, material finishes and source-matched runtime evidence | Which materials exist and behave as expected in the selected checkout/runtime |
| [PR #167, Neon Reliquary descent](https://github.com/techrote/cybersand/pull/167) and its [scene guide](neon-reliquary-demo.md) | Distinct themes, monumental silhouettes, inhabited details and composed close views | The new map's topology and persistence; the four reference districts are separately loaded scenes |
| [PR #175, Blacksite Nine](https://github.com/techrote/cybersand/pull/175) and its [connected-complex guide](blacksite-nine-demo.md) | A continuous district grid, reciprocal passages and camera changes preserving one world | Traversability with the actual intended actor and the new map's material state |
| [PR #184, Grey Area 51](https://github.com/techrote/cybersand/pull/184), pinned [guide](https://github.com/techrote/cybersand/blob/1a84e87d22d490f17d79e50b538e62fc4ede0dff/docs/operations/grey-area-51-demo.md) | Concrete massing, cramped routes, inspection slots and small machinery details | Availability of that branch and the new host's input, rendering and actor integration |
| [Strata Theatre contract](../systems/depth-layers-and-parallax.md) | Four native planes, independent rates, relief, parallax and immutable render publications | Authored dimensions, full-map camera support and whether proposed sources fit the host |
| [Pinned Deepworks guide](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/operations/deepworks-exhibition.md) and [audit](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/audits/2026-10-20-deepworks-exhibition.md) | A complete 1024-square composition, paired exhibits, four-plane coverage and failure-driven polish | Applicability of its implementation, budgets, tests and Linux rendering evidence |

**Exit criterion:** a short reference/material worksheet identifies source
versions, supported mechanisms, selected host, known limits and the visual
qualities to carry forward. Resolve contradictions through source and retained
evidence before building around an assumption.

## Turn the request into a measurable map brief

Translate adjectives into artifacts that can be inspected. “Lots of detail”
needs both a large-scale composition and meaningful close-up details. “Full
multilayer coverage” needs a deliberate contribution from every required plane
in every area. “Chemical showcase” needs native products or mechanism-specific
motion, not just attractive starting materials.

Use the following worksheet as authoring notes; it is not an engine schema:

| Brief field | Record before expanding the map |
|---|---|
| Total extent | Exact world width/height in native cells, district bounds and border policy |
| Continuity | One connected world or separately loaded scenes; camera-only navigation versus installation/reset |
| Player role | Free-camera exhibition, sampled-player traversal or physical-actor exploration |
| Theme | Overall setting, district stories, dominant silhouettes, palette relationships and quiet spaces |
| Required layers | Meaning of foreground, active rear, atmosphere and frozen far scenery; owners and clocks |
| Exhibits | Mechanism, reagents, product/motion witness, contact geometry, containment and timing |
| Coverage | District-by-layer table, aperture locations, connecting routes and source/drain placement |
| Limits | Current constructor/event/upload/step capacities and planned headroom |
| Interaction | Initial state, run/pause/step, reset scope, camera, layer visibility, inspection and return path |
| Acceptance | Native, controller, actual-pixel and human visual checks; target platforms and evidence gaps |
| Handoff | Launch route, replay instructions, captures, guide, audit, recoverable commit and PR |

For the **pinned Deepworks example**, 1024 × 1024 is the total XY footprint.
Sixteen 256-square districts form a 4 × 4 grid. Its four separate native planes
overlap those same coordinates; they do not enlarge the map into four adjacent
worlds. Every district has a foreground apparatus, a rear apparatus, atmosphere
and distant architecture. Those are example design choices, not a requirement
that every future map contain sixteen districts or use the same rates.
See the pinned [map composer](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_map.gd)
and [district/exhibit table](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/operations/deepworks-exhibition.md#districts-and-their-paired-exhibits).

Plan a district as a readable local story: what was built here, which process
the apparatus demonstrates, how its geometry makes that process visible, and
which small objects suggest use or decay. Vary the silhouette and spatial
rhythm as well as the material palette. Reserve empty viewing space while
planning the structure; inserting it after every wall is decorated is expensive.

**Exit criterion:** all required areas have an explicit row in the coverage
matrix, all connections have endpoints, and every promised interaction has a
proposed native witness. Unknowns become small investigations before expansion.

## Choose the host and make one complete district

### Verify capabilities before extending dimensions or ownership

**Current at the guide's main baseline:** Strata Theatre's
[depth runtime and compositor](../systems/depth-layers-and-parallax.md)
share a 640 × 360 authored ROI over 1024 × 1024 native backing. Allocated backing
does not prove that authoring, interest, camera transforms, publication and
rendering all support a full 1024-square map.

**Pinned Deepworks addition:** PR #185 parameterizes the shared depth path and
adds its own exhibition runtime and full-map host. Inspect its
[depth contract](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/systems/depth-layers-and-parallax.md),
[configuration](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/reference/configuration-reference.md#depth-host-and-deepworks-configuration)
and [dimension tests](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_depth_dimensions.gd)
before using those additions. On a checkout without them, first implement and
validate the required capability or select an already capable host. Changing
one size constant is insufficient.

Preserve [native ownership and immutable publication](../architecture/data-ownership-and-lifetimes.md).
The dedicated four-world lab serializes calls through its exclusive owner;
ordinary desktop gameplay has a different asynchronous owner. Do not attach a
second writer to a live play world. Apparent depth introduces no automatic
cross-plane mass, collisions or chemistry. The frozen `background` plane is
static architecture. A request for “background reactions” can be realized on an
active rear plane, with that mapping stated explicitly in the brief and controls.

### Finish a representative vertical slice

Select one district that exercises the difficult requirements: architecture,
foreground chemistry, visible rear chemistry, atmosphere, far scenery, a
connection and useful inspection controls. Build and run all of them together
before copying the pattern across the map.

Separate responsibilities in the authoring code:

| Responsibility | Output and boundary |
|---|---|
| Architecture | Deterministic bounded shapes, district silhouettes, apertures, route reservations and finishes |
| Apparatus | Specimens, contact surfaces, reagents, sources/drains and expected native mechanisms |
| Composition | Final ordered per-plane recipe, dimensions, identities, budgets and coverage summary |
| Runtime | Validated installation, exclusive native stepping, event schedule, reset and fault outcomes |
| Host | Camera, inspection UI, painting, input ownership, layer presentation and launcher lifecycle |
| Tests/capture | Calls the real composer and production runtime; records native observations and actual rendered output |

This is the division used by the pinned
[Deepworks source directory](https://github.com/techrote/cybersand/tree/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition).
Reuse the existing repository interfaces where they fit; a new framework is not
a prerequisite for every content map. Check the
[shared MicroScenario contract](microscenarios.md) before selecting it. A larger
exhibition programme must not silently bypass that schema's admission limits.

**Exit criterion:** the slice can be installed, run, paused, inspected, reset and
rendered with every required plane visible. Its reaction witness comes from the
real native owner. Resolve the slice's failure modes before multiplying them.

## Expand a connected map without losing the layer plan

Use local district coordinates and one explicit origin transform. Clip geometry
to the declared district/world bounds. Keep apertures and routes named, with
tests that evaluate the final native composition rather than only the planned
rectangle list. Overpaint order can close a route that was clear in an earlier
builder.

A useful construction order is broad masses, large voids, hero structures,
apparatus, secondary architecture, small details, then authoritative final
carving of reserved routes/apertures. The exact order belongs to the recipe:
ensure the final carve does not erase vessels, source contact or story details.
The pinned [Deepworks architecture](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_architecture.gd)
and [composer](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_map.gd)
show district clipping and final corridor carving.

Review the complete layer matrix after each expansion:

- Foreground frames the apparatus and leaves intentional windows onto depth.
- Active rear has its own machinery, native materials and visible reaction area.
- Atmosphere has a source, a visible travel path and bounded cleanup appropriate
  to the selected material; a hidden emitter is unfinished coverage.
- Far scenery has a composed silhouette and quiet contrast behind each area.
  Full coverage includes intentional empty cells, not a requirement to fill
  every cell with solid material.

For a traversable map, prove reciprocal openings and the actual intended actor's
passage through the composed geometry. Camera access and a connected empty-cell
graph do not establish actor traversal. For a free-camera exhibition, test the
promised camera and material connections and keep actor traversal outside the
completion claim. The [Blacksite guide](blacksite-nine-demo.md) documents a
traversal example; pinned Deepworks uses the latter exhibition scope.

Track both record count and cumulative authored cell writes, including repeated
overdraw, for every layer. Track source work separately from initialization.
Choose practical headroom below the real limits; do not enlarge shared limits
merely to fit decorative repetition without investigating the cost. The
[capacity guide](configuration-and-capacity-budgets.md) owns bounded-work policy;
the [configuration reference](../reference/configuration-reference.md) owns
current constants.

**Exit criterion:** the full extent, district identities, connectivity,
layer coverage and budgets pass on the composed map before the final detail pass.

## Build bounded programmes and predictable controls

Use the [exhibit playbook](map-exhibition-design.md) to develop each reagent
programme and its native oracle. Scripts supply reactants before the intended
native tick; native rules produce the advertised chemical results. For finite
exhibits, stop feeds so the resulting state remains inspectable. Repeating
environmental sources need local cleanup that cannot erase unrelated specimens.

Validate the complete candidate definition before replacing a working map:
known material IDs, exact layer IDs, coordinates, scalar overflow, finite values,
rectangles, schedule ranges, total work and frozen-layer restrictions. Reject an
invalid candidate without leaving a partially installed scene. When a runtime
or publication fails, preserve the failure outcome and stop affected activity;
a later success message must not conceal an unsuccessful reset or upload.
These are recommended design checks; the pinned
[Deepworks runtime](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_runtime.gd)
is a concrete bounded implementation.

Make time semantics explicit. Each active plane has its own native tick counter
and configured rate. Pausing or hiding a layer need not mean the same thing.
Bound catch-up work and expose dropped time. A tour may move the camera while
all districts continue evolving; a late visitor may see reaction products rather
than the original reagents. Document how to reset and replay that situation.

Define controls in terms of state changes and test the host's actual methods:

| Control or transition | Contract to decide and verify |
|---|---|
| Initial open | Paused or running; initial camera; installed recipe and acknowledged owner |
| Run/pause/step | Which clocks advance; whether manual step advances each active plane once |
| Camera/district selection | Camera movement preserves native state and edits unless installation is explicitly intended |
| Reset | Global or local scope; camera preservation; programmes, queued commands, ticks and old generations retired |
| Layer visibility | Render state versus simulation state; frozen far behavior |
| Paint/erase | Selected plane and inverse rendered transform; admission failure is visible |
| Menu, focus loss and held input | UI owns its gestures; returning to the map waits for required releases |
| Exit and reopen | The prior owner/session is retired and the launcher can open a fresh scene |

Reset generation and publication serial serve different purposes. Guard both
before mutating pixels or admitting delayed commands. Include a valid newer
publication control and an old-generation rejection control; a test that merely
rejects every publication proves little. The
[depth contract](../systems/depth-layers-and-parallax.md) owns the current
publication boundary, and the pinned
[Deepworks controller tests](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks_controller.gd)
show host-level checks.

**Exit criterion:** a reviewer can open, understand, run and replay the map
without knowing its implementation. Controls and on-screen notes match the
actual host, including simultaneous evolution in areas outside the camera.

## Add polish at three viewing scales

Use the [layer and polish playbook](map-layer-polish-and-validation.md) for the
detailed composition pass. Review overview, district and apparatus scales in the
actual renderer, with both clean and HUD-visible views.

At overview scale, check the large silhouette, district rhythm, routes, material
contrast and focal hierarchy. At district scale, verify the story, depth
apertures, machinery, reaction readability and transitions to neighbors. At close
range, add purposeful fixtures such as specimen labels, pipes with brackets,
valves, console faces, shelves, furniture, stained windows, repairs and small
signs of occupation. Repeated decorative motifs should support a theme without
making every room the same.

Keep the reaction's change more legible than its surroundings. A bright
background can hide pale products; transparent/glossy material everywhere can
flatten separation. Use restrained matte masses and localized highlights where
the actual material programme supports them. After a geometry or palette change,
revisit the affected native contacts and rendered layers.

**Exit criterion:** all districts work at the three scales, not just the best
screenshot. Small details survive the supported inspection view, and decoration
does not occlude native products, routes or automatic atmospheric motion.

## Run separate native, controller and rendered gates

Create meaningful tests for the changed risks. Run inexpensive composition and
focused mechanism checks first, then the complete production map and host.
Broaden testing to shared consumers when their behavior changed or a required
gate applies. Avoid repeated broad suites after the relevant uncertainty has
been resolved.

| Gate | Required observation for the claim | Common insufficient substitute |
|---|---|---|
| Definition and geometry | Exact extent, admitted materials, final bounds/connections, layer budgets and invalid-input rejection | Counting builder records before overpaint or checking a thumbnail |
| Native exhibits | Production composer/runtime and actual native ticks; novel products absent from initial/source inputs where applicable, plus consumption, growth or transport witnesses that exclude direct feed contributions | Prepainting products, advancing a surrogate scheduler or counting injected material |
| Full-map interaction | Each district/exhibit observed after complete composition and its relevant schedule | Passing an isolated reaction probe only |
| Host lifecycle | Real launch, camera, pause/step/reset, layer/paint transforms, input release and exit/reopen | Testing helper functions without the installed host |
| Actual pixels | GUI-capable renderer; viewport/camera state recorded; layer differences and source-local dynamic material visible | Headless skip, populated RG8 storage, static walls or an occluded layer |
| Human visual review | Overview, every district, close-up and evolved states checked for clarity and intended theme | Attractive initial overview alone |
| Repository and release | Documentation, current provenance, historical integrity and applicable exact-head hosted jobs | Exit zero with errors, stale runtime evidence or skipped jobs counted as passes |

The [build guide](local-build-and-validation.md) owns pinned tools and commands.
Do not copy a machine-local executable path from an old audit. Before native
execution, verify the selected runtime payloads and source provenance; an LFS
pointer is not a usable library. Before pixel tests, establish a real display,
writable task-specific Godot data/cache paths and suitable audio/render drivers.
Record software versus hardware rendering explicitly.

For the **pinned Deepworks example**, the executable entry points are
[`test_deepworks.gd`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks.gd),
[`test_deepworks_reactions.gd`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks_reactions.gd),
[`test_deepworks_controller.gd`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks_controller.gd)
and [`test_deepworks_render.gd`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks_render.gd).
Its [pinned build section](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/operations/local-build-and-validation.md#deepworks-and-depth-dimensions)
specifies the full commands and environment. These files do not exist on the
guide's older main baseline; select tests from the actual implementation branch.

Retain failed attempts with their cause and correction. An environment failure
does not establish a product defect or a product pass. A renderer that reports
errors and exits zero is not accepted evidence. Use realistic bounded timeouts,
record cold compilation costs and avoid turning a missing display into a
successful visual result.

The pinned [Deepworks audit](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/audits/2026-10-20-deepworks-exhibition.md)
records why this separation mattered: a heat source missed settled Brine,
foreground geometry hid atmospheric sources, and HUD layout covered the map
despite a misleading headless check. Native measurements, actual pixels and
visual review exposed different defects.

**Exit criterion:** each promised behavior has source-matched evidence and a
stated platform scope. Distinguish compile, runtime, native behavior, real
rendering, browser execution and user acceptance. Linux software OpenGL cannot
establish Windows execution, hardware-GPU performance or actor traversal.

## Package the map as a retrievable, reviewable checkpoint

Follow the [documentation-update checklist](documentation-maintenance.md#documentation-update-checklist).
Publish a concise scene guide with launch instructions, district/exhibit map,
controls, layer/time/reset semantics, limits and reproduction commands. Keep
the dated validation record separate from the current guide.

A useful evidence record includes:

- Exact source HEAD plus a manifest of any tested local delta, recipe identity
  and a recoverable checkpoint.
- OS/architecture, Godot/native/Rapier identities as applicable, relevant hashes,
  worker/profile configuration, display/render/audio environment and input files.
- Executed command, timeout, elapsed time, exit/error status, actual assertions
  and compared state or pixel regions.
- Before/after images and source tick/generation/camera identities, with failures,
  fixes, remaining gaps and each platform's actual execution scope.

Capture from the real scene and retain an atlas, district views, useful
apparatus close-ups, layer contributions and evolved reactions. State simulation
dimensions separately from image resolution. If district images are claimed to
be exact atlas crops, verify decoded pixels and dimensions; file naming alone
does not prove that relationship. The pinned
[`capture_deepworks.gd`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tools/capture_deepworks.gd)
and [capture manifest](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/images/deepworks/capture-manifest.json)
illustrate a reproducible engine capture.

Map changed behavior to canonical subsystem, ownership/lifetime, interfaces,
invariants, configuration, build/tests, roadmap and user-control documentation.
Update applicable owners; record why the others are unaffected. Add focused
frontmatter and unique canonical topics, register the guide in
[`retrieval-corpus.json`](../reference/retrieval-corpus.json), and route it from
the documentation/retrieval indexes. Link version-specific examples immutably
when their files are absent from the target branch.

Add natural supplementary questions for new retrieval needs while preserving
the frozen set. Keep claim status and source/platform qualifiers in retrieved
sections. Review the actual top-ranked chunks for enough information to answer,
including what remains unimplemented or untested; a keyword hit can be incomplete.
Keep important source links inline beside their claims: the repository's
[`heading chunker`](../../tools/docs/retrieval_eval.py) does not automatically
carry end-of-document reference-link definitions into every retrieved section.
Run from the source root, substituting task-specific local output paths:

```text
python3 tools/ci/check_docs.py
python3 tools/ci/check_repository.py
python3 tools/ci/check_m11_consistency.py
python3 tools/docs/retrieval_eval.py --output <frozen-report.json>
python3 tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output <challenge-report.json>
git diff --check
```

The [documentation contract](documentation-maintenance.md#checks-and-evaluation-interpretation)
explains these gates. Frozen questions can also depend on companion-workspace
inputs. If a question references a missing companion file, restore the identified input or
report the missing-input failure; do not rewrite the question/checker to obtain
a pass. Report frozen, pre-existing supplementary and new questions separately.
The evaluator is a deterministic lexical baseline, not a deployed vector-RAG
or unseen-question accuracy measurement.

Review the diff for unintended imports, generated caches, toolchains, runtime
changes and unrelated work. Commit the authorized scope and publish the PR under
the [repository release policy](github-development-and-release.md). Use a draft
during implementation iteration; record required exact-head checks before any
merge. A requested PR does not itself request a merge.

Verify the published commit/tree, changed files and PR base. If an approved
publication mechanism changes commit metadata, establish file identity through
matching Git trees/blobs before carrying local evidence across. Record hosted
results against the exact remote head; keep running, skipped and failed jobs
distinct from passes. A final documentation-only change can have different
applicable jobs from a runtime implementation change.

**Exit criterion:** the reviewer can open the map, replay its exhibits, inspect
the evidence and find the canonical docs without relying on the author's chat
history. The PR explains the concrete problem, changes, resulting behavior,
verification and remaining acceptance limits.

## Completion and handoff worksheet

Copy and fill this worksheet in the new map's own guide/audit. Empty fields are
unfinished work or explicitly documented gaps, not implicit passes.

```text
Map title and brief:
Source checkout / baseline / branch / tested delta:
Total native XY size and district layout:
Selected host and capability prerequisites:
Layer owners / active rates / frozen layer:
District-layer coverage and native exhibit table:
Construction / schedule / per-tick work budgets:
Launch / inspect / run / step / reset / return:
Composition, native, controller and rendered evidence:
Atlas, district, close-up, layer and evolved captures:
Failures corrected and remaining platform/performance gaps:
Canonical guides, updated routes and retrieval results:
Recoverable local checkpoint / published head and tree:
PR URL and applicable exact-head hosted check status:
Next action, if any, and its acceptance criterion:
```

For a continuing agent, give the repository/branch, guide links, tested identities
and a concrete next gate. Example task wording:

> Continue the authored exhibition map using the map production workflow,
> exhibit-design playbook and layer/polish playbook. Read the current checkout's
> material and ownership contracts first. Preserve the recorded total extent,
> native mechanisms and layer roles. Resume from the latest evidence checkpoint,
> resolve the named failing gate, update affected docs and publish the authorized
> review checkpoint with exact source/artifact/platform scope.

Reuse the process and evidence discipline; choose the district count, palette,
mechanisms, source timing and performance targets for the actual request.
