---
title: MicroScenarios contract and shared host
status: Current
document-kind: contract
scope: MS-000 schema 1 and compatible MS-001 schema 2 definitions, bounded owner lifecycle, shared modes, inspection and fresh-reset comparisons; not physics architecture or full replay
canonical-for: [microscenario-contract, microscenario-host, microscenario-capture]
last-reviewed: 2026-09-19
related-documents: [microscenarios-programme.md, experiment-tower.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/level-saves-and-replay.md, ../audits/2026-09-19-issue-27-microscenarios.md]
---

# MicroScenarios contract and shared host

## Current implementation and authority

**Current source:** MS-000 adds one data validator, catalogue and owner-local host
around existing native builders and operations. `microscenario_contract.gd`,
`microscenario_catalogue.gd` and `microscenario_host.gd` in `godot/scripts/` own
those responsibilities. The MS-000 extraction changes no native source. MS-001
adds the read-only native adapter described below, not material kernels, solver,
Cell layout, transport defaults, reaction cadence or production Water precision.

The catalogue wraps the unchanged version-4 Experiment Tower and all 35 version-1
Water Feel recipes. Two new **exploratory** fixtures, `fixtures/unequal-head` and
`fixtures/sand-release`, exercise generic scheduled release, observation and
objective logic without Water-specific scene scripts. The unequal-head fixture is
#26-style apparatus, **not** a registered #26 baseline, candidate or accepted fix.
The Sand fixture establishes a non-Water consumer.

The [programme](microscenarios-programme.md) still owns ordering. #27 does not
admit #18 compact motion, #20 sparse ballistics, #29 interaction tuning or
#14/G-final. No #20-style ballistic event is implemented while its admission is
held. The host is useful to exploratory #28 authoring; the separately evidenced
[MS-001 Materials Laboratory](microscenario-reference-pack.md) owns the #28 readiness checkpoint.

[Validation](../audits/2026-09-19-issue-27-microscenarios.md) distinguishes Linux
native execution, both existing controller code paths, automated GUI input and
unavailable Windows/real-browser/GPU coverage. A catalogue `reference` label means
an existing recipe baseline, not physics approval or new all-platform acceptance.

## Versioned definition and validation

A definition is JSON data, not executable code. `CyberMicroScenarioContract.base`
provides a complete schema-1 template; `validate` checks in-memory data and `parse` checks
bounded JSON. Unknown or missing fields, invalid types, fractional integer fields,
non-finite numbers, out-of-world regions and capacity excess are rejected before
native replacement. Integral JSON floats are normalized to integers, including
validated transport settings, so canonical JSON round trips keep the same SHA-256.

All root fields are required:

| Fields | Meaning |
|---|---|
| `schema_version`, `id`, `recipe_version`, `seed`, `maturity` | Schema 1 or 2; stable ID; positive recipe version; 0..2147483647 seed; `exploratory` or existing `reference` baseline |
| `rectangles` | Flat setup records `x,y,width,height,material`; current IDs 0..80 except reserved 10 |
| `partial_water_fills` | Flat records `x,y,width,height,normalized_mass,coherence`; existing fractional Water setup, not a generalized fractional-liquid solver |
| `transport_profile`, `water_semantics` | Existing validated transport profile and native Water packet `[1,mass_bits,coherence_ticks,0]`; mass3..8, coherence0..12 |
| `player_start`, `camera_origin`, `player_enabled`, `body_enabled`, `tools` | Initial positions, existing character/body participation and admitted `paint`, `erase`, `player` tools; no new entity system |
| `interest`, `execution` | Declared owner-controlled or fixed region and existing cadence/adhesion settings |
| `events`, `observations`, `conditions` | Bounded ordered existing operations, read-only observations and objective/failure predicates |
| `source_recipe`, `source_recipe_hash` | Ancestral recipe identity, distinct from the canonical full definition hash and actual runtime identity |
| `presentation` (schema 2 only) | Required bounded title/instructions/duration/baseline/profile/region metadata; forbidden in schema 1 |

The finite demo world remains 1024 by 1024. Rectangles/fills must be wholly inside
it, with positive dimensions. Limits are 4096 records per setup array; total
rectangle write area at most eight world areas and partial-Water area at most one
world area. Overlaps are intentional, ordered setup writes, not extra capacity.
JSON is limited to 1 MiB. Seeds select the declared deterministic recipe; they do
not introduce a new global random-number generator. Legacy Tower supports seed
zero only; legacy Water seed semantics remain unchanged.

### Region and execution policy

`interest` is `{policy,region}`, where region is `[x,y,width,height]` and policy is
`owner` or `fixed`. `execution` contains `policy`, `cadence_lod_enabled` and
`liquid_surface_adhesion_enabled`. Existing #13/#19 wrappers retain owner settings
and their established controls. Their comparisons must also match those owner
settings, character inputs and body samples.

The new proving fixtures use a fixed region, cadence disabled and existing
adhesion enabled. The same owner-local settings are applied in desktop, synchronous
Web and headless execution; live cadence/adhesion overrides are refused for these
fixed fixtures. Camera movement cannot change their admitted active region.
A fixed execution policy with cadence enabled still needs matched owner interest
inputs; disabling cadence is the supplied fixtures' way to avoid that dependency.
Worker count remains an explicit owner/runner configuration, recorded separately.
Nothing changes the native excluded-region pause/no-catch-up contract.

### Scheduled operations and observation timing

Events retain the small existing Water recipe record shape:
`tick,kind,x,y,width,height,material,normalized_mass,coherence`. There are at most
24, ordered by tick, with stable authored order for ties. Their summed region area
is at most one world area. Events execute **before** the next native tick when the
completed tick equals the event's tick. Their admitted indices are 0..3599.
There is no recurring timer, callback or arbitrary per-tick cell-write escape.

`fill` requests existing normalized Water fill; `erase` requests the existing
native region erase for any material; `sample` is read-only. A legacy Mercury
sample retains material ID 33 as metadata, not a special simulation operation.
Coherence scaling and Water source/sink deltas match the old Water owners.

Observations contain `id,tick,metric,region,material`, with at most 24 unique IDs,
ordered completed ticks 0..3600, and total region area at most one world area.
Schema-1 metrics are `water_integer`, `material_cells` and `tick`; schema 2 also
admits a one-cell structured `cell_state` probe. Material-cell counting
is refused for body-enabled definitions because the existing point-query API can
be masked by bodies; it must not be advertised as an authoritative masked census.
Schema 1 has no temperature/entity/electrical probes. Schema 2 adds the bounded
existing-field query described below, not a new temperature or electrical solver.

Tick-zero observations happen after setup and before tick-zero events. Later
observations happen after a successful completed tick. Each observation runs once.
A condition names an observation, an integer threshold, `eq`/`le`/`ge`, and outcome
`complete`/`fail`. Failure takes precedence. Objectives observe physics; they never
change cells or automatically stop the world. Optional instrumentation may be off,
but observations needed by objective predicates still execute as read-only logic.

## Ownership, reset and failure

`CyberMicroScenarioHost` belongs to the **existing** mutable World owner: the
GDScript simulation thread on desktop, the synchronous main-thread owner on Web,
or the explicitly native-only headless runner. Native pool workers still call no
Godot APIs. The host never owns live Rapier scene objects or mutable render storage.

`install` validates and resolves the complete candidate before calling the
existing native candidate-and-swap builder. On rejection the old World, scheduled
cursor and retained observations remain intact. Accepted reset creates a fresh
paused world, clears prior schedules/observations and retains only declared recipe,
mode and selection state. Main-thread desktop acknowledgement waits for the new
immutable summary before changing the active UI. Pending reset cannot be replaced
by a new generic step/capture command. Explicitly choosing Tower/Water can cancel
that pending selection through their existing reset path.

Both controllers call the same `before_tick`/`after_tick` host around their existing
physics order. Desktop character-before-cell and Web character-after-cell order
are **not** silently unified. Headless `advance` has neither character nor Rapier.
A missed event/observation or skipped completed-tick boundary latches a visible host
fault instead of catching up. Native failure remains native quarantine; no partial
native observation is exported as success, and no automatic retry occurs. Only a
fresh admitted reset clears the fault.

Definitions, summaries and captures are copied values. Desktop capture is requested
at the owner boundary and frozen recursively once before publication; a retained
record can be shared by successive snapshots without mutable nested dictionaries
or a large per-frame definition copy. The consumer never reads the worker's World.
This does not claim that the pre-existing general input queue is now bounded.

## Play, Inspect and Benchmark controls

The shared `CyberMicroScenarioPanel` is used by both controllers. Choose a catalogue
entry, mode and seed, then **Load selected**. **Fresh reset** preserves the active
scenario definition; R also resets a generic fixture instead of silently returning
to Tower. Pause/resume and bounded single-step use existing owner commands.

Play hides the legacy developer panel and shows objective/status. Inspect and
Benchmark expose available observations and capture; all three use the same
validated definition, native operations and physics. No GUI mode selects a different
solver. F8 hides/restores the common HUD and Tower labels for captures. Optional
players are not simulated or drawn in the supplied player-disabled fixtures.

**Definition JSON** opens a bounded paste/edit view for a complete definition.
Validation failure leaves the running world untouched; application is always a
fresh reset, never live parameter mutation. For generic fixtures the draft is the
installed definition; otherwise it is the selected catalogue template. Actual Water
policy/blind-run controls remain in their original panel. The generic editor and
capture route are disabled during a blind session to avoid leaking hidden policy.
Use the established blind reveal/export workflow instead.

The root Tower entry button has the isolated #24 `FOCUS_NONE` correction; common
launcher buttons and pickers are also non-focusable. The modal JSON editor uses
normal text-entry focus while the simulation is paused. A seed text editor remains editable
and releases focus on Enter or Load. Automated input regression covers mouse entry,
Space press/repeat/release and F9 non-echo handling; it is not owner visual approval.

## Headless runs from the same definition

With the repository's pinned Godot and native runtime:

```text
godot --headless --path godot --script res://tests/run_microscenario.gd -- --scenario=fixtures/unequal-head --seed=2 --ticks=120 --workers=1 --mode=Benchmark --output=observation.json
```

A generated definition can be passed using `--definition=/absolute/fixture.json`.
This option takes the complete JSON definition as authoritative, rather than
silently overriding its seed with a catalogue default. Its JSON can also be pasted
into the common UI. `--observers=off` disables optional logs/timings, not physics or
objective semantics. Allowed ticks are 0..3600 and worker count 1..32, subject to
native platform support. The output directory must exist. Unknown options and
invalid values fail with exit 2; run failure or a failure objective exits 1.
Output is written to a temporary file and renamed after a successful write.

The runner refuses player/body-enabled definitions rather than silently omitting
those owners and claiming interactive parity. It records its native-only scope.
`--source-sha=<full-40-character-revision>` supplies an explicit build/checkout
identity; omitted identity is **unavailable**, not inferred from historical M11.

## Capture, provenance and limits

The GUI writes `user://microscenario-observation.json` and copies JSON to the
clipboard where available. Headless output uses the requested path. Captures retain
canonical definition/hash, seed/version/maturity, original recipe identity, actual
Water and transport selections, execution flags, worker count, source/runtime
fingerprints, completed tick, bounded actions/observations and objective state.

`CyberMicroScenarioIdentity` hashes actual available apparatus scripts and the
platform native artifact. It labels missing source/artifact data unavailable;
script-set identity is not a full-checkout attestation. The native artifact
identifies authoritative material code and a hashed `cell_world.gd` identifies the
UI catalogue mirror. Source revision supplied by a caller is labelled as such.
Exported/converted Web files may not be readable as source; no historical manifest
is substituted as if it identified the executing build.

Optional native tick timing retains the first 3600 samples, p50/p95/p99/max,
total/count and an explicit truncation flag; it excludes observation, renderer,
Rapier and owner costs. The CLI separately reports advance-loop wall time including
enabled observers, excluding setup/export. These are measurements for that run,
not a new production performance claim or registered physics experiment.

Water ledgers identify initial quantity and before/after deltas of scheduled edits.
They do not fabricate accounting for reactions, arbitrary player tools or finite-ROI
outflow. World hashes are diagnostics, not proof of complete replay. Captures say
`replay_complete=false` and are **definition plus observations, not a restorable
runtime snapshot**. Generic level export/import is disabled while controlled
scenarios are active because CYSD1 omits their lifecycle. Capture/reduce/triage is
supported, but full organic user-input replay, generalized probes, new interaction
rules and a production persistence redesign remain separate work.

## Schema 2: complete apparatus presentation and existing-field inspection

**Current source:** schema 2 is opt-in. Schema-1 definitions, canonical hashes,
legacy Tower/Water recipes and their controls remain unchanged. It adds exactly
one required `presentation` record: `title`, `instructions`, `duration_ticks`,
`baseline`, `profile`, `regions`. Text is bounded (128 characters for title and
identity labels, 4096 instructions); duration is 1..3600 completed ticks. At most
12 unique named regions carry an in-world rectangle and a label of at most 96
characters. Presentation never changes native physics. The ancestral recipe hash
is distinct from the complete definition hash and from the executing build.

A schema-2 `cell_state` observation is exactly one cell. It returns copied stored
material/state, raw temperature availability, body-mask identity and chunk/block
coordinates through the [exclusive-owner native query](../reference/interfaces-and-message-contracts.md#read-only-native-microscenario-inspection).
It cannot be used as a scalar condition. Raw temperature is not a calibrated heat
solver; masked temperature is unavailable, not falsely reported ambient. There
is no entity census or per-cell awake flag. New capabilities require the rebuilt
adapter: a stale runtime is rejected **before** replacing the previous world.

No event type or capacity is added. In particular, a scheduled Water fill must
have positive normalized mass; zero-mass fills are now rejected during pure
validation because native already rejects them. Use an explicit erase for a sink.
Initial partial-fill semantics and historical valid definitions are unchanged.

The common workbench displays all declared probes (including pending ones), all
retained results, complete identities, effective profiles, bounded native work
statistics and instructions. Its A/B slots hold two independent validated complete
definitions and at most one capture per slot. **Every load is a fresh reset** via
the existing acknowledged desktop or synchronous Web owner. Invalid edits preserve
the active world and slots; no parameter is written into a live worker. Matching
runtime/tick/seed is necessary, not sufficient to claim matched organic brush input.
Blind sessions disable these definition/capture routes exactly as before.

**Run declared window** sends one existing single-step command at a time and waits
for its owner acknowledgement, stopping at the declared completed tick. It is
bounded by 3600; pause changes, reset/hash changes, quarantine or missing owner
acknowledgement cancel it without retry/catch-up. This is neither a recurring
native event nor another physics loop. F8 hides labels, dialogs and HUD. Generic
controls show only admitted tools; material selection and radius use the existing
brush command path. Full controls and generated definitions are in the
[reference pack](microscenario-reference-pack.md).

Schema-2 optional telemetry copies actual completed-tick work and configured
capacities. Native tick timing remains separate from before/after-host timing;
CLI advance-loop wall time is broader again. Rendering, Rapier and whole-frame
cost are not silently included in a native tick distribution. Missing queue
occupancy, total heap allocations, per-worker utilization and per-cell sleep
remain explicitly unavailable. Instrumentation off removes optional recording,
not required objective observations or authoritative behavior.
