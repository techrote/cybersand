---
title: PUBPRES Completion renderer and lifecycle review
status: Historical
document-kind: audit
scope: Exact Linux renderer and mounted Workbench observations, independent source review, and remaining Windows qualification
canonical-for: [evidence-pubpres-completion-renderer-review]
last-reviewed: 2026-11-22
related-documents: [../../operations/pubpres-completion-001.md, ../../operations/pubpres-playability-evaluation.md, ../../architecture/rendering-and-gameplay-bridges.md]
---

# PUBPRES Completion renderer and lifecycle review

Review source was local `71065da1c0e59b48352c54d9561be859275127ea`, tree
`e520a91e0a9e11da067a10bc086196fad9749cbb`. The implementation and qualification
contract is in the [Completion handover](../../operations/pubpres-completion-001.md).
Earlier component and pre-join runs retain their own identities below. The
review disposition is **Draft/HOLD**. Windows renderer and owner NVIDIA
execution were pending for this review.

## Publication and ownership

The [Main intake](../../../godot/scripts/main.gd) validates complete render
metadata and payload before mutating the CPU picture. Accepted uploads rotate
the two history references, bind consumers and advance the accepted serial. A
publisher structural refusal rebuilds both histories from the exact CPU bytes
before ACK. A rejected packet requests a complete refresh and retains the
previous accepted upload watermark.

The [worker](../../../godot/scripts/simulation_worker.gd) retains the journal
until it observes an ACK. It bounds future ACKs by the currently published
render serial and keeps its lifetime serial monotonic across native World
replacement. A complete baseline stays immutable when it is the sole payload.
Appending a delta detaches it into the mutable owner journal. A requested
refresh or new World bypasses the optional ACK diagnostic gate. The World
generation advances only for accepted replacement. A worker pause receipt
requires the corresponding pause intent and a turn without a native tick.
Physical publication checks native health before exposure and Main admits only
the matching owner, sample and installed terrain for its real Rapier step.

The [two-plane timeline](../../../godot/scripts/workbench_material_timeline.gd)
clears its previous receipt on World generation change. A source-audit finding
at `71065da1` is that the default requested-Hz fallback in Main can re-enable
the previous plane for a same-size World replacement. That path receives a
fresh blend clock while reusing both physical texture slots. The measured
timing path keeps the timeline's one-plane decision. This is distinct from the
accepted generation fence and the vapour-history reset.

The [focused intake fixture](../../../godot/tests/test_workbench_material_world_blend.gd)
reproduced the defect at the original source with one failure in ten assertions.
Generation 43 and render serial 3 were accepted and ACKed in order. The
previous physical plane still had the exact generation 42 bytes and the
timeline's previous receipt was empty. At that instant the legacy policy
reported `snapshot_blend=0.0` and `previous_blend_active=true`. Measured timing
reported `snapshot_blend=1.0` and `previous_blend_active=false`. Both policies
resumed blending after an actual generation 43 predecessor.

Main repair `90a5010e7fa2d700178f4d149a562235b16e628d` preserves the
timeline's zero previous contribution when a Workbench upload has no exact
same-World predecessor. The focused fixture independently passed all ten
assertions after the repair. Specialist fixture update `a4afbc02` preserves
genuine native previous receipts in the existing controlled timer scenarios.
The actual graphical Kestrel guard passed 37 assertions. The headless native
Needle contact, dense and temporal presentation fixtures passed 141, 3,422 and
573 checks respectively. Their expired/active clock controls, old-only material
obstructions, native PAINT/erase and invalid-receipt withholding remain covered.

The focused `71065da1` lifecycle controls passed render-payload validation,
retained ownership and explicit ACK, 24 native/R8 World-generation assertions,
112 material-delivery timing checks, 30 actual native-failure quarantine and
ordinary-reset assertions, and 26 graphical vapour-history assertions. The
failure fixture's native capacity refusal was the expected stimulus. The
worker kept the previous valid publication and stopped real steps until the
accepted reset. The visual test separately verified that a same-World full
refresh preserves vapour and a generation change resets both vapour planes.

## Renderer correction and evidence

Pinned official Godot `4.7.stable.official.5b4e0cb0f` executable SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`
ran Linux OpenGL Compatibility with Mesa 25.0.7 llvmpipe. The local runtime
used a source-projected Linux GDExtension built with GCC 14.2, SHA-256
`a842d77977644ea330d826710ac7cf50a7b1150f0e8b65a27101e481e73b06ae`.
The active Linux Rapier LFS binary SHA-256 was
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
The local container required a cookie-authenticated per-process Xvfb TCP
display. Runtime trials used fresh data and cache directories.

The preserved `d316c281` isolated fixture reproduced a Safe R8 two-slot final
first-current read with four stale pixels. Its previous plane and immediate
second current read matched. The bounded policy in specialist commit
`241ab0fea1c8f94b43a844b223b5807eed4ed73e` directs the existing 1×1 retirement
draw to sample the just-written history into the distinct, existing sink. The
default retains staged-source retirement. No added texture or draw is required.
This is evidence of an ordering sensitivity around the original retirement
and first read. The tests leave driver-internal promotion and completion
timing unobserved.

| Pinned Linux graphical case | Outcome |
| --- | --- |
| Safe staged control | 23 ordinary, 9 of 12 queued. Three queued first-current failures and the aggregate parity failure. |
| Safe target | 3,237 assertions, all 23 ordinary and 12 queued cases. |
| Separate staged control | 23 ordinary, 5 of 12 queued. Seven queued first-current failures and the aggregate parity failure. |
| Separate target | 3,249 assertions, all 23 ordinary and 12 queued cases. The independent engine startup/upload negatives remain in the qualification ledger. |
| Production Main `transition_2048_w1` | Full, stage and target each accepted revisions 31–210. Each verified both complete planes at every revision and all 15 sparse re-entries. The target test also passed at combined source `1f2cccb9`. |
| Combined Wave Follow 2048² development pair | Stage and target each delivered 144 actual steps with exact trajectories, accepted samples, terrain fences and terminal history hashes. Other local work overlapped these runs, so the 33.302 and 25.680 second capture lengths remain advisory. |
| Mounted camera and actor presentation | 1,703 ordinary and 1,730 rotating Follow checks passed at `cd3327a2`. The optional rotation fixture observed 12 actual steps above 14 radians/s and 12 matching rotating overlay transforms. Guarded Free and Follow at `1f2cccb9` each completed 220 real steps with 20 Fire insertions and eight framebuffers. |

The renderer-only full–stage–target–target–stage–full run used six completed
180-revision processes, identical decoded final framebuffers and exact final
history hashes. Frame p95 in that order was 8.613, 15.536, 13.992, 14.747,
12.836 and 7.368 ms. Publication-call p95 was 1.985, 1.767, 7.040, 7.145,
1.561 and 1.788 ms. The two blit treatments held 28 logical texture identities
and 80,150,533 logical texture bytes. Godot reported 109,098,662 render memory
bytes in every sampled blit frame. The actual process peaks were 840.98–841.85
MiB for blit and 775.86–777.07 MiB for full. The run excluded overlapping team
compiles and graphical runs. A read-only partial-clone traversal may have
produced some background Git I/O. Frame timestamps represent software callback
delivery. The target policy addresses the first-read failure, while relative
stage/target frame performance remains mixed.

The actual Safe hold fixture at `1f2cccb9` passed all 64 checks in the quiet
replay. Across the fixed 150,000 μs windows, combined and early modes delivered
11 and nine genuine callbacks with zero and one physical admission. A concurrent
development replay explicitly failed the early deadline. Its first callback
began at +158.269 ms and the first process observation occurred at +171.788 ms.
The later real step did not replace the failed deadline.

## Sustained ordinary Wave Workbench

The [sustained fixture](../../../godot/tests/pubpres_sustained_renderer.gd)
extends the existing real-owner observer with a separate input tape. It mounts
ordinary current-Wave Workbench with a 2048×1024 authored basin, a Needle and a
barrel. The tape goes neutral at actual physical step 144. During the timed
capture, ten prescribed pulses enqueue a live Fire or Smoke brush, request a
complete native resync through the existing worker control and switch Free or
Follow with zoom/pan. Startup and terminal framebuffer and full material
readback occur outside timing.

The exact local run used `71065da1`, with new fixture file SHA-256
`1a33548ae6a48124ff94a0facd886d0b51b20844eb05e7bcdbb31d196effd679` and
authored setup SHA-256
`d765948142a57d8076d8796150a16a4d854c6c9d4131a50443f4c9aa65cde4c6`.
One target-retirement run completed 65.125 seconds, 1,331 actual manual Rapier
steps and 368 steps after 45 seconds. The four-worker owner observed four
participants in 245 of 246 sampled native dispatches and three in the other.
Its final native Wave total was 2,664 rounds. The actor and World remained
healthy. Both terminal GPU planes matched their CPU histories on the first
reads, and every recorded real step retained the exact terrain and feedback
fence. The camera switched between Free and Follow at 480×270 and 960×540 views.

| Actual interval | p50 / p95 / p99 / maximum, ms |
| --- | --- |
| Rapier completion gap | 44.029 / 88.414 / 124.828 / 318.832 |
| Frame callback delivery gap | 43.727 / 66.290 / 130.825 / 250.147 |
| Accepted material publication gap | 43.775 / 88.043 / 122.206 / 306.593 |

All ten complete native publications were followed by accepted sparse native
packets of 25,426–60,914 bytes. Each of those live re-entries staged the full
4,194,304-byte RG8 plane in the publisher. The detached 180-revision oracle
exercises the distinct copy-and-patch case with smaller known dirty coverage.
The sustained run retained 25 publisher texture identities and 38,207,493
logical texture bytes across 33 samples. Godot reported 67,710,598–78,285,650
render memory bytes while the view and effects ran. The actual process high
water mark was 1,272.22 MiB. These are separate measurements of engine-accounted
storage and process residence. Results cover one instrumented local profile.

Reproduce on a checkout containing the fixture with source-matched Linux
native/Rapier binaries and the pinned engine. Run from a real private display
with a fresh profile and an evidence output directory. The repository's
[process campaign helper](../../../tools/pubpres_playability/run_campaign.py)
supports 250 ms working-set sampling against the actual executable PID.

```sh
CYBERSAND_SOURCE_REVISION="$(git rev-parse HEAD)" \
CYBERSAND_MATERIAL_PUBLICATION=blit \
CYBERSAND_DIAG_MATERIAL_RETIREMENT_SOURCE=target \
CYBERSAND_DIAG_PHYSICS_PUBLICATION=early \
CYBERSAND_DIAG_PRESENTATION=coherent \
CYBERSAND_DIAG_MATERIAL_TIMING=measured \
CYBERSAND_DIAG_NATIVE_RENDEZVOUS=0 \
CYBERSAND_DIAG_SAME_FRAME_CONTINUATION=0 \
"$pinned_godot" --path godot --rendering-method gl_compatibility \
  --rendering-driver opengl3 --audio-driver Dummy --render-thread safe \
  --script res://tests/pubpres_sustained_renderer.gd -- \
  --fixture=landscape2048x1024 --workers=4 --receipt="$evidence/receipt.json"
```

The local process sampler bounded execution at 175 seconds including setup
and close. The fixture's measured wall window is 65–95 seconds.

## Source-matched sustained renderer comparison

The four-process local comparison froze source
`d4fb48040f530e0c5d69b466d018ee7ac37a27a0`, including the World history repair.
One fresh private display and profile ran at a time. The workload, pinned
engine, same-source native runtime, actor input tape, four native workers,
early publication, coherent pose, measured material timing and Safe OpenGL
thread mode were shared. The material publication order was full, corrected
target-retirement blit, corrected target-retirement blit, full. Rendezvous
and same-frame continuation were disabled.

Every arm completed 65.004–65.006 seconds, witnessed ten accepted dense to
sparse native transitions and matched both complete GPU histories on their
first terminal reads. The authoritative body, installed terrain and sample
tuples agreed through all 1,418 steps common to the four processes. Camera
and material pulses used the same wall-time schedule. The separate pilot
tape was addressed to actual steps. Each row retains its own distribution.

| Actual Workbench outcome | Full A0 | Target B0 | Target B1 | Full A1 |
| --- | ---: | ---: | ---: | ---: |
| Completed Rapier steps | 1,444 | 1,442 | 1,418 | 1,431 |
| Rapier gap p95 / p99, ms | 61.242 / 99.171 | 61.701 / 94.312 | 76.856 / 92.723 | 63.880 / 95.521 |
| Rapier maximum gap, ms | 179.574 | 149.194 | 103.661 | 122.383 |
| Rapier gaps of at least 100 ms | 14 | 7 | 3 | 6 |
| Frame callback gap p95, ms | 56.735 | 56.699 | 60.798 | 55.202 |
| Publication call p95, ms | 1.311 | 6.495 | 6.667 | 1.353 |
| Godot process high-water working set, MiB | 1,250.36 | 1,272.05 | 1,274.96 | 1,250.65 |

Both blit arms held 25 publisher identities and 38,207,493 logical bytes
through their sampled lifetimes. The full arms held two material texture
identities. Engine-reported video totals during zoom switched within
30,049,243–40,624,295 bytes on full and 67,710,598–78,285,650 on blit.
Full retains the default. Corrected blit lowered the observed physical p99
and maximum in each nearest full/blit pair. The physical p95 and callback
results were mixed, and both blit processes had larger high-water marks.

In the final full arm, the longest physical gap lasted 122.383 ms. The
matching native result completed 15.436 ms after the prior Rapier step,
leaving 106.947 ms until the next observed Rapier step. The real solver took
0.584 ms. The one overlapping material call took 1.104 ms. The balance is
unattributed. Software callback and wall-call measurements leave graphics
driver completion and physical adapter memory unobserved.

The original arm logs, input ledger, capture and memory samples, receipts,
event traces and local reduction are indexed in the 32-member
`PUBPRES-COMPLETION-001-sustained-renderer-d4fb4804.zip`.
Archive SHA-256 `b9d7e75bfdd18e3c4dd47d17e05e52030436cdcbcf89730976425234d96ba70d`.
Reduction SHA-256 `1f557ece3b9091e410b18fa183fcfe440025e909af79191bd89fb2adae4ac4e6`.

## Main-thread callback blackout

The final full comparison arm's raw trace joins the 122.383 ms handoff from
step 158 to step 159. The material wall call finished at +2.096 ms and
application Main returned at +2.739 ms. The matching healthy native tick
completed at +15.436 ms, with the first usable handoff at +16.141 ms and the
same installed hard terrain. The inline post-draw signal for that process
frame arrived at +91.405 ms. The next physics callback started at
+115.353 ms and admitted that tick. It was the first application Main or
physics callback after readiness. The earlier application Main callback
had already returned by the time the native result was ready.

A separate diagnostic used the same stock engine, mounted source, native
runtime, settings and Full Safe path. A fixture subclass bracketed the
startup and terminal framebuffer captures with clock anchors. An external
sampler read the actual Godot main task through Linux procfs at a nominal
3 ms cadence. The diagnostic ran 65.009 seconds and completed 1,431 real
physical steps, ten actual dense-to-sparse transitions and exact terminal
history reads. The anchor endpoints required a 3.091 ms clock-alignment
envelope. Counts use observations inside that conservative envelope.
The sampler used 4.876 seconds of its own CPU during the process lifetime.
These results are for attribution outside the four-arm comparison.

At step 1262, the physical gap was 107.721 ms. The matching native tick
completed at +18.390 ms and the first matching handoff arrived at
+19.823 ms. The inline post-draw signal arrived at +73.629 ms, followed
by the next physics entry at +100.005 ms without an intervening Main or
physics callback. Ten of 15 sampled main-task observations between native
completion and post-draw showed the Linux futex wait channel and syscall.
Three of six after post-draw showed the polling wait channel and syscall.
The enclosing counter readings bound main-task CPU service to at most
30.973 ms across the 81.615 ms from ready to next physics entry. Guest
run-queue wait increased by 0.048 ms over the enclosing readings.

Two further gaps repeated the sampled pre-draw futex and post-draw polling
pattern. This identifies actual main-task blocking across a stock inline
render frame with an exact native result already available. The readings
leave the futex owner and graphics completion unobserved. In all 33 in-capture
thread inventories the guest allowed nine CPUs and Godot had 57 tasks,
including nine named llvmpipe workers. The container exposed no CPU quota
or throttling counter.

The archived procfs samples, output, clock anchors, fixture extension and
receipt reduction are in `PUBPRES-COMPLETION-001-scheduler-full-d4fb4804.zip`.
Archive SHA-256 `d296fb6aa5eac2f8fe7d827ce83abc29aead08a15743d87717b90b47072d9e71`.
Reduction SHA-256 `5cb278c4b9da6be79bfe351c6c18c462fcb463b4a4bdb1d3a60eb688608e3b9e`.

## Linux software-renderer worker-count sensitivity

Four more fresh Full Safe processes used the same `d4fb4804` source,
runtime and authored Wave tape. The llvmpipe worker setting was absent in
the first and last arms. The two middle arms set `LP_NUM_THREADS=4`.
The fixture subclass read actual task names and process working set at
the before and after framebuffer boundaries. The external scheduler
sampler was disabled for this comparison. Both inventories verified
9/4/4/9 named llvmpipe workers and 57/47/47/57 Godot tasks on the same
nine-CPU guest affinity. The native solver's four-worker participation
was observed in at least 96% of sampled dispatches in every arm.

Every arm ran 65.010–65.044 seconds and witnessed ten actual native
dense-to-sparse transitions and exact first reads of both complete GPU
histories. Physical body, sample and terrain witnesses matched through
all 1,021 steps common to the four processes.

| Actual Workbench outcome | Default A0 | Four B0 | Four B1 | Default A1 |
| --- | ---: | ---: | ---: | ---: |
| Completed Rapier steps | 1,430 | 1,025 | 1,021 | 1,430 |
| Rapier gap p95 / p99, ms | 61.803 / 91.221 | 82.866 / 104.142 | 81.329 / 92.363 | 64.182 / 94.899 |
| Rapier maximum gap, ms | 136.847 | 187.974 | 125.015 | 117.284 |
| Rapier gaps of at least 100 ms | 4 | 11 | 5 | 7 |
| Frame callback gap p95, ms | 58.044 | 82.846 | 81.446 | 56.209 |
| Joined native tick p50, ms | 14.494 | 10.548 | 10.403 | 14.511 |
| Native completed to observed Rapier step p95, ms | 37.598 | 69.823 | 71.102 | 36.522 |
| Godot process high-water working set, MiB | 1,255.89 | 1,250.54 | 1,254.90 | 1,250.90 |

Limiting Mesa to four workers reduced actual step throughput by 28% and
slowed frame delivery in both pairs. The exact matched native ticks finished
sooner while eligible results took longer to reach an observed Rapier step.
The default llvmpipe setting was restored. The result is specific to the
local Linux software adapter and worker counts.

The 33-member `PUBPRES-COMPLETION-001-llvmpipe-workers-d4fb4804.zip` indexes
all four original outputs, traces, framebuffers and process inventories.
Archive SHA-256 `fd89d114f04792116118a549421cd1322c4f03ce679052951e085ae134a69792`.
Reduction SHA-256 `6a741ae81a7159be270e43de5eb4b59f2180ed21e3b60e13f8855e58019e689d`.

## Targeted hosted Linux renderer controls

The original targeted artifact `14774018047` ran frozen source
`1aaacaa6ca7038eb469012719af1a4b8473c8cc8` with official Godot 4.7 and Linux
Mesa 25.2.8 llvmpipe. Corrected target retirement passed 3,237 Safe and
3,249 Separate reachability assertions. The Separate actual threaded
publication fixture passed 128 checks. The Safe run recorded 224
transition-history, 87 rectangular staging and 1,730 rotating camera
assertions. Actual Safe material pixels and all ten World-blend checks
passed. The Separate result covers these exact Linux conditions.

The 65.001-second sustained Safe corrected-blit trace contains 890 actual
Rapier steps, 890 advancing physics callbacks and 889 accepted material
uploads. Both terminal planes matched exactly on their first reads.
There were ten native dense-to-sparse re-entries and 245 of 248 sampled
dispatches observed all four native participants. Actual Rapier gap
p95/p99/maximum was 92.977/106.651/113.431 ms. This is a hosted correctness
sample from one instrumented profile.

The Safe reachable tile fixture's process returned zero but its original
log reports two GDScript errors. Its 33×19 test World has no reachable
64×64 sparse atlas. The test used that absent atlas, so both storage-format
owner checks stopped early. The strict host harness rejected the raw log.
Fixture repair `2569df6d2` uses the actual full staging resource for a
foreign same-shape array mutation and requires both format sections to
finish. Pinned same-source local Safe Eager and Reachable checks passed
1,985 and 1,982 assertions, including both owner sections and all eight
shader comparisons. Original reachable log SHA-256
`a8c01327b4c11c2002cc731f22caf178e5470dc5ead5cf0d2747ce7e911b96b6`.
Original targeted ZIP SHA-256
`d5817bcb29bd6c91e3067679e308ca598cdd4f34787957fe0f78731f7ea61fe2`.

Both original Safe graphical author runs reached Save. Both fresh-process
reopen runs verified native saved state and failed the superseded assertion
that a prior Art prompt reenters live model context. Accepted
ART-SESSION-LOG-001 requires separate session audit files. The repaired
fixture at `601f8fcd3f4aa1805a829e262bfecfb9d5555479` passed pinned local
graphical 512×512 author and fresh-reopen runs with both continuation
selectors. Each pair passed 210 author and 67 reopen assertions. All four
prepared native material hashes matched
`52e3a94accff0bc8498412b740f3c4381717dc5c4bec3501194e847b3ae1eaab`.
Both profiles retained the exact original post-shutdown root JSONL and
created an independent six-event root log containing the fresh marker.
The 31-member archive `PUBPRES-COMPLETION-001-art-author-reopen-601f8fcd3.zip`
indexes the logs, source evidence, screenshots and independent JSONL checks.
Archive SHA-256
`8c5095c1166e6a7e494d8badab4f60ce7382a316b04d54b928955d7b7d33df0d`.

## Original targeted Windows graphical results

The Windows checks artifact `14775586372` ran frozen `1aaacaa6` in Safe
ANGLE on the Microsoft Basic Render Driver. Target-retirement staging
passed 3,237 assertions. The 224 transition-history, 87 rectangular
staging and ten World-blend checks passed, along with actual material
presentation pixels. The reachable tile fixture repeated its original
Linux script error. Both installed and source author/reopen pairs
executed their native save reconstruction and repeated the same retired
cross-session Art assertion.

The original camera test passed all 12 fast Follow rotations and matching
overlays and the actual renderer picking grids. Six fixed-hover assertions
failed across the three resized windows. The logged cursors
`[154,83]`, `[115,55]` and `[77,53]` agree with an ambient window point
`[512,384]` under each retained renderer transform. The fixture's direct
Workbench input had assigned a different test point without changing the
system mouse. Camera fixture repair `5d78d9d3e` isolates ambient viewport
input only during that controlled hover and restores its prior setting
afterward. It retains an unguarded viewport overwrite control, attempts
the same ambient event during each actual resize, and records both
observed pointer and independently expected cell.

The repaired pinned Linux run passed all 1,732 assertions and retained
12 verified rapidly rotating overlays. A scratch run with isolation
disabled repeated exactly the six original Windows failure strings and
three cursor cells while measuring the alternate pointer. The
`PUBPRES-COMPLETION-001-camera-input-isolation.zip` archive retains the
original Windows log and both local controls. SHA-256
`ea8c951579766762b97cece835568450a9841d07fceae59ab717d5eb0ecc7847`.
The repaired fixture requires its own Windows run.

The separately timed Windows 2048×1024 Safe corrected-blit run completed
636 physical steps in 65.132 seconds, 275 accepted uploads and ten
dense-to-sparse transitions. Both terminal GPU planes matched on their
first reads. Rapier gap p95/p99/maximum was 224.882/422.111/608.601 ms.
There were three gaps of at least 500 ms. In the longest gap, application
Main returned at +11.305 ms, the native result completed at +15.484 ms and
the exact handoff arrived at +16.547 ms. The same inline post-draw callback
arrived at +606.805 ms and the next physics callback started at +606.922 ms.
The overlapping submission call took 3.817 ms and the solver took 0.217 ms.
The gap is an observed host callback delay on the software adapter.

Both Separate Windows processes ended during GLES3/GLAD initialization
with access violation `0xC0000005`, before any fixture completion. They
remain separate experimental startup failures. Original Windows checks
ZIP SHA-256
`064fbcf07d67e186279933e267e29d9db3ed0217130599d56e878e7ce6adade3`.

## Original artifact identities

Original logs, GPU captures and receipts were retained separately from the
repository. Paths below are relative to the local `pubpres-renderer-evidence`
directory.

| Evidence | File | SHA-256 |
| --- | --- | --- |
| Original Safe first read and raw pixel capture receipt | `baseline-safe/receipt.json` | `fcccb766595c712b8ae8aab6734a2e66fa6f14e727f0c47cad75084427d7e08e` |
| Original World-blend negative | `world-blend-original/raw.log` | `fb821d2943191f65a1e701227a73bffa33ef0082282b3ad8bbf8428982d3dfca` |
| Repaired World-blend proof | `world-blend-fix-test_workbench_material_world_blend/raw.log` | `a7b0b5cfb19c4baead881dc1c2b66d4e7d06bdf75d0dd5993d7177845d7df60c` |
| Repaired graphical production pose proof | `world-blend-fix-test_pr593_mask_coherent_production/raw.log` | `4b3df8b7c32e1e9c9d4517a7f65120071e4e9e00081cdd47368b16c7416f7a14` |
| Repaired native contact proof | `world-blend-fix-test_workbench_temporal_contact/raw.log` | `d5c4e430765690e20e8a9a785be83b7c1d717b07e2deb160899d128e1ed4eb9a` |
| Repaired dense temporal proof | `world-blend-fix-test_workbench_temporal_dense/raw.log` | `43b3934281d0cf189a470b0e517ee0bb36d9aae03ab3a03e880af1f329a24062` |
| Repaired temporal presentation proof | `world-blend-fix-test_workbench_temporal_presentation/raw.log` | `6d28ca472712d93b9a1095adcd5df4e723f9f662dfea8a208ed16f7b3a5999fd` |
| Safe staged strict negative | `complete-staging-safe-stage-0/raw.log` | `bdd9fd0755867a5505dcd1c22c63e14b9208fca6f7b980351e3d18f20dcd898f` |
| Safe target strict positive | `complete-staging-safe-target-0/raw.log` | `d397e21f965b43b791fe2b8955079b0b3272d4bddeb3ca5de878a5af761d1d4e` |
| Separate staged strict negative | `complete-staging-separate-stage-0/raw.log` | `d0c986f297cee8cd4f523086697960029ca66f3998635ab41554e2f559e52efe` |
| Separate target strict positive | `complete-staging-separate-target-0/raw.log` | `6f3862ccd14413917a0102700d6bbeaaa03f84f6445ecb7953d307d6447c7ab2` |
| Combined 180 dual-history proof | `combined-pubpres_source_transition_oracle-audited/receipt.json` | `fe1067edd18ba7ac2a82c682abb57db023e32ebfa8e5e8160db26b8372222995` |
| Six-process timing and memory reduction | `isolated-transition-summary.json` | `1688c58739104a579e860b2e5f3ecec0feb1dfd51618e6ef67b5810ddd623501` |
| Concurrent callback deadline negative | `combined-test_workbench_physics_publication-traced/raw.log` | `ac3eb27624c8a1e6ffabf8ce02b2ea8a8cd33ff7569c2f22b847d464d34175ef` |
| Quiet callback deadline positive | `combined-test_workbench_physics_publication-traced-paused-peers/raw.log` | `d1b7db670e8c13f1253cca948a243510509617714b3db5a53f11496f47b8c8ed` |
| Rotating Follow receipt | `checked-rotating-follow-1/native-pixel-camera.json` | `01b081fafd68de02a5bdfbb3f469dac1e819ddb53d011ad02a7d8223d117b432` |
| Wave Follow stage development trace | `combined-pubpres_source_gameplay-stage/receipt-events.jsonl` | `9728c3468abb3a40340ca6240d0cdd0ffdfdcda0d813720a8fefb1a082c6771d` |
| Wave Follow target development trace | `combined-pubpres_source_gameplay-target/receipt-events.jsonl` | `a77c2bcf5418b3a387a118a8ee18d3dc61fe85e9a01e4029bf2a1e850404fcea` |
| Sustained actual process log | `sustained-target-a/raw.log` | `b0c03ff02afe12a7fe3f2118c09cfc390f1f5cb077e86f028f85eaffdcc2494d` |
| Sustained Workbench receipt | `sustained-target-a/receipt.json` | `1304e49b2e8c6150c440ec1c540dff7b2983889e7988114f6ad2c180b6b7205f` |
| Sustained actual event trace | `sustained-target-a/receipt-events.jsonl` | `68c740cff49a9535225ac83bda19c88e094e418e91cc45202d774e22623f4933` |
| Sustained Godot process memory | `sustained-target-a/process-memory.jsonl` | `23c4e4a638e7fe503248890f67480a7d61b691398b8a02ce3e70d1a59c940eb7` |
| Exact World-generation controls | `lifecycle-test_render_world_generation/raw.log` | `4ed931eb8b82db33e08f979d85613ceeb6de17200d49c4086e7061fd7af68cc9` |
| Real failure quarantine and reset | `lifecycle-test_play_life005_failure_recovery/raw.log` | `1075c69e6e2d7887e3add195dbedcb25d8d99a0768a611321e26e43b7089e65a` |
| Graphical vapour-history controls | `lifecycle-test_material_vapour_pipeline_render/raw.log` | `e5465f34d8cf9bd41ba5f7ad8a47dc5c37432169255fe78fed1c1354d8eea29b` |
