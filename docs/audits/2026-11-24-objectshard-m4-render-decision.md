---
title: ObjectShard M4 rendered performance decision
status: Current
document-kind: audit
scope: Actual Linux software-renderer development controls, separate semantic progression and physical Windows/NVIDIA acceptance boundary
last-reviewed: 2026-11-24
related-documents: [2026-11-24-objectshard-m4-completion-negative-results.md, 2026-11-24-objectshard-m4-source-recovery.md, ../research/objectshard-m4-workbench.md, ../operations/objectshard-workbench-playtest.md]
---

# ObjectShard M4 rendered performance decision

**Performance decision: HOLD.** The ordinary Workbench now has actual native
ownership and Rapier progression witnesses, but the measured cloud graphical
workloads remain slow. Neither passing functional checks nor headless semantic
throughput resolves the owner's earlier active-body rate below 10 FPS. Physical
Windows/NVIDIA acceptance requires the verified ordinary Workbench evaluator on
that machine.

This record concerns measured development sources, not a claim that a later
application commit has already passed its complete platform campaign. All rates
below identify their own clocks and workloads. A renderer submission is not a
measurement of physical monitor scanout.

## Source and environment custody

The observations use official Godot `4.7.stable.official.5b4e0cb0f`, Rapier
`0.35.2`, X11 and OpenGL compatibility rendering. The reported device is Mesa
25.0.7 llvmpipe, LLVM 19.1.7. This is CPU software rendering, not NVIDIA. The
desktop reports nine available processors; other workloads share the host.
Concurrent desktop applications and changing host resource pressure prevent an
uncontended benchmark claim.

| Observation | Frozen application source | Loaded Linux native SHA-256 |
| --- | --- | --- |
| Full 180-tick graphical tower baseline | `e39c423872c9e1682a1fc67d0fedde2313068756` | `5eba15b16979dd3b0fc69002e7fa31f4135cb90a3ad7de51043506064126836a` |
| Four paused/playing controls after sparse composition | `30597a36d7c0d6e817c45dd1210e2764b3603709` | `d355e859bbe7409f52cc2c1879ab9fd52cb26650cd706bd37775fd57e8386628` |
| Same-source default/four-thread controls after readiness suppression | `d089df853e5bb1f3236a93e2b048082e8e5169c4` | `0dfe2a63e69062a44a4b7eb01ea65a4aa9c210f096f2413344482b7b051a68ae` |

The final native development binary's original build source is
`ccdfde97c279d809eafbb6e74b880d14cfb2f60e`. Its 117 native compilation
inputs match the executed application source. Reuse of those identical inputs
does not change the original build identity. The local compiler is GCC 14.2;
the pinned hosted Linux/Windows builds are separate qualification artifacts.

The [evidence manifest](objectshard-m4-completion-20261124/graphical-evidence-manifest.json)
hashes the retained JSON records. The [final native build receipt](objectshard-m4-completion-20261124/graphical-final-native-receipt.json)
preserves its full source-input map. Raw logs, environment observations and
frozen source copies remain part of the development evidence bundle.

## Full actual graphical tower baseline

The [completed tower run](objectshard-m4-completion-20261124/graphical-baseline-profile.json)
passed 101 checks, completed 180 native semantic ticks in 205.938 seconds and
recorded 1,075 actual renderer post-draw callbacks. It observed an awake real
Rapier body and exact native pose acknowledgements throughout the measured
workload, with no displayed World/shard identity mismatch.

| Metric | Observation |
| --- | ---: |
| Renderer submissions per wall second | 5.220 |
| Native semantic ticks per wall second | 0.874 |
| Render interval median | 167.174 ms |
| Render interval p95 | 351.327 ms |
| Longest render interval | 681.693 ms |

Compilation and other host work overlapped this observation. It establishes a
real slow rendered workload, not an isolated speed measurement or physical
Windows acceptance. An earlier terminated attempt produced no complete report
and is retained as an invalid attempt.

## Paused and playing controls

Each control uses the ordinary tower, twelve-second windows, actual native
material and the existing Main Rapier space. The latency probe is disabled and
there is no full diagnostic readback on each callback. Paused windows admit no
physical or native time and perform zero owner snapshots. A detached paused
body remains physically owned; pausing is not a material return or deletion.

The earlier [sparse-composition controls](objectshard-m4-completion-20261124/graphical-controls-before-readiness.json)
passed 116 checks. They recorded 4.49 submissions/s while intact and paused,
4.77 intact and playing, 2.78 detached and paused, and 2.50 detached and playing.
The active detached window progressed only 0.25 native ticks/s. These are
another source and another host-pressure interval; no before/after speedup
ratio is valid against the later run.

The final pair uses exactly the same application source and native binary.
The only deliberate environment difference is setting `LP_NUM_THREADS=4`
versus leaving it unset. Other shared-host activity was not controlled. Both
runs passed all 116 checks, with 518 and 822 process observations respectively
and the same number of actual draw observations; neither had an incoherent
World/shard publication.

| Window | Default renderer submissions/s | Four-thread renderer submissions/s | Default native ticks/s | Four-thread native ticks/s |
| --- | ---: | ---: | ---: | ---: |
| Intact, paused | 9.607 | 9.559 | 0 | 0 |
| Intact, playing | 9.645 | 9.105 | 3.050 | 2.980 |
| Detached, paused | 7.792 | 8.708 | 0 | 0 |
| Detached, playing | 7.522 | 7.632 | 1.571 | 1.576 |

The [default active window](objectshard-m4-completion-20261124/graphical-controls-default.json)
completed 19 real physical intervals and 19 native ticks in 12.097 seconds.
Its render-interval p95 was 207.795 ms. The
[four-thread active window](objectshard-m4-completion-20261124/graphical-controls-four-threads.json)
completed 20 physical intervals and 19 observed native ticks in 12.055 seconds,
within the permitted one pending native boundary. Its render-interval p95 was
183.546 ms. All accepted native body poses had exact real-Rapier echoes.

Changing the software-renderer thread setting did not produce a substantial
active-body improvement in this pair. These runs provide no basis for shipping
that setting as a performance repair. Slow paused windows show substantial
standing presentation/host cost even with zero worker snapshots and zero
simulation progression. They do not prove that every active-body slowdown has
the same cause, or establish the cause of the owner's NVIDIA observation.

## What the implementation changes do establish

Source review and native/ordinary-Workbench tests support these bounded
reductions in unnecessary work:

- Compact owner publications omit the already supplied ordinary World raster.
- Sparse attached composition visits occupied shard cells, preserves ordered
  relocation and reuses only a still-current composition receipt.
- Unobserved no-resolve GCR sweeping is omitted where the attached transaction
  supplies the complete composition; ordinary observed paths remain intact.
- Unchanged shard material textures and terrain geometry reuse their storage.
  Texture identity includes the full World/body incarnation and dimensions.
- Authenticated steady-state binding no longer adds a redundant zero-lease
  readiness command after each completed publication. Initial binding,
  exact-publication motion leases and all segment acknowledgements remain.
- The Main rendezvous remains bounded to eight milliseconds and 48 operations;
  it neither invents native ticks nor removes required physical segments.

The [eleven actual graphical texture checks](objectshard-m4-completion-20261124/graphical-overlay-identity.json)
pass on source `348146492b1fb90c950eba5898d719156bcc5c11` with the final
native development binary. Their publications are intentionally synthetic to
test texture storage identity; they are not a native motion or conservation
test. Actual ordinary Workbench motion is witnessed by the separate controls.

Native occupancy time includes relocation, and the Main receipt-pump time
includes waits and its nested stages. Adding them as independent wall-clock
cost would double-count work. Two attempted matched headless baseline runs
terminated with signal 9; successful later runs do not repair that missing
causal comparison. Registered native and standalone performance budgets remain
unchanged and require their own complete final campaign.

### Remaining serialization cost

An [independent source and counter review](objectshard-m4-completion-20261124/snapshot-cost-review.json)
examined the later 148-check mixed/overview profile at application source
`d106273e7adb70576dce104a339fc4ef6a0f3e94`, with the final native development
binary and one 98-by-125-cell shard. During 180 native ticks and 720 actual
physical segments, the worker made 1,080 compact owner snapshots. The enclosing
snapshot stage took 1.533 seconds of the 12.365-second observation; the native
coordinator's nested snapshot counter accounted for only 8.94 milliseconds.

The facade already reuses unchanged packed material arrays. Source review
identifies remaining serialization of shape/terrain rectangles, current
accounting dictionaries and a full bounding-box payload digest. The counters
do not individually time those facade operations. Eliminating the entire
measured snapshot stage would remove at most 12.4% of this recorded interval;
that upper bound is not an achieved optimization or a displayed-FPS result.

Further digest reuse cannot key only on material revision: the digest includes
reaction scheduling, whose next-due tick can change independently of that
revision. Any later cache needs an exact schedule or native-tick identity,
full owner incarnation, and tests for motion, mutation and retirement. The
candidate keeps fresh pose, transaction and tick publications. This
finding neither changes the native source nor resolves physical GPU acceptance.

## Remaining physical owner decision

The portable evaluator must first pass exact-source native, Linux, Windows,
graphical and shipped-launcher qualification. The physical owner then needs to
establish displayed smoothness, input responsiveness and visible intermittent
stalls on Windows/NVIDIA, including the tower, bridge, burning timber, mixed
Water/Sand scene and eight-body stress start. Use matching paused/playing and
overview/zoom observations, and record the actual native progression alongside
displayed rate.

Resolution, renderer, driver, body population, chosen scene and source/runtime
manifest belong with the observation. A screen recording and the compact
diagnostic export can connect a visible stall to the recorded receipt and
progression state. Hosted software-renderer success cannot answer physical
driver or monitor questions.

This HOLD does not authorize a merge, Ready promotion, default activation or
production runtime publication. Final platform qualification and physical
owner performance acceptance remain distinct decisions.
