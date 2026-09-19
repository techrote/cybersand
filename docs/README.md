---
title: CyberSand documentation
status: Current
document-kind: navigation
scope: Entry routes and authority rules for the focused documentation hierarchy
canonical-for: []
last-reviewed: 2026-09-18
related-documents: [reference/retrieval-index.md, reference/status-and-roadmap.md, operations/documentation-maintenance.md, operations/microscenarios-programme.md]
---

# CyberSand documentation

## Choose a reading route

| Need | Start here |
|---|---|
| Author, load or benchmark a MicroScenario | [Current shared contract and host](operations/microscenarios.md), [checkpoint evidence](audits/2026-09-19-issue-27-microscenarios.md) |
| Begin development | [Handover](operations/cybersand-codex-development-handover.md), [actual source identity](operations/source-checkpoint-and-recovery.md), [roadmap](reference/status-and-roadmap.md) |
| Choose current MicroScenarios / interaction work order | [Canonical programme graph](operations/microscenarios-programme.md), then the target issue and its named dependencies; issue numbers are not sequence |
| Understand the engine | [Architecture overview](architecture/overview.md), then its focused ownership/threading/coupling links |
| Answer one technical question | [Retrieval index](reference/retrieval-index.md) |
| Change a material | [Rule kernels](systems/materials-and-rule-kernels.md), [Water](systems/water-design.md), [material lab](MATERIAL_LAB.md) |
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
the Current H-ready four-level presentation and deterministic runtime Water-policy
apparatus. The later human H study has not run; no production precision, packing,
#18/#20 admission or G-final decision follows from #19.

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

#29 is **INT-000**, covering versioned non-kinetic intermaterial interactions
rather than chemistry alone. Its authoring model is sparse/layered with generated
fixtures and retained tuning-pass provenance. Kinetic/contact anomalies discovered
in MicroScenarios are captured/reduced and routed to their real physics owner
instead of being hidden in interaction rules.


## Scalable reversible soliding

The [current #12 programme](operations/soliding-programme.md) supersedes the bounded
Phase 0 endpoint. Read its [reuse audit](audits/2026-09-19-issue-12-phase0-reuse.md),
[lifecycle](architecture/soliding-lifecycle.md), [incremental discovery](systems/settled-region-discovery.md),
[ordinary-sleep control](operations/soliding-measurement.md) and current
[Stage 3 execution freeze](operations/soliding-stage3-freeze.md). The
[Stage-3 exit review](audits/issue-12-2026-09-19/stage3-exit-review.md) records the
exact integrated candidate, frozen checklist and retained negative cost evidence.
Macro-dynamics and coherent-child fracture remain first-class staged goals; Stage 3
keeps producer/connectivity read-only with respect to material authority.
