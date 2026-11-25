---
title: Bounded native context scan performance investigation
status: Planned
document-kind: audit
scope: Pure-value Context.build profiling and a separately qualified exact scan candidate
last-reviewed: 2026-11-25
---

# Bounded native context scan performance

The full displayed native campaign at source
`2743f89a0df6f6afcf7484e859c10790d521e74b` recorded a **107.814 ms**
Context.build interval over 262,144 actual captured material cells. That is a
concrete main-thread boundary. This investigation keeps the full native plane,
its material hash, context provenance, policy constraints and complete audit
behavior; it does not change native authority or introduce a model request.

## Source-pinned phase baseline

Measurement-only source
`0e93cc9093aee4ddf7429c7b008a48ec87c06fd5`, tree
`a71b686bee6e2fdea9c9e10fb4c05ddba78cb913`, ran the phase benchmark under
the lead's executor with clean tracked source: **86 checks, zero failures**.
The specialist independently fetched its original numeric report and checked
its SHA-256 against the execution custody record:

- [Original phase report](https://github.com/techrote/cybersand/blob/59061988a57738d0c63bb2e89e82924dc8496569/docs/audits/2026-11-25-art-workbench-collaborative-002/context-phase-baseline/context-phase-benchmark.json).
- [Execution and host custody](https://github.com/techrote/cybersand/blob/59061988a57738d0c63bb2e89e82924dc8496569/docs/audits/2026-11-25-art-workbench-collaborative-002/context-phase-baseline/execution.json).
- Report SHA-256:
  `d4a2df89783f6dffd250419d1a929b404fbdb72a2152e1c6973c153e54ce3bef`.

The recorded host is Linux 6.18.57 x86_64, nine logical CPUs, Godot
`4.7.stable.official.5b4e0cb0f`. No physical GPU or processor model is
inferred. Inputs come from original native diagnostic PNGs, authenticated against
the original int32 material-plane hashes and source identities. This is a replay
of recorded values: **zero live native calls and zero model calls**.

| Original native before plane | Captured cells | Median total | Median native scan | Median material hash |
| --- | ---: | ---: | ---: | ---: |
| Industrial repair | 49,152 | 20.866 ms | 19.154 ms | 0.841 ms |
| Stopped workshop | 98,304 | 41.328 ms | 38.822 ms | 1.653 ms |
| Staged megaframe | 262,144 | 111.292 ms | 105.213 ms | 4.580 ms |
| Xeno vault | 98,304 | 44.511 ms | 41.613 ms | 1.935 ms |

Each row retains a warmup and seven full repetitions. Per-phase medians do not
necessarily sum to the median total. Host variability is visible: the final
xeno repetitions took 59.629, 75.346 and 106.552 ms. The 0e93 total also includes
the returned private-plane copy; the earlier campaign timer stopped just before
that copy. Comparing 111.292 with 107.814 is therefore not an isolated regression
measurement.

## Small exact scan candidate

The native scan dominates the measured interval. The candidate uses a packed
256-entry histogram, precomputes horizontal bucket offsets and each axis's bin
population, and initializes exact observed/eligible populations from their
products. Every actual material ID is still validated. Empty cells need no
coarse-grid update; nonempty cells increment occupancy, and nonzero/non58 cells
decrement source-policy eligibility.

This preserves all 16-by-16 bin counts, including zero-population bins in
one-cell-wide or uneven regions. It preserves ascending material identities,
every sample, knowledge selection, source/policy/model hashes and the private
full material plane. It changes no request lifecycle, native permission,
history, execution or approval behavior.

The authoring-proposal suite adds nine explicitly synthetic reference cases:
single-cell, narrow, short, uneven and maximum-size dense byte-domain planes.
A simple scalar reference checks exact histogram and occupancy semantics.
Those cases are correctness tests; they are not additional native captures.

## Controlled paired comparison

`godot/tests/run_art_context_scan_comparison.gd` uses a byte-identical copy of
Context from0e93:

`godot/tests/fixtures/art_world_context_scan_baseline_0e93.gd`, SHA-256
`59fd1b9b517ffd742e81f1e4ec5aca6f81c9911b3e3e04bc04072692efb34415`.

The specialist fetched that source from the immutable commit and checked the
copy before publication. The benchmark checks its digest again at runtime.
It runs baseline and candidate in one process with eight paired repetitions
per input, counterbalancing which arm runs first. Every warmup and measured pair
must produce identical model bytes, context and policy digests, source,
private captured values and inspector content apart from timing fields.

Inputs include the four original before planes above **and the actual completed
megaframe after plane**, so timing is not restricted to mostly Empty baselines.
The report preserves every sample, both script identities, observed nonempty
counts and all phase medians. Inputs, plane decoding and equality checks are
outside the measured build intervals.

~~~text
ART_CONTEXT_BENCH_NATIVE_DIR=PATH_TO_ORIGINAL_NATIVE_CASE
CYBERSAND_TEST_ARTIFACT_DIR=NEW_EVIDENCE_DIRECTORY
CYBERSAND_SOURCE_REVISION=EXACT_COMPARISON_SOURCE
Godot --headless --path godot --script res://tests/run_art_context_scan_comparison.gd
~~~

The result file is `context-scan-comparison.json`; terminal marker is
`ART_CONTEXT_SCAN_COMPARISON`. Run the pinned comparison source: later changes
to model disclosure or schema intentionally make exact comparison fail instead
of silently ignoring changed context.

**At this checkpoint the packed candidate and paired benchmark have not yet
executed. No improvement or graphical responsiveness result is asserted.**
A worker-thread lifecycle change remains deferred until this smaller change's
measured residual cost is known. The existing independently qualified source
and original evidence remain separate.
