# ObjectShard M4 — final source-bound performance decision

**Application:** `5f0722ae231d955a98a83b0fbb9a0e7517ef2d8a`  
**Git tree:** `51ff1e6a0949dff3b2b17cdca7a40d4943b05f78`  
**Qualification:** [run 45530425519, attempt 1](https://github.com/techrote/cybersand/actions/runs/45530425519)  
**Disposition:** Engineering evidence supports owner evaluation. **Physical Windows 11 / NVIDIA performance acceptance remains HOLD.**

This report preserves the final actual Workbench measurements and their limits. The complete main campaign passed all four jobs. Windows and Linux each passed 43 headless cases and 32 nominal graphical cases; 18 cases in each graphical invocation actually require display. Windows also passed all 17 pristine extracted-package cases and the actual shipped-launcher checks. Those correctness results do not establish physical presentation speed.

The final Windows software-renderer overview profiles delivered **15.19–15.75 renderer submissions/s** and **3.68–4.96 native semantic ticks/s** across the five scenes. Linux llvmpipe delivered **6.83–6.95 submissions/s** and **1.77–2.33 native ticks/s**. A disabled, paused, zero-body control remained slow on both hosts. Separately, active headless ObjectShard costs remain measurable. The owner’s earlier sustained sub-10-FPS report is therefore unresolved as a physical-machine acceptance concern; it is not dismissed by native PASS results or by the hosted renderer baseline.

[Machine-readable synthesis](final-performance-5f.json) contains all 52 final profile records, four disabled-control processes, two enabled-control processes, exact original footer hashes, full-window stage deltas, tails, boundary observations, and separately identified earlier local controls. It deliberately does not reserialize large native-instance integers through JavaScript numbers; exact original footer text hashes and the complete raw logs preserve those identities.

## Evidence custody and measurement scope

All final rows below come from application `5f0722ae231d955a98a83b0fbb9a0e7517ef2d8a`, tree `51ff1e6a0949dff3b2b17cdca7a40d4943b05f78`. The local equivalent is `b9bbf27465b79739abfd85f4c886e95a9a403523`. Later documentation commits do not change these execution inputs or the packaged application.

| Platform | Original job | Evidence artifact | Archive bytes | Archive SHA-256 |
|---|---|---|---:|---|
| Linux | [138924056891](https://github.com/techrote/cybersand/actions/runs/45530425519/job/138924056891) | [14986462220](https://github.com/techrote/cybersand/actions/runs/45530425519/artifacts/14986462220) | 14,264,606 | `3f745a25db44992edb8f2d2d889fff77d319f2273c583663c0b5c9c4eba94743` |
| Windows | [138926161028](https://github.com/techrote/cybersand/actions/runs/45530425519/job/138926161028) | [14986123965](https://github.com/techrote/cybersand/actions/runs/45530425519/artifacts/14986123965) | 39,179,166 | `e9621d53c45fb649738c6b3c8572dc76c1a90fa4f020131967ff536d86e54468` |

The complete decoded GitHub job-log bytes were independently read and hashed. Linux: 2,778,292 UTF-8 bytes, SHA-256 `2bccaf639ea94167a37aacb7707ddfa5cf3dbf6c4f80c35d71ca2616d9540658`. Windows: 3,453,079 bytes, SHA-256 `757f32f8a9e4a57105488a4e7947505e3d3fa6246d904fbb766ccf390fd72a08`. These identities include the connector-returned BOM and original line endings; they are not mislabeled as hashes of different log members inside the evidence archives. Every derived profile in the JSON names its job-log line and hashes the exact JSON footer text, without timestamp prefix or line ending.

Actual hosted renderers were:

- **Windows:** ANGLE 2.1.1 git aaebda1c5a40, Microsoft Basic Render Driver, Direct3D11 vs_5_0 ps_5_0, D3D11-10.0.20348.5756, OpenGL ES 3.0.
- **Linux:** Mesa llvmpipe, LLVM 20.1.2, 256 bits; OpenGL 4.5 Compatibility, Mesa 25.2.8-0ubuntu0.24.04.4, X11 virtual display.

Neither is the owner’s NVIDIA GPU. `frame_post_draw` is a renderer submission observation, not a physical monitor-present measurement. Native ticks, actual Rapier segments, completed 1/60-second physical intervals, and per-body native pose acknowledgements are separate counters.

The common Godot version is `4.7.stable.official.5b4e0cb0f`. The same-job actual native readbacks identify Linux SHA-256 `09098674d07b11fcf8a2eaa8baa792d672c8ff7a7025c013b7b3bb4196499a43` and Windows `cfd75fcdcc252ab8b6b42fba1e0c78182517db6142b89a261a5b881eaff047c4`. Those readbacks appear in the actual liquid-equipment regression footers in the respective full logs; the delivery audit separately binds every case’s input manifest and the extracted runtime bytes. Pinned executable, Rapier, source-script and fixture identities are included in the JSON.

## Matched graphical controls and all five scenes

Every row uses the ordinary native Workbench. The control recipe is Tower on a 512 × 512 canvas, origin [0,0], view [512,512], authored-rectangles SHA-256 `5521cf71efd5c8f4088d2f8fcfc0cbb98f6a76fb593e9c983d3f1611860fa49d`. Disabled rows retain the same ordinary actor and authored materials while proving no ObjectShard attachment, body, or coordinator snapshot calls. Enabled controls additionally install the fixture’s callback and post-draw coherence observers. This observer asymmetry prevents attributing their complete difference to product ObjectShard overhead.

The six control rows per platform are approximately 12-second wall-time windows. Each scene/profile row completes exactly 180 native ticks and 180 complete physical intervals, or 3 simulated seconds. Rich profiles take one diagnostic state readback per callback and explicitly enable recording. Light profiles omit that full readback while preserving callback timestamps and all required body, native, physics and coherence checks. Recording on/off is independent of light/rich sampling.

**N / R / I** means native semantic ticks / actual Rapier steps / completed 1/60-second material-body intervals. Disabled ordinary Rapier steps are measured, but the separate material-body interval counter does not exist in that disabled path, so I is unavailable. Tails describe observed within-window callback and submission intervals, in milliseconds.

### Windows hosted software renderer

| Workload | Bodies | Submissions/s | Native ticks/s | N / R / I | Callback p50 / p95 / max ms | Post-draw p50 / p95 / max ms |
|---|---:|---:|---:|---|---|---|
| Disabled, intact, paused | 0 | 13.962 | 0.000 | 0 / 0 / — | 74.77 / 77.64 / 83.92 | 74.26 / 77.65 / 79.57 |
| Disabled, intact, Play | 0 | 15.327 | 26.822 | 322 / 324 / — | 64.74 / 70.65 / 74.68 | 64.67 / 68.70 / 70.92 |
| Enabled, intact, paused | 0 | 13.813 | 0.000 | 0 / 0 / 0 | 75.01 / 79.12 / 90.06 | 74.79 / 78.47 / 83.01 |
| Enabled, intact, Play | 0 | 15.197 | 5.232 | 63 / 253 / 63 | 65.13 / 72.42 / 206.89 | 64.83 / 72.02 / 208.57 |
| Enabled, detached, paused | 1 | 15.067 | 0.000 | 0 / 0 / 0 | 67.16 / 68.95 / 76.89 | 67.14 / 68.79 / 71.67 |
| Enabled, detached, Play | 1 | 15.646 | 4.994 | 60 / 243 / 60 | 63.47 / 67.84 / 76.50 | 63.49 / 67.00 / 78.95 |
| Tower, rich overview | 1 | 15.746 | 4.964 | 180 / 721 / 180 | 63.33 / 68.76 / 90.08 | 63.43 / 66.31 / 88.89 |
| Viaduct, rich overview | 3 | 15.194 | 4.683 | 180 / 721 / 180 | 53.54 / 190.17 / 205.03 | 52.91 / 189.53 / 204.04 |
| Timber, rich overview | 1 | 15.264 | 4.633 | 180 / 721 / 180 | 53.10 / 145.01 / 216.80 | 53.02 / 148.95 / 216.88 |
| Mixed, rich overview | 1 | 15.365 | 4.818 | 180 / 721 / 180 | 52.85 / 189.08 / 196.30 | 51.72 / 188.34 / 195.60 |
| Stress, rich overview | 8 | 15.367 | 3.678 | 180 / 721 / 180 | 64.40 / 75.25 / 194.26 | 64.42 / 74.42 / 194.63 |
| Tower, light, recording off | 1 | 15.665 | 4.947 | 180 / 721 / 180 | 63.59 / 69.49 / 78.64 | 63.67 / 67.30 / 78.65 |
| Tower, light, recording on | 1 | 15.606 | 4.972 | 180 / 721 / 180 | 63.94 / 69.05 / 189.10 | 63.83 / 67.95 / 189.66 |

### Linux hosted llvmpipe

| Workload | Bodies | Submissions/s | Native ticks/s | N / R / I | Callback p50 / p95 / max ms | Post-draw p50 / p95 / max ms |
|---|---:|---:|---:|---|---|---|
| Disabled, intact, paused | 0 | 7.158 | 0.000 | 0 / 0 / — | 135.97 / 172.56 / 188.17 | 135.88 / 172.62 / 188.29 |
| Disabled, intact, Play | 0 | 6.967 | 6.884 | 83 / 84 / — | 140.45 / 160.65 / 189.78 | 140.37 / 160.70 / 189.93 |
| Enabled, intact, paused | 0 | 5.792 | 0.000 | 0 / 0 / 0 | 185.78 / 191.93 / 192.75 | 185.85 / 191.76 / 192.71 |
| Enabled, intact, Play | 0 | 6.812 | 3.074 | 37 / 149 / 37 | 142.88 / 179.94 / 190.36 | 143.25 / 180.44 / 190.65 |
| Enabled, detached, paused | 1 | 7.235 | 0.000 | 0 / 0 / 0 | 134.31 / 156.52 / 187.07 | 134.35 / 156.69 / 187.14 |
| Enabled, detached, Play | 1 | 6.799 | 2.322 | 28 / 113 / 28 | 142.41 / 179.62 / 196.16 | 142.81 / 179.19 / 196.00 |
| Tower, rich overview | 1 | 6.868 | 2.294 | 180 / 721 / 180 | 142.23 / 179.68 / 195.77 | 142.35 / 179.49 / 198.58 |
| Viaduct, rich overview | 3 | 6.834 | 2.334 | 180 / 721 / 180 | 141.24 / 185.48 / 196.21 | 141.42 / 185.54 / 196.21 |
| Timber, rich overview | 1 | 6.866 | 2.293 | 180 / 721 / 180 | 141.14 / 182.02 / 193.46 | 141.25 / 181.66 / 193.60 |
| Mixed, rich overview | 1 | 6.951 | 2.267 | 180 / 721 / 180 | 139.52 / 182.67 / 193.29 | 139.65 / 182.79 / 193.75 |
| Stress, rich overview | 8 | 6.854 | 1.770 | 180 / 721 / 180 | 140.29 / 185.64 / 195.76 | 140.52 / 185.24 / 195.84 |
| Tower, light, recording off | 1 | 6.870 | 2.534 | 180 / 721 / 180 | 141.23 / 180.02 / 196.26 | 141.35 / 179.46 / 195.74 |
| Tower, light, recording on | 1 | 6.877 | 2.427 | 180 / 721 / 180 | 141.26 / 180.25 / 194.37 | 141.37 / 180.02 / 194.34 |

The detached-paused row is a stopped one-body display control. Its Rapier awake flag can remain true while owner Pause prevents stepping; it is **not** a naturally sleeping running-body control. The separately identified natural-rest witness below covers that different condition.

All four disabled-control processes passed their exact zero-native-tick and zero-Rapier-step paused assertion. The corrected fixture captures the ordinary user Pause request serial and waits for that exact worker acknowledgement, as well as host/native Pause, actor suspension and image coherence. It also rejects a synthetic stale acknowledgement. In final graphical Windows and Linux, request 2 / acknowledgement 2 bracket native tick 3 throughout the entire paused window. The original 519 Linux and 422 Windows controls failed that strict requirement and remain historical failures.

For the enabled-control fixtures, all 1,241 callback observations and 1,241 draw observations across the two platforms were coherent. The 26 rendered scene-profile processes recorded 20,438 callback observations and 20,464 draw observations, with **zero incoherent observations**. These observer counts include setup and final checks; they are not the timed render-submission totals. Disabled controls retain explicit image-boundary checks but do not install the same continuous observer.

## Headless progression, natural rest and diagnostic recording

The headless observations establish substantive ObjectShard coordination cost even without software rasterization. Different processes and workload instrumentation remain disclosed; a disabled control is not an identical active-body workload with only a boolean changed.

| Workload | Windows native ticks/s | Linux native ticks/s | Scope |
|---|---:|---:|---|
| Disabled intact Play | 60.061 | 59.971 | Same 512 Tower recipe and ordinary actor, no ObjectShard attachment |
| Tower, rich overview | 31.986 | 33.993 | 1 native owned body, 180 ticks / 180 intervals |
| Viaduct, rich overview | 33.494 | 29.951 | 3 native owned bodies, 180 ticks / 180 intervals |
| Timber, rich overview | 27.343 | 29.164 | 1 native owned body, 180 ticks / 180 intervals |
| Mixed, rich overview | 34.582 | 26.887 | 1 native owned body, 180 ticks / 180 intervals |
| Stress, rich overview | 29.639 | 22.021 | 8 native owned bodies, 180 ticks / 180 intervals |
| Tower, light, recording off | 31.052 | 23.219 | Same full native/physics workload; no per-callback rich state readback |
| Tower, light, recording on | 31.971 | 33.070 | Only requested recording state differs from preceding light row |
| Stress, light, recording off | 29.750 | 27.576 | All eight bodies retained |

**Naturally stationary while Play remained active:** the durable [109-check natural-rest report](natural-rest-local/report-complete.json) uses earlier exact application `61213289ccaf2ec9771274f73576752ac1d648ff`, tree `639b3709c7ae82236aacab86ff3cb13327b5e446`, with unchanged application/native paths in its `537ddef6` integration equivalent. It is earlier development evidence, not a new final-5f execution. After ordinary support erasure and natural falling/resting, a 12.000172-second headless window recorded **400 native ticks, 400 complete intervals, 1,600 actual Rapier segments and 1,600 exact native ACK/pose echoes**, at **33.333 ticks/s**. Every one of 1,642 actual Rapier state readbacks was sleeping, with zero linear/angular velocity and zero pose drift. No forces, velocities, sleeping flags, physics or chemistry were artificially changed. Callback p50/p95/max were **8.930 / 10.497 / 62.409 ms**. Per-callback physical readback adds observer cost.

That source’s sealed native build came from `ccdfde97c279d809eafbb6e74b880d14cfb2f60e`; the 117-input native equivalence, actual executable hashes, shared Xeon 8573C host and full application input map are retained in [its campaign receipt](performance-local-61213289c/campaign.json). Its completed report SHA-256 is `62a9023380e7e0d0b3f9fd125f7630e6cda014101fb10540258f4afc566a13d4`. The initial 373-native/374-physical-interval window remains recorded with its limited edge evidence; the complete replay retained exact phases and does not rewrite the first counts.

**Recording is optional, not an evidenced FPS cure.** Final graphical Windows light Tower measured 4.947 ticks/s off and 4.972 on; Linux measured 2.534 off and 2.427 on. Headless variation also changes direction and magnitude. These single paired processes do not establish a consistent benefit from switching recording off.

An earlier source-bound headless light ABBA sequence retained the complete 180-tick workload in all four cases: **26.511 off, 28.307 on, 29.954 on, 30.775 off ticks/s**. This order trend likewise fails to establish a recording speedup. Exact source, receipts, logs and shared-host load observations are retained in the JSON and original committed campaign. The product’s default-off change removes unsolicited observation work and gives the owner a deliberate diagnostic control; it does not justify a speed claim.

## Cadence tails, camera and publication age

The tables above retain median, upper-tail and maximum callback/submission intervals. Distinct native-tick delivery has a separate cadence. The following values are derived from all timestamped Main-observed native changes in each final overview window, including the Play transition at the beginning. These are delivery observations, not native worker execution durations. All displayed rows observed every one of the 180 native changes; no coalesced tick jump occurred in these particular windows.

| Scene | Windows native delivery p50 / p95 / max ms | Linux native delivery p50 / p95 / max ms |
|---|---|---|
| Tower | 190.98 / 256.42 / 588.80 | 422.86 / 480.72 / 1666.26 |
| Viaduct | 199.87 / 323.00 / 408.17 | 423.26 / 480.40 / 1771.82 |
| Timber | 197.19 / 332.17 / 920.43 | 425.11 / 490.52 / 546.81 |
| Mixed | 197.15 / 332.10 / 613.97 | 419.32 / 483.49 / 2250.21 |
| Stress | 256.64 / 382.45 / 2963.95 | 561.39 / 630.73 / 1528.57 |

The multi-second maximum delivery gap in some windows is retained. It does not become an input-to-monitor measurement, and the early Play-transition gap must not be described as a steady-state per-tick CPU cost.

Camera comparison used the same scene and native workload, with overview [0,0]/[512,512] versus a fixed zoom [96,256]/[256,256]. These are separate fresh processes. They are not a timed continuous panning experiment.

| Scene | Windows overview submissions/s; ticks/s | Windows zoom submissions/s; ticks/s | Linux overview submissions/s; ticks/s | Linux zoom submissions/s; ticks/s |
|---|---|---|---|---|
| Tower | 15.746; 4.964 | 16.052; 4.897 | 6.868; 2.294 | 7.436; 2.645 |
| Viaduct | 15.194; 4.683 | 15.896; 4.691 | 6.834; 2.334 | 7.412; 2.561 |
| Timber | 15.264; 4.633 | 15.912; 4.518 | 6.866; 2.293 | 7.470; 2.495 |
| Mixed | 15.365; 4.818 | 16.190; 4.663 | 6.951; 2.267 | 7.576; 2.521 |
| Stress | 15.367; 3.678 | 15.890; 3.672 | 6.854; 1.770 | 7.277; 1.866 |

Final profile boundaries, after ordinary Pause and drain, show equal latest/displayed native tick, equal latest/displayed publication sequence, and matching displayed/uploaded World revision in all 52 cases. Continuous coherence observes that World and owned-material presentation identities agree. Neither fact measures the age of each running publication. **A full-window running material-delivery-age distribution, causal input response, physical monitor latency and physical present intervals remain unavailable.** The probe explicitly reports `hardware_present_verified=false`, `input_to_post_draw_causally_proven=false`, and does not claim frame-serial display proof by itself.

The owner guide supplies ordinary wheel zoom, middle-button pan, Overview, and actual Cut/Ignite/Settle controls. Their correctness fixtures and mounted input witnesses are distinct from this fixed-view performance campaign. No continuous-camera performance claim is inferred from overview still captures.

## Measured costs and scheduling interpretation

The following are **full-window accumulated durations**, in seconds. They are intentionally not summed. Main pump includes rendezvous waits and its nested stages; native work can overlap Main execution; occupancy includes relocation/contact. The native-only snapshot counter excludes the Godot marshalling measured by the worker snapshot stage. Stage maxima carried in cumulative Main counters are lifetime maxima, not newly inferred window maxima.

| Platform / execution / scene | Wall s | Main pump s | Worker snapshots s | Main frame copy s | Actual Rapier stage s | Occupancy s | Of which relocation s |
|---|---:|---:|---:|---:|---:|---:|---:|
| Windows / headless / Tower | 5.627 | 3.659 | 0.471 | 0.011 | 0.052 | 0.517 | 0.343 |
| Windows / headless / Mixed | 5.205 | 3.822 | 0.524 | 0.011 | 0.052 | 0.683 | 0.361 |
| Windows / headless / Stress | 6.073 | 4.847 | 0.935 | 0.017 | 0.066 | 1.231 | 0.795 |
| Windows / graphical / Tower | 36.263 | 3.881 | 0.821 | 0.032 | 0.574 | 0.860 | 0.600 |
| Windows / graphical / Mixed | 37.358 | 4.334 | 0.753 | 0.026 | 0.989 | 1.044 | 0.558 |
| Windows / graphical / Stress | 48.936 | 6.578 | 1.469 | 0.041 | 2.287 | 2.269 | 1.545 |
| Linux / headless / Tower | 5.295 | 3.109 | 0.672 | 0.028 | 0.082 | 0.740 | 0.502 |
| Linux / headless / Mixed | 6.695 | 3.464 | 0.749 | 0.030 | 0.081 | 0.985 | 0.540 |
| Linux / headless / Stress | 8.174 | 4.856 | 1.298 | 0.041 | 0.107 | 1.690 | 1.145 |
| Linux / graphical / Tower | 78.475 | 3.088 | 0.673 | 0.037 | 0.091 | 0.766 | 0.524 |
| Linux / graphical / Mixed | 79.417 | 3.032 | 0.732 | 0.019 | 0.068 | 0.996 | 0.549 |
| Linux / graphical / Stress | 101.695 | 4.486 | 1.245 | 0.031 | 0.102 | 1.753 | 1.201 |

For example, final Windows headless Tower completed 180 ticks in 5.627 s while accumulating 3.659 s in Main’s pump, including waits, 0.471 s in 1,080 worker snapshots including dictionary/packed-array marshalling, and 0.517 s in native occupancy including 0.343 s relocation. Actual Rapier stepping accumulated 0.052 s, and native-only snapshot work 0.001780 s. This separates measured coordination/marshalling and conservative occupancy work from a blanket attribution to Rapier compute.

Final Windows rendered Tower took 36.263 s with 3.881 s pump, 0.821 s worker snapshots and 0.574 s actual Rapier stage. Linux rendered Tower took 78.475 s with 3.088 s pump, 0.673 s snapshots and 0.091 s Rapier stage. Those accumulated costs do not explain the full wall duration in isolation; callback scheduling and renderer waits remain material.

Source inspection explains an important coupling without changing the ownership contract:

- [Main `_process`](../../../godot/scripts/main.gd) consumes worker state, polls the M4 adapter and retries a coherent World upload. Main `_physics_process` refuses to start another material interval while the adapter is not ready.
- [The existing M4 runtime](../../../godot/scripts/object_shard_m4_runtime.gd) pumps at most 48 operations within an 8,000 µs budget per Main process callback. An already-admitted unresolved receipt uses its existing bounded 100 µs wait.
- Each actual segment sends immutable completed poses to the exclusive native owner. Only the validated matching native receipt and exact pose echo advance acknowledged physical time. A complete 1/60-second interval normally contains four base segments in these workloads.
- Completion then requires the due native semantic tick and installation/publication gates. New native progress therefore depends on Main callbacks being available to consume receipts and continue the admitted interval. Slow rendered callback cadence delays that chain even when isolated native or Rapier stage durations are short.

This is an evidenced scheduling contribution, not a claim that a measured stage is the sole bottleneck. In all 26 rendered final profile windows, the end snapshot has `phase=RealRapierInterval`, `pending_kind=motion`, **721 actual steps, 720 ACKs per body, 180 complete intervals and 180 native ticks**. The next segment has physically occurred but is still awaiting its native acknowledgement. It is not counted as a completed interval. Subsequent ordinary Pause drains that admitted boundary before the final coherent census. Other headless windows finish at 720 steps in Ready. These actual boundary distinctions are retained in the JSON. Disabled ordinary controls use independent native-publication and Rapier counters; their 12-second edges can differ (for example Windows headless 721 native ticks versus 720 ordinary Rapier steps). They do not use M4 segment acknowledgements, and their count difference is not relabeled as a missed successful ACK.

Already implemented sparse composition, immutable receipt reuse, unchanged-geometry reuse and redundant readiness suppression remain present. The final timed profiles report zero native geometry and terrain rebuild duration because geometry is unchanged during their measured portions; this is not a measurement of edit/rebuild cost. Separate live-edit qualification verifies actual geometry replacement and surviving material-point velocity. The native storage counters are accounted lower bounds: e.g. 66,152,030 live bytes for Tower and 66,721,464 for eight-body stress, excluding allocator overhead, much World metadata, Godot and Rapier. No per-operation allocation-cost conclusion follows.

### Bounded probe stages do not isolate GPU time

Stage samples from optional recording are a recent bounded ring, often 256 observations; some stages have fewer observations and can include setup. They are kept separate from the full-window counters above.

| Rendered Tower probe stage | Windows count; p50 / p95 / max ms | Linux count; p50 / p95 / max ms |
|---|---|---|
| physics_work | 256; 0.130 / 0.198 / 41.619 | 256; 0.121 / 0.168 / 0.187 |
| publication_prepare | 256; 0.070 / 0.099 / 0.120 | 256; 0.072 / 0.095 / 0.114 |
| queue_admission | 256; 0.028 / 0.039 / 0.064 | 256; 0.032 / 0.088 / 0.134 |
| receipt_delivery | 256; 5.338 / 11.911 / 18.981 | 256; 4.461 / 15.747 / 16.928 |
| scene_callback | 256; 8.801 / 10.198 / 47.459 | 256; 8.786 / 9.546 / 11.335 |
| texture_upload_submission | 48; 52.997 / 59.927 / 172.656 | 49; 0.147 / 0.182 / 0.241 |
| upload_to_post_draw | 48; 4.285 / 17.296 / 17.513 | 49; 186.578 / 189.868 / 190.103 |

In particular, Windows texture-upload submission wall time and Linux upload-to-postdraw wall time occupy different sides of the renderer handoff. Neither is an isolated physical GPU timer. Full-scene callback durations also contain nested work, and this bounded sample set can differ from the full measurement-window callback tails.

The disabled paused controls establish substantial standing presentation cost outside active ObjectShard. They do not isolate which ordinary renderer/publication subsystem owns every microsecond. No unfinished PUBPRES, Equipment, Actor Compose or RAMCACHE branch was imported, and no causal performance claim is made for another programme’s unmeasured changes.

## Material workload and retained negative results

The five demonstrations remained actual native material arrangements with unchanged body counts and chemistry:

- Tower: one coherent structural body; exact Wood and Brick inventory retained in the no-cut performance window.
- Viaduct: three independent owned bodies. Final overview displacement recorded 1,511 Water-cell relocations.
- Timber: four source-bound ignitions precede the window; native chemistry produced 15 products with 41 blocked-output observations retained.
- Mixed: one body interacting with native Water, Sand and Fire. Final overview counters recorded 4,859 Water-cell relocations, 1,531 Sand-cell relocations, four accepted and consumed exposures, one external ignition, three extinguish events and four chemistry products.
- Stress: all eight independent bodies remained present, with 5,760 native pose ACKs and exact echoes for the 180 complete intervals.

The raw inventory witnesses separately retain stored grid materials, native Water visible/overfill/ballistic quantities, parcel Float64 records, and rendered RG8 projection. A rendered Water pixel is not counted as stored Water inventory. These illustrative profiles report **zero Sand ingestion**, so they demonstrate conservative Sand displacement here; established lodging behavior is supported by its separate native qualification, not invented from this profile.

The original failures remain failures: f5 Windows’s terminal missing-provenance replay; f5 Linux acquisition HTTP403; 519 Windows’s mixed native/display burn-boundary assertion; 519 Linux and 422 Windows’s pre-acknowledgement paused controls; 422 Linux’s actual held-pointer publication race. Later exact-source corrections and all-PASS final campaign supersede readiness for new inputs without rewriting predecessor outcomes.

No proven performance cache was added in this recovery. A separately committed, unadmitted experiment proposed changing the pump’s pending-receipt wait from 100 µs to zero, preserving all physics/ACK assertions. Its first **unchanged baseline** was SIGKILLed after 6.287 s before producing a completed profile. **No variant process ran; no ABBA comparison exists.** The precise one-line diff and observed negative are retained in [the continuity packet](executor-outage-b-continuity.md) and [unadmitted patch](pump-wait-unadmitted.patch). That interruption is not evidence that either wait value is faster, slower or incorrect. Final application 5f retained the original wait.

The earlier 12.4% snapshot-stage observation described an entire mixed development-run stage, not an isolated payload-hash function. The final snapshot and occupancy measurements still justify future profiling of exact owner/publication marshalling and rendezvous. They do not justify a material-revision-only cache: scheduler state and full lifetime/ownership identities remain necessary dependencies.

## Owner acceptance procedure and remaining boundary

Use the principal portable ZIP and its `Open Workbench.cmd`; the launcher verifies the payload and enters the ordinary ObjectShard-enabled Tower experience. The default 2048 canvas still refuses native ObjectShard attachment; use the supplied 512 scenes or the supported 512/1024 starts. That limit remains visible rather than being bypassed.

On the owner’s Windows 11 NVIDIA machine, preserve the chosen window size, renderer, camera and material settings across comparisons. Start with recording off. Compare intact paused, intact Play, released Tower, natural rest, Mixed and all-eight-body Stress. Use Overview and repeat a fixed zoom; try pan and Cut while genuinely moving, then Pause/Settle at a naturally resting near-grid pose. Observe native progression as well as displayed responsiveness.

For an inexpensive diagnostic sample, enable the ordinary Structures diagnostic checkbox only for the chosen interval, then stop and save that one report. Starting recording begins a fresh epoch; stopping retains the captured data for saving. The explicit direct-engine `--objectshard-diagnostics` flag is available separately; passing arguments to the fixed shipped CMD is not the documented activation route. Full recording remains optional.

Record the package identity, NVIDIA GPU/driver, window/display configuration, chosen scene/camera, and whether diagnostics were enabled. Note sustained low display cadence, multi-second pauses, input refusal versus accepted edits, publication mismatch, or physical progression that remains slow despite fast display. The optional report cannot by itself prove physical monitor presentation; an owner observation or separate physical-machine measurement is still required.

**Specialist B verdict:** source and measurement evidence support the final engineering-qualified owner evaluator. The measured coordination cost and hosted presentation limits remain explicit. Physical performance acceptance stays **HOLD** until the unchanged principal package receives qualifying owner-machine evidence.
