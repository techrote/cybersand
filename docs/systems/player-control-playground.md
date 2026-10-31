---
title: Player control playground
status: Current
document-kind: contract
scope: Experimental movement controls and shared asynchronous desktop composition, input and lap lifetime, lifecycle and bounded native failure validation; isolated Sand and Water player fields
canonical-for: [player-control-playground, player-movement-presets, player-material-field]
last-reviewed: 2026-10-31
related-documents: [physical-actor-rigs.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../audits/2026-10-20-player-control-playground.md]
---

# Player control playground

## Current PLAY acceptance boundary — 2026-10-30

The [authoritative owner decision](https://github.com/techrote/cybersand/issues/263#issuecomment-6522029843)
accepts [PR #302](https://github.com/techrote/cybersand/pull/302), merged at
`8d2dd843dfe457d34f32ebd015a924cf58b3c1ce`, for PLAY's mandatory native-busy
lifecycle gate. Its [exact-source special-runtime execution](https://github.com/techrote/cybersand/actions/runs/40987544825)
at `102f6b5da74bffcf3da0063ca335ba6e8c22ce94` passed **34/0 assertions on each
Windows and Linux**: genuine claimed `World::tick_phased()` jobs stayed
outstanding while Main, physics/Rapier and Viewport/input progressed; the
immutable snapshot stayed valid; production stop preceded manual release,
drain, dispatch return and worker join. The
[original audit](../audits/2026-10-29-play-busy001b-real-phase-host.md)
preserves its special-runtime provenance, earlier failure and actual ordering.
Ordinary production binaries do not contain the temporary qualification hook.

**PR #304 is optional and non-blocking.** Its changing-framebuffer-under-held-job
experiment is not an additional mandatory acceptance gate. The original
[run 41046902349](https://github.com/techrote/cybersand/actions/runs/41046902349)
at `0d5619e83b60e35ce49aa0efe4efa48a28b11dca` failed both host jobs. Retained
artifacts and later nonqualifying diagnostics must not be relabeled as passing
authoritative executions. Historical references below to an unmet native-busy
gate describe those earlier slices; #302 and the owner decision supersede that
dependency without broadening their original evidence claims.

Live state checked on 2026-10-30: #266, #267 and #273 are completed/closed;
#265 remains closed Not Planned; #271 is deferred; #272 remains conditional
fallback architecture. The active path is **#268 → #269 → #270 → #263**.
The [concrete #270 human checklist](https://github.com/techrote/cybersand/issues/270#issuecomment-6485284121)
remains unexecuted. Neither this checkpoint nor automated counters establish
PLAY promotion, physical-controller compatibility or human responsiveness.

## Integrated playable-session selection and device rearm

**Current implementation, candidate qualification:** the feature launcher now
offers **Play session**, opening the shared `main.tscn` host's composed selector.
Choose the original Player Playground course, any of the five mechanical SetP
rigs, keyboard plus standard gamepad or keyboard only, four-checkpoint lap or
free play, construction-time per-material solver policy and close-follow or
overview starting camera. No alternative simulation owner is introduced.
The in-host Play button shares the existing wrapping MicroScenario action bar,
so it does not add a vertical launcher row or displace the older mouse targets.

[`main.gd::apply_playable_session`](../../godot/scripts/main.gd) validates the
copied selection and calls the existing prepared native/physical reconstruction.
The [panel](../../godot/scripts/playable_session_panel.gd) reuses the existing
native-backed liquid editor; unsupported family/material choices retain native
refusal reasons. **Build selected session** queues one request. Previous applied
actor, options, World and receipts remain authoritative until the matching
worker acknowledgement. Refusal retires the prepared candidate and preserves
the old applied session. A successful build starts paused; **Play / resume**
requires neutral input, and **Restart applied session** retains the accepted
policy/options instead of unsubmitted UI edits. Solver selection is a rebuild,
never a live swap. Default selections remain Current, keyboard/gamepad, lap
and follow camera; existing entry points retain their defaults.

Requested and applied policy are displayed separately for the selected material;
the applied native policy and construction-receipt hashes are available in the
policy tooltip. The panel blocks gameplay input while open. P/Escape and selected-gamepad Start pause, R restarts,
F toggles the course camera. **Return to launcher** in the Play session panel
uses the existing scene-navigation teardown; F2 remains an optional shortcut. Keyboard-only mode
excludes gamepad polling and button forwarding. Free play suppresses the lap
tracker/HUD. Protected scientific/blind fixtures refuse the new reconstruction
route; the standalone material swarms and specialist/NPC paths remain separate.

### Course target visibility and optional worker details

The shared course now reuses the authored checkpoint drawing: the next gate is
accented, future gates are faint and completed gates are marked. The overlay
receives copied lap identity and the same camera/content transform as the actor.
It neither queries a native World nor awards checkpoints. Invalid/retired actor
or World identity, pending reconstruction, fault, free play and clean-view mode
clear the targets. Completed native ticks and actual main-thread Rapier
observations still own timing and visits; visual rings are not traversal proof.

F3 expanded details in a running Play course request an optional owner-side
statistics sample at most four times per second. Main only receives the frozen
copy, including a retained read-only empty value when sampling is off or
unavailable. Replacing the owner slot preserves earlier published values.
The display separates the constructor's requested worker setting, capacity,
observed **task participants**, source native tick and sample age. Participants
mean the maximum distinct task-claiming workers in one phase dispatch of that
tick; an inline nonempty phase counts the owner as one. This does not measure
simultaneous execution or utilization. Sampling defaults off, stops when details
close, and Main sends a request only when that choice changes.

Owner-publication serial gaps count snapshots coalesced before Main consumed
them. They are separate from native tick deltas, rejected serials and rejected
render payloads. An unavailable sample is labelled unavailable, not replaced
by the configured capacity. No production shader, default solver, mechanical
tuning or additional simulation owner is introduced.

The [UI007 audit](../audits/2026-10-31-play-ui007-desktop-readiness.md) retains
the original missing-overlay negative, five actual-host headless regressions,
separate overlay-only pixel tests and failed shared-Main graphical startup.
The [manual packet](../operations/play-desktop-manual-qualification.md) binds
all five rig entry points and physical checks to a reviewed source/runtime;
generating it proves identity only and leaves every human row untested.

The [course event bridge](../../godot/scripts/playable_course_gamepad_events.gd)
observes `Input.joy_connection_changed`. Loss, replacement or addition of the
selected first controller cancels the current physical command and pending
button edges through the existing owner, including its native-effect
cancellation signal, and requires neutral input before rearming. An unrelated
secondary controller event does not revoke the selected controller. A
keyboard-only session ignores gamepad connection changes. This is a source
behavior claim; physical disconnect/reconnect still needs the manual checklist.

The [real-host regression](../../godot/tests/test_play_ui005_session_selection.gd)
constructs all five rigs with alternating Current/Water-pressure policies,
checks one transaction and unchanged prior owner/options while pending, actual
native receipts, original map, newer identities, prior Rapier retirement,
camera/rule/control selection, running native/Rapier clocks and policy-retaining
reset. It also exercises native Oil/pressure refusal, protected-fixture and
deferred-swarm refusal, selected/unselected device signals and focus rearm.
It also sends viewport mouse events to the visible in-host Play button. The
existing Experiment Tower mouse/Space/F9 regression remains unchanged.
Only the OS-focus predicate and device enumeration are synthetic; they do not
qualify real hardware, OS focus delivery, natural course traversal or human feel.
The [dated audit](../audits/2026-10-30-play-ui005-integrated-session.md) owns local
source hashes, commands, original failures and final-head hosted-gate status.

## Immediate shared-course pause transitions

**Current source behavior; final hosted acceptance is recorded separately:**
P, Escape and the selected gamepad's Start route through the same shared-course
pause setter. Every actual pause/resume transition immediately cancels input
authority and queued button/equipment edges, before the next physics callback.
A pause then resume within one callback interval therefore cannot retain an old
press or lease. The existing native worker, World, actor session and Rapier
bridge remain the owners; release controls to neutral before fresh input rearms.

The pause toggle respects window/UI ownership. Unselected controllers and
keyboard-only sessions cannot use Start; modal/unfocused input cannot resume.
The panel's explicit Play / resume button uses the same cancellation path.
Resume refuses failed native work, pending reconstruction/reset or unready terrain.
Controls outside the composed course retain their previous behavior.

Ordinary actor-picker and environment-tuning opening, GUI focus acquisition and
window-focus-loss notification also revoke course authority immediately. The
visible MicroScenario Pause / resume button calls the central pause setter as
an explicit UI action, including while its Seed field retains text focus. The
keyboard/gamepad toggle remains context-gated. Every successful transition still
requires neutral controls before fresh physical input can rearm.

The [INPUT010 audit](../audits/2026-10-31-play-input010-pause-transitions.md)
records an actual failing-before callback-gap reproduction, all-five-rig
automatic Main/native/Rapier regressions, original local environmental failures
and required exact-head hosted results. Injected focus/device enumeration is
explicitly synthetic; this is not physical-controller or OS-focus acceptance.
The [INPUT011 audit](../audits/2026-10-31-play-input011-authority-transitions.md)
preserves the rapid modal/focus failure and the separately reproduced focused
button refusal. Its v2 five-rig cases include both explicit-button success and
keyboard-toggle refusal with retained text focus, actual later neutral/fresh
Rapier steps, and the matched stale-input negative. The ordinary parent runner
requires source-bound raw-evidence readback before accepting each rig case;
synthetic window notifications do not establish real OS-focus delivery.

## Live adversarial delivery qualification

[LIFE010](../audits/2026-10-31-play-life010-live-delivery.md) supplements the
accepted50-real-lifetimes-per-platform baseline with two sequential actual
Main/native/Rapier lifetimes per rig. An inherited worker probe retains authentic
immutable packets and deliberately delivers duplicates, delayed/out-of-order
values and an old actor/World packet while the sole publisher stays live. A
separate real-host serial-guard bypass must fail specifically for serial
regression. No artificial production transport queue or second worker loop is
introduced.

Actual quick equipment presses reach the inherited worker's extracted-request
boundary. A bounded test gate outside the production mutex allows Main and
Rapier to continue. Valid-lease pause cancellation must prevent the native effect;
fresh authority must recover. Positive native receipts require a subsequent
completed Rapier step on the same run/epoch/control generation. These checks
preserve actual body/terrain/render/lap fences through reconstruction and complete
join. The common Windows/Linux runner independently reduces retained raw packets,
process receipts and logs, including21 reason-specific adverse controls, before
accepting each LIFE010 case. This is synthetic scheduling on the actual host,
not physical-device, graphical or human-feel qualification. Exact resulting-head
hosted execution remains in the PR ledger.

## Eight-policy composed-session qualification

[LIFE011](../audits/2026-10-31-play-life011-composed-solver-matrix.md) exercises
all eight liquid-selector presets on every mechanical rig through ordinary
shared-Main construction and retained-policy reset. Each rig requires eight
builds, eight resets and 72 samples of completed nonneutral Rapier progress
alongside native progress. The existing transaction must refuse eight Oil/pressure requests and
three radius-two inertial requests while preserving the current World, actor,
applied policy and receipt. Any inertial solver requires explicit radius three;
this does not change the default geometry or solver assignments.

Old-run and still-valid-lease old-control observations are separately refused;
fresh observations recover. Retained publications remain immutable and all
replaced graphs and the final worker retire. The ordinary Windows/Linux runner
requires the independent policy/receipt verifier and its 37 reason-specific
adverse controls under the same 15-second readback budget. The verifier and
policy dependencies are bound to the declared source before and after reduction.
This actual-host headless contract supplements the 50-lifetime baseline. Exact
integrated hosted evidence, graphical output, physical devices and human play
remain separate qualification requirements.

## PLAY composable existing-host route — accepted course and five-rig slice

[PLAY-COMP-001 #273](https://github.com/techrote/cybersand/issues/273) was
completed by [PR #274](https://github.com/techrote/cybersand/pull/274),
merged on 2026-10-27 as `7500c1cc`. Its focused existing-host
Player Playground/SetP Acrobat integration passed 117 assertions and zero
failures on **each** of Linux and Windows, through the existing
`CyberSimulationWorker` plus **main-thread Rapier**. This proved the
feasibility of reusing the owner, not five-rig parity or frame pacing.

**Accepted five-rig #267 slice:** [PR #275](https://github.com/techrote/cybersand/pull/275)
merged on 2026-10-27 as `6c5b8b45df151e39a026ae23075ae4611826387c`.
The normal MicroScenario selector now admits the exact authored
`playground/player-course` layout in **Play** mode; **F5 → SetP** separately
chooses the stunt buggy, trials bike, acrobat, arcade lander or jet barrel.
The first actor's physical origin is source-faithful at
`(178, FLOOR_Y - equipment_clearance)` for the three ground rigs and
`(178, 304)` for the flight rigs. Normal MicroScenarios and all other
rig constructors retain their former spawn rules. Source-tree-identical
[Windows/Linux actual-host tests](https://github.com/techrote/cybersand/pull/275#issuecomment-6436394299)
passed **73/73 assertions on each OS**, moving each real mechanical rig
with native/physical ticks, actual Rapier terrain and copied worker state,
and preserving map identity across actor changes and reset.
[Native](https://github.com/techrote/cybersand/actions/runs/40452089685),
[Godot/GDExtension](https://github.com/techrote/cybersand/actions/runs/40452089898)
and [Docs](https://github.com/techrote/cybersand/actions/runs/40452089638)
CI succeeded for the tested tree. A passing headless test is **not**
interactive camera/lap/gamepad parity, worker parallel-speedup or subjective feel.

**Accepted #267 solver-policy slice:** [PR #276](https://github.com/techrote/cybersand/pull/276)
merged on 2026-10-27 as `e936489d5b731665bf3cbc102be986ca8d67b6cf`
with Git tree `506f7bf42eae5ddadad925feb686f74392a69a23`
identical to its qualified source head. Both [Windows and Linux actual-host
Godot/GDExtension jobs](https://github.com/techrote/cybersand/actions/runs/40469479950)
returned **87 assertions / 0 failures**, retaining the original course
rectangles, material IDs and recipe digest `9aa78894...`; the prepared
World applied Water `pressure_flow_v1` at construction with policy hash
`f67a65e8...` and immutable native receipt `f01864b2...`. The focused
regression checks generation 8 → 9 → 10, atomic controlled-route refusal,
reset and F5 Acrobat retention. Exact-source
[Native](https://github.com/techrote/cybersand/actions/runs/40469480069)
and [Docs](https://github.com/techrote/cybersand/actions/runs/40469479883)
also succeeded. This is a prepared rebuild option, **not** a hot solver swap
or exhaustive fluid-family validation. The subsequently triggered main
merge-CI remains a distinct execution record.

**Accepted #268 initial input/camera slice:** [PR #278](https://github.com/techrote/cybersand/pull/278)
merged on 2026-10-27 at `3dd28213231e434369356f4040445856faad69d4`.
The existing async desktop course reuses `CyberPlayerPlaygroundInput` for
keyboard/arrows and standard gamepad mapping, optional logical-key input,
neutral rearm and camera following the actual main-thread Rapier actor.
Both [Windows and Linux actual-host jobs](https://github.com/techrote/cybersand/actions/runs/40492528449)
passed **99 assertions / 0 failures** each, including quick arrow edges and
unchanged construction-time Water `pressure_flow_v1` policy receipts.
[Native](https://github.com/techrote/cybersand/actions/runs/40492528431)
and [Docs](https://github.com/techrote/cybersand/actions/runs/40492528439)
succeeded on the same reviewed integration tree. This does not establish
physical gamepad or manual gameplay feel.

**Accepted PLAY-UI-002 / #268 camera slice:** [PR #279](https://github.com/techrote/cybersand/pull/279)
merged on 2026-10-27 at `fc397c6f7ff9807610171a69e340af47f3e04f37`.
The mechanical course now uses its authored 256x128 close-follow viewport;
F toggles the exact `Rect2i(128,128,512,256)` panorama and back without
rebuilding the World. Other scientific/default camera controls retain their
original behavior. The [Windows/Linux Godot jobs](https://github.com/techrote/cybersand/actions/runs/40515691731)
each passed 115/115 actual-host five-rig assertions, with
[Native](https://github.com/techrote/cybersand/actions/runs/40515691552)
and [Docs](https://github.com/techrote/cybersand/actions/runs/40515691616)
green at exact reviewed head. No manual camera/feel claim follows.

**Accepted PLAY-UI-003 / #268 lap/HUD slice:** [PR #280](https://github.com/techrote/cybersand/pull/280)
merged on 2026-10-28 as `69e340d390e3e563833e80659aa97fddc2922310`.
Its accepted tree `63c6612fcaecdacad26452f7d15dfb118d410d9d` matches
reviewed head `8533876b` and tested checkout `eb84f71c`.
[Godot/GDExtension](https://github.com/techrote/cybersand/actions/runs/40600760606),
[Native](https://github.com/techrote/cybersand/actions/runs/40600760721),
[Documentation](https://github.com/techrote/cybersand/actions/runs/40600760603)
and [independent source review](https://github.com/techrote/cybersand/pull/280#issuecomment-6453690179)
completed successfully for that source. The prior parse failures remain in the
[retained audit](../audits/2026-10-27-play-ui003-exact-head-parse-failure.md).
The composable course's lap/HUD uses completed **native snapshot tick deltas**
for elapsed time and **completed main-thread Rapier steps** for the four ordered
checkpoint visits. The same host's `_physics_process` observes actual SetP
poses only after `physical_actor_session.complete_step()` advances its tick.
Its independently paced `_process` updates the visible HUD and native clock
without replacing or repeating physics-step gate credit. The native World is
never stepped or inspected directly from the UI. Timing begins on admitted
human input, pauses without catch-up and resets its visible session after
actor/World generation replacement. The tracker retains monotonic lifetime
fences to reject retired actor/World publications; per-rig bests survive
ordinary scene resets.

[Real-host cadence regression](../../godot/tests/test_play_ui003_physics_cadence.gd)
disables both automatic render/physics callbacks, then performs explicitly
completed **real Rapier** steps through entry and exit of an authored gate. It
uses bridge-based **test-only whole-assembly repositioning** to force that
short visit; this is an instrumentation fixture, not natural game travel.
A separate identical-host negative arm overrides only the new completed-step
sampling hook, proving the render-only path loses the transient visit. The
existing [five-rig integration fixture](../../godot/tests/test_play_comp002_five_rig_course.gd)
and [50-cycle model-only lifetime fixture](../../godot/tests/test_play_ui003_lap_clock.gd)
passed on both Windows and Linux: **41/0** real-cadence assertions, including
one matched render-only negative control; **126/0** five-rig assertions; and
**1,373/0** lap-model assertions covering 50 **model-only** lifetime cycles.
These are parent-source results, not qualification of a later combined branch.
They do not establish hardware gamepad behavior, interactive FPS, subjectively
acceptable camera/controls, or #269's fifty-real-host lifecycle campaign.
The remaining [#268](https://github.com/techrote/cybersand/issues/268)
scope includes final qualification of the integrated selector/rules described
above, complete focus and physical-gamepad qualification and real frame-pacing/feel validation.
The accepted four-checkpoint lap/HUD slice does not close those requirements.
Native Auto measurement history is retained under closed #266; remaining
lifecycle/stress and final desktop feel are #269/#270. Material swarms (#271) remain deferred in the standalone
seven-preset experimental scene. Specialist scientific and NPC-training
fixtures retain independent deterministic admission/execution.
No second native World owner is introduced; redundant #265 remains closed.

Sources: [course geometry and mechanical origins](../../godot/scripts/player_playground_course.gd),
[versioned MicroScenario catalogue](../../godot/scripts/microscenario_catalogue.gd),
[existing desktop admission](../../godot/scripts/main.gd),
[existing-host feasibility test](../../godot/tests/test_play_comp001_existing_host_spike.gd),
and [current five-rig/solver test](../../godot/tests/test_play_comp002_five_rig_course.gd).

## Accepted normal desktop lifecycle qualification

[PLAY-LIFE-001 PR #284](https://github.com/techrote/cybersand/pull/284) merged
on 2026-10-28 as `8288e580df90620640bd1f0b6aa774802f055d61`. Its accepted
tree `aa44de54df44a2640a437a5a10359615c50c28fe` exactly matches reviewed
head `d191dca5` and tested checkout `33babe9e`.
[Godot/GDExtension](https://github.com/techrote/cybersand/actions/runs/40634055217),
[Native](https://github.com/techrote/cybersand/actions/runs/40634055249),
[Documentation/provenance](https://github.com/techrote/cybersand/actions/runs/40634055172)
and a distinct [source/artifact review](https://github.com/techrote/cybersand/pull/284#pullrequestreview-5679054535)
passed. Both Windows and Linux completed **50 real host lifetimes and
1,165 assertions, zero failures**: ten lifetimes per SetP rig, with every
exclusive worker joined and final main-thread Rapier session retired.

The [actual-host helper](../../godot/tests/play_life001_shared_host_case.gd)
checks course/actor/terrain acknowledgment, native and Rapier clocks, real
keyboard button edges, focus cancellation/rearm, pause/resume, fresh reset
identities, immutable earlier snapshots and final retirement. Earlier
`294122c0` results retain their historical source identity; this combined
source received its own execution. This is bounded normal-lifecycle evidence,
with zero solver-reconstruction cycles and no slow-native injection.

**Open qualification:** #266 has accepted source-bound native participation and
repeated reference measurements through [PR #285](https://github.com/techrote/cybersand/pull/285),
as defined by the [threading contract](../architecture/simulation-tick-and-threading.md#play-native-worker-observation-and-reference-measurements).
The actual course control still reports max jobs one and zero parallel phases;
reference timing does not supply gameplay pacing or concurrent-execution proof.
#268 retains integrated selection and
complete device/focus/pacing requirements; #269 retains adversarial outstanding
work, delayed completion, broader course failure/recovery and stale-delivery/effect
stress. Its bounded populated-control and reference-body fault slices are
qualified separately below.
#270 joins those gates with actual desktop frame/snapshot timing and human
gameplay feel. Headless lifecycle success does not establish any of those
remaining outcomes. Main-thread Rapier, per-material construction-time solver
selection/refusal and specialist-fixture isolation remain unchanged.

## Actual-host solver reconstruction regression

**PLAY-LIFE-002 / #269 bounded regression:** the
[actual-host helper](../../godot/tests/play_life002_solver_case.gd) extends
the accepted lifecycle apparatus with five separate real SetP/main-host cases.
Each rebuilds Water to `pressure_flow_v1/reference`, resets that policy,
rebuilds to Current defaults (`freemass_v1` Water), then resets again.
Requested/applied native envelopes, policy and construction receipts, authored
recipe, newer actor/World/session identities and terrain acknowledgment are
checked, together with old Rapier retirement and retained immutable snapshots.

Each policy cohort also refuses the controlled actor-free route and submits an
unsupported Oil/pressure request through the public host API to the actual
worker/native transaction. Refusal closes the separately staged graph and
retains the accepted actor/World/receipt; the native and physical clocks and
primary input work afterward. These checks do not seed an outstanding old
command/lap immediately before replacement, inject delayed native work or test
failure recovery.

The [dated source/evidence audit](../audits/2026-10-28-play-life002-solver-reconstruction.md)
preserves the earlier local Windows proof and initial LFS pointer/import failure.
Fresh [Windows/Linux Godot execution 40751990374](https://github.com/techrote/cybersand/actions/runs/40751990374)
at source `0a17fd97`, tree `6fa58f168e93a64712f36706369e1f30f31232cb`,
passes **335 assertions / zero failures per OS** in five real processes:
ten policy changes, ten retaining resets, twenty explicit refusals and five
exclusive GDScript owner joins/final Rapier retirements per OS. The retained
worker reference means this join assertion does not independently observe native
pool destruction. Source review, final Native/Docs results, artifact readback and
the accepted-tree merge receipt are recorded on [PR #287](https://github.com/techrote/cybersand/pull/287).
Those gates remain distinct from this Godot execution result. No solver default,
live hot-swap, broader lifecycle or release acceptance is implied.

## Actual-host prepared-construction teardown regression

**Current PLAY-LIFE-003 / #269 test implementation:** the
[actual-host helper](../../godot/tests/play_life003_prepared_shutdown_case.gd)
holds a supported reconstruction at the existing native-prepared/physical-ready
precommit barrier. At least seven completed Main callbacks must progress before scene
exit; a bounded synchronization-only helper releases after the owner stop fence.
The actual accepted/staged Rapier graphs retire, the exclusive GDScript owner
joins, and only then may the test inspect the unchanged applied native receipt
and retired preparation token. Dropping retained references must destroy both
worker and native adapter objects, extending earlier joined-thread assertions.
The helper uses nonblocking Boolean `Mutex.try_lock()` so contention cannot
prevent deadline checks. A separate post-join arm holds the real worker mutex
on main, requires safety release without acquiring it, then always unlocks
before joining. Only this adversarial arm uses a 25 ms helper budget; actual
pending-construction shutdown retains 15,000 ms.

The [dated audit](../audits/2026-10-28-play-life003-prepared-shutdown.md) preserves
the original `22900486` local 135/0 proof, the later boundedness finding and
corrected-source `cd5f2ce5` 150/0 proof separately. Clean non-forced integration
`9782693c` consumes accepted #287/#288 main and receives its own local Windows
**150 assertions / zero failures**: five real hosts, five stop fences/joins,
ten Rapier graph retirements and five worker/adapter destructions, plus five
contended safety releases. Earlier results are not relabeled as this source.
Final source `92e0bcca` passed exact-head Windows/Linux150/0, Native/Docs and
distinct source/execution review before [PR #289](https://github.com/techrote/cybersand/pull/289)
merged as `91778603`, tree `3e513ab8b38a5d1d8076b5a4156d234f8d8a068f`.
The [accepted audit](../audits/2026-10-28-play-life003-prepared-shutdown.md#accepted-source-and-subsequent-main-verification--2026-10-29)
binds hosted artifacts and the separate passing main push runs. Earlier local
results retain their original source identities. This covers pending construction
cancellation; it does not hold native simulation jobs, inject a slow native
tick, observe an OS native-thread join trace, measure rendered pacing or supply
human feel. #269/#270 stay open.

## Populated command and lap retirement regression

**Current PLAY-LIFE-004 test implementation:** the
[actual-host helper](../../godot/tests/play_life004_populated_retirement_case.gd)
extends LIFE002's real Main/worker/Rapier apparatus across all five SetP rigs.
Before both supported pressure/reference reconstruction and policy-retaining
reset it starts a lap through admitted human input, observes positive completed
native elapsed ticks and visits the first authored gate through a completed
Rapier step. Test-only whole-assembly placement through the bridge forces that
visit; it is not natural traversal or a handling assessment.

An observed-identity human command must be admitted by the old session, and real
keyboard events must leave two ordered unconsumed primary edges plus held
movement immediately before replacement. The new active, unsuspended session
must reject that retained command specifically for `run_or_epoch`, preserve its
fresh control state and withhold held input until neutral rearm. Fresh input then
starts only the new lap. New actor/World/session identities, requested/applied
pressure policy/receipts, retained recipe, old graph retirement and immutable
prior snapshots remain checked. Test-only reinjection of a retained actual
snapshot into Main's copied presentation slot exercises its old-epoch lap fence;
it does not simulate a native delivery race or certify all rendering paths.

The [source/evidence record](../audits/2026-10-29-play-life004-populated-retirement.md)
records clean source `fc3143fa` passing local Windows **335 assertions / zero
failures**, ten populated transactions and ten old-command refusals, with all80
native and737 scoped tested inputs verified. Final source `d3ad406d` has
source-tree-matched hosted Windows/Linux **335/0 per OS** in
[Godot40797616577](https://github.com/techrote/cybersand/actions/runs/40797616577),
with184 applicable Windows cases and196 unique Linux cases passing.
[PR #291](https://github.com/techrote/cybersand/pull/291) accepted that source
as `5374a343`, tree `7172a4babc60cd2759f301774e8f28a44748809f`, after its
exact-head Docs/Native/Godot and distinct source/execution reviews passed.
The audit's [accepted receipt](../audits/2026-10-29-play-life004-populated-retirement.md#accepted-source-and-exact-head-hosted-qualification)
binds the source/CI/artifact identities, with earlier local probes kept separate. Existing
UI003 already covers one populated Jet Barrel reset; this adds populated command
retirement and all-five-rig construction/reset coverage. It does not establish
native-busy shutdown, failure recovery, equipment-effect replay, broad race/leak
freedom, physical devices, gameplay pacing or human feel. #269/#270 remain open.

## Actual Main native failure and ordinary recovery regression

**Current PLAY-LIFE-005 test implementation:** the
[actual-host regression](../../godot/tests/test_play_life005_failure_recovery.gd)
constructs real Main with the existing test-only active scheduling capacity1,
restores the setting before entering the tree, and proves healthy native and
three-reference-body Rapier steps first. Two public queued Sand emissions are
presented and acknowledged while paused; the next native attempt must raise the
actual capacity exception. The failed publication retains valid copied data and
the presented material image, pauses Main and refuses further emissions.

At least eight actual Main and physics callbacks must progress with no further
Rapier step/pose change after the **observed failure fence**. Resume/view changes
cannot unlatch the failed World; the exclusive owner stays available for ordinary
public R/reset. Reset advances native generation, clears diagnostics and resumes
healthy native/Rapier steps using the same three reference-body nodes/epoch0.
The whole stored material image is inspected only after owner join, checking
that the fixture's known Sand emissions are absent throughout the recovered
World, including outside interest and beneath masks.

The [source/evidence record](../audits/2026-10-29-play-life005-native-failure-recovery.md)
separates the working-overlay27/0 and29/0 probes from the final stronger
source's own execution, CI and review gates. Clean source79574a24 passes local
Windows30/0, including the complete stored-image check after join, with all80
native and738 tested inputs verified. Exact source `385e0307` subsequently passes
its own hosted qualification and distinct reviews: **30/0 on each Windows
and Linux OS**, with185 applicable Windows/197 Linux cases. [PR #293](https://github.com/techrote/cybersand/pull/293)
accepted that source as `4b6ca055`, tree `81bd8f5e1e083d4211a6aa9fe53d06979b015ccb`,
after all applicable exact-head Docs/Native/Godot and distinct reviews passed.
The [accepted receipt](../audits/2026-10-29-play-life005-native-failure-recovery.md#accepted-source-and-exact-head-hosted-qualification)
preserves original CI-checkout ancestry and all source-specific cohorts.
This exercises actual Main failure
and ordinary default-policy recovery, not the five SetP course rigs. Prepared
liquid construction still requires a healthy World; no prepared recovery or live
solver replacement is admitted. Source/platform qualification is separate from
slow-native/outstanding-job shutdown, arbitrary cancellation races, general
leak/race freedom, gameplay performance, physical devices and human feel.
#269/#270 remain open.

### Executed normal-load snapshot-handoff lock wait baseline (PLAY-WAIT-001)

The **unmerged, source-qualified** five-rig [test-only probe](../audits/2026-10-29-play-wait001-main-snapshot-mutex.md) uses actual Main/CyberSimulationWorker/main-thread-Rapier course execution with an instrumented, semantically equivalent `take_latest_snapshot` mutex acquisition. Windows/Linux [Godot run 40899843252](https://github.com/techrote/cybersand/actions/runs/40899843252) passes 16 assertions per rig, with 120 real native and Rapier ticks per rig, 290 Main callbacks and 289 complete callback intervals. Normal-load mutex-acquire p95 was 1 microsecond per rig. The same-source [Native run 40899843210](https://github.com/techrote/cybersand/actions/runs/40899843210) failed its first TSan 15-minute timeout but passed on explicitly diagnosed attempt 2; both attempts remain evidence. This measures only that handoff lock, **not** other Main waits, sustained rendered FPS, native jobs actually held, physical device/focus or human feel. No production, native runtime or solver default is altered. #268/#269/#270 remain open.

## Open the seven-preset movement course

**Current experimental source:** choose **Player playground** in the feature
launcher, open `res://player_playground.tscn`, or launch pinned Godot 4.7 with:

```text
godot --path godot -- --player-playground
godot --path godot -- --player-playground --player=acrobat
```

The optional player value is an ID from the table below. The course combines a
ramp, low tunnel, airborne slalom, landing decks and a material sieve in a
512 × 256 view of one native world. Four ordered checkpoints give each preset
a route and a simulation-time lap counter. The timer starts when active movement
or action input is admitted, including a quick press/release before the next
physics tick. Elapsed time advances only with simulation ticks and continues
while coasting with neutral input. Best times are kept only during this scene's
lifetime. Authored routes and
checkpoint detection do not establish that every route has been completed.

Five mechanical presets also appear in **F5 → Rapier → SetP**, among the
46 retained physical actor IDs and original eight sets. The separate 4LY
free-flight family appends a ninth **F5 → set4LY** selection group without
renumbering SetP or replacing this dedicated player playground. They reuse
the shared physical session, controls and optional equipment lifecycle in exploratory maps.
Dust Devil and Undertow are available only in this separate playground; they
control native material and have no Rapier actor definition.

Sources: [scene owner](../../godot/scripts/player_playground.gd),
[course and displayed controls](../../godot/scripts/player_playground_course.gd),
[mechanical catalogue](../../godot/scripts/player_actor_catalog.gd) and
[launcher](../../godot/scripts/feature_launcher.gd).

## Keyboard controls for all seven presets

In `--player-playground` (optionally `--player=ID`), use 1–7 or Tab/Shift+Tab
to select, R to restart, P/Escape to pause, F for overview/follow, and F2 for the
launcher. These scene controls accompany the movement actions below.

| Key / ID | Preset | Movement and actions |
|---|---|---|
| **1** / `stuntbuggy` | **Loose Cannon** — loose-jointed stunt buggy | W/S drive/reverse; A/D or Q/E lean and rotate in air; Space hops from support; Shift brakes; hold C for recovery assistance. Sprung wheels and a hinged rider carry the motion. |
| **2** / `trialsbike` | **Trials Rat** — trials bike | W/S throttle/reverse; A/D or Q/E lean; hold Space while supported to preload, then release to hop; Shift brakes; hold C for recovery assistance. The rear wheel drives and the front wheel rolls freely until braking. |
| **3** / `acrobat` | **Afterimage** — momentum acrobat | A/D run and steer in air; Space jumps, then double jumps; hold Shift or S to slide; tap Shift to roll; Shift+Space or S+Space bullet jumps; C cancels/brakes and, held in air, glides. Mouse position aims bullet jumps. |
| **4** / `arcadelander` | **Vector Rush** — arcade lander | W or Space fires the body-axis main engine; A/D or Q/E rotates; S gives reverse thrust; Shift applies a strong airbrake; tap C toggles damped flight/coast. |
| **5** / `dryswarm` | **Dust Devil** — Sand cloud | WASD guides actual Sand; Space surges in the movement direction, or upward from neutral; Shift spreads; C gathers. Neutral admitted input keeps the cohesion/loft field active. |
| **6** / `liquidswarm` | **Undertow** — Water blob | WASD guides actual Water; Space surges; Shift squeezes transverse to travel into a stream; C gathers. Neutral admitted input keeps the cohesion/loft field active. |
| **7** / `jetbarrel` | **Barrel Rocket** — barrel with jetpack | W or Space fires the body-axis jet; A/D or Q/E provides strong rotation; S gives reverse thrust; Shift brakes; hold C for upright assistance. |

Arrow keys duplicate WASD in the dedicated scene. The lander and barrel thrust
along their current orientation, so rotation changes the direction of the next
burst. Damping and recovery are authored game assistance with bounded forces;
contacts and rigid-body motion remain Rapier's responsibility. A cancelled bike
preload is discarded without firing a hop.

## Acrobat movement chains and cancels

Afterimage preserves momentum through a low-drag slide and uses actual folding
hip/ankle joints for its tucked posture. Steering during slides and rolls is
weaker than running; reversing input changes momentum gradually. A held crouch
can keep the tuck during a brief loss of support. The controller does not
teleport the body or replace its velocity with a character trajectory.

- **Run → slide → bullet jump:** gain speed with A/D, hold Shift or S to tuck,
  aim with the mouse, then press Space. Grounded bullet jumps include an upward
  component; faster velocity already aligned with the launch is retained.
- **Jump → double jump → roll → glide:** Space gives the ground jump and one
  airborne jump. Press Shift in air for the separate air roll. Hold C near the
  apex or while falling to reduce descent while steering with A/D.
- **Roll → jump cancel:** press Space during a roll to leave it using an
  available jump. If Shift/S remains held, the same press requests a bullet
  jump first while that separate launch is available. Release crouch for an
  ordinary jump cancel.
- **Slide/roll → brake cancel:** press C to end the slide or roll. On support,
  C brakes; slide stays suppressed until crouch is released. Releasing Space
  early shortens an ordinary jump. Q/E adds airborne attitude trim.

The controller supplies a short coyote window and input buffer. One airborne
jump, one bullet jump, one air roll and a finite glide reserve recharge after
confirmed support, not after focus changes or cancellation. Glide retains
positive gravity and has a finite duration; it is not hover. Exact timing and
actuation limits belong to the
[configuration reference](../reference/configuration-reference.md#player-playground-values).
Sources: [acrobat controller](../../godot/scripts/player_acrobat_controller.gd)
and [physical rig actuator](../../godot/scripts/physical_actor_rig.gd).

## Gamepad and quick scene controls

The dedicated scene samples the first connected standard gamepad. Its left
stick supplies WASD, A supplies Space/primary, B supplies Shift/secondary, X
supplies C/auxiliary, and the shoulder buttons supply Q/E trim. Start pauses.
The stick has a radial deadzone and is combined with keyboard input before
unit-length clamping. The mouse supplies aim while inside the play view;
otherwise movement supplies aim, with a diagonal fallback at neutral.
Gamepad mapping is implemented; physical controller qualification is separate.

**Accepted PLAY-UI-004 shared-course event slice:**
The normal desktop scene attaches a small main-thread
[gamepad event bridge](../../godot/scripts/playable_course_gamepad_events.gd).
When the existing course/human SetP capability gate is active, unhandled A/B/X
press and release events from the first connected pad invoke the existing
`publish_actor_keyboard_input` path immediately. This lets its existing bounded
physical-session FIFO retain a short tap between physical callbacks, rather
than relying only on the next polled state. Controls receive events first;
other devices, unmapped buttons and non-course/specialist configurations are
not intercepted. Focus, pause, reset, rearm, equipment and epoch authority stay
in the original host; the bridge never steps or owns any simulation object.
Analog stick/trim polling and standalone scene behavior are unchanged.

The [focused fixture](../../godot/tests/test_play_ui004_gamepad_events.gd)
uses genuine Viewport events and physical-session/Rapier steps, with a disclosed
synthetic selected-device index and test host publisher. It verifies ordered
button pairs and a matched no-event/poll-only negative control, not a physical
controller, the complete desktop focus path or interactive feel.
[PR #286](https://github.com/techrote/cybersand/pull/286) merged as
`e076819e086abb762796303b830314e330f87234`; its source-matched Windows/Linux
fixture passed **32 assertions per OS**. The later combined #284 suite
preserves that fixture. The
[dated candidate audit](../audits/2026-10-28-play-ui004-gamepad-events.md)
records the gap, test boundaries and integration obligations.

| Control | Scene operation |
|---|---|
| 1–7 or preset buttons | Select a preset and construct a fresh course/session |
| Tab / Shift+Tab | Select next / previous preset |
| R or Restart | Reset the selected preset and course; keep this scene's best times |
| P, Escape or gamepad Start | Pause/resume; pause revokes current input |
| F or camera button | Toggle course overview and player-follow view |
| F2 or Menu | Close the current owner and return to the feature launcher |

Selection, restart, pause and focus changes require movement/action controls to
be released before input rearms. Window focus loss, GUI focus or a mouse-button
press cancels pending control. Focus loss alone does not pause the physics;
uncontrolled material settles and mechanical momentum continues. Use pause to
stop stepping. The scene begins running after successful setup, unlike the
ordinary F5 map replacement, which begins paused.

Source: [local sampler](../../godot/scripts/player_playground_input.gd) and
[scene admission/rearm](../../godot/scripts/player_playground.gd).

## Native Sand cloud and Water blob ownership

The [playground runtime](../../godot/scripts/player_playground_runtime.gd)
exclusively owns one synchronous native World for a material preset. Setup seeds
256 Sand or Water cells. Each admitted step applies the native field before the
ordinary material tick; normal kernels still own gravity, Water flow and
reactions. Mechanical presets instead use the existing synchronous physical
arena and its main-thread Rapier session. Neither lane borrows the asynchronous
sandbox worker's World.

`World::apply_player_material_field` moves complete stored cells through
`relocate_stored_cell`, preserving compact state, temperature and exact partial
Water quantity within that call. It does not erase/repaint the cloud, create
per-cell physics bodies, or introduce a Water pressure/flow rule. The next normal
tick can redistribute Water and apply ordinary interactions. A field therefore
does not promise conservation across unrelated chemistry or authoring actions.

Selection is **matching material within a local radius**, not a persistent
collection of owned particles. Nearby environmental Sand/Water can join; material
that leaves the field is no longer controlled. The field follows the returned
quantity-weighted material centroid with a bounded centre adjustment. WASD moves
material rather than a remote selection cursor. The visible ring shows this
local selection boundary.

The native call scans at most 4,225 candidate positions within a radius-32
selection, captures at most 512 source parcels once, and attempts at most four
axis-adjacent moves per parcel. Stable ordering and phase-based scan rotation
prevent repeated source processing. Occupied cells, hard terrain, transient
bodies, world bounds and unavailable destination storage stop a step. No
occupied cell is overwritten. Invalid commands and failed/in-tick Worlds are
refused before mutation. Exact API, receipt and limits are in
[interfaces](../reference/interfaces-and-message-contracts.md#player-material-field-control)
and [configuration](../reference/configuration-reference.md#player-playground-values).

## Leases, reset and bounded authority

Mechanical input uses the shared version-2 physical action envelope. The
material lane uses version-1 `player_material_field_action`: run, epoch, actor,
sequence, actually issued observation and expiry all must match. Both receive
six-tick observation-relative human leases in the scene. The material lane
accepts one through six ticks; the shared physical API retains its own larger
admitted bound. A late response cannot extend a lease;
pause, cancel, reset, replacement or close revokes the old authority. The swarm
mode priority is C gather, then Shift spread/squeeze, then Space surge, then
normal cohesion/loft.

Neutral input is still an admitted, renewed command. If focus or the lease is
lost, the runtime stops calling the field entirely and the material follows its
ordinary native simulation. No field state persists in World. Copied receipts
and render packets carry the current reset generation; no mutable World storage
or Rapier object is exposed to the UI. Input cancellation clears future intent
without deleting momentum, replenishing airborne actions or releasing a bike's
stored preload. The [ownership contract](../architecture/data-ownership-and-lifetimes.md)
and [physical contract](physical-actor-rigs.md) own the shared boundaries.

## Circular wheels and qualification limits

The buggy and bike use real Rapier circles for hard contact and round visuals.
The existing native body ABI remains oriented rectangles: each circle is coupled
to materials through a conservative circumscribed square. That square can
occupy corner cells outside the drawn wheel, especially as it rotates. This is
an explicit approximation, not circular native rasterization or a generalized
shape-coupling change. See the
[coupling contract](../architecture/rigid-body-and-cellular-coupling.md).

The [original playground record](../audits/2026-10-20-player-control-playground.md)
preserves source/artifact identities, local Linux native/Godot checks and
failures. The [PR #189 completion record](../audits/2026-10-21-player-playground-pr189-completion.md)
adds original-head hosted Linux and actual Windows headless results and tracks
combined-source runtime and final-head gates after integration with GEN-003 main,
with the final exact-head outcomes recorded in PR #189's description and Checks. The
[build guide](../operations/local-build-and-validation.md#player-playground-checks)
routes focused regressions. Human feel on the target PC, complete checkpoint
routes, real gamepad/window-focus behavior and browser execution are not
established by headless tests. Actual Windows headless execution does not
establish interactive Windows feel. Generic body/granular, soliding and Water successor acceptance
retain their existing programme owners.
