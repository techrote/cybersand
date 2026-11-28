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
Enabled-zero and sleeping bodies approach the ordinary reference's callback cap,
although their native/physical work still has an incremental CPU cost.

All results use the same Godot 4.7 executable, Rapier and 60 callback cap on a
shared AMD EPYC 9V74 host with nine visible logical processors. They measure real
native semantic ticks and Main-owned Rapier work in **headless** execution. They
do not measure monitor FPS or establish performance on the owner's Ryzen
5600X/TITAN RTX. The release runtime and graphical/source/extracted campaigns
are qualified independently by the integration/release workstream.

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
