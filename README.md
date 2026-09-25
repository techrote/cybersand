# CyberSand

CyberSand is a C++20 cellular simulation engine hosted by Godot, with a material
lab and bounded Rapier2D/cellular coupling proof. The longer-term product intent
is a reusable foundation for cyberpunk RPG and exploration games.

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

[Dated validation](docs/reference/validation-evidence.md) records what actually
ran and which artifacts/platforms it covers. CYSD1 restores levels, not exact
replay continuation. Review [license status](LICENSE_STATUS.md) and
[third-party notices](THIRD_PARTY_NOTICES.md) before distribution.
