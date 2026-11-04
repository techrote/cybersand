---
title: WATER-CONTACT #362 Phase A four-family Rapier impact discrimination
status: Current
document-kind: audit
scope: Issue 362 Phase A results for water_contact.impact.v1 on main 3da7e7be source (runtime-identical at 7ef4856e); mechanism discrimination of relocation, transport, retained IN state and ballistic launch; Windows and Linux native plus actual Rapier execution; ballistic-spray feasibility and handover; no physics, coupling or default change
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-water-contact-362-registration.md, 2026-11-03-lcb-reassessment.md, 2026-09-20-issue-91-wex001-water-body-baseline.md, 2026-09-24-rem002-issue11-integration-forensics.md, ../architecture/inertial-cellular-v1.md, ../architecture/pressure-flow-v1.md, ../operations/architecture-programme-prompts/sparse-motion.md]
---

# WATER-CONTACT #362 — Phase A results

## Finding

**Current CyberSand Rapier↔Water splash is collision-driven cell relocation,
followed by ordinary liquid transport that only lowers or spreads it.** None of
the four liquid families launches Water ballistically, and there is no upward
momentum anywhere in the current source. Across 11 registered cases × 5 arms ×
2 worker counts on Windows and Linux, the observed effects are small:

- the highest Water reaches at most **6 rows** above the initial surface;
- the spray band (rows `y < surface − 4`, i.e. ≥5 rows above the surface) never
  holds more than **4 cells** (1,020 units) at once;
- **all spray-band gain is relocation**. No tick in any run had a net positive
  solver change in the band. The decomposition is per-tick net, so a rise and a
  fall inside one tick would cancel; the D3 peak-rise counter covers part of that.

PressureFlow is the only family whose liquid tick lifts Water at all. It rises
by 1 row at a time, pushed by pressure redistribution next to the body, and
never reaches the spray band.

A second finding limits any future spray more than the missing velocity law:
**a submerged body stops displacing Water.** The adapter relocates each source
cell only to an Empty, unmasked cell within `ceil(penetration)+8` cells along
its outward normal, with tangent offsets up to ±4. The path check blocks only
other bodies and hard terrain; Water on the path is allowed. Most interior
cells of the 8×14 body get lateral normals. Once the nearest Empty cell is
beyond that per-cell reach, the overlap is `unresolved` and the Water stays
stored under the body mask. In S-H-C the resting top face is about 10 rows
below the surface, just past the 9-row reach. In the high-speed cases that
reach the floor in 24–72-deep Water (S-H-C, S-H-O, S-H-W, D-H-C, D-H-R), this
leaves a median of **80–112 masked Water cells** for the rest of the run
against a body area of 112, an undisplaced overlay. Near-floor N-H-C (depth 8)
and the low-speed rows keep a median of 0–1. The impulse feedback still acts
on Rapier whether or not a cell moved.

Phase A therefore concludes **“upward ballistic IN absent; spray is bounded
relocation”**. It recommends **further characterization of the submerged-overlap
gap, then DEFER** for any Phase B law. No Phase B work was started.

## Source and runtime identity

| Item | Value |
|---|---|
| Accepted main at registration | `3da7e7be4a6af4c85e03a7d8a0ed57229e5db33d` |
| Main at publication | `7ef4856e` (#371 MAT-AUTH shadow catalogue: `materials/`, `tools/material_catalogue/`, docs, `documentation.yml` only; no native, Godot-script, runtime or provenance delta) |
| Measured source | branch `claude/rapier-water-splash-discrimination-dc6b5c` at `cb777c60` (registration commit; adds only fixture/test/tool/audit files) |
| Manifest | `water_contact.impact.v1.json`, SHA-256 `8ed2f478b99fd79f2afbd9e32bbc4f472fd2b91f8f2855bf3fecbfe915b4218b` |
| Windows native runtime | `cybersand_native.windows.x86_64.dll` `ee09f7ab…7199a`, equal to `runtime-provenance.json` (build `a7ee10f2`) |
| Linux native runtime | `libcybersand_native.linux.x86_64.so` `0f60213c…6cf45`, equal to `runtime-provenance.linux.json` |
| Rapier | Godot `RapierPhysicsServer2D`, Rapier2D v0.35.2 (Windows DLL `b54e54bd…10dd7`); `physics/2d/physics_engine = Rapier2D` asserted per run |
| Godot | 4.7.stable.official `5b4e0cb0f` (Windows console and Linux x86_64) |
| Windows host | Windows 11 Pro 10.0.26300, AMD64, 12 logical processors (shared with the concurrent Linux run) |
| Linux host | WSL2 Ubuntu 24.04, kernel 6.18.54.1-microsoft-standard-WSL2, same physical machine |

The Linux checkout is a `GIT_LFS_SKIP_SMUDGE=1` clone of `cb777c60`. The two
Linux runtime libraries were copied in with their provenance-matching bytes, so
its packet lists them as modified pointer files. Windows lists only untracked
Godot-generated `.uid` files. Neither run changes any measured source.

## Commands

```bash
python tools/water_contact/run_campaign.py --godot C:/tools/Godot/Godot_v4.7-stable_win64_console.exe --out <dir> --stage 2 --workers 1,4 --timeout 7200
```

```bash
python3 tools/water_contact/run_campaign.py --godot <Godot_v4.7-stable_linux.x86_64> --out <dir> --stage 2 --workers 1,4 --timeout 9000
```

```bash
python tools/water_contact/reduce_impact_evidence.py <dir> --stage 2 --workers 1,4
```

```bash
<godot> --headless --path godot --script res://tests/test_water_contact_impact.gd
```

The wrapper records `packet.json` (source head/tree/dirty paths, runtime hashes,
Godot version, exact command, timeout, duration and exit code) and runs the
reducer. The stage-1 gate (S-H-C, C0S, C1; 30 rows + 20 probes) passed every
invariant on Windows before stage 2 began. Retained evidence:
[`water-contact-362-2026-11-04/`](water-contact-362-2026-11-04/).

- `windows/` and `linux/`: every stage-2 record (minified JSON), kinematic
  probes, index, wrapper `packet.json` and `reduction.json`. Rerun the reducer
  on either directory to reproduce the reduction.
- `windows-stage1/`: the collection-time stage-1 reduction, probes and index.
  The 30 raw stage-1 records repeat stage-2 cases and are not retained, so
  running the reducer on that directory reports them missing.

Godot logs are not committed.

## Qualification

| Gate | Windows | Linux |
|---|---|---|
| Stage 2 rows (11 cases × 5 arms × workers 1/4) | 110/110 ok, reducer **passed** (1,698 s) | 110/110 ok, reducer **passed** (1,760 s) |
| Kinematic probes (5 arms × 4 modes) | 20/20 | 20/20 |
| I1/I2 exact quantity and containment (ROI every tick, complete World every 10 ticks and final) | 0 violations | 0 violations |
| I3 applied policy/radius/backend/workers and runtime provenance, Rapier active | all rows | all rows |
| I5 relocation census (`BodyDisplacement` events = coupling `displaced` = in-ROI grid difference) | every tick of every row | every tick of every row |
| I6 carried state (sources before coupling vs destinations after coupling, before the tick) | 0 mismatches | 0 mismatches |
| I7 IN `vy ≥ 0` (every 2-tick census and every relocated destination) | 0 negative | 0 negative |
| I8 body mask equals current-pose rasterization | 0 mismatched cells | 0 mismatched cells |
| I9 configured-1 vs configured-4 trace digest, final physical-state hash and coupling totals | 55/55 identical | 55/55 identical |
| I10 duplicate snapshot and aged result refused by the unchanged bridge | refused (S-H-C, all arms) | refused |
| I11 Rapier body floor penetration (WEX-001 two-cell characterization tolerance) | max 0.0042 cells; wall max 0.060 | max 0.0044 cells; wall max 0.0011 |
| Focused regression `test_water_contact_impact.gd` | 108 assertions, 0 failures | 108 assertions, 0 failures |
| Reducer negative controls (20 corruption classes, including vacuous I6, + valid packet) | 21/21 tests | — |

The near-floor (N-H-C) and wall-adjacent (S-H-W) controls are the hard-boundary
controls. In both, the body reaches the floor or wall (contact by ticks 4 and 9)
and no Water crosses either barrier. This preserves the REM-002 no-crossing
contract; WEX-001's historical floor crossing remains a recorded historical defect.

## Mechanism discrimination

| Mechanism | Present in current source? | Evidence |
|---|---|---|
| **A. Collision-driven relocation** | **Yes — the only splash source.** `prepare_rigid_body_coupling` → `reconcile_overlap` → `find_ejection_target` → `World::relocate_stored_cell` (native adapter); GDScript fallback mirrors it (`_find_body_ejection_target`, `_move_material_for_body`). | Kinematic probe, overlap modes: every family moves the probe cell exactly 3 rows (`ceil(2.5)`) along the overlap normal. Swept mode (`swept-up-20`): every family leaves the cell unrelocated (displaced 0, unresolved 1, state identical). Its outward direction is the travel direction, and every target in reach lies inside the swept mask. Dynamic runs: relocations are 97 % upward (`dy < 0`), at most 6 rows above the initial surface. |
| **B. Subsequent liquid transport** | Yes, ordinary family law. | Net per-tick solver above-surface gain is **0** in FreeMass, CellularYield and IN in every row: no tick of theirs added net above-surface Water. Gross within-tick rises are not separately measured. PF lifts 11,342 units over the configured-1 rows (32 one-row rises; 22,684 units and 64 rises across all 110 Windows rows), all below the spray band. Transport B includes each solver's response to the moving obstacle mask and coupling wake/pressure-input invalidation (`world.cpp` `move_cell`). |
| **C. Retained IN momentum** | Retained, never upward. | Relocation carries `(vx, vy, ax, ay)` unchanged. The probe cell kept `vy=+21` (downward) after being moved 3 rows up; its next tick converted contact into lateral `vx=-15`, `vy=0`. Dynamic IN max `vy` 12–18, never negative. The IN setter, kernel and physical-state codec all refuse `vy < 0`. |
| **D. True ballistic launch** | **Absent.** | No coupling path writes velocity from body velocity or impulse. Probe destinations and states are identical for body velocities 0, 600 px/s up and 600 px/s sideways. The fallback's `_try_sparse_ballistic_move` is downward-only two-cell free fall (upward only for Smoke), a cadence-LOD path, not launch. |
| **E. Presentation** | Not measured as transport. | All metrics use stored state from `diagnostic_snapshot` and `water_experiment_observation`. PF overfill is counted in quantity, never rendered. |

Cells have no stable identity, so FreeMass, CellularYield and PF have no
trajectory, launch angle or velocity estimate. Region motion is reported only as region motion.

**Check bounds.** These checks are bounded, not exhaustive:

- **I6:** runs on at most 40 relocating ticks per row, giving 10–40 complete
  checks per body row and 0 incomplete. The reducer now requires at least one
  check whenever cells were displaced.
- **I7:** the census covers Water above the initial surface every 2 ticks,
  plus up to 4,096 relocated destinations. The IN kernel's `vy < 0` throw
  backstops cells below the surface.
- **I8:** sampled every 2 ticks.
- **I5:** `BodyDisplacement` is recorded for any `move_cell` outside a tick
  (`world.cpp`). It equals relocation here only because nothing else in this
  fixture moves cells outside a tick.

The `unresolved` column counts overlap-ticks, which are recounted every tick.
It includes swept-trail cells (their outward direction is the travel direction)
that become unmasked after the final-pose rasterization. That is why
low-speed rows show 694–1,104 with masked p50 0.

### Cross-family results (Windows, configured 1 worker; 4-worker rows are identical)

| Case | Arm | Displaced | Unresolved overlap-ticks | Masked Water p50 | Up / lat / down relocations | Peak rows above | Spray-band peak (units) | Solver above-surface gain | Body floor contact |
|---|---|---:|---:|---:|---|---:|---:|---:|---:|
| S-L-C | FM3 | 34 | 931 | 0 | 33/1/0 | 2 | 0 | 0 | — |
| S-L-C | CY3 | 24 | 825 | 0 | 23/0/1 | 2 | 0 | 0 | — |
| S-L-C | PF3 | 19 | 792 | 0 | 19/0/0 | 2 | 0 | 2,127 | — |
| S-L-C | IN3 | 40 | 694 | 0 | 32/6/2 | 4 | 0 | 0 | — |
| S-H-C | FM3 | 75 | 29,388 | 99 | 75/0/0 | 3 | 0 | 0 | 9 |
| S-H-C | CY3 | 84 | 28,496 | 96 | 84/0/0 | 3 | 0 | 0 | 9 |
| S-H-C | PF3 | 78 | 28,518 | 96 | 78/0/0 | 3 | 0 | 1,420 | 9 |
| S-H-C | IN3 | 80 | 28,224 | 95 | 80/0/0 | 4 | 0 | 0 | 9 |
| D-L-C | FM3 | 31 | 870 | 0 | 31/0/0 | 2 | 0 | 0 | — |
| D-L-C | CY3 | 31 | 858 | 0 | 29/2/0 | 2 | 0 | 0 | — |
| D-L-C | PF3 | 32 | 1,104 | 0 | 32/0/0 | 2 | 0 | 850 | — |
| D-L-C | IN3 | 32 | 743 | 1 | 26/4/2 | 4 | 0 | 0 | — |
| D-H-C | FM3 | 72 | 33,538 | 112 | 72/0/0 | 3 | 0 | 0 | 26 |
| D-H-C | CY3 | 88 | 33,515 | 112 | 88/0/0 | 3 | 0 | 0 | 26 |
| D-H-C | PF3 | 72 | 33,554 | 112 | 72/0/0 | 4 | 0 | 69 | 26 |
| D-H-C | IN3 | 303 | 28,717 | 96 | 303/0/0 | 4 | 0 | 0 | 26 |
| S-H-O | FM3 | 73 | 29,971 | 101 | 73/0/0 | 3 | 0 | 0 | 9 |
| S-H-O | CY3 | 84 | 28,501 | 96 | 84/0/0 | 3 | 0 | 0 | 9 |
| S-H-O | PF3 | 78 | 28,512 | 96 | 78/0/0 | 3 | 0 | 1,095 | 9 |
| S-H-O | IN3 | 80 | 28,227 | 95 | 80/0/0 | 4 | 0 | 0 | 9 |
| D-H-R | FM3 | 136 | 33,934 | 112 | 129/4/3 | 5 | 255 | 0 | 28 |
| D-H-R | CY3 | 245 | 29,624 | 112 | 241/1/3 | 5 | 255 | 0 | 28 |
| D-H-R | PF3 | 135 | 33,922 | 112 | 129/4/2 | 5 | 255 | 8 | 28 |
| D-H-R | IN3 | 503 | 24,574 | 80 | 496/3/4 | 5 | 1,020 | 0 | 29 |
| S-H-W | FM3 | 59 | 31,190 | 105 | 59/0/0 | 4 | 0 | 0 | 9 |
| S-H-W | CY3 | 72 | 28,557 | 96 | 72/0/0 | 4 | 0 | 0 | 9 |
| S-H-W | PF3 | 65 | 29,440 | 99 | 65/0/0 | 4 | 0 | 1,000 | 9 |
| S-H-W | IN3 | 72 | 28,557 | 96 | 72/0/0 | 5 | 255 | 0 | 9 |
| N-H-C | FM3 | 55 | 542 | 0 | 55/0/0 | 3 | 0 | 0 | 4 |
| N-H-C | CY3 | 47 | 953 | 1 | 44/3/0 | 3 | 0 | 0 | 4 |
| N-H-C | PF3 | 48 | 710 | 0 | 43/1/4 | 4 | 0 | 4,773 | 4 |
| N-H-C | IN3 | 111 | 1,033 | 0 | 74/34/3 | 6 | 510 | 0 | 4 |

The body-free controls (C0S, C0D) have no coupling, no above-surface Water and
no motion; after three start-up ticks every family reports zero task claimants,
yet PF still spends ~13–16 ms per tick outside claimed pool dispatch. The
no-Water control (C1) reaches the floor at tick 9 with zero Water and zero
relocations. **FM2 (radius 2) matches FM3** in every recorded observable:
all 11 cases have identical sampled series, body traces and coupling totals.
Their final physical-state hashes still differ, because that hash also binds
non-cell construction and scheduler state, so cell-for-cell identity is not
claimed. Radius has no observable effect on FreeMass in this fixture.

### Interpretation by family

- **FreeMass / CellularYield.** These are pure relocation then settling, and
  near-identical. Spray-band Water appears only in the rotating case: one cell,
  returned within 1–2 ticks for FreeMass. CY's single cell reached the band
  late, at tick 291, and was censored at the horizon.
- **PressureFlow.** This is the only family whose liquid tick raises Water. PF
  redistributes the body's displacement through pressure (overfill up to 7,984
  units in N-H-C) and lifts the surface by single rows beside the body. That is
  pressure-driven level change, not flight; the gas ledger closes in every
  observation. PF reference costs ~14–16 ms per tick even when the pool is at
  rest, against tens of µs for the other sleeping families. That cost belongs to
  PF cache/variant work (#363), not this issue.
- **Inertial (IN).** IN relocates 2–4× more cells in the deep and rotating cases.
  Its retained lateral motion keeps refilling the body's path, and the refilled
  cells are relocated again. It produced the largest spray-band peak in D-H-R:
  the band was non-empty for ticks 5–23 and peaked at four cells, all by relocation. Contact converts
  downward IN momentum into lateral motion (`kDeflect` 3/4), never upward.

### Worker participation and cost

Configured workers are not actual participants. With four configured, the
maximum distinct task claimants per tick was mostly 1–2. Four claimants
appeared on up to 179 ticks in PF rows (Windows D-L-C PF3 179; Linux at most
94) and on 63–102 ticks in deep IN/PF rows on Windows, but on only 2–6
start-up ticks in most other rows.
Participation is scheduling-dependent and differs between runs and OSes,
while simulated state stays identical (I9). Median native tick cost on Windows (configured 1):

| | FM3 | CY3 | PF3 | IN3 |
|---|---:|---:|---:|---:|
| S-H-C | 1.18 ms | 0.91 ms | 13.97 ms | 0.64 ms |
| D-H-C | 0.82 ms | 2.27 ms | 15.24 ms | 2.36 ms |
| C0D (at rest) | 0.02 ms | 0.02 ms | 15.75 ms | 0.02 ms |

Coupling preparation was 0.2–0.3 ms and the Rapier step about 0.11 ms. These
are headless call durations on a host shared with the concurrent Linux run,
recorded as advisory host costs; they are not displayed FPS.

## Linux execution

Linux ran the same source, manifest and command with the Linux Godot binary and
provenance-matching Linux runtimes. It passed every invariant and 55/55
worker-parity pairs, and its 20 kinematic probe records are identical in content
to Windows (the files are not byte-identical). Every mechanism conclusion above holds on Linux unchanged.

**Cross-OS identity is observed, not contracted.** The final physical-state
hash matches Windows in 104/110 rows. The six that differ are D-H-C IN3 and
S-H-C FM2/FM3, at both worker counts. Their displaced and unresolved counts
are identical; only `contacts` differ, by 3–6. Separately, D-H-R FM2/FM3 and
S-H-O IN3 differ by exactly one unresolved overlap-tick over 300 ticks, yet
their final hashes match. Sixteen rows differ in `contacts`. Displaced
counts, peaks and decomposition are equal everywhere. Only 50/110 trace
digests match. Those digests include raw Rapier body-state floats; the
body-free rows match. The divergence is consistent with platform
floating-point differences in Rapier. The fixture registers same-OS 1/4-worker
parity, not cross-OS bit identity, so this is a recorded limitation, not a
failure.

Linux host costs differ from Windows (for example, D-H-C IN3 median 9.6 ms
against 2.4 ms). Both ran concurrently on the same machine under WSL2, so the
numbers are advisory only. PF's high resting cost and the configured-versus-
actual participant pattern reproduce.

## Comparison with WEX-001 and REM-002

This experiment reuses WEX-001's barrel body unchanged. It agrees with WEX-001's
source-matched result that a moderate shallow impact relocates Water and raises
above-surface mass, while the body-free controls create none. Unlike historical
WEX-001, current source crosses no hard boundary: every row has zero Water
outside the basin interior, as REM-002 requires. The WEX-001 and REM-002
fixtures and historical evidence were not rerun or modified.

## Missing interfaces (recorded, not implemented)

1. **Per-relocation destination and distance trace.** The adapter exports only
   aggregate `displaced` and `unresolved` counts. Destinations are recovered here
   from copied ROI grid differences and direction signs from the physics
   histogram. A full source→destination table would need coupling-owner
   instrumentation in `cyber_native_cell_world.cpp`, which is shared with
   #347/#349/#358.
2. **IN momentum ledger readback.** `InertialLedger` (external/impulse/retired
   terms) is not bound to Godot. Carried-state identity uses
   `inspect_inertial_cell` tuples instead.
3. **Masked Water quantity.** Not exported. It is computed here from stored
   snapshot bytes because `material_at()` is occupancy-masked.

## Ballistic-spray feasibility (Phase B — not started)

Any physical spray law can act only on **relocated** cells: 20–500 per impact
here, never a submerged body's volume. Fixing the submerged-overlap gap is
therefore a precondition for meaningful spray volume.

| Criterion | Option 1: IN momentum injection | Option 2: bounded detached-cell flight (#20) | Option 3: presentation-only spray |
|---|---|---|---|
| Quantity conservation | Exact (state rides existing cells) | Exact only with a reserved/escrowed carrier and reintegration ledger | Unaffected (nonphysical) |
| Momentum / energy | Needs a signed `vy` domain, upward gravity deceleration, and an external-impulse ledger term tied to body impulse | Carrier owns velocity; body impulse must be debited once | None; must be labelled nonphysical |
| Body impulse interpretation | Inject a fraction of `-impulse/mass_cell` capped by `kVmax`; double counting against the existing displacement reaction must be ruled out | Same, per launched parcel | n/a |
| Terrain and mask collision | Existing IN contact rules, but upward travel needs new ceiling/mask contact and rest rules | New swept collision vs hard terrain and all body masks | Visual only |
| Reintegration | None needed (cells never leave the grid) | Must land without loss or duplication; refusal path when blocked | n/a |
| Lifetime / capacity | Bounded by existing per-cell state | Fixed parcel budget, explicit capacity outcomes | Fixed effect budget |
| Determinism / workers | Must keep radius-3 ownership and 1/4 parity; upward reach must stay within the radius | New phase owner; ordering and parity needed | Presentation thread only |
| Memory / tick cost | ~0 extra state; small kernel cost | Sparse carrier plus sweep cost | GPU only |
| Serialization / restart | Codec currently **refuses** `vy < 0`: new state format, hash version and policy version | New serialized carrier | None |
| Families covered | IN only | All families | All (visual) |
| Gameplay feel | Real arcs for IN only, limited by relocated-cell count | Most convincing | Convincing but not material |
| Admission | New law version (`inertial_cellular_v2` or a new variant), owner-approved | Blocked by #18/G-M and #20 G-B admission | Lowest risk; still needs a nonphysical label |

**Ranking.** Option 3 is cheapest and lowest-risk, but it is not physics.
Option 1 is the most coherent physical extension, but only for IN and only
after a versioned law change. Option 2 remains blocked by #20's existing gates.

**Recommendation: further characterization, then DEFER Phase B.** The concrete
gap Phase A exposes is the submerged-body overlay, not a missing velocity term.
Spray would stay at a few relocated cells per impact even with a perfect
ballistic law.

## Handover

1. **Next (characterization, no law change):** the coupling owner should
   register a read-only submerged-overlap characterization: masked quantity,
   unresolved-by-reason, ejection-reach failures by depth and speed. It needs
   interface 1 above, so sequence it after or with #347, whose structural
   conservative displacement may already address the push-chain/reach limit.
   Reuse this fixture and reducer unchanged.
2. **If the owner later wants physical spray:** admit Option 1 as a separately
   versioned opt-in IN law. It needs a signed `vy` domain with gravity
   deceleration, upward contact/rest rules, an external-impulse ledger term,
   codec/hash version bump, radius-3 reach proof and 1/4-worker parity. Acceptance should reuse
   `water_contact.impact.v1`, including D1/D3: spray-band solver gain would
   then become nonzero and must be booked against body impulse.
3. **If only appearance is wanted:** Option 3, explicitly labelled nonphysical,
   in presentation code, with no authoritative-state change.
4. Do not start Option 2 without #18/G-M and #20 G-B admission. Do not change
   `inertial_cellular_v1/reference`, defaults, per-droplet Rapier bodies or
   liquid creation.

#362 stays open; closure needs the owner's assessment of this report. Phase B requires
explicit owner authorization.

## Follow-up: submerged-overlap study — 2026-11-04

Handover item 1 was carried out as the owner-chosen read-only
[`water_contact.submerged.v1` study](2026-11-04-water-contact-362-submerged.md).
It confirms the overlay is structural. Masked Water has no Empty target within
reach, mostly because lateral normals point into Water. More reach or a push
chain of at most four moves would not resolve it. Only a non-local, owner-admitted
displacement design could. Phase B remains DEFERRED.

## Independent review — 2026-11-04

An independent read-only review of `d618c4d4` returned **ACCEPT WITH
CORRECTIONS**. Without running Godot, it re-derived the following from source
and the committed packets, and they hold:

- the mechanism conclusions;
- histogram decoding, stored-byte observation and the A-skip premise;
- both reductions (identical output);
- runtime hashes against provenance and LFS object IDs;
- all 32 table rows, and the headline figures (97 % upward, peak 6, band peak
  1,020, solver band gain 0, 55/55 parity);
- the feasibility ranking and the DEFER conclusion;
- scope: no production, #347 or #370 file changed.

Corrections applied in this revision:

1. The cross-OS hash-difference rows were misattributed; they are rewritten
   with the correct rows.
2. The spray-band definition is ≥5 rows above the surface, not ≥4.
3. The submerged-overlap mechanism is restated as per-cell reach, and
   `unresolved` is labelled as overlap-ticks that include swept-trail cells.
4. The solver-gain figures are qualified as per-tick net.
5. The swept-probe outcome is reported.
6. The check bounds are disclosed, and a reducer guard now rejects a vacuous
   carried-state check.
7. Participation counts, PF totals and the D-H-R band duration are corrected,
   and probe identity is qualified.

The review did not run the GDScript regression; it passed separately on both OSes.

