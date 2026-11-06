---
title: SOL bearing-gate diagnostic
status: Current
document-kind: audit
scope: Dependent observation-only diagnostic of the native granular bearing velocity gate under pre/post Sand ordering; registered result INCONCLUSIVE
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-sol-contact-gravity-order.md, ../systems/solid-detachment.md, ../architecture/rigid-body-and-cellular-coupling.md, ../operations/local-build-and-validation.md]
---

# SOL bearing-gate diagnostic

## Decision and scope

**Registered decision: INCONCLUSIVE** for both the tree and the building. The
non-perturbation control is **PERTURBATION_UNRESOLVED** by its registered rule.
Too few host/worker pairs were eligible: on Windows, post acceptance fell to
0.20–0.61 in this run, below the 0.5 eligibility floor. So the registered
attribution test could not be decided. No physics, mass, inertia, gravity,
damping, force/correction cap, planner, age gate, default or native source
changed.

What the run does establish, descriptively:

- The native bearing correction law is reproduced exactly from captured inputs:
  0 failures in 83,133 per-proxy checks over 24 episodes.
- The `vy <= 0` gate is engaged far more under post than pre wherever post
  Sand is mostly accepted. On Linux, gate fractions were 0.78–0.95 for post
  versus 0.01–0.12 for pre, and post withheld up to 0.0033–0.0072 cells/step
  of correction (upper bound) in the tail.
- Packed outcomes are highly sensitive to publication/tick phase. Single
  episodes per cell cannot carry pairwise ordering claims.

This is source-local SOL, dependent on Draft
[#461](https://github.com/techrote/cybersand/pull/461) at
`cba3c0de35c4fae410b2fa16fa821524308c1ce8`. It is not an admitted #394
LA/SOL composition, settling candidate, support law, material-weight
calibration or original clearance/CPU result.

## Question and registration

The [#461 dossier](2026-11-06-sol-contact-gravity-order.md) attributed post's
worse burial to gravity integrating before Sand stops velocity. An independent
review raised another explanation. The unchanged ordinary law in
`godot/native_extension/cyber_native_cell_world.cpp:858` skips both bearing
impulse and correction when a proxy's published `velocity.y <= 0`. Post
publishes after Sand has stopped velocity, so it may withhold the 0.99 ×
downward-travel correction (capped at 0.5; `:875-880`).

Registration `native/tests/fixtures/sol_bearing_gate_001.json` was committed at
`340ecfb367c1ee38260ffb02f2d88d66f6ffc0f7` before any execution. Hypotheses:

- H_gate: gate suppression.
- H_integration: integration before Sand.
- H_schedule: acceptance or incoming age.

Amendment_001 at `56b925dcde495dac0faed24595a8d44adf7ddafd` followed a
retained apparatus failure (below). It preceded every registered matrix
episode. Thresholds were not changed after seeing matrix outcomes.

## Apparatus and its retained failure

The only behavioural switch is native World telemetry, through the default-off
session seam `_native_telemetry_enabled()`; telemetry only adds counters. A
test-only worker subclass copies the following for every published native tick
into a 64-entry mutex ring:

- `diagnostic_body_metrics` rows;
- the exact prepared states;
- the native results.

The main-thread probe drains that ring once per physics step. There were no
production default or native changes.

**smoke-001 (retained, apparatus failure).** Native writes diagnostic
`support_samples` only after its velocity gate passes (`:882-886`). Gated
proxies therefore always reported zero support, and the gate fraction was 0 by
construction.

**Amendment.** Support is now `below_contact`: the boundary-pressure face
histogram, recorded before any velocity gate, shows a movable non-wall material
directly below a proxy cell. `granular_support_at` is stricter, so this is an
**upper bound** on support and gives `lost_correction_upper`. It is calibrated
against native support on ungated proxies.

smoke-002 checked the repair only. Its outcomes are excluded from every
decision.

## Execution and custody

| Run | Source | Content |
|---|---|---|
| smoke-001 | `340ecfb3` | Focused gates + one tree post w1 per host; apparatus failure |
| smoke-002 | `56b925dc` | Repaired apparatus check; excluded |
| matrix-001 | `56b925dc` | 24 registered episodes × 720 steps (Windows/Linux, workers 1/4, tree/building, off/pre/post) + 2 Windows telemetry-off replays |

Actual Windows and WSL Ubuntu Godot 4.7 with Rapier 0.35.2 were run, reusing
the #460 parent's source-authenticated native binaries. Engine, native and
Rapier SHA-256 values equal those in the #461 dossier:

- Windows: `b2ca888d…`, `9e68d2d7…`, `b54e54bd…`.
- Linux: `f85bbc6b…`, `8bf350d9…`, `566e68ae…`.

On both hosts, all focused gates were clean: planner, fences and the #461
dispatch suite. The final documentation commit is not relabelled as executed
physics.

Raw evidence is under the local, uncommitted `build/sol-bearing-gate`:
971 MiB, inside the registered 1.5 GiB cap with a 5 GiB free-space reserve.

| Retained file | SHA-256 |
|---|---|
| smoke-001/receipt.json | `dc8c3f166682d347bc41cecf01f040b2d4efa1d4218318d8b3849bf99e8eced6` |
| smoke-002/receipt.json | `0a73d8e238c007d2ad2e4739cfb9fe60976413c18ed1a04a59f6d2b3eb375bf9` |
| matrix-001/receipt.json | `2fea6155a59a458bed1c7963dda671d1a30f4e09c3edaf3000f70d4cdeb9a8a7` |
| matrix-001/reduction.json | `bcf91cd8ecf945ca1e422efa6546d5c516c60247ae0b33e86ed66af4948fef06` |

## Apparatus qualification

- 15,138 applied ordinary results were captured. Of these, 15,114 were
  evaluated. 24 had no previous prepare (the first per episode). There were 0
  misaligned, 0 receipt mismatches, 0 age-zeroed and 0 ring overflows.
- Native law model: 83,133 per-proxy checks, 0 failures within 1e-5 cells.
- Support proxy calibration on ungated proxies: precision ≥ 0.993 and recall
  1.000 in every episode.

## Results

Tail values are over steps 600–719, in cells/step. "Lost" is the upper-bound
correction withheld by the gate.

| Pair | Post accept | Pre gate | Post gate | Δ sink (post−pre) | Δ lost | Eligible |
|---|---:|---:|---:|---:|---:|---|
| Windows w1 tree | 0.61 | 0.12 | 0.44 | −0.0081 | 0 | no (Δsink) |
| Windows w4 tree | 0.20 | 0.11 | 0.30 | 0.0082 | 0.0021 | no (acceptance) |
| Linux w1 tree | 0.95 | 0.11 | 0.78 | 0.0015 | 0.0072 | no (Δsink) |
| Linux w4 tree | 0.78 | 0.08 | 0.84 | 0.0033 | 0.0033 | **yes, R = 1.00** |
| Windows w1 building | 0.29 | 0.07 | 0.27 | 0.0039 | 0.0005 | no (acceptance) |
| Windows w4 building | 0.25 | 0.09 | 0.22 | 0.0006 | 0.0002 | no |
| Linux w1 building | 0.96 | 0.01 | 0.95 | −0.0012 | 0.0047 | no (Δsink) |
| Linux w4 building | 0.48 | 0.06 | 0.24 | 0.0026 | 0 | no (acceptance) |

The registered rule needs at least 3 of 4 eligible pairs per structure. Tree
had 1 and building had 0, so both are INCONCLUSIVE.

Post acceptance fell on Windows because incoming age-one samples became
refused age two:

| Windows post episode | StaleContactSample refusals |
|---|---:|
| w1 tree | 118/467 |
| w1 building | 425/624 |
| w4 tree | 492/649 |
| w4 building | 458/640 |

This shows the review's F2 scheduling sensitivity directly. Off gate fractions
(0.09–0.72) are descriptive: without Sand, published velocity also changes sign.

Interpretation, with only one eligible pair:

- The gate mechanism is real and engaged under post whenever post Sand is
  accepted.
- Its first-order magnitude (0.003–0.007 cells/step) is the same order as the
  #461 post-minus-pre tail sink.
- Where post accepted Sand at 0.95–0.96 (Linux w1), the post trajectories in
  this run did not sink more than pre. Lost correction therefore does not map
  one-for-one onto net sink; it is first-order accounting, not a
  counterfactual trajectory.

Neither H_gate nor H_integration is established or rejected.

## Non-perturbation and phase sensitivity

Every Windows pre/post episode matched live-001 bit for bit for 87–97 steps.
Each then diverged when a native tick prepared a different sample than in
live-001 (RACE). One exception, tree post w4, is classified PERTURBATION at
step 0 by the registered rule: prepared states were equal but results differed.

**Post-hoc observation, not a verdict change:** at that step the two runs
consumed different native ticks (1 versus 2) and snapshot serials (10 versus
11) from the same sample. That is a consumed-snapshot phase race that the
registered classifier did not cover. Both telemetry-off replays also diverged
from live-001 by RACE, at steps 95 and 93. Ordinary run-to-run races therefore
exist without telemetry. Telemetry may still shift scheduling phase; that is
not separately identified.

Descriptive rest screens (steps 600–719) vary by phase. Windows tree post w1
rested with telemetry on, while its telemetry-off replay and live-001 did not.
Several off episodes also rested. Quiet rest is not clearance, and none of
this changes the #461 NO-GO.

## Decisions at these sources

| Question | Decision |
|---|---|
| Bearing-gate attribution (H_gate) | INCONCLUSIVE (registered) |
| Native bearing law understood from captured inputs | PASS: 0/83,133 model failures |
| Gate engaged by post Sand | Descriptively yes on Linux high-acceptance pairs |
| Post ordering as a settling fix | Unchanged NO-GO (#461) |
| Original SOL clearance / CPU | Not proved; all preserved blockers stand |
| Integration admissibility | Not admissible; inherited material and runtime guard failures remain |

Preserve 84/84 synchronized sustained-clearance failures, 64/84 depth failures,
36/36 asynchronous final overlaps, 1,452/1,452 fixed-orientation refusals,
historical CPU failures, the #365 restoration block, the frozen material guard,
the eight inherited runtime source mismatches, hard-material exclusions and the
tiny RedBrick filter.

## Owner decisions

The [review and owner-decision record](2026-11-06-sol-review-and-owner-decisions.md)
records the 2026-11-06 owner decision: SOL adopts main's workbench granular contact
law (LA-SELECTIVE), subject to a registered repeated experiment on the actual cut
structures with unchanged mass and caps.

## Next action

A decidable attribution needs phase control, not more single episodes. Two
options:

1. Repeat each cell with several fresh seeds or phases and stratify by measured
   incoming age.
2. Run the separately registered live P2 arm (ordinary → step → publish → Sand).
   P2 removes the gate input change while keeping post's Sand timing.

Either must preserve mass, caps and guards, and register before running. No
gate, cap or law change follows from this diagnostic.

## Checks at the documentation source

On the documentation commit:

- `check_docs.py`, historical `check_m11_consistency.py`, `git diff --check`, and
  the gate and order reducer unit tests pass.
- Retrieval: the four SOL order/gate questions rank 1. The original
  `retrieval-questions.json` keeps its existing top-five routes.
- `check_repository.py` exits 1 for the same eight inherited Windows/Linux
  native-extension source-input mismatches.
- The frozen material guard exits 1 for World: expected
  `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1`, actual
  `91cecf308d01ef214f491f3dc1f353f10c9db17a55162b983fc4ecf80e6363e6`.

Neither guard is refreshed. Both remain integration blockers.

## Reproduction

```bash
python tools/sol281/test_gate_reduction.py
python tools/sol281/gate_live.py --run NEW            # add --smoke for apparatus checks
python tools/sol281/gate_reduce.py --run NEW --reference <live-001 folder>
```

`gate_live.py` requires the authenticated #460 parent artifacts at the
`order_common.py` paths, a clean committed source and materialized LFS. Linux
runs under an actual timeout wrapper; each command has a 300 s limit.
