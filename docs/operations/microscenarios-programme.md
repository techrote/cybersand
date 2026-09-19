---
title: CyberSand MicroScenarios and intermaterial-interactions programme
status: Planned
document-kind: design
scope: Canonical development-order graph for reusable exploratory MicroScenarios, anomaly triage, non-kinetic intermaterial-interaction authoring/tuning, and staged showcase work
canonical-for: [microscenarios-programme, microscenarios-development-order, intermaterial-interaction-programme]
last-reviewed: 2026-09-19
related-documents: [experiment-tower.md, architecture-programme.md, ../reference/status-and-roadmap.md, ../reference/product-intent-and-priorities.md, ../MATERIAL_LAB.md, ../systems/flow-transport-and-profiles.md]
---

# CyberSand MicroScenarios and intermaterial-interactions programme

> **Execution-order safety:** GitHub issue numbers are identifiers, **not a serial
> development path**. Do not choose work because its number is lower/higher or
> because an older issue comment shows a linear chain. For #24, #27-#30 and their
> links to #18, #20, #26 and #14, this page owns the programme-level dependency
> graph. The architecture programme still owns the scientific gates and semantics
> of #14/#18/#20. If an issue body or planning note conflicts with this page,
> reconcile the documentation and issue mirror before implementing the disputed
> dependency.

MicroScenarios are a thin scenario layer over the existing CyberSand engine.
They define situations, objectives, tools and observations; authoritative engine
systems determine what happens. They are useful **before** the physics is finished:
interesting playable worlds should expose edge cases that a Cartesian pair audit
would never anticipate, then turn those discoveries into small retained fixtures.

Issue #30 tracks this programme. #27 owns the reusable harness, #28 the first
exploratory/reference scenario pack, and #29 is **INT-000**, the versioned
intermaterial-interaction framework/campaign. #30 is a tracker, never a prerequisite
that must itself be "executed" before those work items.

## Authority and ordering rules

The following rules are deliberately redundant with AGENTS.md, the handover,
roadmap and issue bodies so an autonomous agent cannot safely infer another order.

- **Never infer dependency from issue number.** Read this graph and the issue's
  explicit dependencies.
- **Source/ADRs remain runtime authority.** This page controls programme
  orchestration, not physics semantics.
- **#18 remains independent architecture research.** MicroScenarios must not
  retroactively change its registered controls, admission or acceptance.
- **#20 remains gated by #18/G-M and its own G-B admission.** A reusable scenario
  harness is apparatus, not evidence that sparse ballistic transfer is needed.
- **#26 remains independent.** It may use the common harness when that preserves
  registered/source-matched evidence, but it must not wait for the harness when
  urgent characterization can proceed on the existing Water Feel Lab.
- **#14/G-final remains the architecture decision gate defined by the architecture
  programme.** MicroScenarios and INT-000 are not new G-final completion
  dependencies.
- **G-final is not a blanket prerequisite for exploratory MicroScenarios.**
  Provisional scenarios can run against the current named baseline and be
  revalidated after relevant architecture changes.
- **There is no global "physics is finished" gate for interactions.** Every
  accepted interaction result names the exact kinetic/contact baseline it used;
  later relevant physics changes trigger targeted revalidation.

## Current dependency graph

The intended graph is:

```text
#24 Tower/launcher hygiene
        |
        v
#27 MS-000 common scenario harness -------------------------------+
        |                                                        |
        +----> #28 exploratory scenario pack                     |
        |        |                                               |
        |        +--> Materials Laboratory readiness --------+   |
        |        +--> Flood-Control Puzzle (exploratory)      |   |
        |        +--> Simulation Stress Test (exploratory)    |   |
        |                                                     |   |
        +----> reusable fixtures for #26 when useful          |   |
        +----> reusable fixtures for #20 after #20 admission  |   |
                                                              |   |
#18 compact-motion research --------------------------------> #20 |
        |                                                        |
        +---------------- architecture evidence -----------------+
                                                                 |
#19 complete + #20 disposition + architecture evidence ----------> #14 G-final
                                                                 |
#27 stable fixture contract + #28 Materials Lab readiness --------+
        |
        v
#29 INT-000 interaction infrastructure
        |
        +--> bounded versioned interaction tuning passes
        |
        +--> retained regression corpus

#14/G-final may require affected provisional scenarios/fixtures to be
revalidated or rebaselined. It does NOT retroactively mean they should have
waited to exist.
```

### Work-start table

| Work | May start when | Does **not** wait for | Hard boundary |
|---|---|---|---|
| #24 | Now / its own issue | #18, #27 | Keep it a focused input/launcher fix |
| #27 MS-000 | Once the working base contains the #24 fix, or the fix is taken as an isolated prerequisite in the same branch | #18 completion, #14/G-final | Apparatus only; no new physics semantics |
| #18 | Under its existing admission | #27/#28 | Preserve registered experiment contract |
| #26 | Under its existing characterization contract | #27 | Preserve source-matched evidence |
| #20 | Design/admission per its own issue; implementation only after its own gates | #28/#29 | Still blocked by #18/G-M plus G-B admission |
| #28 MS-001 | When enough of #27 is stable to host real scenarios | #14/G-final | Pre-G-final scenario results are provisional/versioned |
| #29 INT-000 planning/inventory | Now | #14/G-final | No broad retune merely because inventory exists |
| #29 implementation | Stable #27 fixture contract + #28 Materials Laboratory readiness checkpoint | completion of Flood Control/Stress Test; blanket G-final | Preserve rolling baseline/provenance and subsystem ownership |
| Interaction tuning pass | INT-000 infrastructure + named relevant physics/contact baseline | a mythical global physics freeze | Re-screen affected accepted fixtures after relevant physics changes |
| #30 | Tracker/documentation only | everything | Never treat issue #30 itself as an execution gate |

The #28 issue may remain one issue. Its **Materials Laboratory readiness
checkpoint** can unlock INT-000 while Flood Control and Simulation Stress Test
continue independently. Split #28 only if implementation/review size later
justifies it; do not create artificial serial dependencies merely for issue hygiene.

## Why exploratory scenarios move forward now

The current material system already feels broadly useful, but unknown edge cases
remain. Examples may span several owners: Lava can produce Stone and later appear
to penetrate it; Stone bridging/bracing may be useful in some structures and
implausible in others; a reaction may look slow because its kinetics are wrong or
because transport makes contact too rare.

Those are exactly the defects a playable exploratory world can reveal.

MicroScenarios therefore have two lives:

- **Exploratory/provisional:** build and play now against a named current source
  and profiles; use them to discover behavior and design better tests.
- **Stabilized/regression:** after a behavior is understood/fixed, retain a reduced
  fixture and, where the larger scenario matters, rebaseline its version against
  the relevant accepted engine state.

Rework is expected. It is cheaper than deferring discovery until every underlying
system claims maturity.

## Discovery-to-regression loop

When an interesting world exposes odd behavior, use this loop:

```text
play/explore a MicroScenario
        |
        v
capture anomaly + exact identities
        |
        v
reduce to the smallest reproducible scenario/fixture
        |
        v
triage ownership
   +----+---------+-----------+-------------+
   |              |           |             |
kinetic/       intermaterial state/phase  cross-system
contact        interaction    bug          integration
physics
   |              |           |             |
   +--------------+-----------+-------------+
                  |
                  v
          bounded fix/tuning issue
                  |
                  v
       retain regression + evidence
                  |
                  v
         return to the larger world
```

Do not classify first and force the symptom into that subsystem. Capture and
reduce first. For example, "Lava sinks through the Stone it created" could be
contact/support, permeability/density exchange, product-state initialization,
update ordering, an intermaterial rule, or a cross-system defect.

Every retained observation/fixture should identify at least:

- scenario ID/schema/recipe version and deterministic seed;
- source revision and tested runtime artifact/platform;
- material catalogue/version identity;
- kinetic/transport profile and relevant Water/material policy;
- intermaterial-interaction profile/version/hash once INT-000 exists;
- scheduled inputs and relevant user actions;
- expected/observed outcome and whether it is exploratory, accepted, limited or
  awaiting revalidation.

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
- result/export metadata including source/artifact/profile identity.

Prefer declarative scenario data plus a small bounded host API over
scenario-specific scene scripts.

The same definition should support:

- **Play** — ordinary objective/tool interaction with minimal instrumentation;
- **Inspect** — pause/single-step, probes, overlays, captures and controlled
  parameter/seed changes;
- **Benchmark** — repeatable instrumented/headless execution and exported metrics.

These are modes around one scenario definition, not different simulation
implementations.

Generic host operations may create/reset from recipes, initialize materials,
schedule bounded existing events, observe declared conditions, capture metadata
and mark objective/failure state. Do not add an unrestricted arbitrary-cell
per-tick scripting escape hatch. Scenario logic must request normal engine
operations rather than replace material kernels.

Initial proving consumers remain the #13 Experiment Tower, #19 Water Feel Lab,
a #26-style Water behavior fixture and, when #20 is independently admitted, a
#20-style bounded event fixture. Migrating/re-expressing a fixture must not
rewrite old source-matched evidence.

## MS-001: exploratory/reference scenario pack

#28 owns three deliberately different scenarios against the same MS-000 host.

### Materials Laboratory

A controlled interaction/tuning environment with reproducible setup recipes,
inspection, quick reset and compact experiment export. It is the interactive
front end for generated INT-000 fixtures.

**Readiness checkpoint:** once the lab can load/reset one generic generated
interaction fixture from the same definition used headlessly, expose its
identities/observations and preserve owner/reset boundaries, INT-000
implementation is unblocked. Flood Control and Simulation Stress Test need not
be finished first.

### Flood-Control Puzzle

A playable hydraulic/environmental objective with multiple physically valid
approaches. This is especially valuable early: the world should expose
unexpected transport, support, erosion, clogging, reaction and terrain edge cases
without scripted solution flags.

### Simulation Stress Test

The canonical benchmark/showcase name. Deterministic bounded profiles exercise
sustained fluid work, granular collapse, gas/smoke where supported, repeated
events and mixed workloads while exporting capacity/work/timing telemetry.

All three may exist in **exploratory** versions before G-final. Any scenario
whose outcome depends on a later changed architecture/physics decision is
version-bumped and revalidated rather than having its earlier observations
silently relabelled as current acceptance.

## INT-000: intermaterial interactions, not kinetic physics

Issue #29 is not a chemistry-only project. Its scope is **intermaterial behavior
other than kinetic/material-motion physics**.

In scope includes mechanisms such as:

- chemical reaction and explicit products/byproducts;
- combustion/ignition/extinguishing semantics;
- thermal-contact consequences and phase transitions;
- dissolution, corrosion and purification;
- curing/setting and environment-dependent state conversion;
- electrical/conductive interaction;
- catalytic, growth/biological or other material-specific contact semantics;
- wetting/absorption only where it is an intermaterial state rule rather than
  merely transport/motion;
- visual/event products when they are consequences of an authoritative
  interaction, while rendering itself remains non-authoritative.

Out of scope as INT-owned behavior includes density exchange, pressure/flow,
granular support/bridging/bracing, erosion/entrainment, collision/ballistics and
other kinetic movement. MicroScenarios may discover those problems, but triage
them to their actual physics owner instead of hiding them in an interaction rule.

### Sparse layered authoring

Do not make humans maintain a dense N×N table. With 64 materials there are 4096
ordered pairs; with 256 there are 65536. A dense resolved runtime lookup may be
perfectly reasonable if measurement favors it; **dense manual authoring is not**.

INT-000 should extend the useful #13 profile precedent:

```text
intrinsic material properties/state
        |
family/default interaction rules
        |
material-specific adjustments
        |
sparse directed/symmetric pair overrides
        |
context/state modifiers
        |
validated resolver/compiler
        |
compact runtime lookup representation
```

Explicit pair entries exist for genuine exceptions, not because every Cartesian
cell needs bespoke content.

### Independent interaction channels

Avoid one monolithic "A vs B" record. Resolve independent channels so tuning one
mechanism does not erase another, for example:

- thermal/phase;
- dissolution/corrosion;
- chemical conversion/products;
- combustion;
- electrical;
- curing/growth/special state;
- authoritative emissions/products;
- other future non-kinetic mechanisms.

Kinetic transport/contact settings remain under their existing owners and may be
shown read-only in a workbench for provenance/diagnosis.

### Versioned passes and provenance

Interaction work is cumulative and reversible in evidence terms:

```text
named baseline
  + aqueous/dissolution pass
  + thermal/phase pass
  + combustion pass
  + corrosive/reactive pass
  + electrical/special pass
  + sparse pair-exception passes
```

A later pass records a delta/override and may supersede a chosen value, but does
not delete the earlier evidence. Each pass records exactly what changed and
compares against the previous accepted profile plus all affected retained
regressions.

The coverage ledger distinguishes at least:

- inherited/default;
- explicitly non-interacting;
- characterized and accepted;
- accepted with known limitation;
- candidate rejected;
- superseded tuning choice with retained evidence;
- untested/not yet characterized;
- explicit material/pair override.

Coverage percentages must not imply that every ordered pair deserves a bespoke
rule.

### Rolling physics baselines

Do **not** wait for a single permanent `physics-contact-baseline-v1`.

Every accepted interaction result instead pins the relevant contact/motion
identity: source revision, transport/Water/granular policies and any other
physics configuration that materially affects whether/how the materials meet.

If later kinetic work changes that contact regime, mark the affected interaction
evidence for targeted re-screening. Unrelated accepted interaction evidence stays
valid within its stated scope.

This separates questions such as:

- "the reaction probability/cadence is wrong";
- "the materials no longer meet often enough";
- "the product is created with the wrong support/state";
- "the visual result changed while authoritative conversion did not".

## Generated interaction fixtures and workbench

Generate only topologies relevant to the mechanism, such as:

- A above B / B above A;
- horizontal interface;
- small quantity/droplet into bulk;
- sustained stream/contact;
- mixed or packed contact;
- heated/cooled starts where temperature matters;
- ignited contact where combustion matters;
- separated-then-release;
- barrier/control material;
- low/high quantity and short/long contact horizons.

A fixture definition should run:

- headlessly as characterization/regression;
- interactively in Materials Laboratory;
- in batch coverage campaigns;
- under human visual/feel review where appropriate.

The planned Interaction Workbench should expose the **effective** interaction
matrix/coverage without making that matrix the authored source of truth. A cell
should be able to show resolved channel values, rule origin/provenance, explicit
overrides, conflicts, relevant tests and what changed in the selected tuning
pass.

Where applicable, retain exact starting/ending quantities, conversions/products,
source/sink/outflow ledgers, Water/fractional quantity accounting,
temperature/phase/lifetime changes, reaction attempts/successes, emissions,
time-to-first-reaction/quiescence, work/performance and repeat/worker identity.

## Showcase catalogue and staging

Do not create every showcase issue before its underlying systems are useful to
exercise. The ten current concepts remain:

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

#28 owns items 2, 4 and 10 as the first pack.

A useful *soft* maturity progression for later focused showcases is Shooting
Range -> Mining -> Sewer, then Environmental Puzzle Room -> Breach-and-Extract,
then Utility-Tunnel Incident -> Industrial Accident. This is not a license to
ignore real dependencies or infer a GitHub-number sequence.

## Agent checkpoint protocol

Before starting any issue in or adjacent to this programme:

1. Read root `AGENTS.md`, the development handover, status/roadmap and this page.
2. Inspect actual branch/HEAD/status and active overlapping PRs.
3. Read the target issue plus its **named** dependencies; do not sort issue numbers.
4. State which hard prerequisites are satisfied and which lanes are merely parallel.
5. Preserve current source/ADR ownership. A scenario need is not permission to
   implement an engine feature inside scenario code.
6. When an exploratory anomaly appears, capture/reduce/triage before assigning it
   to a subsystem.
7. At every checkpoint, update this programme, roadmap, retrieval routes/corpus and
   affected issue mirrors together if dependency/order/scope changed.
8. Preserve dated/historical evidence; never rewrite old results to make them match
   the new scenario/profile/source.
9. Run documentation/retrieval/repository checks required by
   `documentation-maintenance.md` and report inherited failures separately.

If an autonomous agent cannot reconcile the issue body with this programme and
the architecture programme, it must treat that as a planning contradiction,
record it, and resolve the documentation/issue mirror before changing physics.

## Completion boundaries

MS-000 is complete when a small stable scenario apparatus exists and migrated
controls retain authoritative behavior.

MS-001 is complete when the three first-pack scenarios use the same framework
cleanly; exploratory versions may precede architecture stabilization.

INT-000 is complete when sparse layered/versioned interaction definitions,
generated fixtures, provenance/coverage, comparison tooling and the Materials
Laboratory path can support later bounded tuning passes without overwriting prior
work.

None of those completions by itself approves a Cell layout, motion
representation, reaction retune, kinetic-physics change or replay contract.

## MS-000 source checkpoint, 2026-09-19

**Current in this source checkpoint:** the [version-1 contract and shared host](microscenarios.md)
wrap existing Tower and 35 Water Feel recipes, with a shared catalogue/launcher,
bounded events/observations, objective status, JSON import/reset, truthful capture
and a native-only headless runner. New unequal-head Water and Sand-release fixtures
are exploratory proving consumers, not registered physics experiments. The isolated
#24 focus correction is carried with automated input coverage; issue closure and
main-branch merge remain separate from this source record.

[Dated validation](../audits/2026-09-19-issue-27-microscenarios.md) identifies actual
platform scope and pending checks. #28 can build on this fixture API once its source
checkpoint is accepted; the Materials Laboratory readiness gate is not asserted by
this harness. #18/#20/#26 scientific controls and #14/G-final are unchanged. Do not
infer those decisions from the presence of a reusable apparatus or from issue numbers.


## INT-000 bounded preflight checkpoint, 2026-09-19

**Current planning evidence only:** the
[issue #29 preflight audit](../audits/2026-09-19-issue-29-preflight.md) inventories
the source-backed interaction surface on `main`
`de332eaf8f4e70b25b097bed0c2e2a7b2aac0173`, separates compact pair reactions
from source-driven neighbourhood/lifecycle semantics and kinetic exclusions, and
records the candidate sparse schema, coverage/provenance model, fixture families
and post-gate implementation touchpoints.

The implementation gate remains **closed** at this checkpoint. #27's stable
fixture contract is present, but #28's active execution record explicitly says
Materials Laboratory readiness has not yet been established. The preflight makes
no runtime/framework change, does not retune any material and does not create
executable #29 fixtures. A later #29 agent must first verify source-identified #28
readiness evidence, reconcile the preflight against the landed generated-fixture
contract, and only then begin implementation.
