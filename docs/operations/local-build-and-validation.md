---
title: Local build and validation
status: Current
document-kind: guide
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-25
related-documents: [source-checkpoint-and-recovery.md, testing-validation-and-replay.md, web-threading.md, deepworks-exhibition.md, ../systems/depth-layers-and-parallax.md]
---

# Local build and validation

## First launch from a source checkout

Use this repository's launcher and retained runtime for a first exploration. A
native rebuild is a separate development task. The [player getting-started
guide](getting-started.md) walks through opening the Workbench; this page owns
the build, identity and validation procedure.

The required engine is **Godot `4.7.stable.official.5b4e0cb0f`**. Native builds
use **godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` and API `4.7`**;
another 4.7 patch executable or a different binding checkout is not the same
input. The [complete input table](#which-build-inputs-are-required) links the
authoritative locks and platform toolchains.

From a new checkout with Git and Git LFS installed:

```sh
git clone https://github.com/techrote/cybersand.git
cd cybersand
git lfs install --local
git lfs pull
git rev-parse HEAD
git status --short
python3 tools/ci/check_repository.py --require-materialized
```

On Windows, use `python` instead of `python3` when that is the installed command.
`git lfs pull` obtains the committed runtime payloads. A small text pointer is not
a usable DLL or shared library. `check_repository.py` checks the runtime bytes
and recorded source inputs; it also checks documentation and dependencies, so
read the actual failure rather than assuming every failure means a broken DLL.

**Windows:** install the [exact Godot pin](#which-build-inputs-are-required), then
run from this repository root in PowerShell:

```powershell
.\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe -PrintIdentityOnly
.\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe
```

The path is an example: use the actual executable location. The launcher also
accepts `CYBERSAND_GODOT`, or searches `C:\Godot47`. It validates the pinned Godot
version, materialized Windows runtimes and CyberSand DLL hash; it prints the
checkout/runtime identity and performs no build or replacement. The default
project scene is [Feature Launcher](../../godot/project.godot), which routes to
the ordinary **Shared Workbench** and standalone scenes. `-Editor` opens the same
project in the editor. `dev.cmd` is not required for a source-only checkout.

**Linux x86_64:** with the pinned Godot executable and materialized Linux runtimes,
use an explicit executable path:

```sh
CYBERSAND_GODOT=/absolute/path/to/Godot_v4.7-stable_linux.x86_64
"$CYBERSAND_GODOT" --version
"$CYBERSAND_GODOT" --headless --editor --path godot --import --quit
"$CYBERSAND_GODOT" --path godot
```

The version output must match the table below. The last command requires a
graphical session. Import and launch are separate steps; successful project
import is not proof that native gameplay or every feature ran. A software display
is useful for reproducible graphical tests, but does not establish the owner's
Windows/NVIDIA playfeel.

## Choose the right development path

| Task | Inputs and procedure | Evidence it can establish |
|---|---|---|
| Explore accepted software | Source checkout, materialized retained runtime, exact Godot | Actual launch and exercised behavior on that machine |
| Review a portable evaluator | Exact package manifest, bundled launcher and its matching source | Only that package/source; candidate does not become main |
| Change documentation or retrieval | Python, Git and [structural/retrieval checks](documentation-maintenance.md#checks-and-evaluation-interpretation) | Documentation structure, containment and inspected claims |
| Change native C++ | Pinned compiler/dependencies; [native commands](#repository-native-build-and-test-commands) | Focused or complete native tests actually executed |
| Change Godot scripts or bindings | Source-matched extension, pinned Godot; [test-selection guide](testing-validation-and-replay.md) | Actual tested script/native integration; bindings may require rebuild |
| Qualify Web | Separate Web godot-cpp, exact SDK/templates and actual browser execution | The named compat/threaded artifact, not desktop parity |

Inspect the actual Git root, branch, HEAD, dirty files and required LFS state
before work. The companion workspace contains optional host-specific wrappers;
this source repository contains the application, tests and native build entry
points. [Source identity](source-checkpoint-and-recovery.md) owns that boundary.

For a bounded first validation pass from the repository root:

```sh
python3 tools/ci/check_docs.py
python3 tools/ci/check_repository.py --require-materialized
make c-header-check
make -n test
```

The C-header probe needs Make and a C compiler. It compiles
`native/tests/test_c_header.c` with `-std=c11 -Wall -Wextra -Wpedantic`, the native
include directory and `-fsyntax-only`; it checks the public header as C without
linking a game or running simulation. `make -n test` displays the native
build/run plan without executing it. Use the smallest meaningful subsystem test
during iteration, following [test selection](testing-validation-and-replay.md);
the full applicable matrix remains the implementation gate.

## Isolated test data and diagnostics

Godot tests and graphical captures must not overwrite the owner's saved scenes,
Art traffic or local provider configuration. Use the repository's
[isolated Godot runner](../../tools/physics/isolated_godot.py) or the appropriate
existing test/capture harness with its own user profile. Inspect that harness's
arguments and refusal rules before invoking it; a normal interactive launch
intentionally uses the user's ordinary application data.

For a useful failure report, record the checkout SHA and dirty state, exact Godot
version, native runtime/provenance identity, platform, command, fixture or small
synthetic setup, steps, expected result, actual result and whether the operation
was queued, applied, displayed or refused. Include the first relevant error and
completion status, not only a green process exit. Preserve the original failed
result alongside a successful retry. Art prompts, traffic, endpoint credentials
and owner maps may be private: inspect and redact attachments, and prefer a
synthetic reproduction. [Troubleshooting](troubleshooting.md) covers common launch,
focus, runtime and capacity failures.

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
| Rapier2D | Single-precision 2D **v0.35.2** base; qualified cooperative deferred-BVH join backport on Windows/Linux x86_64, official bytes on other targets; [Rapier lock](../../godot/third_party/rapier2d.lock.json) |
| Web templates | Exact Godot 4.7 dlink templates: `web_dlink_nothreads_{debug,release}.zip` for compat, `web_dlink_{debug,release}.zip` for threaded |

Keep native and Web godot-cpp checkouts separate: generated bindings and archives
are target-specific. Python 3.12.14 was used locally; the workspace helper requires
Python 3.10+. Do not silently update pins while debugging a simulation change.

The runtime lock labels export templates `absent-and-unpinned`; the repository
does not establish reproducible current exports merely because a local machine
has templates installed. The configured Web CI also disagrees with the builder; see
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
`godot/project.godot` through its configured `feature_launcher.tscn`; `-Editor` opens the
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
make c-header-check
make -n test
make -j2 test
make sanitize
make thread-sanitize
```

`make test` includes the current native World, soliding, worldgen and material
baseline targets. The [Makefile](../../Makefile) is the executable inventory;
`make sanitize` and `make thread-sanitize` have distinct target coverage, so do
not claim that either alone executes every subsystem sanitizer. Focused generation
and soliding sanitizer targets remain available. The default AddressSanitizer
configuration enables leak detection; a historical hosted exception is not a
new default.

These commands may compile substantial native source. They are procedures, not
pass claims. Set a budget appropriate to the selected target and host; do not reuse
historical 120/300-second examples as current full-suite budgets. The accepted
[CI execution policy](ci-execution-and-performance.md) derives hosted allowances
without weakening scientific cases or sanitizer failures.

A GDExtension rebuild additionally needs pinned godot-cpp and SCons:

```sh
export GODOT_CPP_ROOT=/absolute/path/to/pinned-godot-cpp
export SCONS_PYTHON=/absolute/path/to/build-venv/bin/python
SCONS_JOBS=2 tools/build_pinned_godot_cpp.sh linux
CYBERSAND_NATIVE_OUTPUT="$PWD/build/libcybersand_native.linux.x86_64.so" \
  tools/build_native_extension.sh
```

The example writes the candidate extension under ignored `build/`, leaving the
retained library alone. Inspect and qualify the candidate before installing it
into a test project. Installing a locally built library does not create accepted
runtime provenance: [guarded publication](github-development-and-release.md#source-matched-runtime-publication)
requires its actual source, input hashes, target-platform execution and lease.
The build scripts enforce pinned dependency revision and source checks; do not
use `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT` to report a reproducible release.

For Windows GDExtension cross-builds, use `build_pinned_godot_cpp.sh windows` and
[build_native_extension_windows.sh](../../tools/build_native_extension_windows.sh)
with the pinned `LLVM_MINGW_ROOT`/`WINDOWS_CXX` inputs. A PE/import inspection is
separate from execution on Windows. The root `build_windows_msvc.bat` is a native
core build entry point with its explicit test list, not the complete Godot/native
qualification matrix. The [Windows execution helper](../../tools/ci/run_windows_godot_regressions.py)
and accepted workflow own source-bound Windows Godot execution.

## Linux GDExtension CI sharding

The accepted [GDExtension workflow](../../.github/workflows/gdextension.yml)
builds a source-matched Linux runtime and plans regression jobs from the current
source inventory. The [execution planner](../../tools/ci/godot_job_plan.py)
supplies shard counts and budgets; `max-parallel` is a concurrency cap, not a
fixed number of required tests or a promise that four shards are sufficient.
Do not copy an unmerged runner experiment into the current procedure.

The local/default invocation is serial. Rendered cases need a display; this
source-supported software-rendered route is useful on a prepared Linux host:

```sh
LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 GALLIVM_PERF=nopt xvfb-run -a \
  -s '-screen 0 1920x1080x24 -nolisten tcp' \
  python3 tools/ci/run_godot_regressions.py --godot "$CYBERSAND_GODOT" \
  --output build/godot-regressions --keep-going
```

The runner discovers `godot/tests/test_*.gd`, includes the explicit profile probes
and scene startup, and performs a clean import. Cases requiring actual pixels
use the compatibility renderer. Missing display/executable, timeout, explicit
skip, engine/script error and incomplete evidence are distinct failures; process
exit zero alone is insufficient. `--keep-going` retains later case results after
ordinary failure, while import failure stops the shard.

The independent [Linux coverage reader](../../tools/ci/verify_linux_godot_shards.py)
requires complete unique assignments, original logs and source/runtime identity.
The accepted [test-selection guide](testing-validation-and-replay.md#ci-execution-sharding)
and [CI policy](ci-execution-and-performance.md) own coverage and parent budgets.
Historical four-shard migration timings remain dated evidence, not a current
source inventory or physical GPU performance measurement.

## Physical actor timeout investigation

**Current qualified #234 apparatus:** both platform runners use
`run_godot_regressions.run_case` and an independent
[process monitor](../../tools/ci/godot_process_monitor.py). The three suspect
fixtures request live capture after 30 seconds without a new main-thread marker
and fail as `timeout` / `progress_watchdog` at 45 seconds idle. Capture is separately
bounded and cannot defer that failure decision. The ordinary 180-second outer
case ceiling remains unchanged; no heartbeat extends it. Startup, setup, stepping,
frame waits and post-quit stalls are covered externally. Linux attempts process /
`/proc` wait-state and bounded native stack capture; Windows attempts process/thread
state and DbgHelp minidumps for the wrapper and engine child. Refusal or missing
stack capture remains explicit evidence. Full logs and bounded tails are retained.

The original `REGRESSION_PROGRESS` records preserve actual case, phase, rig/model
and last reported physical tick. The additional `CYBERSAND_PROGRESS` sequence and
cumulative step counter are coarse main-thread heartbeats, not an exact blocked
instruction or native-worker count. Unrelated output and timestamp-only changes
cannot renew liveness. No retries, skips, workload reduction, physics parameters
or native-worker count changes are introduced.

The fixture-only [internal guard](../../godot/tests/helpers/physical_internal_watchdog.gd)
observes a separate 120-second whole-fixture limit using a RefCounted Godot thread,
monotonic clock and copied mutex-owned context. It performs no scene-tree, World
or Rapier operation. Expiry emits sticky `ERROR: REGRESSION_WATCHDOG`; a later
successful return cannot erase it. Stop polls for at most one second, then joins
only an exited thread. A blocked main thread is terminated by the external runner
after capture; the internal observer never self-kills and does not promise native
stack recovery. Startup before arming, a process-wide runtime stall and engine
shutdown after disarming remain externally bounded. The
[test-selection guide](testing-validation-and-replay.md#physical-regression-timeout-diagnostics)
owns these failure and observation limits.

Focused checks, with the pinned Godot executable already prepared:

```sh
python tools/ci/test_physical_progress_watchdog.py
python tools/ci/test_godot_process_monitor.py
python tools/ci/test_physical_internal_watchdog.py --godot <godot>
```

The last command executes both a healthy child and an expected-failing child
whose main thread is synchronously blocked. It verifies independent observation,
sticky nonzero failure and join without admitting the expected failure as an
ordinary passing physical fixture.

The [standard 600-attempt workflow](../../.github/workflows/physical-timeout-stress.yml)
is dispatch-only and GitHub-hosted. Set `source_sha` to the exact immutable
candidate commit after applicable exact-head ordinary gates. It runs five batches
of ten repetitions for each of arena, rigs and usable course on Windows/Linux
in serial and three-process parallel modes: 600 physical attempts plus import
preflights. Inspect the independent completeness gate and raw per-attempt evidence.
The [#234 integration ledger](../audits/2026-10-24-issue-234-physical-hang-repair.md)
owns actual source/run identities, completed ordinary admission and fresh
qualification run `40129364630` at immutable merge source
`13b8e631f3e8fbaa2176ed41afc02c434b11e558`: 600/600 physical passes, 0/600
timeouts, zero other failures and 20/20 import passes. Each of the twelve
OS/mode/test strata passed 50/50. The [retained distributions](../audits/issue-234/stress-distributions.csv)
use exact Decimal medians and nearest-rank p95 (rank 48 of 50), including every
physical observation. All 600 raw attempt receipts match the hosted gate.
The [admitted #233 campaign](../audits/2026-10-24-issue-233-physical-regression-timeouts.md)
retains 589 passes, 11 Windows timeouts and zero other physical failures at its
original source, plus the older Linux failure. Preserve all original attempts.

The retained [earlier stress workflow](../../.github/workflows/physical-actor-stress.yml)
and GDExtension `physical_actor_stress` / `rapier_bvh_pair` diagnostics belong to
the [PR #236 investigation](../audits/2026-10-23-physical-actor-timeouts.md).
Its same-host paired campaign 40056501226 recorded six Windows control timeouts,
zero Linux control timeouts and zero candidate timeouts in 300 candidate trials.
Balanced pair order, hardware/fixture identities, matching native stacks and the
scope of earlier failed or inconclusive samples are retained in the
[blocking-call and paired audit](../audits/2026-10-24-physical-actor-bvh-validation.md).
That comparison supports adopting the exact qualified Windows/Linux x86_64 BVH
backport artifacts; other architectures/Web retain release bytes. Runtime locks,
provenance and repository/Windows preflights still reject byte or build-input
drift. Those 300 candidate samples remain separate from #234's fresh standard
600-attempt acceptance. Integrated PR #236 head
`330ded5aa0937b4a46ea0b5f270583a8e0375931` passed exact-head ordinary gates and
merged. Its completed fresh standard campaign qualifies the registered
Windows/Linux x86_64 workload and exact artifacts. Both modes recorded zero
timeouts; descriptive timing differences between clustered hosted batches do
not establish co-tenancy or native-worker-count dependence. The precise
scheduler trigger and untested loads/platforms remain outside that acceptance.
Ordinary run `40125433675` separately retained 45 passing
physical-family observations within 268 passing cases and five passing imports;
these are outside the stress N. The [timing CSVs](../audits/issue-234/ordinary-observations.csv)
retain the actual synthetic checkout `bb84068378765e3874840e19507666c6a7a1e5df`,
which has the same source tree as that PR head, and per-platform runtime hashes.

## Windows retained-runtime execution

The accepted [GDExtension workflow](../../.github/workflows/gdextension.yml)
executes a source-bound Windows candidate through
[run_windows_godot_regressions.py](../../tools/ci/run_windows_godot_regressions.py).
It passes the built candidate with `--native-candidate`; the helper also supports
its retained-runtime path when no candidate is supplied. These are explicit
artifact sources, not interchangeable provenance claims.

The helper verifies exact source identity, runtime inputs, pinned official Godot
archive/version and Rapier before import. It discovers the applicable headless
cases, profile probes and scene startup. Rendered cases are outside this headless
Windows lane and require their own graphical evidence. The execution planner
supplies the current shard count and full-budget allowance; the independent
[coverage reader](../../tools/ci/verify_windows_godot_shards.py) requires every
assigned original case exactly once with source/run/attempt identity and logs.

Retain `windows-execution.json`, commands, runtime/tool identities and raw log
hashes even when execution fails. Read its completion, source-drift and failed-case
fields. A successful Windows cross-build does not replace Windows execution, and
headless Windows execution does not establish physical Windows/NVIDIA playfeel.
For intermittent physical actor/usable stalls, follow the
[timeout diagnostic procedure](testing-validation-and-replay.md#physical-regression-timeout-diagnostics)
with the exact current source and original watchdog contract. Do not dispatch a
large historical stress campaign merely to validate documentation.

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

### Residual LCB-001 native setup and receipt checks

The moving-body gas repair additionally registers
`LCB-002 moving gas masks retire and preserve exact identities` in ordinary,
ASan/UBSan and TSan Makefile suites and the Windows MSVC test source list.
With an already built ordinary binary, `build/tests "moving gas masks"` selects
the focused group. It covers all four retirement reasons plus a still-live
negative control, reference/cached/dormant with configured1/4 workers, immediate
masked save/restore and exact authority/ledger/history continuation. Configured
workers do not prove actual task participation. The separate ordinary Main
regression supplies actual Rapier motion and asynchronous feedback evidence;
neither test alone establishes performance or final platform acceptance. See the
[dated repair record](../audits/2026-10-25-pressure-moving-mask-gas-retirement.md).

The accepted #246 native shared-contract checkpoint registers its whole-cell
Water, normalization, native-issued refusal, typed receipt and quantity-ledger
cases in the ordinary `make test` and `build_windows_msvc.bat` suites. The
[native contract](../architecture/liquid-prepared-setup-and-receipts.md) owns
the interfaces and qualifications; the [dated evidence](../audits/2026-10-24-lcb001-residual-shared-contract.md)
records the earlier two 121-case native builds and scoped fresh Windows Godot
proof, followed by five new rectangle/event/gas-ID regressions. The latest native
accepted shared-contract baseline has126 cases; the #201 moving-mask repair
branch has141 ordinary cases and the combined #212 IN branch has153. Use each dated receipt for its exact tested
source/delta rather than treating historical counts as a current global total.

```sh
python tools/lcb/water_normalization_contract.py --check
python tools/lcb/liquid_run_receipt_contract.py --check
python tools/lcb/derive_capability_matrix.py --check
python tools/lcb/policy_contract.py --check
python tools/lcb/native_policy_artifacts.py --check
python tools/lcb/lcb_registry.py build --check
python -m unittest discover -s tools/lcb -p 'test_*.py'
```

The two new oracles compare complete canonical byte vectors with independent
Python encoders. Source-sensitive runtime publication remains required before
ready-PR acceptance. Both development runtimes passed scoped publication in
run `40138333825` at source `29c7c4d`, appended as `888a39f0`; the dated audit
records their hashes and exact coverage. Full non-draft acceptance remains
separate. Scratch Windows proof does not reattest retained libraries. The
Godot normalization opt-in and full application host are separate integration
work, and no new #201/#212 implementation is included in this checkpoint.

### Controlled liquid application-host slice

The later integrated [`test_liquid_inertial_host.gd`](../../godot/tests/test_liquid_inertial_host.gd)
requires a fresh DLL from accepted #246 main plus the stable IN checkpoint and
owned adapter delta. It reads the independent sibling
`docs/reference/inertial-parameter-vectors.json`, exercises all17 actual damping
values, radius2 refusal/radius3 admission, actual native extension/instance
versions, three families at workers1/4, CYPS3 continuation, normal controls and
articulated graph/equipment/mask adoption. The
[integrated ledger](../audits/2026-10-25-lcb003-integrated-inertial-host.md) records
artifact/input/log hashes and the wider scoped local regression matrix.

On `codex/lcb003-application-host`, the focused
[`test_liquid_prepared_host.gd`](../../godot/tests/test_liquid_prepared_host.gd)
executes the typed native preparation/token API, explicit normalization,
canonical copied receipts and actual desktop/synchronous application controller
routes. It uses Semaphore barriers at the preparation/commit boundary to test
same-definition supersession, ordinary reset and stop deterministically. It
also retains masked stored Water, host event cursors and applied receipts on
refusal. Run with a freshly built source-matched development DLL:

```text
godot --headless --path godot --script res://tests/test_liquid_prepared_host.gd
```

The [dated host ledger](../audits/2026-10-24-lcb003-controlled-host-slice.md)
separates Windows headless execution of `web_main.tscn` from actual browser
execution, records artifact/source inputs and preserves the first test-harness
failure. Retain policy, worker, MicroScenario, native-observation, workbench and
Water Feel lifecycle regressions alongside this focused case. No release
runtime is supplied by this local source checkpoint; Linux, real Wasm/browser,
hosted publication and final exact-head acceptance remain separate gates.

### Normal liquid-comparison UI slice

The subsequent [`test_liquid_water_feel_host.gd`](../../godot/tests/test_liquid_water_feel_host.gd)
checks72 assertions: original35 recipe identity/player/action preservation,
exact Current native control, explicit initial normalization/refusal, final
request/reset/stop fences, ordinary Water Feel activity and source ledger,
same-semantic-hash refusal acknowledgement, actual panel/reset/semantic change,
blind/body/future-source refusal and native synchronous controller. Retain the
existing Water Feel controller/blind/10-exit,24-policy/70-build native integration,
35-recipe and shared owner regressions. The [dated evidence](../audits/2026-10-25-lcb003-water-feel-constructor.md)
identifies the unchanged native DLL separately from new GDScript and preserves
the typed-array fixture failure with recoverable before-test source snapshots.

The subsequent [`test_liquid_owner_observation.gd`](../../godot/tests/test_liquid_owner_observation.gd)
checks28 assertions through actual Host/Main panel/synchronous owners: staged
collection refusal, final-guard refusal, copied full record versus compact
publication, native receipt/generation binding, normalized whole-cell selection,
restart and default retirement. The physical transaction test additionally
retains the old actual articulated graph's record on terrain refusal. The
[owner ledger](../audits/2026-10-25-lcb003-owner-observation.md) records seven
scoped Windows processes, fresh DLL inputs and the genuine hosted stale-registry
failure/derived repair. Run this only with the new token-bound capture adapter.

The later [`test_liquid_host_evidence.gd`](../../godot/tests/test_liquid_host_evidence.gd)
requires a fresh observation-enabled DLL and checks34 assertions: actual API path
and current file hash, real stale-publication mismatch, typed native byte/digest
consistency, immutable canonical host values, exact signed identities, retained
qualifications and explicit malformed/depth/capacity refusal. Its optional
external process barrier supports an OS-module query; the clean editor shadow
probe instead uses a scratch-only EditorPlugin and Godot's real editor MainLoop.
The [observation ledger](../audits/2026-10-25-lcb003-qualified-host-observation.md)
records both clean controlled launches and the failed custom-editor harnesses.
These local Windows proofs do not establish actual Wasm/browser execution or
full source-matched publication/host eligibility.

The subsequent [`test_liquid_tower_host.gd`](../../godot/tests/test_liquid_tower_host.gd)
exercises ordinary Tower dispatch with the existing integrated development DLL:
original Current constructor parity, final floor/player preparation, independent
transport, releases, deterministic request/reset/stop commit fences, actual Main
and native synchronous panel apply/refuse/reset/profile, typed identity retirement
and committed observer-fault classification. Its
[dated ledger](../audits/2026-10-25-lcb003-tower-constructor.md) qualifies unchanged
native inputs and the separate GDScript checkpoint; no new published runtime or
actual browser execution follows.

The later [`test_liquid_comparison_ui.gd`](../../godot/tests/test_liquid_comparison_ui.gd)
executes actual feature-launcher and desktop/synchronous panel button routes,
native availability and immutable requests, apply/refuse/reset, explicit gross
normalization counters, disabled unsupported actor routes, a mixed-liquid World
step and complete-hash agreement with the original Current control. It requires
the updated native bridge and exact fixture files. Keep sibling `examples/`
fixtures beside a staged `godot/` project for the existing semantic-depth launcher
regression. Run:

```text
godot --headless --path godot --script res://tests/test_liquid_comparison_ui.gd
```

[UI evidence](../audits/2026-10-25-lcb003-liquid-comparison-ui.md) records the fresh
local development DLL, source input manifests, commands, timeouts, failures and
remaining platform gates. The [constructor matrix](lcb-manual-comparison-ux.md#constructor-coverage-at-this-checkpoint)
is the authoritative boundary of this UI slice. No browser, release provenance
or complete constructor acceptance follows from native headless execution.

### Staged sampled/exploratory host slice

[`test_liquid_sampled_preparation.gd`](../../godot/tests/test_liquid_sampled_preparation.gd)
adds real candidate-versus-live collision and spawn-recovery checks, declared
precommit equipment refusal, retained actor/equipment/epoch and masked native
state, deterministic supersession/settings barriers, final independent PENV
configuration, owner-frame acknowledgement and actual main/panel/F5/reset and
synchronous controller routes. Run with the freshly built adapter:

```text
godot --headless --path godot --script res://tests/test_liquid_sampled_preparation.gd
```

Retain actor session/rig/usables, existing host/UI/controller/workbench, exploratory
actor selection and Water Feel lifecycle cases. The [sampled evidence](../audits/2026-10-25-lcb003-sampled-exploratory-host.md)
records the October 25 source/runtime, exact ten-process matrix and failures.
**Historical checkpoint:** that run used pre-final-fix native base `9e91a9f7` and
required a repeat after #246 integration. That dated requirement does not describe
a present unmerged blocker. The focused runner remains available; qualify any new
run against its actual source/runtime and keep physical-body, publication and
actual browser claims separate.

### Staged articulated physical host slice

The [physical preparation contract](../architecture/liquid-prepared-setup-and-receipts.md#staged-articulated-physical-owners)
adds three focused cases, all requiring a fresh adapter DLL and actual Rapier:

```text
godot --headless --path godot --script res://tests/test_prepared_physical_owner.gd
godot --headless --path godot --script res://tests/test_liquid_physical_preparation.gd
godot --headless --path godot --script res://tests/test_liquid_physical_transaction.gd
```

They verify actual frozen poses across real physics frames, shared native mask
raster parity and stored Water, tick-zero mask/receipt equality, copied pending
facts, stale/tampered continuation refusal, final request/reset/settings/stop
fences, admitted paint/profile disposition and actual panel/application graph
adoption or retained-owner refusal. Keep ordinary physical integration/equipment,
sampled/controlled/UI, MicroScenario, actor-selection and Water Feel cases in the
same scoped matrix. **Historical checkpoint:** the October 25 run used a
pre-final-#246 native base, so its evidence could not qualify later integration,
publication, Linux or Web. Current runs must use current source-matched runtimes;
the old outstanding gates are not a claim about today's branch state.

### Branch-scoped runtime publishers

[Runtime publication custody](github-development-and-release.md#source-matched-runtime-publication)
owns the current generic requirements. A publisher/request is scoped to its
branch, source inputs, schema, runtime paths and actual execution evidence.
Inspect the applicable current publisher; do not restore a historical workflow
and treat its old authorization or source lease as active.

Earlier GEN/PLAY/Water publishers and their retained failures remain in the
[source-pinned previous procedure](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/local-build-and-validation.md#branch-scoped-runtime-publishers)
and the original linked audits. Their source-qualified artifacts remain evidence
for their recorded input sets. Retiring or modifying a publisher belongs to its
authorized implementation/publication task, not documentation cleanup.

The existing [standalone repeated Play campaign](../../tools/play/run_auto_campaign.py)
remains a deliberate qualification tool. Use a fresh output directory under
ignored `build/` or outside the checkout; inspect its source/runtime admission
and required process budget before running it. A campaign result cannot substitute
for the applicable exact-head platform and owner acceptance gates.

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
sources for each test. The current aggregates contain sixteen executables each:
seven showcases and nine principal tests, including GEN-005 semantic planes.
The [shared execution policy](ci-execution-and-performance.md#owner-policy-and-acceptance-boundary)
owns current command and family watchdogs. The earlier five/ten-minute bounds
below describe historical qualification. The
[dated audit](../audits/2026-10-21-gen004-hierarchical-generation.md)
retains the cold-build timeout that motivated this change and subsequent results.

The [bounded build investigation](../audits/2026-10-31-worldgen-bounded-build.md)
retains the later post-merge sanitizer timeout: eight tests passed, and the ninth
was interrupted after prerequisite compilation consumed most of its ten-minute
budget. The current Native workflow uses `make -j2 --output-sync=target` for these
two aggregates. Seven independent showcases use the same two-job Make budget as
compilation, followed by the nine principal recipes in their original order.
See [parallel showcase execution](ci-execution-and-performance.md#parallel-worldgen-showcase-execution)
for the complete test and failure contract. No compilation moves outside the
original command watchdog. The inventory helper checks forced serial/two-job
dry runs without executing a compiler and rejects omitted/duplicated showcases,
omitted/reordered principal tests or altered source/flag families.
Its passing checks do not replace actual cold compilation/execution. The first
local two-job normal build failed at linking with an unexplained empty object;
the separate sanitizer attempt stopped at its second test with a nonexecutable
ELF output. Both failed qualifications and diagnostic records remain preserved.
Original candidate `b7a29cac` subsequently passed its first hosted Native matrix,
with all nine normal and nine sanitized binaries completing in 103.95 and
289.31 seconds inside the same 300/600-second limits. Independent raw readback
checks all six families, exact compilation/test inventories and 154 scientific
CLI invocations; maximum child RSS is not concurrent aggregate memory. The
[cumulative LIFE011 preparation](../audits/2026-10-31-worldgen-bounded-build.md#cumulative-life011-integration--preparation-only)
preserves that evidence's original source identity and all failed attempts.
It changes no Makefile, native/Godot/scientific input or runtime. Fresh complete
resulting-head hosted gates are required before integration.

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

The [owner's issue #3 decision](https://github.com/techrote/cybersand/issues/3#issuecomment-5593128559)
makes Web an occasional disposable experiment. These commands describe the
retained experimental path, not a maintained CI/release obligation or a desktop
acceptance gate. Qualify the exact inputs and coverage of each new experiment.

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
An older companion wrapper supplied the acquisition base as `--source-commit`;
that historical export field is not proof of current HEAD. Inspect the actual
wrapper used by a new experiment and capture its current source and artifact
hashes; this repository cannot attest an unseen external wrapper.
See [source identity](source-checkpoint-and-recovery.md).

Preview generated output through HTTP with WASM MIME and profile headers, then
run the actual browser fixture. Checksums/HTTP checks prove packaging; native
headless Godot proves native execution; only browser execution tests Web behavior.
The [Web guide](web-threading.md) owns hosting requirements, and the
[validation ledger](../reference/validation-evidence.md) owns dated outcomes.

## How is the physics baseline rebuilt?

Follow [physics characterization](physics-characterisation.md): rebuild the
native CLI and adapter before running the deterministic P1–P4 matrices. If the
experiment claims Web results, build/export its applicable profiles and execute
them in a real browser. Capture actual HEAD/local file hashes separately from
legacy export acquisition labels.
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

### Shared Play session and owner qualification

The [executable manual packet](play-desktop-manual-qualification.md) prepares
a source/runtime-pinned checklist and initially untested result sheet. Its
generator performs no engine or physical execution and cannot grant acceptance.

Use the exact candidate checkout named by its PR, Godot
`4.7.stable.official.5b4e0cb0f` and the repository-pinned native/Rapier LFS bytes.
Record `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git status --short`,
Godot version, OS/GPU/CPU and physical controller model/mapping. Materialize
LFS and run the current provenance gate before interpreting gameplay evidence:

```text
git lfs pull
git lfs fsck
python3 tools/ci/check_repository.py --require-materialized
godot --headless --path godot --editor --quit
godot --path godot
```

Select **Play session** at the launcher. Choose the Player Playground map,
one of the five mechanical rigs, controls, lap/free-play, solver policy and
starting camera. Click **Build selected session**, wait for the actual applied
actor/policy, release movement controls and click **Play / resume**. P pauses,
R restarts the applied session, F changes camera and F2 returns to the launcher.
The in-host **Play session** button reopens selection. Build changes configuration;
Restart ignores unsubmitted choices and retains the accepted configuration.

Execute the existing [concrete #270 checklist](https://github.com/techrote/cybersand/issues/270#issuecomment-6485284121)
on the physical target machine: each rig's natural movement/camera/lap, pause and
focus loss/regain, held-control neutral rearm, supported policy rebuild/refusal,
physical stick/A/B/X/shoulder behavior, keyboard/controller handover, selected
controller unplug/replug, repeated reset/exit and actual responsiveness/feel.
Also try keyboard-only and free-play selections and record requested/applied
receipts. Record each item as pass, fail or not tested with exact source/runtime
identity and representative tick/frame/snapshot/wait measurements. A successful
headless run or software-rendered layout inspection does not execute this gate.

The focused automated command is:

```text
godot --headless --path godot --script res://tests/test_play_ui005_session_selection.gd
```

This test runs actual Main/native worker/Rapier reconstruction for all five rigs,
with synthetic OS focus and connected-device enumeration. It is automatically
discovered by ordinary Windows/Linux Godot CI; no dedicated workflow is needed.
Its [audit](../audits/2026-10-30-play-ui005-integrated-session.md) keeps local,
hosted, rendered-layout and unexecuted physical/human evidence separate. On
restricted Linux environments, set writable XDG config/data/cache directories
before importing or running; preserve any earlier failed invocation.

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
in the source-derived GitHub-hosted shard plan. The current planner determines
shard counts from the inventory and time budgets; four is not a fixed suite size. The original
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

### 4LY-003 flight lab checks

**Current 4LY-003 physical flight lab:** [flight-lab contract](../systems/physical-flight-lab.md),
[prospective criteria](../../godot/tests/fixtures/4ly003_qualification_registration.json),
[historical implementation checkpoint](../audits/2026-10-23-4ly003-checkpoint.md),
and [frozen-teacher final-score evidence](../audits/2026-10-24-4ly003-final-qualification.md).
The latter passes the recorded Linux actual-host teacher-family thresholds but
does not provide separately attested external custody or learned qualification.
The existing Godot GDExtension suite auto-discovers the development
episode, gameplay scene, bounded throughput and two scored-family
development fixtures by wildcard. The pinned runtime must include real
`CyberNativeCellWorld` and `RapierPhysicsServer2D`, never mocks.

```sh
godot --headless --path godot --script res://tests/test_physical_flight_lab.gd
godot --headless --path godot --script res://tests/test_physical_flight_pilot.gd
godot --headless --path godot --script res://tests/test_physical_flight_lab_scene.gd
godot --headless --path godot --script res://tests/test_physical_flight_teacher_dev_free.gd
godot --headless --path godot --script res://tests/test_physical_flight_teacher_dev_obstacle.gd
```

The first validates frozen 4LY profile/controller digests, actual
native/Rapier 60 Hz stepping, copied policy/normalization boundary,
issued-observation generation fences, physical navigation samples,
hover and power-off negative controls. It is deliberately
**development-only**; the separately registered final split must
remain sealed until the teacher implementation is frozen. The second
measures at most 960 physical ticks from one actual host, along with
decision/reset/JSON-serialization/memory counters. The scored development
fixtures retain separate native/Rapier JSON traces and their SHA-256
inventory under `CYBERSAND_PRESENTATION_EVIDENCE`; the
[separate Python readback](../../tools/ci/readback_4ly003_development.py)
is required **after** Godot exits in the Linux sharded and serial
workflows. The original public final geometry is retired and superseded
by [v3 sealed external geometry](../../godot/tests/fixtures/4ly003_split_amendment_v3.json).
It cannot be accessed without the separately admitted suite.
These wildcard tests alone do not establish final teacher acceptance:
the one-use final score and independent readback are retained in the
separate audit. Neither learned-policy success nor desktop real-time
throughput is demonstrated. Do not run neural training in routine PR CI. Keep failed episodes and the exact
tested checkout and runtime identities.

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

## Native worker-race feedback order

**Current CI configuration, 2026-10-25:** the complete `build/tests_tsan`
compile and execution run before the ordinary and ASan/UBSan build stages.
The GitHub-hosted Ubuntu runner, full test executable, `halt_on_error=1`,
separate fifteen-minute compile/run limits and ninety-minute job limit are
unchanged. All existing Native stages still apply. This order exposes worker
ownership failures earlier; it does not qualify a repair without actual
successful execution and the complete required final-head matrix.

The [Water IN publication record](../audits/2026-10-25-water-inertial-publication.md)
preserves failed Native run `40205443189` at `e2411469`, whose TSan check found
shared chunk-activity access after the ordinary and ASan/UBSan groups passed.
Native repairs still require fresh source-matched runtimes and final-head gates.

## Soliding successor validation

`make soliding-test` and `make soliding-sanitize` compile the standalone lifecycle
and discovery suites. They change no installed native runtime artifact. See the
[control measurement procedure](soliding-measurement.md) for immutable-source
benchmark compilation; builds/tests must stop during registered local timing.

Native CI prebuilds the eight soliding sanitizer executables under a separate
compilation watchdog, then runs the unchanged `make soliding-sanitize` group
with ASan/UBSan failure handling. Current watchdog values come from the
[shared execution policy](ci-execution-and-performance.md#owner-policy-and-acceptance-boundary)
and Native planner; the earlier twenty/ten-minute command and ninety-minute job
bounds below are historical. The original compiler flags, eight executables,
test order and hosted runner remain. Six executables now share exact-input
core objects within each build configuration; see
[soliding compilation reuse](ci-execution-and-performance.md#soliding-compilation-reuse)
for invalidation, interruption and full-coverage requirements. The
[residual shared-contract audit](../audits/2026-10-24-lcb001-residual-shared-contract.md#native-aggregate-compilation-timeout-and-separate-build-budget)
preserves the preceding aggregate timeout while compiling the final executable
and distinguishes partial earlier passes from complete final-head acceptance.

`make soliding-benchmark-smoke` compiles the isolated journal characterization
with warnings as errors and exercises its bounded-work/fairness assertions on a
small fixture. CI timings are not performance acceptance measurements.

## Combined desktop entry

The project now defaults to `res://feature_launcher.tscn`; F2 returns there and discards the current session. Direct `res://main.tscn` and showcase user arguments remain available. See the [physical actor programme](physical-actor-programme.md) for the Blacksite comparison and `test_physical_actor_trial.gd` regression.

Opt-in coupled lockstep (desktop, default off): `godot --path godot -- --lockstep-coupling`
makes cells and bodies take turns, so the same start gives the same result. Under
load it runs in slow motion instead of going stale. Labs and the workbench keep
their own pacing. See [coupled desktop determinism](../architecture/determinism-and-boundary-transfers.md#coupled-desktop-determinism--2026-11-06).


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
The scoped GEN-007 publisher (retired; see
[branch-scoped runtime publishers](#branch-scoped-runtime-publishers)) bound
Linux/Windows execution to exact source and runtime bytes; the ready-for-review
full repository gates remain separate.

## Native Brine IN checkpoint
The isolated #212 [Brine reference](../architecture/inertial-cellular-v1.md) is exercised with `make build/tests` then `./build/tests "LCB-005"`; the full native suite remains required. [Dated local evidence](../audits/2026-10-24-lcb005-native-brine-checkpoint.md) distinguishes Windows LLVM execution, failed fixture premises, actual worker participation and memory components from future Linux/MSVC/Godot/runtime qualification. No Water IN or application adapter follows from this native-only checkpoint.

For the native damping parameter, run `python tools/lcb/inertial_parameter_contract.py --check` and the LCB Python suite as well as the native groups. The optional IN family blockv2 applies `damping_numerator`0..16/16(default1); actual readback/identity and save/restore are native-owned. The worker fixture observes four actual participants at0/default1/16, while the matched tail fixture records rounding/retained-motion outcomes without assuming every arm settles. Existing illustrative v1 vectors remain separate; use the family reference for the exact schema and qualifications.

The [corrected Brine IN publication](../audits/2026-10-25-lcb005-pressure-union-integration.md#actual-sequence3-publication-of-the-contact-repair)
passes actual Windows/Linux import and14 scoped cases perOS at source
`c11983c2`, run `40160900817`. IN10192 includes the mandatory resting-contact
regression. The runtime-only append is `fcf0e9b6`; full exact-head ready-PR
matrix remains a separate gate.

The accepted native default-demo API has a focused
`test_liquid_default_demo_preparation.gd` case. It requires a fresh staged DLL
with the new binding, compares the complete old-DLL tuple controls at four
Water/transport configurations and exercises candidate masks, token/refusal,
geometry and constructor-origin lifetime. Its [dated Windows proof](../audits/2026-10-25-lcb003-native-default-demo-preparation.md)
retains the diagnostic-lifecycle failure and 167/493/72 final regression results.
This native API case does not test Main/worker adoption or published platforms.

The later [desktop native-default owner checkpoint](../audits/2026-10-25-lcb003-desktop-native-default-host.md)
adds `test_liquid_desktop_default_host.gd` plus five non-discovered helper scripts
under `tests/fixtures/lcb/desktop_default_*.gd`. It requires actual86/0, successful
process exit, two healthy FM/CY moving-body rows and three native pressure-capacity
refusals. A success footer followed by0xC0000005 is a failure. The corrected API
case is164/six sections; its earlier167 result predates the initial-capacity
preflight. Registered native capacity46 and focused ASan+UBSan46 are bounded
separate results; seven affected Godot processes pass1078 assertions. Keep old
failures, final EOF-only transition, raw/canonical source bindings and actual
runtime identities. Fresh integrated native/publication/full platform gates
remain required; do not substitute the old development DLL for them.

## Earlier checkpoint procedures

<a id="consumed-app-publication--source5f02-and-checkpoint-ea96--2026-10-25"></a>
<a id="current-trial-consumption-of-corrected-app--preparation-only"></a>
<a id="historical-preparation-and-water-artifact-consumption"></a>
<a id="integrated-desktop-trial-successor--2026-10-25"></a>
<a id="large-authored-workbench-landscape-admission"></a>
<a id="play-input011-ordinary-ui-authority-and-raw-evidence-gate--2026-10-31"></a>
<a id="play-life010-raw-evidence-gate--2026-10-31"></a>
<a id="play-life011-composed-policy-raw-evidence-gate--2026-10-31"></a>
<a id="published-and-development-identity-test-controls"></a>
<a id="source-built-windows-candidate-validation--2026-11-08"></a>
<a id="trial-successor-correction-after-accepted-app--2026-10-25"></a>
<a id="water-in-native-successor-checks"></a>
<a id="water-publisher-guards-and-publication-checks"></a>

These earlier bookmarks refer to dated checkpoint procedures. The
[source-pinned previous guide](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/local-build-and-validation.md)
preserves their commands, identities, results and original limits. Use the current
procedures above for new work; old source leases, authorizations and pass claims
do not transfer to a new checkout.
