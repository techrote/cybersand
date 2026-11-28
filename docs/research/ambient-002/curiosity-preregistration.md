---
title: AMBIENT-002 supplementary curiosity contrast preregistration
status: Current
document-kind: evidence
scope: Six planned physical episodes isolating one authored trait; separate from the primary 194-episode programme
last-reviewed: 2026-11-25
---

# Curiosity-only physical contrast

This protocol is committed before the first physical execution. The application
is frozen at `a7250e15495667b2fcf564cbed1eaa8dea217c45`. An external subclass of
its existing physical apparatus supplies ordinary editable profile and native
scene inputs, and copies additional diagnostic values. It does not modify any
file under the frozen `godot/` project, controller, actuator or physics law.

## Hypothesis and mechanism

Higher curiosity should cause more selected investigation and more horizontal
approach to a newly observed Oil patch when investigation competes with a
routine goal. The production investigation module's approach utility is
`(0.1 + 1.3 * curiosity) * novelty`; patrol utility is `0.9`. Both modules have
priority 30. Investigation weight is 1; patrol weight is 0.5. Consequently the
initial candidate scores are approximately 1.4 versus 0.45 for high curiosity,
and 0.1 versus 0.45 for low curiosity. The fixed persistence trait is 0.5, so the
patrol's temporary retention multiplier is 1.625; it does not prevent a fresh,
high-curiosity discovery from winning. No overriding reflex masks the choice.

This isolates a documented goal-selection mechanism. It does not test a claim
that curious actors always explore more, or that a utility difference proves
human-like intelligence or entertaining play.

## Exact authored inputs

Six 30-second physical Runner episodes run in six fresh native/Rapier Worlds,
one Godot process per episode: curiosity 0.0 and 1.0 under each seed 605, 1701
and 2909. Order is low then high within ascending seed order. Each pair starts
with identical native material bytes, complete actor-pose identity and geometry.
All profile fields except `personality.curiosity` are identical within a pair,
including the ordinary seed, drives, other traits, memory, perception and module
settings. All non-curiosity traits use the standard v2 defaults.

The profile contains `investigate_material` (instance ID `discovery`) and
`patrol_route` (`routine`). Investigation uses all catalogue defaults except
priority 30 and weight 1: Oil material ID16, radius64, standoff12, pace0.45,
effort0.7, approach deadline12s, inspection2s, habituation12s, cooldown8s and
commitment3s. Patrol has priority30, weight0.5, home-relative waypoints
`[-48,0]` and `[-8,0]`, pace0.45, effort0.7, arrival radius6 and leg deadline12s;
its other settings remain catalogue defaults, including two-second dwell and
looping. The two goals initially point in opposite horizontal directions.

The unchanged apparatus spawns Runner at `(220,175)` in a 512-by-256 canvas.
Native Stone occupies floor rectangle `(0,200,512,8)`, outside walls
`(0,0,8,200)` and `(504,0,8,200)`, and pocket walls `(258,190,4,10)` and
`(286,190,4,10)`. Ordinary Oil occupies `(262,190,24,10)`. No material is painted
or actor moved after setup by this diagnostic. Ordinary production motion,
material simulation, leases and observation ownership remain active.

The existing independent outcome observer samples Oil and Water with radius50,
near-field radius8 and requested spacing4 for both arms. The policy itself has
the same radius64 Oil request in both arms. Additional output records the
already-copied policy Oil sample, candidate utility/score, selected goal key and
target; it performs no extra live-world query and never feeds these copies back
to the actor.

## Primary outcomes and falsification

The primary window is completed simulation time `[0,10)` seconds, using the
existing 0.1-second decision samples. Report each matched seed separately:

- Selected investigation duration: 0.1 seconds for each sample whose selected
  module is `discovery`.
- Horizontal approach gain to the first common, actually observed Oil sample:
  initial absolute X-distance minus the minimum absolute X-distance in the
  primary window. This fixed observed reference avoids treating later absence
  beyond the observer's range as zero distance. It is an approach to the initial
  observed location, not a global assertion about every moving Oil cell.
- Actual horizontal displacement and X range, reported beside Euclidean centre
  path so vertical gait cannot masquerade as supported horizontal approach.

The directional hypothesis is not supported if high curiosity fails to produce
both more selected investigation and greater horizontal approach gain in at
least two of the three matched pairs. Report the two effects separately: a
choice difference without physical approach is a physical limitation, while
fresh material coverage without a choice difference challenges the intended
utility mechanism. Exact identity or coverage failures invalidate the affected
comparison rather than becoming favourable trait evidence.

The secondary window is the entire 30 seconds. Record selected approach and
inspection phases, actual inspect arrival, cooldown/habituation explanations,
return to routine, actuator stalls and material coverage. An inspection label
does not prove stillness or resource benefit. No parameter, module weight,
priority, geometry or endpoint will be retuned after observing outcomes.

## Custody and limits

The external diagnostic and runner are committed separately from the frozen
application. Their commit and SHA-256 hashes, the complete a725 project/source
inventory, pinned engine, native/Rapier identities, exact commands, original
console streams and original JSON reports are retained. The ordinary apparatus
validator checks all physical ticks, legal command receipts, actor identity and
observation cadence. A post-run comparison requires the exact one-field profile
change, equal initial materials/poses/geometry, and equal initial copied Oil
observations. Full custody is rechecked after the six processes.

These six episodes remain supplementary and are excluded from the primary194
registry and all baseline/candidate totals. They provide three matched seed
pairs for one authored competition, not population significance, all-personality
validation, universal trait effects or NVIDIA playfeel acceptance. All failures,
identical results and unsupported secondary outcomes remain in the record.
