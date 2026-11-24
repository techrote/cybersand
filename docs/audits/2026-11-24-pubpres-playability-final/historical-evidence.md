# Historical progression evidence recovered on 24 November 2026

**Disposition: retain Full publication, early physics, and Draft/HOLD. None of
the historical experiments establishes complete Workbench playability.** This
review re-downloaded original artifacts, verified ZIP bytes, SHA-256 and CRC,
and independently reduced the actual `rapier_step` event stream. It did not
repeat those expensive graphical experiments. Exact receipt paths, receipt and
trace hashes, source/native/engine/Rapier identities, fixtures, adapters, and all
26 independently reduced measurements are in
[`historical-comparisons.json`](historical-comparisons.json).

## Custody and what was actually qualified

The [22-job campaign 45078090513](https://github.com/techrote/cybersand/actions/runs/45078090513)
completed successfully at frozen candidate
`c90dbc46e1f57f28e06b1f4205b83467335ff657` (tree
`bf742007f0640bf13c8b21cab5823b4a5a8c208d`). Its historical accepted-main
control was `00cdb02f103265b6dc5224c68283e9a0c8cb449f` (tree
`06b62d73138028d1f7615b83edc9810491bf6287`). All 22 artifacts were available and
nonexpired at retrieval, totaling 675,200,474 API-reported bytes, with retention
through 20 February 2027. Successful collection includes retained failures and
negative controls; it does not mean 22 gameplay acceptance gates passed.

The active Windows runtime identities in the re-read receipts are:

| Component | SHA-256 |
| --- | --- |
| Official Godot 4.7 executable | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| Frozen C native DLL | `250fe0d1da6df0857e6e1e135f183038a37eccfc5c9aba88551f68f78da58b28` |
| Historical M native DLL | `210b23ace8728427f8416c2f6ec119054f87f635b9bf6d169b447e31e8c13b39` |
| Rapier Windows DLL | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

The operating renderer was Safe/ANGLE on **Microsoft Basic Render Driver**,
with AMD EPYC host CPUs. These artifacts provide no physical NVIDIA driver
acceptance. Linux-named libraries inside the Windows staged project are small
LFS pointer files, so their recorded hashes must not be presented as working
Linux runtimes.

Original download custody is retained here:

| Artifact and role | ZIP bytes | SHA-256 |
| --- | ---: | --- |
| [14779020615: historical M/C/C/M controls](https://github.com/techrote/cybersand/actions/runs/45078090513/artifacts/14779020615) | 45,566,707 | `6ef9b2f903253cdcb5ce418ae7b56cff237a27e961c7d6ed05b98bfefb228194` |
| [14778950415: large-canvas arms and sustained control](https://github.com/techrote/cybersand/actions/runs/45078090513/artifacts/14778950415) | 49,419,962 | `e4d0c605e29ea4c0e8d14cd90bd1b974881800034c5ba183504d1269e43cb4bd` |
| [14787448688: corrected physics-publication ABBA](https://github.com/techrote/cybersand/actions/runs/45105890195/artifacts/14787448688) | 24,589,929 | `a5494806d0e0590b6778fb2d64f6aee495a2acb94949e30c3c7769cdb90af459` |
| [14776386674: independently built Linux native controls](https://github.com/techrote/cybersand/actions/runs/45078090513/artifacts/14776386674) | 8,217,670 | `3ac208f97a7a7ec4c48f1f2396dee8a7601a91ccb96989a1577b1823a2a644f6` |

The recovered Linux C native library is 5,257,896 bytes with SHA-256
`bc5cdbf4832d09f8b14f6ff2ed7cf1e182343d55a3a4ebc4dc1d93894d660d59`;
M is 5,253,776 bytes with SHA-256
`a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`.
Their receipts bind GCC 13.3 and godot-cpp commit
`101ae38034304346a46ea9ea84ae156d3e860496`. They can accelerate correctness
reproduction, but cannot be matched against a newly compiled GCC 14 candidate
as a clean source-only performance comparison. The dependency archive itself
is not included in this artifact.

## Real progress improved at 2048, regressed at 512, and retained severe stalls

Every row below uses the **first 144 real completed Rapier steps** and 143
inter-completion intervals. Rates use elapsed capture-start-to-step-144 time,
not engine callback counts. Quantiles use the existing linear-interpolation
distribution definition. All times are milliseconds. M/C/C/M order is retained.

| Workload / arm | Real steps/s | p50 gap | p95 gap | p99 gap | Maximum gap |
| --- | ---: | ---: | ---: | ---: | ---: |
| Wave512 Follow M0 | 13.240 | 6.648 | 241.291 | 248.988 | 252.677 |
| Wave512 Follow C1 | 12.179 | 7.625 | 252.329 | 264.582 | 267.532 |
| Wave512 Follow C2 | 11.470 | 7.605 | 255.448 | 390.481 | 499.165 |
| Wave512 Follow M3 | 12.696 | 7.181 | 248.097 | 254.392 | 262.031 |
| Current Wave2048 Follow M0 | 2.781 | 342.116 | 770.530 | 849.785 | 882.631 |
| Current Wave2048 Follow C1 | 3.590 | 278.342 | 505.183 | 816.262 | 861.466 |
| Current Wave2048 Follow C2 | 3.638 | 278.967 | 378.078 | 726.025 | 904.565 |
| Current Wave2048 Follow M3 | 2.771 | 344.141 | 749.548 | 840.785 | 875.807 |

The large workload's roughly 29–31% rate improvement is supported by real
completed steps. The small reference regresses, and the large-workload maximum
does not improve consistently. Median native elapsed tick duration fell from
136.113/152.149 ms in M to 106.997/116.384 ms in C at 2048, so native work is
material at that size. Native elapsed time includes scheduling/preemption;
this observation alone does not identify which algorithm caused the change.
The complete matched receipts are in artifact 14779020615.

The retained 60-second Full control reached 220 real completions in 60.179 s,
with p95/p99/maximum gaps 729.200/767.204/797.701 ms and 18 gaps over 500 ms.
Those are **whole-capture** figures reported in the original retained evidence.
The independent JSON also preserves its distinct first-144 window, whose p95
is 712.325 ms. Mixing those windows would misstate the comparison.

## The corrected Early/Combined experiment is a verified negative

[Run 45105890195](https://github.com/techrote/cybersand/actions/runs/45105890195)
used evidence-only workflow head `53ad974603f4ae89e9a1c1bd19e9e2fcefbed83e`
but the unchanged c90 application/native runtime. It remains **failed**: the
unmodified V3 reducer required a positive early handoff timestamp, whereas
Combined legitimately has both copied/source early-mailbox clocks equal to
zero. This failure is retained rather than retrospectively relabelled green.

| Wave512 Full / physics arm | Real steps/s | p50 gap | p95 gap | p99 gap | Maximum gap |
| --- | ---: | ---: | ---: | ---: | ---: |
| Early 0 | 11.433 | 8.812 | 274.724 | 291.313 | 424.824 |
| Combined 1 | 11.149 | 8.842 | 277.625 | 282.672 | 537.394 |
| Combined 2 | 10.694 | 8.916 | 277.178 | 284.135 | 285.732 |
| Early 3 | 10.875 | 8.900 | 279.223 | 282.925 | 288.365 |

The [detached bda07360 audit](https://github.com/techrote/cybersand/blob/bda07360cc0873d2ec182caa23c61a3ab9167c5e/docs/evidence/PUBPRES757-Wave512-physics-ABBA-20261123.md)
documents replay of the byte-exact frozen reducer with one explicit
Combined-only zero-handoff exception, all other semantic gates retained,
four admitted arms, and rejection of ten semantically tampered copies. This
mission independently recovered the original artifact and reproduced the raw
timing results above; it does not claim to have rerun those ten prior fault
tests or the optional on-disk project/engine checks. One auxiliary preflight
file contains a literal trailing `\\n`, so its JSON validity is not claimed.

The median native ticks in those four arms were only
3.286/3.259/3.279/3.346 ms; native-completed-to-Rapier p95 remained
269.512/271.886/271.364/272.773 ms. Rapier solver p95 was
0.976/0.377/0.473/0.406 ms, although rare solver elapsed-time outliers also
exist. Most reference tail delay therefore survives after native completion,
in Main/render/engine delivery and scheduling; changing physics publication
alone did not resolve it. This is a causal boundary, not a claim that a
particular driver operation has been isolated.

## Negative controls and misleading metrics remain in the decision

The large-canvas Full/Target/Target/Full rates were
3.571/3.472/3.768/3.609; maximum physical gaps were
828.323/883.496/862.501/812.791 ms. The Target submit-call improvement did not
establish repeatable physical progression improvement. The D/C/C/D predecessor
comparison yielded 3.594/3.864/3.553/3.640 steps/s, also failing the registered
all-candidate-better rule. Continuation on/off rates were mixed and supplied
zero additional authentic completions. All arms remain in the JSON decision
packet; none is discarded in favor of a favorable individual run.

Application command admission needs care too: in corrected Early arm 0, using
only the most recently repeated consumed command gives p95 1.632 ms, whereas
the first admitted command for that same physical tick waited p95 271.122 ms.
The successor supplemental reducer records both and calls neither a measured
device/input-delivery latency. High callback FPS, a short upload submission,
or a fresh repeated command sequence does not establish a progressing actor.

Frame-post-draw is a CPU notification, not GPU completion or physical scanout.
On Separate, Godot defers that notification back to Main; Main's live render
serial then cannot prove which material/pose the completed draw used. The new
renderer experiment must preserve that unavailable measurement explicitly.
Windows Separate's historical GLAD initialization crash is a real failure;
the recovered #609 EGL-handoff engine is a distinct, explicitly identified
engine treatment, and a startup repair is not a performance result.

The successor experiments are therefore narrow: native occupied-mask bounds
with exact checkpoint parity, same-source Full two/three-slot publication,
and a separate engine-isolated Safe/Separate arm. They retain 512 and current
2048 Follow controls, actual physical-step witnesses, original semantic gates,
ordinary Workbench coverage and physical NVIDIA acceptance as distinct gates.
No historical negative result authorizes a default change.
