---
title: CyberSand documentation
status: Current
document-kind: navigation
scope: Entry routes and authority rules for the focused documentation hierarchy
canonical-for: []
last-reviewed: 2026-09-24
related-documents: [reference/retrieval-index.md, reference/status-and-roadmap.md, operations/documentation-maintenance.md, operations/microscenarios-programme.md, operations/development-claims-remediation-programme.md, operations/water-hybrid-pressure-extension-programme.md]
---

# CyberSand documentation

## Choose a reading route

| Need | Start here |
|---|---|
| Reconcile a completed/closed claim, broad gameplay acceptance, or remediation owner | [Development-claims remediation programme](operations/development-claims-remediation-programme.md), then the [dated REM-001 audit](audits/2026-09-20-development-claims-closure-audit.md) for intake evidence |
| Explore the MS-001 Materials Lab / Flood / Stress pack or compare generated definitions | [Reference pack and controls](operations/microscenario-reference-pack.md), [MS-001 evidence](audits/2026-09-19-issue-28-ms001.md) |
| Author, load or benchmark a MicroScenario | [Current shared contract and host](operations/microscenarios.md), [checkpoint evidence](audits/2026-09-19-issue-27-microscenarios.md) |
| Begin development | [Handover](operations/cybersand-codex-development-handover.md), [actual source identity](operations/source-checkpoint-and-recovery.md), [roadmap](reference/status-and-roadmap.md) |
| Understand the recovered CI baseline, #65 completion or the 2026-09-20 through 2026-09-22 incident | [Repository/release policy](operations/github-development-and-release.md), [final recovery audit](audits/2026-09-24-cybersand-recovery-audit.md), [Stage-3B production plan](operations/soliding-stage3b-production-plan.md) |
| Choose current MicroScenarios / interaction work order | [Canonical programme graph](operations/microscenarios-programme.md), then the target issue and its named dependencies; issue numbers are not sequence |
| Inspect current intermaterial rule/provenance/coverage semantics | [Interaction substrate](systems/intermaterial-interactions.md), [#29 implementation evidence](audits/2026-09-19-issue-29-int000.md) |
| Understand the engine | [Architecture overview](architecture/overview.md), then its focused ownership/threading/coupling links |
| Answer one technical question | [Retrieval index](reference/retrieval-index.md) |
| Change a material | [Rule kernels](systems/materials-and-rule-kernels.md), [Water](systems/water-design.md), [material lab](MATERIAL_LAB.md) |
| Investigate deep Water surge, hybrid Water sheets, trapped gas or decompression | [Water hybrid/pressure extension](operations/water-hybrid-pressure-extension-programme.md), [WEX-003 gas-region feasibility](research/lumped-gas-region-pressure-bookkeeping.md), then [Water Current semantics](systems/water-design.md) and [soliding programme](operations/soliding-programme.md) |
| Investigate powder penetration, barrel sinking or soliding | [Measured baseline tooling](operations/physics-characterisation.md), [dated results](audits/2026-09-09-physics-characterisation.md), [future soliding plan](operations/physics-characterisation-plan.md) |
| Build or validate | [Build guide](operations/local-build-and-validation.md), [test selection](operations/testing-validation-and-replay.md), [dated evidence](reference/validation-evidence.md) |
| Understand intent | [Product priorities](reference/product-intent-and-priorities.md), [principles](architecture/principles-and-non-goals.md), [ADRs](decisions) |
| Maintain these docs | [Documentation and retrieval contract](operations/documentation-maintenance.md) |

## Authority and status

Executable source defines **Current** behavior. An **Approved** requirement may
still be partly implemented. **Planned** means future work; **Deferred** means
deliberately postponed; **Rejected** means intentionally declined. Frontmatter
`Approved design` is the compatibility alias for Approved. Label claims individually
when a page mixes implemented behavior and target design.

Runtime claims need dated source/artifact/platform evidence. Historical M11 hashes,
an acquisition base, a compiled library, a headless fixture, an HTTP checksum check
and a browser run prove different things. [Evidence](reference/validation-evidence.md)
and [source identity](operations/source-checkpoint-and-recovery.md) explain the limits.

## Hierarchy and retrieval

- `architecture/`: ownership, lifecycle, scheduler, determinism and coupling contracts.
- `systems/`: storage, activity, materials, Water and appearance behavior.
- `decisions/`: accepted choices, rationale, rejected alternatives and implementation gaps.
- `operations/`: building, testing, profiling, troubleshooting and checkpoint procedures.
- `reference/`: API/defaults/invariants, saves, status, evidence, glossary and owner intent.
- `research/`: attributed upstream behavior and adaptation scope.
- `audits/`: immutable dated results and explicitly superseded historical records.

Each canonical page declares its scope, status, review date and unique topic ownership.
The [corpus manifest](reference/retrieval-corpus.json) selects ordinary retrieval;
navigation and historical pages are explicitly excluded. Carry page metadata and
heading ancestry with each chunk. Link the canonical contract instead of copying
its detailed facts into multiple pages. Evaluate retrieval using the
[frozen questions](reference/retrieval-questions.json) and semantic sufficiency review.

## Historical routes

The [structural rewrite audit](audits/2026-09-08-structural-documentation-audit.md)
and [retrieval evaluation](audits/2026-09-08-retrieval-evaluation.md) record this
documentation checkpoint, its measured limits and recommended next work.
The local [issue #1 implementation evidence](audits/2026-09-08-issue-1-failed-ticks.md)
records the failed-tick policy and platform-scoped acceptance.
The subsequent [GitHub milestone](audits/2026-09-08-github-milestone.md) records
the paired source/workspace publication and open correctness follow-ups.

[M11 audit records](audits/m11/README.md), [BUILD_ID](BUILD_ID.md),
[first September documentation audit](audits/2026-09-08-documentation-audit.md),
and [pre-rewrite handover/checkpoint records](audits/pre-rag-rewrite-2026-09-08/README.md)
retain their original scope. Legacy milestone overview/status/performance files
remain historical routes, not current contract owners. Consult them explicitly for
a historical question; do not merge their claims into the current answer.

The [coordinated issue #2 acceptance](audits/2026-09-08-issue-2-interest-regions.md)
records pause/re-entry, independent causes and combined failure/recovery validation.

Current runtime/source gates and immutable M11 retention use [separate validation policies](operations/current-and-historical-validation.md).

Current player support and pair exchange: [granular interaction policy](systems/granular-interaction-policy.md),
[ADR-011](decisions/ADR-011-granular-interaction-policy.md) and
[dated issue #10 acceptance](audits/2026-09-09-issue-10-granular-policy.md).


## Issue #13 experiment checkpoint

[Experiment Tower](operations/experiment-tower.md) provides the shared five-floor physics lab; [issue #13 evidence](audits/2026-09-09-issue-13-transport.md) separates its checkpoints and acceptance.


The [transport profile editor](systems/flow-transport-and-profiles.md) shows effective
settings/origins, saves editable user copies and applies through an explicit restart.

## Issue #19 Water Feel Lab

The [Water Feel Lab runbook](operations/experiment-tower.md#current-19-water-feel-lab-extension)
and [completion evidence](audits/2026-09-12-issue-19-water-feel-lab.md) describe
the validated four-level presentation and deterministic runtime Water-policy
apparatus. No human H preference study has run. The later
[REM-001 reconciliation](operations/development-claims-remediation-programme.md)
qualifies the old broad "H-ready" wording: the simulation/presentation apparatus
remains valid, while formal blind-study capture is held for #84 because arm identity
and append-only observation integrity require repair. No production precision,
packing, #18/#20 admission or G-final decision follows from #19.

## Architecture experimental programme

The [evidence-gated programme](operations/architecture-programme.md) coordinates Cell layout, liquid precision/history, fractional presentation and conditional sparse motion. It retains existing ADRs and reuses soliding issue #12; linked prompts are self-contained. This is Planned research, not a selected replacement architecture.

## Completed architecture research

[Programme staged gates](operations/architecture-programme.md#g-l-staged-decision-2026-09-11),
[Cell research](operations/cell-layout-experiment.md) and the
[reconciliation audit](audits/2026-09-11-programme-gate-reconciliation.md)
distinguish evidence completion from production approval.

[Completed liquid characterization](operations/liquid-characterization.md) and
its [acceptance coverage](audits/2026-09-11-issue-15-coverage.md) explain the C gate
and the distinction between sleep, mobility, cadence and Water rest.

## Water precision research

The [Issue17 registration](operations/state-precision-experiment.md) defines the isolated
P1/P2/P3 native experiment. That dated experiment did not migrate its production
control. For current physical storage after later integration, use the
[source-qualified storage contract](architecture/chunk-tile-and-buffer-model.md#what-is-stored-per-cell-and-per-chunk);
this does not reinterpret #17 or select G-final.

[Completed precision results](audits/2026-09-11-issue-17-state-precision.md) and
[staged G-P](operations/architecture-programme.md#g-p-staged-decision-2026-09-11)
retain mass8, establish Water-only delay4, and keep downstream feature gates intact.


## MicroScenarios and intermaterial interactions

The [canonical programme](operations/microscenarios-programme.md) owns the
programme-level dependency graph for #24/#27-#30 and their links to
#18/#20/#26/#14. **Issue numbers are identifiers, not execution order.**

MicroScenarios are now an active exploratory apparatus rather than a purely
post-G-final showcase phase. #27 can proceed once the Tower/launcher hygiene is
present, independently of #18 completion; #28 may build provisional exploratory
worlds on the common host before G-final and revalidate them after relevant
architecture/physics changes.

#29 is **INT-000**, covering versioned non-kinetic intermaterial interactions rather than chemistry alone. Its infrastructure landed through PR #55 at
`910717aac101363ec2b1b89e4041a22bc9a97b97`; #30 remains a tracker, not an
execution gate. The [current interaction substrate](systems/intermaterial-interactions.md)
owns the implemented sparse schema, stable rule/channel/family IDs, native
provenance/coverage model and behavior-preserving compact-pair migration.
Generated schema-2 fixtures use the same Materials Laboratory/headless/A-B
contract, while specialized world.cpp mechanisms remain explicitly represented
but current-authoritative where kinetic separation is not clean. Later tuning is
separate bounded/versioned work. Kinetic/contact anomalies are captured/reduced
and routed to their real physics owner instead of being hidden in interaction rules.


## Scalable reversible soliding

The [current #12 programme](operations/soliding-programme.md) supersedes the bounded
Phase 0 endpoint. Read its [reuse audit](audits/2026-09-19-issue-12-phase0-reuse.md),
[lifecycle](architecture/soliding-lifecycle.md), [incremental discovery](systems/settled-region-discovery.md),
[ordinary-sleep control](operations/soliding-measurement.md) and current
[Stage 3 execution freeze](operations/soliding-stage3-freeze.md). The
[Stage-3 review](audits/issue-12-2026-09-19/stage3-exit-review.md) records the exact
passed Stage-3A bounded reference and the Stage-3B locality/scalability gate.

The active route is now the
[Stage-3B production plan](operations/soliding-stage3b-production-plan.md).
#56-#65 and #69 are complete; #65 landed through PR #106 as
`cdf0a0874d4732c41273e10d921bcd5feaac3e3c` with exact-head and landed-main
Documentation, Water, Native and GDExtension/Godot validation. **#66 is the next
dependency-ready Stage-3B implementation package**, followed by #67, #68 and the
registered #70 campaign/exit packet. Stage 4 is not admitted.
Macro-dynamics and coherent-child fracture remain first-class later goals; discovery
stays read-only with respect to material authority.
