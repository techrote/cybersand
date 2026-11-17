---
title: Workbench physical freeze follow-up
status: Current
document-kind: audit
scope: Failed physical candidate, actual physics-progress evidence, collider scheduling correction and exact-source qualification limits
canonical-for: []
last-reviewed: 2026-11-16
related-documents: [2026-11-15-camera-stack-coherence.md, ../architecture/rendering-and-gameplay-bridges.md, ../operations/camera-stack-coherence-acceptance.md, ../operations/engine-lab-pose-tracing.md]
---

# Workbench physics freezes after the coherence delivery

## Disposition and source

**Physical FAIL/HOLD.** The owner rejected the delivered Windows application
`43f46c6e5ec9dbebbc6f80d4aeeeea3a728b0ba1`: Rapier/actors repeatedly freeze for
approximately 100–1000 ms and gameplay is unplayable. This supersedes the earlier
"ready for physical evaluation" disposition. Neither the earlier hosted green
results nor this follow-up establish physical NVIDIA acceptance.

The failed ZIP is `CyberSand-Coherence-Windows-43f46c6e5ec9.zip`, 92,546,536 bytes,
SHA-256 `c51d3cd96db24077f2a178a0132dd6f6b8352b7a36b5e0e6611b1fee1372358d`.
Its retained Actions campaign is `43766285219`. The current repair is a descendant
on the same Draft #609 branch, integrated with accepted main `018bd09503d7`.
No constituent PR is merged or promoted, and native source, timestep, material
law and stale-feedback admission rules are unchanged.

## What the evidence establishes

The principal six-pair Test It comparison used native-sample wait OFF and sample
wake OFF. The interactive launcher used both ON, native 60 Hz, default Rapier
60 callbacks, automatic or explicitly saved native workers, ordinary VSync and
the normal 1920×1080 window/view. Its scripted counterparts used a fresh profile,
one native worker, Rapier120, native30 or2, a 1600×900 window/240×135 view and
VSync OFF. Therefore the strongest prior flight comparison did not exercise
the actual interactive scheduling path.

The prior all-live/zero-rewind result describes visual pose selection only.
Independent re-reduction found actual completed-physics gaps in that same
successful campaign:

| Source/platform arm | Actual witness | Gate observations during gap | Next step's timed work |
| --- | --- | --- | --- |
| `43f46`, Windows WARP Follow60 coherent | steps377→378, 383.285 ms | 22 terrain-installation holds, three Main submissions/uploads | 1.056 ms |
| `43f46`, Linux software Follow60 coherent | steps763→764, 241.549 ms | 21 terrain-installation holds, three Main submissions/uploads | 0.790 ms |

These are genuine pauses in physical progression while the renderer continues
selecting the unchanged live state. They are not source rewinds. Some hosted
Windows step-work spans also exceed50 ms. That timer includes feedback admission,
controller work, Rapier stepping/flush/readback and session completion, and can
include OS descheduling. It is not an isolated Rapier CPU timer or an NVIDIA result.

The original private owner archive `20261115-172915-26552.zip` was reused rather
than requesting repeated evidence. Its TITAN RTX coupled-repaired arm contains
195 steps,1,009 native-sample holds and600 Main intervals,406 of which advance
no physics. The mean consecutive-step gap decomposes into1.279 ms before native
start,38.643 ms native World work,1.723 ms publication/handoff,9.110 ms callback
rendezvous and0.648 ms next-step work:51.403 ms total. Its maximum gap is68.105 ms.
No original owner arm has a100 ms completion gap, so that old archive does not
fully explain the new100–1000 ms report. No newer owner capture was accessible
at this follow-up. The original archive records Windows11/TITAN RTX and driver
`32.0.15.8180`, and a one-worker request, but no CPU identity or actual pool topology.

An actual default-handshake, headless2048² reproduction at failed source43f46
completed187 physical steps and185 native ticks in10.053 seconds while Main
submitted583 frames. It recorded379 native-sample holds and35 terrain holds.
Completion gaps were50.071 ms median,85.564 ms nearest-rank p95 and154.142 ms
maximum. Native ticks were27.09 ms median and43.64 ms p95; a terrain install call
took33.380 ms with922 of1,024 chunks still pending. The reproduction uses pinned
Godot4.7 and the original exact native World/Needle fixture, with Fire OFF.
This demonstrates a physical stall path without graphics, not complete causal
attribution of the owner's latest device behavior.

## Confirmed unnecessary work and repair

The bridge destroyed and recreated every rectangle shape in a changed64×64
terrain chunk. One retained84-packet comparison changed a median3/max6 of1,024
chunks, but destroyed a median64 shapes;56 of those shapes were geometrically
unchanged. Their RIDs, contact state and broadphase entries did not need replacement.

The correction matches exact rectangle multisets, retains attached unchanged
RIDs, removes only obsolete shapes in actual server-index order, and appends new
rectangles. Packet ordering and actual server shape ordering are separate arrays.
Fully equal completed packets avoid another scan; equal pending packets do not
restart progress. New packet bytes remain owned copies. Clearing an already
empty legacy full-terrain body is also avoided.

Independent review found an intermediate cache regression: installing part of
packet P, synchronously replacing the geometry with Q, then queueing P again
could preserve a cursor past the overwritten prefix and falsely certify P.
The synchronous replacement now cancels the pending packet, cursor and count.
The same actual-PhysicsServer manual-step test failed only the exact geometry
assertion before this correction and passes afterward. Ordinary equal-pending
publication still preserves its progress. Workbench does not use this alternate
installation sequence; it was a new shared-bridge defect, not an established
cause of the owner's freezes.

Main previously allowed terrain budget processing only once per rendered process
frame. A slow draw could therefore waste several real physics callbacks while
Rapier remained blocked. Each actual physics callback now may advance the existing
bounded installation. The128 changed-chunk/4,000 µs cooperative allowance remains;
one atomic chunk can overrun it. The complete required native revision still must
be installed before a physical step. Workbench already bypassed the worker's
general250 ms hard-packet throttle; that throttle is not the current cause and
was not changed.

**Design choice:** retain the coupled native response and strict one-step age,
geometry, generation and owner checks. Simply enabling the uncoupled diagnostic
would produce higher flight rates by refusing older feedback and would not
qualify material contact. This repair changes collider resource maintenance and
scheduling, not physical laws or timestep. It introduces no extrapolated actor
pose, smoothing offset or hidden animation while authoritative physics is held.

## Production counterexample and negative cases

`test_workbench_physics_pacing.gd` uses the actual Main callbacks, native World,
PAINT receipts, real Needle/barrel and Rapier space. It changes256 separate native
collider chunks while physics runs120 callbacks at30 rendered FPS. Unchanged
shapes must retain their RIDs, and each eligible physics callback must progress
pending terrain even without a new Main frame.

The final test passes919 checks in four phases on the corrective source. The
same test against exact43f46 fails exactly three targeted assertions: physics
installation waits for rendering, unchanged RIDs are replaced by the256-chunk
edit, and unchanged RIDs are replaced by a one-cell erase. Both source arms
pass independent actual PhysicsServer rectangle/RID attachment multisets, true
hard-terrain contact, default wait/wake behavior, native Ice/Fire hard changes,
and invalid/session/epoch/generation/aged native-response refusal checks.
No physical step is allowed against partially installed required terrain.

Two initial test construction failures are retained: an edit list was not in
required row-major order, and a Wood/Fire assertion incorrectly expected burn
completion within37 ticks despite the native240-count/two-tick burn schedule.
The final fixture uses row-major edits and an existing Ice/Fire thermal transition.
Neither fixture mistake was a product failure or a waived assertion.

## Timing qualification boundary

Native World work already exceeded16.7 ms in the failed-source2048² cohort, so
the coupled architecture cannot guarantee60 completed physical steps per second
there. An initial one-worker run was worse than Auto, and changing the worker
default is not the repair. The first candidate timing run retained raw hard
packets while the initial Auto control did not; that observer mismatch prevents
a controlled before/after throughput claim. Those runs and their raw records
remain retained.154 shared recorded physical steps nevertheless matched position,
angle and velocity exactly.

The sequential matching-observer Auto/Fire-OFF comparison disables raw packet
retention in both arms, uses the same original2048² fixture and native60/Rapier60
handshake, and retains every run. It measures the following in about10 seconds
per arm on headless Linux:

| Measurement | Exact43f46 control | Corrective candidate |
| --- | ---: | ---: |
| Completed physical steps | 182 | 214 |
| Main submissions | 592 | 597 |
| Terrain-installation hold callbacks | 46 | 7 |
| Terrain call p95 | 4.254 ms | 2.322 ms |
| Consecutive completed-event gap p95 | 80.121 ms | 61.496 ms |
| Maximum completed-event gap | 104.388 ms | 83.532 ms |
| Native tick median / p95 | 30.855 /40.504 ms | 28.394 /38.248 ms |
| Rapier solver call p95 | 4.457 ms | 4.882 ms |

All182 shared completed physical steps have identical recorded positions,
angles, velocities and native-feedback receipts. The181 common native ticks
have the same body sample and World revision. This is evidence of improved
terrain availability on this workload, with varying native timing and no solver
speedup claim. Coupled throughput remains about21 steps/s, well below60; the
native World cost remains the principal constraint. It is not a physical Windows
acceptance result or a guarantee that all reported freezes have been removed.

The matching Fire ON→OFF pair ran candidate then control, using the same
tick-addressed transition at completed step 60 and the same observer in both
arms. Auto resolved to four workers on this host:

| Measurement | Exact43f46 control | Corrective candidate |
| --- | ---: | ---: |
| Completed physical steps | 168 | 209 |
| Main submissions | 592 | 540 |
| Terrain-installation hold callbacks | 66 | 15 |
| Consecutive completed-event gap p95 | 83.341 ms | 68.278 ms |
| Maximum completed-event gap | 158.866 ms | 126.709 ms |
| Native tick p95 | 58.125 ms | 38.093 ms |

All 168 common completed steps match position, angle, velocity and native
feedback exactly. The 167 common native ticks match sample, revision and native
visited/moved/job counts. Native execution time nevertheless differs, so this
single sequential pair does not isolate the full throughput change to collider
maintenance. Both tables use completion-event timestamps; separately retained
observer callback-end gaps differ slightly and are not mixed into these rows.

The candidate Fire common prefix averages 47.760 ms per completed step:
27.119 ms native work, 16.999 ms between native completion and admission of the
next physics step (including callback rendezvous and terrain installation),
2.375 ms physics work and 1.266 ms publication/wake/preparation. It still does
not sustain interactive 60 Hz physics. A passing structural test or zero visual
holds must never be reported as proof that the owner freeze is resolved.

The largest observed `session.advance` span, 98.501 ms, occurs at the first
completed step, before the first native tick. Across seven retained probes,
every advance span above 10 ms is the first step only; the candidate Fire arm's
remaining 208 calls have a 6.589 ms maximum. The region includes sensor/ray,
controller and equipment work. Wall timers alone cannot separate backend
first-use work from CPU execution or descheduling, so this is not attributed
as the cause of recurrent owner freezes.

Native completion is also not the end of the handshake: the worker still
assembles required hard geometry and the render/snapshot publication before
handoff. Candidate Fire native-complete to handoff is 5.647 ms median, 13.116 ms
p95 and 22.585 ms maximum. Some of that work is required before the next physical
step. Removing its fence without separating the publication contracts would be
unsafe. Full image uploads also block Main callback opportunities; retained
examples at native ticks 1, 11 and 17 took 72.547, 54.202 and 39.672 ms. These
timers include possible descheduling and do not establish a GPU-driver cause.

## Integration failure retained

The first full local follow-up campaign completed all 30 production cases;
29 passed. The dense eight-actor fixture correctly failed four repeated-refresh
flicker assertions. Refresh 3 hid slots 0–3, refresh 4 displayed all actors and
refresh 5 hid slots 0–5. Slots 0–3 were therefore absent twice among six genuine
full refreshes, despite valid receipts, unchanged native tick 0/material revision
3 and no material or unknown-texture veto. The assertions were not relaxed.

The shared clearance deadline was exhausted. The actor certificates used upload
serials and GPU texture RIDs as identity, so every unchanged-byte refresh
invalidated them. Once the deadline had expired, the prior selected pose could
not be recertified either. This is a real visible omission, distinct from the
physics-progress stall.

The repair assigns monotonic content identities using exact bytes and image
dimensions/format, and requires the selected pose's certified contents to cover
every currently visible texture. Unknown active previous history still vetoes
reuse. A changed pose receives only the contents its own sweep checked. This
does not certify motion from content equality alone or increase either budget.

The expanded actual-native dense fixture deterministically exhausts the
clearance allowance and uses real PAINT for clear A → obstructed B → clear A.
It independently checks that B obstructs the old selected footprint while the
actual physical body is elsewhere. Both preserved pre-fix runs fail the same
17 visible-hold assertions. The first candidate passes those controls but fails
four original refresh-progress assertions during a 74.780-second run with
selection spans up to 266.855 ms, including large no-upload/zero-cell spans.
This failure is retained, not waived. Its ordinary phase later advances every
actor, so no permanent presentation latch was observed.

One authorized reversed-order diagnostic, using identical source, assertions
and fresh profiles, then passes all 3,391 candidate checks in 25.518 seconds
(17.970 seconds child CPU). The old source again fails only the 17 intended
hold assertions in 24.627 seconds (17.026 seconds child CPU). All eight candidate
actors advance on all six refresh frames, with 34–114 µs cache cost and
562–698 µs selection cost. All ten hidden bodyframes are intentional safety
negatives: eight unknown-history, one current obstruction and one previous
obstruction. No assertion, allowance or retry policy was loosened. The initial
slow run lacks CPU telemetry, so external scheduling cannot be proven as its
cause retrospectively. Main SHA256 for this comparison is
`71b40a7a49fe56e06253c86fe603add1b16c5c9ad01beae79ff61709ba39b67e`;
the identical dense test is
`ee305bcc928d45a717a174ef8547dc56cba9cc6464e3b4d99b8cada51f94cf85`.

## Full material upload copy reduction

The single, complete, tightly packed full-World patch now calls `image.set_data`
after the existing complete validation and old-image preservation. This removes
an extra payload slice, temporary patch Image and full-image blit. Offset,
padded, partial and multiple patches retain the old path. The source-matched
test `test_render_full_upload.gd` exercises actual Main/Image/ImageTexture/
ShaderMaterial objects, R8 and RG8 bytes, previous-image identity, input ownership,
invalid-payload rejection and the ordinary fallback paths.

Both pre-change and corrected implementations pass the same 265 checks. One
headless sequence of 12 actual 2048² full uploads per format measures:

| Format | Before median / maximum | Corrected median / maximum |
| --- | ---: | ---: |
| R8 | 3.456 / 21.911 ms | 0.322 / 0.583 ms |
| RG8 | 7.431 / 39.626 ms | 1.191 / 1.861 ms |

Exact RG8 content comparison still costs about 1.2 ms median and remains charged
to the presentation allowance. These are isolated CPU/headless upload-call
measurements, with no native worker and no physical GPU claim; they are not
whole-game frame-rate measurements. Final Main SHA256 after this narrow copy
change and the opt-in content-identity trace field is
`41be8737f2618db1a6a542793984bacbd6cd4fd83cdfefe13f664b20ba086a1d`.

## Final default-coupled application measurement

One final sequential control → candidate pair uses that final Main, unchanged
bridge `1757daa7…`, the original 2048² native World and Needle, all eight original
tick-addressed inputs, Fire ON→OFF at step 60, native-sample wait/wake ON and
Auto workers. Each capture lasts about ten seconds. Every run is retained;
there are no retries. This pair has slower native execution than the earlier
cohorts, so only its paired control is used for the following comparison.

| Actual observation | Failed43f46 control | Final corrective source |
| --- | ---: | ---: |
| Completed Rapier steps | 96 | 149 |
| Rapier / native / Main callback Hz | 9.581 / 9.481 / 49.300 | 14.888 / 14.788 / 59.452 |
| Completed-step gap median / p95 / p99 | 84.707 / 201.224 / 228.305 ms | 65.513 / 98.477 / 118.492 ms |
| Maximum completed-step gap | 267.631 ms | 138.420 ms |
| Main interval median / p95 / p99 | 16.507 / 46.649 / 59.787 ms | 16.430 / 24.860 / 29.491 ms |
| Material upload interval p95 | 208.334 ms | 97.862 ms |
| Terrain-installation holds | 123 | 13 |

All 96 common physical states match position, angle, velocity and native feedback
exactly; 95 native event inputs/revisions and 96 shared snapshot workload counters
also match. Common-prefix native work is slightly slower in the candidate,
42.354 → 43.801 ms mean, while native completion to next admitted step falls
53.825 → 21.541 ms. This supports an actual scheduling/publication improvement.
Both arms contain the same nineteen full 8 MiB uploads at native ticks 1–19:
13.961–87.243 ms before, 0.081–0.926 ms after.

The candidate still has actual physics gaps above 100 ms, four changed-material
overlay withholds at the shared deadline (control fifteen), and other patch
uploads reaching 37.537 ms. Native capacity remains insufficient for 60 coupled
steps/s on this measured host. No feedback age, wait, collision law, fixed step
or safety veto was relaxed to improve these numbers. Physical acceptance and
complete resolution of the owner's freeze report remain unproven.

Final scoped local qualification runs fourteen relevant production cases on
Main `41be8737…`, including the dense native-PAINT counterexample, temporal/contact
headless and graphical paths, pose trace, previous-texture crossfade, camera
picking/rendering, PAINT/Undo/Redo/reopen and full-image upload. All fourteen pass.
The earlier thirty-case campaign's twenty-nine passes and dense failure, the
deterministic negatives and the first slow candidate failure all remain retained.
The final hosted campaign runs all thirty-one production cases on Linux and
thirty-seven installed Windows cases, plus the expanded paired flight matrix;
its exact commit/run/artifact disposition is recorded in Draft #609 after it
completes. This local checkpoint does not claim those hosted results in advance.

## Qualification and documentation changes

The existing trace gains exact gate state and existing solver/flush call times;
tracing remains opt-in. The analyzer reports consecutive completion gaps separately
from visual holds, marks missing completion intervals, excludes explicit pause
spans from active-gap counts, and preserves long-gap witnesses.33 analyzer tests
include an all-live visual capture with a real120 ms physical gap. Leading and
trailing capture spans without a completing step are not included in the
completed-interval distribution; unchanged-physics Main interval counts remain
visible. `last_collider_call_usec` names the last observed bridge call, which
may precede the current hold callback; it is not a per-hold cost attribution.

Test It retains the six original diagnostic pairs and adds coupled interactive
Free/Follow pairs with native60/Rapier60, Auto workers, ordinary display defaults
and Fire ON→OFF. Quick now selects interactive Follow. Receipts add CPU and actual
worker resolution, and the owner summary separates real physical gap/hold evidence
from visual-source evidence. No owner preferences are silently erased.

Canonical behavior is updated in rendering/gameplay bridges; user controls and
qualification interpretation in the acceptance and pose-trace runbooks; current
failure disposition in the roadmap, handover and documentation index. The old
coherence audit retains its source-scoped results with this later failure linked.
Native ownership/wire format, World persistence and the fixed coupling law require
no change. The documentation/retrieval gates and source/runtime preflight apply
to the final corrective checkpoint, not just this preliminary record.

## Hosted corrective checkpoint and reporting follow-up — 2026-11-16

Source `30660f7da126eec95a2df8c5b432a4fa05a49a86`, tree
`6a8273fa91908850fc8ccde1fb974fdfee8347f1`, completed Actions run
`43779233966` successfully: all 31 Linux production cases, accepted-main
generator/Flatten/persistence checks, ten Linux flight arms, all 37 extracted
Windows application cases and the actual PowerShell 5.1 double-click workflow's
sixteen arms/eight pairs. All native/runtime identities matched before and after.
This is functional qualification with unresolved performance, not physical acceptance.

The Windows package contains 1,059 authenticated payload files and 1,023 tracked
source files, with all 93 native and four Rapier source inputs verified. Its ZIP
was 92,576,044 bytes, SHA256
`1594158bb303f6f5427294661188d5529e8524f6cb326e6fb472a35a3a9b33ef`.
It is retained as the checkpoint with the reporting defect described below.

Independent raw analysis finds all 755 Windows coherent submissions live and
aligned, with no known source rewinds or withholding; all 3,349 shared physical
states match the original-presentation arms. On Linux, 629 of 630 coherent
submissions are visible with no known rewinds; all 3,032 common physical states
match. The missing Linux Free submission is a time-budget refusal lasting until
the next submission 127.810 ms later, a real remaining flicker risk on that host.

Windows ordinary coupled Follow/Free achieve 12.473/12.642 completed steps/s.
Follow median/p95/max gaps are 80.050/89.930/117.099 ms; Free is
79.995/82.777/97.097 ms. Fifteen of sixteen Windows arms report at least one
100 ms gap. Terrain-installation holds are zero in that campaign; native-sample
waits and callback opportunities remain. The uncoupled Follow60 arm reaches
384.219 ms completion gaps and 107.730 ms p95 inside the timed solver call,
versus 0.026 ms flush and 0.554 ms presentation-resolver p95. These are wall
times including scheduling, not proof of solver CPU consumption or an inner lock.

Windows used Server 2022/ANGLE/WARP with an AMD EPYC 9V45 virtual machine,
two physical/four logical cores, Auto capacity four and startup/effective VSync1.
Its 1024x768 desktop clamps the normal requested 1920x1080 window to 1028x749;
the ordinary 480x270 view remains. Linux used Xeon 6975P-C/four logical cores and
llvmpipe at 1920x1080. Linux ordinary coupled Follow/Free each have 143/143 gaps
above 100 ms, about 7.4 steps/s and zero terrain-installation holds. Their mean
post-handoff callback waits are about 111/109 ms. None is NVIDIA acceptance.

A single bounded partial-upload diagnostic retained a fixture-equivalent native24
receipt with nine tightly packed patches, 143,934 bytes and 71,967 visible cells.
Its first 25 physical states and 24 native associations match both retained arms.
Original witness bytes were not retained and upload occurred one physical step
later, so byte identity and allocator/callback equivalence are not claimed. The
fresh upload took 3.599 ms; four predetermined real Main/Image/Texture replays
took 5.549/2.023/1.880/2.152 ms, passing 36 byte/history/slot checks. Neither the
16,384-cell previous-history scan nor padded bytewise compaction executes for
this packet. The 37.537 ms tail did not recur; sampled Linux CPU counters were
too coarsely updated for stage attribution. No additional speculative repair or
rerun followed. The original long frame remains unresolved evidence.

The final Windows audit found one reporting error in every one of the sixteen
arms: `Sort-Object -Property gap_ms` does not order the newly constructed
Hashtable witnesses correctly in Windows PowerShell 5.1. For example, Follow
coherent reported 80.138 ms/step97 first, whereas the actual maximum is
117.099 ms/step9. All other physics-progress fields and all other statistics
match the independent packaged Python reducer. Local PowerShell 7.7 had not
exposed this platform discrepancy. Original reports and the audit failure are
retained, including an earlier audit-helper whitelist omission for four inbox
Windows DLLs; that omission was not an application or runtime failure.

The narrow correction sorts explicit numeric gap keys descending, then start
time and step ascending. Its new CI harness extracts actual packaged production
functions, checks four unsorted/tied/pause/missing-completion fixtures and replays
all sixteen preserved raw traces, recursively comparing every field with Python.
Each specifically fenced successor's entire Godot/native/dependency trees must equal this
qualified checkpoint, and its exact corrected runner hash and changed-file list
are fenced. Only then may the existing application suite be reused under its
original source label. Actual Windows PowerShell 5.1 must reproduce the old
witness-only failure, pass the corrected replay and pass a freshly packaged
`Test It.cmd -Quick` plus reduction of both new traces. New package/run identities
and completion are recorded in Draft #609 after that scoped campaign finishes.
Other changes, or `force_full`, select the complete application campaign.

The first reporting attempt, `5a34cf35c12f40e9aa13513188908e7d3765730f`,
ran in Actions `43784599316`. Windows PowerShell 5.1 reproduced the old ranking
defect (1,463 registered witness-only differences), passed the corrected sixteen
traces and four fixtures, and completed the installed `Test It.cmd -Quick` with
both cases and its results ZIP. The final independent comparison failed on one
field: coherent `flush_ms.mean`, Python 0.024813 versus PowerShell 0.024812 ms.
The binary difference marginally exceeded the checker's intended 0.000001 ms
tolerance at the serialized rounding boundary. This is a reporting-check failure,
not an application crash or a physical-performance pass. The failed run and its
complete raw captures are retained; no delivery artifact was published by it.
Its evidence artifact is `14189709756`, 49,003,962 bytes, SHA256
`dd5c05479b1aea9d581cc60f0c45bd57ff4d74a8575521b5faf03057df9f28f8`.

That new hosted Quick capture still contains 86 original-presentation and 78
coherent completion gaps of at least 100 ms out of 143 intervals each, with
maxima 311.479/157.325 ms. It does not establish frozen-physics resolution.
The narrowly fenced follow-up preserves the failed commit as its sole parent,
keeps the application and corrected runner identical, and changes only the
checker, reuse fence and these two explanatory documents. The decimal boundary
requires a justified comparator regression, followed by the same real Windows
replay and newly installed Quick gate; it is not waived by rerunning a capture.

This reporting checkpoint changes no presentation mapping, material safety,
physics law, native source or owner preference. Canonical trace/acceptance guides,
roadmap, handover and index are updated; existing physics retrieval questions
still describe the unchanged physical and presentation contracts. The known
physics/presentation tails and the owner's physical FAIL/HOLD remain open.
