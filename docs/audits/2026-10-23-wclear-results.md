---
title: WCLEAR-001 complete campaign readback
status: Current
document-kind: audit
scope: Complete authorized 672-process prepared-resident clear-event evidence and independent readback; no carrier selection
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [2026-10-23-wclear-admission.md, ../research/mat003-continuation.md]
---

# WCLEAR-001 complete campaign readback

Run [39889832605](https://github.com/techrote/cybersand/actions/runs/39889832605) completed successfully at2026-10-23T02:38:06Z. Execution commit is `4a0e9d28173bea7811c9f24ace2509a5fd8b3ef3`; admitted registration SHA-256 is `a207d988098f75b6d1921ec817d11322f001b2e85ea9977b04448cf14732a3e1`. The authenticated owner explicitly authorized that exact identity. Frozen qualified apparatus source remains `f7c80a47da8bd1c87ac84b2f7281120a4fcc0796`, GCC13.3/ld2.42 on native Linux x86-64. Workflow publication PR225 merged only the admitted workflow; PR211/221 remain draft.

## Raw retention and complete matrix

[Artifact12474820652](https://github.com/techrote/cybersand/actions/runs/39889832605/artifacts/12474820652) contains44,021,844 bytes, SHA-256 `cc4b461a2dd402ef3237ba74db8000bdca08807de87263c60bbaded58f5db5e1`, independently matched after download. It expires2027-01-21T02:29:22Z. The unchanged ZIP and extracted raw evidence are retained locally under ignored `build/mat003-continuation/timing-39889832605`. It includes original qualified ZIP/source/binaries, preflight and owner authority, all process stdout/stderr, semantic records, schedule, hashes and complete readback. No observation was rerun, dropped or reconstructed.

The [complete descriptive readback](mat003-continuation-2026-10-23/wclear-39889832605-readback.json) retains all48 contexts: four widths, three resident sizes, two scenes, one/four workers, seven AB/BA process pairs. All672 processes and all336 clear observations are retained. Per-context raw values, median/min/max/MAD, nearest-rank p50/p95/p99/max, paired excess/ratio and peak RSS are preserved. With N=7, p95/p99 equal the observed maximum and are descriptive, not population-tail estimates. Startup/setup/input timing remains separate in raw receipts. Actual epochs/counts, visits and phase work remain in each process receipt; observer-off background participation relies on qualified twins.

## Observations within admitted scope

Quiet/sleeping/excluded, one-worker clear-event process medians (milliseconds):

| Width |512²|1024²|2048²|
|---|---:|---:|---:|
|E8|0.062092|0.467809|2.406053|
|E16|0.065046|0.486447|2.385403|
|E24|0.063403|0.474999|2.444518|
|E32|0.098465|0.543130|2.510146|

The largest observed event-inclusive tick is4.739428ms (E32,2048²,active-window-excluded,w1). The negative paired excess of−17,425ns in one E32/512²/active/w1 pair is retained; no outlier trimming or selective rerun is applied. These process contrasts include ordinary simulation and preparation/store/cache history, not an isolated instrumented clear loop. Large resident clears exceed the historical1ms review trigger; this is a recorded review finding, not a predefined rejection threshold.

The cell carrier address spans are4/16/64MiB at the three sizes (16-byte C80-aligned stride). They are not measured bus traffic; peak RSS also includes scratch, semantic buffers and startup. The clear cost increases sharply with resident size. Increasing width does not remove the individual clear hitch. Cross-width ordering is not a production ranking: E8 retains natural stamps, wider events are prepared, and cache/store histories differ under the admitted protocol.

[Conditional projections](mat003-continuation-2026-10-23/wclear-39889832605-projections.json) retain each context's ordinary median N, paired-excess median D and N+D/(2^E−1). The first clear occurs at2^E and later intervals are2^E−1; finite-horizon counts remain as registered. These models do not measure natural wide-epoch long-run performance or C64/packed/C128 access overhead. No carrier break-even or production choice is established.

## Independent disposition

Final external raw-evidence review is recorded below. Workflow success alone grants no performance acceptance. PR211/221 remain draft; no production, Water, persistence or streaming implementation changes are made.

The separate independent reviewer reran the frozen `verify_timing.py` against retained `timing` and `qualified/wclear` roots, without running any binaries. Exit0, empty stderr, errors[], all672 processes/48 contexts and4032 semantic records passed. Fresh readback exactly equals the embedded result; the reviewer independently recomputed all medians/minima/maxima/MAD/quantiles and paired ratios/excess from raw stdout. All8504 extracted files match the ZIP, with no duplicates/CRC errors, and before/after complete file hashes are identical. External readback SHA-256 is `bdb2195a4aa20cb4a539c7e5df9183942c2b5529d6ec17cd2cbce2b2b7929d20`.

**Independent disposition: accepted complete measured evidence for the exact admitted prepared-resident protocol.** The frozen automated `performance_accepted=false` field is preserved; this separate review disposition does not rewrite raw evidence. All112 pairs above the1ms excess review trigger (all2048 contexts) and the single negative excess were explicitly reviewed and retained. The maximum paired excess is2.509726ms (E16/2048/sleep/w4). Peak whole-process RSS is288324KiB (281.566MiB). Active visits are960/1920/3840 at512/1024/2048; phase jobs are[4,4,2,2]/[8,8,4,4]/[16,16,8,8]. Sleeping scenes have zero ordinary visits/jobs, distinguishing resident clear traversal from active simulation. Worker participation scope remains observer-twin qualified.

No production layout/epoch winner, generalized width ordering or cold-gameplay guarantee is accepted. The 1ms findings require architecture consideration of resident traversal/frame hitches; wider epochs change frequency without eliminating the observed hitch. No failed/incomplete observations exist in this campaign; no reruns were performed.

Documentation/current repository/historical M11 checks and diff checks pass. Frozen retrieval remains21/32 at1,32/32 at5,MRR0.7937; supplementary96/119 at1,119/119 at5,MRR0.8843. Manual fact/status review preserves the protocol qualifiers and separate timing-admission versus evidence-acceptance meanings.
