---
title: Retrieval question index
status: Current
document-kind: navigation
scope: Question-to-canonical-document routes; detailed answers belong to the linked contracts
canonical-for: []
last-reviewed: 2026-09-11
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
| Desktop/Web order, synchronous ticks, failed-world reset/replacement | [Tick and threading](../architecture/simulation-tick-and-threading.md) |
| Web compatibility/threaded Auto and hosting | [Web threading](../operations/web-threading.md) |
| Body masks, displacement, terrain, Rapier scope | [Rigid-body/cellular coupling](../architecture/rigid-body-and-cellular-coupling.md) |
| Current powder/player collision and Mercury penetration | [Granular policy](../systems/granular-interaction-policy.md), [version decision](../decisions/ADR-011-granular-interaction-policy.md), [issue #10 evidence](../audits/2026-09-09-issue-10-granular-policy.md) |
| Historical powder measurements, barrel sinking and reversible soliding | [Baseline tooling](../operations/physics-characterisation.md), [issue #9 results](../audits/2026-09-09-physics-characterisation.md), [future soliding plan](../operations/physics-characterisation-plan.md) |
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

Issue #2 pause/re-entry, unchanged windows and failed-world region requests route
to [storage](../systems/world-storage-and-interest-region.md), [activity](../systems/activity-dirty-regions-and-waking.md)
and [tick ownership](../architecture/simulation-tick-and-threading.md). Dated
[combined evidence](../audits/2026-09-08-issue-2-interest-regions.md) remains outside
the default corpus; C02 has updated facts, and C03/C04 are new supplementary queries.

Current runtime/source gates and immutable M11 retention use [separate validation policies](../operations/current-and-historical-validation.md).

## Why can Dust support a player without stopping falling grains?

**Current:** Use the granular/player policy for capability, packing, side resistance, enclosure and fallback limits. See the [granular/player policy](../systems/granular-interaction-policy.md).


## Issue #13 experiment checkpoint

For reproducible five-floor experiments and preserving Mercury while tuning Sand, use the [Experiment Tower](../operations/experiment-tower.md), then its [dated evidence](../audits/2026-09-09-issue-13-transport.md).


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## Which architecture experiments should run before changing Cell or liquid state?

Use the [architecture programme](../operations/architecture-programme.md) for future experiment dependencies, decision gates, retained baselines and self-contained issue prompts. Its source ledger preserves four-conversation refinements. Current behavior still belongs to the linked subsystem and ADR contracts.

## Is issue16 ready to select a Cell layout?

No. The [cell layout registration](../operations/cell-layout-experiment.md) defines staged comparisons and records the owner-released L1 campaign. The [evidence record](../audits/2026-09-10-issue-16-cell-layout.md) reports exact comparisons, timing/memory and sleeping cost flags. Packing, direct epoch and sidecar stages remain; G-L is open.
