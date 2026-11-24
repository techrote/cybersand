---
title: Architectural module and staged construction Workbench
status: Current
document-kind: guide
scope: WORLD-STEER-BATCH-M3-M5-001 Draft/HOLD owner workflow, native modules, GOLDMAPS retrieval, offline staged construction and evaluator boundaries
canonical-for: [architectural-workbench-owner-workflow, architectural-staged-evaluator]
last-reviewed: 2026-11-24
related-documents: [world-steer-batch-lab.md, ../systems/native-architectural-modules.md, ../systems/architectural-knowledge-and-evaluation.md, ../systems/architecture-staged-construction.md, ../architecture/shared-workbench-authoring-data.md]
---

# Architectural module and staged construction Workbench

**Draft / HOLD.** The M3–M5 successor extends the existing native Batch Lab with
reusable material parts, compact GOLDMAPS design knowledge and an independently
executable staged construction panel. It uses actual CyberSand material geometry
and the ordinary Workbench history. No model account is required for the offline
typed plans, starter parts or example constructions.

The [integration ledger](../audits/2026-11-24-world-steer-m3-m5/integration-ledger.md)
and [final decision packet](../audits/2026-11-24-world-steer-m3-m5/FINAL-DECISION-PACKET.md) identify the tested source, runtime, campaign and
Windows package. A successful hosted graphical run does not establish physical
Windows/NVIDIA or owner gameplay acceptance. Keep the candidate Draft/HOLD.

## Open the evaluator

Extract the complete architecture Windows evaluator into a writable directory,
check the supplied SHA-256, and launch **Open Workbench.cmd**. The package carries
Godot 4.7, the source-matched native DLL, Rapier and its runtime dependencies. Keep
the whole directory together. First launch imports the project.

In ordinary Shared Workbench, pause the World and choose **Architecture…**. The
panel is created lazily. Opening it does not start inference or construction. It
has module, construction-stage and reference views. Ordinary Batch Lab remains
available independently through **Batch Lab…**.

For a first complete example, create a new **512 × 512** Empty authored canvas
using ordinary Workbench controls. In Architecture, select **Assembly hangar**
and **Load example**. This loads three proposals: structure, services and detail.
Each proposal needs its own inspection and approval. The other examples use the
same canvas and a true orthographic side elevation:

| Example | Declared construction region | Architectural emphasis |
| --- | --- | --- |
| Assembly hangar | 480 × 320 | Long roof span, suspended machinery and an open working floor |
| Interconnected arcology | 480 × 320 | Unequal inhabited blocks, bridge connections and lower passage |
| Biomechanical arboretum | 384 × 256 | Branching forms, constructed services and protected open space |
| Irregular megastructure | 480 × 320 | Asymmetric masses, transitions and service access |
| Service and pipework network | 480 × 320 | Multiple levels, galleries and deliberately bounded services |
| Constructed cavern | 384 × 256 | Irregular rock banks with inserted infrastructure |

After **Build 8 starter parts**, the picker also offers **Modular assembly
hangar**, **Modular service stack** and **Modular transfer viaduct**. These three
plans contain 32, 41 and 37 pinned placements respectively, across structure,
services and detail stages. They compose the actually harvested starter modules
with repetition and mirroring. Bounded seeded variation is available separately
for declared variable detail; these primary examples retain their connected parts.
They are not rasterized
substitutes for module reuse.

These are independent authored recipes informed by design cards. They do not
copy GOLDMAPS artwork or silently admit a refused original map. Geometric
clearance is inspected; dynamic stability, actor traversal and design preference
remain separate observations to make during owner playtesting.

## Inspect, preview and approve a stage

Select **Inspect + zero-write preview**. The host captures the actual native
material plane and computes the exact proposed footprint, material permissions,
protected cells, clearances, connection requirements and execution budget. The
image is explicitly a projection. It has performed no writes and has not
simulated physics. Empty previews or queued commands are not completed geometry.

New module selections and fresh previews fit their complete material extent.
Use **Fit** to restore that view, **1:1** for one cell per view pixel, the mouse
wheel to zoom and a right/middle drag to pan. Ordinary session refreshes retain
your chosen inspection framing.

Review the stage JSON and projected material result. **Approve stage** performs
a fresh native inspection. If the World, dependencies or plan changed since the
preview, approval refuses and requires another preview. A valid approval enters
the existing native execution path. Wait until the state is **completed** and
inspect the receipt/readback before choosing **Next stage**. Each dependent
stage requires completed, still-present native geometry from its predecessor.

The stage editor exposes intent, region, dependencies, exact module identities,
transformations, material roles, protection, connections, budget, expected
effects, uncertainty and refusal conditions. Edit the JSON and use **Revise
stage** to replace an unfinished proposal. Revision clears approval; the next
preview recomputes everything. **Skip stage** does not satisfy its dependencies.
**Stop / cancel** cancels an unexecuted proposal or requests a stop at the native
acknowledgement boundary. A partial prefix is retained with its actual receipts.

The native executor's accepted source-material restrictions remain in force.
Changing an existing non-Empty/non-Hardwall cell can refuse even when a palette
contains the requested destination material. The architecture adapter does not
expand ordinary Art permissions. A no-op on an identical cell is distinct from
an authorized overwrite.

## Harvest reusable native parts

There are three practical entry paths:

- **Build 8 starter parts** constructs columns, a truss, a floor, a doorway,
  return pipework, a gallery, a machine housing and a stepped transition in
  private native Batch tiles, then harvests their actual cropped material
  readback. Existing Batch experiments are retained. Recipes are not marked
  native-verified before execution.
- In Batch Lab, select a completed native tile and choose the harvest control,
  or use **Harvest selected Batch tile** in Architecture. Partial, refused,
  stopped and unobserved tiles cannot become successful harvested modules.
- Enter an in-bounds World region and choose **Harvest native region**. The
  read-only capture retains exact material IDs without adopting a new baseline
  or clearing ordinary authoring history.

Give the part a name, structural type and tags. **Allow grid mirror / quarter
turns** is an explicit authored permission. A capture establishes geometry; it
does not infer load-bearing meaning, sockets or playable passages. Such semantics
must be declared and validated separately. A module stores static material IDs,
not temperatures, velocities, actors or evolved simulation state.

The library supports search, structural filtering, inspect, **Rename / tag**,
**Import module…**, **Export module…** and **Save modules**. Import and fresh
reopen validate content hashes but cannot confer current native observation from
a serialized flag. Replaying an imported part through the native stage path can
establish new evidence. Native qualification, architectural recommendation and
physical acceptance have different meanings.

## Place, vary and compose parts

Select a module, choose a permitted transformation and an integer destination,
then set rows, columns and gap for finite repetition. The destination is the
transformed bounding box's top-left corner. Rotation is limited to exact quarter
turns; no rescaling or perspective conversion is performed.

Palette JSON maps an explicitly declared semantic role to a compatible material
ID, for example `{"structure":58}` only when that role and replacement are
declared by the module. Bounded seeded variation can thin declared variable
regions while retaining fixed and attachment geometry. An arbitrary harvested
part normally has no variable regions or role permissions until authored.

Choose **Propose placement**, then preview and approve the resulting finite
stage. Empty cells in a module are transparent during placement; they do not
erase the destination. A declared clearance is separately checked against the
actual World. Out-of-region placement, protected intersections, incompatible
palettes, unsupported transforms or unsatisfied required connections refuse
before mutation. Unsupported connection forms are explicit refusals.

Use **Undo native edit** and **Redo native edit**, or ordinary Workbench history,
to reverse/replay acknowledged native edits. These operations preserve the
shared ordering of human painting and staged construction. Reinspect stage
dependencies after an edit or history change. Library annotation and file
imports are not World edits.

## Retrieve architectural guidance

In References, enter structural intent and choose **Retrieve design cards**.
The offline ranker returns a small context pack from **25 source-bound GOLDMAPS
cards**. More precise typed queries can specify family, scale, topology,
connections, negative space, materials and compatible native module roles.

Cards separate observed source facts, cited architectural interpretation and
proposed construction strategy. Their evidence links preserve the original
source/policy identities, the 70 recovered versus 67 primary populations and
the original refusal history. A card is reference knowledge, not geometry or
permission to edit. The ranker distinguishes metadata-compatible library parts
from parts observed natively in this process; the stage host must still check
every selected placement.

The retrieval evaluation excludes three entire visual families and uses six
transfer briefs. It is a small curated deterministic test, not a blind preference
study or model-quality result. The native 30-attempt comparison preserves five
offline construction arms, two seeds and three contextual families. Its
independent diagnostics measure actual attachment, corridor intrusion, local
density, protection and geometric route clearance. Painted-cell count alone is
not an architectural quality score.

## Save, reopen and inspect evidence

**Save session…** retains the finite plan and historical execution records in a
separate architecture document. **Open session…** reopens it for review and
fresh inspection. It does not replay pending writes automatically, trust imported
completion flags or replace the current World. Use ordinary Workbench **Save start [Ctrl+S]**
to retain the authored World itself, and save/export the modules separately.

On reopening a World and session, compare the actual native material geometry
and receipts before continuing. A completed record is a historical observation
of its source World, not perpetual permission after Undo, editing or replacement.
When a stage fails or stops, inspect its exact partial result, then deliberately
revise, undo or propose a recovery stage. The retained record keeps the failure
and acknowledged prefix visible.

The preview pane may retain its last projected image after completion,
cancellation or a plan change while the label says **No current approval preview**.
It is not a continuously refreshed native World view. **Inspect + preview**
creates a new projection of the current source; native receipts and final
readback establish completed construction.

The evaluator's qualification evidence contains source/runtime hashes, native
module manifests, full material planes, stage receipts, saved examples, actual
graphical captures and fresh-process reopen results. Material-ID diagnostic
images are labelled separately from rendered application captures. The packaged
`architecture-evidence/` directory contains the completed source Windows outputs
and a separately hashed provenance manifest. Import its `modules/*.module.json`
or `stages/*-module.json` (typed examples) and `stages/modular-*.module.json`
(modular examples) through **Import module…**; inspect the adjacent native
planes, recipes and receipts as historical evidence.

For interactive modular-example replay, build the starter parts and use the
shipped example picker. It pins the current library's actual module identities.
The archived modular `*-plan.json` recipes instead pin the accompanying
`stages/source-part-library.json`, including its original native provenance;
equivalent geometry from a fresh harvest has a different content identity and
correctly refuses those old pins. Exact programmatic replay pairs the archived
plan with that library through `NativeModuleLibrary.load_library(path)`. The UI
imports individual module documents rather than whole-library JSON. An exported
whole-composition `*-module.json` (typed) or `modular-*.module.json` (modular)
is directly importable through the module UI.

## Integration and acceptance boundaries

The independently usable pathway is **typed plan → actual native inspection →
zero-write preview → owner approval → existing native executor → receipts and
readback**. The separately owned Art Workbench successor may submit typed plans
through this adapter. Conversation UI, provider reliability, model selection,
transport handling and session logging remain with that mission.

No paid inference, training, production physics/material-default change, merge
or Ready promotion is authorized. Model-assisted architectural quality remains
unqualified until an authorized real model campaign runs. Physical Windows
interaction, GPU behavior, playability and the owner's aesthetic acceptance
remain explicit final gates.
