---
title: GCR-LA passive motion, dynamic burial and powered sliding
status: Current
document-kind: audit
scope: Source-matched independent-body observation on Windows/Linux; unchanged response laws and no structural-detachment or sleep implementation
canonical-for: []
last-reviewed: 2026-11-03
related-documents: [../operations/gcr-creep-registration.md, ../architecture/granular-contact-rest.md, ../systems/granular-review-flight-fleet.md]
---

# GCR-LA creep and burrowing investigation

Compact evidence: [qualification summary](gcr-creep-2026-11-03/qualification-summary.json),
[200 phase windows](gcr-creep-2026-11-03/phase-summary.csv),
[four selected witnesses](gcr-creep-2026-11-03/selected-traces.json), and
[raw bundle identity](gcr-creep-2026-11-03/raw-bundle.json). The three committed
result artifacts total66,884bytes. The CRC-verified49,586,716-byte local raw ZIP
contains197 original evidence/helper files and is deliberately not committed.
Committed JSON uses canonical LF with matching internal artifact hashes; the CSV
hash likewise denotes canonical LF/Git-blob bytes. The raw bundle retains the
original generated CRLF summary/selected-trace bytes.

## Outcome and source boundaries

The registered investigation distinguishes three situations: a barrel's small
correction cycle, a lightweight flyer buried by a dynamic bank without pilot
input, and powered sliding on a quiet flat bed. It selects no new response law.
Sleep, coefficients, controller authoring and material policy are unchanged.
This work does not close REM-004 or assert owner gameplay acceptance.

The branch starts at preferred-review source
`8ce36b0e41c9292ab0b1f02cf7789450082a67b5`, not an implicit promotion of that
unmerged experiment to main. Fetched main is89020b9e/tree79de0247. The unrelated
dirty material checkout and Astra's #281/PR347 work remain untouched. All existing
production source, including World, adapter, worker, bridge, actor/controller
and detachment/session, remains identical to the starting control.

| Evidence | Actual source |
|---|---|
| Original registration | d42e5aab617aa2865a9154f17d74e6b31c70d32e |
| Partial attempt03: six completed Windows barrels, then flyer setup refusal | fb61215e; retained as partial |
| Complete dynamic-bank/barrel population:32 captures | 6f42ce6e21ae5b2ca12f3ef0283d931bae06a9c5 |
| Separate flat-bed preregistration | 24c8bcb0 |
| Complete flat-bed population:8 captures | 94fb91ba8045530280bc949ac6cb3bcc595b0df6 |
| Reused native build | 181a8257a93f82d64fbeb97e9c413ef52d44f13d |

The complete88-input native production maps and actual native/Rapier bytes match
before/after each successful campaign. Godot is4.7.stable.official.5b4e0cb0f,
Rapier addon0.35.2/core0.35.1. Windows native SHA256 is
65c1d2a35134c44aea539a0e8441d66b3b4db92cba7c5477d038b842fe7c889e;
Linux is8bfe51214643c626dd5800f66ecff86f3348a166b55551e0674d1b4f762cfbf5.
The actual Windows engine hash is distinguished from its console launcher.
Later evidence/docs are not relabelled native builds or physical execution.

## Registered populations and measurements

The [registration and immutable protocols](../operations/gcr-creep-registration.md)
precede their respective populations. Each capture has1800 sequential60Hz steps,
a300-second external watchdog, exact native configuration, source/project/runtime
identity and recorded input. There are40 completed successor captures on two
platforms, plus six retained partial-attempt barrels. Native workers remain1;
these synchronous controls do not qualify asynchronous PLAY or compound delivery.

The primary population uses Sand2/Salt23 barrels at gentle placement with no
drive, pulse and held drive; default Kestrel with coast, zero actuator ceilings,
pulse and held drive beside a bank; and separate hard/Water negatives. The flat
follow-up has four Sand/Kestrel arms with the existing Q/E side jet. Actual mass
and inertia remain authored defaults, including Kestrel0.1/0.975.

Neutral input still permits controller drag. Zero ceilings remove controller
actuation while retaining gravity and ordinary backend damping. Original raw
`controller.actual_impulse` is a rig-reported bounded request, not always backend
delivery: a retained tiny-impulse guard can suppress it. The corrected reducer
measures the fresh same-phase native-sample-to-pre-correction velocity gap.
The flat producer records requested and measured quantities separately, with
rig safety participation explicit. No sampled force-dot-velocity estimate is
called exact actuator work or whole-system energy.

Barrel post-overlap is sampled-pose post-ejection; flyer overlap is observed
after Rapier integration. They are not pooled as an identical phase metric.
Counts are native stored material/Water quantities, including masked cells.
Flyer censuses occur every60ticks plus the final step; unobserved ticks remain
null. Repeated application observations are not independent efficacy samples.

## What the cases establish

### Barrel response is unchanged and continues to cycle

The new gentle barrels never reach hard support and have zero measured
post-ejection overlap. Sand/Salt agree within each matched arm. Across the
registered300-step tails, the largest spans are about0.183cell horizontally and
0.164 vertically. Correction is active110/114/111 times for passive/pulse/held
arms. Post-wrench speed p95 is about3.06..3.11cell/s despite small position spans.
Those sampled velocities describe a phase of the cycle, not continuous visible
translation at that speed.

The historical reduction separately preserves source594a1a73, its original
drive schedule, eight raw hashes and selected stage traces. Summed upward
correction is not net withdrawal. Neither old nor new data independently proves
that correction causes the remaining motion. No barrel response code changes.

### Dynamic bank burial does not require pilot thrust

All eight granular flyer arms on each OS descend about196cells before the hard
floor arrests them. Zero ceilings deliver zero measured linear/angular actuator
impulse for all1800steps, yet first flag the floor at tick1127. Coast first flags
it1153, pulse1155 and held drive1197. Hard-clearance loss occurs a few steps
earlier; final stationary tails are hard-supported, not granular-rest passes.

This is a dynamic loading case. The tall bank initially collapses, with thousands
of material moves on early steps. The body rotates before commanded drive, so
its later body-axis thrust is no longer directed horizontally into the bank.
Thus this population does not isolate quiet-bed creep or powered side entry.
The initial authoring mask excludes six bank cells before baseline; measured
Sand/Salt population is140796, rather than the nominal rectangle sum140802.
There is no subsequent unexplained material loss.

Before the common hard-clearance boundary, cross-platform flyer positions agree
to serialization precision and velocity differences are at most3.815e-6cell/s.
Do not extend that to entire trajectories: after floor impact, coast/pulse
velocity differences reach roughly59cell/s and positions differ0.59..0.68cell.
The Water control also differs after hard contact. Those limits remain retained.

### Quiet support and powered sliding are distinct

The separate flat bed removes the collapsing bank and uses constructor angle0.
All four arms on each OS remain hard-clear with zero measured overlap. Coast
and zero ceilings retain x=296 exactly throughout1800steps. Their final vertical
tail spans are approximately0.288/0.278cell: subpixel vertical cycling remains,
but this fixture shows no passive horizontal burrowing.

The pulse travels about1.265cells horizontally; held gentle side thrust travels
about19.308cells. Late held-drive steps900..1199 travel about4.577cells. Motion
after release is much smaller; the held arm's final horizontal tail span is
about0.173cell. This is powered sliding across supported material, with zero
reference penetration and overlap in the admitted fixture, not deep burrowing.
The owner's original recording remains an unverified craft/input-history case.

The actual controller contribution appears between native sampling and wrench
application. During gentle side thrust the measured velocity gap reaches about
0.166cell/s and agrees with reported bounded impulse/mass at roughly1.5e-7.
This localizes a response-phase question; it does not establish that changing
sample order would provide desirable static friction or preserve feel.

All flat cases report zero material moves and unchanged Sand vertical sum. This
is a quiet-bed control. Contact is intermittent: held drive has nonzero native
contact nodes in71/300 late-drive observations, versus117/300 for coast and121/300
for zero ceilings. Correction is active59/300 in the held interval. Its mean
controller horizontal impulse is about+0.01612 versus GCR-0.01570 per tick, with
mean post-Rapier horizontal velocity about0.915cell/s. Contact continuity and
sample/actuation order deserve isolated comparisons before changing friction.

## Mechanism witness: event loading and passive resistance

The zero-actuator Sand flyer at tick600 is still hard-clear, has54 overlapped
stored cell centres and continues downward:

| Quantity, engine units | Value |
|---|---:|
| Controller linear/angular impulse | 0 /0 |
| Positional correction / zeroing energy removal | 0 /0 |
| Downward event impulse | +1.480000019 |
| Passive vertical impulse | -1.543259025 |
| Net delivered vertical impulse | -0.063259006 |
| Gravity impulse per tick | +0.063333334 |
| Vertical velocity before wrench | 11.011833 |
| After wrench | 10.379243 |
| After Rapier | 11.012578 |

The bridge's measured delta-v/delta-omega closes with one fresh age0 wrench.
Current correction and pilot input do not explain this step. The continuing
descent is consistent with event/passive near-cancellation plus gravity.

Source identifies the event as blocked cellular movement, not the old no-target
ejection reaction. `World::try_move` records a signed direction times density
when its destination is a body mask, before refusing the move. Powder can try
down and both down-diagonals. Density is clamped50..1600; both tested materials
reach1600. With gain0.025/1000,1.48 corresponds to37 net axial attempt units,
not37 unique moving grains. The retained native regression explicitly permits
positive events with unchanged material content. Completed parcel translation
or measured parcel momentum is not required by that path.

The adapter applies the accepted event to provisional velocity before the
passive solve. Its energy guard compares the passive result with that post-event
state. It does not certify event generation, gravity, correction or hard contact
as one passive system. At the witness, event scale is1, passive capacity18.52,
accepted normal magnitude1.545 and normal-cap hits0. The label
`active_capacity_limiter=global` selects available capacity; it does not prove
that capacity was exhausted. Raising20 is not justified by this witness.

This supports a separately controlled event/passive comparison for dynamic
burial, and an actuation/sample-phase comparison for powered sliding. Neither
intervention is implemented here. It does not select a replacement friction,
load, correction, event or sleep law.

Source routes: [blocked contact accumulation and failed move](../../native/src/world.cpp),
[event-first adapter](../../godot/native_extension/cyber_native_cell_world.cpp),
[passive response and energy guard](../../native/include/cybersand/granular_contact_response.hpp),
[arena sampling/actuation schedule](../../godot/scripts/physical_actor_arena.gd),
and [rig impulse request/tiny guard](../../godot/scripts/physical_actor_rig.gd).

## Gates, failures and handoff

Both complete campaigns pass authenticated capture completeness, exact closed
quantity checks and fresh application checks. All40 captures have1800 unique
accepted age0 applications. Hard and Water controls have zero granular normal,
tangent and event response, with complete measured coverage. Delivery closure
stays within the registered relative1e-5 bound.

Fresh imports and focused new host tests pass on Windows/Linux:77 primary
apparatus checks and24 flat apparatus checks per OS. Eight retained host controls
cover fleet controls, bridge/freshness/protocol, REM-002/003, ordinary rig
integration and six hard/Water/non-granular controls. Original execution sources,
runtime hashes and log hashes remain explicit when reusing unchanged inputs.
Python evidence/reuse readers pass47 adversarial checks. Native/sanitizer
execution remains inherited unchanged-input evidence; no fresh native rebuild
or full production-envelope acceptance is claimed.

The two complete populations contain72,000 sequential rows and unique fresh
applications,22,468 sampled conservation checks and948 raw censuses. All pass.
Maximum relative delivered-wrench closure errors are8.57821e-7 linear and
2.45236e-7 angular. Independent review rehashed all40 original case files and
recomputed the selected controller/backend phase measurements, with maximum
flat measurement serialization error8.85e-10.

Retained apparatus failures are: missing explicit legacy protocol path;
JSON-number versus integer-array metadata refusal; post-prime pose reset changing
bridge session; and a new flat measurement helper's non-overwriting Dictionary
merge leaving null fields. All were repaired in apparatus before complete
successor acquisition. The failed flat unit's owned headless processes were
identified and terminated; failure notes distinguish observations from raw logs.
No solver guard or physical threshold was weakened.

Timing includes large diagnostic censuses/copies and material evolution. These
are bounded functional runs, not uncontended FPS or production performance
acceptance. Full reducers, original logs, input maps and raw case hashes remain
in the local evidence bundle; compact qualification tables route below.

Reproduce using `tools/experiments/run_gcr_creep.py` with the relevant committed
protocol and source-matched native runtime, then `analyze_gcr_creep.py`. Use a new
output directory for every attempt. Keep this focused apparatus successor and
all earlier PRs unmerged. The next shared-source experiment must reconcile with
Astra's current coupling owner and retain these exact controls.

```text
python tools/experiments/run_gcr_creep.py --output build/creep-new
python tools/experiments/analyze_gcr_creep.py --folder build/creep-new --protocol docs/audits/gcr-creep-2026-11-03/protocol.json --output build/creep-new/reduction.json
python tools/experiments/run_gcr_creep.py --protocol docs/audits/gcr-creep-2026-11-03/flat-protocol.json --output build/creep-flat-new
python tools/experiments/analyze_gcr_creep.py --folder build/creep-flat-new --protocol docs/audits/gcr-creep-2026-11-03/flat-protocol.json --output build/creep-flat-new/reduction.json
python -m unittest discover -s tools/experiments -p "test_gcr_creep*.py"
```

Documentation mapping: this audit owns dated outcomes; the registration owns
population/decisions; the fleet contract owns requested-versus-delivered control
telemetry; handover/roadmap/index route the result. No ownership/interface ABI,
material descriptor, runtime pin, capacity law, persistence, rendering or ADR
changes follow. Documentation/M11/materialized repository checks pass. Frozen
retrieval is32/32top5,19top1; the affected PLAY supplement is11/11top1, including
the new creep question. These retrieval counts are routing evidence, not answer
or runtime acceptance. Final exact-head checks remain separately recorded.
