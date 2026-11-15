---
title: Camera, terrain and actor temporal coherence correction
status: Current
document-kind: audit
scope: Isolated production-path counterexample, monotonic presentation repair, current-main integration and Windows evaluation boundary
canonical-for: []
last-reviewed: 2026-11-15
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../operations/engine-lab-pose-tracing.md, ../operations/camera-stack-coherence-acceptance.md]
---

# CAMERA-STACK-COHERENCE-001

**Implemented candidate; Draft/HOLD. Physical Windows NVIDIA acceptance remains
pending.** This work continues #566 → #593 → #606 → #609. It changes desktop
presentation and its qualification, not native material authority or Rapier law.
The previous physical verdict remains a failed presentation until the owner
evaluates this new source-matched application.

## Inputs and confirmed mechanism

The verified starting PR heads were #566 `214de85adef2`, #593 `9628729af052`,
#606 `2632422aa67e`, and #609 `01a8416761ba`. The isolated correction starts from
`d5397a7d2a1285bf6d2ade5f76e0e89e00e85c70`, preserving the separate cadence
continuation's genuine previous-image history and fixed ACK deadline repairs.
Accepted main for integration is `018bd09503d7f079ddac52e225c2f7daf8d678bf`.

The owner archive `20261115-172915-26552.zip`, SHA-256
`57e08ffedc7d139475609e8d459a68aa9344413a844be50b7ea94f7f1f054a88`, was available
and inspected. Its 36 completed arms use the earlier `7c85b348f707` application,
Windows 11 Pro, NVIDIA TITAN RTX driver `32.0.15.8180`, and Godot
`4.7.stable.official.5b4e0cb0f` OpenGL3. The private capture is not republished.

In the baseline repaired arm's frame 450, live Rapier advances +1.25365 world
cells in Y while the selected overlay moves −5.70120 cells, causing a
−30.91638-pixel screen displacement. The guard changes from live to mask-bound
with `material_in_swept_mask`. Free camera reproduces backward selection with
stationary terrain; smoothing OFF also reproduces it. Therefore neither camera
motion nor an active crossfade is necessary for this remaining failure.

The 2 Hz native arm selects a 19.59430-cell backward movement, −91.63437 screen
pixels, or 85.63439 pixels relative to static terrain. Its longest measured hold
is 249.890 ms; the earlier hosted 364 ms result is a separate observation.
Representative independent shader/overlay projection residuals stay below
0.000136 pixels. Baseline, Free, and the two 2 Hz physical legacy/repaired pairs
have identical recorded Rapier positions at equal completed steps, with
1,194–1,204 matched body samples per pair. These observations establish a
presentation source reversal without establishing a physics trajectory defect.

Source inspection agrees: Main originally followed live Rapier before selecting
the overlay. Every guard veto removed an override, and `render_parts` substituted
an older material-bound pose. The repeatedly growing mask-to-live sweep could
also hit material deposited behind the already displayed actor or the cumulative
32-cell limit. Spatial clearance alone did not define a coherent visual timeline.

## Architectural correction and design choices

`Main._resolve_workbench_presentation_frame` selects actor poses before Follow.
The resulting frame carries session/epoch/generation, material and texture
identity, actual selected/desired Rapier steps, selected poses, explicit reasons,
holds/withholds, camera target, final pixel mapping and resolver CPU duration.
Terrain shader and overlay consume the same frozen mapping and blend value.
Continuous requested camera state and `CyberPixelCameraTransform` are preserved.

For each actor, the conservative guard checks movement from the last actually
selected pose to the desired live pose against both visible material textures.
It does not keep restarting from an increasingly old native mask. A safety veto
can retain the last pose only with a valid material certificate or a successful
fresh stationary-footprint scan. Otherwise that actor is explicitly withheld.
Withheld entries are removed from a copied strict display receipt so the renderer
cannot silently fall back to an older mask pose.

A newer native receipt can rejoin the visual timeline after contact or a large
movement only when its real sampled Rapier step is newer. Main keeps a bounded
2,048-entry sample-serial-to-Rapier-step journal at the existing body publication
boundary. Native tick indices are never substituted for Rapier timestamps.
Unknown initial provenance is recorded as unknown. Session and World replacement
reset the timeline; temporary invalid receipts do not discard an advanced pose.

The chosen policy deliberately permits explicit safety holds and withholding.
The rejected alternative was unconditional live display, which would bypass
visible-material safety. Freezing all motion to native mask cadence would retain
the responsiveness defect. Arbitrary smoothing or visual offsets would obscure
the source mismatch without resolving it. The retained diagnostic
`CYBERSAND_DIAG_PRESENTATION=legacy` makes reversal to the original policy explicit
for matched evaluation. `CYBERSAND_DIAG_FLYER_POSE=mask` remains a separate original
mask baseline. The older render-cadence diagnostic is independent of this choice.

Independent multi-actor review found and corrected an intermediate availability
regression: the full turning-circle scan exhausted the shared deadline and
starved later bodies. The final oracle bounds the already proven sampled,
dilated geometry tightly, precomputes inverse transforms, reads immutable bytes
captured once per actual upload, and can prove a completely empty bounded region
using native byte operations. Every queried cell remains charged to the shared
24,000-cell budget. Admission rotates and bootstraps missing certificates first.
Current/previous texture and upload identity is unchanged; no certificate is
reused merely because a native revision number happens to match.

The independent eight-actor native Workbench probe had 96/128 steady actor
observations and 41/48 full-refresh observations hidden before that correction.
Both paused and unpaused corrected runs displayed all 24 compound parts in all
22 observations (176/176 actor selections), without budget retries. Resolver
medians were 595.5–597 µs for steady frames and 799.5–1,345 µs after full refresh.
Observed total maxima were 2.266–3.256 ms: the two-millisecond bound is a
cooperative query deadline, not a hard whole-stage scheduling guarantee.
Byte-capture cost is included in the consuming frame's resolver total and
reported separately. Large nonempty/rotated custom geometry can still reach an
explicit conservative capacity refusal; universal extreme-contact performance
is not established. The comparison launcher shares the optimized oracle while
restoring the original temporal selection and camera policy.

## Isolated actual production-path evidence

Godot 4.7 on Linux loaded the source-matched #566 runtime
`44c906356a98c84b09c01f6e83bcae2391a4c0e39c5c632431a4a3f4cc1578e9`; all 89
applicable native compiler inputs were verified before execution. Controlled
actual Rapier RID placements and completed steps exercise mounted Main,
Workbench, native World/material receipts, the guard, camera and final overlay.
They are causal presentation stimuli, not claims about ordinary flight dynamics.

| Case | Untouched `d5397a7d2` control | Corrected production path |
| --- | --- | --- |
| Free camera, real Wall veto | Selected X 245 → 240 → 247; −17.53 px reversal | 245 → 245 → 247; veto causes an explicit hold |
| Follow, same stimulus | Approximately −66.53/+66.54 px compensation | No veto jump; camera follows the selected pose |
| Ten clear four-cell advances | Cumulative bound causes a 126.17 px reversal | Continues live past 40 cells with increasing selected steps |
| Invalid epoch/generation/revision | Retained negative behavior inspected | Hides safely; resumes without forgetting the advanced timeline |
| Genuine previous-image uncertainty | Original fallback/phase reproduced | Explicit safe hold/withhold until evidence is sufficient |
| Native Fire PAINT then erase | Existing legacy crossfade retained | Actual Fire ID 6 and Empty readbacks; old Fire prevents stationary admission |
| PAINT receipt and native rejoin | Separate sample/native clocks | Sample 2 maps to Rapier step 3 while native tick is 1 |

The extended candidate fixture completed **335 checks, zero failures, 38
observations**, with maximum independent projection residual 0.000087 px. One
observed scheduler-induced shared-budget refusal was retained and retried with
the identical stimulus under a maximum-four budget-only retry. Unsafe states
and other failures are not retried away. Near-edge placement and session reset
also passed. Scoped resolver median was 120.5 µs and maximum 487 µs in this
controlled fixture; these numbers are not representative 2048² performance.

Other local isolated execution: conservative sweep 33/33; Engine Lab 78/78;
native cadence worker 49 checks; ACK deadline 108 checks; retained pose trace
24/24; retained cadence contract 65/65; analyzer 27/27. Historical PR593 tests
explicitly select the retained legacy policy; the new temporal fixture owns
the new policy's requirements.

Commands use the pinned Godot with `--headless --path godot --script
res://tests/test_workbench_temporal_presentation.gd`, plus
`-- --temporal-evidence=<output>`. The untouched control adds
`--temporal-expect-legacy`. `run_camera_coherence_regressions.py` records process
exits, complete logs, executed source hashes and source deltas. Exact final-source
hosted results belong to the workflow artifacts, not these earlier local counts.

## Integration, qualification and delivery boundary

Local isolated checkpoint `a0315dc87` is published as source-identical commit
`755c99beb9df26281fb5d2940b622370ef0856e8` (tree
`5d48c9ecc4949c702bb42b68d97c7e41433f7922`). Local integration `6b92ad2d4`
is source-identical to published merge
`766d529560130344f3d7e686a3e33add15e3ccc6` (tree
`1d3bfe21430b7fa0bf75917da1d8765e186a4f81`). Later qualification corrections
are descendants; final manifests identify their exact application SHA.

The final local temporal fixture passes 343 checks, including an 80-cell actual
Rapier move rejoining through its newer native receipt without smoothing. The
permanent dense fixture passes 3,227 checks across 150 submissions: eight fleet
actors progress into genuine native terrain contact, 128/128 controlled moving
selections are live, and the ordinary two-second phase has 947 live plus 13
certified held selections with no withholding. A supported 128² compound also
displays in all eight clear-space samples. A fresh-upload frame records three
budget-withheld bodies at 2.992 ms, recovered on the next frame; the fixture
retains this event, permits one isolated budget interruption, and rejects
repeated disappearance. This is not a claim of universal zero flicker.

Integrated local authoring checks preserve native PAINT/Undo/Redo and fresh
reopen, material catalogue (1,348 assertions), pixel picking (1,699 checks),
Flatten including failure/reopen/storage-fault cases, and combined 512² authoring
with one and four native workers. Architecture native (812), project (1,952),
UI (56), reopen (18), multistyle author/reopen (72/26), legacy generation and
material equivalence pass. The separate headless architecture author phase
retains four form-layout failures; its graphical campaign remains a required
gate. These are tree-hashed local results, not final Windows acceptance.

The integration preserves current main's generator, Flatten, material and
authoring changes. Its retained native runtime was built at
`6d6e2cd68490591fbdac3e17dab0caed49c84758` with 93 compiler inputs. Linux SHA-256 is
`0cbef228d1ce28772ac3f4d6f3dcc2cc7778775abe631bd39e71239eda404d7b`; Windows is
`373b74cbaf19089422c30f89da7aaab170052a541d8383766286f6a522c793b0`. Packaging
reuses these binaries only after checking all applicable canonical inputs and
the unchanged native source against accepted main. A newer application source
does not relabel the native build.

The exact-source workflow exercises actual temporal/camera/material safety,
native PAINT and persistence, accepted-main generation/Flatten/combined
authoring, and matched 2048² Needle comparisons. Windows qualification extracts
the standalone ZIP, verifies its payload, runs installed tests and executes the
real `Test It.cmd`. Actual frame intervals, native/Rapier/publication rates and
resolver CPU distributions are recorded separately from requested caps.

The owner procedure is in the [acceptance guide](../operations/camera-stack-coherence-acceptance.md).
Hosted Windows rendering and local Linux software rendering are qualification
evidence only. Neither establishes physical NVIDIA smoothness, display timing,
driver behavior or owner preference. Genuine safety holds/withholds and contact
costs must remain visible in those results. All four PRs remain Draft/HOLD and
unmerged; no auto-merge or physical acceptance is authorized by this record.
