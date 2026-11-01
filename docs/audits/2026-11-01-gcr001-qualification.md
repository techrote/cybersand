---
title: GCR-001 combined category contact qualification
status: Current
document-kind: evidence
scope: Source-bound experimental R2 implementation, failed physical qualification, platform controls and retained acceptance limits; no production or owner acceptance
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [../architecture/granular-contact-response.md, ../operations/granular-contact-response-plan.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# GCR-001 combined category contact qualification

## Decision and retained boundary

**NO-GO for the current GCR-001 R2 integration.** It implements a bounded
experimental normal/friction/contact-moment pipeline, but fails registered
horizontal resistance and Y1 impact-preservation gates. Passing analytic
mechanics, deterministic replay and quantity conservation does not override
those failures. The equations with admitted contacts have not been disproven;
the integrated adapter has a concrete side-admission defect and other response
and delivery differences requiring separate experiments.

B0 remains the ordinary default. Y1 remains an explicit comparison reference.
Controllers, thrust, braking, damping, hard collision properties, joints,
material laws and ejection/search bounds were not retuned. Sleep admission/wake
policy, rest caches and body-to-cell conversion remain out of scope. REM-004/#83
is not complete. The implementation PR stays draft and unmerged.
**AWAITING OWNER GAMEPLAY ACCEPTANCE** is an unfulfilled acceptance boundary,
not a recommendation to accept this failed candidate.

## Fresh main, concurrent ownership and recoverability

The isolated `codex/gcr001-category-contact-20261101` branch starts from actual
main `809fd30dfac0c5e127302997075be9c4b279e5aa`, tree
`863db60c767bf00a215b9e4064d6bccb71eb69ab`. A later fetch during qualification
still found that main. Its delta from the prior observed
`25ce0731d89b9540c2d95cfa8bae321c37e6e118` is merged PR#344 render copying;
that work is retained. The unrelated dirty `C:/khybersand` material checkout
and old investigation branches were preserved. No archived branch was merged,
rebased or wholesale cherry-picked.

The read-only archive review and owner constraints are recorded in the
[registered plan](../operations/granular-contact-response-plan.md). #12/#281/#283
retain aggregate discovery/lifecycle ownership; this branch adds no aggregate
owner. #29 retains non-kinetic material/reaction authority. The final active-PR
inspection also found draft#345 at `2461a6a9da130a39dcf2578059f3d47337db4c58`:
its render-retention work overlaps `simulation_worker.gd` and documentation
files, but not the contact law. A future composition requires deliberate
reconciliation and new source evidence; this branch does not import it.

The approved plan is recoverable at `2aff460c60f36c0f209b67fe682d0f8b9e5e0f83`.
The committed [protocol](gcr001-2026-11-01/protocol.json) freezes 66 pairs,
coefficient/capacity/age rules, named controls and decision criteria before
physical acquisition. Native R1 `c775febb` failed the10% reduction gate.
R2 registration `9d17e1e6` preceded physical results and native R2 `d9f35c21`.
Initial full physical acquisition used clean source
`201759cdec52ade2f90a9602a3af6209f6f45370`.

Portable-source acquisition used clean source
`73f9b3e9fa2e01e51016ef20fad289c15ba69661`, tree
`841a74694394250527961c7be4c481c008509d0d`. Subsequent review/test fixes expose
the actual GCR selector, include registered hard/Water/Empty review controls,
make no-argument async discovery executable and correct the zero-wrench hard/air
assertion. They do not change native mechanics or explicit capture parameters.
The complete physical matrix remains attributed to73f9b3e9, rather than being
relabeled as a later documentation/test head. Final gate receipts separately
identify their executed head and unchanged native/script inputs.

## Implemented mechanism and bounded approximation

The [canonical experimental contract](../architecture/granular-contact-response.md)
owns ABI17/14, main-thread application, actual inertia/COM and nonwrapping
session and wrap-aware sample-serial fences. The old11/9 path stays separate. GCR replaces overlapping
granular displacement/boundary/bearing feedback with geometric normal response,
Coulomb-limited tangent response and their contact moment. Non-granular feedback
retains its old path. Native blocked granular moves carry an integer source
moment, explicitly described as attempted-move feedback rather than physical
parcel momentum.

Eight source bins reduce to at most16 numerical contacts, four sample-weighted
Jacobi passes and8192 scalar updates per64-body boundary. R1 single-centroid
reduction had maximum normalized wrench error13.3955%, failing the unchanged10%
gate. R2 second-moment quadrature passes the same36-case unreduced-solver oracle
at maximum4.50628%. Finite budgets, mirror/lever-arm/energy tests and bounded
capacity remain separate from integrated physical efficacy.

The category is Sand, Stone, Dust, Seed, Salt, Sodium, Gunpowder, Coal and Rust.
All six registered Stone fixtures explicitly use granular state_b1. The shared
policy is unchanged, including its stable downward8/9 and side9/9 witnesses.
No yellow-Sand special treatment or new per-material law was introduced.

## Source-matched runtimes and retained portability failure

Both extensions were rebuilt from the81 canonical native compiled inputs at
73f9b3e9. The tracked provenance manifests bind those Git bytes, build inputs,
toolchains and artifacts:

| Platform | Artifact SHA-256 | Bytes |
| --- | --- | ---: |
| Windows x86_64 | `aa08dd4bafe5f44a762f85dccc809d5a2254b7587cf981bbbe43c83b50c49138` | 4875264 |
| Linux x86_64 | `341ca1cbbafc129f803a9092b8c621d999b13c95e8c871fbc262592a174345cb` | 4279064 |

Godot is official4.7 `5b4e0cb0f`; Windows engine SHA-256 is
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`.
Rapier addon0.35.2/crate0.35.1 and its retained cooperative BVH patch are unchanged;
Windows Rapier SHA-256 is
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
godot-cpp pin is `101ae38034304346a46ea9ea84ae156d3e860496`.
Windows used LLVM-MinGW20260826/Clang23.1.0 UCRT; Linux used WSL Ubuntu24.04
GCC13.3.0/binutils2.42 with explicit `LINUX_CXX=/usr/bin/g++-13`.
Each extension build had a1200-second process bound and exited0.

The first Linux build imported `hypot@GLIBC_2.35`, exceeding the combined2.34
floor. The repository wrapper only adds `-fno-math-errno` and did not resolve it.
73f9b3e9 replaced that norm with a scaled Euclidean calculation and added
overflow/subnormal/nonfinite regressions, without changing response parameters.
In288 oracle distances,78 differ by at most1ULP; therefore the original coupled
runs were retained and the whole physical campaign was reacquired. This is a
portability correction, not a claimed physical improvement. The rebuilt floor
check passes: extension GLIBC2.32/GLIBCXX3.4.30/CXXABI1.3.9 and Rapier GLIBC2.34.

## Registered physical results

Portable-source Windows campaigns completed166 captures:132 primary,12 real async,
six B0 controls, ten diagnostic ablations and six deterministic replays.
All completed and conserved measured per-ID quantities and exact Water mass.
The [compact primary summary](gcr001-2026-11-01/primary-final-summary.json)
reports every material/case and all mechanism comparisons; repeated work events
are not counted as independent physical trials.

All three required25% horizontal bank-improvement gates failed:

| Material | Y1 peak entry, cells | GCR peak entry, cells | Change |
| --- | ---: | ---: | ---: |
| Sand | 1.372 | 6.974 | 408% worse |
| Dust | 2.059 | 7.190 | 249% worse |
| Rust | 1.372 | 6.974 | 408% worse |

Eight of nine materials violate horizontal nonworsening, in both bank and glancing
cases. Stone bank entry changes1.815→1.834, within allowance. All36 category
scenarios eventually generate admitted contacts and positive new normal impulse;
that does not mean resistance acts early enough to prevent penetration.

Four of six Y1-preservation rows fail vertical entry:

| Case | Y1→GCR peak entry, cells | Y1→GCR post-ejection overlap, cells |
| --- | ---: | ---: |
| High anchor | 4.770→6.026 | 16→18 |
| Light high | 2.582→3.482 | 12→14 |
| Heavy high | 9.734→13.156 | 44→63 |
| 45° moderate | 2.052→2.692 | 2→1 |

The first three also fail post-overlap preservation. Gentle entry and half-size
high entry remain within their registered entry/overlap allowances. Fixed-mass
half/double geometry comparisons at moderate entry show smaller changes
(Sand/Rust half1.120→1.098; double0.413→0.385). The90° rows have zero reference
entry in both arms; they are retained but cannot establish a positive efficacy
improvement. Mass0.5/2, edge, slope, off-centre streams, mixed seams and excavation
are separately reported, without promoting isolated favorable cases. Late drift,
slip and angular motion remain observations; no sleep/rest claim follows.

All six synchronous replays match the corresponding physical projections
exactly, including actual application/refusal/age, corrected/translated wrench,
overlap, edits and final recorded material observations. Full cell contents and
state hashes were not captured for this comparison; no full-cell/state replay
claim follows. Timings and identity fields are excluded.
The [replay projection receipt](gcr001-2026-11-01/replay-comparison.json) retains
the definitions and hashes.

## Rotation, friction, support change and real delayed delivery

MU0 has exactly zero accepted tangent impulse in all five ablation scenarios.
Before conservative geometric clearance to any enclosing hard surface, MU0
sliding has zero event torque but passive torque up to13.0548 and angular
speed0.6025. Thus normal contacts can produce torque independently of friction.
CENTRAL transmits exactly zero packet angular impulse; the bridge still performs
the registered COM translation. Under the same clearance censor, full→CENTRAL
peak angular speeds are bank3.581→0.00144, glancing12.202→0.00311,
slide5.316→0.01591, edge6.203→0.00354 and stream1.321→0.00533.
This censor is geometric inference, not a Rapier contact receipt. Evolving
trajectories are not calibrated torque or monotone-friction evidence. See the
[ablation ledger](gcr001-2026-11-01/ablation-mechanisms.json).

Full Stone excavation retires new normal/tangent/moment/event/correction on the
next fresh support sample; partial excavation retains remaining support. Reset,
duplicate, stale, wrong-session and geometry refusal are tested separately.
The real worker uses immutable mailbox/ACK delivery with every-sixth-delivery
hold, not mutated internal sample age.

The final [async summary](gcr001-2026-11-01/async-final-summary.json) retains:

| Case | Y1 | GCR |
| --- | --- | --- |
| Moderate | Peak4.311; no floor | Peak4.218; no floor |
| High | Peak15.561; no floor | Peak94.661; floor tick94 |
| Lateral | Entry1.855; floor1170 | Entry6.947; floor747 |
| Glancing | Entry2.835; floor269 | Entry15.680; no floor by1800 |
| Stream | Peak0.032; no floor | Peak3.476; no floor |
| Excavation | Floor692 | Floor694 |

Accepted GCR responses have age0/1 and contact displacement within0.5cell.
Held/refused deliveries contribute no actual impulse. These fences do not
qualify dynamic adequacy. Async overlap is unsupported and stays null.
Initial201759cd schedules differ materially, including a failed moderate case;
the [initial async summary](gcr001-2026-11-01/async-initial-summary.json) is retained.
Neither differing schedule nor portable norm is described as a physical fix.

## Failure interpretation and next registered experiment

There is a source-supported admission conflict: ejection precedes exterior
sampling; a side9/9 stored-material stencil necessarily includes the emptied
adjacent body pixel. A clean interface cannot satisfy it. Exactly45° normals
also take that side path. Meanwhile the old granular boundary/displacement
reaction is suppressed. This is an integration defect rather than evidence
against friction/torque once contacts exist.

Separately, attempted-move events enter before passive response and spend its
shared budget. They can add downward feedback and reduce available braking.
No observed early/pre-floor supported boundary exhausts the20-unit event budget;
the initial async maximum is only2.169/2.123 for moderate/high. Moderate sync
has no early event contribution yet still regresses. Event budgeting cannot
explain every failure. Native computed-boundary sums and actual main-delivery
sums have different populations; their difference is not a causal decomposition.

A successor should preregister an admission-only bounded interior support witness,
retaining shared policy, stable real source/path, original geometric force point,
ejection, solver and coefficients. Event/delivery changes require separate
ablations. Do not relax the failed gates or immediately tune coefficients.

**Owner suggestion,2026-11-01:** friction along the embedded body sidewalls may
assist sinking resistance and damp vertical slip. This is compatible with
contact-point friction/torque, but needs a credible normal/confinement load.
The current velocity-only normal solver produces no normal impulse for pure
vertical sliding along an exactly vertical stationary face, so increasing mu
alone cannot guarantee that assist. A future experiment should separately test
contact admission, the source of side normal load and a bounded friction range,
including yielding, lateral control and rotation. This suggestion has not been
implemented or used to retune the registered R2 results.

## Host checks, performance and acceptance limits

The actual unchanged playground controllers run through
`CyberPlayerPlaygroundRuntime`/arena/session: rocket barrel and articulated rig,
Y1/GCR, hard/air and Sand/Dust/Rust,360 steps each. All16 captures conserve
quantity and pass after correcting the assertion that a valid zero-impulse
hard/air record must count as a nonzero application. The arena independently
requires preparation, response and atomic application admission. Ordinary course
Sand/Water samples are removed identically so hard/air is a genuine control.
These are bounded host checks, not the entire proposed topology or human-feel
matrix. No GCR owner preference has been supplied.

At73f9b3e9 the full native suites pass170/0 on Windows and170/0 on Linux;
focused Godot imports plus16 scripts/OS pass. Native ASan/UBSan and subsequent
correction/performance receipts are recorded in the checkpoint addendum below.
No passed claim is inferred from a draft CI skip.

Observed maximum is8 bins/15 nodes/120 scalar updates per body, within R2's
8/16/128 bound. Concurrent functional coupling timings are deliberately not
performance qualification. Scanned work in Stone horizontal changes p95 from0
to1029, triggering investigation; a finite amplification ratio is undefined
against zero. Sequential AB/BA results, when available, remain separate.

Exact GCR adapter state/temperature payload preservation, actual germination/
reactive support-loss, complete mirrored physical causality, full playground
topologies, graphical/device/export/Web qualification and owner gameplay
preference remain unqualified. Native conservative relocation tests are narrower
payload evidence. No hidden erase/restore, material teleport, duplicate granular
owner, worker Rapier access or new sleep mechanism was introduced.

## Reproduction and owner comparison

From this worktree, use the authenticated runner with pinned Godot4.7 and a
source-matched runtime. Each capture has a240-second parent process bound:

```powershell
python tools/experiments/run_gcr_qualification.py --output out/gcr-primary --jobs 3
python tools/experiments/run_gcr_qualification.py --mode async --output out/gcr-async --jobs 3
python tools/experiments/analyze_gcr_qualification.py out/gcr-primary/campaign.json --output out/gcr-primary-summary.json
python tools/experiments/export_gcr_evidence.py --campaign primary=out/gcr-primary/campaign.json --campaign async=out/gcr-async/campaign.json --output out/gcr-compact
```

The acquisition receipts specify all additional B0/ablation/replay case arguments.
Use fresh destinations; retain failures. The [raw manifest](gcr001-2026-11-01/raw-bundle-manifest.json)
binds original logs/reports; large raw archives stay local rather than in Git.
Selected traces and machine-readable summaries accompany the protocol, and the
source/runtime manifests retain the recoverable input identities.

For the synthetic diagnostic comparison:

```powershell
python tools/experiments/run_gcr_qualification.py --mode review
```

The scene offers B0/Y1/GCR, all registered material cases and hard/Water/Empty
controls, reset, excavation and pause. For the actual rocket-barrel/articulated
host use the [explicit playground launch](../architecture/granular-contact-response.md#how-do-i-compare-gcr-and-y1-with-actual-rocket-barrel-controls).
Start with Sand horizontal entry, high anchor, angled entry, edge and excavation;
then compare Dust/Rust. These surfaces expose a failed experimental candidate,
not an accepted production/default change. Space press/repeat/release and focused
controls are covered by the review input regression.

## Completed platform and performance checkpoint

The [native gate receipt](gcr001-2026-11-01/native-qualification.json),
[84-input manifest](gcr001-2026-11-01/native-input-manifest.json) and
[compiler identities](gcr001-2026-11-01/native-tool-identities.json) retain full
commands, bounds, source/input checks, binary hashes, log hashes and outcomes.
Windows170/0 took77.49s; Linux170/0 took233.06s; Linux ASan/UBSan170/0 took517.19s.
All exited0 without timeouts or sanitizer diagnostics. Build bounds were1800s;
full execution bounds3600s plus outer WSL guards. This is the core suite defined
by Makefile TEST_SOURCES, not standalone generation or soliding targets.

The [initial scoped host receipt](gcr001-2026-11-01/host-qualification.json)
contains both imports and16 scripts per platform, all exit0 with no ERROR output:
GCR protocol, negative controls, actual playground, Y1 controls/review, manual
Rapier stepping, REM-002, REM-003, instrumentation, physics async, cell World,
failed-tick quarantine, prepared owner, interaction async, native edge regression
and64-body capacity. The [corrected host receipt](gcr001-2026-11-01/corrected-host-qualification.json)
at `b7d283dc` repeats imports, the actual three-arm review/controls/pause test and
the no-case real-worker async test on Windows and Linux; all six processes pass.
The earlier review test lacked the registered hard selector and is not used as
proof of that corrected assertion. Original failed host assertions and relative
capture-path failures remain in the local raw archive, with their scope retained.

Sequential Windows timing used clean source
`dce2977b3be7c5d556425832ede740789df36682`, identical native/Rapier/engine/protocol
hashes, one functional process, telemetry off and120 warmup ticks removed.
Three fresh-process AB/BA repetitions per arm on five registered cases completed
30/30 and conserved measured quantities. No competing qualification jobs ran.
All30 selected physical projections match the telemetry-on primary references;
the [timing reducer](../../tools/experiments/analyze_gcr_timing.py) specifies that
projection. It does not compare complete cell state.

Pooled timing samples across the three processes give:

| Case | Coupling p50/p95/p99/max µs, Y1 | GCR | Main application p95 µs, Y1→GCR |
| --- | --- | --- | --- |
| Vertical | 24/39/46/317 | 28/42/51/303 | 13→37 |
| Horizontal | 27/40/49/195 | 90/129/156/261 | 12→47 |
| Glancing | 28/41/48/168 | 70/214/274/618 | 12→49 |
| Stream | 23/33/40/154 | 30/46/57/140 | 12→37 |
| Heavy high | 35/66/92/217 | 83/138/166/291 | 13→43 |

Horizontal/glancing/heavy coupling exceeds both registered p95 thresholds
(>25% and >25µs) in all three individual repetitions. Their pooled main
application also triggers. Across all measured components,25 component triggers
occur in13/15 paired repetitions; stream's pooled measured-component total
425→543µs also triggers. There is no Rapier p95 or scanned-work trigger in these
five timing cases. The result getter is included and accounts for4.0–9.1% of
GCR coupling time; preparation dominates the measured coupling cost. This
locates cost components, not a causal decomposition of changed trajectories.
No admitted performance budget or promotion follows.

The [timing detail](gcr001-2026-11-01/timing-detail.json) retains every p50/p95/p99/
max for coupling, Rapier, native tick, main application, preparation, packing,
getter and work, plus per-repeat thresholds and telemetry comparisons. The
[compact timing receipt](gcr001-2026-11-01/timing-final-summary.json) and
[raw manifest](gcr001-2026-11-01/timing-raw-bundle-manifest.json) preserve source
identity and original raw/log hashes. Support/event/passivity/slip ledgers were
not acquired with telemetry off and stay null; measured overlap remains available.
The measured-component total excludes diagnostic observations, overlap scans,
report construction and serialization, so it is not end-to-end wall time.
The [separate raw timing archive](gcr001-2026-11-01/timing-raw-archive.json) is local.

Independent review verified81 native inputs per platform against actual Git
bytes, artifact hashes/sizes, all166 primary/control receipts, the published
physical/async numbers, ordinary B0 preservation and the sidewall-friction
normal-load constraint. Its evidence corrections distinguish Windows physical
scope, material observations from full state, and wrap-aware serials from the
nonwrapping session. The replay projection executable is retained at
[compare_gcr_replay.py](../../tools/experiments/compare_gcr_replay.py).
Remaining acceptance limits listed above stay open; this checkpoint does not
convert NO-GO into completion of REM-004 or owner gameplay acceptance.
