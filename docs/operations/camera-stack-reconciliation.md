---
title: Camera stack reconciliation and rendering handoff
status: Current
document-kind: runbook
scope: Isolated camera and Engine Lab staging on accepted GEN-007 main, component disposition, runtime custody and the independently owned rendering repair
canonical-for: [camera-stack-reconciliation, camera-stack-rendering-handoff]
last-reviewed: 2026-11-15
related-documents: [native-pixel-scrolling.md, architectural-generator-playtest.md, gen008-flatten-qualification.md, ../systems/material-appearance-and-rendering.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../audits/2026-11-15-camera-stack-reconciliation.md]
---

# Camera stack reconciliation

**Conditional integration candidate; no merge or Ready promotion.**
`integration/camera-stack-reconciliation-20261115` starts from accepted main
`018bd09503d7f079ddac52e225c2f7daf8d678bf` (tree
`dd4eed8f95cfe21197a98fdc7ef663bee873dc94`). That is the owner's 15 November
GEN-007 #582 merge and includes accepted GEN-008 Flatten. The four original
branches and their review/failed evidence remain untouched.

The candidate preserves the camera's qualified spatial transform and current
authoring functionality. **It does not repair or accept the actor-versus-terrain
stutter.** Its temporary actor display stays bound to the uploaded material
receipt and can visibly hold/jump at slow native cadence. The independent #609
worker owns the causal diagnosis, temporal design and eventual corrected result.

## Source composition

The [complete source inventory](../audits/2026-11-15-camera-stack-source-inventory.json)
records heads, trees, immediate parents, common bases, independent paths,
cumulative paths, original commits and overlap. All four original heads share
main merge-base `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`.
The [per-path provenance map](../audits/2026-11-15-camera-stack-source-map.json)
records retained file hashes and exact originating heads. The candidate's
accepted-main first parent and #566 second parent preserve the camera's original
qualified palette-transition ancestry; the selected tree omits obsolete jobs.

| Component | Immutable inspected head | Disposition in this candidate |
| --- | --- | --- |
| #566 camera | `214de85adef2aaabc8e26de8612a3bf27cc1a081` | Keep camera, coordinate consumers, recording, effects and their actual-frame tests; reconcile docs and Flatten source; replace branch-pinned qualification orchestration |
| #593 presentation | `9628729af052b417aa8a64e56f7e7bcdf4f2e876` | Keep receipt/session/epoch/generation/finite-pose safety only; exclude guarded-live selection, swept oracle and previous-texture occupancy scans |
| #606 Engine Lab | `2632422aa67ee9acdc347089cd54c36e518c713a` | Keep with modification: live clock/FPS/VSync controls and achieved measurements; no delayed ACK or dependency on guarded-live presentation |
| #609 trace | `01a8416761ba3477a2587d7b07a854945b0f0286` | Wait for worker-owned coherent diagnostic/repair delta; no moving source imported |

The accepted-main overlap is larger than the six documentation paths shared
with #582 alone. Flatten changes `main.gd`, `shared_workbench.gd` and
`workbench_paint_editor_controller.gd`, all touched by #566. Their changes compose
without textual conflict but require native authoring/reopen qualification.
The camera patch has five textual documentation conflicts; these retain both
current architectural/Flatten contracts and camera contracts. The retrieval
corpus keeps historical evidence outside current-answer context.

The original #566 `native-pixel-integrated-qualification.yml`, its paired
`native_pixel_integrated_qualification.py` and test, and its modifications to
`wb-art-paint-qualification.yml` are not imported. They pin the older campaign,
accepted base or runtime publication. Reusable underlying camera, recorder,
effect, PAINT and performance fixtures retain their provenance.

## Camera and authoring boundary

`CyberPixelCameraTransform` and the palette shader are retained from #566.
Continuous requested world coordinates are separate from final framebuffer
translation. Picking and terrain use the same sample centre, reciprocal and
operation order. Overlay consumers receive `presentation_camera_origin()`.
Follow is updated once in Main before terrain/overlay submission; the child
Workbench no longer changes camera state after that publication point.

The spatial transform does not wait for a native tick or texture publication.
Actor pose freshness is a separate temporal problem: following a live actor
while displaying an older mask-bound actor can still produce judder. No new
camera easing, speculative pose heuristic or physics law is introduced here.
The retained palette crossfade also uses the requested publication interval to
set its blend duration; that is a temporal assumption, independent of the
camera's spatial mapping. Delayed publication and previous-texture lifetime must
be reviewed with the eventual #609 repair, not inferred from a correct projection.

Recording encloses the displayed fractional view, including partially visible
right/bottom cells, and preserves that initial ROI for the session. It records
simulation-state material data, not a screen-video or exact physics continuation.
The native recording regression also fixes a retained startup defect: an
unprimed recorder waits through an empty, already-ACKed status receipt for its
requested full material refresh. Malformed publications still fail.
The accepted generated-start and flattened material-baseline formats remain
unchanged. Source-native GEN-007 five-style algorithms, material IDs and Viaduct
v2 are inherited unchanged from accepted main.

## Receipt-only actor staging

`Main._valid_workbench_mask_frame` validates physical session, epoch, displayed
World generation, material revision and the instance dictionary.
`Main._present_physical_actor_overlay` is the single future renderer admission
point. The staging path requests strict receipt handling from
`CyberPhysicalActorSession.render_parts(display_frame, require_mask_receipt)`.

Strict Workbench presentation requires matching per-actor generation and a finite
copied `Transform2D`. Missing or stale receipts suppress the affected overlay;
they cannot silently fall back to a live RID with a different displayed material
state. Non-Workbench/geometry-inspection callers retain their original API.
This is the independently useful safety slice of #593, not its clearance oracle
or unaccepted smooth-presentation claim.

The genuine-native `test_workbench_mask_receipt.gd` fixture exercises receipt
identity, actual World replacement, a deliberately different live pose and the
historical live fallback as a negative control. Its results must name the exact
reconciliation SHA and loaded native runtime.

## Engine Lab scope and clock semantics

The limited Engine Lab retains requested Pixel/native pacing, Rapier callback
rate, render publication rate, FPS cap, VSync, native sample wake and the
Workbench completed-native-sample wait control. These are experimental scheduling
controls. FPS cap, Rapier callback cadence and main-window VSync apply to the
current application process and survive a return to the feature launcher. Pixel
pacing and material-publication targets belong to the current native owner.
**Restore baseline** restores the values captured when that Lab was mounted,
not necessarily project defaults; a new application process restores unsaved
defaults. Only an explicitly saved worker request persists across application
launches. Scene teardown retires the Lab capture and its session-bound scripted
input. This process scope is retained from #606.

The integrators still advance fixed **1/60 simulated seconds** per completed
step; changing wall-clock targets can dilate simulation time.

Requested rates and achieved Main-observed native ticks, completed actor-session
steps after Rapier, process frames and successful texture publications are
reported separately. The Lab's `rapier_steps` is `physical_actor_session.tick`;
the enhanced external performance apparatus separately reads the bridge's
completed `space_step` counter. A successful actor completion follows that step,
but an actor completion refused after a flight-step fault can differ from a
completed low-level Rapier step. The downstream trace must preserve that scope
and qualify the fault path if it relies on either counter. A publication serial
gap is not an upload count. Workbench still refuses to simulate the same prepared
Rapier sample twice; sample wakes can also advance earlier than the requested
Pixel interval. Therefore control independence does not promise arbitrary achieved
rates or smooth motion under overload.

Aggregate `valid=true` certifies identity/settings continuity and the capture's
listed invalidation conditions. It does not certify absence of actor-step faults
or equality of the actor and bridge counters: a flight fault can suspend the
actor without pausing Main or failing the native owner. Before relying on this
aggregate for faulted/refused-completion behavior, qualify a real fault-path
negative control that retains both counters and proves explicit fault
invalidation or separately labelled physics-step and actor-completion rates.
The current qualified rate observations do not establish that fault-path gate.

**ACK is immediate after successful upload.** The original #606 delayed-ACK
countdown can restart on each newer upload and postpone acknowledgement
indefinitely. Its replacement belongs to the active rendering worker and is not
independently implemented here. The candidate neither removes mandatory ACKs nor
changes the native render mailbox ownership contract.

## Runtime custody

No native C++, native extension input, material definition, solver policy,
retained native library or runtime provenance file is changed. The accepted
native build remains source `6d6e2cd68490591fbdac3e17dab0caed49c84758`, tree
`0b18ce0e848a1bed4847dc3f2f9253411ffdc1bd`. Verify every provenance input against
the candidate before reusing it; record the new application SHA separately.

| Retained runtime | SHA-256 |
| --- | --- |
| Linux native SO | `0cbef228d1ce28772ac3f4d6f3dcc2cc7778775abe631bd39e71239eda404d7b` |
| Windows native DLL | `373b74cbaf19089422c30f89da7aaab170052a541d8383766286f6a522c793b0` |
| Selected Linux Rapier | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Selected Windows Rapier | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

Use Godot `4.7.stable.official.5b4e0cb0f`. The existing #606/#609 package builders
pin older #566 libraries and guarded rendering; they are excluded. The
reconciliation package exports the exact candidate, retains accepted build
provenance and tests its copied payload with its included one-command runner.

## Qualification and physical acceptance

The [dated reconciliation record](../audits/2026-11-15-camera-stack-reconciliation.md)
owns actual execution results. The commands/coverage here are requirements, not
claims that a run has passed.

- Camera: actual native picking/edit/readback, Free/Follow, 1× and fractional
  scaling, zoom, framebuffer samples, recording artifact decoding and effect alignment.
- Accepted main: five-style GEN-007 and legacy v1 reconstruction; PAINT shapes,
  Fill, Undo/Redo; agent drawing; Flatten/edit/Save and separate-process reopen.
- Ownership: real moving actors/native terrain, successful-upload-before-ACK,
  paused/running/mismatched clocks, stale session/World rejection and shutdown.
- Performance: same-host accepted-main/candidate comparisons with achieved rates,
  frame/Main/worker/upload timing and retained adverse results. Software rendering
  never establishes the owner's physical NVIDIA GPU experience.

The older #566 Linux penalty remains unresolved evidence; favorable measurements
elsewhere cannot erase it. Physical Windows DPI at 125%, 150% and 200%, VSync,
long moving-contact sessions and perceived actor/terrain coherence remain owner
acceptance. The candidate must not be described as a stuttering repair.

## Downstream #609 handoff

At audit, the worker's published continuation was
`fix/render-cadence-001-20261115` at
`7c85b348f7077adbc7dbbf338f92683ac0df08f4` at the 09:50 UTC refresh;
this is separate from the original #609 PR tip. Its application remains the
`d5397a7d` result; the newer commit only extends its Windows matrix deadline. Its retained 2-Hz fixed-camera negative control still showed a
364-ms pose hold and 88-pixel catch-up despite matching completed-step physical
trajectories. Complete presentation remained **FAIL/HOLD**. Refresh the actual
worker source and published evidence before admitting any delta.

The integration boundary is deliberately small:

1. Review the worker's exact root cause and remaining negative controls.
2. Import its one coherent diagnostic schema, reference fixture, analyzer and
   physical test runner together; do not duplicate or relabel the old versions.
3. Compose the approved selector through `_present_physical_actor_overlay`,
   retaining strict receipt fencing. The original #593/#609 signature uses
   `(frame, presentation_poses, require_mask_receipt)`; the staging second boolean
   moves to the third position only when a proven selector is admitted.
4. Review successful texture upload, previous-texture lifetime and fixed-deadline
   ACK changes as one ownership transaction. Any additional World-sized CPU image
   requires renewed memory/upload/frame measurements.
5. Re-run receipt, camera/framebuffer, cross-clock, PAINT/Flatten/generator
   regressions and source-matched Windows copied-package execution. Changes to
   Main or `render_parts()` also require the five PLAY-UI007 graphical navigation
   cases, actor-prototype/actor-rig/Blacksite and affected physical-flight
   rendering/session fixtures. Preserve receipt-free geometry inspection callers.
6. For ACK/publication changes, repeat `test_camera_stack_recording.gd` and the
   recorder/full-refresh regressions, including late attachment after an
   already-ACKed empty status receipt. Then obtain physical owner acceptance
   and explicit integration approval.

The original diagnostic contract at `01a84167` provides the following interfaces
for the worker-owned downstream delta; none is copied into this staging tree:

| Surface | Retained contract for admission |
| --- | --- |
| `begin_workbench_pose_trace(settings)` / `finish_workbench_pose_trace()` | Bind application SHA, actual native-library SHA, engine and experiment settings; preserve opt-in operation |
| `_workbench_trace_presentation_frame(...)` | Observe final overlay parts and the one presented camera after selection; never recompute an alternative pose for the trace |
| `workbench_pose_trace.gd` | JSONL `cybersand-pose-trace-v1`: header, ordered frame rows, summary; at most 12,000 frames and 32 bodies with explicit drop, duplicate and body-truncation counts |
| Frame identity | Process/physics frame, native tick/snapshot serial, completed Rapier step, session/epoch/World/material identities, uploaded serial, requested/presented camera and blend state |
| Body evidence | Bound/live/selected/first-drawn-part poses, actual selector reason, projection residual and screen displacement; Main submissions are not GPU-present timestamps |
| `engine_lab_reference_fixture.gd` | Reconstruct the 2048-square reference with 256 chunk receipts on accepted-main native bytes; original fixture JSON SHA-256 `b001849d0823b9a1c3fdff7a650d455945eb1ebb885004e9836ee7525ce1b954`, material SHA-256 `71610b37531531e284f069cf1e07c151283a441c9b0ff32a4fcc1dbb6c997a7a` |
| Tick-addressed input tape | Compare identical input at completed Rapier steps, with epoch/World fences; wall-clock key timing is not trajectory equality |
| Focused tests and analyzer | Requalify `test_workbench_pose_trace.gd`, `test_engine_lab_physical_test_it.gd`, `test_analyze_pose_trace.py` and the worker's final cadence/ACK tests together with its final schema |

The current aggregate Engine Lab report is not a second pose trace. It exposes
snapshot/material age and completed counts but explicitly leaves GPU-present
time, worker wait duration and backlog depth unmeasured. Those remaining
diagnostic fields belong to the worker's source-mapped trace integration.

Do not merge the original four PRs sequentially: that would reintroduce excluded
guard/default/ACK/packaging behaviour. The shortest future composition is this
accepted-main-based candidate plus the minimum reviewed final worker delta,
followed by the affected acceptance gates. Existing branches retain their history
until the owner chooses how to retire them.
