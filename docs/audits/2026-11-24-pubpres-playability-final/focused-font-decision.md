# Focused font ownership repair: exact execution and independent decision

**Disposition: the font ownership repair passes its registered startup and byte-history gates; Separate rendering is rejected as a playability improvement for both measured workloads. Everything remains Draft/HOLD.**

This is a new execution of retained application/native/engine bytes, with a separately committed corrected qualifier. It does not rewrite the earlier red workflow. Every physical result below comes from independently witnessed actual Rapier completions; upload-call duration, draw notifications and step-selection counters supply no physical credit.

## Contents

- **Identity and custody** — exact old application, new driver, engine/runtime files and original artifact.
- **Correctness and negative controls** — original Separate failure, repaired font/startup and both first-read GPU histories.
- **Physical decision** — all eight first-144-step arms, including adverse controls and tail counts.
- **Freshness and costs** — submitted-pose/material ages, real process CPU/RSS and observer limitations.
- **Architectural consequence and limits** — what faster submission answers, and the remaining display/NVIDIA requirements.
- **Reproduction** — exact replay, immutable packet and bounded temporary extraction.

## Identity and custody

| Item | Exact identity |
|---|---|
| Application | `c2f8a73d34448bc1496ecd84bca02f0812c80d27` |
| Application tree | `351b947a50ce054361660eba9379006122527547` |
| Execution driver | `d4f4afe93d02192d9165622b78b762d9fbf8dc3e` |
| Driver tree | `804aa805a974dba929bbbb94f8a83a97b0ea1813` |
| Focused workflow | [45467136551](https://github.com/techrote/cybersand/actions/runs/45467136551), original conclusion **SUCCESS** |
| Retained engine/native build | [45452580606](https://github.com/techrote/cybersand/actions/runs/45452580606), application `c2f8a73d…` |
| Focused artifact | `14959055513`; 20,857,561 bytes; 947 ZIP members |
| Focused ZIP SHA-256 | `3dc89e83a4757c860a7f7f645b165eb948d3bfb1a12c294596b524f802464b5d` |
| Repaired GUI SHA-256 | `b0c608bc47bdc05cdd2083df4dfd67861c5d36b876a1ccf7086374059c7bad15` |
| Repaired build proof SHA-256 | `0f1d6059578d4505043fe11f1286cd7395c5cc64df7aa379106f7a0bcafdf1c5` |
| Original #609 GUI SHA-256 | `d6a1e5795205eb7968131df55f39916af112f716ec419fce5f97ccb48990fd45` |
| Native Windows DLL SHA-256 | `1cdcbf4f72204d79b22d1a9551e46f9ccf02f6785d3141503e90e27feda28f1b` |
| Native manifest SHA-256 | `f1d8e97e923eb8c03a9ae3592bd9a45b2784ca70eee2cdd15e0a85cd63f51be1` |
| Rapier Windows DLL SHA-256 | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| Full independent replay SHA-256 | `9bf58d62571451b0ba220b54d8792a3c031a073152dd2b01d9dc7a0948e9c2bb` |

The replay revalidated the complete 112-file committed driver closure and complete-tree execution request, all 105 committed native inputs, pinned build/dependency/toolchain predicates, actual Windows DLL and Rapier bytes, and both complete original engine archives. Both engine GUI/console PE roles, dependency closure, source patches, API evidence and proof identities passed their unchanged readers. Runtime custody uses the separately identified read-only Windows target derivation; it does not execute Windows binaries on the replay host.

The captured application and execution driver are deliberately different. The source-locked new-execution derivation changes only their registered identity join and adds the exact retained runtime/build gates. The original same-head qualifiers and every frozen physical predicate remain unchanged. All observers are hashed from the actual new driver.

## Correctness and negative controls

The retained original engine passed the finite Safe font control and reproduced the exact expected `CowData<unsigned char>::get` index-zero/size-zero failure under Separate. That failed control remains failed and is classified as an admissible historical negative. No unrelated diagnostic is accepted as that failure.

The repaired engine passed both Safe and Separate font arms. All three successful finite font reads matched framebuffer SHA-256 `4c48a542065f2c9ac9befc88c0c81ca5ca830e63a2eb06d27f6f15f077679b38`. Each successful font arm executed the registered 64 draws and 6,016 glyph calls with the exact fixture and source. Both repaired ordinary Workbench startup owners passed, with native tick zero: these paused startup receipts carry no physical-progress credit.

Both repaired render owners then passed the original two-slot transition tape: 180 actual admissions, 35 independently reconstructed initial/warmup/sparse-entry/final byte hashes per owner, and two fixed positive texture RIDs alternating without replacement or aliasing. The complete source/driver/render-owner/process/log joins and first-read current/previous histories were replayed from raw files before examining timing.

## Physical decision

Each table row uses exactly the first 144 genuine completed steps and 143 consecutive completion gaps. The same repaired executable, c2 application/native/Rapier, Full2, Early/coherent policy, deadline-off, continuation-off, full physical observer and submitted-pose/CPU observer are fixed. The order is Safe / Separate / Separate / Safe. Actual body trajectories, native responses, terrain revisions, input leases and Water ledgers satisfy the full unchanged physical gates and equal-step parity.

The host was **AMD EPYC 9V74, four logical processors**, using ANGLE D3D11 with the **Microsoft Basic Render Driver**. It is not a physical NVIDIA result. Percentiles use the frozen linear-interpolated definition. Thresholds below are pre-existing reporting categories, not newly invented owner acceptance budgets.

### Wave512 reference: one Wave round, spill disabled

| Arm | Actual steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 / >1000 ms |
|---|---:|---:|---:|---:|---:|---|
| 0: safe | 12.539238 | 8.536 | 239.540 | 247.269 | 694.478 | 46 / 1 / 1 / 0 |
| 1: separate | 7.401807 | 221.553 | 244.023 | 251.078 | 257.504 | 81 / 3 / 0 / 0 |
| 2: separate | 6.787068 | 225.016 | 244.172 | 478.836 | 483.809 | 85 / 4 / 0 / 0 |
| 3: safe | 12.904871 | 8.070 | 234.370 | 241.448 | 242.969 | 46 / 0 / 0 / 0 |

Both Separate rates are below both Safe controls: **41.0–47.4% lower** across the four cross-arm comparisons. The original registered improvement decision remains **NOT_ESTABLISHED**. This is a bounded adverse cohort, not a universal hardware theorem.

### Current Wave2048: two Wave rounds, spill/ballistic enabled

| Arm | Actual steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 / >1000 ms |
|---|---:|---:|---:|---:|---:|---|
| 0: safe | 3.915376 | 276.748 | 515.713 | 722.726 | 855.032 | 129 / 82 / 8 / 0 |
| 1: separate | 3.467233 | 290.119 | 568.878 | 1003.672 | 1093.445 | 129 / 98 / 14 / 2 |
| 2: separate | 3.706240 | 262.885 | 583.904 | 948.080 | 1066.463 | 122 / 81 / 17 / 2 |
| 3: safe | 4.007764 | 259.855 | 526.447 | 807.939 | 845.557 | 128 / 77 / 12 / 0 |

Both Separate rates are below both Safe controls: **5.3–13.5% lower** across the four cross-arm comparisons. The original registered improvement decision remains **NOT_ESTABLISHED**. This is a bounded adverse cohort, not a universal hardware theorem.

The first Safe512 arm includes its full 694.478 ms stall; it was not removed to improve the control. Separate512 happens to have smaller maximum gaps than that one outlier, while doubling the count of >100 ms gaps and losing 41–47% of progression. A favorable isolated maximum does not select the treatment. In the large workload, both Separate arms exceed one second, each with two >1000 ms gaps; both Safe controls remain below one second but still have severe tails.

## Freshness and costs

| Workload / arm | Upload-call mean ms | First-part completion age p95 / max ms | Material generation age at submission p95 / max ms | Actual first-144 submissions |
|---|---:|---|---|---:|
| 512 / 0 safe | 97.765 | 239.835 / 687.218 | 235.763 / 695.163 | 48 |
| 512 / 1 separate | 0.487 | 244.677 / 254.356 | 461.050 / 481.530 | 82 |
| 512 / 2 separate | 0.444 | 245.720 / 482.161 | 456.807 / 485.061 | 90 |
| 512 / 3 safe | 103.602 | 235.522 / 237.558 | 244.281 / 440.211 | 47 |
| 2048 / 0 safe | 119.146 | 542.235 / 844.370 | 561.402 / 810.771 | 114 |
| 2048 / 1 separate | 1.900 | 656.563 / 1085.257 | 821.855 / 1236.081 | 135 |
| 2048 / 2 separate | 1.681 | 745.676 / 1060.131 | 767.181 / 1297.903 | 125 |
| 2048 / 3 safe | 139.796 | 572.107 / 839.439 | 697.536 / 990.129 | 113 |

All eight first-144 traces have zero withheld actors, zero intentional holds and zero selected physical steps behind. Those counters coexist with material ages above one second and first-part selected-completion ages up to 1.085 seconds. The independent pose joins use real completion times and the actual submitted first collider part/transform; geometry verification does not turn an old wall-clock pose into a fresh one. One to three pre-capture/initial poses per arm lack an independent in-capture completion time and remain explicitly unknown.

For Safe, submitted state can be joined to its inline completion notification. For Separate, the callback is a Main-delivered draw-completion notification. It does not identify the rendering owner’s exact completion time, the GPU, scanout or which material serial was displayed. The reducer requires that Separate draw/material association remain unavailable. Submitted state is still observed independently at Main’s actual pre-draw boundary.

| Workload / arm | Sampled process interval s | Process user + kernel CPU s | Mean CPU cores | Queried peak RSS MiB | Pose observer total ms |
|---|---:|---:|---:|---:|---:|
| 512 / 0 safe | 127.015 | 183.172 | 1.442 | 826.1 | 7.186 |
| 512 / 1 separate | 145.766 | 227.531 | 1.561 | 793.6 | 20.839 |
| 512 / 2 separate | 151.609 | 238.875 | 1.576 | 783.3 | 21.792 |
| 512 / 3 safe | 115.015 | 171.094 | 1.488 | 824.9 | 7.512 |
| 2048 / 0 safe | 245.688 | 640.797 | 2.608 | 791.1 | 19.431 |
| 2048 / 1 separate | 262.297 | 676.766 | 2.580 | 783.5 | 31.411 |
| 2048 / 2 separate | 257.328 | 655.969 | 2.549 | 781.3 | 26.915 |
| 2048 / 3 safe | 198.250 | 587.047 | 2.961 | 926.5 | 17.680 |

These are actual process-wide user/kernel counters and kernel peak-RSS queries, independently bound to each owned Godot PID. They include setup and cleanup and are not aligned to the 11–42 second physics capture. They cannot establish CPU cost per completed physics step. The independently retained instantaneous-RSS maxima are distinct from the maximum queried kernel peak. The external sampler reports its own read time, including successful and failed queries; its largest reads here are about 201–244 ms. That external wall cost is not Godot CPU and is not silently charged to a specific physics step.

The extra pose observer was enabled identically in all matched arms. Its measured total callback work is retained, and different owner/callback counts naturally change that total. This experiment supplies no new off/on calibration for this repaired Windows engine; earlier Linux calibration is not inherited as a zero-overhead claim.

## Architectural consequence and limits

Separate makes the CPU upload submission call dramatically faster: roughly 98–104 ms means become 0.44–0.49 ms for512, and 119–140 ms become 1.68–1.90 ms for2048. Actual completed physics gets slower and submitted material/pose ages worsen. The effect is therefore insufficient as a playability repair. This reinforces the retained Target-publication negative: moving or shortening a submission call does not establish reduced end-to-end dependency or rendering backpressure.

The finite font race is independently repaired for the tested engine/ANGLE cases. Its ownership fix may remain as a correctness candidate. It does not select Separate rendering. A next scheduling/engine arm needs an explicit different blocked-stage hypothesis and unchanged native/terrain/physical authority; these results do not justify another undifferentiated Separate or faster-upload campaign.

Actual native start/wake/dispatch clocks were not enabled in these timing arms. The separately reported native-completion→physical clocks show delay after native completion, but elapsed solver calls and publication overlaps are not pure CPU/GPU execution. No missing native start is synthesized by subtracting a duration. No specific physical NVIDIA driver cause can be inferred from hosted software rendering.

The cohorts contain one controlled actor and the registered Follow tape, not sustained eight-actor painting. They neither repair nor invalidate the separately reproduced submerged-actor withholding defect. Ordinary mixed workloads, long-duration freshness, input-device-to-display latency, actual display trails, default Windows WGL and physical NVIDIA remain explicit acceptance work. The successful workflow is an evidence/qualification success containing a negative performance decision; it is not a production or playability pass.

## Reproduction

The [complete replay](focused-font/independent-replay.json), [executed reader](focused-font/replay.py), [resource readouts](focused-font/resource-readouts.json) and [packet builder](focused-font/build_packet.py) are indexed with exact hashes in [INDEX.json](focused-font/INDEX.json). Original ZIPs and raw process/trace files remain authoritative. The complete report retains every physical window, supplementary observation and relative-decision predicate.

The executed reader accepts `--workspace-root` and `--output`. It expects an isolated detached Git checkout at `evidence-c/font-reader-root`, with HEAD exactly `d4f4afe93d02192d9165622b78b762d9fbf8dc3e`, and the retained files at the documented paths. Only the `tools`, `third_party`, `godot/tests`, `.github`, palette selector and material shader source paths need checkout; committed application/native input objects remain available through Git. Use `GIT_LFS_SKIP_SMUDGE=1` for this source reconstruction so inactive-platform pointer bytes match the original capture.

The reader restores original engine archives into temporary bounded directories, fully verifies them, retires the old restored payload after admission, and removes the repaired temporary runtime at exit. Each timed arm is extracted and reconstructed separately. It calls only read-only retained-data validators; it never launches an engine or reruns gameplay. A missing source/runtime byte fails the replay rather than weakening custody.
