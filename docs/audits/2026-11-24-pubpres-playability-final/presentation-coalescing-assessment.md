# Bounded material consumption assessment — 24 November 2026

Status: **read-only architectural assessment; Draft/HOLD**. Source inspected:
`b21dca8fd6bd30bed9c19ce84601f85050405bed`. No additional scheduling treatment or
physical credit is implemented by this record.

## Finding

A latest-only material transport already exists. Adding another queue with the
same replacement policy cannot remove a backlog that the application does not
retain. A useful additional experiment would instead be an explicit, bounded
presentation deadline or requested-cadence policy. It could avoid a selected
upload while the ordinary physics callback continues to consume its own exact
native completion. It would not remove engine renderer synchronization, make a
stale material plane current, or license another Rapier step before its native
body sample completes.

The qualification specialist found no isolated 30/60 Hz material-consumption
comparison in the recovered 45078090513 or 45105890195 controls. Their Full,
Target, source, continuation and sustained arms held the repaired cadence
constant. That makes a carefully registered cadence experiment a new question,
but does not establish that reducing presentation frequency improves gameplay.

## Existing ownership and transport

| Boundary | Source behavior | Consequence |
|---|---|---|
| Native owner to graphical mailbox | `simulation_worker.gd:2557`, `take_latest_snapshot(after_serial)`, returns the single newest immutable publication. | Main already skips superseded worker publications. |
| Dirty material accumulation | `simulation_worker.gd:3736`, `_append_native_render_packet`, appends ordered patches until accepted acknowledgement; byte and rectangle limits trigger a complete-frame recovery. | A retained latest packet contains intervening unacknowledged changes; a native delta alone is insufficient. |
| Journal retirement | `simulation_worker.gd:3306` clears only when the latched acknowledged serial reaches the newest pending material serial. | An old acknowledgement cannot discard newer dirty changes. |
| Native/physical completion | `main.gd:2310` reads the separate physics mailbox, followed by exact terrain, owner and body-sample checks. | Rendering does not provide physical-step credit. |
| Material consumption | `main.gd:3540` and `4685` consume one newest graphical publication in the ordinary process callback. | There is no application FIFO of old GPU submissions to drain. |
| Texture and CPU histories | `main.gd:6225` and `6462` retain the actual old CPU plane, apply ordered patches, then rotate/update GPU resources. | Previous means the previously uploaded plane even when publication serials jump. |
| Accepted visual identity | `main.gd:4673`, `workbench_display_frame`, selects a receipt bound to the actual uploaded World and revision. | Current native status never relabels stale material bytes. |
| CPU-data acknowledgement | `main.gd:4415` and `4427` acknowledge only accepted upload submission. | The acknowledgement is not a GPU fence or presentation witness. |

The native exchange consumes dirty chunks after copying them into owned packet
bytes (`cyber_native_cell_world.cpp:1232`). The worker's journal is therefore
necessary: dropping an intermediate native packet before accumulation loses
edits. A journal can contain a complete baseline followed by deltas; they must
be applied chronologically.

Workbench also fences native advancement to the next genuine body sample
(`simulation_worker.gd:2955`, `3106`). While Main is blocked in the renderer, it
cannot execute the next manual Rapier step or publish that step's body sample.
The producer cannot run freely far ahead of physical completion. This limits
the benefit available from graphical coalescing alone.

## Safe shape of a presentation deadline experiment

The smallest distinct treatment would keep one immutable pending material
snapshot on Main, replacing it with a newer eligible snapshot while continuing
to consume ordinary status and control results. A bounded deadline selects when
to call the existing upload function. It introduces no native tick, Rapier
callback, queued physical command or guessed completion.

- **Defer before CPU mutation.** Current `image`, byte caches, previous image,
  content identifiers, texture bindings, timeline and uploaded identity stay
  unchanged until the chosen upload. The coherence guard reads those CPU bytes
  as evidence of the visible GPU planes.
- **Retain the accumulated packet.** Main may replace a pending snapshot with
  the worker's newer cumulative publication, but cannot extract only its final
  rectangle or native delta. If a required base is unavailable, request and
  await a complete frame through the existing recovery path.
- **Acknowledge only an accepted chosen upload.** Skipped publications receive
  no acknowledgement. Uploading the newest cumulative packet makes one newest
  acknowledgement sufficient. Delayed older acknowledgements remain monotonic.
- **Keep actual histories.** If uploads jump from material serial 20 to 24, the
  two histories are 20 and 24. Serials 21–23 were never displayed and cannot
  become previous-texture identities, pose anchors or timing observations.
  `WorkbenchMaterialTimeline` already accepts increasing nonconsecutive serials
  and bounds fades using real upload/publication clocks.
- **Keep physics independent.** Each callback still installs matching complete
  terrain, rejects duplicate/wrong-owner/stale samples, applies that sample's
  native impulses once and publishes a genuinely completed Rapier body frame.
- **Keep pose and camera evidence.** While deferred, retain the uploaded receipt
  and both actual visible planes. The coherence guard may certify a real later
  pose against them, briefly hold it, or withhold it. Follow uses that selected
  pose. New native status is not permission to substitute a live pose.
- **Bound memory and postponement.** Retain one pending immutable snapshot and
  a fixed deadline. Replacing the offer cannot reset its deadline indefinitely.
  A Main renderer stall may overrun the deadline and must be reported as such.

Same-size replacement still changes World identity. Reset, physical-owner
session/epoch change, teardown, native failure or rejected material must
invalidate the deferred offer. A new accepted World uses the existing complete
frame/history-reset path. Same-World full refresh remains a transport operation;
it does not by itself invalidate a legitimate previous history.

Implementation should first extract a small policy object deciding
offer/defer/consume from immutable identities and clocks. Existing Main upload,
fallback, ACK and timeline code remain authoritative at consumption. A diagnostic
selector should remain off by default until matched results establish benefit.

## Required distinguishing evidence

Source supports semantic feasibility, not performance selection. Registered
comparisons must report skipped material generations, native completions, exact
accepted physical steps, input-to-completed-step latency, material age, selected
pose age/withholding and full completion-gap tails. Hold native source, material
backend, ring size, renderer ownership, workload and timestep constant.

Challenge overlapping patches across skipped serials, a baseline plus deltas,
out-of-order delayed acknowledgements, bounded journal overflow/full recovery,
same-size World replacement, corrupt-payload refusal, save/reopen, multiple
actors, painting and Follow. Read both actual GPU histories and compare against
independently replayed cumulative bytes after a deliberate serial jump.

The causal question is whether avoiding a texture submission frees Main to run
more fully admitted physics callbacks without materially worsening freshness.
If engine Main-to-renderer synchronization or drawing dominates, coalescing
uploads preserves that stall. The three-slot and engine-ownership treatments
are independent experiments.

## Native dependency observation for follow-up

Occupied bounds remove zero-valued obstacle queries, but deliberately preserve
allocated-mask classification. `world_wave.inc:486`, `504`, `736` and `783` show
why an actor still prevents dry/clean shortcuts across much of the full-canvas
mask allocation. Those fields are explicitly bound by `hash_wave_state` near
line 402. Replacing their region with occupied bounds changes retained identity
and potentially flux retirement; it is not another harmless clipped lookup.

A distinct conservative investigation is an internal certificate for an
unchanged entirely Empty half or column, invalidated by every material/mask
write and checked against current mask and selected region. It must preserve
hashed dry/clean/flux outputs exactly and prove omitted mass/weight/metadata
computations already yield zero. No certificate is implemented or claimed safe
here. This differs from rejected generic tiling and conditional-store arms, but
requires a complete invalidation proof before implementation.
