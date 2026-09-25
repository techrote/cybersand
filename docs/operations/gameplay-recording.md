---
title: Desktop gameplay state recording
document-kind: contract
canonical-for: [gameplay-state-recording]
status: Current
scope: REC-001 desktop material-state recording, ownership, bounded pressure, evidence format, controls and validation limits
keywords: [recording, gameplay review, material state, immutable snapshot, bounded queue, dropped frames, REC-001]
related-documents: [../architecture/data-ownership-and-lifetimes.md, ../architecture/rendering-and-gameplay-bridges.md, microscenarios.md, testing-validation-and-replay.md]
last-reviewed: 2026-09-25
---

# Desktop gameplay state recording

## What the recorder is

REC-001 / issue #135 adds an opt-in desktop evidence recorder for tuning and
owner gameplay review. It is deliberately a **simulation-state recorder**, not a
screen recorder and not an exact replay stream.

The recorder consumes the same immutable `CyberSimulationSnapshot` objects that
the presentation layer already consumes. It never receives a mutable `World`,
never runs a second simulation owner and never reads live Rapier objects.
Material render publications are folded into a private fixed ROI buffer on the
presentation thread. Retained frames copy that ROI into a bounded queue. A
dedicated writer thread performs file encoding and disk I/O.

Recording schema v2 separates the **material generation** from the **actor
sample**. Once the ROI is primed, later immutable worker snapshots may produce
capture frames while reusing unchanged material bytes, so actor-only movement is
visible without manufacturing a new cellular render revision.

This keeps the native/Godot ownership decision in ADR-003 intact. Recording may
consume CPU, memory bandwidth and disk bandwidth, but recorder pressure is not
allowed to block or skip authoritative simulation work.

## Starting and stopping a recording

Desktop builds expose a **Start Recording / F10** control. Starting a session:

1. freezes the current camera ROI for that session;
2. records runtime/source/configuration identity;
3. requests one full immutable render publication to prime the private ROI;
4. begins capture only after that full publication covers the ROI.

Interactive **Stop Recording / F10** closes admission and requests finalization.
The bounded queue drains and the final manifest is written on the recorder thread
while the desktop remains responsive. The UI shows a non-interactive finalizing
state until completion. Application shutdown may still synchronously join the
bounded writer as part of teardown.

Defaults are 15 retained capture attempts per second and an eight-frame queue.
The following user arguments override the defaults for a run:

- `--record-hz=N` — capture cadence, clamped to 1–60 Hz;
- `--record-queue=N` — retained writer queue, clamped to 1–64 frames;
- `--record-roi=x,y,width,height` — fixed world-space ROI instead of the
  camera ROI at the instant recording begins.

The output root is `user://recordings/`. The control tooltip and stdout identify
the session directory.

## Retained frame format

Every written frame has three files with the same numeric stem:

- `frame-NNNNNN.ids` — exact row-major, top-down uint8 serialized material IDs
  for the fixed ROI;
- `frame-NNNNNN.bmp` — immediately viewable 8-bit indexed BMP. Material
  palette indices are serialized material IDs; review-only outline indices 255
  and 254 identify the sampled player and rigid bodies;
- `frame-NNNNNN.json` — timing, tick, player/body and scenario/configuration
  metadata.

The raw `.ids` file preserves material identities even where the review bitmap
draws an actor outline. The canonical material RGBA8 palette is copied into the
session manifest so frame interpretation is stable.

Per-frame metadata carries two explicit identities:

- **material generation** — render serial, cellular revision, completed tick and
  generation timestamp for the retained material-ID bytes;
- **actor sample** — immutable worker snapshot, completed tick, publication time,
  active representation and active player body ID where applicable.

A later worker snapshot may therefore reuse the same frozen material payload while
advancing the sampled or Rapier player. The older material generation retains its
own tick/time identity and is never relabelled as newly generated material.

Per-frame metadata includes:

- immutable consumer-snapshot serial and render-publication serial;
- completed simulation tick for the render generation, plus the later consumer
  snapshot tick as a diagnostic field;
- render-generation monotonic time, consumer publication time, elapsed monotonic
  time and a wall-clock estimate derived from the session start;
- backend and worker count;
- active-player representation, body identity where applicable, origin, extent,
  velocity, sampled grounded/recovery state where applicable, and the full
  resolved player/environment tuning profile at the actor sample;
- copied rigid-body input ID, center, rotation, extent, velocities, mass and
  sample serial for the exact value sample consumed by the worker publication;
- active MicroScenario ID/hash/recipe/seed/mode and presentation tuning profile;
- transport profile name/hash and Water policy hash when present.

PENV-001 also retains the full player/environment profile in scenario identity,
while the session's desktop configuration records the profile active at recording
start. These are tuning/provenance inputs, not evidence that a candidate is
physically calibrated or owner-accepted.

REC-001 v2 retains the serialized material-ID channel only. The render
visual-condition channel is explicitly omitted. Temperature is not present in
the immutable desktop render publication and is therefore recorded as
**unavailable/omitted**, never as zero or inferred data.

## Session manifest and evidence semantics

`recording.json` is written at session start and finalized after the writer
drains. It records:

- evidence kind `simulation-state-evidence-not-exact-replay`;
- complete/incomplete disposition and reason;
- source/script/native-runtime/platform/Godot identity supplied by the desktop;
- active desktop worker/backend count plus render cadence, simulation-window,
  cadence-LOD, liquid-adhesion, view/margin and requested-worker configuration;
- ROI, capture cadence, queue capacity, starting material-tool selection and
  retained-state scope;
- the canonical material palette and review-overlay indices;
- capture attempts, enqueued frames, written frames and dropped frames;
- queue high-water and capacity;
- render-publication count and render-patch folding time total/maximum;
- capture-copy time total/maximum and writer write time total/maximum;
- retained drop records plus an explicit omitted-drop count if the bounded
  drop-event ledger itself fills.

The recording is suitable for frame-by-frame behavior comparison and owner
review. It is not sufficient to resume or deterministically replay a simulation.
CYSD1/replay contracts remain separate.

## Queue pressure, drops and failures

The queue has one producer (presentation consumption) and one writer. It is
explicitly finite. If full when a capture is due, the recorder records a
`queue-full` drop event containing the completed tick and both publication and
capture-observation monotonic timestamps. It does not wait for the writer and
does not ask the simulation worker to skip or slow a tick.

Material publications continue to update the recorder's private ROI even when a
capture frame is dropped. The next retained frame therefore represents the
latest consumed publication rather than a stale queued state. Worker snapshots that repeat an already-consumed render serial do not reapply
material patches. They may still satisfy capture cadence when the actor sample has
advanced; the resulting frame explicitly points back to the unchanged material
generation.

Malformed recorder input or a writer failure stops admission and marks the
session incomplete. A simulation failure likewise stops admission and records
the attempted failed tick plus the last retained completed tick. Existing
queued frames may drain. None of these recorder outcomes changes the simulation
failure/recovery contract.

## Performance evidence required before closing #135

The implementation exposes the counters needed for the issue, but its presence
does not establish "zero overhead." Before #135 is called complete, run matched
desktop recordings with recording OFF and ON on the same machine, fixture,
source/runtime and worker configuration.

At minimum retain:

- simulation tick timing/throughput and worker overruns;
- render/publication cadence and relevant publication/upload counters;
- render-publication count and render-patch folding cost;
- requested capture cadence;
- capture attempts, enqueued/written/dropped frames;
- queue high-water/capacity;
- capture-copy total/maximum and writer write total/maximum.

Use `rem003/player-granular-review` as the primary owner-review fixture and
include at least one active/falling-material case, such as the collapse region
in that fixture or `fixtures/sand-release`. Preserve negative and ambiguous
results. Do not convert owner taste into an automated acceptance score.

#135 is the finite first implementation child. Parent #130 remains open for
future recording, comparison, export and review ergonomics.


## REC-001 integration correction

The post-implementation integration review identified three recorder integration
gaps. Schema v2 corrects them without changing simulation semantics:

- actor-only motion is recordable against unchanged material bytes;
- worker-owned snapshots identify `sampled-baseline`,
  `sampled-burial-safe` or `barrel-rapier`, and the active Rapier player body
  is drawn as the player rather than as a generic body;
- `launch-desktop.cmd` / `tools/launch_desktop.ps1` exports the exact checkout
  SHA to the child Godot process as `CYBERSAND_SOURCE_REVISION`;
- interactive stop/finalization no longer waits for disk/encoding completion on
  the presentation thread.

These corrections do not satisfy #135's remaining owner/performance evidence
gate by themselves. Matched recording OFF/ON measurements and useful retained
desktop clips are still required before closing #135.
