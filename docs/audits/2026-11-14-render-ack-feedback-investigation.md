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
