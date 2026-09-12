---
title: Architecture programme addendum — Water presentation, feel and semantic budgets
status: Current
document-kind: design
scope: Post-G-P refinement of #19/#18 ordering and evaluation authority; supplements rather than rewrites completed C/L/P evidence
canonical-for: [architecture-experimental-programme-water-feel-refinement]
last-reviewed: 2026-09-12
related-documents: [architecture-programme.md, architecture-programme-prompts/fractional-presentation.md, water-feel-lab-experiment.md, state-precision-experiment.md, experiment-tower.md, ../audits/2026-09-11-issue-17-state-precision.md, ../audits/2026-09-12-issue-19-water-feel-lab.md]
---

# Post-G-P Water feel refinement

## Status and authority

This dated addendum records an owner-led refinement after completed G-C, G-L and G-P. It **does not alter the measurements or scientific conclusions of #15–#17** and does not authorize a production migration.

**Current checkpoint, 2026-09-12:** #19 V1/V2 are complete and the Water Feel
Lab is H-ready under the [dated acceptance record](../audits/2026-09-12-issue-19-water-feel-lab.md).
The later human H gate has not run. Accordingly #18 remains open and held, #20
remains downstream and G-final remains open.

Completed #17 remains the numerical precision oracle:

- mass8 is retained as the quantitative/reference control for downstream experiments;
- Water coherence values 0..12 are exactly representable in four bits;
- mass4/6/10 have measured numerical/work consequences in the registered fixtures;
- no production Water precision or Cell layout was selected.

The new programme distinction is:

> **Quantitative equivalence and perceptual adequacy are separate gates.**

A game material is not selected solely for reproducing a higher-precision numerical reference. Quantitative characterization establishes what changes; hard correctness establishes whether a candidate is safe enough to observe; controlled human evaluation establishes whether the resulting behavior looks and feels desirable in the game.

Subjective preference never waives conservation, ownership, determinism, bounded work/capacity, failure quarantine, region semantics or other accepted invariants.

## Why the refinement is needed

The primary motivation for testing lower Water precision is flexible material-state packing: bits reclaimed from quantity or auxiliary state may support other material-local parameters. Runtime performance is secondary evidence, not the principal reason for quantization.

The intended partial-fill renderer exposes a small number of visible fill levels (initial experimental target: four). Internal mass precision can still affect accumulation, transfer thresholds, settling, streams, films and interactions even when those states are not individually visible. Therefore neither renderer resolution nor headless levelness metrics alone determine the correct gameplay state budget.

#17's lower-precision differences are now interpreted as a map of behavioral changes that later human testing must judge, not as automatic perceptual rejection.

## Revised sequencing

Current programme ordering for the affected work is:

```text
completed C/L/P evidence (#15/#16/#17)
                 |
                 v
#19 V1: establish/verify compact fractional Water presentation
                 |
                 v
#19 V2: build verified Water Feel Lab + runtime semantic policies
                 |
                 v
later H gate: blinded human-led material-feel assessment
                 |
        +--------+--------+
        |                 |
        v                 v
accepted candidate   named unmet perceptual/motion target
state budgets              |
        |                  v
        +------------> #18 M admission or no-go
                           |
                           v
                    #20 B only if a distinct
                    high-speed need remains
                           |
                           v
                        G-final
```

#18 remains technically unimplemented and held for a concrete directional-persistence target. #19/H-preparation may make such a target observable and reproducible; the later H gate decides whether it is actually worth solving. If no meaningful deficit is perceived, #18 may complete by a reasoned no-go rather than inventing a motion requirement.

#20's dependency remains unchanged.

## #19 expanded responsibility

#19 now owns both:

1. **V1 presentation:** a four-visible-level fractional Water presentation plus local orientation/fallback experiments on unchanged authoritative states; and
2. **V2 H-preparation:** extension of #13's Experiment Tower into a deterministic Water Feel Lab with runtime-selectable Water semantic policies.

Its self-contained execution contract is `architecture-programme-prompts/fractional-presentation.md` (historical filename retained to avoid link churn).

#19 completion has made the laboratory technically trustworthy and **H-ready**.
It did not choose the preferred candidate.

## Runtime semantic-policy principle

Human testing should not require a rebuild for every candidate. #19 therefore tests Water semantics using a superset experimental storage representation and an immutable World-creation/restart policy.

Required semantic axes:

- mass precision 3, 4, 5, 6, 7, 8 bits;
- coherent duration 0..12 ticks, with 12/7/3/0 named reference candidates;
- intended four-level partial-fill presentation held fixed during semantic comparisons;
- registered rest-policy selection only where explicitly controlled.

These settings describe **semantic precision/duration**, not physical production packing. Actual packing remains a later architecture decision after useful state requirements are known.

The same effective policy must be selectable via in-game developer controls, versioned profile/config and launch configuration, all resolving to one validated representation. Simulation-semantic changes use Apply + Reset at the exclusive owner boundary rather than mutation under active workers. Render-only controls may hot-switch where safe.

## Trust relationship to #17

The runtime Feel Lab reproduces relevant #17/reference behavior before its novel
candidates are offered for later perceptual decisions. Shared mass4/6/8 fixtures,
current mass8/coherence12 controls, exact per-lattice conservation and repeat/
worker expectations passed the correspondence gate.

Mass3/5/7 and shortened coherence are new candidate semantics. They require focused arithmetic/conservation/boundary characterization sufficient to distinguish intended quantization from implementation errors, but not a repetition of #17's full performance campaign.

## Later H gate

The human evaluation is deliberately not authored as a final issue until #19 exposes the real apparatus and candidate workflow. Once #19 is H-ready, the H charter should use the actual lab capabilities rather than guessed tooling.

Expected authority layers:

**Hard invariant gate:** material conservation/explicit source-sink accounting, ownership, deterministic policy application, bounded work/capacity, safe failure/region behavior and reproducibility.

**Descriptive quantitative context:** levelness, discharge, front/spread, settling, small-quantity survival, active lifetime and work. These explain what differs.

**Human material-feel decision:** perceived weight, fluidity, readability, liveliness, satisfying settling, stream/puddle behavior, undesirable crawling/stickiness, useful chunkiness, interactions and overall game fit.

Human judgments should use blinded A/B/C labels where practical and identical deterministic recipes/render settings. Preferred/acceptable/unacceptable outcomes should retain short observations before candidate identities are revealed.

## Implications for #18

#18 should consume a **named perceptual deficit**, not technical novelty alone. For example, a later H result might establish that an otherwise preferred low-state candidate loses horizontal emission coherence too rapidly. #18 can then measure whether compact material-local history fixes that specific problem at acceptable cost.

If H establishes no worthwhile motion deficit, #18 should record no-go rather than implementing history by programme momentum.

Any bits apparently freed by a human-selected semantic budget are only **available candidate capacity**. They are not allocated to direction/strength/age until #18 proves those semantics useful.

## Implications for G-final

G-final must distinguish at least:

- numerical/reference precision;
- perceptually accepted semantic precision;
- physical Cell packing/layout;
- presentation representation;
- optional motion/history requirements.

No single result silently selects the others.

A later production migration, if any, still requires separately reviewed ABI/save/profile/render/platform/rollback scope and appropriate ADR updates. Current production source remains unchanged until that authorization.
