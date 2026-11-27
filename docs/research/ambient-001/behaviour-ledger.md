---
title: AMBIENT-001 procedural behaviour implementation ledger
status: Current
document-kind: evidence
scope: Pure value engine, module semantics, actual Rapier clock regression and independent review; no playfeel acceptance claim
canonical-for: [ambient-001-behaviour-evidence]
last-reviewed: 2026-11-24
related-documents: [../../systems/ambient-actors.md, mission-ledger.md, perception-ledger.md, authoring-ledger.md]
---

# AMBIENT-001 behaviour lane

This is a Draft/HOLD implementation on accepted main
`00cdb02f103265b6dc5224c68283e9a0c8cb449f`. Actor Compose #762 is not imported.
The local evidence below covers the stated source delta, not an accepted product
release or physical Windows/NVIDIA playfeel.

## Owned source and interface

The lane owns `godot/scripts/ambient/ambient_engine.gd`,
`godot/scripts/ambient/ambient_modules.gd`,
`godot/tests/test_ambient_engine.gd`, `godot/tests/test_ambient_clock.gd`,
`tools/ci/test_ambient_delivery.py`, `docs/systems/ambient-actors.md` and this
ledger. Schema/editor, perception,
actuation and ordinary session integration have different implementers. The
engine receives dictionaries and finite values only. It has no World, node,
RID, mutable cell, position-setting or lease-submission authority.

The public methods are:

- `configure(profile, context) -> {ok, error}` validates a complete authored
  profile and explicit capabilities before replacing the previous valid state.
  Context supplies the stable authored actor ID, original home and capabilities.
- `step(environment, delta_seconds) -> intent` consumes a source-bound
  `ambient-observation/v1` and actual completed physical progression. It returns
  `ambient-intent/v1`, with direction, pace, effort, optional primary pulse,
  candidate explanations and any active override.
- `reset(reason)` retires timers, latches, RNG streams and first-observation
  identity. Profile configuration remains authored. Handoff, disable, replacement
  and reprofile use the owner adapter's reset contract.
- `diagnostics()` returns an independent copy. It performs no sampling,
  randomness, transition, clock advancement or command renewal.

The first valid observation binds run ID, epoch and physical slot. Authored
instance identity is checked against configuration on every call. A new command
control-generation after pause does not reset intentions. A changed run, epoch
or slot requires an explicit owner reset. Repeated observation ticks with zero
progress return the last copied result; positive progress on a repeated tick is
refused. Finite position/velocity and nonnegative physical sampling ticks are
mandatory. If an explicit simulation clock is supplied, its change must match
the supplied progression delta.

## Composition and determinism

Every module has authored `id`, `type`, `enabled`, `priority`, `weight` and
validated `params`. `module_specs()` is the single metadata vocabulary used by
schema, editor and runtime. Authored configuration never contains runtime
state, and applying invalid data preserves the usable producer.

Ordinary active preferences combine their bounded direction, pace and weight.
Close cancellation selects a stable dominant preference; a previous candidate
within ten percent of the strongest score retains the tie. Temporary overrides
select the highest authored priority. Equal override priorities use authored
list order. Zero weight disables a module's contribution, including an override.
Enabled modules with nonzero weight advance private state on a legitimate
decision even when a higher-priority candidate wins; inspecting their candidates
never advances them.

Each actor and module instance has its own explicit 31-bit integer RNG stream.
The seed mixes the profile seed, stable authored actor ID and module ID. The
explicit shared-seed option omits actor ID. UI inspection order and other actors'
updates cannot consume this stream. Same admitted profiles and copied input
streams yield identical decision results in the focused test; this is not a
claim of cross-platform Rapier trajectory determinism.

Timers use supplied completed simulation progression. Pause advances nothing.
First evaluation accepts zero elapsed time and initializes only required state.
Long wall-clock stalls are irrelevant. An actual physical-progression gap expires
persistent intentions by elapsed simulation time, but gaps over 0.25 seconds
break continuous-support and continuous-obstruction debounce inference. The
engine performs at most one state transition per module per decision and does
not run a wall-clock catch-up loop.

## Implemented vocabulary

| Type | Function and release semantics |
| --- | --- |
| `wander` | Per-module seeded heading choices, bounded interval variation, gradual changes and intentional idle periods. Only legitimate movement axes are used. |
| `seek_material` | Acquires the nearest observed target inside the inclusive module radius, approaches a standoff, dwells once, and reacquires after the declared loss cooldown. Ground actors do not invent a vertical route. |
| `avoid_material` | Acquires inside entry distance and retains until exit distance. It is an urgent override. Coincident observations use a stable seeded direction, not a changing arbitrary sign. |
| `avoid_ledge` | Uses exact per-module support lookahead and enough searched depth. A grounded trigger latches its original retreat direction and duration once. Continuous safe support is required to rearm; unavailable samples break continuity. |
| `avoid_boundary` | Handles canvas/region margins separately from terrain. Flyers combine inward corner axes. A finite inward latch rearms only after reaching the release margin. |
| `escape_obstruction` | Requires requested movement, actual nonprogress and available contact proximity; debounces a finite reversal and cooldown. Optional jump is a single compatible grounded primary pulse. |
| `return_home` | Homeward steering outside the outer radius, held until the inner release radius. Ground actors use horizontal home distance. |
| `rest` | Seeded active intervals and finite neutral rest overrides. Higher priority safety reflexes may interrupt the selected rest. |
| `follow_actor` | Uses copied compatible nearby actor positions, an observed-radius limit and a comfortable separation band. |
| `avoid_crowding` | Weighted local separation, with stable opposing directions for coincident actor identities. Symmetric neighbors do not manufacture a preferred side. |
| `maintain_altitude` | Home-relative vertical correction with a tolerance band, admitted only for legitimate vertical-capable rigs. |

Material radii and neighbor radii are capped at the admitted 96-cell sensor
extent. Material perception is sparse: a target is the nearest *observed* cell,
not a guaranteed nearest material cell or a passability result. Insufficient
sensor extent, unavailable data, inconsistent target distance/coordinates and
missing exact ledge reach/depth are diagnosed rather than used as zero/safe.
An existing finite ledge retreat remains latched through a later sensor outage;
new terrain-dependent acquisition requires available samples.

## Adding one bounded module

Add its stable metadata to `module_specs()` with typed defaults, finite ranges,
units, required observations and capability tags. Add a named value function
and one dispatch case in `evaluate()`. The function receives only authored
parameters, copied observation, private per-instance state, explicit simulation
time and copied capability/home/previous-intent context. Return an inactive
reason or a bounded steering/override candidate. Use the module's own RNG helper;
never the process RNG, a wall clock, UI visibility or another actor's state.

Declare entry, hold, exit, unavailable-data and reset semantics before adding a
preset. Include an independent input-stream fixture that exercises those
semantics, unsupported capabilities, malformed observation and boundary cases.
No session-owner branch or new arbitrary scripting evaluator is needed merely
to add another pure module. A genuinely new sensor or actuator still requires
its separate owner-mediated capability contract and actual integration tests.

## Focused execution checkpoint

Command: `Godot_v4.7-stable_linux.x86_64 --headless --path godot --script
res://tests/test_ambient_engine.gd`. Runtime:
`4.7.stable.official.5b4e0cb0f`; Linux 6.18.57 x86_64. The project initialized its
retained Rapier extension, but this suite deliberately executes no physical
step or material World.

On 24 November 2026 the suite passed **850 checks, zero failures**. Coverage
includes radius-50 inclusivity and exclusion; Oil relocation; Water override
and hysteresis; stale, missing and contradictory measurements; finite dwell;
latched ten-second retreat, pause, release, continuous rearm and second trigger;
wall/ledge/boundary distinctions; corner retreat; actual-progress obstruction
debounce; a single jump pulse; five hundred identical seeded decisions;
independent/shared seeds; immutable inspection; failed edit preservation;
identity/clock refusal; exact per-module ledge reach/depth; long actual-time gaps;
and every exposed additional module's functioning result.

An informational pure-value workload measured eight actors, ten modules per
actor, 300 decisions each: 2,400 decisions in 423,639 microseconds, mean
176.51625 microseconds per decision. Earlier runs measured 182.35 and 211.00
microseconds. These are shared-host GDScript timings, not sensor cost, frame
latency, native throughput, a scaling acceptance result or owner hardware data.

The source delta at this checkpoint had SHA-256:

| File | SHA-256 |
| --- | --- |
| `ambient_engine.gd` | `ce2d406dcb8bb23a78a4a3efed360e76e47ddbfabb957fe67c16b17300696b04` |
| `ambient_modules.gd` | `c331a0a49a4d521e7400043484e8360d02f0a2a5fb3d6f331f55e6f193bba50c` |
| `test_ambient_engine.gd` | `95105d209e9a826f5deecab28d396b80580f091e763d92bc1a135149dec46981` |

This is the retained earlier checkpoint, not the later source below. It is not
a substitute for the final integrated-source qualification.

## Reviewed engine and actual-clock checkpoint

Later on 24 November 2026 the same pinned Godot 4.7 command passed **877 checks,
zero failures**, including the concrete review repairs after the 850-check
checkpoint. Added coverage rejects the 30-cell no-hit wall sentinel as contact,
enforces actual 96-cell neighbor extent and verifies that correlated actor IDs
and profile seeds do not cancel into synchronized RNG streams. Seed mixing now
hashes separately delimited seed, actor and module identity fields; no process
hash or global random generator participates.

This run measured 2,400 copied-value decisions in 471,797 microseconds, mean
196.582083 microseconds, using the same eight-actor/ten-module/300-decision
workload. The separate native-motion lane was running concurrently. These are
informational shared-host measurements with no isolated-hardware, physical
scaling, sensor-cost or frame-budget claim.

Command: `Godot_v4.7-stable_linux.x86_64 --headless --path godot --script
res://tests/test_ambient_clock.gd`. The new focused fixture passed **21 checks,
zero failures**, using the actual retained Rapier bridge and one admitted
Runner. Ten real manual bridge steps yielded 0.166666666666667 completed seconds.
It created no native material World and performed no rendering. Checks include:

- A completion callback without a bridge step and an advance request without
  physical progression consume no ambient time.
- A requested delta of 0.2 seconds followed by one genuine fixed step advances
  only that step's duration; several actual bridge steps are counted exactly.
- Wall-clock frames while paused consume no private timer state. Resume rejects
  the old issued command and issues fresh authority while preserving the body.
- Human handoff and ambient handback preserve the physical RID and restart
  private intentions at the current physical time.
- A nonfinite live profile is refused before producer retirement; the valid
  private state and physical body remain intact.

The source files recorded for this later local checkpoint have SHA-256:

| File | SHA-256 |
|---|---|
| `ambient_engine.gd` | `4c05449d0390782ab4f2427e3f1d03ca1f8c9fbee8ac54cf132894c7638b6834` |
| `ambient_modules.gd` | `6077e1aff117747c2217a20cd698cda587f9dc47434d8f63e0ee616cac33c2f1` |
| `test_ambient_engine.gd` | `6ff15b391ea9b874750da61240e8d30c4d3dc6e72567c50b873e5f07f883b604` |
| `test_ambient_clock.gd` | `359a0c95bf10b10c31a8b5f1829fd729fb6d204b7c2079e40b4acbc6ecd8bdac` |
| `physical_actor_session.gd` | `edb16c4fa1c7915baa24f1a7e0f5012584dfdea5272e15b877a1fa9631df48c7` |
| `workbench_actor_control.gd` | `342a925a2ba0df06599768879fbb04e9f687dac21c0d72147cb1253b51c0cbff` |
| `ambient_profile.gd` | `cd0233dc4863a6acad9ff74feeb871e4766714e68bbac22b11712353a2141157` |
| `ambient_actuator.gd` | `11c14b1e2eca8e8623ac328e36ebf47d269fab17b329be07a0abfe66080608ef` |

Lane B independently authored and ran `test_ambient_independent.gd`: **214
checks, zero failures**. Its audit combines actual copied Perception, Engine and
Actuator values for conflicting native IDs, stale/refresh neutrality, an empty
profile, caller/inspector mutation isolation, per-module stream independence
under reordering, and real wall/no-hit/jump capability semantics. This evidence
is the independent implementer's reported result, not a second execution by A.
The test source hash is
`3ee20a3ee1195746ff007597e33e23cb3052c01ec91ef8213eddeb26e3026f9a`.
The separate B ledger records its command and runtime details.

C independently reran the current engine suite and reported **877 checks, zero
failures**, with a mean 185.24 microseconds in that run's same pure-value
workload. C also reviewed the canonical contract against the final authored
schema/editor and found no authoring contradiction. These are independent
reported observations, not extra executions by A.

The mission ledger owns the final complete source manifest and integration
freeze. Changes after these local checkpoints must retain this scope and record
their own relevant rerun; the earlier and later hashes must not be substituted.

## Independent delivery-contract review

A reviewed the lead's qualification runner and packaging custody while keeping
the gameplay implementation frozen. The final input selection binds tracked
Godot scripts/resources and native inputs, the actual loaded project, retained
runtime artifacts and pinned engine before and after execution. Fresh campaign
directories isolate test userdata; only the authored save/reopen pair shares a
directory, and those tests refuse to overwrite an existing save.

Concrete review findings and lead/B repairs were:

- The inherited source enumerator found new GDScript files but initially omitted
  new untracked profile/example JSONs in development-delta reports. The ambient
  runner now explicitly registers those authored inputs.
- Exit code zero and an error-free log did not independently prove each fixture
  reached its final assertions. Every scoped case now requires its unique
  positive terminal result with zero failures; rich reports are also hashed.
- A process receipt replaced with `{}` passed a subset-key comparison
  vacuously. Every original receipt is now separately SHA-256 bound before
  parsing, including import and graphical execution receipts.
- The native-motion report initially selected Linux runtime filenames even
  for a future Windows run. B changed it to hash the actual platform DLL/SO,
  GDExtension selectors and executing Godot binary.
- Regenerated import metadata needs a precise exemption. Packaging permits only
  the previously reviewed Rapier image sidecars, original script UIDs, import
  caches and portable userdata; additional executable project scripts remain
  refused. C reviewed the packaging path independently.
- Graphical evidence requires all five ordinary example phases, each with at
  least 120 physical and 119 native ticks, and twelve unique expected images.
  Missing/duplicate phases or images cannot be substituted by a large total
  image count. Displayed actor/material publication metadata remains distinct
  from current copied physical poses.

Command: `PYTHONDONTWRITEBYTECODE=1 python3 tools/ci/test_ambient_delivery.py`.
The focused temporary-file suite passed **35 unittest methods**, with all
15 case-terminal variants and the relevant negative cases as subtests, in
0.046 seconds on this host with Python 3.12.14. It directly exercises
runner/packager verifiers for
wrong/absent/repeated terminal results, nonzero failures, modified logs,
receipts/reports/images, source-delta refusal, unexpected pristine payload,
post-launch script injection, the reviewed import allowlist, unauthenticated
engine bytes, missing/duplicate/headless/incomplete capture evidence, wrong or
missing graphical source/engine/backend identity, and missing or contradictory
displayed material/actor-frame metadata. An explicitly unavailable displayed
frame remains labelled as a fallback rather than being treated as a matched
publication.

These fixtures are deliberately synthetic verifier inputs. They create no
native World, run no Godot process, capture no real image, authenticate no
synthetic runtime and publish nothing. Their purpose is to demonstrate refusal
and preservation behaviour; actual committed-source gameplay, graphical capture,
pristine extraction and Windows execution remain the separate mission gates.
C independently reviewed these tests' temporary-fixture scope and verifier
entry points. Any later verifier change belongs to the final source freeze and
its rerun, not an extension of this recorded checkpoint.

## Independent review and limitations

C independently identified the unavailable-support rearm continuity defect;
A repaired it and added a discontinuous-observation regression. A's review
identified the editor reading authored data instead of live diagnostics, stale
editor Apply across same-model actor replacement, neighbor sensor/radius mismatch,
zero sparse-sample coverage, and shared maximum-lookahead misuse across ledge
modules. Source reinspection confirms live diagnostic reads, run/epoch-bound
editor application, strict compatible assignment, exact per-module ledge samples,
zero-coverage unavailability and same-affordance copied neighbors. C and B own
their independent qualification of those repairs.

A's integration review also found that the first clock draft counted requested
actuator delta rather than actual fixed-step completion. The lead repaired the
clock using the bridge's completed manual-step counter; the 21-check actual
Rapier fixture above independently verifies it. Physics now ingests its newest
validated native publication before decisions, and B's monotonic publication
guard prevents an older render callback from restoring stale authority. Cache
activation is restricted to enabled ambient producers with material requests.

The assisted-flight action review found that 4LY's real API has no separate
effort channel. B added an explicit capability explanation; C disables the
Effort widget for those rigs. Pace remains its desired-velocity request; this
repair does not multiply unrelated values or change motor tuning.

The pure suite establishes selected intent, deterministic module state and
schema interactions. It does not prove that a body reaches a material, clears a
ledge, has adequate thrust/resources, or remains aesthetically convincing. There
is no global routing, terrain passability map, learned model, new material law,
combat controller or physical immunity. Supported ground, wheel and flight
motion, native material response, ordinary Workbench interactions, persistence,
Windows packaging and human playfeel remain separately evidenced integration
and acceptance gates.
