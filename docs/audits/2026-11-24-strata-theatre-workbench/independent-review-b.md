# STRATA-THEATRE-WORKBENCH-001 — specialist B review

**Reviewer:** presentation/interface specialist B. **Disposition:** Draft/HOLD;
scoped engineering and owner-handoff review completed. This is an independent review of root's ordinary
Workbench integration, A's ownership boundary, and C's qualification coverage.
B authored the presenter, panel and examples, so this document does **not**
independently approve those implementations. A reviewed B's private shader repair;
C owns its actual framebuffer qualification.

## Reviewed source and evidence

Root's integrated source review covered
`fd73afadf4f776829538ec526417aac0ca5e5088`, with the Art deferral correction checked
at `8dce8dd5a0a596ee1f2a40bbe8d9fac4106cc006`. Relevant files are the Strata
controller, ordinary Shared Workbench and paint-editor hooks, static layer owner,
and the actual Workbench graphical qualifier. C was actively extending the
qualifier during review; its uncommitted inspection snapshot had SHA-256
`35a414dbd34e83eaeca861ada0b5b841e38876a9b223be648f5192b7074a8cf2`.

I inspected actual hosted Linux Godot images in
`/tmp/strata-campaign1-linux/{industrial-assembly,arcology,cavern}/`:
`composite.png`, `disabled.png`, and `plane-background.png` for each scene.
Their execution reports identify source
`16054c8894af6ba747ae72cf6b3cb582aa113c4c`, 569 GDScript checks per scene and empty
failure arrays. The overall campaign **failed**, because its Python validator
incorrectly required positive RefCounted instance IDs. Those original results
are retained; they are not a completed platform qualification or fresh-process
reopen pass. Visual review found an additional real product defect that those
569 checks did not detect.

## Independent findings and repairs

| Finding | Evidence and disposition |
| --- | --- |
| **Blocking: Play material remained visible during background Solo** | All three background-only images still show the complete Play platforms/floor, while the actor overlay is hidden. The palette fragment assigns `COLOR = colour`, bypassing `self_modulate`. Native no-edit checks and nonempty framebuffer checks could therefore pass while visibility was wrong. B repaired the isolated private presentation variant in `30d9cc84e38bc732dfa970948f3126cbef96e2fd`; A independently found no source-level blocker. Actual final-pixel opacity 0/0.5/1, Solo, Flat, hide and restore checks remain mandatory. |
| **Blocking follow-up: additive Play glow bypassed modulation too** | Existing `glow_composite.gdshader` writes its additive RGB directly, so hiding the main material alone would leave emissive Play halos. B's `83e56f74177a4e29bee101582de8a87287c7bf62` adds a separately validated private final-RGB opacity factor, retaining normal glow strength, enable state and viewport scheduling. A independently reviewed both alias/material restoration paths. C must verify an emissive material-77 core/halo at 0/0.5/1, Solo and hide, plus the existing glow toggle. No shared shader file was changed. |
| **Queued Art/manual Stop could remain stuck after switching edit target** | The new host guard returned `busy:true` with a terminal target error. Existing `_deliver_manual` tests busy before reason, and `poll` drains deferred work before handling Stop. Root changed the guard to `busy:false` plus its explicit reason in `8dce8dd5`: submit still refuses, queued manual work receives refusal, and Stop can settle. No Art subsystem source change was required. |
| **Gesture order and stale revision** | Root's brush union now sorts row-major indices before native submission. A backtracking path therefore satisfies the existing executor/history ordering contract. The gesture records plane, generation and authored revision; release refuses after an intervening same-plane edit. Boundary clipping is explicitly refused as a whole. |
| **Flatten and Art target ambiguity** | Both the Flatten button and direct request now use the explicit Play guard. Play-only Art admission uses the same guard. Hidden, locked or non-Play targets no longer silently receive those material/history actions. |
| **Same-event-batch coordinate cache** | Presenter conversion previously relied on a prior process callback. Pan/zoom/resize followed immediately by input could read an older view. B's `bc03f2f4` refreshes the existing host view at coordinate entry points. C was asked for a camera change followed by native paint and a framebuffer check without an intervening explicit `sync_view`, including display scale 1.25. |
| **Qualification gaps** | Round trips alone can share the same wrong transform. A changed pixel alone can still pass with double multiplication. C is adding an independently located transformed paint sample, raw opaque surface-to-framebuffer comparison at haze 0/opacity 1, explicit Play pixel exclusion, and untouched reference-scene captures. |

Framebuffer sampling also needed the root viewport stretch transform: the
original captures are 1600×900 pixels, while the logical content rectangle is
larger. C corrected its helper to apply that transform before indexing PNG
pixels. Its new actual viewport-input, panel-control and visibility fixtures
were read for obvious source-level fixture errors; this does not replace running
them. Requested viewport dimensions must remain distinct from measured images.

The reviewed lifecycle keeps one ordinary play owner. Decorative preparation
stages all three native Worlds, copied initial packets, texture resources and
the host material before ordinary play admission. Root now checks presentation
mount before committing the decorative token, and releases candidate resources
on refusal. Save routes through the layered envelope even with presentation off;
ordinary nonlayered replacement clears decorative ownership only after positive
admission. Material-history Flatten does not collapse planes.

## Native scene appearance review

The actual composites show clean native material pixels and straight-on side
elevation. Industrial hazard-striped platforms and arcology cyan platform edges
remain legible against the rear machinery/buildings. Cavern Play-only inspection
shows a recognizably irregular ceiling/floor and generous traversable voids;
its pipework and suspended room read as separate industrial decoration. The
ordinary toolbar and edit-target label are readable in these 1600×900 captures.

These captures were taken after the qualifier changed haze/parallax and made
test edits. They establish that actual native four-plane content draws, but they
do not fairly evaluate the authored scene defaults. No geometry tuning was
performed from them. C is supplying untouched reference composites and an actual
mounted panel image before further visual decisions. Physical Windows/NVIDIA
appearance and interaction remain an owner gate.

Original background-only evidence exposing the Play visibility defect:

| Scene | Original PNG SHA-256 |
| --- | --- |
| Industrial assembly | `41da6cfe3e20906dc8d12ddecbb3b0986ab07eef515694800c146dbb21fdbbba` |
| Arcology | `a158a9215d2f7749cf3e0cd7b108e8e46f8b0c8ee51bb0036bceadd9c2b44ab7` |
| Cavern | `fee1e9d3d09713c3d68b212c0a4d1face6936b4cd5e921a5cfdd34896d59807e` |

## Corrected Linux visual follow-up

The second hosted Linux campaign is bound to commit
`99d3d9ef8cbf112e13979e6d64ed3113b4ec55fc`, tree
`21d47b1ca2210ad61cfeac8997019586f8e0d639`. Root supplied GitHub artifact
`14948514050`; I independently hashed its unchanged local archive
`/tmp/strata-campaign2-linux.zip` (72,393,018 bytes):
`8b8ddb33b47c8b3b1c34592b187cde4461415021704b208a077a4bfa5285c91c`.
The reports identify official Godot `4.7.stable.official.5b4e0cb0f`, executable
SHA-256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`,
X11, Compatibility rendering, and llvmpipe (LLVM 20.1.2, 256 bits).

I visually inspected each untouched `reference-composite.png`, the mounted
industrial `strata-panel.png`, industrial background Solo and Flat, arcology
hidden Play, cavern Flat background, and industrial half opacity. I also read
all three install/reopen reports and verified their hashes and the reviewed PNG
hashes against the campaign evidence manifest. These are actual native Godot
captures; they were not reconstructed or retouched.

| Untouched reference | SHA-256 |
| --- | --- |
| Industrial assembly | `6b8d7b717dc582d3c690a55c48c9c8bd3c32ff6c7ad46f2ca45b6be5570a7c45` |
| Arcology | `034b7b5a7a41d637d19630d5555f8d2d33ec281b4bc6379e7a5d285599e0a08f` |
| Cavern | `a3b565ece958c2ec4c732f32ac0f638c3710c4c2d59e7a3f9263c94c9c1f0546` |

The untouched references preserve clean side-elevation material pixels.
Industrial hazard strips distinguish the traversable foreground from the rear
crane, tanks and distant city. Arcology's bright cyan platform edges identify
the Play routes against finer rear lift spines, skybridges and building windows.
The cavern combines an irregular ceiling/floor, separate mineral ribs,
suspended infrastructure and sparse mist without covering the main open space.
These authored defaults are calmer than the earlier qualifier-mutated frames;
no visual tuning is necessary to proceed to owner evaluation. The actor label
is visible in each complete composition.

The corrected industrial background Solo and Flat images contain only the
background skyline: the foreground floor, hazard platforms, rear machinery
and pilot label are absent. Arcology hidden Play removes the bright foreground
cyan routes and floor while retaining rear lights and structures. Cavern Flat
background removes Play platforms, water basins and the pilot, leaving its
distant mineral surfaces. This closes the specific visible defect found in the
first campaign's images, within this Linux rendering environment.

As an additional check independent of C's in-process sample code, I read the
unchanged industrial PNGs directly at the temporary marker and halo pixels:

| Captured state | Marker RGB at (906, 370) | Halo RGB at (944, 370) |
| --- | --- | --- |
| Background-only baseline | (4, 7, 11) | (4, 7, 11) |
| Play Solo | (116, 119, 124) | (6, 46, 44) |
| Background Solo | (4, 7, 11) | (4, 7, 11) |
| Flat background | (4, 7, 11) | (4, 7, 11) |
| Play hidden | (4, 7, 11) | (4, 7, 11) |
| Play opacity 0 | (4, 7, 11) | (4, 7, 11) |
| Play opacity 0.5 | (60, 63, 68) | (5, 26, 28) |
| Play opacity 1 | (116, 119, 124) | (6, 49, 46) |
| Layering disabled | (116, 119, 124) | (9, 52, 52) |

These are image pixel coordinates, not a replacement coordinate transform test.
The ordinary glow is animated, so its nonzero values need not be identical in
successive captures. Exclusion returns the actual sampled halo to its baseline;
half opacity has an intermediate contribution. C's three scene reports each
record 880 install checks and 162 fresh-process reopen checks, no failures,
native material-77 glow exclusion, intermediate half opacity, and exact original
host material restoration. Each also records an independently located immediate
pan/zoom input at display scale 1.25: inverse error 0, native material 131, and
raw source-to-framebuffer colour error approximately 0.000437. These results
address the earlier shared-transform and double-multiplication gaps.

The actual mounted panel capture is 600×467 pixels after display scaling. Its
edit-target, visibility/lock/Solo controls, opacity/depth/parallax/haze sliders,
static 0 Hz policy and history controls are readable. The first visible page
ends inside the policy paragraph and has an obvious vertical scrollbar. Root's
owner guide now explicitly directs the user to scroll down to the complete
example selector and close or move the panel before painting. Panel tests use
actual Godot control signals; they do not establish physical mouse interaction.

A's separate native-layout inspection found that the industrial lower hall is a
substantial enclosed flight space, with a clear source-authored Midge box sweep
from x64 to x960 at y624 and a central rise to y418. Its upper/exterior regions
are separate. This supports keeping the current geometry, but remains a static
clearance result, not a claim of actual flown traversal.

The overall second campaign still **failed**: its maximum-extent runner raised
`FileExistsError` for the already created maximum directory before launching
that case. The scene install/reopen successes must not be promoted to an overall
platform pass. Root's subsequent `d95f9ceaa77ff444d8ff85ce9b90a1173edb7989`
changes only that harness directory handling; its complete campaign is pending
at this review cutoff. The three scene bytes remain unchanged.

## Corrected hosted Windows follow-up

Root supplied Windows artifact `14949891238` for the same `99d3d9ef` commit and
`21d47b1c` tree. I independently verified the unchanged local archive
`/tmp/strata-campaign2-windows.zip` (61,981,224 bytes), SHA-256
`4216516e92cc0287cac7ed38a022f96de4ef538cae783a26ee7e70c75c265a5d`.
The official Godot 4.7 console executable is identified by SHA-256
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`.
The actual adapter is **ANGLE / Microsoft Basic Render Driver / Direct3D 11**,
with the Windows display server and Compatibility renderer. It is not physical
NVIDIA evidence.

I visually compared the Windows arcology untouched reference with the Linux
reference. The platforms, skyline, fine lift structures, pilot and material
edges retain their layout and readability; no platform-specific visual blocker
was apparent. Its Windows Flat-background capture contains only the distant
skyline, with Play routes, glow, rear structures and actor absent. Both actual
images are 1600×900 pixels. Verified hashes are:

| Windows PNG | SHA-256 |
| --- | --- |
| `arcology/reference-composite.png` | `b434e138c3059eef58d61069dd81e79225444dcd56389b83b6f02043ad5ca9a8` |
| `arcology/visibility-flat-background.png` | `91d974e7a5ba5cc26fe0f0190f1c399640300c89f5dfa0987b7d7d61c9fef5c6` |

Direct Windows industrial PNG sampling at the same image coordinates gives
marker RGB (116,119,125) in Play Solo/opaque/disabled, (5,7,12) in background
Solo/Flat, hidden Play and opacity 0, and (60,63,68) at opacity 0.5. The halo
returns to its Windows baseline (5,7,12) in every excluded state; visible Solo
is (6,48,45) and half opacity (5,28,29). Small cross-platform colour differences
do not affect the exclusion result. All three Windows install reports contain
880 checks, their fresh-process reopen reports 162, and no failures. As on Linux,
the overall campaign is still failed because maximum-extent directory creation
raised an already-exists error before that case launched.

## Completed d95 Linux campaign visual check

The complete Linux campaign for application candidate
`d95f9ceaa77ff444d8ff85ce9b90a1173edb7989`, tree
`c38460e875ee7ca6b2a07b13ea4f05c04ffa3481`, now reports **passed**. I verified
artifact `14951246003` through its unchanged local archive
`/tmp/strata-campaign3-linux.zip` (75,534,780 bytes), SHA-256
`72fddc0c23272c41ace196ba551548a59418c9eda379f3816fdd3b03122a069f`.
The source delta from the earlier candidate is one maximum-runner directory
handling line; application and scene sources are unchanged.

I visually inspected all three untouched reference composites at this source and found
no regression in layer layout, route/pilot readability or material pixels.
Their verified PNG hashes are:

| d95 Linux reference | SHA-256 |
| --- | --- |
| Industrial assembly | `c5d1bf77d78bdb1536fb1683760dfcffce2d1837a41c9575836170acc5e7802b` |
| Arcology | `d40deb778d9f8d0f95196179d9b725d4a4e8d9e09243186d018e5374e1b7ac0b` |
| Cavern | `3895c355ef28ae9308f681c3f8b0448439661698ca0e186f15c2e8cf5f7bbe7c` |

All three panel PNGs are byte-for-byte identical to the previously reviewed
Linux panel images. Each scene again reports 880 install checks and 162 reopen
checks with no failures. A independently reviews the maximum-extent case and C
owns the full campaign custody audit. I have not re-rendered or modified any
evidence image.

## Package admission repair review

The complete Windows report for the same d95 candidate also records `passed`
and passed input custody; the independently read original qualification JSON
has SHA-256 `94b7f2c12ddc6d2651a789a996a1ce686318043f421238c7a3c8ad932ee9d59e`.
The subsequent package gate failed before producing its ZIP because its profile
verifier classified nested architectural styles and schemas as canonical
generator recipes. The established stager copies only direct
`examples/worldgen/*.json` files.

I independently reviewed C's repair
`98fa74a8dc2e21e49cec67c5a7208765086cd725`. Its exact-parent filter aligns profile
admission with that existing stager. The preceding complete archived-source
subset requirement and per-file payload hashes are unchanged, so nested styles
and schemas remain shipped and required. I inspected the preserved original
failing reproduction and independently ran the focused `ArchivedGeneratorProfiles`
test against the actual committed source archive. It passed, including missing
profile-record, missing canonical-copy and tampered-copy negative cases.

The generated evaluator README now explicitly directs the owner to scroll,
choose an example, press **Load selected example…**, and move or close the panel
while painting. That matches the actual reviewed panel. No product script,
material source, scene or native binary changed in this repair. The newly
source-bound full campaigns and actual pristine package launch remain required;
this focused verifier test does not establish that they passed.

## Final application and owner-image delivery review

Both complete source campaigns now pass at application commit
`d365f78190af0e006ee9998a17b453f04f31b3ae`, tree
`4e2e44513355c6f976d6b672d5dc958f20331add`, workflow `45457176340`. I read the
original Linux and Windows qualification records, confirmed their source/tree,
passed input custody and platform status, and checked all six scene install
reports (880 checks each) and six fresh reopen reports (162 checks each): their
failure arrays are empty. I independently hashed both original archives:

| Source campaign archive | SHA-256 |
| --- | --- |
| Linux, artifact `14952301125` | `e534c6091a6c430925b2b9afdf2afa3f5c3d752edec75fc1a8ae7a641bd9e5aa` |
| Windows | `c62e0ca647308873967d76e0ef7f7f95a2c1e9af4cf91d30419a34ff6b611ca8` |

I visually inspected all three delivered Linux reference PNGs and the final
Windows arcology reference. The same distinct scene silhouettes, readable Play
routes, pilot and crisp native material edges remain present, without an
observed visual regression. This is actual software-rendered native evidence;
it does not settle the owner's physical appearance/performance judgment.

The staged owner images under
`/workspace/scratch/f1ade3e61398/deliverables/` are byte-for-byte equal to their
original admitted Linux PNGs. Their complete byte lengths and hashes also match
`CyberSand-Strata-Native-Scene-Images.json` and the source campaign's original
evidence manifest:

| Owner image | Bytes | SHA-256 |
| --- | ---: | --- |
| `CyberSand-Strata-Industrial-Assembly.png` | 975,588 | `b7e2a5f63117eea92db5e36ab88cb63e0bfb980f144ffb1b701339cbfcfd21f3` |
| `CyberSand-Strata-Arcology.png` | 1,162,249 | `26d3defc438ab59e0d3bdc78682624ca04958df9552836cdf1b2d4bfbf55f45d` |
| `CyberSand-Strata-Organic-Industrial-Cavern.png` | 1,207,649 | `81b3c39db8fe83ce3fefdd6a47a09785ab41c97b8328a45045725fe99d3e596b` |
| `CyberSand-Strata-Authoring-Panel.png` | 96,358 | `b81c177fe36825ed025dd07ab10b1aa639a5ea7ef5597bdba542fd0d2063a430` |

The image manifest's SHA-256 is
`f6b08b68c9b5de98a8dc595d96fdefab62633d5a9dad0bad81cd78a30aae012b`.
The references are 1600×900; the panel is 600×467 and byte-identical to the
previously reviewed panel. The manifest correctly distinguishes untouched scene
defaults from the panel's control-test settings. The final Windows arcology PNG
hash is `08cb692c6671bb8868557a42823a3d2acfe34976187cda00a2b2a5f80d248f96`.
No image was regenerated, retouched or resized for delivery.

## Final portable owner-handoff review

The portable evaluator is now concrete and reviewable:
`CyberSand-Strata-Workbench-Windows-d365f78190af.zip`, 204,378,995 bytes,
SHA-256 `344ff7de0caf120096baa377967585918fd985fd9d35ad7b7620e1c6c9b03a71`.
I recomputed that digest and matched the adjacent checksum file. The adjacent
manifest is byte-identical to the ZIP's `evaluation-manifest.json`; its SHA-256
is `0b6f88603afa07b6a44f713ab8ac06887db4ad34c91d0e6c153f5a18c01594a8`.
It declares 1,359 payload entries, plus the manifest itself in the 1,360-entry
archive, the exact d365 source/tree, official Godot 4.7, both qualification
platforms and `draft_hold: true`. C independently owns complete payload custody;
my review read selected archive members without extracting another engine.

The exact shipped README now gives a usable sequence: extract the whole ZIP to
a writable folder, run **Open Workbench.cmd**, open **Strata Theatre**, scroll to
the example selector, choose and load the example, then move or close the panel
for editing. It covers visibility/lock, selected-plane history, toggling during
ordinary actor play, named save and fresh-process reopen. Its static decorative
World, authored-layout persistence and physical-owner limitations match the
implemented controls. `OWNER-EVALUATION.md` provides fields for GPU/driver,
scaling, scene observations and a HOLD/request-changes/later-merge-review decision.

The three source scene files are present. I verified each byte-for-byte against
`git show d365f78190af0e006ee9998a17b453f04f31b3ae:<path>` and against the payload
manifest:

| Shipped native scene | SHA-256 |
| --- | --- |
| `godot/data/strata/industrial-assembly.json` | `b803b1e3804e0f1538cb5493b9eca209b06d58f058ff0b56ac95187ff0adc220` |
| `godot/data/strata/arcology.json` | `82f5c7d62ac85144559d1ba884c922cf0bab018c2613ced1e11529d49b0f9569` |
| `godot/data/strata/cavern.json` | `ec22baeaa08952031259d2890e494d8e4d430fd3d79990ad7f9d082259975d59` |

All four staged owner PNGs remain byte-identical to both the image ledger and
the corresponding original PNG members inside the delivered evaluator's Linux
qualification folder. The ledger hash remains
`f6b08b68c9b5de98a8dc595d96fdefab62633d5a9dad0bad81cd78a30aae012b`.
The archive also retains native reference and panel captures for all three
scenes on each platform.

The actual shipped CMD (SHA-256
`605b83bc7e2bc6eb39369a82026fd14172107ce1380a8835a90367b0fe7869fb`)
uses the bundled official engine, a quoted local project path and package-local
userdata. Its headless phase is the import preflight; the subsequent application
phase opens ordinary Workbench graphically through `-- --workbench`. The packaged
project itself defaults to Compatibility rendering. It does not select the old
standalone depth host or activate Strata by default.

I read the actual launcher receipt, stdout and stderr from the pristine directory
`D:\a\_temp\strata owner package`. The receipt's SHA-256 is
`2095d31dc1cbad1a00b3f07704e5202b1fe84032c1e658995d0233cbd18668cc`.
It records the shipped CMD, exit code 0 and ordinary 2048×2048 Workbench
admission at the exact d365 source, with `strata_enabled: false`, native worker
`-9223371959830575630` and World generation 2. I parsed the original stdout
admission marker and confirmed it exactly matches the receipt. This proves the
normal launcher reached native admission; it is not a substitute for the
separate layered interaction campaign or physical owner interaction.

The extracted Windows campaign also reports passed source/input custody, all
three 880-check install and 162-check reopen cases with empty failures, and the
82-check maximum-extent case. Its original report SHA-256 is
`7eb196d6e64227f486f151185b2a1a24580361f304f11806994d85b63abfdbd8`.
A separately reviews that extracted lifecycle evidence. The launcher log retains
the expected unsupported-OpenGL warning and actual fallback to ANGLE/Microsoft
Basic Render Driver. The launched process is hosted software rendering, with
audio/rendering/exit arguments supplied by the automated launch check; it does
not establish physical Windows 11/NVIDIA appearance, input feel or GPU pacing.

No remaining owner-handoff blocker was found in this scoped review. The original
negative campaigns and all later repairs remain part of the evidence trail.

I also independently reviewed the completed owner guide and decision packet
after their final evaluator, cost and qualification sections were populated.
Their Play/persistence statements match the implemented boundaries: view
changes retain the active World and actors; a deliberate new/load replaces an
authored scene; Save retains authored layouts rather than evolved simulation;
Flatten remains explicit and Play-only; Undo stacks are not serialized. The
scene text qualifies static clearance separately from actual actor progression
and does not promise every chamber or every actor can traverse the examples.

The final wording retains measured hosted wait-budget overruns, the paused
scope of the 2048² probe, control-signal versus physical-input limits and the
remaining physical Windows 11/NVIDIA gate. The verified package steps include
the actual scroll/Load/panel workflow. I found no owner-facing overstatement
requiring another application or delivery change.

## Remaining qualification boundary

Keep Draft/HOLD for owner evaluation. Both complete final-application source
campaigns, the pristine extracted campaign, the actual ordinary CMD admission
and the delivered reference images have source-bound evidence. Physical
Windows 11/NVIDIA appearance, interaction and performance remain a distinct owner
gate. The canonical matrix also retains the distinction between executed failure
cases and staged Play-ACK/partial-edit/publication faults reviewed only in source.
No merge, Ready promotion, default activation or native runtime publication is
implied by this review. B's own presentation implementation remains independently
reviewed by A and graphically qualified by C, as stated at the beginning.

Hide/show currently permits one bounded static-surface rebake; it creates no
recurring native snapshots or uploads. A proposed cache optimization was
deliberately deferred until the graphical campaign completes. Callback timing,
tracked Godot memory and software-renderer frame intervals must retain their
labels and must not be reported as physical GPU FPS.

Local graphical attempts killed by signal 9 remain original environment
interruptions, including `/tmp/strata-visuals/capture.log` and
`/tmp/strata-visuals/interruption.json`. They did not reach a framebuffer and are
neither semantic passes nor established OOM diagnoses. No local native process
was restarted during this review.
