---
title: MS-001 reference MicroScenario pack and Materials Laboratory
status: Current
document-kind: runbook
scope: Exploratory generated Materials Laboratory definitions, shared controls, fresh-reset A/B, readiness and named baseline; Flood Control and Simulation Stress Test completion tracked separately
canonical-for: [microscenario-reference-pack, materials-laboratory-readiness, microscenario-workbench-controls]
last-reviewed: 2026-09-19
related-documents: [microscenarios.md, microscenarios-programme.md, experiment-tower.md, ../reference/status-and-roadmap.md, ../audits/2026-09-19-issue-28-ms001.md]
---

# MS-001 reference MicroScenario pack and Materials Laboratory

## Implementation and readiness disposition

The only authoritative #28 branch/PR is `codex/issue-28-ms001` / **PR #44**, based
on selected MS-000 PR #40, `de332eaf8f4e70b25b097bed0c2e2a7b2aac0173`.
`microscenario_reference_pack.gd` generates complete schema-2 definitions for the
same `microscenario_host.gd` used by Play, Inspect, Benchmark and the native-only
CLI. PR #36 / `micro_scenario_*.gd` remains superseded, not an additional module.

**Current source, exploratory:** Materials Laboratory is implemented. Its readiness
is independently evaluated in the [execution ledger](../audits/2026-09-19-issue-28-ms001.md).
A locally passing checkpoint is not automatically a merged-ready or all-platform
checkpoint: identify the exact consumable commit and rebuilt native artifact
before using it. Bundled pre-MS-001 runtimes lack the new read-only methods and
are rejected transactionally. PR #44 remains draft while current-head pinned
runtime publication/validation and the remaining #28 deliverables are completed.

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

All are recipe version 1, maturity `exploratory`, against the named de332eaf
contact baseline, Baseline transport and Water mass8/coherence12. The declared
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

## Inspection, control and fresh-reset A/B

Choose a catalogue entry, mode and seed, then **Load selected**. The world starts
paused. P toggles pause; R or **Fresh reset** reconstructs the same complete active
definition. Arrow keys pan. **Run declared window** uses acknowledged existing
single steps and stops at the declared completed tick; Cancel stops scheduling
more steps, with at most one already-admitted step outstanding. It never selects
a mode-specific solver. F8 hides/restores all common HUD, dialogs and bay labels.

The full Lab admits LMB paint/RMB erase, radius 1..16 and the existing material
catalogue selector; 1–6 and Q/E retain normal material selection. Controlled
single-bay fixtures deliberately omit live tools so matched inputs are straightforward.
Actor-free worlds do not advertise jetpack controls. Leaving the generic scenario
restores the controller's original help and all existing Tower/Water workflows.

**Identities / all results** shows scenario/schema/recipe/seed, canonical definition
and ancestral hashes, declared material IDs/catalogue identity, source/runtime,
transport/Water policies, instructions, all declared observations and every retained
result. Pending observations are not displayed as zero. `cell_state` is a declared
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

## Remaining pack scope

Flood-Control Puzzle and Simulation Stress Test are still under implementation in
PR #44 at the Lab checkpoint. Flood Control must demonstrate several ordinary-engine
solutions and a failing untreated control under the same world-state objective.
Stress profiles must cover finite Water, granular, gas and mixed work with named
budgets and comparable telemetry. Neither is implied complete by Lab readiness.
