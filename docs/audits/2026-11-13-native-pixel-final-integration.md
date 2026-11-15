---
title: Final native-pixel camera integration, performance and Windows evaluation
status: Current
document-kind: evidence
scope: Accepted #565 reconciliation, controlled application performance, resulting-source platform qualification and Windows delivery for Draft #566
canonical-for: []
last-reviewed: 2026-11-14
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

## Final presentation-fixture acknowledgement

The full Godot campaign at `aa2d1c0aa49dd20cb8bb5ce0e003b1901a4f6f06`,
[43501208280](https://github.com/techrote/cybersand/actions/runs/43501208280),
completed all 54 jobs: 40 passed, 12 failed and two expected optional/scope
jobs were skipped. The failures were the five PLAY UI007 rig wrappers on each
platform and their two coverage aggregates. Every other case shard and both
native builds passed, including the preceding actor, Blacksite and camera
repairs. The Windows shard-zero synchronous watchdog proof was skipped after
its case failure and was not claimed as executed.

The original shared fixture reproduces 59 assertions with two failures for
each rig. A callback-stage diagnostic distinguishes this from a product
alignment failure: at the end of Main callback 79, target, actor and presented
origins all equal `(103.1111145,175.6049347)`. Deferred Container layout then
moves the WorldView's global Y from 229 to 213 before callback 80. A coroutine
resuming on `SceneTree.process_frame` sees that new layout but the prior Main
publication; a fresh origin calculation is then `(103.1111145,172.4444427)`.
Godot emits that signal before ordinary node processing. The original fixture
also wrongly equated the overview's requested `(128,128)` origin with its
snapped presented origin `(123.2592621,131.5555573)` in the intentionally small
64×64 headless root.

The shared fixture now captures coordinate values after the ordinary
Main callback and waits, within its existing watchdog, for a later callback
that has presented the currently observed layout. Readiness does not depend
on the layer-agreement assertion becoming true. The exact original target
comparison is retained and strengthened with same-callback actor and terrain
agreement. Overview checks requested authored framing separately from the
presented origin and explicitly preserves actor epoch, World generation and
session. No manual physics or camera callback, extra World, production change,
floating-point comparison tolerance or retry is introduced.

Graphical execution then exposes two independent input-fixture preconditions.
The Return button's `(20,689,154,31)` rectangle fits inside its 680×740 popup.
The failing visibility assertion is caused by an earlier popup lifecycle:
popup focus exits, root focus enters, and the popup's queued hide runs after
the fixture reopens it. Native root focus was already true in the retained
negative trace. The fixture now acknowledges native root focus and completes
a rendered-frame barrier before reopening, draining that earlier lifecycle.
It does not lengthen a timeout or change the application's popup behavior.

The original direct popup-viewport press/release also reaches the button's
GUI-input callback without establishing hover, so it cannot activate the
button. Godot's embedded-viewport mouse-over path requires routing through
the root/embedder. The corrected fixture sends ordinary motion, left press
with its button mask and release through that root at the popup-transformed
button center. It asserts actual hover, both GUI events and exactly one real
button signal, then retains the original launcher-navigation, Main-destruction,
native-worker join and Rapier-session retirement checks. The direct-popup
negative and root-routed positive are retained. Neither graphical branch
emits a synthetic button signal. These behaviors match pinned Godot's
[Popup focus lifecycle](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/scene/gui/popup.cpp)
and [BaseButton event contract](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/scene/gui/base_button.cpp).

The five original wrappers remain headless cases. Five small `_render`
entry points inherit those exact rig cases, explicitly refuse headless
execution and are discovered graphically by the unchanged complete Linux
regression runner. The original Windows regression runner explicitly excludes
graphical cases; the private integrated-camera campaign therefore also
executes these five cases on both platforms and their installed applications.
Its original nine camera/preservation cases retain their separate results.
Graphical captures use the per-process artifact directory when no dedicated
UI007 path is supplied. The existing overlay-pixel model remains a separate,
unchanged oracle. This closes the coverage gap that had left real popup input
unexecuted in the full suite.

All five original wrappers pass 61 assertions each in fresh pinned headless
execution, retaining the adversarial 64×64 root. The five new graphical entry
points pass 71 assertions each with no failures; all ten original screenshot
hashes are verified. The unchanged overlay model passes 40 checks. The shared
fixture SHA-256 is `3224ae8d3b31e307d95ea3f9bfd0b3aa560c398dca0b3ad6e80ea9b075feb1bf`.
An explicit headless launch of a graphical wrapper refuses before Main runs.
An initial overlay-only invocation also correctly refuses a composite local
source label; its corrected invocation records the exact unchanged `aa2d1c0a`
commit, while the separate local manifest identifies the shared-fixture delta.
Neither refusal is treated as a passing graphical run.

The private campaign independently re-reads each original UI007 receipt and
both PNG hashes, checks all 71 assertions and actual input/owner outcomes,
and binds them to source, engine, Rapier and native runtime custody. Sixteen
admission guards pass, including deliberate wrong-source, headless, incomplete
input, stale-presentation, altered-capture and relabeled-result negatives.
The original nine camera results remain unchanged and separately required.
The subsequent complete final-head campaign and published delivery are
recorded in the PR delivery ledger. The follow-up changes only this shared fixture, its graphical entry
points, the private qualification admission and this evidence document;
application, native, shader, recorder and performance-apparatus bytes remain
identical to the measured `aa2d1c0a` product. Any performance evidence retained
from that source keeps its actual commit and runtime identities; it is not
relabeled as execution of a later commit.

## Extracted-package Git directory preservation

The next integrated campaign at
`78a277f2f91e0623be654f2472ae795b0adc8f5e`,
[43509386141](https://github.com/techrote/cybersand/actions/runs/43509386141),
passes the Linux and Windows source applications and both full performance
campaigns. The separately dispatched Documentation, Native, Godot and required
Palette gates also pass on that exact source. Its Windows package nevertheless
fails before installed application cases: bundled Python cannot authenticate
the retained compatibility ancestry through bundled Git. The failed delivery
is not published or accepted.

Built-in .NET extraction had successfully hashed all 21,013 extracted files;
the Windows Shell ZIP handler had opened the archive and copied both launchers
and README with exact bytes. Those file checks did not detect missing empty
directories. The private `write_archive` implementation enumerated only files,
omitting the clean detached repository's empty `source/.git/refs` directory.
Git requires that directory to recognize its repository, even when all retained
objects and `packed-refs` are present. Consequently `git show` exited 128; the
compatibility wrapper's generic history error did not itself prove a missing
commit. The baseline and all compatibility-transition commits remain ancestors
of the exact source.

A discriminating local reproduction uses the actual clean-source packager and
the frozen private ZIP writer. The clean detached repository can read its
retained baseline before archiving. After the file-only ZIP round trip, the
same command fails with `not a git repository`. Creating only the missing
empty `.git/refs` directory immediately restores the same baseline blob, with
every file byte unchanged. The original #565 archive explicitly included that
directory; extracting only its files reproduces the same failure.

The narrow repair preserves directory entries in the private ZIP, including
empty directories, while retaining conventional Deflate, the Windows name and
path checks, symlink refusal and exact file-hash inventories. A real detached
Git repository round-trip regression must preserve the source commit, retained
ancestor/blob and empty reference directories. No compatibility check, history
closure, dependency version, application code or performance apparatus is
changed. The repaired source must complete its own full qualification and
actual .NET-extracted package execution; the preceding source successes keep
their original commit identities and are not relabeled as those new results.

## Explicit one-pixel-per-cell motion coverage

A final comparison with the mission's requested zoom matrix finds a coverage
gap at the archive-repaired source
`90838045d6fe8085646f2318f9753b8c3a92af29`. The existing coordinate and graphical
matrices exercise 2x, 2.5x, 4x and 8x motion. Their 1x shader reference and the
2048-square 1x performance case are stationary; neither establishes 1x slow
panning. The separate Palette camera offsets use their retained fallback
mapping. This is missing explicit coverage, not a demonstrated product defect.

The two existing camera fixtures now append 1x without removing or reordering
their prior cases. The graphical fixture also renders sixteen forward and
sixteen reverse fractional requests, 32 frames total, using exact binary
increments. Its independent expected
pixel phase is derived from the unsnapped request, and its unchanged per-cell
and translated-frame oracles inspect actual GPU images. The sequence retains
26 stationary phases, advances `(2,1)` physical pixels, reverses `(-2,-1)` and
returns to its original frame byte-for-byte. Request accumulation never uses
the rounded presentation as its next input.

A third mounted Main/root-window case uses a 960x720 Window, its actual 0.5
root stretch, a 240x160 logical WorldView and a 120x80-cell view. The measured
physical basis is exactly `(1,1)`. Actual images and input picking have zero
mismatches over 9,600 content pixels before and after a one-pixel pan; all eight
new real integer/fractional GUI inputs agree with the captured cell. The former
screen helper remains a negative control, with 7,972 framebuffer and 9,600
picking mismatches in this new setting. Existing capture names are preserved;
the new setting has its own `-zoom-1` names.

Pinned local Godot 4.7 execution passes 1,687 coordinate/native-edit/follow
checks and 339 graphical checks, preserving the earlier 1,531 and 191. The
graphical receipt contains 31 captures, 116 frame observations, nine mounted
root records and 24 real GUI events. The CPU fixture SHA-256 is
`8d2a0313c7997bef59bbaa51750696db4e04c413b91bc1a04bb9b5c3185ee3a1`;
the graphical fixture SHA-256 is
`1c03370749a6b7ac9ced67bb6d9ad107dc5837f709b00e72636be7a6e1c141e8`.
These are unpublished test-only delta results against the identified parent,
not relabeled original `90838045` execution.

The existing source and installed camera labels automatically exercise the
expanded fixtures on both platforms. All original image tolerances, reference
and translation oracles, shader fixture setup and timing function bodies are
unchanged. The application benchmark and its runner also remain byte-identical;
the broader historical graphical fixture now includes the additional correctness
cases and therefore has a new source hash. The published follow-up must complete
its own full platform/performance/package campaign. No application, camera,
recorder, shader, native, physics or authoring implementation is modified.

## Installed large-Fill fixture selectability repair (2026-11-14)

The exact `f8041847bc7627b3fdd3d7426d45f646f79995fd` campaign
[43524865177](https://github.com/techrote/cybersand/actions/runs/43524865177)
passes both source application campaigns, both performance campaigns and all
four separately dispatched downstream gates. Its installed Windows
[package job 132255724278](https://github.com/techrote/cybersand/actions/runs/43524865177/job/132255724278)
nevertheless fails the combined 1024-square authoring fixture. No failed ZIP is
published. Microsoft .NET extraction has verified all 21,019 files, the Shell
ZIP handler has opened the archive and copied both launchers plus README, and
bundled Git compatibility plus all four Materials Lab installed cases pass.
This provides actual Windows confirmation of the preceding empty-directory
repair; interactive Explorer GUI use remains untested.

The first combined-authoring failure expects 147,456 Fill cells, but the native
receipt completes 147,840 cells, with the same requested, checked, changed and
applied counts. There is no native error, incomplete prefix or timeout. Nine
later required-phase failures follow the early return. Source combined cases
use a 512-square World, so their success does not cover this installed
1024-square adaptive-Fill path. The original Windows failure artifact
`14088539002` is 1,165,666 bytes with SHA-256
`2871325db411c037d7d064f2f72c3ae9ef77fe4e48b92a6e10a0e1b28e32a4b5`.

An external diagnostic subclass runs the unchanged fixture and production
source with pinned Godot 4.7, the source-built Linux native runtime and actual
X11/OpenGL presentation. It traces the requested endpoint, physical sample,
published shader cell and actual Main pick, then captures native cells after
the real PAINT Rectangle/Outline input events and before Fill. The ordinary
Linux layout has a 1,880-by-710 logical WorldView, a 0.75 physical stretch and a
960-by-540-cell view: 71/72 physical pixels per cell. Both requested corners
remain selectable, the native enclosure is exactly 386 by 386, and Fill
completes the required 384 by 384 interior. The complete author flow passes
218 checks, including two diagnostic capture checks.

The same-source Windows performance geometry records a 708-high WorldView.
A discriminating Linux counterexample changes only the real toolbar's minimum
height by two logical pixels, allowing its parent container to allocate that
708-high view. The resulting physical scale is 59/60 pixels per cell. The
requested first corner `(560,64)` remains exact, while `(945,449)` addresses a
pixel displaying `(945,450)` in both Main picking and the published shader
mapping. Independent native readback verifies all 149,382 cells in the actual
386-by-387 enclosure: 1,542 boundary cells are material 58 and all 147,840
interior cells are Empty. Fill then completes exactly 147,840 and the original
assertion fails. This reproduces the fixture defect and exact failure count;
the failed Windows process itself did not log its endpoints, so the diagnostic
does not invent a direct geometry trace for that original process.

The narrow fixture repair temporarily inspects the unchanged enclosure in a
400-by-400-cell view. Before the existing gestures it requires at least one
physical pixel per cell and exact endpoint picks, and records both overview
and inspection geometry. A native capture independently checks the complete
Empty interior and material-58 boundary before Fill. The original 147,456-cell
receipt assertion, every post-Fill native material check, full-World save
comparison and fresh-process reopen checks remain unchanged. The previous
camera origin and view size are restored and checked before subsequent
authoring. No capacity, deadline, worker configuration, input implementation,
camera mapping, shader, native code or material rule is changed.

The repaired fixture SHA-256 is
`f59e80e3174526ace3e55ec9e4da8410a4fcbecc7b4b7ace857e4444c6b5d927`.
Actual local X11 execution at the reproduced 708-high layout passes 222 author
checks and 54 fresh-process reopen checks for each of one and four workers.
The inspection basis is 1.3275 physical pixels per cell and its requested
corners are exact; both Fill receipts complete 147,456 cells. Independent
readback verifies all 148,996 cells in each of eight large-enclosure captures
before Fill, after Fill and at reopen, plus fourteen original PNG hashes and
dimensions. Each author run's complete prepared native material digest matches
its own fresh reopen. The production engine and native hashes remain the
identified pinned runtime bytes.

The external Python observer initially raises a path-indexing TypeError during
its final protected-file rehash, after all four Godot processes have exited
zero and stored their complete receipts. The original exception is retained;
a separate read-only hash closure corrects path joining and verifies the same
original logs and source bytes. It neither reruns an application case nor
changes repository source. This observer defect is separate from the four
successful executed cases.

Local evidence describes this unpublished test-only delta on `f8041847`, not
new acceptance of that failed delivery. Its published successor must complete
fresh exact-source qualification and every actual extracted Windows case;
the earlier source and performance successes retain their original identities.
