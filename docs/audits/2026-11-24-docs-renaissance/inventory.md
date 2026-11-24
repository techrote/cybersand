---
title: Documentation inventory and disposition
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated coverage and per-file disposition; not ordinary current-answer context
last-reviewed: 2026-11-24
---

# Documentation inventory and disposition

The [complete JSON inventory](inventory.json) accounts for every baseline Markdown file and relevant retrieval entry plus new current guides/tooling. It retains before/after hashes, metadata, canonical topics, audiences, priority, review depth, disposition, active overlaps, source claims and incoming-anchor effects. New mission evidence and images have separate manifests and do not inflate current-document coverage. The [dated generator](inventory_generator.py.txt) runs from the repository root using the immutable baseline and committed lane receipts; it needs no scratch snapshot.

## Coverage

| Measure | Count |
|---|---|
| baseline markdown count | 508 |
| inventory entry count | 547 |
| default documents before | 145 |
| default documents after | 151 |
| navigation documents | 8 |
| new current guides | 6 |
| source reconciled current markdown | 131 |
| source reviewed preserved current markdown | 21 |
| source reviewed current markdown total | 152 |
| metadata only routing changes | 27 |
| source inspected narrow current markdown | 0 |
| unreviewed default semantics | 3 |
| unreviewed default p1 | 0 |

**Review depth is explicit.** Source-reconciled means the owning lane recorded a substantive claim and source basis; independent outcomes are in the review packet. Metadata-only routing changes add `retrieval: explicit-only` to 27 already excluded packets and do not certify their prose. Structural checks cover local paths/anchors and metadata, not runtime correctness. Source-reviewed-preserved means a recorded source inspection justified keeping original bytes; the stated review scope does not imply every claim or runtime was requalified. Source-inspected-narrow records bounded table/identity checks without claiming a full semantic review. Historical evidence remains preserved.

## Current entry and answer documents

Every default and navigation document is listed below. The JSON additionally accounts for all exclusions, historical files and ancillary documentation. A preserved page is not an unqualified semantic PASS.

| Path | Priority | Review / disposition | Active overlap |
|---|---|---|---|
| `.github/pull_request_template.md` | P2 | metadata-and-structural; preserve; defer deeper reconciliation | None recorded |
| `AGENTS.md` | P0 | instruction-read; preserve | None recorded |
| `CONTRIBUTING.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `README.md` | P0 | source-reconciled; correct/consolidate | #754, #767 |
| `docs/MATERIAL_LAB.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/README.md` | P1 | source-reconciled; correct/consolidate | #729, #745, #754, #762, #767, #769, #770, #771, #773, #775 |
| `docs/architecture/ballistic-water-v1.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/chunk-tile-and-buffer-model.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/data-ownership-and-lifetimes.md` | P0 | source-reconciled; correct/consolidate | #745, #754, #762, #767, #775 |
| `docs/architecture/determinism-and-boundary-transfers.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/inertial-cellular-v1.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/item-authored-material-programs.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/lcb-pressure-inertial-handoff.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/liquid-prepared-setup-and-receipts.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/liquid-solver-family-policy.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/liquid-state-transition-matrix.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/material-authoring-catalogue-plan.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/module-boundaries.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/overview.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/pressure-flow-v1.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/pressure-optimization.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/principles-and-non-goals.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/rendering-and-gameplay-bridges.md` | P0 | source-reconciled; correct/consolidate | #767, #769 |
| `docs/architecture/rigid-body-and-cellular-coupling.md` | P1 | source-reconciled; correct/consolidate | #754 |
| `docs/architecture/shared-workbench-authoring-data.md` | P0 | source-reconciled; correct/consolidate | #762, #769 |
| `docs/architecture/simulation-tick-and-threading.md` | P1 | source-reconciled; correct/consolidate | #767 |
| `docs/architecture/soliding-lifecycle.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/architecture/wave-flow-v1.md` | P1 | source-reconciled; correct/consolidate | #767 |
| `docs/decisions/2026-11-14-owner-authoring-intent.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/decisions/ADR-001-native-simulation-core.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/decisions/ADR-002-double-buffered-tile-jobs.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/decisions/ADR-003-godot-bridge-and-immutable-snapshots.md` | P1 | source-reviewed-preserved; reviewed-preserved | #767 |
| `docs/decisions/ADR-004-interest-region-and-reconfiguration.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/decisions/ADR-005-water-model.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/decisions/ADR-006-gpu-compute-deferral.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/decisions/ADR-007-rigid-body-cellular-coupling.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/decisions/ADR-008-bounded-approximate-fidelity.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/decisions/ADR-009-rapier-2d-rigid-body-backend.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/decisions/ADR-010-failed-tick-quarantine.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/decisions/ADR-011-granular-interaction-policy.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/decisions/ADR-013-canonical-semantic-generation.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/decisions/ADR-014-semantic-plane-admission.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/operations/architectural-generator-playtest.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/architecture-programme-water-feel-addendum.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/architecture-programme.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/atlas-agent-runner.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/blacksite-nine-demo.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/cell-layout-experiment.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/ci-execution-and-performance.md` | P1 | source-reviewed-preserved; reviewed-preserved | #721, #735, #739 |
| `docs/operations/configuration-and-capacity-budgets.md` | P0 | source-reconciled; correct/consolidate | #745, #775 |
| `docs/operations/current-and-historical-validation.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/cybersand-codex-development-handover.md` | P0 | source-reconciled; correct/consolidate | #729, #745, #754, #767, #769, #770, #773 |
| `docs/operations/deepworks-exhibition.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/operations/development-claims-remediation-programme.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/documentation-maintenance.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/experiment-tower.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/explore001-desktop-playtest.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/gameplay-recording.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/gen008-flatten-qualification.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/gentek80-evaluation.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/getting-started.md` | P0 | source-reconciled; add | None recorded |
| `docs/operations/github-development-and-release.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/lcb-manual-comparison-ux.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/lcb-scenario-catalogue.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/lcb-water-comparison-and-fixtures.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/liquid-characterization.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/local-build-and-validation.md` | P0 | source-reconciled; correct/consolidate | #721, #729, #745, #754, #775 |
| `docs/operations/material-catalogue-shadow.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/material-liveness-investigation.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/materials-lab-authoring.md` | P0 | source-reconciled; correct/consolidate | #768 |
| `docs/operations/microscenario-reference-pack.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/microscenarios-programme.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/microscenarios.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/neon-reliquary-demo.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/physical-actor-programme.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/physics-characterisation-plan.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/physics-characterisation.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/play-desktop-manual-qualification.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/procedural-qualification.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/operations/profiling-observability-and-performance.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/rapier-2d-migration-runbook.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/semantic-depth-authoring.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/operations/showcase-guide.md` | P1 | source-reconciled; add | None recorded |
| `docs/operations/soliding-macro-fracture-fixture.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/operations/soliding-measurement.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/soliding-programme.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/soliding-stage3-freeze.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/soliding-stage3b-production-plan.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/source-checkpoint-and-recovery.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/state-precision-experiment.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/testing-validation-and-replay.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/troubleshooting.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/water-feel-lab-experiment.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/water-hybrid-pressure-extension-programme.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/wave-flow-evaluation.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/wb-art-paint-integrated-candidate.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/web-threading.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/operations/workbench-actor-composition.md` | P1 | source-reconciled; correct/consolidate | #762 |
| `docs/operations/workbench-art.md` | P0 | source-reconciled; add | None recorded |
| `docs/operations/workbench-first-session.md` | P0 | source-reconciled; add | None recorded |
| `docs/operations/workbench-painting-and-history.md` | P0 | source-reconciled; add | None recorded |
| `docs/operations/workbench-saving.md` | P0 | source-reconciled; add | None recorded |
| `docs/operations/workbench-water-lab.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/reference/configuration-reference.md` | P1 | source-reconciled; correct/consolidate | #762, #769 |
| `docs/reference/glossary.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/reference/interfaces-and-message-contracts.md` | P0 | source-reconciled; correct/consolidate | #745, #762, #775 |
| `docs/reference/invariants.md` | P0 | source-reconciled; correct/consolidate | #745, #775 |
| `docs/reference/level-saves-and-replay.md` | P0 | source-reconciled; correct/consolidate | #745 |
| `docs/reference/material-effects-register.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/reference/procedural-spatial-operators.md` | P2 | metadata-and-structural; preserve; defer deeper reconciliation | None recorded |
| `docs/reference/product-intent-and-priorities.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/reference/retrieval-index.md` | P1 | source-reconciled; correct/consolidate | #721, #729, #745, #754, #762, #767, #769, #770, #771, #773, #775 |
| `docs/reference/status-and-roadmap.md` | P0 | source-reconciled; correct/consolidate | #721, #729, #745, #754, #762, #767, #769, #770, #773, #775 |
| `docs/reference/validation-evidence.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/research/bounded-decompression-impulse-events.md` | P2 | metadata-and-structural; preserve; defer deeper reconciliation | None recorded |
| `docs/research/lumped-gas-region-pressure-bookkeeping.md` | P2 | metadata-and-structural; preserve; defer deeper reconciliation | None recorded |
| `docs/research/sandspiel-performance-and-material-port.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/activity-dirty-regions-and-waking.md` | P2 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/systems/actor-control-prototypes.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/actor-rigs.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/actor-usables.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/architectural-generator.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/building-material-catalogue.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/systems/depth-layers-and-parallax.md` | P1 | source-reconciled; correct/consolidate | #769 |
| `docs/systems/explore001-generated-playable-maps.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/flow-transport-and-profiles.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/generation-workbench-2.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/granular-interaction-policy.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/systems/intermaterial-interactions.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/material-appearance-and-rendering.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/material-visual-pattern-library.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/materials-and-rule-kernels.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/paint-editor-bounded-shapes.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/physical-actor-rigs.md` | P1 | source-reconciled; correct/consolidate | #762 |
| `docs/systems/physical-flight-lab.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/physical-free-flight.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/player-control-playground.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/player-environment-profiles-and-traversal.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/procedural-generation-fields-and-modifiers.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/procedural-hierarchical-generation.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/systems/procedural-semantic-planes.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/systems/procedural-typed-spatial-fields.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/procedural-world-generation.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/settled-region-discovery.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/smoke-heat-pressure-roadmap.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/themed-construction-materials.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/systems/thunderbowl-control-reference.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/water-design.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/workbench-actor-composition.md` | P1 | source-reconciled; correct/consolidate | #762, #775 |
| `docs/systems/workbench-art-providers.md` | P0 | source-reconciled; correct/consolidate | #756, #773 |
| `docs/systems/workbench-direct-art-batches.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/workbench-liquid-equipment.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/systems/world-storage-and-interest-region.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/tools/art-pipeline-unification.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `docs/tools/world-art-capture.md` | P1 | source-reconciled; correct/consolidate | None recorded |
| `docs/tools/world-art-evaluation.md` | P1 | source-reviewed-preserved; reviewed-preserved | None recorded |
| `docs/tools/world-art-preview.md` | P0 | source-reconciled; correct/consolidate | None recorded |
| `godot/native_extension/README.md` | P2 | metadata-and-structural; preserve; defer deeper reconciliation | None recorded |
| `third_party/README.md` | P2 | metadata-and-structural; preserve; defer deeper reconciliation | None recorded |

## Selection-only packets

These 27 packets were already excluded by the original manifest. Their bodies, statuses and authority remain unchanged; selection metadata prevents fallback/direct default ingestion.

| Path | Disposition |
|---|---|
| `docs/architecture/in-tools-gameplay-admission.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-prompts/cell-layout.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-prompts/compact-motion.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-prompts/decision-review.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-prompts/fractional-presentation.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-prompts/liquid-characterization.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-prompts/soliding-supplement.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-prompts/sparse-motion.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-prompts/state-precision.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/architecture-programme-source-ledger.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/gentek-interlaced-viaduct.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/gentek-rosework-showcase.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/gentek-showcase-integration-001.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/in-tools-fixtures-and-playtest.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/soliding-stage3-spark-connectivity.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/soliding-stage3-spark-measurement.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/soliding-stage3-spark-producer.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/soliding-stage3-spark-verification.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/operations/soliding-stage3b-astra-review.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/research/gentek-80-integration-001.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/research/gentek-classic-001.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/research/gentek-interlock-001.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/research/gentek-metabolist-001.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/research/gentek-showcase-cathedral-001.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/research/gentek-showcase-megablock-001.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/research/gentek-showcase-megatruss-001.md` | Preserve explicit task/research scope; metadata-only correction |
| `docs/research/gentek-suspended-001.md` | Preserve explicit task/research scope; metadata-only correction |

## Consequence-ranked residual work

- **P1:** 0 default documents remain without bounded consequential source review. Coverage records are claim-scoped; source inspection is not full scientific or runtime requalification. Active candidate overlaps still require their owning programme at acceptance.
- **P1:** Resolve remaining retrieval primary-destination misses using source/context evidence. Accurate bounded answers and correct abstentions are evaluated separately from ranking.
- **P1:** Runtime/evaluator and physical owner acceptance remain with their owning programmes; documentation does not adopt unmerged implementations.
- **P2:** Three low-use operator/research references retain metadata/structural review only: `docs/reference/procedural-spatial-operators.md`, `docs/research/bounded-decompression-impulse-events.md`, and `docs/research/lumped-gas-region-pressure-bookkeeping.md`. Their deeper mathematical/research semantics are explicit backlog; they were not silently certified. Further consolidation requires local applicability and preserved evidence.
- **P3:** Ancillary research/assets and historical Markdown retain original scope; low-consequence style churn was deferred.

## Preservation and incoming links

Machine entries retain all original/current heading slugs and baseline incoming links affected by removed slugs. Immutable Git and exact `.md.txt` snapshots preserve condensed front-door history. Lane preservation records and the aggregate packet identify originals. Original historical reports and frozen question sets remain unchanged.
