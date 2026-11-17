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
Linux/Windows OpenGL/ANGLE compatibility paths under qualification. Two persistent linear
RGBA8 targets retain exact logical R8/RG8 current/previous material values. A
bounded ring of independent one-layer R8/RG8 staging arrays receives one immutable upload per
publication, followed by GPU rectangle copies into the recycled history target.
A dense update uses one full staging upload and one whole-World copy. The
production path never reads GPU pixels back to construct an update.

At 2048²,128² tiles bound dirty tracking to 256 entries. Recycled histories repair
all accumulated dirties and skip byte-identical cached tiles. A single changed
tile uploads 32 KiB instead of 8 MiB. The two history targets, staging resources and
retirement sink occupied 44,728,324 logical GPU texture bytes in the one-stage
e61 checkpoint. The bounded two-ImageTexture experiment occupies 55,902,212 bytes.
Its two-layer array-only successor occupied 55,902,213 bytes. The new independent
one-layer ring occupies 44,728,325 / 55,902,213 / 67,076,101 bytes for one / two /
three resources per size class, including a separate 1-byte R8 source dummy and excluding driver
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
Only this copy shader samples a Texture2DArray, always at layer zero. Each size
class owns a fixed ring of independent arrays and fixed sampler materials;
the provisional three-resource default does not redefine texture storage or
change the ordinary World sampling shaders. Exact horizontal runs combine
copies only within both World and atlas rows, preserving upload bytes and
destination pixel area.

The pinned [DrawableTexture2D resource implementation](https://github.com/godotengine/godot/blob/4.7-stable/scene/resources/drawable_texture_2d.cpp),
[GLES3 texture storage](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/storage/texture_storage.cpp),
[blit shader](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/shaders/tex_blit.glsl)
and [API contract](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/DrawableTexture2D.xml)
identify this mechanism and its experimental status. The implementation uses
single-target calls and ends each changed batch with a 1×1 sink copy: the engine
otherwise leaves large targets attached to its persistent framebuffer after
resource release. The tiny copy is included in submission timing. No resource
queue, unbounded allocation stream or global publication cache is introduced.
The pinned GLES3 source uses `glTexImage2D` for ordinary ImageTexture updates
and `glTexSubImage3D` for array-layer updates. This is an API/storage distinction,
not proof of a specific driver wait or guaranteed nonblocking behavior. A
separate ordinary source0 dummy avoids the blit API's fixed 2D source binding;
each array sampler is bound once per resource through the custom material interface.

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

## Rejected e61 checkpoint and bounded staging experiment

Source `e61f3b6e40fe7c6152a440369a536fb8bf551055`, tree
`3b199dc357a58b5bd1765615d65215c4fff255ba`, passed the complete
[Linux/Windows application campaign 43838952079](https://github.com/techrote/cybersand/actions/runs/43838952079).
Both hosts passed material293 and physical-publication64 assertions, all eight
actual appearance comparisons, source ABBA state/association checks and ordinary
contact recovery. Windows also passed all three real graphical launchers and
the real Desktop PowerShell5.1 Test It.cmd (four captures, two pairs). The
unchanged palette guard passed in
[43838963413](https://github.com/techrote/cybersand/actions/runs/43838963413), whose
synthetic merge tree exactly equals e61. Its separate Draft-gated provenance
step was skipped; the application preflight authenticated the runtime inputs.

Independent raw timing review nevertheless **rejects e61 for the freeze target**.
All four Windows source pairs retained exact144-step recorded bodies and native
associations, but p95 physical gaps changed140.56→227.17,139.40→218.96,
139.37→215.62 and137.67→200.51 ms. Candidate gaps≥250 ms numbered4/3/2/1;
each control had zero. The improved rates and median gaps do not offset those
recurrent tails. Staging calls≥100 ms numbered45/98,43/93,47/97 and44/96,
with maxima301.798–320.478 ms; blit submission medians were about0.36 ms.

This is ordinary sparse-update evidence, not only full refresh: the512KiB,
16-tile staging class had≥100 ms calls38/83,37/80,40/82 and38/82, frequently
alternating approximately0.08 ms with100–220 ms. Actual Test It independently
repeated the pattern. Its callback median improved from about94 to6 ms, while
p95 worsened from121–127 to199–203 ms. The delay is observed inside the staging
update call; resource-specific GPU waiting, global backend synchronization and
OS descheduling are not individually isolated by these scopes.

Final e61 Linux source ABBA remained mixed at roughly7.3–7.6 completed steps/s.
Every143-gap arm exceeded100 ms, none reached250 ms, and candidate material
calls stayed below13 ms. The local same-source full/blit pair also remained
mixed, including a1,002 ms candidate gap and worse p95. All raw evidence,
rejected packages and independent reductions remain retained.

The next controlled experiment gives each staging size class two fixed source
textures. A publication uploads one immutable atlas into the selected resource,
copies into the same two authoritative histories, performs sink retirement,
then advances that pool's cursor. Full-size aliases share the cursor; NPOT full
sources use a separate bounded pool. Initialization primes one resource per
class and starts the two-resource path with its alternate. This increases
reuse distance and does not constitute a GPU fence. It adds11,173,888 logical
GPU bytes at2048² RG8, for55,902,212 total. One/two resources are selected with
`CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS=1|2`; two is the unaccepted experimental
default. Metrics record the slot and actual staging RID.

The targeted local gate passed785 graphical assertions and18 headless fallback
assertions, including exact history/appearance, recurring-capacity alternation,
shared and separate full pools, malformed second-slot/pool/cursor rejection,
no-op cursor preservation and fallback ACK correctness. Independent static
review found no blocker for the experiment. This is not performance approval.
The dedicated Windows probe uses one source and full observer configuration,
ordinary coupled2048² Needle/Follow inputs, and serial full/one/two/two/one/full
arms. It preserves complete captures and compares the exact1..144 physical
prefix. Whole-frame, callback and physical-completion tails determine adoption;
a shorter staging call alone does not. Full exact-source qualification follows
only after a mechanism is justified.

The exact image-pool source `f32327823318f6e990eb1ca44eef3ced0813219a`
(tree `b97855bebb1c47fbd129412f27c58d7cb9a323c8`) completed
[Windows run 43849638986](https://github.com/techrote/cybersand/actions/runs/43849638986).
All six arms and all 15 exact physical-prefix comparisons passed; observer drops
were zero. The performance disposition is **FAIL**, independent of the green
capture workflow. Each row contains 144 physical completions and 143 gaps:

| Order / mode | Rapier steps/s | Physical gap p95 / max ms | Gaps ≥100 / ≥250 ms | Frame interval p95 ms |
| --- | ---: | --- | --- | ---: |
| 0 full | 9.906029 | 112.547 / 114.367 | 107 / 0 | 121.825 |
| 1 one image | 10.637135 | 185.941 / 273.054 | 59 / 1 | 205.237 |
| 2 two images | 11.221502 | 190.254 / 286.775 | 43 / 1 | 269.851 |
| 3 two images | 10.166239 | 191.472 / 267.580 | 57 / 1 | 274.604 |
| 4 one image | 10.217736 | 195.508 / 275.521 | 58 / 5 | 227.652 |
| 5 full | 9.434847 | 112.670 / 114.134 | 124 / 0 | 116.854 |

Two images reduced sparse staging calls ≥100 ms to 14/90 and 16/99, versus
29/97 and 24/93 for one image. Main callback medians fell to about 4.1 ms from
86–88 ms for full uploads, but callback p95 remained about 171 ms versus 97 ms.
The physical and frame tails worsened materially. Bounded reuse therefore does
not qualify as the repair. The complete raw capture, including all extra
completions and native/material stages, is retained in artifact `14217259007`,
SHA256 `7d2f9478b0b446540e0f70d72a17e9e334909e36155c0c0907d4d1e87d4241e4`.

## Array-only staging experiment

The successor to `f32327823318f6e990eb1ca44eef3ced0813219a` changes only the staging
upload primitive and its copy shader, retaining both 2D histories, dirty repair,
material certificates, ACK transaction, original appearance shaders and physical
coupling. One fixed array per size class contains one or two layers. Full-image
aliases share the same pool/cursor. Resource kind, actual array RID and layer
are reported separately; zero-change submissions report layer −1 and RID 0.
Preflight checks owned array/material/sampler identity, dimensions, layers,
format, no mipmaps, cursor bounds and source/output separation. Direct per-copy
coordinates encode height and layer exactly within the existing height <16384
bound. The separate source dummy and tiny output retirement sink remain owned
for the publisher lifetime. Initialization accounting includes the dummy byte.

The frozen external Linux prototype passed 402 GPU assertions, including R8/RG8
values, both layer counts, NPOT histories, 2048² sparse/dense copies and eight
exact appearance comparisons. A separate maximum-height gate passed 30 checks
and read back both packed heights 16383 and 32767. The applied production-shaped
helper/shader/test subsequently passed 876 graphical assertions and 19 headless
assertions, with no failures or tested-source changes. All eight original
appearance pairs remained byte-identical. Actual Windows/ANGLE qualification
is a separate gate before its timing comparison.

The external render-plus-publication probe contains no native or Rapier
simulation. Across all 32 recorded frames per arm, sparse frame medians were
315.526/261.955 ms for image staging and 231.484/216.837 ms for array staging;
dense medians were 504.556/364.048 versus 378.738/352.277 ms. Publication medians
were mixed. Startup outliers remain in the raw capture, including a 15,701.450 ms
image-arm frame, a 1,229.142 ms array-arm frame and a 45.799 ms array staging call.
The original summaries also retain the 24 frames after eight startup samples;
those subsets are not physical completion evidence. The capture's exact source
predates the later material-RID guard and dummy-byte accounting, which are
preserved as separate deltas. These results justify a controlled Windows trial,
not an end-to-end freeze-remediation claim.

The next Windows probe first requires actual GPU material/history/appearance
correctness, then runs full/array1/array2/array2/array1/full with the same complete
observer, ordinary coupled 2048² Needle inputs and exact 1..144 physical prefix.
Shared array RIDs and distinct bounded layers are validated explicitly. All
raw completions, startup records, callback/frame/physical tails and unsuccessful
attempts remain available. Adoption requires independent review of those tails
and final exact-source application qualification.

The first array checkpoint, `5248469b6472f9a039e9bfa5a2ae0d2dc4fdca75`
(tree `79c914fe1f48d9594bbf19440862d388a58f2e54`), ran the actual Windows/ANGLE
GPU test in [run 43852642559](https://github.com/techrote/cybersand/actions/runs/43852642559):
876 assertions, zero failures, all eight appearance hashes exact, both logical
history formats, all four pool/extent cases, four packed-height cases and the
8 MiB dense refresh. Independent review matched all 607 executed script/shader
hashes to that exact source and verified the process exit, marker and log hash.
The workflow then **failed in report validation before any timing arm ran**.
The receipt is UTF-8 without a BOM; Python's Windows default cp1252 decoding
changed its `2048²` label to `2048Â²`, so the exact dense-refresh label check
refused otherwise valid evidence. The successor changes exactly four text reads
to explicit UTF-8, retaining every acceptance condition. Replaying the original
and corrected validators against untouched Windows receipts and reconstructed
exact source hashes reproduces failure then success. No runtime change is
included in that repair. The failed-run artifact is `14217549415`, SHA256
`68baa789175676d030e9cb882c6a6b017a7ae8756e3a618616ae271760aea5fd`.
This checkpoint supplies actual GPU correctness evidence, no physical timing
result, and no performance or physical-hardware approval.

The corrected source `e8880159b611e6d7b4e1cfd245ebbba4837bf690`
(tree `6603477e1d3322338c1fa9c03672ef21d60b517b`) completed
[Windows run 43853461245](https://github.com/techrote/cybersand/actions/runs/43853461245).
Actual GPU correctness and all 15 exact 1–144 physical-prefix comparisons passed;
there were no extra physical steps, observer drops or material fallbacks.
Independent raw review nevertheless records **PERFORMANCE FAIL**:

| Order / mode | Rapier steps/s | Physical gap p95 / max ms | Gaps ≥100 ms | Frame interval p95 ms |
| --- | ---: | --- | ---: | ---: |
| 0 full | 12.086 | 94.884 / 141.336 | 2 | 95.650 |
| 1 array, one layer | 11.537 | 147.002 / 242.482 | 37 | 165.849 |
| 2 array, two layers | 10.992 | 156.313 / 212.398 | 37 | 163.864 |
| 3 array, two layers | 11.846 | 137.401 / 200.449 | 41 | 156.680 |
| 4 array, one layer | 11.663 | 154.061 / 190.854 | 39 | 148.759 |
| 5 full | 12.541 | 94.820 / 124.477 | 1 | 95.589 |

The remaining Windows long-call scope is staging: p95 119.658/120.050 ms for
one layer and 139.106/122.140 ms for two layers. Corresponding GPU-copy submission
p95 is only 0.351–0.388 ms. Atlas assembly p95 is about 2.5–2.65 ms, CPU image
patch spans 1.43–1.61 ms and content-cache spans about 0.35 ms. These are elapsed
calls. Previously submitted GPU work or CPU scheduling can still contribute to
a later staging wait. Rapier-call wall p95 also rises despite identical recorded
states, so no exclusive GPU-transfer or intrinsic-solver attribution is made.
The two layers share one RID; they do not establish independent resource reuse.
The raw artifact is `14220536881`, SHA256
`78484a5133b8239ce2a6454460abcc6d49f8160c19efe3f2384a99d82b2abe09`.

A frozen-source local Linux campaign is retained as an **incomplete adverse
experiment**, not a six-arm qualification. Full and one-layer modes completed
144 steps with exact recorded states and associations. Rapier rate fell from
3.005 to 1.721 steps/s; physical-gap p95 rose from 496.858 to 956.035 ms, maximum
from 716.850 to 1,091.826 ms, and ≥1000 ms gaps from zero to five. Forward two-layer
mode failed the unchanged 90-second completion requirement at 132 steps; its
incomplete capture had p95 1,400.303 ms, maximum 3,139.137 ms and 14 gaps ≥1000 ms.
Its common 132-step state comparison is diagnostic only. The next reverse arm
was interrupted during startup after the failure; no trace or receipt existed,
and the remaining arms never started. Original captures, summary, operator-stop
receipt and unchanged post-stop source/runtime/harness fingerprints are retained.
Local staging p95 was only 8.028/13.816 ms for the array captures, and native wall
times also varied. The whole local slowdown is not attributed to staging calls.

## Independent one-layer ring and exact copy-run experiment

The shared-array result above motivates testing resource reuse separately from
layer reuse. Each capacity now owns one, two or three independent one-layer
Texture2DArray resources. Each resource has a fixed sampler material; copies
always read layer zero. Rejected or byte-identical updates never consume a slot,
and the equal-size full atlas shares its capacity pool and cursor. Distinct
current/previous initialization preserves the unused third slot where available.
This increases reuse distance; it supplies no GPU fence or nonblocking promise.

The same proposal coalesces exact horizontal copy runs. Both adjacent World
tiles and their packed-atlas tiles must remain in the same respective rows.
Skipped tiles and either row boundary break the run. The prior per-tile mode
remains a diagnostic correctness control. Dense full copies already use one
call and are never counted as coalescing savings. Sink retirement stays separate.

The frozen external proposal passed 1,649 actual Linux OpenGL graphical
assertions and 19 headless assertions with zero failures. All eight original
appearance-shader pairs matched exactly. Six square/NPOT ring sequences,
twelve maximum-height readbacks and twenty channel/boundary copy cases passed;
the ten tiles/runs pairs had identical actual current/previous GPU hashes,
uploaded bytes and written pixel area. Source hashes were unchanged after
execution. These are correctness results, not physical-performance results.

The focused Windows experiment first requires the actual ANGLE GPU gate, then
runs full/ring1/ring2/ring3/ring3/ring2/ring1/full with the original coupled
2048² Needle workload. All ring arms hold copy mode at runs. This isolates ring
resource count within the new code; it does not isolate runs-versus-tiles timing.
All 28 exact 1–144 physical-state/association pairs, observed resource rotation,
fixed payload size and at least four ordinary sparse coalesced publications in
both the matched prefix and whole capture are required. All stalls and failed
attempts remain in the raw evidence. Physical and frame tails determine whether
any configuration advances; shorter staging calls alone cannot qualify it.

Source `e519aadaddd21df59a19dedec99de8c0542ed62f`, tree
`d805b9d4c8e5831377d4e9c8129e04868a41d8c7`, completed
[Windows run 43860751240](https://github.com/techrote/cybersand/actions/runs/43860751240).
The actual ANGLE gate passed 1,649 assertions, all 28 recorded physical-state
and native-association pairs were exact, and resource/copy checks passed with
zero observer drops or fallback. Independent disposition is **retain ring3 as
a component candidate; reject this source as a completed freeze repair**.

| Order / mode | Native / Rapier / Main Hz | Physical p95 / p99 / max ms | Gaps ≥100 / ≥250 ms | Frame p95 ms |
| --- | --- | --- | --- | ---: |
| 0 full | 9.913 / 9.885 / 7.612 | 137.180 / 218.980 / 232.060 | 99 / 0 | 210.018 |
| 1 ring1 | 10.564 / 10.551 / 7.648 | 223.284 / 246.278 / 284.072 | 58 / 2 | 259.020 |
| 2 ring2 | 11.028 / 11.071 / 7.887 | 219.067 / 248.556 / 349.756 | 51 / 2 | 306.881 |
| 3 ring3 | 10.173 / 10.222 / 7.927 | 135.446 / 209.469 / 344.515 | 95 / 1 | 227.599 |
| 4 ring3 | 10.584 / 10.596 / 7.841 | 139.456 / 262.347 / 340.256 | 93 / 2 | 220.503 |
| 5 ring2 | 11.321 / 11.331 / 7.677 | 209.021 / 257.725 / 332.001 | 50 / 5 | 256.226 |
| 6 ring1 | 9.649 / 9.627 / 7.819 | 218.595 / 249.948 / 255.961 | 72 / 2 | 258.671 |
| 7 full | 9.799 / 9.784 / 7.535 | 132.321 / 144.303 / 155.437 | 106 / 0 | 147.028 |

Every row uses the exact first 144 physical completions and 143 gaps. There are
no ≥1000 ms gaps. The last full control's unmatched extra step 145 remains in
its whole capture. The host is an AMD EPYC 7763 VM with four logical processors,
native Auto capacity four, and Windows software ANGLE; these are not NVIDIA data.

Ring3's upload p95 falls to 5.609/5.745 ms from 120.730/116.071 ms in the full
controls; Main callback p95 falls to 7.217/7.265 ms from 119.271/117.354 ms.
All sparse capacity-16 staging calls stay at or below 0.100 ms. Two forward
dense calls still take 109.351/134.118 ms; reverse ring3 has none ≥50 ms.
Sparse copy counts fall from 976 to 302 and 861 to 254 with unchanged copied
pixel area. These are demonstrated submitted-work and elapsed-call changes,
not an isolated coalescing timing effect or measured GPU execution.

Crucially, same-process-frame joins show Main-end to `frame_post_draw` median
95.368/95.552 ms in ring3 versus 8.015/7.578 ms in full controls; ring3 p95 is
112.686/114.007 ms and maximum 326.546/319.122 ms. Much of the observed delay
appears later in the frame. This interval includes engine/render work, other
callbacks, driver waits and OS scheduling; the marker is not a GPU fence or
scanout. Short publication calls therefore do not establish end-to-end repair.

The ring3 physical mailbox becomes ready about 0.45 ms after native completion
(p95 about 0.53 ms). Ready-mailbox to physics-admission p95 remains
101.703/100.829 ms, with virtually no intervening native-sample holds. Across
all eight arms, only two such holds occur after the complete mailbox timestamp,
6/8 microseconds later, within the snapshot-read/publication race. Existing
evidence supports missing Main callback opportunities, not a stale gate that
could safely be disabled. Rare preceding graphical exchanges still delay the
next native tick, including one 86.711 ms overlap in ring3; they do not explain
the recurring post-Main interval. No exclusive CPU/GPU attribution is made.

The authenticated raw artifact is `14223264355`, 11,363,683 bytes, SHA256
`8102aed382bfcebed69cfd8328a970dfc88c9d70b46d8f0c31b93c1ef366c867`.
Independent review retains full distributions, hold reasons, all extra and
superseded publications, frame-marker joins and exact physical-state comparisons.

### Manual texture-wrapper history regression

Additional review found that a manual retained-wrapper update marked both
targets dirty before submission, but successful submission cleared the changed
target again. Its later sparse reuse could retain a manually changed texel
outside the new patch. An exact e519 GPU reproducer retained RG `[77,99]` where
the authoritative image required `[0,0]`. Ordinary Workbench publication does
not call this compatibility route, so the matched timing captures remain valid.

The narrow reviewed fix re-marks every owned target dirty after the manual
submission. It changes no Main CPU bytes, content certificate, revision or ACK.
The identical R8/RG8 retained-current/previous regression is 100 checks with
18 failures before the fix and 100/0 after it, including five later sparse
publications. The fixed full Linux graphical gate is 1,753/0, with all eight
original appearance pairs exact. The negative and fixed source/receipt hashes
are retained separately; final integration requires this repair and exact-source CI.

## Controlled spare-history experiment

**Disposition: rejected and removed from the final evaluation design.** The
following describes the preserved experiment at source `6656f436b38a`, not a
current production option. Its actual Windows result is recorded below.

The e519 result leaves a specific hypothesis to test: writing the formerly
previous target may encounter outstanding work that samples both visible
histories. `CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS=3` adds one bounded spare
target while keeping exactly two visible histories. Two targets remain the
default. The experiment holds the independent staging ring at three resources
and copy mode at exact horizontal runs; its order is full/H2/H3/H3/H2/full.
It requires actual Windows ANGLE material and transaction gates before timing,
then all fifteen exact 144-step physical-state/association comparisons.

Preparation validates every input and owned target and writes the destination;
one bounded token records the original roles and destination. Commit accepts
only that publisher's outstanding sequence and rotates current, previous and,
when present, spare. Main commits and binds the histories before advancing the
content certificates and upload ACK, with no intervening yield. A rejected
transaction reconstructs the full fallback from the new CPU image and the old
current certificate. The token retains its planes, but plane ownership is weak
and does not keep the publisher or staging resources alive. The reviewed manual
wrapper invalidation repair above is included.

The source-bound external Linux GPU gates passed 223 transaction assertions,
2,017 material assertions with two targets and 2,063 with three; the headless
unsupported-backend gate passed 19 assertions. Each of the eight simultaneous
original full/blit shader pairs matched exactly. The unchanged neon backdrop
uses engine TIME, so its hashes across separate processes are not an appearance
equivalence criterion. These are correctness gates, not performance results.

For a 2048² RG8 World, three staging resources per capacity with two history
targets own 67,076,101 bytes of texture payload; the spare increases this to
83,853,317. Maximum logical CPU tile-cache content grows from 16,777,216 to
25,165,824 bytes. Each destination accumulates its own dirty union, so the spare
can also increase uploaded tiles and capacity. The comparison retains this
additional work, all physical/frame tails and the existing Main-end-to-draw
marker spans. A shorter publication call alone cannot qualify this experiment.

The combined ordinary-gameplay regression also exercises small and large live
erasures through `_world_input`, its real screen-to-World mapping and the native
brush queue while the Needle is airborne. Positive PAINT authoring retains its
existing paused-only policy. The test uses ordinary reverse thrust and level
assist, a four-sample airborne precondition, exact +6/+18 physical-step input
triggers, and the unchanged 90-step/60-second bounds. Both GPU history targets
must match their CPU content certificates after live publication. Separate
checks retain dense contact, Fire ON/OFF, Follow/Free, pause/single-step
and two-body feedback checks. This 1024² functional case does not replace the
matched 2048² performance workload.

The first combined H2 attempt failed five live-edit assertions: its prior input
was forward body-oriented thrust plus turning, not Cartesian downward motion.
Airborne flight began only 76 steps into the bounded phase, so the second trigger
fell beyond the existing limit. The unchanged failed capture is retained. The
input-only reverse-thrust correction passed 1,015 checks with H2 and 1,003 with
H3, all with zero failures and unchanged runtime hashes. Both checked edit
windows span 57 completed steps; phase summaries separately record 58 and 57
because their final observation boundaries differ. These results establish the
tested gameplay paths and material/terrain validity, not smooth performance.

Exact source `6656f436b38a974d72a951e5e09fba21a0304422`, tree
`931675e578c08a3bf33f3e44221e4407685ce9b2`, completed
[Windows run 43868676012](https://github.com/techrote/cybersand/actions/runs/43868676012).
Actual ANGLE gates passed 2,017 H2, 2,063 H3 and 223 transaction assertions,
with no failures. All fifteen recorded physical-state/native-association pairs
are exact over steps 1–144. No arm has extra steps, observer drops, duplicate
snapshot receipts, fallback or unbounded resource changes.

| Order / mode | Native / Rapier / Main Hz | Physical median / p95 / p99 / max ms | Gaps ≥50 / ≥100 / ≥250 / ≥1000 ms | Frame p95 ms |
| --- | --- | --- | --- | ---: |
| 0 full | 9.487 / 9.494 / 9.171 | 111.876 / 114.468 / 129.585 / 140.431 | 139 / 122 / 0 / 0 | 119.363 |
| 1 H2 | 10.235 / 10.279 / 9.769 | 101.589 / 119.974 / 215.006 / 278.445 | 130 / 89 / 2 / 0 | 169.522 |
| 2 H3 | 11.105 / 11.092 / 9.679 | 99.176 / 118.816 / 226.085 / 287.788 | 119 / 65 / 2 / 0 | 172.024 |
| 3 H3 | 10.701 / 10.696 / 9.720 | 101.218 / 110.106 / 213.142 / 310.964 | 124 / 82 / 2 / 0 | 175.420 |
| 4 H2 | 10.373 / 10.405 / 9.686 | 100.711 / 132.731 / 195.662 / 276.355 | 129 / 79 / 1 / 0 | 190.239 |
| 5 full | 9.697 / 9.689 / 9.156 | 111.840 / 114.343 / 160.026 / 181.460 | 134 / 115 / 0 / 0 | 135.895 |

Each row contains 143 consecutive physical gaps on the same Windows software
ANGLE host, an AMD EPYC 9V74 VM with four logical processors and native Auto
capacity four. These are not cross-host comparisons with the earlier EPYC 7763
run. H3's p99 and maximum physical gaps worsen in both directions relative to H2;
frame p95 is mixed. Main-end-to-frame-post-draw medians remain 79.826–84.719 ms
for H2 and 81.981–82.427 ms for H3, versus about 10 ms for full. H3 does not
establish that a target-read hazard explains or removes the late-frame delay.

H2 upload p95 is 5.506/5.729 ms versus full 96.353/98.941 ms, but its physical and
frame tails still fail to establish a completed freeze repair. Shorter calls
and modestly higher throughput are retained as component results only. No
exclusive CPU/GPU attribution or physical GPU acceptance follows from them.

Independent review recommends the smaller H2 ring3 implementation for final
source/integration qualification, with the reviewed manual-wrapper fix, early
physical mailbox, real live-erasing tests and explicit package control defaults.
The spare, prepared-token transaction, incompatible transaction test and selector
are removed from the delivery candidate. The complete negative source and raw
capture remain available. [Artifact 14228270452](https://github.com/techrote/cybersand/actions/runs/43868676012/artifacts/14228270452)
is 9,987,887 bytes, SHA256
`b930014a551404d78f8a4d0d2e6d7b791f11e805cb3b8d3658721c8e25aa1247`.

The assembled H2 restoration subsequently passed 1,000 ordinary graphical pacing
checks and 1,753 material GPU checks on frozen Linux source, with no failures.
All 671 script/shader/scene/config hashes, native/Rapier libraries and the pinned
engine stayed unchanged. Eight within-process appearance pairs are exact. The
live phase records 57 completions while its last input-hook observation spans
56; those observation boundaries remain separate. This is supplemental assembled
source evidence, not a replacement for final committed Linux/Windows gates.

The final owner launchers select source defaults for staging/copy controls and
the default publication Test It capture forces detailed observer events, then
restores its caller's environment. Existing Windows launcher and four-case Test
It gates deliberately inject conflicting child-only probe settings and require
actual slots3/runs plus callback/mailbox evidence. No extra performance matrix
is introduced. The shipping guide explicitly retains PHYSICAL HOLD and separates
ordinary live erasing from paused positive PAINT/Undo/Redo/persistence checks.

## Full campaign failure and explicit live-flight setup

Source `f268126f9ce3892f9d4248ad66faaea219980cde`, tree
`8d9ed9f63646c0d6d6ccb435e22db28f6c9f862c`, completed
[application run 43873737482](https://github.com/techrote/cybersand/actions/runs/43873737482)
with a failed headless pacing case on both platforms: Linux 1,691 checks and
Windows 1,622 checks, each with ten live-flight/edit failures. The other 36 Linux
and 42 installed Windows cases passed. The three actual Windows launchers,
Windows PowerShell 5.1 Test It command and reducer, and both source ABBA
validation steps also passed. No delivery ZIP was published by this failed run.
These successful subsets do not waive the failed qualification gate.

Independent raw review found that earlier phases legitimately complete different
numbers of physical steps because they require both step and wall-duration
minima. Hosted headless recovery ended at the floor, whereas earlier successful
captures ended near a sparse ceiling. The fixed reverse-thrust input settled the
Needle on the floor through all 90 live-phase completions, so no airborne edit
trigger was reached. Linux completed those steps at approximately 16.67 ms
intervals with valid owner, terrain and feedback associations. This is a failed
flight precondition, not a missing-completion freeze. An unchanged exact-f268
local replay passed all 37 cases; it is retained without overruling hosted CI.

The correction authors a separate clear-air Needle/barrel setup through ordinary
`SharedWorkbench.apply(preserve=false)` while paused. Actual spawn, zero-step and
zero-velocity state, advancing session/epoch/World, and complete installed terrain
must be observed before play. Ordinary forward thrust and level assist then
drive the live phase. Earlier dense-contact phases remain, and the byte-unchanged
packet-fence test runs before the deliberate owner reset so its old packet still
has to fail the original strict age test. No live body is moved directly.
The 48-step minimum, 90-step maximum, 60-second watchdog, four airborne samples,
exact +6/+18 triggers, live native erasures and GPU-history checks are unchanged.

The first isolated setup attempt failed one of 1,231 checks before the graphical
case ran. Its new owner's first physical step correctly refused both provisional
sample-1 packets before any native completion; both accepted-sample counters
remained -1. The original f268 first phase has the same bootstrap behavior.
The corrected oracle explicitly checks only that exact first-step refusal,
including native tick zero, absent native completion and unchanged authority.
Every owner/generation/terrain assertion remains, and every later row retains
ordinary completed-sample matching and the strict accepted-age limit. A raw
replay checks the one bootstrap plus 47 ordinary rows and rejects 16 malformed
variants. The failed attempt is retained; no physics law or admission rule changes.
The corrected frozen overlay then passed 1,250 headless and 982 graphical checks,
both with six phases and unchanged executed source/native/engine identities.
These focused passes supplement, rather than replace, committed-source CI.

The f268 Linux source comparison retains all four exact recorded-state/native
association pairs, but candidate physical p95 worsens in each pair. Both sources
remain near 6.1 completed steps/s and all 143 intervals per arm exceed 100 ms.
Neither source has a 50 ms upload call in that cohort, so it establishes no
gameplay-scale material-stall removal there. Windows median upload-call duration
in the retained arms falls from approximately 100.5–101.2 ms to 3.10–3.21 ms.
Within the common 144-step prefixes, physical p95 improves in all four pairs,
but Follow p99 worsens to 276.207/242.940 ms and maximum gaps to
378.581/375.148 ms. Free-camera tails improve. This remains a component gain
with mixed physical tails, not an accepted end-to-end freeze repair.
The authenticated Linux and Windows
raw artifacts are [14231092654](https://github.com/techrote/cybersand/actions/runs/43873737482/artifacts/14231092654)
and [14233415237](https://github.com/techrote/cybersand/actions/runs/43873737482/artifacts/14233415237).
The revised test requires a new exact-source application campaign. Engineering
and physical acceptance remain HOLD until their respective gates are satisfied.

## Exact 2f69 qualification and PAINT startup replay

Commit `2f69a4a2f98ba67932909d824c86a9dcaf2551f9`, tree
`424936224e001faac7c5c9500c73ff8e48285db5`, completed application run
[43884520564](https://github.com/techrote/cybersand/actions/runs/43884520564)
with Linux PASS and Windows FAIL. All 37 Linux production cases and 41 of
43 Windows installed cases passed, including both corrected pacing cases and
1,753 graphical material assertions per platform. Actual Windows launchers,
PowerShell 5.1 Test It and source ABBA validation also passed. These successes
do not waive the failed installed PAINT gate or establish physical smoothness.

Windows PAINT authoring stopped at its first two readiness checks, before
`author()` and before saving anything. Its recorded maximum frame gap was
61,077,361 microseconds against the existing 60-second startup wait. The four
fresh-reopen failures then follow from the absent authored save. The timeout
helper checks its deadline before re-evaluating readiness after an awaited
frame; its empty message is `bench.message`, not a worker failure diagnosis.
No terminal readiness components or per-thread CPU timing were captured, so
these receipts cannot establish readiness at expiry or attribute the gap to
native work, rendering, driver waits or OS scheduling. The same PAINT source
and production runtime passed the preceding f268 Windows campaign.

The failed Windows artifact
[14237278117](https://github.com/techrote/cybersand/actions/runs/43884520564/artifacts/14237278117)
is retained: 104,278,704 bytes, SHA256
`eef1a733aa04f8d2617934cc3ef41c7edf82acf3b6042a59b73091277579b8f1`.
All 2,669 archive members passed CRC and path checks. A focused installed
graphical PAINT author/fresh-reopen replay records startup lifecycle evidence
without increasing deadlines or changing failure behavior. Original failed
receipts remain separate from subsequent runs. Engineering remains HOLD until
the installed gate is satisfied; the unexplained startup gap is not erased by
a later successful execution.

The diagnostic helper passed 300 adversarial checks, including unchanged
short-circuit reads and refusal of an expired wait with terminal readiness true.
One frozen Linux graphical overlay passed all 66 authoring and 12 fresh-reopen
checks with 625 executable/configuration/runtime inputs unchanged. These passes
validate the observer and authoring path; they do not explain the Windows gap
or substitute for its focused replay and subsequent full exact-source campaign.

The focused Windows replay at `5455b4f68cf686d9ba65ffe4dc06a944a1301952`
([run 43898774067](https://github.com/techrote/cybersand/actions/runs/43898774067))
passed its actual import, 66-check graphical authoring and 12-check fresh-reopen
cases. It still finished FAIL: the new post-execution payload guard stopped at
`Radial2D.svg.import`. The original archive contains CRLF-converted bytes for
all four tracked import sidecars, whose committed content is canonical LF.
Actual changed bytes were not retained by that first-mismatch guard; neither
an EOL-only cause nor a single changed file can be established retrospectively.
The successor pins import-sidecar exports to LF and retains strict complete
post-execution hashes, plus every mismatch's before/after bytes and text diff.

The same replay records a 53.087240-second first pre-draw to post-draw signal
interval, while its longest bracketed Main callback is 57.156 milliseconds.
Readiness passes after approximately 54.531 seconds; fresh reopen waits about
2.039 seconds. This reproduces a large startup wall interval, not its CPU, GPU
or driver cause. Initial native material publication and publisher setup occur
before that first draw, but this first observer omitted actual backend/fallback
state. One same-source full/auto/auto/full comparison therefore records actual
material state at the first draw and uses a fresh profile for each ordinary
author/reopen pair. Machine and driver caches are not reset. Every original
readiness and process watchdog remains in force; a failed arm remains failed.
The original failed receipts and both after-startup frame-gap maxima are kept.
This diagnostic comparison does not grant engineering or physical acceptance.

The controlled comparison completed at
`1f6bcc9c57dd335860eaf939bd33cb9329524c0d`, tree
`01b4075a94f1ec5cc780969eb9f6d0b6c2c57026`, in
[run 43906528622](https://github.com/techrote/cybersand/actions/runs/43906528622).
All four graphical authoring cases passed 66 checks and all four fresh-process
reopens passed 12. The strict after-run ledger checked all 1,068 original files,
including the manifest, with zero changed bytes. This qualifies the canonical
LF export repair prospectively; the missing 5455 after-bytes remain unknown.

| Profile-cold pair, execution order | First author draw signal span | Author readiness wait | Reopen readiness wait |
|---|---:|---:|---:|
| Full, first | 44.185 s | 45.277 s | 2.022 s |
| Auto/blit, second | 46.567 s | 47.953 s | 1.980 s |
| Auto/blit, third | 46.371 s | 47.704 s | 2.053 s |
| Full, fourth | 50.473 s | 51.653 s | 1.916 s |

All 32 first-boundary material observations prove the requested full/full or
auto/blit backend without fallback. First draws share the paused 1024-square
bootstrap World, RG8, native tick zero, and matching World/revision/render and
worker metadata; auto uses three independent staging resources and copy runs.
Workbench subsequently installs its 2048-square World. Actual cell bytes are
not independently hashed by this startup observer. Profiles are isolated, while
machine/driver caches are not reset. First author Main callbacks are only
1.905–2.441 ms; one auto reopen still records a 162.043 ms Main callback.

The severe first-draw elapsed cost occurs in both modes in this bounded sample.
It supplies no evidence for a publisher-specific startup repair and does not
identify CPU, GPU, shader, driver or scheduling execution. No startup draw is
hidden or deferred, no readiness limit is increased, and the production runtime
remains unchanged. The earlier failures and the shared cold-start risk remain
part of qualification. The authenticated evidence artifact
[14246088200](https://github.com/techrote/cybersand/actions/runs/43906528622/artifacts/14246088200)
contains 232 checked files; archive SHA256 is
`90210c8f4da2d6732e4681d901fd8be36fbe16f12dfff98db58aaccc3b604838`.
Final exact-source integrated Linux/Windows qualification remains required;
these startup observations cannot qualify physical progression or NVIDIA.

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
