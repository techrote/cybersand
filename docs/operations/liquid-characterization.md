---
title: Completed liquid characterization and evidence coverage
status: Current
document-kind: guide
scope: Interpretation of retained Issue 15 specialization and sleep evidence, with September research admissions separated from later accepted liquid implementations
canonical-for: [liquid-characterization-experiment]
last-reviewed: 2026-11-24
related-documents: [architecture-programme.md, ../audits/2026-09-11-issue-15-coverage.md, ../systems/materials-and-rule-kernels.md]
---

# Liquid characterization

This page explains the **September #15 experiment**, not the current solver
catalogue or today's implementation permission. Its measurements and negative
results retain their original source and fixtures. Current Water/Brine policy,
Wave, ballistic transport and storage are described by the
[solver-family contract](../architecture/liquid-solver-family-policy.md),
[Wave reference](../architecture/wave-flow-v1.md),
[ballistic Water contract](../architecture/ballistic-water-v1.md) and
[chunk/storage contract](../architecture/chunk-tile-and-buffer-model.md).
Later accepted work must not be rejected by treating a September admission hold
as a permanent restriction.

## What does completed G-C establish?

**G-C: COMPLETE / evidence reviewed at its original checkpoint.** That decision
retained distinct native liquids and the then-current production defaults. The [coverage matrix](../audits/2026-09-11-issue-15-coverage.md)
reviews all eleven liquids and every required dimension against retained
#9/#10/#13/Water and completed #15 evidence at `cdb4c2a`. No new measurements were
needed. [Original registration](https://github.com/techrote/cybersand/blob/cdb4c2a6df0248c76e7957fd09cae77655ec974f/docs/operations/liquid-characterization.md),
[complete results](https://github.com/techrote/cybersand/blob/cdb4c2a6df0248c76e7957fd09cae77655ec974f/docs/audits/2026-09-10-issue-15-liquid-results.md) and
[source/eleven-liquid inventory](https://github.com/techrote/cybersand/blob/cdb4c2a6df0248c76e7957fd09cae77655ec974f/docs/audits/2026-09-10-issue-15-liquid-characterization.md)
remain on the published experiment branch with their historical wording intact.
Its instrumentation is not integrated into this source checkout.

## Does keeping Water awake fix residual leveling or films?

No in the measured fixtures: every Water content trajectory matches quiet3 versus
4096 across five translations and workers1/4 in support, film and both basins.
The 96-wide basin remains active with 418..435 units column spread at tick1800;
the narrow basin rests at46 and the supported48-unit film never changes despite
extra visits. Sleep is therefore not the explanation in this measured horizon.
Precision, thresholds and finite-time local relaxation remain distinguishable
questions; these data do not prove a precision cause or predict that fewer bits win.

Brine/Paste/Slush/Mercury whole-cell support trajectories differ under the same
paired threshold change in all five translations. Failed deterministic mobility
samples occur before lateral cadence and do not schedule a retry; sleep censors
later opportunities. This establishes scheduler-dependent rest in the bounded
one-cell fixture, not an unwanted heap or a constitutive yield/stress law.
Mercury's period30 powder-exchange deadline is a separate mechanism; the support
fixture has no powder. Oil/Acid/Lava bypass generic mobility, while Cement/Molten
Glass lifecycle writes can affect activity. Their unmeasured details stay qualified.

<a id="what-research-does-c-now-permit"></a>
## What did C permit at its September checkpoint?

The [staged G-C programme decision](architecture-programme.md#g-c-staged-decision-2026-09-11)
admitted #17/P's bounded normalized mass4/6/8/10 and separate delay4/8 diagnostic
on one controlled carrier after G-L completed. The experiment had to preserve its solver and
exact per-precision accounting; initial quantization and threshold policy remain
separate. A negative result was valid. No P implementation occurred in #15.

#19/V was justified as an independent frozen-authority presentation experiment:
stable film/basin inputs let it investigate local coverage/orientation under its
existing visual/cost contract. C proves neither a visual deficit nor a renderer
benefit and authorizes no render migration. V does not require production layout
selection. At that checkpoint #18/M had no admitted measured jet/spray target;
implementation was held for a concrete target/no-go review, with
[completed G-P](architecture-programme.md#g-p-staged-decision-2026-09-11)
satisfying its precision prerequisite. #20/B still required #18/G-M and its
separate admission/transfer gate. The recorded non-admissions for general liquid
unification, universal FreeMass, new yield solvers, production velocity/history
and Cell widening describe that research stage. They do not negate the later
accepted CY/PF/IN families, Wave retained flux, ballistic transport or eight-byte
Cell representation. The [current-state register](../reference/status-and-roadmap.md)
owns present programme status; this page does not close G-final or authorize a
new liquid model.

## Evidence and limits

Reuse 352 behavior and224 timed processes, including observer-off/on and unchanged
source controls; all576 raw outputs match retained hashes. Exact Water/species,
worker/repeat and source-neutrality checks pass in the original experiment.
85/112 timing pairs trigger research review flags; keeping all blocks awake is
costly, and instrumentation tail neutrality is unresolved. This is Windows core
evidence on one pinned host/compiler, not fresh desktop/Web/Linux acceptance.
Macroscopic heap laws, reaction mass units, jets, visual quality, process memory,
PMU/GPU metrics and exact wake-cause/write counts remain explicit gaps whose
absence limits later admissions rather than preventing characterization closure.
