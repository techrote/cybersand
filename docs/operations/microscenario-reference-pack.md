---
title: MS-001 reference MicroScenario pack
status: Current
document-kind: runbook
scope: Exploratory Materials Laboratory, Flood-Control Puzzle and Simulation Stress Test definitions on the shared host, with fresh-reset A/B, world-state objectives and bounded telemetry
canonical-for: [microscenario-reference-pack, materials-laboratory-readiness, flood-control-scenario, simulation-stress-test, microscenario-workbench-controls]
last-reviewed: 2026-09-25
related-documents: [microscenarios.md, microscenarios-programme.md, experiment-tower.md, ../reference/status-and-roadmap.md, ../audits/2026-09-19-issue-28-ms001.md]
---

# MS-001 reference MicroScenario pack

## Implementation and readiness disposition

The only authoritative #28 branch/PR is `codex/issue-28-ms001` / **PR #44**, based
on selected MS-000 PR #40, `de332eaf8f4e70b25b097bed0c2e2a7b2aac0173`.
`microscenario_reference_pack.gd` generates complete schema-2 definitions for the
same `microscenario_host.gd` used by Play, Inspect, Benchmark and the native-only
CLI. PR #36 / `micro_scenario_*.gd` remains superseded, not an additional module.

**Current source, exploratory:** all three first-pack scenarios are implemented on
PR #44: Materials Laboratory, Flood-Control Puzzle and Simulation Stress Test. The
[execution ledger](../audits/2026-09-19-issue-28-ms001.md) owns exact source/runtime
identities, measured outcomes and platform limits. The retained Linux/Windows native
runtimes are refreshed for the schema-2 observation adapter; Windows is a pinned
cross-build only, not Windows execution. Actual browser/WebAssembly and target-GPU
acceptance remain explicitly separate from source/functional acceptance.

The [programme](microscenarios-programme.md) owns admission: stable MS-000 plus
this Lab readiness can unblock #29 without waiting for Flood Control or Simulation
Stress Test. It does not authorize this #28 worker to implement #29. No #18/#20/
#26/#14 gate is satisfied or waived, and no material/Water/support/soliding/motion
physics is retuned to make these worlds pass.

## Materials Laboratory worlds

| Catalogue ID | Complete definition and purpose |
|---|---|
| `materials/contact-lab` | Three sealed bays: Salt/Water dissolution, Lava/Water quenching, and a non-reacting Sand/Water transport control; 240-tick horizon; ordinary paint/erase for exploration |
| `materials/salt-water` | Generated single-bay Salt/Water fixture, 384 Salt cells, existing shelf release at tick 12, 120-tick observations |
| `materials/salt-water-dose-small` | Same controlled apparatus with 192 Salt cells; an explicit complete-definition A/B example, not a tuning verdict |
| `materials/lava-water` | Generated Lava/Water contact with the existing Stone/Steam conversion; 120-tick observations |
| `materials/sand-water-control` | Generated Sand/Water non-interaction control; transport may move materials, but no INT conversion rule is expected |
| `materials/fire-gunpowder` | Existing Fire/Gunpowder combustion path; bounded material-count observations |
| `materials/acid-metal` | Existing Acid/Metal corrosion path; Rust observations without changing corrosion policy |
| `materials/spark-metal` | Existing Spark/base-Metal electrical interaction; declared cell-state/material observations |
| `materials/cement-water` | Existing Cement cure under Water/air context; Concrete observations over a 240-tick horizon |

All are recipe version 1, maturity `exploratory`, against the named current
source/contact identity retained in each capture, Baseline transport and declared
Water semantics. The original MS-001 fixtures retain their historical recipe
identity; the INT-000 additions add no material-rule tuning. The declared
seed moves the initial dose within its bay deterministically. It does not introduce
a global RNG or an INT-000 profile. Ordinary setup rectangles provide reproducible
material doses; finite existing erase events remove shelves. There is no generic
pump, heater, fan, igniter, arbitrary-material recurring emitter or new reaction.

`interaction_fixture(pair, seed, dose)` returns independent complete data. The
retained `godot/tests/fixtures/ms001-salt-water-v1.json` is one generated definition,
not a second implementation. Paste it into **Definition JSON**, or pass exactly
that file to the CLI:

```text
godot --headless --path godot --script res://tests/run_microscenario.gd -- --definition=/absolute/ms001-salt-water-v1.json --ticks=120 --workers=1 --mode=Benchmark --source-sha=<exact-checkout-40-hex-sha> --output=observation.json
```

The CLI refuses player/body-enabled definitions rather than silently omitting
owners. Supplied fixtures disable those owners in both GUI and headless modes.
A source SHA supplied by the caller is labelled as such; actual available script
and native artifact hashes are retained separately. Missing exported source bytes
remain unavailable rather than borrowing an old build identity.


## REM-003 player/granular owner-review surface

Catalogue ID `rem003/player-granular-review` is a **candidate-C1 owner-review
surface**, not a new automated acceptance oracle. It uses the shared schema-2
MicroScenario host in Play mode with the sampled player enabled and erase-only
world editing.

The finite review world contains five labelled regions: flat packed Sand for
walking/acceleration/braking/reversal; a one-cell step plus rising Sand shoulder
for transition/edge behavior; adjacent Dust and Salt support; a Sand landing zone
for low and higher jetpack drops; and a supported Sand shelf that can be erased
to expose falling/collapse behavior. Fresh reset restores the exact candidate
review geometry.

The on-screen instructions ask the owner to judge support, yield,
slopes/shoulders/edges, loose-versus-packed discrimination, excavation/collapse
and any sticky, rigid or jittery behavior. Those observations are deliberately
subjective. The scenario's declared completion condition only proves the bounded
600-tick apparatus can execute; it does **not** accept C1 gameplay. Automated
REM-003 correctness/measurement evidence remains in the dated REM-003 audit and
issue #82 stays open until explicit owner acceptance or another allowed
disposition.

## PLAY-VAL-001 selectable player-representation fixtures

Issue #139 adds three **exploratory** catalogue entries derived from the same
REM-003 review geometry:

- `rem003/player-granular-review/sampled-baseline`
- `rem003/player-granular-review/sampled-burial-safe`
- `rem003/player-granular-review/barrel-rapier`

They preserve the original review surface's rectangles, events, player start,
camera, admitted tools and ancestral geometry/action hash. The sampled-baseline
arm enables the historical runtime enclosure recovery; sampled-burial-safe disables
that runtime reordering while retaining the separate invalid-spawn repair contract;
barrel-rapier disables the sampled owner and admits only Rapier body 0 as the
controllable player at the same authored start.

Representation selection is **reset-scoped owner configuration**, not a new schema-2
field. The controlled fixture therefore refuses ordinary F6/F7 live representation
changes: select another catalogue arm and perform a fresh reset instead. This keeps
the registered world definition reproducible while making the PCHAR alternatives
directly selectable for matched owner review.

The three PLAY-VAL representation arms are currently **desktop-only**. Web uses a
different synchronous player/body owner and explicitly rejects these IDs instead of
pretending to execute the desktop PCHAR representation contract. Ordinary
MicroScenarios remain available to their previously supported owners.

The common MicroScenario status reports the active player identity. Scenario
capture also receives the active representation/recovery identity from the desktop
owner. Because schema 2 forbids authoritative `material_cells` census while a
body mask is active, the barrel fixture retains only the neutral 600-tick
completion probe; its material comparison is visual/recording evidence rather than
a masked census. These fixtures do not select a production player, change
generic-body semantics or satisfy #139's subjective owner-review disposition by
themselves.
See the dated PLAY-VAL-001 fixture evidence for exact implementation/validation
scope.

## Flood-Control Puzzle

Catalogue ID `ms001/flood-control` is a compact hydraulic world with a finite
reservoir, a scheduled ordinary gate removal at tick 20 and a protected generator
zone. The only objective is the declared `protected-water` observation at tick 180:
zero completes; any positive Water quantity fails. The untreated seed-0 control
records **5,031 integer Water units** in that zone and therefore fails.

Three retained acceptance witnesses preserve the exact same objective and change
ordinary setup geometry only:

| Witness | Physical intervention | Seed-0 protected Water at tick 180 |
|---|---|---:|
| `containment` | reinforce the reservoir aperture before scheduled release | 0 |
| `berm` | freestanding upstream barrier across the main channel | 0 |
| `diversion` | deflector plus bounded side sump routing flow away from the target | 0 |

The three final native content hashes are distinct, so these are not three labels
for one scripted solution state. The witnesses are test/evidence definitions, not
runtime solution flags. The selectable puzzle admits ordinary paint/erase tools so
a user can discover other solutions; organic edits are not silently treated as a
matched benchmark input.

Play, Inspect and Benchmark produce the same untreated seed-0 native content/Water
state at tick 180. One-worker instrumented and four-worker observer-off runs also
match. No pump, drain, flood-specific solver hook or scenario callback is added.

## Simulation Stress Test

The canonical `ms001/stress/*` profiles are deterministic, finite 180-tick workloads:

| Profile | Existing mechanics exercised | Bounded inputs |
|---|---|---|
| `water-flow` | sustained Water flow / basin activity | finite initial fill plus 14 scheduled Water fills |
| `granular-collapse` | large Sand collapse/runout | one ordinary support erase |
| `gas-column` | long-lived Smoke motion | setup only; no recurring generator |
| `mixed` | Sand + Water + Smoke | one support erase plus five Water fills |

Every profile stays under the unchanged 24-event / 24-observation limits, completes
with `budget_outcome=admitted`, and records 180 successful telemetry samples when
instrumentation is enabled. Seed-0 one-worker visited-cell sums are **2,111,536**
Water, **9,815,552** granular, **6,117,120** gas and **9,491,522** mixed. These are
functional workload identities, not target-PC performance thresholds.

Available native counters include visited/moved cells, scheduled cores,
chunk/temperature-field allocations and deferred events. Queue high-water, total
heap allocations and per-worker utilization remain unavailable and are named as
such. Four-worker observer-off Play runs match one-worker instrumented Benchmark
native content/Water outcomes while retaining no optional observation/work/timing
payloads.

## Inspection, control and fresh-reset A/B

Choose a catalogue entry, mode and seed, then **Load selected**. The world starts
paused. P toggles pause; R or **Fresh reset** reconstructs the same complete active
definition. Arrow keys pan. **Run declared window** uses acknowledged existing
single steps and stops at the declared completed tick; Cancel stops scheduling
more steps, with at most one already-admitted step outstanding. Opening Definition
JSON or accepting any reset also cancels further scheduling, including a reset to
the same definition. It never selects a mode-specific solver. F8 hides/restores all
common HUD, dialogs, labels and optional telemetry across later status refreshes.

The full Lab admits LMB paint/RMB erase, radius 1..16 and the existing material
catalogue selector; 1–6 and Q/E retain normal material selection. Controlled
single-bay fixtures deliberately omit live tools so matched inputs are straightforward.
Actor-free worlds do not advertise jetpack controls. Leaving the generic scenario
restores the controller's original help and all existing Tower/Water workflows.

**Identities / all results** shows scenario/schema/recipe/seed, canonical definition
and ancestral hashes, declared material IDs/catalogue identity, source/runtime,
transport/Water policies, instructions, all declared observations and every retained
result. Under INT-000 it also exposes the native interaction schema/profile,
independent channels, layer precedence, catalogue validation, coverage/tuning-pass
records, effective pair provenance and represented specialized world-kernel
authority. The view is read-only and cannot mutate interaction semantics. Pending observations are not displayed as zero. `cell_state` is a declared
single-cell probe into existing fields; chunk/block coordinates are not a per-cell
sleep claim. Full stored values remain visible even when the compact HUD abbreviates
a compound observation.

For A/B, load the baseline definition and **Store active as A**, load the candidate
through the JSON/catalogue reset and **Store active as B**. **Fresh reset A/B**
always invokes the existing validated owner reset, never live parameter mutation.
Run each to the same declared horizon and capture its result. The comparison retains
two definitions and one immutable report per slot, with exact identities and outcomes.
Different completed ticks/runtime/seed/workers do not receive a matched flag. Even
matching flags do not certify unmatched manual brush input as a controlled experiment.
Blind workflows keep this generic definition/capture route disabled.

GUI capture atomically writes `user://microscenario-observation.json` and copies it
to the clipboard where supported. Capture is a definition plus observations, **not
a save/replay** of all runtime state or organic input. Existing controlled-scenario
CYSD1 save restrictions remain.

For INT-000 batch evidence, use the same catalogue definitions through
`tools/interactions/batch.py`. The run command executes the declared proof set at
the requested one/four-worker identities, rejects worker-semantic drift and writes a
manifest containing the full interaction catalogue, rolling kinetic/contact
baseline, source/sink ledger, coverage summary and explicit coverage gaps. The
compare command reports both observation differences and stable-ID rule/layer/pass
field changes; it never fabricates outcomes for untested pairs.

## Accounting, telemetry and anomaly triage

Retain exact starting/ending material-cell counts and native Water integer quantity.
The current Salt fixture reports two Brine cells per converted Salt cell; the quench
reports existing Stone and Steam products. Water lost to those conversions is not
mislabelled as an apparatus sink. The scheduled-source/sink ledger covers declared
edits only; it does not reconstruct reactions or arbitrary tools.

Optional native tick distributions exclude observer/host cost. The separate
before/after-host distribution includes apparatus observation work but excludes
rendering, Rapier, publication and whole-frame scheduling. Current native counters
include cells/blocks/chunks/work/phase jobs, configured capacities and specifically
chunk/temperature-field allocations. Queue occupancy/high-water, total allocations,
per-worker utilization and per-cell sleep are explicitly unavailable. These are
run-specific measurements, not target-PC performance acceptance.

An unexpected result should retain the complete definition, identities and negative
observations, then be reduced and routed to the true engine owner. Apparatus defects
are fixed in #28; material/contact/support/phase behavior is not compensated with
scenario-specific logic. Future relevant physics changes require a new recipe or
revalidation against the new named baseline; prior evidence is preserved.

## Pack acceptance boundaries

The three scenarios share schema 2 and the same owner-local host in Play, Inspect
and Benchmark. Opening Definition JSON cancels further bounded-run stepping before
modal inspection; every accepted reset cancels any previous run waiter even when
the complete definition hash is unchanged; F8 clean view keeps status telemetry
hidden across subsequent status refreshes. These are apparatus-lifecycle fixes,
not simulation retuning.

The pack remains **exploratory/versioned** against the named baseline. Its world
outcomes are useful discovery and regression evidence but are not production Water,
interaction, support, soliding or motion acceptance. Relevant later physics changes
require targeted version bump/revalidation. #29 implementation remains separate;
#18/#20/#26/#14 gates are neither satisfied nor waived here.
