---
title: PLAY UI007 targets, runtime details and desktop qualification packet
status: Current
document-kind: audit
scope: Bounded shared-host presentation and navigation corrections, local actual-host evidence, separate pixel scope and source-pinned manual preparation
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../operations/play-desktop-manual-qualification.md, ../operations/local-build-and-validation.md, 2026-10-31-play-input010-pause-transitions.md]
---

# UI007 desktop readiness — 2026-10-31

## Concrete gaps and source ownership

The shared course already counted actual completed native ticks and Rapier
checkpoint visits, but did not present its authored checkpoint targets. Its
expanded status described configured thread capacity without an observed
participation sample, and a compact keyboard had no visible launcher-return
route in the composed Play panel. This package supplies those three capabilities
without moving scene/Rapier ownership or adding another simulation worker.

`playable_course_overlay.gd` reuses the unchanged legacy target drawing. Main
supplies copied lap identity and the same world/content transform as the actor;
the overlay never awards a gate or queries native/Rapier state. Pending, retired,
faulted, invalid or free-play state clears its markers. A Play-panel **Return to
launcher** button calls the existing FeatureNavigation teardown, also used by F2.
The existing wrapping action row is reused; no extra launcher row is inserted.

Optional expanded details ask the exclusive worker for a frozen statistics copy
at most every250,000us. The setting defaults off. The integrated Main sends a
mutex-owned request only when the requested display state changes. The sample
retains native completed tick, World generation, collection time, sequence,
capacity and phase task counts. **Task participants** are the maximum distinct
task-claiming participants in one phase dispatch of the sampled tick; a nonempty
inline phase counts the owner as one. Neither capacity nor participation means
utilization or simultaneous execution. Empty/stale-generation samples are
unavailable. Owner serial gaps count coalesced publications separately from
native tick deltas and rejected render payloads.

No native source, retained binary, physics default, scientific fixture, authored
rig mechanics or production shader changes. The original50-real-lifetimes-per-
platform cohort and all earlier lifecycle cases stay discoverable.

## Author source and independently checked local evidence

Author commit `8c5be0110bbd3522e5b76dee3b7050ef7e1eeab4`, tree
`cf040807936c500477788f3ad84525b34e3053ca`, builds on INPUT010 author source
`b7ceab2136a888d98f9050f18ebb3eb9377f6bef`. The integration branch consumes
published INPUT010 `12380a590d1bc301a9700ec4af78cbc72ca027e0`, including the
reviewed LIFE009 correction; exact resulting-head qualification is separate.

Local Linux uses official Godot `4.7.stable.official.5b4e0cb0f`, Rapier0.35.2 and
the source-matched retained native/Rapier LFS libraries. The evidence manifest
SHA-256 is `8af5ed83030ddea34938b5daa37efa2777b8a437247a3b2207e1594b14ea8a67`.
Independent root readback verified all135 retained artifact hashes and all15
committed production/fixture hashes. The archive also retains source variants,
per-process commands, logs, runtime hashes and original failure classifications.

| Author-source execution | Assertions / failures | Scope |
|---|---:|---|
| Five UI007 real shared hosts | 285 / 0,57 each | Main/native/Rapier, targets, camera, sampling, consumer hold, reconstruction and ordinary launcher teardown |
| Unchanged lap model | 1373 / 0 | Pure model, not real lifetimes |
| Unchanged physics-cadence fixture | 41 / 0 | Existing actual-host boundary |
| Unchanged UI005 selector | 90 / 0 | Existing composed selection regression |
| INPUT010 acrobat author fixture | 101 / 0 | Immediate pause/control ownership |
| LIFE009 acrobat author fixture | 103 / 0 | Original same-owner pause fixture |
| Isolated production-overlay pixels | 39 / 0 | Actual target pixels only; ten retained PNGs |

The five final UI007 fixtures acknowledge Main in252,787–294,518us, complete in
3.442–3.529s and perform launcher navigation/teardown in58,781–67,745us.
Optional native-statistic copies take8–15us in these local samples, with a
minimum262,943us sample interval and1–4 observed task participants at capacity4.
These are bounded observations, not general performance guarantees or displayed
FPS. Real consumer suppression creates observed publication gaps; the test
checks the exact serial-gap arithmetic without fabricating an owner packet.

The unchanged final fixture against the previous Main fails10 assertions/1
failure for the intended missing-overlay assertion, with actual join/retirement
and48,560us teardown. It is a source-baseline negative, not a timing failure.
Pure serial and copied-identity controls are labelled models; they supplement
the actual native/Rapier host and do not establish natural lap traversal.

## Original failures and graphical boundary

Original headless navigation attempted real popup mouse hit testing. Headless
reported a1x1 usable popup area, closed the popup and failed55 assertions/4
navigation/teardown checks. A subsequent fixture type error after freeing Main
was interrupted and remains incomplete. Corrected headless tests invoke the
actual Button's connected pressed callback and verify real scene destruction
and join; they explicitly do not qualify mouse hit testing or displayed layout.

The first sandbox graphical command could not open X11. After local-display
access was authorized, the **first actual shared Main graphical attempt failed**
the unchanged UI00730s first-Main-callback guard at55,430,888us. This
startup interval is distinct from PACE004's Build-to-ready-Main-callback
construction acknowledgement; neither failed interval is a pass. The original cascading worker
prerequisite label was corrected in a later fixture revision; the original
failed run was not replaced or called a pass. No shared-Main graphical rerun,
shader investigation, warmup, cache change or relaxed deadline followed.

The separate overlay-only graphical unit renders the production target overlay
without Main, native jobs, actor bodies or terrain shaders. It checks actual
authored coordinates, next/completed/future ring pixels and invalid-identity
clearing. This does **not** qualify shared-Main startup, actor/terrain output,
mouse navigation, device compatibility, natural traversal or graphical FPS.

For normal hosted integration the unit is registered as
`test_play_ui007_overlay_render.gd`. Existing suffix-based discovery makes it a
mandatory graphical Linux case and an explicit Windows headless exclusion.
The ordinary process runner supplies a per-case artifact directory beside its
log, and Linux supplies the actual checkout SHA just as Windows already does.
The registered unit adds a source-revision assertion to the original39; its
new-source result was executed independently at
`b9e9cc24bb319c453f81446988048c7dd22d7744`: clean import4.473s, actual-host
acrobat57/0 (fixture3.532698s, teardown61,028us), and overlay40/0
(fixture355,125us, process0.902s). A separately retained headless negative exits1
for the intended no-display assertion. A local summary helper originally
raised a missing-key error after those processes; that incomplete summary and
console remain retained. Independent readback sealed unchanged tested source
and all positive process records without repeating a positive case. Headless invocation fails,
and raw captures remain in the normal retained shard artifact.

## Manual packet and reproducible commands

The [manual qualification guide](../operations/play-desktop-manual-qualification.md)
and `tools/play/create_manual_packet.py` prepare identity, preflight, checklist,
51 initially untested CSV rows, manifest and guarded launch script. Preparation
requires exact clean source, the committed generator, the unchanged complete
materialized-provenance gate and byte matching to the pinned official engine
archive. Windows checks both executable companions; Linux requires executable
permissions. Preparation never runs Godot, including a version probe.

Manual author source `b5dd4a079a2f9d38e126541143d939c1115ac8f5` has11 adverse
unit methods, passing normally and under Python optimization. Independent integration
review found that revalidation omitted retained host metadata; the correction
compares the recorded host tuple as well and adds a targeted changed-host
negative. Review also corrected unsupported-family manual instructions, clarified
the two applied tooltip hashes and timing origin, and added UTF-8 BOM output
for Windows PowerShell Unicode paths with a targeted control. The integrated
manual suite has13 methods. A routed precursor
`be5edd9dc905ebf3d5e6437cb26463bb7ae1bc82` successfully creates and reverifies a
real Linux source/runtime packet without executing the engine; all51 rows stay
untested. A manually transcribed wrong expected SHA was correctly refused
before that creation. This precursor is not the final UI007 integration head.
Integrated source `b9e9cc24bb319c453f81446988048c7dd22d7744` also created and
reverified its real local packet with all51 rows untested.

The scoped `play-desktop-packet.yml` executes the same preparation and independent
reverification on literal GitHub-hosted Windows/Linux runners, with all retained
LFS inputs and pinned companion documentation. It preserves first failures and
does not execute the launch scripts. Generated metadata that dirties a later
checkout is not ignored: preserve the old source/logs and prepare a separately
identified attempt. No automatic device or human verdict is inferred.

Focused reproduction after the existing pinned import/provenance preparation:

```text
python tools/play/test_manual_packet.py
python -O tools/play/test_manual_packet.py
python tools/ci/test_godot_regression_sharding.py
<pinned-godot> --headless --path godot --script res://tests/test_play_ui007_<rig>.gd
```

Use the ordinary runner for the rendered overlay to retain its source identity,
explicit artifact directory and graphical command. The external graphical/case
limit180s, import240s, operation15s, fixture150s and Main acknowledgement30s are
unchanged. A skipped, timed-out or incomplete result is not a pass.

## Integration and residual acceptance

The live PR must retain exact resulting head/tree, complete Docs/materialized
provenance, all Native families/aggregate, Windows/Linux Godot coverage, scoped
packet checks and independent final review before guarded merge. Local or
predecessor results cannot substitute for that matrix. Post-merge source/tree
and push checks remain a separate verification step.

This package does not close #268/#269/#270/#263. The40-event pacing successor,
broader held lifecycle work, real OS focus, physical keyboard/gamepad/display
and human feel remain separately scoped. Keep #308/#310 held, #312/#316 frozen,
shader/cache/decomposition work deferred and Scheduswarm paused.
