---
title: LCB scenario catalogue and controlled runner
status: Current
document-kind: runbook
scope: LCB-003 (#202) / LCB-000 Gate E (#213) — versioned liquid comparison scenario catalogue v1, source-derived scenario registry for the LCB UI, controlled native-only runner, regressions, negative contracts and blocked future-family arms
canonical-for: [lcb-scenario-catalogue]
last-reviewed: 2026-10-25
related-documents: [lcb-water-comparison-and-fixtures.md, lcb-manual-comparison-ux.md, ../architecture/liquid-solver-family-policy.md, microscenarios.md, ../audits/2026-10-23-lcb003-scenario-qualification.md]
---

# LCB scenario catalogue and controlled runner

## Status

**LCB-000 Gates A–E PASS; #213 closed completed (2026-10-24).** See the [final admission checkpoint](../reference/status-and-roadmap.md#liquid-comparison-build-design-checkpoint--2026-10-23). Only a separately scoped initial opt-in #200 start is admitted. On 2026-10-24 the owner lifted the hold for the bounded [#200 policy foundation](../reference/status-and-roadmap.md#lcb-001-policy-foundation--2026-10-24) and then authorized the bounded LCB implementation, including the previously held #200 pressure reference and #212 inertial work ([owner decision](../reference/status-and-roadmap.md#lcb-001-pressure-reference--2026-10-24)). The opt-in [`pressure_flow_v1/reference`](../architecture/pressure-flow-v1.md) is Current in source; #212 is no longer held but is outside this accepted main checkpoint. This does not admit production default changes, generic #12 Stage-4 cell↔Rapier ownership, a production Cell-carrier migration, full GEN-006 streaming, new pressure-to-Rapier forces or a schema/ABI freeze.

The #213 prerequisite is satisfied. Remaining arm dependencies below still
block execution; the registered historical inventories are unchanged.

**Current apparatus.** The scenario definitions, runner, registry tooling and
regressions on this page exist in source and run against the unchanged native
World. Every *executed* result is a **Current-defaults** control: Water
`freemass_v1`, other liquids `cellular_yield_v1`.

**Campaign accounting** uses the signed rule `lcb-signed-ledger-v7`. It
superseded v2 (re-review N3/N4), v3 (re-review R1–R4), v4 (re-review F1/F2),
v5 (re-review F3/F4, G1/G2) and v6 (re-review I1: campaign report-shape
validation; the accounting body is unchanged).
- Every root, item and key is type-checked before use. A malformed container
  is `MALFORMED_EVIDENCE` and never raises. A present `events` value must be a
  list, and an explicit `null` is malformed. Omitting `events` means
  aggregate-only evidence.
- Every quantity is bound to the declared initial ledger and inventory.
- The species domain covers the inventory and every observed key, plus Brine
  whenever Salt is declared or observed. Each key is observed at every
  checkpoint, and an undeclared species starts at 0.
- Supplied species evidence is evaluated before any constant-Water closure,
  and only Salt-only reactions have a complete signed ledger.
- A reactive species never explains a Water discrepancy.
- Explicit sources and sinks close only against timed per-event amounts. Each
  event carries exactly one `source` or `sink` key. On **every** route, reaction
  closures included (v6; v4/v5 skipped it for active Salt), the events must lie
  inside the observed horizon. They must also keep a non-negative chronological
  balance.
- Campaign reduction binds each 1/4-worker report pair to its scenario id,
  worker count, pinned definition hash, horizon, source revision and shared
  runtime identity. A mismatch is never "identical" or measured. Duplicate JSON
  names, or any malformed field the reducer reads, make a report a
  `malformed_report` problem case. Malformed fields include observation entries
  (string id, an integer or object value, unique ids), the timing object, the
  runtime identity and the checkpoints list. The rest of the campaign is still
  reduced.
- Superseded records (v2–v6) are verified by replaying each record's own
  producer at its recorded revision. The record must also be byte-identical
  there. Current catalogue, loader or manifest changes cannot alter or break
  that check.

Gains, out-of-bound losses, impossible directions, exceeded budgets and
negative event balances fail. Where the retained data cannot establish the
reaction amount, the source/sink timing or the event horizon, the case is
`UNVERIFIED_*` and ineligible for acceptance. See the
[ledger correction](../audits/2026-10-23-lcb003-scenario-qualification.md#addendum--campaign-report-validation-v7-2026-10-23).

**Accepted evidence** is the CI-re-executed prefix: canonical hash, initial
inventory, tick-30 hashes and 1/4-worker parity for all 27 scenarios. The
full-length values are author-reported characterization; see the
[evidence scope](../audits/2026-10-23-lcb003-scenario-qualification.md#accepted-evidence-scope-stated-2026-10-23-for-the-gate-e-review).

**Retained campaign status and current admission are separate.** Experimental
registry arms remain unmeasured/blocked in the retained campaign until their
owning execution is qualified; underlying native support is no longer uniformly
unavailable. Each arm names its dependency (#200, #201, #212). No arm runs on a
fallback solver.
In source W-PF `reference`
executes natively ([design](../architecture/pressure-flow-v1.md)) and in
[`test_lcb_pressure_reference.gd`](../../godot/tests/test_lcb_pressure_reference.gd)
on registered geometries. Accepted main #246 additionally
admits W-CY natively and through the explicit policy constructor, with
transactional partial-Water refusal. Current capability metadata is regenerated,
but the registry's campaign arm records remain blocked; #202 owns consuming and
re-dispositioning them. A qualified candidate capability is not measured campaign
evidence. See the [native setup/receipt contract](../architecture/liquid-prepared-setup-and-receipts.md)
and [accepted checkpoint](../audits/2026-10-25-lcb001-shared-contract-acceptance.md).
Families and refusal codes are defined in the
[solver-family policy](../architecture/liquid-solver-family-policy.md).

The PR #215 protected fixtures are listed in the same registry, unchanged:

- `lcb.dam.water.freemass.reference.v1`;
- `lcb.mixed.water-oil-brine.v1`, arm M0.

Their accepted definitions, hashes and observations are reproduced, never
regenerated.

Dated results:
[2026-10-23 qualification evidence](../audits/2026-10-23-lcb003-scenario-qualification.md).

## Files

| Path | Role |
|---|---|
| [`tools/lcb/scenario_catalogue.py`](../../tools/lcb/scenario_catalogue.py) | Single source of the v1 scenarios; writes definitions; derives initial inventories by painting rectangles then fills in `demo::construct` order; `--check` |
| `godot/tests/fixtures/lcb/scenarios/*.json` | 25 frozen MicroScenario schema-2 definitions (fixed execution, no player/body/tools) |
| [`godot/tests/lcb_scenario_runner.gd`](../../godot/tests/lcb_scenario_runner.gd) | Shared controlled run: contract parse → native install → fixed ticks → checkpoint hashes, work counters, host capture; explicit `refused`/`faulted`/`failed_condition`/`completed` status |
| [`godot/tests/run_lcb_scenario_suite.gd`](../../godot/tests/run_lcb_scenario_suite.gd) | Campaign entry point over a list of definitions |
| [`tools/lcb/lcb_registry.py`](../../tools/lcb/lcb_registry.py) | `reduce` campaign → dated controls file (refuses to overwrite); `build` / `build --check` registry |
| [`docs/reference/lcb-scenario-controls-2026-10-23.json`](../reference/lcb-scenario-controls-2026-10-23.json) | Dated, immutable reduced controls (1/4-worker, Windows local) |
| [`godot/tests/fixtures/lcb/lcb-scenario-registry.json`](../../godot/tests/fixtures/lcb/lcb-scenario-registry.json) | Source-derived registry for the UI and regressions |
| [`test_lcb_scenario_catalogue.gd`](../../godot/tests/test_lcb_scenario_catalogue.gd) | Per scenario: contract and canonical hash, derived inventory vs native tick 0, tick-30 hash goldens, 1/4-worker parity, arm/status consistency |
| [`test_lcb_negative_contracts.gd`](../../godot/tests/test_lcb_negative_contracts.gd) | Refusal and failure-visibility contracts |
| [`test_lcb_fixture_manifests.gd`](../../godot/tests/test_lcb_fixture_manifests.gd) | PR #215 protection (unchanged) |

## Catalogue v1

Every scenario uses a fixed interest region, cadence LOD off, default Water
semantics `[1,8,12,0]` and seed 0. **Purpose** is the visible behaviour or
correctness property that justifies the scenario.

| ID | Category | Purpose |
|---|---|---|
| `lcb.dam.water.freemass.depth-48.v1`, `-96`, `-160` | dam-ladder | Release volume, retained reservoir and front band against initial depth. Geometry matches the protected reference; depth-160 is physics-identical to it (consistency control). |
| `lcb.shallow.stream-steps.v1` | shallow-flow | 20 scheduled 4×4 sources onto six descending steps: falling sheets, step overflow, supported films, explicit source ledger |
| `lcb.shallow.ledge-sheet-fall.v1` | shallow-flow | 8-row sheet spills off a shelf and falls 128 rows: sheet thinning, stream break-up, landing |
| `lcb.shallow.obstacle-run.v1` | shallow-flow | 24-row release over three low obstacles: overtopping, ponding, thin fronts |
| `lcb.head.vented-two-limb.v1` | communicating-head | Vented 160/40-row limbs through an 8-row roofed passage. Equal levels are valid **only** because both headspaces are open (#49 boundary assumption). |
| `lcb.head.narrow-passage.v1` | communicating-head | Same limbs through a 2-row passage |
| `lcb.head.sealed-two-limb.v1` | communicating-head | Roofed (enclosed) limbs. Current has no gas state, so its result is labelled **`measured_not_a_sealed_control`**. A valid sealed target needs W-PF gas (#200). On the pressure branch W-PF gas runs it: it differs from vented but was 4.9 rows from the isothermal law at t2400, still settling (characterization). |
| `lcb.rest.deep-quiet-pool.v1` | rest-wake | Closed full-cell pool with no input: zero motion state and constant `lcb.quiescent-physical-content.v1`; complete hashes retain clocks |
| `lcb.rest.remote-disturbance.v1` | rest-wake | Remote source (t300) and sink (t900) in a deep pool; ledger closes to the initial mass |
| `lcb.rest.two-pool-partial-activity.v1` | rest-wake | Disturb pool A only; pool B must stay unchanged; activity counters show locality |
| `lcb.viscous.lane-gallery.v1` | viscous | Equal blocks of Water, Oil, Brine, Slush, Paste and Mercury in separate lanes: spreading against viscosity, kernel specializations kept |
| `lcb.viscous.pour-heaps.v1` | viscous | Dropped 32×32 blocks: heap retention versus spreading |
| `lcb.density.inverted-column.v1` | density | Brine/Water/Oil inverted column sorts by density; residual mixing |
| `lcb.density.mercury-drop.v1` | density | Dense Mercury sinks through Water; Water conserved |
| `lcb.density.water-brine-lock-exchange.v1` | density | Brine undercuts Water; Brine cells conserved (preregistered condition) |
| `lcb.density.oil-water-lock-exchange.v1` | density | Oil rides over Water; Oil cells conserved (preregistered condition) |
| `lcb.granular.water-sand-baseline.v1` | granular | Release onto a Sand bed, Baseline transport |
| `lcb.granular.water-sand-erosion.v1` | granular | Same with Threshold erosion; transport tuning kept separate from family |
| `lcb.granular.salt-dissolution.v1` | granular | Salt dissolves to Brine; reaction quantity accounting (#160 partial-cell evidence) |
| `lcb.mixed.repeated-openings.v1` | mixed-stress | Staggered gate openings plus Water pulses; Oil conserved |
| `lcb.mixed.sodium-oil-fire.v1` | mixed-stress | Water+Sodium → Steam+Fire beside Oil; native chemistry and phase products; counts not conserved by design |
| `lcb.seam.dam-on-chunk-seams.v1` | seams | Gate on the x=384 chunk seam; reservoir across chunk and core seams |
| `lcb.seam.world-boundary.v1` | seams | Container formed by the world-bound wall and bottom row (chunk row 7) |

**Out of scope for native-only controlled runs:**
- player, Rapier body and rendering stations;
- negative coordinates, which the 0–1023 MicroScenario frame cannot express.
  Native [`test_world.cpp`](../../native/tests/test_world.cpp) covers signed
  seams: `test_flow_rest_films_and_barriers` checks Water rest and film
  conservation at shifts −129 to 127, and `test_negative_coordinates`.

These belong to #202's live host and #203's packaged runs.

## Registry contract (for the LCB-003 UI)

The UI reads `res://tests/fixtures/lcb/lcb-scenario-registry.json` (schema
`lcb-scenario-registry-v1`). Each entry has:

| Field | Meaning |
|---|---|
| `id`, `version`, `category`, `title`, `purpose`, `protected` | stable identity and the reason the scenario exists |
| `definition.res_path`, `repo_path`, `file_sha256_lf`, `canonical_hash`, `contract` | source definition and integrity (`canonical_hash` is `CyberMicroScenarioContract.parse().hash`) |
| `setup` | seed, horizon, transport profile, Water semantics, interest/execution, scheduled events, derived initial inventory and `material_region` |
| `observations`, `conditions` | controlled observation fields and preregistered outcomes |
| `camera` | origin, overview rectangle, bookmarks (named regions) |
| `manual` | `free_play` suitability and note. Any manual input makes a session exploratory |
| `liquids`, `compatibility` | liquids present and their capability-matrix family cells |
| `arms` | `id`, material→`family/variant` mapping, `status` (`measured`, `measured_not_a_sealed_control`, `blocked`, `failed`, `unmeasured`), `executable_today`, `depends_on`, `reason`; protected arms also carry `manifest_status`. One availability rule covers every arm: only a measured Current-default mapping is executable, and a candidate mapping is `blocked` whatever its manifest label |
| `qualification` | Windows local native result, Linux CI route, and Web/Rapier/render status (not executed) |
| `goldens` | initial Water quantity and tick-30 content/state hashes used by the regression |

UI rules (to be enforced by #202):
- offer only arms with `executable_today: true`;
- show blocked arms with their `reason` and `depends_on`;
- never fall back to another family.

## Arms

| Arm | Mapping | Status |
|---|---|---|
| `W-FM` / `C0` | Current defaults | **measured** on Current |
| `W-CY` | Water `cellular_yield_v1/reference` | campaign arm unmeasured; native/explicit-constructor admission accepted on main in #246 with Windows/Linux publication and required matrix; registry host campaign integration remains pending |
| `W-PF` | Water `pressure_flow_v1/reference\|cached\|cached_dormant` | retained registry campaign unmeasured. All three variants are accepted on main through #253, with source-matched publication and exact-head gates. This does not reclassify the retained registry campaign |
| `W-IN` | Water `inertial_cellular_v1/reference` | retained campaign blocked: #200, #212. Isolated sourceaa8af247 and Windows/Linux scoped publication execute Water IN; final ready-PR/common-Water campaign qualification remain separate |
| `BRINE-IN` | Brine `inertial_cellular_v1/reference` | retained campaign unmeasured/blocked; Brine IN is accepted on main through #250 after corrected source-matched publication and full exact-head gates; retained campaign qualification remains open |
| `M1` | Water FreeMass + Oil CellularYield + Brine Inertial | retained campaign unmeasured/blocked; local #212 mixed controls exist, with fresh combined-source and registry campaign qualification separate |
| `M2` | pressure Water + Oil + inertial Brine | blocked: #200, #201, #212 |
| `M2b` | pressure Water + Oil/Brine CellularYield | blocked: #200, #201 |
| `M1-alt` | Toxic Sludge inertial (protected mixed fixture only) | proposed alternate; needs #212 and a new geometry version |

**No scenario in the retained dated registry campaign has run three families
at once.** Its executed mixed scenarios use Water `freemass_v1` and
`cellular_yield_v1` for the rest. Separately qualified native/Godot controls run
Water-FM (and a PF substitution), Oil-CY and Brine-IN with actual contacts in
one World. Those controls do not promote the117 retained classifications or
complete a registered full-host campaign. Water-IN/Oil-CY/Brine-IN contains two
distinct families.

## Negative contracts

| PR #215 NC | Coverage on current source |
|---|---|
| NC-1, NC-2, NC-10 | **Executed by the #200 foundation** in [`test_liquid_solver_policy.gd`](../../godot/tests/test_liquid_solver_policy.gd) through the MicroScenario host: Oil × inertial `combination_rejected`, pressure/inertial `family_unavailable` with the live session intact, and CYSD1 import on default families. Accepted #246 main admits pressure reference; #201 admits all three Water PF variants, so its transactional negatives use unsupported Oil/PF mappings and inertial. Retained registry campaign statuses are not retroactively promoted. A definition carrying a `solver_family` field is still refused as an unknown root field. |
| NC-3 | Native preparation and explicit Godot policy-constructor regressions exercise `normalization_required` on accepted #246 native/explicit-constructor source, preserving the live session. The retained registry/negative-contract record remains blocked pending #202 consumption; Godot explicit normalization opt-in is still absent. |
| NC-4 | Current #201 branch executes certificate/revocation and exact body/material/authority tests. This separate local proof does not promote the retained registry NC-4 arm or final platform acceptance |
| NC-5 | **Blocked (#212)** under M1. The Current equivalent is measured (`salt-dissolution`, mixed M0). |
| NC-6 | **Blocked (#200/#212)** across families. Current same-family density exchange is measured (lock exchanges, inverted column, Mercury drop). Physical hash/CYPS2 exist on accepted #246 main; inertial-family qualification remains #212. |
| NC-7 | **Executed:** campaign 1/4-worker parity plus regression tick-30 parity |
| NC-8, NC-9 | **Blocked (#202):** presentation/exploratory flags live in the UI. Partial cover: the native-only runner refuses player-enabled definitions. |

Additional contracts executed by `test_lcb_negative_contracts.gd`:

- **Malformed or invalid definitions are refused before any tick**, and the
  runner returns `refused` with a visible reason and no capture:
  - malformed JSON and over-byte-budget text;
  - unknown or missing root fields;
  - reserved or out-of-catalogue material IDs, and out-of-frame rectangles;
  - a non-Water fractional fill, a zero-mass fill, or an erase carrying a
    payload;
  - Water mass bits above 8, coherence above 12, or fill mass above 255;
  - exceeding the observation-area or event budget;
  - events out of order or beyond the horizon;
  - `material_cells` observations under body masks;
  - an unsupported transport profile;
  - a player-enabled definition in the native-only runner.
- **Capacity exhaustion:** a World with active-core capacity 1 quarantines the
  first multi-core tick, and the host reports `failed`, never `complete`.
- **Harness visibility:**
  - native ticks outside the host boundary make the host fault;
  - a preregistered fail condition surfaces as `failed_condition`.
- **Source/sink accounting:** a scheduled fill and erase are ledgered exactly,
  and the Water ledger closes.

## Commands

From the repository root with pinned Godot 4.7 and a source-matched native
runtime. `<list>` is a file of absolute definition paths, one per line.

```bash
python tools/lcb/scenario_catalogue.py --check
```

```bash
godot --headless --path godot --script res://tests/run_lcb_scenario_suite.gd -- --list=<list> --workers=1 --output-dir=<dir-w1> --source-sha=<40-hex>
```

```bash
godot --headless --path godot --script res://tests/run_lcb_scenario_suite.gd -- --list=<list> --workers=4 --output-dir=<dir-w4> --source-sha=<40-hex>
```

```bash
python tools/lcb/lcb_registry.py reduce --w1 <dir-w1> --w4 <dir-w4> --out docs/reference/lcb-scenario-controls-<date>.json --date <date> --platform "<platform>" --source-sha <40-hex>
```

```bash
python tools/lcb/lcb_registry.py build --check
```

```bash
godot --headless --path godot --script res://tests/test_lcb_scenario_catalogue.gd
```

```bash
godot --headless --path godot --script res://tests/test_lcb_negative_contracts.gd
```

A new campaign writes a **new dated** controls file. Pointing the registry at
it is an explicit, reviewed change.
- A changed golden is diagnosed (source, setup, runtime or semantics) and
  registered as a new scenario version.
- It is never silently overwritten.

## Remaining native integration requirements (LCB-003/004)

1. **#200:**
   - `LiquidSolverPolicy`, its packed bridge, refusal codes and effective
     readback are Current (2026-10-24 foundation; NC-1, NC-2 and NC-10
     executable);
   - at the accepted #245 main checkpoint: `pressure_flow_v1/reference`, the
     versioned physical-state hash, CYPS v1 persistence and per-family
     observation (`inspect_cell.family_state`, gas inspection, overfill in
     `water_integer`);
   - accepted #246 main at `ec58d919` adds W-CY and `normalization_required`,
     native normalization, immutable typed v1 setup/run/attempt receipts and exact
     quantity accounting; physical hash/CYPS2 include that continuation and old
     CYPS1 refuses. Actual Windows/Linux publication and all required gates pass
     at the [accepted checkpoint](../audits/2026-10-25-lcb001-shared-contract-acceptance.md).
     Full host/registry campaign qualification remains #202/#203.
2. **#212:** `inertial_cellular_v1` plus Brine qualification unblocks BRINE-IN,
   M1 and M2. W-IN requires its own real Water admission/qualification; a Brine
   proof does not satisfy the approved four-model controlled-Water contract.
   M1 is the first registered three-family campaign target.
3. **#201:** pressure `cached`/`cached_dormant` variants with equivalence to
   `reference`, and cross-family invalidation (NC-4).
4. **#202:**
   - remaining full-application constructor routing, typed receipt/provenance
     collection and explicit Godot normalization integration;
   - registry consumption in the launcher, Tower and comparison panel;
   - exploratory marking (NC-9) and presentation-only overlays (NC-8);
   - live player, Rapier body and render stations, which the native-only
     runner refuses;
   - per-family observation fields such as overfill, velocity and gas.
5. **#203:** sequential isolated timing, Linux/Windows packaged execution and
   Web profiles. The Windows-local timings here are characterization only.
6. **Optional runner extension:** a schema-2 observation metric for front
   position and occupied extent. Bands are used today because the contract
   admits only `water_integer`, `material_cells`, `tick` and `cell_state`.
