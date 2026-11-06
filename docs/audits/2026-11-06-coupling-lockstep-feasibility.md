---
title: Coupled native/Rapier lockstep feasibility
status: Current
document-kind: evidence
scope: Preregistered COUPLING-LOCKSTEP-001 measurement of desktop run-to-run determinism for native cells plus Rapier bodies, with a default-off lockstep fence; repeatability, Windows/WSL Linux agreement, cost, remaining non-determinism sources and a recommendation; no default, main.gd pacing, native or Rapier change
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../architecture/determinism-and-boundary-transfers.md, ../architecture/simulation-tick-and-threading.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/level-saves-and-replay.md, 2026-11-04-workbench-boundary-and-pacing.md]
---

# Coupled native/Rapier lockstep feasibility — 6 November 2026

## Answer

| Question | Result at these sources |
|---|---|
| (a) Do repeated same-host runs become bit-identical under lockstep? | **Yes.** On Windows and WSL Linux, 5/5 registered repeats per worker count were identical. 1 and 4 native workers were identical. There were 0 timeouts. Amendment repeats at 600 and 1,800 ticks were also identical. The asynchronous control diverged in 40/40 repeat pairs, each first by RACE. |
| (b) Do Windows and Linux lockstep runs match? | **Registered arm: no.** The first difference is at step 39, in the packed float32 rotation only; Rapier transforms were still bit-equal. **Exploratory amendment: yes.** With rotation repacked from the basis using a double-precision `atan2`, every recorded field matched for 600 and 1,800 ticks with 1 and 4 workers. That includes Rapier body bits, the per-tick native hash and the final hashes. |
| (c) What does lockstep cost? | At nominal load, 59.8–59.9 versus 60.1–60.6 Rapier steps/s (≤1.3%). The only held frames were 3–7 at startup. The body→cell→body result age is always 0, versus mostly 0 with 1–4% at age 1–4 asynchronously. Once native work approaches the frame, lockstep slows simulated time instead of going stale (table below). |

**Recommendation: lockstep as a selectable mode, not everywhere yet.** The
evidence follows the [remaining-source list](#remaining-non-determinism-sources).

These results survived an independent review and repair (see
[review repairs](#review-repairs--2026-11-06)). The repaired reducer also compares
the applied snapshot serial and validates every artifact and the complete
registered matrix; re-reducing the retained traces changed no decision. The
1,800-tick Windows/Linux match is a qualified experimental result for one
fixture on x86-64, not a guarantee.

The opt-in fence is a prototype. The production default and `main.gd` are
unchanged. This is evidence for a future design decision, not a replay format,
strict runtime policy or multiplayer contract.

## Context and claims

The 2026-11-06 SOL bearing-gate diagnostic (local, Draft-dependent branch
`claude/sol-bearing-gate-diagnostic-20261106`, commit `0d939d76`) saw Windows
runs match an earlier recording for about 90 steps. They then diverged when a
native tick prepared a different body sample. Telemetry-off replays did the
same. That SOL apparatus depends on unmerged native SOL code. This measurement
therefore reuses its method instead: lossless per-step bits and a
first-divergence classifier. It runs on main's ordinary coupling path, with a
fixture derived from the existing `test_physics_async.gd`.

Claims as found before this work:

| Claim | Status | Owner |
|---|---|---|
| Desktop cells and Rapier independently paced; Web sequences both on main | Current | [threading](../architecture/simulation-tick-and-threading.md), [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md) |
| Native 1-/multi-worker PhasedInPlace parity for declared fixtures | Current (native only; not the coupled Rapier world) | [determinism](../architecture/determinism-and-boundary-transfers.md#what-does-native-worker-parity-guarantee) |
| Exact comparison as the engineering oracle | Approved | same |
| Complete hash/replay versioning, future-state coverage, selectable strict policy | Planned | [determinism](../architecture/determinism-and-boundary-transfers.md#which-boundaries-still-limit-the-guarantee), [level saves](../reference/level-saves-and-replay.md) |
| Durable replay, replay input capture, explicit strict mode | Planned implementations of Approved exact validation | [level saves](../reference/level-saves-and-replay.md) |
| Fully asynchronous Web ownership | Deferred | [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md) |
| Roadmap F03 (tick ownership) and F05 (replay/fidelity) | Open | [roadmap](../reference/status-and-roadmap.md) |
| Workbench Rapier/native sample fence (`_workbench_wait_sample` vs `workbench_completed_sample`, commit `055925f1`) | Current, workbench only; pacing measured, repeatability not | [workbench pacing](2026-11-04-workbench-boundary-and-pacing.md) |

## Registration and apparatus

The registration `native/tests/fixtures/coupling_lockstep_001.json` and the
apparatus were committed at `f5ef221b79782935fa5e6fcdb355550ff1805786`, before
any execution. The runner and reducer followed at `5923179f`; the registered
matrix ran at that source. Amendment_001 was committed at
`a56e3f87` after matrix-001 had been reduced, and its runs used that source.

- **Fence.** `CyberSimulationWorker.set_lockstep_coupling(true)` is default off
  and refused after start. Each accepted body publication increments a
  mutex-owned counter. While no newer publication exists, the worker loop does
  not latch, extract or tick. It polls every 100 µs, counts holds and hold time,
  and counts a timeout once per hold longer than 250 ms; it never ticks on
  stale input. A fenced tick skips the wall-clock deadline. Labs,
  MicroScenarios, the workbench and pending physical liquid keep their own
  pacing. Snapshots carry `consumed_rigid_body_publication` in every mode. As
corrected after review, it names the publication consumed by the last
successfully completed native tick; paused, reset-only and failed turns do not
advance it.
- **Main side** (fixture only). A physics frame is skipped, and counted, until
  the newest snapshot consumed main's last publication. A hold over 5 s fails
  the episode.
- **Fixture.** `godot/tests/test_coupling_lockstep.gd` uses the
  `test_physics_async` seed-0 Sand column with three 8×14 bodies: two at the
  surface and one dropped onto them. Each Rapier step records lossless f64
  encodings of every body's transform and velocities before and after the
  step. It also records the applied snapshot serial, native tick, consumed
  publication, prepared-state bytes, result bytes and the sampled character.
  The owner records `physical_state_hash` for every tick.
- **First-divergence classes** (as registered):
  - RACE: a different consumed publication or tick.
  - NATIVE: same consumed inputs, different results.
  - RAPIER: same pre-step bits and results, different post-step bits.
  - OTHER: anything else.

**Retained apparatus defect.** matrix-001 read `state_hash` and `content_hash`
from `diagnostic_snapshot`. The adapter returns `state_hash` under `"hash"` and
has no `content_hash`, so both final fields were empty strings in all 40
episodes. The final-hash tail comparison was vacuous. Per-tick
`physical_state_hash` and per-step bit comparisons were complete. Amendment
runs record `"hash"` and a final `physical_state_hash`. matrix-001 evidence is
unchanged.

## Execution and custody

All runs were on the same host: AMD Ryzen 5 5600X (6 cores, 12 logical CPUs),
Windows 11 Pro build 26300. Linux ran in WSL2 Ubuntu-24.04 (kernel
6.18.54.1-microsoft-standard-WSL2, glibc 2.39). Each episode used a fresh
process with a 300 s bound, and arms were interleaved within each repeat.

| Identity | SHA-256 |
|---|---|
| Windows Godot 4.7 console executable | `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c` |
| Linux Godot 4.7 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Windows native (built from `acce570e`, native source unchanged to HEAD) | `cb675a4cde4317608bb892437af9b9f2b7cddf6a7289a6a028500efab19aae9d` |
| Linux native (same build source) | `a09a4a60cb54c8f1ca5c339d5ef8c3e230b53fc931b845690211ca33b5dac588` |
| Windows Rapier (addon v0.35.2, rapier2d 0.35.1, BVH backport) | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| Linux Rapier (same build inputs) | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |

Raw evidence was produced in uncommitted `build/coupling-lockstep/` (268
files, 126.7 MiB including the review repair logs). It is sealed, with a
per-file SHA-256 manifest (`coupling-lockstep/MANIFEST.sha256.json`), in the
host's evidence store as
`C:/CyberSand-evidence/PR464-coupling-lockstep-001-20261106T191757-ba5733dd.zip`
(21.9 MiB, SHA-256
`fa0e7bd77f5b2a0b5b57c6463e966d056c807cea0a5a65579962a2eb530410d9`). That copy is
still host-local. The repository is public, so publishing the archive (for
example as a release asset) is an owner decision and has not been done. Every
receipt records `post_source_equality: true`. matrix-001's `reduction.json` was
regenerated by the amendment reducer at `a56e3f87`. Its decisions match the
first reduction, and only the decision-key format changed.

| Run | Source | Episodes | receipt.json | reduction.json |
|---|---|---:|---|---|
| smoke-001 (excluded) | `5923179f` | 8 | `a0908528…6089bac` | `1d9a7099…16f74e7` |
| matrix-001 | `5923179f` | 40 | `48215957…60d2` (full `482159574c8e2fc68d20bd4657deabeb9b6f82bdd429a32348f8ec61da2960d2`) | `71bba09aed069c68b064abe3113c165ebaef7cf908888bb3c349d630326be96e` |
| f64rot-001 | `a56e3f87` | 24 | `790f0b1e7b642a3c4d0613bd8d1e7347810fff3e7d7fa9d151cef7b3140e16e1` | `d3125edbc0ffaf08577df2cd71d9fe9f820a85351838e3dd3fd468ccdfbc425a` |
| horizon-001 | `a56e3f87` | 16 | `1d342e349a97d5ad2977d439da74d29f7cb6d883c1fb07c1ed4976d97a5d2c1e` | `f2c0fc63359af14936cd9be4b6aa99c6c0074174013e977574934e0af9ce8d27` |
| load-0/8000/14000/20000 | `a56e3f87` | 4 each | `8304d845…`, `c372ddc2…`, `d6eb3995…`, `c0015818…` | `9704a48b…`, `3ee56f5e…`, `e286b910…`, `f16bf938…` |

## Review repairs — 2026-11-06

An independent review of head `8577a8d2` (GitHub review 5804426933) accepted
the approach and required repairs before the exactness claims are accepted.
Repairs were made first and the retained traces were then re-reduced; no new
measurement episode was needed.

| Finding | Repair | Effect on results |
|---|---|---|
| P1: the reducer did not compare the applied snapshot `serial`, although the registration records it | `serial` is a compared step field and a RACE-class field (`cdfe26ac`); a negative regression proves a serial-only difference is detected | None: every decision is unchanged |
| P1: the reducer trusted the receipt `clean` flag; one valid episode passed repeatability vacuously and an empty group threw | The v2 reducer validates source identity at the recorded commit, result and log hashes, measured wall time inside the process duration, tick-hash and trace coverage, completed ticks, fence invariants (lockstep step N applies tick N from publication N) and exact registered matrix membership. Any error yields no decisions and exit 2. Eighteen regressions cover corruption, missing repeats, empty groups, duplicates, incomplete traces, durations, the clean flag and identity, and run in Documentation CI | All eight retained runs validate with zero errors; decisions unchanged |
| P2: snapshots copied the latest latched publication even when no native tick completed | `_lockstep_completed_publication` is advanced only by a successful tick; superseded publications are counted (`ba5733dd`). `test_coupling_lockstep_semantics.gd` exercises pause, paused reset, duplicate publications and (at the owner bookkeeping boundary, since the World has no failure injection) failure | None for the retained traces: the fixture never pauses or resets, a native failure fails the episode, and asynchronous pre-tick applications already recorded `-1`. Lockstep traces satisfy the fence invariant at every step |
| P2: custody and qualification | Evidence sealed as above; main merged (`c30e6862`, one index conflict, both sections kept) | Public evidence upload and exact-head runtime CI remain open (see below) |

Validation notes from the v2 reducer:

- Amendment receipts (`a56e3f87`) hashed the Windows CRLF working-tree copies
  of the registration, runner and fixture. They equal the CRLF form of the
  committed LF blobs, and the reducer records this as a note rather than a
  failure. matrix-001 identities match the blobs directly.
- matrix-001 and smoke-001 final hashes are the registered empty-field defect.
  The reducer requires them to be empty there, reports
  `final_hashes_compared: false` and requires them non-empty for every other run.
- The original `reduction.json` files are retained unchanged; v2 output is
  `reduction-v2.json`.

| Run | reduction-v2.json SHA-256 |
|---|---|
| matrix-001 | `db077991a6337475047e48f44870245c1319292d235d5777cf9dae5eca690fc8` |
| smoke-001 (excluded) | `4e3f9a6d8baac40da09b364c6ae62ea742cec3c9c427bcb47ed24d0dfd31b3fe` |
| f64rot-001 | `fec90d6c49518554f9468bc76679dc60d1be23fe1d26496a617933ed5eec883e` |
| horizon-001 | `1203edbd8411cfef3e50ff209cc154a008190d21184330f27c1bcecffd6d429e` |
| load-0 / 8000 / 14000 / 20000 | `0bbb7576…`, `b6ef7a89…`, `232c7974…`, `3b7d01ee…` |

## Results

### (a) Same-host repeatability

| Group (600 ticks) | Lockstep pairs differing | Async pairs differing | Async first divergence (step) |
|---|---:|---:|---|
| Windows w1 | 0/10 | 10/10 RACE | 3–7 |
| Windows w4 | 0/10 | 10/10 RACE | 3–86 |
| Linux w1 | 0/10 | 10/10 RACE | 9–45 |
| Linux w4 | 0/10 | 10/10 RACE | 7–12 |

- Lockstep w1 equals w4 on both hosts. The coupled run therefore preserves
  native worker parity.
- In every RACE, the two runs applied results prepared from different body
  publications or native ticks while all earlier steps were equal.
- Asynchronous runs took 601–605 Rapier steps for 600 native ticks. Main
  re-applied no new result on some steps.
- The amendment found 0 differing pairs for both lockstep arms, on both hosts,
  for both worker counts: 3 repeats at 600 ticks and 2 at 1,800 ticks.

### (b) Windows versus Linux

- **Registered lockstep (w1 and w4): DIFFER.** Up to step 38 everything is
  equal. At step 39 only the packed sample differs: body 1's float32 rotation is
  `-0.0022422580514103174` on Windows and `-0.002242258284240961` on Linux. Both
  were computed from the same bit-equal basis by `Transform2D.get_rotation()`,
  a float32 `atan2` from the platform libm. The true value is
  `-0.0022422581433898903`.
- After that, native results first differ at step 54 and Rapier post-step bits
  at step 57. The per-tick physical hash first differs at tick 85.
- **Amendment `lockstep-f64rot`: MATCH** on every recorded field: 600 ticks with
  w1/w4 and 1,800 ticks with w1/w4. At 1,800 ticks with w4, both hosts end with
  `state_hash` `75162c33c4c48132`, physical hash `5c3bc06158bd2404` and equal
  final body bits.
- That arm is fixture-only: rotation is `atan2(float(basis.x.y), float(basis.x.x))`
  in double, stored as float32. Production packing is unchanged.
- So, in this fixture, MSVC-built and GNU-built Rapier 0.35.1, built without
  `enhanced-determinism` and with `parallel` on, and the two native builds
  produced identical arithmetic on x86-64. One fixture does not make that a
  guarantee.

### (c) Cost

Nominal load (matrix-001, medians per group):

| Arm | Rapier steps/s | Held frames | Result age histogram (0,1,2,3,4) | Worker overruns |
|---|---:|---|---|---:|
| Async, Windows | 60.1–60.2 | 0 | ~99% age 0; ages 1–4 present | 0 |
| Async, Linux | 60.6 | 0 | ~96% age 0; ~4% age 1 | 0 |
| Lockstep, Windows | 59.8 | 3 per episode (startup) | 100% age 0 | 0 |
| Lockstep, Linux | 59.9 | 6–7 per episode (startup) | 100% age 0 | 0 |

The lockstep worker's mean wait of about 13 ms per tick (maximum 25 ms) is idle
time until main's next frame, not added work. There were no timeouts.

Synthetic load: amendment `load-*`, Windows, w4, extra native-owner time added
before each publication.

| Extra native time | Async steps/s, ages, overruns | Lockstep steps/s, held fraction |
|---:|---|---|
| 0 | 60.1; 96% age 0; 0 overruns | 59.8; 0.5% |
| 8 ms | 60.1; 71% age 1; 0 overruns | 59.8; 0.6% |
| 14 ms | 60.1; 85% age 1, 2% age 2–4; 48 overruns | 35.1; 41.5% |
| 20 ms | 60.2; 65% age 1, 35% age 2; 189 overruns | 29.9; 50.2% |

Asynchronous mode keeps Rapier real-time and lets coupling results go stale.
Lockstep keeps results exact, so simulated time slows. The worker misses the
next frame once native time plus wake-up latency exceeds what is left of the
16.7 ms frame. That happened at 14 ms here.

Uncontrolled contention: during horizon-001, another session's Godot process
(PID 31364, started 16:47) shared the host. Windows lockstep episodes stretched
from 31 s to 39–58 s, with 33.6–47.7 steps/s and 21–44% held frames. Linux was
unaffected. Bit identity still held: 0 differing pairs, and Windows equalled
Linux for f64rot. Timer granularity and contention affect lockstep throughput
only. Polling with `OS.delay_usec` also adds Windows wake-up latency; a
semaphore would remove it.

## Remaining non-determinism sources

| # | Source | Evidence | Status after this work |
|---|---|---|---|
| 1 | Publication/tick race: worker prepares whichever sample main last published | Measured: 40/40 async pairs, RACE at steps 3–86 | Removed by the fence in the fixture only. `main.gd` is not wired, and labs, MicroScenarios and the workbench are excluded. |
| 2 | Godot physics-frame timing: catch-up frames step Rapier with no new result | Measured: async 601–605 steps per 600 ticks | Removed under lockstep: held frames do not step. |
| 3 | Float32 `atan2` in `pack_body_states` (`Transform2D.get_rotation`) | Measured: 1-ulp Windows/Linux difference at step 39 | Fixture repack removes it. Production unchanged; candidate fixes are packing basis cos/sin or a double `atan2`. A double libm `atan2` matched here but is not guaranteed correctly rounded on every platform. |
| 4 | Native double `std::cos`/`std::sin` in rasterization and overlap tests (`cyber_native_cell_world.cpp` `rasterize_transform_in`, `cell_inside_body`, `overlap_normal`) and `granular_contact_response.hpp` | Inspection; not observed to differ in this fixture | Unverified. The same platform-libm class as #3. |
| 5 | Rapier build: `parallel` on, `enhanced-determinism` off (`third_party/rapier-bvh-build.lock.json`); deferred BVH join is blocking | Same-host repeatable; Windows matched Linux on x86-64 | Not guaranteed across CPUs, ARM, Web/Wasm or other compilers. |
| 6 | Wall-clock budgets on main: hard-terrain collider installation (`process_hard_surface_collider_budget`, 750 µs soft budget), render-snapshot cadence | Inspection; this fixture installs terrain once | Live terrain edits can change collider installation timing across runs. A lockstep mode needs a tick-counted budget or an installation fence, like the workbench terrain fence. |
| 7 | Inputs: keyboard, edits, emissions, physical effects and usables reach the worker on wall-clock timing | Inspection | No tick-keyed input capture exists. Required for demo replay and multiplayer. |
| 8 | Hash coverage: `state_hash` omits external body state; no hash covers Rapier internals or contact caches; `content_hash` is not exposed by `diagnostic_snapshot` | Inspection and the retained apparatus defect | Per-step body bits plus `physical_state_hash` were used here. A replay identity must define a combined hash. |
| 9 | Native worker count | Measured: coupled w1 equals w4 | Not a source. |
| 10 | Workbench fence | Exists (`055925f1`); not measured | Measure separately. Its native coupling (`accumulate_workbench_contacts`) differs from the ordinary path. |
| 11 | Desktop versus Web order (F03) | Documented | Unchanged. A cross-platform contract must pick one order. |

## Recommendation

Adopt **lockstep as a selectable mode**: demo recording and playback, A/B
development runs and later multiplayer. Keep the asynchronous default for
ordinary play for now.

- **For a mode.** Same-host exactness is achieved with a small change, has no
  measurable cost at nominal load and improves coupling latency, since result
  age is always 0. Cross-host exactness was also reached in this fixture once
  float32 `atan2` packing was removed.
- **Against everywhere.** Lockstep turns any native or host stall into slow
  motion: 35 steps/s at 14 ms of extra native time, and 34–48 steps/s under
  foreign contention. The asynchronous default stays real-time. The fence also
  does not yet cover labs, MicroScenarios, the workbench, terrain installation
  or inputs.

Suggested next steps, each separately registered and owner-approved:

1. Wire an opt-in mode in `main.gd`, mirroring the fixture's main hold.
   Replace polling with a semaphore wake, and consider a bounded in-frame wait
   of about 2 ms before skipping a frame.
2. Make packed rotation deterministic. This is small and affects both modes.
   Re-measure in the existing fixture.
3. Fence or tick-count the terrain collider installation in lockstep mode.
4. Add a tick-keyed input stream and a combined native+body replay hash. This
   is the replay schema owned by F05.
5. Measure workbench-fence repeatability and a heavier fixture: many bodies,
   liquids, actors and live edits.
6. Before any multiplayer claim, evaluate a separately built
   `enhanced-determinism` Rapier with full provenance, and test non-x86 and Web
   targets.

## Validation

- After the review repairs (source `ba5733dd`, run 2026-11-06, 600 s bound per
  test, same engines): Windows `test_coupling_lockstep` (self-check),
  `test_coupling_lockstep_semantics`, `test_physics_async`,
  `test_physical_actor_integration`, `test_rem002_body_granular` and
  `test_physical_actor_effect_admission`, and WSL Linux
  `test_coupling_lockstep`, `test_coupling_lockstep_semantics`,
  `test_physics_async` and `test_physical_actor_integration`, all exit 0.
  Making the snapshot report the latest latched publication again makes the
  semantics test fail with four errors. The 18 reducer regressions pass.
- After the repairs and the main merge, `check_docs.py`,
  `check_m11_consistency.py`, `check_repository.py`, the CI-provider check and
  `git diff --check` exit 0, and retrieval is unchanged (frozen 19/32 at rank 1,
  32/32 at k = 5; challenges 124 and 156/157; PLAY 12/12; lockstep 2/3 and 3/3).
- Native, GDExtension/Godot and scoped runtime CI do not run while the PR is a
  Draft. Exact-head runtime CI is required before any promotion.
- Original regressions with the fence default off:
  - Windows: `test_physics_async`, `test_physical_actor_integration`,
    `test_rem002_body_granular` and `test_physical_actor_effect_admission` all
    exit 0 with no errors.
  - WSL Linux: `test_physics_async`, `test_physical_actor_integration` and the
    lockstep self-check all exit 0.
- The lockstep self-check (`test_coupling_lockstep.gd` with no arguments)
  passes on both hosts: every step applies the result of publication N−1 at
  age 0, and reconfiguration after start is refused.
- At the documentation working tree (parent `a56e3f87`), `check_docs.py`,
  `check_m11_consistency.py` (no working-tree differences), `check_repository.py`
  and `git diff --check` all exit 0. No inherited failure was observed on this
  main-based source, and no guard or hash was refreshed.
- `retrieval_eval.py` (BM25, k = 5), compared with a main `06522e30`
  documentation snapshot:
  - frozen set: 19/32 hit@1 and 32/32 hit@5, before and after;
  - challenges: 124 hit@1 and 156/157 hit@5, before and after;
  - PLAY: 12/12;
  - no question changed rank.

  The additive [lockstep questions](../reference/retrieval-questions-lockstep.json)
  hit 3/3 at k = 5 and 2/3 at rank 1. LOCKSTEP-003 ranks its interface contract
  third.

## Reproduction

```text
godot --headless --path godot --script res://tests/test_coupling_lockstep.gd
python tools/lockstep/run_coupling_lockstep.py --run NEW
python tools/lockstep/run_coupling_lockstep.py --run NEW --arms lockstep,lockstep-f64rot --repeats 3
python tools/lockstep/run_coupling_lockstep.py --run NEW --hosts windows --workers 4 --delay-usec 14000
python tools/lockstep/reduce_coupling_lockstep.py --run NEW
python -m unittest discover -s tools/lockstep -p test_reduce_coupling_lockstep.py
godot --headless --path godot --script res://tests/test_coupling_lockstep_semantics.gd
```
