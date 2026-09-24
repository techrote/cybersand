---
title: Retrieval question index
status: Current
document-kind: navigation
scope: Question-to-canonical-document routes; detailed answers belong to the linked contracts
canonical-for: []
last-reviewed: 2026-09-24
related-documents: [../README.md, retrieval-corpus.json, ../operations/documentation-maintenance.md, ../operations/architecture-programme-water-feel-addendum.md, ../operations/microscenarios-programme.md, ../operations/water-hybrid-pressure-extension-programme.md]
---

# Retrieval question index

Use this navigation page to select focused documents. Default machine retrieval
uses [retrieval-corpus.json](retrieval-corpus.json), not this index's repeated
question wording. Each answer must preserve the target's status/platform/evidence
qualifiers. [Maintenance](../operations/documentation-maintenance.md) defines the
metadata and [frozen questions](retrieval-questions.json) define the evaluation set.

| Question family | Canonical route |
|---|---|
| Is a closed/completed development claim actually implemented, integrated, verified and owner-accepted now? | [Development-claims remediation programme](../operations/development-claims-remediation-programme.md); use the [2026-09-20 audit](../audits/2026-09-20-development-claims-closure-audit.md) for the frozen intake findings |
| How do Play/Inspect/Benchmark share a definition, and is a scenario capture replay? | [MicroScenario contract](../operations/microscenarios.md) |
| Actual version, commits, local changes, recovery | [Source checkpoint](../operations/source-checkpoint-and-recovery.md) |
| Who mutates cells; may a worker touch Godot? | [Ownership and lifetime](../architecture/data-ownership-and-lifetimes.md) |
| Desktop/Web order, synchronous ticks, failed-world reset/replacement | [Tick and threading](../architecture/simulation-tick-and-threading.md) |
| Web compatibility/threaded Auto and hosting | [Web threading](../operations/web-threading.md) |
| Body masks, displacement, terrain, Rapier scope | [Rigid-body/cellular coupling](../architecture/rigid-body-and-cellular-coupling.md) |
| Current powder/player collision and Mercury penetration | [Granular policy](../systems/granular-interaction-policy.md), [version decision](../decisions/ADR-011-granular-interaction-policy.md), [issue #10 evidence](../audits/2026-09-09-issue-10-granular-policy.md); use the [remediation programme](../operations/development-claims-remediation-programme.md) for broad gameplay-acceptance status |
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
| What survives #26 review, what did #49 repair, and what now gates #45? | [Water design](../systems/water-design.md), [#26 post-merge review](../audits/2026-09-19-issue-26-post-merge-review.md), [#49 v2 registration](../audits/2026-09-20-issue-49-water-apparatus-v2-registration.md), [#49 Current-Water v2 baseline](../audits/2026-09-20-issue-49-water-apparatus-v2-baseline.md), [architecture programme](../operations/architecture-programme.md) |
| Why can deep connected Water keep unequal levels, what did #26 reject, and what comes next? | [Water design](../systems/water-design.md), [architecture programme](../operations/architecture-programme.md), [#26 evidence](../audits/2026-09-19-issue-26-water-leveling.md) |
| Why test hybrid Water sheets before adding another pressure solver? | [Water hybrid/pressure extension](../operations/water-hybrid-pressure-extension-programme.md), [Water design](../systems/water-design.md), [soliding programme](../operations/soliding-programme.md) |
| Is the barrel a special physics object, and was its historical support result owner-accepted? | [Product intent](product-intent-and-priorities.md), [Water hybrid/pressure extension](../operations/water-hybrid-pressure-extension-programme.md), [remediation programme](../operations/development-claims-remediation-programme.md) |
| How could trapped gas, sealed rooms or vacuum be approximated without cellular gas CFD? | [WEX-003 feasibility research](../research/lumped-gas-region-pressure-bookkeeping.md), [Water hybrid/pressure extension](../operations/water-hybrid-pressure-extension-programme.md), [field roadmap](../systems/smoke-heat-pressure-roadmap.md) |
| Heat/pressure/wind and Smoke limits | [Field roadmap](../systems/smoke-heat-pressure-roadmap.md) |
| Appearance LUTs, glow, authoring intent | [Appearance](../systems/material-appearance-and-rendering.md), [authored programs](../architecture/item-authored-material-programs.md) |
| API versions, packed samples/results | [Interfaces](interfaces-and-message-contracts.md) |
| Invariants and incomplete enforcement | [Invariants](invariants.md) |
| Exact tools, separate native/Web bindings | [Build guide](../operations/local-build-and-validation.md) |
| CI drift, base-only build identity, release readiness | [Repository/release](../operations/github-development-and-release.md) |
| What is the current CI provider/recovery state, and is main protected? | [Repository/release](../operations/github-development-and-release.md), then the [2026-09-24 recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md) for incident evidence |
| Is Stage-3B #65 complete and what is the next dependency-ready package? | [Stage-3B production plan](../operations/soliding-stage3b-production-plan.md), [roadmap](status-and-roadmap.md); use the [recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md) for #65 recovery evidence |
| Are the retained #65 Linux/Windows runtimes source-matched, and what was actually executed? | [Current/runtime validation](../operations/current-and-historical-validation.md), [validation evidence](validation-evidence.md), then the [recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md) |
| How should implementation/integration/verification/acceptance be distinguished when closing work? | [Development-claims remediation programme](../operations/development-claims-remediation-programme.md); #86 remains the live owner for the durable closure/ownership/validation-premise controls |
| Historical versus current platform/test claims | [Validation evidence](validation-evidence.md) |
| What to update at a physics checkpoint | [Documentation checklist](../operations/documentation-maintenance.md#documentation-update-checklist) |
| Product intent and next priorities | [Owner intent](product-intent-and-priorities.md), [roadmap](status-and-roadmap.md) |
| Meaning of a term or unexplained symptom | [Glossary](glossary.md), [troubleshooting](../operations/troubleshooting.md) |
| Why #17 does not make mass8 the perceptual minimum | [Water-feel programme addendum](../operations/architecture-programme-water-feel-addendum.md), [#17 evidence](../audits/2026-09-11-issue-17-state-precision.md) |
| What #19 delivers, and whether the Water Feel Lab is ready for a formal blind human study | [Experiment Tower](../operations/experiment-tower.md), [policy registration](../operations/water-feel-lab-experiment.md), [completion evidence](../audits/2026-09-12-issue-19-water-feel-lab.md), then [REM-001 current qualification](../operations/development-claims-remediation-programme.md) |
| Why #18 remains held after G-P | [Water-feel programme addendum](../operations/architecture-programme-water-feel-addendum.md), [compact-motion prompt](../operations/architecture-programme-prompts/compact-motion.md) |
| What is the actual #24/#27-#30 development order, and may MicroScenarios run before G-final? | [Canonical MicroScenarios/interactions programme](../operations/microscenarios-programme.md), [roadmap](status-and-roadmap.md) |
| What interaction schema/rule/provenance is authoritative now, and how do we avoid a destructive N² matrix? | [Current interaction substrate](../systems/intermaterial-interactions.md), [canonical programme](../operations/microscenarios-programme.md) |

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

The Current Tower includes #19's 35-scenario Water Feel Lab, normalized runtime
policy and transactional Apply + Reset. Its simulation/presentation apparatus
remains validated, but the old broad "H-ready" wording is not sufficient for a
formal blind human study: #84 owns arm-identity separation and append-only study
observations. No human preference result exists yet.

## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## Which architecture experiments should run before changing Cell or liquid state?

Use the [architecture programme](../operations/architecture-programme.md) for the original future experiment dependencies and completed staged gates. Then use the dated [Water-feel addendum](../operations/architecture-programme-water-feel-addendum.md) for the post-G-P refinement of #19/#18 ordering and evaluation authority. Current behavior still belongs to subsystem and ADR contracts.

## Architecture gate status

G-L, G-C and G-P are complete. Current 4-byte Cell remains baseline pending G-final; mass8 remains the quantitative/reference Water control; current coherence 0..12 fits exactly in four semantic bits. None of those results selects production packing.

Following owner clarification after G-P, #19 completed **V plus H-preparation**:
the intended four-visible-level Water presentation and a deterministic
runtime-configurable Water Feel Lab. See the [post-G-P refinement](../operations/architecture-programme-water-feel-addendum.md)
and [completion evidence](../audits/2026-09-12-issue-19-water-feel-lab.md).

#19 supplied the validated simulation/presentation apparatus. Formal blind-study
capture now waits on #84. Separately, later H-related evidence and #26 identify a
bulk head/leveling defect first; both #26 bounded local candidates remain rejected.
Post-merge review required #49 to repair/version the successor apparatus; the
corrected v2 control is now available in the dated #49 baseline. #95 must synthesize
that control with WEX evidence before #45 may select a disposition. #18 remains held
until the resulting bulk-head disposition lets directional references be
interpreted cleanly. #20
remains downstream of #18/G-M; G-final remains open.

For the pre-refinement identity/scope reconciliation, use the [dated reconciliation audit](../audits/2026-09-11-programme-gate-reconciliation.md).

## Water precision experiment

For mass4/6/8/10, normalized versus literal thresholds, and Water delay4/8, use
the [preregistered experiment](../operations/state-precision-experiment.md).

For the measured numerical recommendation, use [G-P](../operations/architecture-programme.md#g-p-staged-decision-2026-09-11) and the [precision evidence](../audits/2026-09-11-issue-17-state-precision.md).

For the later interpretation that numerical divergence is not automatic gameplay rejection, and for planned mass3/5/7 plus shortened-coherence human-test preparation, use the [Water-feel addendum](../operations/architecture-programme-water-feel-addendum.md). This later planning refinement does not rewrite #17 evidence.


## MicroScenarios and intermaterial interactions

For the actual dependency graph, the rule that issue numbers are not sequence,
the exploratory-before-G-final policy, anomaly capture/reduction/triage workflow,
and INT-000 programme boundaries, retrieve the
[canonical programme](../operations/microscenarios-programme.md). For the implemented sparse/versioned schema, rule IDs, family membership, provenance, coverage ledger and bounded compact-pair migration, use the [current interaction substrate](../systems/intermaterial-interactions.md); use the [dated #29 audit](../audits/2026-09-19-issue-29-int000.md) only for source/test evidence.

The architecture programme remains the separate authority for #14/#18/#20
scientific gates. MicroScenarios can provide apparatus and later retained
fixtures; their existence is not architecture admission evidence.


## MS-001 reference pack and readiness

Route generated interaction definitions, full observation inspection, fresh-reset
A/B, Flood-Control world-state objectives/solution witnesses, named bounded Stress
profiles and #29 Lab-readiness questions to the [reference-pack runbook](../operations/microscenario-reference-pack.md),
then the [shared schema/host](../operations/microscenarios.md). The
[dated execution ledger](../audits/2026-09-19-issue-28-ms001.md) owns platform/run
claims. Exploratory source acceptance, merged readiness and platform acceptance are
separate; the programme graph owns admission.

## Soliding, settled-region acceleration and coherent fracture

- Current programme/dependencies and Phase 0 disposition: [soliding programme](../operations/soliding-programme.md).
- Owners, lifecycle, eligibility and nonwrapping identities: [soliding lifecycle](../architecture/soliding-lifecycle.md).
- Dirty/activity discovery, complete summaries and refusal: [discovery substrate](../systems/settled-region-discovery.md).
- Passed Stage-3A bounded-reference evidence and open Stage-3B locality/scalability gate: [Stage-3 review](../audits/issue-12-2026-09-19/stage3-exit-review.md).
- Completed read-only Stage-3B review and active implementation route: [Astra architecture-review packet](../operations/soliding-stage3b-astra-review.md), then the [Stage-3B production plan](../operations/soliding-stage3b-production-plan.md). #56-#65/#69 are complete; #65 landed and was verified through the recovery programme. **#66 is next**, followed by #67, #68 and #70.
- Ordinary Current sleep control and measurement gaps: [measurement contract](../operations/soliding-measurement.md).

- Blocked falling/torque/coherent-child motion fixture: [macro-fracture preregistration](../operations/soliding-macro-fracture-fixture.md).
