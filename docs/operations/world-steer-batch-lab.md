---
title: Native Workbench Batch Lab
status: Current
document-kind: guide
scope: WORLD-STEER-BATCH-001 M0–M2 Draft candidate, native isolation, experiment boundaries and Windows owner evaluation
canonical-for: [native-workbench-batch-lab, batch-lab-experiment-contract, batch-lab-owner-evaluation]
last-reviewed: 2026-11-21
related-documents: [../systems/workbench-direct-art-batches.md, ../systems/workbench-art-providers.md, ../architecture/shared-workbench-authoring-data.md, local-build-and-validation.md]
---

# Native Workbench Batch Lab

**Draft / HOLD.** This implements the bounded M0–M2 scope authorized by the owner
for [WORLD-STEER-BATCH-001 / #579](https://github.com/techrote/cybersand/issues/579),
under [#549](https://github.com/techrote/cybersand/issues/549). It does not authorize
merge, production-default changes, paid model calls or M3–M7 implementation.
Runtime and package acceptance belong to the exact-source qualification artifacts;
the existence of this guide does not assert a successful platform run.

## Launch and acceptance

Extract the entire Windows evaluator ZIP into a writable directory. Check its
SHA-256 against the accompanying `.sha256` file, then run **Open Workbench.cmd**.
Godot 4.7, the source-matched native DLL, Rapier and app-local runtime dependencies
are bundled. The first launch imports the project. No separate Godot installation
or model account is needed for the three procedural examples.

In Shared Workbench, choose **Batch Lab…**. It is optional and starts OFF; opening
it does not start construction or inference. Its saved experiments use a separate
file selected through Save/Open and do not replace ordinary Workbench saves.

1. Select **Architecture**, **2 × 2**, **Procedural control**, then **New example**
   and **Run grid**. Each tile must move through queued/running to a terminal
   state with its own attempt ID, native receipt, changed cells and material hash.
2. Choose **4 × 4** and repeat with **Architecture**, **Pipework** and **Greebles**.
   These are the three ready-made examples. Native construction operates on
   individual material Worlds; thumbnails are derived from their readback.
3. Select a tile and inspect its retained attempt, prompt/version, seed, native
   materials, accepted edits and failures. Toggle **Godot material rendering** to
   distinguish actual shader rendering from the material-ID diagnostic image.
   Use the zoom/pan view and cell hover for full-resolution inspection.
4. Check at least two tiles and use **Fit all** for equivalent cell scale. Enable
   **Blind labels** to conceal prompt/provider/seed while retaining visible
   failures. The offline review export also randomizes presentation and keeps its
   provenance key separate from the reviewer packet.
5. Run a grid and press **Stop** while tiles are queued/running. Wait for native
   acknowledgements. Inspect stopped/partial attempts and their confirmed prefix;
   queued operations must not appear as completed changes. **Repeat** is a new
   attempt; **Replay** uses the retained source/program without model inference.
6. **Save**, exit the application completely, reopen the file and replay a result.
   Compare its material hash. **Export** retains all attempts, including failures,
   images, material planes and provenance. Return to ordinary Workbench and verify
   manual painting plus shared manual/agent Undo/Redo still work while paused.

The evaluator targets Windows 11. Hosted Windows Server 2022/ANGLE testing is
separate from the owner's Windows 11 desktop and physical NVIDIA acceptance.
The package is a Batch Lab runtime evaluator. Optional material-program compilation
and external local inference still require their existing developer/provider tools.

## Native ownership and preserved semantics

[`batch_lab_controller.gd`](../../godot/scripts/batch_lab/batch_lab_controller.gd)
owns a bounded queue of up to sixteen displayed tiles and at most two active
owners. [`batch_lab_tile_host.gd`](../../godot/scripts/batch_lab/batch_lab_tile_host.gd)
uses the existing `CyberSimulationWorker`, `CyberNativeCellWorld`, `ArtBatchPlan`
and `ArtBatchExecutor`. It adds no native World implementation or second
authority over the Workbench's installed World.

Each attempt restores copied material identities into its own paused native
World. The visible footprint is 64–512 cells per side. The existing native
constructor requires a 512-square arena; unused padding is independently checked
after application. Spatial padding is not the isolation boundary: different tiles
have different owners and Worlds. Dynamic materials such as Water preserve their
stored identities, but this M0–M2 prototype does not advance their simulation.
No cross-tile physics isolation claim depends on empty gaps in one shared World.

The source adapter uses the accepted material-baseline capture boundary with
`commit=false`. It never adopts/Flattens the ordinary Workbench or clears its
history. A selected crop retains its original coordinates and hash. Source
material protection, destination permissions, native per-chunk budgets and
stored-material acknowledgement remain enforced by the accepted Art pathway.
Batch destinations use that pathway's existing 18-material allowlist; ordinary
manual PAINT retains its full native palette. Source snapshots preserve all
native-supported stored identities, including protected materials outside the
Art destination subset.

Completed owners are released; immutable source/result planes and receipts remain.
Stop cancels pending inference and queued work, then waits for active native
receipts before reporting the applied prefix. Material **Undo/Redo inside Batch
Lab** reconstructs the attempt's source/result in a fresh isolated native World.
This is a material-baseline operation, not ordinary Workbench timeline history or
a complete physics checkpoint. Actor masks, conditions and evolved physical state
are not copied. Existing material IDs, physics defaults and ordinary save formats
remain unchanged.

## Experiments and evidence limits

The versioned inputs live under [`godot/batch_lab`](../../godot/batch_lab/experiments/v1.json).
P0 is direct construction; P1 adds geometry/connectivity/negative-space guidance;
P2 adds a source-grounded SANDMAPS text card; P3 adds explicit supported tool
contract guidance. All four variants have the same accepted seven Art primitives,
permissions and native budget. P3 introduces no new macro interpreter.

Procedural controls intentionally emit the same operations for each P0–P3 at a
matched seed. Seeded-random controls relocate the same component sizes/count
within the same footprint and budget. These demonstrate real construction,
measurement and failure retention; they do **not** measure prompt improvement.
There is no claim that a deterministic fixture is a model response.

The three reference cards identify and hash actual inspected originals in
`techrote/sandmapsreference` at commit
`99a166e7fcae45eb22be1740e9f33f62faccbcc7`: `works-0027` assembly hangar,
`biome-0004` mycological cavern and `techn-0021` containment-tree laboratory.
Visible observations, inferred native proposals and uncertainties are distinct.
Only cards and immutable source links are packaged; P2/P3 receive **grounded text
cards**, not image bytes or authoritative geometry/material labels.

Structural diagnostics cover native changed cells, protected/out-of-scope cells,
connected structural components, useful empty-space fraction, declared feature
occupancy and square-clearance path connectivity. These are explicit geometric
proxies, not an aesthetic score or proof that a gravity-driven player can traverse
the construction. Retain negative controls even when JSON, paint counts and
native execution are valid.

The independent reducer reads every retained attempt, validates material hashes
and native acknowledgements and retains unevaluable failures in its denominator:

```sh
python tools/batch_lab/evaluate.py session.json --output analysis.json --blind-dir new-review-directory
python tools/batch_lab/unblind.py committed-judgements.json new-review-directory/unblinding-key.json --output new-results.json
```

Keep `unblinding-key.json` away from the reviewer until judgements are committed.
Reserved final cohorts are separated by structural and reference groups, not
merely seed. They remain unexecuted and require independent task-fit curation;
no held-out quality gain or human preference result follows from development
fixture success.

## Providers, costs and responsiveness

Procedural, seeded-random and direct programs need no model. Optional local
inference reuses `ArtProvider` and its finite response/time budgets; it does not
introduce another provider/session stack. The candidate restricts dispatch to
literal loopback/private-LAN endpoints and refuses paid cloud dispatch. OpenAI
and NVIDIA selections are retained as visible refusal outcomes. Availability of
models in ChatGPT is not API entitlement. Missing endpoints, credentials,
malformed responses and cancellation are failures to inspect, not sample filters.
Never store credentials in configurations or exported evidence.

Model, compilation, native application, material capture, analysis and graphical
presentation times are separate. Usage is recorded when a provider supplies it;
unknown cost remains unknown. Exact-source scripted HTTP fixtures test protocol
failure paths only and must never be counted as actual model experiments.

At most two tile owners execute concurrently. Native initialization and structural
analysis operate on copied values away from the UI thread. A single existing
World Art render rig renders each immutable result once; selection/comparison
reuses cached images. The graphical campaign records actual render counts and
cached-interaction timing, rather than assuming a thumbnail implies completed
construction.

## Baseline, dependencies and write sets

The branch starts from accepted `main`
`846fe0533b3170e7b01f690518da49fc40cc24d1` (including merged #691 and #714).
That source includes the 80-Gentek catalogue, Materials Lab, Shared Workbench,
World Art, Art conversation lifetime, native painting and actor composition.
The #559 direct Art implementation is reused. Unmerged #569 research is a
read-only design reference, not a runtime dependency or imported training corpus.

| Area | Owned delta and accepted dependency |
| --- | --- |
| Native orchestration | New `scripts/batch_lab` adapter/controller; existing worker and Art executor unchanged |
| UI | New Batch Lab panel/view; one lazy toolbar entry and source-capture method in `shared_workbench.gd` |
| Experiments | New versioned prompts/cards/manifests, metrics and independent reducer; no #568/#569 data mutation |
| Qualification | New Batch Lab tests, runner and one request-scoped workflow; accepted build/packaging helpers reused |
| Documentation | This canonical guide and additive navigation/questions; historical records preserved |

The independently authorized SWARM-004/005, SWARM-006, CI-OPT-002, PUBPRES and
GEN-006 branches, workflows, evidence and baselines are untouched. No Batch Lab
capability depends on their unmerged work. Recheck live main/ownership before
any later reconciliation; shared Workbench mounting is the small overlap seam.

## Reproduce qualification and inspect custody

Use the pinned dependencies in the existing
[local build guide](local-build-and-validation.md), then run:

```sh
python tools/batch_lab/qualify.py --godot /path/to/Godot-4.7 --project godot --evidence /new/evidence --graphical --regressions
```

Linux requires an X11 display (software rendering under Xvfb is qualified
separately from physical GPUs). The dedicated
[`world-steer-batch-qualification.yml`](../../.github/workflows/world-steer-batch-qualification.yml)
builds both native runtimes from the checked-out source, runs real Linux/Windows
material/graphical tests and ordinary-authoring regressions, packages committed
source and re-executes a fresh extraction on Windows. It does not publish runtime
changes into main or another branch. It runs only by explicit dispatch or changes
to its request file on this mission's branch.

Artifacts retain exact source/runtime hashes, original logs, successful and failed
attempts, material planes, rendered frames, timing, blinded review input and ZIP
checksums. `qualification.json` and `results.json` assert actual outcomes; a ZIP
is published as qualified only after extracted-package execution succeeds.
Physical Windows 11/NVIDIA acceptance and genuine model comparisons remain
explicit independent gates.

## Deferred M3–M7

The small native pilot should determine the next authorization, not a 108-attempt
matrix by default. Development controls can pass geometric proxies without
demonstrating useful design, so freeze real provider settings and obtain blind
owner judgements before claiming optimization.

| Milestone | Follow-on decision and evidence required |
| --- | --- |
| M3 module harvesting | Select useful attempts first; qualify exact local-coordinate paste, seed variation, source identity and ordinary history |
| M4 SANDMAPS retrieval | Expand beyond three grounded cards only after real no-reference/reference comparisons establish value |
| M5 conversational design | Reuse existing conversations and zero-write previews; prove per-stage approve/revise/skip/Stop with native readback |
| M6 SLM distillation | Require genuinely useful verified traces, failure accounting and unseen structural cohorts before training |
| M7 mixed orchestration | Require measured provider budgets, independent module bounds and owner-reviewed multi-region usefulness |

All five remain **Deferred / not implemented by this mission**.
