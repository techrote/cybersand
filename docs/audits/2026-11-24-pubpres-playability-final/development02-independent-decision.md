# Development 02 independent physical-progression decision

**Draft / HOLD.** The occupied-mask native repair supports a relative gain in
the Linux current Wave2048 cohort. The Wave512 source comparison and both
three-image publication comparisons do not establish a repeatable gain. The
large-workload physical intervals remain plainly material to ordinary play:
all 143 measured inter-step intervals in every Linux Wave2048 arm exceeded
100 ms. These observations do not establish acceptable user-perceived play or
physical NVIDIA behavior.

## Exact source, runtime and retained evidence

The original [run 45436083078](https://github.com/techrote/cybersand/actions/runs/45436083078)
tested candidate `515fce2862dd87d8dd01935bdf7bd1736e645901` against frozen
`c90dbc46e1f57f28e06b1f4205b83467335ff657`. Candidate application/native bytes
were unchanged from the first `b21dca8f` development capture; the checkpoint
changed qualification/evaluator apparatus. The Linux graphical job's original
result remains **FAILURE**, retained without rewriting. All twelve independent
graphical correctness outcomes passed. The later failure was in the added
allocation checker, which assumed every captured fixture exposed an `extent`
field. The generated `reference2048` fixture instead retained its original
recipe, generated-image and setup hashes.

The repair supplies expected dimensions from the original campaign's registered
fixture. If an observed extent exists, it must agree. The checker does not infer
dimensions from the texture's own claimed allocation. Its tests reject absent
dimensions on both sides, invalid dimensions, observed/registered disagreement
and false byte counts. The original game captures needed no rerun.

| Evidence | Exact identity |
| --- | --- |
| [Linux graphical artifact 14943496499](https://github.com/techrote/cybersand/actions/runs/45436083078/artifacts/14943496499) | 40,055,365 bytes; SHA-256 `afd69e365ee244fbc5d31dada33c3f3a0d85e30d6cc88cceb453db94880e3361` |
| Linux official Godot 4.7 | SHA-256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Linux candidate native runtime | SHA-256 `aeb83dc3795b8010437e8bbba037053aff6cf5b5c928d60e0eeedef6b6eb6bd1` |
| Linux frozen native runtime | SHA-256 `bc5cdbf4832d09f8b14f6ff2ed7cf1e182343d55a3a4ebc4dc1d93894d660d59` |
| Linux execution | Intel Xeon 6975P-C; llvmpipe LLVM 20.1.2, 256 bits; OpenGL Compatibility; actual Safe owner |
| [Windows renderer artifact 14941889432](https://github.com/techrote/cybersand/actions/runs/45436083078/artifacts/14941889432) | 12,606,621 bytes; SHA-256 `b785312517b14eeb92890e13f3b63eab0eda48df2c1d7eee75e9d63f93f1839c` |

The independent stdlib reader recomputed all sixteen Linux traces from their
original bytes and verified each receipt/trace identity, actual consecutive
Rapier/manual/native step, accepted body sample, terrain revision, callback
credit, input ownership and fixed delta. A second replay ran the entire frozen
V3 reducer and the repaired extent/slot checker. It reconstructed the 27
declared application resources from exact Git objects and retained binaries;
the unchanged strict native verifier checked each independently built runtime's
105 source inputs, build log, compiler and pinned dependency custody in an
isolated temporary native checkout. Both replays passed all sixteen captures.
All equal-step trajectories and admitted actions matched across each cohort.

The [compact machine-readable packet](development02-independent-packet.json)
retains every source, runtime, receipt and trace digest, every arm's independent
timings and physical witnesses, original failed-summary digests, all comparison
directions and negative controls. The read-only reproducer is
[`replay_extent_check.py`](../../../tools/pubpres_final/replay_extent_check.py).
It does not add a new observer claim to historical evidence.

## Linux source comparison

Every value below comes from the first 144 real completed steps. Percentiles
use the existing linear interpolation on the 143 observed inter-step gaps.
Rates include the original observation-window start edge. D/C/C/D is the
registered order; no arm was dropped or chosen as the representative run.

| Workload / arm | Real steps/s | p50 gap ms | p95 gap ms | p99 gap ms | Max gap ms | Gaps >250 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Wave512 D0 | 11.928 | 83.293 | 87.959 | 90.293 | 91.161 | 0 |
| Wave512 C1 | 11.874 | 84.701 | 87.592 | 89.477 | 90.312 | 0 |
| Wave512 C2 | 11.760 | 84.794 | 87.267 | 89.875 | 90.196 | 0 |
| Wave512 D3 | 11.535 | 87.096 | 89.997 | 91.185 | 92.717 | 0 |
| Current Wave2048 D0 | 4.911 | 258.415 | 266.981 | 269.837 | 271.157 | 88 |
| Current Wave2048 C1 | 6.394 | 151.864 | 237.089 | 239.576 | 244.052 | 0 |
| Current Wave2048 C2 | 6.360 | 151.549 | 233.595 | 240.726 | 270.694 | 1 |
| Current Wave2048 D3 | 5.028 | 252.729 | 262.320 | 265.694 | 274.234 | 84 |

Both large-workload candidate rates exceed both controls, both p95/p99 values
are lower, and candidate maxima and all registered severe-gap counts stay
within the worse control. This satisfies the unchanged relative direction rule
for this cohort. Cross-arm rate ratios span approximately 26.5–30.2% improvement;
that range is descriptive and is not a population confidence interval.

The Wave512 candidate tails are modestly lower, but the rates overlap the
control runs. The required joint direction is therefore **NOT_ESTABLISHED**.
Even a large-workload win does not resolve this small-workload limitation.
Native computation and command-to-physical observations remain separately
reported in the packet; the latest repeated command can arrive shortly before
a step after an earlier input has already waited through most of a gap.

## Linux three-image publication comparison

The same candidate was used in all four arms, in two / three / three / two
image order. Full publication, Early physics, coherent presentation and actual
Safe ownership stayed fixed. The repaired allocation gate also retained exact
three-identity ownership and fixed logical GPU byte accounting.

| Workload / slots and index | Real steps/s | p50 gap ms | p95 gap ms | p99 gap ms | Max gap ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Wave512 2/0 | 11.761 | 84.676 | 88.387 | 91.773 | 92.495 |
| Wave512 3/1 | 11.793 | 85.230 | 87.400 | 88.483 | 91.177 |
| Wave512 3/2 | 11.705 | 85.954 | 88.807 | 90.732 | 91.515 |
| Wave512 2/3 | 11.702 | 85.632 | 88.589 | 90.581 | 91.177 |
| Current Wave2048 2/0 | 6.344 | 151.519 | 235.237 | 239.985 | 241.854 |
| Current Wave2048 3/1 | 6.606 | 151.133 | 233.976 | 237.508 | 242.809 |
| Current Wave2048 3/2 | 6.263 | 149.059 | 234.529 | 238.201 | 239.566 |
| Current Wave2048 2/3 | 6.559 | 149.278 | 233.388 | 235.619 | 238.201 |

Neither workload establishes the preregistered direction. The large three-image
arms include both the fastest and slowest physical rate, and the first has a
larger maximum gap than either two-image control. The ring remains an explicit
diagnostic option with an extra 8 MiB of logical RG8 allocation at 2048²; these
results do not justify changing the ordinary default.

## Windows renderer controls and unresolved acceptance

All eight retained Safe captures in the engine-isolation job independently
passed the raw physical witness reader. The four patched Separate ordinary
captures aborted with `CowData<unsigned char>::get` indexing an empty buffer
after ANGLE and Rapier initialized. The simple independent two-image Separate
history oracle passed. No Separate gameplay receipt or throughput estimate
exists, and startup success in the smaller oracle cannot qualify Workbench.

| Workload / engine at Safe | Real steps/s | p95 gap ms | p99 gap ms | Max gap ms |
| --- | ---: | ---: | ---: | ---: |
| Wave512 official 0 | 18.180 | 156.990 | 160.896 | 169.883 |
| Wave512 original EGL patch 1 | 18.314 | 162.190 | 164.307 | 470.662 |
| Wave512 original EGL patch 4 | 17.555 | 168.561 | 172.304 | 330.453 |
| Wave512 official 5 | 17.939 | 164.746 | 168.467 | 176.949 |
| Current Wave2048 official 0 | 5.304 | 345.983 | 471.571 | 526.025 |
| Current Wave2048 original EGL patch 1 | 6.354 | 227.018 | 517.938 | 522.815 |
| Current Wave2048 original EGL patch 4 | 5.801 | 253.485 | 432.406 | 434.071 |
| Current Wave2048 official 5 | 5.254 | 255.549 | 553.932 | 558.154 |

The Safe subset does not meet the strict direction rule either: Wave512 rates
overlap and patched tails regress; the large workload has adverse p99 and
>250 ms controls despite higher rates. The complete renderer cohort remains
invalid because all Separate ordinary arms failed. The host reported AMD EPYC
9V45 and Microsoft Basic Render Driver through ANGLE; this supplies no evidence
about a physical NVIDIA driver.

The [original renderer-probe run 44962312107](https://github.com/techrote/cybersand/actions/runs/44962312107)
was recovered to avoid repeating answered controls. Its Windows artifact
14730266729 (943,137 bytes, SHA-256
`dd6aafaff49907c344c8656b32a5c5bceed7ca76c8e4f8a449b939f676304e3a`)
independently verified all 82 listed raw-file hashes and ten original source
inputs. Safe empty and two/three-image material cases passed; all three stock
Separate cases failed GLAD before producing a script receipt. The new patched
ordinary crash is a later, distinct failure boundary. Its repair requires its
own exact engine identity and fresh qualification while retaining this failed
engine as a control.

These captures predate the new submitted-pose and whole-process CPU sidecars.
Those observations remain unavailable here. Calibration, sustained mixed
eight-actor authoring, final extracted evaluator qualification and physical
Windows/NVIDIA owner acceptance remain separate gates.
