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

## Wave 1 observed; wave 2 staged

Wave 1 real outcomes and source/artifact references: [results-2026-11-16.md](results-2026-11-16.md).
AERO6 survived 42 legal game decisions (36 BRANCH, 5 RETRACE, 1 STOP) at ~4.27x
paired stock p50. SKELE6 made 48 STRAIGHT choices at ~4.27x. SKELE4
immediately STOPed three times; its 7.98x p50 is not a valid nonterminal
speed claim. AERO4 failed the intended attention-ballast initialization guard;
its original flow identity is retained unchanged.

Wave 2 introduces *new* named tail variants, rather than retrospectively
rewriting failed AERO4. It also builds a reproducible ephemeral Q4_K_M from
the pinned Q8 donor and records a same-runner Q8-stock/Q4-stock/Q4-AERO6
triad. The new quantised model is a **requantisation** and is not equivalent to
an F16-source Q4. Large generated model files are kept out of Git history.
All model transforms and hashes appear in original Actions evidence.

## Wave 3 findings and wave 4 strategy

Source-fenced [results](results-2026-11-16.md) establish that five-layer
AERO5_NO23 is alive with 48 legal, nonterminal BRANCH/RETRACE/RIGHT actions;
four-layer TAILFLIP4 also survives, but gives a nearly world-invariant BRANCH
personality. Four-execution ECHO4 survives and has some world-conditioned LEFT
turns. Wave 4 tries Q4_K_M requantisation of AERO5_NO23 and TAILFLIP4, plus
seed-571 replication of AERO5_NO23 and ECHO4. Quantised checkpoints remain
out of Git history; Q4 is made from immutable Q8 (not FP16). Game code is
read-only and all W0 projections are synthetic, not native acceptance.

## Wave 4 verified, wave 5 dispatched

Four original Wave-4 archives verified 150/150 content hashes: five-layer AERO5
survives Q4 (48 nonterminal decisions, 29 BRANCH/11 RETRACE/8 RIGHT), whereas
TAILFLIP4 Q4 ends after five alternating branch/retrace moves in each world.
The Q8 seed-571 AERO5 and ECHO4 remain nonterminal, though broader responsiveness
remains unproven. [Details and archived evidence](results-2026-11-16.md).

Wave 5 checks a new four-layer deletion, a five-layer reordered tail,
ECHO4-Q4, and AERO5-Q4 at another seed. New modes are speculative and run
against the unchanged W0 legal-action host with pinned same-runner stock controls.
No CyberSand game/native/Workbench modifications or production promotion.
