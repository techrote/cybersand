# Compact Workbench performance overlay: #792 deferred handover

**Disposition:** Deferred during PUBPRES-MAINLINE-CONVERGENCE-001. No overlay or
additional telemetry was implemented. The priority remains integrated runtime
correctness, qualification and the standalone Windows evaluator. The separately
activated follow-up should use the then-current accepted main and obtain the
owner's assessment of density, placement, colours and Windows DPI readability.

[Issue #792](https://github.com/techrote/cybersand/issues/792) requests a tiny,
toggleable monospace instrument with miniature recent history, and explicitly
keeps it outside the current integration gates. This handover inspected
application source
[0670733eb0a418c8580458a9c5dd9aff24f342c6](https://github.com/techrote/cybersand/commit/0670733eb0a418c8580458a9c5dd9aff24f342c6).
Its relevant production sources are
[Main](https://github.com/techrote/cybersand/blob/0670733eb0a418c8580458a9c5dd9aff24f342c6/godot/scripts/main.gd)
and the existing bounded
[owner gameplay collector](https://github.com/techrote/cybersand/blob/0670733eb0a418c8580458a9c5dd9aff24f342c6/godot/scripts/workbench_owner_gameplay.gd).
Recheck these interfaces after the final integration fixes; do not assume a
physics-only packet contains a newly published material frame.

## Existing observations and truthful labels

| Proposed compact field | Existing source | Definition and limit |
|---|---|---|
| Render count/s | `Engine.get_frames_drawn()` | Counter difference divided by monotonic wall time. Label it a renderer count, not measured physical display FPS. |
| Draw delivery gap | Collector `draw.usec`, `callback_process_frame`, `frames_drawn_at_delivery`, `render_thread_inline` | The `frame_post_draw` callback's CPU delivery interval. A deferred callback cannot identify the exact currently submitted frame. |
| Rapier steps/s | `rapier_bridge.manual_step_count()`, `fixed_delta()`; collector `step.manual_steps`, `fixed_delta_sec` | Count only actual completed bridge steps. Main updates `_workbench_completed_step`/`_workbench_completed_step_usec` after the real `step()` and `complete_step()` transaction. No owned physical session means unavailable. |
| Simulated seconds/wall second | Actual Rapier count delta times the admitted `fixed_delta()` | Keep separate from native semantic ticks and render callbacks. |
| Native ticks/s | Accepted `latest_snapshot.tick_index`, scoped by its World identity; collector `step.native_tick` | Semantic tick difference per wall second. Coupling-only completions are separately recorded as `coupling_only_completions` and must not increase this rate. |
| Physical gap/hold | Collector `step.usec`, `gap_usec`, `hold.reason`, `paused`, `wanted_sample`, `completed_sample`, `pending_chunks` | Exact completion/hold observations when that producer is observed. Existing `gap_usec` resets at ownership changes. Do not label a paused world as a stall. |
| Material age | Main `_cadence_upload`: `world_generation`, `render_serial`, `generated_usec`, `native_completed_usec`, `completed_usec` | These fields are updated at an accepted production upload even with disk recording off. Show age from the bound native completion or generation clock with the chosen clock in the label. Missing/foreign clocks are unavailable. A physics-only/coupling-only packet must not reset material age. |
| CPU upload call | `_cadence_upload.completed_usec - start_usec`; collector `upload` | CPU call duration, including possible waiting/descheduling. It is not GPU execution time. Native render serial differences do not count accepted uploads: serials can be skipped. |
| Actor presentation age/state | Accepted `workbench_presentation_frame.selected_observations[slot].completed_usec`, `sources`, `reasons`, `selected_steps`, `hold_age_usec`; collector `presentation`/`body` | Optional selected-actor row. Preserve legitimate occlusion and withheld/held distinctions. Do not query a newer unpublished pose. |
| Spawn phase | Existing `spawn`: `usec`, `phase`, `request_serial`, `session`, `epoch`, `world`, `duration_usec`, `details` | Last measured phase only if observed. Nested phases overlap; adding them would double-count time. |
| Recording integrity | Existing `loss` and `close` records | Missing/lost history is unavailable evidence, not zero latency or zero stalls. |

The current collector has four 2 MiB rotating segments, batches of 32 rows and
four queued batches. It constructs bounded body/part observations only for the
owner recorder. It is not an always-on in-memory metrics service, and it exposes
no existing complete input-latency or GPU-time row to reuse.

## Minimal implementation route

Keep the overlay default **OFF**, with one ordinary Workbench toggle, no keyboard
focus or mouse interception, and no saved-world fields. Refresh text and the
miniature graph once per second. Use one fixed 60-bucket ring; each bucket holds
only counts, elapsed wall time, ages and optional maximum gaps. Render one
compact instrument in a corner, not a dashboard.

The smallest first slice reads accepted Main/bridge/snapshot scalars at 1 Hz and
plots those one-second rates and material age. This works with disk recording
off. It must not claim to recover per-frame p95/max gaps from one-second samples.
Show unavailable fields as `--`, and use observable paused/preparing/refused
state instead of guessing a bottleneck from a low rate.

If exact short gap spikes are included, add an optional scalar memory view at
the existing real completion and draw-observation producer boundaries. Reuse
their timestamps and identities; do not add another event log, JSON queue,
native query or GPU readback. Accumulate count and maximum interval into the
current bounded bucket, then refresh the UI at 1 Hz. Keep the detailed recorder
as its independent disk sink. Overlay OFF must disconnect its optional draw
observation and stop its UI timer; recording ON continues unchanged.

`CYBERSAND_PLAYABILITY_OWNER_RECORDING=0` currently prevents the owner writer from
starting; ordinary Main does not retain `_owner_gameplay` in that mode. Showing
the overlay must not silently start the writer, require an owner receipt, or
parse rotating files. The existing `_cadence_upload` and completion scalars
already provide the recording-off baseline. Exact gap/spawn fields need the
explicit shared scalar producer view or must remain unavailable.

Reset counter baselines at a changed bridge instance/session/epoch/World tuple,
scene replacement, RAMCACHE restoration and a recreated physical owner. Mark
the transition in history instead of subtracting a new counter from an old one.
Keep renderer delivery history process-scoped. Rebind selected-actor history
when actor instance/generation or accepted presentation identity changes. Clear
foreign material clocks rather than displaying their age as the restored world.

## Required qualification before that follow-up ships

Compare overlay OFF/ON on source-matched Wave512 and Mixed2048, then a sustained
Fire-on session, using the existing whole-gameplay and resource readers. Register
an overhead budget before the comparison; retain all adverse arms and uncertainty.
Test recording OFF/ON independently so the display cannot borrow correctness or
performance claims from a running disk recorder.

Demonstrate native/physical/render separation under an actual bounded slow/stall
control. Verify monotonic units, missing data, paused/manual-step behavior, owner
resets and bounded ring capacity. Exercise repeated toggles, Follow/free camera,
pan/zoom, resize/DPI changes, toolbar collapse, spawning, scene replacement,
RAMCACHE and selected-actor changes. Show that picking, input leases and saved
authoring state are unchanged. Report renderer callbacks as CPU observations.

Finish with an exact-source Windows evaluator, an independently extracted launch,
a one-line toggle guide and screenshots at ordinary DPI. The owner's physical
NVIDIA playtest determines usability. Unsupported GPU time/VRAM or process-memory
metrics should remain absent; Godot's static allocator usage is not total RSS.
