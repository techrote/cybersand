---
title: Flyer budget controls in the editable playground
status: Current
document-kind: audit
scope: Source-matched developer controls and painting-room host checks; no new physical-law acceptance
canonical-for: []
last-reviewed: 2026-11-02
related-documents: [../systems/granular-review-flight-fleet.md, 2026-11-02-gcr-rest-contact-comparison.md]
---

# Editable flyer budget playground

## Source and boundaries

Owner requested the budget and mass/inertia controls in the larger seven-flyer
painting room, with PR351 unmerged. Source checkpoint
6ebc3b0290320dd2f595b807799f5887f45bc8d2 selectively reconstructs the retained
fleet from f7d611501c18425f7f06f0c874324113da78d8e7, without importing its native
runtime or investigation corpus. Four shared actor-host scripts change; native
code, libraries, dependency pins and the single-body Rapier bridge do not.
Current Windows/Linux SDKs remain native build181a8257, with all88 compiled
inputs and actual artifact hashes verified against provenance.

This is a new application-source checkpoint. Its complete project ledger differs
from the frozen594/181 physical campaign. The earlier88 trajectories, failures,
unsupported rest gates and NO-GO R/PRC disposition retain their original source.
No new physical campaign, coefficient calibration or production default promotion
follows from this playable extension.

The [fleet contract](../systems/granular-review-flight-fleet.md) owns controls and
authoring semantics. LA/A1 uses native GCR-REST control mode and budgets5..80;
no P/R/C context or authority is supplied. Retained RFT uses R2 with fixed20.
Comparing RFT against LA changes admission as well as capacity; compare20/40/80
within LA to isolate the budget. Each flyer retains one actual body, one packed
17-field boundary and one accumulated wrench application.

Actual mass is authored mass times0.01..64. Actual inertia is rectangular inertia
at that scaled mass times the separate0.01..64 factor. All cached rig mass/inertia
values are assigned during construction before bridge binding. Exact authored
fleet definitions gate these overrides; ordinary actor validation is unchanged.
Force/torque ceilings stay authored; controllers derive requests from actual
properties until those ceilings bind. High mass can prevent flight.

Apply/reset rebuilds the selected craft and room, clearing painted terrain.
Selecting another craft retains applied controls. Text editing suppresses craft
shortcuts and leased flight input. Native paint/erase remains an intentional
authoritative edit between synchronous owner steps; this is not a closed material
conservation apparatus. No detached building properties, sleep or default law
are changed.

## Executed qualification

The [compact receipt](gcr-rest-2026-11-02/fleet-playground-summary.json) binds logs,
commands, timeouts, runtime identities and project-input hashes. Windows and Linux
Godot4.7/Rapier each pass a fresh import plus all eight target controls:

- New fleet controls:968 assertions, including all seven craft at minimum/default/
  maximum mass/inertia, native sample properties, actual load-aware/global budget
  readback at20/40/80, one-wrench delivery, no catch, malformed refusal, ordinary
  mass limits and reset retention.
- Retained crash playground and seven-flyer controls: real paint/erase/hard edits,
  live controller/material ticks, force/torque ceilings, no hidden equipment,
  retained RFT identity, numeric-field focus and staged/default reconstruction.
- Player vehicle controls and playground runtime.
- Physical actor arena, session and rigs.

Every executed project code input was rehashed against current source and both
isolated projects after execution. The existing SDK is reused; no sanitizer/native
rerun is represented as new source execution. Independent review found and
repaired a malformed Session-definition dereference and missing GCR-REST
transient-mask cleanup before this final checkpoint.

Preserved fixture failure: Vector2 stored0.01 slightly below the exact minimum.
Refusal was correct. The final test uses double-valued array literals; no bound
was relaxed. Original failed/watchdog logs remain under ignored
build/fleet-host-controls. Successful partial961-check runs remain separate from
the final968-check execution.

Documentation, materialized repository/provenance and historical M11 checks pass.
Frozen retrieval hits32/32 at5; challenges159/160, new GCR-FLEET-01 at rank1 and
existing LCB03 absent. These are lexical route results, not answer sufficiency.
The Windows room was opened from the authenticated tested project; visual review
confirmed all seven flyers, LA20 controls, both multipliers and material painting.
The owner was already operating the craft, so no further UI input was injected.
This records availability, not a subjective acceptance verdict.

## Reopen and review

Use tools/experiments/run_gcr_fleet_review.py with a committed source-matched
project; identity-only verifies executable project inputs, native/Rapier artifacts,
official Godot4.7 and source identity before launch. The local tested project is
build/fleet-review-hosts/windows/godot. P pauses; Space thrusts; F changes camera;
1–7 or Tab changes craft. LMB paints, RMB erases and the wheel changes brush size.
Apply/reset is required for staged controls and clears the edited room.

PR351 remains draft and unmerged. Owner acceptance and broad gameplay/physical
qualification remain open; this extension does not close REM004 or issue83 and
does not change any earlier failed result.
