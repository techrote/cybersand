---
title: 4LY-003 flight laboratory and actual-host episode contract
status: Current
document-kind: contract
scope: Experimental single-host physics episode API and scored frozen teacher; external final-custody signoff and learned-policy qualification remain separately gated
canonical-for: [4ly-flight-lab, 4ly-episodes, 4ly-scripted-teacher, 4ly-training-contract]
last-reviewed: 2026-10-24
related-documents: [physical-free-flight.md, physical-actor-rigs.md, ../operations/physical-actor-programme.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../audits/2026-10-23-4ly003-checkpoint.md, ../audits/2026-10-24-4ly003-final-qualification.md]
---

# 4LY-003 physical flight laboratory

## Current implementation and explicit admission boundary

Issue [#207](https://github.com/techrote/cybersand/issues/207) follows
4LY-001/#205 and 4LY-002/#206, merged as [PR #223](https://github.com/techrote/cybersand/pull/223)
at `1f9336388f11be39abaae340a781a5eef52115d4`.
All four real physical profile hashes and the unchanged source controller
`fb86190c68c6a87e7d2ef7e845b1fb97305f188723a326f67f07caa6971cc8ae`
are prospective admission requirements. The source string
`calibration = "candidate_4ly002"` remains untouched.

**Current implementation** provides a native-material flight course, playable
lab frontend, real synchronous episode owner, bounded local ray sensing and
an observation-only reference teacher. [The 2026-10-24 score audit](../audits/2026-10-24-4ly003-final-qualification.md)
records a **passing frozen-teacher physical final score**: 224/224 traces
independently read back, 157/160 nontrivial family successes, all 48 negative
controls without navigation credit, and zero faults. Three Hauler obstacle
failures remain visible. This result is scoped to the recorded Linux host,
teacher and suite hashes. The run-local final-suite generator was authored
after the teacher freeze, but not held by a separate external custodian;
an automated reviewer label does not establish independent human signoff.
Earlier public layouts remain retired by [split amendment v3](../../godot/tests/fixtures/4ly003_split_amendment_v3.json).
The runtime still refuses final access without separately supplied exact
source/teacher/suite admission. This is **not** a 4LY-004 learner admission.

In-game entry: choose **4LY Flight Lab** in the feature menu, click
**4LY flight lab** in the main sandbox, or launch with `--flight-lab`.
The independent lab scene is **an entry mode of the same Godot application**,
not an alternate physics engine. It uses the existing
`CyberPhysicalActorArena` and `CyberPhysicalActorSession`:
`CyberNativeCellWorld` -> copied native rigid-body mask ->
native physics tick/coupling -> Rapier hard-terrain colliders and real body ->
owner observation. One Rapier body per drone retains the configured mass,
inertia, gravity, native mask, force/torque and controller unchanged.
Desktop sandbox physics remains a separately paced host; the
headless arena is a *synchronous* but fully physical execution route.
The interactive flight scene invokes that same synchronous arena on
each 60 Hz Godot physics callback.

Game view: profile, scenario and producer selectors all perform a **fresh
physical reset**. W/A/S/D or arrow keys request normalized desired velocity;
scripted teacher and optional external policy submit through the same owner.
External policy mode does not advance until an actual action is supplied;
it does not fake a learned policy. Rendered start, goal/radius,
obstacles and current rigid-body footprint are presentation only. F2/Exit
returns to feature selection. Existing sandbox maps, actor selector,
scientific fixtures, materials and learned Jolt lane are untouched.

## Scenario and geometry contract

`CyberPhysicalFlightCourse` owns fixed seeded scenarios in the rectangle
`(128,128)-(640,352)`, with native-material perimeter and obstacles:

| Scenario IDs | Family / mechanics |
|---|---|
| `unsupported_hover` | Hover and low-speed dwell; not navigation credit |
| `horizontal_reach`, `vertical_reach`, `diagonal_reach` | Directed free-space movement |
| `reverse` | Reach one waypoint, reverse and dwell at the second |
| `arrival_braking` | Long-range arrival and speed-controlled settling |
| `wide_corridor`, `offset_gates`, `corner`, `slalom` | Finite native material obstacles with profile-relative clearance |
| `wall_recovery` | Bounded host disturbance, actual Rapier contact and subsequent recovery/arrival |
| `neutral_control`, `constant_control`, `power_off` | Negative controls must demonstrably fail remote-target low-speed dwell; any genuine navigation success fails the negative gate |

Recovery qualification is **not** satisfied by merely routing around the wall.
The evaluator requires an accepted bounded host-disturbance receipt and at least
one authoritative Rapier contact at or after that disturbance before a later
low-speed arrival can receive recovery-family qualification credit. The policy
observation still receives neither contact count nor disturbance schedule.

Nominal obstacle gaps are recorded separately from **measured** feasible
transits: `feasible_clearance()` reports gap, actual profile collider
dimensions, nominal margin and `clearance_measured=false`.
An obstructed Hauler episode cannot be scored as a learned-policy
failure until physical feasibility is demonstrated. Environment
randomness affects bounded authored geometry only; dynamics, response
and controller are unchanged.

**Development and tuning** retain distinct start/goal/obstacle geometries,
not merely different seed labels. The
[original numeric threshold registration](../../godot/tests/fixtures/4ly003_qualification_registration.json)
still binds per-profile gates. Geometry-only
[split amendment v2](../../godot/tests/fixtures/4ly003_split_amendment_v2.json)
repairs pure vertical/horizontal/hover semantics; the later
[v3 amendment](../../godot/tests/fixtures/4ly003_split_amendment_v3.json)
explicitly retires disclosed public final examples. The published game
checkout **cannot access the new final suite**. For genuine final admission,
an independent reviewer must supply separately held
`user://4ly003_sealed_final_suite.json` and an
`user://4ly003_final_admission.json` binding the exact approved teacher,
GitHub checkout source and suite SHA-256. Until then final episode reset
fails closed. No final geometry is passed to a policy.

## Episode lifecycle and authority

`CyberPhysicalFlightEpisode` is the episode owner. `reset(model,scenario,
seed,split,source)` creates fresh native World, isolated Rapier space,
physical chassis, new session epoch/run ID, and invalidates all previous
action authority. `observe()` publishes a fresh copied policy view.
`tick(action, observation_id, repeat_ticks)` accepts a new action **only**
at 6-tick decision boundaries, with 1-6 real 60 Hz physical steps per
call and never beyond the next decision boundary. Omitted actions carry
only an already-admitted controller request while its v2 lease remains
live; this includes a missed fresh decision at a six-tick boundary and
never creates or renews authority. `tick(null, "", n)` therefore may
advance the current lease to the next decision boundary or physical lease
deadline. If no live lease exists, a boundary call without an action fails
`missing_decision` before physics advances. The maximum lease remains
12 ticks and fresh policy decisions remain admitted only every six. An action is rejected
*before* any physical step if malformed, nonfinite, stale, wrong epoch,
wrong producer, or made from a revoked observation. One actual Rapier
step and native tick are recorded for each consumed physics tick.

No physical motion may be credited after first success, deadline, actor
fault or administrative failure. The final real observation and physical
receipt are retained. `transition()` distinguishes
`terminated`, `truncated`, `failed`, `success`,
`navigation_credit` and `reason`. Success requires entering
the circle, reducing speed to at most 2.5 cells/s and holding for
36 **consecutive physical ticks**. A high-speed pass-through cannot
meet the dwell condition. A complete episode `record()` holds the
actual `world_tick`, owner-observation identity, action request and
admission, post-step authority snapshot (`producer`, `control_generation`,
`command_live`, `lease_remaining_ticks`, `actuator_mode`, `fallback_reason`),
flight force/torque receipt, physical pose, contact count, dwell and termination.
No direct velocity, position or actuator force writes originate in this layer.

## Policy observation and normalization

The versioned `4ly-observation/v1` dictionary is copied from the
real owner and task goal. Fields in canonical insertion order:

1. `version`, `action_version`, `run_id`, `actor_id`, `epoch`,
   `observed_tick`, `observation_id`, `control_generation`
2. `goal_delta_cells` (Vector2, world +x right/+y down),
   `arrival_radius_cells` (scalar positive)
3. `velocity_cells_per_second` (Vector2), `orientation_sin`,
   `orientation_cos` (dimensionless), `angular_velocity_rad_per_second`
4. `actuator_mode` (string), `assistance_valid` (true only while a live
   admitted command owns a structurally valid controller response; false after
   expiry or cancellation even though the configured controller's reset receipt
   remains structurally valid), `command_age_ticks` (-1 if absent), `command_live`,
   `lease_remaining_ticks`
5. `resources` (continuous authored supply, powered,
   fuel measurement invalid), `capabilities` (copied immutable
   physical *values*, without model name), `local_obstacles`
   (eight world-fixed rays, R/NE/N/NW/L/SW/S/SE, maximum 80 cells,
   normalized hit distance, per-ray validity mask, hit flag)

No absolute goal, scene geometry, route, future disturbance, evaluator
status, reward, score, source profile ID or global map is provided.
The policy producer and teacher see the same dictionary. Owner ray
queries are 8 finite Rapier queries against *actual* installed native
terrain colliders; invalid sensing is explicit with empty arrays and
`available=false`. A valid ray with no collision reports distance
1.0 and hit=false. Controller assistance receives **no** scene
position, target or rays.

`4ly-flat-observation/v1` is a **54-float**, fixed-order
`CyberPhysicalFlightObservationAdapter.flatten()` output:

| Offset (0-based) | Contents | Normalization and supported range |
|---|---|---|
| 0-1 | Relative goal x/y | divide 512 cells, clamp [-1,1] |
| 2-3 | Own velocity x/y | divide respective `desired_speed`, clamp [-4,4] |
| 4-5 | Angle sine/cosine | unchanged [-1,1] |
| 6 | Angular velocity | divide 8 rad/s, clamp [-4,4] |
| 7-11 | Mode one-hot | velocity, neutral, passive_no_lease, power_off, other |
| 12 | Command age | -1/18 when absent, otherwise ticks/18; [-1,1] |
| 13 | Live flag | 0 or 1 |
| 14 | Remaining lease | ticks/18 in [0,1] |
| 15 | Powered flag | 0 or 1 |
| 16-29 | Physical capabilities | width/64, height/64, mass/20, inertia/14000, speed x/240, speed y/240, acceleration/1200, braking/1200, thrust response/5, velocity response/5, max force/24000, gravity/500, vertical force margin/24000, angular drag/8; each clamped [-1,1] |
| 30-37 | 8 local ray distances | [0,1], zeroed if mask invalid |
| 38-45 | 8 hit flags | 0/1, zeroed if invalid |
| 46-53 | 8 validity masks | 0/1 |

Malformed source versions or nonfinite values return an empty result
rather than supplying fabricated observations. Capability scaling
uses published schema bounds; raw physical values remain in the
dictionary for diagnostics, and clipping is declared for the flat
learner input. Negative velocity ratio may exceed 1 after real
contact/impulse (clamped to 4, not silently recast as a new actuator).
All arrays and dictionaries crossing the owner boundary are copied.

Action version `4ly-action/v1` contains only
`{"move": Vector2(x, y)}` with finite normalized components in
[-1,1] and unit-disk normalization. This is wrapped in the existing
v2 `physical_wire_action` envelope, never a second controller.

## Teacher and qualification

`CyberPhysicalFlightTeacher` uses permitted relative goal/velocity,
published braking, acceleration and actuator response, and bounded
local owner sensing. It applies a predictable stopping-distance planner
with PD-like low-speed control and local potential-field obstacle
correction. It has no profile-name-specific branches, future course
geometry, hidden reward or privileged contact knowledge.
The frozen reference was evaluated on the physical host after its
development-only tuning. The [retained score](../audits/2026-10-24-4ly003-final-qualification.md)
meets all prospectively registered per-profile family gates. Three Hauler
obstacle failures remain in the record; platform generality and independent
custody signoff remain open.

**Prospective pass gate**: independently per profile and family,
nontrivial start-goal separation, minimum score counts,
low-speed dwell, arrival/overshoot/contact metrics, zero rejected
commands or physics faults, and zero navigation credit for trivial
controls. Failed episodes and their reasons are retained.
An issue/PR must not be accepted solely because the scripts import.
After freezing the teacher and final geometry, run the separately
registered final qualification on GitHub-hosted actual Godot/native
and review every failed episode. Linux/Windows determinism is not
assumed equivalent; differing runtimes need separate measured checks.

## Training handoff, rewards, and limits

The proposed `4LY-004` interface in
`techrote/neural-cyber-automata#74` shall verify
`4ly-episode/v1`, `4ly-observation/v1`,
`4ly-flat-observation/v1` (54 fields), `4ly-action/v1`,
`4ly_velocity_v1`, 60 Hz, 6-tick decisions, v2 producer lease,
the four exact profile digests, controller digest, course version,
Godot/native/Rapier versions and checkout SHA. Mismatches are
admission failures; never substitute a recorded/dummy protocol fixture
for training physics. One persistent actual host initially;
multi-host concurrency needs an independently measured lane.

**Implemented evaluator-only** bounded reward terms are recorded per
consumed physical tick, not in the teacher/policy observation:
`clip((d[t-1]-d[t])/16, -1,1)*0.3` progress,
`+1.0` only upon nontrivial navigation success **after 36 low-speed dwell ticks**,
`-min(contact_count,1)*0.02` per tick (contact is a 0/1 flag),
`-0.001` elapsed-tick penalty and `-1.0` on a consumed physics fault.
The first tick of each goal has zero progress reward (no prior distance).
`transition(repeat)` returns the accumulated evaluator reward for exactly
its consumed ticks; `transition(0)` grants zero reward, preventing duplicate
training credit. Per-step terms and cumulative totals are retained in the
evaluator trace and metrics only. Administrative deadline is a
**truncation**, not an independently penalized failure. No neural-policy
training has been performed.

`godot/tests/test_physical_flight_lab.gd` supplies actual-host development
smoke, privilege checks and negative controls; it does not score final.
The two new wildcard cases
`test_physical_flight_teacher_dev_free.gd` and
`test_physical_flight_teacher_dev_obstacle.gd` exercise all four
profiles on development-only geometry, retaining every per-tick positive
and failed physical trial in bounded individual JSON files. The separate
Python [readback](../../tools/ci/readback_4ly003_development.py)
verifies the complete SHA-256 inventory, receipt attribution, tick
sequence and positive/negative outcomes after Godot exits; no final
qualification is inferred from a single seed.
`godot/tests/test_physical_flight_pilot.gd` runs a prospectively
capped 960 real physical-tick single-host pilot and records physics
ticks/s, decisions/s, resets, JSON serialization, OS/CPU, Godot and
memory. Transport/inference overhead remains null when unsupported.
[The historical checkpoint audit](../audits/2026-10-23-4ly003-checkpoint.md)
records earlier-source measurements; the [final-score audit](../audits/2026-10-24-4ly003-final-qualification.md)
records the qualified frozen teacher, 224 traced episodes, remaining custody
caveat and later integration checks. All tests use the ordinary real native
and Rapier runtime; no stand-alone simulator is introduced.

## Ownership and exclusions

Game UI owns inputs and screen-only drawing; Episode owns task
terminal and observation projection; Course owns immutable native
geometry; Arena owns native cellular effects and Rapier stepping;
Session owns producer/lease authority; old Flight controller owns
bounded force/torque. The teacher has access **only** to the
policy observation. The native material solver, Water/LCB, 64-bit
cell carrier, general ACT004 scientific fixtures and
Jolt neural learning are not modified by this feature.

An actual positive teacher navigation score is **Measured on the recorded
one-use Linux final suite**, rather than merely planned. External custody
and reviewer signoff remain unverified, and the companion learned-policy
evaluation is still unrun. Never promote the retained score to a different
source/runtime identity without its own conformance evidence.
