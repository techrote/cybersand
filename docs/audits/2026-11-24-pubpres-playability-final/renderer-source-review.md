---
title: PUBPRES final renderer source and recovered engine review
status: Historical
document-kind: audit
scope: Three-slot Full publication experiment and source-exact recovery of the earlier Windows EGL context-handoff repair
canonical-for: []
last-reviewed: 2026-11-24
related-documents: [../../architecture/rendering-and-gameplay-bridges.md, ../../operations/pubpres-completion-001.md]
---

# Renderer source and recovered engine review

## Decision boundary

This continuation starts from frozen #757
`c90dbc46e1f57f28e06b1f4205b83467335ff657`. It preserves Full publication,
strict native/terrain feedback, Main-owned Rapier, ordinary two-slot storage and
all production defaults. The earlier Target and Combined experiments remain
negative. No upload-call saving is interpreted as physical progression.

The distinct three-slot Full experiment updates an ImageTexture absent from the
preceding bound current/previous pair. It changes one resource reuse decision,
not render-thread ownership or native laws. The third slot adds one logical
R8/RG8 plane. Command ordering and immutable queued Images remain mandatory;
multiple queued frames can still reference that slot. No nonblocking or GPU
completion claim is made. The canonical rendering contract describes controls
and invariants. Hosted graphical correctness and actual progression comparisons
remain required for the new application source.

## Pinned Separate/ANGLE source defect

The exact upstream Godot commit is
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` (official 4.7). Independent source
inspection recovered this sequence:

1. `RenderingServerDefault::init()` calls
   `DisplayServer::release_rendering_thread()` before starting the rendering
   pump. Windows routes ANGLE release to `EGLManager::release_current()`.
2. `drivers/egl/egl_manager.cpp` releases the EGL context with
   `eglMakeCurrent(..., EGL_NO_CONTEXT)` but leaves `current_window` populated.
3. The rendering pump's `_thread_loop()` calls `gl_window_make_current()` for
   the same Main window on its new thread. `EGLManager::window_make_current()`
   returns early because the window pointer equals that cached value.
4. The new owner therefore has no rebound GL context. GLES3 GLAD initialization
   fails. Its early constructor return leaves incompletely initialized rasterizer
   members, consistent with the observed subsequent access violation.

This is a source-located context-handoff defect that matches the hosted
Separate/ANGLE startup failure. It is not a diagnosis of an NVIDIA driver or
every subsequent Workbench stall. Native Windows OpenGL uses a different manager.

Primary source:
[RenderingServer owner initialization](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/servers/rendering/rendering_server_default.cpp),
[Windows owner routing](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/platform/windows/display_server_windows.cpp),
[EGL manager](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/drivers/egl/egl_manager.cpp),
[GLES3 initialization](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/drivers/gles3/rasterizer_gles3.cpp).

## Main and rendering still rendezvous

The same pinned Godot source bounds the architectural claim. `Main::iteration()`
executes its due physics steps, runs idle processing, then unconditionally calls
`RenderingServer::sync()` before the next draw. In Separate mode that method
calls `command_queue.sync()`; Safe mode flushes pending commands on Main.
Separate can overlap the previous draw with the next iteration's native/Main
work, but a long preceding draw still delays the next iteration and its next
Rapier opportunity. Clearing EGL's stale window cache repairs startup ownership;
it does not remove this engine rendezvous, admit additional physics samples or
make dependent terrain safe for speculative steps.

There is also a measurement distinction. `_draw()` calls
`_run_post_draw_steps()` directly in Safe mode and defers that method to Main in
Separate mode. Thus a Separate `frame_post_draw` observer timestamps delivery of
the completion notification. It does not timestamp the render owner's exact
end, a GPU fence or display scanout. Main may have advanced its live material
serial before receiving that notification, so the serial must not identify the
draw without an independent binding. A current Main-thread
`RenderingServer.is_on_render_thread()` observation still distinguishes Safe
from Separate; it is not evidence that the deferred draw notification originated
at that instant.

Primary source:
[Main iteration and the render synchronization point](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/main/main.cpp),
[render synchronization, draw dispatch and deferred post-draw steps](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/servers/rendering/rendering_server_default.cpp).

## Exact donor repair and artifact recovery

This fix already existed in frozen #609
`5a36ce49404ed7dc8a9e5815593d250ab990615a`. The recovered patch clears the
cached `current_window` immediately after EGL release. Patch, builder,
restorer, lock, delivery lock and adversarial provenance tests are restored
byte-for-byte from that source. Their presence does not select the engine or
change any launcher. The exact original engine can be reused for a separately
identified same-policy current-source experiment without rebuilding it merely
to refresh a CI badge.

| Recovered object | Identity |
| --- | --- |
| Original hosted engine build | [43980022228](https://github.com/techrote/cybersand/actions/runs/43980022228) |
| Original Windows engine artifact | [14284768334](https://github.com/techrote/cybersand/actions/runs/43980022228/artifacts/14284768334) |
| Original artifact bytes | 79,639,903 |
| Artifact SHA-256 | `34dfdf5769828dc4ae876550864b4c80c3acd5bc960944ce8631d9bf900421be` |
| Provenance SHA-256 | `a4be0fa432c77240c49e28ab53cc30b4cb97f898a0064e747e03f445ac04751c` |
| Patch SHA-256 | `29a74947a3128ed93eeea0c6ab7274d10f45c194627fb516d7db6b511413e9a1` |
| Unpatched EGL source SHA-256 | `65f6cb972cd6f8d3242663589e213f96d3a51dcf9f65e745d5d0ca34986d8de7` |
| Patched EGL source SHA-256 | `9faf74aa030f0b11b59f82bc0eca1373c781cef9372a2f9ba43c576f8869321e` |
| Engine version | `4.7.stable.cybersand_egl_handoff.5b4e0cb0f` |
| GUI executable SHA-256 | `d6a1e5795205eb7968131df55f39916af112f716ec419fce5f97ccb48990fd45` |
| Console launcher SHA-256 | `6f642c28780409295c0001f3919d14a9f71485a602c533a1c0335df5819d1030` |

On 24 November the original artifact was downloaded, its exact byte count and
GitHub SHA-256 matched, ZIP CRCs passed, all paths were checked before extraction,
and the original `restore_workbench_godot.verify_payload()` accepted the
source/patch/lock/builder, executable, API-equivalence and PE import records.
All 13 original adversarial provenance tests passed. This is fresh artifact
custody verification; the earlier API/build execution retains its original date.
Windows execution of the successor application is a separate pending gate.

An initial local recovery included an extra terminal newline in the recovered
text files, and the original verifier correctly rejected the lock. Restoring
the original bytes repaired recovery; no verifier predicate or digest changed.

## Earlier gameplay negative remains binding

The [independent #609 review](https://github.com/techrote/cybersand/pull/609#pullrequestreview-5946314640)
accepted the patched engine's separate build qualification but retained
increased Follow tails in that broader treatment: maximum gaps
335.063 to 390.963 ms and 248.674 to 460.038 ms, with higher p95 and lower Main
submission rates. That comparison also changed other policies. Startup repair
therefore does not establish a gameplay win. A useful new comparison keeps
application source, native runtime, input, Full publication and physical gates
identical while comparing patched Safe against patched Separate. Stock Safe
remains a separately identified engine control. Physical Windows 11/NVIDIA
and scanout acceptance remain unperformed.

## Local validation boundary

The exact official Godot 4.7 parser accepted Main, the new publisher and both
new graphical fixtures with source-matched locally built native and retained
Rapier 0.35.2 libraries loaded. Local Xvfb cannot create its display sockets in
this execution environment. The graphical first-read oracles are not relabelled
headless passes; hosted execution must supply their results.

The added production-Main recovery fixture checks a same-size World replacement,
the following same-World admission, forced publisher ownership refusal, exact
two-slot fallback histories, six ordered ACKs and explicit ring recreation.
Its first GPU reads and the helper/transition fixtures include actual executable,
fixture, publisher, driver and render-owner identities. Their Python validators
independently reconstruct the registered pixel histories. The native specialist
reviewed the ring's ownership/rotation and requested the recovery coverage; the
presentation specialist separately checked the validator's byte reconstruction
and all 180 admitted slot phases. These source reviews do not substitute for
graphical execution or an ordinary Workbench performance result.
