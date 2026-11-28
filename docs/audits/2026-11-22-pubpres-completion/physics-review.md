---
title: PUBPRES completion physics and native evidence
status: Historical
document-kind: audit
scope: Workbench hold-clock and causal admission evidence, Wave stage profiling, two unselected optimizations and an allocation overlap observation
canonical-for: []
last-reviewed: 2026-11-22
related-documents: [../../operations/pubpres-playability-evaluation.md, ../../architecture/simulation-tick-and-threading.md, ../../architecture/rendering-and-gameplay-bridges.md, ../../architecture/wave-flow-v1.md]
---

# PUBPRES completion physics and native evidence

The 22 November physics checkpoint for [Draft #757](https://github.com/techrote/cybersand/pull/757) corrected the 150 ms held-publication test and verified an opt-in native-to-Rapier trace. Two later continuation placements and two native Wave optimizations remained unselected. The original [#682](https://github.com/techrote/cybersand/pull/682), [#719](https://github.com/techrote/cybersand/pull/719) and [#740](https://github.com/techrote/cybersand/pull/740) results retain their original scope. Final source-matched graphical and physical Windows/NVIDIA acceptance remained HOLD at this checkpoint.

## The historical Windows hold failure

The [installed Windows run 44785110041](https://github.com/techrote/cybersand/actions/runs/44785110041), artifact `14655293403`, recorded two callbacks after the old observation baseline where the fixture required three. The installed payload declared `1f04f2ad34097899aeeb53138cfab2812d8e3131`. The physics-publication and rendezvous fixture files had the same bytes as frozen #719 `d316c281e0abb575eb6302afc12ec44f211460ba`.

The worker reported hold start at 47,853,050 µs and full handoff at 47,905,013 µs. Their 51,963 µs interval is an upper bound on the actual hold because release precedes handoff. Seven genuine catch-up rendezvous calls occurred within those boundaries. The combined control admitted zero physical steps. The independent early-publication control admitted exactly one. The old trace omitted timer creation, first decrement and release clocks.

The pinned Godot 4.7.0 engine computes the process delta at iteration start, runs physical catch-up, then enters SceneTree process. SceneTree emits `process_frame` before it services process timers. A timer created from that signal can consume the entire precomputed delta immediately. The retained minimal reproducer uses the exact `5b4e0cb0f` engine commit with `--headless --path timer-phase --script res://phase.gd`. After 175 ms of deliberate pressure in a preceding process frame, a new 150,000 µs SceneTree timer charged 142,284 µs in its creation frame and expired with two actual callbacks after 33,460 µs of wall time. Repeats with 200, 225 and 250 ms of preceding pressure expired with two callbacks in 33,365, 33,363 and 33,414 µs. [Godot iteration](https://github.com/godotengine/godot/blob/5b4e0cb0f/main/main.cpp#L4917-L5059) · [SceneTree process and timers](https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/main/scene_tree.cpp#L684-L815)

The revised fixture measures the same 150,000 µs against the worker's actual monotonic hold start. It counts an engine callback only when both its start and completion fall within that window. It records late observation and release separately, retains the original worker watchdog, and preserves the legacy process-timer reproducer under `CYBERSAND_TEST_LEGACY_PROCESS_TIMER=1`. The independent-publication assertion counts matching physical steps through release. In an adversarial run capped at four process frames per second, both 150 ms windows contained zero eligible callbacks and both assertions failed, even though Main first observed the deadline after roughly 239 ms and 237 ms. The overall run still checked independence, pause, exact terrain and retirement.

## Causal trace and real physics qualification

The local guard application uses integrated base `5ecdc3ca97aaa862e842cee767b81c52927a24da` with the recorded GDScript-only changes and that base's freshly built, source-matched native runtime. The exact engine and runtime hashes, test deltas, startup receipts and original failed attempts are in the archive index. Elapsed test safety watchdogs and physical elapsed thresholds have distinct purposes.

| Actual native/Rapier gate | Result |
| --- | --- |
| Physics publication with continuation Off and On | 64 checks each. Combined held zero admissions and independent publication admitted exactly one |
| Bounded native rendezvous | 121 checks, including actual engine catch-up, expired wait budget, pause and owner retirement |
| Same-frame continuation | 52 checks. Positive case advanced once. Cancelled, paused and expired cases advanced zero times |
| Causal trace Off | 13 checks and zero added producer phases |
| Causal trace On, early and combined publication | 57 checks and eight complete sample joins per mode |
| Intentional 4 fps starvation | Expected failure. Zero completed callbacks qualified within either hold window |

The producer test verifies real Workbench `PackedFloat64Array` sample acceptance, exclusive-owner latch, coupling preparation, native execution, feedback capture, final native health observation, and immutable publication. Exact World, session, epoch, sample and required collider revision join the packet to a genuine manual Rapier completion with validated feedback and zero pending terrain chunks. Earliest handoff follows actual native completion and precedes Rapier. An idle status publication may repeat the completed sample. The trace retains its first healthy handoff for age calculations. The additional producer and Main clocks are selected explicitly with `CYBERSAND_DIAG_PHYSICS_CAUSAL_TRACE=1`. The trace has no authority over sample admission or physical execution.

The [frozen #719 campaign](https://github.com/techrote/cybersand/actions/runs/44963596029) yielded 1,000 `native_sample` refusals across both paired ON arms of four large-Wave cohorts. The old helper's entry attempt preceded the earliest matching healthy packet in all 1,000 cases. Main had already returned in 944. The 56 packets available within the entire Main callback all required a changed terrain revision. The 12 additional contended attempts also led to changed terrain. Extending the optimistic counterfactual to associated inline post-draw delivery produced at most 13 eligible exact-terrain timings, seven across the 607 current-gameplay attempts. Those are upper bounds on time opportunities. The captures do not establish unchanged input and lifecycle identity at a proposed later hook. No later poll or extra callback credit was selected.

## Current-gameplay Wave native comparison

The candidate removed redundant false and zero stores from the strip-owned clean and dry flags. The column, flux and apply barriers and every Water operation were preserved. An earlier [#740 native investigation](https://github.com/techrote/cybersand/pull/740) measured 7.93% lower Wave column time in its local paired run. This checkpoint rebuilt exact control A and candidate B with the same local GCC 14.2 toolchain, pinned godot-cpp, Godot 4.7.0 and Rapier 0.35.2. The application and observer files have identical bytes. The only one of 105 native input files that differs is `native/src/world_wave.inc`. Both resulting binaries independently reproduce the earlier D0 and C1 binary hashes.

| Arm | Source commit | Native runtime SHA-256 |
| --- | --- | --- |
| A, control | `0725114fdf569c6efc372d8f8397b4efbca6ff06` | `a842d77977644ea330d826710ac7cf50a7b1150f0e8b65a27101e481e73b06ae` |
| B, conditional stores | `bba15f802058dcb2d8d0fb022c1b4eecbf94a9f7` | `f4b4ab71d4900a9244d76253cf5294f774b6e15a70ebb181fef50b660f44ca71` |

Both versions passed all 48 native Wave spill cases. All 24 exact live World checkpoints match across 1, 2, 4 and 8 worker requests, including negative coordinates, a bounded viewport interruption and re-entry. The fixture independently scans stored Water, checks the parcel pool, and compares visible, overfill and ballistic ledger closure. It exercised real parallel workers and ballistic launches.

The matched diagnostic ran all eight fresh processes sequentially from 21:06:30 to 21:09:28 UTC. The 2048 Follow fixture observed four distinct task-claiming participants and the 512 Free control observed one. Both use `gameplay_main846f`, two Wave rounds, spill and ballistic transport, the same recorded Needle input tape, fixed Rapier steps and identical camera mode within the cohort. The historical one-round fixture remained a separate workload. Every arm completed 144 unique actual Rapier steps and matched its cohort's exact body trajectory, admitted moves, Water ledger and terrain sequence.

| Fixture | Run | Mean column ms per native tick | Native median ms | Native p95 ms | Actual steps/s | Physical gap p95 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Wave2048 Follow | 0-A | 45.849 | 99.760 | 104.566 | 11.668 | 117.617 |
| Wave2048 Follow | 1-B | 45.999 | 98.470 | 105.513 | 11.715 | 117.366 |
| Wave2048 Follow | 2-B | 46.206 | 99.613 | 107.179 | 11.603 | 118.097 |
| Wave2048 Follow | 3-A | 42.216 | 87.941 | 95.762 | 12.962 | 116.466 |
| Wave512 Free | 0-A | 7.389 | 11.505 | 12.691 | 59.622 | 16.815 |
| Wave512 Free | 1-B | 7.331 | 11.618 | 12.888 | 60.046 | 16.948 |
| Wave512 Free | 2-B | 7.438 | 11.393 | 14.334 | 58.026 | 17.142 |
| Wave512 Free | 3-A | 7.481 | 11.635 | 12.837 | 58.808 | 16.884 |

The 2048 candidate's two run means average 46.102 ms versus 44.032 ms for A, a 4.70% increase. The 512 means differ by 0.68%. The new evidence does not reproduce the previous favorable large-fixture signal, so the conditional stores were left out of the selected candidate. Reported phase means use existing cumulative native counters divided by 144 exact completed ticks. Each tail describes its own run. Steps/s uses actual Rapier completion timestamps from capture start. These local headless diagnostic runs characterize native execution and physical sequencing. Graphical throughput and owner playability require separate qualification.

## Wave gather and scatter isolation

An isolated profiling build added clocks to each admitted column on the unoptimized A source. The source is `02277c2ef307a03320843b11855056ea8fd89a6d`, tree `f6c06b5005cd4b9840e7224d50929f36da835ad7`, with Linux runtime SHA-256 `d591098a761400ba1f20b1b8ad35f0e927b8f7cfe4cc5e88e8492a27eb2d1d22`. Each task recorded its own bounded counters and the exclusive owner reduced them after the existing column barrier. Ordinary runtime source received no profile clocks.

The current-gameplay Wave2048 Follow fixture profiled 437,760 admitted columns across 144 completed native and Rapier steps and four actual native participants. Each completed step matched the previous A control's exact body, movement, Water-ledger and terrain sequence. The ordinary column wall-time mean was 43.974 ms per native tick. Private worker intervals summed to 167.484 ms per tick because they can overlap and include preemption.

| Column task span | Summed worker ms per native tick | Share of task intervals |
| --- | ---: | ---: |
| Gather and transient body mask | 69.700 | 41.62% |
| Settle and retain overfill | 9.479 | 5.66% |
| Spill support and falling classification | 6.331 | 3.78% |
| Head and Oil flags | 8.875 | 5.30% |
| Depth class | 7.561 | 4.51% |
| Scatter and change accounting | 60.175 | 35.93% |

The next candidate, R, hoisted the fixed clipped interval out of the per-row gather and scatter loops. It filled the same rigid caps and zero flags outside the interval and kept the same admitted reads, writes, dry marks and native barriers. R started from A and excluded both the conditional stores and the diagnostic clocks. R source `d701ceead92852b380719e1481653ca876e3dba5`, tree `d5e70557fffc1ef3c96a19482089df2c2503bcd2`, rebuilt with Linux runtime SHA-256 `16df92445b3e53c9d29bbb1a0aa16319a7a1687d247977e5e67420017626219d`. Application bytes and build dependencies match the A control.

R passed all 48 Wave spill cases and every one of the same 24 live-state and independent Water-inventory checkpoints. Those checks retain negative origins, partial Y selection and re-entry. The suite also retains a fully excluded X half-chunk with exact frozen Water cells and an actual transient-body mask alongside a spilling face.

| Fixture | Run | Mean column ms per native tick | Native median ms | Native p95 ms | Actual steps/s | Physical gap p95 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Wave2048 Follow | 0-A | 44.548 | 96.864 | 103.325 | 11.708 | 117.296 |
| Wave2048 Follow | 1-R | 44.804 | 96.862 | 109.111 | 11.480 | 130.676 |
| Wave2048 Follow | 2-R | 44.827 | 97.936 | 104.609 | 11.540 | 118.104 |
| Wave2048 Follow | 3-A | 56.211 | 103.537 | 194.141 | 8.348 | 246.612 |
| Wave512 Free | 0-A | 7.226 | 11.398 | 12.170 | 59.618 | 16.810 |
| Wave512 Free | 1-R | 7.670 | 11.838 | 13.974 | 56.883 | 31.672 |
| Wave512 Free | 2-R | 7.260 | 11.362 | 12.151 | 58.665 | 16.960 |
| Wave512 Free | 3-A | 7.736 | 11.636 | 13.765 | 56.502 | 20.263 |

All eight fresh headless processes ran sequentially from 21:24:50 to 21:27:56 UTC and preserved exact physical credit, 144 completed Rapier steps and their native sequences. The two R large-case column means average 44.816 ms, close to the first A control's 44.548 ms. The slower final control produces an arithmetic 11.04% reduction against the two-control mean. Its long native tail stays in the record and its cause remains unmeasured. The 512 column means differ by 0.21%, with mixed physical tails. The evidence supports retaining A rather than selecting R. It identifies gather and scatter as the largest measured stages while leaving the cause of their remaining cost unresolved.

## Adjacent Wave strip allocation

The Wave column tasks own distinct halves of a chunk. With 64-byte cache lines, a misaligned row-major `weight` or `meta` array can place the two halves' boundary cells in the same line. The diagnostic measured the allocated pointer residues and adjacent task intervals on the real four-worker workload. It also marked each task's scatter spans at that boundary after existing row skips. The normal array layout, task dispatch and barriers stayed intact.

This isolated Linux build used source `0020c18bae2723618149d0d378871ca49b047589`, tree `9ac2638052e72904675821451252cc49cde806e6`, and runtime SHA-256 `07337d4ba8b8ea7f2b8681c4c8ed0f4e6cc1b7e2f47276b49abbfbda68686c25`. The real Wave2048 Follow trial completed 144 Rapier steps. Its exact body, movement, Water-ledger and terrain sequences match the prior A control. The diagnostic took seven first-substep samples at native ticks 1, 16, 32, 64, 96, 128 and 144. A solved chunk can appear in more than one sample.

| Measured observation | Count |
| --- | ---: |
| Solved chunk observations | 1,092 |
| `weight` boundaries sharing a modelled line | 957 |
| `meta` boundaries sharing a modelled line | 1,069 |
| Adjacent task pairs on distinct threads with overlapping task intervals and writes on both sides | 79 |
| Adjacent task pairs with overlapping boundary scatter spans | 0 |

The static line model establishes layout adjacency. The sampled wall intervals show no simultaneous boundary scatter in this trial. Hardware cache traffic and possible line transfers between sequential phases were outside the measurement. The result supplies no causal basis for a storage alignment change. The candidate retains the original allocation and scheduling.

## Evidence custody

`PUBPRES-COMPLETION-001-physics-checkpoint-01-20261122.zip` contains 104 indexed payloads, 3,101,461 bytes, SHA-256 `1e8b0f649c4236e5895e8524b6c0932555dedab591c1ddab99028344fb2f4e9f`. Its `INDEX.json` binds the raw process logs, unmodified negative Windows and hosted trace excerpts, monotonic-clock reproducer, exact native build receipts, both native test logs, capture receipts and all eight raw traces. The index records the full historical ZIP identities independently of their selected entries. Per-arm filenames and hashes are also in `native-abba-wave-gameplay-2048-follow/native-reduction.json` and `native-abba-wave-gameplay-512-free/native-reduction.json` inside the archive.

`PUBPRES-COMPLETION-001-physics-column-checkpoint-02-20261122.zip` contains 81 indexed payloads, 2,247,641 bytes, SHA-256 `6aaef820db1610af20aec37d5300471ec6e3ddfa4fd9380c128006433295bd73`. The raw profile and R comparison paths are `native-abba-wave-profile-2048-follow/`, `native-abba-wave-clipped-2048-follow/` and `native-abba-wave-clipped-512-free/`. Each includes the individual traces, executable receipts and independent reduction. `wave-parity-R/parity.json` binds the 24 exact checkpoints to the original A fixture and log. `pubpres-physics-source-deltas.bundle` reconstructs the isolated source and control commits given accepted main `00cdb02f103265b6dc5224c68283e9a0c8cb449f` and frozen donor `d316c281e0abb575eb6302afc12ec44f211460ba`.

`PUBPRES-COMPLETION-001-physics-alignment-checkpoint-03-20261122.zip` contains 18 indexed payloads, 276,468 bytes, SHA-256 `bfb4bb9ccedf967fd4abc1bd140efae886fde84a6066456817de0e36947e591b`. It includes the exact diagnostic source bundle, build and native runtime receipts, pinned process command, original test log and raw JSONL, and the independent layout and overlap reduction. The source bundle requires `098a65c225561a11d72ddd22e12dfc92f0a63f90`.
