---
title: MicroScenarios and intermaterial-interactions programme revision
status: Current
document-kind: audit
scope: Dated planning/RAG reconciliation that supersedes the earlier linear MicroScenarios sequencing without changing simulation semantics
canonical-for: []
last-reviewed: 2026-09-18
related-documents: [../operations/microscenarios-programme.md, ../reference/status-and-roadmap.md, ../operations/architecture-programme.md]
---

# 2026-09-18 MicroScenarios / interaction programme revision

## Trigger

The initial MicroScenarios planning pass treated the work too serially:
#18 -> #27 -> #20/#26 -> #14/G-final -> #28 -> #29. It also framed #29
primarily as chemistry.

Owner clarification on 2026-09-18 established three governing points:

- intermaterial work means material/material interactions **other than
  kinetic/material-motion physics**, not chemistry alone;
- many important edge cases are still unknown even though Sand/Water generally
  feel good; playable MicroScenario worlds should be used to discover them
  organically rather than postponing scenario work until physics is declared
  complete;
- GitHub issue number is not an intended serial-development indicator.

This audit records the planning reconciliation. It is not runtime evidence.

## Decision

The canonical
[MicroScenarios/intermaterial-interactions programme](../operations/microscenarios-programme.md)
now owns the programme-level dependency graph for #24/#27-#30.

Key changes:

1. #27/MS-000 may proceed once #24 launcher/input hygiene is present. It does not
   wait for #18 or #14/G-final.
2. #18 remains independent architecture research; #20 remains gated by #18/G-M
   plus its own G-B admission. MicroScenarios cannot satisfy those gates.
3. #26 remains independent and may use the common harness only where
   source-matched evidence remains valid.
4. #28 may create explicitly provisional exploratory worlds before G-final.
   Relevant later architecture/physics changes trigger targeted revalidation.
5. The #28 Materials Laboratory has a readiness checkpoint that can unblock
   #29 without waiting for Flood Control or Simulation Stress Test to finish.
6. #29 is renamed/reframed as INT-000 for non-kinetic intermaterial
   interactions. Planning/inventory may begin early; implementation uses the
   stable scenario-fixture contract and Materials Laboratory readiness.
7. Interaction acceptance uses rolling named kinetic/contact baselines rather
   than a single permanent "physics complete" gate.
8. The permanent discovery loop is explore -> capture -> reduce -> triage ->
   bounded fix/tuning -> retained regression -> return to the larger world.
9. Issue #30 is a tracker, never an execution prerequisite, and issue numbers are
   identifiers rather than ordering authority.

## Interaction-model consequence

INT-000 avoids dense manual N² authoring. It uses family/default rules,
per-material adjustments, sparse directed/symmetric pair overrides,
context/state modifiers, independent interaction channels, generated fixtures,
versioned tuning overlays, provenance and a coverage ledger. A dense resolved
runtime table remains an implementation option if measured useful.

Kinetic behavior such as density exchange, flow, support/bridging/bracing,
erosion/entrainment and collision/ballistics remains owned by the existing
physics systems. MicroScenarios may discover those defects but must triage them
to the correct owner.

## RAG synchronization performed

The revised rule is propagated through:

- root `AGENTS.md`;
- root README;
- development handover;
- documentation index;
- documentation-maintenance checklist;
- architecture programme cross-boundary;
- status/roadmap;
- product-intent reference;
- retrieval index and corpus;
- Experiment Tower runbook;
- Material Lab runbook;
- canonical MicroScenarios/interactions programme.

GitHub issue bodies #27-#30 are synchronized. The earlier MicroScenarios
sequencing comments on #14/#18/#20/#24/#26 were edited to the revised graph
rather than leaving contradictory instructions in place.

## Validation

Planning branch: `codex/microscenarios-programme`, PR #31.

On branch head `870d33f1b41a1e02f0163d6af00d64582a80abf8`, GitHub Actions run
`35393103042` (**Documentation and provenance**, run 62) completed successfully.
Its consistency job passed:

- current documentation/pins/runtime-provenance validation;
- retained M11 verification;
- validation-failure-contract tests;
- current retrieval-route evaluation;
- Git LFS and whitespace checks.

This success predates this audit-only commit; the final PR head must retain a
green documentation workflow before merge. Native/Godot workflows are allowed to
run normally even though this planning revision changes no simulation code.

## Non-effects

This revision does not select or alter a Cell layout, Water model, compact
history, sparse ballistic representation, granular/contact solver, material
reaction tuning, Rapier authority, save/replay contract or historical runtime
evidence. Existing architecture gates keep their own authority.
