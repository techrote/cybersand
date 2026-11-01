---
title: Current-main chunk-run render-copy reconciliation
status: Current
document-kind: audit
scope: Frozen current-main R source selection, native differential proof, runtime provenance and graphical Control versus R qualification
canonical-for: [render-copy-production-reconciliation-evidence]
last-reviewed: 2026-11-01
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../operations/profiling-observability-and-performance.md, ../reference/validation-evidence.md]
---

# Current-main chunk-run render-copy reconciliation

## Frozen source and authority

This implementation starts from main
`25ce0731d89b9540c2d95cfa8bae321c37e6e118`, tree
`26bac27fb535f15e594dc62df8eac183d7b75fea`, on the fresh branch
`codex/render-copy-production-20261101`. Main had not advanced beyond the
accepted #340 scheduling rehabilitation when fetched. No subsequent rebase is
part of the experiment. The final PR remains draft and must not merge without
explicit owner mergedown approval.

| Authority | Source identity | Use in this reconciliation |
|---|---|---|
| [#290](https://github.com/techrote/cybersand/pull/290) | Corrected executable `60915dc86631271ea8661377a3458149adda9361`; World blob `a6afd8cad4264ac2eca0362d14711158e3606760` | Production function, including last-included-coordinate overflow preflight |
| [#301](https://github.com/techrote/cybersand/pull/301) | Publication stack `b5e415784d5e0884684869dd622883dacf3c9de5` | Historical runtime/source provenance; no binaries silently reused |
| [#333](https://github.com/techrote/cybersand/pull/333) | Older reconciliation `21d44e43e071d2d5777c2ed46a92f59675639599` | Superseded integration evidence; original draft preserved |
| [#335](https://github.com/techrote/cybersand/pull/335) | Investigation `902fc5b518855911c1b6761a7165573843e567ed` | Test-only differential coverage and real-consumer tracing; not production R authority |

The current-main World blob is
`6987e9d05564cb11294d7704514df2f811a26c48`. Its entire difference from the
corrected #290/#301/#333 World is the intended `copy_render_cells` function:
35 added lines and 9 removed. The header and all other World operations remain
unchanged. All 80 native inputs in #301's historical manifest match the ported
native source; nevertheless this task rebuilds and republishes both libraries
through a newly scoped current-source publisher, retaining current build and
host-execution identities.

## Production contract

Each row is split into contiguous runs ending at a chunk boundary. One address
calculation and one chunk lookup serve each run. The unchanged material and
state accessors feed the unchanged `project_visual_state`; missing chunks
produce Empty with zero stored state. Existing layout/stride validation remains
first. Zero extents return before dimension subtraction, and the inclusive
last-coordinate check accepts `INT64_MAX` while refusing unrepresentable
regions before writing. The counted-column loop never forms an overflowing
exclusive endpoint.

World remains sparse and signed: this change introduces no world clipping,
dirty-state modification, simulation change, publication policy or ACK change.
The literal reference exists only in tests/benchmarks. Ordinary runtime has no
Control/R selector and no second permanent production implementation.

## New native qualification

The registered native case passes **153,284 assertions, 231 region comparisons,
8,338,180 compared payload bytes, 42 nonmutation receipts and 18 invalid-call
refusals, with zero failures**. These are whole-buffer comparisons plus fixture
and state assertions; the assertion denominator is not comparable with #335's
per-cell assertion count. Dense/sparse 1024-square copies, signed and partial
rectangles, chunk seams, absent chunks, practical material/state lanes,
exhaustive configured Water mass/coherence values, deterministic random Worlds,
padding guards and inclusive integer endpoints are covered. Separate receipts
check each path's persistent bytes, quantities, temperatures, hashes, revision,
resident storage and dirty state. Four subsequent ticks agree with an untouched
World.

[Publication run 41301725876](https://github.com/techrote/cybersand/actions/runs/41301725876)
passes the same counts in ordinary and ASan/UBSan execution **with leak detection
enabled** at source `a7ee10f251f647a16dec8a1d7f18c4f299100cba`, tree
`aed6d7acfca8778af691955142c677bdfc2ed781`. Artifact
`render-copy-native-41301725876-1` retains original logs, receipts and binaries.
Both log hashes are
`934fee88da9d0c0f72bf18ddafce8fa7d0ce7112d948fd6c01200015c967acd0`.
The earlier local LeakSanitizer failure caused by the executor's ptrace
restriction remains retained; its leak-disabled rerun is not substituted for
the successful hosted leak-enabled gate.

World and `RenderSnapshotExchange` preserve signed regions without clipping.
The desktop adapter explicitly selects the 1024-square full window; Main
rejects out-of-image patches. The existing handoff case now additionally
accepts the final RG8 pixel and rejects negative origins/right/bottom crossings
without changing any destination byte. This adds 14 assertions in the existing
case, not another shard. Local execution with the newly published Linux runtime
passes; final-head GDExtension execution qualifies the committed addition.

## Native production performance

Three fresh processes per implementation, 101 measured calls per scenario after
three warmups, use separately compiled frozen-main and R production functions.
The getter oracle is excluded from the claimed production speedup. All 54
scenario records and 5,454 measured equality pairs pass. Percentiles below use
303 pooled production calls per implementation/scenario; these are not 303
independent process replications. Units are milliseconds.

| World/region | Control p50 / p95 / max | R p50 / p95 / max | p50 ratio |
|---|---:|---:|---:|
| Dense 1024×1024 | 30.945 / 35.555 / 51.312 | 1.516 / 1.979 / 5.420 | 20.41× |
| Sparse 1024×1024 | 21.214 / 23.931 / 29.293 | 0.275 / 0.405 / 0.939 | 77.02× |
| Absent 1024×1024 | 8.558 / 9.544 / 12.771 | 0.068 / 0.114 / 0.299 | 126.54× |
| Dense 384×256 | 3.136 / 3.452 / 4.067 | 0.121 / 0.185 / 1.150 | 25.98× |
| Sparse 384×256 | 2.029 / 2.362 / 3.450 | 0.026 / 0.041 / 0.153 | 77.46× |
| Dense 32×24 | 0.01893 / 0.01981 / 0.08184 | 0.00161 / 0.00174 / 0.12996 | 11.73× |

All nine measured scenarios improve at p50/p95/p99. The one worse observed
maximum is the tiny dense rectangle above; no systematic regression follows
from that isolated outlier. Dense full-frame process medians are
31.286/31.409/30.268 ms for Control and 1.511/1.452/1.625 ms for R.
Full-frame address and chunk-resolution invocations each fall from 3,145,728 to
8,192, with 8,192 contiguous runs: a **source-derived 384× reduction**, not a
hardware-counter measurement. Small/large/signed-offset rectangles require
48/1,024/576 R runs respectively.

Both benchmarks use GCC 13.3.0 (`13.3.0-6ubuntu2~24.04`), C++20, `-O3 -DNDEBUG`,
without LTO. The original source and oracle are committed at `dfa81dff`; only
Control's native source comes from frozen main. Subsequent logged rebuilds
reproduce both measured executables byte-for-byte: Control
`f420dacb4e8051cb59c4bd3c0d1f2febb4fb97c20264c965fd68487d8525fff3`,
R `b1275056e4d1a640081e55d83636d29d07f6c51da028c7cf21b51405ad209f2f`.
Raw samples, commands, process ordering and independent calculations are in the
retained local qualification bundle. Historical #335 Linux dense
23.30→0.98 ms and Windows 14.09→1.05 ms are separate experiments; the absolute
values differ with fixture/toolchain/host conditions and their exact
contributions have not been isolated.

## Real Main Control versus R

The primary local campaign has **20/20 successful fresh processes**: five per
implementation/ACK cohort, 240 graphical frame intervals each. It uses Godot
`4.7.stable.official.5b4e0cb0f`, real Main, Linux X11/llvmpipe compatibility
rendering, ordinary worker pacing, 120 accepted paused Sand/Water commands and
one ordinary reset at frame 120. All 60 post-reset cells, final native/CPU/texture
byte equality, complete event populations, runtime restoration and a rendered
PNG witness pass. One retained trace per cohort passes 32/31/31/31 adverse
readback controls. A separate reviewer recomputed all raw timing quantiles and
causal counts without importing the primary reducer.

The host/apparatus is frozen at `a7ee10f`; the locally built R library truthfully
names `dfa81dff`/tree `b81d7b0245898f7579d8e261822f14459df4dcfc`.
Its 80 native inputs equal the frozen candidate. Local Control uses the exact
base commit/tree. Their hashes are respectively
`ab912774e019574989f9560bcdbf82702b15cf33709dfd8896e83eb6ee5bc564` and
`1fbc3a4658471bcbb77ca970f45113d570fd17d2df8c58da39a006fb87c8d86b`.
Both use identical recorded compiler/linker/SCons/godot-cpp archive and build
scripts. These local binaries are not mislabeled as the later hosted artifacts.

| Cohort | Refreshes | Dirty onto full | Forced retries | Full publications | ACK clears | Maximum consecutive retries |
|---|---:|---:|---:|---:|---:|---:|
| Control N | 605 | 2 | 2 | 12 | 603 | 1 |
| R N | 605 | 0 | 0 | 10 | 605 | 0 |
| Control W | 605 | 595 | 595 | 605 | 0 | 60 |
| R W | 605 | 595 | 595 | 605 | 0 | 60 |

Per refresh, N dirty-onto-full/retry rates fall **0.003306→0**; full-publication
rate is **0.019835→0.016529** and ACK-clear rate **0.996694→1.0**. W retry rate
is **0.983471** for both. All retries are a retained 2,097,152-byte baseline plus
a dirty packet causing byte-only overflow; rectangle and backpressure limits do
not trigger. Both isolated normal-Control events follow reset: generation 2
baseline serial 62 receives a two-byte dirty serial 63, forces full serial 64,
and receives ACK 62 during the slow copy. That ACK is stale against 64; a later
covering ACK clears the baseline. R has no normal event, but **sustained normal
feedback lock-in is not reproduced by Control on this host**.

Pooled raw timings below are **p50 / p95 / p99 / max**, in milliseconds.
Per-process distributions remain in the evidence; all 240 frame intervals per
process, including startup, remain in the primary population.

| Metric | Control N | R N | Control W | R W |
|---|---:|---:|---:|---:|
| Native exchange | .031 / .078 / 47.790 / 74.001 | .031 / .077 / 2.720 / 4.744 | 40.283 / 64.163 / 66.283 / 85.322 | 1.724 / 2.653 / 3.511 / 10.726 |
| Worker publication with refresh | .465 / .737 / 52.326 / 80.254 | .456 / .783 / 6.965 / 12.925 | 47.649 / 65.821 / 70.389 / 86.223 | 2.892 / 4.538 / 7.032 / 11.670 |
| CPU patch excluding validation | .018 / .043 / .846 / 2.320 | .018 / .034 / .779 / 2.396 | .823 / 1.174 / 2.136 / 5.131 | .828 / 1.190 / 2.031 / 3.278 |
| Texture submission | .350 / .602 / .796 / 1.788 | .349 / .574 / .903 / 2.818 | .325 / .553 / .782 / 2.416 | .314 / .496 / .684 / 4.310 |
| ACK to covering clear | 8.762 / 15.820 / 16.536 / 17.880 | 8.182 / 15.931 / 16.527 / 16.950 | — | — |
| Frame interval | 44.052 / 55.789 / 60.597 / 11419.319 | 44.392 / 57.847 / 66.096 / 2387.760 | 44.634 / 56.654 / 62.790 / 2111.541 | 43.490 / 56.695 / 61.410 / 2025.285 |

W full-copy p50/p95 falls **46.637/64.815→2.034/3.039 ms**; retry p50/p95
falls **46.635/64.826→2.023/2.953 ms**, while full-copy count/bandwidth stays.
No new retained-state policy or native World memory behavior is introduced.
The measured pending-payload high-water is not a total-process/GPU memory audit.

R improves actual reset-request→first generation-2 Main texture submission:
N median **89.114→47.475 ms**, W **89.054→49.969 ms**. It does **not demonstrate
frame-hitch improvement** here. Every process's largest frame interval is frame
1; the first Control process's 11.4-second interval has no overlapping native
copy. The post-hoc startup/reset breakdown is descriptive only, never an
acceptance exclusion. An R normal non-startup 214.815 ms outlier also has no
overlapping native copy and remains retained. Texture API timing does not prove
GPU completion, hardware Windows/NVIDIA behavior or human feel. The paused,
frame-paced workload and software renderer limit wall-time emission pressure;
trace mutex/diagnostic costs perturb both implementations equally in design.

## Fresh published runtime provenance

The approved shared publication engine is reused through a narrowly scoped
profile, with a fresh explicit request. Publication completes in the run linked
above and appends exactly four paths, single parent, at
`c405db68310042089b8bf4aa51c3ea7622312606`, tree
`607965b3fa2f0e83e5e57d83aedd263bd6d4aeef`. Both artifacts bind the armed source
`a7ee10f` and its exact tree, **80 native + 646 build-input hashes**, pinned
commands/dependencies, original artifact attempts and actual-target execution.
The native input ledger remains unchanged by later tests/documentation.

| Runtime | SHA-256 / LFS object ID | Bytes |
|---|---|---:|
| Linux ELF x86-64 | `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45` | 4,222,424 |
| Windows PE32+ x86-64 | `ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a` | 4,824,064 |

Linux uses GCC 13.3.0 (`13.3.0-6ubuntu2~24.04.1`) and GNU ld 2.42. Windows uses
LLVM-MinGW 20260826 UCRT, Clang/LLD 23.1.0, archive
`cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65`.
Both use SCons 4.10.1 and godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`. The dependency archive hashes are
Linux `bc5f860471475c745ebad2b45988607a15c9a35c6996b0f08fea37570e6ef666`
and Windows `869970b079bd55b24f983714244e53b4c1c4eb0018dd83447688beb81ba3ead7`.
Complete toolchain text, commands and ledgers are in the two runtime manifests
and original workflow artifacts. Import plus render-generation, native RG8
bridge, immutable handoff, Water Feel and liquid-policy cases pass on each
actual OS. Native RG8 full extraction returns 2,097,152 bytes.

## Exact-head gates, independent review and decision

All existing #340 workflow/scheduler files are unchanged, including the
19-Windows/20-Linux shard model, expected-cost assignment, concurrency caps,
setup/retry behavior and watchdogs. A separate ephemeral verification branch
adds only its own workflow as a single-parent child of the final candidate. It
checks the source lease and dispatches the unchanged Native, complete
GDExtension, Documentation/provenance, Water, PLAY packet-identity and
informational source-scope workflows at that exact candidate. Its graphical
repeat uses the published R artifact and a freshly rebuilt matching Control.
Every started case retains its full watchdog; an insufficient aggregate budget
names unstarted cells and fails rather than accepting a partial matrix.

[Draft PR #344](https://github.com/techrote/cybersand/pull/344) owns the final
candidate SHA/tree, exact-head gate URLs/conclusions and hosted graphical
readback. Those results are required separately from this local/native record;
a draft skip or a dispatch acceptance is not a pass. Failed original evidence
must remain available. This document does not claim unexecuted final gates.

Independent source, tests, observation, provenance and raw-result reviews find
no production correctness blocker. They corrected misleading allocation/count
wording, excluded post-receipt crashes from successful cohorts, separated
startup from causal claims, and identified the finite-edge test gap addressed
above. A final driver EOF whitespace finding is also corrected. AI review is
not human approval.

**Production selection: R alone**, subject to the exact-head gates recorded in
the PR. New native proof and local graphical evidence support GO for the copy
optimization; sustained historical lock-in elimination and hardware frame feel
are not claimed. **E: NOT NEEDED — E not justified by current evidence.** No
meaningful normal-ACK residual remains in this campaign; W confirms retained
semantics but reduces copy cost substantially. No E, C/coalescing, baseline
drop, early ACK, simulation change or unrelated physical/PLAY stack is included.
#333 remains preserved as historical reconciliation evidence. Leave #344 draft;
merge requires explicit owner mergedown approval.
