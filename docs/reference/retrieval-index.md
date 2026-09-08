---
title: Retrieval question index
status: Current
document-kind: navigation
scope: Question-to-canonical-document routes; detailed answers belong to the linked contracts
canonical-for: []
last-reviewed: 2026-09-08
related-documents: [../README.md, retrieval-corpus.json, ../operations/documentation-maintenance.md]
---

# Retrieval question index

Use this navigation page to select focused documents. Default machine retrieval
uses [retrieval-corpus.json](retrieval-corpus.json), not this index's repeated
question wording. Each answer must preserve the target's status/platform/evidence
qualifiers. [Maintenance](../operations/documentation-maintenance.md) defines the
metadata and [frozen questions](retrieval-questions.json) define the evaluation set.

| Question family | Canonical route |
|---|---|
| Actual version, commits, local changes, recovery | [Source checkpoint](../operations/source-checkpoint-and-recovery.md) |
| Who mutates cells; may a worker touch Godot? | [Ownership and lifetime](../architecture/data-ownership-and-lifetimes.md) |
| Desktop/Web order, synchronous ticks, failure handling | [Tick and threading](../architecture/simulation-tick-and-threading.md) |
| Web compatibility/threaded Auto and hosting | [Web threading](../operations/web-threading.md) |
| Body masks, displacement, terrain, Rapier scope | [Rigid-body/cellular coupling](../architecture/rigid-body-and-cellular-coupling.md) |
| Pinned Rapier acquisition and verification | [Rapier runbook](../operations/rapier-2d-migration-runbook.md) |
| Native snapshots, dirty retention, GPU uploads | [Rendering/gameplay bridges](../architecture/rendering-and-gameplay-bridges.md) |
| CYSD1 content, import/export ownership, exact resume | [Level saves and replay](level-saves-and-replay.md) |
| Hash coverage, parity, deterministic boundaries | [Determinism](../architecture/determinism-and-boundary-transfers.md) |
| Chunk versus activity block versus core, neighbor writes | [Chunk/tile model](../architecture/chunk-tile-and-buffer-model.md) |
| Explosion queue-full, lazy allocation, capacity failure | [Capacity budgets](../operations/configuration-and-capacity-budgets.md) |
| Actual defaults and adapter/fallback overrides | [Configuration reference](configuration-reference.md) |
| Interest filtering, preallocation, sleeping re-entry | [World storage](../systems/world-storage-and-interest-region.md) |
| Local wake, conservative phase wake, dirty/sleep | [Activity](../systems/activity-dirty-regions-and-waking.md) |
| Material IDs, adapted rules, staggered cadence | [Material kernels](../systems/materials-and-rule-kernels.md) |
| Native Water versus discrete fallback, viscosity/rest | [Water design](../systems/water-design.md) |
| Heat/pressure/wind and Smoke limits | [Field roadmap](../systems/smoke-heat-pressure-roadmap.md) |
| Appearance LUTs, glow, authoring intent | [Appearance](../systems/material-appearance-and-rendering.md), [authored programs](../architecture/item-authored-material-programs.md) |
| API versions, packed samples/results | [Interfaces](interfaces-and-message-contracts.md) |
| Invariants and incomplete enforcement | [Invariants](invariants.md) |
| Exact tools, separate native/Web bindings | [Build guide](../operations/local-build-and-validation.md) |
| CI drift, base-only build identity, release readiness | [Repository/release](../operations/github-development-and-release.md) |
| Historical versus current platform/test claims | [Validation evidence](validation-evidence.md) |
| What to update at a physics checkpoint | [Documentation checklist](../operations/documentation-maintenance.md#documentation-update-checklist) |
| Product intent and next priorities | [Owner intent](product-intent-and-priorities.md), [roadmap](status-and-roadmap.md) |
| Meaning of a term or unexplained symptom | [Glossary](glossary.md), [troubleshooting](../operations/troubleshooting.md) |

## Retrieve historical results explicitly

For the M11 August audit use [audits/m11](../audits/m11/README.md) and
[BUILD_ID](../BUILD_ID.md). For the first September audit use
[its dated report](../audits/2026-09-08-documentation-audit.md). The earlier
handover/roadmap/test tables are preserved in the
[pre-rewrite record](../audits/pre-rag-rewrite-2026-09-08/README.md).
Their statements do not supersede current source or later evidence.
