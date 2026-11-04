---
title: Authored compound flyers and Scooper qualification
status: Current
document-kind: validation
scope: Source-bound developer authoring, one-body compound hulls and bounded Scooper comparison; no response promotion or owner gameplay acceptance
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../systems/granular-review-flight-fleet.md, ../architecture/compound-granular-coupling.md, ../operations/gcr-authored-compound-registration.md]
---

# Authored compound flyers and Scooper — 4 November 2026

## Authority, registration and recoverable source

The owner authorizes authoring cleanup, genuine compound hull support and a
Scooper with Afterglow controls and stronger stabilization. Preserve the seven
existing flyers; qualify LA, events off and selective arrivals; keep sleep and
material-law tuning out of scope and all PRs unmerged.

The isolated `codex/gcr-authored-compound-scooper-20261104` branch starts from
draft PR381 source `b759e9ea05f274eb01eec7163b0cdc47c83b7c43`. Freshly fetched
main is `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`. The source worktree is
C:/Users/_/.codex/worktrees/gcr-scooper/khybersand; the dirty C:/khybersand
checkout and earlier running review projects are preserved. Independently owned
draft PR347 remains at `957ce67df859315ed238b6bbec1eebc9a743aaba`, with its own
physical NO-GO. This task does not import its latest branch or reinterpret a
detached payload lease as an actor.

The [registration](../operations/gcr-authored-compound-registration.md) was
committed at `49475875e6ee19097e86e51971bc317c739f6b6a` before implementation
or results. The machine [protocol](gcr-authored-2026-11-04/protocol.json) freezes
eight cases, three responses, two desktop OSs, synchronous one-worker native
execution, dt1/60 and at most900 observations per case. Registration metadata
and thresholds remain intact. Earlier owner preference for selective arrivals
does not cancel its previously registered NO-GO or accept this new craft.

## Implemented contracts

Eight named, bounded JSON definitions replace roster-specific scalar tables.
The [fleet guide](../systems/granular-review-flight-fleet.md#how-do-i-author-or-reload-a-flyer-including-scooper)
owns authoring, atomic Reload/reset, source hashes and controls. Saved spawn,
Shift boost, Ctrl brake, Burst B, painting and the dense toolbar remain available.
The seven old definitions retain exact physical/controller parameters and
identical controller outputs against the frozen parent controller fixture.

Scooper uses one actual Rapier body, mass0.18, uniform-area COM and inertia
approximately22.10, with six matching graphics/collider/native rectangles. Its
open cavity is not filled by a bounding-box collider. The stronger attitude
motor and Q/E±1.2rad trim are authored actor parameters; Afterglow retains its
original parameters. Carried material remains authoritative native cells.

The explicit `gcr_authored_compound=true` native construction mode preallocates
the existing compound workspace. The new value-only admission binds immutable
geometry and mass/inertia/friction to one session/generation. One aggregate
wrench and load-aware budget apply about the physical COM. It does not create
per-piece bodies, repeat body mass, add an impulse owner or bypass sample-age
and bridge guards. Invalid, mixed, retired and stale admissions refuse before
cell/mask mutation. The authored owner high-water fence survives diagnostic
reset. Independent bodies retain their path. Structural payload token,
quarantine, retirement and mass authority retain their separate path; explicitly
authored worlds reject structural commands rather than admitting a second owner.

The [compound contract](../architecture/compound-granular-coupling.md#authored-compound-review-bodies)
owns these interfaces. Core World, material laws, sleep, response defaults,
detachment implementation and ordinary player presets are unchanged. The native
adapter's existing `diagnostic_body_metrics()` is per-proxy independent
diagnostic evaluation; use aggregate compound results/diagnostics for physical
wrench accounting. No exact trajectory equivalence across arbitrary rectangle
decompositions is asserted.

## Runtime identity and receipt correction

Initial native source `a6bf8ec4e75cd1105ab40b927d909b888f42280f` compiled89
production inputs. Its [build record](gcr-authored-2026-11-04/native-builds.json)
and original preflights are preserved. The first physical matrix at6015cd37
stopped stream LA at tick259 on both OSs: `catch_applied=false` accompanied a
false catch impulse `[7.45058059692383e-09,0]`. Reassembling already Float32
components differed by one ULP from exporting the final compound sum. The strict
bridge correctly refused the receipt; this was not evidence of a budget failure.

Source `0206b5406a22ba668f02018516ff4723f3b3fc6d` corrects only no-catch
metadata: the exported actual wrench is the uncaught wrench and the catch delta
is exactly zero. True-catch accounting, physical result, forces and bridge guards
are unchanged. Both desktop SDKs were rebuilt, source-matched and published at
`8af64c5ea9e1ad99f95106cb3826f4f5d559fb38`. The
[corrected build record](gcr-authored-2026-11-04/native-builds-receipt-correction.json)
keeps complete commands, pinned dependencies, source/input/artifact hashes and
Linux symbol-floor results:

| Platform | Native SDK SHA256 |
| --- | --- |
| Windows x86_64 | `5ea17e8c97103c166a6c234497c9f7020247fc621f2a6ba4ebb493994cc24c77` |
| Linux x86_64 | `5b722e6b2c712bd9617e3c1c5c4e6392e5f2b1a6af65f738acab60c1749b28c8` |

Host is Godot4.7.stable.official.5b4e0cb0f with pinned Rapier addon0.35.2/core0.35.1.
Each actual run authenticates both extensions and all89 native inputs. Other
platforms retain their historical artifacts and are not qualified here.

## Mechanical controls and preserved original failures

The compact [verification summary](gcr-authored-2026-11-04/verification-summary.json)
binds original local receipt/log/patch bytes, source cohorts, native identity and
unchanged core inputs. Commands use300s host watchdogs,1200s SDK builds and the
retained pinned compiler/dependency roots. Actual original preflight totals are:

| Control | Executed outcome and source scope |
| --- | --- |
| Frozen seven-flyer authoring/controller parity |562 pure checks;574 full Windows checks with retained UI suite142, initial SDK |
| Native authored API |6277 checks per OS, initial SDK; full/rotated union, open cavity, identity/refusal, nine powder policies, quantities, seam/source/budget/passivity, Water/hard controls |
| Actual Scooper body |245 per OS, initial SDK; one RID, six colliders, mass/COM/inertia and actual response routing |
| Support removal |1962 per OS, initial SDK; gravity-only contact, actual deceleration, excavation and fresh support release |
| Broad compatibility |28 suites plus import on each OS,58 actual passing processes, initial SDK; actor/bridge, async/stale, REM002/003, ejection/conservation and structural controls |
| No-catch accounting |2060 instrumented Linux checks, corrected SDK source;45/48 combined event/passive compound samples and39 real regrouping witnesses |
| Strict 900-tick LA stream receipt |7215 per OS, corrected ordinary SDK;2400 source additions conserved, exact no-catch closure, deliberately forged one-ULP delta still refused |
| Native core |177 Debug and177 ASan/UBSan tests with leak detection; all136 recorded core/test/Makefile inputs still match current source |

Support-removal actuation ceilings are zero. Natural downward speed27.233318
falls to9.215538 at the first supported response, impulse3.3572008. Excavation
removes5120 Sand cells without changing hard floor; fresh bearing, support and
correction become zero and the body falls28.294693cells over60 observations,
first exceeding1cell at index5. This is a mechanical release control, not a broad
excavation gameplay claim.

Failed attempts remain preserved: inherited `GDScript.reload` naming collision;
illegal test `RefCounted.free()`; a lazy diagnostic read before requesting its
result; an obsolete invalid fleet index7 after adding the eighth entry; a support
fixture velocity setter that overwrote a queued wrench; and the strict-stream
test initially adding Sand without subtracting replaced Empty. The final test
census corrects that expectation. None is renamed a passing physical result.
Core attempt01 failed because WSL lacks make; attempt02 directly invokes the
matching retained g++13 source/flag set. Original compilation/logs remain.

## Sanitizer scope

The separate local instrumented adapter build at0206b540 passes import plus
6277 authored API,245 body,415 structural mechanical and2060 receipt checks,
with no candidate sanitizer diagnostics and all89 inputs unchanged. Instrumented
module SHA256 is
`d2aef97ebe6e19bd705f68f5ff584dc4c8bb25bc03d4183090437ffcd258787b`.
This is modified-loader instrumentation, not an ordinary pinned-host pass.

Original attempt01 lacks the required Godot-cpp ASAN define. Attempt02 compiles
but the ordinary pinned engine's RTLD_DEEPBIND conflicts with ASan. Attempt03's
local dlopen shim removes that flag; its original unsuppressed import reports
three external Fontconfig/libexpat allocations,320bytes. Attempt04 retains leak
detection and one exact-stack suppression, `FcConfigSubstituteWithPat`, matching
only those three external import allocations. The shim, suppression, original
stacks, process commands, instrumented identity and hashes are preserved in
`build/scooper-adapter-sanitizer-04`; shipping libraries and engine are unchanged.
The ordinary SDK is separately exercised by both OS host and physical runs.

## Physical matrix and limits

The corrected SDK population runs at8af64c5e in `build/scooper-captures-02`.
All48 case processes complete with their expected600/900 rows, accepted owner
steps and source/runtime identities. The original campaign-level completion is
**false**: the unrelated receipt-test census line changed in the source checkout
while the matrix ran. Both copied projects authenticate the frozen8af inputs
before and after all captures. No capture, controller, production/native or
protocol input changed in those projects. The verification summary records the
one changed test path; the original false completion is retained. These physical
captures are evidence at their actual source, not final-head execution.

The authenticated [machine summary](gcr-authored-2026-11-04/machine-summary.json),
[selected traces](gcr-authored-2026-11-04/selected-traces.json) and
[raw manifest](gcr-authored-2026-11-04/raw-manifest.json) retain all48 mechanical,
quantity, budget, passive-energy and bounded-work results. All pass their
mechanical checks; physical quality is separate. The analyzer preserves the
false custody result and LA demonstration failures rather than emitting an
overall qualification pass.

| Mechanism | LA | Events off | Selective arrivals |
| --- | --- | --- | --- |
| Landing Sand | Same measured path in this fixture | Same | Same |
| Dust burst,96 actual grains | Large downward loading | Little body displacement | Large downward loading; fewer event boundaries |
| Sand stream,2400 actual grains | Large downward loading | Little body displacement, unresolved overlap remains | Large downward loading, unresolved overlap remains |
| Sand burial | Final downward displacement95.93cells | Final upward displacement3.35cells | Final downward displacement34.72cells, with rebound |
| Carry16 grains | Fails8-cell lift and intended tip/spill | Lift threshold at165; half spill by330 | Lift threshold at165; half spill by330 |
| Salt edge | Same path, no measured angle change in this fixture | Same | Same |
| Water-only/hard-only | No granular event response; controls match | Same | Same |

The displayed translations are Windows results; Linux retains its own full
traces and outcomes. This table is not cross-platform bit identity. At tip
start300, E/S each have16 grains in the primary cavity; at least half leave by330.
Both satisfy the literal registered demonstration, while **primary cavity count
is zero at observation180 during ascent**, before returning to16. The auxiliary
sample-pose count and the body/native phase offset are retained. They do not
replace the primary metric or establish uninterrupted carry. LA retains16 but
its continued event response prevents the intended lift/tip; no force law or
motor value is tuned after this result.

Landing and Salt edge have zero passive-solver nodes in this population and
are weak bearing/torque discrimination cases. Their matching paths do not
establish a complete asymmetric contact response; the separately excited
native and gravity-only support controls carry the mechanical coverage.

Consequently this new hull is technically admitted for owner review, with
**bounded physical weaknesses**. Selective arrival loading can still displace
the very light Scooper substantially under stream/burial; the earlier seven-
flyer qualitative burial assessment is not extended to this hull. Existing
barrel/flyer controls and previous selective NO-GO remain separate. Loaded
stability, uninterrupted carry and useful asymmetric torque need owner review
or a separately registered follow-up, rather than default promotion here.

Closed nonreacting material censuses and Water quantity remain exact, including
accepted source additions. Water cell count changes as it redistributes and is
not used as a liquid quantity invariant. Water/hard C/E/S pose/velocity traces
match exactly within each OS; that does not qualify arbitrary reactive loads.
Peak post-ejection overlaps remain explicit in the summary, including83 in LA
burial and38 in selective stream. This is not a universal clearance result.

Maximum observed solver work is32 nodes/256 scalar updates, below the admitted
96/768 bounds. Timing records measure the whole normal owner step (native,
adapter and Rapier); they do not isolate coupling cost or establish a controlled
performance improvement between responses. Each case keeps p50/p95/p99/max
and active/scanned/move work. Parallel host processes and instrumented runs are
not a production frame-time benchmark. Across these cases, p95 owner-step
times range1.343..5.518ms on Windows and1.232..17.128ms on Linux/WSL;
worst observed samples are10.851ms and32.524ms respectively.

No mathematical zero-rest, universal carrying, powered-burrowing prevention,
cross-platform bit identity, Web or owner feel acceptance follows from the bounded
population. The sample/physics presentation phase is observable and must remain
visible in primary cavity counts rather than replaced with auxiliary counts.

Qualified admission is one authored compound per diagnostic World. Coexistence
with independent actors or structural payloads has not been exercised here;
this is an admitted test boundary, not a claim that coexistence is impossible.
Native admission freezes assigned mass/inertia; the authoring layer derives
them and developer overrides intentionally permit other assignments. Concave
corners retain existing deterministic single-source contact selection rather
than a complete manifold. Simultaneous rooms using different hot-reloaded
versions of the process-global registry are unqualified. Native room seeding
follows successful replacement; a later seeding/quarantine failure pauses the
new owner instead of restoring the already retired one.

## Final checkpoint and owner handoff

Final-head execution, documentation/provenance, retrieval and hosted statuses
are recorded against their actual SHA in the focused successor draft PR. Draft
state intentionally skips expensive hosted runtime jobs; local source-matched
execution does not turn those skips into passes. All27 immutable material-shadow
consumers are unchanged from this task's parent; inherited lock drift is retained
as a separate compatibility blocker without refreshing the lock/checker.

Reproduce in fresh output directories with
`python tools/experiments/run_gcr_authored.py --output build/<new-population> --captures-only`
and
`python tools/experiments/analyze_gcr_authored.py --output build/<new-population> --summary-dir build/<new-summary>`.
The analyzer authenticates original campaign/raw/log/protocol and copied source
against retained Git identities. Its seven failure controls cover identity,
incomplete prefixes, budget/passivity/work corruption, quantities and primary
versus auxiliary cavity counts. It returns nonzero for this population's
retained custody failure and LA demonstration failure. The original partial
[failed population](gcr-authored-2026-11-04/failed-population-summary.json)
retains12 completed captures, two failed stream prefixes and34 missing cases;
these never become a passing48-case population. Final mechanical gates use
`python tools/experiments/run_gcr_authored.py --output build/<new-head-gates> --gates-only`.

Run `launch-granular-events.cmd` from this worktree. Key8 selects Scooper; W/S
and A/D move, Space lifts, Q/E tilt, Shift boosts, Ctrl brakes. Use saved spawn
and Apply/reset to compare LA, events off and selective arrivals with identical
settings. Try level loading, a short vertical carry, controlled Q/E spill,
off-centre Burst and stream loading, pile-edge contact and excavation. Editing a
flyer JSON and Reload/reset is the supported quick iteration loop. Source,
runtime and definition identity remain in Details/receipts.

**AWAITING OWNER GAMEPLAY ACCEPTANCE.** No PR is merged, no response default is
promoted, no REM004 completion is claimed and sleep remains out of scope.
