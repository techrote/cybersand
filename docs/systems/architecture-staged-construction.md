---
title: Staged native architectural construction
status: Current
document-kind: contract
scope: WORLD-STEER-BATCH-M3-M5-001 Draft prototype, offline typed plans and ordinary native Workbench authoring
canonical-for: [native-architecture-stages, architecture-plan-adapter]
last-reviewed: 2026-11-24
related-documents: [native-architectural-modules.md, workbench-direct-art-batches.md, ../operations/world-steer-batch-lab.md, ../architecture/shared-workbench-authoring-data.md]
---

# Staged native architectural construction

**Draft / HOLD.** The separately authorized M3–M5 successor extends the existing
Batch Lab. The optional **Architecture…** Workbench window provides harvested
modules, offline typed construction plans, native inspection, zero-write
compilation, per-stage decisions, native execution and exact material evidence.
It neither dispatches inference nor replaces the Art provider or conversation UI.
No production physics, native material default or SWARM implementation changes.

## Authority and execution

`architecture_stage_plan.gd` is a pure compiler over copied native material bytes.
It accepts finite `cybersand-architecture-plan-v1` documents, at most 32 stages,
and a host inspection for the exact region. Stages declare intent, dependencies,
native module identities and transformations, direct drawing operations,
material permissions, protection, clearances, connections, resource budget,
expected effects, uncertainty and refusal conditions. Model estimates are never
used as native accounting.

Each stage covers at most 512 × 512 cells inside the ordinary World. Compilation
admits at most 2,048 source operations, 262,144 changed native cells and a
conservative 1,048,576 raster candidate bound. Sparse polygon/airbrush misses
count toward that bound. The existing Art rasterizer is advanced in bounded
chunks across frames. The compiler separately reports emitted input points,
conservative scan bound, unique touched cells and actual normalized native cost.
These are resource measures, not architectural-quality scores.
Module instances are capped at 64 before decoding; cumulative decoded cells,
compiled operations, clearance/protection scans and connector counts have
independent checked bounds before their arrays or loops expand.

Ordered proposed geometry is projected into private material bytes, then
normalized into one native write per changed cell. The accepted Art executor
only replaces stored **Empty or Hard wall** source identities. An unchanged
occupied cell becomes a no-op; changing Metal, Stone, Wood or another occupied
identity is refused before approval. Normal manual authoring can revise those
materials through its existing controls. This preserves the native contract
rather than implying that a destination palette grants arbitrary overwrite.

Host protection refuses any intersecting proposed footprint. Clearances require
actual projected Empty cells. Module-declared protected geometry must survive
composition; its protected regions are retained by the active session after
successful placement. Required authored point sockets/receptors require a
compatible opposite-facing placed partner. Required attachment lines currently
refuse explicitly; optional lines remain inspectable declarations. None of these
static semantic checks establishes physical support or actor traversability.

`architecture_stage_session.gd` captures native stored materials through the
existing `capture_batch_source` boundary with `commit=false`. It does not Flatten,
adopt a World or clear ordinary history. Preview is explicitly a **zero-write
compilation projection**, not speculative native simulation. Static staged
construction requires a paused Workbench.

Approval recaptures the native region and checks its exact material hash and
World generation, stage identity and selected module hashes. Required completed
dependencies are checked against their retained native written-cell receipts in
the current World; changed or undone geometry blocks continuation. The accepted
shared Art executor then owns native queueing, bounded application, Stop and
ordinary PAINT history. A queued stage is never described as completed.

Completion requires genuine completed `CyberNativeCellWorld` receipts, every
requested cell confirmed with no exclusion or refusal, exact changed-cell
accounting and a fresh authoritative material capture matching the approved
projection. Native refusal, changed geometry, Stop and missing final readback
remain explicit partial/refused/cancelled outcomes. Exact native readback rows
and hashes, source revision, platform, engine and final material plane are
retained. A partial prefix can be recovered through ordinary Workbench Undo;
revision/retry always takes another native inspection rather than replaying a
possibly applied suffix blindly.

## User controls and reusable parts

**Architecture… → Modules** searches names, tags and structural vocabulary;
inspects native material geometry; harvests an authored World region or selected
completed Batch tile; names/tags, imports and exports module documents; selects
explicitly permitted grid transforms, role-compatible palettes and bounded
detail variation; and proposes repeated placements. Placement is always a typed
stage requiring preview and approval.

**Build 8 starter parts** executes the eight typed part recipes in a private
bounded Batch controller and harvests actual completed native readback. It does
not replace the owner's displayed Batch grid or populate the library from
unexecuted procedural bytes. Stop retires the private work and cancelled parts
are not silently added. Imported documents preserve historical provenance but
do not acquire current-session native observation authority.

**Construction** loads one of nine independent side-elevation recipes, imports a
typed plan, edits/revises a stage, previews, approves, skips, stops and selects
the next stage. The examples are assembly hangar, arcology, biomechanical
arboretum, irregular megastructure, service network and constructed cavern, at
384 × 256 or 480 × 320 cells. Three additional modular examples assemble a hangar,
service stack and transfer viaduct from 32, 41 and 37 pinned starter-part
placements. Build the native starter library first, or import its actual module
identities. These plans retain module hashes, transformations and bounded detail
variation; loading a plan performs no construction. Each separates primary structure, services and
detail with explicit protected negative space. GOLDMAPS card identities describe
architectural interpretation, not traced source geometry or admission of refused
original maps.
Detail candidates are Empty cells directly face-adjacent to actual projected
supports/services, selected within bounded zones. Seeded detail never occupies
the declared traversal clearances. This is a geometric placement control,
not a human aesthetic judgement.

**References** retrieves a bounded source-bound design-card context and compatible
module metadata. Observed source statements, interpretation, schema/native
admission, graphical qualification and physical acceptance retain separate
meanings. No card or Gold recommendation is itself permission to place geometry.

## Persistence and adapter handoff

`save_session` atomically writes `cybersand-architecture-session-v1` through the
existing native file replacement boundary. The 64 MiB session limit is explicit.
It retains typed plans, decisions and exact native evidence. Ordinary Workbench
**Save start** separately persists authored native geometry through unchanged
Setup/material-baseline formats. Session files are not evolved physics saves.
Admission reserves conservative receipt space before native execution, including
the complete plan, states and imported historical evidence in the same envelope.
A full evidence budget refuses another stage rather than truncating its records.
Reopen also refuses if preserving the complete history and its provenance would
exceed the bound. Every admitted queued stage emits one terminal event, including
unexpected shared-executor replacement; unavailable final readback stays explicit.

Fresh-process Open verifies the plan identity and preserves imported evidence as
historical claims. All stages reopen as proposals, with no queued work, automatic
resumption or assumed current-World completion. The user reinspects and approves
before replaying. Changing native history from the architecture window invalidates
its approval preview and completed dependency state.

The future Art successor can call `load_plan(plan)`, `revise(stage)`,
`preview_selected()`, `approve()`, `skip()` and `cancel()` on the session adapter,
subscribe to `changed`/`terminal`, and consume compact retrieval context. It must
not bypass the host inspection, permission, budget, decision or native receipt
boundaries. Provider/model selection, network lifecycle, conversations and shared
logging remain owned by the independent Art mission. Genuine model quality,
hierarchical orchestration and training are not qualified by these offline plans.

## Qualification boundary

`test_architecture_stage_plan.gd` checks independent geometry and refusal oracles.
`test_architecture_stage_native.gd` executes the ordinary Workbench, static
preview, stale-source refusal, cancellation, shared Undo/Redo, real partial
prefixes and the six typed representative constructions.
`test_architecture_module_compositions.gd` independently executes all nine stages
of the three module compositions with exact readback and whole-World boundary
checks. The graphical fixture requires all nine native planes and exercises the
shipped module library and example picker. Its evidence is source-bound;
fresh-process reopen and actual graphical rendering have separate scripts and
results in the existing Batch qualification campaign. Linux, hosted Windows,
extracted Windows package and physical owner acceptance are separate gates.
Only observed final campaign receipts establish a platform pass.
