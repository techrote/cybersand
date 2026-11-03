---
title: Linux display setup without mesa-utils
status: Current
document-kind: evidence
scope: Removal of the unused mesa-utils package from GDExtension Linux display setup, its exact-head qualification and same-tree controls
canonical-for: [linux-display-mesa-utils-removal-2026-11-03]
last-reviewed: 2026-11-03
related-documents: [../operations/ci-execution-and-performance.md, 2026-10-31-play-pace004-policy-successor.md, 2026-11-01-ci-workflow-audit.md]
---

# Linux display setup without mesa-utils — 2026-11-03

## Change

[`prepare_linux_display.sh`](../../tools/ci/prepare_linux_display.sh) now checks
`xvfb xauth libgl1-mesa-dri` and no longer checks `mesa-utils`. On the hosted
`ubuntu-24.04` image all three remaining packages are preinstalled, so every
Linux GDExtension shard takes the existing #340 skip path and makes no
package-mirror request. The bounded retry, 30-second timeout and fail-on-error
path is unchanged for any package that is genuinely missing.
[`test_prepare_linux_display.py`](../../tools/ci/test_prepare_linux_display.py)
now asserts the exact queried package set.

This closes the candidate follow-up recorded in the
[PACE004 reconciliation](2026-10-31-play-pace004-policy-successor.md#gdextension-run-41251140343-failure-classification).
Run 41251140343 lost five Linux shards to 15-minute mirror stalls inside the
pre-#340 inline `apt-get update`. Until now, `mesa-utils` kept that network path
active on every shard. Solvers, renderer code, shard counts and watchdogs are
unchanged.

**What was removed:** `mesa-utils`, plus the seven dependencies it pulled in:
`libdecor-0-0 libegl-mesa0 libegl1 libgles2 libxcb-xkb1 libxkbcommon-x11-0
mesa-utils-bin`. The install reported `0 upgraded`, so it never changed the
preinstalled Mesa version. No repository source invokes `glxinfo`, `glxgears`,
`eglinfo` or `es2_info`. Godot `gl_compatibility` with `--display-driver x11`
uses GLX, which the image already provides.

## Evidence

All runs are GitHub-hosted `ubuntu-24.04`, Godot `4.7.stable.official.5b4e0cb0f`,
20 Linux shards at `max-parallel: 8`, watchdog scale 1.

| Run | Source | Display packages | Result |
|---|---|---|---|
| [41726646768](https://github.com/techrote/cybersand/actions/runs/41726646768) (manual, qualification) | `2de26a0b` | without mesa-utils | success, 45 jobs |
| [41726124468](https://github.com/techrote/cybersand/actions/runs/41726124468) (main push, control) | `070c7a22` | with mesa-utils | success |
| [41721541512](https://github.com/techrote/cybersand/actions/runs/41721541512) (PR, control) | `9c90fb5d` | with mesa-utils | success |
| [41533671574](https://github.com/techrote/cybersand/actions/runs/41533671574) (main push, earlier baseline) | `89020b9e` | with mesa-utils | success |

`9c90fb5d` and `070c7a22` have identical trees. `2de26a0b` differs from them only
in the two files above. That gives two same-source controls for the qualification
run.

- **Display step:** in run 41726646768, all 20 Linux shards printed
  `Display packages already installed; no package-mirror request needed.`, finished
  the step in under one second, and fetched nothing from the mirror. In 41533671574
  all 20 shards ran `apt-get update` and install, taking 9–41 seconds.
- **Coverage:** `linux x86_64` (job 126243215987), `windows x86_64` and
  `linux build x86_64` passed. Shard artifacts carry source `2de26a0b`, Godot
  `4.7.stable.official.5b4e0cb0f` and the native/Rapier runtime hashes
  `0f60213c…cf45` and `566e68ae…c66a`.
- **Renderer identity:** each run's artifacts contain 14 rendered-case logs. All
  14 in every run report
  `OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)`.
  No rendered log in any run mentions EGL, GLES, GLX, xkbcommon, libdecor or a
  failed library load.
- **Deterministic pixels:** all 11 deterministic rendered PNGs (ten UI007 overlay
  captures and `material-id-slots-000-131.png`) are byte-identical across
  41721541512, 41726124468 and 41726646768.
- **Run-variable rendered cases:** these assertions all pass (0 failures), but
  their reported values already vary between the mesa-utils controls:
  - The four `test_physical_flight_gameplay_render` PNGs differ even between the
    two same-tree mesa-utils controls. The case samples the asynchronously paced
    native worker tick after 90 Godot physics frames. The qualification run
    recorded `host_tick` 96 and colour buckets 7/10/14/11. Earlier mesa-utils
    runs recorded 94–97 and 6–14 (for example 41322340172: ticks 94/95/96/94,
    buckets 14/11/14/10).
  - `test_deepworks_render`: district A2's scripted-layer count was 9992,
    compared with 9989–9991 across eleven mesa-utils runs. District B2's
    native-air pixel count was 5. Mesa-utils run 41322340172 also recorded 5.
    All 173 checks pass.
  - PALETTE context differences are limited to process ids and object/RID
    identities.

**Conclusion:** the renderer identity is unchanged, the deterministic pixels are
byte-identical, and every rendered and coverage gate passes. The remaining value
differences stay within variance already observed between mesa-utils runs.
The change is qualified.

**Local checks** (WSL Ubuntu 24.04, Python 3.12.3):
`test_prepare_linux_display.py` passes 5 tests; `check_ci_provider_policy.py`
and `check_ci_scheduling_policy.py` pass. `git diff --check` is clean.

## Gaps

- This evidence covers a single qualification attempt. Pixel variance for the
  run-variable cases comes from 4–10 retained runs, not a statistical bound.
- The GitHub job-log API truncated some shard step logs (for example shard 1
  stopped at 22:11:47 while the step ran until 22:12:35). Renderer and pixel
  comparisons therefore use the retained shard artifacts, not job logs.
- PACE004's own graphical workflow checks `libglx-mesa0` separately. It was not
  run here because that workflow is unchanged.
- The merge head adds this documentation on top of `2de26a0b`, with no further
  change to `tools/ci`. Moving the PR to ready-for-review runs the exact-head
  GDExtension gate before merge.
