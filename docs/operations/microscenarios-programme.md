---
title: CyberSand MicroScenarios programme
status: Planned
document-kind: design
scope: Reusable deterministic scenario apparatus, post-G-final reference pack, chemistry experiment substrate and staged showcase roadmap
canonical-for: [microscenarios-programme]
last-reviewed: 2026-09-18
related-documents: [experiment-tower.md, architecture-programme.md, ../reference/status-and-roadmap.md, ../MATERIAL_LAB.md]
---

# CyberSand MicroScenarios programme

MicroScenarios are a thin scenario layer over the existing CyberSand engine.
They do not define new material physics. A scenario defines a bounded situation,
initial state, available normal tools/configuration, objectives and observations;
the authoritative material system determines what physically happens.

The programme is tracked by GitHub issue #30. Implementation issues are #27
(MS-000 harness), #28 (MS-001 reference pack), and #29 (CHEM-000 chemistry
experiment substrate).

## Why this is being added now

#13 Experiment Tower and #19 Water Feel Lab already established reusable pieces:
shared recipes, deterministic scenarios, reset, pause/single-step, profile
selection, observation metadata and controlled human A/B/blind workflows.
Those features are valuable beyond Water.

The framework should therefore be extracted from proven apparatus instead of
creating separate architectures for each showcase or experiment.

This planning layer does **not** alter completed architecture evidence, accepted
ADRs, #18 compact-motion admission, #20 sparse-motion admission, or #14 G-final.

## Development-path insertion

The intended sequencing is:

```text
#18 compact motion
        |
        v
#24 Tower input hygiene
        |
        v
#27 MS-000 deterministic scenario harness
        |
        +----------> #20 sparse-motion fixtures
        |
        +----------> #26 Water-behavior fixtures where useful
        |
#20 + relevant #26 evidence
        |
        v
#14 G-final
        |
        v
#28 MS-001 reference scenario pack
        |
        v
#29 CHEM-000 generated chemistry fixtures
        |
        v
bounded chemistry tuning passes and later showcase packs
```

#18 is intentionally not made dependent on MicroScenarios. It should complete
under its current experimental contract. #27 is apparatus-only and must not
become post-hoc evidence for choosing a motion representation.

#20 keeps its G-B admission, ownership, capacity and scientific acceptance.
MS-000 supplies reusable fixture/runtime machinery only.

#26 may continue characterization before MS-000. If the harness lands during
that work, its registered Water scenarios may be re-expressed through the
framework when that does not invalidate source-matched evidence.

#14 remains the architecture decision gate. MS-001 deliberately waits until
the relevant architecture baseline is settled.

## MS-000: common scenario contract

A MicroScenario should declare, with versioned provenance:

- stable scenario ID and schema/recipe version;
- deterministic seed;
- initial world/material recipe;
- legal simulation/profile/config selections;
- optional player spawn and available generic tools;
- setup/reset lifecycle;
- optional bounded scheduled starting events;
- requested observations/metrics;
- optional objective and failure conditions;
- result/export metadata, including source/artifact/profile identity.

Prefer declarative scenario data plus a small bounded host API over
scenario-specific scene scripts.

### Common execution modes

The same scenario definition should support:

- **Play** — minimal instrumentation, objective/tool interaction;
- **Inspect** — pause/single-step, probes, overlays, snapshots and controlled
  parameter/seed changes;
- **Benchmark** — repeatable instrumented/headless execution and exported metrics.

These are presentation/operation modes around one scenario definition, not three
different simulation implementations.

### Host-operation boundary

Generic host operations may create/reset from recipes, initialize materials,
schedule bounded existing events, observe declared conditions, capture metadata
and mark objective/failure state.

Do not add an unrestricted per-tick arbitrary-cell scripting escape hatch.
Scenario logic should observe and request normal engine operations rather than
replace material kernels.

Existing persistence/replay limits remain truthful: a scenario seed/profile does
not make CYSD1 or current hashes a complete replay system.

### Initial proving consumers

MS-000 should migrate/generalize:

1. the #13 Experiment Tower without changing its transport/chemistry behavior;
2. the #19 Water Feel Lab without changing its blind/reset/correspondence behavior;
3. at least one #20-style bounded event fixture;
4. at least one #26-style Water behavior fixture.

The last two prove that the abstraction is not Water-UI-specific; they do not
change #20/#26 acceptance ownership.

## MS-001: reference scenario pack

After G-final, three deliberately different reference scenarios prove the
framework boundary.

### Materials Laboratory

A controlled interaction/tuning environment. It should support reproducible
material setups, inspection, quick reset and compact experiment export. Later
chemistry fixtures should open interactively from the same definitions used by
headless tests.

### Flood-Control Puzzle

A small playable hydraulic/environmental objective with multiple physically
valid approaches. The level defines goals and available ordinary systems rather
than scripted solution branches.

### Simulation Stress Test

The canonical stress/benchmark scenario name. Deterministic profiles should
exercise sustained fluid work, granular collapse, gas/smoke where supported,
bounded repeated events and mixed workloads while exporting capacity/work/timing
telemetry.

Together these test apparatus, gameplay and benchmarking through the same host.

## Chemistry campaign

#29 CHEM-000 uses MicroScenarios as the common chemical-interaction experiment
substrate. It does not immediately retune every reaction.

A growing material catalogue makes a handcrafted dense pair campaign
unmanageable: 64 material IDs imply 4096 ordered pairs and 256 imply 65536.
Most pairs should not acquire bespoke rules merely because the Cartesian product
exists.

The campaign should therefore use:

- family/default behavior where genuinely shared;
- explicit directed versus symmetric interactions;
- sparse pair-specific overrides;
- explicit intentionally-nonreactive, inherited, tested, limited and untested states;
- generated fixtures for relevant geometries/contact conditions;
- exact reaction/source/sink accounting where applicable;
- versioned baseline + tuning-pass evidence rather than one mutable matrix.

A fixture definition should be usable headlessly, in batch coverage campaigns,
and interactively in Materials Laboratory.

Representative generated topologies include A-over-B/B-over-A, horizontal
interface, small-quantity into bulk, sustained contact, separated-then-release,
heated/cooled/ignited cases where relevant, and barrier/control comparisons.
Not every topology applies to every pair.

Each tuning pass records exactly which families/pairs/parameters changed, pins
scenario/profile versions, compares against the previous accepted pass and
retains superseded evidence. Later passes must not silently erase earlier gains.

Initial apparatus-validation families may include Water/Salt/Brine,
Water/Lava/Ice/Steam, Acid/Metal/Rust, Fire/Wood/Oil/Coal/Dust,
Sodium/Water, Cement/Concrete, Toxic Sludge purification and Spark/Metal
behavior. Naming these does not authorize tuning them in CHEM-000.

## Showcase catalogue and staging

Do not create all showcase issues before their underlying systems are ready.

The ten current concepts are:

1. **Utility-Tunnel Incident** — integrated flooding/electricity/debris/smoke traversal.
2. **Flood-Control Puzzle** — compact hydraulic engineering objective.
3. **Breach-and-Extract** — traversal governed by material properties.
4. **Materials Laboratory** — controlled interaction/tuning apparatus.
5. **Industrial Accident** — cascading systems-failure intervention.
6. **Mining / Excavation Toy** — terrain activation, granular collapse, fluids and cavities.
7. **Sewer / Drainage Sandbox** — sustained dirty flow, debris, deposition and clogging.
8. **Destructible Shooting Range** — repeatable damage/material interaction measurement.
9. **Environmental Puzzle Room** — one objective with multiple emergent solutions.
10. **Simulation Stress Test** — deterministic engineering/performance workloads.

#28 owns items 2, 4 and 10 as the first reference pack.

Later focused showcase work should normally progress:
**Shooting Range -> Mining -> Sewer**, then
**Environmental Puzzle Room -> Breach-and-Extract**, then
**Utility-Tunnel Incident -> Industrial Accident**.

This is a dependency/order guide, not a requirement to create those issues now.

## Framework rule

> Define a situation and an objective; let the material system determine what
> solutions exist.

Anything broadly useful to several scenarios belongs in the framework or in a
separately admitted engine feature. Anything unique remains inside its scenario.
A showcase must not smuggle new physics into scenario-specific scripts.

## Completion boundaries

MS-000 is complete when a small stable apparatus exists and migrated controls
retain their authoritative behavior.

MS-001 is complete when Materials Laboratory, Flood-Control Puzzle and
Simulation Stress Test all use the same framework cleanly.

CHEM-000 is complete when generated/versioned interaction fixtures and coverage
records can drive later bounded chemistry passes without overwriting prior work.

None of those completions by itself approves a new production material model,
Cell layout, motion representation, reaction retune or replay contract.
