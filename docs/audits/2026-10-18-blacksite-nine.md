---
title: Blacksite Nine connected scene implementation and validation
status: Current
document-kind: audit
scope: 2026-10-18 continuous nine-district scene, frozen native recipe, Linux traversal/controller/render evidence and publication boundary; separate from broad physics or platform acceptance
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../operations/blacksite-nine-demo.md, ../reference/validation-evidence.md, 2026-10-18-neon-reliquary-descent.md, ../operations/current-and-historical-validation.md]
---

# Blacksite Nine implementation checkpoint

## Request and recoverable source boundary

The owner requested nine seamlessly connected CyberSand tiles in a 3 × 3
composition: an industrial research laboratory between two surface wastelands,
with six dense underground hive and machinery districts. The aesthetic direction
favours advanced detail, oppressive industrial mass, irregular rooms and narrow
service routes. This increment supplies authored content, camera navigation and
scene-specific presentation using the existing native material world.

The inspected source root is `/workspace/scratch/fb9daf9fc631/cybersand`, with
remote repository `techrote/cybersand`. The current local branch is
**`scene/blacksite-nine`**. Its recoverable merge baseline is
**`b93a17de775b8fdb98fd7ddfd88f01ffeaae56e1`**, with parents
**`1ab7c9fc6bd35c832fdc70a4fcdfceae3e71d0f3`** and
**`087ca3e972296b189c8b83060463125c06d600e2`**. That merge incorporates the
previous four-scene history and current ACT-002 actor rigs before this new
connected-scene delta. It is not the final Blacksite implementation commit.

The implementation was validated as a delta above that merge baseline, then
published with the identical Git tree recorded below. The companion
[evidence manifest](2026-10-18-blacksite-nine-evidence.json) binds the recipe,
source files, tests, runtime and retained images. The capture's own script list
is an apparatus identity, not a complete checkout manifest; its unembedded Git
revision must not be substituted for the explicit source boundary here.

The earlier [Neon Reliquary descent audit](2026-10-18-neon-reliquary-descent.md)
remains historical evidence for its four independently installed districts and
their publication. Blacksite does not revise those recipes or their old results.
Native source, material rules, ordinary palette/emission/glow shaders, native
ABI, dependency pins and retained runtime libraries remain unchanged by this
scene increment. Current-provenance checking passed with all 18 required LFS
payloads materialized; all 30 recorded native source inputs match their retained
Linux provenance hashes.

## Frozen scene and construction

The complete complex occupies **`[32,32,960,960]`** inside one finite
1024 × 1024 native world. Each district is a 320 × 320 camera tile. The scene
uses one schema-2 definition, **`showcase/blacksite-nine`**, and one ordinary demo
ID, **`blacksite_nine`**. It does not load or reconstruct a district when the
player crosses an internal boundary or the camera changes tiles.

| Row | West | Centre | East |
|---|---|---|---|
| Surface | A1 · Slag Approach | A2 · Aster Research | A3 · Ashworks Breach |
| Middle works | B1 · The Intake Warrens | B2 · Containment Choir | B3 · Condensate Works |
| Deep works | C1 · Furnace Ossuary | C2 · The Synapse Vault | C3 · Blackwater Terminus |

The surface contrasts a collapsed viaduct and leaning transmission frame with
the fortified laboratory's containment cassettes, then a damaged receiver dish,
crane and cargo tram. Below it, bunks and a freight cage, a monitor theatre,
condensate vessels, unequal crusher jaws, an instrument shrine and flooded pump
machinery provide distinct landmarks. Dark wiring, solid corroded finishes and
restrained cyan/amber instruments carry the palette through all nine districts.
The [scene guide](../operations/blacksite-nine-demo.md) owns the detailed art,
route, authoring and control descriptions.

| Frozen construction identity | Value |
|---|---|
| Ordered rectangles | **3,527** |
| Authored cell writes, including overlapping layers and Empty carves | **2,776,918** |
| Material identities, including Empty | **32** |
| Canonical definition bytes | **58,021** |
| Canonical definition SHA-256 | `225b0cdbd677d678cdfd5188df2f8fd17987e7edfbe508049fbbae261f21d489` |
| Tile-local record counts, A1 through C3 | `351, 356, 345, 356, 367, 351, 334, 342, 330` |

The retained [portable definition](../images/blacksite-nine/blacksite-nine.scenario.json)
adds one final line feed: the file is **58,022 bytes**, with raw file SHA-256
`42285d402fd756ea77fe8f8a8cec091577e68d721e19d6c4098848019a3e0a34`.
Removing only that final line feed yields the canonical bytes and frozen digest
above. These are deliberately different identities.

[`CyberBlacksiteNine.rectangles()`](../../godot/scripts/blacksite_nine.gd)
composes the three row recipes, then owns the outside walls, route floors,
shaft sidewalls and shared collars. Its final clear pass reserves a
**28-cell-wide circulation band** along every path in
[`CyberBlacksiteNineLayout`](../../godot/scripts/blacksite_nine_layout.gd).
Glass, cables, lights and grilles retain ordinary native collision and are
cleared out of that reservation. All twelve horizontally or vertically adjacent
district pairs have reciprocal openings in the same material field.

The strict contract retains its 4,096-record, eight-world-area and 1 MiB canonical
JSON limits. Every local tile stays within its 320 × 320 bounds and 410-record
allocation. Baseline transport, Water8/coherence12 and the ordinary owner
execution policy remain in force. Fixed interest admits the whole complex
independently of camera framing. The definition enables the historical sampled
player and paint/erase/player tools, with no bodies, scheduled events,
observations or objectives. This is authored setup, not a saved continuation or
complete deterministic replay.

## Interaction and presentation scope

Desktop **Shift+F11** or the Blacksite launcher, and the Web demo menu, install
the same paused tick-zero complex through the existing MicroScenario host.
Desktop waits for the asynchronous owner acknowledgement; Web installs through
its synchronous owner. The 3 × 3 map, whole-complex view and following view
change camera state while retaining the world, edits, tick, player and pause
state. **R** restores all nine districts and the initial player together.
**F10** remains the recorder and ordinary **F11** retains Neon Reliquary.

The scene-specific backdrop and multiplicative exposure grade use absolute
world coordinates and accepted immutable current/previous material textures.
The backdrop excludes occupied cells, unfinished material-to-empty transitions
and the sampled player. The grade affects material appearance while excluding
Empty cells and the player. Both are disabled for an edited definition that
enables rigid bodies. Neither supplies collision or changes material authority.
Normal material rendering and glow remain in use.

The map popup now suppresses painting, movement, jetpack and camera-pan input.
Held pointer and movement/pan keys must be released before a new gesture resumes
after closing the map. Material ticks may continue while the popup is open.
The actual keyboard defect and its correction are recorded below; pointer
blocking alone was not treated as proof of keyboard blocking.

## Runtime and artifact identity

All new execution in this record uses Linux x86_64 and the pinned
**Godot `4.7.stable.official.5b4e0cb0f`**. Focused Blacksite native and controller
fixtures use one native worker. Existing fixtures retain their own choices;
MicroScenarios intentionally compares one and four workers.

| Runtime artifact | SHA-256 |
|---|---|
| Official Godot editor archive | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Executed Linux Godot binary | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| CyberSand Linux native GDExtension | `43e747137249041d56a522dbe0ec35219082ea555e1ec1cbdd40971c6a58db9c` |
| Rapier 0.35.2 Linux library | `147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831` |

The native artifact retains its existing
[Linux provenance](../../godot/addons/cybersand_native/runtime-provenance.linux.json),
including native source commit `aae015058f907e15b0781ff7fbd3ebd55e4d990e`.
That native build identity is separate from this scene's merge baseline and
working script delta. No runtime was rebuilt or reattested for scene content.

Rendered checks use a real X11 display under Xvfb, Godot Compatibility/OpenGL
4.5, Mesa `25.2.8-0ubuntu0.24.04.2` and llvmpipe LLVM 20.1.2. This is software
rendering, not physical-GPU performance evidence. The display reports its
unsupported V-Sync-mode warning; final rendered runs have no script or shader
errors.

## Native construction and actual sampled traversal

[`test_blacksite_nine.gd`](../../godot/tests/test_blacksite_nine.gd) passes
**158 assertions with zero failures**, exit status 0. It checks the strict shared
recipe and canonical round trip, nine framings, exact setup bytes, safe supported
spawn, limits, rejection of an invalid replacement and exact whole-world reset.
A normal native paint operation supplies a positive collision control before
reset removes that edit.

Native 28 × 28 collision queries sampled every four cells cover the whole route
reservation, including turn caps and shared boundaries. These checks run before
and after **120 native material ticks**. The seam checks additionally inspect
continuous footing or shaft collars. **549,763 authored hard cells** retain their
material identity through that progression, and native storage/scheduler
statistics remain within their existing capacity.

Traversal then uses the actual
[`CyberSampledCharacter.simulate()`](../../godot/scripts/sampled_character.gd)
implementation against the progressed native world. Each step uses `1/60` second,
horizontal input in `{-1,0,1}` and a Boolean jetpack input. The driver does not
assign position, velocity, acceleration or recovery policy while travelling.

| Actual movement evidence | Result |
|---|---:|
| Neighbouring seams | **12** |
| Forward/reverse physical crossings | **24 / 24** |
| Continuous tour movement steps | **6,712** |
| Jetpack steps within that tour | **2,154** |
| Total crossing and tour movement steps | **8,572** |
| Runtime enclosure-recovery attempts | **0** |
| Invalid-spawn recovery attempts | **0** |

Each directed seam case starts a character on one side and physically moves it
forty cells to the other. The full tour uses **one character and one initial
reset**, visiting **A1 → A2 → B2 → B1 → C1 → C2 → C3 → B3 → A3**. The route graph
supplies turn waypoints; reaching them still requires ordinary movement and
native collision. Recovery counters and body enclosure are checked after every
movement step. The independent sorted-tour assertion requires exactly all nine
IDs, and bounded, unique orthogonal edge metadata requires all twelve pairs.

The long movement portion does **not** advance native materials on each
character step. Its explicit claim is traversability of the native geometry
after 120 ticks. The native tick and exported material bytes remain unchanged
through those movement checks. It is not a full live-material tour, an
interactive timing result, general traversal acceptance or a substitute for
controller integration.

## Controller integration and existing regressions

The latest completed
[`test_blacksite_nine_integration.gd`](../../godot/tests/test_blacksite_nine_integration.gd)
run passes **249 assertions with zero failures**, exit status 0, on the desktop
asynchronous owner and synchronous Web controller hosted by Linux Godot. It
covers camera-only visits to all nine districts, retained edits including paint
across a shared seam, continued full-region interest, pause/reset, rejected
requests, input ownership and exit to ordinary scenes.

The four-tick interest probe records advancement in **nine regions**, including
**eight outside the selected camera tile**, for each owner. The keyboard checks
exercise physical D, Space and Right-arrow input with the map open, closed with
keys held, and after release followed by a fresh gesture. Their recorded owner
steps continue materials while guarding player/camera input. This is direct
controller evidence and remains separate from actual browser execution.

The earlier 243-assertion run covers the keyboard-modal fix. Six additional
assertions on the final layout verify that both owners share the existing
launcher row, relax the active world's minimum height while retaining its prior
minimum width, and restore the exact prior minimum-size vector on exit. The
final atlas and seven-state rendered UI review use that presenter source.

Six existing regressions also pass, with unchanged test and native source:

| Existing fixture | Result | Process bound |
|---|---|---:|
| `test_showcase_tiles.gd` | **200 assertions, 0 failures** | 180 s |
| `test_neon_reliquary.gd` | **89 assertions, 0 failures** | 180 s |
| `test_microscenarios.gd` | **8,843 assertions, 0 failures** | 240 s |
| `test_web_demo_setup.gd` | **0 failures**; four constructors, stepping, CYSD1 and native rejection | 180 s |
| `test_actor_rig_integration.gd` | **683 assertions, 0 failures** | 180 s |
| `test_brush_owner_commands.gd` | **0 failures** | 180 s |

All six processes exited 0, with no parser/runtime error lines. They completed
before the isolated Blacksite keyboard-modal fix and exercise inactive Blacksite
controls. The new integration fixture covers the subsequent map-specific change;
the six earlier results are not silently relabelled as execution of later source.
Raw log hashes and source boundaries are retained in the companion manifest.

## Rendered continuity and visual review

[`test_blacksite_nine_render.gd`](../../godot/tests/test_blacksite_nine_render.gd)
passes **40 rendered checks with zero failures**, exit status 0. It verifies the
two effects' current/previous occupancy, Empty, player, fresh-paint and erase
behaviour, and exact overlapping pixels under camera motion across all twelve
seams for both world-coordinate effects. Its headless path explicitly skips;
the result recorded here used the X11 rendering display.

The normal desktop scene and accepted native publication produced the retained
[2880 × 2880 atlas](../images/blacksite-nine/blacksite-nine.png) at paused tick zero
and three pixels per native cell. The
[capture manifest](../images/blacksite-nine/capture.json) and portable definition
accompany nine 960 × 960 district PNGs. These district images are crops from the
same rendered atlas, preserving shared glow; they are not claimed to be nine
independently rendered cameras.

Read-only decoded-pixel comparison establishes **9/9 exact crop matches**.
Stitching all nine files reproduces the atlas with **zero differing pixels and
zero maximum channel difference**. That proves integrity of the exported image
set. The separate 40-check renderer fixture supplies camera-motion evidence;
crop equality by itself is not that test.

The full atlas and all nine district images were visually inspected. The central
lab, distinct western viaduct and eastern receiver/crane wastelands, six enclosed
underground landmarks, muted wiring and restrained instruments remain readable.
No remaining material aesthetic defect requiring another art change was found
in that review. This is an implementation review, not inferred owner acceptance.

### Final rendered UI

The final X11 UI review passes **seven states with zero failures**, exit status
0. It combines visible-control bounds diagnostics with inspection of the tile,
map and clean views at **1280 × 720** and **1600 × 900**, plus the restored
Experiment Tower after exit at 1600 × 900.

| Reviewed states | Result |
|---|---|
| Tile view at both window sizes | Title and recorder visible; no clipping or overlapping controls |
| Map view at both window sizes | All nine district labels readable; popup contained; pointer and keyboard guards active |
| F8 clean view at both window sizes | **Zero visible controls**, with the map hidden and scene atmosphere retained |
| Tower after exit | Ordinary title, controls and layout restored; Blacksite map, backdrop and grade hidden |

All seven states have an empty out-of-bounds-control report. At both window
sizes, the title rectangle is **`[20,16,1880,31]`** and the recorder rectangle is
**`[20,1033,1880,31]`**, expressed as `[x,y,width,height]` on the **1920 × 1080
logical canvas**. These are logical layout bounds, not physical window pixels.
The six active-scene captures remain paused at tick zero.

The retained review record is
`/tmp/cybersand-demo-validation/blacksite-ui-review-final/review.json`, SHA-256
`acf7886a15a1e503335760db043845e95fc7c2272dabe1f77a860fdc3d26ec2f`.
Its command, helper, final metadata, image hashes and earlier overflow evidence
are also bound through the companion evidence manifest.

## Diagnosed attempts and corrections

Failed and qualified attempts remain separate from final passing evidence:

- The initial native fixture reported three failures. Its Western maintenance
  well sidewall assertion extended twenty cells into a deliberately open elbow,
  producing the same false expectation before and after progression. Restricting
  collar inspection to the shared seam preserves the full forty-cell movement
  and body-clearance checks. Its solid positive control also used
  `diagnostic_fill_rect()`, which correctly rejects ordinary, non-diagnostic
  worlds. The fixture now uses normal `paint_disc()` and verifies the resulting
  native material and collision. No geometry or native policy changed for these
  corrections. All 24 crossings and the full tour had already succeeded in the
  failing attempt.
- Initial controller integration recorded four failures from expectations that
  fixed interest also froze owner execution/quality policy. The scene declares
  fixed interest and ordinary owner execution. Those expectations were corrected
  to the existing contract, and the result distinguishes nine advanced regions
  from the eight actually outside the camera. This was not justification to
  introduce new simulation policy.
- A separate physical-key reproduction exposed a real desktop defect: while the
  map's pointer guard was active, D, Space and Right-arrow polling still moved
  the player and camera, and held input remained active after closing it. The
  presenter/desktop/Web paths now share explicit map keyboard blocking and
  release-before-rearm handling. The rendered post-fix reproduction reports no
  player or camera movement with the map open and keeps held input blocked after
  close. The expanded 243-assertion keyboard iteration supplies fresh-gesture
  positive controls as well as blocking checks.
- An intermediate keyboard-fixture run reported unacknowledged Web owner steps
  after the headless popup emitted focus-out, and the partial run was interrupted.
  The corrected fixture explicitly sets Web `focused` and `input_armed` before
  synchronous steps to isolate the map guard, with a source comment documenting
  that choice. Production focus handling was unchanged. It retains movement
  positive controls and does not treat headless OS focus as browser-input proof.
- The first rendered layout review found vertical overflow: the title began at
  logical y = -18.5 and the recorder extended to y = 1098.5 on a 1080-high
  canvas. Sharing the existing launcher row and relaxing the active world's
  minimum height corrected that layout. The final seven-state review has no
  clipping, and the 249-assertion integration run checks exact restoration of
  the prior minimum-size vector on both owners. The earlier metadata remains
  retained separately from the corrected images.
- Visual iteration found the ordinary Cable material's multicoloured bands too
  prominent for this composition. Authored wiring changed to the existing Rubber
  finish, and the scene-specific world-coordinate exposure grade was reviewed in
  actual Godot images. Neither change alters native material rules.

The known software V-Sync warning is retained in rendered logs. Prior Neon and
four-district failures and publication records remain in their original audits;
they are not rewritten as Blacksite attempts.

## Reproduction

Use the exact pinned Godot runtime, materialized matching native/Rapier
libraries and writable Godot user directories. The local headless wrapper sets
`XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` beneath the validation
scratch directory. The actual bounded native regression command was:

```sh
timeout --signal=TERM --kill-after=10s 180s \
  /tmp/cybersand-demo-validation/run-godot.sh --headless --path godot \
  --script res://tests/test_blacksite_nine.gd
```

The six existing scripts use that same command shape with the bounds in the
table. The final integration run used the following command, with stdout/stderr
redirected to `blacksite-integration-layout-final.log`:

```sh
/tmp/cybersand-demo-validation/run-godot.sh --headless \
  --path /workspace/scratch/fb9daf9fc631/cybersand/godot \
  --script res://tests/test_blacksite_nine_integration.gd
```

That run had no external process timeout. Its ordinary waits are bounded at
20 seconds and each native keyboard step at five seconds. The rendered
post-fix keyboard probe likewise used the pinned rendered wrapper without an
external timeout. The seven-state UI helper uses that wrapper, with 15-second
install/exit waits and no external process timeout. Exact invocations and log
paths are recorded in the companion evidence manifest. From the repository
root, rendered reproduction examples with `godot` resolved to the pinned engine
are:

```sh
timeout 120 godot --path godot --rendering-method gl_compatibility \
  --script res://tests/test_blacksite_nine_render.gd
timeout 180 godot --path godot --rendering-method gl_compatibility --max-fps 30 \
  --script res://tools/capture_blacksite_nine.gd -- \
  --capture-dir=/tmp/blacksite-nine-capture
```

Both commands require a rendering display. The capture helper rejects
headless capture. Running the Web controller inside Linux Godot is not an actual
browser/WebAssembly, WebGPU or Web export result.

## Documentation-update checklist and claim map

This checkpoint follows the canonical
[documentation-update checklist](../operations/documentation-maintenance.md#documentation-update-checklist).
The scene guide owns Current controls and construction; this dated audit records
the evidence and its source/platform limits.

| Checklist concern | Canonical disposition in this working checkpoint |
|---|---|
| Actual source, local delta and recoverable boundary | Merge baseline and both parents recorded above; file/artifact bindings in the companion manifest; final publication identity remains separate |
| User entry, route, camera/edit/reset semantics | [Blacksite guide](../operations/blacksite-nine-demo.md), [README](../../README.md), [Material Lab](../MATERIAL_LAB.md) and [documentation index](../README.md) |
| Ownership, lifetime and immutable presentation | [Ownership contract](../architecture/data-ownership-and-lifetimes.md) and [material appearance](../systems/material-appearance-and-rendering.md) link the new consumer; native World and render handoff remain authoritative |
| Schema, interfaces, configuration and limits | [MicroScenarios](../operations/microscenarios.md) and [configuration reference](../reference/configuration-reference.md); no schema, ABI or capacity increase |
| Programme, roadmap and handover | [MicroScenario programme](../operations/microscenarios-programme.md), [roadmap](../reference/status-and-roadmap.md) and [handover](../operations/cybersand-codex-development-handover.md); no physics gate or issue-order change |
| Retrieval ownership, aliases and reverse routes | New canonical scene guide in the [corpus](../reference/retrieval-corpus.json), [retrieval index](../reference/retrieval-index.md) and independent `SCENE03` challenge; frozen 32 questions and the earlier scene/actor challenges remain intact |
| Dated execution and preserved failures | This audit, companion manifest and [validation ledger](../reference/validation-evidence.md); earlier scene audits and historical M11 hashes preserved |
| ADRs, native invariants, dependencies and CI provider | No new architectural decision, material rule, runtime pin or workflow/provider migration; existing contracts and gates retain their scopes |
| Final checks and checkpoint | Documentation/current provenance, historical M11, both retrieval sets and the final local diff passed as recorded below; publication identity is recorded separately |

## Final local repository gates

All six gates exited 0 on the assembled scene source. The companion manifest
retains their exact commands, source snapshots, output hashes and limits.

| Gate | Recorded result |
|---|---|
| `python3 tools/ci/check_docs.py` | 82 documents, 8 navigation documents, 146 canonical claims, 1,444 local links, 84 heading anchors and 32 frozen questions; no errors or warnings |
| `python3 tools/ci/check_repository.py --require-materialized` | Passed; all 18 required runtime payloads materialized, no missing payloads or errors |
| `python3 tools/ci/check_m11_consistency.py` | 18 historical records and 28 source hashes verified against `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`; no errors |
| Frozen lexical retrieval | 32/32 canonical hits at 5, 23 at 1, MRR 0.8438 |
| Supplementary lexical retrieval | 48/48 canonical hits at 5, 37 at 1, MRR 0.8705 |
| `git diff --check` | Passed with no diagnostics |

Both retrieval runs use 82 documents and 825 heading chunks. SCENE01–SCENE03
and ACT01–ACT09 each rank 1. The SCENE03 returned passages include the full tour,
entry, continuous native state, camera controls, reset scope and presentation
ownership. Canonical retrieval hits are not independent proof of answer
correctness. No checked input or evaluated corpus file changed during the gate
run. Publication bookkeeping is recorded after that snapshot.

Current source/runtime provenance and historical M11 integrity remain
[separate gates](../operations/current-and-historical-validation.md); the M11
pass does not reattest current runtime behavior.

## Acceptance limits and publication

**Current local evidence:** the frozen native scene is constructed, traversed
under the stated sampled-character scope, exercised through both Linux-hosted
controllers, and reviewed in actual software-rendered images. It does not
establish a complete live-material full tour, performance or scalability,
target-PC feel, physical-GPU timing, Windows/macOS execution, browser/WebAssembly,
WebGPU or cross-platform parity. It supplies no new Water successor, general
body-coupling, broad gameplay acceptance or exact replay guarantee. The
GDScript fallback does not gain equivalent native scene/material semantics.

**Published:** [scene/blacksite-nine](https://github.com/techrote/cybersand/tree/scene/blacksite-nine),
with [draft PR #175](https://github.com/techrote/cybersand/pull/175) targeting
main. The PR builds on the still-open four-scene [PR #167](https://github.com/techrote/cybersand/pull/167)
and includes the current ACT-002 main baseline. Neither PR nor main was merged
by this task.

| Publication identity | Value |
|---|---|
| Published scene implementation | `ab7eb974c3b9442b14661ea96c8344385b33b688` |
| Verified implementation tree | `79ac1fc79d10f4678d6227ba4af02eb8cd536bbc` |
| Equivalent local implementation | `d3c477ea6164b634b6642829763ceed9cc9360c4` |
| Published merge baseline | `94f6cbefc313a65f27c6e6ba8ca0d1aa89412bac` |
| Identical local/published baseline tree | `eedc52b3ad8bff2f096d9de136f11d7d6e50ffb0` |
| Preserved local history branch | `scene/blacksite-nine-local-checkpoint` |

Git data publication verified every uploaded image blob and required the remote
implementation tree to equal the committed local tree before creating the branch.
A fresh fetch then confirmed the same tree and a zero-difference checkout.
The local history checkpoint retains the original merge and implementation
commits; the working branch tracks the published branch. This subsequent audit
and manifest update changes only publication documentation, leaving all recorded
implementation, test, recipe and image hashes unchanged.

The PR remains a draft review checkpoint. Local passes do not substitute for
applicable exact-head ready-for-review integration jobs before a later merge
into main; draft scope/classification jobs are not runtime execution evidence.
The initial published implementation passed
[Documentation/provenance run 39123398663](https://github.com/techrote/cybersand/actions/runs/39123398663).
Its Native and GDExtension workflows were skipped in draft state. The PR owns
the CI disposition of subsequent publication-documentation commits.
