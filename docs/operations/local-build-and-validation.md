---
title: Local build and validation
status: Current
document-kind: guide
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-10-22
related-documents: [source-checkpoint-and-recovery.md, testing-validation-and-replay.md, web-threading.md, deepworks-exhibition.md, ../systems/depth-layers-and-parallax.md]
---

# Local build and validation

## Which build inputs are required?

**Current:** build scripts and locks select the following inputs. A pin is a
requirement, not evidence that every platform artifact was built or tested.

| Input | Required identity and authoritative reference |
|---|---|
| Godot editor/runtime | `4.7.stable.official.5b4e0cb0f`; [runtime lock](../../third_party/godot-runtime.lock.json) |
| godot-cpp / API | `101ae38034304346a46ea9ea84ae156d3e860496` / `4.7`; [native lock](../../third_party/native-toolchain.lock.json) |
| SCons | `4.10.1`; [hash-pinned requirement](../../tools/requirements-build.txt) |
| Windows compiler | LLVM-MinGW 20260826, Clang 23.1.0, UCRT; native lock pins the Linux-host archive; local Windows ZIP is a distinct input |
| Linux compiler/linker | GCC/G++ 13.3.0 / binutils 2.42; native lock |
| Web compiler | Emscripten **4.0.20**, checked by [build_web.py](../../tools/build_web.py) |
| Rapier2D | Official single-precision 2D **v0.35.2**; [Rapier lock](../../godot/third_party/rapier2d.lock.json) |
| Web templates | Exact Godot 4.7 dlink templates: `web_dlink_nothreads_{debug,release}.zip` for compat, `web_dlink_{debug,release}.zip` for threaded |

Keep native and Web godot-cpp checkouts separate: generated bindings and archives
are target-specific. Python 3.12.14 was used locally; the workspace helper requires
Python 3.10+. Do not silently update pins while debugging a simulation change.

The historical runtime lock still labels templates `absent-and-unpinned` although
the local Windows setup has exact templates. This is an unresolved release-lock
gap. The configured Web CI also disagrees with the builder; see
[release prerequisites](github-development-and-release.md#unresolved-ci-contradictions).

## Windows development commands

From `C:/kybersand`, the companion workspace provides `dev.cmd` / `tools/dev.py`.
Host paths, installation and environment overrides belong to
`C:/kybersand/docs/LOCAL_DEVELOPMENT.md`. Source-only clones do not contain these
wrappers; the repository-native scripts are listed below.

```powershell
.\dev.cmd doctor
.\dev.cmd native-bindings
.\dev.cmd native-build
.\dev.cmd native-test
.\dev.cmd godot-test
.\dev.cmd web
# Optional internally parallel Web profile:
.\dev.cmd web --profile threaded
```

The repository also contains `launch-desktop.cmd` /
`tools/launch_desktop.ps1` for source-only Windows checkouts. It validates the
pinned Godot/runtime inputs, prints checkout/runtime identity, exports the exact
checkout SHA to the child Godot process as `CYBERSAND_SOURCE_REVISION` for
recording provenance, and does **not** rebuild or replace retained runtimes.

`native-bindings` builds pinned Windows godot-cpp; `native-build` builds the
GDExtension. `native-test` compiles/runs the C header check and native tests;
`godot-test` imports the project then runs all `test_*.gd` runners. Godot tests
load the installed DLL: running them alone does **not** rebuild that DLL.
Record its hash and source identity with the result. The wrapper allows 240 s
for import, 180 s per Godot runner, and rejects Godot error output even with exit 0.

### Repository-contained Windows desktop launcher

**Current:** a source checkout can launch the retained desktop test project without
the companion-workspace `dev.cmd`:

```powershell
.\launch-desktop.cmd
.\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe
.\launch-desktop.cmd -PrintIdentityOnly
.\launch-desktop.cmd -Editor
```

The wrapper invokes [`tools/launch_desktop.ps1`](../../tools/launch_desktop.ps1).
It accepts an explicit `-Godot` path or `CYBERSAND_GODOT`; otherwise it searches
the established `C:\Godot47` location. It requires exactly
`4.7.stable.official.5b4e0cb0f`, verifies that the project, retained CyberSand
Windows DLL/provenance file and Rapier Windows DLL are present, verifies the
CyberSand DLL SHA-256 against `runtime-provenance.json`, and prints checkout,
Godot and runtime identities before launch. The default action runs
`godot/project.godot` through its configured `main.tscn`; `-Editor` opens the
same project in the editor.

The launcher deliberately contains **no build step**. A missing, hash-mismatched or
wrong-version runtime is an explicit failure; it never rebuilds, replaces or
silently refreshes the retained DLL.

M11 output byte equality now requires `CYBERSAND_VERIFY_M11_OUTPUT=1`; current
builds keep compiler/source pin checks and identify their own tested outputs. See
[validation policies](current-and-historical-validation.md). The existing local
`CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` override bypasses some compiler/dirty-source
checks. It still
requires the exact godot-cpp revision. Inspect that checkout explicitly; a local
validation build with this override is not bit-identical M11 reproduction.

## Repository-native build and test commands

From the source root on a configured Linux host:

```sh
timeout 120 make test
timeout 300 make sanitize
timeout 300 make thread-sanitize
# GODOT_CPP_ROOT and SCONS_PYTHON identify the pinned dependencies:
timeout 3600 tools/build_pinned_godot_cpp.sh linux
timeout 3600 tools/build_native_extension.sh
timeout 60 tools/check_linux_runtime_floor.sh
```

These are executable entry points, **not current Linux pass claims**.
[Makefile](../../Makefile) defines Debug `-O0 -g3` tests, ASan+UBSan and TSan.
The default sanitizer target enables leak detection; the historical M11 run
disabled it after a hosted `/proc` limitation. Preserve that distinction.
Windows cross-builds use `build_pinned_godot_cpp.sh windows` and
[build_native_extension_windows.sh](../../tools/build_native_extension_windows.sh)
with `LLVM_MINGW_ROOT`/`WINDOWS_CXX`. PE/import inspection alone cannot prove a
Windows runtime launch.

The GitHub-hosted Native job has a 45-minute overall allowance. Its individual
build, test and benchmark commands retain their separate deadlines; increasing
the job allowance does not skip cases or relax sanitizer failures. The
[MAT-002 completion audit](../audits/2026-10-19-mat002-review-and-validation.md#completion-resumed--2258-utc)
records the observed 35-minute cancellation and preceding successful durations.

## Linux GDExtension CI sharding

**Current:** the [GDExtension workflow](../../.github/workflows/gdextension.yml)
builds the pinned Linux runtime once on GitHub-hosted `ubuntu-24.04`, verifies its
ABI/runtime floor and publishes that exact extension plus the pinned Rapier Linux
runtime as a short-lived artifact. Four isolated GitHub-hosted regression jobs
restore the same source/runtime identity and run deterministic subsets of the
Godot suite. Each shard performs its own clean headless import. Active external
or self-hosted runner routing is rejected by the repository policy checker.

The local/default invocation remains serial. Linux rendered-output tests need a
display; a software-rendered run can use Xvfb:

```sh
LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 GALLIVM_PERF=nopt xvfb-run -a \
  -s '-screen 0 1920x1080x24 -nolisten tcp' \
  python3 tools/ci/run_godot_regressions.py --godot <godot> \
  --output build/godot-regressions --keep-going
```

CI uses `--shard-count 4 --shard-index 0..3`. The runner still discovers every
`godot/tests/test_*.gd` automatically and explicitly includes
`profile_native_world.gd`, `profile_scheduler.gd` and scene startup. Approximate
historical timings only influence deterministic scheduling; they are not test
thresholds. Unknown/new tests receive a conservative default weight and must appear
exactly once in the union of shards.

`test_*_render.gd` cases automatically request the compatibility renderer; other
cases and import remain headless. Explicit skips are required-case failures,
including the former headless pixel-test skip. `--keep-going` records the rest of
the assigned cases after test failure, while import failure stops immediately.
Read each record and the final completion/status fields in `timings.json` before
claiming a pass. The [test-selection guide](testing-validation-and-replay.md#ci-execution-sharding)
owns these acceptance rules.

The initial migration PR proved exact serial/sharded coverage equivalence on the
same source/runtime/Godot identity. That serial lane is now opt-in only via
`GDEXT_SERIAL_EQUIVALENCE=1`; ordinary PRs use the sharded gate. The active workflow
uses literal GitHub-hosted runner labels and pinned build inputs; source/runtime
identity and the required exact-head gates are independent of shard scheduling.
Current build jobs set `SCONS_JOBS=2` directly; the
[repository provider policy](github-development-and-release.md) owns the runner
and provider-routing boundary.

## Windows retained-runtime execution

**Current:** the GDExtension workflow also executes the retained Windows DLL on a
GitHub-hosted `windows-2022` runner. This lane is separate from the Windows
cross-build job. The
[Windows execution helper](../../tools/ci/run_windows_godot_regressions.py)
requires an exact workflow checkout, committed LFS bytes, matching runtime
provenance and complete coverage of the current native source/header input set.
Any changed or newly added native input requires a matching runtime publication
before the retained DLL can satisfy this gate. Historical build-input hashes
continue to describe their original build.

The helper verifies the pinned official Windows Godot 4.7 archive, executable
version and Rapier runtime before import. It dynamically selects every discovered
headless case, including the two profile probes and scene startup, and preserves
the shared runner's per-case timeouts and error/skip rejection. Each applicable
case must execute exactly once. All discovered `test_*_render.gd` cases are
explicitly outside this Windows lane; Linux's rendered shards execute them.
After the ACT-005 integration, the source inventory is 97 Windows headless
cases and 103 Linux cases, with import counted separately. These counts describe
discovery, not an executed pass.

The job retains `windows-execution.json`, source/runtime/tool identities,
commands, individual logs and their SHA-256 hashes under the
`windows-godot-headless-<run-id>` artifact even when execution fails. The report
records incomplete import, failed cases, source drift and final completion
explicitly. Only the four declared Rapier texture `.import` descriptors normalize
CRLF to LF for content comparison: the hosted checkout and Godot's re-save can
differ in newline representation. Changes to descriptor content still fail.
All other tracked inputs use raw SHA-256, including DLLs, images and source, so
binary byte changes cannot be hidden by text normalization. The execution step
is bounded to 40 minutes within a 45-minute job.
Use the dated audit and exact workflow run to establish actual platform results;
this lane does not establish Windows rendered-output or browser acceptance.

## Physical usable validation

ACT-005 extends the [32-item usable catalogue](../systems/actor-usables.md) onto
the [physical actor owner](../systems/physical-actor-rigs.md). Use the pinned
Godot runtime and materialized Linux CyberSand/Rapier libraries. Verify native
`source_inputs` against the retained runtime provenance before attributing a
Godot result to the current native source. A matching native input manifest
allows GDScript-only changes to use that binary; its historical `build_inputs`
do not establish acceptance of changed scripts or newly added tests.

The focused regression groups are:

| Group | Runner and evidence scope |
|---|---|
| Physical mount and lifecycle | [`test_physical_usable_equipment.gd`](../../godot/tests/test_physical_usable_equipment.gd), [`test_physical_usable_lifecycle.gd`](../../godot/tests/test_physical_usable_lifecycle.gd): real part/body identity, joint-driven aim, equipment epochs, receipt fencing, release/settle/fix and explicit nearby pickup |
| Native usable work and worker admission | [`test_physical_usables_runtime.gd`](../../godot/tests/test_physical_usables_runtime.gd), [`test_physical_usables_admission.gd`](../../godot/tests/test_physical_usables_admission.gd): physical source/target masks, bounded actual-cell work, processor lifecycle, atomic queue capacity and stale/cancelled requests |
| Scripted loadouts | [`test_physical_usable_script.gd`](../../godot/tests/test_physical_usable_script.gd): all 46 explicit loadout policies, including five empty SetP mounts, and bounded, observation-driven equipment intent |
| Integrated hosts | [`test_physical_usable_course.gd`](../../godot/tests/test_physical_usable_course.gd), [`test_physical_usables_desktop.gd`](../../godot/tests/test_physical_usables_desktop.gd): the standalone usable course and desktop physical-owner handoff |
| Retained sampled compatibility | [`test_usables.gd`](../../godot/tests/test_usables.gd), [`test_usable_session.gd`](../../godot/tests/test_usable_session.gd), [`test_actor_usables_integration.gd`](../../godot/tests/test_actor_usables_integration.gd): the original catalogue, sampled command/session and sampled owner integration |

Run any focused runner directly after a clean headless project import, for example:

```sh
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_physical_usables_runtime.gd
godot --headless --path godot --script res://tests/test_physical_usables_desktop.gd
godot --headless --path godot --script res://examples/thunderbowl/run_physical_thunderbowl.gd -- --course=usables-v1 --rig=digger --actors=8 --ticks=600 --seed=0 --output=physical-usable-result.json
```

Set writable Godot user/config/cache directories on a restricted host and retain
import failures separately from successful test execution. A process exit code
alone is insufficient: reject script/native error output, require each runner's
explicit completion marker, and bound execution time. The headless course result
reports an authored scenario, not visual usability or target-machine performance.

The [automatic Godot suite](../../tools/ci/run_godot_regressions.py) discovers all
these `test_*.gd` files without a manual registry. It also retains the ACT-004
capacity, articulation, actuation, session, initial-terrain, effects, arena and
trial regressions. Native tests, ASan/UBSan and TSan establish separate native
evidence; a disabled leak detector must be reported explicitly. The
[ACT-005 audit](../audits/2026-10-19-act005-physical-usables.md) records tested
source/runtime identities, local results, remaining limitations and exact-head
hosted gates. Earlier ACT-004 or sampled USABLE-001 results do not certify this
changed physical integration.

## Semantic plane generation and native fixtures

GEN-005 adds [`test_generation_planes.cpp`](../../native/tests/test_generation_planes.cpp)
to both existing generation targets. Its oracle compares all four material
arrays and canonical registration unions across reversed negative-coordinate
tiles, worker counts and bounded slices, including shared typed masks and
actor proposals. Run it with the ordinary generation suite:

```sh
make worldgen-test
ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 make worldgen-sanitize
godot --headless --path godot --script res://tests/test_worldgen_planes.gd
godot --headless --path godot --script res://tests/test_semantic_planes_runtime.gd
godot --headless --path godot --script res://tests/test_semantic_planes_examples.gd
```

The runtime test requires every transaction, lifecycle, event, native reaction,
cleanup and actor section to complete. The actual-example runner loads both
checked-in recipes, requires all 40 fixture IDs and verifies every scheduled
application/cleanup. Rear-only ticks must produce native Brine and transport
while play/effects/background bytes stay unchanged. Separate play/effects
ticks verify Water transport and complete the finite programmes. Inactive and
missing-partner controls must fail the positive product/transport predicates.
Any script error or required skip fails even if the process exits zero.

The graphical oracle requires a real rendering backend:

```sh
xvfb-run -a godot --path godot --rendering-method gl_compatibility --display-driver x11 --audio-driver Dummy --script res://tests/test_semantic_depth_render.gd
```

It compares rendered pixels while camera pan/zoom/parallax leave generation,
semantic records and live ownership unchanged. The [authoring guide](semantic-depth-authoring.md)
documents reproducible composites, isolated planes, region details and capture
manifests. Headless rendering does not substitute for those captures.

The scoped [GEN-005 publisher](../../.github/workflows/gen005-runtime-publication.yml)
builds source-matched Linux and Windows runtimes, runs all retained player and
generation admission checks plus the three GEN-005 headless suites on each
target OS, and accepts only complete positive-count error-free evidence before
publishing the four runtime/provenance paths. Its independent
[`unittest` suite](../../tools/ci/test_gen005_runtime_publication.py) exercises
missing, malformed and tampered evidence. Exact-head documentation/provenance,
native, full Godot and applicable scoped apparatus gates remain required for
implementation acceptance. The [GEN-005 audit](../audits/2026-10-21-gen005-semantic-planes.md)
records actual platform/source results and any environment qualification.

## Hierarchical generation example and acceptance

GEN-004 extends the existing generation targets with
[`test_generation_grammar.cpp`](../../native/tests/test_generation_grammar.cpp).
Its controls cover stable semantic IDs, canonical shared ports, finite region
partitions, nested cross-chunk structures, constraints/fallbacks, socket geometry,
bounded solving and final raster routes. Run the focused native target while
iterating, then the combined generation and sanitizer targets:

```sh
make worldgen-test
ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 make worldgen-sanitize
godot --headless --path godot --script res://tests/test_worldgen_grammar.gd
```

The native targets reuse generation objects within each existing compiler flag
set under `$(BUILD_DIR)/worldgen-objects`: normal/sanitized and
threaded/non-threaded variants stay separate. Source, shared-header and Makefile
changes invalidate those objects. This avoids recompiling the same generation
sources for each test while retaining all eight executables and the five-minute
normal and ten-minute sanitizer CI bounds. The
[dated audit](../audits/2026-10-21-gen004-hierarchical-generation.md)
retains the cold-build timeout that motivated this change and subsequent results.

Godot execution requires a source-matched extension and the exact pinned editor.
The [hierarchy profile](../../examples/worldgen/hierarchy-multi-district.json)
is an executable schema-3 recipe; the
[grammar schema](../../examples/worldgen/schemas/grammar-v1.schema.json)
documents its `grammar` member. Load it with the Workbench's hierarchy control
to inspect four canonical districts. It uses 64-cell chunks so its complete
256×256-cell window occupies sixteen preview cache entries.

The adapter test checks copied semantic records, accepted recipe roundtrips,
cell provenance, final route/support reporting and failed configuration retention.
The [canonical contract](../systems/procedural-hierarchical-generation.md)
qualifies region-contained buildings, explicit cross-region routes, semantic
support, final static solid contact and the floating-square clearance profile.
Require both `passed` and `supports_passed` for the authored example; their
profiles establish distinct geometric facts. A hard blocker may
produce a valid material proposal with a failed route report; test and report
both facts without silently erasing the override.

Implementation acceptance additionally requires the repository's exact-head
Documentation/provenance, Native, GDExtension Linux/Windows and applicable scoped
apparatus gates. The [dated audit](../audits/2026-10-21-gen004-hierarchical-generation.md)
records actual commands, source/runtime identities, failures and limits. A
successful abstract route graph, native compile or inherited runtime binary
alone does not satisfy these gates.

## Procedural generation candidates and workbench

GEN-001/GEN-002 provide native-only comparison, field/modifier regressions and
focused fresh-chunk admission checks. GEN-003 adds independent typed analytical,
multiresolution/cache/worker, bounded seed/mapping and finite solver regressions
to the same native targets:

```sh
make worldgen-test
ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 make worldgen-sanitize
make worldgen-demo
./build/worldgen_demo --output build/worldgen-plain.ppm --seed 314159 --plain
```

The explicit sanitizer command disables leak detection for environments where
LeakSanitizer cannot inspect processes under ptrace. Without that override the
sanitizer runtime enables it; use `detect_leaks=1` in a supported execution
environment. The [GEN-001](../audits/2026-10-18-gen001-procedural-generation.md) and
[GEN-002](../audits/2026-10-18-gen002-fields-and-aggregates.md) evidence distinguish
actual LeakSanitizer infrastructure failures from passing ASan/UBSan results.
The PPM contains actual generated material pixels from Strata, Flow Network
and District Grammar; its printed local elapsed time is not a performance gate.

With a source-matched extension, launch the separate authoring scene or its
regression script using the pinned Godot executable:

```sh
godot --path godot res://worldgen_workbench.tscn
godot --headless --path godot --script res://tests/test_worldgen_workbench.gd
godot --headless --path godot --script res://tests/test_worldgen_fields.gd
godot --headless --path godot --script res://tests/test_worldgen_typed.gd
```

The generation workbench is separate from the ordinary sandbox and its optional
[actor prototypes](../systems/actor-control-prototypes.md). It previews bounded
native chunk generation, with theme/parameter strokes, guide paths, hard rectangles,
module instances, fields/sidechains, context masks, aggregate materials and complete
JSON profiles, without ticking the simulation. The
[field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md)
owns the extended controls and diagnostic channel meaning.
Load the examples under `examples/worldgen/`; use the
[generation contract](../systems/procedural-world-generation.md) for exact ranges,
module registration, receipt ownership and the separate fresh-chunk installer.
Native generator/binding changes require rebuilt runtimes before these Godot
commands establish source-matched evidence. Merely importing an old extension
does not register `CyberWorldGenerator`.

The [typed contract](../systems/procedural-typed-spatial-fields.md) and
[operator inventory](../reference/procedural-spatial-operators.md) own GEN-003
numerical/type guarantees. The Workbench's Typed spatial graphs page selects
five executable schema-2 profiles: `typed-industrial-structure.json`,
`typed-vector-utilities.json`, `typed-categorical-districts.json`,
`typed-reusable-decay.json` and `typed-multiscale-seeds.json`. They exercise
transforms, vector guidance, exact districts, nested parameterized authoring and
world-aligned coarse sampling. Typed Godot validation checks configuration
roundtrips, typed diagnostics, malformed/refused inputs and Workbench integration;
native analytical tests remain the numeric oracle. New native tests do not
replace source-matched Linux/Windows runtime publication and ready-PR gates.

To reproduce the five GEN-003 material/typed-diagnostic pairs, use the typed
renderer with an absolute script path from the repository root:

```sh
GENERATION_ROOT="$PWD"
godot --headless --path "$GENERATION_ROOT/godot" --script "$GENERATION_ROOT/tools/render_worldgen_typed.gd" -- --output "$GENERATION_ROOT/build/worldgen-typed"
```

It samples a 256×192-cell region at `[-128,0]` from each checked-in profile and
writes ten PNGs plus `render-manifest.json`. The manifest records the actual
platform/Godot version, runtime and source SHA-256 values, recipe SHA-256,
accepted graph fingerprint, typed diagnostic metadata and per-chunk material
and receipt hashes. Colour mapping is the Workbench's presentation mapping;
the native diagnostic payload retains signed numbers, vector components and
exact categorical identity. These panels show generated proposals, with no
simulation ticks or claim of visual throughput.

To reproduce the three GEN-002 material/mask panels, run the checked-in renderer
with an absolute script path. From the repository root:

```sh
GENERATION_ROOT="$PWD"
godot --headless --path "$GENERATION_ROOT/godot" --script "$GENERATION_ROOT/tools/render_worldgen_fields.gd" -- --output "$GENERATION_ROOT/build/worldgen-fields"
```

The tool loads `hilbert-seams.json`, `weathered-aggregate.json` and
`sidechained-arcology.json` directly from `examples/worldgen/`. For each profile it
generates a 512×384-cell region at `[-256,0]`, writes material and grayscale mask
PNGs, and records per-chunk content/receipt hashes plus logical work in
`render-manifest.json`. Its 12/48/12 chunks follow each profile's declared geometry.
This is actual native proposal output, before any material simulation; the tool
does not assess visual GPU throughput or Windows/Web execution.

## Web compile, export and execution are different checks

From source, with the SDK active and paths adapted to the host:

```text
python tools/build_web.py --cpp <web-godot-cpp> --compile-only
python tools/build_web.py --cpp <web-godot-cpp> --godot <godot> --templates <templates>
```

The default profile is compatibility. Add `--profile threaded` for pthreads.
Both normal profiles package Rapier; `--cellular-only` is a diagnostic option.
`--native-tests` requires a separate `--native-cpp` directory. `--compile-only`
returns before runtime tests/export even if `--native-tests` is present.

`--export-only` checks existing WASM structure, not freshness against source.
The workspace wrapper still supplies the acquisition base as `--source-commit`;
that export field is not current HEAD. Capture current source and artifact hashes
separately until the producer is repaired in an implementation checkpoint.
See [source identity](source-checkpoint-and-recovery.md).

Preview generated output through HTTP with WASM MIME and profile headers, then
run the actual browser fixture. Checksums/HTTP checks prove packaging; native
headless Godot proves native execution; only browser execution tests Web behavior.
The [Web guide](web-threading.md) owns hosting requirements, and the
[validation ledger](../reference/validation-evidence.md) owns dated outcomes.

## How is the physics baseline rebuilt?

Follow [physics characterization](physics-characterisation.md): rebuild the
native CLI and adapter before running the deterministic P1–P4 matrices, then
build/export both Web profiles and execute them in a real browser. Capture actual
HEAD/local file hashes separately from legacy export acquisition labels.
The [2026-09-09 report](../audits/2026-09-09-physics-characterisation.md) records
Windows/Web results and the unavailable Linux execution environment. Local
rebuilt artifacts are measured inputs, not automatically updated published LFS
runtime manifests; the current release gate remains separate from M11 integrity.

For the standalone CLI's current material-admission and sampled-accounting gate:

```sh
timeout 300 make physics-characterisation-test
ASAN_OPTIONS=detect_leaks=1:strict_string_checks=1 \
  UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
  timeout 300 make physics-characterisation-sanitize
```

The sanitized command includes leak detection when the execution environment
supports process inspection. Native CI uses its explicitly recorded ASan/UBSan
scope. Both targets compile the actual CLI and retain per-invocation JSON/stdout,
stderr and the executable hash under `build/physics-cli-validation/`. The
[measurement-path contract](physics-characterisation.md#which-checks-guard-the-measurement-path)
defines the 132-entry output and independent accounting oracle.

Issue #10 uses the [current acceptance commands](physics-characterisation.md#how-do-i-reproduce-issue-10-acceptance)
and [its own artifact audit](../audits/2026-09-09-issue-10-granular-policy.md).
Both native Web modules were rebuilt before final script exports. The shared
threaded probe must yield before replacing a newly constructed default world,
after replacement and after teardown so browser pthread startup/recycling can
finish before synchronous native joins. This fixture lifecycle requirement does
not change production native ownership or introduce asynchronous Web simulation.

## Issue17 native precision research

The separate codex/issue-17-state-precision worktree has an experimental native
mass interface and fixed wide Cell. Use its [registered driver](state-precision-experiment.md)
and [source/artifact evidence](../audits/2026-09-11-issue-17-state-precision.md),
not the workspace default DLL builder. No experimental DLL, Web module, save
migration or renderer was published. Core tests/timing do not certify those adapters.

## MicroScenario harness checks

The new `test_microscenarios.gd` and `test_microscenario_controllers.gd` are included
by the existing `tools/ci/run_godot_regressions.py` test discovery. Run them against
the pinned runtime, together with existing Tower, Water, failed-tick/region and
immutable render-handoff regressions when changing the harness.

The [MicroScenario runbook](microscenarios.md#headless-runs-from-the-same-definition)
describes the bounded native-only JSON runner. Its result is not a Windows or
browser run merely because it exercises the synchronous controller on Linux.
Use actual platform artifacts and retain their identities for platform acceptance.

## Player playground checks

Use the pinned Godot 4.7/Rapier runtime and a rebuilt source-matched native
extension. The new field method must exist; a preceding retained binary cannot
exercise the material presets. On Linux provide writable XDG data/config/cache
directories if the environment's defaults are read-only.

```text
make build/tests
./build/tests "player material field"
godot --headless --path godot --script res://tests/test_player_material_field.gd
godot --headless --path godot --script res://tests/test_player_vehicle_controls.gd
godot --headless --path godot --script res://tests/test_player_acrobat.gd
godot --headless --path godot --script res://tests/test_player_acrobat_physics.gd
godot --headless --path godot --script res://tests/test_player_playground_runtime.gd
godot --headless --path godot --script res://tests/test_player_playground_course.gd
```

The native executable accepts an optional name substring; no match fails and
omitting the filter runs the complete suite. Its field groups check complete
stored-state/temperature/partial-Water preservation, collisions, invalid inputs,
work bounds, distinct modes and deterministic ordering. The binding runner
checks actual native admission and nonmutation; mechanical runners exercise
bounded control plans and actual Rapier motion. The integrated runner covers
seven owners, issued observations, replay/refusal, expiry, cancellation, pause,
reset and UI rearm. It also verifies that an admitted press/release between
physics ticks starts the course clock and counts subsequent neutral/coasting
ticks. The course runner checks mounted spawns and actual short traversal
routes. Counts and outcomes belong to the
[original local audit](../audits/2026-10-20-player-control-playground.md) and
[PR #189 completion record](../audits/2026-10-21-player-playground-pr189-completion.md),
which separates original-head hosted passes from pending combined-source gates.

Changed shared catalogue/session/loadout behavior also uses the existing
physical regressions below. Focused execution is not a complete suite, human
play or platform result. Run the normal applicable native/Godot gates before
publication; dynamic Godot discovery includes the new `test_*.gd` files.
Controls and manual course entry are in the
[player guide](../systems/player-control-playground.md).

## Actor control prototype checks

### ACT-004 articulated actors and physical Thunderbowl v2

The physical catalogue, real Rapier fixtures, native effects/capacity, common
session, desktop installation and separate physical arena have focused runners:

```text
godot --headless --path godot --script res://tests/test_physical_actor_catalog.gd
godot --headless --path godot --script res://tests/test_physical_actor_script.gd
godot --headless --path godot --script res://tests/test_physical_actor_actuation.gd
godot --headless --path godot --script res://tests/test_physical_actor_rigs.gd
godot --headless --path godot --script res://tests/test_physical_actor_session.gd
godot --headless --path godot --script res://tests/test_physical_actor_integration.gd
godot --headless --path godot --script res://tests/test_physical_actor_effects.gd
godot --headless --path godot --script res://tests/test_physical_actor_effect_admission.gd
godot --headless --path godot --script res://tests/test_act004_body_capacity.gd
godot --headless --path godot --script res://tests/test_physical_actor_arena.gd
```

Use the pinned Godot 4.7/Rapier 0.35.2 and source-matched native runtime. The
64-body adapter change requires a rebuild; a previous retained binary does not
implement it merely because new scripts load. All `test_*.gd` runners are
automatically discovered by `tools/ci/run_godot_regressions.py` and included once
in the existing four GitHub-hosted shards. The original
`test_physical_actor_trial.gd`, sampled rig/session, Thunderbowl and protected
scenario regressions remain in that suite.

The catalogue test checks definitions and local producers. The Rapier fixture
checks connected real assemblies, sustained movement, contact-dependent control,
recovery and attachment lifecycles. Native effects/capacity tests exercise real
cell admission and bounded material edits; session/integration tests cover
source identity, leases, cancellation, replacement and the F5 owner boundary.
The physical arena tests use a distinct synchronous world/space. Their concrete
fixture thresholds are regression bounds, not a target-machine feel or universal
traversal claim. The [ACT-004 audit](../audits/2026-10-18-act004-articulated-actors.md)
records what ran, failures corrected during tuning and remaining platform limits.

The [physical Thunderbowl reference](../systems/thunderbowl-control-reference.md#physical-thunderbowl-v2)
contains scene and headless runner examples. Its version-2 command and observation
contract is separate from the sampled control lab below.

### Runner IK joint-target checks

**ACT-IK-001 development, actual host required:** the separate
[Runner IK contract](../systems/physical-joint-targets.md) and
[admission ledger](../audits/2026-10-23-act-ik-001-development-admission.md)
require the pinned Godot 4.7 GDExtension/Rapier2D v0.35.2 runtime.
From the checked-out repository root with the pinned binaries installed,
the commands below run a source/protocol shape fixture and a **real**
physical-session fixture:

```sh
godot --headless --path godot --script res://tests/test_physical_joint_target.gd
godot --headless --path godot --script res://tests/test_physical_joint_session.gd
```

CI's `tools/ci/run_godot_regressions.py` automatically discovers both
`test_*.gd` files and must also pass the normal Runner, physical usable
and 4LY suites with zero hidden skips. The host fixture's 40/64-hex build
identity is explicitly synthetic; a passing result cannot replace real
source/runtime provenance. Final acceptance needs the exact NCA #55
client/packet cross-check, actual compiled runtime hashes, motion/obstruction
screens, independent review and NCA physical performance criteria.
The current authored test files must not be cited as executed passes.

### Physical free-flight checks

The internal [4LY family](../systems/physical-free-flight.md) uses the same
pinned Godot 4.7, Rapier 0.35.2 and source-matched native runtime. Import the
project first, then run these automatically discovered fixtures from the source
root:

```text
godot --headless --path godot --script res://tests/test_physical_flight_profile.gd
godot --headless --path godot --script res://tests/test_physical_flight_session.gd
godot --headless --path godot --script res://tests/test_physical_flight_physics.gd
godot --headless --path godot --script res://tests/test_physical_flight_handling.gd
godot --headless --path godot --script res://tests/test_physical_flight_selection.gd
# The following actual-framebuffer case must run with a real display:
godot --path godot --script res://tests/test_physical_flight_gameplay_render.gd
```

The profile fixture checks the closed schema, numerical limits, canonical
profile/controller hashes, force/torque response and goal-blind pure controller.
The session fixture checks the one-body/no-equipment topology for all four IDs,
strict two-output input, copied observations, producer parity and lifecycle
fences, including actual-step receipt attribution and rejection of incorrect
host step ordering. The original physical fixture requires real Rapier and
native World: unsupported Trainer hover, ascent/descent, neutral braking,
attitude recovery, explicit power-off fall, underpowered gravity saturation,
high-momentum bounded actuation and native hard-contact integration.

**4LY-002 adds two headless cases and one graphical capture case:**
`test_physical_flight_handling.gd` uses the same four real Rapier physics
fixtures and normalized commands for every profile, and separately compares
braking under an identical +20 cell/s physical impulse. It also measures
unsupported neutral hover, response onset, 60/120-step velocities, reversal,
up/down motion, angular recovery, the bounded force/torque receipt, passive
power-off coast and the actual static wall. The fixture parses the
[prospectively registered numeric gate](../../godot/tests/fixtures/4ly002_handling_thresholds.json)
and prints a `4LY_002_HANDLING_METRICS` JSON line with the profile hashes and
actual measurements. `test_physical_flight_selection.gd` exercises real main
scene F5 selector entries, no-equipment enforcement, same-source ownership,
fresh reset fences, scripted/policy choices, multi-drone demo, exploratory
map retention and return to sampled gameplay.
`test_physical_flight_gameplay_render.gd` (Linux `*_render` display shard)
opens the **actual ordinary main sandbox**, selects all four drones in turn,
submits observation-fenced policy velocity requests through the normal host,
and retains full GL viewport PNGs plus controller/profile and physical
motion metadata under `CYBERSAND_PRESENTATION_EVIDENCE`. It is **descriptive
gameplay evidence**, not a subjective handling preference or an alternative
motion implementation. The case does not run on headless Windows.
These fixtures must execute against actual backend/runtime/source identities;
a skipped display/backend, script error or pending check is **not** acceptance.

Run the existing physical catalogue/session/rig/equipment, sampled reference and
protected scientific-fixture regressions when changing shared owners. The five original flight cases join the existing Linux and Windows Godot
discovery; the new `*_render` capture joins **only the Linux display suite**;
no separate provider or external runner is required. Draft-skipped expensive checks
do not qualify the implementation. Before merge, follow the
[exact-head release gates](github-development-and-release.md) and record source,
runtime, commands, outcomes and unmeasured platforms separately.

These are reproduction instructions and fixture scopes, **not a statement that
the current checkout has passed**. 4LY-002 [real-Rapier measured envelopes](../audits/2026-10-23-4ly002-measured-handling-qualification.md)
pass their prospective criteria at the recorded prior implementation head,
while new visual capture/final-head validation and human owner-feel acceptance
remain separate. The literal `candidate_4ly002` must remain unchanged
until a new measured identity is intentionally qualified; do not hand
this candidate to learning as already accepted. The flight lab, qualified teacher, learned
navigation, target-PC human feel and new Web runtime support have separate
4LY follow-up gates.

### Thunderbowl controls and native arena

The [Thunderbowl reference](../systems/thunderbowl-control-reference.md) contains
the standalone scene/CLI commands and fourteen match definitions. Four new
automatically discovered Godot regressions cover direct actuation, its session
mailbox, native arena/driver/presentation behavior and controller/schema output:

```sh
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_rig_actuation.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_actuator_session.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_thunderbowl_arena.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_thunderbowl_controllers.gd
```

Run the existing actor-rig and SetA suites when changing the shared session or
motor. The controller suite retains structured positive/adversarial cases in
`user://thunderbowl-contract-cases.json`; the separate
[`validate_examples.py`](../../tools/thunderbowl/validate_examples.py) checks them
and the eight schema definitions with Python `jsonschema` (development tool,
tested with 4.26.0). Its `--capture` argument accepts the resolved Godot user-data
path. This validates JSON shape independently from the Godot validator; actual
run/observation identity, capacity, privilege and input lifetime remain native
arena/session integration checks. No inference service or credentials are needed.

### Original actor compatibility checks

The original **SetA** tests `test_actor_prototypes.gd`, `test_actor_prototype_session.gd` and
`test_actor_prototype_integration.gd` are discovered by the existing Godot
regression runner. The core runner covers the shared
action/observation contract, Runner jump/dash timing, Skimmer
thrust/energy/braking, Crawler supported clamber/brace, runtime burial, bounded
query work and native hard-surface collision/material conservation. The tests
also print informational controller timings; those are not target-PC performance
acceptance or a neural-network inference benchmark. The session runner covers
capacity, producer/epoch/sequence/lease admission, edge coalescing, cancellation,
independent actor instances and copied observations.
The integration runner exercises real owner reset/refusal receipts, desktop
model/scenario selection, input release/rearm, overlay geometry and recorder
actor/material-generation identities.

After importing the project with the pinned Godot runtime, a focused run is:

```sh
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_prototypes.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_prototype_session.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_prototype_integration.gd
```

Run the existing PENV, PCHAR, PLAY-VAL, controller and immutable publication tests
alongside the prototype tests when changing desktop integration or fixture
lifecycle. The unchanged full suite remains available through
`tools/ci/run_godot_regressions.py`; new `test_*.gd` files are discovered by all
appropriate deterministic CI shards without a hand-maintained case list.

The [actor contract](../systems/actor-control-prototypes.md) distinguishes a
controller fixture from desktop controls, visual/feel review, a learned policy
or Web integration. Use the [validation ledger](../reference/validation-evidence.md)
for the actually executed source/runtime/platform scope. These commands are
reproduction instructions and do not themselves claim a pass.

## Actor rig checks

ACT-002 adds `test_actor_rigs.gd`, `test_actor_rig_session.gd` and
`test_actor_rig_integration.gd` through the
same discovered Godot regression runner. The motor fixtures exercise all 26
additional rigs against independent occupancy/material worlds: input bounds,
conservative angular clearance, traversal, flight/resources, adhesion/tuck,
rope attachment/occlusion/reel/release, local tools and protected materials.
Native smoke cases use the source-matched retained extension separately from
the mock-world controller timing loop.

The session fixtures check the 29-entry catalog and stable set IDs, the additive
40-value observation and ten-value action layouts, consumed edge/sequence
readback, producer/epoch/lease rejection, cancellation and deep-copy retention.
SetA parity compares the original motor with both legacy and extended submission
paths; adding channels must not silently retune the original three models.

The integration fixture uses the native desktop owner for extended-action
admission, dual v1/v2 publications and tool telemetry. It also checks every set's
selector/comparison capacity, independent pointer projection, keyboard axes and
quick taps/rearm, rotated overlay geometry and anchor projection, recorder JSON
with separate actor/material times, and controlled-scenario exclusion.

After pinned-runtime import, run the new fixtures alongside the three SetA
commands above:

```sh
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_rigs.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_rig_session.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_rig_integration.gd
```

Changing the selector, human controls, worker, overlay or recorder also requires
desktop integration and existing PENV/PCHAR/PLAY-VAL/publication/recording
regressions. Use the full discovered runner for the intended CI matrix rather
than treating these focused commands as the complete gate.

The [rig contract](../systems/actor-rigs.md) owns control meanings and limits.
The [validation ledger](../reference/validation-evidence.md) owns actual dated
execution. Printed mock-world motor timings are informational local-host results,
not native scene throughput, learned-policy latency, target-PC playfeel or Web
acceptance. Reproduction commands alone do not claim successful execution.

## Actor usable checks

USABLE-001 adds three focused Godot fixtures covering the 32-entry catalogue,
material/tool semantics, swept/delayed payloads, processor transactions,
equipment leases, quick clicks, pause/reset lifecycle, live worker publication
and F5 desktop integration.

```sh
timeout 180 <godot> --headless --path godot --script res://tests/test_usables.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_usable_session.gd
timeout 180 <godot> --headless --path godot --script res://tests/test_actor_usables_integration.gd
```

Changes to equipment input, the worker, recorder, overlay or F5 selector also
require the existing actor-rig, recording, publication and desktop integration
regressions. The discovered full Godot runner remains the acceptance route; these
focused commands do not by themselves prove target-PC feel or Windows/Web
interactive acceptance.

## Soliding successor validation

`make soliding-test` and `make soliding-sanitize` compile the standalone lifecycle
and discovery suites. They change no installed native runtime artifact. See the
[control measurement procedure](soliding-measurement.md) for immutable-source
benchmark compilation; builds/tests must stop during registered local timing.

`make soliding-benchmark-smoke` compiles the isolated journal characterization
with warnings as errors and exercises its bounded-work/fairness assertions on a
small fixture. CI timings are not performance acceptance measurements.

## Combined desktop entry

The project now defaults to `res://feature_launcher.tscn`; F2 returns there and discards the current session. Direct `res://main.tscn` and showcase user arguments remain available. See the [physical actor programme](physical-actor-programme.md) for the Blacksite comparison and `test_physical_actor_trial.gd` regression.


## Deepworks and depth dimensions

The [Deepworks guide](deepworks-exhibition.md) owns the map and interactive
controls; the [depth contract](../systems/depth-layers-and-parallax.md) owns
parameterized surfaces, independent worlds and publication. The new scene uses
the current materialized native runtime without changing its ABI or dependency
pins. Open it with `godot --path godot -- --deepworks` or
`godot --path godot res://deepworks.tscn`.

Run focused headless checks with the pinned engine, for example:

```sh
godot --headless --audio-driver Dummy --path godot --script res://tests/test_deepworks.gd
godot --headless --audio-driver Dummy --path godot --script res://tests/test_deepworks_controller.gd
godot --headless --audio-driver Dummy --path godot --script res://tests/test_deepworks_reactions.gd
godot --headless --audio-driver Dummy --path godot --script res://tests/test_depth_dimensions.gd
godot --headless --audio-driver Dummy --path godot --script res://tests/test_depth_compositor.gd
```

| Case | Meaningful scope |
|---|---|
| `test_deepworks.gd` | Full recipe, all districts/planes, passage openings, catalogue coverage, bounded programme and rejected-install atomicity. |
| `test_deepworks_controller.gd` | Production host controls, view changes, input transforms, pause/reset/tour and foreground/rear painting. |
| `test_deepworks_reactions.gd` | Actual full-map native simulation through the production source scheduler, copied material observations, reaction products and transport away from feeds. |
| `test_depth_dimensions.gd` | Default, non-square, minimum and 1024 × 1024 worlds; failed reset preserves prior state; guards, weather, far-edge camera and input. |
| `test_depth_compositor.gd` | Packet admission and surfaces, including an older generation with a higher serial leaving pixels and identity untouched. |
| `test_depth_dimensions_render.gd` | Actual far-edge pixels across all four planes, full-size composition, pointer mapping and MAT-002 relief bands. |
| `test_deepworks_render.gd` | Actual production scene pixels, usable HUD area, per-district rear/distant contribution and atmospheric visibility. |

The two new `*_render.gd` cases require a graphical compatibility renderer:

```sh
godot --audio-driver Dummy --rendering-method gl_compatibility --path godot \
  --script res://tests/test_depth_dimensions_render.gd
godot --audio-driver Dummy --rendering-method gl_compatibility --path godot \
  --script res://tests/test_deepworks_render.gd
```

Use a 180-second per-test deadline, as in the shared regression runner. The
retained depth runtime, default lab and material-surface regressions remain
applicable. Linux suite discovery includes every new `test_*.gd`; rendered
suffixes require a display and cannot pass by skipping headless pixels. The
Windows lane separately discovers the applicable headless cases. Discovery
does not establish that either platform executed this source successfully.

Reaction acceptance additionally requires all 32 expected district/plane
identities to complete and pass their mechanism checks. Check both the process
exit status and the complete log for `SCRIPT ERROR:` / `ERROR:`. The original
626-plus-one summary was invalid despite exit 0; the
[PR #185 correction](../audits/2026-10-20-deepworks-pr185-completion.md) records
the missed transport assertions and repaired rear Stone chute. When saving
`CYBERSAND_DEEPWORKS_REACTION_REPORT`, require `verified_exhibit_count == 32`
and every record's `oracle_completed`, positive `oracle_assertions` and
`verified` result in addition to zero failures.

[`capture_deepworks.gd`](../../godot/tools/capture_deepworks.gd) creates review
images and a manifest from the actual renderer; its invocation and optional
`--quick` scope are in the [capture guide](deepworks-exhibition.md#reproduce-images-and-verify-changes).
Image capture and native reaction checks establish different things. Record
source/runtime identity, renderer, commands, timeouts and failures in the
[dated Deepworks audit](../audits/2026-10-20-deepworks-exhibition.md) before making
an acceptance claim.

## Exploratory map actor replacement regression

Run `godot --headless --path godot --script res://tests/test_exploratory_actor_selection.gd`
with a 180-second timeout and the pinned materialized native/Rapier libraries.
It exercises all five authored exploratory maps, physical barrel/Ripper and
sampled baseline/rig replacement, R retention, all 29 sampled rigs with their
scripted companions, physics labels, legacy F6 reference-body restoration and protected fixture/Benchmark refusal.
Existing Set A/rig, physical-trial, Blacksite/showcase and controller tests remain
required. The [physical actor programme](physical-actor-programme.md) owns controls
and the full-roster Rapier conversion requirement; these tests do not validate
articulated actors or broad granular contact fidelity.

## Generation Workbench 2 and procedural qualification

Read the [workbench contract](../systems/generation-workbench-2.md),
[scene qualification guide](procedural-qualification.md) and
[dated GEN-007 ledger](../audits/2026-10-21-gen007-workbench-qualification.md).
Native source changes require rebuilt runtimes before executing these scripts.

```sh
make worldgen-test
make worldgen-sanitize
godot --headless --path godot --script res://tests/test_gen007_inspection.gd
godot --headless --path godot --script res://tests/test_gen007_workbench.gd
godot --headless --path godot --script res://tests/test_gen007_qualification.gd
godot --headless --path godot --script res://tests/test_gen007_reactions.gd
```

Run the additional `test_gen007_*_render.gd` cases through the existing regression
runner on a display-backed renderer. The `_render` suffix prevents a headless
no-frame shortcut. `capture_gen007.gd` retains real scene views and identities;
its successful completion and each required output image must be checked.
The scoped GEN-007 publisher binds Linux/Windows execution to exact source and
runtime bytes; the ready-for-review full repository gates remain separate.
