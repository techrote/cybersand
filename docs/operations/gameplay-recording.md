---
title: Desktop gameplay state recording
document-kind: contract
canonical-for: [gameplay-state-recording]
status: Current
scope: REC-001 desktop material-state recording, ownership, bounded pressure, evidence format, controls and validation limits
keywords: [recording, gameplay review, material state, immutable snapshot, bounded queue, dropped frames, REC-001]
related-documents: [../architecture/data-ownership-and-lifetimes.md, ../architecture/rendering-and-gameplay-bridges.md, microscenarios.md, testing-validation-and-replay.md]
last-reviewed: 2026-11-25
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

The ordinary desktop Main sandbox/showcase host exposes **Start Recording /
F10**. This is not a general Workbench shortcut: Shared Workbench hides the old
Main controls and returns from its own key handler before the F10 recorder
branch. Separate hosts such as Deepworks and Strata Theatre do not acquire this
recorder merely by using native materials. Source: [Main input](../../godot/scripts/main.gd)
and [Workbench setup](../../godot/scripts/shared_workbench.gd).

Starting a supported session:

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

**ULTIMA candidate storage prerequisite:** disk recording requires the
source-matched native runtime's file-replacement capability. A missing or stale
runtime is refused before creating a recording directory. This is a new candidate
boundary, not a claim that every historical GDScript-only Main host supported
safe replacement. The in-memory test mode performs no file I/O and remains
independent of that capability. Each disk recording creates a new session;
existing session directories are refused rather than resumed or overwritten.
Programmatic session names accept ASCII letters, digits, underscores and hyphens.

**Current capture extent:** `gameplay_recorder.gd::start_recording` clamps the
requested ROI to the legacy `CyberCellWorld.WORLD_WIDTH/HEIGHT` bounds, currently
1024×1024. This is a source limit, not a dynamic promise to capture a larger
Workbench canvas. Inspect the retained manifest ROI before interpreting an
image as a complete scene; the bytes remain a cropped material-ID view.

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
Tick zero is a valid reset generation when a render-publication serial exists;
both retained frames and drop records preserve it even after actors advance.

ACT-001 adds copied [SetA actor context](../systems/actor-control-prototypes.md)
to `actor_sample.actor_prototypes` and `material_generation.actor_prototypes`.
The former contains the current bounded session observation; the latter remains
bound to the exact material generation. The player metadata also retains this
context and an `environment_profile_applied` flag, which is false for prototypes
because their model owns the movement values. JSON includes the demo NPC rows;
the review bitmap retains its existing player/body outlines and does not draw
additional prototype NPCs.

ACT-002 adds the [rig schema](../systems/actor-rigs.md#what-does-the-version-2-observation-contain)
inside those same separately timed actor contexts: set/rig identity, 40-value
state rows, ten-value consumed actions, consumed edge flags and admitted/applied
sequences. Catalog body/color metadata is published as numeric arrays. The player
metadata records the current unrotated hull extent, exact actor rotation, rig ID
and set, including collision-safe tuck state. The review bitmap still draws
unrotated rectangular outlines rather than the desktop's rotating procedural rig
glyphs; use JSON for angle, attachments, NPCs and actuator-state interpretation.


USABLE-001 also retains copied `actor_usables` at both timing boundaries:
`actor_sample.actor_usables` is the current worker sample, while
`material_generation.actor_usables` is frozen with the render generation that
produced the retained material bytes. Player metadata carries the current
equipment state as well. This records selection, charge/cooldown/results,
projectile/device/effect/hit records and bounded work counters; it is evidence,
not resumed inventory or exact replay. The lightweight review bitmap does not
draw the equipment overlay, so JSON remains authoritative for those entities.

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

The `.ids` byte format is the current render projection, not the authoritative
eight-byte Cell carrier or the two-byte-per-cell Flatten baseline. It cannot
substitute for either persistence format.

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

### Candidate write verification and recovery

The ULTIMA correction verifies every newly written frame file after close against
its complete intended bytes. A frame is counted as written only after its `.ids`
(when retained), `.bmp` and `.json` writes succeed. A failed write stops admission,
marks the session incomplete and may leave a partial frame in the new session
directory. Keep that directory as failed evidence; an isolated file or image is
not proof that the whole recording completed.

`recording.json` uses the shared
[staged replacement contract](../architecture/shared-workbench-authoring-data.md#save-file-replacement-and-failure-handling).
The final manifest replaces the initial valid manifest only after the complete
staged bytes have been verified. If final publication fails, the recorder reports
failure and retains the previous valid manifest, usually with disposition
`recording`. That unfinished disposition must not be interpreted as `complete`,
even if some frames are readable. Recover those frames only as partial evidence,
retain the failure message, and start any retry in a fresh session.

This is per-file verification and manifest replacement, **not a transaction over
all recording files**. It does not promise filesystem synchronization, power-loss
durability, protection against a hostile process modifying the same directory,
or exact replay. The local qualification exercised pinned Godot 4.7 on Linux with
actual file-size limits, plus injected final-manifest replacement refusal and
session-collision tests. Windows storage behavior requires its own execution;
the [ULTIMA product evidence](../audits/2026-11-25-docs-renaissance-ultima/product/README.md)
records the actual platform results rather than inferring them from Linux.

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
The candidate's closed-byte verification adds writer-thread reads; include that
cost in the matched comparison rather than reusing an older writer measurement.

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

#135 is the finite first implementation child and remains open at the
24 November status check. Parent #130 tracks future recording, comparison,
export and review ergonomics; implementation presence does not close the owner
and performance evidence gates.


## REC-001 integration correction

The post-implementation integration review identified four recorder integration
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

## Focused storage regression

Use the pinned engine and materialized source-matched native/Rapier libraries
from the [build guide](local-build-and-validation.md). Run from the repository
root with a disposable user-data profile:

```bash
"$GODOT" --headless --audio-driver Dummy --path godot --script res://tests/test_gameplay_recorder.gd
```

The OS fault runner creates fresh disposable output and first commits a valid
manifest. On Linux it then installs `RLIMIT_FSIZE=128` with `SIGXFSZ` ignored and
checks the refused frame, failed status and unchanged prior manifest. On Windows
it holds the actual manifest open without delete sharing and checks that a fully
written frame cannot make a refused final manifest report completion. Each
platform also runs a normal successful recording:

```bash
python3 tools/ci/run_recorder_storage_qualification.py --godot "$GODOT" --project godot --evidence build/recorder-storage-check
```

The evidence directory must not already exist. This focused check does not run
the interactive F10 workflow, the owner performance comparison or a power-loss
test. The portable unit fixture also covers missing capability before output,
unsafe names, existing sessions, partial-frame detection and final-manifest
refusal.
