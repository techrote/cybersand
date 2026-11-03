---
title: Separate GCR-LA timing, withdrawal and blocked-event causal tests
status: Current
document-kind: record
scope: Dated Windows/Linux experimental evidence; no production response, sleep, material or default change
canonical-for: []
last-reviewed: 2026-11-03
related-documents: [../operations/gcr-causal-registration.md, 2026-11-03-gcr-la-creep-and-burrowing.md, ../architecture/granular-contact-rest.md]
---

# Separate GCR-LA timing, withdrawal and blocked-event causal tests

## Outcome and decision boundary

The registered experiments distinguish three operational effects. Moving
actuation before sampling does not meet the registered late-motion threshold.
Cancelling bridge withdrawal while preserving its original zeroing and wrench
is harmful and fails barrel guards. Removing the blocked-move event response
strongly reduces unactuated burial in the collapsing-bank population, while
retaining native blocked attempts and recomputing the existing passive solve.

This is causal evidence for the event channel's contribution in that population,
not approval to delete all granular loading or impact response. The event-free
high barrel has more late motion despite passing the registered impact guards.
The quiet flat bed has no observed events and still has subpixel vertical motion.
Neither the full powered-burrowing envelope nor a general rest law is solved.
No intervention is promoted to ordinary gameplay. Sleep and catch stay excluded;
all related PRs remain draft and unmerged.

## Source, runtime and registration

This isolated successor starts at PR366 control
`029c214e7e3530ebbee63927c725f832d18ff34a`, not at current-main production GCR.
Fetched main at task start was `89020b9eb6d540383a5bb64b58dcd29a87592c32`,
tree `79de02472a653a4315149bc5e1970a512e6d74b6`.
Astra's independently owned #281/PR347 was observed at3e974985; its branch and
shared production source are untouched. This population uses independent bodies;
that scope is not a prohibition on compound bodies sharing a World with actors.

Both physical protocols and their decisions were committed at0cd09be4 before
apparatus implementation or candidate execution. Subsequent pre-acquisition
clarifications distinguish first-tick contact counters, safety-guard censoring
and the existing1e-5 Float32 transform parity tolerance. The JSON protocols remain
unchanged through all primary captures. See the [registration](../operations/gcr-causal-registration.md).

Complete acquisition source is
`9a0434915821256d34347d9115961ba4f26d4136`,
tree `a25c37b0e976f678be27ea9432151f14e6b11f08`.
Its Godot/config input identity is
`4a1dc9d7f71e03c7cd763d865f74afb10362cb5e37b908a388f2151462cb8b73`.
The runner authenticates source/protocol/project/runtime inputs, copied projects,
original process/raw hashes and unchanged inputs at completion. Capture source
remains that revision when later evidence-reader or documentation changes land.

No production native input changes. All 88 inputs remain source-matched to
native 181a8257a93f82d64fbeb97e9c413ef52d44f13d. Godot is
4.7.stable.official.5b4e0cb0f, Rapier addon0.35.2/core0.35.1; fixtures use one
synchronous native worker and manual main-thread Rapier stepping at60Hz.

The retained LA control is explicitly selected as native candidate `GCR-REST`,
mode `control`, admission `A1`, base budget20 in the receipts; the name does not
imply a new rest or sleep law.

| Runtime | SHA256 |
|---|---|
| Windows actual Godot engine | b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8 |
| Linux Godot engine | f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75 |
| Windows native extension | 65c1d2a35134c44aea539a0e8441d66b3b4db92cba7c5477d038b842fe7c889e |
| Linux native extension | 8bfe51214643c626dd5800f66ecff86f3348a166b55551e0674d1b4f762cfbf5 |
| Windows Rapier | b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7 |
| Linux Rapier | 566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a |

The console launcher is a different Windows file; receipts separately retain
its hash. Linux executes in WSL Ubuntu24.04. No Web/mobile/macOS execution or
fresh native/sanitizer rebuild is claimed by this unchanged-native experiment.

## Timing and contact continuity

T moves the one actuator advance before the one sample. Original C samples
before actuation. Direct backend velocity differences witness actual actuation;
the old sampled-to-application gap is not used as a T actuator measurement.
Unactuated C/T matches exactly over 1800 observations on both platforms.

For held side thrust, late ticks900..1199 travel is 4.57666 cells in C and
4.89404 on Windows /4.89368 on Linux in T. The approximately+0.317cell change
is below the registered 1.14417cell threshold. Contact-node duty changes from
23.6667% to 15%, an8.6667 percentage-point decrease, below the10point threshold.
Thus this scheduling intervention does not qualify as the primary remedy for
late powered sliding in the tested fixture. This is not proof that timing is
irrelevant for every actor/control surface or asynchronous delivery mode.

S applies an identity backend transform assignment only when the original bridge
actually translated the body. S/C physical states match within registered
tolerance; the largest driven rotation roundtrip is approximately 4e-9 rad.
X instead restores the exact pre-response origin after original delivery.
Its velocity zeroing, impulse and angular impulse remain the originals, including
the bridge's corrected-COM torque. Proposed/observed correction, c×J and both
potential changes are separately recorded. It is not a recomputed physically
consistent no-correction wrench.

| X guard, both OSes | Control peak entry | X peak entry | Control/X peak effective overlap |
|---|---:|---:|---:|
| Gentle barrel | 0.02798 | 7.51959 | 0 /51 |
| High barrel | 6.69016 | 32.55262 | 22 /113 |

All values are cells or cell counts. X fails the registered penetration and
overlap allowances. Flat unactuated X also reaches approximately 15.235 cells of
reference entry and 39 overlapping cells; its tail vertical span is about11.819
cells against the control's0.278. Held X reaches 4.799 cells of reference entry and
14 overlapping cells. These comparisons have no hard-contact/rig-guard censoring.
**Reject blanket withdrawal cancellation.** This does not reject a future
separately qualified correction law; it rules out adopting this operational X.

## Blocked-move events

C and E0 both freshly reconstruct native World before authoring/ticking, using
the existing diagnostic contact option at0.025 or 0. Body, session, initial native
physical hash and material counts match. E0 removes event J/L, event budget
charge and post-event provisional velocity together, then recomputes passive
response. It is not a posthoc packet subtraction or an isolation of those three
subcomponents. Powder-only rooms require zero legacy non-granular response;
Water is a separate mechanical negative.

A fresh native witness produces 3blocked attempts with 0parcel moves, unchanged
material cells, no passive nodes and identical post-tick native hashes across
gains. Effective gain is 0.0249999994412065 or 0. The public counter increase is
measured across that first native tick, excluding unchanged adapter observations.
It is not assumed to identify arbitrary contacts from an old aggregate counter.

| Bank, Sand and Salt | C | E0 |
|---|---:|---:|
| Descent at tick 900 | 154.26651 cells | 1.072906 cells |
| First hard proximity | tick 1123 | absent through 1799 |
| First floor contact | tick 1127 | absent through 1799 |

Both arms are hard-clear through the registered tick 900 comparison. The
approximately 153.194cell reduction exceeds its38.5666cell threshold. All controller
impulses are exactly zero. Native blocked attempts continue in E0; their live
counts need not remain identical after body/material trajectories diverge.
Conservation stays exact. Identical Sand/Salt outcomes are evidence for these
two existing policies, not a qualification of the whole granular roster.

E0 bank tail overlap remains6 cells, with correction active in 150/300 tail
observations and p95 speed approximately 0.751 cell/s despite small pose spans.
Preventing deep burial in this fixture does not establish cleared or quiet rest.

Flat C/E0 is an exact1800-observation physical null with zero native blocked
events. High-barrel E0 passes the registered guards: peak entry6.69016→6.38551,
effective overlap22→20, upward speed2.92296→3.36067 within the2 cell/s allowance.
However, tail position spans increase from approximately 0.831×0.476 cells to
1.715×0.918 cells. Do not call E0 a qualified rest solution or owner-accepted
replacement. Genuine moving-grain load, glancing impact, angular response,
additional materials, powered entry and the asynchronous envelope remain open.

The justified next response-law investigation is how repeated blocked cellular
attempts become event impulses, preserving actual material loading/impact and
the existing passive response. Any shared-source change must reconcile with
Astra's current coupling ownership first. Increasing friction or the impulse
ceiling is not justified by these results. Do not suppress correction to make
this channel look better.

## Gates, failures and reproduction

The complete population is 40captures, each 1800 steps:24 timing/contact and 16 event.
All processes exit successfully within their 300 second watchdogs, with complete
sequential fresh age0 applications and exact closed material/Water quantities.
Common first hard proximity or rig safety intervention censors direct granular
attribution; later trajectories remain operational observations. Event-C bank
motion after first hard proximity is not solver-only evidence. No rig guard or
hard boundary censors the registered timing comparisons or event tick 900 test.

New actual-host mechanical suites run fresh on both OSes:16,276 timing checks and
1,078 event checks per OS. They cover copied-control parity, actual stage counters,
same-phase actuation, setter state/torque accounting, native gain calibration,
reconstructed control parity and Hard/Water negatives through the new driver.
Eight retained body/fleet/REM host controls are reused only with unchanged
source/config/native/engine/Rapier identities and original successful log hashes;
their original execution source remains explicit. No reused result is relabelled
as a fresh run. New diagnostic costs and concurrent raw readers do not establish
production FPS or a coefficient performance comparison.

The strict causal Python suite passes 47 tests, including adversarial metadata,
raw/log identity, actual stage/correction accounting, fresh gain calibration,
censoring, valid event initial hashes and complete barrel overlap coverage.
Independent review rehashes all 40 original captures/logs,649 application inputs
and 88 native inputs per platform and recomputes the material conclusions.
Maximum relative delivered-wrench errors are 5.9132e-7 linear and 2.4524e-7 angular,
within the registered 1e-5 bound. Repeated observations are not independent trials.

Retained pre-primary failures include the Float32 transform angle roundtrip
(7.45e-9 rad), missing event-unit barrel material setup and its cascade, and
attempt01's inherited-log relative-path resolution. The missing timing-protocol
negative intentionally refuses. No physical threshold was weakened. Attempt01
has an input/import receipt and a reconstructed note of its tool stdout, not an
invented raw stderr log; it contains no causal captures. Complete successor02
uses unchanged producer/protocol bytes after the runner lookup repair.

The [compact summary](gcr-causal-2026-11-03/qualification-summary.json) and
[selected phases](gcr-causal-2026-11-03/selected-phases.csv) accompany a
[trace manifest](gcr-causal-2026-11-03/selected-phases-manifest.json) and
[raw evidence manifest](gcr-causal-2026-11-03/raw-manifest.json).
Full-precision raw captures/logs, full reducers, input maps, original mechanical
failures and local validation reports remain outside Git. Selected CSV values
are rounded human illustrations; formal results use full precision.

Local raw bundle `build/gcr-causal-qualification-20261103-v1.zip` is 78,775,594 bytes,
SHA256 `907ef4073bdd14e42b3712b397840c0922a463b1e2619971f1ef22a5638a8ccf`.
The independent review inside it has SHA256
`570d8b8e03f5491fdd397434698d3ef01e1525deda39af0236d14d1ef9f1245f`.
No archives, copied projects or runtime binaries are committed. The archive is
a local recovery artifact; immutable Git source, protocols and public LFS inputs
provide the reproduction route if that local file is unavailable.

```text
python tools/experiments/run_gcr_causal.py --output build/causal-new
python tools/experiments/analyze_gcr_causal.py --folder build/causal-new/timing --protocol docs/audits/gcr-causal-2026-11-03/timing-contact-protocol.json --output build/causal-new/timing/reduction.json
python tools/experiments/analyze_gcr_causal.py --folder build/causal-new/event --protocol docs/audits/gcr-causal-2026-11-03/event-protocol.json --output build/causal-new/event/reduction.json
python -m unittest discover -s tools/experiments -p "test_gcr_causal*.py"
```

Use new output directories; the runner refuses overwrites and source drift.
Optional unchanged-control reuse requires the original evidence directory,
original hashed logs and exact runtime inputs. Windows watchdogs terminate only
their owned process tree; WSL additionally wraps the actual engine in GNU timeout.

Documentation mapping: registration owns protocols/decisions; this audit owns
dated results; handover/roadmap/index/retrieval route the outcome. Shared solver,
ownership/lifetime, interfaces, material chemistry, capacity laws, runtime pins,
ADRs and gameplay controls are unchanged. Native/sanitizer evidence remains
unchanged-input inheritance. Exact draft-head host and documentation/provenance
checks are recorded separately in the PR; draft CI skips do not establish them.
