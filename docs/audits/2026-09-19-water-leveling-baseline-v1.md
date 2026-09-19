---
title: Issue 26 Water leveling baseline v1 review
status: Current
document-kind: evidence
scope: Retained authoritative baseline characterization and preregistration review before any issue 26 candidate semantics
canonical-for: [issue-26-water-leveling-baseline-v1]
last-reviewed: 2026-09-19
related-documents: [../operations/water-leveling-experiment.md, 2026-09-18-water-h-gate-synthesis.md, ../systems/water-design.md, ../reference/validation-evidence.md]
---

# Issue 26 Water leveling baseline v1 review

## Disposition

The WL26-v1 native baseline confirms the issue #26 bulk defect and the source
mechanism hypothesis strongly enough to continue the bounded experiment.

Candidate semantics are **not** admitted from the raw v1 surface maxima alone.
Baseline review found that whole-run hill/terrace turnover can classify intended
macro geometry and moving fronts as a surface defect. Per the preregistration,
that is an apparatus/reduction defect: v1 evidence remains retained, and a
versioned surface-window correction must be frozen and rerun before candidate A.

No production Water semantics changed in this baseline.

## Retained identity

- branch/head: `codex/issue-26-water-leveling` /
  `51efed0738ccf91ba117dc845481aa8435d55e1c`
- frozen semantic ancestor:
  `781a2d7cb5d5a66bf1cff8fc6654e0ab708e419c`
- source tree: `c5cd53821ab2e5459f0099eb82e491a2d308a884`
- compiler: `g++-13 (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`
- harness executable SHA-256:
  `5eca7cf30f8080eaca6173c789bbcc5344a087f2c150a28605dd70664350a9a0`
- Actions run: `35409429191`
- retained artifact: `water-leveling-baseline-35409429191`, artifact
  `10574215572`, 4,098,883 bytes
- artifact SHA-256:
  `36e50088e2a336274a0e0d1ed5d3da7111d29a66721be6fd8632932a28eaef54`
- raw/reduced files in the artifact: 510
- reducer self-tests: 9/9 passed
- repeat/worker parity: 180/180 registered runs passed
- observer-neutrality pairs: 9/9 passed
- timing semantic controls: 18/18 passed
- every canonical fixture retained exact initial/final Water integer quantity.

The hosted-runner timing values are platform-specific baseline context, not a
desktop performance attestation.

## Bulk result

### Identical-outlet reservoirs: discharge barely responds to head

Cell-equivalent quantity downstream of the bit-identical outlet:

| tick | R8 | R24 | R40 | R24/R8 | R40/R8 |
|---:|---:|---:|---:|---:|---:|
| 30 | 25.953 | 25.953 | 25.953 | 1.000 | 1.000 |
| 60 | 37.894 | 38.247 | 38.247 | 1.009 | 1.009 |
| 120 | 52.937 | 53.608 | 53.608 | 1.013 | 1.013 |
| 240 | 73.055 | 74.004 | 74.004 | 1.013 | 1.013 |

R24 and R40 are exactly identical at all four registered early checkpoints.
Tripling or quintupling depth from R8 therefore produces at most about 1.3%
extra early discharge in this fixture. This is direct native evidence that the
current outlet response is dominated by local geometry/cadence rather than
usefully scaling with the registered upstream head.

### CP16: partial relaxation followed by a false rest state

The communicating-pool arm difference starts at exactly 16 cells.

- tick 60: 12.337 cells;
- tick 240: 12.088 cells;
- tick 900: 12.042 cells;
- tick 7,200: 12.042 cells.

Only about 24.7% of the initial difference is removed. The world has zero moved
cells and zero active blocks by tick 900, so this is not just a long slow tail:
the current rules settle into an authoritative non-equilibrium rest state. The
registered 8-cell half-life is never reached.

This is directionally consistent with the H connected-pools observation that a
multi-degree free-surface difference remained thousands of ticks after
connection. The native fixture is not claimed to be geometrically identical to
the H recipe.

### UT96-48: saturated differential head is completely invisible

The true unequal-head U-tube starts with heads 96 and 48 cells around a full
connector. It remains exactly 96/48 through tick 7,200.

- Water moved cells: zero throughout;
- arm difference: exactly 48 cells throughout;
- Water quantity: exactly conserved;
- the initial activity sleeps rather than creating any redistribution.

This is the expected source-mechanism result: the current immediate same-row
transfer cannot create capacity inside a full saturated chain, and no current
rule propagates the remote free-surface/head difference through that chain.

This fixture is intentionally stronger than the uniformly filled H
`u-vessel`; it does not imply that issue #26 now owns a general hydrostatic
pressure solver.

### CS: quantitative convergence target

Calm settling reaches the registered flat condition at tick **2,811**.

The H owner target says the acceptable current mass8 result should be reached
roughly 2-4 times faster. Applied to this registered native metric, that gives a
candidate target band of approximately **703-1,406 ticks**. The band remains a
human target, not a sole automatic acceptance threshold.

Useful state points:

| tick | depth minimum | depth maximum |
|---:|---:|---:|
| 60 | 0.055 | 29.075 |
| 240 | 6.024 | 20.992 |
| 480 | 10.231 | 17.949 |
| 900 | 12.757 | 16.451 |
| 1,800 | 14.212 | 16.071 |
| 2,811 | 14.722 | 15.722 |
| 4,200 | 14.992 | 15.478 |
| 7,200 | 14.996 | 15.478 |

The final retained state is static despite a remaining sub-cell depth range,
which is expected under the current discrete tolerance/cadence policy.

### Fast dump and ledge-sheet controls

FD reproduces a small authoritative contact defect: maximum registered wall gap
is one cell and the longest gap run is 13 ticks. It also preserves a large
moving-surface transient, so whole-run hill maxima are not a valid
`hillnipple` measurement.

LS provides the positive-control baseline needed for candidate comparison:

- downstream quantity: 117.686 cell-equivalents at tick 30,
  159.000 at 60, 182.122 at 120 and 203.392 at 240;
- peak connected Water components: 26;
- peak small components (<=16 cells): 24;
- peak lateral range: 125 cells.

These values do not replace focused H judgement of serpentine/splashy character.

## Surface-reducer v1 review

The reduction code itself is deterministic and its synthetic tests passed, but
baseline use exposed a scope error in the registered *whole-run maxima*.

Examples:

- CS reports a 14.97-cell maximum hill at tick 5. That is the intended compact
  settling mound/front, not a late `hillnipple`. Once the body is near level,
  the same side-band residual is small.
- LS reports a 34.68-cell maximum hill because the registered surface ROI includes
  the intended ledge/drop lip.
- FD reports a 9.96-cell early hill while the released body is still a large
  moving front.
- whole-run quarter-cell terrace-edge turnover is dominated by real bulk/front
  motion, so its raw per-second value is not equivalent to the H notion of a
  settled terrace edge flickering in and out.

These v1 numbers are retained exactly. They must not be cherry-picked as
candidate acceptance scores.

## WL26-v2 correction required before candidate A

The semantic fixtures, quantities, bulk metrics, worker matrix and baseline
source remain frozen. Only the surface-defect *eligibility window/ROI* is
versioned:

- CS hill/terrace/shimmer scoring begins at the first tick starting a 60-tick
  run where the full leveling ROI depth span is <=4 cells. On v1 baseline this
  state-derived onset is tick 843; the tick is not hard-coded for candidates.
- FD hill/terrace scoring begins only after Water first reaches the terminal
  contact column; wall-contact gap remains separately measured from first
  contact. The morphology ROI excludes the immediate gate and terminal-wall
  boundary.
- LS surface-defect morphology excludes the intended drop lip and terminal wall,
  and begins only after its downstream ROI is continuously wet for 60 ticks.
- other fixtures retain their registered surface ROIs from tick zero.
- terrace shimmer uses boundaries associated with a real >=3-column terrace,
  not every quarter-cell classification edge, and records turnover both per
  simulated second and per cell-equivalent of authoritative contour change.
  A low-motion subset uses <=1 cell-equivalent of total ROI L1 change per tick.
- full-run raw maxima remain diagnostic output alongside the registered
  surface-window metrics.

This correction is state-based and frozen before any candidate result exists.
The corrected baseline must be regenerated and retained before Water semantics
change.

## Candidate disposition after corrected baseline

If WL26-v2 reproduces the bulk results above while passing the same conservation,
repeat/worker and observer gates, candidate A is admitted as a bounded
head-scaled local-drive experiment.

The U-tube result is a deliberate limitation check: a radius-bounded candidate
may improve practical free-surface/head response without solving remote saturated
hydrostatics. If it cannot affect UT96-48, that negative result remains evidence;
it is not permission to silently introduce a global pressure solver.

Candidate B remains independent and is compared with the same baseline. Candidate
C remains unregistered unless A and B both justify it.
