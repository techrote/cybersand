---
title: INV-004 Windows Rapier calling-thread execution experiment
status: Current
document-kind: audit
scope: PR 449 reproduction and bounded calling-thread CPU versus wall-time discrimination
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../operations/profiling-observability-and-performance.md, ../reference/validation-evidence.md]
---

# INV-004 Windows Rapier calling-thread execution experiment

## Registered scope

Classify long synchronous `space_step()` intervals in the exact #449 acrobat
course: no brush, 60-frame warmup, four four-second original/timed/timed/original
arms, 60 FPS, unchanged gameplay/physics/rendering/dependencies. Require at least
20 aligned long steps. CPU dominated requires 80% of events at least 80% running;
off-CPU dominated requires 80% at least 60% off CPU. Missing alignment, excessive
perturbation, insufficient events or unresolved attribution means inconclusive.

The fallback measures GetThreadTimes kernel plus user execution on the calling
thread, with QPC and existing monotonic wall brackets. It cannot distinguish
blocked from ready-but-descheduled time. Rapier's parallel build can compute on
other threads while its caller waits. Cycle counters are corroborative only.
100 ns counter units do not guarantee 100 ns effective accounting resolution.

## Source custody and dependency preservation

Intake root `C:/khybersand` was on unrelated `mat/material-fidelity-pass-2`, HEAD
`620826f59fbe248f93a45c45e786a7297f2e5288`, with material/native work and generated
UIDs. Those files stay untouched. The historical companion workspace is not this
actual Git root. The only new scoped branch is
`codex/inv154-windows-thread-time-20261105`, based on inspected current main
`06522e300dcf91efbab0ac8f4f4370af72cf2029`, in
`C:/Users/_/.codex/worktrees/rapier-thread-time-20261105/khybersand`. Main differs
from accepted diagnostic baseline `ba9cbc89029be88b812af59b19e5c59829bbcd90`
only by three README lines; production/settings/runtime source is equivalent.

| PR | Exact base | Exact head | Unique experiment |
|---|---|---|---|
| #436 | `ba9cbc89029be88b812af59b19e5c59829bbcd90` | `8c824de5f08611116758e07ce94310a963288c67` | Baseline then brush callback attribution |
| #440 | `8c824de5f08611116758e07ce94310a963288c67` | `d278a40a56be6a402dce3b23e56093d2d6f30b06` | 60/0/0/60 cap and draw clocks |
| #446 | `d278a40a56be6a402dce3b23e56093d2d6f30b06` | `e2b4dd0f97d03af1a3f50ededb246d824350d942` | Five physics wrappers versus residual |
| #449 | `e2b4dd0f97d03af1a3f50ededb246d824350d942` | `2e937ee37532b06d46fa49205ff2e51c1a9baa2e` | Same-cap ABBA stage and step/flush clocks |

All eleven additive stack files (five fixtures, six workflows) are retained
verbatim. Older workflow branch filters and the offline analyzer's historical
run/source/artifact remain frozen. #449 directly uses the shared host and Main;
predecessor ancestry is not a runtime dependency. **#436/#440/#446 can safely be
superseded as active investigations while retaining branches, unique tests,
failures and artifacts.** They are not duplicate tests. No old branch is
rebased, modified, deleted or merged; no PR is closed or promoted.

## Unchanged original reproduction

[Windows run 42115748865](https://github.com/techrote/cybersand/actions/runs/42115748865)
executes exact #449 head/tree `2e937ee37532b06d46fa49205ff2e51c1a9baa2e` /
`4a9aeb666a590fe4fb18850bcd9a8e0f4c260de3`: 965 callbacks, 22 assertions, zero
failures, positive native/Rapier progress, no overflow and joined shutdown.
Windows Server 2022 ANGLE/D3D11 uses Microsoft Basic Render Driver.

| Arm | Callbacks | Callbacks over 40 ms | Step wall time in those callbacks |
|---|---:|---:|---:|
| Original A1 | 242 | 9 | 361.294 ms |
| Timed B1 | 242 | 16 | 638.168 ms |
| Timed B2 | 241 | 24 | 942.982 ms |
| Original A2 | 240 | 9 | 364.940 ms |

The 40 timed long callbacks contain 1,581.150 ms of step time in 1,584.684 ms
Rapier wrapper time. This reproduces the tail before CPU probes. Original native
pool-worker participation was not separately sampled.
[Raw artifact 13456501103](https://github.com/techrote/cybersand/actions/runs/42115748865/artifacts/13456501103)
is 95,790 bytes, ZIP SHA-256
`248c7aa33719955d85b732d50d6ed6badc9014ffe893c15bcd7ada8b0dcc3f68`.

The unchanged original also passes locally on Windows 11 Pro 26300, Ryzen 5600X
(6 cores/12 logical CPUs), TITAN RTX 32.0.15.8180, Godot 4.7 ANGLE/D3D11. Import
and runtime exit zero, 22 assertions pass and the worker joins. No step exceeds
40 ms in 960 callbacks. This different-host single run is inconclusive and does
not isolate GPU effects. An unrelated existing Godot process remains untouched.

Both use native source/build `acce570e667c7e2cc3ef83ab451e7dff262006a9`, native
SHA-256 `cb675a4cde4317608bb892437af9b9f2b7cddf6a7289a6a028500efab19aae9d`
and Rapier `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
Main blob is `791ef440efd6edb206c6f1be33989cb62e9213b2`; bridge blob is
`87eea1f36b11375eb40be6a833433871000fbb2e`.
