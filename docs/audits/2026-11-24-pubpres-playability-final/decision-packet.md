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

## Competing implementation arms

| Arm | Bounded change | Required proof | Current decision |
| --- | --- | --- | --- |
| Occupied-mask bounds | Compute tight bounds once under the exclusive World owner; skip only obstacle probes outside actual occupied cells. | Exact material/physical/contact/conservation parity, changed-bound tests, sanitizers, matched ordinary gameplay. | Local semantic parity passed; one-body large-canvas timing promising, small-canvas tails and eight-body results prevent a broad winner claim. |
| Three Full-image slots | Add one persistent spare, update it before rotating current/previous, rebuild exact histories on structural refusal. | Actual current/previous GPU bytes, source/engine identity, fixed resources, all rotations, World changes and ACK ordering, matched physical comparisons. | Explicit experimental selector; default remains two. Hosted qualification pending. |
| Recovered EGL handoff | Clear the cached current window after releasing the EGL context so the receiving thread can bind it. | Original engine artifact/source/patch/API/dependency custody; real rendering-owner observation; exact image histories; isolated stock-Safe/patched-Safe/patched-Separate comparison. | Known source repair; new identical-policy performance qualification pending. |
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
