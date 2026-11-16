---
title: Workbench freeze remediation completion follow-up
status: Historical evidence
document-kind: audit
scope: Source-bound continuation from3da6; controlled desktop renderer overlap and publication ownership, without physical acceptance or merge authority
canonical-for: []
last-reviewed: 2026-11-16
related-documents: [2026-11-16-physics-freeze-remediation-002.md, ../architecture/simulation-tick-and-threading.md, ../architecture/rendering-and-gameplay-bridges.md, ../operations/camera-stack-coherence-acceptance.md]
---

# Physics-freeze remediation completion follow-up

## Revalidated starting point

PR609 remained open Draft at `3da6ea884a4c9157c6689f7ed1baabc8935f78cd`,
tree `ecfc80a81bb4b842d9663c5a0fee322ebfd51190`. Accepted main remained
`018bd09503d7f079ddac52e225c2f7daf8d678bf`. All four dependent PRs remained
Draft/HOLD, unmerged and without auto-merge. The prior exact-source application
run43909363577 was successful but did not meet the freeze target. The original
c1ad control and previous negative measurements remain in the preceding audit.
Native/Rapier compiler inputs, runtime hashes and official Godot4.7 remain
unchanged; no physics law, fixed timestep or feedback-age protection is relaxed.

The local results below identify immutable working-source bookends over3da6,
not a claim that the3da6 commit already contains this follow-up. Final committed
source, exact-head Linux/Windows jobs and package checksums belong to the
[PR609 delivery ledger](https://github.com/techrote/cybersand/pull/609).

## Publication ownership and bounded transfer repair

The preallocated128-tile rectangular class uses16 by8 tiles. At2048² RG8,
65–128 changed tiles submit4MiB instead of8MiB. The22 texture RIDs represent
79,659,013 nominal bytes with the normal three-resource ring,12,582,912 bytes
more than the previous design. The123-tile fixture uses eight exact copy runs
and2,015,232 destination pixels instead of a whole4,194,304-pixel copy.
Full-size updates/fallback remain available; there is no production GPU readback
or per-publication allocation of staging textures. Exact GPU histories, NPOT
edges and stable resource identities passed the expanded1,838-check fixture.
Some isolated copy-fixture timings regressed; reduced bytes are not a claim
that all publication or gameplay tails improve.

Queued RenderingServer calls may retain the Image object. Four full-material
create/update sites now submit immutable Image snapshots. The deterministic
separate-render negative had10 real history failures in111 assertions; the
fixed source passed111/0 and Safe83/0. The earlier111/11 attempt included two
watchdog failures and nine history failures and is retained separately.

Actual Main initially crashed in both separate-off and separate-fixed16 before
any usable timing. Disassembly placed the assertion in GLES texture upload's
empty COW data access, but did not identify the particular texture. The supported
startup `gui/theme/default_font_generate_mipmaps=true` selects the engine's
copied-atlas path. Changing only that setting in the exact crashing project
allowed both full144-step captures to finish. This is a workaround observation,
not proof of the crashing RID. Safe99/0 and Separate197/0 font tests verified
actual nearest-filtered UI pixels and queued atlas ownership. Review added
CPU-to-GPU and exact-reference assertions; the amended test must pass the final
source-specific gates. Mipmap generation adds CPU work and texture storage.

A31-file/15-producer inventory found the same persistent-Image hazard in the
shared Depth surface reachable through F2. Its two create/update calls now also
submit immutable snapshots. Original Separate71/4 exposed four wrong
intermediate GPU images despite correct final images; fixed Separate71/0 and
Safe67/0 preserved all final appearance pixels. No Web, WORM/DRIV3R, Wave Flow
or generator implementation was changed. The Web-only producer is outside the
qualified desktop navigation path; a global renderer-default change would need
separate consideration.

## Scheduling cause and bounded implementation

Pinned engine source shows that Main runs a batch of scheduled physics callbacks
before its unconditional RenderingServer queue synchronization. Without a
rendezvous, the first Rapier step can publish its native sample and the remaining
catch-up callbacks immediately return while that sample is pending. A long
render interval then delays the next admission even when native work completed
much earlier. This is avoidable admission latency, distinct from native tick
computation, terrain work or Rapier solver work.

A fixed16.667ms wait increased completed-step averages but worsened physical
p95 and frame cadence in both Safe and Separate trials. It remains an explicitly
selected rejected-performance control, not a normal default.

The renderer-aware policy queues at most one native Semaphore marker in the
first actual callback of a process frame. A bound Variant retains the Semaphore
until the native-only render callback returns, including owner retirement.
Later already scheduled catch-up callbacks may wait for the exact native sample
only while the marker is pending, sharing one66,667µs deadline with250µs polls.
Marker consumption is latched; backlog refuses new queue growth. Safe rendering
adds no such wait. All ordinary owner, epoch, session, generation, feedback and
complete-terrain gates are repeated before a fixed1/60 Rapier step.

This uses otherwise outstanding renderer work; it does not create callbacks,
physics time debt, speculative physics or extrapolated poses. Godot still
synchronizes each Main iteration, so graphics and physical callbacks are not
fully independent. A marker certifies earlier RenderingServer calls returned,
not GPU completion, scanout or a displayed frame identity. Separate-thread
post-draw delivery is explicitly unassociated with Main's current frame.
Requested deadlines are cooperative; OS descheduling can exceed wall bounds.

## Focused matched local trial

All arms used the same774-file project, official engine, native libraries,
2048² Needle geometry,11-entry completed-step tape, Fire ON/OFF at0/60,
Auto0 workers (resolved capacity4), strict native wait/wake, normal window,
startup VSync and identical observer configuration. Linux used X11 and
Mesa25.0.7 llvmpipe on the available EPYC9V74 host. Timings are wall elapsed,
including possible waits and descheduling; no isolated CPU/GPU attribution or
physical NVIDIA acceptance follows.

The matched common prefix is144 actual completions,143 gaps. Columns are
achieved rates and milliseconds, never configured FPS:

| Mode | Native/s | Rapier/s | Main/s | Gap median | p95 | p99 | Maximum | Gaps≥100ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| safe-off | 7.449 | 7.454 | 7.448 | 128.075 | 161.165 | 172.685 | 175.179 | 143 |
| separate-off | 8.373 | 8.380 | 8.430 | 117.084 | 144.907 | 149.779 | 157.337 | 143 |
| separate-overlap | 29.685 | 29.759 | 8.070 | 23.926 | 70.567 | 90.832 | 98.188 | 0 |

Every recorded body position/orientation/linear velocity and native/terrain
association is exact across the144 shared steps. Main frame p95 worsened from
143.404ms in Separate-off to153.336ms in overlap; maximum178.046ms in Safe,
154.144ms in Separate-off and175.256ms in overlap. Graphics remain constrained
by software rendering. Native completion-to-admission median fell from95.557ms
in Separate-off to3.322ms in overlap, p95122.929→48.747ms.

The unchanged capture requires both ten wall seconds and144 completions.
Overlap therefore recorded322 actual steps, including178 extra steps beyond
the common prefix. Its complete321-gap distribution still had zero≥100ms,
p9566.432ms and maximum98.188ms, with31.859 completed steps/s. Those extra
states are preserved but have no matching control states and are not included
in the equivalence claim. The full trace contains221 successful waits;95 are
inside the shared prefix. All join unique actual admissions. Its85 recorded
markers are distinct and all latch, queue-growth and deadline checks pass.
Most natural waits reach the cap while rendering remains pending; controlled
queue tests separately exercise completion during a wait. The277.937ms first
marker observation includes delayed Main observation and is not render duration.

Source bookends for the three-arm capture:

- `godot/scripts/main.gd`: `06adf8af8217f1ff86a70f911fe6229125bd7a171af26d729e1bd806e1124ae5`.
- `godot/scripts/workbench_native_rendezvous.gd`: `300743e3ea0a4b2baa9b4bed812eefdbc3f6a99a08d78258ee39d6badac3495f`.
- `godot/scripts/blit_material_publisher.gd`: `dda4a78e1ad4e056af46eb717b0b5305c50ad5f2ded647dec06f4ec2b05674b8`.
- `godot/project.godot`: `4fa79b6bb6a2796893f15e63c41a6e1838140d96ebe31fbb48731b1db83b65ca`.

Raw trace SHA256 and complete file/engine/native/harness ledgers are in
`render-overlap-development/summary.json`; the stricter read-only reduction
retains all whole-capture statistics without rewriting that original report.
Independent raw review is `render-overlap-three-mode-review.json` plus its
full-capture addendum and the scheduling engineer's `actual-main-review.json`.

## Failed attempts and qualification boundary

Retained negatives include the original queued-material and Depth history
failures, both full Main separate-render crashes, the fixed16 frame/tail
regressions, the original font-test scope before its oracle amendment, and
two26/1 marker-lifetime oracle attempts caused by test-owned VM temporaries.
The corrected ownership-scope test passed26/0 Safe and34/0 actual Separate;
all original source/logs remain. The actual Main fixed16 integration passed113
checks; that fixture alone does not qualify the overlap policy.

The follow-up adds actual GPU/history/font/Depth gates, finite authoritative
state validation, marker/admission checks, reverse-order Linux/Windows comparison
and installed-package checks. Successful engineering gates must be attached to
the final exact source. No local result alone promotes a default or grants
physical acceptance. **PHYSICAL HOLD** remains mandatory until the owner tests
the delivered source on physical Windows11/NVIDIA. All four PRs stay Draft/HOLD
and unmerged; no auto-merge or Ready promotion is authorized by this record.
