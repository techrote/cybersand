---
title: Retrieval question index
status: Current
document-kind: navigation
scope: Question-to-canonical-document routes; source-backed answers live in the linked contracts
canonical-for: []
last-reviewed: 2026-11-24
related-documents: [../README.md, retrieval-corpus.json, ../operations/documentation-maintenance.md, status-and-roadmap.md]
---

# Retrieval question index

Use this page to choose a source, then read its scope and the relevant section.
It is navigation, not a second answer corpus. Source behavior, approved intent,
unmerged candidates and dated test evidence are different claims.

## Launch, develop and qualify

| Question | Authoritative route |
|---|---|
| How do I launch a fresh Windows or Linux source checkout? Is `dev.cmd` required? | [First launch](../operations/local-build-and-validation.md#first-launch-from-a-source-checkout) |
| Which exact Godot, godot-cpp, compiler and SCons versions are required? | [Build inputs](../operations/local-build-and-validation.md#which-build-inputs-are-required) |
| How do I detect Git LFS pointers or a native library from different source? | [Source/runtime validation](../operations/current-and-historical-validation.md#what-validates-current-source-and-runtime-identity) |
| What belongs to this source repository and what belongs to the companion workspace? | [Source identity and recovery](../operations/source-checkpoint-and-recovery.md) |
| Which focused tests should I run, and what does a pass establish? | [Test selection](../operations/testing-validation-and-replay.md) |
| How do I reproduce a failure without changing the owner's user data? | [Isolated test data and diagnostics](../operations/local-build-and-validation.md#isolated-test-data-and-diagnostics), [troubleshooting](../operations/troubleshooting.md) |
| How are required CI cases scheduled and checked for complete execution? | [CI execution policy](../operations/ci-execution-and-performance.md), [test selection](../operations/testing-validation-and-replay.md#ci-execution-sharding) |
| Can a Draft skip, a cross-build or an old-head check authorize merge? | [Draft and qualification rules](../operations/github-development-and-release.md#current-ci-provider-and-draft-gating) |
| Who may publish a runtime, and which source/lease/artifact identities must agree? | [Runtime publication custody](../operations/github-development-and-release.md#source-matched-runtime-publication) |
| Should today's source match the historical M11 binary hashes? | [Current versus historical validation](../operations/current-and-historical-validation.md) |
| What are the actual Web build/release gaps? | [Unresolved Web configuration](../operations/github-development-and-release.md#unresolved-ci-contradictions), [Web threading](../operations/web-threading.md) |

## Author scenes and use tools

| Question | Authoritative route |
|---|---|
| Where is the ordinary Shared Workbench and what can I do first? | [First session](../operations/workbench-first-session.md) |
| What do paint, selection, fill, protection, Stop and history actually support? | [Painting user guide](../operations/workbench-painting-and-history.md), [editor contract](../systems/paint-editor-bounded-shapes.md) |
| What is the difference between a queued edit, native application and visible publication? | [Direct Art batches](../systems/workbench-direct-art-batches.md), [interfaces and messages](interfaces-and-message-contracts.md) |
| What is a Gentek, Variant, Preset or Composition, and how do I generate one? | [Architectural Generator](../systems/architectural-generator.md), [walkthrough](../operations/architectural-generator-playtest.md) |
| Are eighty Genteks available, and does that also ship SWARM negotiation? | [Accepted catalogue contract](../systems/architectural-generator.md), [current-state register](status-and-roadmap.md) |
| How do generated geometry, material palettes and authored starts relate? | [Shared authoring data](../architecture/shared-workbench-authoring-data.md), [generated playable maps](../systems/explore001-generated-playable-maps.md) |
| What are fields, modifiers, grammars and semantic planes? | [Generation fields](../systems/procedural-generation-fields-and-modifiers.md), [hierarchy](../systems/procedural-hierarchical-generation.md), [semantic planes](../systems/procedural-semantic-planes.md) |
| Does Save preserve the exact evolved simulation and moving actors? | [Save user guide](../operations/workbench-saving.md), [save/replay contract](level-saves-and-replay.md) |
| What does Flatten bake or discard, and what happens after reopening? | [Flatten storage contract](../architecture/shared-workbench-authoring-data.md#flatten-and-storage-compatibility), [workflow](../operations/gen008-flatten-qualification.md) |
| How do I configure OpenAI, NVIDIA, LM Studio or a custom local model? | [Art user guide](../operations/workbench-art.md), [providers](../systems/workbench-art-providers.md) |
| Does hiding Art cancel it? What does Stop mean, and are chats restored next launch? | [Art lifecycle and privacy](../systems/workbench-art-providers.md) |
| How do I inspect declared versus effective material properties? | [Materials Lab](../operations/materials-lab-authoring.md), [material kernels](../systems/materials-and-rule-kernels.md) |
| Does compiling a material make it active in the current Workbench scene? | [Candidate states](../operations/materials-lab-authoring.md#supported-candidate-edits-and-state-transitions), [current-state register](status-and-roadmap.md) |
| How do I select Water families and compare their behavior? | [Water Lab](../operations/workbench-water-lab.md), [solver-family policy](../architecture/liquid-solver-family-policy.md) |
| How do I compose multiple actors, change control source and add equipment? | [Actor procedure](../operations/workbench-actor-composition.md), [composition contract](../systems/workbench-actor-composition.md), [equipment](../systems/workbench-liquid-equipment.md) |

## Understand cells, physics and presentation

| Question | Authoritative route |
|---|---|
| Who owns cells, which worker can use Godot APIs, and where does Rapier run? | [Ownership and lifetimes](../architecture/data-ownership-and-lifetimes.md), [tick threading](../architecture/simulation-tick-and-threading.md) |
| Is Cell still four bytes? Is richer state restricted to sidecars? | [Chunk/storage model](../architecture/chunk-tile-and-buffer-model.md), [World storage](../systems/world-storage-and-interest-region.md), [approved intent](../decisions/2026-11-14-owner-authoring-intent.md) |
| What happens after a failed tick or capacity refusal? | [Tick failure contract](../architecture/simulation-tick-and-threading.md), [capacity budgets](../operations/configuration-and-capacity-budgets.md) |
| Can I treat all liquids as identical Water mass semantics? | [Liquid transition matrix](../architecture/liquid-state-transition-matrix.md), [family policy](../architecture/liquid-solver-family-policy.md) |
| Can Water travel upward ballistically? What remains out of scope? | [Ballistic Water](../architecture/ballistic-water-v1.md), [Wave Flow](../architecture/wave-flow-v1.md) |
| Do pressure, inertial and Wave solvers have the same law and defaults? | [Solver-family policy](../architecture/liquid-solver-family-policy.md), [pressure](../architecture/pressure-flow-v1.md), [inertial](../architecture/inertial-cellular-v1.md), [Wave](../architecture/wave-flow-v1.md) |
| Do all declared material properties affect every kernel? | [Materials and kernels](../systems/materials-and-rule-kernels.md), [Lab effective behavior](../operations/materials-lab-authoring.md) |
| How are reactions selected, accounted and tested? | [Intermaterial interactions](../systems/intermaterial-interactions.md), [material effects register](material-effects-register.md) |
| Can a body be erased into cells then restored each tick? | [Rigid-body coupling](../architecture/rigid-body-and-cellular-coupling.md), [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md) |
| Are high FPS and fast upload calls proof of physical progression? | [Rendering bridges](../architecture/rendering-and-gameplay-bridges.md), [profiling interpretation](../operations/profiling-observability-and-performance.md), [current-state register](status-and-roadmap.md) |
| Does Web simulation advance asynchronously like desktop? | [Tick threading](../architecture/simulation-tick-and-threading.md), [Web threading](../operations/web-threading.md) |
| What equality do hashes, coupled lockstep and fixtures actually establish? | [Determinism](../architecture/determinism-and-boundary-transfers.md), [validation semantics](../operations/testing-validation-and-replay.md#what-does-equality-establish) |
| Which limits are hard refusals and which remain planned requirements? | [Invariants](invariants.md), [configuration](configuration-reference.md), [capacity budgets](../operations/configuration-and-capacity-budgets.md) |

## Find current status and approved intent

| Question | Authoritative route |
|---|---|
| Is a named capability accepted, an unmerged candidate, or approved future design? | [Current-state register](status-and-roadmap.md); follow its principal live record before acting |
| Are PUBPRES, ObjectShard, RAMCACHE, SWARM, Batch, Gremlin, live material audition or integrated Strata available on main? | [Current-state register](status-and-roadmap.md), not an old PR title or copied HOLD banner |
| What does the owner intend for structural parts, authoring, persistence and layered presentation? | [Product intent](product-intent-and-priorities.md), [14 November decision](../decisions/2026-11-14-owner-authoring-intent.md) |
| Does the creation of #592 or an approved design authorize implementation or historical retirement? | [Owner decision scope](../decisions/2026-11-14-owner-authoring-intent.md), [documentation authority](../operations/documentation-maintenance.md) |
| Which foundational work should run first? | [Architecture programme](../operations/architecture-programme.md), [MicroScenarios programme](../operations/microscenarios-programme.md); never infer order from issue numbers |
| May an agent silently change protected material identities or source locks? | [Catalogue compatibility guard](../operations/material-catalogue-shadow.md), [material authoring architecture](../architecture/material-authoring-catalogue-plan.md) |
| What is still unresolved rather than rejected? | [Open decisions](status-and-roadmap.md), [product intent](product-intent-and-priorities.md); abstain when neither source nor owner decision settles it |

## Standalone scenes and World Art

| Task | Route |
|---|---|
| Deepworks, Blacksite Nine or the four Neon Reliquary tiles | [Deepworks](../operations/deepworks-exhibition.md), [Blacksite Nine](../operations/blacksite-nine-demo.md), [Neon Reliquary](../operations/neon-reliquary-demo.md) |
| Four-plane Strata Theatre and layer ownership | [Depth layers](../systems/depth-layers-and-parallax.md), [semantic authoring](../operations/semantic-depth-authoring.md) |
| Human movement, physical actors, flight and Thunderbowl | [Player playground](../systems/player-control-playground.md), [rigs](../systems/physical-actor-rigs.md), [flight lab](../systems/physical-flight-lab.md), [Thunderbowl](../systems/thunderbowl-control-reference.md) |
| Open World Art without assembling donor branches | [Viewer](../tools/world-art-preview.md), [pipeline contract](../tools/art-pipeline-unification.md) |
| Capture large/asymmetric World Art and preserve failure evidence | [Capture contract](../tools/world-art-capture.md), [Windows evaluator](../tools/world-art-evaluation.md) |

Art viewer dimensions do not enlarge native playable World capacity. Standalone
layer mechanisms and source-specific gallery captures do not prove ordinary
Workbench integration or physical GPU acceptance.

## Retrieval evaluation and explicit history

The [manifest](retrieval-corpus.json) selects the current answer corpus. The
[maintenance contract](../operations/documentation-maintenance.md) defines metadata,
selection, authority envelopes, fallback and cache requirements. Navigation pages
route users and stay outside default answer chunks.

Use separate fixtures for separate questions:

- [Frozen original questions](retrieval-questions.json) and
  [challenge set](retrieval-challenges.json) retain their original scope.
- [Owner-intent questions](owner-intent-retrieval-questions.json) test the
  authoring/world decision route.
- [DOCS-RENAISSANCE v1](retrieval-questions-docs-renaissance-v1.json) adds current
  onboarding, authoring, material, status and authority counterexamples.
- Focused implementation question files remain beside these fixtures; an additive
  suite does not replace or rewrite a frozen one.

For an explicit historical question, use the
[engineering history index](../history/engineering/README.md) and the evaluator's
`--historical` mode. Historical chunks keep their non-authoritative envelope even
when the original text says `Approved`, `Current` or gives an imperative. No link
expansion or ordinary fallback imports the archive.

Corpus containment, ranking and answer correctness are measured separately.
Read the saved contexts and check applicability against accepted source; a top-five
canonical hit does not establish a correct answer or owner approval.

## Earlier bookmarks

<a id="architectural-generator-catalogue"></a>
<a id="architecture-gate-status"></a>
<a id="branch-reconciliation-and-design-choices"></a>
<a id="coupled-desktop-determinism--2026-11-06"></a>
<a id="deepworks-exhibition-and-full-size-depth-worlds"></a>
<a id="development-application"></a>
<a id="direct-native-art-batches-without-inference"></a>
<a id="generated-terrain-in-the-playable-workbench"></a>
<a id="generation-workbench-2-and-procedural-quality"></a>
<a id="human-player-controls-acrobat-chains-and-material-swarms"></a>
<a id="independently-controlled-actors-in-ordinary-shared-workbench"></a>
<a id="issue-13-experiment-checkpoint"></a>
<a id="lcb-current-main-reassessment-routes--2026-11-03"></a>
<a id="material-authoring-adoption-and-implementation-boundary--2026-11-04"></a>
<a id="material-catalogue-compiler-and-compatibility-guards--2026-11-04"></a>
<a id="material-liveness-phase-a-and-implementation-admission--2026-11-04"></a>
<a id="materials-lab-v1-review-candidate--2026-11-11"></a>
<a id="microscenarios-and-intermaterial-interactions"></a>
<a id="ms-001-reference-pack-and-readiness"></a>
<a id="opt-in-transport-profiles"></a>
<a id="retrieve-historical-results-explicitly"></a>
<a id="semantic-four-plane-generation-and-authoring"></a>
<a id="shared-course-targets-and-worker-details"></a>
<a id="soliding-settled-region-acceleration-and-coherent-fracture"></a>
<a id="water-precision-experiment"></a>
<a id="which-architecture-experiments-should-run-before-changing-cell-or-liquid-state"></a>
<a id="why-can-dust-support-a-player-without-stopping-falling-grains"></a>
<a id="world-art-inspection-capture-and-windows-evaluation"></a>

Older section links land here so that existing bookmarks keep working. The
[source-pinned previous page](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/reference/retrieval-index.md)
preserves the original dated detail. Use the current routes above for present
behavior and instructions; a previous candidate status is not today’s status.
