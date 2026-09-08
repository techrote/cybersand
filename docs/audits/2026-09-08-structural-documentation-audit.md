---
title: Structural documentation rewrite and readiness audit
status: Current
document-kind: evidence
scope: Dated documentation-only rewrite following source checkpoint 126175c, with retrieval evaluation and focused source diagnostics
canonical-for: []
last-reviewed: 2026-09-08
related-documents: [../README.md, ../reference/status-and-roadmap.md, ../operations/documentation-maintenance.md, 2026-09-08-retrieval-evaluation.md, 2026-09-08-foundation-diagnostics.md]
---

# Structural documentation rewrite and readiness audit

**Scope: 2026-09-08 documentation checkpoint.** This follows the
[first factual audit](2026-09-08-documentation-audit.md), which remains unchanged.
Simulation, adapters, dependencies, workflow configuration and runtime binaries
were not modified. New executable files are documentation structure/retrieval
checkers; standalone diagnostics stayed outside implementation source.
This record is excluded from ordinary current-answer retrieval.

## Source checkpoint and coverage

The acquired branch base is `e2892c54d4bd91aac60971e81c748bd49fbe2adb`.
The actual upstream history was recovered without checking files out over local
work. Existing source changes and the first audit were committed locally as
`126175cfc4dd1fb8659212f62b9b517bac54d8c2`, on `codex/rag-docs-foundation`.
The companion workspace has its own local repository, initially
`b179dbb361681c3575b07b9d6b1769cc168747b1`, for guides and wrappers.
`C:/kybersand/SOURCE-CHECKPOINT.json` records the completed source documentation
checkpoint; the containing commit identifies this report's final documentation.

The owner confirmed a USB backup and asked to stop looking for it. It was not
inspected. An existing local capture verified 740 restored file hashes; ignored
tools and generated outputs have separate coverage. Git and required local LFS
objects secure a source checkpoint, not every platform/toolchain. Fourteen
other-platform payloads remain pointers. See the [checkpoint contract](../operations/source-checkpoint-and-recovery.md).
Nothing was pushed, published or delivered.

## Major structural and factual corrections

- Replaced repeated inventories and generic prologues with focused canonical
  contracts, decision rationale, operating guides and references. Each selected
  page declares title, kind, scope, status, review date, unique topic ownership
  and related documents. Navigation routes questions; it does not repeat answers.
- Added canonical homes for source identity, build freshness, level saves/replay,
  dated validation, product intent and documentation maintenance. The handover is
  a short onboarding route. Constants, interfaces and invariants retain their
  useful detail, including all 75 existing invariant IDs and new `TIME-002`.
- Separated actual native authority, desktop GDScript ownership and synchronous
  Web ticks. Native pthreads do not permit concurrent Web drawing during a tick;
  scene-tree/Rapier access remains main-thread work. Character order, terrain
  gating and error handling differ between platforms.
- Clarified separate body masks, bounded translated/rotated rectangle sweeps,
  Rapier hard-contact ownership and the limits of terrain budgets. The measured
  three-body thin-floor fixture is not a general zero-penetration or shape proof.
- Distinguished fixed CYSD1 levels, content hashes, state hashes and exact replay.
  Save export needs exclusive ownership and clears the transient mask; complete
  configuration, tick/activity/events and Rapier continuation state are absent.
- Corrected stale fallback adaptive-stride claims, first-64-world-tick Smoke
  grace, material-specific cadence including Ice's 16-tick lane, and incomplete
  eventual-wake behavior. Native and fallback Water remain distinct.
- Distinguished lazy tick allocations from prepared-fixture allocation goals;
  capacity failure is not atomic rollback. Recorded the reproduced region
  re-entry and partial-tick defects without implementing a speculative fix.
- Preserved historical performance/checkpoint tables in explicitly scoped records.
  Source/build identities and dated native/headless/browser/checksum evidence
  are separate. The old no-Git finding is historical after the new checkpoint.

## Retrieval evaluation

The [evaluation report](2026-09-08-retrieval-evaluation.md) records the frozen
32-question development set, identical heading-chunk/BM25 method, before/after
metrics, per-question expected-fact review and disclosed refinement iterations.
Two additional questions cover newly discovered defects and are scored separately.
Canonical route hits are not treated as complete answers. No embedding backend,
held-out set or production answer-generation system was tested.

Final metrics are in that report and its machine-readable evidence; they are not
duplicated here so this historical summary cannot become a competing metric owner.

## Checks and evidence

The [curated check record](2026-09-08-structural-documentation-checks.json) includes
commands, outcomes and preservation hashes. Checks performed:

- Current metadata, canonical ownership, explicit corpus coverage, local links,
  heading anchors and frozen question references; companion workspace links too.
- Valid and intentionally invalid fixtures for the new structural checker.
- Repeatable lexical retrieval with complete top-five context review, plus the
  separate failure/re-entry challenges.
- `git diff --check` and `git fsck --full` for source and companion repositories.
- Existing-source comparison: all 205 pre-existing non-Markdown files remain
  byte-identical to the first audit inventory; aggregate SHA-256 remains
  `0f07e1029418c0bca47a66f6c75b088a42f2871448794f9be2ca3971e1957b52`.
- Fifteen historical records have unchanged content against checkpoint 126175c.
  Fourteen match Git blobs byte for byte; the first audit JSON retains CRLF while
  Git serializes LF. It was not rewritten. No release hash/result was updated.
- The M11 checker **fails with the same seven historical source/hash mismatches**;
  its independent document/link checks add no failures. A red historical checker
  is reported, not hidden by replacing old hashes.
- Two fresh Windows source-built diagnostics confirm interest re-entry and
  partial tick failure; [methods/results](2026-09-08-foundation-diagnostics.md).

The earlier factual audit compiled/reran 39 native tests and ran 15 Godot fixtures
on Windows with the retained DLL; those dated results remain in the
[validation ledger](../reference/validation-evidence.md). They were not counted
again as new rewrite runs. No new browser, cold extension rebuild, Linux sanitizer
or visual acceptance was performed for this documentation-only change.

## Remaining contradictions and next recommendation

The documentation is ready to guide **bounded foundational checkpoints**, with
explicit uncertainties. The simulation is not cleared for broad physics expansion.
First resolve failed-tick recovery and region re-entry with focused regressions.
Then decide common ordering, force/field units, approximation controls and replay
inputs needed by the first physical increment. The [roadmap](../reference/status-and-roadmap.md)
records F01–F08 and their narrow next checks.

Web CI still selects 4.0.11 while the builder requires 4.0.20, omits the separate
native binding argument, and uses compile-only where runtime coverage is implied.
The historical template lock and wrapper's base-only export identity also need
a separate tooling checkpoint. Current Linux/other architectures, Firefox/Safari,
complete replay and general-shape/high-count coupling acceptance remain absent.

Keep this hierarchy and improve it incrementally rather than rewriting it again.
The strengthened [maintenance checklist](../operations/documentation-maintenance.md)
and PR template require affected-document mapping, source/evidence identity,
status/platform reconciliation, reverse-link searches and retrieval checks.
The new checks are locally runnable; wiring them into CI is separate follow-up work.
Before selecting a production RAG system, test unseen questions and the actual
retriever/answer generator. The current development-set result is a useful baseline.
