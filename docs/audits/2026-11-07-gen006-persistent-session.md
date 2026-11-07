---
title: GEN-006 persistent native World / opt-in Godot controller
status: Planned
document-kind: audit
scope: Experimental one-owner sharded native Worlds; no production shared-World admission
last-reviewed: 2026-11-07
---

# GEN-006 persistent native World and Godot controller

This experimental successor to [#486](https://github.com/techrote/cybersand/pull/486) addresses the biggest remaining usability defect in the first visual demo: **restarting the entire native World process on each user input**. It does not alter the already-qualified #486 source, its coordinate safety guard, or production native/Godot adapters.

## Implementation

- The new native command-line executable is built from native/tests/gen006_persistent_stream.cpp and the existing real World/Generator source. Launch with --serve SAVE_ROOT CONTROL_ROOT [1|4].
- A **single long-lived** native process retains its 1–2 actual native World shards, advances real simulation approximately once every 100ms regardless of user inputs, and preserves state through automatic checkpointing every 2.5 seconds, synchronous eviction, explicit SAVE and clean exit. No unlimited rate catch-up.
- Godot scene godot/tests/gen006_persistent_stream_demo.tscn owns an asynchronous, bounded atomic-file mailbox. It NEVER calls OS.execute per frame or per edit. Native is the only World owner; Godot consumes copied 64x64 RGBA frame bytes with native frame sequence, completed tick, coordinate, resident count and actual observed worker count.
- Commands: FOCUS, WALL, DIG, WATER (amount and temperature), PAUSE, RESUME, STEP (up to four ticks), SAVE, STATUS and QUIT. At most one IPC command is outstanding; Godot queues at most 16.
- The native mailbox publishes up to 12 rotating immutable frame files and replaces an atomic state receipt only after a frame is completely written. A heartbeat detects owner loss; a shutdown marker requests final native save on window exit.
- A cross-process single-writer save-root lock directory refuses parallel owners. In the event of an abnormal process crash, verify the old process has ended before manually removing a stale .gen006_session_lock. Do not run two sessions against the same save root.
- Existing #486 LRU, receipt verification, native CYPS save, edit intent and restore-coordinate guard remain the source of truth. Normal controls: arrows move one signed 64x64 chunk; Shift+arrows jumps 24 chunks; left/middle/right mouse paint Wall/Water17/dig; Space pauses/resumes; S saves; R requests readback.

### Launch

Build the existing #486 native executable, replacing its final translation unit native/tests/gen006_streaming_slice.cpp with native/tests/gen006_persistent_stream.cpp; the exact full Linux/Windows native compilation commands are in .github/workflows/gen006-persistent-session.yml.

On Linux:

~~~sh
export GEN006_PERSISTENT_EXECUTABLE="$PWD/build/gen006-persistent/persistent-native"
export GEN006_PERSISTENT_ROOT="$PWD/build/gen006-persistent/manual-world"
godot --path godot res://tests/gen006_persistent_stream_demo.tscn
~~~

On Windows, set GEN006_PERSISTENT_EXECUTABLE to the generated persistent-native.exe and optionally GEN006_PERSISTENT_ROOT to a dedicated save directory, then launch the same scene in Godot 4.7.

The original #486 process-per-input demonstration is retained unchanged as a historical acceptance control. The already integrated #496 regression preserves **five original full OpenGL framebuffer PNGs**, their source identities and SHA manifest at [original run #42327654878, artifact #13556425122](https://github.com/techrote/cybersand/actions/runs/42327654878/artifacts/13556425122). The existing integrated graphical CI keeps producing new screenshots without modifying those originals.

## Required acceptance

The dedicated workflow compiles the **actual native World/Generator**, not mocks, on Linux and Windows; exercises configured 1 and 4 worker modes; proves one process ID remains alive across idle ticks and commands; checks real edits and RGBA, 1536px camera travel, bounded eviction, restored Wall, invalid-request refusal, graceful save, independent process restart and actual worker participation. A separate real Godot 4.7 headless integration must connect to the persistent process, display native frames, issue edits and camera commands and prove reload. Each exact-source run preserves compiler, native stdout, test logs and source SHAs.

## Explicit non-admission boundary

This remains one real native World **per shard** rather than selective chunk eviction within the single shared production World. No cross-chunk Water/reactions/halo, live Rapier actor transfer, four-plane bundle persistence, async generator cancellation, historical CYPS migration, recipe reconciliation, production renderer replacement or crash-proof multiwriter transaction is claimed. There is no automatic startup from normal gameplay. Both #486 and this successor remain experimental and Draft; no merge into main or Ready transition is authorized by this task.
