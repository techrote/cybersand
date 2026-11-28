# Strata admission investigation — unchanged performance gate

## Decision

PR #776 at `410ac8e5e613b1454928699dbc9a68cd035f0894` remains an unmerged, owner-pending integration candidate. This review preserves the **45-second cold scene-admission failure**. It does not alter Strata or PUBPRES source, relabel the failed target, or infer physical performance from hosted software rendering.

The original functional application is `934cc0c0eef70dad528155e9a92eebe25e2757eb`. Run `45509477752` retains its source Linux, source Windows, and actual extracted Windows application evidence. All three original functional campaigns completed 28 cases; performance acceptance is a separate gate.

## What the existing measurements establish

| Scene | Extracted Windows cold admission | Reopen | Three decorative Worlds: construction and first snapshots |
|---|---:|---:|---:|
| orbital-terminal | 51.619 s | 8.881 s | 0.275 s |
| neon-rain-arcology | 66.316 s | 8.891 s | 0.355 s |
| industrial-underworks | 66.200 s | 7.636 s | 0.186 s |
| abyss-foundry | 59.958 s | 7.622 s | 0.178 s |
| vertical-transfer-spine | 54.804 s | 7.706 s | 0.236 s |

The existing owner diagnostic records only 0.178–0.355 seconds for constructing all three decorative native Worlds and taking their first complete material snapshots. Every scene remains at owner generation 1 with zero retired Worlds. The source assigns this timer only during `LayerOwner.prepare`, so the retained value belongs to initial construction. This measured phase is less than 0.7% of each cold admission: changing native decorative World construction cannot, by itself, explain or repair the tens-of-seconds deficit. The timer excludes preceding document validation, presentation surfaces, and ordinary Play admission.

The same source's original Windows checkout recorded 31.849–40.047 seconds for cold installation, while its extracted Windows evaluator recorded 51.619–66.316 seconds. Source Linux recorded 14.290–15.238 seconds. These are different executions, not a controlled package-overhead experiment. The existing evidence does not identify a single causal bottleneck or establish that packaging caused the difference. Whole-case CPU/RSS and callback samples include other work and cannot be substituted for phase timings or physical presented FPS.

## Source boundary map

The qualification admission timer begins immediately before `strata.load_demo` (or ordinary `load_setup` for reopen). It ends only after Workbench idle, document adoption, and ordinary physical actor session readiness. Initial 512-cell ordinary startup precedes the timer; later captures, hash comparisons, editing, movement, and Save follow it.

Cold installation performs `Scenes.make` recipe acquisition and validation, `load_document` setup/document validation, private decorative preparation, copied packets and texture/presentation preparation, then `wb.apply` through the existing ordinary Play owner. That ordinary path validates the setup, converts authored stamps through `Setup.rectangles`, prepares native Play and physical definitions, and adopts them. Strata commits its decorative candidates only after ordinary Play acknowledges. These ownership boundaries should remain intact.

A concrete redundant operation exists in `Scenes.make`: it reads and validates the source recipe, then calls `metadata(id)`, which reads and validates the same recipe again, including geometry provenance hashing. Returning metadata from the already validated object could remove repeated acquisition and preserve a single read identity. No isolated timing currently shows that this accounts for a significant part of the failure; it is not represented as a proven performance remedy.

## Next controlled experiment

Capture separate elapsed times for recipe acquisition/validation, decorative native preparation, texture/presentation preparation, ordinary rectangle preparation, native Play preparation, and acknowledgement/adoption on the exact frozen source. Compare the ordinary generated-start/material-baseline reopen path with cold authored recipe admission. Retain the same five scenes, source/runtime identities, original failed evidence, 45-second target, actual extracted Windows package, and renderer identification. Then repair a measured phase and qualify the resulting source and actual package.

This sequence does not require importing or altering the active PUBPRES comparison branches. Any later change in ordinary Main, SimulationWorker, or publication ownership requires explicit coordination with that programme. No speculative rendering or scheduling rewrite is proposed here.

## Evidence custody and owner queue

The machine record preserves all 15 original admission/construction rows, original report hashes, exact inspected source file hashes, and the source of every derived observation. Full originals remain in #776's existing audit and campaign records. The historical evaluator is artifact `14978334114` from run `45509477752`; inner ZIP SHA-256 `1a619b8b9c6af51529517f1609b457a7f25ed727deccbac8cd92269c7c23a547`, 208,785,019 bytes. It is a frozen feature evaluator, not an accepted-main build. Physical Windows/NVIDIA appearance, real input response, movement, aesthetic acceptance, and the failed admission-performance gate remain outstanding.
