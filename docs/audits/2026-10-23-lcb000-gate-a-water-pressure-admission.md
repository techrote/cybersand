---
title: LCB-000 Gate A — opt-in experimental pressure admission proposal
status: Planned
document-kind: evidence
scope: Issue #213 Gate A exit artifact — reconciles the owner-approved opt-in Liquid Comparison Build pressure lane with the WEX-005 / #45 Water routing; proposes its experimental admission boundaries; selects no production solver and does not pass LCB-000
canonical-for: [lcb-000-gate-a-pressure-admission]
last-reviewed: 2026-10-23
related-documents: [2026-10-23-wex005-water-evidence-synthesis.md, ../operations/water-hybrid-pressure-extension-programme.md, ../systems/water-design.md, ../decisions/ADR-005-water-model.md, 2026-09-20-issue-49-water-apparatus-v2-baseline.md, 2026-09-20-issue-91-wex001-water-body-baseline.md]
---

# LCB-000 Gate A — opt-in experimental pressure admission proposal

## Status

**Gate A exit artifact: submitted for acceptance.** It counts as accepted only
after the PR carrying it and the
[WEX-005 synthesis](2026-10-23-wex005-water-evidence-synthesis.md) is reviewed,
passes exact-head checks and lands on `main`.

**LCB-000 overall: NOT PASS.** Gates B–E have no accepted evidence (see
[gate ledger](#lcb-000-gate-ledger)). Under
[#213](https://github.com/techrote/cybersand/issues/213), LCB-001
([#200](https://github.com/techrote/cybersand/issues/200)) pressure
implementation/porting and state/schema freeze stay **BLOCKED** until all five
gates pass. Accepting Gate A alone removes the #95/#45 routing blocker for the
*experimental* lane. It admits no code.

Source basis: `main` `9012425e3bba62aa1fefb15ea5d7306f196b8da2`, plus the
identities recorded in the WEX-005 synthesis.

## Gate A checklist (issue #213)

| Gate A item | Evidence | State |
|---|---|---|
| Read the canonical WEX/Water/ADR-005 routing, the source-matched #49 apparatus, #91, #92 (blocked), #93 and #94 | [WEX-005 synthesis — inputs and evidence matrix](2026-10-23-wex005-water-evidence-synthesis.md#evidence-matrix); current-main #49 rerun 39739371203 | Done |
| #95 disposition separating deep surge / vented communicating head / sealed gas, with an explicit #45 disposition, no invented #92 outcome | WEX-005 Q1, Q4 and Q3 (**#45 NARROW**); #92 = still blocked | Submitted (becomes canonical on merge) |
| Separately scoped opt-in LCB experimental admission | [Admission proposal](#experimental-admission-proposal) below | Submitted |
| Canonical disposition cross-referencing #95/#45/#200 with boundary assumptions, fixed controls, unacceptable regressions and the production gate | This record; mirrored in the [WEX programme](../operations/water-hybrid-pressure-extension-programme.md#lcb-experimental-pressure-lane-reconciliation-2026-10-23) and the [Water contract](../systems/water-design.md#wex-005-disposition-and-the-opt-in-lcb-lane-2026-10-23) | Submitted |

#95 and Gate A do not conflict. WEX-005 leaves #45 as the *production* owner
(NARROW). The LCB lane is an *opt-in research comparison* that WEX-005 explicitly
neither waits for nor treats as #45 completion. Owner permission for LCB is not
used here to bypass #95: the routing is decided by the synthesis first.

## Experimental admission proposal

Once **all five** LCB-000 gates pass, LCB-001 may port and integrate, as an
**opt-in, side-by-side experimental family**:

- `pressure_flow_v1` — the corrected pressure/overfill/horizontal-flow/gas
  candidate — with the implementation variants `reference`, `cached` and
  `cached_dormant` (legacy arm IDs `pressure`, `pressure_cached`,
  `pressure_dormant`; #201 owns cache/dormancy);
- selected only by an immutable, validated, versioned per-World policy with
  effective-policy readback (#213 Gate C). No hidden fallback to Current, to
  another family or to GDScript;
- running in the **same native World authority**: per-material assignment, no
  independent liquid world (ADR-005 rejects one);
- with Water as a controlled common test material (#213 Gate D), while
  everyday Water stays `freemass_v1` / mass8 / coherence12.

The admitted *purpose* is manual feel comparison plus registered automated
comparison. Results are research evidence.

### Explicitly not implied

Admission of the experimental lane does **not**:

1. switch any default, remap everyday Water, or change Current golden behaviour;
2. select a production #45 mechanism or complete #45, #95, #14 or #18;
3. grant #12 Stage 4 / dynamic soliding authority or create a Water-only hybrid
   backend;
4. add new pressure-to-Rapier forces or buoyancy. Body interaction stays the
   existing generic coupling path (REM-002 semantics), and toy buoyancy is not
   evidence;
5. admit a production gas-region/atmosphere owner (#93 stays research only) or
   production decompression (#94 stays narrow-use);
6. admit #18 compact directional history (LCB-005 inertial is separate);
7. unify liquids or change FreeMass/CellularYield defaults;
8. amend ADR-005, migrate the Cell carrier, or freeze save/schema (Gate B owns
   the state/storage handoff);
9. turn the archived `7ef2aac` prototype measurements into acceptance evidence.

### ADR-005 relationship

ADR-005 governs Current production Water and is not amended. The experimental
family must still meet these invariants *within its own declared state*, or
report any deviation as an experimental result rather than hide it:

- exact integer conservation in closed operations, **including** hidden overfill
  and any gas-amount ledger, with explicit source/sink accounting;
- equivalent resting states stop exchanging mass, or bounded residual churn is
  declared and measured (owner tolerance for small residuals is preference
  context, not a waiver of measurement);
- presentation/dither never alters authority;
- a versioned complete physical-state hash covering every authoritative candidate
  field (historical hashes are not redefined);
- deterministic worker parity for the declared configuration.

Production adoption of any of this requires an ADR-005 amendment.

## Boundary assumptions

| Configuration | Gas/boundary model | Equal-level target? | Use |
|---|---|---|---|
| Water + `freemass_v1` + `reference` (Current) | No gas state; `Empty` is one implicit shared atmosphere | Yes, in vented fixtures; Current is `not_reached` there | Protected control |
| `pressure_flow_v1`, vented scenes | Shared atmosphere at every free surface | Yes (vented control) | Head/leveling comparison against the #49 v2 fixtures |
| `pressure_flow_v1` with sealed air | Experimental stored gas amount per sealed pocket; pressure derived from amount and volume | **No.** The target is a gas-pressure-dependent level difference, preregistered per fixture | Experimental only; must pass the #200 gas-defect regressions |
| Low-pressure/vacuum boundary | Not modeled by Current or the LCB candidate | No | Out of scope; #94 local events only |

Deep-release/surge comparisons use a separately registered Dam Break family
(#213 Gate E, `lcb.dam.water.freemass.reference.v1`). They never reuse an
equalization metric.

## Fixed numerical controls

These are held constant and must reproduce under the default policy:

- **#49 apparatus v2**, unchanged schemas `water-evidence-runner-v2`,
  `water-apparatus-v2`, `water-fixtures-v2`, `water-equilibrium-v2` and their
  preregistered thresholds. Original control: run `35536086473` (artifact
  `10613591045`). Current-main control: run `39739371203` (artifact `12409012082`,
  `source_sha256 f698cf52…3919`, binary `b88de6e6…3f41`). LCB pressure results
  are reported as separate arms and never overwrite those controls.
- **Native Water fixtures** named in the
  [Water contract](../systems/water-design.md#how-should-i-diagnose-a-shimmering-pool):
  `test_conserved_water_levels_and_sleeps`, `test_water_surface_column_mass_is_level`,
  `test_water_conserves_across_storage_boundaries`.
- **WEX-001 regression** (`godot/tests/test_wex001_water_body_baseline.gd`): zero
  forbidden-floor Water mass and 1/4-worker equality under Current.
- **Water policy ranges:** mass precision 3–8 and coherence 0–12 (#19 policy).
  Defaults are mass8/coherence12. Candidate thresholds scale with precision; no
  hidden 255-unit assumptions.
- **Worker parity:** 1-worker and 4-worker authoritative equality for every
  registered comparison case.
- **Bounded work:** zero post-setup tick-time allocation in apparatus runs, with
  explicit capacity refusal.
- **Lifecycle:** #199 Water exit acknowledgements and failed-tick quarantine
  (ADR-010) unchanged.

## Unacceptable regressions (stop conditions)

Any of these blocks LCB-001 merge:

- any change to Current/default results: golden native hashes, #49 v2 control
  outcomes, WEX-001 zero-forbidden result, or existing transport-profile
  reference fixtures;
- a requested family that silently runs another family, Current or GDScript;
- unaccounted quantity loss or duplication, including overfill or gas amount;
  silent truncation of fractional Water;
- authoritative candidate state missing from the versioned physical-state hash,
  save/readback or quantity APIs;
- worker-count nondeterminism, data races, or Godot/Rapier calls from native
  workers;
- unbounded or tick-time allocation outside admitted preparation boundaries;
- reappearance of the reviewed #200 gas defects (pocket amount cycling, unequal
  merge loss, stale reseal, unhashed gas changes);
- any new pressure-derived force on Rapier bodies;
- a refused policy application that loses the live session.

## Production gate

Any production use of a pressure mechanism needs its own separately admitted
gate:

1. #45 NARROW admission evidence (registered surge and vented-head fixtures,
   frozen thresholds from the current-main #49 v2 control) and candidate results;
2. focused owner H review;
3. an ADR-005 amendment for the new authoritative state;
4. a Gate B / #204 storage decision (Cell carrier stays the 64-bit fallback
   unless a separate migration is admitted);
5. a separate implementation and default-switch issue with rollback;
6. the full Native, GDExtension/Godot, Water apparatus and documentation gates
   on the exact head, plus intended-platform runtime evidence.

Gas-region production (#93) and decompression production (#94) each need their
own owner and admission as well.

## Evidence classification of the archived prototype

`claude/water-pressure-prototype` at `7ef2aacf…` (patches on `620826f5…`):

- exploratory, local Windows/MSVC, unregistered scenes, owner sandbox feedback;
- defects confirmed by the 2026-10-22 review recorded in #200;
- its default `content_hash` excludes the spare bits that hold overfill and air;
- **use:** the candidate source LCB-001 ports and corrects, and a candidate
  *family* #45 may list during admission;
- **not usable as:** #45/#95 acceptance, a threshold source, or proof of surge
  improvement.

## LCB-000 gate ledger

| Gate | Owner input | State on 2026-10-23 |
|---|---|---|
| A — #95/#45 reconciliation and experimental admission | This record + WEX-005 synthesis | **Submitted.** Accepted only after merge and verification on `main`. |
| B — #204 state/storage handoff | [#204](https://github.com/techrote/cybersand/issues/204); draft PRs #208/#211 hold untimed feasibility | **Not satisfied.** No qualified handoff yet. |
| C — four-family policy/compatibility specification | #213 / #200 / #212 | **Not produced.** |
| D — Water as common controlled material for all four | Owner decision YES recorded in #213 | **Owner decision recorded; comparison contract not produced.** |
| E — Dam Break and mixed-liquid fixtures | #213 / #200 | **Not registered.** No source-matched preset exists. |

**Integrated decision: BLOCKED** for LCB-001 pressure implementation and
state/schema freeze. Under #213, read-only inventory, policy/API and UI design,
and provisional manifests may continue.
