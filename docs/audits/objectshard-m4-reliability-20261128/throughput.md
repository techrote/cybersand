# ObjectShard M4 semantic throughput — 28 November 2026

This is historical mission evidence, not an independent acceptance or publication
contract. The candidate remains Draft/HOLD for physical owner evaluation.

## Outcome and exact comparison scope

Final measured application source is `19485bbb5e474f0d4d90c40617a36b3120552f5b`,
tree `1b421ec0aa61ff4a8f034bd31424ebd9e9507599`, reconciled against accepted main
`9920e7a7369f24e2818313c007cc33616c1a6a83`. All forty historical comparison runs
passed (4,560 assertions), followed by twelve identical-native controls (1,924
assertions). All ran sequentially between 02:10:01 and 02:22:23 UTC; the other
specialists and root reserved that window without local Godot/build workloads.
External shared-host activity is not controlled.

The identical-native control is the strongest evidence that the script-side
pacing improvement persists without a compiler or binary change:

| Recording off workload | Old scripts, same COM native | Candidate, same COM native | Ratio |
|---|---:|---:|---:|
| Enabled, zero bodies | 37.49 ticks/s | 59.94 ticks/s | 1.60× |
| One awake tower | 21.22 ticks/s | 56.37 ticks/s | 2.66× |
| Eight awake bodies | 15.80 ticks/s | 29.74 ticks/s | 1.88× |

These are medians of two observed rates, not confidence intervals. The one-body
45–60 objective is reached locally. The eight-active objective of at least 30
remains narrowly unmet; no acceptance waiver or rounded-up pass is implied.
Enabled-zero and the single naturally sleeping plank approach the ordinary
reference's callback cap, although their native/physical work still has an
incremental CPU cost. No fully sleeping eight-body cohort was measured.

All results use the same Godot 4.7 executable, Rapier and 60 callback cap on a
shared AMD EPYC 9V74 host with nine visible logical processors. They measure real
native semantic ticks and Main-owned Rapier work in **headless** execution. They
do not measure monitor FPS or establish performance on the owner's Ryzen
5600X/TITAN RTX. The release runtime and graphical/source/extracted campaigns
are qualified independently by the integration/release workstream.

The practical consequence of the identical-native local rates is explicit: with
a fixed 1/60-second physical interval, 56.37 ticks/s is about 94% of real-time,
while 29.74 ticks/s is about 50%. Eight-active collapse therefore remains visibly
slower despite the approximately 1.88× improvement. The one-plank sleeping result
does not remove the full-roster and serial transaction costs of larger populations.

## Source and runtime provenance

Historical application is `1ec3f214662f7d5a0a38ff727b684c15b41c067b`. Its executable
scripts/native inputs match the owner-evaluated `efe3bc19c68a9b9e292821ef28b735caec538915`;
intervening changes concern publication and qualification tooling.

| Input | SHA-256 / source |
|---|---|
| Godot 4.7 stable, `5b4e0cb0f` | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Rapier 0.35.2 Linux | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Historical published native | `5fdf1e8f60f7fd93090ce4d924544c5f7aa9393e565af6b85a4e15e73d63ba20`, source `efe3bc19` |
| Combined COM/native proof runtime | `547c8f6f3474bc6f6406176239cefe3ae42d63326423f219d68a26d6a75032a0`, exact native inputs committed at `062670c1e` and identical in the measured application |
| Common throughput fixture | `1a50da49057b8f1b82621e727df2e2acac7177fc34672ecb6968d1337be4aeb5` |

The historical native used pinned GCC 13.3/binutils 2.42. The local candidate
used GCC 14.2/binutils 2.44 through the established explicit toolchain-drift
option; this binary is test evidence, not the guarded release publication.
Consequently the historical table compares complete candidates and carries that
compiler/runtime change. The separate identical-native control holds the COM measurement
native bytes, Godot and Rapier fixed for both old and new scripts.

That control is a test-only hybrid, not a qualified historical evaluator. Old
scripts still obtain a full material snapshot after every accepted motion and
ignore additive pose-proof, COM-domain and render-carrier fields. All three
ordinary workloads passed actual geometry, clocks, ownership and quantity
checks. This establishes compatibility for those workloads; it does not claim
that the old bridge implements the new sparse-fragment COM contract. The control
covers script-side changes together, rather than attributing every gain to one
individual code line.

## Final historical matrix and cohort support

| Observed workload | Baseline, recording off | Candidate, off | Baseline, recording on | Candidate, on |
|---|---:|---:|---:|---:|
| Structures disabled, 0/0 | 59.52 | 59.39 | 59.30 | 59.83 |
| Enabled, zero bodies, 0/0 | 39.01 | 59.80 | 43.57 | 59.94 |
| One awake tower, 1/1 | 19.70 | 53.97 | 19.80 | 51.23 |
| Eight awake bodies, 8/8 | 13.47 | 29.62 | 14.13 | 29.92 |
| Naturally sleeping plank, 1/0 | 21.37 | 59.67 | 31.37 | 59.86 |

Units are native semantic ticks/s; cohort notation is owned/awake. Disabled,
zero, one-tower and sleeping cohorts occupy each complete approximately six-second
window. The sleeping fixture additionally queries actual Rapier sleep and proves
a preceding gravity/contact fall. Baseline scheduling varies appreciably between
short repeated runs; all individual rates remain in the machine-readable files.
The small off/on differences do not establish a precise recording overhead.

Eight-body windows contain later natural sleeping. The active-body claims use
only the observed 8/8 cohort, with the following support:

| Comparison | Baseline 8/8 ticks / seconds, two runs | Candidate 8/8 ticks / seconds, two runs |
|---|---|---|
| Historical, off | 77 / 6.013914; 85 / 6.014223 | 90 / 3.014273; 91 / 3.096858 |
| Historical, on | 89 / 5.881813; 79 / 6.015187 | 91 / 3.033325; 91 / 3.049306 |
| Identical native, off | 88 / 6.013524; 89 / 5.248373 | 91 / 3.055597; 88 / 2.962441 |

These are actual acknowledged callback-end snapshots, not continuous sensors.
The remaining portions retain eight owned bodies with fewer awake bodies; their
global rate is not substituted for an eight-active rate. Common authored scenes,
real ordinary support cuts and the existing eight-body capacity are used; this
is not a reconstruction of the owner's original pointer trace.

`profile_object_shard_m4_throughput.gd` disconnects the fixture's deep per-callback
coherence observer only during the uniformly light timed window. Exact Pause,
physical/publication coherence and native quantity assertions run afterward.
`tools/objectshard/compare_throughput.py` executes one process at a time in AB/BA
order, requires identical harness hashes and retains source/runtime hashes,
actual clocks, cohorts, control counters, checks and per-run receipt hashes.

## Measured critical path and bounded implementation

The baseline already had an 8 ms Main idle receipt pump and a worker wake path.
It was incorrect to attribute all lost progression to a simple worker sleep or
to absence of any pump. Physics callbacks could decide readiness before consuming
an already completed receipt, missing another complete callback. Each segment
also entered an ordinary worker turn and constructed a complete material frame.

An instrumented 48-operation pump exhausted that iteration cap 154 times in
1,085 calls, in addition to 230 wall-budget exits. With 128 operations it had no
iteration-cap exits in 775 calls and 351 wall-budget exits. The **8 ms wall budget
is unchanged**; increasing the operation ceiling removes premature polling exits.
Only `OwnerBusy` permits have a bounded 2 ms rendezvous; every retry revalidates
the exact frame, and no actor work, forces or physical time occur before a grant.

Final recording-off measurements retain all native work and show the presentation
construction reduction. Costs below cover whole windows; eight-owned windows
include their later sleeping cohorts.

| Workload | Historical snapshots / tick | Candidate snapshots / tick | Historical snapshot + marshalling ms/tick | Candidate ms/tick | Candidate Rapier ms/tick |
|---|---:|---:|---:|---:|---:|
| Zero bodies | 6.00 | 3.00 | 1.154 | 0.610 | — |
| One tower | 6.01 | 3.00 | 3.619 | 1.979 | 0.465 |
| Eight owned bodies | 6.02 | 3.01 | 7.738 | 3.825 | 1.059 |
| Sleeping plank | 6.00 | 3.00 | 1.403 | 0.860 | 0.337 |

For the eight-owned windows, an actual motion command averages 0.155 ms in the
admission queue, 3.127 ms in the native owner call, 0.422 ms in publication/copy
and 1.201 ms before Main consumption. Four serial motion acknowledgements per
base interval, full completion/publication work and callback admission remain
material constraints. The native owner call dominates Rapier computation.

Those four spans partition one exact command. They overlap pump, worker and
snapshot counters and must **not** be added to those totals as independent frame
costs. Ordinary diagnostic `receipt_delivery` is publication-to-Main snapshot
age, not an M4 command service measurement. This distinction prevents the owner's
approximately 15 ms snapshot-age observation from being mislabelled as native
computation or a fully isolated receipt bottleneck.

Main now consumes admitted receipts at the beginning of its physics callback,
then admits at most one new fixed interval. While a physical lease is active,
the exclusive worker may service ordered `accept_motion` requests without
rebuilding unrelated ordinary presentation. Completion, refusal, replacement,
reset or shutdown returns to the ordinary owner path. Captured actor/equipment
work and the native tick remain exactly-once operations on final completion.

Only a successful, explicitly non-final motion can omit its full material
snapshot. Native copies the actual bounded `OwnerReadback` poses after application,
not the caller's coordinates. Proof requires a complete active roster, no
truncation/quarantine and no geometry or promotion pause. Every original ACK and
exact identity/pose/velocity/sleeping comparison remains. Final, refused,
incomplete and legacy receipts retain complete diagnostic/material frames; the
semantic completion also publishes a full frame. Existing publication barriers
prevent newer terrain from appearing with an older structural overlay.

Across the final off pairs, the tower retains **2,592 ACKs and 2,592 actual-native
pose echo checks**; the eight-owned cases retain **11,448 of each**. Successful
intermediate presentation omissions are separately counted (1,944 tower; 1,074
eight-owned), rather than presented as skipped physics/native operations.

## Correctness, COM integration and independent review

Runtime COM follow-up `a3b596e0a` consumes A's material/geometry-bound native domain.
Full synchronization calls the read-only `refresh_motion_domain` before Ready;
angular admission uses active-span `rotation_radius` and corner admission uses
`motion_radius` about physical COM. Stable cell/storage indices and native pose
coordinates remain unchanged. Intermediate motion captures contact witnesses but
transfers no owned carriers, so this domain remains fixed throughout a lease.
Semantic ingress precedes chemistry and geometry rebuilding; changed carriers
are refreshed before another lease. A independently reviewed the final pacing,
proof, completion and fixture changes and found no physical correctness blocker.

| Focused actual-native case | Checks | Result |
|---|---:|---|
| Receipt scheduling, interrupted lease, refusal, Restore, shutdown | 151 | PASS |
| Delayed completed actor sample | 104 | PASS |
| Equipment completion and one-shot effects | 95 | PASS |
| Actor clock/Pause/Step | 96 | PASS |
| Stale-owner lifecycle | 119 | PASS |
| Ordinary Workbench cutting/combustion/quantity completion | 185 | PASS |
| Fragmented cut and explicit reabsorption | 134 | PASS |
| Lifecycle fuzz | 1,007 | PASS |
| Optional diagnostic recording | 36 | PASS |
| Independent reference barrel | 114 | PASS |

The 151-check case includes real delayed intermediate receipts; stale/foreign
serial, World and session proofs; altered/missing native poses; exactly one
paused Step; ordinary Pause plus queued Sand brush during an admitted interval;
a real invalid-geometry native refusal returning a full frame; Restore while the
refused lease is idle; and joining the worker during an active lease. It repeats
with A's final same-material-revision/domain-conflict guard. The other nine cases
used the COM bridge before that final guard, with identical native bytes; the
final integrated source/extracted campaign remains independently required.

Fixture-premise repairs are explicit. A delayed-publication test must disable
both idle and physics receipt pumps. Setup now waits for durable attachment/body
reservation and then the existing exact Pause/coherence barrier, instead of
trying to observe a transient Ready during Play. Equipment tests use the actual
queued immutable request and pending queue while the leased worker intentionally
retains one ordinary publication. All cut-source, ownership, equipment cutoff,
projectile age/effect and cancellation assertions remain. No timeout was inflated.

One newly written interrupted-Pause assertion initially expected actor time to
advance when the admitted material interval drained. The established actor-clock
contract suspends controller time immediately on Pause. The new assertion was
corrected to require one admitted native/physical interval and no interrupted
actor tick; the separate paused Step still requires exactly one actor tick.
Production semantics and existing actor-clock assertions were unchanged. Original
failed experiment logs are retained separately with the corrected witnesses.

## M5 handover and retained evidence

Keep exclusive native ownership, Main-only physics, immutable full publication,
exact geometry/pose ACKs and one-shot actor/equipment completion. Compact pose
proofs are an extension seam for separating material presentation from physical
segments; they do not remove occupancy/contact work or make independent body
advancement safe. Stable cell identity is now distinct from physical COM, so a
future sparse representation can change storage without changing cell witnesses.

Next measure native occupancy traversal and its nested relocation scans, especially
unchanged or sleeping footprints. Early tower instrumentation found approximately
1.026 s occupancy over 180 ticks, including a nested 0.744 s relocation scan with
zero relocated cells; those nested figures cannot be summed. Investigate reuse
only against moving-cut, contact, fluid/granular and full accounting regressions.
At hundreds of fragments, full active rosters, nested pose matching, retained
empty storage and single-flight receipts need explicit budgets and a declared
batch time/ACK boundary. Hybrid debris and presentation interpolation should
follow those experiments. No M5 representation or body-count increase was added.

Repository evidence is `throughput-final-matrix.json`,
`throughput-identical-native.json`, `throughput-final-analysis.json`,
`receipt-scheduling.json` and `throughput-focused.json`. The first exploratory
forty-run matrix remains in `throughput-initial-matrix.json`; it predates the COM
fix and some sleeping/recorded pairs overlapped necessary camera/physics work.
It is superseded for final comparison claims, not erased. Detailed raw receipts
and logs are retained under the mission's `throughput-evidence` workspace, with
hashes in the compact committed summaries. Root owns final source reconciliation,
guarded runtime publication, Windows package identity and physical-owner HOLD.

## Subsequent no-op brush correction and bounded confirmation

The fifty-two paired measurements above use the **COM measurement native**
`547c8f6f...`, before the narrowly scoped `emit_disc` correction. They are not
measurements of the later guarded delivery binary. A subsequent actual supported
Tower experiment showed that an Erase covering protected contact cells and
unchanged Empty neighbours could return Accepted without changing World bytes,
yet the facade advanced revision 55→56. Native render serial 20 remained unchanged;
Main stayed at revision 55/publication 656 while the owner frame reached
revision 56/publication 657. All clocks/leases were settled, but exact Pause could
not satisfy its presentation fence. This was outside leased fast-path servicing.

A's `c3d6580e48b19fe5e2184397eba19531afbfbcfa` binds the attached brush revision to
the coordinator's actual `world_material_revision` delta, matching the existing
direct edit API. The independent B review checked that real state/temperature
writes still dirty both native render and mutation witnesses, protected/refused
cells remain fenced, and ordinary non-M4, hard-surface, ACK, clock and lease
behavior is unchanged. No coherence assertion was relaxed.

A bounded confirmation uses local integrated source
`44db8378f9cb6b7be587fbd7b4905baae75baf8b`, tree
`6d6b5e698b484ac669fef994f101a437950f0e5b`, and rebuilt test-native SHA-256
`656077181d398d33a74ecfe7c2a5bcdfb6addb20b7b2ba478e7ea019745f4d18` (5,963,312 bytes,
same explicit local compiler scope). One recording-off six-second run each
passed: zero bodies 41 checks/59.84 ticks/s; tower 107/55.81; eight-owned 333/29.58
globally, with the actual 8/8 cohort 89 ticks in 3.017341 s (29.50 ticks/s). These
single runs confirm the final correction did not disrupt the workloads; they do
not replace the interleaved comparisons or establish a new performance claim.
`throughput-post-noop-confirmation.json` preserves exact hashes, clocks, cohorts
and acknowledgements. Final delivered native provenance remains the guarded
publication recorded by the integration/release workstream.

B independently replayed A's committed `05777c2336a050398b85bf50746cd8a7a234d313`
brush-revision fixture on that complete application/native pair: **154 PASS**.
The protected/unchanged brush kept revision 54→54 and all native, displayed and
uploaded identities matched. All 471 observed callbacks were coherent. The
positive condition-only Wood control changed state 173/91→0/0 while preserving
temperature 371 and revision 3→4; identical repaint remained at 4 and advanced no
native time. Actual distant Wood creation and erasure also retained their
publication/quantity assertions. The compact independent receipt is included in
`throughput-post-noop-confirmation.json`; no forced render refresh was used.

## Hosted Linux source54 qualification and practical limits

Workflow 46099370014, Linux job 140838073361, completed successfully for exact
source `54a7719e55be313820ebeb8d36efe6c230c1348c`: **65 headless-matrix cases and all
52 cases in the graphical-profile lane passed**. The latter lane contains 28
actual X11-rendered cases and 24 repeated headless helpers, as recorded by their
individual commands. The supporting artifact is 15246670363, outer SHA-256
`be0a31fb682173c5099e2f4cb50a458f20e1e773589e605915f72cc6df1004f9`.
Its sealed pinned-toolchain native SHA-256 is
`059c5880234a4d5349e6e78527187b13e3b205b039b5f3baf3e033cdaff53fe4` (6,081,432 bytes).
The separate production bundle 15245544924 contains exactly those binary bytes,
and its same-World/Main-Rapier/compact-motion validation passed. These identities
were checked against both qualification receipts, not inferred from a job label.

| Hosted source54 workload | Headless semantic ticks/s | Xvfb/software semantic ticks/s |
|---|---:|---:|
| Structures disabled | 59.88 | 5.02 |
| Enabled, zero bodies | 60.05 | 20.04 |
| One awake tower, recording off | 34.00 | 11.97 |
| One awake tower, recording on | 36.15 | 11.78 |
| Eight awake bodies | 28.10 | 7.57 |
| One naturally sleeping plank, 1/0 | 60.12 | 18.19 |

The hosted headless one-body objective is not reached: approximately 34 ticks/s
corresponds to about 57% nominal real-time, and eight-active 28.10 to about 47%.
These lower hosted results accompany the faster local paired figures; they are
not omitted or substituted for them. The headless eight-awake cohort lasted
3.168 seconds before some bodies slept. The software-rendered eight-awake cohort
occupied its complete approximately 6.205-second window.

The graphical lane explicitly uses Xvfb, `LIBGL_ALWAYS_SOFTWARE=1`,
`LP_NUM_THREADS=2` and `GALLIVM_PERF=nopt`. It records only about 4 renderer
post-draw callbacks/s, including the weak disabled reference. Its visual and
publication assertions pass, but this is not a responsive physical-GPU
performance pass or a monitor-FPS measurement. No matched historical graphical
baseline was collected on this hosted environment, so these differences are not
attributed to a single implementation, compiler, scheduling or rendering cause.

The complete campaign 54 remains **failed**, because its separate native sanitizer
job encountered two obsolete singleton angular-refusal assertions. Linux lane
success does not erase that gate. Application/native/shader production paths are
identical between 54a, 69cea and b7d889b; their test/CI/documentation changes and actual
run identities remain distinct. `linux-source54-qualification.json` preserves the
cohort durations, focused transaction results, provenance reconciliation and
explicit scope. Later exact-source campaign qualification is tracked separately.

## Second hosted Linux observation, unchanged production

Source `69cea6f7f3484e7b13bd3c01a717ef0c1c64580f`, run 46101473408/Linux job
140844659296, also passed **65 headless-matrix cases and all 52 cases in the
graphical-profile lane**, again 28 rendered and 24 repeated headless helpers. Evidence artifact
15245949136 has SHA-256
`9f09e307e07d0b1265c5234bce4c20930562ce699a13f46e09e22afc4eed8df0`.
The separately verified producer artifact 15246995227 contains the same
`059c5880…` native binary as source54. Every one of its 126 native and 1,378 build
input hashes was independently compared with the exact source Git blobs, and its
three native owner helper receipts and log hashes passed reconciliation.

| Hosted source69 workload | Headless semantic ticks/s | Xvfb/software semantic ticks/s |
|---|---:|---:|
| Structures disabled | 59.78 | 6.83 |
| Enabled, zero bodies | 60.00 | 28.65 |
| One awake tower, recording off | 58.85 | 18.77 |
| One awake tower, recording on | 57.96 | 19.53 |
| Eight awake bodies | 30.05 | 12.43 |
| One naturally sleeping plank, 1/0 | 59.94 | 32.89 |

The headless 8/8 cohort lasted 2.995 seconds; the graphical 8/8 cohort lasted its
full 6.033-second window. One/tower and sleeping cohorts span their complete
approximately six-second windows. Every profile retains exact acknowledgement
and pose-echo equality. Graphical renderer callbacks remained approximately
4.6–5.3/s for enabled workloads, with 6.99/s for the disabled reference.

These substantially different short hosted observations use identical
production code and native bytes. They therefore do not establish a further
implementation gain or identify a single cause for host variability. The
single headless eight-awake observation just above 30 does not replace the
interleaved comparisons or turn the provisional physical-performance objective
into a robust pass. Physical owner evaluation remains necessary.

The overall source69 campaign remains **failed**: native sanitizers, ordinary
World and benchmark execution passed, but the subsequent Python discovery gate
found one missing ordinary Workbench opt-in registration for the new brush
fixture. That one-line test-registration repair is included in source b7; no
production behavior changed. `linux-source69-qualification.json` preserves this
disposition and exact observations. `linux-source54-to-b7-inputs.json` separately
records that all 126 native and five native build-contract inputs from source54
also match b7. Neither record relabels earlier execution as a final-source pass.

## Final b7 Linux qualification and producer custody

Final application source `b7d889b925ab3244d10e6fe48f487fbe0dc1ce73`, tree
`c7205a87bc9fda757dbcad511dcaacc618a6e73c`, completed Linux job 140850716133 in run
46103413203, attempt 1. All **65 headless-matrix cases** and **52 graphical-profile
lane cases** passed. Individual command records establish 28 actual X11-rendered
cases and 24 repeated headless helpers in the latter lane. Every case completed
naturally with exit 0 and no launch/diagnostic error or skip. This is final-source
Linux evidence; complete Windows, extracted-package and guarded-publication
outcomes are recorded by the release workstream.

Qualification artifact **15246929773** is 25,272,662 bytes, outer SHA-256
`47a5511628070bebd8fc63209adc1eaacd5a06106342853e58e2828f6ab2767b`.
Producer artifact **15246929759** is 2,384,016 bytes, outer SHA-256
`a7825226751144cd9565c91af7822fc4d01bc76dc787783dd39a4c745c754086`.
Both archives were downloaded independently and their actual digests checked.
The producer's 6,081,432-byte ELF has SHA-256
`059c5880234a4d5349e6e78527187b13e3b205b039b5f3baf3e033cdaff53fe4`, exactly matching
the sealed runtime used by both final qualification lanes. All 126 native and
1,378 build-input hashes match the exact b7 Git blobs. Godot/Rapier identities,
source/tree/run/attempt, native-helper completion and log hashes also reconcile.
The three focused producer helpers passed 28, 18 and 9 checks respectively.

The Linux runtime manifest SHA-256 is
`14857902133f346b04f26832b91ab28798a904b8026fef8a0d76b0b99a5fa9e1`; its target
validation receipt is
`c104cac294af0f138906689bfc91f70f2b13f770f13fcb3796a4ea36a367e80e`.
`linux-final-b7-qualification.json` records all identities and case modes, with
the producer's independent input/log reconciliation embedded. These final bytes
are retained separately for the integration owner's publication comparison.

| Final b7 workload | Headless target-cohort ticks/s | Xvfb/software target-cohort ticks/s |
|---|---:|---:|
| Structures disabled, 0/0 | 59.84 | 6.72 |
| Enabled, zero bodies, 0/0 | 60.02 | 36.65 |
| One awake tower, recording off, 1/1 | 59.81 | 19.54 |
| One awake tower, recording on, 1/1 | 60.08 | 19.55 |
| Eight awake bodies, 8/8 | 29.83 | 12.81 |
| One naturally sleeping plank, 1/0 | 59.98 | 38.84 |

The final headless eight-awake cohort is exactly **88 ticks in 2.950026 seconds**
(29.83025 ticks/s), followed by natural sleeping within the approximately
six-second whole observation. It corroborates the matched 29.74 result without
replacing that comparison. It is about 50% nominal real-time and remains below
the provisional 30 target. The one-awake cohorts last 5.918933 seconds off and
5.892557 seconds on; those rates use only those cohorts, excluding their short
sleeping tails. Small rates above 60 reflect finite callback-boundary windows,
not a claim of sustained simulation faster than its fixed interval.

In the software-rendered lane the awake cohorts span the full windows: tower
119 ticks in 6.089681 seconds, and eight bodies 78 ticks in 6.090532 seconds.
Their renderer post-draw callback rates are 4.93/s and 4.60/s. All twelve profiles
retain exact native acknowledgement/pose-echo equality. These functional and
presentation passes still do not establish a responsive physical-GPU or owner
hardware performance pass. No further performance experiment or architectural
change was made during final qualification.

## Supporting source54 Windows observations

The earlier source54 Windows artifact 15247169371 was independently checked at
SHA-256 `efcb49f751bb8641cafbdd86338f1e5deadc92e8c9d14974bdc9a393d1e544b5`.
Its actual native DLL is
`3d2e35a124f4307993f84751c94a7bba87ea7c1a0ee12c55480bc63357775ecb`, distinct from
the final b7 producer. The 65 headless-matrix cases, 52 graphical-profile cases
(28 actually rendered), and 32 extracted-package cases (five actually rendered)
passed. Source54's separate native test gate failure still prevents treating the
whole historical campaign as passed. Final b7 Windows evidence is independent.

| Supporting source54 Windows workload | Headless ticks/s | Actual ANGLE ticks/s |
|---|---:|---:|
| Structures disabled | 60.00 | 19.46 |
| Enabled, zero bodies | 49.65 | 21.84 |
| One awake tower, recording off | 29.82 | 16.66 |
| One awake tower, recording on | 29.82 | 15.47 |
| Eight awake bodies | 29.59 | 13.13 |
| One naturally sleeping plank, 1/0 | 43.16 | 22.76 |

The headless eight-awake cohort is 89 ticks in 3.008132 seconds; its graphical
counterpart is 79 ticks in 6.017646 seconds. The one-body cohorts occupy the full
approximately six-second windows. All twelve profiles preserve exact native
acknowledgement/pose-echo equality. Their actual graphical logs identify
ANGLE/OpenGL ES 3 over Direct3D 11 using **Microsoft Basic Render Driver**; tower
and eight-body renderer callback rates are 7.50/s and 6.81/s.

These Windows observations do not meet the one-body 45–60 objective, and the
headless one-body result is about 50% nominal real-time. They accompany the
faster Linux/local observations without being hidden or relabelled as a
physical pass. They are not a matched Windows before/after comparison, so a
single platform or scheduling cause is not established. A targeted owner-machine
comparison should use the retained control-queue, native execution, publication
and arrival probes to locate any remaining Windows pacing cost before another
implementation change. `windows-source54-throughput-review.json` preserves the
actual source/runtime, command modes, cohorts and renderer identification.

### Residual Windows coordination cost from existing receipts

The source54 Windows one-tower headless recording identifies a substantial
remaining serial transaction cost. It completes 179 native ticks in 6.001865 s
while process callbacks continue at 60.31/s: 2.022 process callbacks per native
tick. The same window completes 716 motion controls and 179 final controls,
exactly four motion acknowledgements plus one completion per observed tick.

| Exact-control stage, ms per observed native tick | Tower, recording off | Tower, recording on |
|---|---:|---:|
| Admission to worker handler entry | 5.755 | 5.593 |
| Owner command handler/native service | 5.314 | 5.436 |
| Full publication where required and receipt copying | 1.550 | 1.569 |
| Receipt ready to Main observation | 9.750 | 10.002 |
| Serial control round-trip sum | **22.369** | **22.599** |
| Queue plus Main delivery, already included above | **15.505** | **15.595** |

These are observed counter-total differences divided by the native ticks from
the same six-second window, not medians or estimates inferred from FPS. Each
control's four stages partition its monotonic wall-clock round trip, and Main
permits one pending serial control at a time. A finite window can end with one
partial physical interval; the recording-off/on tower samples here both have
the exact 716/179 completed-control counts and 179 observed native ticks.

The serial round trips alone exceed the 16.667 ms nominal interval. Queue plus
Main delivery account for approximately 69% of that measured control time.
Actual Rapier stepping is only 0.421 ms per observed tick off and 0.446 ms on;
pose-packet capture is 0.226/0.242 ms. The Main 8 ms pump reaches its wall budget
376/723 polls off and 382/723 on, with **zero operation-cap exhaustions**.
Its total elapsed time is 21.767/22.092 ms per tick, including waits and contained
Main work. It is not CPU time and must not be added to the control-round-trip
sum. Snapshot construction remains three calls per tick and 1.786/1.792 ms per
tick; those measurements can overlap publication and ordinary owner work.

This establishes a residual coordination/receipt critical path in this hosted
Windows result, even with inexpensive Rapier work. It does not establish whether
the wait arises from OS sleep precision, thread wakeup, mutex contention or
which Main callback observes a ready result. The owner-command service span
also does not encompass every ordinary semantic World operation, so the balance
of wall time is not assigned by these summaries. Existing-contract pacing
should be investigated before a representation redesign; this report does not
propose increasing the 8 ms budget or relaxing an acknowledgement barrier.

For clarity, the opt-in tower probe's ordinary `receipt_delivery` has a 5.574 ms
median and 8.112 ms p95 over its bounded recent observations. That field is
**ordinary snapshot publication age**, distinct from the exact-control delivery
stage above. Its worker metrics describe only the latest observed snapshot,
not an interval average. Neither is added to the serial control sums. Differences
of lifetime maximum counters likewise are not interval maxima and are unused.
`windows-source54-control-timing.json` preserves the twelve existing profiles'
counter sums, normalization, callback/cohort support and precise clock scopes.
Final b7 Windows timing evidence is evaluated separately when available.

## Final b7 Windows receipts and remaining objective misses

Final Windows evidence artifact **15249057392**, run 46103413203/attempt 1,
contains exact source `b7d889b925ab3244d10e6fe48f487fbe0dc1ce73`. Its 56,377,302-byte
evidence ZIP was independently hashed at
`dc82660c6b598b118d4020297d494386028727e64aa507b31825debe6918447a`.
All 65 headless source cases, all 52 graphical-profile cases (28 rendered and
24 headless), and all 32 extracted-package cases (five rendered and 27 headless)
passed with natural completion, exit 0 and no diagnostic/launch error or skip.
The exact DLL in all three lane receipts is
`a4b75f118a565fd965109b0b172e5050ae2f46346ef2a4863e8a1a9f363cc503`.
The evaluator archive and its four shipped-CMD launch witnesses have separate
package identities recorded by the release workstream; this evidence ZIP is not
the evaluator download.

| Final b7 Windows workload | Headless target-cohort ticks/s | Actual ANGLE target-cohort ticks/s |
|---|---:|---:|
| Structures disabled | 60.00 | 17.24 |
| Enabled, zero bodies | 47.04 | 22.51 |
| One awake tower, recording off | 29.66 | 15.53 |
| One awake tower, recording on | 30.47 | 15.62 |
| Eight awake bodies | 29.12 | 13.08 |
| One naturally sleeping plank, 1/0 | 42.29 | 23.52 |

The headless eight-awake cohort is **89 ticks in 3.056352 s**, followed by natural
sleep within its full observation; the graphical cohort spans its full window,
**80 ticks in 6.116968 s**. Both one-tower cohorts remain 1/1 throughout their
approximately six-second windows. All twelve profiles have exact acknowledgement
and pose-echo equality. Every graphical profile log identifies ANGLE/OpenGL ES 3
over Direct3D 11 on **Microsoft Basic Render Driver**. Tower/off and eight-body
renderer callbacks are 7.43/s and 7.03/s, not physical monitor FPS.

The final headless one-body 45–60 objective is therefore **not reached on this
hosted Windows environment**, and the eight-active target remains unmet. Roughly
30 semantic ticks/s means about half nominal real-time; these costs remain
practically significant despite the demonstrated local matched improvement.
Each Windows entry is one short profile, so the modest off/on variation does
not establish a precise recording overhead. These results neither replace the
paired Linux comparison nor establish performance on the owner's declared GPU.

Exact b7 control clocks corroborate the source54 residual finding. Tower/off
completes 712 motion controls plus 178 final controls for 178 native ticks.
Per tick, queue wait is **5.763 ms**, owner command service **5.268 ms**,
publication/copy **1.476 ms**, and Main delivery **9.866 ms**: **22.373 ms** in
serial round trips, of which **15.629 ms** is queue plus Main delivery. The
recording-on window observes 22.031 ms total and 15.273 ms queue plus delivery
per native tick, with one completed physical interval still awaiting its native
tick at the finite-window boundary. Actual Rapier stepping is only **0.397 ms
per tick** in both profiles. Process callbacks remain 60.32/s off and 60.10/s on.
The off pump reaches its existing 8 ms budget 375 times in 724 polls and has zero
operation-cap exhaustions.

This is an existing-contract coordination/receipt bottleneck on the recorded
Windows workload, not evidence that rigid-body computation needs replacement.
The precise wakeup, scheduling or contention cause remains unisolated; no OS
timer claim or late implementation change is made. The four stage definitions
and non-additive timing cautions above still apply.
`windows-final-b7-control-timing.json` preserves the actual final lane identities,
execution modes, all cohorts, counters and renderer lines. The M5 handover gives
platform-specific pacing investigation priority while retaining the current
8 ms budget and every ownership, acknowledgement and clock guarantee.
