---
title: Expanded playground districts, player tuning and usables
status: Current
document-kind: evidence
scope: Owner-requested player feel changes, eight six-times-area maps and physical/material usable integration; actual Windows headless results and explicit remaining gates
canonical-for: []
last-reviewed: 2026-10-26
related-documents: [../systems/player-control-playground.md, 2026-10-26-player-playground-maps.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md]
---

# Expanded playground districts, player tuning and usables

## Checkpoint and source identity

This is the owner's follow-up to the [first map checkpoint](2026-10-26-player-playground-maps.md),
implemented on `codex/player-playground-maps` / PR #262 from base
`4329e2f5174a24bbebf939a479e68481ac71bb39`. Accepted main remains
`9e53a5b1b501e0667037b8502d3c1d15089211f5` at preparation. PR #262 was returned
to draft during iteration; prior-head hosted results do not certify this delta.
The dated [actual Windows packet](2026-10-26-player-playground-expanded-windows.json)
records that base plus canonical-LF hashes of every changed/new executable
script, exact process argv/timeouts/exit codes and raw log hashes. Those source
bytes remained unchanged through the final cohort. The focused branch/commit
history is the recovery path. Unrelated dirty `C:/khybersand` and all parked LCB
successors remain untouched.

Godot is `4.7.stable.official.5b4e0cb0f`, actual Windows console SHA-256
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`;
Rapier 0.35.2 Windows SHA-256 is
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
Both retained manifests' 80 native input hashes still match current source;
actual DLL/SO hashes remain `e3f17363d21260690682dfaa9e5e118253544c1b9b19e69e50c03af567712343`
and `02ea0661d3a62e2ab346c3fe46f9f85b808c6a0099c639144f053dc70a5c3d46`.
Their publication source stays `5f02d089ee4cff8b34421cc4ca58bb4ef50dd92c`.
There is no C++/binding, LFS runtime, dependency, native law, Water-default or
C64/E8 change and no new runtime publication. Broad historical script/build
manifests are not relabeled as matching this new host script set.

## Implemented scope and actual movement measurements

The [canonical controls](../systems/player-control-playground.md#stronger-player-controls-and-usable-testing)
own exact user behavior. Mechanical tuning also reaches the existing F5 SetP
catalogue; other actor families and immutable 4LY profiles retain their controls.

| Measurement | Previous same-fixture control | Tuned actual result |
|---|---|---|
| Buggy supported hop height | 6.6023 cells | 12.5777 cells; **1.905×** |
| Bike full-preload supported hop height | 14.8839 cells | 28.9592 cells; **1.946×** |
| Rear-wheel lean, 12 free-air ticks | Previous control was centre-applied torque | Buggy 0.7486 rad; bike 0.8135 rad, with actual tangential linear impulse plus torque around named rear wheel |
| Lander free fall after 20 ticks | Drift gravity 32 cells/s², final downward speed 10.9517 | Damped gravity 96 cells/s², speed 25.6004; actual Rapier gravity scales read independently |
| Barrel root inertia | `2.4 × (9²+12²)/12` | Actual property ×0.85; mass unchanged |
| Barrel sustained thrust | Prior soft speed target 155 | New soft target 175; actual fixture speed 182.3753 cells/s because limiting is a finite braking impulse |

The hop comparison changes only the upward multiplier between 1 and √2 in the
same actual rig/floor fixture. It does not infer doubled height solely from a
constant. Charge/release/support/cooldown/cancellation remain enforced. Rear
steering applies bounded impulses, never sets poses or pins the wheel to the
world. Detached equipment is excluded from mode-dependent gravity updates.

Material players use five unchanged native radius-32 fields spanning radius
60, with copied individual subreceipts, native-centre clamping and bounded
periodic/inward/tangential idle flow. Aggregate counts are samples and movement
operations; overlapping calls may affect a parcel more than once. Native
per-call budgets remain unchanged; the owner performs at most 21,125 scan
positions, 2,560 source captures and 10,240 move attempts per admitted step.
Neutral motion still requires a current issued lease. Sand counts and exact
Water mass remain conserved in the isolated idle and existing owner fixtures.

Every selectable map is now **1024×768**, six times 512×256, exceeding the
requested fourfold area without extending the native finite World. Eight
distinct deterministic layouts each contain at least 100 authored rectangles
and at least 15 material IDs, with ground-level editable targets, elevated
service benches, multi-storey/open-floor structures, ramps/steps, reservoirs,
flight slaloms, granular sieves, salvage racks and different traversal routes.
Old `mixed` is now expanded Mixed Works; the original small course is explicitly
retained as the `legacy` fixture for scoped regressions. Overview and follow
coordinates now use the larger bounds; follow view is 384×288. All maps remain
available to every player. Layout complexity/selection is not proof that every
complete route has been traversed by every player.

All 32 existing catalogue usables are selectable. Actual mounted mechanical
equipment consumes existing identity/charge/cooldown/lifecycle paths. Material
players use the existing material-only runtime with a visible emitter 68 cells
along aim, avoiding self-occlusion by the cloud. M triggers, B alternates;
N/U drops/reattaches only for mechanical players, which have actual held bodies.
Paused commands refuse, quick press/release before a tick is preserved,
selection does not refill resources, and map reset clears old projectiles/devices.
Usable operations mark practice laps. Native source laws and processor recipes
are reused, not reimplemented in the playground.

## Final actual Windows cohort

All commands are pinned Godot `--headless --path godot --script res://tests/NAME.gd`,
420-second local watchdog per process, three isolated test processes at most,
one native worker per playground owner. **All 14 processes exit zero**, have
their expected zero-failure footer and no script/engine error. There are
**9,895 assertions/checks** in this cohort:

| NAME | Assertions/checks | Outcome |
|---|---|---|
| `test_player_playground_maps` | 4,770 | 336 actual 8-map × 7-player × 6-Water configurations; area/material/complexity, native readback/receipt/bodies, real ticks, authoring/UI/reset |
| `test_player_playground_tuning` | 112 | Actual hop/lean/gravity/inertia/speed; broad idle field, conservation, positive tool/projectile/processor swarm paths, five mounted tool paths, quick taps, pause refusal, native-edge safety |
| `test_player_playground_runtime` | 1,333 | Retained legacy owner/native/Rapier/input lifecycle plus actual expanded scene controls |
| `test_player_playground_course` | 1,440 | Legacy physical spawn/vehicle/tunnel/lander routes under tuned controls |
| `test_player_vehicle_controls` | 79 | Real traction, preload, cancellation, flight damping and braking |
| `test_player_material_field` | 56 | Unchanged native binding admission/state/conservation contract |
| `test_physical_actor_arena` | 915 | Shared native/Rapier arena roster, bounded effects and terrain |
| `test_physical_actor_session` | 113 | Shared authority and session contracts |
| `test_physical_actor_integration` | 389 | Actual actor integration |
| `test_physical_usable_equipment` | 307 | Existing equipment identity/selection/admission |
| `test_physical_usable_lifecycle` | 39 | Existing mounted/released equipment lifecycle |
| `test_physical_usables_runtime` | 243 | Actual native material effects with catalogue size 32 |
| `test_usable_session` | 28 | Existing usable session and copied snapshot contracts |
| `test_physical_usable_course` | 71 | Retained physical usable course |

Final packet SHA-256:
`1e2977b7ee66f4c4c4fe659800fa4152361b78a77858748e09d72e05c59939ef`.
Original logs/receipt are at
`C:/Users/_/.codex/tmp/playground-expanded-final-validation-v2`.
The 336-setup case takes 95.91 seconds on this Windows workstation; CI retains
its finite 420-second case budget. Physics comparisons are simulation-step
measurements, not wall-clock gameplay or performance acceptance.

## Retained failures and bounded corrections

Earlier logs remain in `C:/Users/_/.codex/tmp/playground-expanded-*.log` and the
first complete 14-case packet remains at
`C:/Users/_/.codex/tmp/playground-expanded-final-validation/RECEIPT.json`.
The final source/log packet and dated failure index keep their identities.

- Initial tuned buggy lean missed the registered 12-tick rotation screen.
  Steering authority was increased to the final 11/12 rad/s, 90/95 rad/s².
- The new idle test initially sent an empty action, which the existing strict
  session API correctly refuses; it now sends an explicit neutral movement.
  The interrupted process lacking a final footer is not a pass.
- Material usable origins initially started inside their own occupied cloud,
  causing real occlusion refusals. The integrated origin now sits at the
  displayed field edge. No collision/refusal rule was weakened.
- Subsequent positive fixtures tried firing during the prior item's retained
  cooldown, then placed a processor into the legacy ceiling after an extended
  upward idle trajectory. These legitimate refusals remain recorded. Positive
  category tests now start a fresh open staged fixture; paused refusal and
  normal retained cooldown semantics remain unchanged.
- The retained lander route's old controller supplied gravity feed-forward 32
  after real damped gravity became 96 and could not reach its staging point.
  The controller now supplies actual 96; physical gate/walls, reach tolerance
  and bounded force/speed targets remain. Actual final nearest gate is about
  1.25 cells and the same three staging points are reached.
- The first complete 14-suite pass preceded three added accessible ground-level
  targets and clearer control/resource readouts. A second full cohort freezes
  those final source bytes and passes all 14 again; the first receipt remains.

## Documentation and qualification limits

Canonical updates cover player controls/maps/usables; physical rigs for SetP;
configuration for exact bounds; interfaces for unchanged native call versus
composite owner; ownership for devices, lease/cancel and detached gravity;
README/index/retrieval/handover/roadmap for discovery and scope. PLAY03/04/06
are reconciled with Current source and PLAY07 adds the tuning/usable question;
the frozen question set is unchanged. No solver ADR or ABI migration follows.

Exact-head documentation/provenance and applicable hosted runtime gates plus
independent review remain required before merge. Final local documentation
receipt, current PR head and any active CI are recorded at PR #262. Local
Windows headless results do not establish interactive feel, full route
completion, hardware controller input, GPU presentation or Linux execution.
Web/browser/shader testing remains owner-deferred. No MAT/material-fidelity,
new solver architecture or #203 scientific campaign is started; #202/#203 are
not closed by this usability checkpoint.
