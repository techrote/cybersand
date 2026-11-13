---
title: Final native-pixel camera integration, performance and Windows evaluation
status: Current
document-kind: evidence
scope: Accepted #565 reconciliation, controlled application performance, resulting-source platform qualification and Windows delivery for Draft #566
canonical-for: []
last-reviewed: 2026-11-13
related-documents: [2026-11-13-native-pixel-scrolling.md, 2026-11-12-mat-auth-workbench-integration.md, ../operations/native-pixel-scrolling.md, ../systems/material-appearance-and-rendering.md]
---

# Final native-pixel camera integration

**Draft / HOLD; no merge, Ready promotion or auto-merge is authorized.** The
owner requests final integration with accepted #565, preservation of the
qualified camera, controlled performance investigation and a fully tested
Windows evaluation. The [PR #566 delivery ledger](https://github.com/techrote/cybersand/pull/566)
holds the final source-bound workflow links, downloadable package and separate
technical/owner disposition. This record preserves the integration and measured
engineering evidence; pending execution is not a pass.

## Source and preserved ancestry

| Identity | Exact source |
| --- | --- |
| Accepted main / #565 merge | `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742` |
| Qualified camera parent | `b52dd6c9fac5739bde9829b72b55f09ef89455d6` |
| Normal integration, ordered parents camera then main | `b1e2e9b1ce0a93d9eda54cbc35d04257eba9dfa7` |
| Integrated, unoptimised source tree | `5ef0f8a14c29481519e7455d646f3011a30d6b1b` |
| Preserved camera shader transition | `1755b2195e4d38c6030ae287ac2eb8e070da62ef` |
| Preserved native capability transition | `b432d52d0d9acaa22f93eeb8d1fad48c64b4c087` |

The source merge has five documentation conflicts: the documentation index,
handover, retrieval corpus, retrieval question index and roadmap. Both sides'
new sections/routes are retained, with the newest review date. Product code
merges without a conflict. No competing design or default is selected.

Independent byte comparison confirms that every path changed by only one
parent retains that parent's exact bytes in the normal merge. At that merge,
`main.gd`, `gameplay_recorder.gd`, `pixel_camera_transform.gd` and
`material_palette.gdshader` exactly match the qualified camera parent. Final
qualification subsequently found a root-window stretch defect and repairs only
Main's renderer-transform composition and its pointer consumer, as recorded
below. The camera math, palette shader and recording implementation remain
unchanged. The shader's LF SHA-256 remains
`b8e5542dae2c36fd6fbef0170a7b537bce5c853fc10920174cefe13dbec78d4f`.
The Materials Lab native-window functions match accepted main; the combined
Workbench retains the camera callbacks plus the accepted Lab toolbar entry.
The compatibility registry retains all 30 accepted-main transitions and the
camera transition, without refreshing the frozen material authority lock.

All files under `native/`, `godot/native_extension/` and `third_party/` match
accepted main. No physics, material-law, native owner, worker architecture,
publication cadence or save-format change is part of the reconciliation.
Original component branches, training #567/#568 and unrelated work remain
outside this task.

## Runtime custody and local preflight

Both retained native manifests are byte-identical to main, and all 89 native
`source_inputs` match. `check_repository.py::verify_runtime` validates those
inputs and the binary/pointer SHA and size. Historical `build_inputs` retain
their original qualification scope and do not establish acceptance of changed
scripts. The canonical build guide permits matching-native retained reuse for
script changes. Fresh Linux/Windows source builds and execution are nevertheless
required for this final campaign.

| Accepted retained binary | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows x86_64 | 5,121,536 | `83b656c2638fe31c9a8ab3700c4f8c353db56e996d37a276ddfa205e81c87c54` |
| Linux x86_64 | 4,576,208 | `44c906356a98c84b09c01f6e83bcae2391a4c0e39c5c632431a4a3f4cc1578e9` |

Local preflight uses the authenticated Godot archive (75,664,355 bytes,
SHA-256 `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`),
runtime `4.7.stable.official.5b4e0cb0f`, and the accepted native/Rapier bytes.
Godot import passes. Current documentation and retained-runtime identity checks
pass after restoring their five exact companion inputs from pinned
`6a58311982941b75f46e22109a0829e5acb83c7e`. The initial missing-companion
diagnostic is an environment prerequisite, not a relaxed source check.

The existing recorder's separate CLI mode passes eight assertions for explicit
ROI precedence, extent clipping and cadence/queue clamps:

```text
Godot_v4.7-stable_linux.x86_64 --headless --path godot --script res://tests/test_gameplay_recorder.gd -- --recording-roi-override-test --record-roi=1000,700,100,120 --record-hz=120 --record-queue=0
```

The camera fixture gains two narrow cases absent from its original scope:
fractional Line/right-button erase with exact surrounding 9×9 native readback,
and twelve distinct real Rapier steps under ordinary Workbench Play/Pause.
A late observer verifies the actual parent/child callback outputs rather than
manually supplying an actor pose. Local execution passes 1,457 assertions in
6.542 seconds with zero failures; the real actor moves from y260.5 to
y262.350677. Each sampled terrain uniform and all three overlays share the
presented origin. The executed fixture SHA-256 is
`f6361d773785b4dd9cc8ac9bec1b73a5446427f214b7352234ee06b094b4b41d`.
This evidence is the integration plus the explicitly identified local test
delta; it is not hosted Windows or graphical qualification.

## Controlled performance questions

Subject A is accepted main `ac0d9fb9`; subject B is the unoptimised integration,
including any required correctness repair, executed from the frozen qualification
head that also contains the test apparatus. The receipts record that actual head
and its product-source manifest. The initial normal merge is `b1e2e9b1`; it is
not substituted for the later executed source. Compare each source with its own native build, identical
Godot/Rapier/settings/seed, an identical externally staged harness and fresh
userdata. Use paired ABBA order, warmups, raw frame samples and per-arm source
identities. Keep Windows and Linux/software results separate.

The historical installed llvmpipe result was 31 legacy and 30 native frames:
median 98.406/101.716 ms and p95 104.210/113.171 ms (+8.60%). Its fixture used
a frozen 512×256 material texture, a 128×96-cell view at 1280×960 output,
twelve warmup frames and at most sixty frames/three seconds per arm, always
legacy first. It isolates the coordinate shader block, not accepted-main
application throughput. A longer interleaved shader comparison must remain
separate from the exact-source application comparison.

Representative application cases cover 512²/1024²/2048², paused and active
Sand/Water, sparse/dense/mixed occupancy, stationary/pan/zoom/follow cameras,
integer/fractional zoom, two viewport sizes, effects on/off, manual/native
authoring and one/four native workers. Existing Main/worker counters identify
CPU submission, snapshot publication, dirty bytes, full-image uploads and
actual worker participation. Process memory and action latency retain their
own units; no software-renderer timing is labelled physical GPU utilization.

Only a measured, low-risk improvement can be admitted. Up to three are allowed;
zero is a valid outcome. The camera architecture and physical sample order are
preserved. Raw samples, per-repeat medians/tails, source identities and measured
comparisons are retained in each platform's `native-pixel-performance` artifact.
The PR delivery ledger records their final interpretation and a ranked
opportunity register without changing the already executed source identity.

## Windows distribution compatibility

The original #565 archive was independently downloaded and matched its recorded
SHA-256 `29e444ac801c884b066bae8866cf4dff02b5bc4ccafea2aec97bf2ceef10dd0c`.
It has 22,476 entries (21,422 files), conventional Deflate compression, no
Zip64 requirement and no invalid Windows names/case collisions. Some member
paths are 263 characters long before an extraction root is added, chiefly
qualification shader caches. This is a concrete Windows path-length risk;
it does not establish the cause of the owner's Explorer opening failure.

The new package preserves the complete Lab/Workbench authoring prerequisites
and source custody. Qualification evidence is kept under a short archive path,
with original bytes/hashes retained. Built-in .NET extraction and actual
Shell.Application ZIP-handler access are separate required checks; neither is
claimed until executed. The delivered application must be tested from its
actual extracted package. Physical owner DPI, graphics hardware and perceived
frame pacing remain owner acceptance, even after hosted qualification passes.

## Qualification apparatus repairs

The first integrated campaign, [43491723524](https://github.com/techrote/cybersand/actions/runs/43491723524)
at `0c56c9b6bdefe753a1acc9627291f0df44b03638`, passed source admission but its
full-gate dispatch step failed before any request: the receipt's parent directory
did not exist. The narrow repair creates that directory before writing; a
regression reproduces the original failure and verifies all four dispatch receipts
and refusal to overwrite prior evidence. The failed campaign remains historical.

Independent review also found that Windows' console launcher and its actual Godot
engine have different hashes. The performance runner now records both executable
paths and hashes, verifies the actual engine reported by the running process, and
rechecks both at completion. Native timing now counts distinct completed ticks
after each phase's start, while retaining repeated publication observations
separately. Eight focused guards and real paused/active Godot 4.7 smoke runs pass;
these checks do not establish graphical performance. No product camera, shader,
native law, simulation default or snapshot ownership changed in these repairs.

The corrected campaign must execute from its new exact source. Its final status,
all downstream gates and the published package identity belong in the PR delivery
ledger; none is inferred from this local apparatus verification.

## Resulting-application defects found during final qualification

The full Godot campaign on `f67417fb52ea838637e19698b954cc6272996179`
exposed an obsolete assertion in `test_actor_prototype_integration.gd` on both
Linux and Windows. It supplied a fractional origin to the actor overlay but
expected that origin to be floored. The qualified overlay contract preserves
the supplied presentation origin. The original failure was reproduced locally
with pinned Godot 4.7 (157 checks, one failure); the corrected assertion checks
the exact supplied fractional origin (157 checks, zero failures). No actor
implementation was changed to satisfy the old expectation.

Investigation of the application's physical performance geometry also exposed
a product defect. With this project's embedded-subwindow setting, Godot 4.7's
`CanvasItem.get_screen_transform()` omits the root Window's final stretch. In
an actual 960×720 window, `canvas_items` applies a 0.5 viewport basis and a
90-pixel vertical offset, while the old query returns a unit basis. Snapping
that logical transform does not ensure integer framebuffer translation. Pure
transform tests and direct SubViewport fixtures had not exercised this mounted
root-window condition.

Main now composes `get_viewport_transform() * get_global_transform()`, matching
the renderer's final viewport/canvas/item composition exactly once. The PAINT
controller captures and refreshes its stationary physical pointer through the
same mapping. Continuous camera state, the shared pixel-sampling math, palette
shader, recorder edge handling, native World and immutable publication ownership
are unchanged. The mounted tests use an independently composed renderer oracle,
and the graphical fixture compares actual resized-window framebuffer pixels
with the old transform as a discriminating negative control. Final execution
and exact fixture counts are recorded in the PR delivery ledger.

Pinned local Godot 4.7 execution of the extended mounted fixture passes 1,531
checks in 6.63 seconds, preserving the previous 1,457 checks, six native
readbacks and twelve moving-follow samples. The registered float32 clipping
counterexample temporarily uses a unit root to preserve its exact physical
1.5x basis, `(251,17)` origin and half-pixel boundary; separate real root-window
tests exercise 960×720, 1280×960 and 1920×1080. The old helper disagrees with all
eight sampled cells at each nonunit root scale and none at unit scale. Local
headless evidence does not substitute for the subsequent framebuffer and
hosted platform campaigns.

Actual `root.push_input(event, false)` delivery then exposed a separate numeric
edge case in Godot's float32 viewport and Control inverses. At a 1280×960 root,
physical `(49,180)` arrives at the Control as approximately
`(36.49999237,42.99998474)` and reprojects to `(48.99999619,179.99998474)`.
Flooring that value selects the previous pixel and world cell `(72,71)` instead
of the displayed `(73,71)`. A visible first-column sample was also rejected as
letterbox. The original event, local coordinate, reprojection and wrong cell
are retained; this is not inferred solely from a synthetic matrix inverse.

The input-only repair restores an integer physical coordinate when its
reconstruction differs by at most `2 * FLT_EPSILON * magnitude`, with
`FLT_EPSILON = 1.1920928955078125e-7` and per-axis magnitude equal to the maximum
of the physical coordinate, transform origin (absolute values) and one. At
magnitude 1920 this is approximately 0.000458 physical pixels. The narrow band
is applied immediately before discrete pointer sampling and PAINT's stationary
pointer storage. Continuous zoom anchors and shader sample arithmetic are
unchanged. The framebuffer regression retains actual GUI-dispatched integer
corners and fractional controls 0.01 and 0.99 pixels away from the boundaries;
it does not substitute general nearest-integer rounding for pixel containment.

Local pinned Godot 4.7 OpenGL/llvmpipe execution passes all 191 graphical
checks. At 960×720 it compares 38,400 content pixels per frame, and at
1280×960 it compares 60,000, before and after a one-pixel pan: corrected
framebuffer and picking mismatches are zero. The old helper retains 8,262 and
16,677 framebuffer mismatches as negative controls. All sixteen actual GUI
events pass, including the originally wrong integer corner and fractional
positions on either side. Original 150 graphical checks remain present; no
pixel tolerance or excluded region was expanded to obtain this result.

The complete Godot campaign also exposed the Blacksite Nine test's minified
overview assumption on both platforms and both desktop/Web controllers. It
injected the mathematical centre of cell `(352,444)` when the overview showed
only 0.3299 or 0.6476 physical pixels per cell. The actual displayed samples
addressed `(353,444)` and `(352,443)` respectively. The map's held/released
input guards worked; the test waited for an unaddressed cell to erase. The
fixture now uses an inspectable view around the same seam and explicitly
checks the real picked cell before its positive erase. All held/release,
native-neighbour and paused-tick assertions remain. This repairs the fixture's
precondition without changing gameplay, minification or map ownership.
The repaired Blacksite fixture passes 261 assertions with zero failures,
including all original 251 and ten visible-target preconditions, at 1.9792
and 3.8854 physical pixels per cell. Fresh local runs after the numeric repair
also pass the actor fixture (157/0) and mounted camera fixture (1,531/0).

The benchmark now derives the physical viewport basis independently for both
subjects. It records actual window/content geometry and verifies that requested
pan, zoom and follow paths really move. Earlier `f67417fb` performance output
retains its original source and apparatus identity but is superseded: fitting
from the old logical transform could clamp a small world to the full width and
suppress the requested horizontal motion. Those measurements cannot qualify
the corrected physical-camera comparison.

That superseded Windows performance job also stopped on the accepted-main
zoom case: the external harness called the newer two-argument `zoom_by`
interface, while accepted main accepts one argument. The runner correctly
rejected the script errors even though the GDScript completion marker was
optimistic. The repair uses the shared one-argument centre-zoom interface and
smoke-exercises every workload against both sources before the next campaign.
The original log and artifact `14072691846` remain inspectable; completed arms
from that failed, older-geometry experiment are not promoted to final results.
All thirteen workloads subsequently pass short, pinned-engine headless runs
against each subject (26 processes), including manual/agent edits, active
2048-square worlds with one/four workers, actual pan/zoom/follow motion and
the shared zoom interface. Independent comparison verifies equal root/window
geometry, physical scales, per-frame view sequences, fixture recipes and
initial native material planes. These are apparatus preconditions, not timing
or graphical performance claims; the exact final head still requires the full
hosted ABBA runs.
