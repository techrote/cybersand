---
title: Current-main integrated gameplay acceptance
status: Draft qualification record
document-kind: audit
scope: Exact-main source-matched Windows workbench acceptance after #406 integration
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../operations/play-desktop-manual-qualification.md, 2026-11-06-whole-engine-bench.md, 2026-11-06-stress-canvas.md]
---

# Current-main integrated gameplay acceptance

## Registered source

This campaign is pinned to accepted production `main`
`7e2c2fd1aa2759590d63d5dfb53ce9e4c0a76e4b` (tree
`9460c007eee2f3864cbb40d63800db3f85c0b858`), the merge of #406.
All six ordinary post-merge workflows on that commit passed before this
qualification branch was created.

The qualification branch may change only this audit, its dedicated workflow,
its GDScript observation harness and its small Python guard/summary tests.
It must not modify native physics, Main, the worker, Rapier ownership,
materials, solver defaults, built-in canvases, retained runtime binaries or
production launch behaviour. The workflow independently enforces that
boundary before building or executing anything.

## Objective

Establish one reproducible, source-matched Windows acceptance package for the
new current-main integrated gameplay baseline rather than treating isolated
component tests as gameplay acceptance.

The real production shared workbench is exercised through its existing
exclusive `CyberSimulationWorker`, native World, main-thread Rapier session,
immutable publications and built-in authored canvases. No synthetic second
World or replacement physics owner is introduced.

## Registered profiles

Each profile runs for 60 wall-clock seconds after construction is acknowledged
and ballistic impact spray is live.

| Profile | Canvas | Actors | Water solver | PF gas | Ballistic options |
|---|---|---|---|---|---|
| A | `my-canvas` | built-in Rapier barrels | PressureFlow `cached_dormant` | on | ballistic Water + face release + impact spray |
| B | `bench-canvas` | built-in eight barrels | PressureFlow `cached_dormant` | on | ballistic Water + face release + impact spray |
| C | `stress-canvas` | built-in eight barrels | PressureFlow `cached_dormant` | **off** | ballistic Water + face release + impact spray |

Stress-canvas deliberately uses gas-free PressureFlow because the existing
#406 evidence already identifies the 1,024 gas-compartment capacity as a
separate research boundary for that canvas. This is an explicit profile, not
a hidden fallback or a claim that gas-on stress is accepted.

## Evidence collected

The Windows lane freshly cross-builds the CyberSand GDExtension from the
qualification head after proving that all production source is byte-identical
to the registered main baseline. It authenticates the pinned LLVM-MinGW,
godot-cpp revision, official Godot 4.7 Windows archive and retained Rapier
runtime, then executes the graphical workbench with
`gl_compatibility/opengl3_angle`.

For each 60-second profile the package records raw and summary distributions
for:

- process and physics callback cadence and duration;
- native simulation time, worker-step time and snapshot-copy time;
- retained snapshot/render age and publication counts;
- main-thread workbench terrain-gate duration;
- hard-surface packet integer count and revision changes;
- completed native and Rapier rates and Rapier callbacks that did not advance;
- scheduler jobs/parallel phases/worker overruns;
- exact Water `total == expected` conservation observations;
- final ballistic/spray ledger and PressureFlow policy readback;
- an actual rendered Windows screenshot.

The complete artifact also retains the fresh Windows DLL and its SHA-256,
source identity, toolchain identity, raw JSON, CSV, console log, summary,
reproduction instructions and a SHA-256 manifest.

### Collider measurement boundary

Current main does not expose a source-isolated timing field for the full
hard-surface packet extraction stage to this production owner. This campaign
therefore **does not invent one**. It reports published packet size/revision,
the Main workbench terrain-gate callback, and an explicitly labelled
`worker_pipeline_residual_ms` equal to worker step minus native tick and
snapshot copy. That residual is not collider extraction and must not be
relabelled as such. PR #470 remains a separate optimisation/source question.

## Automated acceptance contract

Automated disposition is **REPAIR** if any registered profile:

- enters worker failure quarantine or fails to make native/Rapier progress;
- cannot retain approximately 60 seconds of evidence;
- reports any exact Water conservation mismatch;
- does not read back PressureFlow `cached_dormant`;
- fails to enable ballistic Water and impact spray or observes no body-driven
  spray activity;
- fails to produce a graphical screenshot;
- fails orderly exclusive-worker/Rapier shutdown.

Performance distributions have **no invented threshold** in this campaign.
Poor pacing remains evidence for an optimisation decision but is not silently
converted into a physics-correctness failure.

## Lockstep boundary

PR #474 is stacked on the separate #464 source line rather than current main.
It is therefore not a valid control for this exact-main acceptance package and
is not cherry-picked, substituted or used to explain away asynchronous
results. A future lockstep comparison must first reconcile that feature onto
the accepted baseline and run as a separately identified source arm.

## Human gate

Automated acceptance does not establish subjective feel, physical keyboard or
gamepad behaviour, focus/device handling or target-PC responsiveness. Those
remain under the existing desktop manual qualification packet. This package
provides a trustworthy baseline for that later human session; it does not
replace it.

## Execution status

Registered and dispatched from the dedicated qualification branch on
6 November 2026. Final exact-head workflow IDs, artifact hashes, measurements
and ACCEPT/REPAIR disposition are appended only after original hosted evidence
has completed and been inspected.
