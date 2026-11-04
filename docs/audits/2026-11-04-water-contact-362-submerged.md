---
title: WATER-CONTACT #362 submerged-overlap characterization
status: Current
document-kind: audit
scope: Results of the owner-chosen read-only study water_contact.submerged.v1 on source 165352e6 (runtime-identical to main 7ef4856e); why a submerged Rapier body leaves stored Water under its mask, under all four Water families, on Windows and Linux; no coupling, solver, bridge, #347 or default change
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-water-contact-362-submerged-registration.md, 2026-11-04-water-contact-362-phase-a.md, 2026-11-04-water-contact-362-registration.md]
---

# WATER-CONTACT #362 — submerged-overlap characterization

## Finding

**The gap is structural to the current relocation law, not a tuning margin.**
Once a body is under the free surface, the stored Water inside its mask has
**no admissible Empty target within the adapter's reach**. Its probe fan is
filled with Water, or with the floor. The body then rests as an undisplaced
overlay over **62–128 masked Water cells**, essentially its own area, for the
rest of the run. This holds in all four families and in every fast or deep
entry in the matrix.

Neither more reach nor a short push chain would fix it. Most masked cells are
pushed sideways, into Water that continues to the basin walls. A one-cell
vacancy chain of at most four moves that starts at the body border, as #347's
does, reaches Empty for at most 1.6 % of all residual cell-samples, and at most
6.2 % of border cells that have any chain.

| Question (registered) | Answer (28 submerged dynamic rows; both OSes identical) |
|---|---|
| Q1 amount | Median masked Water 62–128 cells against body areas of 96–128 cells. It persists from entry to the 240-tick horizon. The only rows with median ≤ 5 are the low-speed rows (G-D12-V60, G-D24-V15), where the body floats near the surface. |
| Q2 cause | `no_empty_within_reach` in **43–96 %** of residual cell-samples: no probe met Empty, and the fan holds Water (plus possibly floor or masked cells). `hard_or_bounds_only` in **4–56 %**: mostly bottom-face cells against the floor, highest for the flat 16×8 body. This class also absorbs fans that land only on masked or swept Water, because such probes are skipped without being counted. It is therefore an upper bound on purely floor-backed cells. Exclusion under the body mask plus a blocked path is **≤ 0.55 %**, and `empty_path_blocked` is zero. |
| Q3 geometry | Residuals get **lateral** overlap normals in 71–94 % of samples for 8×14 and 4×24 bodies, and 25–39 % for the 16×8 body. Their fan points sideways into Water. |
| Q4 required reach | For **63–100 %** of residual cell-samples, the same fixed-direction probe fan meets no unmasked Empty within 64 cells; adapter reach is `ceil(penetration)+8`. For lateral normals it hits the basin walls and never meets Empty, so more reach in that direction would not help at any length. |
| Q5 push chain | A border-first chain (the masked source steps to an unmasked neighbour, then travels through unmasked Water) of **≤ 4 moves** exists for **0–1.6 %** of all residual cell-samples, and 0–6.2 % of those that have any chain. The **48–98 % "unreachable"** share is mostly **definitional**: interior mask cells have no unmasked neighbour. Interior plus floor-backed cells over body area predict it (8×14: 69.6 % against 69.9 % observed; 4×24: 47.9 % / 47.8 %; 16×8: 76.6 % / 75.8 %). Only the 96-deep rows also exceed the 64-step chain limit to the surface. |
| Q6 threshold | No fixed depth threshold. Relocation continues only while the body carries a small **Empty pocket** trapped at entry (see below). |

P1 holds: the classifier and the adapter never disagree, and the classifier
predicts the adapter's exact destination in the positive control for every
family. P2 holds: the no-Empty class dominates every submerged row except
S-WIDE/IN3 (43 % no-Empty against 56 % hard; S-WIDE/FM3 is 64 % against 35 %).
P3 does not hold as a simple depth: see Q6.

## The carried Empty pocket (kinematic descents)

Prescribed descents isolate the relocation law. A body entering from above the
surface traps about 20 Empty cells under its mask (112 − 92 for the 8×14
body). At one row per step the sweep extent is 1, no larger than the 1-cell
sample spacing (`rasterize_body_sweep`). So only the current pose is masked,
and the exposed top row is an admissible first-probe target in the same
prepare call: exactly one body-width of top-face cells moves into it, before
any liquid tick, and the pocket travels with the body.
Displacement per step equals the body width at every depth (8, 4 and 16 cells
for the reference, tall and wide bodies) down to the floor. The **net displaced
volume stays the trapped pocket**, never the body volume.

| Descent | FM3 | CY3 | PF3 | IN3 | Deepest relocating body top (rows) |
|---|---|---|---|---|---|
| 1 row/step, liquid ticks | 660 moves, residual 92 | — | — | 660, 92 | 80 (floor) |
| 1 row/step, coupling only | 660, 92 | — | — | — | 80 |
| 3 rows/step, liquid ticks | 72, residual 112 | 93, 112 | 76, 112 | 506, 92 | FM 17, CY 20, PF 17, IN 80 |
| 3 rows/step, coupling only | 506, 92 | — | — | — | 80 |
| 8 rows/step, liquid ticks | 38, 112 | — | — | 40, 112 | 8 |
| 16×8 body, 1 row/step | 1,428, residual 76 | — | — | — | 86 |
| 4×24 body, 1 row/step | 286, residual 90 | — | — | — | 70 |

At 3 and 8 rows per step the exposed rows lie inside the sweep raster and are
excluded as targets (`find_ejection_target`). They become targetable only on
the next coupling call, after the liquid tick. At 3 rows per step, FreeMass,
CellularYield and PressureFlow flow into them first; the pocket collapses by
17–20 rows and the body becomes a full 112-cell overlay. Coupling-only descents
and IN, whose resting Water does not fill the pocket, keep the conveyor going.
At 8 rows per step the exposed rows also lie beyond reach, and the pocket is
lost at entry.

## Qualification

| Gate | Windows | Linux |
|---|---|---|
| Stage 1 shakeout | attempt 1 **failed** (classifier ignored the swept mask; 5 disagreements), corrected and retained | — |
| Stage 2 attempt 1 (`77930964`) | **failed** I8 on G-D96-V360/IN3 at both worker counts: one exact-edge mask cell | same failure |
| Stage 2 attempt 2 (`165352e6`) | 38 dynamic + 12 kinematic rows, reducer **passed** | **passed** |
| Classifier positive control (4 families) | predicted = actual `(240, 397)` | same |
| Oracle/adapter disagreement | 0 in every row | 0 |
| All `water_contact.impact.v1` invariants on dynamic rows | passed | passed |
| Configured 1/4 parity (G-D24-V180, G-D96-V360; 6 pairs) | 6/6 identical, including classifier output | 6/6 |
| Cross-OS | — | 38/38 final hashes and all classifier and descent outputs identical to Windows |
| `test_water_contact_impact.gd` after both fixes | 108/0 | 108/0 |
| Reducer negative controls | 9/9 (`test_reduce_submerged_evidence.py`) | — |

Attempt 1's I8 failure was an **observer** defect. `mask_check` used
`Vector2.rotated()`, while the adapter (`rasterize_transform_in`) rotates in
double precision and stores single-precision `Vector2` values. For a body
resting almost level on the floor, the two disagreed on one edge cell. The
check now mirrors the adapter exactly. Attempt 2 is identical to attempt 1 in
all 38 trace digests and every classifier value, which confirms the simulation
was unaffected. The `water_contact.impact.v1` evidence was produced with the
old check and recorded zero mismatches. Its regression passes with the
corrected check, but its 220 rows were not rerun.

Source `165352e6` adds only the fixture, apparatus, runner, reducer and audit
files to main `7ef4856e`. Runtime bytes are unchanged: Windows `ee09f7ab…`
and Linux `0f60213c…`, both equal to their provenance. Linux ran in WSL2 Ubuntu
24.04 on the same machine.

## Commands and evidence

```bash
<godot> --headless --path godot --script res://tests/run_water_contact_submerged.gd -- --out=<abs dir> --stage=2
```

```bash
python tools/water_contact/reduce_submerged_evidence.py <dir> --stage 2
```

Evidence lives in [`water-contact-362-2026-11-04/`](water-contact-362-2026-11-04/):

- `submerged-stage2-{windows,linux}/`: the accepted attempt 2.
- `submerged-stage2-attempt1-{windows,linux}/`: the failed attempt, which its
  reducer rejects.
- `submerged-stage1-windows/` and `submerged-stage1-failed-windows/`: the
  corrected and the failed shakeouts.

Godot logs are not committed.

## Limits

- The classifier replays the documented rule in GDScript; the adapter's own
  per-cell reason is not exported. Agreement rests on zero disagreement, the
  exact positive control and, mainly, on the stage-1 failure. That failure
  shows the disagreement check fires (5 cell-samples) when the sweep is
  ignored. The positive control covers only one unrotated, unswept, top-normal,
  zero-tangent case, with a replayed rather than adapter mask. A per-cell
  destination check against the coupling-only K-R3-N census (506 swept
  relocations) is a recommended strengthening, not done here.
- Two small arithmetic differences can only bias the classifier toward
  "not admissible", so they could hide, never create, a disagreement, and
  only within `empty_only_under_mask` (≤ 0.55 %):
  - `overlap()` computes `half − |local|` in double, while the adapter
    subtracts in single precision; near ties this can flip the normal or
    `ceil(penetration)`.
  - The replayed sweep also excludes the exact current pose.
- Samples are every 4 ticks. Counts are cell-samples, not distinct cells.
- Push-chain length is a geometric lower bound through unmasked Water. It is
  not a proposal, and it ignores whether #347's transaction would admit the path.
- Depth is measured from the initial surface, not the deformed local surface.
- Kinematic descents are forcing experiments. Their wake/pocket behavior
  explains, but does not replace, the dynamic rows.

## Consequences for design (not implemented)

1. **Local relocation cannot displace a submerged body's volume.** Any fix
   must be non-local, must conserve quantity, and must touch the shared
   coupling owner. Candidates:
   - free-surface displacement along a bounded connected Water path;
   - PressureFlow overfill absorption (PF only);
   - accepting the overlay and representing displaced volume only as a body
     impulse, which is today's behavior.
2. **#347's conservative displacement does not address this.** It is
   detachment-only, refuses PF/IN/CY Worlds, and is limited to four moves
   with every destination unmasked. Its chains would cover at most 1.6 % of
   all measured residual cell-samples, an upper bound.
3. **A ballistic spray law (Phase B option 1) would still act on only a few
   relocated surface cells per impact.** That supports keeping Phase B DEFERRED
   until the owner decides whether to admit a non-local displacement design.
4. Any such design is a new coupling-law change and needs owner admission, a
   versioned rule, sequencing with #347/#349/#358 on the shared adapter, and
   acceptance against these two fixtures, unchanged.

## Independent review — 2026-11-04

An independent read-only review of `6da4a101` returned **ACCEPT WITH
CORRECTIONS**. It confirmed the following:

- both stage-2 reductions reproduce byte-equal, and the attempt-1 packets fail;
- every table range and descent row;
- 38/38 cross-OS final hashes, with trace digests that differ between OSes;
- the replay's soundness argument and the ROI handling;
- the `mask_check` fix and the observer-defect conclusion;
- the #347 statements;
- the scope: no production, #347 or #370 path changed.

Corrections applied in this revision:

1. The Q5 "unreachable" share is definitional for interior cells. The border-first
   share is now added, and #347's bound is stated as an upper bound.
2. `hard_or_bounds_only` now carries the caveat about fully masked fans.
3. The pocket mechanism is split by sweep extent (rate 1 versus 3 and 8).
4. The two classifier precision biases are documented, along with the limits
   of the positive control.
5. The P2 exception, the Q2 wording and the Q4 "never" interpretation are
   corrected.
