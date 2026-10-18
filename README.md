# CyberSand

Desktop opens the [combined feature launcher](docs/operations/physical-actor-programme.md): showcase maps, actor/material sandboxes, Thunderbowl, Strata Theatre depth studies, generation authoring and the initial physical barrel/Ripper Blacksite comparison. F2 returns to the launcher and closes the current session.

CyberSand is a C++20 cellular simulation engine hosted by Godot, with a material
lab and bounded Rapier2D/cellular coupling proof. The longer-term product intent
is a reusable foundation for cyberpunk RPG and exploration games.

F5 selects **Sampled** rigs or **Rapier** barrel/Ripper in the sandbox, Blacksite and all four showcase districts. Applying restores the selected map; R retains the actor. A/D drives physical bodies, Q/E adds torque and Space supplies an upward pulse.

## Blacksite Nine

Press **Shift+F11** or click **Blacksite Nine** to open a continuous 3 × 3
industrial complex. A fortified research laboratory sits between two ruined
wastelands, above six dense underground districts: worker warrens, containment
galleries, condensate machinery, crushing works, an instrument vault and a flooded
pump terminus. All nine share one native world, with twelve connected passages.

Use the **3×3 tile map** to inspect a district, **Whole complex** for the atlas,
or **F** to follow the player through the narrow routes. The scene starts paused;
**P** runs it, **A/D** move, and holding **Space** rises through shafts. Camera
changes preserve the entire complex and its edits; **R** restores all nine
districts together. It is also available in the Web demo menu. See the
[Blacksite Nine guide](docs/operations/blacksite-nine-demo.md) for the route,
controls, construction and reproducible captures.

![Blacksite Nine rendered in CyberSand](docs/images/blacksite-nine/blacksite-nine.png)

## Neon Reliquary and the city below

Press **F11** or click **Neon Reliquary** in the desktop sandbox to open an
elaborate machine cathedral: a suspended cyan engine, stained glass, stacked
service buildings, cable runs and a flooded nave. It is also available in the Web
demo menu. From there, use **Below** to descend through **Middle Cyberberbia**,
**Sewertech Alley**, and **Industrial Underswamp**: stacked homes and a garden
bridge, a dense technological sewer ravine, then drowned and overgrown machinery.
Each tile opens in its original paused layout with five camera views. Press
**F8** for a clean view and **P** to animate the materials.
See the [four-tile scene guide](docs/operations/neon-reliquary-demo.md) for controls,
construction details and reproducible captures.

![Neon Reliquary rendered in CyberSand](docs/images/neon-reliquary/overview.png)

## Development

**Current source, reviewed 2026-09-08:** this checkout preserves the acquired
`web-demo-m11` history plus existing local work, checkpointed before the RAG
rewrite as `126175c`. Inspect current HEAD/status; historical M11 `BUILD_ID` and
Web export base fields are different identities. See
[source checkpoint](docs/operations/source-checkpoint-and-recovery.md).

Start with [AGENTS.md](AGENTS.md), the [handover](docs/operations/cybersand-codex-development-handover.md)
and [focused documentation](docs/README.md). Use the
[roadmap](docs/reference/status-and-roadmap.md) before foundational physics work:
failed ticks now quarantine the affected world, and phased interest re-entry
resumes retained activity. Their separate acceptance and remaining gaps are recorded.
For current MicroScenarios/intermaterial-interaction sequencing, do **not**
infer order from GitHub issue numbers; use the
[canonical programme graph](docs/operations/microscenarios-programme.md).

[Current validation and retained M11 integrity](docs/operations/current-and-historical-validation.md)
explain the independent source/runtime and historical checks.

The active Windows workspace is `C:/kybersand`; from there:

```text
dev.cmd doctor
dev.cmd native-test
dev.cmd godot-test
dev.cmd web
0Preview.cmd
```

A source-only checkout also has a repository-contained Windows desktop path:
`launch-desktop.cmd`. It validates the pinned Godot/runtime inputs, prints the
checkout/runtime identity and launches `godot/project.godot` without rebuilding
the retained DLL; see the build guide for overrides and identity-only use.

[Build instructions](docs/operations/local-build-and-validation.md) distinguish
native DLL compilation, tests, Web exports and browser execution. Godot uses the
exact 4.7 pin. Desktop has an asynchronous simulation owner; Web ticks are
synchronous even with internal pthreads. Rapier objects stay on the main thread.
The GDScript fallback has different material semantics.

The desktop sandbox includes 29 provisional
[actor rigs](docs/systems/actor-rigs.md) in six sets: the original **SetA**
Runner/Skimmer/Crawler controls, **SetB** ground machines, **SetF** flight and
descent, **SetY** contact/rope/impulse traversal, **SetU** salvage-tool movers and
**SetV** fictional interface personas. Open **F5** to choose a rig and a keyboard,
scripted-demo or external-policy pilot, adjust power and compare the other rigs
in its set. All share a bounded input/observation boundary; neural inference is a
future consumer. The [SetA contract](docs/systems/actor-control-prototypes.md)
retains the original motor and policy compatibility details.

The standalone [Thunderbowl control reference](docs/systems/thunderbowl-control-reference.md)
adds a native battle/training test area, runnable controller scripts and eight
versioned JSON schemas. Compare assisted controls, direct actuator profiles,
oracle teams, independent and coordinating swarms, an untrained NCA-inspired
controller and an external smart-link adapter. The first arena uses explicit
virtual tag combat, with at most eight rigs and bounded local observations.
Run its separate scene or headless examples using the reference commands.

[Dated validation](docs/reference/validation-evidence.md) records what actually
ran and which artifacts/platforms it covers. CYSD1 restores levels, not exact
replay continuation. Review [license status](LICENSE_STATUS.md) and
[third-party notices](THIRD_PARTY_NOTICES.md) before distribution.
