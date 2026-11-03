---
title: GCR-LA passive creep and powered burrowing investigation
status: Current
document-kind: design
scope: Frozen and executed apparatus-only independent-body investigation; unchanged response laws, no structural-detachment edits or sleep
canonical-for: [gcr-creep-investigation]
last-reviewed: 2026-11-03
related-documents: [gcr-rest-registration.md, ../architecture/granular-contact-rest.md, ../systems/granular-review-flight-fleet.md]
---

# GCR-LA passive creep and powered burrowing investigation

**Current experimental apparatus:** the [dated qualification](../audits/2026-11-03-gcr-la-creep-and-burrowing.md)
records32 dynamic-bank/barrel and8 separately registered flat-bed captures on
actual Windows/Linux Godot/Rapier. This registration retains the prospective
decisions and apparatus failures. Results do not select a new response law,
close REM-004 or supply owner acceptance.

## Source, ownership and purpose

Owner authorizes this focused investigation while Astra independently progresses
#281/PR347. The isolated branch `codex/gcr-creep-investigation-20261103` starts
from the exact preferred-review control PR351 source
`8ce36b0e41c9292ab0b1f02cf7789450082a67b5`. Freshly fetched main is
`89020b9eb6d540383a5bb64b58dcd29a87592c32`, tree
`79de02472a653a4315149bc5e1970a512e6d74b6`. This is a deliberate same-source
apparatus successor, not a claim that unmerged GCR-LA is current main.

Only new capture/fixture, runner/reducer/test files and focused documentation
change. Existing World, native adapter, worker, Rapier bridge, actor, controller
and detachment/session source remain byte-identical to the control. PR347's
branch is read-only; no independently competing handoff or mixed-body owner is
created. All PRs remain unmerged. Sleep, catch, material laws, response tuning,
default promotion and body-to-cell representation are outside this experiment.

The existing Windows/Linux native modules were built at181a8257. Reuse requires
exact complete production input maps and actual runtime hashes, plus current
application input hashes before/after execution. Changed apparatus does not
relabel the earlier native build. The standalone synchronous fixture is useful
for attribution; it does not qualify asynchronous PLAY or compound delivery.

## Preregistered population

Commit this document and the [machine protocol](../audits/gcr-creep-2026-11-03/protocol.json)
before new physical acquisition. Sixteen cases per OS,32 primary captures total,
1800 ticks at60Hz each,300-second external watchdog. Preserve failed attempts;
any apparatus repair gets a separately identified successor, not a replacement
primary result. Smoke/parse and mechanical gates are distinct from acquisition.

| Fixture | Materials | Input arms |
|---|---|---|
| Barrel8x14, mass1, near-upright, gentle placement on160-deep bed | Sand2, Salt23 | No drive; pulse; sustained gentle impulse |
| Default Kestrel9x6, mass0.1, inertia0.975, horizontal body axis against a bank over a deep base | Sand2, Salt23 | Neutral controller/coast; zero actuator ceilings; pulse; sustained gentle drive |
| Identical Kestrel geometry | Hard Wall1, Water3 | Sustained drive, separate negative controls |

The barrel retains existing friction0.78, gravity92.12 and current correction/
zeroing/response. Its authored horizontal impulse is0.02 per tick during the
selected interval. Kestrel retains all default mass, inertia, force and torque
authoring. Input fraction0.15 and effort0.7 are registered gentle commands, not
changes to material law or actuator ceilings. Its gravity remains38.
Pulse runs ticks120..179; sustained drive runs120..1199; all then release.

The flyer room is closed at(128,128), size512x384. The base occupies
(129,320,510,191); the connected bank occupies(300,192,339,128). The initial
centre is(296,312), rotationpi/2. Wall contact is reported explicitly so late
hard-floor arrest cannot be called granular rest. This bounded geometry is an
experimental choice, not a permanent engine limit.

## What does passive mean?

Neutral input is not necessarily zero actuation: the actual flyer controller
continues velocity drag. The unactuated arm sets existing developer thrust and
torque ceilings to zero, retaining gravity/contact and existing backend damping.
It is a diagnostic control, not a proposed flyer default. Record commanded
actions and actual controller force/torque/impulse separately. Finite throttle
slew after release belongs in the actual actuation ledger.

No presentation/exhaust inference supplies force evidence. The owner's defaults
recording remains observational and its craft/source uncertainty is retained.

## Measurements and decisions

First independently re-reduce existing synchronous control captures, retaining
their original594a1a73 identity and input schedules. Their copied ledgers can
localize correction/zeroing/wrench sequences but do not qualify this successor.

New captures record exact schedule, native configuration, actual physical mass/
inertia, pose/velocity/omega, actual actuation, fresh response IDs/age, correction
translation, pre/post-zeroing/wrench velocities and energies where available,
overlap, granular limiter/refusal and displacement counters. Missing fields stay
null. Closed material counts and exact Water quantity are sampled at declared
census boundaries. Free painting, emissions and chemical source edits are absent.
Diagnostic census, copying and per-event observation work is not production
performance; measure its timing separately where available.

Compare before-drive[0,120), early-drive[120,180), late-drive[900,1200),
after-release[1200,1500) and tail[1500,1800). Report signed displacement,
span, velocity percentiles, summed correction, fresh application counts and
actual actuator work.0.5cell displacement and0.1cell/s velocity are reporting
thresholds, not a production acceptance claim. Numerical delivery closure uses
relative1e-5; conservation is exact. Hard-contact windows remain separate.

Classify motion as observed with no command, with zero actuators, during drive,
or persisting after actual actuator output stops. Report matched differences
without treating ticks/repeated events as independent efficacy populations.
Ledger association alone does not prove that correction causes creep. The old
R/PRC failure combined two operations; P/C never activated in its physical
population. No friction/load/catch change is selected from those facts.

The deliverable is a reduced reproduction, compact machine summary, selected
traces and hashed raw evidence, followed by the smallest justified next causal
experiment. Keep the barrel feel and actual structural mass as retained controls.
Gameplay acceptance and the remaining REM-004 envelope stay separate.

## Apparatus continuation registered before attempt04

The original protocol remains byte-identical. Attempt01 stopped in a retained
control because the isolated project needed an explicit legacy protocol path.
Attempt02 passed all nine Windows host controls, then refused the new protocol
before physics: JSON numeric arrays compared unequal to source integer arrays.
The repair accepts numerically exact integer coordinates and retains refusal of
fractional geometry; floating metadata has only an absolute1e-12 parse tolerance.

Attempt03 completed the six Windows barrel cases, then the first flyer refused
at step0 with no trajectory rows. Its setup called `bridge.reset_body` after
the arena's initial native prime, creating a new bridge session while native
retained the old session. The session mismatch guard is correct and unchanged.
All six barrel results and the failed flyer remain original partial evidence.

Before attempt04, register a setup-only repair: retire the preconfigured pose
through an acknowledged empty native preparation; author the initial transform
once using the existing main-thread Rapier API without resetting bridge history;
prime the registered geometry without resolving overlap. Require the same bridge
session, unchanged native tick/material/Water quantities and no invented swept
geometry. This is initialization, never a per-frame transform assignment.

The complete successor is the same32-case two-platform population. Combined with
the retained six completed attempt03 cases, this permits38 actual full-length
captures across the original partial attempt and complete successor. Nothing is
tuned from the six barrel outcomes, and no failed/partial attempt is relabelled
as a passing complete campaign. Authenticate unchanged retained control inputs
and original logs before reuse; always execute import and the changed apparatus
test. Record the original executed source for inherited controls explicitly.

## Flat-bed follow-up registered after attempt04

Attempt04 completed all32 captures with exact conserved quantities and unchanged
inputs. Its flyer bank is a dynamic loading case: the tall loose bank collapses
before commanded drive, and the free body rotates so later forward thrust is
mostly upward. Its zero-actuator descent does not establish creep on a quiet bed
or an isolated powered-side-entry comparison. Retain those results as measured.

The separate [flat-bed protocol](../audits/gcr-creep-2026-11-03/flat-protocol.json)
registers four Sand/Kestrel arms per OS, eight new full-length captures. Remove
only the tall bank, retain the same191-deep base and closed room, and use the
constructor's default angle0 at(296,312). Native/bridge priming already matches
that initial pose; no pose-reset or new owner is needed. Before the first measured
Rapier step, the existing arena's normal terrain revision consumer installs the
authored hard borders; the baseline census precedes that rebuild. All body
authoring, laws and numerical thresholds remain.

Compare coast, zero actuator ceilings, pulse and sustained drive. Drive uses the
existing Q/E side jet via `trim=+0.15` with `move=0`, the original120/180/1200
schedule and effort0.7. Rotation remains free; actual world force projection is
measured rather than assuming body-local side thrust stays horizontal. Sand/Salt
agree in the dynamic fixture; this bounded follow-up isolates its geometry and
input premise rather than creating another material Cartesian matrix.

The initial capture's field `controller.actual_impulse` is a rig-reported bounded
request: the existing per-part tiny-impulse guard can suppress it before backend
delivery. Keep original raw bytes and correct its interpretation in the reducer.
Both sample velocity and pre-correction velocity were independently recorded;
their same-phase difference measures delivered actuator/rig-guard impulse before
the native wrench and before Rapier integration. The new flat producer records
reported and measured impulses separately. Mark movement-guard activation and
missing phase evidence explicitly; do not infer whole-system energy or work.

No event-channel, correction, friction or sleep intervention is selected. If the
quiet support and commanded-motion premises are satisfied, report their motion
separately and nominate the next causal comparison from the actual ledgers.
