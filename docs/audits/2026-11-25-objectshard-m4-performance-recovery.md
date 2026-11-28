---
title: ObjectShard M4 performance recovery and optional recording
status: Current
document-kind: audit
scope: Recovery of earlier renderer evidence, opt-in instrumentation repair and source-bound development qualification; physical Windows/NVIDIA acceptance remains open
last-reviewed: 2026-11-25
related-documents: [2026-11-24-objectshard-m4-render-decision.md, ../research/objectshard-m4-workbench.md, ../operations/objectshard-workbench-playtest.md]
---

# ObjectShard M4 performance recovery and optional recording

**Physical performance acceptance remains HOLD.** This recovery preserves the
earlier source-bound [render decision](2026-11-24-objectshard-m4-render-decision.md),
including its slow paused control, active-body observations and the invalid
attempts. No earlier failure is relabelled as a successful later run.

## Recovered scope and remaining cost

The accepted recovery intake is application source
`f5b7ac7e651356c9f6d5657dfb0cb9d60111be81`, tree
`fcbb55a7c80a9d1a887e4e0336491e07c3ae01db`. The original local completion tree
is identical at `66365c4c20b4331c004810b4235893315a623525`. The existing
117-entry native input map matches this source exactly. The recovered sealed
Linux development runtime is SHA-256
`0dfe2a63e69062a44a4b7eb01ea65a4aa9c210f096f2413344482b7b051a68ae`, built
originally at `ccdfde97c279d809eafbb6e74b880d14cfb2f60e`. Reuse preserves that
build identity; it is not a new pinned hosted build.

The existing mixed headless profile's 1,080 compact snapshots over 180 ticks
cost 1.533 seconds of a 12.365-second window. That whole stage is a 12.4% upper
bound, not isolated payload-digest cost or an achieved speedup. Fresh shape and
accounting marshalling remain candidates for a separate measured change.
Material-revision-only digest caching is invalid because reaction due times
change independently. Sparse composition, native receipt reuse, unchanged
geometry and readiness suppression are preserved.

The original rendered tower capture was visually inspected: it shows actual
ordinary Workbench controls, coherent mixed Wood/Brick material rotated against
the raised native footing, and the existing reference barrel in the same
canvas. A still image establishes neither motion continuity nor displayed FPS.

## Recovered hosted observations

The [machine-readable review](objectshard-m4-recovery-20261125/performance-recovery.json)
retains all 48 recovered profile summaries, original report/log hashes, runtime
identities, render controls, five inspected screenshot hashes and the new local
results. The original archives were independently hashed again in this lane.
They match the recovered GitHub artifact identities exactly.

| Original evidence | Application source | Actual renderer | Renderer submissions/s | Native semantic ticks/s |
| --- | --- | --- | ---: | ---: |
| [Earlier Linux artifact](https://github.com/techrote/cybersand/actions/runs/45457037610/artifacts/14954007570), 12 rendered scene/camera profiles | `0f013ba4826730cce64bd37cf9ca95f7dcaab603` | Mesa 25.2.8, llvmpipe LLVM 20.1.2 | 6.653–7.504 | 1.610–2.523 |
| [Principal Windows artifact](https://github.com/techrote/cybersand/actions/runs/45473059187/artifacts/14961723648), 12 rendered scene/camera profiles | `f5b7ac7e651356c9f6d5657dfb0cb9d60111be81` | Microsoft Basic Render Driver through ANGLE/D3D11 | 10.626–11.496 | 2.154–3.429 |
| Same principal Windows artifact, 12 headless profiles | `f5b7ac7e651356c9f6d5657dfb0cb9d60111be81` | Headless | 0 | 25.216–35.363 |

The earlier Linux archive is 11,738,809 bytes, SHA-256
`8d11121e8448a656b307b4f82d87014bf6b4f66ce45d7dfbaa01726e6c8f1520`.
Its graphical invocation remains **FAILED** because its ordinary Workbench
completion case failed. Those 12 individual profile reports contain complete
180-tick results; they do not change that aggregate outcome. The exact job is
`138669186177`, run `45457037610`, attempt 1, independently confirmed in retained
full job metadata. That metadata's SHA-256 is
`f13c25dd2b3426c6ad4147e6963be020b044f1a3287a09ba7f9c52522dc9f219`.

The principal Windows archive is 33,235,453 bytes, SHA-256
`3f35d18a7e54ce8327d0b6f63dc57cf3e035380e7b87714c612dd0370f3650d7`.
Its underlying 38-case headless and 27-case nominal graphical reports passed,
but job `138728620324` remains **FAILED** because the subsequent extracted
package replay failed. Only 14 cases in that original graphical invocation
required a display. This failure remains a delivery failure even though these
application profiles passed. Its attempt 1 is explicit in retained original
full run metadata (SHA-256
`83d7f6ac399eabc5a96bfaaa3f33dc3446e38aa907ff0a557903da72c530d4ce`);
that initial metadata is used for source/attempt identity, not terminal status.
None of these environments establishes physical
NVIDIA performance, and the different sources, platforms and host loads do not
support a before/after speedup ratio.

The principal Windows overview comparisons provide a useful workload split:

| Scene | Actual bodies | Renderer submissions/s | Native ticks/s, graphical | Native ticks/s, headless | Render interval p95 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Tower | 1 | 10.973 | 3.429 | 28.933 | 96.553 ms |
| Viaduct | 3 | 10.815 | 3.061 | 31.516 | 268.521 ms |
| Timber | 1 | 10.626 | 3.193 | 30.984 | 227.999 ms |
| Mixed materials | 1 | 10.828 | 3.185 | 29.103 | 269.008 ms |
| Eight-body stress | 8 | 10.923 | 2.154 | 26.915 | 99.201 ms |

These are completed 180-native-tick profiles with actual Rapier segments,
accepted native pose echoes and zero observed incoherent publications. The
timed window can include one in-flight segment from the next interval; the
completed physical-interval counter excludes that partial work. The raw reports
retain both counters and the final native barrier. Water/Sand displacement and
timber chemistry witnesses remain present; lower throughput was not obtained
by reducing the workload.

The principal Windows timing probe was disabled in its separate four-window
control. It still recorded 9.376 submissions/s while intact and paused,
10.911 intact and playing, 11.432 detached and paused, and 10.928 detached and
playing. Both paused windows had zero native progression and zero owner
snapshots. The earlier Linux intact-paused control similarly recorded 6.506
submissions/s with zero native progression. Standing presentation/host cost is
therefore substantial in these environments. That observation does not explain
the owner's physical machine or eliminate the measured attached-owner cost.

### Stage evidence and its limits

In the principal Windows tower report, recent bounded
`texture_upload_submission` observations have median 86.834 ms, p95 93.608 ms
and maximum 237.239 ms over 51 samples. The same-source headless report has
median 0.023 ms and p95 0.514 ms over 23 samples. Graphical `scene_callback`
median is 9.188 ms and actual `physics_work` median is 0.165 ms, compared with
8.228 ms and 0.094 ms in headless execution.

These stage summaries begin at recording start and can include setup and
support cutting. They are not exclusively the timed 180-tick window. Texture
submission can include engine synchronization; these measurements are neither
isolated rasterization cost nor a GPU timer. They support further presentation
investigation but do not prove which physical-driver operation is responsible.

The separate window counters are precisely bounded. The graphical tower's
1,080 worker snapshots cost 1.122 seconds within its 52.494-second window;
unchanged geometry and terrain reconstruction counters are both zero. The
eight-body window has 1,080 snapshots costing 2.052 seconds within 83.584
seconds. Main receipt-pump counters include waits and nested work; native
occupancy includes relocation. Adding these counters would double-count work.
The review preserves the existing PUBPRES ownership boundary and imports no
unfinished presentation branch.

## Optional recording correction

Previously, the ordinary ObjectShard flag and Structures enable action started
full bounded event recording automatically. That imposed event construction
and observation callbacks on every evaluator session, contrary to the requested
optional diagnostic mode. The corrected default is recording off. The new
Structures checkbox and separate `--objectshard-diagnostics` flag opt in.

Stopping preserves the last bounded recording for Save diagnostics and removes
its post-draw callback. Starting another recording clears its samples and
advances the recording epoch. Native/Rapier barriers, active body counts,
chemistry, actor effects and publication identity are unchanged. Rich profiles
explicitly enable observation and require nonempty timing/progression evidence.
Light sampling independently omits per-callback physics readback; its default
disables recording, while a matched tower counterpart explicitly enables it.
Every recording-enabled profile must contain actual timing events and native
delivery intervals regardless of its sampling mode.

This is a removal of unnecessary default instrumentation, not a claimed fix for
the owner's severe frame-rate problem. Its cost must be measured using matched
instrumentation-on/off workloads. The prior slow paused window already disabled
the latency probe, so this correction cannot explain that observation.

## Development qualification and retained negatives

The initial ordinary checkbox fixture passed 35 of 36 checks. Its one failure
compared a JSON-decoded dictionary (integral numbers decoded as floating point)
directly with its original GDScript Variant dictionary. The native progression,
disabled-recording, real checkbox, retained capture and saved file checks had
all succeeded. The repaired test compares both values through the same JSON
serialization boundary; it does not loosen a timing or physics requirement.
That replay passed all 36 checks with zero display-identity discrepancies in
340 headless callback observations in the original failed attempt. Subsequent
source-bound results are recorded with their own identities below.

Local graphical execution is unavailable in this recovery environment: there
is no display, the X server cannot create its listening socket under the
execution policy, and the native desktop tool reports runtime unavailable.
The retained original graphical evidence and the required replacement hosted
graphical campaign retain separate source and renderer scopes. A headless
run here is never reported as graphical acceptance.

## Additive comparison inventory

The replacement qualifier preserves all five scenes, overview/zoom profiles,
the original four enabled pause/play renderer controls, and both existing light
profiles. It adds an ordinary tower control launched without the ObjectShard
flag, a matched tower light profile with recording enabled, and checkbox/CLI
recording cases. In the rendered lane, both recording cases use the real
renderer and require actual post-draw observations.

The disabled control authors the same native material rectangles and ordinary
reference actor on the same 512 canvas, with the same overview camera. It
measures paused and running windows for at least 12 seconds each, proves that
no mutable body or native attachment exists, and requires actual ordinary
native/Rapier progression only in the running window. Its report records the
authored rectangle digest and exact view rectangle; the rendered qualifier
requires these inputs to match the enabled control. It does not substitute a
blank scene or label headless callbacks as rendered submissions.

The enabled control also preserves the established fixture's per-callback
publication-coherence checks. The disabled control has no attached publication
to inspect. Therefore an enabled-versus-disabled timing difference includes
asymmetric qualification-observer cost and is not a pure measurement of product
ObjectShard overhead. The light recording-on/off pair uses the same observers
on both sides and isolates the recording option within the stated host scope.

Development executions of the added disabled control passed 21 checks and the
light recording-on tower completed 180 native ticks and 720 real Rapier
segments with 512 retained timing events. The added validator tests reject
missing recording observations, accidental attachment, missing native/physical
progression and headless/renderer scope substitution. These development runs
are preparation for the fresh committed-source hosted campaign, not release
qualification or owner GPU performance acceptance.

## Committed local execution and matched recording result

An additional sequential local campaign executed application
`61213289ccaf2ec9771274f73576752ac1d648ff`, tree
`639b3709c7ae82236aacab86ff3cb13327b5e446`. Its
[complete receipt](objectshard-m4-recovery-20261125/performance-local-61213289c/campaign.json)
records 1,076 committed execution-input hashes, all commands, log/report hashes,
the exact Godot/Rapier identities, original sealed native build receipt and
host/load observations. All 117 native compilation inputs were compared again
with the reused runtime's input map. The host is Linux 6.18.57 with nine exposed
logical CPUs reporting Intel Xeon Platinum 8573C. It is a shared headless
environment; no exclusive-host or hardware-display claim is made.

All **13 executions and 1,829 assertions passed**: real checkbox and CLI
recording tests, disabled and original enabled controls, four matched tower
light profiles, and all five rich overview scenes. Full parsed reports are
retained beside the campaign receipt. The zero-body disabled control progressed
59.898 native ticks/s, the enabled zero-body control 55.749 ticks/s, and the
detached active tower control 27.732 ticks/s. The observer caveat above applies.
All paused controls consumed zero native or Rapier time. Rich scene rates were
27.106 tower, 23.849 viaduct, 26.949 timber, 26.672 mixed and 17.126 eight-body
stress native ticks/s; renderer submissions were zero because these are
headless runs.

An independent tree comparison finds no changed path under `godot` or `native`
between this tested source and the frozen local integration
`537ddef6e88eca2a59b8a02816a149601504dc7e`, tree
`a3f3e166f474d8c2a0d882cc9f7bb2adf21d8919`. The local runtime identities
remain the bytes actually executed. Different qualification/packaging inputs
outside those scopes still require the fresh hosted integration campaign.

The matched recording experiment deliberately used the order off/on/on/off,
the same fresh tower, overview camera, light callback sampling, native/Rapier
workload and publication observers. Every run completed 180 semantic ticks.

| Sequence | Recording | Native ticks/s | Retained timing events |
| --- | --- | ---: | ---: |
| 1 | Off | 26.511 | 0 |
| 2 | On | 28.307 | 512 |
| 3 | On | 29.954 | 512 |
| 4 | Off | 30.775 | 0 |

This small shared-host comparison shows **no consistent throughput benefit
from disabling recording**. The changing run-order rates prevent a precise
overhead estimate; the on/off medians are 29.130 and 28.643 ticks/s respectively.
The correction gives the owner optional observation and removes unnecessary
default work. It does not establish an FPS repair. Actual acknowledgement,
chemistry, actor and material work remain intact in both modes.

### Naturally sleeping body while the simulation runs

The recovered 180-tick one-body profiles had no separately classified sleeping
cohort. A paused detached body cannot fill that gap. An
[external frozen-application observer](objectshard-m4-recovery-20261125/natural-rest-local/observer-complete.gd)
therefore released the ordinary tower, allowed actual Rapier settling without
state setters, required 120 native ticks of stable quiet motion, and measured
another twelve seconds with the simulation running. Its
[complete receipt and custody](objectshard-m4-recovery-20261125/natural-rest-local/custody.json)
preserve both executions, exact observer digests and raw reports/logs. The
second execution added full edge diagnostics and inventory-report retention;
the application remained unchanged.

In the complete replay, Rapier naturally reported sleeping after the fall.
All 1,642 observations in the 12.000172-second measured window were sleeping,
with zero linear/angular velocity and zero position/angle drift. The same
physical RID and geometry remained owned. It completed 400 native ticks,
400 physical intervals and 1,600 actual Rapier segments with 1,600 native pose
acknowledgements. Native progression was 33.333 ticks/s; callback median/p95/max
was 8.930/10.497/62.409 ms. There were 2,400 worker snapshots costing 1.993
seconds. Independent inventory remained 2,184 Wood and 2,232 Brick cells.
All 109 assertions passed. This observer adds direct Rapier state readback and
is headless development evidence, not an uncontended or rendered comparison.

The first execution's different window-edge counts are retained exactly:
373 native ticks, 374 physical intervals and 1,496 real segments. It observed
native tick 477 before the window, 850 after it and 851 after explicit Pause.
Its exact start/end phases were not retained, so those states are not invented.
The implementation increments completed physical intervals only after valid
native segment acknowledgements and exact pose echoes, then waits for the due
native tick before reporting Ready. A native observation edge can therefore
trail acknowledged physical completion without implying a missed acknowledgement.

The complete replay preserves this distinction directly. Both measurement edges
were in `RealRapierInterval`, with one executed segment awaiting its native
acknowledgement: `pending_kind=motion`, one segment, zero acknowledged interval
duration. Neither pending edge was included as a completed interval. Explicit
Pause subsequently drained that already admitted interval: steps 3,505→3,508,
acknowledgements 3,404→3,408, completed intervals 876→877 and native tick
877→878, ending Ready with zero pending serial and zero lease. These are
separate clocks, not values normalized to make them agree.

### Replacement campaign's long-burn observation failure

The first replacement Windows campaign at
`51903088118d2a04f2dc79dd6fff7c25b226970c`, run `45517975210`, attempt 1,
passed 41 of 42 headless cases and failed the existing long-burn assertion.
That aggregate remains **FAILED**. The
[focused review and replay custody](objectshard-m4-recovery-20261125/long-burn-local/custody.json)
retain the failed original log/archive identities, exact tested fixture,
resource samples and the successful local correction.

The failure joined two different observations: `f.tick()` reads the latest
native frame, while `f.owned_cell_state()` intentionally reads the coherent
display publication. At native tick 514 the failed trace already contained
eight structural cells and geometry revision 2, while the displayed Wood still
had burn state 1 and the physics-applied revision was 1. The display correctly
waited for geometry acknowledgement. At tick 515 it showed Empty with applied
revision 2. Counting this delivery delay as extra native combustion time was a
fixture error. The ordinary display/source helper remains unchanged because
moving tools require its displayed identity.

The corrected fixture reads cell and lifetime tick from one immutable native
sample, records the displayed cell/tick/sequence separately, and additionally
requires their exact join after Pause and geometry acknowledgement. The
240-opportunity law and strict 480-native-tick bound are unchanged. Independent
source review approved this narrow correction. Optional recording can alter
observation timing around the existing bounded receipt pump; it does not gate
chemistry or acknowledgements. A causal claim that its toggle triggered this
specific failure has not been established.

The focused replay in the established local project passed **233 assertions**
in 32.275 seconds and exited naturally with code 0. Ignition tick 34 to
exhaustion tick 514 is exactly 480 native ticks; the final post-Pause total of
481 includes one separately identified drain tick. Last-cell physical/native
retirement also passed. Resource sampling observed peak RSS 601,522,176 bytes
and minimum host available memory 1,426,546,688 bytes. These are external
process/host observations, not allocation-rate measurements.

The executed external fixture SHA-256 is
`3c8ce13a53f99a753b3e43bceddf8afa6eff9e06ba443d8af8327c07356dc70f`.
The committed successor in `1d494c36b119219db3cd812e7bff45358a3a6c87`
adds only the derived `lifetime_native_ticks` and
`post_exhaustion_native_ticks` receipt fields. Its SHA-256 is
`787b302391300875338fa60f4ffa262c6c5344bafffe31eb9b617e3776dddcad`.
The [exact successor diff](objectshard-m4-recovery-20261125/long-burn-local/report-only-successor.diff)
is retained. The local execution is not relabelled as those later bytes; the
final hosted campaign must execute the exact committed successor.

## Disabled-control Pause acknowledgement recovery

The first recovery campaign at source
`51903088118d2a04f2dc79dd6fff7c25b226970c` completed all 42 Linux headless
cases, but its graphical invocation passed 30 of 31 cases. The new disabled
control observed two native ticks and zero Rapier steps during its purportedly
paused window. This remains a **failed control and failed Linux job**. The
[retained correction custody](objectshard-m4-recovery-20261125/disabled-pause-correction/custody.json)
records the exact run, job, archive and process log identities.

The fixture had accepted a coherent snapshot marked paused without requiring
acknowledgement of the particular UI Pause. Existing ordinary actor-composition
qualification already explains why an internal held body sample can produce
such a snapshot during Play. The correction in
`658b6b1464aecc8165cb8c77817ea5d591d56d0a` uses the existing monotonic
`workbench_pause_request_serial` and worker-exclusive
`workbench_pause_ack_serial` receipt, together with actor suspension and the
original coherent-image conditions. An otherwise coherent copied receipt from
before that request is explicitly refused. Reports retain the requested and
acknowledged serials, native tick, World identity and publication serial before
and after each window. The zero-native-ticks/zero-Rapier-steps requirement and
twelve-second workload windows remain unchanged. No product or native law is
altered by this fixture correction.

The exact corrected fixture is SHA-256
`6fc42b178288ddc47c5f3801f1f46535904e54d9f55ba00a2ba8d8f8fb69c8ea`.
The first external execution was interrupted by loss of the executor; its
outcome is unavailable and is not a pass. After recovery, an exact committed
source execution parsed and reached its initial flag assertion, then terminated
with SIGKILL after 5.219 seconds during ordinary Workbench startup. Neither
measurement window executed. The retained external samples observed peak RSS
357,523,456 bytes and minimum host available memory 1,178,390,528 bytes; they do
not establish the termination cause. The independent 117-native-input and
five-build-contract-input comparison and engine/runtime hashes passed. This
focused attempt is **not qualified**. Fresh actual hosted execution of the
corrected fixture is still required; source review does not replace it.

One authorized direct-script retry retained the exact committed three-file
portable bootstrap. All three files already matched and there were no extra
generated metadata files; this is not evidence of a metadata repair. Ordinary
Workbench setup, the initial native tick, monotonic Pause, stale-receipt refusal
and actual native/actor acknowledgement passed. SIGKILL at 11.432 seconds then
interrupted the first measurement window. This second attempt also remains
**not qualified**, with its separate log/resource custody retained.

## Independent held-edit delivery review

The bounded product correction at
`22b610dfaa16faf98df691cd0ccbaf9b43aebb50` records the latest validated
material mutation's full owner/port identity and maximum transaction number.
The held pointer waits for a later coherent publication from that exact owner,
in addition to its existing native/physics readiness and frame/publication
equality. Read-only inspection creates no mutation dependency. Diagnostic
result retention cannot erase the fence, conflicting owner identities enter
Hold, and authoritative port retirement clears the prior identity. This is a
transaction-delivery condition; it changes no native physics or material law.

Independent source review approved that scope. The
[value-level conformance case](objectshard-m4-recovery-20261125/edit-delivery-fence/review.json)
at `5c9ba082f4571258cc4874e4dfb9f83a65f1a5a0` passed 36 assertions with
natural exit 0 in 1.909 seconds. It challenges out-of-order validated receipts,
all capability/publication owner identities, malformed counters, inspect
exclusion, diagnostic-result eviction, conflict Hold and retirement reset.
These copied values do not claim that native material moved. The independently
executed delayed-Main fragment case provides the separate physical evidence.
The new focused case is added to every appropriate existing qualifier lane;
the explicit inventory is 43 headless, 32 graphical and 17 package-replay cases,
with 18 cases actually requiring a display. Every prior case remains present.

## First replacement Linux graphical comparison

The [source-bound comparison table](objectshard-m4-recovery-20261125/linux-519-performance/readout.md)
and [machine-readable readout](objectshard-m4-recovery-20261125/linux-519-performance/readout.json)
independently join all 26 headless/graphical profile reports and original
process-log hashes from the first `51903088` Linux replacement artifact.
All 13 graphical profiles completed 180 native ticks with actual Rapier
segments and zero observed incoherence. The two new optional-recording cases
also executed through the actual renderer and passed 38 checks each. The
aggregate Linux job remains failed because of the disabled-control boundary
described above.

The five overview scenes submitted approximately 6.65–6.80 frames per second
on Mesa llvmpipe, while native progression ranged from 1.72 to 2.26 ticks per
second. The disabled running control submitted 6.73 frames per second and
advanced 6.65 native ticks per second. Its paused sibling submitted 7.02 frames
per second but is not a valid zero-progression control: the two late native
ticks remain in its report. This software-renderer evidence establishes
neither physical NVIDIA performance nor an ObjectShard speedup. The complete
table separates callback/render interval tails, bounded delivery age, worker
snapshots and Main costs, and retains their nonadditive timing scopes.

## Visual review and next acceptance evidence

All five recovered principal Windows overview captures were inspected
individually. They show the actual ordinary toolbar and reference actor with a
recognizable tipped tower, three independent viaduct sections in Water, coherent
timber with combustion products, a mixed structure contacting Water/Sand, and
eight distinct stress frames. The fixed overview retains substantial empty
canvas; ordinary zoom and pan remain available for detailed edits. Profile
screenshots return to overview after the timed window, so a screenshot named
for a zoom workload is not a capture of that workload's timed camera state.

These still images belong to the original `f5b7ac7e` application. They establish
neither continuous motion nor the new optional checkbox's graphical behavior.
The replacement hosted campaign must supply fresh graphical optional-recording,
scene/camera, input and package evidence. The
[owner guide](../operations/objectshard-workbench-playtest.md) describes optional
fifteen-second comparisons and a single diagnostic export without a compiler,
Python installation or source instrumentation. Physical Windows 11/NVIDIA
smoothness, responsiveness and visible stalls remain **HOLD** until actual
owner-machine evidence exists.

Source review of the owner guide against the frozen launcher/UI found no
blocking navigation gap. A later documentation refinement names the exact
**Eraser** selector/shortcut, moving-tool selector, wheel/middle-button camera
controls and the fixed CMD arguments. This refinement postdated the initial
`51903088` qualification freeze. Whether it is present in a later evaluator is
determined by that evaluator's immutable source and payload manifest.

One minor help-text inconsistency remains for direct engine launches with
`--objectshard-diagnostics`: the first opening of Structures can show the
generic "Timings are off" guidance even though the recording checkbox is
correctly checked and the probe is recording. Toggling the checkbox updates the
guidance. The normal CMD launch starts recording off and its checkbox workflow
is correct. This cosmetic CLI-only issue does not alter recording, native
ownership or performance counters, and does not justify changing frozen
application inputs during the replacement campaign.

## Qualification impact

The repair changes Main, Structures UI, the optional probe and profile/test
scripts. Native source and binaries are unchanged. Focused native-input reuse
is legitimate only after the full map comparison; changed application inputs
require fresh actual Linux and Windows Workbench execution. The registered
inventory is additive: it retains every prior case and adds actual checkbox
and CLI recording executions. Physical NVIDIA/monitor acceptance remains the
owner's gate after the portable package itself passes qualification.
