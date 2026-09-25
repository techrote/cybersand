---
title: Player/environment tuning profiles and sampled traversal
status: Current
document-kind: contract
scope: PENV-001 sampled-player mass, gravity, terminal/jetpack tuning, material-response identity and step/knee/clamber traversal; excludes Water semantic changes and generic-body physics
canonical-for: [player-environment-tuning, sampled-character-traversal-bands]
last-reviewed: 2026-09-25
related-documents: [granular-interaction-policy.md, ../operations/gameplay-recording.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/configuration-reference.md, ../audits/2026-09-25-pchar001-player-representation-experiment.md]
---

# Player/environment tuning profiles and sampled traversal

## What owns these settings?

**Current:** `godot/scripts/player_environment_profiles.gd` owns the version-1
sampled-player/environment tuning schema and presets. `CyberSampledCharacter`
consumes one validated profile under the simulation-worker owner. The desktop
panel in `player_environment_panel.gd` edits a value copy and submits it through
`CyberSimulationWorker.queue_player_environment_profile()`.

A profile change does not mutate an executing run. The worker pauses, accepts the
validated value profile, and the presentation owner then invokes the appropriate
fresh-reset path for the ordinary demo world, Experiment Tower, Water Feel Lab or
the current MicroScenario. Native cell authority, Rapier ownership and material
descriptors are unchanged.

PCHAR-001's player representation/recovery layer is orthogonal to this profile.
Ordinary sandbox use may select the sampled character or the barrel/Rapier
experiment and may choose sampled-baseline or burial-safe runtime recovery. PENV
does not overwrite those choices. Registered Tower/Water/MicroScenario runs keep
PCHAR's forced sampled-baseline representation while still receiving the active
player/environment profile.

The profile hash is SHA-256 over the resolved profile fields. It identifies the
player/environment tuning inputs; it is not a state hash or exact-replay identity.

## Version-1 fields and baseline

The exact-current control intentionally reproduces the pre-PENV sampled-character
values:

| Field | Current baseline | Meaning |
|---|---:|---|
| effective mass | 1.0 | Player-side multiplier used by the existing bounded granular landing-response request |
| gravity acceleration | 92 | Downward sampled-character acceleration |
| terminal fall speed | 86 | Independent downward speed cap |
| jetpack acceleration | 180 | Upward acceleration while jetpack input is active |
| maximum jetpack rise speed | 60 | Independent upward speed cap |
| granular response sensitivity | 1.0 | Player-side multiplier on the REM-003 C1 landing request |
| liquid response sensitivity | 1.0 | Exposed/captured identity only in PENV-001; no production Water response hook is introduced |
| step / knee / clamber height | 1 / 1 / 1 px | Preserves the historical one-pixel traversal envelope |
| knee / clamber speed factor | 0.65 / 0.35 | Dormant in the exact-current profile because knee/clamber do not extend beyond one pixel |

The schema also retains separate granular and liquid response identity strings so
captures cannot imply that one generic material-response scalar owns both systems.

These are gameplay-space values in the existing cell/pixel coordinate system.
They are not calibrated SI mass, gravity or force units.

## Presets and custom tuning

**Current baseline** is the unchanged control above.

**Earth-feel candidate (~2x gravity)** is an owner-tuning starting point. It sets
gravity acceleration to 184 while retaining terminal fall speed 86 and the other
baseline fields. The label is deliberately “Earth-feel candidate”: it is not a
claim of physically calibrated Earth gravity.

The desktop panel exposes every numeric version-1 field directly. Custom profiles
can therefore use lower or higher gravity without changing code, and gravity,
terminal speed, effective mass and response sensitivity remain independent inputs.

## Granular and liquid response boundary

REM-003 C1 remains the owner of the bounded sampled-player landing disturbance
hook. On downward contact, PENV-001 supplies

`impact_request = vertical_speed * effective_mass * granular_response_sensitivity`

to the already-existing conservative `character_disturb_granular` operation.
At baseline mass 1.0 and sensitivity 1.0 this is exactly the old request. The
native/fallback granular support classifier, packing thresholds, conservative
relocation and material ownership are not changed by PENV-001.

The liquid-sensitivity field is intentionally inspectable and recorded but has no
Water displacement, pressure or head semantics in this child. A future meaningful
player↔liquid response must route through the Water/generic-body owners rather
than treating this field as permission to invent a second liquid solver.

## Step, knee and clamber bands

Horizontal sampled-character traversal tests obstacle clearance from the smallest
height upward:

- **Step:** height at or below `step_height` traverses at the full horizontal
  increment, preserving the historical one-pixel no-slowdown behavior.
- **Knee:** above step and at/below `knee_height` requires body clearance and
  uses `knee_slowdown` as the horizontal progress factor for that simulation tick.
- **Clamber:** above knee and at/below `clamber_height` requires the same bounded
  clearance/support check and uses `clamber_slowdown`.
- **Above clamber:** the sampled horizontal move is blocked unless another
  explicitly owned mechanic applies.

The exact-current profile sets all three thresholds to one pixel, so a two-pixel
or larger obstacle remains blocked exactly as before. PENV-001 regression fixtures
cover one-pixel, two-pixel, configured larger clamber and above-clamber cases.

This is a bounded sampled-character traversal rule, not ledge grabbing, animation,
stamina, arbitrary collision-shape climbing or a generic Rapier-body semantic.

## Desktop visibility and recording provenance

The desktop exposes a compact **Player / Environment Tuning** panel with the
active profile ID/hash and core values. Applying any accepted edit performs the
fresh reset described above.

REC-001 recording binds the full resolved player/environment profile to the exact
render generation represented by each retained material frame. It appears in
both the frame's player metadata and scenario identity, while recording-session
desktop configuration retains only the profile already published as active at
session start. A later consumer snapshot therefore cannot relabel older material
bytes with newer tuning. MicroScenario capture identity also includes that
published active profile.

This provenance is evidence identity, not proof that a candidate feels correct.
Final Earth/Mars/starship values remain owner-tuning outcomes under parent #133.
