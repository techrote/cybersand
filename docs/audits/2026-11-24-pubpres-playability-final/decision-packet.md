# PUBPRES physical progression decision packet

Status: **Draft/HOLD; active qualification, no selected final runtime yet.**
This record belongs to [the successor handover](../../operations/pubpres-playability-final-001.md)
and [Draft #767](https://github.com/techrote/cybersand/pull/767). It retains negative
results and distinguishes executed evidence from prospective work.

## What the recovered evidence establishes

The [independent historical reconstruction](historical-evidence.md) binds original
archives, runtime receipts and raw physical traces. The completed 22-job run
`45078090513` is an evidence-capture result, not a physical acceptance result.

| Question | Recovered answer | Consequence for this mission |
| --- | --- | --- |
| Did frozen #757 improve Windows current-Wave2048 over accepted main? | About 29–31% more real completed steps, with severe tails remaining. | Preserve the gain as the control; do not call the workload playable. |
| Did Wave512 also improve? | No; both candidate rates were below both main rates, with a worse maximum physical gap. | Wave512 remains a primary acceptance workload. |
| Did fast target-publication calls solve progression? | No; roughly two orders of magnitude less submission-call time did not establish better complete-gameplay progression. | Do not repeat the same target experiment as a new optimization. |
| Did Combined publication resolve the small-canvas delay? | No; the corrected Early/Combined/Combined/Early evidence is a valid negative. | Preserve original red capture and detached reducer audit separately. |
| Is Rapier computation alone the small-canvas bottleneck? | Native ticks were roughly 3.3 ms and solver p95 below 1 ms, while native-completion-to-physics p95 approached 270 ms. | Investigate admission opportunity and Main/render scheduling, not solver-only optimization. |
| Can a stale terrain revision license more physics? | No. Exact body-sample occupancy, coupling and consecutive geometry history are also required. | No fabricated callback credit or stale-sample physics. |
| Is Windows Separate startup failure a newly discovered NVIDIA defect? | No. A previously qualified #609 EGL release-cache repair exists. | Recover its exact custody and isolate it; hosted software rendering does not qualify NVIDIA. |
| Does the recovered EGL repair make ordinary Separate Workbench usable? | No. In run 45436083078 it initialized ANGLE and passed the small image-history oracle, but all four ordinary timed starts aborted in an empty `CowData` byte buffer. | Retain this later failure; test a separately identified font-atlas Image ownership repair before timing. |

## Causal architecture

The native World has one authoritative worker owner. A completed turn prepares
material publication and exact physical dependencies. Main consumes the early
physical mailbox only when World identity, sample serial, required terrain and
health permit a real Rapier callback to complete. The completed actor state then
supplies the next native body sample. This feedback loop intentionally prevents
physics from moving against invalid material/actor occupancy.

Material delivery already uses a bounded latest-snapshot mailbox. Unacknowledged
patches accumulate in order with bounded recovery to a full plane. Main consumes
the newest packet and keeps the preceding actually uploaded image. An ACK means
the CPU publication was installed; it is neither a GPU fence nor a displayed-frame
timestamp. Native completion, physical admission, texture submission, draw
notification and physical scanout are therefore distinct events.

Godot 4.7 Main runs physics and idle callbacks and then synchronizes the previous
render before drawing again. Separate mode moves render ownership but retains
that rendezvous. In Separate, `frame_post_draw` is deferred back to Main, so its
timestamp includes notification delivery and its contemporaneous Main serial
cannot identify the image actually drawn. The
[source-bound renderer review](renderer-source-review.md) records these limits.

The dependency boundaries in this loop have different remedies. Their clocks
must not be collapsed into a single purported physics cost:

| Boundary | Authoritative operation and existing bound | What the evidence can establish |
| --- | --- | --- |
| Main to native admission | A copied body/equipment sample with session, epoch and serial enters the worker mutex-protected mailbox. | Admission-to-consume delay and actual sample identity; never permission to reuse a completed sample for another step. |
| Worker wake and World ownership | The sole World owner checks pending work during a bounded poll; completed-sample timer debt is rebased without authorizing another native tick. | Worker wake/lateness and mutex wait must be separated from the subsequent native calculation. Historical small-canvas delay is much larger than native execution alone. |
| Native material and coupling | One real material turn consumes the admitted occupancy/geometry, then captures its coupling result. | Exact native timestamps, conserved contents and the matching completed body sample. Occupied-mask bounds remove only provably zero probes. |
| Terrain dependency | The packet retains World identity and required hard revision; Main must install all required collider chunks before stepping. | A terrain wait is legitimate dependency work. Reusing an older hard revision or changing chunk budgets cannot silently grant physics credit. |
| Early physical publication | A bounded immutable mailbox becomes visible before material extraction/upload finishes; retirement cannot repopulate an old owner. | Publication and Main observation are distinct. The recovered Combined negative does not justify restoring delayed physical publication. |
| Main admission and Rapier | A real callback passes every owner/sample/terrain/health gate, applies native response, advances controls and performs one manual Rapier step. | Consecutive manual steps, body owners and actual completed poses independently witness progression. Solver time alone excludes the wait for a callback opportunity. |
| Material delivery | A bounded cumulative patch journal and latest mailbox preserve all changes until an actual accepted upload is acknowledged. The experimental deadline holds one immutable cumulative packet. | CPU upload/ACK and material freshness are measurable; neither proves a completed draw or physical scanout. |
| Render ownership and presentation | Safe executes on Main; Separate queues work but still rendezvous with the prior render. Selected overlay pose and Follow are read before submission. | Submitted-pose freshness is a separate witness. Deferred Separate post-draw notifications cannot borrow the current Main serial as their draw identity. |

These source boundaries are implemented in
[`simulation_worker.gd`](../../../godot/scripts/simulation_worker.gd),
[`main.gd`](../../../godot/scripts/main.gd) and
[`workbench_physics_bridge.gd`](../../../godot/scripts/workbench_physics_bridge.gd).
They explain why optimizing one producer can leave long physical gaps when its
consumer has no prompt Main-thread opportunity. They do not assign an unobserved
driver function as the cause of a particular retained stall.

## Competing implementation arms

| Arm | Bounded change | Required proof | Current decision |
| --- | --- | --- | --- |
| Occupied-mask bounds | Compute tight bounds once under the exclusive World owner; skip only obstacle probes outside actual occupied cells. | Exact material/physical/contact/conservation parity, changed-bound tests, sanitizers, matched ordinary gameplay. | Linux Wave2048 supports a relative gain in the second campaign; Wave512 does not. Actual large-canvas gaps still reach 150–270 ms. No broad playability acceptance. |
| Derived Empty storage certificate | Cache only proven Empty material with zero weight/meta in a complete chunk half; retain all original settle, flux, apply, dry/clean and paused-face work. | Actual-cell certificate assertions, complete lifecycle parity across independent sources/workers, normal/sanitized material tests, raw per-tick native controls and ordinary source comparisons. | Correctness passes locally. The 24-process native screen is invalid as a complete cohort because one control observed only three of four required workers; small/no-body adverse arms and large host drift remain retained. Explicitly unselected candidate for new ordinary hosted comparison. |
| Three Full-image slots | Add one persistent spare, update it before rotating current/previous, rebuild exact histories on structural refusal. | Actual current/previous GPU bytes, source/engine identity, fixed resources, all rotations, World changes and ACK ordering, matched physical comparisons. | Both platforms pass twelve correctness outcomes. Linux matched comparisons do not establish a gain. Original failed extent-check result and corrected independent replay remain separate. Default stays two. |
| Recovered EGL handoff | Clear the cached current window after releasing the EGL context so the receiving thread can bind it. | Original engine artifact/source/patch/API/dependency custody; real rendering-owner observation; exact image histories; isolated stock-Safe/patched-Safe/patched-Separate comparison. | EGL initialization is repaired; ordinary Separate starts still abort. Safe controls do not establish a repeatable progression gain. This engine is not qualified for an ordinary Separate evaluator. |
| Private font-atlas Image publication | Preserve each glyph/alpha/mipmap operation, then give queued ImageTexture create/update a private Image instead of the still-mutable atlas object. | Exact ten-site source patch, unchanged build/dependency/API gates, new binary identity, default non-mipmap font framebuffer parity, ordinary Workbench startup, then same-executable Safe/Separate controls. | Windows build/API/provenance passed. Original renderer qualification stopped before launching because the patch reader rejected equivalent Git context alignment; independent exact source replay and corrected-reader tests pass. New actual font/startup/owner execution remains required. This arm changes ownership, not Main/render synchronization. |
| Bounded material deadlines | Default-off 30/60 Hz presentation admission holds one immutable cumulative packet, never extends a pending deadline, and ACKs only actual accepted uploads. | Independent cumulative current/previous bytes, no skipped-packet ACKs, World/session/epoch/failure cancellation, unchanged real-step authority, matched zero/30/60 controls and freshness costs. | Policy and actual Main identity preflight pass; independent 22-boundary/8-history oracle implemented. Graphical and timing execution pending. It cannot reduce publication frequency when other Main/render work already exceeds its interval. |
| Stale-sample continuation | Additional physics without a current native body sample. | A valid collision/coupling/geometry certificate that the current protocol does not provide. | Rejected for this implementation; no admission gate changed. |
| Another latest-only transport queue | Duplicate existing bounded mailbox behavior. | A distinct retained-work or backpressure defect. | Existing source already coalesces pending delivery; no new queue is justified. |

The three-slot allocation is exactly one additional logical material plane: 8 MiB
for RG8 at 2048², 4 MiB at 2048×1024, and 512 KiB at 512². These are declared
uncompressed texture bytes, not measured GPU allocation or residency. One extra
reuse interval is not a completion fence. No default or acceptance gate is changed
because an upload call returns quickly.

## Independent controls and remaining qualification

The [prospective registration](../../../tools/pubpres_final/registration.json)
keeps the original V3 actual-step, native, terrain, input, actor, Water and GPU
checks. Source D/C/C/D uses independent frozen/candidate builds with identical
toolchain/dependency identities. Slot 2/3/3/2 uses one source/runtime. Both run
serially on an owned host, retain every arm and preserve the strict directional
rule. A complete capture can be a negative performance result.

The [native receipts](native-abba-receipts.json),
[reduction](native-abba-reduction.json) and
[independent challenge](native-independent-review.json) retain all 24 local arms.
They contain exact state/contact checkpoints and reported aggregate timings, but
not a per-tick timing array; the reviewer cannot independently recompute those
quantiles. They are native causal evidence, not ordinary Rapier qualification.
The original adverse 512² tail, mixed zero-body control and mixed eight-body
timings remain part of the decision.

First hosted source is `b21dca8fd6bd30bed9c19ce84601f85050405bed`, tree
`ab5493df827a7c2bef273b4bfc4132345cd6d291`, run
[45430704276](https://github.com/techrote/cybersand/actions/runs/45430704276).
This is a development capture. Final sanitizer, sustained/mixed workload,
extracted Windows evaluator, complete artifact manifest and physical Windows/
NVIDIA owner acceptance remain open. Subsequent source identities and original
results must be added here before any final performance decision.

The first run's two graphical jobs each completed all twelve original processes
without a process failure or source mutation. The transition checker then
incorrectly rejected signed RefCounted ObjectIDs. The source-domain correction
and independent replay are retained in [the replay audit](object-id-replay.md).
They do not retroactively mark the original failed workflow green, and no timed
physical arm was executed by that run.

Second hosted source is `515fce2862dd87d8dd01935bdf7bd1736e645901`, tree
`1acd4bb5c4f067e7d54fe731ffe12a48a6fa9fff`, run
[45436083078](https://github.com/techrote/cybersand/actions/runs/45436083078).
Its independent Linux and Windows native builds and all hosted jobs have
completed. The original workflow remains red. Both platforms passed all twelve
correctness processes and completed their source/slot captures; the added slot
allocation checker rejected generated fixtures without an observed `extent`.
The [independent decision packet](development02-independent-decision.md) retains
all sixteen Linux and sixteen Windows raw reductions, plus the eight valid
Windows Safe engine controls. Complete frozen-gate replays pass all sixteen
source/slot captures on each platform. The
[Windows custody audit](development02-windows-frozen-replay.json) and
[independent peer check](development02-windows-replay-peer-check.json) bind actual
GUI/Rapier/native bytes, all source inputs and original traces; the original
failed workflows remain unchanged. The
[renderer/evaluator audit](second-campaign-renderer-and-evaluator.md)
retains the separate ordinary Separate crash, ten successful other evaluator
launches and successful native authoring/Save/reopen. Collector execution was
not reached, so that original evaluator is not qualified. Its
committed application/native source bytes match the first checkpoint; source differences are
measurement correction, packaging, orchestration and evidence. The later
deadline and eight-actor work is not part of this second source identity.

The second runtime archives were independently downloaded, SHA-256/ZIP-CRC
checked and verified against all 105 committed native inputs, build logs,
compiler pins and godot-cpp dependency/driver custody. Linux binaries reproduce
the first checkpoint exactly. Windows binaries retain distinct actual hashes:
the frozen control is `a0d0097fe3a66a85cc75bfdbde0f63e8defd1ad1b795ae85a787df51ca06e047`
and candidate is `c571e40334d65fb2828f1db772779455061a4a1bbcf73a9d62be997c24a0b3d7`.
The [PE comparison](windows-runtime-repeatability.json) accounts for all fourteen
changed bytes per DLL in the temporary export-module basename and CodeView GUID;
executable text bytes are identical. No artifact is normalized or reattested.

The Windows graphical raw reader subsequently passed all sixteen physical
captures. Its current-Wave2048 source D/C/C/D rates were
3.604/3.716/3.734/3.861 real steps/s, so it does not reproduce the Linux source
gain. Its three-slot Wave512 rates were 9.080/9.065 versus two-slot
13.602/13.765, with maxima 700.931/709.374 ms versus 248.089/248.607 ms.
Large three-slot arms were also adverse. The
[prospective retirement record](../../../tools/pubpres_final/retired_experiments.json)
therefore removes repeated slot timing and sustained-three-slot campaigns while
retaining every correctness/ownership/allocation gate and all negative evidence.
All ordinary source, sustained, mixed, deadline and engine-owner comparisons use
Full2. This retirement changes no original registration or failed outcome.
The graphical job used AMD EPYC 9V74, whereas the separate engine-isolation job
used EPYC 9V45; their absolute rates are not a matched cross-job engine comparison.

The [new native certificate proof](native-empty-derived.md),
[raw 24-process receipt](native-empty-derived-abba-receipts.json) and
[adverse/invalid screen](native-empty-derived-screen.json) retain the next native
arm before any final choice. All material/state/content/contact/Water/parcel
checkpoints agree, and its full diagnostic Wave/spill/body-boundary checks pass.
Large-canvas mean improvements in that screen are descriptive only: control
drift and small/no-body regressions prevent a broad performance decision.

The [new mixed-workload registration](mixed-workload-registration.md) exercises
eight independently owned actors, active current-profile Wave, Follow, four
ordinary paint/erase actions and actual passive contact on 512² and 1024² for at
least 60 seconds and 144 genuine steps. It is additive workload qualification.
Asynchronous native paint admission is retained as a control limitation, not
treated as an equal material timeline for a performance comparison. Every
bounded material-probe attempt contributes to measured observer elapsed time.

The [deadline implementation](material-deadline-implementation.md),
[independent byte/authority review](deadline-independent-review.md) and
[integrated preflight receipt](material-deadline-independent-preflight.json)
separate source/authority correctness from graphical, physical and timing
acceptance. The integrated preflight has no display and is explicitly not a
new complete-source runtime attestation or a GPU result.

The next campaign adds an explicit off/on/on/off observer calibration before
instrumented comparisons. It measures selected submitted-pose/material freshness
and sampled whole-process CPU cost without granting any physical credit. CPU
sampling covers startup and capture together; it is not mislabeled as a
Godot-clock-aligned capture-only cost. Calibration is an evidence-validity gate,
not an invented acceptable-overhead threshold. Mixed eight-actor qualification
and off/30/60/60/30/off deadline controls retain all original physical gates.

A new stock-engine evaluator is assembled separately so its complete included
launcher, authoring, reopen and collector sequence can run. The original failed
package remains retained. Omitting its optional research engine does not pass
or reinterpret any failed Separate requirement. The new font engine remains a
separate research artifact until its own exact runtime and gameplay gates pass.

The integrated preflight for this next source passes 49 final-driver tests,
16 new-engine tests, 11 presentation/resource observer tests and 14 package
tests. The 99-file new engine-owner driver closure is committed and verified.
These are local apparatus/source results, not replacement graphical or runtime
qualification. Both source-comparison and evaluator startup evidence explicitly
observe deadline-off state; frozen donor API absence is recorded as null rather
than fabricated policy telemetry.

## Third hosted source and runtime custody

[Run 45452580606](https://github.com/techrote/cybersand/actions/runs/45452580606)
executes candidate `c2f8a73d34448bc1496ecd84bca02f0812c80d27`, tree
`351b947a50ce054361660eba9379006122527547`. Its request fingerprint is
`ca17f9d85980d94cff08fbe8b509f9f863a515ee8fd48de21fda5f7aa0348eab`.
The registration phase `final` selects the expanded qualification workload; it
does not grant final acceptance or select this candidate.

Both native build jobs passed. The
[independent runtime inventory](final03-native-runtime-inventory.json) verifies
all 105 committed native inputs for each of the four binaries, source trees,
build drivers/logs, exact compiler pins and godot-cpp dependency custody.
Control and candidate share identical toolchain identities within each platform;
their dependency builder is this exact candidate source. No runtime is promoted.

| Platform / role | Actual binary SHA-256 |
| --- | --- |
| Linux frozen control D | `bc5cdbf4832d09f8b14f6ff2ed7cf1e182343d55a3a4ebc4dc1d93894d660d59` |
| Linux candidate C | `33d9c39ecfca71c800f538dbf3edbbb85675c0c65be35d6af525f699b7d15dc0` |
| Windows frozen control D | `505c766c6003b9d7c1e3acdee9331527210ba09a149a1588de32bf877ee3bb40` |
| Windows candidate C | `1cdcbf4f72204d79b22d1a9551e46f9ccf02f6785d3141503e90e27feda28f1b` |

At this custody checkpoint, Linux graphical execution, full native normal/scoped
ASan/UBSan and the extracted stock Windows evaluator passed. Windows graphical
comparisons are still active. The [native/evaluator record](final03-evaluator-and-native.md)
contains the exact original manifest, all-member/source verification and a
separate raw-process/collector/persistence peer review. Nine hosted launches and
the actual collector passed; physical NVIDIA and normal native OpenGL remain
unperformed. Startup receipts and screenshots do not establish gameplay timing.

The custom Godot build also passed, but its renderer qualification failed before
any process because the proof reader treated equivalent Git brace-context
alignment as an undeclared edit. The
[reader correction](font-engine-patch-reader.md) and
[independent peer review](font-engine-reader-independent-peer-review.json)
retain that original failure, verify all eleven exact edits and independently
reproduce every declared postimage from the original captured patch. The
[separate new-execution qualifier](../../../tools/pubpres_final_requalification/README.md)
pins the existing c2 application/native/engine and every new driver/observer
input. It changes only the explicitly registered application-to-driver join;
every original physical, font, startup, GPU and source/runtime gate remains.
No renderer or playability pass is inherited from build success.
