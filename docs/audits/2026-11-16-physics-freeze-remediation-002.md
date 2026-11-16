---
title: Workbench publication and physics-freeze remediation002
status: Historical evidence
document-kind: audit
scope: Owner-authorized PR609 publication repair; source-bound tests and limitations, not physical acceptance or merge authority
canonical-for: []
last-reviewed: 2026-11-16
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../operations/camera-stack-coherence-acceptance.md, 2026-11-15-workbench-physics-freezes.md]
---

# PHYSICS-FREEZE-REMEDIATION-002

## Intake and ownership

The owner authorized runtime implementation, regression repair, matched
performance qualification and a standalone Windows evaluation. Starting PR609
HEAD was revalidated as `c1ad4910a07422b37d63df270bac337863ae7b2f`, tree
`911d68c8d741691a0e2fe85194515b6145151cff`. Accepted main remains
`018bd09503d7f079ddac52e225c2f7daf8d678bf`. All #566→#593→#606 ancestors are
retained; all four PRs remain Draft/HOLD and unmerged. Starting Actions runs
43779233966/application30660 and43786549963/c1ad were both successful, with
their original scope retained. This does not reinterpret them as performance
acceptance or evidence for the new implementation.

The isolated checkout preserves prior evidence. Native source, Godot 4.7
`5b4e0cb0f`, Rapier version/backport, actor laws and dependency pins are unchanged.
Both desktop native libraries were authenticated against the 93-input retained
build ledger, and both Rapier libraries against their recorded build inputs.
The package manifest and [PR609 ledger](https://github.com/techrote/cybersand/pull/609)
identify the final source/tree, exact-HEAD Actions runs and downloadable payload.

## Established causes and implemented repair

The old CPU patch path still calls `ImageTexture.update` for the complete World
plane. At 2048² RG8 this is 8 MiB per changed publication. CPU patch size does
not imply partial GPU upload. The first array-based repair reduced submitted
bytes but introduced shader cost and retained expensive Windows submission
spans; its rejected results are recorded below.

The current candidate uses Godot 4.7's experimental drawable-texture API on the
qualified Linux/Windows OpenGL/ANGLE compatibility paths. Two persistent linear
RGBA8 targets retain exact logical R8/RG8 current/previous material values. A
bounded set of R8/RG8 staging textures receives one immutable atlas upload per
publication, followed by GPU rectangle copies into the recycled history target.
A dense update uses one full staging upload and one whole-World copy. The
production path never reads GPU pixels back to construct an update.

At 2048²,128² tiles bound dirty tracking to 256 entries. Recycled histories repair
all accumulated dirties and skip byte-identical cached tiles. A single changed
tile uploads 32 KiB instead of 8 MiB. The two history targets, staging resources and
retirement sink occupy 44,728,324 logical GPU texture bytes, excluding driver
allocation overhead. CPU submission bytes exclude GPU source reads and RGBA8
target writes; the latter are reported as a logical estimate, not bandwidth.
Upload Images remain immutable while RenderingServer may retain queued refs.

All six original appearance shaders are restored byte-for-byte from c1ad;
material indexing, crossfading, neighbour reads and effects retain ordinary 2D
sampling. In particular, the protected palette returns to its existing reviewed
SHA256 `b8e5542dae2c36fd6fbef0170a7b537bce5c853fc10920174cefe13dbec78d4f`.
The material catalogue compatibility guard is retained without a waiver.
A small separate `texture_blit` Shader uses nearest integer source texels,
blend-disabled output and direct per-call coordinates. It writes exact R/G,
zero B and opaque A into a linear target; SRGB targets are rejected.

The pinned [DrawableTexture2D resource implementation](https://github.com/godotengine/godot/blob/4.7-stable/scene/resources/drawable_texture_2d.cpp),
[GLES3 texture storage](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/storage/texture_storage.cpp),
[blit shader](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/shaders/tex_blit.glsl)
and [API contract](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/DrawableTexture2D.xml)
identify this mechanism and its experimental status. The implementation uses
single-target calls and ends each changed batch with a 1×1 sink copy: the engine
otherwise leaves large targets attached to its persistent framebuffer after
resource release. The tiny copy is included in submission timing. No resource
queue, unbounded allocation stream or global publication cache is introduced.

`auto|full|blit` selects publication. Unsupported platforms/backends/capacities
and detectable resource failures reconstruct both exact full ImageTextures from
retained CPU histories. The void blit API cannot prove that arbitrary later
GPU/device failure was detected. Cold first use, full initialization and dense
copies remain separately measured risks. Current/previous content certificates,
revision ACKs and safe presentation/collision masking retain their identities.
The exact previous CPU Image also avoids the redundant legacy per-cell
occupancy scan; callers without that image retain conservative bounded checks.

Previously `_publish_snapshot` completed graphical extraction and packing
before exposing native completion to Main physics. The candidate publishes one
immutable physical mailbox after post-tick edits and exact required hard
geometry, before graphical work. It shares one globally reserved owner-turn
serial with the later graphical snapshot. The existing sample wait, maximum
feedback age, fixed 1/60 timestep, owner/epoch/generation and complete-terrain
gates remain. An older graphical packet cannot roll terrain back. Failure
quarantines both slots; retirement cannot resurrect old graphical authority.

The native owner still performs graphical packing before its next tick, and
Rapier remains main-thread owned. Rendering/upload contention can still delay
physics callbacks. Mailbox/status publications are not physical completions.
No uncoupled default, extrapolated pose or changed physics law is introduced.

## Focused local evidence and negative results

These observations are Linux llvmpipe on Xeon Platinum 8370C, not physical NVIDIA.
The c1ad control uses the original 2048² Needle geometry/tape, Fire ON→OFF and
ordinary coupled defaults. Each capture records 144 completed steps/143 gaps.

| Control | Rapier steps/s | Gap median/p95/p99/max ms | Gaps≥100/250/1000 ms |
| --- | ---: | --- | --- |
| Follow |4.032671|224.336 /353.776100 /522.577620 /587.134|143 /53 /0|
| Free |4.052381|235.405 /340.267000 /427.180380 /606.582|143 /59 /0|

Follow native tick median was28.099 ms, while completion→next physical admission
median was 191.996 ms. Typical upload spans were only about 4 ms in these captures.
The complete gap is therefore not attributable to the upload call or native
computation alone. Software shader/frame execution and unmeasured scheduling
remain material. No sum of overlapping scopes is used as causal accounting.

A frozen same-source full-texture combined→early handoff pair matched all 144
recorded positions, orientations, linear velocities and native associations.
Rapier rate3.713→4.061 Hz; median gap266.834→241.552 ms; p95 337.724→306.890 ms;
maximum490.397→427.990 ms; gaps≥250ms94→62. Every 143 gap still exceeded100 ms.
Native and upload timings also varied between these sequential arms, so the
whole difference cannot be isolated to scheduling. This is developmental
source-delta evidence, not the final source ABBA result or playable acceptance.

Initial real Workbench/Rapier barrier checks passed57 assertions both headless
and graphical: held graphical publication permits0 physical steps in the
combined control, exactly1 in early mode, then the strict next-sample wait
holds. They also verify exact GCR/terrain identity, paused hard PAINT, older
geometry refusal, reset, single-step and cleanup. The final test adds a retired
epoch during held publication; its final executed counts belong to CI evidence.

All failed development attempts are retained separately: a typed-array test
parse failure, an initial shader sampler-argument incompatibility, and an
incorrect vapour comparison fixture. In the latter the test reused a full
ImageTexture as both a linearly sampled Canvas carrier and nearest material
sampler; it interpolated material IDs. The corrected fixture uses production
ColorRect/nearest sampling. The failure PNGs/logs remain evidence and are not
claimed successful production output. No cosmetic material/physics change was
made to hide the mismatch.

## Rejected first checkpoint and follow-up

Checkpoint `e2a489a20a9585ca5a56d82ac526aee75d7ae322` (tree
`b7cc284381b29021788555842fa80c3b04cd326a`) is **not a successful performance
candidate**. Its complete Linux and Windows source ABBA evidence is retained in
[Actions 43825168135](https://github.com/techrote/cybersand/actions/runs/43825168135).
All four 144-step matched pairs per host retained exact recorded physical bodies
and native associations; there were no missing native/Rapier completions. This
correctness result does not turn adverse timing into acceptance.

On Windows WARP, the first Follow pair changed Rapier9.529→9.678 steps/s but
median/p95/p99/max gaps111.714/116.227/152.027/153.021→
124.282/139.505/223.397/254.968 ms. Across all four Windows candidate arms,
material-upload medians98.323–102.439 ms exceeded the controls85.669–86.829 ms.
Backend submission scopes alone had medians94.917–98.793 ms despite a median
360,448 submitted bytes. These are elapsed call scopes, not isolated GPU or
CPU time. Prior-render synchronization is a plausible dependency, not a proven
attribution. Linux llvmpipe also regressed: Follow controls7.595/7.276 steps/s
versus candidates5.562/5.466. A local Follow ABBA independently reproduced that
direction; it was stopped after all four Follow arms, leaving Free unqualified.

A separate render-only probe reproduced added array sampling cost without any
native work or timed uploads. Integer division plus `texelFetch` was slower;
shift/mask addressing helped but remained insufficient. The adopted follow-up
uses normalized nearest sampling and a cached tiled Shader specialization.
Mixed-material forward/reverse median frame-post-draw intervals changed from
shift/texelFetch284.541/264.262 ms to normalized-specialized204.090/191.512 ms;
full-texture controls were210.966/174.355 ms. Actual framebuffer bytes matched.
An open-flight probe still showed a full-versus-tiled cost gap. These software
renderer probes justify the shader repair but establish neither end-to-end
physics improvement nor physical NVIDIA acceptance. Negative alternatives and
raw timings remain retained.

The e2 integrated run also exposed two qualification failures. The pacing
fixture required fresh contact while its Needle was still physically airborne
after Fire OFF. The repaired oracle retains that original flight window and
adds neutral-input recovery, requiring fresh selected-Needle contact within
360 actual fixed steps and a separate wall watchdog. It changes no physics law.
The Windows publication fixture rejected initial readiness at its30s setup
allowance; the available log does not identify the blocking startup subsystem.
Only initial readiness now uses the pacing fixture's existing90s allowance and
records actual setup/owner state. The later30s waits,5s injected graphical hold,
150 ms observation window and64 behavioral assertions remain unchanged.

The normalized graphical material gate passed224 assertions with all eight
nonvacuous appearance comparisons exact, plus19 headless fallback assertions.
The39-assertion cache/provenance/lifetime gate is included in both integrated
platform case lists. Final source performance and complete application gates
must still decide the follow-up's disposition.

## Drawable follow-up and retained limitations

The exact 6f57 full/tiled same-source ABBA matched all144 recorded steps in both
pairs but produced mixed timing. Forward full→tiled changed4.073→3.962 steps/s,
median230.341→238.794 ms and p95 317.124→317.502 ms. Reverse full→tiled changed
4.029→4.665 steps/s, median222.376→211.545 ms and p95 364.004→244.881 ms. Every
143 gap in every arm still exceeded100 ms. This is not a uniform repair.

A standalone drawable prototype passed 113 actual GPU/appearance assertions,
including all byte values in R8/RG8, current/previous history, NPOT edges, seams,
Canvas clipping interleaving, eight nonvacuous shader outputs, sparse/dense2048²
updates, and invalid layout/sink/SRGB rejection. Its first NPOT sparse calls
included48–58 ms blit spans. Initial parse/type mistakes and all cold observations
are retained, not presented as warmed results.

The first warmed drawable prototype exposed another negative: mutable custom
copy uniforms caused repeated material-buffer updates, and dense publication
spans reached about 35 ms on llvmpipe. A contained direct-coordinate variant uses
the API's per-call `MODULATE` vector instead. A matched forward/reverse isolated
copy probe, independently reduced with conventional interpolated quantiles,
reduced sparse submission medians 4.1555/3.3250→1.0055/1.0845 ms and dense
29.7500/31.8970→5.7860/5.9125 ms with exact pixels. First direct dense staging calls
of 42.647/77.197 ms remain in the evidence. Dense whole-frame intervals remained
about 49–53 ms. This reduces time inside the submission call but does not establish
lower total GPU work or end-to-end physical improvement. Source-qualified
Workbench and Windows comparisons, including cold/dense costs, remain required.

The integrated production gate then passed 293 actual GPU/appearance assertions,
including all eight nonvacuous comparisons after restoring the original shaders.
Headless history/fallback passed 18, full-upload coverage 264, palette bounds 27,
vapour callers 26 and native-camera effect callers 62. These are working-source
development gates; final exact-HEAD platform runs remain the qualification gate.
Production setup primes each fixed staging source with a tiny sink copy and
reports that preparation inside initialization. This does not guarantee a
nonblocking first edit: the final correctness run retained a 63.019 ms staging
upload for the immediate first 2048² sparse update despite only 32 KiB submitted
(copy submission 0.420 ms). Its following dense update took 10.619 ms overall.
These observations remain visible alongside warmed results.

Independent raw joins on World generation, native tick, revision and body sample
showed that graphical handoff finished at least 121.924 ms before the next Rapier
step started in the first three 6f57 arms. Render exchange medians were 0.609–0.707 ms
and post-exchange snapshot tails about 1.0–1.2 ms. Under the unchanged sample
contract, another packing worker cannot remove that demonstrated idle period:
the next authoritative physical feedback did not yet exist. This is a conclusion
about those captures, not proof that packing can never limit another workload.
Godot's Main loop batches physics callbacks before process/render; merely moving
uploads to its experimental Separate render thread retains a later Main sync
barrier and does not grant independent physical progression through a long wait.

The 6f57 Windows installed suite and actual PowerShell5.1 Test It.cmd passed, but
the ordinary launcher test hit its 300s readiness watchdog. An actual configured
feature-launcher reproduction proved the blank Workbench was fully installed:
it had zero authored actors and intentionally no physical owner/initialized
Rapier. The diagnostic readiness gate incorrectly required that bridge anyway.
The narrow fix permits the valid blank state while requiring an adopted owner,
initialized bridge, reset fence and complete terrain whenever actors are
configured. Four missing-owner attempts refuse; restoring the blank setup emits
a receipt, and the ordinary headless entry exits successfully. This corrects a
qualification gate, not gameplay physics. Genuine final Windows launchers must
still execute successfully.

## Final qualification and evidence interpretation

`run_physics_freeze_comparison.py` extracts immutable c1ad source, authenticates
its reused native/Rapier inputs, verifies every executed candidate source, and
runs serial ABBA on each host for ordinary Follow/Free. It requires contiguous
completed-step prefixes and matching actor slots, then exact equality of all
recorded positions/orientations/linear velocities and native admission fields.
It retains full-arm and common-prefix distributions,50/100/250/1000 ms counts,
actual rates, missing/duplicate completions, hold reasons, stage timings and
native-completion→physical-admission delay. It does not observe every hidden
Rapier state or numeric native force/torque value.

The ABBA common-observer mode suppresses new `main_callback` and
`physics_publication` events; runtime stage counters remain charged to candidate
cost. Detailed installed Test It captures retain those events separately.
Elapsed scopes include OS descheduling and possible backend waits; none is an
isolated CPU execution, GPU completion, transfer-bandwidth or scanout measure.
Evidence includes adverse tails and failures, not only averages.

Targeted drawable qualification covers R8/RG8, non-power-of-two extents, tile seams,
recycled histories, effect-only edits, full resync, live mode switching, malformed
resource fallback, bounded2048² submissions and actual pixels from all shader
consumers. Physical publication tests exercise real native/Rapier owners and
negative lifetime/terrain/sample cases. The integrated suite retains PAINT,
Undo/Redo, fresh reopen, failure recovery, generator/Flatten/Materials Lab,
multiple actors, contact and the presentation coordinator. Linux and Windows
graphical ordinary contact/pacing cases supplement the original Needle workload.

The final Windows workflow extracts the actual ZIP into a fresh directory,
verifies all hashes, executes the three actual ordinary/publication launchers,
then runs Windows PowerShell5.1 `Test It.cmd` and its independent reducer.
`Open Publication Control.cmd` means full textures plus combined handoff in the
same source; `Open Full Texture Control.cmd` retains early handoff. Neither is
mislabelled a historical binary. Exact source-control comparison is separate.

No hosted result grants physical Windows11/NVIDIA acceptance. Successful
engineering qualification with that gate outstanding is **ENGINEERING QUALIFIED /
PHYSICAL HOLD**. If functional/equivalence gates fail, engineering remains
**FAIL/HOLD** too. The final PR/artifact ledger records the observed disposition;
this implementation record grants no Ready, auto-merge or merge authority.
