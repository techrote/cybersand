# SOL364 hosted synchronized physical review

**Execution is verified; physical recovery remains NO-GO.** All four synchronized reports from run [41815817333](https://github.com/techrote/cybersand/actions/runs/41815817333) identify source `9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d`, tree `b5baf8b23ff947c2d7b70e69745c10f18fbe9ebe`. Linux and Windows each executed workers 1 and 4, with 21 cases and 180 Rapier steps per case. The four processes passed 33,352 apparatus assertions. Their 84 physical cases retain **84 sustained-clearance failures and 64 depth-limit failures**.

The complete numerical review is [physical-review.json](physical-review.json). It retains every case's statistics, physical-gate decisions, initial/final state, actual runtime identity, raw-report hashes, input-manifest custody, portable artifact members and intended repository publication paths. The review reopens the complete canonical reports; concise console footers are not substitutes for trace evidence. This review was performed by the synchronized apparatus author. Separate independent implementation/geometry/concurrency reviews remain separately identified.

## Scope and provenance

The native field is held after one real initialization tick and the exact native 520-cell handoff. Native material integration and ordinary conservative displacement do not advance during these synchronized runs. The same six occupied proxies, mass, center of mass, inertia, crown hole and open concavity are retained. Real Rapier manual integration runs at a declared 1/60-second step, with zero external gravity/damping and sleeping disabled identically in every arm. No positional correction is applied.

The three arms are the additional Sand response disabled, the exact frozen pre-repair velocity planner, and the current reclip planner. Their initial states and native material fields match within each fixture. Every received contact is also evaluated by both planners on identical frozen inputs and the same present body state. Later evolving trajectories are not falsely called identical contact histories once response changes their state.

There are **15,120 authenticated after-step geometry observations**, or **15,204 including the 84 initial observations**. Cell-ticks and area-cell-ticks are appropriate here because no declared step is omitted. Deterministic dropped/delayed receipt does not suppress geometry measurement. These are not asynchronous worker scheduling or the original contact CPU cohort; elapsed synchronous diagnostic timings must not substitute for that cost gate.

The historical embedded pose is reused with deliberately zero velocity over an authored frozen native field. Unrecorded historical material cells are not reconstructed. This is a controlled causal test, not a claim to reproduce the entire historical asynchronous trajectory.

| Actual host | Executed native SHA-256 | Compiler |
|---|---|---|
| Linux | `de38c0de458b2a30d43cb36c633cb7ee3b469f8d84f7a3e512fafc9838bb82a5` | GCC 13.3.0, Ubuntu `13.3.0-6ubuntu2~24.04.1` |
| Windows | `a5e616c0e72eee56c84f66151499d401dd3f4fb7faab347adbc6335493fefd61` | Pinned LLVM-MinGW Clang 23.1.0 |

The Windows DLL was cross-compiled; the separate actual Windows MSVC native-suite result must not be confused with its toolchain. The local development native `a013…` receipt was not substituted for these hosted reports. Godot, Rapier, bindings, build manifests and complete checked-input inventories are identified in the JSON review.

## What the executable controls establish

**Interior embedding can produce area without an exterior witness.** The supported 3×3 Sand pocket has 9 cells squared of intersection when entirely inside an occupied proxy and zero exterior contact records. A separate source pose over the same native content places that pocket across a face and yields three valid contacts. This distinguishes missing exterior geometry from unsupported fresh Sand. The exact aggregate payload remains exclusively owned. The control preserves native semantic content and material cells; the full activity hash changes because changed transient masks legitimately wake scheduler metadata.

**A valid stationary contact still cannot be cleared by velocity-only dissipation.** The retained embedded pose stays at depth 2.532470619 cells for all 180 observations in all three arms. It records 10,620 overlap-cell-ticks and 6,867.398755 Sand-area-cell-ticks. Both response arms accept all 180 observations, yet apply zero impulse and do zero correction work. There is no missing/stale publication or witness refusal to blame in this stationary case. A dissipative velocity response has no mechanism to remove stationary burial.

**The transported-midpoint defect is real and the bounded reclip corrects it.** The original witnessed segment retains a positive current length of 0.0625 cells even though its transported old midpoint exits the observed cell. The old planner returns `ClearedContact`; the current planner accepts the surviving authenticated segment under the existing 0.25-cell pose-drift fence. This control preserves the original segment and does not broaden it to an entire face or manufacture a new material witness.

**Early packed overlap also reflects the unchanged support eligibility rule.** In every hosted configuration, packed impact steps 1–19 have positive observed overlap with zero eligible contact records. The first recorded contact geometry appears at step 20 and first applied impulse at step 21. The frozen material table proves that each first-column Sand cell at `(54,58)` through `(54,64)` sees the footprint `[[Empty,Sand,Sand],[Empty,Sand,Sand],[Empty,Sand,Sand]]`. Its maximum possible stable support count is six, below the existing threshold of eight. This upper-bound proof requires no assumption about Sand update epochs. These early observations must not be mislabelled publication delay or transported-midpoint rejection. The rule is unchanged; this review does not authorize a GCR/material policy change.

**Latency and refusal remain independently visible.** With a one-step delay, reclip changes 167 accepted responses plus 12 `ClearedContact` refusals into 178 accepted responses plus one refusal. The eleven additional accepts have zero impulse on the evolving response trajectories, so depth and motion do not improve. With a two-step delay, both response arms reject all 178 delivered observations as stale, following two explicit missing receipts; their motion matches the awake response-disabled control. Every geometry step is still measured.

## Physical comparison across all four configurations

Ranges below include Linux/Windows and workers 1/4. No registered threshold has been adjusted.

| Fixture | Response disabled: maximum depth | Frozen velocity control | Current reclip | Sustained clearance |
|---|---:|---:|---:|---|
| Stationary embedded | 2.532470619 | 2.532470619 | 2.532470619 | Failed in every arm |
| Packed impact | 2.499954224 | 1.003701264 | 1.003709053–1.003709107 | Failed in every arm |
| Off-centre impact | 2.499954224 | 1.003701264 | 1.003709053–1.003709107 | Failed in every arm |
| Rotated compound | 4.145154436 | 2.635964969 | 2.635964969 | Failed in every arm |
| Every fourth receipt dropped | 2.499954224 | 1.003875433–1.003889339 | 1.003883788 | Failed in every arm |
| One-step delayed receipt | 2.499954224 | 1.072706997 | 1.072706997 | Failed in every arm |
| Two-step stale receipt | 2.499954224 | 2.499954224 | 2.499954224 | Failed in every arm |

All 84 cases have positive overlap on all 180 after-step measurements. None starts a sustained-clearance window, so recurrence is **not evaluable**; this is not a recurrence pass. The stationary cases and the two resisting rotated arms satisfy their initial-depth-plus-0.25 limit. The other 16 cases per configuration fail their declared depth gate.

The current packed response limits maximum penetration relative to the disabled control, but its peak slightly exceeds the new one-cell bound and is slightly greater than the frozen planner's peak. Its residual final Sand depth is about 0.6537 cells. It travels about 7.2188 cells instead of 8.9998, and rotates about 0.30656 radians. These are measurable resistance and torque, not sustained nonpenetration.

For rotated impact, the current response travels about 0.5781 cells instead of the disabled control's 9.0005, dissipating about 2328.5827 of the initial 2340 kinetic-energy units. Nevertheless it finishes with approximately 45.943 cells squared of Sand intersection and 2.62189-cell depth. Angular velocity remains finite, with maximum magnitude about 0.014572 radians/second, and the registered zero-work energy guards pass. Strong dissipation does not clear existing burial.

## Refusal regression and cross-host differences

The rotated current planner accepts only **20/180** observations, refusing **159** as `NonDissipativeResponse` and **one** as `InvalidGeometryWitness`. The frozen velocity control accepts **95/180**, with **85** nondissipative refusals. This regression is reproduced on both operating systems and both worker configurations. These are safe pre-application refusals; there are no actual post-application readback/energy violations. The larger refusal count remains a blocker and is not hidden behind lower total area.

Worker counts 1 and 4 produce identical recorded state/geometry trajectories within each operating system. Cross-platform raw JSON state equality holds for eight of 21 cases. Seventeen of 21 actual float32 RID-state trajectories are identical after restoring the serialized numbers to their native precision: for example, the stationary y coordinate is printed as `41.5955200195312` on Linux and `41.5955200195313` on Windows, both representing the same float32 value.

Four trajectories retain small real float32 differences: current packed, current off-centre, current rotated, and the frozen control with dropped publications. The largest cross-platform differences are approximately 0.0000353 cells/second in linear velocity, 0.00000527 radians/second in angular velocity, 0.000362 cells in reported proxy corners, and 0.0001811 energy units. The frozen dropped-publication arm has three nondissipative refusals on Linux and four on Windows. No physical pass/fail disposition changes. The JSON preserves exact ranges, per-case differences and descriptive standard deviations; four platform/worker configurations are not presented as repeated-trial uncertainty estimates.

## Disposition and bounded next action

The reclip is a qualified witness correction. It is **not an accepted persistent-penetration recovery solution**. Complete execution, conserved ownership and dissipative readback do not override 84 clearance failures, 64 depth failures, or the rotated refusal regression.

The next bounded contact task is to register one aggregate-side current-pose penetration-recovery constraint for the already-embedded, zero-velocity case. Its correction-work budget, exact compound/holes witness, refusal conditions and convergence must be explicit before implementation. Use the same stationary and delayed replay controls to determine whether it can clear burial without uncontrolled work or duplicated ownership. Do not obtain clearance by relaxing support eligibility, changing the material law, widening native relocation, weakening energy/CPU gates or promoting Y1. No such recovery change is made by this review.

The original 24-group asynchronous CPU gate and current publication/documentation disposition remain separate records. This physical review makes no claim that those gates passed, and no claim of graphical acceptance or representative GPU pacing.
