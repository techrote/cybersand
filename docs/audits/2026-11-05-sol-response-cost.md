---
title: SOL chamber response-generation and observation cost
status: Planned
document-kind: evidence
scope: Prospectively registered unchanged-physics timing refinement dependent on Draft411; no original SOL authority or CPU acceptance
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [2026-11-05-sol-chamber-yielding.md, ../operations/local-build-and-validation.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# SOL chamber response-generation cost — 5 November 2026

Root alone owns `codex/sol-response-cost-20261105`, based on Draft411
`b424032b925fd890421d3e94ed0524988445b5fb`; no upstream branch is edited.
The [prospective48episode profile](../../godot/tests/fixtures/sol_chamber/cost-001.json)
is committed before instrumentation or execution. It is a new timing experiment,
not a revision of the old192episode physics comparison or25case value diagnostic.

The original four-stage subtotal ends native timing before
`workbench_coupling_results()`. That getter includes the passive contact solve
and serial response construction. Whole-step time includes it, but the stage
subtotal cannot qualify its cost. The new test-only apparatus times this getter
and statistics capture explicitly. No native84 input or compiled binary changes.

The fixed matrix uses closed unforced/driven cases, LA-SELECTIVE, requested
workers1/4, actual Windows/Linux, three repeats and full/minimal observers.
All body, material, force, application, cadence and export inputs stay fixed.
Only intermediate per-cell census work is removed in the minimal observer.
Body/owner/revision/failed records remain at every boundary; full initial/final
census and the original CYPS export schedule remain. Minimal observations do
not replace the original complete geometry audit.

Matched observer trajectories and initial/final full payloads must agree before
their timing difference is interpreted. Shared-host timing, one-participant
results, mismatches and failed work remain explicit. No performance threshold,
original24group SOL CPU gate or universal60Hz claim is introduced. Source-archive,
material authority and original SOL ownership/clearance failures remain binding.

Linux/Windows runtime overrides are the existing authenticated source-equivalent
builds, separately materialized from the chamber lane with their original build
receipt; they are not newly compiled here. Four canonical Native/Rapier LFS
payloads are materialized. Five companion files retain pinned workspace source
`a15e06ca6f37750b66b89936424e0d018b203f7b`. Results and exact commands will be
added only after execution. Keep any publication Draft and dependent on411;
independent adversarial review must precede owner admission.

The first Windows smoke at `b21d7727` imports cleanly but both full/minimal
episodes exit1 at coordinate validation, before body construction or any native
tick. The complete failed receipt/logs remain in `build/sol-response-cost/initial`.
An actual Godot type probe at the same source exits0 and records parsed numeric
type3, `Array.has(1)==false`, `Array.has(1.0)==true` for JSON workers `[1,4]`.
The [separately registered apparatus correction](../../godot/tests/fixtures/sol_chamber/cost-apparatus-002.json)
changes only membership validation's number type. It does not change requested
workers, physical inputs, observers, measurement windows or any threshold.
