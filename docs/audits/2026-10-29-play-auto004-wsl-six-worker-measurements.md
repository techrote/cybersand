---
title: PLAY-AUTO-004 supplementary WSL six-worker measurements
status: Current
document-kind: evidence
scope: Source-bound Ubuntu24.04 WSL2 native reference measurements with six task-claiming workers; not ordinary Linux desktop, concurrency or release qualification
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [../architecture/simulation-tick-and-threading.md, 2026-10-27-play-auto002-worker-matrix-candidate.md, ../systems/player-control-playground.md, ../operations/local-build-and-validation.md]
---

# Supplementary WSL six-worker reference campaign — 2026-10-29

## Executed source, apparatus and platform

The unmodified persistent campaign runs on accepted main
**`91778603db950a817b82fc6a4f75efee201f5044`**, tree
`3e513ab8b38a5d1d8076b5a4156d234f8d8a068f`, in isolated source
`/home/i/cybersand-play-auto004`. It preserves all80 native and14 scoped
apparatus inputs; those also match the prior Windows six-worker sourcef667.
The source/reference result is not transferred to this later evidence commit.
No implementation, default, solver, dependency pin or CI policy is changed.

The local platform is **Ubuntu24.04 under WSL2 on Windows**, Linux kernel
`6.18.54.1-microsoft-standard-WSL2`, with12 exposed logical processors on the
AMD Ryzen5 5600X host (six physical cores/twelve logical processors). This is
supplementary Linux execution under a hypervisor, separately qualified from
GitHub-hosted Linux and ordinary Linux desktop. It supplies no cross-platform
or controlled hypervisor-performance comparison with the earlier Windows data.

Pinned Godot `4.7.stable.official.5b4e0cb0f` uses official Linux archive
75,664,355bytes, SHA-256
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`;
binary SHA-256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
Retained native runtime SHA-256
`496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6`
(4,222,304bytes), source/buildd7e35aa3, and Rapier
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`
(117,275,416bytes) match exact LFS pointer payloads and provenance. No fresh
native build is asserted. Necessary Ubuntu `git-lfs`3.4.1-1ubuntu0.4 was
installed; its filters are configured in the isolated clone. Windows Git/source
state and the unrelated dirty primary checkout are untouched.

## Method and retained execution

```text
python3 tools/play/run_auto_campaign.py --godot /home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64 --output /home/i/cybersand-play-auto004-evidence/campaign-01 --warmup 60 --ticks 120 --repetitions 5
```

The exact command in the raw report is authoritative. Five cyclically balanced
repeats request1/2/4/6/Auto at480 and960 cells per side. Every row starts a fresh
Godot process/World, uses60 warm-up ticks and120 measured ticks, and retains its
180s process bound. There are50 measurement processes,3,000 warm-up and6,000
measured ticks. Import keeps240s; no failed row is retried, skipped or discarded.

The campaign runs UTC00:59:21.859841–01:03:29.721825. Its import takes2.862s;
the separate initial strict preflight import takes5.032s. The unmodified
`verify_directory` validates all51 campaign log hashes, raw markers, summary
reductions and per-size level hashes. Separately, campaign preflight/final
source checks and direct evidence-collector readback verify the94 input hashes
and runtime payload bytes. There are zero errors, skips, timeouts, retries or
source/runtime drift.

Launcher affinity is logical CPUs0–11, nice0; sampled initial load averages
0.0757/0.1377/0.0679. Child affinity/priority and CPU frequency/residency are
unmeasured. External Windows/WSL load and hypervisor scheduling are uncontrolled.
This is repeatable fixed-workload reference evidence with transparent observed
conditions, not an isolated hardware speed comparison or a statistical population
claim. No outlier is removed.

## Capacity, task participation and timings

Configured capacities are1/2/4/6/6. All20 explicit-six/Auto rows reach **six
actual task-claiming workers**;40 rows observe multiple participants. Across the
2,400 measured explicit-six/Auto ticks,2,399 report six and one reports five.
Thus the data does not claim six participants in every tick. Created-worker
census, overlapping execution, CPU utilization and OS thread joins are not
measured. The existing counter reports the maximum distinct task-claiming workers
within a completed tick, and the serial route reports one.

Each table row pools600 measured tick samples across five fresh-process repeats.
The ratio is the mean of five paired per-repeat serial/native mean ratios,
not the ratio of the pooled means. Native timings exclude copied statistics,
export and hashing; harness frame intervals/completedHz are not gameplay FPS.

| Side | Request | Native mean ms | p95 ms | p99 ms | Mean paired serial ratio |
|---|---|---|---|---|---|
| 480 | 1 | 27.178762 | 33.010010 | 35.581258 | 1.000000 |
| 480 | 2 | 15.898585 | 19.878734 | 22.618735 | 1.711836 |
| 480 | 4 | 9.085402 | 11.863129 | 16.764903 | 2.993476 |
| 480 | 6 | 7.710409 | 10.156877 | 11.436822 | 3.528646 |
| 480 | Auto | 7.734618 | 10.574397 | 14.343078 | 3.536133 |
| 960 | 1 | 95.953049 | 107.253891 | 110.350260 | 1.000000 |
| 960 | 2 | 50.124110 | 58.622994 | 65.023883 | 1.915089 |
| 960 | 4 | 26.997962 | 31.528379 | 34.422233 | 3.557415 |
| 960 | 6 | 21.231298 | 26.318704 | 29.692838 | 4.523792 |
| 960 | Auto | 21.814998 | 26.617066 | 30.120395 | 4.405733 |

All multiworker row means are lower than their same-repeat serial controls here.
Counterexamples remain: Auto is slower than equal-capacity explicit-six at480
repeats1/2 and960 repeats1/2/4; pooled960 explicit-six maximum38.518063ms exceeds
explicit-four38.252794ms. Lower means do not imply universally better tails or
that Auto is always the fastest request.

Per-size terminal level hashes match every request/repeat and the prior Windows
six-worker data:480=`a649a5ee5282ab93658ecf0456eee4e2a8293a376c73df85b1c30f4c8a68b2c6`,
960=`5fa8a0f5bf67e8abcd83d470b2a624c188515973335e271369b6773a439beff3`.
These are exact terminal level comparisons, not complete gameplay replay.

## Durable identity and remaining gates

[Raw WSL report](play-auto004-2026-10-29/linux-wsl6-campaign.json):658,840bytes,
SHA-256 **`d3e806b3c230ee7d306f784e5b92be1c6e16743e8884f9430efbe093d805c1dc`**.
An exact-path `-text` attribute preserves its original bytes on every checkout.
All76 campaign/preflight/condition/collector files have a hash-verified backup at
`C:/Users/_/.codex/artifacts/play-auto004-wsl-six-2026-10-29`; local readback
SHA-256 `c16fac508c990c4a260ea9308d033ad50e2244f9ffce30d771b4f9bc1d38d59d`.
An initial pointer-only materialization was refused before import; exact shared
LFS objects then supplied the verified payloads. That preflight record is retained.

Prior Windows six-worker evidence at
[43ebaf9e](https://github.com/techrote/cybersand/commit/43ebaf9e8f60ee7bd45360ec8dab28502348c793)
remains byte-identical, SHA-256
`846235bb1c50a1808fd2ccc71f8a621fe79ffef9620a40257dd361d8285b43d8`,
with its original source, counterexamples and51 logs. Neither report overwrites
the accepted four-worker hosted campaign or the other six-worker platform.

This evidence-only branch is not a runtime publication or merged product
qualification. Local Docs/repository/M11 checks, frozen32 retrieval (32/32 at5)
and all20 existing campaign verifier tests pass. Final independent data readback
is separately required; the #266 checkpoint records its actual outcome and
evidence commit. No hosted
CI result for this new report commit is asserted by its measured source917.
#266/#268/#269/#270 remain open for representative gameplay scheduling, main
wait/frame/snapshot timing, lifecycle/failure/device integration and human feel.
Native default/solver family/receipt/refusal semantics remain unchanged; #265
stays closed Not Planned and #271 stays deferred.
