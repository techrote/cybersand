---
title: GCR-LA causal timing, contact and blocked-event tests
status: Current
document-kind: design
scope: Separate preregistered causal interventions in experiment-owned files; no shared coupling, material, sleep or production-default change
canonical-for: [gcr-causal-tests]
last-reviewed: 2026-11-03
related-documents: [gcr-creep-registration.md, ../architecture/granular-contact-rest.md, ../decisions/ADR-007-rigid-body-cellular-coupling.md]
---

# GCR-LA causal timing, contact and blocked-event tests

## Current qualified outcome — November 3

The [dated causal evidence](../audits/2026-11-03-gcr-causal-tests.md) records
40 complete Windows/Linux captures at source 9a043491, with exact conservation
and 72,000 fresh applications. This remains experimental evidence on the unmerged
control successor, not a current-main response/default change.

- T, actuation before sampling, misses the registered late-motion threshold;
  unactuated T/C matches exactly.
- S/C qualifies the transform-setter sham. X, cancelling withdrawal after original
  delivery, fails gentle and high barrel penetration/overlap guards. Do not adopt X.
- E0, native event-gain zero with passive recomputation, reduces zero-actuator
  bank descent at tick 900 from 154.27 to 1.07 cells in both Sand and Salt on both
  OSes. Flat C/E0 is an exact no-event null. Native blocked attempts remain active.
- E0 passes high-barrel impact guards but increases late barrel motion; its bank
  tail retains 6 overlap cells and correction on half the observations. It does
  not qualify a general event-free response, cleared rest or powered burrowing.

Next investigate the blocked-attempt-to-impulse mechanism under the existing
coupling owner, preserving genuine material load/impact, the passive response
and barrel guards. No friction/load/sleep tuning, production promotion or merge
is authorized by these results. The prospective registration below is retained.

## Authority, source and write boundary

Owner authorizes separate causal tests following [PR366's observation](../audits/2026-11-03-gcr-la-creep-and-burrowing.md).
Fresh isolated branch `codex/gcr-causal-tests-20261103` starts from exact control
`029c214e7e3530ebbee63927c725f832d18ff34a`. Fetched main remains
`89020b9eb6d540383a5bb64b58dcd29a87592c32`, tree 79de0247. This is an explicitly
unmerged control successor, not current-main production promotion.

Astra independently owns #281/PR347, observed at3e974985. No existing production
World, native adapter, worker, Rapier bridge, actor/controller or session path is
edited. The implementation uses new apparatus files and existing public APIs.
Native cells and main-thread Rapier retain their respective authority. There is
one packed boundary and one response per body per step. Native build181a8257 and
all 88 production inputs must remain exact. No new native runtime is necessary
unless that premise changes. Preserve all other branches and dirty worktrees.

The two immutable machine registrations below are committed before intervention
implementation or candidate execution. All PRs remain draft/unmerged. Sleep,
catch, material-law tuning, arbitrary friction/load coefficient changes,
body-to-cell caching and production/default selection are excluded.

## Timing and contact continuity lane

[Timing/contact protocol](../audits/gcr-causal-2026-11-03/timing-contact-protocol.json)
registers12 cases per OS,24 captures total. Use the retained quiet flat bed and
default Kestrel with zero ceilings or held gentle existing side thrust, released
at1200. Four arms are independent; no T+X combination:

| Arm | Operational intervention |
|---|---|
| C | Retained sample/prepare, actuation, native tick, response, terrain, Rapier order |
| T | Move the single actuation stage before the single sample/prepare stage; all later stages unchanged |
| S | C plus an identity transform assignment after response whenever correction actually translated the body |
| X | C plus cancellation of only that observed translation after response, before Rapier; same setter condition/count as S |

Compare T with C, X with S, and S with C. First mechanically qualify the copied
C pipeline against the actual retained arena, normalizing only session/token
identities. Actual actuator and sampled velocities must witness T, with unchanged
pose and unchanged force ceilings. Truly unactuated T/C is a null comparison.

X retains the original bridge's velocity zeroing, validation and delivered J/L.
It is **post-delivery withdrawal cancellation**, not a physically recomputed
no-correction wrench. The bridge transports torque using corrected COM; record
the retained torque and `correction.cross(J)` counterfactual explicitly. Restore
the actual pre-response origin to avoid cancellation-rounding drift, preserving
post-response velocity/omega and rotation. Record both potential-energy changes.
The extra backend setter may affect contact caches/wake; S controls its presence.
If S differs from C, retain that outcome and qualify translation-only attribution.
No pose hold, support memory, velocity snap or cell restoration is added.
The backend transform roundtrip can change reconstructed angle by Float32
precision. Use the already registered 1e-5 parity tolerance for that rotation
readback, recording its actual delta; do not snap rotation back or relax exact
origin restoration and velocity/omega preservation. S controls this operation.

Flat arms cover zero actuators and sustained drive. Gentle and canonical speed90
barrels add C/X guards: these test regression of the full X operation, including
setter semantics, rather than independently decomposing a barrel torque law.
Barrel mass, inertia, near-upright angle and response remain the original values.

Measure contact/node duty and support signatures, horizontal slip, tail span,
rotation, overlap, penetration, correction/zeroing/J/L and actual actuator stages.
The registered material-effect reporting thresholds are max(0.25cell,25%) change
in late-drive travel or 10 percentage points contact duty. These are not production
acceptance. Missing correction activity is an unexercised premise.

## Blocked-move event lane

[Event protocol](../audits/gcr-causal-2026-11-03/event-protocol.json) registers
eight cases per OS,16 captures total: zero-actuator Sand/Salt banks, quiet flat
Sand and original mass1/speed90 Sand barrel, each with gain0.025 or 0.

The existing native `diagnostic_reset` contact option changes the event before
budget accounting and passive evaluation. Reconstruct native World symmetrically
before room authoring and either clock's first step in both arms. Re-prime the
upright body before bank authoring, preserving the original six masked exclusions,
then use the retained initial-pose retirement/re-prime helper. Confirm native
tick 0, bridge session, initial cells/body, terrain revision and collision refresh.

Gain0 leaves native blocked attempts and material work enabled while removing
their body-event J/L and budget charge. The unchanged passive solve recomputes
from the corresponding provisional state. This is channel removal, not post-hoc
subtraction. It changes event wrench, its budget use and provisional velocity
together; do not attribute their effects independently.

The gain also scales non-granular legacy contacts. Restrict causal rooms to Empty,
Wall and the selected support-capable powder, and require `legacy_non_granular`
zero throughout. Water is a separate mechanical negative, not an event-only
physical comparison. Initial native states must match; evolving material states
can differ as genuine feedback from changed body motion, with quantity exact.

There is no direct gain getter. A separate native one-grain witness supplies
behavioral readback: positive blocked contact count N, zero parcel movement,
unchanged material bytes, no passive nodes or legacy, event scale1, and
`event_raw.y*1000/(N*1600)` equals the selected gain. Compare full native hashes
after the same one tick across the two gains; do not compare a World's tick 0
hash with its advanced state. No Rapier stepping occurs in this calibration.
N is the public contact-counter increase across the fresh witness's first tick,
excluding the unchanged adapter contact observations. That first-tick subtraction
is not a general live-contact-count formula for an already advancing World.

Compare descent at tick 900 only while both arms are hard-clear. Otherwise mark
that metric unsupported and retain a common pre-hard interval plus censored
first-hard-contact latency. Report a material channel effect only above
max(2 cells,25%) hard-clear descent difference. Flat/no-event gain arms are a null
control. Do not label a chosen capacity limiter as a saturated impulse budget.

## Mechanical, safety and evidence gates

All 40 full-length captures use1800 steps at60Hz and 300-second process watchdogs.
Register geometry, parameters, inputs and observation windows in the two JSONs;
do not tune them from outcomes. Native/engine/Rapier/project/protocol identities
are authenticated before/after execution. Preserve every failure and partial
attempt; apparatus repairs need explicit continuation records before successors.

Before primary acquisition require actual C parity, T one-stage order/process
proofs, S/X setter/velocity/torque tests, effective gain calibration, fresh
response/duplicate guards, hard/Water mechanical negatives and strict adversarial
reader tests. Retain source-identical existing body/fleet/REM controls. Record
actual one-step/sample/application counts rather than inferring from API presence.
Clock/sample counts derive from before/after native tick, Rapier manual step,
bridge sample serial and session tick. Instrument actual actuator-stage calls
and independently measure its velocity change. An assigned literal count is
not an observed clock witness. Hard/Water negatives execute through the new
driver as well as retaining the historical owner controls.

Conservation is exact. All phase states must be finite. Granular outcomes after
hard contact are separate. Barrel guards use matched-control allowances:
max(0.5cell,10%) entry, max(1cell,10%) overlap and max(2 cell/s,25%) upward rebound.
Failing these prevents selecting an intervention despite improved late motion.
Copied-stage and delivered-wrench closure use relative1e-5. No mathematical
zero-rest requirement or new sleep policy is introduced.
Record any existing rig safety/movement guard activation. Restrict direct
granular-mechanism comparisons to the common interval before either hard contact
or a rig guard; retain later trajectories as operational outcomes, not uncaught
solver evidence. No existing safety guard is disabled for these experiments.

Keep compact summaries, selected traces, protocol and raw hashes in Git; large
raw/log/runtime evidence stays local with a manifest. New diagnostic costs do
not establish production FPS. Update canonical routes and dated outcomes, run
appropriate host/tests plus docs/M11/repository/retrieval checks, and open a
focused draft successor. Preserve owner acceptance and full production gates.

## Acquisition continuation1 — before primary results

Attempt `build/causal-primary-01` at source 850b4d51 passed its Windows import,
then stopped before any causal capture. The retained controls used paths relative
to their original source root; the new runner looked for one in the new worktree.
The resulting missing-log error is a harness failure, not a failed physical arm.
Retain that directory and its import/input receipts. Resolve relative inherited
logs against their original `build` parent, still requiring the original hash;
add a regression for this location rule. The frozen physical protocols, all
producer bytes, thresholds and populations remain unchanged. Commit this
continuation before complete successor `build/causal-primary-02`.
