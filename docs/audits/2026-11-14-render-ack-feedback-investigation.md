---
title: RENDER-ACK-001 — acknowledgement/refresh feedback diagnosis
status: Draft
document-kind: audit
scope: Opt-in transport trace, exact full-refresh cause labels, ACK-held native regression
last-reviewed: 2026-11-14
related-documents: [2026-11-13-render-upload-investigation.md]
---

# RENDER-ACK-001 — acknowledgement/refresh feedback diagnosis

**Draft/HOLD. Instrumentation only; retain the production `ImageTexture` path.**
Issue [#577](https://github.com/techrote/cybersand/issues/577) is the canonical research
ledger. This isolated branch starts directly from accepted main
`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`.
Do not merge, retarget another owner's branch, or attribute separate #578/#566
hosted measurements to this source.

## Mechanism identified in the accepted baseline

1. Main acknowledges **only after accepting the texture publication**, including
   actual `ImageTexture.update()` submission. Reading a worker status snapshot is
   not an acknowledgement.
2. The worker publishes the most recent immutable status snapshot in one slot;
   Main can miss older status snapshots. Until a serial is acknowledged,
   `_append_native_render_packet` **concatenates** new native patch metadata
   and payloads onto the pending unacknowledged material batch.
3. At `_publish_snapshot`, an ACK for the latest pending serial clears the
   batch. A delayed ACK therefore leaves multiple pending native updates
   accumulated. The worker falls back to `take_render_snapshot(true)` when
   either strict threshold is exceeded:
   - **more than 256 pending rectangles**; or
   - **more than 2 × max(default World area, Workbench area) pending bytes**.
   The thresholds are absolute backlog limits, *not percentages of dirty cells*.
4. Independent full sources also exist: initial render, accepted World
   replacement, Main's explicit refresh request (including recorder start and
   rejected/malformed upload), native `RenderSnapshotExchange` capacity error
   (status 3), native-internal full refresh, and GDScript fallback. Native
   exchange Backpressure (status 2) is a separate cause and retains dirty
   state; it is **not** worker pending-capacity overflow.
5. The native source's `CapacityExceeded` path is distinct from the worker's
   `MAX_PENDING_RENDER_PATCHES` guard. Native full packet construction copies
   the whole World. The renderer may independently submit the entire
   `ImageTexture` for **every** accepted compact patch.

The observed #578 Windows hosted pattern (many full native packets with the
slow `ImageTexture` path, none with the candidate) is **consistent** with
an ACK / pending-backlog feedback loop, but the older campaign did **not**
record the ACK/overflow cause fields. Timings alone do not prove that cause.

## Opt-in diagnostic event custody

Launch an ordinary desktop Main scene with:

```powershell
& C:\Godot_v4.7-stable_win64_console.exe --path C:\CyberSand-RenderAck\godot --rendering-driver opengl3 -- --render-ack-trace
```

With `--render-ack-trace` omitted, no trace buffer or file is active;
existing renderer, serial admission, native simulation and pacing are unchanged.
The worker's bounded 4,096-entry ring contains copied values only and does
not write from its thread. Main polls every 0.5s, writes an append-only JSONL
session file under Godot's `user://`, and flushes on clean scene exit.
The console prints `RENDER_ACK_TRACE_PATH` with the absolute path.
If the worker ring overflows, `trace_ring_evicted` makes the report nonexhaustive.

Each event contains a monotonic microsecond timestamp. Main observes:
incoming status/render serial, World generation, native payload size, full flag,
publication age, texture-upload duration and outcome, ACK issue, and explicit
full-request reason. The worker observes ACK receipt/latch delay and pending
clear; native status, full flag, bytes, patch count and request origin; pending
accumulation; strict overflow threshold and unacknowledged backlog age.
No material cells, screenshot data, tokens or private map contents are logged.

Reduce the observed file:

```powershell
py -3 tools\render_ack\analyze_trace.py "C:\path\printed\by\Godot\render-ack-....jsonl" --output render-ack-analysis.json
```

The report separates:
- `pending_capacity_escalation` (256-rectangle/byte threshold), with
  precise strict trigger, acknowledged serial, pending age and counts;
- `native_capacity_exceeded` (native status 3);
- `explicit_request` (recording, rejected payload, other Main request);
- `world_generation_changed`, `startup_or_reset`, native-internal full refresh;
- `native_exchange_backpressure` (status 2, not a full packet by itself).

A slow Main publication may cause an ACK to arrive after the next worker
snapshot, but the trace must establish that sequence before attributing a
specific full refresh to ACK latency. `Time.get_ticks_usec` measures
application clocks, not GPU DMA or screen scanout. Tracing adds overhead, so
do not compare traced runs as unaffected performance benchmarks.

## Qualification gate and follow-up

`tools/render_ack/qualify.py` runs pinned Godot 4.7 native headless
tests on source-matched Linux and Windows runtimes, preserving all logs and
receipts. `test_render_ack_feedback.gd` checks strict thresholds,
immutable trace readback, monotonic ACK, real native sparse edits with ACKs,
and deliberate withholding of ACKs to provoke the pending-capacity fallback.
The existing render-patch handoff regression is an independent control.

The next measurement is one traced Windows software-rendered native workload
and one traced actual NVIDIA/Windows Workbench session using the same scene,
plus untraced duration comparisons. Do not implement coalescing, alter ACK
semantics, or adopt #578's RGBA8 prototype merely because the backlog guard
has been demonstrated. A fix needs explicit previous/current texture
correctness, refused-packet safety, bounded memory, and both Windows/Linux
qualification.


## Hosted qualification and actual-graphics causal reproduction — 14 November 2026

**Direct native controls:** [run 43559555814](https://github.com/techrote/cybersand/actions/runs/43559555814),
executed source `c73ccc8c3cde08a7be5b31c9ffb7ac452c17e1cd`, pinned Godot
`4.7.stable.official.5b4e0cb0f`. Windows and Linux both passed:
Godot import, original unmodified render-patch handoff, and the new native
ACK feedback regression (**575 assertions, zero failed, per OS**).
With acknowledgements withheld after an initial accepted startup publication,
the native worker recorded an escalation first from `pending_rectangles`
(exceeding 256) and then `pending_bytes` (full snapshot plus
subsequent small patch), with three total native full packets. An earlier
deliberately retained failed attempt used scattered test coordinates where
a repeated/no-change edit prevented the controlled backlog; the corrected
fixture alternates immobile material IDs on a confirmed writable cell.

**Real graphical Main/worker control:** [run 43559956383](https://github.com/techrote/cybersand/actions/runs/43559956383),
source `6ee6c1f947d984fa56b44e4868b3b1fb9bfbbcad`;
[original Windows ANGLE artifact](https://github.com/techrote/cybersand/actions/runs/43559956383/artifacts/14099662472).
Both arms execute the pre-existing `bench_render_copy_publication.gd`
over **240 frames, 120 accepted native pulse commands**, including an ordinary
World reset halfway through. It mounts the real Main scene, actual native
worker, original production `ImageTexture.update()` and temporal
two-texture path. Exact final native→CPU and CPU→texture bytes and the original
benchmark's readback controls passed for both arms. The only deliberate
causal difference is whether the benchmark worker forwards Main's ACK to the
ordinary worker:

| Measured quantity | N: normal ACK | W: all ACKs withheld |
| --- | ---: | ---: |
| Accepted native edit commands | 120 | 120 |
| Main accepted compact native patch publications | 92 | 0 |
| Main accepted full native payload publications | 1 | 88 |
| Native full packets (including startup/reset) | 2 | 91 |
| Native full packets caused by pending-capacity recovery | 0 | 89 |
| Worker overflow events | 0 | 89 |
| Trigger of overflow events | None | `pending_bytes` (all 89) |
| Worker ACK arrivals | 94 | 0 |
| Lost trace events | 0 | 0 |
| Final CPU/native and GPU/CPU equality | PASS | PASS |

The W arm starts with an unacknowledged full plane (2,097,152 bytes at the
native default 1024² RG8 extent). The next ordinary **2-byte** patch raises
the pending batch to **2,097,154 bytes**, strictly greater than its
2,097,152-byte limit. The worker requests another full native copy;
while that new full remains unacknowledged, another tiny delta does the same.
The source-bound trace recorded all 89 occurrences as
`pending_capacity_escalation` with `pending_bytes` reason.
It did not attribute these to native exchange capacity, explicit user
request, GPU shader history, or a World generation reset.

The N arm accepted its ordinary post-upload ACKs; it had **zero** pending
escalations despite using the same complete-image GPU texture update method.
It still spent a substantial amount of CPU call time submitting
`ImageTexture.update()` (p95 237.752 ms among accepted compact
payloads), but the edit cadence allowed ACKs to catch up. Therefore a slow
texture call alone is **not sufficient** to assert a feedback loop; the actual
unacknowledged packet sequence and thresholds matter.

This hosted renderer was **ANGLE/D3D11 Microsoft Basic Render Driver** with
software graphics; no NVIDIA hardware or completed GPU-transfer metric is
claimed. The deliberately ACK-withheld arm is an adverse causal control, not
an ordinary configuration, so do **not** interpret its shorter 240-frame
wall-clock duration as a performance improvement. In both arms, the standard
renderer still submits a complete GPU texture update for every accepted
material change; “compact patch” refers to **native World transport**, not
rectangular GPU uploads.

**Additional instrumentation refinement:** after this qualifying source, the
Main event for an issued ACK was moved immediately before the worker call
rather than after it, so the reducer's ACK-call→receipt measurement is
meaningful. This timing-only source change needs its own exact-head result
before it is described as qualified.

## Narrow optimization candidates (not implemented)

1. **ACK-aware native snapshot pacing / backpressure:** while a pending render
   packet remains unacknowledged, let native dirty state accumulate in its
   existing canonical owner instead of repeatedly capturing, concatenating and
   copying full payloads. A new ACK would admit a fresh capture of the latest
   state. Investigate impact on publication age, initial/reset handling,
   recording and native exchange capacity.
2. **Coalesce superseded pending patches:** retain one exact latest-value region
   per dirty chunk/tile instead of every sequential copy of the same cells.
   Preserve last-write order across overlaps, bounded packet capacity, serial
   and generation fences, and exact previous/current texture history.
3. **Maintain a bounded final-state fallback** on true native capacity
   exhaustion, explicit full resync, new World generation, or impossible
   compaction. Never ACK merely because the CPU Image accepted a patch if GPU
   submission has not passed the normal acceptance boundary.

The next implementation should compare (1) versus (2) under the exact same
real native edit sequence, measure native full copies, pending serial age,
frame pacing, mutation provenance and RAM, and include an adversarial
renderer-upload rejection. No change is authorized by this diagnostic PR.
