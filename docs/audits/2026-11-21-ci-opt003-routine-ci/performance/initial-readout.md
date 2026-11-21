# CI-OPT-003: independent initial performance and CI architecture readout

Observed 21 November 2026. Read-only investigation; no implementation or remote mutations.

## Baselines and source authority

Current accepted main was `846fe0533b3170e7b01f690518da49fc40cc24d1`, the merge of #714. Its actual push cohort ran Documentation and the source-scope advisory only because #714 changed workflow/documentation files. That cohort is not complete routine execution evidence.

The previous accepted source `0f0161af337d6d0cee8fa961a9667aff570a75b0` has a complete representative successful cohort:

| Workflow | Run | Event to last executed job | Unweighted runner-minutes | Executed jobs |
| --- | --- | ---: | ---: | ---: |
| Native | [44941414576](https://github.com/techrote/cybersand/actions/runs/44941414576) | 30m37s | 89.950 | 8 |
| GDExtension | [44941414698](https://github.com/techrote/cybersand/actions/runs/44941414698) | 19m11s | 169.800 | 54 |
| Palette | [44941414560](https://github.com/techrote/cybersand/actions/runs/44941414560) | 7m14s | 15.950 | 8 |
| Wave | [44941414598](https://github.com/techrote/cybersand/actions/runs/44941414598) | 5m22s | 13.050 | 4 |
| Documentation | [44941414603](https://github.com/techrote/cybersand/actions/runs/44941414603) | 9m10s | 9.117 | 1 |
| Architecture source guard | [44941414570](https://github.com/techrote/cybersand/actions/runs/44941414570) | 26s | 0.383 | 1 |
| Native scope advisory | [44941414743](https://github.com/techrote/cybersand/actions/runs/44941414743) | 31s | 0.450 | 1 |
| Entire cohort | same source | **30m37s** | **298.700** | **77** |

Eight explicit conditional skips are retained in raw jobs; they are not counted as work or new qualification. Native's earliest complete functional family was soliding-normal at event+3m12s. Across the wider cohort, Wave normal completed at event+1m18s. Policy success is not functional feedback. Run API updated_at can trail the final job by one second; comparisons here use final executed-job completion consistently.

The six-family control [44948256292](https://github.com/techrote/cybersand/actions/runs/44948256292) source `8fada1df005553eecb98935afdbcebd27615bd13` is an immutable proof branch reproducing accepted native computation. It completed Native in **37m28s**, **97.566667 runner-minutes**, first functional family **3m01s**. It is not a full whole-repository cohort.

Rejected #718's candidate [44948729271](https://github.com/techrote/cybersand/actions/runs/44948729271), PR head `65aa1382a49bb01571177b4639f27b64f5dcb66d`, tested merge `9ae8b2a483d756af18ad21f1d99f529645640f12`, completed Native **37m03s**, **102.533333 runner-minutes**, first functional family **6m30s**. Its different CPU invalidates a precise scheduling speedup inference. No reason to reopen this experiment.

## Actual critical path and trustworthy granularity

Canonical Native DAG is optional Ready scope -> policy/planner -> six concurrent families (max six) -> `native` reducer. Policy, original failure receipts, complete source/run/attempt-bound reducer and advisory-history stages all remain required as defined.

The control's worldgen job occupied **35m58s**, versus soliding-asan **26m04s**. Its measured child commands were:

| Worldgen command | Accepted-main Intel | Control AMD 9V74 | #718 AMD 7763 |
| --- | ---: | ---: | ---: |
| Physics characterization + sanitizer | retained in JSON | 96.556s | separate family |
| Normal worldgen make + tests | retained in JSON | 354.882s | separate family |
| Sanitized worldgen make + tests | 1404.917s | 1691.767s | 2124.821s |

All three worldgen artifacts were downloaded and their ZIP SHA256 checked against GitHub. Host data comes from retained `performance.jsonl`:

- Accepted main: Intel Xeon 6975P-C, four logical CPUs, image `20261116.133.1`, AWS kernel.
- Six-family control: AMD EPYC 9V74, four logical CPUs, image `20261116.376.1`, Azure kernel.
- #718 sanitizer: AMD EPYC 7763, four logical CPUs, same Azure image as control.
- Compiler log for control/candidate: GCC 13.3.0 `13.3.0-6ubuntu2~24.04.1`.

Control sanitizer make used **1952.72 user CPU seconds**, **30.91 system CPU seconds**, **117% aggregate CPU**, max-child RSS **1,695,204 KiB**. Candidate also used117% CPU and similar1.7GiB max-child RSS, but took433.054s longer. These are actual whole-command measurements. Max-child RSS is not aggregate concurrent memory.

**Historical logs cannot separate compilation and test execution.** The outer `run_timed_command.py` buffers inner output: compiler and test lines all receive end-of-family GitHub log timestamps. Inner command.log is untimestamped. Its performance resource sample records only direct make-process RSS/CPU (CPU0), not descendants. Do not manufacture compile-time estimates from those log line timestamps. A minimal compiler wrapper and explicit test-phase timing in a bounded proof is warranted.

The next Native bottleneck is soliding-asan. In the control, settled-regions sanitizer compilation took **701.300s**, remaining soliding binary build **849.292s**, actual full sanitizer execution **2.237s**. This is unequivocal compile dominance; initial heavy compilation reached **8,013,496 KiB max-child RSS**, so indiscriminate -j4 here risks memory exhaustion.

GDExtension DAG runs execution plan, Linux build and Windows cross-build concurrently. Linux build425s (377s actual build), Windows build260s (228s actual build); each platform feeds its eight-at-a-time regression matrix (24 Linux +23 Windows). Both platform reducers and Art graphical smoke remain mandatory. Windows regression tail set the prior cohort's GDExtension completion; #718's otherwise-equivalent cohort ended about19m after event with Linux tail. This is a future bottleneck only once Native falls below roughly20–22min. Native checkout/artifact overhead is seconds; whole reducer51s includes32s advisory history in the control. Artifact transfer is not the current dominant cost.

## Prioritized engineering candidates and bounded comparison

1. **Overlap heavy independent worldgen compiler contracts at fixed concurrency.** Source already deduplicates generation objects by normal/threaded/sanitized variants. Make walks threaded planes/grammar before the plain generator object; launching the two heavy `world_generation.cpp` contracts early under the existing -j2 cap may remove a long serial compile tail. Preserve separate pthread/non-pthread objects and all original target/test invocations. Highest critical-path leverage, small reversible build-tooling change. This remains a hypothesis until instrumented pairing; no claimed saving yet.
2. **Deduplicate identical soliding/core compilation, then use memory-aware parallel work.** Control spends25m50s building and2.24s executing sanitizer assertions. Same-input object reuse could remove repeated core compilation without changing any tests. Avoid concurrently scheduling two8GiB compiles on a16GiB host. High runner-minute potential and necessary to avoid soliding becoming the new ceiling. Independent native engineer owns design.
3. **Follow with GDExtension shard balance/build reuse only after Native improves.** Current47-shard contract already shares native build artifacts. Match historical per-case timing to late shard assignments and inspect duplicated immutable Godot preparation. No current evidence justifies importing #708 wholesale or increasing runner count. Larger maintenance/race surface than the first two, and no present critical-path gain.

Suggested predeclared programme: one same-worker cold-build baseline/candidate pair, isolated build roots, exact same production+fixture hashes, GCC13 and flags, identical test inventory; capture true per-compiler/phase wall, user/system CPU and peak memory. If order effects or hardware noise would alter the decision, use two workers with AB and BA arm order. Run full actual candidate Ready qualification concurrently, rather than repeating whole cohorts to fish for a favorable number. Stop on unsafe memory, lost tests/receipts, or a gain small enough that maintenance and uncertainty outweigh it. One pair can establish the observed exact comparison, not a percentile or reliable population-wide percentage.

## Qualification routing, provenance and retained evidence

- Native and GDExtension ignore workflow/docs-only diffs on push/PR; Ready scope repeats the filter. A Makefile or substantive tools/ci change triggers them. Their workflow_dispatch paths also exist. Draft PR runs intentionally skip expensive families and cannot count as actual execution qualification.
- Changing Makefile triggers Wave Flow via explicit path filters. Preserve that applicable Linux/Windows qualification too.
- `Makefile` is retained in native runtime manifest `build_inputs` as historical publisher evidence but **not in `source_inputs`**. `check_repository.verify_runtime` compares source_inputs. A test-only Makefile change does not require rewriting binary provenance. Preserve original manifest bytes and all production inputs.
- Current `main` was reported unprotected by branch endpoint. This does not remove repository-required check obligations or stable status-context requirements.
- All raw full job arrays, run metadata, downloaded ZIPs and unpacked receipts are in this directory. `baseline-summary.json` contains machine-readable cohort and host/command timings. No CI-only implementation has yet been qualified by these historical results.

Artifact digests:
- 14725108726: `3a5a402f27fef61e2f9c940e212d339187dc2b26ed79fa9ee99ef3ee37826e9f`.
- 14725619047: `65ca2fb8a8525cc4c3a5146fc6ff6c06e7e6cd93cff28dd9059d2776bbd527dc`.
- 14722054189: `77adf07cbe9e5753043041c2ad0124188eb30257a39285e85fef33f25d22ef99`.

