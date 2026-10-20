---
title: Player control playground implementation and validation
status: Current
document-kind: evidence
scope: Seven human player presets, native material field, controller lifecycle, Linux execution and platform-qualified runtime publication
canonical-for: []
last-reviewed: 2026-10-20
related-documents: [../systems/player-control-playground.md, ../systems/physical-actor-rigs.md, ../reference/validation-evidence.md]
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
| Source checkpoint used for native rebuild | `e5baca03384380f34fc255802903f57435874734`, tree `f8bf2c9f14038e55935060f00bee3829a9351cde` |
| Retained runtime checkpoint | `3d0ab36` (same native inputs; subsequent source changes are Godot presentation/tests, course clearance and documentation) |
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
An initial 11-cell tunnel trapped the mounted acrobat's trailing foot. Actual
traversal testing selected 12-cell clearance, which permits the complete folded
assembly to pass. Standing attempts can also compress physically under contact;
this is not an exclusive slide-only lock.
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
| `test_player_playground_runtime.gd` final integration | 1,325 assertions, zero failures, including quick-tap and real UI lifecycle cases |
| `test_player_playground_course.gd` | 1,446 assertions, zero failures, actual native/Rapier mounted spawns and short traversal routes |
| `test_actor_rig_integration.gd` | 693 assertions, zero failures; all five new F5 entries selectable in human mode |
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

The integrated runtime checks cover seven owners, rejected stale/replayed
commands, lease expiry, actual physical pause, unchanged native state while
paused, material conservation, sealed walls, cancel equivalence and replacement
cleanup. The five mechanical presets move useful finite distances under input.
The final scene cases also verify quick keyboard and material-button taps,
bounded input queue refusal, cancel/expiry dropping pending pulses, focus release
gates, paused camera baking, reset restoring rendering and a genuinely fresh run
after the ten-minute mechanical limit.

The course fixture proves that the buggy and bike reach the approach and ramp
gates with ordinary throttle (139 and 247 ticks). The mounted acrobat's complete
assembly exits the low tunnel at tick 121, including 60 settling ticks; standing
height 13.55 falls to 10.72 cells, with maximum height 11.41 while inside. The
lander crosses the first flight opening with bounded human-channel thrust and
rotation, passing within 0.58 cells of its gate. These are short route checks, not
an automated proof that every human can clear the complete timed course.

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

## Final local validation and publication boundary

The real OpenGL compatibility capture rendered all seven presets under Linux
Xvfb/Mesa 25.2.8 llvmpipe LLVM 20.1.2. Visual inspection confirmed readable controls,
visible terrain, aligned round wheels, live material parcels and articulated
postures without clipping at 1600 × 1000. This is software-renderer presentation
evidence. The initial capture used automatic audio fallback because the virtual
host has no sound device. The final capture requested the Dummy audio driver,
completed all seven plates with no engine/script errors, and was inspected after
the one-cell tunnel adjustment and barrel visual cues. The final runtime/UI
suite was rerun after those source edits: 1,325 assertions, zero failures.

Canonical docs/routes and five supplementary retrieval questions were added
together. Frozen questions and all 79 prior supplementary question objects remain
unchanged. The 32 frozen questions retain 21/32 hit@1, 32/32 hit@5 and MRR 0.7953.
All 84 supplementary questions give 66/84 hit@1, 84/84 hit@5 and MRR 0.8704; the five
new player questions give 4/5 hit@1, 5/5 hit@5 and MRR 0.9. The prior 79 retain their
hit@1/hit@5 counts, with MRR moving from 0.8728 to 0.8686 as SOL02/USABLE03 shift
from second to third place. This small lexical ranking regression is disclosed;
the full top-five coverage and canonical ownership remain intact.

The initial docs check lacked the companion files required by the frozen fact
fixtures. Restoring exactly the five files from the CI-pinned companion revision
`6a58311982941b75f46e22109a0829e5acb83c7e` reproduces the existing workflow's
layout, without changing questions or checkers. The final documentation check
passes: 94 documents, 181 canonical claims, 1,979 links, 164 anchors, zero errors or
warnings. Current source and retained runtime provenance verification passes with all 18
required LFS payloads materialized. The historical M11 check passes without
rewriting its evidence. Linux ABI floor inspection passes (bundle GLIBC 2.34;
CyberSand GLIBC 2.32/GLIBCXX 3.4.30/CXXABI 1.3.9). The Windows artifact is a
PE32+ x86-64 DLL. Launcher navigation passes 39 assertions with zero failures,
and the explicit `--player-playground --player=liquidswarm` argument test opens
the correct owner and returns through F2 without replaying startup arguments.

At the initial local checkpoint, automatic approval review rejected pushing the
implementation branch because the request did not explicitly authorize external
publication. The complete source and matching desktop runtimes were committed
locally as `57e99b6`. The owner subsequently authorized pushing this branch and
opening its pull request on 2026-10-20. Hosted execution results are recorded in
that pull request against its exact head; this local evidence does not pre-claim
them. Actual Windows runtime execution, gamepad hardware, owner playtesting,
target GPU performance and new browser/WebAssembly execution remain outside
the local evidence. The scene requires the matching native runtime for both
material modes; there is no decorative fallback.
