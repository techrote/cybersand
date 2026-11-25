---
title: CyberSand documentation
status: Current
document-kind: navigation
scope: Audience-oriented routes to current user guides, canonical technical contracts, development procedures and explicitly historical evidence
canonical-for: []
last-reviewed: 2026-11-25
related-documents: [reference/status-and-roadmap.md, reference/retrieval-index.md, operations/local-build-and-validation.md, operations/documentation-maintenance.md]
---

# CyberSand documentation

**Build scenes, experiment with materials, play with physical actors, or work on
the engine.** Choose the route that matches your task. The [project overview](../README.md)
shows what CyberSand is; the [current-state register](reference/status-and-roadmap.md)
separates accepted functionality from active candidates and future direction.

| I want to… | Start here |
|---|---|
| Launch a source checkout | [Getting started](operations/getting-started.md) |
| Author and explore a native scene | [Your first Workbench session](operations/workbench-first-session.md), then [painting and history](operations/workbench-painting-and-history.md) |
| Generate architecture | [Architectural Generator walkthrough](operations/architectural-generator-playtest.md), [Gentek catalogue](systems/architectural-generator.md) |
| Understand a result or limitation | [Troubleshooting](operations/troubleshooting.md), [current-state register](reference/status-and-roadmap.md) |
| Contribute code or documentation | [Development handover](operations/cybersand-codex-development-handover.md), [build and validation](operations/local-build-and-validation.md), [contributing](../CONTRIBUTING.md) |
| Find the authority for a technical answer | [Question-to-document index](reference/retrieval-index.md) |

## Play and explore

The desktop project opens the **Feature Launcher**. Individual demonstrations
have their own controls and ownership boundaries; a standalone scene is not
necessarily a mode of the ordinary Shared Workbench.

| Experience | Guide |
|---|---|
| Shared Workbench: generated maps and editable starts | [First Workbench session](operations/workbench-first-session.md) |
| Materials sandbox and manual interaction recipes | [Materials sandbox guide](MATERIAL_LAB.md) |
| Composed actors and the Mixed Actor Workshop | [Actor composition guide](operations/workbench-actor-composition.md) |
| Player and rig experiments | [Player playground](systems/player-control-playground.md), [physical rigs](systems/physical-actor-rigs.md), [free flight](systems/physical-free-flight.md) |
| Deepworks material exhibition | [Districts, controls and reset behavior](operations/deepworks-exhibition.md) |
| Blacksite Nine industrial complex | [Routes, navigation and controls](operations/blacksite-nine-demo.md) |
| Neon Reliquary and the city below | [Four-tile scene guide](operations/neon-reliquary-demo.md) |
| Thunderbowl arena and controllers | [Control reference](systems/thunderbowl-control-reference.md) |
| Standalone Strata Theatre and semantic depth | [Four-plane presentation](systems/depth-layers-and-parallax.md), [semantic authoring](operations/semantic-depth-authoring.md) |
| World Art collections and rendered export | [Interactive viewer](tools/world-art-preview.md), [capture](tools/world-art-capture.md), [Windows evaluator guide](tools/world-art-evaluation.md) |

## Create and author

| Task | Canonical guide or contract |
|---|---|
| Paint, erase, select, fill and manage bounded edits | [Painting user guide](operations/workbench-painting-and-history.md), [operation contract](systems/paint-editor-bounded-shapes.md) |
| Understand baseline, edits and live simulation | [Shared authoring data](architecture/shared-workbench-authoring-data.md) |
| Generate native architecture and choose Genteks | [Architectural Generator](systems/architectural-generator.md), [hands-on walkthrough](operations/architectural-generator-playtest.md) |
| Explore generation fields, modifiers and hierarchy | [Generation overview](systems/procedural-world-generation.md), [fields and modifiers](systems/procedural-generation-fields-and-modifiers.md), [hierarchical generation](systems/procedural-hierarchical-generation.md), [standalone generation editor](systems/generation-workbench-2.md) |
| Save/reopen an authored result or bake history | [Save and Flatten user guide](operations/workbench-saving.md), [format boundaries](reference/level-saves-and-replay.md) |
| Inspect materials and test isolated candidates | [Materials Lab authoring](operations/materials-lab-authoring.md) |
| Compare Water families and configure experiments | [Water Lab](operations/workbench-water-lab.md), [family policy](architecture/liquid-solver-family-policy.md) |
| Draw through Art and configure a provider | [Art user guide](operations/workbench-art.md), [native batches](systems/workbench-direct-art-batches.md), [provider contract](systems/workbench-art-providers.md) |
| Compose actors and use supported equipment | [Actor composition](operations/workbench-actor-composition.md), [liquid equipment](systems/workbench-liquid-equipment.md), [usable contracts](systems/actor-usables.md) |
| Find material identity and appearance | [Material kernels](systems/materials-and-rule-kernels.md), [building catalogue](systems/building-material-catalogue.md), [visual patterns](systems/material-visual-pattern-library.md) |

An authored Save and Flatten are distinct operations. Neither should be assumed
to serialize every live body, solver, provider or simulation state. Follow the
[save contract](reference/level-saves-and-replay.md) for the actual format and
continuation limits.

## Understand the engine

Start with the [architecture overview](architecture/overview.md), then follow the
owner of the question. Native source establishes current cellular behavior;
Godot controls input, presentation and adapters. Platform and backend qualifiers
matter throughout these references.

| Subject | Reference |
|---|---|
| State ownership, threads and lifetime | [Ownership](architecture/data-ownership-and-lifetimes.md), [tick scheduling](architecture/simulation-tick-and-threading.md) |
| Cell storage, chunks and resident regions | [Chunk model](architecture/chunk-tile-and-buffer-model.md), [World storage](systems/world-storage-and-interest-region.md) |
| Materials, interactions and conservation | [Kernels](systems/materials-and-rule-kernels.md), [intermaterial interactions](systems/intermaterial-interactions.md), [material effects](reference/material-effects-register.md) |
| Water solver families, Wave flow and ballistics | [Solver policy](architecture/liquid-solver-family-policy.md), [pressure](architecture/pressure-flow-v1.md), [inertial](architecture/inertial-cellular-v1.md), [Wave](architecture/wave-flow-v1.md), [ballistics](architecture/ballistic-water-v1.md) |
| Rapier and material coupling | [Body/cell boundaries](architecture/rigid-body-and-cellular-coupling.md) |
| Publication, rendering and immutable observations | [Rendering bridges](architecture/rendering-and-gameplay-bridges.md), [interfaces and receipts](reference/interfaces-and-message-contracts.md) |
| Determinism, exactness and replay limits | [Determinism](architecture/determinism-and-boundary-transfers.md), [saves and replay](reference/level-saves-and-replay.md) |
| Requirements and capacity outcomes | [Invariants](reference/invariants.md), [configuration](reference/configuration-reference.md), [capacity budgets](operations/configuration-and-capacity-budgets.md) |

## Develop and test

1. Read [AGENTS.md](../AGENTS.md), the [handover](operations/cybersand-codex-development-handover.md)
   and the subsystem you will change. Inspect the actual checkout and preserve
   other work.
2. Use [build and validation](operations/local-build-and-validation.md) for the
   exact Godot/toolchain pins, native inputs, source-only launch and task-specific
   commands. The separate companion workspace is optional infrastructure.
3. Select [focused tests](operations/testing-validation-and-replay.md). Keep
   source inspection, compilation, runtime execution and physical owner
   acceptance as distinct evidence.
4. Follow [repository development and release](operations/github-development-and-release.md)
   for Draft status, exact-source qualification and runtime publication.
5. Complete [documentation maintenance](operations/documentation-maintenance.md)
   when behavior, controls, configuration, authority or navigation changes.

The [CI execution guide](operations/ci-execution-and-performance.md) owns accepted
scheduling policy. Active CI experiments are not production policy until accepted.
Use [CI campaign coordination](operations/ci-campaign-coordination.md) for
read-only run observations and [publication custody](operations/publication-custody.md)
for artifact and input verification. The
[24 November CI closure packet](operations/ci-engineering-closure-001/FINAL-DECISION-PACKET.md)
retains its dated evidence and decision boundaries.
The [current/historical validation guide](operations/current-and-historical-validation.md)
explains why a current build must not rewrite retained M11 evidence.

## Project state and approved direction

- [Current-state register and roadmap](reference/status-and-roadmap.md): accepted
  capabilities, active programme records, unresolved blockers and update seams.
- [Product intent and priorities](reference/product-intent-and-priorities.md):
  approved direction and preferences, distinct from delivered implementation.
- [14 November owner clarification](decisions/2026-11-14-owner-authoring-intent.md):
  the specific authoring/world decisions and their limits.
- [Validation evidence](reference/validation-evidence.md): dated results with
  source, artifact and platform scope.
- [Architecture programme](operations/architecture-programme.md),
  [MicroScenarios programme](operations/microscenarios-programme.md) and
  [development-claims programme](operations/development-claims-remediation-programme.md):
  canonical dependency and admission rules; issue numbers do not define order.

## Historical research

Use historical records deliberately to investigate an earlier decision, experiment
or failure. [Engineering archaeology](history/engineering/README.md) provides the
index and typed findings; [retained M11 records](audits/m11/README.md) preserve the
older release evidence. Their original `Current`, `Approved` or imperative text
retains its original scope and supplies no present implementation permission.

Ordinary retrieval excludes `docs/history/` and `docs/audits/`. Explicit historical
retrieval labels every returned chunk as non-authoritative. The
[retrieval and maintenance contract](operations/documentation-maintenance.md)
explains corpus selection, fallback behavior and separate answer review.

## Earlier bookmarks

<a id="architecture-experimental-programme"></a>
<a id="authority-and-status"></a>
<a id="choose-a-reading-route"></a>
<a id="ci-parallel-production-integration--2026-10-31"></a>
<a id="completed-architecture-research"></a>
<a id="consumed-app-publication--source5f02-and-checkpoint-ea96--2026-10-25"></a>
<a id="current-owner-policy-and-accepted-baseline--2026-10-31"></a>
<a id="current-trial-consumption-of-corrected-app--preparation-only"></a>
<a id="hierarchy-and-retrieval"></a>
<a id="historical-preparation-and-water-artifact-consumption"></a>
<a id="historical-routes"></a>
<a id="integrated-trial-successor"></a>
<a id="issue-13-experiment-checkpoint"></a>
<a id="issue-19-water-feel-lab"></a>
<a id="lcb-000-final-admission-status"></a>
<a id="microscenarios-and-intermaterial-interactions"></a>
<a id="play-current-route--2026-10-30"></a>
<a id="post-publication-test-checkpoint"></a>
<a id="scalable-reversible-soliding"></a>
<a id="trial-successor-correction-after-accepted-app--2026-10-25"></a>
<a id="water-precision-research"></a>
<a id="world-art-pipeline"></a>

Older section links land here so that existing bookmarks keep working. The
[source-pinned previous page](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/README.md)
preserves the original dated detail. Use the current routes above for present
behavior and instructions; a previous candidate status is not today’s status.
