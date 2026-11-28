# ObjectShard M4 semantic throughput — 28 November 2026

This is historical mission evidence, not an independent acceptance or publication
contract. Candidate remains Draft/HOLD for physical owner evaluation.

## Source and execution scope

The matched historical application is `1ec3f214662f7d5a0a38ff727b684c15b41c067b`.
Its executable scripts/native source inputs match the owner-evaluated application
`efe3bc19c68a9b9e292821ef28b735caec538915`; intervening changes concern runtime
publication and qualification tooling. Baseline Linux native SHA-256 is
`5fdf1e8f60f7fd93090ce4d924544c5f7aa9393e565af6b85a4e15e73d63ba20`.

Initial B implementation is `f25b1aaa2`. It depends on A's geometry-sensitive
bridge helper from `047c89f19`. Local combined A+B+C native is privately anchored
at `3479c621c`, SHA-256
`aa015a895c091f67d6d07a7f6dab6b18d6e1e55247ff880c10fcef7425a2149b`.
That build uses GCC 14.2/binutils 2.44 under the established explicit local
compiler-drift option, so it is test evidence, not the guarded release runtime.
Root owns accepted-main reconciliation and guarded Windows/Linux publication.

All local comparisons use the same Godot 4.7 stable executable, SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`, and Rapier
0.35.2 binary, SHA-256
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
The local shared host reports AMD EPYC 9V74 and nine visible logical processors.
Results use headless execution with a 60 callback cap. They measure actual native
semantic ticks and Main Rapier time. They do not measure physical monitor FPS or
establish performance acceptance on the owner's Ryzen 5600X/TITAN RTX.

## Confirmed orchestration costs

The starting implementation already had an 8 ms bounded receipt pump in Main's
idle callback. It was therefore incorrect to attribute all lost progression to a
simple worker sleep or to absence of any fast pump. Investigation separated:

- Physics callbacks decided readiness before consuming an already completed
  worker receipt. Waiting until the later idle callback could miss the next
  complete physical frame.
- Every intermediate physical segment entered the full ordinary worker turn and
  rebuilt a native material presentation plus Godot dictionaries. For one tower,
  180 semantic ticks required 721 actual segments and 1,080 snapshots, taking
  about 676 ms in native snapshot plus Godot marshalling calls.
- Native pose/contact work still has a material cost. The first tower recording
  attributed about 1.026 s to occupancy over 180 ticks; relocation was a nested
  approximately 0.744 s with zero relocated cells. Those nested costs must not be
  added to occupancy. Rapier was approximately 111 ms over the whole run.
- Ordinary diagnostic `receipt_delivery` measures snapshot publication to Main
  observation. It is not an M4 command service measurement. New serial-bound
  counters divide each exact control into admission queue, native owner call,
  presentation/receipt copying, and Main delivery spans. These spans partition
  that control but overlap other Main/worker instrumentation and are not an
  additive frame-cost model.

An instrumented 48-operation pump exhausted its operation limit 154 times in
1,085 calls, as well as its time budget 230 times. A 128-operation variant had
zero operation-limit exits in 775 calls and 351 time-budget exits. The wall budget
remains 8 ms. This removes a second, shorter platform-sensitive polling ceiling;
it does not allow unbounded Main rendezvous. Exploratory sequential rates varied
with scheduling and were not used as the final matched comparison.

## Bounded implementation and preserved contracts

Main's physical callback now consumes already admitted receipts before deciding
whether to start its one new fixed 1/60 interval. Only an `OwnerBusy` permit may
rendezvous for up to 2 ms; every retry validates the same exact installed frame,
and no actor work, forces or physical time occur before a grant. All other
refusals retain their existing behavior.

The exclusive native worker can service `accept_motion` during an active lease
without rebuilding unrelated ordinary publications. A completion, replacement,
failure or lifecycle transition returns to the ordinary owner path. Its final
actor sample, equipment/effects and semantic tick retain their existing one-shot
consumption. No native World or Rapier authority moves between threads.

Only a successful explicitly non-final segment may omit its full presentation
snapshot. Native copies the actual bounded `OwnerReadback` pose roster after
application; it does not echo caller coordinates as proof. The compact proof
requires the complete active roster, no truncation, no quarantine and no geometry
or promotion pause. Main retains every original native acknowledgement and exact
identity/coordinate/velocity/sleeping comparison. Failed, incomplete, legacy and
final segment receipts retain the full diagnostic/material frame. Final interval
completion and the semantic tick also publish full frames. Existing pending and
physical-interval barriers prevent a retained prior frame from being presented
with newer terrain.

A's helper is also used by the runtime's predictive angular subdivision; B does
not change its native occupancy or physical motion contract.

## Repeatable apparatus

`godot/tests/profile_object_shard_m4_throughput.gd` provides the same light
observer for ordinary disabled Workbench, enabled zero detached bodies, one
mixed-material tower, eight actual structural bodies, and a naturally sleeping
plank. The sleeping fixture removes a real authored support, proves a fall before
natural Rapier sleep and requires the entire measured cohort to remain asleep.
Recording off/on is selected through the ordinary Structures diagnostic control.

The fixture disconnects deep per-callback coherence observers only for the timed
window, then checks full native/physical/publication/quantity coherence after
Pause. It reports callback-end actual native awake/owned cohorts, not an inferred
active count. A 6-second window compares a common initial authored scene;
semantic progression differs and therefore later physical states can differ.
Rates are descriptive, not fixture acceptance thresholds.

`tools/objectshard/compare_throughput.py` runs one process at a time, interleaving
baseline/candidate and candidate/baseline on repeated pairs. It records executable,
Rapier, native and relevant source hashes, every return code, actual cohorts,
checks and rates. The two projects must contain the identical copied harness.
Historical native versus current combined native compares the complete candidates;
a same-native control is required to isolate compiler/native-facade differences.

## Qualification and current disposition

Initial actual-native receipt scheduling regression passed 124 checks. It delays
one genuine receipt, challenges copied stale/foreign serials and native pose
proofs, retains every ACK, completes exactly one paused native/actor interval,
and refuses duplicate physical/semantic time. The final segment remains full.
Focused follow-ups add queued Pause/brush, actual native refusal, whole-World
replacement and shutdown while a physical lease is idle.

The original stale-admission lifecycle fixture now calls the real permit API
while both pumps are disabled. Calling the ordinary physical callback would
correctly synchronize the newer publication first, invalidating the old test's
premise. All stale-source/no-clock assertions remain intact.

Matched matrix, same-native control and focused integration results are being
collected. No provisional rate or incomplete campaign is an acceptance waiver.

## Initial matched evidence and residual constraint

The first forty interleaved six-second profiles all passed their native, physical,
cohort and quantity assertions. `throughput-initial-matrix.json` preserves their
identities and small receipts. The clean recording-off pairs are:

| Workload | Baseline semantic ticks/s | Candidate semantic ticks/s | Support |
|---|---:|---:|---|
| Structures disabled | 59.33 | 59.33 | Full windows, zero detached bodies |
| Structures enabled, zero bodies | 34.94 | 60.01 | Full windows, zero detached bodies |
| One awake mixed-material tower | 18.71 | 54.22 | All callbacks report one owned/one awake across both full windows |
| Eight awake bodies | 15.36 | 29.56 | Baseline 89 ticks in each 5.65/5.95 s cohort; candidate 90/89 ticks in 3.07/2.99 s cohorts |

Values are medians of the two observed rates. Eight-body global windows also
contain fewer awake bodies after natural settling: their 15.38 versus 29.08
overall rates are not substituted for the actual eight-awake cohort rate.
Cohorts are actual acknowledged callback-end snapshots, not continuous sensor
traces. The sleeping fixture independently queries actual Rapier sleep.

The one-body 45–60 engineering objective is reached in this local headless
experiment. The eight-awake objective of at least 30 is narrowly missed and
remains open. No physical-machine acceptance follows from these results.
The measured candidate eight-body case still spends approximately 3.10 ms per
actual motion acknowledgement in its native owner call (four base segments per
semantic interval), approximately 3.77 ms per semantic interval constructing
three full snapshots, and 1.04 ms per interval in actual shared Rapier stepping.
Those serial/native spans explain a remaining callback-scale limit; they cannot
be summed with overlapping pump/worker totals as an exact causal decomposition.

Sleeping/off and recording-on samples overlapped C's required Held-camera tests
or A's required sparse-fragment failure reproduction. They remain functional
passes and descriptive observations, with concurrency explicitly recorded; clean
final-source confirmation will replace them for comparative performance claims.

## M5 handover from this workstream

Keep the exclusive native owner, Main-only physical space, immutable full visual
publication, exact geometry revision and one-shot actor/equipment completion
boundaries. Compact intermediate proofs are a useful extension seam: receipt
size can scale with active pose identities while presentation is constructed at
semantic/display boundaries. They do not make independently advancing bodies
safe or remove occupancy/contact work.

The next measured investigation should separate native occupancy traversal and
its nested relocation scans, especially sleeping or unchanged footprints. Test
cache/reuse proposals against moving cuts, contact, liquid/granular transfer and
full material accounting before batching more native work. At hundreds of
fragments, nested pose matching, single-flight receipts and per-segment complete
active rosters will become explicit scaling constraints. A later batched or
hierarchical transaction design needs a declared physical-time/ACK boundary,
not a larger queue/body limit. Hybrid debris and interpolation can then build on
those measured contracts. No hybrid/M5 representation was added here.

## COM-domain integration and adversarial completion follow-up

A's subsequent natural sparse-parent collision established a second independent
source of conservative false refusal: erased empty storage still moved around a
remote origin. B runtime follow-up `a3b596e0a` consumes A's native material/COM
domain. Full synchronization refreshes its exact material/geometry-bound extent
before Ready; predictive angular admission uses the active extent diagonal and
corner admission uses radius about physical COM. Intermediate motion records
contact witnesses but transfers no owned carriers, so the domain remains fixed
through one physical lease. Native semantic ingress precedes chemistry and rigid
geometry rebuilding; changed carriers are refreshed before the next lease.

Local combined COM native SHA-256 is
`547c8f6f3474bc6f6406176239cefe3ae42d63326423f219d68a26d6a75032a0`.
The extended receipt scheduling fixture passes 151 checks on that native. It
includes actual ordinary Pause and Sand brush during a delayed segment, a real
invalid-geometry native protocol refusal returning a complete diagnostic frame,
Restore while its refused lease is idle, ordinary shutdown/worker join during
an admitted lease, and coherent terrain/structural observations throughout.

The first new interrupted-Pause assertion incorrectly expected actor time to
advance when the material interval drained. Existing `test_object_shard_m4_actor_clock`
and `physical_actor_session.complete_step` deliberately suspend controller time
immediately on Pause. The new fixture was corrected to require exactly one
already-admitted native/physical interval, no actor tick after interruption, and
the separately checked paused Step's exactly one actor tick. Production semantics
and existing actor-clock assertions remain unchanged; the original failed local
receipt is retained in mission evidence.

The existing equipment completion fixture required repeated ordinary snapshots
while a complete physical interval was deliberately withheld. Leased service
now intentionally retains the last coherent snapshot. Its replacement witness
requires that single retained publication plus actual asynchronous worker idle
progress, and authenticates the exact queued equipment request from the real
immutable transport admission and mutex-owned pending queue. All no-premature-use,
source-bound cutoff, delayed second request, cancellation, Rocketjumper effect,
projectile count/age and one-shot tick assertions remain. Updated fixture passes
95 checks; actual actor-clock 96, delayed final-sample 104, stale-owner lifecycle
133, and ordinary cutting/combustion/quantity completion 185 also pass locally.

The fragmented-pointer regression also deliberately withheld Main publication.
It now disables both idle and physical receipt callbacks for that exact test
window; disabling only idle callbacks correctly allows the new physical pump to
install a fresh publication and therefore no longer reproduces the intended
delay. Its one-cut-before-display and source-cell receipt assertions remain.
Fragment/fuzz/replacement setup waits now observe durable attachment or body
reservation, then the existing exact paused geometry/publication barrier. They
do not depend on observing a transient Ready phase during active play. The
returning plank explicitly resumes after that barrier before its ninety real
physical intervals; no settlement or material assertion was relaxed.

Final focused results on the combined COM native: completed-sample 104, equipment
95, actor clock 96, stale-owner lifecycle 119, ordinary Workbench completion 185,
fragment/reabsorption 134, lifecycle fuzz 1,007, optional diagnostics 36, and
remote barrel 114 checks; all pass. Extended receipt/lifecycle case adds 151.
The final source/extracted campaign remains independently required.
