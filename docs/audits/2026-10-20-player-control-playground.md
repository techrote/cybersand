---
title: Player control playground implementation and validation
status: Current
document-kind: evidence
scope: Seven human player presets, native material field, controller lifecycle, Linux execution and platform-qualified runtime publication
canonical-for: []
last-reviewed: 2026-10-20
related-documents: [../systems/player-control-playground.md, ../systems/physical-actor-models.md, ../reference/validation-evidence.md]
---

# Player control playground — 2026-10-20

The owner requested playable actors inspired by loose articulated stunt vehicles,
Trials-style motorbikes, momentum platformers with slide/roll/bullet-jump chains,
fast damped landers, actual dry/liquid material swarms, and a strongly rotating
jet barrel. This implementation belongs to CyberSand's existing authoritative
native-cell and Rapier gameplay owners. It does not move gameplay into the
companion neural research repository.

## Source and runtime identity

| Identity | Value |
|---|---|
| Repository | `techrote/cybersand` |
| Base main | `4f3685b71366218e82e7c2188e4ecdf27553f4cf` |
| Recoverable implementation branch | `feat/player-control-playground` |
| Initial implementation evidence | Base plus the branch's dated implementation checkpoint; later validation updates identify their exact commits below |
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Rapier | Pinned `v0.35.2`, actual Linux runtime |
| godot-cpp | Exact Git revision `101ae38034304346a46ea9ea84ae156d3e860496` |
| SCons | `4.10.1` from the pinned, hash-verified wheel |
| Linux toolchain | Ubuntu 24.04, GCC 13.3.0, GNU ld 2.42 |
| Rebuilt Linux SHA-256 | `3651192ea9bfbee97169dcc0af81ebe918e28cafa23b53805d851451c0b32adc` |
| Windows cross-toolchain | LLVM-MinGW 20260826 UCRT, LLVM 23.1.0, pinned archive SHA-256 `cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65` |
| Rebuilt Windows SHA-256 | `6d364db1d01b0b66268d55fb40d57816844e483f28c91a233ac786bb227b535e` |

The downloaded godot-cpp archive did not match the retained archive checksum, so
it was not admitted. Both builds used the build script's existing exact-Git-revision
path instead. No dependency pin, integrity check, or historical hash was changed.
Current runtime manifests record the full source input hashes separately from
this narrative. Windows cross-build success alone is not Windows execution.

## Implemented behavior and review corrections

Five mechanical presets extend the shared physical catalog to 46 models in eight
sets. Seven choices in the dedicated scene include the two native material modes.
The new mechanical modes have explicit human loadouts, empty equipment mounts,
and a bounded demo translator for the existing sandbox. A human idle command never
automatically operates equipment. All models stay within eight physical bodies.

The two vehicles have true circular Rapier wheels. The native coupling continues
to use an explicitly declared circumscribed rectangle around each wheel. This
conservative material footprint can contact cells near the square corners; no
exact circular native occupancy claim is made.

Acrobat crouch and slide use joint targets to tuck its articulated body. Controllers
apply bounded forces, impulses and torques through the existing rig rather than
teleporting transforms or replacing authoritative velocity. Landing-gated budgets
bound double jumps, bullet jumps, air rolls and glide time. Cancellation clears
intent without refreshing those budgets or erasing momentum.

The native Sand/Water field relocates complete cells, including temperature and
partial Water quantity. Its 65-by-65 scan, radius-32 selection, 512-parcel admission
and at most four adjacent relocation steps per admitted parcel bound each call.
Walls and occupied cells block relocation. The field admits matching nearby
environmental material; it does not claim persistent identity for a seeded cohort.

Review caught and corrected snapshot reads that issued fresh command authority,
quick button taps lost between physics frames, reset while paused leaving the
render surface disabled, and paused camera changes without a fresh viewport bake.
The low tunnel was tightened to an 11-cell clearance so compact posture matters.
UI preset changes and focus transitions require release before control re-arms.

## Completed local execution

These results use actual Linux Godot and Rapier, not mocked movement. The native
source remained unchanged during runtime builds. Tests are reproducible through
the repository's normal native target and Godot script runner.

| Fixture | Completed result |
|---|---|
| Full native World suite | 84 tests passed |
| Focused native player field cases | Six groups passed, including conservation, complete-cell state, blockers, capacity and one/four-worker determinism |
| `test_player_material_field.gd` | 56 assertions, zero failures against the rebuilt GDExtension |
| `test_player_acrobat.gd` | 304 assertions, zero failures |
| `test_player_acrobat_physics.gd` | 36 assertions, zero failures |
| `test_player_vehicle_controls.gd` | 79 assertions, zero failures |
| `test_player_playground_runtime.gd` initial integration | 1,202 assertions, zero failures; subsequent quick-tap and UI additions have a separate final result below |
| `test_physical_actor_catalog.gd` | 6,267 assertions, zero failures |
| `test_physical_usable_script.gd` | 4,460 assertions, zero failures |
| `test_physical_actor_actuation.gd` | 86 assertions, zero failures |
| `test_physical_actor_session.gd` | 113 assertions, zero failures |
| `test_physical_actor_rigs.gd` | All 46 rigs for 1,200 ticks each, plus legacy special cases, zero failures |
| Final bike demo correction | Focused 1,200-tick bike run plus legacy special cases, zero failures; 893 supported ticks and actual hops |
| Linux and Windows extension builds | Both completed with their pinned toolchains; Linux executed, Windows execution pending at this checkpoint |

Measured acrobat cases moved 103.53 cells in 65 run ticks, reduced standing
height from 13.49 to 7.31 cells while sliding, braked from 102.50 to 0.50 cells/s,
and reduced 45-tick fall displacement from 65.66 to 19.15 cells while gliding.
These are fixture observations, not universal speed targets or human feel ratings.

The initial integrated runtime checks cover seven owners, rejected stale/replayed
commands, lease expiry, actual physical pause, unchanged native state while
paused, material conservation, sealed walls, cancel equivalence and replacement
cleanup. The five mechanical presets move useful finite distances under input.

Typical focused invocation (use a writable XDG data/config/cache directory):

```sh
godot --headless --path godot --script res://tests/test_player_playground_runtime.gd
godot --headless --path godot --script res://tests/test_player_acrobat_physics.gd
godot --headless --path godot --script res://tests/test_player_vehicle_controls.gd
```

Real renderer review uses `godot/tools/capture_player_playground.gd` under Xvfb
with OpenGL compatibility. Its output is a disposable review capture and manifest,
not checked-in gameplay state. Its completion and inspected scope are recorded
with the final publication results.

## Remaining gates at initial checkpoint

Final UI lifecycle regressions, graphical inspection, canonical documentation and
retrieval checks, current provenance verification, and ready-for-review hosted
CI are not yet claimed at this initial source checkpoint. Actual gamepad hardware,
owner playtesting, target GPU performance and new browser/WebAssembly execution
remain outside the local evidence. The dedicated scene requires the matching
native runtime for both material modes; there is no decorative fallback.
