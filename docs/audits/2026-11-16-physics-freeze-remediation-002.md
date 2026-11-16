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
plane. At 2048² RG8 this is 8 MiB per changed publication. Exact Godot 4.7 GLES3
source maps the ordinary 2D update to `glTexImage2D`, while a texture-array layer
update maps to `glTexSubImage3D` with depth 1. These API/source facts establish a
real bounded submission mechanism, not the cause of every observed wall span.
The implementation can be inspected in the pinned [Godot 4.7 GLES3 texture
storage](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/storage/texture_storage.cpp)
and [ImageTextureLayered implementation](https://github.com/godotengine/godot/blob/4.7-stable/scene/resources/image_texture.cpp).

The candidate represents current/previous material as two bounded arrays, at
most 256 layers each. Tile side starts at 64 and grows to fit the layer budget;
2048² uses 128²×256. Two 1×1 Canvas carriers preserve the existing Texture2D
interface without uploading a full material plane through that interface.
Actual array RIDs and exact GPU reconstruction are separately observable.
The production path never uses GPU readback to assemble an update.

Each recycled slot repairs the union of current dirty rectangles and the
preceding publication's changes, then compares exact cached tile bytes before
issuing an update. Thus a two-publication-old slot cannot leak stale texels.
When an exact previous CPU image is retained, publication also skips the
redundant legacy per-cell occupancy-map scan. The legacy path retains its
bounded map and conservative refusal.

Current/previous CPU history and material-content certificates remain separate
from GPU resource identities. All six material shader consumers use the same
global-texel→tile/layer lookup, including cross-tile neighbours. The follow-up
uses normalized nearest texel-centre sampling with an exact power-of-two
reciprocal. Each material caches its base Shader and one tiled specialization;
unchanged publications neither construct nor reassign Shader resources.

The default is `auto` on qualified OpenGL/ANGLE; `full` retains the whole-image
path and `tiled` requests arrays subject to compatibility/capacity checks.
Detectable structural failure reconstructs both full textures from the exact
retained CPU histories and retires superseded array resources. `update_layer`
has no error return: arbitrary asynchronous driver/device loss cannot be
claimed detectable at submission. Full initialization/dense updates remain
potentially expensive. No unbounded upload queue or GPU allocation stream exists.

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
The c1ad control uses the original2048² Needle geometry/tape, Fire ON→OFF and
ordinary coupled defaults. Each capture records144 completed steps/143 gaps.

| Control | Rapier steps/s | Gap median/p95/p99/max ms | Gaps≥100/250/1000ms |
| --- | ---: | --- | --- |
| Follow |4.032671|224.336 /353.776100 /522.577620 /587.134|143 /53 /0|
| Free |4.052381|235.405 /340.267000 /427.180380 /606.582|143 /59 /0|

Follow native tick median was28.099ms, while completion→next physical admission
median was 191.996ms. Typical upload spans were only about 4 ms in these captures.
The complete gap is therefore not attributable to the upload call or native
computation alone. Software shader/frame execution and unmeasured scheduling
remain material. No sum of overlapping scopes is used as causal accounting.

A frozen same-source full-texture combined→early handoff pair matched all 144
recorded positions, orientations, linear velocities and native associations.
Rapier rate3.713→4.061Hz; median gap266.834→241.552ms; p95337.724→306.890ms;
maximum490.397→427.990ms; gaps≥250ms94→62. Every143 gap still exceeded100ms.
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
124.282/139.505/223.397/254.968ms. Across all four Windows candidate arms,
material-upload medians98.323–102.439ms exceeded the controls85.669–86.829ms.
Backend submission scopes alone had medians94.917–98.793ms despite a median
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
shift/texelFetch284.541/264.262ms to normalized-specialized204.090/191.512ms;
full-texture controls were210.966/174.355ms. Actual framebuffer bytes matched.
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
150ms observation window and64 behavioral assertions remain unchanged.

The normalized graphical material gate passed224 assertions with all eight
nonvacuous appearance comparisons exact, plus19 headless fallback assertions.
The39-assertion cache/provenance/lifetime gate is included in both integrated
platform case lists. Final source performance and complete application gates
must still decide the follow-up's disposition.

## Final qualification and evidence interpretation

`run_physics_freeze_comparison.py` extracts immutable c1ad source, authenticates
its reused native/Rapier inputs, verifies every executed candidate source, and
runs serial ABBA on each host for ordinary Follow/Free. It requires contiguous
completed-step prefixes and matching actor slots, then exact equality of all
recorded positions/orientations/linear velocities and native admission fields.
It retains full-arm and common-prefix distributions,50/100/250/1000ms counts,
actual rates, missing/duplicate completions, hold reasons, stage timings and
native-completion→physical-admission delay. It does not observe every hidden
Rapier state or numeric native force/torque value.

The ABBA common-observer mode suppresses new `main_callback` and
`physics_publication` events; runtime stage counters remain charged to candidate
cost. Detailed installed Test It captures retain those events separately.
Elapsed scopes include OS descheduling and possible backend waits; none is an
isolated CPU execution, GPU completion, transfer-bandwidth or scanout measure.
Evidence includes adverse tails and failures, not only averages.

Targeted array qualification covers R8/RG8, non-power-of-two extents, tile seams,
recycled histories, effect-only edits, full resync, live mode switching, malformed
array fallback, bounded2048² submissions and actual pixels from all shader
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
