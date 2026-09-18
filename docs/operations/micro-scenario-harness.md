---
title: MicroScenario harness and fixture contract
status: Current
document-kind: contract
scope: MS-000 schema, bounded host, launcher, capture and headless execution; not material physics or programme admission
canonical-for: [micro-scenario-contract, micro-scenario-host, micro-scenario-capture]
last-reviewed: 2026-09-19
related-documents: [microscenarios-programme.md, experiment-tower.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/level-saves-and-replay.md, ../audits/2026-09-19-ms000-harness.md]
---

# MicroScenario harness and fixture contract

**Current:** MS-000 provides declarative recipes and one bounded owner-side host.
The catalogue contains the unchanged Experiment Tower, all 35 Water Feel recipes,
and an independent `communicating-reservoirs` proving fixture. This is apparatus,
not a new physics implementation or an H-study result. Programme admission and
#24/#27–#30 sequencing remain in the [programme](microscenarios-programme.md).
Platform evidence and gaps are in the [dated audit](../audits/2026-09-19-ms000-harness.md).

## Definition and validation

[CyberMicroScenarioContract](../../godot/scripts/micro_scenario_contract.gd) accepts
JSON data, rejects unknown/missing fields and nonintegral numbers, normalizes
profile defaults with the existing resolvers, sorts object keys, and hashes the
normalized definition. JSON round trips retain that identity.

| Fields | Meaning |
|---|---|
| `schema_version`, `id`, `recipe_version`, `seed`, `seed_scope`, `maturity` | Schema 1; stable name and versioned recipe; explicit exploratory/revalidation status. Seed scope is recipe identity, **not reseeding native physics**. Tower is fixed at seed zero. |
| `rectangles`, `partial_water_fills` | Ordered, flat setup records: five integers `(x,y,w,h,material)` or six `(x,y,w,h,normalized_mass,coherence)`. Ordering and overlap are meaningful. |
| `transport`, `water_policy` | Existing validated transport profile and optional semantic Water policy, applied only through native candidate construction/reset. Empty Water policy retains ordinary Tower behavior. |
| `events`, `conditions` | Finite ordered operations and sample-based conditions; no callbacks, loops or arbitrary script execution. |
| `player_start`, `camera_origin`, `body_enabled`, `tools` | Optional sampled player, initial view, existing scene-owned body capability, and an explicit `paint`/`erase`/`jetpack` allow-list. |
| `legacy` | Original Tower/Water family and recipe hash, separate from the new schema hash. Metadata changes are not physics changes. |

The complete copyable example is
[`communicating-reservoirs-v1.json`](../../godot/scenarios/communicating-reservoirs-v1.json).
A definition is capped at 2 MiB, 4096 records per setup array, 24 events through
tick 3600, and eight conditions. All regions lie within the existing 1024-square
world. Setup areas are capped at eight world areas for rectangles and one for
partial Water; cumulative event area is at most one world. Material counting is
limited to 32768 cells per declared sample. Material IDs remain the existing 0–80
catalogue; no material or interaction channel is added here.

Scheduled operations are **Water fill**, **erase**, and **sample**, invoked before
the next native tick once their declared completed-tick boundary is reached.
For example, a tick-120 sample requires running through the boundary before tick
121. Same-tick operations retain array order. Conditions reference a sample and
compare Water quantity, Water cell count, sampled material occupancy, or tick
against a bound. Occupancy sampling may include body-mask occlusion; it is not
an unqualified underlying-material quantity measure.

## Owner, reset and mode boundaries

[CyberMicroScenarioHost](../../godot/scripts/micro_scenario_host.gd) is owned by
the existing desktop simulation thread or synchronous Web controller. It creates
no threads, performs no ticks and calls no scene/Rapier objects. Native candidate
build/swap remains the world-replacement authority. Invalid definitions or failed
builds do not replace the world, frozen definition, event cursor or objectives.
Successful reset clears run history, observations, objectives and event failure.
A rejected event stops the run; it is not automatically retried.

Main-thread desktop requests are validated and copied before entering the existing
single-command mailbox. Apply/capture acknowledgements are copied into immutable
snapshots. Pending resets cannot be overwritten by launcher controls. After tick
failure, diagnostic capture may be acknowledged, but physical payloads remain the
last completed publication and no partial-world observation is presented as valid.

Play, Inspect and Benchmark consume the same definition. Play disables optional
sample retention; condition evaluation and the finite event/edit ledger remain
active. Generic fixtures use a fixed whole-world domain with cadence LOD disabled
and adhesion enabled. Legacy Tower/Water paths retain their original owner/view
configuration; leaving a generic fixture restores those settings. Desktop still
moves the sampled character before cells and Web after cells. Compare only matching
owner/configuration scopes, not unrelated player/body traces across platforms.

## Launcher, inspection and capture

Both existing scenes expose the shared selector, mode and seed fields, fresh reset,
pause/resume, one tick, JSON definition editor, observation capture and F4 HUD hide.
R resets the current generic definition. The Tower launcher does not take keyboard
focus; Space remains available to navigation. Text entry suppresses movement and
paint input. The generic launcher/JSON/capture routes are unavailable during a
registered blind Water session: its existing reveal/export controls remain authoritative.

Capture writes `user://micro-observation.json` and copies JSON when clipboard access
exists. It retains the frozen definition, scenario/schema/recipe/seed identity,
effective profiles and hashes, owner configuration, actual native artifact hash,
source-file hashes, retained build manifest, bounded actions, observations and
objective state. `CYBERSAND_SOURCE_REVISION` can supply the source commit; absent
that value, the export explicitly reports it unavailable and retains file hashes.
A retained native manifest is a historical build record, not new platform acceptance.
Web binary/source access may be unavailable: retain the matching export manifest
externally rather than inventing those identities.

These are **observation-and-recipe captures, not exact replay or continuation
saves**. Live inputs, Rapier continuation and complete future-affecting state are
not serialized. Scheduled source/sink accounting excludes reactions and manual
edits. Generic runs therefore reject CYSD1 export rather than lose their timeline
silently. Existing ordinary level-save semantics are unchanged. To investigate an
anomaly, copy the definition and capture, reduce the recipe/events, then classify
and retain the reduced fixture under its actual physics/interaction owner.

## Headless execution and regression checks

Run from the repository root with the pinned native runtime installed:

```sh
Godot --headless --path godot --script res://tools/micro_scenario_benchmark.gd -- \
  --scenario=communicating-reservoirs --seed=17 --ticks=121 --workers=4 \
  --mode=benchmark --observers=on --output=user://micro-benchmark.json
```

`--definition=/absolute/path/fixture.json` loads the same standalone data accepted
by the interactive editor. The file's seed is authoritative. Ticks are bounded at
3601; requested and actual worker counts are recorded. `--observers=off` tests
instrumentation independence. Timing includes host events, the stationary sampled
character when declared, and native ticking; it excludes final capture. It is not
production performance acceptance. Body-enabled recipes fail explicitly in this
cellular runner and require the existing scene/Rapier owner instead.

`test_micro_scenario_contract`, `test_micro_scenario_runtime`,
`test_micro_scenario_controllers` and `test_tower_launcher` join the normal
`run_godot_regressions.py` discovery. Legacy #13/#19 tests remain in that same suite.
No #20 bounded-event fixture is registered: its separate admission remains required.
