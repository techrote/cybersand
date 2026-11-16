# Frankenlayers Lab — 6/4-layer game-policy carcasses (research only)

This is a **stacked** experiment on #626, not a replacement for its accepted
8-layer source/evidence. It changes only the experiment's *source-built llama.cpp
System One decision graph*, using the immutable d1-2B Q8 donor and the exact
phase-2 stock-vs-mutant W0 paired evaluator.

Four new speculative sparse skeletons are tried: `skele6`, `aero6`,
`skele4`, `aero4`. All preserve known phase-2 attention ballast candidates.
A graph-time metadata check requires both full and sliding attention paths to
be used; missing paths are a documented **runtime rejection**, not valid model
inference. No claim is made that the flows will work before their actual jobs.

First wave: source tests, pinned runtime build, pinned Q8 donor acquisition,
three W0 game-like families × up to 16 decisions each, each mutant paired with
stock on the same runner. Preserve HTTP decision responses, exact choices,
legal-action lists, p50/p95 latency, PNGs, hashes, failed server logs and CPU
metadata. One full CI evidence archive per mutant, including failures.

Only after a viable 6/4-layer candidate is evidenced should follow-up waves
try personality mutants (reorder/duplicate/weight surgery), alternate seeds,
Q4/IQ3/IQ2 or bounded repair training. This staged choice avoids comparing
quantized mutations against unqualified skeletons.

**Game-target boundary:** models are for CyberSand-style painting/navigation,
but this lane never edits the CyberSand game implementation or content. No
native/Workbench runs, paid API/GPU, production provider changes or merge.
Draft/HOLD. This PR stacks on `research/619-d1-frankenlayers-yolo`.
