---
title: Completed-step material admission experiment
status: Current
document-kind: audit
scope: Source implementation and bounded local correctness checks; no graphical or gameplay selection
canonical-for: []
last-reviewed: 2026-11-24
related-documents: [../../operations/pubpres-playability-final-001.md, ../../architecture/rendering-and-gameplay-bridges.md, ../../reference/configuration-reference.md]
---

# Completed-step material admission experiment

This is a separate **default-off, Draft/HOLD** continuation of source
`c2f8a73d34448bc1496ecd84bca02f0812c80d27`. It preserves the frozen source,
Target, two/three-slot, Early/Combined, native-rendezvous, same-frame-continuation
and 30/60 Hz deadline controls. No default change or performance selection is
made. Actual independent completed Rapier observations remain the required
physical witness.

## Question and mechanism

The existing time deadline may admit every material packet when Main already
runs more slowly than 30 or 60 Hz. This separate experiment asks whether omitting
an entire accepted Full2 material transaction on an available Main turn allows
the next genuine native/terrain/Rapier transaction to finish sooner. A deferred
packet performs no CPU image patching, content-history comparison, Image
duplication, `ImageTexture.update`, material timeline advancement or upload ACK.
Main still consumes independent physical snapshots, drains collider work,
processes input and authoring, and updates the camera and coherent overlay.

This differs from the retained Target negative: reducing submission-call time
while retaining staging, target writes and history work did not establish a
physical gain. The new arm omits selected upload transactions, but it still
draws the viewport and may only move a wait into rendering or synchronization.
Lower upload counts are not a success criterion. Material and selected-pose age
can worsen while physical throughput improves; the submitted-pose sidecar,
independent physical gaps and actual input/application observations must decide.

The first-offer anchor is deliberate and differs from the 30/60 Hz policy's
prior-accepted-upload anchor. For an illustrative 83ms Main cadence, with native
responses ready before each following physical callback, the actual method order
would be:

| Main opportunity | Genuine completion and material action |
|---|---|
| Initial upload | Step `n` is complete; actual upload establishes anchor `n`. |
| About83ms later | Physics completes `n+1`; idle then offers newer material. Its first-offer deadline is now+16.667ms, so the same turn omits that upload. |
| About166ms later | Physics completes `n+2`; idle replaces the pending cumulative packet and accepts it once. The original deadline is also overdue by roughly66ms. Both eligibility conditions and actual overrun are reported. |

This is a source-derived example, not a measured performance result. If the
second real completion is absent, expiry still flushes at the next Main
opportunity with no added physics credit. If two real completions already exist
before the first offer, that offer uploads immediately. The first capture must
therefore establish actual deferrals/replacements and physical, material and
pose outcomes; the requested interval alone cannot establish an exercised or
beneficial treatment.

## Authority, bounds and immediate paths

`CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL=2` is the sole enabled value. It requires
explicit `CYBERSAND_MATERIAL_PUBLICATION=full` and two image slots. Selecting
the existing 30/60 Hz deadline disables this new policy with an explicit reason.
Changing to an actual unsupported publisher retires the pending packet without
ACK and requests a fresh full publication for the original immediate path.

The helper retains at most one immutable cumulative worker packet. Its identity
contains the current Workbench session, epoch, authoritative World generation
and actual bridge ObjectID. A replacement packet cannot move either the step
anchor or first-offer deadline. The step witness is a read-only observation of
the active initialized Main-owned bridge: `physical_actor_session.tick` must
equal Main's completed-step field, with a valid completion clock. The helper
anchors that step and `bridge.manual_step_count()` only after an actual accepted
upload. A fixed counter offset is allowed; their nonnegative deltas must agree.
Wrong types, a reset or disagreement produce immediate publication without a
count anchor. No callback count, actor generation, timer expiration or native
sample serial can supply physical credit.

The **scheduled added-hold deadline is 16,667 microseconds after the first
offer**. A separate one-second source-age guard can shorten it. Already old,
unknown or future source clocks receive no fresh waiting budget. Expiry drains
on the next available Main opportunity, even if no physics step or mailbox
publication occurs. It does not bound actual wall-clock holding, visible age or
scanout while Main stalls. Status records actual hold, deadline overrun and
maximum observed overrun. A native/Main interval longer than the scheduled hold
can make the following opportunity expire the hold before another completion,
adding material age without physical benefit. Initial/paint/World/source-age or
already-satisfied count bypasses can instead make the policy effectively inert.
The length of a Main interval alone does not determine whether a first offer is
held; merely requesting count2 establishes no effective coalescing.

Initial/new-World material, paused operation, absent/incompatible physical
ownership and transitions preserve immediate progress. Failure, owner/session/
epoch/bridge retirement, reset, texture recreation and rejection clear pending
authority. The original upload function receives the exact selected packet.
Only actual serial advancement and matching accepted World complete the helper.
Deferred serials receive no ACK. If a selected transaction is cancelled during
history recreation, Main separately reports an actually accepted upload after
policy cancellation; the ordinary upload/ACK trace remains authoritative.

Every successful ordinary disc or explicit-cell footprint admission re-arms
paint priority, including soft Sand with no hard-surface revision change.
Successful precise Paint edits and Art chunks make the same presentation-only
notification. Rejected and empty commands do not. Copied worker state also
covers queued/inflight legacy work, precise Paint and Art receipt ownership.
A new edit retires any earlier idle observation. Priority clears only after an
actual accepted material packet generated after the new observed-idle clock.
An already displayed edit can conservatively leave priority armed through a
static period if no newer packet is generated; this preserves immediate future
publication and never invents material completion.

## Correctness evidence and remaining gates

Local execution used exact official Linux Godot
`4.7.stable.official.5b4e0cb0f`, executable SHA256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The native-independent policy fixture passed **123 checks**, including fixed
counter offsets, malformed/mismatched counters, replacement deadlines, late
Main drain, source age, same-tick bridge recreation, paint re-arming and refusal.
The actual Main identity/queue fixture passed **47 checks**, including twelve
owner/failure cancellations, fast already-idle Sand in all three ordinary brush
branches, no hard-revision change, stale accepted serial, actual missing-texture
refusal/full resync and publisher retirement. No body or native edit was
executed, no GPU upload occurred and no Rapier step was credited by these tests.
The existing deadline Main authority fixture still passed 25 checks; the retained
Art deferred-manual regression passed 14 checks.

Local `git diff --check` passes. The documentation checker reports six missing
companion-repository expected-fact paths (Q01/Q04/Q28/Q29/Q30), including
`SOURCE-PROVENANCE.json`, the Web/local development notes, `tools/dev.py` and
browser-results evidence outside this checkout. It reports no new local link or
heading error. Those missing sources are not replaced or treated as a pass;
the integrated documentation/provenance gate remains separately required.

The new graphical fixture uses the production cumulative worker journal and
actual Main upload/ACK methods. Its completion witness is explicitly synthetic;
it cannot qualify physical progression. It requires seven first-read GPU pairs:
20/empty, 24/20, 25/24, new-World30/25, recovery33/30, paused34/33 and ownerless35/34.
It deliberately leaves ACK24 unobserved before appending25, so replay of the
21/22/24/25 prefix must still produce exact previous/current bytes. Hosted
graphical execution and an independent Python byte/authority oracle are pending.

Independent source reviewers challenged fast-edit admission, actual publisher
scope, strict counter types and the distinction between accepted transactions
and cancellation counters. These are resolved in source and bounded tests;
review is not rendered acceptance. Required next gates are source-exact Full2
history qualification and matched off/count2/count2/off ordinary Wave512 and
current-Wave2048 captures, with the same native runtime, engine, observer and
real-step reducer. Both held/withheld pose freshness and material age remain
mandatory, including sustained painting/multiple-actor confirmation if an arm
survives the primary comparison. All negative results must remain available.

## Engine scheduling alternatives

The pinned Godot source is `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`.
[`Main::iteration`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/main/main.cpp)
already executes genuine physics and idle work before the rendering sync.
[`RenderingServerDefault::sync`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/servers/rendering/rendering_server_default.cpp)
waits for a queued barrier in Separate mode. Its draw call emits pre-draw,
queues the actual render work, and later delivers post-draw through Main's
deferred queue. That deferred notification has no immutable draw/material join.
[`CommandQueueMT`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/core/templates/command_queue_mt.h)
stores copied commands in a growing buffer without a consumer-capacity admission
result. Removing sync while Main keeps producing uploads, canvas and shader
commands therefore supplies no bounded queue. Removing idle work would suppress
ordinary input, camera, authoring and collider maintenance.

Native rendezvous waits for an eligible native sample; same-frame continuation
reuses an already admitted physical callback. Both preserve different earlier
dependencies and are retained controls, not names for a new render-owner fix.
The font Image snapshot patch repairs an ownership race, not engine scheduling.

A distinct bounded engine experiment is conceivable: a consumer completion
token could admit at most one additional complete Main producer turn, followed
by the original barrier. Actual draws alone would advance draw counters and
signals. Such an arm still needs explicit command/material lifetime bounds,
interpolation-state admission, shutdown/forced-draw coverage, exact engine
custody and matched ordinary gameplay. It can retain the final long stall or
worsen queue age. No unrestricted nonblocking sync change is source-proven here,
and no engine scheduler patch is silently included in this material experiment.

The necessary observation boundary is an internal render-owner token completed
after the queued renderer work for its identified submission has actually
returned, with release/acquire visibility to Main. A copied queue-pending flag or
Main-delivered `frame_post_draw` is insufficient. Any token covering a producer
batch must also distinguish later queued material/canvas commands, so completing
an old marker cannot authorize an unbounded newer backlog or starve new draws.
Main's `increment_frames_drawn` and force-redraw reset must remain conditional on
an actual admitted draw. Only that draw emits `frame_pre_draw`; its actual render
completion schedules one `frame_post_draw`, with submitted and delivered counts
kept separate. This token still would not measure physical display scanout.

An immediately repeated Main turn may have no newly due physics callback and no
new eligible native sample. Neither extra waiting nor manufactured callback
credit can make it productive. Publication work that already blocks before the
sync also remains blocking. Those limits make this a distinct prospective
experiment after repaired-engine owner qualification, rather than a claimed
solution derived from source inspection alone.
