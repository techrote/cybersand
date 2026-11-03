---
title: Paired-material plan and bounded flyer material sources
status: Current
document-kind: audit
scope: Planned paired-material implementation and app-only flyer additions; desktop host mechanics, not new material or rest qualification
canonical-for: []
last-reviewed: 2026-11-03
related-documents: [../operations/paired-wall-loose-materials-plan.md, ../systems/granular-review-flight-fleet.md, 2026-11-02-flyer-actuator-limits-and-navigation.md]
---

# Paired-material plan and flyer material sources

## Implementation boundary

Starting checkpoint was `f6cd386824013e1498af37493aff78198f2786ff` on
`codex/gcr-rest-comparison-20261102`. Application source
`d624bc191cbf3f6ad2c0e8988b3a2aa520e8bf93` adds the requested flyer controls
and the [paired wall/loose plan](../operations/paired-wall-loose-materials-plan.md).
The latter is **Planned**, including the shell-destruction playground annex and
finite-dose curing. No new native material, reaction, hard classification or
curing law has been implemented or qualified here. Current Cement is not changed.

The new flyer sources are real native materials: Midge Q Acid12/E Lava8,
Cartographer Q/E left/right Water3, Observatory Q/E left/right Lava8, and
Kestrel S Gunpowder26. They add material without recoil. Needle, Kestrel and
Surveyor Q/E apply body-local side thrust at0.65 of authored acceleration,
combined before the existing single force clamp and impulse owner. A/D yaw is
retained; dispenser buttons no longer also yaw. Afterglow retains Q/E tilt.
Kestrel S no longer reverses thrust; W+S and independent Q+E are retained.

The separate **Thrusters emit real Fire** checkbox starts off. It changes the
live source setting without rebuilding the room and is retained across craft
reset/selection. Active thrust may emit Fire6; idle hoverboard gravity
compensation does not. Zero force cap prevents thruster Fire. This feature can
ignite or react with the existing banks; it is an intentional material source,
not a closed conservation fixture or a material-chemistry change.

The dedicated synchronous main-thread source is admitted only to the explicit
single-human, single-body fleet route. Generic actor commands and the ordinary
Sand-only effect consumer retain their schemas and policies. Ports inherit an
accepted Session epoch, control generation and sequence, and require its live
consumed action/lease. Cancel, focus/edit cancellation, pause, lease expiry,
replacement ordinary commands and teardown cannot revive stale ports. All
independent buttons must be released before input rearms after cancellation.

At most3 radius-zero cells are requested every6 ticks, without catch-up. A
maximum64-cell supercover trace and1024 reads per due step allow only the
contiguous own-mask prefix, then require an Empty/unmasked path and destination.
Corner crossings inspect both sides. Occupied powder, liquids, hard terrain,
foreign masks, out-of-bounds or failed-World conditions refuse the nozzle.
The native overwrite API is guarded again at the write boundary. Fixed counters
and at most3 copied last-frame receipts replace any growing event history.

## Source-matched checks and limitations

The compact [host summary](gcr-rest-2026-11-02/fleet-jets-summary.json) records the
source, project-input ledger identity, commands,240-second process watchdogs,
runtime identities and log hashes. Fresh import and nine target tests pass on
each of Windows and Linux/WSL using Godot4.7 official5b4e0cb0f and Rapier addon
0.35.2/core0.35.1:

- Side-thruster actual-controller/Rapier regression:130 checks per OS.
- Emission regression:74 checks per OS, including native Water full-quantity
  initialization, actual Session lease expiry/cancellation and obstruction tests.
- Retained fleet control API:1,155 checks per OS; budgets, mass/inertia,
  thrust/torque ceilings and native response ownership remain covered.
- Seven-craft UI/live ticks/painting, live Fire setting, reset retention,
  independent sampled buttons and rearm; review navigation23 checks per OS.
- Ordinary physical actor rigs, material effects, queued effect admission and
  Session lifetime controls.

All application inputs are compared before/after with both isolated projects.
Native SDK source `181a8257a93f82d64fbeb97e9c413ef52d44f13d` is reused with all88
compiled inputs unchanged. Native hashes remain Windows
`65c1d2a35134c44aea539a0e8441d66b3b4db92cba7c5477d038b842fe7c889e` and Linux
`8bfe51214643c626dd5800f66ecff86f3348a166b55551e0674d1b4f762cfbf5`.
No new native build, sanitizer campaign, physical response envelope or Web
qualification is claimed for these application changes. Sleep, rest modes,
friction/load/correction and production defaults remain unchanged.

The first Windows UI preflight failed3 assertions because synthetic key events
did not create physical-key state under headless DisplayServer. The corrected
test injects independent sampled button levels at the scene input boundary,
then exercises actual scene normalization, rearm, controls and native owner.
This is not a hardware keyboard execution claim. Original failed log remains
local at `build/fleet-jets-preflight/ui.log`; its hash is in the compact summary.
The corrected preflight and both final platform runs pass. Initial retrieval
orchestration also used unsupported `--questions`; the corrected invocation uses
`--queries`. A UTF-8 result-display retry changed no source or engine result.

Documentation, retained M11 integrity, materialized repository/provenance and
whitespace checks pass. Frozen retrieval is32/32 in top5. Supplementary retrieval
is162/163 in top5; both new questions rank1. The LCB03 miss is also present on the
starting checkpoint (160/161 top5), so it remains a separately recorded retrieval
limitation rather than a claimed all-pass.

The recoverable code checkpoint is the commit above; the evidence/docs follow-up
changes no application inputs. Raw receipts/logs and isolated projects remain
under `build/fleet-jets-final`. The authenticated owner project is
`build/fleet-jets-final/windows/godot`; the manual shortcut is
`build/launch-gcr-fleet-review.cmd`. Historical GCR-REST failures, the cropped
burrowing observation and earlier gameplay judgements retain their own sources.
This extension does not solve burrowing, qualify stable granular rest or infer
owner acceptance. PR351 remains draft and unmerged.
