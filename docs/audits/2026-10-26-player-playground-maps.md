---
title: Player playground maps, Water selection and material authoring
status: Current
document-kind: evidence
scope: Seven added maps and independent player/map/Water controls; actual local Windows headless setup and authoring qualification, with hosted/manual gaps explicit
canonical-for: []
last-reviewed: 2026-10-26
related-documents: [../systems/player-control-playground.md, ../operations/local-build-and-validation.md, ../reference/validation-evidence.md]
---

# Player playground maps, Water selection and material authoring

## Source and recoverable scope

This separate owner-requested usability checkpoint starts from accepted main
`9e53a5b1b501e0667037b8502d3c1d15089211f5` in
`codex/player-playground-maps`, isolated at
`C:/Users/_/.codex/worktrees/player-playground-maps/khybersand`. The dirty
`C:/khybersand` material branch and every prior LCB successor remain preserved.
The committed [Windows evidence packet](2026-10-26-player-playground-maps-windows.json)
binds the exact canonical-LF source delta and actual log hashes to this base;
it does not pretend a dirty overlay was already a commit. The focused PR and
commit history provide the recoverable checkpoint. Final hosted results, if
pending, must be read separately at that PR's exact head before any merge.

Seven new authored maps supplement the original mixed course, with independent
selection across every player. Six existing native Water assignments, bounded
material bursts/painting/erase and practice-lap identity are exposed through the
existing synchronous owners. The canonical
[player guide](../systems/player-control-playground.md#seven-tailored-maps-water-selection-and-painting)
owns actual controls, maps, limits, reset and refusal semantics.

## Runtime and dependency identity

Actual Windows x86_64 execution uses pinned Godot
`4.7.stable.official.5b4e0cb0f`; console executable SHA-256
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`.
Rapier 0.35.2 Windows SHA-256 is
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.

The inherited App003 publication source remains
`5f02d089ee4cff8b34421cc4ca58bb4ef50dd92c`, with unchanged manifests/libraries:

| Platform | Published native library SHA-256 | This checkpoint's execution |
|---|---|---|
| Windows x86_64 | `e3f17363d21260690682dfaa9e5e118253544c1b9b19e69e50c03af567712343` | Actual pinned engine and Rapier, seven focused suites |
| Linux x86_64 | `02ea0661d3a62e2ab346c3fe46f9f85b808c6a0099c639144f053dc70a5c3d46` | Bytes/source-input comparison only; no local Linux execution |

All 80 native inputs in each retained runtime manifest compare exactly to
current canonical source and both actual library bytes match the manifest.
The materialized 18 LFS payloads are retained. No C++/binding, dependency pin,
default policy, carrier C64/E8, compiled flag or runtime artifact is changed.
The old 535-entry broad build maps retain historical scripts/tests; they are
not a hash identity for these new GDScript controls. No runtime publication is
required for this script-only source delta, and no full host/module/script
qualification follows from native input equality.

## Actual local Windows cohort

Commands use `Godot_v4.7-stable_win64_console.exe --headless --path godot
--script res://tests/NAME.gd`, one native worker per playground owner, actual
Rapier mechanical sessions. Each process has a 420-second watchdog in the
local harness; CI discovers the new 336-setup test automatically and gives that
case its own finite 420-second timeout and scheduling weight. Other case
timeouts remain unchanged. Engine initialization/import completed before tests.

| NAME | Assertions / failures | Actual wall seconds |
|---|---|---|
| `test_player_playground_maps` | 4,754 / 0 | 85.157 |
| `test_player_playground_runtime` | 1,329 / 0 | 20.188 |
| `test_player_playground_course` | 1,475 / 0 | 5.063 |
| `test_physical_actor_arena` | 915 / 0 | 14.937 |
| `test_physical_actor_session` | 113 / 0 | 0.703 |
| `test_physical_actor_integration` | 389 / 0 | 15.047 |
| `test_physical_usable_course` | 71 / 0 | 14.344 |

All seven actual processes exit zero, contain their intended zero-failure
footers and contain no engine/script error. The accepted independent log
reduction is retained locally at
`C:/Users/_/.codex/tmp/player-playground-final-validation/ACCEPTED-REDUCTION.json`,
SHA-256 `efd85d9e6d2b53acfd449ba454fd23ffa8353f9d97b7f1143940755df29a789f`.
The committed packet copies its exact contents. The full source delta is fenced
unchanged through execution; raw stdout/stderr hashes and commands are included.

The new test performs **8 × 7 × 6 = 336 actual configurations**, independently
reads native Water family/variant, explicit radius and tick-zero setup receipt,
compares initial body count with actual render/body parts, verifies four clear
checkpoint centres, spawns full-cell Water and runs three admitted player/native
ticks. Separate regressions check both mechanical and material owners: invalid
paint nonmutation, exact paused disc counts, occupied-cell preservation,
explicit replacement/erase, stored-cell/body-mask protection, protected course
boundary, reset and failed replacement. Real scene tests check selector retention,
native applied readback, paused spawn/practice status, painting input exclusion,
overview/follow pointer coordinates, outside-view nonmutation and restart.

The original course tests still demonstrate actual buggy/bike ramp approach,
mounted acrobat tunnel clearance and a short lander flight gate. They do not
prove full traversal of each newly authored route. Shared arena and usable
regressions retain the non-playground config/reset and actual Rapier schedules.
The sharding tests pass 25/25 and the CI-provider policy checker passes.

## Preserved failures and reduction corrections

No historical records were overwritten. The first ad-hoc new runner stopped
on the wrong copied policy dictionary key `family`; the actual receipt uses
`applied_family`/`applied_variant`. That incomplete process was interrupted and
is not a success. The second runner reported 62 fixture failures: 56 expected
FreeMass spelling mismatches (`free_mass_v1` versus actual `freemass_v1`), and
six incorrect assertions that the composed body cell would be Empty. Composed
body masks correctly read as Wall; corrected assertions independently inspect
stored cells and actual body IDs. The intermediate corrected matrix passed
4,750 assertions; the final cohort adds four pointer/zoom/letterbox assertions.

The original local cohort detector accidentally matched `assertions=915
failures=0` and `assertions=71 failures=0` as positive failure counts. This was a
reduction defect, not a native failure. Its original receipt SHA-256
`e11d1d71f534cb9e320d40c03dc5824ec2d0f18150ca4a88fa674424fc25326e`
and exact logs remain intact. The accepted reduction authenticates every log,
requires actual exit zero and zero-failure footer, and rejects script/engine
errors and correctly parsed positive failure counts. It does not rerun or
reinterpret a failed engine process as a success.

## Documentation and acceptance boundary

The documentation change map is: player contract for controls/map ownership;
configuration for capacity/radius/spawn bounds; ownership for mutation windows
and provisional sessions; README/index/retrieval routes for discovery; roadmap
and handover for scope; this audit/packet for dated execution. Existing native
interface layouts, solver ADRs, body-mask ABI, worker/lifetime invariants and
scientific thresholds do not change. New source-linked retrieval question
PLAY06 supplements the immutable frozen set. Historical failures remain separate.

Final documentation checks are recorded at the focused PR. No merge is claimed
before exact-head applicable Documentation/provenance and Godot checks plus
independent review. Linux hosted execution, interactive Windows feel, complete
new-map routes, actual gamepad use and visual fit remain distinct acceptance
scope. No additional Web/browser/shader testing is performed. #202/#203,
scientific campaigns, MAT and material-fidelity work are not expanded or closed.
