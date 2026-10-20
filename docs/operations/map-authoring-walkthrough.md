---
title: Polished map authoring walkthrough for agents
status: Current
document-kind: runbook
scope: Start-to-finish agent workflow for an authored CyberSand map, from brief and material research through connected composition, native multilayer exhibits, visual polish and evidence-backed handoff
canonical-for: [polished-map-authoring-workflow, map-authoring-agent-handoff]
last-reviewed: 2026-10-20
related-documents: [map-authoring-design-and-materials.md, map-authoring-native-layers-and-programmes.md, map-authoring-validation-and-acceptance.md, deepworks-exhibition.md, documentation-maintenance.md, github-development-and-release.md, ../systems/building-material-catalogue.md, ../systems/depth-layers-and-parallax.md]
---

# Polished map authoring walkthrough for agents

Use this runbook when asked to build a detailed showcase, connected district map,
or physics/chemistry exhibition with Deepworks-level polish. It owns the
**authoring sequence and agent handoff**, while the linked chapters own design,
implementation technique and acceptance. Read the sequence once; retrieve the
appropriate chapter while working.

**Current reference:** the completed Deepworks source at
[`4f3685b`](https://github.com/techrote/cybersand/commit/4f3685b71366218e82e7c2188e4ecdf27553f4cf)
and [PR #185](https://github.com/techrote/cybersand/pull/185). Its 1024 × 1024 total
map, sixteen districts, four material planes and 32 exhibits are a worked
configuration, not mandatory dimensions or quotas for every new map. This guide
turns that implementation and its recorded corrections into a **recommended
production method**. It does not claim that every step below was performed in
this exact order during the original work.

Source-backed behavior is labelled Current where a distinction matters. Proposed
design choices and review criteria are recommendations. Runtime claims retain
their dated platform and artifact scope. Refresh the current contracts before
using this guide against a later revision; the
[exhibition guide](deepworks-exhibition.md) remains the owner of Deepworks controls,
district identities and source schedules.

## Contents

1. [Establish the brief and source](#1-establish-the-brief-and-source) — Resolve what is being built and record the actual implementation baseline.
2. [Choose the host and delivery boundary](#2-choose-the-host-and-delivery-boundary) — Select a suitable existing host and define view, actor and platform behavior.
3. [Plan the map before drawing detail](#3-plan-the-map-before-drawing-detail) — Reserve connections, establish a district grammar and budget four-plane coverage.
4. [Read the material catalogue and specify exhibits](#4-read-the-material-catalogue-and-specify-exhibits) — Match material behavior to architecture and make each mechanism observable.
5. [Finish one representative district](#5-finish-one-representative-district) — Prove the complete experience in a small part of the final composition.
6. [Expand the connected composition](#6-expand-the-connected-composition) — Scale the authored grammar without losing continuity or district identity.
7. [Complete depth and bounded programmes](#7-complete-depth-and-bounded-programmes) — Populate every promised plane and control the lifetime of sources and reactions.
8. [Polish views and interaction](#8-polish-views-and-interaction) — Review atlas, district, apparatus and HUD scales through an actual renderer.
9. [Validate behavior and challenge the evidence](#9-validate-behavior-and-challenge-the-evidence) — Prove mechanisms, regression coverage and honest execution.
10. [Publish a reproducible handoff](#10-publish-a-reproducible-handoff) — Bind source, captures, docs and hosted acceptance to one candidate.
11. [Use the agent work packet](#11-use-the-agent-work-packet) — Start or resume work with explicit ownership, decisions and remaining gates.
12. [Recognize the finish line](#12-recognize-the-finish-line) — Decide whether the map meets its brief and explain any remaining limits.

## 1. Establish the brief and source

**Input:** the user's map request, references and repository. **Output:** a short
authoring brief plus a recoverable source checkpoint.

Read [AGENTS.md](../../AGENTS.md), the
[development handover](cybersand-codex-development-handover.md),
[roadmap](../reference/status-and-roadmap.md), the relevant scene guides and
[material catalogue](../systems/building-material-catalogue.md). Inspect the
actual branch, HEAD, local changes, dependency pins and LFS state using the
[source identity](source-checkpoint-and-recovery.md) and
[build](local-build-and-validation.md) procedures. A reference PR, remembered
screenshot or installed DLL alone is not the current source identity.

Write down the few decisions that materially affect construction:

| Brief field | What the agent must make explicit |
|---|---|
| Total extent | Simulation cells across the entire map, district arrangement and intended capture resolution |
| Experience | Free-camera exhibition, traversable level, actor sandbox or another named host |
| Art direction | Mood, density, architectural language, dominant silhouettes, local accents and reference intent |
| Connectivity | Required district connections, shafts, entrances, circulation and any actor-clearance target |
| Layer coverage | What foreground, rear simulation, atmosphere and distant architecture must contain |
| Interaction | Painting, source activation, reset/replay, cameras and actor controls when actually in scope |
| Delivery | Expected files/branch/PR, runtime platforms, captured views and acceptance evidence |

Preserve known user choices. Make reasonable reversible decisions where the brief
allows them; ask only when a missing choice would change the map substantially.
Record assumptions instead of repeatedly stopping for minor decorative choices.

Separate total map dimensions from image resolution immediately. Deepworks'
2048-square atlas renders a 1024-square simulation at two image pixels per cell;
it is not a 2048-square world. Likewise, a matrix of district views need not imply
separate worlds. See [Deepworks](deepworks-exhibition.md) and
[Blacksite Nine](blacksite-nine-demo.md) for the two existing connected examples.

## 2. Choose the host and delivery boundary

**Output:** a file/ownership plan and an explicit state-transition contract.

Choose the smallest existing host that supports the requested experience. The
[Neon Reliquary descent](neon-reliquary-demo.md) uses separate scene definitions;
[Blacksite Nine](blacksite-nine-demo.md) uses one connected native region with
camera changes; [Deepworks](deepworks-exhibition.md) owns a separate four-plane
exhibition. These are different state models. Select deliberately before copying
a controller or adding launcher actions.

For a Deepworks-like map, separate these responsibilities:

| Responsibility | Existing Deepworks reference |
|---|---|
| Titles, district coordinates, final composition and recipe identity | [`deepworks_map.gd`](../../godot/scripts/exhibition/deepworks_map.gd) |
| Structural and decorative rectangles | [`deepworks_architecture.gd`](../../godot/scripts/exhibition/deepworks_architecture.gd) |
| Native apparatus and bounded source definitions | [`deepworks_exhibits.gd`](../../godot/scripts/exhibition/deepworks_exhibits.gd) |
| Validated programme installation and ticking | [`deepworks_runtime.gd`](../../godot/scripts/exhibition/deepworks_runtime.gd) |
| Scene lifecycle, camera, UI, painting and reset | [`deepworks.gd`](../../godot/scripts/exhibition/deepworks.gd) |

Use new scene-specific names and tests when creating another map. The existing
Deepworks scheduler and district indexing have fixed assumptions; copying them
does not create a generic map-registration system. Follow the
[native layers chapter](map-authoring-native-layers-and-programmes.md) for the
actual APIs and boundaries.

Specify whether selecting a district changes only the camera, whether hidden
planes continue ticking, what a reset restores and whether it preserves view
selection. Deepworks starts paused, keeps all districts alive during a camera
tour, and resets all four worlds together. Those are useful reference semantics,
not proof that a new controller already implements them.

An apparently walkable gallery is not actor acceptance. If actors are requested,
include the relevant [physical actor contract](../systems/physical-actor-rigs.md),
coupling ownership and traversal tests in the plan. Deepworks itself provides a
free-camera material exhibition and no ordinary actor session.

## 3. Plan the map before drawing detail

**Output:** district matrix, connection ledger and layer-coverage matrix.

Use the [design and materials chapter](map-authoring-design-and-materials.md)
to establish the major masses, voids, route skeleton and visual rhythm. A useful
district row names its purpose, main silhouette, palette, primary mechanism,
rear mechanism, atmosphere, distant landmark and neighboring passages.

Reserve circulation and exhibit observation space before adding walls or clutter.
For each connection, record both neighboring district IDs, a shared world-space
rectangle and its intended width/height. Deepworks applies its final foreground
passage carve after architecture and apparatus composition in
[`CyberDeepworksMap.build()`](../../godot/scripts/exhibition/deepworks_map.gd).
A decorative doorway on one side of a seam is insufficient.

Plan depth as a district-by-plane matrix. A full-size allocated world containing
one decoration does not establish complete authored coverage. Conversely, open
space is a necessary part of a readable composition. Record the intended view
through each foreground aperture and the rear/far feature it reveals.

**Checkpoint:** inspect a coarse atlas and the connection geometry before
commissioning fine detail. Resolve an unreadable layout or missing route here,
while the cost of moving a room is small.

## 4. Read the material catalogue and specify exhibits

**Output:** a material-role sheet and an exhibit manifest with independent
observation criteria.

Start from [MAT-002 building materials](../systems/building-material-catalogue.md),
[native material rules](../systems/materials-and-rule-kernels.md) and
[interaction semantics](../systems/intermaterial-interactions.md). Then consult
[appearance](../systems/material-appearance-and-rendering.md),
[visual patterns](../systems/material-visual-pattern-library.md) and the
[effects register](../reference/material-effects-register.md) for presentation.
A material's name or color does not prove conductivity, containment, permeability
or a reaction product.

Assign structural roles, reactive specimen roles and aesthetic roles separately.
Deepworks' Copper Choir uses actual Metal for the working electrodes and Brass
for casing. Its corrected rear Stone classifier needs a real open chute because
the native Stone behavior does not supply the assumed sideways movement. Both
examples are documented in the [scene guide](deepworks-exhibition.md) and
[completion audit](../audits/2026-10-20-deepworks-pr185-completion.md).

For every mechanism, record:

- Stable district/plane identity, source and target materials, seed geometry and
  a protected observation region.
- The existing native rule or transport behavior being demonstrated.
- Source timing, quantity bounds, collection space and any cleanup boundary.
- A witness that distinguishes the mechanism from the initial layout: movement
  across a threshold, a new product, charge, consumption, curing or growth.
- How to reset and replay it, and how a deliberately broken setup should fail.

Choose observable, contained demonstrations before complicated sequences. If a
reaction is stochastic or its products are later consumed, observe a bounded
series of samples rather than relying only on the final frame. Keep authored
reactants and measured products distinct. The
[validation chapter](map-authoring-validation-and-acceptance.md) explains these
oracles and negative controls.

## 5. Finish one representative district

**Output:** one district demonstrating the complete production method.

Build the first district in the coordinate system and host intended for the
final map. If using a small standalone fixture to characterize a mechanism,
still integrate that mechanism into a representative full-host district before
copying it everywhere.

Finish its large structure, routes, foreground apparatus, independently working
rear apparatus, atmosphere, distant architecture, camera focus and labels.
Exercise pause, run, whole-map reset, painting and return-to-launcher behavior.
Capture the actual district view and compare its layers individually.

Review this district at four scales: whole-map thumbnail, normal district view,
close apparatus inspection and HUD interaction. Confirm that its visual
foreground opening exposes the rear specimen and that its containing tray lives
in the same native plane as its reactants.

This step discovers expensive mistakes early: the wrong host, a palette that
turns into visual noise, chemistry obscured behind a wall, unbounded feeds, or a
reaction check that never measures transport. Fix the pattern before repetition.

**Checkpoint:** a representative district is ready to expand when it is visually
readable, its intended mechanism passes meaningful checks, and its controls and
reset restore the promised state. A finished screenshot alone does not establish
this milestone.

## 6. Expand the connected composition

**Output:** the complete authored map with a consistent language and distinct
districts.

Reuse a grammar of frames, supports, pipes, observation windows, signs and
containers, then vary scale, wear, materials and function by district. Reuse
source helpers where appropriate; avoid making every room the same repeated box
with a different accent color. The
[design chapter](map-authoring-design-and-materials.md) covers hierarchy,
negative space, deterministic detail and transition zones.

Keep a single integration owner for shared geometry and coordinate conventions.
Independent agents can own bounded district groups or apparatus definitions,
with explicit reserved passages and naming rules. They should return source,
bounds, material choices, witness regions and test results together. Integrate
small batches and inspect a stitched atlas after each batch.

After the full composition is assembled, run structural checks against the
**composed map**, not only each helper's output. Confirm all required districts,
seams, material roles and layer entries; look for later rectangles covering an
earlier aperture or specimen. Preserve the intended composition order and apply
the shared passage policy consistently.

Review neighboring views at their true placement. Similar colors at an edge
can hide a blocked native seam; a connected native seam can still look
accidentally cut through a building. Geometry and visual continuity need
separate evidence.

## 7. Complete depth and bounded programmes

**Output:** full layer coverage and a programme ledger whose cost and lifetime
are understood.

Use the [native layers and programmes chapter](map-authoring-native-layers-and-programmes.md)
with the [depth contract](../systems/depth-layers-and-parallax.md). Work outward
from foreground composition to rear mechanisms, then atmosphere and distant
architecture. Test the actual view transforms and visibility at map edges;
merely allocating four worlds is not a depth review.

Make each feed's lifetime explicit. Deepworks uses independent plane clocks,
finite chemistry supplies, and repeating atmosphere with local cleanup.
A tour changes the view while finite events elsewhere may finish. Design the
replay instructions and observations around that behavior.

Keep work bounded: source areas, event counts, repeat counts, native ticks,
publication and pixel sampling all need deliberate limits. Measure a
representative simultaneous programme, including off-camera districts.
A new map should not inherit Deepworks' rates or counts without checking its own
cost and intended pacing.

Reset must restore the accepted recipe and schedule coherently. Invalid
installation and stale publication must preserve valid current state as
specified by the existing owners. Do not bypass those checks to accommodate
authored geometry.

## 8. Polish views and interaction

**Output:** reviewed rendered views plus a short list of resolved visual and
interaction defects.

Make separate passes for silhouette and composition, material readability,
local detail, depth separation, atmosphere and interaction. Inspect the actual
render after each meaningful pass. Compare like-for-like views with known
camera, viewport, time and layer settings.

At atlas scale, ask whether major regions and route structure are legible.
At district scale, ask whether the main apparatus is obvious and details imply
use and history. At apparatus scale, ask whether reactants, contact and products
remain visible. At HUD scale, ask whether instructions, selectors and painting
controls are readable without covering the specimen.

Use foreground apertures, selective contrast, quieter distant massing and
localized atmospheric motion to preserve the scene hierarchy. More emissive
pixels or denser clutter do not automatically improve polish. Review at both
paused and running states: a handsome initial arrangement may turn into an
unreadable pool after its programme executes.

Exercise mouse and keyboard interaction while menus, sliders and other controls
have focus. Deepworks' completion repair demonstrates why a globally polled
movement key can conflict with a focused slider even when ordinary camera tests
pass. Include focus changes, held input, mid-drag cancellation and return from UI
in the review.

## 9. Validate behavior and challenge the evidence

**Output:** a candidate with explicit structural, behavioral, interaction and
rendered evidence.

Follow [map validation and acceptance](map-authoring-validation-and-acceptance.md)
for executable commands and current harness registration. Validate incrementally:
pure recipe checks, native mechanisms, controller/lifecycle, depth and actual
pixels, followed by relevant integration and hosted acceptance.

A mechanism passes only when the expected identity exists, its helper completes,
meaningful assertions execute, the oracle passes and the log is free of
disqualifying errors. The [PR #185 correction](../audits/2026-10-20-deepworks-pr185-completion.md)
records why exit zero plus a printed zero-failure count was inadequate.

Use negative controls that challenge a real risk: block a chute, suppress a
mechanism helper, omit a required plane witness or inject an older generation.
Keep them isolated and restore the intended source. Do not dilute a valid
criterion because the composition fails it; first determine whether the fixture,
test premise or engine behavior is wrong.

Inspect captured pixels as well as automated results. A region containing cells
does not prove that the user sees those cells through the final compositor.
Record headless and graphical execution separately, and qualify platform claims.

## 10. Publish a reproducible handoff

**Output:** reviewable source, usable documentation, provenance and final
acceptance tied to the published candidate.

Use the [documentation-maintenance contract](documentation-maintenance.md).
Keep scene operation, shared subsystem contracts, source references and dated
evidence in their appropriate homes. Add retrieval routes for new concepts and
evaluate new questions separately from frozen fixtures. An agent should be able
to find how to author a map without mistaking a historical capture for current
behavior.

Retain a recoverable checkpoint for each meaningful stage and follow any
user-requested progress-recording interval. Record the commit or dirty-source
identity, recipe, tool/runtime versions, platform, commands, timeouts, worker
settings, logs and capture hashes. Keep generated imports, toolchains and raw
temporary logs outside source control according to AGENTS; commit the concise
audit, intentional images and reproducible capture recipe.

Historical results remain historical. If a test was invalid, add a correction
that names the failure and the replacement evidence. Preserve the old hashes
and qualify old captures when the recipe changes.

Follow [repository publication policy](github-development-and-release.md).
For implementation work, iterate in draft and record every applicable
ready-for-review gate on the final head. A code change after validation requires
reassessing the affected evidence. Follow the user's requested endpoint:
an instruction to open a review PR should leave that PR open; merge and verify
on the base branch when merge is part of the authorized task.

## 11. Use the agent work packet

The following is a **task-description template**, not a configuration format or
new engine API. Replace every bracketed field with the actual assignment.

```text
Task: author [map name] in techrote/cybersand.

Goal:
[Total simulation extent, experience, visual intent and required references.]

Authority:
[Inspected base/branch/local changes, applicable AGENTS and canonical contracts.]
Read map-authoring-walkthrough.md and its design, layers and validation chapters.
Refresh material and depth contracts before choosing IDs, APIs or capacities.

Deliverables:
[Scene/recipe/module names, launcher integration, tests, operating guide,
intentional captures, source/runtime evidence and requested PR/merge endpoint.]

Authored coverage:
[District matrix; neighboring ports; reserved routes; foreground/rear exhibits;
atmosphere and distant architecture; actor/platform scope if requested.]

Ownership:
[Integrator and exclusive files or district groups for each agent.]
Shared coordinates, passage policy, event identities and reset semantics are
owned by [integrator]. Reviewers inspect independently.

Milestones:
1. Brief, material-role sheet, connection ledger and acceptance plan.
2. One fully working and visually reviewed representative district.
3. Full connected composition and authored layer coverage.
4. Bounded programmes, controls, render polish and focused regression evidence.
5. Final documentation/RAG checks, exact-candidate acceptance and handoff.

Progress:
At each milestone report source/checkpoint, changed decisions, actual tests,
failed attempts, current visual evidence, remaining gates and next action.
[Preserve any explicit user-requested repository checkpoint interval.]

Completion:
Use the agreed acceptance criteria and platform limits. Record all required
exhibit identities and meaningful checks, reject script errors and required
skips, preserve historical evidence, and publish the requested review result.
```

For a resumed task, prepend a compact state table: last accepted commit,
unpublished changes, owned files, completed gates, known failures, pending
decisions and next concrete step. Never ask a successor agent to reconstruct
authority from elapsed chat history alone.

## 12. Recognize the finish line

A polished map is complete when it meets the agreed brief in both authored
composition and actual execution. Use this recommended review rubric with the
task's explicit requirements:

| Area | Evidence to review |
|---|---|
| Composition | Distinct districts, coherent large forms, controlled detail and readable apparatus views |
| Continuity | Agreed connections in the final native geometry and convincing adjacent views |
| Materials | Structural roles and reactions consistent with the current catalogue and kernel behavior |
| Depth | Intended foreground, rear, atmosphere and distant features visible across every required district |
| Programmes | Bounded feeds, observable native mechanisms, containment and usable reset/replay |
| Interaction | Launch/return, camera, focus, painting and lifecycle behavior meet the selected host contract |
| Acceptance | Meaningful executed checks, reviewed actual pixels, negative controls and scoped platform evidence |
| Handoff | Recoverable source, source-linked docs, discoverable retrieval routes and exact-candidate results |

Report remaining limits directly. Reusing the guide does not transfer Deepworks'
past acceptance to a new recipe, establish actor traversal, certify browser
behavior, or prove target-machine performance. The successor map earns those
claims through its own agreed tests and review.
