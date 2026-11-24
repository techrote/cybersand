# Retrieval contexts for independent answer review

Source-backed expected facts and the complete top-five contexts follow. A canonical route hit alone is not an answer pass.

## DR01: I cloned CyberSand on Windows. Must I have C:/kybersand and dev.cmd before I can open the Workbench?

Canonical rank: 1

Expected facts:

- A source-only checkout has launch-desktop.cmd; dev.cmd belongs to the separate companion workspace.
- Verify materialized runtime inputs and the exact Godot pin; the configured main scene is the Feature Launcher.

### Rank 1: operations/local-build-and-validation.md — Local build and validation > Windows development commands

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Windows development commands
From `C:/kybersand`, the companion workspace provides `dev.cmd` / `tools/dev.py`. Host paths, installation and environment overrides belong to `C:/kybersand/docs/LOCAL_DEVELOPMENT.md`. Source-only clones do not contain these wrappers; the repository-native scripts are listed below. ```powershell .\dev.cmd doctor .\dev.cmd native-bindings .\dev.cmd native-build .\dev.cmd native-test .\dev.cmd godot-test .\dev.cmd web # Optional internally parallel Web profile: .\dev.cmd web --profile threaded ``` The repository also contains `launch-desktop.cmd` / `tools/launch_desktop.ps1` for source-only Windows checkouts. It validates the pinned Godot/runtime inputs, prints checkout/runtime identity, exports the exact checkout SHA to the child Godot process as `CYBERSAND_SOURCE_REVISION` for recording provenance, and does **not** rebuild or replace retained runtimes. `native-bindings` builds pinned Windows godot-cpp; `native-build` builds the GDExtension. `native-test` compiles/runs the C header check and native tests; `godot-test` imports the project then runs all `test_*.gd` runners. Godot tests load the installed DLL: running them alone does **not** rebuild that DLL. Record its hash and source identity with the result. The wrapper allows 240 s for import, 180 s per Godot runner, and rejects Godot error output even with exit 0.


### Rank 2: operations/web-threading.md — Web worker profiles and reference tests > Build and preview

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Build and preview
From `C:/kybersand`: ```powershell .\dev.cmd web --profile threaded .local/python/Scripts/python.exe source/tools/serve_web.py --directory source/build/web-threaded --port 8002 --open ``` While the preview server is running: ```powershell .\dev.cmd http-smoke --profile threaded --url http://127.0.0.1:8002/ ``` `dev.cmd web` builds compatibility. Use export-only only with a matching fresh side module; successful packaging does not prove source-to-binary freshness. The [build guide](github-development-and-release.md) owns exact dependency pins and unresolved CI/toolchain drift. Native/Web generated bindings stay separate. The supplied server sets COOP `same-origin`, COEP `require-corp`, appropriate WASM MIME and no-cache behavior. Threaded hosting needs a secure context (HTTPS or localhost) and cross-origin isolation. Serve the complete export, including worker JavaScript, PCK, WASM, notices and manifest. HTTP/checksum success is structural evidence; open the actual browser for execution. Local delivery is a separate explicit workflow after acceptance: `Deliver-Web.ps1 -Profile threaded` copies to `C:/cybersand/web-threaded`; compatibility uses `C:/cybersand/web`. Documenting this command does not execute delivery or remote publication.


### Rank 3: operations/physics-characterisation.md — Reproducible physics characterisation > How do I reproduce a run?

Document: Reproducible physics characterisation
Path: operations/physics-characterisation.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Opt-in physics measurement tooling, historical issue 9 baseline and current interaction regression routes
canonical-for: [physics-measurement-tooling, physics-baseline-procedure]
last-reviewed: 2026-10-19
Section: Reproducible physics characterisation > How do I reproduce a run?
Work in `C:/kybersand/source`; keep raw files under `C:/kybersand/validation/local/<date>-physics/`. Build the adapter with `C:/kybersand/dev.cmd native-build` before Godot measurements. The Python runner builds its own native CLI by default; `--skip-build` requires an identified, source-matched executable. The installed Godot DLL is not rebuilt by `godot-test`. ```text C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py native --group expanded --output C:/kybersand/validation/local/2026-09-09-physics/native-expanded C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py native --group controls --output C:/kybersand/validation/local/2026-09-09-physics/native-controls C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py godot --group controls --output C:/kybersand/validation/local/2026-09-09-physics/godot-controls-final C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py godot --group expanded --output C:/kybersand/validation/local/2026-09-09-physics/godot-expanded C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py godot --group finalists --seeds 20 --ticks 7200 --output C:/kybersand/validation/local/2026-09-09-physics/godot-creep ``` [run.py](../../tools/physics/run.py) records commands, fixture JSON, actual HEAD, dirty status, source-file hashes, executable hashes and platform in each result directory. New Godot batches also capture their own manifest. A seed is a coordinate translation, **not a new engine random stream**. The checked-in generator plus explicit configuration is the replay input; CYSD1 is not used. All runs start with newly constructed authority. Do not edit sources between batches; preserve each tested source snapshot if iterating. Defaults are five seeds `0..4`, 1,800 completed ticks, `dt = 1/60 s`. Finalists use seeds `0..19` and 7,200 ticks. The separate interpreted fallback defaults to one seed/180 ticks, overridable with `--fallback-ticks`; it is a semantic reference with no native Water-mass or rule-event parity claim. Timeouts are 180 seconds per native CLI run, 300 for its build, and 3,600 per Godot batch. A failed run retains its output; it must not be counted as completed evidence.


### Rank 4: operations/materials-lab-authoring.md — Materials Lab v1 > Launch and prerequisites > Windows launch

Document: Materials Lab v1 inspection, candidate authoring and native tests
Path: operations/materials-lab-authoring.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Accepted desktop native inspection, candidate authoring, isolated World comparisons and existing-material MicroScenarios; no runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-24
Section: Materials Lab v1 > Launch and prerequisites > Windows launch
From a source checkout, run the checked desktop launcher: ```powershell .\launch-desktop.cmd -Godot "C:\Tools\Godot\Godot_v4.7-stable_win64.exe" -- --materials-lab ``` A complete evaluator may instead supply **Open-Materials-Lab.cmd**, its own compiler/dependencies and qualification manifest. Follow that package's launcher and keep its payload together. The [completion record](../audits/2026-11-11-materials-lab-completion.md) identifies the historical package; its existence does not qualify a different archive or guarantee a current download. Basic inspection uses the matching runtime, while candidate compilation needs the additional tools below. For source candidate compilation, start Godot from a configured x64 C++20 compiler environment; for MSVC use an **x64 Native Tools Command Prompt** with Python available. Select `cl` or its full executable path in the Edit copy tab. An executable path alone cannot supply MSVC's missing SDK include/library environment. The Python default on Windows is `python`. From **PowerShell inside the cloned repository**, resolve the checkout before launching. PowerShell requires `&` before a quoted executable path: ```powershell $labCheckout = git rev-parse --show-toplevel & "C:\Tools\Godot\Godot_v4.7-stable_win64.exe" --path "$labCheckout\godot" -- --materials-lab ``` The exact Windows execution status belongs to the dated qualification record. Linux screenshots and a successful cross-build are not Windows graphical or human acceptance.


### Rank 5: operations/local-build-and-validation.md — Local build and validation > First launch from a source checkout

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > First launch from a source checkout
Use this repository's launcher and retained runtime for a first exploration. A native rebuild is a separate development task. The [player getting-started guide](getting-started.md) walks through opening the Workbench; this page owns the build, identity and validation procedure. From a new checkout with Git and Git LFS installed: ```sh git clone https://github.com/techrote/cybersand.git cd cybersand git lfs install --local git lfs pull git rev-parse HEAD git status --short python3 tools/ci/check_repository.py --require-materialized ``` On Windows, use `python` instead of `python3` when that is the installed command. `git lfs pull` obtains the committed runtime payloads. A small text pointer is not a usable DLL or shared library. `check_repository.py` checks the runtime bytes and recorded source inputs; it also checks documentation and dependencies, so read the actual failure rather than assuming every failure means a broken DLL. **Windows:** install the [exact Godot pin](#which-build-inputs-are-required), then run from this repository root in PowerShell: ```powershell .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe -PrintIdentityOnly .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe ``` The path is an example: use the actual executable location. The launcher also accepts `CYBERSAND_GODOT`, or searches `C:\Godot47`. It validates the pinned Godot version, materialized Windows runtimes and CyberSand DLL hash; it prints the checkout/runtime identity and performs no build or replacement. The default project scene is [Feature Launcher](../../godot/project.godot), which routes to the ordinary **Shared Workbench** and standalone scenes. `-Editor` opens the same project in the editor. `dev.cmd` is not required for a source-only checkout. **Linux x86_64:** with the pinned Godot executable and materialized Linux runtimes, use an explicit executable path: ```sh CYBERSAND_GODOT=/absolute/path/to/Godot_v4.7-stable_linux.x86_64 "$CYBERSAND_GODOT" --version "$CYBERSAND_GODOT" --headless --editor --path godot --import "$CYBERSAND_GODOT" --path godot ``` The version output must match the table below. The last command requires a graphical session. Import and launch are separate steps; successful project import is not proof that native gameplay or every feature ran. A software display is useful for reproducible graphical tests, but does not establish the owner's Windows/NVIDIA playfeel.

## DR02: Can I use any Godot 4 build, and which godot-cpp version matches the native library?

Canonical rank: 1

Expected facts:

- The runtime pin is exactly 4.7.stable.official.5b4e0cb0f.
- godot-cpp is pinned to 101ae38034304346a46ea9ea84ae156d3e860496 and API 4.7; version similarity alone is insufficient.

### Rank 1: operations/local-build-and-validation.md — Local build and validation > Repository-native build and test commands

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Repository-native build and test commands
From the source root on a configured Linux host: ```sh make c-header-check make -n test make -j2 test make sanitize make thread-sanitize ``` `make test` includes the current native World, soliding, worldgen and material baseline targets. The [Makefile](../../Makefile) is the executable inventory; `make sanitize` and `make thread-sanitize` have distinct target coverage, so do not claim that either alone executes every subsystem sanitizer. Focused generation and soliding sanitizer targets remain available. The default AddressSanitizer configuration enables leak detection; a historical hosted exception is not a new default. These commands may compile substantial native source. They are procedures, not pass claims. Set a budget appropriate to the selected target and host; do not reuse historical 120/300-second examples as current full-suite budgets. The accepted [CI execution policy](ci-execution-and-performance.md) derives hosted allowances without weakening scientific cases or sanitizer failures. A GDExtension rebuild additionally needs pinned godot-cpp and SCons: ```sh export GODOT_CPP_ROOT=/absolute/path/to/pinned-godot-cpp export SCONS_PYTHON=/absolute/path/to/build-venv/bin/python SCONS_JOBS=2 tools/build_pinned_godot_cpp.sh linux CYBERSAND_NATIVE_OUTPUT="$PWD/build/libcybersand_native.linux.x86_64.so" \ tools/build_native_extension.sh ``` The example writes the candidate extension under ignored `build/`, leaving the retained library alone. Inspect and qualify the candidate before installing it into a test project. Installing a locally built library does not create accepted runtime provenance: [guarded publication](github-development-and-release.md#source-matched-runtime-publication) requires its actual source, input hashes, target-platform execution and lease. The build scripts enforce pinned dependency revision and source checks; do not use `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT` to report a reproducible release. For Windows GDExtension cross-builds, use `build_pinned_godot_cpp.sh windows` and [build_native_extension_windows.sh](../../tools/build_native_extension_windows.sh) with the pinned `LLVM_MINGW_ROOT`/`WINDOWS_CXX` inputs. A PE/import inspection is separate from execution on Windows. The root `build_windows_msvc.bat` is a native core build entry point with its explicit test list, not the complete Godot/native qualification matrix. The [Windows execution helper](../../tools/ci/run_windows_godot_regressions.py) and accepted workflow own source-bound Windows Godot execution.


### Rank 2: operations/getting-started.md — Getting started with CyberSand > Source checkout on Linux

Document: Getting started with CyberSand desktop
Path: operations/getting-started.md
authority: current-documentation
document-kind: guide
status: Current
scope: First launch from a source checkout or identified evaluator, desktop prerequisites and user navigation
canonical-for: [desktop-first-launch]
last-reviewed: 2026-11-24
Section: Getting started with CyberSand > Source checkout on Linux
Materialize LFS and use the pinned Linux Godot executable. With that executable available as `godot`, from the repository root: ```sh godot --version python3 tools/ci/check_repository.py --require-materialized godot --path godot ``` The version must match the pin above. The provenance checker and [build guide](local-build-and-validation.md) distinguish missing files, stale native inputs and a valid retained runtime. A native library built for another platform is not a substitute. Launching directly is supported, but does not perform all of the Windows wrapper's checks on your behalf. To enter the Workbench directly after prerequisites are satisfied: ```sh godot --path godot -- --workbench ```


### Rank 3: operations/cybersand-codex-development-handover.md — Development handover > Establish source and runtime identity

Document: Development handover
Path: operations/cybersand-codex-development-handover.md
authority: current-documentation
document-kind: guide
status: Current
scope: Current task intake, ownership and handoff; implementation status, intent and qualification have separate canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-11-24
Section: Development handover > Establish source and runtime identity
From the intended source checkout: ```bash git rev-parse --show-toplevel git status --short git branch --show-current git rev-parse HEAD 'HEAD^{tree}' git log -1 --format='%H %cI %s' git lfs ls-files ``` Review remote configuration locally if needed; do not paste credential-bearing URLs into an issue or report. `git lfs ls-files` identifies tracked objects; it does not prove every required object is materialized or that the runtime matches changed native source. Run the appropriate [repository/provenance check](current-and-historical-validation.md) and compare the selected runtime's input ledger before launch or packaging. The pinned executable version is `4.7.stable.official.5b4e0cb0f` in [the Godot lock](../../third_party/godot-runtime.lock.json). A nearby patch release is not the same qualification target. The native locks, per-platform runtime provenance and Rapier provenance are separate records. A documentation-only head can legitimately retain a runtime built at an earlier commit when all recorded source inputs still match; do not relabel its build commit as the documentation head. Conversely, matching a DLL filename does not establish source identity. Use an isolated test profile for application procedures. Do not overwrite owner maps, Art archives, provider settings or ordinary user data to make a test pass. Portable evaluators, source checkouts, rebuilt runtimes and Web/fallback paths have different prerequisites; [getting started](getting-started.md) and [local builds](local-build-and-validation.md) explain them.


### Rank 4: operations/local-build-and-validation.md — Local build and validation > First launch from a source checkout

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > First launch from a source checkout
Use this repository's launcher and retained runtime for a first exploration. A native rebuild is a separate development task. The [player getting-started guide](getting-started.md) walks through opening the Workbench; this page owns the build, identity and validation procedure. From a new checkout with Git and Git LFS installed: ```sh git clone https://github.com/techrote/cybersand.git cd cybersand git lfs install --local git lfs pull git rev-parse HEAD git status --short python3 tools/ci/check_repository.py --require-materialized ``` On Windows, use `python` instead of `python3` when that is the installed command. `git lfs pull` obtains the committed runtime payloads. A small text pointer is not a usable DLL or shared library. `check_repository.py` checks the runtime bytes and recorded source inputs; it also checks documentation and dependencies, so read the actual failure rather than assuming every failure means a broken DLL. **Windows:** install the [exact Godot pin](#which-build-inputs-are-required), then run from this repository root in PowerShell: ```powershell .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe -PrintIdentityOnly .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe ``` The path is an example: use the actual executable location. The launcher also accepts `CYBERSAND_GODOT`, or searches `C:\Godot47`. It validates the pinned Godot version, materialized Windows runtimes and CyberSand DLL hash; it prints the checkout/runtime identity and performs no build or replacement. The default project scene is [Feature Launcher](../../godot/project.godot), which routes to the ordinary **Shared Workbench** and standalone scenes. `-Editor` opens the same project in the editor. `dev.cmd` is not required for a source-only checkout. **Linux x86_64:** with the pinned Godot executable and materialized Linux runtimes, use an explicit executable path: ```sh CYBERSAND_GODOT=/absolute/path/to/Godot_v4.7-stable_linux.x86_64 "$CYBERSAND_GODOT" --version "$CYBERSAND_GODOT" --headless --editor --path godot --import "$CYBERSAND_GODOT" --path godot ``` The version output must match the table below. The last command requires a graphical session. Import and launch are separate steps; successful project import is not proof that native gameplay or every feature ran. A software display is useful for reproducible graphical tests, but does not establish the owner's Windows/NVIDIA playfeel.


### Rank 5: operations/github-development-and-release.md — Repository development and release > Source-matched runtime publication

Document: Repository development and release
Path: operations/github-development-and-release.md
authority: current-documentation
document-kind: guide
status: Current
scope: Contribution boundaries, Draft qualification, source-matched runtime publication and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-11-24
Section: Repository development and release > Source-matched runtime publication
A source-only documentation edit does not require rebuilding unchanged native inputs. A native/binding input change does. Use the applicable guarded publisher and request contract; an old publisher's branch, source SHA or approval does not provide a lease for new work. For native Windows/Linux publication, verify: 1. **Source custody:** the intended exact source, native and build-input hashes, dependency pins, clean/declared deltas and source branch are identified. 2. **Actual builds and execution:** both required target artifacts and the scoped native/Godot/package cases have complete, positive-count, error-free original evidence. Compilation and cross-compilation are labelled separately. 3. **Artifact identity:** library SHA-256/size, provenance input set, build/execution source and committed LFS object agree. Downloaded bytes are actually available; naming a hash alone is not custody. 4. **Publication lease:** the expected branch head still matches the authorized immutable request. Reject competing source pushes or mismatched evidence. 5. **Write boundary:** append only the publisher's allowed runtime/provenance paths, with the required parent and atomic lease. Native publication normally appends the two libraries and two provenance manifests; the actual contract is authoritative for its precise scope. 6. **Resulting-head admission:** recheck source/provenance and every applicable complete gate after publication/integration. Scoped publisher tests do not replace the full implementation or owner acceptance requirements. ```mermaid flowchart TD S["Frozen source and request"] --> I["Verify inputs and dependency pins"] I --> B["Build target runtimes"] B --> E["Execute scoped target tests"] E --> C{"Artifacts and branch lease agree?"} C -->|No| R["Refuse publication; retain evidence"] C -->|Yes| P["Append allowed runtime and provenance paths"] P --> Q["Qualify resulting head and request owner review"] ``` [Architectural Generator publication](../systems/architectural-generator.md#retained-runtime-publication) is one concrete existing contract. The [current/historical gate guide](current-and-historical-validation.md) explains what repository provenance checks can establish. Do not hand-edit hashes, reuse an old source lease, overwrite another programme's branch or weaken a failed required check to complete publication.

## DR03: The native DLL is tiny text beginning version https://git-lfs.github.com/spec/v1. Is this a usable evaluator?

Canonical rank: 2

Expected facts:

- It is an unresolved Git LFS pointer, not executable bytes.
- Materialize the intended committed object and verify its SHA/size/source provenance; a pointer identity check alone does not qualify a launch.

### Rank 1: operations/local-build-and-validation.md — Local build and validation > First launch from a source checkout

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > First launch from a source checkout
Use this repository's launcher and retained runtime for a first exploration. A native rebuild is a separate development task. The [player getting-started guide](getting-started.md) walks through opening the Workbench; this page owns the build, identity and validation procedure. From a new checkout with Git and Git LFS installed: ```sh git clone https://github.com/techrote/cybersand.git cd cybersand git lfs install --local git lfs pull git rev-parse HEAD git status --short python3 tools/ci/check_repository.py --require-materialized ``` On Windows, use `python` instead of `python3` when that is the installed command. `git lfs pull` obtains the committed runtime payloads. A small text pointer is not a usable DLL or shared library. `check_repository.py` checks the runtime bytes and recorded source inputs; it also checks documentation and dependencies, so read the actual failure rather than assuming every failure means a broken DLL. **Windows:** install the [exact Godot pin](#which-build-inputs-are-required), then run from this repository root in PowerShell: ```powershell .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe -PrintIdentityOnly .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe ``` The path is an example: use the actual executable location. The launcher also accepts `CYBERSAND_GODOT`, or searches `C:\Godot47`. It validates the pinned Godot version, materialized Windows runtimes and CyberSand DLL hash; it prints the checkout/runtime identity and performs no build or replacement. The default project scene is [Feature Launcher](../../godot/project.godot), which routes to the ordinary **Shared Workbench** and standalone scenes. `-Editor` opens the same project in the editor. `dev.cmd` is not required for a source-only checkout. **Linux x86_64:** with the pinned Godot executable and materialized Linux runtimes, use an explicit executable path: ```sh CYBERSAND_GODOT=/absolute/path/to/Godot_v4.7-stable_linux.x86_64 "$CYBERSAND_GODOT" --version "$CYBERSAND_GODOT" --headless --editor --path godot --import "$CYBERSAND_GODOT" --path godot ``` The version output must match the table below. The last command requires a graphical session. Import and launch are separate steps; successful project import is not proof that native gameplay or every feature ran. A software display is useful for reproducible graphical tests, but does not establish the owner's Windows/NVIDIA playfeel.


### Rank 2: operations/getting-started.md — Getting started with CyberSand > Source checkout on Windows

Document: Getting started with CyberSand desktop
Path: operations/getting-started.md
authority: current-documentation
document-kind: guide
status: Current
scope: First launch from a source checkout or identified evaluator, desktop prerequisites and user navigation
canonical-for: [desktop-first-launch]
last-reviewed: 2026-11-24
Section: Getting started with CyberSand > Source checkout on Windows
Install Git with Git LFS and obtain **Godot 4.7.stable.official.5b4e0cb0f**, the repository pin. A different 4.x executable is not interchangeable for this workflow. From PowerShell: ```powershell git clone https://github.com/techrote/cybersand.git cd cybersand git lfs install git lfs pull .\launch-desktop.cmd -Godot "C:\Tools\Godot\Godot_v4.7-stable_win64.exe" ``` Replace the Godot path with your installed pinned executable. The repository launcher checks the exact Godot version, required runtime bytes and provenance, prints checkout/runtime identity and starts the project. It does not rebuild libraries. The same launcher supports an identity-only check: ```powershell .\launch-desktop.cmd -Godot "C:\Tools\Godot\Godot_v4.7-stable_win64.exe" -PrintIdentityOnly ``` The default search location is `C:\Godot47`; an explicit `-Godot` path or `CYBERSAND_GODOT` override avoids dependence on a machine-specific installation. Do not copy another branch's DLL over a failed check. Use the [source/runtime build procedure](local-build-and-validation.md).


### Rank 3: architecture/liquid-solver-family-policy.md — Liquid solver family policy and API specification > Cross-issue acceptance mapping

Document: Liquid solver family policy and API specification
Path: architecture/liquid-solver-family-policy.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Current-main four-family identities, immutable per-World per-material policy, material/variant admission and readback, W-CY material block v2 and IN family block v2; historical design checkpoints and source/platform qualification remain separately scoped
canonical-for: [liquid-solver-family-policy]
last-reviewed: 2026-11-24
Section: Liquid solver family policy and API specification > Cross-issue acceptance mapping
| Owner | Takes from this spec | Must not claim | |---|---|---| | LCB-001 [#200](https://github.com/techrote/cybersand/issues/200) | `LiquidSolverPolicy` type, packing, validation/refusal codes, readback on every constructor, transaction, default-equals-Current proof, `pressure_flow_v1` state and boundary rule, versioned physical-state hash | inertial support; 72/80-bit carrier | | LCB-002 [#201](https://github.com/techrote/cybersand/issues/201) | `cached`/`cached_dormant` variant equivalence; cross-family invalidation and wake | that variants are families | | LCB-003 [#202](https://github.com/techrote/cybersand/issues/202) | per-material picker driven by the matrix, receipts in UI, reconstruct-to-apply ([UX flow](../operations/lcb-manual-comparison-ux.md)) | support the receipt does not report | | LCB-005 [#212](https://github.com/techrote/cybersand/issues/212) | `inertial_cellular_v1` state, Brine (or Toxic Sludge) qualification, inertial boundary rules | Oil/kernel-specialized inertial support | | LCB-004 [#203](https://github.com/techrote/cybersand/issues/203) | the matrix as coverage oracle; receipts in packaged builds | default changes | | MAT-003PREPASS [#204](https://github.com/techrote/cybersand/issues/204) (Gate B) | the per-family field list above | n/a — owns width/sidecar/save |


### Rank 4: operations/local-build-and-validation.md — Local build and validation > Actor control prototype checks > Shared Play session and owner qualification

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Actor control prototype checks > Shared Play session and owner qualification
The [executable manual packet](play-desktop-manual-qualification.md) prepares a source/runtime-pinned checklist and initially untested result sheet. Its generator performs no engine or physical execution and cannot grant acceptance. Use the exact candidate checkout named by its PR, Godot `4.7.stable.official.5b4e0cb0f` and the repository-pinned native/Rapier LFS bytes. Record `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git status --short`, Godot version, OS/GPU/CPU and physical controller model/mapping. Materialize LFS and run the current provenance gate before interpreting gameplay evidence: ```text git lfs pull git lfs fsck python3 tools/ci/check_repository.py --require-materialized godot --headless --path godot --editor --quit godot --path godot ``` Select **Play session** at the launcher. Choose the Player Playground map, one of the five mechanical rigs, controls, lap/free-play, solver policy and starting camera. Click **Build selected session**, wait for the actual applied actor/policy, release movement controls and click **Play / resume**. P pauses, R restarts the applied session, F changes camera and F2 returns to the launcher. The in-host **Play session** button reopens selection. Build changes configuration; Restart ignores unsubmitted choices and retains the accepted configuration. Execute the existing [concrete #270 checklist](https://github.com/techrote/cybersand/issues/270#issuecomment-6485284121) on the physical target machine: each rig's natural movement/camera/lap, pause and focus loss/regain, held-control neutral rearm, supported policy rebuild/refusal, physical stick/A/B/X/shoulder behavior, keyboard/controller handover, selected controller unplug/replug, repeated reset/exit and actual responsiveness/feel. Also try keyboard-only and free-play selections and record requested/applied receipts. Record each item as pass, fail or not tested with exact source/runtime identity and representative tick/frame/snapshot/wait measurements. A successful headless run or software-rendered layout inspection does not execute this gate. The focused automated command is: ```text godot --headless --path godot --script res://tests/test_play_ui005_session_selection.gd ``` This test runs actual Main/native worker/Rapier reconstruction for all five rigs, with synthetic OS focus and connected-device enumeration. It is automatically discovered by ordinary Windows/Linux Godot CI; no dedicated workflow is needed. Its [audit](../audits/2026-10-30-play-ui005-integrated-session.md) keeps local, hosted, rendered-layout and unexecuted physical/human evidence separate. On restricted Linux environments, set writable XDG config/data/cache directories before importing or running; preserve any earlier failed invocation.


### Rank 5: reference/status-and-roadmap.md — Status and foundational roadmap > Active candidates and integration boundaries

Document: Status and foundational roadmap
Path: reference/status-and-roadmap.md
authority: current-documentation
document-kind: reference
status: Current
scope: Accepted-main implementation, separately identified candidates, approved direction and unresolved decisions
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-11-24
Section: Status and foundational roadmap > Active candidates and integration boundaries
**All entries below were unmerged at the snapshot.** The linked principal records own current source, blockers, evaluator availability and exact qualification. This register deliberately does not duplicate their changing job lists or PR heads. | Programme | Principal record | Boundary for accepted-main documentation | |---|---|---| | PUBPRES physical progression and presentation | [#717](https://github.com/techrote/cybersand/issues/717), current finisher [#767](https://github.com/techrote/cybersand/pull/767), predecessor [#757](https://github.com/techrote/cybersand/pull/757) | Do not claim publication stalls or physical freezes are resolved by accepted main. | | ObjectShard moving destructible materials | [#754](https://github.com/techrote/cybersand/pull/754) | Moving native chemistry, mutable body ownership and ordinary Workbench integration are candidate behavior. | | Actor Compose continuous play and pilot recovery | [#762](https://github.com/techrote/cybersand/pull/762) | Preserve accepted #683 controls and disclose successor repair scope. | | Equipment recovery | [#724](https://github.com/techrote/cybersand/pull/724) | Historical #561 merge does not prove every later ballistic-solid/equipment path is present or correct. | | Persistent authored areas / RAMCACHE | [#745](https://github.com/techrote/cybersand/pull/745), [#734](https://github.com/techrote/cybersand/pull/734) | Persistent-area loading, native hot residency, durability and catch-up are not accepted-main save guarantees. | | Consolidated Gentek SWARM-004/005/006 | [#729](https://github.com/techrote/cybersand/pull/729) | Accepted Gentek generation does not imply accepted reciprocal negotiation/recovery. | | Gentek Windows owner evaluator | [#758](https://github.com/techrote/cybersand/pull/758) | GitHub reported this PR open and non-draft despite its HOLD title. Evaluator work and physical acceptance remain separate from the accepted catalogue. | | Art responsiveness, roster and conversation editor | [#744](https://github.com/techrote/cybersand/issues/744), [#765](https://github.com/techrote/cybersand/pull/765), [#766](https://github.com/techrote/cybersand/pull/766), [#756](https://github.com/techrote/cybersand/pull/756), [#763](https://github.com/techrote/cybersand/pull/763) | Do not promise repaired close/HTTP timing, updated provider presets or bounded editor layout before acceptance. | | WORLD-STEER / Batch Lab | [#770](https://github.com/techrote/cybersand/pull/770), predecessor [#720](https://github.com/techrote/cybersand/pull/720), [#579](https://github.com/techrote/cybersand/issues/579) | Native module harvesting, architectural knowledge retrieval and staged construction remain candidate work. | | Gremlin live testing | Prototype [#749](https://github.com/techrote/cybersand/pull/749) | A deterministic Python contract model is not proof of a real native/Godot playtesting backend. Follow the live successor record when published. | | Materials Lab current-scene audition | [#768](https://github.com/techrote/cybersand/pull/768) | Approved live-audition intent is not satisfied by advertising the existing isolated Lab as that feature. | | Workbench Strata Theatre | [#769](https://github.com/techrote/cybersand/pull/769), owner intent [#588](https://github.com/techrote/cybersand/issues/588) | Four-plane painting/composition in ordinary Workbench remains distinct from the available standalone exhibition. | | PAINT latency and physical evaluator | [#703](https://github.com/techrote/cybersand/pull/703), [#711](https://github.com/techrote/cybersand/pull/711) | Native fill speed and usable end-to-end responsiveness are separate measurements. | | CI engineering and publication closure | [#706](https://github.com/techrote/cybersand/issues/706), [#761](https://github.com/techrote/cybersand/issues/761) | Candidate fan-out, RAM-disk and publisher experiments do not replace accepted CI policy. |

## DR04: What is a small source-checkout validation before I launch expensive native and Godot matrices?

Canonical rank: 2

Expected facts:

- Use structural documentation/repository checks and relevant focused tests; the C header syntax check is a bounded native interface probe.
- Passing cheap checks does not establish native runtime or physical acceptance; do not claim an unexecuted full matrix.

### Rank 1: operations/getting-started.md — Getting started with CyberSand > Choose your installation route

Document: Getting started with CyberSand desktop
Path: operations/getting-started.md
authority: current-documentation
document-kind: guide
status: Current
scope: First launch from a source checkout or identified evaluator, desktop prerequisites and user navigation
canonical-for: [desktop-first-launch]
last-reviewed: 2026-11-24
Section: Getting started with CyberSand > Choose your installation route
| What you have | What to do | | --- | --- | | A complete source checkout | Materialize Git LFS, use the exact pinned Godot executable and verify the retained runtime. Follow the commands below. | | A source-identified Windows evaluator | Extract the entire archive to a writable folder and use its supplied launcher, commonly **Open Workbench.cmd**. Keep its project, dependencies, licenses and manifests together. | | Only source files or an incomplete ZIP | Obtain the missing runtime/dependencies or follow the [build guide](local-build-and-validation.md). A small Git LFS pointer is not a native library. | An evaluator has its own source/runtime identity and scope. It may contain an unmerged candidate. Read its manifest and accompanying evaluation record before assuming it behaves like accepted main. This guide does not establish that any particular old Actions artifact is still downloadable.


### Rank 2: operations/local-build-and-validation.md — Local build and validation > First launch from a source checkout

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > First launch from a source checkout
Use this repository's launcher and retained runtime for a first exploration. A native rebuild is a separate development task. The [player getting-started guide](getting-started.md) walks through opening the Workbench; this page owns the build, identity and validation procedure. From a new checkout with Git and Git LFS installed: ```sh git clone https://github.com/techrote/cybersand.git cd cybersand git lfs install --local git lfs pull git rev-parse HEAD git status --short python3 tools/ci/check_repository.py --require-materialized ``` On Windows, use `python` instead of `python3` when that is the installed command. `git lfs pull` obtains the committed runtime payloads. A small text pointer is not a usable DLL or shared library. `check_repository.py` checks the runtime bytes and recorded source inputs; it also checks documentation and dependencies, so read the actual failure rather than assuming every failure means a broken DLL. **Windows:** install the [exact Godot pin](#which-build-inputs-are-required), then run from this repository root in PowerShell: ```powershell .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe -PrintIdentityOnly .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe ``` The path is an example: use the actual executable location. The launcher also accepts `CYBERSAND_GODOT`, or searches `C:\Godot47`. It validates the pinned Godot version, materialized Windows runtimes and CyberSand DLL hash; it prints the checkout/runtime identity and performs no build or replacement. The default project scene is [Feature Launcher](../../godot/project.godot), which routes to the ordinary **Shared Workbench** and standalone scenes. `-Editor` opens the same project in the editor. `dev.cmd` is not required for a source-only checkout. **Linux x86_64:** with the pinned Godot executable and materialized Linux runtimes, use an explicit executable path: ```sh CYBERSAND_GODOT=/absolute/path/to/Godot_v4.7-stable_linux.x86_64 "$CYBERSAND_GODOT" --version "$CYBERSAND_GODOT" --headless --editor --path godot --import "$CYBERSAND_GODOT" --path godot ``` The version output must match the table below. The last command requires a graphical session. Import and launch are separate steps; successful project import is not proof that native gameplay or every feature ran. A software display is useful for reproducible graphical tests, but does not establish the owner's Windows/NVIDIA playfeel.


### Rank 3: operations/local-build-and-validation.md — Local build and validation > Isolated test data and diagnostics

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Isolated test data and diagnostics
Godot tests and graphical captures must not overwrite the owner's saved scenes, Art traffic or local provider configuration. Use the repository's [isolated Godot runner](../../tools/physics/isolated_godot.py) or the appropriate existing test/capture harness with its own user profile. Inspect that harness's arguments and refusal rules before invoking it; a normal interactive launch intentionally uses the user's ordinary application data. For a useful failure report, record the checkout SHA and dirty state, exact Godot version, native runtime/provenance identity, platform, command, fixture or small synthetic setup, steps, expected result, actual result and whether the operation was queued, applied, displayed or refused. Include the first relevant error and completion status, not only a green process exit. Preserve the original failed result alongside a successful retry. Art prompts, traffic, endpoint credentials and owner maps may be private: inspect and redact attachments, and prefer a synthetic reproduction. [Troubleshooting](troubleshooting.md) covers common launch, focus, runtime and capacity failures.


### Rank 4: operations/local-build-and-validation.md — Local build and validation > Windows development commands > Repository-contained Windows desktop launcher

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Windows development commands > Repository-contained Windows desktop launcher
**Current:** a source checkout can launch the retained desktop test project without the companion-workspace `dev.cmd`: ```powershell .\launch-desktop.cmd .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe .\launch-desktop.cmd -PrintIdentityOnly .\launch-desktop.cmd -Editor ``` The wrapper invokes [`tools/launch_desktop.ps1`](../../tools/launch_desktop.ps1). It accepts an explicit `-Godot` path or `CYBERSAND_GODOT`; otherwise it searches the established `C:\Godot47` location. It requires exactly `4.7.stable.official.5b4e0cb0f`, verifies that the project, retained CyberSand Windows DLL/provenance file and Rapier Windows DLL are present, verifies the CyberSand DLL SHA-256 against `runtime-provenance.json`, and prints checkout, Godot and runtime identities before launch. The default action runs `godot/project.godot` through its configured `feature_launcher.tscn`; `-Editor` opens the same project in the editor. The launcher deliberately contains **no build step**. A missing, hash-mismatched or wrong-version runtime is an explicit failure; it never rebuilds, replaces or silently refreshes the retained DLL. M11 output byte equality now requires `CYBERSAND_VERIFY_M11_OUTPUT=1`; current builds keep compiler/source pin checks and identify their own tested outputs. See [validation policies](current-and-historical-validation.md). The existing local `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` override bypasses some compiler/dirty-source checks. It still requires the exact godot-cpp revision. Inspect that checkout explicitly; a local validation build with this override is not bit-identical M11 reproduction.


### Rank 5: operations/material-catalogue-shadow.md — Material catalogue shadow compiler and compatibility guards > Validation, errors and deterministic publication

Document: Material catalogue shadow compiler and compatibility guards
Path: operations/material-catalogue-shadow.md
authority: current-documentation
document-kind: guide
status: Current
scope: Merged MAT-AUTH-001 353-A shadow tooling and source guards; legacy production authority persists, with consumer migration and production liveness corrections separately gated
canonical-for: [material-catalogue-shadow-compiler, material-catalogue-compatibility-guards, material-catalogue-authoring-workflow]
last-reviewed: 2026-11-11
Section: Material catalogue shadow compiler and compatibility guards > Validation, errors and deterministic publication
The compiler rejects unknown fields, duplicate JSON keys, unsupported versions, non-finite values, booleans in integer fields, out-of-range values, invalid references, alias/key conflicts, duplicate legacy slots and ambiguous pair ownership. Errors include the source file and JSON pointer; conflicts identify both origins, and JSON syntax errors also report line/column. Unsupported defaults, state contracts or active interaction layers are rejected instead of interpreted through implicit precedence. Valid inert `RuleKernel::None` targets remain admissible: a reaction participant need not own the tick that initiates its reaction. The compiler does not change wake state, endpoint effects, solver selection or parameter consumption. Output is UTF-8 with LF and a final newline, deterministic escaping and stable ordering. No timestamp, local absolute path or directory order enters generated content. `--check` is nonwriting; missing or stale output fails with a named artifact. Validation completes before publication, and unchanged files retain their bytes and modification times. Negative tests require failure to preserve the previously accepted output set. Run from a complete source checkout: ```text python3 tools/material_catalogue/compatibility.py --check python3 tools/material_catalogue/compiler.py --check python3 -m unittest discover -s tools/material_catalogue -p 'test_*.py' python3 tools/material_catalogue/check_native_parity.py ``` The native query check and the focused generated-C++ regression require a C++20 compiler; JSON generation and strict validation use Python's standard library. CI reuses the existing hosted Documentation workflow and execution watchdog. These focused commands do not run World scenarios or require a Godot download; expensive draft lanes stay suppressed. Under the existing ready-state path classifiers, this tools/data implementation also triggers the full Native and Windows/Linux GDExtension/Godot gates when #371 becomes ready. Those configured integration checks remain required; a draft skip or metadata readback is not a substitute. Freeze and independently review the candidate before that transition to avoid redundant matrices. Record actual jobs and any skips in the PR ledger. For optional actual Godot metadata readback, use a complete editor archive and executable matching `third_party/godot-runtime.lock.json`. Produce a native snapshot and receipt from the same source, then invoke the checker: ```text mkdir -p build/material-catalogue c++ -std=c++20 -O2 -I native/include tools/material_catalogue/native_oracle.cpp native/src/material_rules.cpp -o build/material-catalogue/oracle build/material-catalogue/oracle --snapshot > build/material-catalogue/native-snapshot.json python3 tools/material_catalogue/check_native_parity.py --output build/material-catalogue/native-parity.json python3 tools/material_catalogue/check_gdscript_shadow.py --godot /path/to/pinned-editor --archive /path/to/pinned-editor.zip --native-snapshot build/material-catalogue/native-snapshot.json --native-report build/material-catalogue/native-parity.json --output build/material-catalogue/gdscript-parity.json ``` The helper does not download or modify the editor. Its temporary project loads only the generated metadata. The native receipt's snapshot hash must match, and its complete source/mirror inventory must still be current. This optional engine parser proof is separate from the default documentation CI gate.

## DR05: Can native pool workers touch scene-tree objects and Rapier bodies?

Canonical rank: 1

Expected facts:

- Native C++ owns authoritative cellular state and internal pool workers call no Godot APIs.
- The exclusive desktop simulation owner may use its adapter/value APIs; live scene tree and Rapier ownership remain on the allowed main thread.

### Rank 1: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Who may mutate each resource?

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-24
Section: Data ownership and lifetimes > Who may mutate each resource?
**Current:** each selected cellular world has one external owner. In the ordinary desktop sandbox that is `CyberSimulationWorker`; on Web it is the main-thread controller. Native World coordinates its internal jobs. Queries, export, publication and mutation require serialization by that owner; calling a method through GDExtension does not make World generally thread-safe. Native pool workers call no Godot APIs. The desktop Godot owner may call exclusive adapter/value APIs, but must not touch live scene-tree or Rapier objects. | Resource | Owner and permitted mutation | Lifetime and pressure | |---|---|---| | `World::chunks_` and chunk cell arrays | World coordinator creates/reserves chunks; serial work or phase-exclusive jobs mutate cells | Until World/chunk destruction; construction capacity bounds growth | | Optional temperatures | Chunk owns optional SoA; owner prepares it, permitted rules/movement use it | Allocated on demand or reservation; counted tick allocations | | Activity/dirty metadata and job effects | Job-local observations, then coordinator merge after the phase barrier | Persistent chunk metadata and reusable bounded scratch; dirty bounds survive unsuccessful publication | | Delayed pair deadline | Workers report through fixed disjoint job spans into two preallocated `ParallelState` flag/deadline buffers; the coordinator reduces the earliest deadline into shared block metadata after the phase barrier and wakes it at healthy tick entry | One persistent scalar per block plus bounded scheduler scratch; buffers outlive job spans and pool, excluded blocks retain deadlines, clear/replacement discards them | | Native snapshot slots | One serialized producer writes only an unleased slot | Shared exchange state outlives its facade while leases exist; no-slot/capacity failure retains dirty state | | Desktop world, sampled character and optional actor prototypes | Godot pacing Thread after startup handoff | Worker lifetime; stopped/joined before destruction; actor session reset invalidates old input epochs | | Controlled liquid preparation candidate and token (experimental #202 source) | The exclusive native adapter owns one pending World, render exchange, final setup and copied native receipt | Final configuration precedes capture; one-use token commit checks retained state and the desktop queue-mutex request/reset/stop fence. Discard/supersession/refusal retain the applied session; [sampled owners](liquid-prepared-setup-and-receipts.md#staged-sampled-actors-and-exploratory-owners) and [desktop articulated physical owners](liquid-prepared-setup-and-receipts.md#staged-articulated-physical-owners) prepare before commit. Physical graph/space stays main-owned, frozen and permanent; copied readiness and actual initial masks bind its nonblocking continuation. Other constructors and full evidence stay open | | Live body nodes, RIDs and physics state | Main-thread Rapier bridge and PhysicsServer2D | Scene/bridge lifetime; never passed to cellular workers | | Physical actor rigs, joints and local controllers | Main-thread `CyberPhysicalActorSession`; at most eight rigs/eight total parts each | Run/actor/epoch-bound


### Rank 2: architecture/overview.md — Architecture overview > Who owns each kind of truth?

Document: Architecture overview
Path: architecture/overview.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current execution paths and authority map; routes to the contracts that govern changes
canonical-for: [architecture-entry-point]
last-reviewed: 2026-11-24
Section: Architecture overview > Who owns each kind of truth?
| State | Current owner | What crosses the boundary | |---|---|---| | Cells, compact material state, temperature, activity and liquid accounting | Native World | Copied observations, stored-material captures and render publications | | Body poses, joints, velocity and contacts | Main-thread physical session and Rapier through Godot | Value-only body samples and bounded cellular responses | | Authored start, ordered edits and history | Workbench authoring controller, coordinated with the exclusive native worker | Validated requests, completion receipts and durable authored data | | Actor control authority | Main-thread physical session | Issued observations and bounded action leases, retired on handoff/reset | | Provider conversation and proposed drawing | Art controller/provider adapter | Proposed bounded commands; native completion is still required | | Images, textures, camera and UI | Godot main thread | Immutable copied RG8 material/condition data | The fallback, where selected, owns its own alternate cell arrays; it is never synchronized as a second authoritative copy of a native World. Rapier is the current rigid-body backend behind engine-owned adapters. Native pool workers call neither Godot nor Rapier. The GDScript pacing thread may call the adapter it exclusively owns, but it may not access live scene-tree or Rapier objects. ```mermaid flowchart TD UI["Godot main: input and Workbench"] -->|"copied requests"| Owner["Exclusive cellular owner"] Owner --> World["Native World"] World --> Pool["Native job pool"] Pool -->|"joined phase results"| World World -->|"copied snapshots and receipts"| Owner Owner -->|"immutable publication"| UI Physics["Main-thread Rapier session"] -->|"copied body samples"| Owner Owner -->|"bounded body responses"| Physics ``` The diagram shows ownership and message direction, not concurrent permission to call World. Exact leases, prepared replacements and failure windows belong to [data ownership](data-ownership-and-lifetimes.md).


### Rank 3: operations/cybersand-codex-development-handover.md — Development handover > Foundational work boundary

Document: Development handover
Path: operations/cybersand-codex-development-handover.md
authority: current-documentation
document-kind: guide
status: Current
scope: Current task intake, ownership and handoff; implementation status, intent and qualification have separate canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-11-24
Section: Development handover > Foundational work boundary
Native C++ owns authoritative cells. Desktop uses an asynchronous GDScript owner; Web completes native ticks synchronously on the main thread with its supported internal native pool. Rapier scene objects stay main-thread owned. Native pool workers call no Godot APIs. Immutable snapshots retain ownership until consumption ends; rendering does not read mutable World storage. See [ownership](../architecture/data-ownership-and-lifetimes.md). Failed ticks quarantine a partially mutated World until explicit reset or validated replacement; no automatic retry or rollback is implied. Interest-region re-entry wakes paused resident work within the accepted contract; it is not persistent-area time catch-up. Preserve bounded work, explicit capacity outcomes and current/proposed distinctions in [invariants](../reference/invariants.md). Source-defined controls, exact native fixtures, graphical rendering, packaged startup and physical owner acceptance are different claims. A progress counter, render FPS or a compile pass does not establish playable physics. The existing recording tools also do not supply a general serialized coupled replay format.


### Rank 4: architecture/principles-and-non-goals.md — Architectural principles and non-goals > Which constraints govern foundational work?

Document: Architectural principles and non-goals
Path: architecture/principles-and-non-goals.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Accepted architectural constraints, explicit current exceptions, deferred scope and rejected approaches
canonical-for: [architectural-constraints-and-rejected-shortcuts]
last-reviewed: 2026-09-08
Section: Architectural principles and non-goals > Which constraints govern foundational work?
**Approved:** native C++ remains production cellular authority; Godot owns presentation, input and adapters; the rigid-body backend remains replaceable. The core must run without Godot. Fixed simulation quanta, explicit owners, bounded work/capacity and traceable evidence take priority over incidental prototype structure. [ADR-001](../decisions/ADR-001-native-simulation-core.md) and [module boundaries](module-boundaries.md) explain the authority decision. No native pool worker may call Godot APIs. The desktop Godot pacing Thread may call its exclusively owned adapter/value methods, but may not access live scene-tree/Rapier objects. Rendering consumes immutable snapshots and never locks or borrows mutable cellular state. Resource enforcement belongs in [ownership](data-ownership-and-lifetimes.md), not an assumed universal thread-safety property of GDExtension. Worker timing must not decide mutation ownership or conflict order. Exact native fixture comparison is **Current** for declared inputs; complete replay and a selectable strict runtime policy remain **Planned**. A passing cellular hash does not establish Rapier trajectory equivalence or save continuation. See [hash coverage](determinism-and-boundary-transfers.md) and [level saves](../reference/level-saves-and-replay.md).


### Rank 5: architecture/wave-flow-v1.md — Wave flow Water solver (experimental) > Controls

Document: Wave flow Water solver (experimental)
Path: architecture/wave-flow-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current Wave Flow law, player defaults, bulk strip-parallel execution, admission, state and memory
canonical-for: [wave-flow-v1]
last-reviewed: 2026-11-20
Section: Wave flow Water solver (experimental) > Controls
| Setting | Default | Meaning | |---|---|---| | `WorldConfig::wave_flow.enabled` | `false` | Opt in at construction | | `WorldConfig::wave_flow.substeps` | `1` | Rounds per tick, 1–8 | The ordinary feature launcher has **Wave Flow**. The equivalent direct route is `-- --wave-flow` or `res://wave_flow_evaluation.tscn`; the Windows evaluation ZIP provides `Test It.cmd`. The [evaluation guide](../operations/wave-flow-evaluation.md) owns the launch and scene walkthrough. The evaluator constructs a fresh native World when **Reset scene** applies Wave/FreeMass/Inertial/PressureFlow selection, workers, substeps and world size. It exposes ten scenes, 256/512/1024/2048 sizes, 1–32 workers, 1–8 Wave substeps, native pacing 1–120 Hz and Rapier pacing 30–120 Hz. **Run/Pause**, **Single tick** and **Disturb pool** control the scenario. Native tick timing is reported separately from presentation rate. `get_wave_flow_status` returns copied selection, actual participants, timing, tasks, solved chunks, allocated storage and quantity; `inspect_wave_flow_cell` copies stored/visible uint16 mass and retained face flux. A replacement creates the Water law selected by its destination session. Moving-body and Needle scenes own actual Rapier objects on Godot's main thread; only their bounded transient masks/contact values cross into native simulation. Needle retains its existing authored weight and thrust; **W/A/D/S** provide thrust/turn/reverse. The evaluator uses native material publication, with no cosmetic animation standing in for the solver. Source: [`wave_flow.hpp`](../../native/include/cybersand/wave_flow.hpp), [`world_wave.inc`](../../native/src/world_wave.inc); hooks in [`world.cpp`](../../native/src/world.cpp) (`begin_tick`, `ensure_chunk`, `rule_is_active`, `mark_cell_dirty`, `merge_job_effects`, body-mask edits). Regressions: [`test_wave_flow.cpp`](../../native/tests/test_wave_flow.cpp) (`make wave-flow-test`, `wave-flow-sanitize`, `wave-flow-thread-sanitize`).

## DR06: The old rule says every Cell is four bytes and all richer material state must be a sidecar. Is that current doctrine?

Canonical rank: 1

Expected facts:

- Distinguish the historical compact cell experiment from accepted eight-byte PrecisionStorage.
- Current source and approved intent do not imply a permanent four-byte or sidecar-only prohibition.

### Rank 1: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Save, Flatten and compatibility

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Save, Flatten and compatibility
**Confirmed:** saving should preserve the desired evolved material layout without unexpectedly destroying the session's Undo history. Oil painted in mid-air and allowed to settle should restart in its saved location. Acid used to damage a wall, followed by water and fire cleanup, should not reappear merely because the original construction strokes were replayed. **Confirmed:** explicit Flatten is a material-occupancy snapshot using two bytes per cell, allowing burdensome or blocking construction history to be discarded. It is not a full physical checkpoint. Normal map saves need not always flatten; richer authoring data can remain useful. Neither this clarification nor the word “save” requires persisting the entire session's Undo stack. **Confirmed:** do not promise advanced cross-version compatibility of all old maps. Flatten may provide a fallback that recovers useful material layout in newer versions. Material identity mapping and container/version handling remain engineering details. This is not a guarantee that every old simulation state or every future material ID remains interpretable. Flatten is also distinct from merging the visual/semantic layers of Strata.


### Rank 2: operations/cell-layout-experiment.md — Cell layout experiment > L4 concrete preregistration, September11

Document: Cell layout experiment registration and execution
Path: operations/cell-layout-experiment.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Issue 16 staged native representation research, preregistered before candidate code; no production migration
canonical-for: [cell-layout-experiment]
last-reviewed: 2026-09-11
Section: Cell layout experiment > L4 concrete preregistration, September11
New standalone modules `native/bench/cell_sidecar.cpp` and `tools/experiments/cell_sidecar.py` will compare a neutral uint32 tag, zero absent, with all32 nonzero bits preserved. This is a synthetic transaction carrier, not World physics or a solver-speed prediction. Existing World correctness evidence is retained, not relabelled as a fresh L4 run. No adapter/render change is admitted. Sixteen128-square chunks hold262144 legacy slots on a512-square grid. Legacy material/state_a/state_b/epoch remain byte4 with alignment4 and epoch0, plus a separate i16 temperature array. Inline control adds tag32 (stride8, alignment4). SoA uses optional u32[16384]. Sparse uses optional u16[16384] indices (65535 absent) and bounded8-byte slots containing value32/owner16/next-free16. Slot handles never escape their owner. Include descriptor/vector/free-head bytes and actual capacities, process working/private/peak memory and measurement buffers; allocator/PMC gaps remain explicit. All carriers enforce the same per-chunk logical capacity: min(16384,initial present+64), or0 for unprepared chunks. No measured growth. Density0/1/5/15/50/100% means floor(262144*density/100) tags. Clustered uses the first slots in chunk-major order; dispersed uses the bijection (rank*65537+131*seed) mod262144. Report per-chunk occupancy and allocated chunk count. Absent mode uses density0/unprepared arrays. Allocated-unread scans only legacy bytes; density0 in this mode deliberately prepares every chunk with cap64. Accessed mode performs transactions and reads absence at density0. Initial legacy states cycle current Water mass1..255/delay0..12, Sand17/23 and Fire48/0; temperature200..216. These are state carriers; synthetic reaction sources/sinks are not chemistry predictions. Eight pairs of horizontally adjacent chunks are exclusive worker domains. Each accessed batch attempts64 operations per pair, cycling move/swap/Water split/ Water merge/reaction clear/reaction create/reclaim/read. Deterministic adjacent endpoints include chunk seams; writes stay distance1 within their pair. Moves and swaps transfer legacy, temperature and tag; split explicitly clones a tag, merge prefers the destination tag and accounts drops. Reactions/reclaim have explicit Water and tag source/sink ledgers. Creation tags follow the initial density mask. Preflight post-operation counts before mutation, erase both endpoints then assign replacements. Unprepared/full destination refusal preserves both records. No global free list, worker allocation, per-cell lock, external mutable view or rollback claim. Unread/absent batches perform8192 legacy reads over a cycling resident cursor; payload validation occurs after timing. Accessed batches attempt512 transactions. One/four workers execute identical pair streams, with three persistent child threads plus the caller and two barriers per batch. Report dispatch overhead rather than tuning batch size. All buffers are prepared first, followed by100 empty pool barrier cycles. Benchmark-only C++ new counters screen allocations during batches; this does not observe arbitrary malloc/OS allocations. Exceptions must join safely. Correctness:1800 batches, five existing seeds/translations,1/4 workers,two repeats, all12 accessed density/pattern cases and three carriers:720 processes. A flat reference is independently initialized from declared inputs, compares outcomes and touched endpoints every operation, and


### Rank 3: operations/architecture-programme.md — CyberSand architecture experimental programme > D. Candidate matrix and controlled variables

Document: CyberSand architecture synthesis and experimental programme
Path: operations/architecture-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Evidence gates for Cell representation, liquid state and transport, presentation, and conditional sparse motion; no production architecture selection
canonical-for: [architecture-experimental-programme]
last-reviewed: 2026-10-24
Section: CyberSand architecture experimental programme > D. Candidate matrix and controlled variables
| Question | Baseline / candidates | Change versus fixed controls | Required measurement | |---|---|---|---| | Raw Cell width | Current 4 B; 8 B with four original bytes and four unused bytes | Change stride only. Same semantics, epoch width, geometry, traversal, input, descriptors and compact snapshots. Verify compiler actually emits an 8-byte stride. | Equal content/events/work; tick distribution, ns/visited cell, memory/traffic, worker scaling. | | Packed access | Packed 8/16/8 control; 16/40/8 with only legacy state used; padded 8 B control | Access arrangement/ID extraction; fixed semantic values, epoch and unused capacity. | Masks/read-modify-write cost, size/alignment, no truncation, generated access path, normalized semantic equality. | | Short epoch | Packed 8/16/8 versus 8/18/6, extra two state bits unused | Epoch width/clear period only after access cost is known. | Per-clear duration and exact ticks, p99/max, double-update prevention over wraps/sleep/re-entry. | | Optional state allocation | 4 B plus chunk/block SoA or bounded sparse indexed sidecar versus 8 B inline | First legacy-equivalent storage/access; later identical M semantics and state precision. Same populated positions, lifetimes and work policy. | Zero/1/5/15/50/100% use, clustered versus dispersed use, lookup/move/reclaim cost, total bytes incl metadata and saturated capacity. | | Material ID headroom | Current 8-bit IDs; 10-bit 10/14/8 alternative; 16-bit candidate | Access cost separated from catalogue expansion. 10/14/8 cannot be a full legacy control unless every material's state is losslessly representable. | Actual catalogue/ID needs and adapter/render/profile/save migration surface. No new material pack loader. | | Water mass | 8-bit reference; 4/6/10; 3/12 optional only to locate an observed failure boundary | Fixed tested layout, three-quarter local solver, mass-normalized thresholds, no history. Auxiliary delay remains 12 ticks. | Initial quantization ledger, exact integer mass per precision, normalized levelness/front/rest/film, work and timing. | | Auxiliary precision | Original 8-bit Water delay versus 4-bit representation | Only packing; same 0..12 countdown, max-on-merge, pre-decrement suppression. Other materials retain their own full state range. | Exact behavioral equality and bit access cost. Combined budgets only after isolated results. | | Yield versus sleeping | Actual Water and representative yield liquids; default quiet threshold 3 versus threshold exceeding fixture horizon | Change sleep diagnostic only; same liquid, viscosity, scene and input. Zero is invalid, not a sleep-disable option. | Late mobility failures, eligible attempts, active-block time, residual slope and wake response. | | Flow memory | No history versus small direction/strength/age; inline versus sidecar | First fixed mass precision, solver and layout; next same memory semantics across storage. No new pressure/velocity solver. | Jet COM/range/asymmetry,


### Rank 4: operations/procedural-qualification.md — Procedural Deepworks qualification and visual review > How is deliberate composition kept procedural?

Document: Procedural Deepworks qualification and visual review
Path: operations/procedural-qualification.md
authority: current-documentation
document-kind: guide
status: Current
scope: GEN-007 compact 1024-square recipe, reusable architecture, final-material routes, native exhibit mechanisms and actual rendered qualification
canonical-for: [procedural-qualification-scene, procedural-quality-evidence]
last-reviewed: 2026-10-21
Section: Procedural Deepworks qualification and visual review > How is deliberate composition kept procedural?
Author the major district silhouettes and routes first, then reuse gallery, cabinet and apparatus rules inside those places. Named features and stable IDs make the composition inspectable. Candidate layouts and seeded details supply variation while structural material roles and passage clearance remain explicit. Keep the reference seed and all variant seeds declared in the fixture. Material choices follow the [MAT-002 catalogue](../systems/building-material-catalogue.md): stable structural walls and containment, local metal/glass/service accents, bounded reactive contents and thematic background treatment. A random palette swap does not establish coherent regional identity. Empty air, sightlines and rear windows are intentional composition choices; four-plane treatment does not mean every cell must be nonempty. The recipe report must retain its UTF-8 byte size, reusable rule/template counts, expanded feature counts and manually fixed placements. Authored region bounds, routes and shared apparatus proportions are legitimate declarative design; listing every output material cell is not. Inspect the hierarchy/plane rules in the workbench to determine which choices are fixed and which depend on seed. The current recipe is **61,845 UTF-8 bytes**, with 26 grammar rules and 124 plane templates: 111 projection, eight finite-feed and five link templates. Native expansion produces 161 semantic features and 336 projections. Its [builder](../../tools/worldgen/build_gen007_recipe.py) writes only declarative JSON; the native generator performs feature expansion, seeded candidate selection, route construction and final material rasterization. The [qualification manifest](../../examples/worldgen/gen007-qualification.json) retains the counts and authoring ledger. The manually fixed design consists of four district anchors, two shared gallery definitions, one reused optional-loop definition and four exhibit definitions. The source contains 43 candidate boxes, 83 relative projection rectangles and eight relative fixture rectangles. Native expansion reuses this feature geometry. The baseline has no final hard material overrides. The native route-distance preference selects two of four candidate cabinet sites in each gallery; all four declared seeds produce different actual cabinet layouts and different play/rear material hashes. The far apparatus and sparse effects treatment deliberately retain identical material hashes across these seeds. Reusable definitions include upper/lower galleries, both cabinet arrangements, cabinet windows, gauges, shelves, signals, service rails and optional-loop courts. Optical cores reuse apertures and four braces; vaults reuse locks; every native vessel reuses pilot strips, base feet and inlet posts. The eight galleries each have nonempty treatment and intentional empty cells on all four planes. The structural receipts retain those per-gallery counts for every declared seed.


### Rank 5: architecture/material-authoring-catalogue-plan.md — Canonical material catalogue and interaction authoring — adopted Planned baseline > 11. Current-main review and implementation admission — 2026-11-03 > Legacy endpoints and scheduling must remain executable contracts

Document: Canonical material catalogue and interaction authoring — adopted Planned baseline
Path: architecture/material-authoring-catalogue-plan.md
authority: current-documentation
document-kind: design
status: Planned
scope: Wider Planned material-authoring migration with a current accepted-slice map; numbered sections preserve dated design/admission checkpoints, not current execution permissions
canonical-for: [material-authoring-v1-programme-proposal]
last-reviewed: 2026-11-24
Section: Canonical material catalogue and interaction authoring — adopted Planned baseline > 11. Current-main review and implementation admission — 2026-11-03 > Legacy endpoints and scheduling must remain executable contracts
For #355, section 5's `replace_with_defaults` is only shorthand for the actual legacy World path, **not** a generic reset of every field. Freeze: - Four-tick contact cadence, neighbour/random-stream order, one shared roll, `roll <= threshold` and target-then-source writes; threshold0 means 1/256, while a disabled rule is a distinct future declaration. - Water product quantity from the active World policy maximum, other products' descriptor-initialized state and the existing pressure/IN state retirement. Same-ID products do not automatically preserve quantity or solver state. - Existing optional temperature retention, body-mask/refusal behavior, no-op epoch/dirty semantics and gross produced/consumed plus pair-event accounting. A selected event can be recorded even when the write returns unchanged. - Existing specialized thermal, Acid, ignition, electrical and lifecycle paths remain hand-coded; their catalogue records describe them without replacing execution. #160/#162 retain ownership of their unmerged quantity correction. New `keep_existing`, `set_state` or quantity-aware effects require explicit field, sidecar, temperature, event, mutation and quantity-ledger contracts plus separate owner admission before use in production. Their design or synthetic tests do not authorize applying them to legacy same-material products. For #354, static metadata describes a kernel's obligations, not whether a cell is due, masked, active or waiting now. Preserve inert `RuleKernel::None` reaction targets: 26 of the 41 pair participants use that kernel and can be acted on by an active partner. A compiler must not reject or activate them merely for being inert. Reproduce MoltenGlass quiet-block cooling and yielding-liquid failed-roll retry hypotheses against fixed source before proposing any scheduler repair. Mutual MoltenGlass heating and desired viscous rest are separate gameplay-law decisions. Section 6's `KernelOutcome` is illustrative; first prefer the smallest repair using existing coalesced activity wakes. No blanket always-awake policy.

## DR07: Does a new player session still default to PressureFlow, or does it use Wave Flow Water?

Canonical rank: 2

Expected facts:

- Accepted gameplay source selects Wave Flow with its gameplay spill/ballistic profile for new sessions.
- Pressure, Wave, inertial and FreeMass remain distinct families; a default is not a claim that all families share semantics.

### Rank 1: systems/water-design.md — Water design

Document: Water design
Path: systems/water-design.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current Water-family routing and player defaults; scoped FreeMass mechanics, quantity accounting, historical negative controls and fallback differences
canonical-for: [native-water-semantics, native-fallback-water-differences]
last-reviewed: 2026-11-24
Section: Water design
**Current accepted source `00cdb02f`, checked 24 November 2026:** Water has several admitted native laws. Fresh native sandbox and Shared Workbench sessions use **Wave Flow with waterfall spill and ballistic release**. Plain C++ `WorldConfig` still selects the original FreeMass carrier with those overlays disabled. Native Web, desktop comparison hosts and explicit saved setups must be identified by their actual applied constructor/receipt; there is no universal all-platform player preset implied by the word “Water”. | Path | Material motion and state | Canonical contract | |---|---|---| | Original FreeMass | Pairwise fractional transfer; 255 units per full cell, coherence and film adhesion | The FreeMass sections below | | CellularYield Water | Whole-cell movement with explicit fractional-input admission/normalization | [Family policy](../architecture/liquid-solver-family-policy.md) | | PressureFlow | Pressure/head, visible quantity plus overfill, gas compartments; reference/cached/cached_dormant variants | [PressureFlow](../architecture/pressure-flow-v1.md) | | InertialCellular | Whole-cell carriers with retained integer motion; optional signed-vertical extension is separate | [Inertial](../architecture/inertial-cellular-v1.md) | | Wave Flow | Bulk strip passes, uint16 stored mass and retained face flux; no PressureFlow gas model | [Wave Flow](../architecture/wave-flow-v1.md) | | Ballistic Water | Bounded native parcels that launch, fly and deposit exact Water quantity | [Ballistic Water](../architecture/ballistic-water-v1.md) | | Desktop GDScript fallback | Discrete cell flow with different rules and limits | [Fallback section](#desktop-fallback-difference-and-historical-fixture) | Source: [`WorldConfig`](../../native/include/cybersand/world.hpp), [`select_gameplay_water`](../../godot/native_extension/cyber_native_cell_world.cpp), [`LiquidSolverPolicy`](../../native/include/cybersand/liquid_solver_policy.hpp). This page owns routing and the original FreeMass semantics. It does not collapse all families into one material law or turn an old FreeMass failure into a current Wave result. Runtime and physical acceptance remain source/platform-specific in the [validation ledger](../reference/validation-evidence.md).


### Rank 2: architecture/liquid-solver-family-policy.md — Liquid solver family policy and API specification > Status

Document: Liquid solver family policy and API specification
Path: architecture/liquid-solver-family-policy.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Current-main four-family identities, immutable per-World per-material policy, material/variant admission and readback, W-CY material block v2 and IN family block v2; historical design checkpoints and source/platform qualification remain separately scoped
canonical-for: [liquid-solver-family-policy]
last-reviewed: 2026-11-24
Section: Liquid solver family policy and API specification > Status
**Planned authoring target, 19 November 2026.** The owner wants to choose Wave Flow or an alternative solver per material, with tuning stored separately for each material. Shared contacts will still need rules for exchanging materials of different densities and preserving their quantities and specialized behavior. The accepted Wave implementation supplies the Water–Oil density exchange and supports excess Oil spreading over a Water-backed surface. Oil still runs its own burning, extinguishing and cellular motion rules. [Wave Water and Oil](wave-flow-v1.md#oil-floating-on-wave-water) **Current accepted source — 24 November 2026, `00cdb02f`.** The policy enum still has four registered families: FreeMass, CellularYield, PressureFlow and InertialCellular. Wave Flow is an additional Water execution overlay on the FreeMass carrier, selected through `WorldConfig::wave_flow`; it is not a fifth `LiquidSolverFamily` enum value or a replacement for PressureFlow gas semantics. Ballistic Water is another explicit owner/configuration, orthogonal to those bulk-family choices subject to native admission. Fresh sandbox and Shared Workbench player sessions enable Wave, spill and ballistic release through [`CyberNativeCellWorld::select_gameplay_water`](../../godot/native_extension/cyber_native_cell_world.cpp) and [`main.gd::_ready`](../../godot/scripts/main.gd). Plain native construction keeps Wave and ballistic Water off. Applied receipts/readbacks identify the actual law; a control's staged value is not evidence it was installed. The [Wave contract](wave-flow-v1.md), [ballistic contract](ballistic-water-v1.md) and [configuration reference](../reference/configuration-reference.md#water-constructor-defaults-and-player-profile) own their extra state, limits and profile. Selecting/tuning Wave independently for arbitrary materials is **Planned**. Oil retains its specialized cellular rules even when its contacts exchange with Wave Water. **Current-main checkpoint — 2026-11-03.** At inspected main `89020b9eb6d540383a5bb64b58dcd29a87592c32`, all four physically distinct families are implemented and have ordinary application constructors. The [#359 reassessment](../audits/2026-11-03-lcb-reassessment.md) binds the source, merged and parked PRs, actual worker evidence and remaining qualification. Pressure reference, cached and cached+dormant are three implementations of one family. Those native policy defaults remain Water FreeMass and ten other liquids CY; the current player host separately enables the Wave gameplay overlay as described below. This 3 November checkpoint does not define today's player preset. | Material | Admitted family/variant selection | |---|---| | Water3 | `freemass_v1/reference`, `cellular_yield_v1/reference`, `pressure_flow_v1/reference`, `pressure_flow_v1/cached`, `pressure_flow_v1/cached_dormant`, `inertial_cellular_v1/reference` | | Brine24 | `cellular_yield_v1/reference`, `inertial_cellular_v1/reference` | | Lava8, Acid12, Oil16, Paste20, Slush21, Cement30, ToxicSludge32, Mercury33, MoltenGlass36 | `cellular_yield_v1/reference` only | The native authority is `LiquidPolicyBuild::running()` in [`liquid_solver_policy.hpp`](../../native/include/cybersand/liquid_solver_policy.hpp). An illustrative ToxicSludge IN alternate has no qualified variant and is refused; nonliquids and cached variants of FM/CY/IN are also refused. Every material has one immutable applied family per World. Comparing multiple Water laws requires separate Worlds or a transactional session rebuild. IN requires explicit radius3; the normal non-IN World radius is2. Whole-cell Water CY/IN require saturated Water, with separately requested initial normalization; future fractional inputs still refuse. Matching radius3


### Rank 3: operations/wave-flow-evaluation.md — Wave Flow evaluation > Water Lab (consolidated Workbench UI)

Document: Wave Flow evaluation
Path: operations/wave-flow-evaluation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Experimental PR 631 Wave Flow desktop controls inherited from PR 618, comparative fixtures, actual native diagnostics and explicit unsupported physical persistence and material behavior
canonical-for: [wave-flow-evaluation]
last-reviewed: 2026-11-16
Section: Wave Flow evaluation > Water Lab (consolidated Workbench UI)
Open **Water Lab…** from the main Workbench toolbar. All Water-specific settings share one non-modal window. **Solvers & scenes** selects Wave/FreeMass/PressureFlow/Inertial, comparison canvases and workers; **Wave tuning** exposes the Wave fields and presets; **Transport & spray** contains ballistic, signed inertia, face release, PressureFlow gas, fine cores, impact spray and jets; **Equipment** contains valves, drains, pumps and nozzles; **Advanced policy** retains the full per-material liquid picker and normalization. **Applied native** readback and **Apply solver / tuning** are always visible beneath the tabs. The old separate Wave/spray popups and permanent Water toolbar rows are not created. This is a UI composition change, not a solver/policy modification; staged and refused requests still use the existing native receipts.


### Rank 4: architecture/wave-flow-v1.md — Wave flow Water solver (experimental) > Controls

Document: Wave flow Water solver (experimental)
Path: architecture/wave-flow-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current Wave Flow law, player defaults, bulk strip-parallel execution, admission, state and memory
canonical-for: [wave-flow-v1]
last-reviewed: 2026-11-20
Section: Wave flow Water solver (experimental) > Controls
| Setting | Default | Meaning | |---|---|---| | `WorldConfig::wave_flow.enabled` | `false` | Opt in at construction | | `WorldConfig::wave_flow.substeps` | `1` | Rounds per tick, 1–8 | The ordinary feature launcher has **Wave Flow**. The equivalent direct route is `-- --wave-flow` or `res://wave_flow_evaluation.tscn`; the Windows evaluation ZIP provides `Test It.cmd`. The [evaluation guide](../operations/wave-flow-evaluation.md) owns the launch and scene walkthrough. The evaluator constructs a fresh native World when **Reset scene** applies Wave/FreeMass/Inertial/PressureFlow selection, workers, substeps and world size. It exposes ten scenes, 256/512/1024/2048 sizes, 1–32 workers, 1–8 Wave substeps, native pacing 1–120 Hz and Rapier pacing 30–120 Hz. **Run/Pause**, **Single tick** and **Disturb pool** control the scenario. Native tick timing is reported separately from presentation rate. `get_wave_flow_status` returns copied selection, actual participants, timing, tasks, solved chunks, allocated storage and quantity; `inspect_wave_flow_cell` copies stored/visible uint16 mass and retained face flux. A replacement creates the Water law selected by its destination session. Moving-body and Needle scenes own actual Rapier objects on Godot's main thread; only their bounded transient masks/contact values cross into native simulation. Needle retains its existing authored weight and thrust; **W/A/D/S** provide thrust/turn/reverse. The evaluator uses native material publication, with no cosmetic animation standing in for the solver. Source: [`wave_flow.hpp`](../../native/include/cybersand/wave_flow.hpp), [`world_wave.inc`](../../native/src/world_wave.inc); hooks in [`world.cpp`](../../native/src/world.cpp) (`begin_tick`, `ensure_chunk`, `rule_is_active`, `mark_cell_dirty`, `merge_job_effects`, body-mask edits). Regressions: [`test_wave_flow.cpp`](../../native/tests/test_wave_flow.cpp) (`make wave-flow-test`, `wave-flow-sanitize`, `wave-flow-thread-sanitize`).


### Rank 5: architecture/ballistic-water-v1.md — Ballistic Water and hybrid spray (experimental) > Limits and open decisions

Document: Ballistic Water and hybrid spray (experimental)
Path: architecture/ballistic-water-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Accepted BW-001 Water parcel owner, optional IN-B1 and WCX controls, Wave gameplay release, accounting and versioned persistence; native constructor defaults and player presets are distinct
canonical-for: [ballistic-water-v1, inertial-b1-signed-vertical, water-impact-spray]
last-reviewed: 2026-11-24
Section: Ballistic Water and hybrid spray (experimental) > Limits and open decisions
- Experimental only: no default, production carrier or #45 decision changes. - PressureFlow overfill cells are refused as launch sources; parcels do not carry pressure, gas or temperature (deposits use ambient defaults). - Parcels treat non-resident chunks as hard boundaries. Outside Wave, an excluded simulation region still receives deposits; the Wave-specific region refusals are described above. - Human gameplay acceptance, Windows/Linux CI, source-matched runtime publication and independent review remain open.

## DR08: Water must never move upward ballistically, correct?

Canonical rank: 1

Expected facts:

- The blanket prohibition is stale: accepted optional Water ballistic and Wave release paths exist.
- State the admitted family and bounds; this does not establish every generic solid/equipment successor as accepted.

### Rank 1: architecture/ballistic-water-v1.md — Ballistic Water and hybrid spray (experimental) > IN-B1: signed-vertical inertial law

Document: Ballistic Water and hybrid spray (experimental)
Path: architecture/ballistic-water-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Accepted BW-001 Water parcel owner, optional IN-B1 and WCX controls, Wave gameplay release, accounting and versioned persistence; native constructor defaults and player presets are distinct
canonical-for: [ballistic-water-v1, inertial-b1-signed-vertical, water-impact-spray]
last-reviewed: 2026-11-24
Section: Ballistic Water and hybrid spray (experimental) > IN-B1: signed-vertical inertial law
Opt-in `WorldConfig::inertial_signed_vertical` (requires an applied IN assignment). It has its own extension identity domain and CYPS4 bit; v1 Worlds are unchanged and still refuse `vy < 0` everywhere. - U1/U3: support applies only to a cell that is not rising (`carried >= 0`), so an obstacle beneath never destroys upward motion; gravity alone turns it. - U2: flight gravity is half of v1 (`kSignedGravity = 2` q16/tick²), so the radius-bounded 2-cell/tick launch reaches a visible ≈16-row apex before damping. - U6: an upward-blocked move (ceiling or overhead body) reverses a quarter of the rise; a body overhead receives an upward contact. - Ledger: `gravity_speed` books gravity's exact signed L1 effect, separate from dissipative `loss` (`Σ|v| = gravity_speed - loss + external - retired`); in v1 it equals `gravity_y`. `impart_inertial_velocity` adds a bounded external impulse.


### Rank 2: systems/granular-interaction-policy.md — Granular interaction and sampled player policy > How does the sampled character move and recover? > REM-003 sampled-player landing response

Document: Granular interaction and sampled player policy
Path: systems/granular-interaction-policy.md
authority: current-documentation
document-kind: contract
status: Current
scope: Version 1 material capability, sampled player support, pair exchange and deterministic permeability wakes
canonical-for: [granular-support-policy, granular-pair-policy, sampled-player-collision]
last-reviewed: 2026-09-25
Section: Granular interaction and sampled player policy > How does the sampled character move and recover? > REM-003 sampled-player landing response
**Current candidate C1:** the version-1 8/9 downward and 9/9 side/upward support classification is unchanged. REM-003 source-matched characterization found that packed standing, flat traversal, representative powders and excavation release worked within their registered cases, while materially different Sand landing speeds resolved to nearly the same rigid support height with no granular response. C1 therefore changes the sampled-character response rather than retuning the shared support predicate used by REM-002 generic body bearing. On a downward sampled-player collision, impact speed below 24 cells/second causes no disturbance. From 24 through less than 72, at most one supported foot-edge grain may move; at 72 or above, at most two may move. Only the left/right contact edge is considered. A candidate grain must be a stored support-capable granular material that currently satisfies the existing packing/stability predicate. It may move exactly one cell diagonally outward/up only through the existing whole-cell conservative relocation path into real Empty storage not occupied by another transient body. Material state and temperature move with the cell and the normal wake/dirty machinery runs. Hard terrain anywhere in the sampled collision volume fails this disturbance path closed; liquids, loose/unsupported grains and ordinary resting contact likewise do not trigger it. The player still stops on the accepted support surface; C1 does not introduce character-owned material, a granular Rapier collider, a pressure/velocity field, per-cell character physics or a second body-bearing solver. The native adapter and fallback mirror the bounded operation under their existing serialized owners. The resulting grain may subsequently move under ordinary cellular rules, so the disturbance count is not a promise of permanent crater geometry. Broad generic body↔granular acceptance remains REM-004 / #83. Owner gameplay acceptance of C1 is a separate REM-003 gate and is not implied by automated tests.


### Rank 3: systems/granular-interaction-policy.md — Granular interaction and sampled player policy > How does the sampled character move and recover?

Document: Granular interaction and sampled player policy
Path: systems/granular-interaction-policy.md
authority: current-documentation
document-kind: contract
status: Current
scope: Version 1 material capability, sampled player support, pair exchange and deterministic permeability wakes
canonical-for: [granular-support-policy, granular-pair-policy, sampled-player-collision]
last-reviewed: 2026-09-25
Section: Granular interaction and sampled player policy > How does the sampled character move and recover?
`character_box_collides(origin, size, mode)` accepts finite positive boxes up to 32 by 32 physical cells (up to 33 by 33 raster cells at fractional origins). Mode 0 checks full-volume enclosure, 1 samples powder at feet, 2 at sides, and 3 at the head; every mode checks hard occupancy throughout the volume. Malformed/out-of-world boxes fail closed. `box_collides` is mode 0. The old material-only fallback helper now identifies hard surfaces only. `CyberSampledCharacter` uses at most one-cell movement increments, a one-cell grounded step-up, and clamps each simulation delta to 0..0.1 seconds. PCHAR-001 now distinguishes two uses of the former enclosure search. **Invalid-spawn/reset repair** remains an explicit bounded search of at most 128 axis candidates within 32 cells, nearest first and upward/left/right/down at equal distance. The historical **sampled-baseline runtime** retains the same search before movement, but records attempts, successes, last offset and cumulative upward relocation. This instrumentation makes the previously implicit rapid upward-surfacing mechanism directly observable. The PCHAR **sampled-burial-safe** experiment disables that runtime search while retaining explicit invalid-spawn repair. If material occupies the sampled actor at runtime, velocity is zero, the actor remains in place with `runtime_enclosed/recovery_blocked` set, and no material is erased or displaced. This is an experimental disposition, not a new production player selection. Diagonal escape, crush damage, barrel pushing and carrying remain unimplemented. Native queries run only under the serialized World owner, outside kernels; the read neighbourhood does not enlarge native job write domains. Desktop and Web retain their different character/cell order. Fallback uses the same query geometry and material capability, but its narrower cellular rules remain a separate semantic reference, not native Water/reaction parity.


### Rank 4: architecture/liquid-state-transition-matrix.md — Liquid material and solver state-transition matrix > 5. Velocity and momentum (IN; PF flow)

Document: Liquid material and solver state-transition matrix
Path: architecture/liquid-state-transition-matrix.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Operation-by-operation rules for default liquids, accepted native W-CY/pressure variants/Brine IN and isolated published Water IN; historical Proposed requirements retain their source qualification — ownership, state movement, exact quantity/source-sink, invalidation and family applicability; no production Cell layout choice
canonical-for: [liquid-state-transition-matrix]
last-reviewed: 2026-10-25
Section: Liquid material and solver state-transition matrix > 5. Velocity and momentum (IN; PF flow)
**Inertial update `inertial-update-v1` (Proposed, #212; correction 2026-10-23).** The earlier rows were inconsistent ([re-review finding 2](https://github.com/techrote/cybersand/pull/226#issuecomment-6362824493)): - a per-component ledger with only non-negative losses could not represent a deflection that creates `vx > 0`, nor damping of a negative `vx`; - gravity before deflection could push a supported cell at rest sideways; - "blocked travel zeroes velocity" contradicted "same-family blocking preserves velocity". They are replaced by one ordered update per inertial cell per tick. The executable specification is the standalone oracle [`inertial_contract.py`](../../tools/lcb/inertial_contract.py), with its [tests](../../tools/lcb/test_inertial_contract.py). Its worked examples are embedded in the [contract registry](../../godot/tests/fixtures/lcb/lcb-physics-contracts.json) (contract `inertial-update`). It is a contract model on static neighbourhoods: **the contract model itself executes no World, scheduler or inertial family.** Units: velocity and accumulators are signed integers in `q` units per cell. The illustrative values are `q = 16`, `g = 4` and `vmax = 64`. Fractions are `turn 1/8`, `deflect 3/4`, `damping 1/16` and `drag 1/4`; the rest threshold is `1`. These values are recorded in the receipt and are **not frozen**. `vy ≥ 0` always, because v1 has no upward impulse source. | Step | Rule | |---|---| | Eligibility (N1 correction) | One **directional** rule `eligible(dx, dy)` serves support, re-aim, side selection and every travel move. Empty: any move. A lighter foreign material admitted by Current density/exchange controls: **only a move with `dy = +1`**, straight or diagonal down. This is the vertical density exchange Current `can_density_exchange` admits (vertical delta ≠ 0). A horizontal move (`dy = 0`) never swaps; a lighter neighbour beside the cell is a horizontal contact. Wall, solid, transient body mask and an occupied same-material cell are never eligible and share one contact rule. Selecting IN for both materials does not remove a permitted foreign-material density exchange. No new foreign-liquid boundary law is introduced. | | U1 support | `supported` := `not eligible(0, +1)`, evaluated before any velocity change. A lighter liquid below is therefore not support. | | U2 gravity | `vy += g`, **exactly once per tick**, booked as the only speed-adding entry. | | U3a diagonal re-aim (lateral source A) | If supported and `eligible(±1, +1)`: the `sign(vx)` side first, else `deterministic_direction` order. Then `S = |vx| + vy` (including this tick's `g`), `turn = trunc(S·1/8)`, `S' = S − turn`, `|vx| = S' // 2` toward the diagonal, `vy = S' − |vx|`. A cell at rest gains only `g` along the diagonal. | | U3b support and deflection (lateral source B) | If supported and both diagonals are blocked, a **support** impulse `−g` first


### Rank 5: systems/player-environment-profiles-and-traversal.md — Player/environment tuning profiles and sampled traversal > Step, knee and clamber bands

Document: Player/environment tuning profiles and sampled traversal
Path: systems/player-environment-profiles-and-traversal.md
authority: current-documentation
document-kind: contract
status: Current
scope: PENV-001 sampled-player mass, gravity, terminal/jetpack tuning, material-response identity and step/knee/clamber traversal; excludes Water semantic changes and generic-body physics
canonical-for: [player-environment-tuning, sampled-character-traversal-bands]
last-reviewed: 2026-09-25
Section: Player/environment tuning profiles and sampled traversal > Step, knee and clamber bands
Horizontal sampled-character traversal tests obstacle clearance from the smallest height upward: - **Step:** height at or below `step_height` traverses at the full horizontal increment, preserving the historical one-pixel no-slowdown behavior. - **Knee:** above step and at/below `knee_height` requires body clearance and uses `knee_slowdown` as the horizontal progress factor for that simulation tick. - **Clamber:** above knee and at/below `clamber_height` requires the same bounded clearance/support check and uses `clamber_slowdown`. - **Above clamber:** the sampled horizontal move is blocked unless another explicitly owned mechanic applies. The exact-current profile sets all three thresholds to one pixel, so a two-pixel or larger obstacle remains blocked exactly as before. PENV-001 regression fixtures cover one-pixel, two-pixel, configured larger clamber and above-clamber cases. This is a bounded sampled-character traversal rule, not ledge grabbing, animation, stamina, arbitrary collision-shape climbing or a generic Rapier-body semantic.

## DR09: Can I treat FreeMass Water and other-liquid CellularYield amounts as identical quantity rules?

Canonical rank: 5

Expected facts:

- Water FreeMass and other-liquid CellularYield have different quantity semantics.
- Use the selected family policy and explicit normalization/receipt contract; do not silently unify amounts or conservation claims.

### Rank 1: systems/materials-and-rule-kernels.md — Materials and rule kernels > Current material families

Document: Materials and rule kernels
Path: systems/materials-and-rule-kernels.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native material identity, descriptors, mutable state, kernel execution, current interactions, and extension boundaries
canonical-for: [material-runtime-model, material-kernel-cadence, reactive-material-families]
last-reviewed: 2026-11-24
Section: Materials and rule kernels > Current material families
The table summarizes compiled behavior, not a complete pair-interaction matrix. Exact triggering and writes are in `update_rule_kernel` and [material_rules.cpp](../../native/src/material_rules.cpp). | Family | Representative behavior | |---|---| | Sand, Stone, Dust | Gravity/settling; brace-aware or granular Stone; ignitable Dust | | Water | Conserved pairwise mass; [Water contract](water-design.md) owns numeric semantics | | Smoke, Steam, Foam | Buoyancy and distinct decay/phase behavior | | Fire, Wood, Oil, Coal | Ignition/burn state, emission and selected extinguishing reactions | | Lava, Ice, Glass, Molten Glass | Material/compact-state melting, freezing, cooling and quenching | | Acid, Metal, Rust, Spark | Finite corrosion, local charge propagation, reactions with Water | | Plant, Fungus, Seed | Bounded energy/growth, substrate rules, germination, combustion | | Cloner, Mite, Rocket | Capture/emission, feeding/movement, payload/launch/trail/impact | | Salt, Brine, Sodium, Gunpowder | Dissolution and energetic contact reactions | | Cement, Concrete | Flowing wet Cement and environment-dependent cure | | Toxic Sludge, Mercury | Purification reaction and high-density liquid exchange | | Paste, Slush | Viscous whole-cell yield that can retain heaps | The unmodified **descriptor defaults** assign Water to `FreeMass` and ten other liquids to `CellularYield`. Applied native policy can select supported alternatives for Water and Brine; the current player profile additionally enables Wave over Water's FreeMass carrier. These are not identical flow/quantity semantics. See [Water routing](water-design.md) and the [family policy](../architecture/liquid-solver-family-policy.md). Viscosity is dimensionless gameplay tuning, separate from yield and adhesion.


### Rank 2: operations/water-hybrid-pressure-extension-programme.md — Water hybrid, saturated-head and compartment-pressure extension programme > Owner clarifications recorded 2026-09-20 > Water and other native liquids still use distinct motion/quantity paths

Document: Water hybrid, saturated-head and compartment-pressure extension programme
Path: operations/water-hybrid-pressure-extension-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Parallel/extension research for deep-Water bulk response, generic Rapier↔cellular coupling, bounded solided-Water sheet proofs, saturated-head requirement reassessment, lumped gas regions and optional decompression events; no production architecture adoption
canonical-for: [water-hybrid-pressure-extension-programme]
last-reviewed: 2026-10-24
Section: Water hybrid, saturated-head and compartment-pressure extension programme > Owner clarifications recorded 2026-09-20 > Water and other native liquids still use distinct motion/quantity paths
Completed #15 characterization remains the relevant scoped evidence: - native Water uses the fractional conserved **FreeMass** path; - most other native liquids use whole-cell **CellularYield**-style motion; - Oil retains additional specialization; - no universal FreeMass conversion, liquid unification or new generalized yield solver was selected. A new explicit hydrostatic/depth-pressure transport mechanism would therefore add another liquid-specific bulk-motion authority. This is one reason to measure what generic soliding/hybrid coupling can already provide before adding a new Water solver layer.


### Rank 3: systems/water-design.md — Water design > WEX-005 disposition and the opt-in LCB lane (2026-10-23)

Document: Water design
Path: systems/water-design.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current Water-family routing and player defaults; scoped FreeMass mechanics, quantity accounting, historical negative controls and fallback differences
canonical-for: [native-water-semantics, native-fallback-water-differences]
last-reviewed: 2026-11-24
Section: Water design > WEX-005 disposition and the opt-in LCB lane (2026-10-23)
**Historical FreeMass checkpoint:** the following result predates the later admitted families and Wave player profile. The [WEX-005 synthesis](../audits/2026-10-23-wex005-water-evidence-synthesis.md) records #95's answers: - **Deep release:** the slow-slope deficit is real and unresolved. On current `main` (#49 v2 rerun 39739371203), deep and medium outlets deliver byte-identical discharge, so depth above saturated outlet cells adds no drive. Water sheets (#92) were never tested. No surge fixture is registered yet. - **#45: NARROW.** Bounded head-transmission research continues to its admission/design phase only, under a shared/vented atmosphere, with a separately registered surge fixture family. No mechanism is selected. - **Boundary assumption of that FreeMass comparator:** it has no gas state; `Empty` acts as one shared atmosphere. Equal levels are a valid target only for vented/shared headspaces. Sealed headspaces settle at `Δh = (p_A − p_B)/(ρ·g)`, and vacuum/low-pressure boundaries have no Current target. - #93 is research only, #94 is narrow-use, #18 stays held, and FreeMass and CellularYield stay separate. The owner-approved **Liquid Comparison Build** (#200, gated by #213) adds an opt-in, version-identified `pressure_flow_v1` family and later other experimental families with Water as a common test material. The [LCB-000 Gate A record](../audits/2026-10-23-lcb000-gate-a-water-pressure-admission.md) bounds that lane: unchanged defaults, no hidden fallback, no production #45 selection, no new pressure-to-Rapier forces, and the Current fixtures and #49 v2 controls held fixed. The later native implementations are accepted: PressureFlow and its variants, Water/Brine InertialCellular, and their ordinary prepared application paths are mapped in the [family policy](../architecture/liquid-solver-family-policy.md). Pressure Worlds add overfill, signed flow and World-owned gas compartments; FreeMass `transfer_water` refuses there rather than silently acting as a fallback. The native quantity ledger distinguishes visible, overfill and in-flight Water. These additions do not select a generic #45 mechanism or accept every historical #12 hybrid objective. **Historical admission evidence:** LCB-000 Gates A–E passed and #213 closed on 24 October 2026. The [design checkpoint](../reference/status-and-roadmap.md#liquid-comparison-build-design-checkpoint--2026-10-23), [policy foundation](../reference/status-and-roadmap.md#lcb-001-policy-foundation--2026-10-24) and [bounded implementation decision](../reference/status-and-roadmap.md#lcb-001-pressure-reference--2026-10-24) preserve the original permissions. Their “unmerged pressure branch” and “inertial not implemented” descriptions were later superseded by accepted source; they do not describe availability at `00cdb02f`. The initial admission itself made no production-default, carrier, full-replay or general streaming change. The later Wave gameplay profile is a separately identified transition.


### Rank 4: systems/water-design.md — Water design

Document: Water design
Path: systems/water-design.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current Water-family routing and player defaults; scoped FreeMass mechanics, quantity accounting, historical negative controls and fallback differences
canonical-for: [native-water-semantics, native-fallback-water-differences]
last-reviewed: 2026-11-24
Section: Water design
**Current accepted source `00cdb02f`, checked 24 November 2026:** Water has several admitted native laws. Fresh native sandbox and Shared Workbench sessions use **Wave Flow with waterfall spill and ballistic release**. Plain C++ `WorldConfig` still selects the original FreeMass carrier with those overlays disabled. Native Web, desktop comparison hosts and explicit saved setups must be identified by their actual applied constructor/receipt; there is no universal all-platform player preset implied by the word “Water”. | Path | Material motion and state | Canonical contract | |---|---|---| | Original FreeMass | Pairwise fractional transfer; 255 units per full cell, coherence and film adhesion | The FreeMass sections below | | CellularYield Water | Whole-cell movement with explicit fractional-input admission/normalization | [Family policy](../architecture/liquid-solver-family-policy.md) | | PressureFlow | Pressure/head, visible quantity plus overfill, gas compartments; reference/cached/cached_dormant variants | [PressureFlow](../architecture/pressure-flow-v1.md) | | InertialCellular | Whole-cell carriers with retained integer motion; optional signed-vertical extension is separate | [Inertial](../architecture/inertial-cellular-v1.md) | | Wave Flow | Bulk strip passes, uint16 stored mass and retained face flux; no PressureFlow gas model | [Wave Flow](../architecture/wave-flow-v1.md) | | Ballistic Water | Bounded native parcels that launch, fly and deposit exact Water quantity | [Ballistic Water](../architecture/ballistic-water-v1.md) | | Desktop GDScript fallback | Discrete cell flow with different rules and limits | [Fallback section](#desktop-fallback-difference-and-historical-fixture) | Source: [`WorldConfig`](../../native/include/cybersand/world.hpp), [`select_gameplay_water`](../../godot/native_extension/cyber_native_cell_world.cpp), [`LiquidSolverPolicy`](../../native/include/cybersand/liquid_solver_policy.hpp). This page owns routing and the original FreeMass semantics. It does not collapse all families into one material law or turn an old FreeMass failure into a current Wave result. Runtime and physical acceptance remain source/platform-specific in the [validation ledger](../reference/validation-evidence.md).


### Rank 5: architecture/liquid-state-transition-matrix.md — Liquid material and solver state-transition matrix > Status and inputs

Document: Liquid material and solver state-transition matrix
Path: architecture/liquid-state-transition-matrix.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Operation-by-operation rules for default liquids, accepted native W-CY/pressure variants/Brine IN and isolated published Water IN; historical Proposed requirements retain their source qualification — ownership, state movement, exact quantity/source-sink, invalidation and family applicability; no production Cell layout choice
canonical-for: [liquid-state-transition-matrix]
last-reviewed: 2026-10-25
Section: Liquid material and solver state-transition matrix > Status and inputs
- **Default-family baseline rows** retain the historical prepass at `9012425`/`4caa2c3`. Current PF and W-CY refinements are identified separately below. - **Proposed rows** are the contract that #200 (policy, `pressure_flow_v1`, whole-cell Water) and #212 (`inertial_cellular_v1`) must implement and test. - **PF rows are implemented (2026-10-24)** by the opt-in [`pressure_flow_v1/reference`](pressure-flow-v1.md), Current on main since #245 merged at `03785c3`. Its [lifecycle table](pressure-flow-v1.md#lifecycle-per-mutation-path) owns the Current per-path result. Refinements of the Proposed PF text: the overfill bound is `maximum()`; a kernel-vacated cell carries a vacuum label (volume, not amount); `transfer_water` throws in a pressure World; vented and collapsed gas amounts are booked in `GasLedger`. Accepted [PR #246](../audits/2026-10-25-lcb001-shared-contract-acceptance.md) advances main to exact hash/persistence version **2** with the shared quantity ledger and construction bindings. Main explicitly refuses historical CYPS1; its #245 evidence is retained. CYSD1 stays a default-family reconstruction. - **W-CY rows are Current on main through #246** at merge `ec58d919`: whole-cell Water law version 1 and optional viscosity material block v2, with retained cadence/stochastic liveness. [Native prepared setup and receipts](liquid-prepared-setup-and-receipts.md) owns normalization, native-issued outcomes, typed receipt and accounting codecs. This owner-requested narrow native freeze is not a production Cell or global ABI freeze. Brine IN/reference and #201 caches/dormancy are Current in the combined #212 source, with [IN](inertial-cellular-v1.md) and [pressure](pressure-optimization.md) qualifications separately retained; fresh combined-source qualification remains required. - **Storage** follows the [Gate B bounded handoff](../audits/2026-10-23-lcb000-gate-b-state-handoff.md) (accepted; [refresh](../audits/2026-10-23-lcb000-admission-gatea-gateb-refresh.md)): - the C64-E8 Cell is unchanged; - family state lives in **optional, versioned, solver-owned storage**, plus a **World-owned gas-compartment table**; - no spare-bit allocation; - numeric widths are frozen by #200/#212 before code. - **Not a schema or layout decision.** **Family columns:** | Column | Meaning | |---|---| | FM | `freemass_v1` (Current Water) | | CY | `cellular_yield_v1` (Current other liquids; experimental whole-cell Water in W-CY) | | PF | `pressure_flow_v1` (Water only, v1) | | IN | `inertial_cellular_v1` (Water whole-cell v1; Brine) | **Common state tuple** (Current, moves as one unit): material, `state_a`, `state_b`, and optional chunk temperature. Optional family state is: | Family | Optional state | |---|---| | PF | overfill quantity, signed flow/velocity, optional wake/history | | IN | signed vx/vy (or momentum), subcell accumulators | | World gas table | per compartment: id, generation, ancestry, amount, free volume, vent/seal state, topology revision | **Cross-cutting rules** applying to every row: - **R1** Optional family state belongs to exactly one cell. It moves with that cell and is **retired** (never left behind or duplicated) when the cell becomes Empty or another material. - **R2** A product or newly painted cell starts at its own

## DR10: If I edit viscosity in Materials Lab, does every specialized material kernel use the new value?

Canonical rank: 1

Expected facts:

- Declared and effective properties are distinct; specialized kernels can ignore or refuse candidate properties.
- A compiled candidate is not proof that all production consumers use it; inspect admitted backend and native comparison result.

### Rank 1: operations/materials-lab-authoring.md — Materials Lab v1 > Browse and inspect actual behaviour

Document: Materials Lab v1 inspection, candidate authoring and native tests
Path: operations/materials-lab-authoring.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Accepted desktop native inspection, candidate authoring, isolated World comparisons and existing-material MicroScenarios; no runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-24
Section: Materials Lab v1 > Browse and inspect actual behaviour
Search by exact stable ID, name, physical state, kernel, semantic family or reaction partner. Filters include physical states and explicit hard/granular capabilities. These categories organize the browser; neither appearance labels nor semantic family membership confer inherited physics. Every important property row separates **declared value → effective value → actual consumer → applicability → editability**. The native cold-path bridge reads original descriptor values, capability predicates, density-exchange eligibility, visual-state projection and compiled solver defaults. The model also consumes the existing native interaction profile. Missing native support fails explicitly. It never substitutes shadow catalogue values for native facts. Examples to check: - **Water:** the specialised Water family determines motion. Descriptor viscosity is not a Lab edit. CellularYield Water's versioned policy viscosity is a separate consumer; it is not the descriptor viscosity byte. - **Sand:** powder movement, density and explicit hard/granular capabilities are separate facts. A powder name never implies hard terrain. - **Slush:** native density is 1080; the separately identified GDScript fallback has density 1100. Neither value is silently substituted for the other. - **MoltenGlass:** yielding movement and specialised thermal behaviour are shown separately, including the actual consumers and the admitted descriptor fields. - **Lava, Acid and Oil:** an ignored descriptor viscosity is labelled ineffective for the specialised kernel, and the candidate control is disabled. When opened from Shared Workbench, the inspector receives a **copied applied policy receipt at opening**. Reopen to refresh it. A standalone Lab labels compiled defaults as unobserved by a live World. **Show applied Water settings** switches the inspector to the isolated experiment's acknowledged native policy. The UI never reads a simulation-worker-owned World from the main thread. Sources: [native inspection](../../godot/native_extension/material_lab_inspection.inc), [catalogue model](../../godot/scripts/material_lab_catalogue.gd), [panel](../../godot/scripts/material_lab_panel.gd) and the minimal [Workbench mount](../../godot/scripts/shared_workbench.gd).


### Rank 2: architecture/material-authoring-catalogue-plan.md — Canonical material catalogue and interaction authoring — adopted Planned baseline > 11. Current-main review and implementation admission — 2026-11-03 > Materials Lab effective inspection and editing

Document: Canonical material catalogue and interaction authoring — adopted Planned baseline
Path: architecture/material-authoring-catalogue-plan.md
authority: current-documentation
document-kind: design
status: Planned
scope: Wider Planned material-authoring migration with a current accepted-slice map; numbered sections preserve dated design/admission checkpoints, not current execution permissions
canonical-for: [material-authoring-v1-programme-proposal]
last-reviewed: 2026-11-24
Section: Canonical material catalogue and interaction authoring — adopted Planned baseline > 11. Current-main review and implementation admission — 2026-11-03 > Materials Lab effective inspection and editing
**Planned #356:** catalogue descriptors alone cannot supply effective viscosity controls or runtime reaction status. Reuse the material-info v1–v4 native C API, the native bridge's interaction catalogue/inspection, and the applied liquid policy readback. Report the selected backend and solver beside each value. Lava, Acid and Oil bypass descriptor viscosity in specialized movement, so that declared field is read-only or explicitly unused there. Water-CY consumes its versioned material-block viscosity; generic yielding liquids use descriptor viscosity except for Mercury's diagnostic override. A descriptor-only radius display must also distinguish IN's applied radius-3 geometry. An interaction resolver sees matches and rolls, not the live World's sleep, mask or due-opportunity state. Existing specialized inspection explicitly marks records `evaluated=false`. Show unsupported/unobserved status rather than inventing reasons. A future World observation must be produced by its real owner and preserve the bounded copied-observation contract. Source-edit-required fields can be exported as validated authoring changes for rebuild; existing construction-policy fields can be edited only through their actual validated restart/preparation API. A slider is enabled only when a consumer, owner and applied readback exist. Failed validation or reconstruction preserves the old source/profile/World, and a successful preview does not claim that a production policy was changed. Read-only inspection can precede new reaction semantics; editing cannot bypass #355 or relevant #354 dispositions.


### Rank 3: operations/materials-lab-authoring.md — Materials Lab v1 > Supported candidate edits and state transitions

Document: Materials Lab v1 inspection, candidate authoring and native tests
Path: operations/materials-lab-authoring.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Accepted desktop native inspection, candidate authoring, isolated World comparisons and existing-material MicroScenarios; no runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-24
Section: Materials Lab v1 > Supported candidate edits and state transitions
Select a valid, nonempty material and **Duplicate selected**, or choose **New powder 132**. The original template selects the existing kernel and state contract. The candidate label is not a production rename. Existing IDs, enum encodings and rule slots remain fixed. | Property | Lab v1 boundary | |---|---| | Density; base RGBA | Editable candidate fields; consumed by the descriptor probe and isolated compiled World | | Explicit hard/granular capability; visual-state projection | Editable and exercised by the descriptor probe; edits are rejected by the World backend because it retains the native capability/projection consumers | | Descriptor viscosity | Editable only for generic YieldingLiquid, Cement and MoltenGlass templates; ineffective specialised-kernel edits are rejected | | Physical state, kernel, movement flags, density-motion mode, exchange permission, lateral-flow descriptor, initial state bytes and write radius | Held to the selected template; choose another template for a different admitted mechanism | | Existing sparse reaction slots owned by the template | Structured partners, products, match mode and inclusive probability threshold are editable; identity, slot and supported endpoint-effect semantics stay fixed | | Explicit endpoint effects v2 | Non-Water `keep_existing`, or declared Metal/Combustible `state_b` updates, execute only in isolated compiled Worlds; see the reaction contract below | | New arbitrary production IDs, new kernels, unknown fields, Water retention/quantity effects, arbitrary state writes, new pair-rule slots | Unsupported and rejected with a field path and explanation | | Water movement model in **Try originals** | Built-in default, FreeMass, CellularYield and PressureFlow use the existing native admission and readback in the isolated test World | | Empty 0 and reserved invalid 10 | Inspectable, not candidate templates | **Draft** means editable, unqualified data. **Validated candidate** means the strict schema and immutable compatibility check passed. **Compiled/tested** means that exact candidate compiled and ran in the stated native probe. **Runtime-active** requires an authoritative production installation and engine acknowledgement; Lab v1 never assigns this state to a candidate. An edit revokes previous validation. A background response for an older revision cannot qualify newer edits. Candidate World results also bind the exact test recipe; changing seed, placement, partner, tick count or workers retires the displayed comparison. Actions commit pending numeric text before capturing a request, so typing a value and immediately pressing Validate, Compile or Save uses the visible edit. Validation refuses invalid IDs/types, duplicate JSON keys, duplicate slots, unknown or conflicting definitions, invalid/inactive reaction sources, malformed presets, unsupported state/effects and source drift. It uses the frozen compatibility lock without refreshing it. No failure publishes a partial bundle.


### Rank 4: systems/materials-and-rule-kernels.md — Materials and rule kernels > What the material catalogue and Materials Lab currently control

Document: Materials and rule kernels
Path: systems/materials-and-rule-kernels.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native material identity, descriptors, mutable state, kernel execution, current interactions, and extension boundaries
canonical-for: [material-runtime-model, material-kernel-cadence, reactive-material-families]
last-reviewed: 2026-11-24
Section: Materials and rule kernels > What the material catalogue and Materials Lab currently control
At accepted main `00cdb02f`, the canonical authored source and compiler coexist with the production native descriptor/kernel owners. Only specific consumers have migrated; “the catalogue exists” does not mean every runtime property can be hot-swapped. | Surface | Current authority and effect | |---|---| | Material IDs, descriptors, kernels and initial state | Compiled [`material.hpp`](../../native/include/cybersand/material.hpp) and World; IDs0–131 except reserved10 remain unchanged | | Native hard/granular capabilities | `MaterialRules::is_hard_surface` and `supports_granular_load` consume generated [`material_capabilities.hpp`](../../native/include/cybersand/material_capabilities.hpp) maps | | Capability source and validation | [`materials/catalogue/catalogue.json`](../../materials/catalogue/catalogue.json), [`compiler.py`](../../tools/material_catalogue/compiler.py), [`native_capabilities.py`](../../tools/material_catalogue/native_capabilities.py); the generator owns two four-word masks only | | Inspector facts | Copied native catalogue and effective-consumer readback; declaration, consumer and observed outcome remain separate | | Lab candidate | Validated isolated preset and optional external native descriptor/World comparison; `runtime_active=false`, no production candidate installer | | Current-scene audition | Owner-approved direction and separate unmerged implementation work; not the accepted Lab v1 workflow | The Lab only exposes supported effective changes. For example, [`lab.py::supported_fields`](../../tools/material_catalogue/lab.py) admits descriptor viscosity for selected yielding/Cement/MoltenGlass templates; Water-CY uses its applied policy, and Lava/Acid/Oil have specialized movement. Unsupported edits refuse rather than implying that an inert slider changed the World. Extended endpoint effects run only in the admitted compiled-World comparison; the simpler descriptor/resolver probe does not execute them. Synthetic powder132 is an isolated fixture, not a new production material. The [Materials Lab guide](../operations/materials-lab-authoring.md) owns the workflow. The [programme design](../architecture/material-authoring-catalogue-plan.md#current-implementation-and-remaining-design) preserves broader migration plans and their historical admission checkpoints.


### Rank 5: architecture/material-authoring-catalogue-plan.md — Canonical material catalogue and interaction authoring — adopted Planned baseline > 5. Interaction effects and effective parameters > Effective parameter contract

Document: Canonical material catalogue and interaction authoring — adopted Planned baseline
Path: architecture/material-authoring-catalogue-plan.md
authority: current-documentation
document-kind: design
status: Planned
scope: Wider Planned material-authoring migration with a current accepted-slice map; numbered sections preserve dated design/admission checkpoints, not current execution permissions
canonical-for: [material-authoring-v1-programme-proposal]
last-reviewed: 2026-11-24
Section: Canonical material catalogue and interaction authoring — adopted Planned baseline > 5. Interaction effects and effective parameters > Effective parameter contract
`MaterialDefinition.viscosity_index` is a **declared** value; effective motion depends on kernel and any allowed construction-time profiles. Every proposed editable parameter needs: - stable key; declared and effective values; units and validated limits; - owning source/preset/override and identity/version of the applied policy; - **actual consuming kernel/helper** and supported platform/solver; - status `effective`, `unused_by_selected_kernel`, `unsupported`, `planned` or `source_edit_required`; - change class: appearance preview, compile/rebuild, or validated restart-time policy; - revalidation tags, state/quantity impact and save/physical-hash implications. In v1, **do not** present Lava/Acid/Oil descriptor viscosity as an effective freely editable native slider while their specialised paths bypass that value. An inspector can truthfully display the descriptor and an applicability warning. Similarly, do not infer real-world density units from `density`: it is a gameplay comparison value.

## DR11: Can Materials Lab already audition an edited material in my ordinary live Workbench World?

Canonical rank: 1

Expected facts:

- Accepted Materials Lab supports its documented inspection and isolated candidate experiments.
- The current-scene audition successor is unmerged at the recorded source; do not present candidate behavior as shipped.

### Rank 1: operations/materials-lab-authoring.md — Materials Lab v1 > First inspection and safe experiment

Document: Materials Lab v1 inspection, candidate authoring and native tests
Path: operations/materials-lab-authoring.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Accepted desktop native inspection, candidate authoring, isolated World comparisons and existing-material MicroScenarios; no runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-24
Section: Materials Lab v1 > First inspection and safe experiment
1. Open **Inspect**, search **Water**, and compare **Defined value** with **Value used**. Read the consumer/applicability explanation before treating a displayed property as an adjustable simulation input. 2. Open **Try originals** and choose an existing-material case. Run the isolated test and inspect its native result; it does not alter the Workbench canvas. 3. Return to **Inspect**, select **Sand**, and **Duplicate selected**. Change only a supported candidate field in **Edit copy**, then use **Build + check definition** when the compiler tools are configured. 4. Follow [Compare an edited candidate](#compare-an-edited-candidate-in-a-real-native-world) for a real candidate/reference World comparison. Save the material preset if you want to resume editing later. ![Materials Lab's native Water inspector with declared and effective property columns](../images/materials-lab-v1/01-inspector-water.png) *Retained application capture from the original accepted Lab qualification; its [dated record](../audits/2026-11-11-materials-lab-v1.md) retains the exact source/runtime scope. It is not a fresh capture of this documentation change.* The current Lab tests candidates in isolated worlds. A **live current-scene audition** is a separate unmerged programme; no button in this guide installs candidate definitions into the running Workbench. Closing the Lab returns to that same scene.


### Rank 2: reference/product-intent-and-priorities.md — Product intent and priorities > Live materials and layered presentation

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: current-documentation
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > Live materials and layered presentation
**Approved:** Materials Lab should offer approachable material modification and audition in the Workbench scene. Existing isolated comparison tabs are valuable, but they do not alone satisfy the requested current-scene interaction. Which properties have real consumers and can be changed safely remains an engineering question. Never represent an ineffective specialized-kernel property as editable physics. [Materials Lab](../operations/materials-lab-authoring.md) owns current functionality; its audition successor remains separately identified. **Approved:** four-layer **Strata Theatre** should be an available Workbench option. Historical integration exclusions are not permanent rejection. The standalone prototype's exact clocks and event links are not automatically the future Workbench contract. The [depth contract](../systems/depth-layers-and-parallax.md) owns the existing demonstration and [the candidate register](status-and-roadmap.md#active-candidates-and-integration-boundaries) identifies ordinary Workbench integration work.


### Rank 3: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Live materials and layered presentation

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Live materials and layered presentation
**Confirmed:** Materials Lab should support easy material modification and audition, including changing values in a Workbench window for dynamic/custom trials. The existing comparison tabs are appreciated; isolated comparisons alone do not fulfil the desired current-scene interaction. Which properties can apply safely at runtime remains an engineering question. **Confirmed:** the four-layer Strata Theatre presentation should be an available Workbench option. Its visual impact is important. Historical integration exclusions are not a permanent rejection; the prototype's exact clocks and cross-layer event rules are not automatically the eventual product contract.


### Rank 4: reference/status-and-roadmap.md — Status and foundational roadmap > Current implementation map

Document: Status and foundational roadmap
Path: reference/status-and-roadmap.md
authority: current-documentation
document-kind: reference
status: Current
scope: Accepted-main implementation, separately identified candidates, approved direction and unresolved decisions
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-11-24
Section: Status and foundational roadmap > Current implementation map
| Area | Available on the accepted source | Canonical route and important boundary | |---|---|---| | Shared Workbench | One creative workspace for generated/native material scenes, painting, actor setup, Art and inspection | [First session](../operations/workbench-first-session.md); [authoring contract](../architecture/shared-workbench-authoring-data.md). An acknowledged application is different from a queued request. | | Painting and history | Native material tools, selection/copy-paste, bounded edit operations, Undo/Redo and explicit Flatten | [Painting](../operations/workbench-painting-and-history.md). Partial operations, cancellation and history limits retain their actual receipt semantics. | | Architectural generation | GEN-007 project authoring and the accepted 80-Gentek extension alongside established presets | [Generator](../systems/architectural-generator.md); [playtest](../operations/architectural-generator-playtest.md). SWARM negotiation is a separate unmerged programme. | | Materials and reactions | Native material identities, specialized kernels, generated hard/granular capability consumers and bounded reaction rules | [Materials](../systems/materials-and-rule-kernels.md); [catalogue](../systems/building-material-catalogue.md). A declared field is not necessarily an effective runtime control. | | Materials Lab | Material inspection, candidate authoring and admitted isolated native comparisons | [Materials Lab](../operations/materials-lab-authoring.md). Current-scene audition is still an unmerged successor. | | Water | Distinct solver families, unified Water Lab, Wave gameplay profile with spill/ballistic release and accepted Oil interaction work | [Water Lab](../operations/workbench-water-lab.md); [family policy](../architecture/liquid-solver-family-policy.md); [Wave](../architecture/wave-flow-v1.md). Defaults are host/profile specific; the generic native World is not interchangeable with a gameplay preset. | | Actors and equipment | Independent Workbench actor composition and existing physical actor/control/equipment paths | [Actor guide](../operations/workbench-actor-composition.md); [technical contract](../systems/workbench-actor-composition.md). Continuous-play sandbox/pilot/stack repairs remain candidates. | | Art Workbench | Provider-assisted conversation, direct native drawing, receipts, Stop/Hide and one traffic audit per game session | [Art guide](../operations/workbench-art.md); [provider contract](../systems/workbench-art-providers.md). Accepted #727 removed cross-session conversation restore. Local-provider and window repairs remain unmerged. | | Authored persistence | Saved setup/start data and standalone material-baseline files; Flatten captures stored material IDs while preserving the live World | [Saving](../operations/workbench-saving.md); [save/reference formats](level-saves-and-replay.md). Ordinary authored Save is not a complete evolved physical checkpoint. | | Native runtime | C++20 World, sparse storage, bounded phased workers, desktop owner thread and main-thread Rapier/presentation | [Architecture](../architecture/overview.md); [ownership](../architecture/data-ownership-and-lifetimes.md). Failed-world quarantine, explicit capacity outcomes and immutable handoffs remain essential. | | Rendering and recording | Native material snapshots and Godot presentation, with existing recording/diagnostic paths | [Rendering](../architecture/rendering-and-gameplay-bridges.md). Render FPS, tick counters and recorded presentation do not by themselves prove physical progression or complete replay. | | Standalone exhibitions | Deepworks, Blacksite Nine, Neon Reliquary, player playground, Thunderbowl and Strata Theatre retain their own entry points and owners | [Showcases](../operations/showcase-guide.md). Four-layer Strata is not yet ordinary Workbench layer editing. | | World Art | Accepted shared renderer, viewer, capture tools and source-bound evaluator support | [World Art](../tools/art-pipeline-unification.md). Art-only extents and exports


### Rank 5: operations/microscenario-reference-pack.md — MS-001 reference MicroScenario pack > Inspection, control and fresh-reset A/B > Apparatus A/B and authored material tests

Document: MS-001 reference MicroScenario pack
Path: operations/microscenario-reference-pack.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Exploratory Materials Laboratory, Flood-Control Puzzle and Simulation Stress Test definitions on the shared host, with fresh-reset A/B, world-state objectives and bounded telemetry
canonical-for: [microscenario-reference-pack, materials-laboratory-readiness, flood-control-scenario, simulation-stress-test, microscenario-workbench-controls]
last-reviewed: 2026-11-11
Section: MS-001 reference MicroScenario pack > Inspection, control and fresh-reset A/B > Apparatus A/B and authored material tests
Generated apparatus definitions belong to the fresh-reset A/B workflow above: store both complete validated definitions, compare at the same completed tick, and load each through the acknowledged owner reset. The live worker's material physics is unchanged. Inspect temperature through existing stored-cell probes; masked temperature and per-cell sleeping state are not invented. Scheduler work, native tick time, host observation time and whole-frame cost retain their separate telemetry meanings below. For changes to material density or reaction products themselves, the separate [Materials Lab candidate test](materials-lab-authoring.md#compare-an-edited-candidate-in-a-real-native-world) compiles generated material definitions into an external native World and compares them with untouched source. Its finite bay reuses this pack's geometry, with its own explicitly recorded configuration. It does not mutate the live worker, replace the shared host, or establish hash parity with an apparatus A/B capture. Choose the corresponding workflow and retain its source/definition/worker receipt.

## DR12: How do I paint, erase, fill and undo in a first Workbench session?

Canonical rank: 1

Expected facts:

- Use the actual toolbar/tool controls and their bounded operation outcomes.
- Explain history boundaries, partial completion and refusal; never invent shortcuts or unlimited fills.

### Rank 1: operations/workbench-first-session.md — Your first Workbench session > Make room to work

Document: Your first Shared Workbench session
Path: operations/workbench-first-session.md
authority: current-documentation
document-kind: guide
status: Current
scope: A small paused material authoring tutorial with simulation, saving and fresh-session reconstruction
canonical-for: [workbench-first-session]
last-reviewed: 2026-11-24
Section: Your first Workbench session > Make room to work
1. Choose **Pilot → Observer / no human pilot** so actor movement does not distract from editing. 2. Pause with **Play / Pause [P]**. Use the visible button if a text field has focus. Precise shapes, Fill and Undo/Redo require a paused scene. 3. Select **Overview** to locate your work, then zoom in with the mouse wheel. Middle-drag pans. Use an empty part of the canvas away from bodies and sources. 4. In the main tool selector choose **Paint**. The smaller painting row provides Brush, Eraser, Line, Rectangle, Outline, Select, Fill and Paste. The initial canvas is finite. The coordinate controls and status help you stay inside it. There is no need to populate the whole canvas for this exercise.


### Rank 2: systems/paint-editor-bounded-shapes.md — PAINT-001 — bounded painting editor > Using the editor

Document: PAINT-001 native-backed Workbench painting editor
Path: systems/paint-editor-bounded-shapes.md
authority: current-documentation
document-kind: design
status: Current
scope: Mounted Draft PAINT-001 candidate on the shared Workbench; bounded native painting and reconstructible authored starts, not evolved simulation checkpoints
canonical-for: []
last-reviewed: 2026-11-12
Section: PAINT-001 — bounded painting editor > Using the editor
Open the ordinary Workbench and pause. Its existing material picker now contains the loaded native runtime's supported materials. The additional compact tool row provides Brush, Eraser, Line, Rectangle, Outline, Select, Fill and Paste, with Copy, Undo, Redo, Cancel, named Save start and Load start beside it. A gesture queues and completes one operation; the status distinguishes planning, queued, native execution, completion, refusal and partial completion. | Action | Control | | --- | --- | | Freehand / erase | B / E; right-drag also erases | | Straight line / filled rectangle / outline | L / R / O, then drag | | Select a rectangle | S, then drag | | Capture exact selected native materials | Ctrl+C | | Paste the captured stamp | Ctrl+V or V, position preview, click or drag and release | | Four-connected fill | G, then click; a containing selection defines the capture bounds | | Brush radius 0–24 | Existing radius field; `[` / `]` | | Undo / redo | Ctrl+Z / Ctrl+Y or Ctrl+Shift+Z | | Save named authored start | Ctrl+S or Save start | | Cancel preview / stop native operation | Escape or Cancel | Undo/Redo follows the latest edit in the shared manual/agent timeline. The **Art batches** panel exposes the same Undo and Redo actions. Stop an active agent run and wait for its native result, deferred human strokes and provider activity to settle before using either panel's history controls or shortcuts. Tool keys apply to paused painting and respect focused text fields. Existing playing/actor controls retain their input paths. Pan and zoom use the existing host mapping: aspect-fit local coordinates plus the floored camera origin. A camera-button press cancels an unfinished gesture. Leaving the canvas or Escape cancels without committing. There is no second viewport or simulation controller. The overlay shows selection, canonical brush/line/rectangle footprints and multi-material paste, including Empty. Up to 16,384 preview cells/spans are shown exactly; larger previews explicitly show bounds. A copied selection can be pasted repeatedly during the session. There is no disk-backed stamp library yet.


### Rank 3: operations/workbench-painting-and-history.md — Painting and history > A reusable multi-material stamp

Document: Workbench painting, selection and history
Path: operations/workbench-painting-and-history.md
authority: current-documentation
document-kind: guide
status: Current
scope: Current human painting controls, bounded copy and fill, native completion, cancellation and shared Undo/Redo
canonical-for: [workbench-painting-user-guide]
last-reviewed: 2026-11-24
Section: Painting and history > A reusable multi-material stamp
1. Pause and paint a small structure with two materials and a clear opening. 2. Select a rectangle around it and **Copy**. Wait for native capture. 3. Choose **Paste** and move the preview to a clear position entirely within the canvas. Release to apply and wait for completion. 4. Repeat at another position. Undo reverses the latest acknowledged paste. The captured stamp includes Empty, so pasting can erase destination cells. Source and destination may overlap because Copy owns an immutable material snapshot. World replacement invalidates the clipboard; ordinary edits do not rewrite it. A protected or off-canvas destination can refuse the operation. There is no disk-backed stamp library in this editor.


### Rank 4: operations/workbench-first-session.md — Your first Workbench session > Set the materials in motion

Document: Your first Shared Workbench session
Path: operations/workbench-first-session.md
authority: current-documentation
document-kind: guide
status: Current
scope: A small paused material authoring tutorial with simulation, saving and fresh-session reconstruction
canonical-for: [workbench-first-session]
last-reviewed: 2026-11-24
Section: Your first Workbench session > Set the materials in motion
Press **Play / Pause [P]**. Sand should fall into the container. Pause again after observing it. A simulation tick invalidates construction Undo/Redo when the old native state is no longer safe to restore; Undo is not physics rewind. For a Water variation, restore the authored start, pause, select **Water** and paint a small patch. Fresh Workbench sessions select the Wave gameplay profile. Open **Water Lab… → Solvers & scenes** to inspect the requested and applied law. Changing a control stages a request; **Apply solver / tuning** and its native readback establish what actually runs. The [Water Lab guide](workbench-water-lab.md) explains fair comparisons and law-specific limits.


### Rank 5: operations/workbench-first-session.md — Your first Workbench session > Close and reopen

Document: Your first Shared Workbench session
Path: operations/workbench-first-session.md
authority: current-documentation
document-kind: guide
status: Current
scope: A small paused material authoring tutorial with simulation, saving and fresh-session reconstruction
canonical-for: [workbench-first-session]
last-reviewed: 2026-11-24
Section: Your first Workbench session > Close and reopen
1. Wait for all drawing and saving to finish. 2. Use **Menu [F2]** or close Godot. Returning to the launcher closes the session. 3. Open Development workbench again, enter `first-container` and click **Load start**. 4. Wait for reconstruction. Check the material layout and authored actors, then paint a small new mark to confirm the scene is editable. Undo/Redo stacks and the Art conversation are session-local. They are not restored by loading the authored start. A flattened save rebuilds initial material state from stored IDs; it does not resume the previous tick.

## DR13: An Art batch returned queued=true. May I say the cells have been applied and displayed?

Canonical rank: 1

Expected facts:

- Queue acceptance is not native application or visible publication.
- Follow native acknowledgements and applicable session/generation/sequence identity before claiming applied state.

### Rank 1: systems/workbench-direct-art-batches.md — Direct art batches — WB-ART-002 Stage 1 > Ownership, capacities and completion

Document: Direct art batches, WB-ART-002 Stage 1
Path: systems/workbench-direct-art-batches.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged desktop direct drawing candidate, stored-native completion, Stop, shared PAINT ordering and Undo/Redo, authored-start persistence
canonical-for: [workbench-direct-art-batches]
last-reviewed: 2026-11-12
Section: Direct art batches — WB-ART-002 Stage 1 > Ownership, capacities and completion
`art_batch_plan.gd` validates geometry and lazily emits points. Rectangle/disc raster buffers do not grow with the entire drawing. `art_batch_executor.gd` streams one outstanding chunk to the existing `simulation_worker.gd` owner. The existing `MAX_BRUSH_FOOTPRINT_CELLS` (4096) is an internal chunk size, **not** a batch or lifetime edit ceiling. Explicit pixels are not limited to 32. Input/recipe storage still consumes ordinary process memory; this is not a claim of unbounded capacity. No new native storage, native locks or physics is added. The worker applies points with the ordinary native `emit_disc(..., radius=0)` primitive, alongside ordinary brush execution. On the exclusive World thread it checks installed canvas, selected area, protected rectangles and source material: only existing Empty/Hard Wall cells can be overwritten. It reads native material before and after each eligible point and reports actual checked/changed/excluded counts plus per-point readback, World generation and tick. Enabled materials are also checked at queue admission. No main-thread direct World access is added. Queue acceptance is `queued`, never applied. `executing` means the worker has claimed a chunk. Completion follows actual receipts for every chunk; failures or Stop preserve/report a partial prefix. Unchanged points count as checked, not changed. Excluded cells are distinct from failed writes. Readback is bounded to one chunk and consumed, not accumulated as an exhaustible receipt store.


### Rank 2: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Collaboration, scanline and pacing preview

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Collaboration, scanline and pacing preview
Model prompt and Scanline keep a conversation for the mounted workbench. Turns limits requests per Send, including refusals and rate retries. Zero continues until Stop, completion or another limit. Run s adds an optional elapsed-time ceiling. After native completion, the next request can use the actual changed count and world epoch. An empty array ends the run. Stop cancels pending inference, pacing and queued native work. Clear starts a new conversation while the durable traffic retains earlier events. Full includes all text turns and saved images when Image is enabled. Compacted includes the latest twelve entries and discloses omissions. It omits reasoning prefixes from model context while retaining the original replies in traffic. Custom initially uses the same window. None sends no earlier turns. Historical image bytes remain in durable traffic. Image sends the visible intersection of the work area, or the whole visible canvas with Full view. The request includes pixel dimensions and the world rectangle. Identical captures are skipped within a run. Native chunk receipts remain in local traffic. Guidance opens the editable instructions for the selected mode. Scanline takes rows with local y, optional repeat and scale, and spans in [x,length,material] order or named objects with those fields. Omitted spans preserve cells. An explicit zero material erases. The normal executor applies the resulting ordered rectangles. Consecutive shapes of the same material share native chunks up to the existing cell limit. Material changes preserve the original draw and erase order. Gap s sets an optional request interval. HTTP 429 with numeric Retry-After paces subsequent requests to that endpoint. OpenAI request, token and project token reset durations also pace requests when their bucket reports exhaustion. Known billing and spending quota failures require user action. Traffic supports visible filtering and full disk export. Unknown cost remains unknown. On 2026-11-10 the Windows preview passed 113 native checks and 43 checks with LM Studio LFM2.5 1.2B, including a human follow-up and Stop during pacing. The Linux graphical transport fixtures passed for all three providers. The graphical run_art_scanline_vision.gd probe used the loaded LM Studio LFM3 Omni model through a loopback relay. It applied a four-cell wall, then erased its first cell after a second rendered observation. The earlier LFM2.5 text scanline trial returned malformed JSON. The vision test is a constrained placement test. In a separate graphical 64×128 statue trial, wb-art-local sent three requests over 50.5 seconds. The first two changed 226 and 132 native cells. The last returned an empty array. Reported input and output totals were 11,900 and 6,707 tokens. This


### Rank 3: operations/local-build-and-validation.md — Local build and validation > Isolated test data and diagnostics

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Isolated test data and diagnostics
Godot tests and graphical captures must not overwrite the owner's saved scenes, Art traffic or local provider configuration. Use the repository's [isolated Godot runner](../../tools/physics/isolated_godot.py) or the appropriate existing test/capture harness with its own user profile. Inspect that harness's arguments and refusal rules before invoking it; a normal interactive launch intentionally uses the user's ordinary application data. For a useful failure report, record the checkout SHA and dirty state, exact Godot version, native runtime/provenance identity, platform, command, fixture or small synthetic setup, steps, expected result, actual result and whether the operation was queued, applied, displayed or refused. Include the first relevant error and completion status, not only a green process exit. Preserve the original failed result alongside a successful retry. Art prompts, traffic, endpoint credentials and owner maps may be private: inspect and redact attachments, and prefer a synthetic reproduction. [Troubleshooting](troubleshooting.md) covers common launch, focus, runtime and capacity failures.


### Rank 4: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Offset-area repair > 2026-11-11 scanline qualification

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Offset-area repair > 2026-11-11 scanline qualification
RTX local tests at source `e5bf2916` ran the mech-statue prompt twice per installed model on fresh 64×128 native canvases. LFM3 1.7B exhausted 8192 output tokens on reasoning twice; LFM2.5 1.2B returned unusable geometry twice. The installed LFM2.5 8B-A1B variant applied 2344 and 1727 Hard Wall cells in 11.7 and 23.6 seconds, respectively, but rendered inspection did not establish the requested subject. A test-only reasoning-disabled LFM3 request on 256×512 applied 26741 cells in 3.8 seconds, but also failed visual subject assessment. These establish connection and native application outcomes, not artistic acceptance. No production provider settings were changed. The graphical benchmark accepts `WB_ART_BENCH_WIDTH` and `WB_ART_BENCH_HEIGHT`; defaults remain 64×128. Local original replies, native readback images, rendered PNGs and hashes are retained under `build/local-models-20261111/` (not committed).


### Rank 5: systems/workbench-direct-art-batches.md — Direct art batches — WB-ART-002 Stage 1 > Shared Undo and Redo

Document: Direct art batches, WB-ART-002 Stage 1
Path: systems/workbench-direct-art-batches.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged desktop direct drawing candidate, stored-native completion, Stop, shared PAINT ordering and Undo/Redo, authored-start persistence
canonical-for: [workbench-direct-art-batches]
last-reviewed: 2026-11-12
Section: Direct art batches — WB-ART-002 Stage 1 > Shared Undo and Redo
The Art batches Undo/Redo buttons and PAINT's buttons and shortcuts operate on one chronological history. Only confirmed stored-material changes enter it. Adjacent bounded parts of one direct batch or model drawing submission share an action: one Undo reverses the retained parts, and Redo reapplies them in order. A human edit between chunks closes that group and has its own entry. Undo never jumps over later manual work to target an earlier agent action. Use Stop and wait for batch execution, native receipts, deferred human edits, image capture, provider activity and any scheduled follow-up turn to settle. An idle native chunk boundary alone does not enable Undo. After retirement, Undo can reverse the confirmed applied prefix of a stopped drawing; cancelled or unacknowledged suffixes never enter history. The operation uses PAINT's bounded native preflight and receipt path. Its trusted human inverse can restore the recorded materials without granting ordinary agent submissions broader material, source, protected-region or work-area permissions. History retains at most 32 parts and 1,048,576 edit cells, with at most 262,144 cells per part. The UI labels a partially retained group **Agent drawing (retained tail)** and explains when its older part is no longer undoable. No-change agent receipts preserve the existing Redo branch. Simulation, World replacement or another mutation outside the recorded timeline still invalidate history through its generation/revision/tick fence. History is session-local. Confirmed history results append a human canvas-result turn and durable `history_result` event, with applied counts and continuation/refusal status. They do not rewrite earlier model receipts or automatically request another model turn. The chosen conversation/context mode still governs future requests. The existing persistence limits also apply to history replay. Agent streaming does not preflight the entire authored recipe, so a highly fragmented result can exceed 32,768 stamps or the 1 MiB save envelope. Save then refuses, and Undo/Redo can also refuse a target part before writing if its intermediate authored recipe exceeds those limits, even when the eventual group baseline would be compact. The UI reports the actual confirmed progress and refusal; there is no promise of unbounded or atomic rollback for arbitrary agent output.

## DR14: If I press Stop during a long paint or Art operation, does that roll back everything already applied?

Canonical rank: 1

Expected facts:

- Stop cancels pending work according to the contract; already applied work can remain.
- Report partial native receipts/history outcomes and use supported Undo where applicable; do not promise rollback.

### Rank 1: operations/workbench-art.md — Art Workbench > Stop, Hide and native results

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Stop, Hide and native results
**Stop** cancels pending HTTP/capture and scheduled turns, invalidates the request generation and requests the native executor to stop. A native slice already executing can finish at its boundary. A reported **partial** result can therefore have changed the canvas. Read the confirmed count and use available Undo; do not assume cancellation rolled everything back. Closing the Art window **hides** it. It does not mean Stop, save, or end of the Workbench session. Reopen **Art batches** to inspect the same session. For Undo/Redo, Stop first and wait for model, capture, drawing, deferred manual strokes and receipt processing to settle. Both Art and manual controls use the same chronological history. ```mermaid flowchart TD A["Direct JSON or model response"] --> B["Parse and validate drawing"] B --> C["Queue native work"] C --> D["Native slice and stored-material readback"] D --> E["Completed or partial receipt"] E --> F["History and visible result"] S["Stop"] --> C S --> E ``` **Queued is admission, not applied success.** A result from before Reset, Load or World replacement is stale and must not draw into the new scene. Source failures, rejection and missing acknowledgements are not success receipts.


### Rank 2: systems/player-control-playground.md — Player control playground > Acrobat movement chains and cancels

Document: Player control playground
Path: systems/player-control-playground.md
authority: current-documentation
document-kind: contract
status: Current
scope: Experimental movement controls and shared asynchronous desktop composition, input and lap lifetime, lifecycle and bounded native failure validation; isolated Sand and Water player fields
canonical-for: [player-control-playground, player-movement-presets, player-material-field]
last-reviewed: 2026-11-05
Section: Player control playground > Acrobat movement chains and cancels
Afterimage preserves momentum through a low-drag slide and uses actual folding hip/ankle joints for its tucked posture. Steering during slides and rolls is weaker than running; reversing input changes momentum gradually. A held crouch can keep the tuck during a brief loss of support. The controller does not teleport the body or replace its velocity with a character trajectory. - **Run → slide → bullet jump:** gain speed with A/D, hold Shift or S to tuck, aim with the mouse, then press Space. Grounded bullet jumps include an upward component; faster velocity already aligned with the launch is retained. - **Jump → double jump → roll → glide:** Space gives the ground jump and one airborne jump. Press Shift in air for the separate air roll. Hold C near the apex or while falling to reduce descent while steering with A/D. - **Roll → jump cancel:** press Space during a roll to leave it using an available jump. If Shift/S remains held, the same press requests a bullet jump first while that separate launch is available. Release crouch for an ordinary jump cancel. - **Slide/roll → brake cancel:** press C to end the slide or roll. On support, C brakes; slide stays suppressed until crouch is released. Releasing Space early shortens an ordinary jump. Q/E adds airborne attitude trim. The controller supplies a short coyote window and input buffer. One airborne jump, one bullet jump, one air roll and a finite glide reserve recharge after confirmed support, not after focus changes or cancellation. Glide retains positive gravity and has a finite duration; it is not hover. Exact timing and actuation limits belong to the [configuration reference](../reference/configuration-reference.md#player-playground-values). Sources: [acrobat controller](../../godot/scripts/player_acrobat_controller.gd) and [physical rig actuator](../../godot/scripts/physical_actor_rig.gd).


### Rank 3: systems/paint-editor-bounded-shapes.md — PAINT-001 — bounded painting editor > Using the editor

Document: PAINT-001 native-backed Workbench painting editor
Path: systems/paint-editor-bounded-shapes.md
authority: current-documentation
document-kind: design
status: Current
scope: Mounted Draft PAINT-001 candidate on the shared Workbench; bounded native painting and reconstructible authored starts, not evolved simulation checkpoints
canonical-for: []
last-reviewed: 2026-11-12
Section: PAINT-001 — bounded painting editor > Using the editor
Open the ordinary Workbench and pause. Its existing material picker now contains the loaded native runtime's supported materials. The additional compact tool row provides Brush, Eraser, Line, Rectangle, Outline, Select, Fill and Paste, with Copy, Undo, Redo, Cancel, named Save start and Load start beside it. A gesture queues and completes one operation; the status distinguishes planning, queued, native execution, completion, refusal and partial completion. | Action | Control | | --- | --- | | Freehand / erase | B / E; right-drag also erases | | Straight line / filled rectangle / outline | L / R / O, then drag | | Select a rectangle | S, then drag | | Capture exact selected native materials | Ctrl+C | | Paste the captured stamp | Ctrl+V or V, position preview, click or drag and release | | Four-connected fill | G, then click; a containing selection defines the capture bounds | | Brush radius 0–24 | Existing radius field; `[` / `]` | | Undo / redo | Ctrl+Z / Ctrl+Y or Ctrl+Shift+Z | | Save named authored start | Ctrl+S or Save start | | Cancel preview / stop native operation | Escape or Cancel | Undo/Redo follows the latest edit in the shared manual/agent timeline. The **Art batches** panel exposes the same Undo and Redo actions. Stop an active agent run and wait for its native result, deferred human strokes and provider activity to settle before using either panel's history controls or shortcuts. Tool keys apply to paused painting and respect focused text fields. Existing playing/actor controls retain their input paths. Pan and zoom use the existing host mapping: aspect-fit local coordinates plus the floored camera origin. A camera-button press cancels an unfinished gesture. Leaving the canvas or Escape cancels without committing. There is no second viewport or simulation controller. The overlay shows selection, canonical brush/line/rectangle footprints and multi-material paste, including Empty. Up to 16,384 preview cells/spans are shown exactly; larger previews explicitly show bounds. A copied selection can be pasted repeatedly during the session. There is no disk-backed stamp library yet.


### Rank 4: systems/paint-editor-bounded-shapes.md — PAINT-001 — bounded painting editor > Ownership and native execution

Document: PAINT-001 native-backed Workbench painting editor
Path: systems/paint-editor-bounded-shapes.md
authority: current-documentation
document-kind: design
status: Current
scope: Mounted Draft PAINT-001 candidate on the shared Workbench; bounded native painting and reconstructible authored starts, not evolved simulation checkpoints
canonical-for: []
last-reviewed: 2026-11-12
Section: PAINT-001 — bounded painting editor > Ownership and native execution
PAINT owns `workbench_paint_editor_{shapes,controller,overlay,executor,history}.gd` and its tests. The coordinated shared integration adds a small mount/input seam to `shared_workbench.gd` and a bounded operation seam to `simulation_worker.gd`. The existing worker remains the only live native World owner. Planning uses a separate value-only GDScript thread; that thread never accesses the World. The lifecycle and consumed-receipt pattern were reviewed against agent-art #560 at `293dde66efbf5451dacb117080713cca2ac97449`. No provider/controller architecture, agent branch or agent-only Empty/Hard Wall policy is imported. Human material admission comes from the loaded native bridge's `inspect_interaction` authority. At this source identity it admits 131 IDs: 0–131 excluding reserved slot 10. MAT-AUTH definitions, material IDs, native physics and Rapier behaviour are unchanged. The later #560 head `36d7686dff5beef35e04d009677665618f6ef920` was also inspected; its worker seam is unchanged from that reviewed source. `paint_queue` accepts one bounded edit or capture. Admission reports `queued`, not success. An edit contains unique row-major integer x/y/material triples; a capture contains a bounded rectangle. There is one pending operation and one unconsumed result slot, not an unbounded chain of old brush commands. The legacy `queue_emit_cells` 4,096-cell/eight-command limit remains intact. Every request carries generation, revision and tick. The worker rechecks those identities, pause, settings, current scenario tool permission, native bounds, material authority, protected source rectangles and optional caller source-ID policy. It preflights the entire operation before writing. Applying and capture advance in slices of at most 4,096 cells, with a 262,144-cell operation limit. Existing brush queue admission cannot interleave with these operations. Native `stored_material_at` supplies stored material identity in the integrated candidate. Every covered rigid-body cell is still explicitly refused before capture or editing; stored Empty beneath a body grants no editing permission. The source-matched API is required before any write. This also works beyond the diagnostic bridge's 1,024-coordinate limit. RG8 colour, Water dithering and ballistic overlays are never interpreted as stored IDs. Each written cell is read back. The immutable result reports operation ID, requested/applied counts, actual applied prefix, prior and resulting material IDs, source identity and recovery possibility. Stop, source replacement, revision change or a native mismatch cannot become a false completed acknowledgement. A cancelled operation with writes reports `partial`; it is not an atomic rollback. The UI records a representable acknowledged prefix and offers Undo when its source is still valid. If that prefix exceeds persistence limits, Save and new authoring remain held until recovery or Restore start. A retained-World actor/settings change cannot clear that hold. Stopping recovery also keeps Save blocked.


### Rank 5: systems/workbench-direct-art-batches.md — Direct art batches — WB-ART-002 Stage 1 > Shared Undo and Redo

Document: Direct art batches, WB-ART-002 Stage 1
Path: systems/workbench-direct-art-batches.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged desktop direct drawing candidate, stored-native completion, Stop, shared PAINT ordering and Undo/Redo, authored-start persistence
canonical-for: [workbench-direct-art-batches]
last-reviewed: 2026-11-12
Section: Direct art batches — WB-ART-002 Stage 1 > Shared Undo and Redo
The Art batches Undo/Redo buttons and PAINT's buttons and shortcuts operate on one chronological history. Only confirmed stored-material changes enter it. Adjacent bounded parts of one direct batch or model drawing submission share an action: one Undo reverses the retained parts, and Redo reapplies them in order. A human edit between chunks closes that group and has its own entry. Undo never jumps over later manual work to target an earlier agent action. Use Stop and wait for batch execution, native receipts, deferred human edits, image capture, provider activity and any scheduled follow-up turn to settle. An idle native chunk boundary alone does not enable Undo. After retirement, Undo can reverse the confirmed applied prefix of a stopped drawing; cancelled or unacknowledged suffixes never enter history. The operation uses PAINT's bounded native preflight and receipt path. Its trusted human inverse can restore the recorded materials without granting ordinary agent submissions broader material, source, protected-region or work-area permissions. History retains at most 32 parts and 1,048,576 edit cells, with at most 262,144 cells per part. The UI labels a partially retained group **Agent drawing (retained tail)** and explains when its older part is no longer undoable. No-change agent receipts preserve the existing Redo branch. Simulation, World replacement or another mutation outside the recorded timeline still invalidate history through its generation/revision/tick fence. History is session-local. Confirmed history results append a human canvas-result turn and durable `history_result` event, with applied counts and continuation/refusal status. They do not rewrite earlier model receipts or automatically request another model turn. The chosen conversation/context mode still governs future requests. The existing persistence limits also apply to history replay. Agent streaming does not preflight the entire authored recipe, so a highly fragmented result can exceed 32,768 stamps or the 1 MiB save envelope. Save then refuses, and Undo/Redo can also refuse a target part before writing if its intermediate authored recipe exceeds those limits, even when the eventual group baseline would be compact. The UI reports the actual confirmed progress and refusal; there is no promise of unbounded or atomic rollback for arbitrary agent output.

## DR15: Does ordinary Save restore the exact next tick, moving actors, solver queues and private Art conversation?

Canonical rank: None

Expected facts:

- Authored setup/layout persistence differs from exact evolved physical continuation.
- Do not promise all live actors, queues or provider/conversation state; consult explicit format and separate checkpoint contracts.

### Rank 1: reference/status-and-roadmap.md — Status and foundational roadmap > Current implementation map

Document: Status and foundational roadmap
Path: reference/status-and-roadmap.md
authority: current-documentation
document-kind: reference
status: Current
scope: Accepted-main implementation, separately identified candidates, approved direction and unresolved decisions
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-11-24
Section: Status and foundational roadmap > Current implementation map
| Area | Available on the accepted source | Canonical route and important boundary | |---|---|---| | Shared Workbench | One creative workspace for generated/native material scenes, painting, actor setup, Art and inspection | [First session](../operations/workbench-first-session.md); [authoring contract](../architecture/shared-workbench-authoring-data.md). An acknowledged application is different from a queued request. | | Painting and history | Native material tools, selection/copy-paste, bounded edit operations, Undo/Redo and explicit Flatten | [Painting](../operations/workbench-painting-and-history.md). Partial operations, cancellation and history limits retain their actual receipt semantics. | | Architectural generation | GEN-007 project authoring and the accepted 80-Gentek extension alongside established presets | [Generator](../systems/architectural-generator.md); [playtest](../operations/architectural-generator-playtest.md). SWARM negotiation is a separate unmerged programme. | | Materials and reactions | Native material identities, specialized kernels, generated hard/granular capability consumers and bounded reaction rules | [Materials](../systems/materials-and-rule-kernels.md); [catalogue](../systems/building-material-catalogue.md). A declared field is not necessarily an effective runtime control. | | Materials Lab | Material inspection, candidate authoring and admitted isolated native comparisons | [Materials Lab](../operations/materials-lab-authoring.md). Current-scene audition is still an unmerged successor. | | Water | Distinct solver families, unified Water Lab, Wave gameplay profile with spill/ballistic release and accepted Oil interaction work | [Water Lab](../operations/workbench-water-lab.md); [family policy](../architecture/liquid-solver-family-policy.md); [Wave](../architecture/wave-flow-v1.md). Defaults are host/profile specific; the generic native World is not interchangeable with a gameplay preset. | | Actors and equipment | Independent Workbench actor composition and existing physical actor/control/equipment paths | [Actor guide](../operations/workbench-actor-composition.md); [technical contract](../systems/workbench-actor-composition.md). Continuous-play sandbox/pilot/stack repairs remain candidates. | | Art Workbench | Provider-assisted conversation, direct native drawing, receipts, Stop/Hide and one traffic audit per game session | [Art guide](../operations/workbench-art.md); [provider contract](../systems/workbench-art-providers.md). Accepted #727 removed cross-session conversation restore. Local-provider and window repairs remain unmerged. | | Authored persistence | Saved setup/start data and standalone material-baseline files; Flatten captures stored material IDs while preserving the live World | [Saving](../operations/workbench-saving.md); [save/reference formats](level-saves-and-replay.md). Ordinary authored Save is not a complete evolved physical checkpoint. | | Native runtime | C++20 World, sparse storage, bounded phased workers, desktop owner thread and main-thread Rapier/presentation | [Architecture](../architecture/overview.md); [ownership](../architecture/data-ownership-and-lifetimes.md). Failed-world quarantine, explicit capacity outcomes and immutable handoffs remain essential. | | Rendering and recording | Native material snapshots and Godot presentation, with existing recording/diagnostic paths | [Rendering](../architecture/rendering-and-gameplay-bridges.md). Render FPS, tick counters and recorded presentation do not by themselves prove physical progression or complete replay. | | Standalone exhibitions | Deepworks, Blacksite Nine, Neon Reliquary, player playground, Thunderbowl and Strata Theatre retain their own entry points and owners | [Showcases](../operations/showcase-guide.md). Four-layer Strata is not yet ordinary Workbench layer editing. | | World Art | Accepted shared renderer, viewer, capture tools and source-bound evaluator support | [World Art](../tools/art-pipeline-unification.md). Art-only extents and exports


### Rank 2: operations/workbench-art.md — Art Workbench > Conversation and private traffic

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Conversation and private traffic
Each new Workbench session starts with an empty in-memory conversation. Hiding and reopening Art within that session keeps it; ending the session discards it. Provider/model/endpoint/control preferences can persist in `user://art-provider.cfg`. Previous conversations are not automatically restored. The first log event creates one new JSONL file under `user://art-traffic/`. Requests, responses, direct programs and native results append there for the session. **Traffic…** shows the path, a readable or Raw JSONL view, filtering, copy and **Save full JSONL…** export. Old archives are preserved on disk but are not attached to a new session. Logs are evidence for manual diagnosis, not exact replay of an evolving World. The logger redacts known key/bearer patterns and configured credentials, but prompts, model replies, canvas images and other private content remain sensitive. Inspect and redact a diagnostic extract before sharing it. An endpoint is the destination for its request and credentials; automatic HTTP redirects are disabled. Never paste unrelated secrets into a prompt.


### Rank 3: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Diagnostics and retention > Session-scoped, write-only Art traffic — 22 November 2026

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Diagnostics and retention > Session-scoped, write-only Art traffic — 22 November 2026
Each **new Workbench game session begins with an empty in-memory Art conversation**. The Send, Conversation and direct drawing controls never reopen, link, scan or copy traffic from a previous process or Workbench scene. The user can maintain multi-turn context *within the current session*; closing the session discards the in-memory conversation. Model/provider/endpoint/control preferences may still persist in `user://art-provider.cfg`, but no `traffic_path` is read or published. The obsolete profile pointer is removed on the next successful preferences save. On the first Art log event, the existing bounded writer creates **one new root JSONL** under `user://art-traffic/`. All following requests, provider responses, native results and in-session conversation changes append to that same file until the Workbench session ends. Hiding and reopening the Art window within the same Workbench does not create a second log. There is no automatic replay, linked predecessor, history-resume gate or full-history duplication. An unavailable, corrupt or deleted older log cannot prevent Send. Each model request writes a redacted `request_parameters` event containing the provider/model/endpoint, prompt, guidance, requested work rectangle, allowed materials, protected areas, enabled tools, token/time/turn limits and relevant image/context settings. The normal request/response/native receipt events follow. Direct JSON painting records `manual_program`, `manual_admission` and terminal `manual_result`. This provides the values needed for manual re-entry later; it does **not** promise to reproduce an evolving World from prompts alone or retain exact unlogged source World state. `Traffic…` displays the current session file path and can explicitly export it. Existing legacy and linked archives remain **unchanged** on disk, but are never attached to a new game session. The legacy archive parser remains available for standalone read-only diagnostics and old evidence tests; it is not part of the normal UI lifecycle. No automatic migration, deletion or cleanup is performed. PAINT's native authoritative Undo/Redo is independent of Art. When an Art window exists, confirmed Undo/Redo events may be appended to its current session log. Without an Art session, native editing does not force the Art panel or create a cross-session receipt journal. Old `user://art-pending-history` records are preserved as historical data and never injected into a new session. Disk logging failures remain visible, but must not retroactively repeat a native edit. **Scope boundary:** This is session-local authoring history, not a durable conversation database. Save/Open for the authored World and PAINT's own material history retain their existing independent contracts. New model requests must never trust a stale previous-session continuation pointer.


### Rank 4: operations/cybersand-codex-development-handover.md — Development handover > Choose the correct owning contract

Document: Development handover
Path: operations/cybersand-codex-development-handover.md
authority: current-documentation
document-kind: guide
status: Current
scope: Current task intake, ownership and handoff; implementation status, intent and qualification have separate canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-11-24
Section: Development handover > Choose the correct owning contract
| Task | Read first | Preserve | |---|---|---| | Painting, generator application, Art drawing or history | [Shared authoring](../architecture/shared-workbench-authoring-data.md), [direct batches](../systems/workbench-direct-art-batches.md) | Baseline/revision identity, one edit ordering, native completion receipts, bounded cancellation and history semantics. | | Save, Flatten or persistent-area work | [Save formats](../reference/level-saves-and-replay.md), [owner Save intent](../reference/product-intent-and-priorities.md#save-flatten-and-compatibility) | Authored layout versus live physical state; Flatten is a two-byte material plane and does not reset the live World. Persistent-area candidates have separate owners. | | Materials, Water, reactions or Lab | [Materials](../systems/materials-and-rule-kernels.md), [Water families](../architecture/liquid-solver-family-policy.md), [Lab](materials-lab-authoring.md) | Material identity, effective consumers, family-specific quantity/physics, immutable compatibility evidence and reviewed source transitions. | | Actors, equipment or destruction | [Actor composition](../systems/workbench-actor-composition.md), [coupling](../architecture/rigid-body-and-cellular-coupling.md) | Main-thread Rapier, native material authority, producer leases and actual accepted capabilities. ObjectShard/actor/equipment successors remain separate candidates. | | Rendering, scheduling or physical progression | [Threading](../architecture/simulation-tick-and-threading.md), [rendering](../architecture/rendering-and-gameplay-bridges.md) | Snapshot lifetime, accepted worker ownership, physical progression evidence and public receipt identity. PUBPRES findings do not silently select a new architecture. | | Strata or scene depth | [Depth layers](../systems/depth-layers-and-parallax.md), [semantic planes](../systems/procedural-semantic-planes.md) | Standalone layered owners versus ordinary Workbench integration; Strata Theatre names the four-layer feature only. | | Provider integration | [Art providers](../systems/workbench-art-providers.md), [Art guide](workbench-art.md) | Current session-only lifetime, actual transport/receipt states, credentials and private traffic boundaries. No paid dispatch from a documentation test. | | Build, qualification or publication | [Build](local-build-and-validation.md), [release](github-development-and-release.md), [validation](testing-validation-and-replay.md) | Exact source/artifact/platform evidence, mandatory tests, guarded publication leases and explicit owner merge authority. |


### Rank 5: operations/workbench-first-session.md — Your first Workbench session > Close and reopen

Document: Your first Shared Workbench session
Path: operations/workbench-first-session.md
authority: current-documentation
document-kind: guide
status: Current
scope: A small paused material authoring tutorial with simulation, saving and fresh-session reconstruction
canonical-for: [workbench-first-session]
last-reviewed: 2026-11-24
Section: Your first Workbench session > Close and reopen
1. Wait for all drawing and saving to finish. 2. Use **Menu [F2]** or close Godot. Returning to the launcher closes the session. 3. Open Development workbench again, enter `first-container` and click **Load start**. 4. Wait for reconstruction. Check the material layout and authored actors, then paint a small new mark to confirm the scene is editable. Undo/Redo stacks and the Art conversation are session-local. They are not restored by loading the authored start. A flattened save rebuilds initial material state from stored IDs; it does not resume the previous tick.

## DR16: What does Flatten Bake History store, and should plants stop growing automatically afterwards?

Canonical rank: 1

Expected facts:

- The material baseline stores uint16 material identities, two bytes per cell, without preserving full live simulation metadata.
- Flatten history and authored Save are distinct; do not promise plant energy reset or exact physical continuation unless source implements it.

### Rank 1: operations/gen008-flatten-qualification.md — Flatten / Bake History evaluation > Windows owner acceptance

Document: Flatten and Bake History qualification and owner evaluation
Path: operations/gen008-flatten-qualification.md
authority: current-documentation
document-kind: runbook
status: Current
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-24
Section: Flatten / Bake History evaluation > Windows owner acceptance
Download the source-matched evaluation ZIP identified in the dated record or PR. Verify its SHA-256, extract the complete archive into a new writable folder with a short path, and run **Open Workbench.cmd**. Keep the included source, dependencies and qualification records together. The full package also includes the accepted Materials Lab authoring tools; its separate launcher remains available. 1. Open **New from generator…**, select a real profile and install a map. Paint several materials, erase some cells, and alternate a few manual and agent edits. 2. Run simulation long enough to move or transform material. Move an actor or let it fall, then click **Flatten / Bake History…** and confirm. Observe that the live simulation continues, actors retain their motion and no tick-zero restart occurs. The previous Undo history should now be empty. 3. Pause. Paint a distinctive new mark and erase part of the flattened map. Add a small agent mark. Undo and Redo the subsequent operations in chronological order. 4. Explicitly **Save start [Ctrl+S]** under a new name. Completely exit Godot. 5. Launch again and Load that name. The flattened material layout and subsequent acknowledged edits should return without regenerating the former profile. Actor spawns/settings reconstruct normally; transient physics from the earlier process is not expected to resume. 6. Continue painting and agent authoring, Undo/Redo those new edits, and try Restore start. Confirm ordinary input, Fill, Copy/Paste, generator preview and Materials Lab remain usable. 7. Start a longer drawing operation, attempt Flatten while it is pending, then Stop/wait for acknowledgement and retry. The refusal must explain why; no old history or existing save may disappear during a refused/cancelled preparation. Report the evaluation source SHA, ZIP SHA-256, saved name and exact steps for any failure. Automated graphical frames do not substitute for this owner interaction.


### Rank 2: operations/gen008-flatten-qualification.md — Flatten / Bake History evaluation > What Flatten does

Document: Flatten and Bake History qualification and owner evaluation
Path: operations/gen008-flatten-qualification.md
authority: current-documentation
document-kind: runbook
status: Current
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-24
Section: Flatten / Bake History evaluation > What Flatten does
**Flatten / Bake History…** makes the current native stored material layout the new authored baseline and retires earlier construction instructions and Undo/Redo history. The same live native World, tick, fluid quantities, temperatures, velocities and physical actors continue unchanged. Empty and every currently supported material ID use a complete row-major unsigned 16-bit little-endian plane. Flatten does not Save. New acknowledged paint and agent edits are recorded relative to that baseline. **Save start [Ctrl+S]** later saves the material baseline and those edits. Simulation after Flatten is excluded unless another explicit Flatten captures it. Reopening constructs ordinary initial material and actor state; the file is not a simulation checkpoint. For example, Plant reloads with ordinary initialized state; a captured Plant material ID does not preserve its previous energy or growth state. Existing Setup-v2 and generated-start-v1 files retain their original readers and meanings. The confirmation identifies the discarded history. While capture is pending, the same compact control offers **Cancel Flatten**. Pending human or agent work must finish or be stopped and acknowledged before Flatten. Refusal/cancellation leaves the prior authored start and existing saves intact. Retry after the reported owner operation settles; an incomplete capture never becomes the new baseline.


### Rank 3: operations/gen008-flatten-qualification.md — Flatten / Bake History evaluation

Document: Flatten and Bake History qualification and owner evaluation
Path: operations/gen008-flatten-qualification.md
authority: current-documentation
document-kind: runbook
status: Current
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-24
Section: Flatten / Bake History evaluation
Flatten is accepted implementation from [PR #572](https://github.com/techrote/cybersand/pull/572), implementing issue [#548](https://github.com/techrote/cybersand/issues/548)'s 11 November contract. Start with the practical [saving guide](workbench-saving.md) for ordinary use. This page retains qualification/recovery procedures and links to the original source-bound evidence; it does not place accepted implementation under the original candidate merge hold. The [dated evidence](../audits/2026-11-13-gen008-flatten-qualification.md) records actual source identities, successful and failed runs, performance and remaining physical-evaluation limits. Commands and listed coverage do not assert a new passing run. Automated qualification, owner graphical acceptance and permission to merge a successor remain separate decisions.


### Rank 4: operations/gen008-flatten-qualification.md — Flatten / Bake History evaluation > Reproduce focused tests

Document: Flatten and Bake History qualification and owner evaluation
Path: operations/gen008-flatten-qualification.md
authority: current-documentation
document-kind: runbook
status: Current
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-24
Section: Flatten / Bake History evaluation > Reproduce focused tests
Build the source-matched native extension first using the repository's pinned build scripts. A retained runtime built before the new bulk APIs is insufficient. The source-based native targets are: ```bash make material-baseline-test make material-baseline-sanitize ``` For a local Linux diagnostic (use the actual Godot 4.7 executable): ```bash python3 tools/ci/run_flatten_qualification.py \ --godot /absolute/path/Godot_v4.7-stable_linux.x86_64 \ --project godot --evidence /absolute/path/flatten-local --headless ``` For a source-built Windows checkout in PowerShell: ```powershell python tools/ci/run_flatten_qualification.py --godot C:/Godot_v4.7-stable_win64_console.exe --project godot --evidence C:/CyberSand-Flatten-Evidence ``` A focused iteration may use `--cases 512x1`. The final workflow retains the complete case matrix and accepted regression families. Headless/local diagnostic results must be labelled separately from pinned hosted Windows/Linux graphical execution. When given the Windows console launcher path, the measured Flatten runner invokes its sibling engine executable from the same pinned archive directly. The original requested path, actual engine path/SHA-256 and measured PID remain in the result.


### Rank 5: operations/gen008-flatten-qualification.md — Flatten / Bake History evaluation > Recovering after a native owner fault

Document: Flatten and Bake History qualification and owner evaluation
Path: operations/gen008-flatten-qualification.md
authority: current-documentation
document-kind: runbook
status: Current
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-24
Section: Flatten / Bake History evaluation > Recovering after a native owner fault
If the native simulation reports a fault, keep the application open and explicitly **Save start [Ctrl+S]**. A settled authored document can be saved even when its flattened baseline has not previously been written to disk. The saved content is the retained baseline, acknowledged edits and supported actor/configuration data. Save does not capture the failed World or include simulation changes since Flatten. The success message confirms that the native owner remains failed. Pending edits, unconsumed completion receipts, partial edits, prepared replacements and pending Flatten still block Save. Follow the stated refusal; the recovery path does not bypass those guards. A failed Save preserves the prior valid named file. Save also refuses after owner failure if the document contains any four-field legacy disc instruction: its native execution has no individual acknowledgement. The refusal retains all authored data. A flattened baseline with acknowledged PAINT/Art edits can use the recovery route when the remaining guards are settled. Healthy Save and the existing legacy readers retain their original behavior. After Save succeeds, completely exit, restart and Load the saved name. The new process reconstructs an ordinary authored start with normal initial physics. Flatten and editing remain unavailable on the failed owner. Reset / R and Restore start also refuse their unsafe recipe-only recovery path for generated or flattened starts, with guidance to Save, restart and Load.

## DR17: Are eighty Genteks current, and what are Gentek, Variant, Preset and Composition?

Canonical rank: 1

Expected facts:

- Accepted catalogue and controls are source-backed and separate from unmerged SWARM negotiation.
- Use the owner terminology without implying live Workbench Gentek rule authoring or every future Composition capability.

### Rank 1: operations/architectural-generator-playtest.md — Architectural Generator walkthrough > Choose a Gentek and its parameters

Document: Architectural Generator walkthrough
Path: operations/architectural-generator-playtest.md
authority: current-documentation
document-kind: guide
status: Current
scope: Accepted native Architectural Generator, Gentek catalogue, preview, installation and authored save workflow
canonical-for: [architectural-generator-owner-evaluation]
last-reviewed: 2026-11-24
Section: Architectural Generator walkthrough > Choose a Gentek and its parameters
A **Gentek** is a native architectural generator technique. A **variant** changes its admitted geometry, material or aperture parameters. A **preset** is a named starting configuration. A **composition** assigns styles to zones of one map. These terms describe authoring choices; they do not promise structural stability or navigable routes through every generated crop. The chooser has **80 Genteks plus 13 earlier architectural presets**. Use **Find style…** in a card to narrow by name, family or theme. The [visual catalogue](../images/gentek80-integration/README.md) makes the differences between frames, trusses, vaults, spines and suspended structures easier to see. Five cards support one to five enabled styles; unused cards may stay disabled. For a first scene: 1. Choose **Map 512²**, **Zone 64**, and seed **271828**. The architectural form offers 512² and 1024², even though a fresh blank Workbench is 2048². 2. Enable only card **#1**, choose **Cathedral Megaframe**, and set its share to **100%**. Keep the preset's geometry initially. 3. Turn **Tunnels** off and leave **Doors** and **Windows** on. The switches control independent automatic cuts; a door here is a material aperture. 4. Click **Generate preview**. Wait for completion in the parent generator window, then inspect the material map. Generation does not replace the scene. 5. Return to **Architectural Generator…**, change a geometry parameter offered for that style, regenerate and compare. Keep the seed fixed while comparing one parameter. A disabled or inapplicable field is not an effective control. ![Interlaced Viaduct showing masonry arches intertwined with suspended metal galleries](../images/docs-renaissance/gentek-interlaced-viaduct-native.png) *Interlaced Viaduct, the same accepted-source headless capture scope and seed. Material geometry is native output; physical load-bearing is not inferred.*


### Rank 2: reference/glossary.md — Glossary > Authoring and acceptance

Document: Glossary
Path: reference/glossary.md
authority: current-documentation
document-kind: contract
status: Current
scope: Short definitions and canonical routes; implemented types, planned concepts and evidence terms are distinguished
canonical-for: [project-terminology]
last-reviewed: 2026-11-24
Section: Glossary > Authoring and acceptance
| Term | Meaning and canonical route | |---|---| | Gentek | An architectural generator family; an accepted catalogue entry is distinct from an experimental assembly solver. [Architectural generator](../systems/architectural-generator.md) | | Variant | A version or alternative within a Gentek family, such as v1/v2/v3; it does not itself establish acceptance | | Preset | Saved geometry, material and modifier choices; inspect its schema and the receiving build's admission | | Composition | Multiple Genteks combined; negotiated SWARM assembly is a separate candidate scope | | Authored start | Reconstruction baseline plus supported ordered edits/spawns/options; not the entire evolving World. [Shared data](../architecture/shared-workbench-authoring-data.md) | | Flatten / Bake History | Capture native stored material IDs into a two-byte-per-cell authored baseline; discard earlier construction/Undo history, leave the live World unchanged, then Save explicitly | | Native receipt | An owner-produced result for an identified operation; queue acceptance and model output are not application receipts | | Source-qualified candidate | Evidence applies to an identified source/artifact/platform; the work may remain unmerged | | Accepted main | Repository implementation available at a stated main commit; does not make all historical validation current | | Physical owner acceptance | A stated human evaluation on its actual platform; headless or hosted software-rendered execution does not substitute for it | | Strata Theatre | The existing four-layer depth feature and its named integration programme; not a name for storage or unrelated archaeology |


### Rank 3: systems/architectural-generator.md — Architectural Generator — Phase A and bounded Phase B

Document: Architectural Generator Phase A and B
Path: systems/architectural-generator.md
authority: current-documentation
document-kind: contract
status: Current
scope: Opt-in schema-4 architectural controls, versioned native geometry and bounded one-to-five-style project compilation
canonical-for: [architectural-generator-controls, architectural-style-projects, architectural-zone-coverage]
last-reviewed: 2026-11-24
Section: Architectural Generator — Phase A and bounded Phase B
**Current accepted source, 24 November 2026 (`00cdb02f`).** The schema-4 Architectural Generator foundation (#582) and the 80-Gentek integration (#691) are merged. Earlier Draft/HOLD instructions below describe their original qualification checkpoints, not today's implementation availability. The separate [Gentek-80 evaluator](../operations/gentek80-evaluation.md) remains a source-qualified evaluation workflow; its PR and physical owner acceptance are not implied by the catalogue's presence on main. The normal route is **Shared Workbench → New from generator → Architectural Generator**. A bounded declarative project compiler plans one to five style zones; native GEN-007 produces the material geometry. Preview is separate from the live World. Explicit installation uses the prepared World transaction; **Save project** saves the generation recipe, while **Save start** saves the installed authored start and supported edits. The [practical guide](../operations/architectural-generator-playtest.md) covers those distinct operations. | Term | Meaning in the current authoring path | |---|---| | Gentek | A named native architectural generator/sampler, such as Cathedral Megaframe. | | Variant | A variation of a Gentek's geometry or parameters; it is not necessarily a separately versioned native module. | | Preset | A saved parameter/material configuration. The menu has 93 built-in presets: 13 earlier presets plus 72 CLASSIC and eight advanced Genteks. | | Composition | A bounded project combining up to five configured styles and their assigned zones into one native recipe and World. | These author-facing terms do not rename serialized fields: the project still stores `styles`, and native modules retain their explicit `module_version`. SWARM negotiation and self-assembly are separate pending work. Native geometry alone does not establish structural load capacity or physical playfeel. Source owners are [`architectural_generator_project.gd`](../../godot/scripts/architectural_generator_project.gd), [`architectural_generator_dialog.gd`](../../godot/scripts/architectural_generator_dialog.gd), [`world_generation.cpp`](../../native/src/world_generation.cpp) and [`CyberWorldGenerator::get_catalogue`](../../godot/native_extension/cyber_world_generator.cpp). The [80-style integration research](../operations/gentek-showcase-integration-001.md) retains exact source and image provenance from the original qualification. The [dated local qualification record](../audits/2026-11-14-architectural-generator-local.md) retains source identities, numerical comparisons and original native previews. The [15 November runtime completion record](../audits/2026-11-15-gen007-runtime-completion.md) separately binds the integrated source, actual Windows/Linux execution, retained libraries and independently verified Windows owner package.


### Rank 4: systems/architectural-generator.md — Architectural Generator — Phase A and bounded Phase B > 80-Gentek integration candidate — 20 November 2026

Document: Architectural Generator Phase A and B
Path: systems/architectural-generator.md
authority: current-documentation
document-kind: contract
status: Current
scope: Opt-in schema-4 architectural controls, versioned native geometry and bounded one-to-five-style project compilation
canonical-for: [architectural-generator-controls, architectural-style-projects, architectural-zone-coverage]
last-reviewed: 2026-11-24
Section: Architectural Generator — Phase A and bounded Phase B > 80-Gentek integration candidate — 20 November 2026
**Historical integration checkpoint, subsequently accepted through #691.** The `integration/gentek-80-001` candidate started from accepted main `de109d01` and reconciles repaired CLASSIC `e27ff757` with the eight-showcase aggregation `eb786d97`. It added **80 Genteks (72 CLASSIC and eight advanced showcases)** without removing the thirteen accepted presets: the ordinary form has **93 selectable presets**, while native metadata has **91 module/version entries**. All additions use the existing schema-4 native project path and single World. The [evaluation guide](../operations/gentek80-evaluation.md) describes selection, controls, source-bound packaging and the manual Test It procedure. Each of the five style cards has a **Find style** filter matching name, family and theme. Filtering keeps the current selection available, changes no project parameters, and uses stable catalogue identities when a filtered item is chosen. Clearing it restores the full list. The existing geometry, global apertures, material-role imports, preview/Stop, explicit install and authored-start saving retain their ordinary ownership. Suspended Deck carrier contacts and steep Rib Vault cardinal continuity use the repaired CLASSIC definitions. Showcase imports cannot replace these with older equivalents. Catalogue/schema contracts enumerate the expected identities independently; repaired-parent material oracles are measured from isolated `e27ff757` source. Arched Viaduct v1/v2 and the other accepted geometry versions remain unchanged. Generator inputs use the accepted material catalogue. The integration's visual review additionally found four inherited support defects. Ring Pier now joins its open diamond to both decks; Tripod Frame has continuous transfer support between tiers; Cascade Terrace has a rear core behind its staggered platforms; Scalloped Vault uses a local slope-aware stroke to keep thin quadratic ribs connected. Suspended Deck and Buttress Wall keep their complete existing glass panes and add frames connected to their structure. These six deliberate refinements have explicit before/after references; the remaining 66 CLASSIC definitions retain their authoritative material output. None of these checks asserts engineering load capacity. Gallery exporters compile every translation unit afresh in private directories keyed by source and compiler identity. `--no-build` validates driver, frontend, assembler/linker, version, target, environment, source/flags and executable hash. A compiler switch or missing/mismatched record is refused rather than relabelled. The separate compiler-switch regression uses real GCC 13 and GCC 14. This enforcement covers the gallery exporters and qualification runners; it does not change the repository's general Make cache behavior. The candidate's dedicated qualification runs native and sanitized suites, 520 native-material captures, eighty independent process replays and 240 invalid input cases. Real Workbench author/reopen exercises each of the eighty styles, normal paint/erase, a native simulation tick and saved-start reconstruction. Windows also repeats the Workbench campaign from an independently extracted self-contained package. Exact execution outcomes, timings, source identities and


### Rank 5: operations/gentek80-evaluation.md — GENTEK 80 — Windows evaluation

Document: GENTEK 80 Windows evaluation
Path: operations/gentek80-evaluation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Selection and Test It procedure for the source-qualified Draft/HOLD 80-Gentek integration candidate
canonical-for: [gentek80-selection-and-evaluation]
last-reviewed: 2026-11-21
Section: GENTEK 80 — Windows evaluation
This candidate provides **72 compact CLASSIC Genteks and eight advanced showcases** through the ordinary Architectural Generator. The thirteen accepted presets remain available, giving 93 choices. It remains Draft/HOLD until the owner accepts the delivered package. The source/runtime manifest and dated qualification receipts identify what was actually built and executed.

## DR18: Can I use reciprocal SWARM-004/005/006 negotiation in accepted main because a candidate has passing tests?

Canonical rank: 1

Expected facts:

- The consolidated SWARM candidate remains unmerged at the recorded source.
- Passing candidate tests and an evaluator do not imply accepted-main availability or physical owner acceptance.

### Rank 1: reference/status-and-roadmap.md — Status and foundational roadmap > Active candidates and integration boundaries

Document: Status and foundational roadmap
Path: reference/status-and-roadmap.md
authority: current-documentation
document-kind: reference
status: Current
scope: Accepted-main implementation, separately identified candidates, approved direction and unresolved decisions
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-11-24
Section: Status and foundational roadmap > Active candidates and integration boundaries
**All entries below were unmerged at the snapshot.** The linked principal records own current source, blockers, evaluator availability and exact qualification. This register deliberately does not duplicate their changing job lists or PR heads. | Programme | Principal record | Boundary for accepted-main documentation | |---|---|---| | PUBPRES physical progression and presentation | [#717](https://github.com/techrote/cybersand/issues/717), current finisher [#767](https://github.com/techrote/cybersand/pull/767), predecessor [#757](https://github.com/techrote/cybersand/pull/757) | Do not claim publication stalls or physical freezes are resolved by accepted main. | | ObjectShard moving destructible materials | [#754](https://github.com/techrote/cybersand/pull/754) | Moving native chemistry, mutable body ownership and ordinary Workbench integration are candidate behavior. | | Actor Compose continuous play and pilot recovery | [#762](https://github.com/techrote/cybersand/pull/762) | Preserve accepted #683 controls and disclose successor repair scope. | | Equipment recovery | [#724](https://github.com/techrote/cybersand/pull/724) | Historical #561 merge does not prove every later ballistic-solid/equipment path is present or correct. | | Persistent authored areas / RAMCACHE | [#745](https://github.com/techrote/cybersand/pull/745), [#734](https://github.com/techrote/cybersand/pull/734) | Persistent-area loading, native hot residency, durability and catch-up are not accepted-main save guarantees. | | Consolidated Gentek SWARM-004/005/006 | [#729](https://github.com/techrote/cybersand/pull/729) | Accepted Gentek generation does not imply accepted reciprocal negotiation/recovery. | | Gentek Windows owner evaluator | [#758](https://github.com/techrote/cybersand/pull/758) | GitHub reported this PR open and non-draft despite its HOLD title. Evaluator work and physical acceptance remain separate from the accepted catalogue. | | Art responsiveness, roster and conversation editor | [#744](https://github.com/techrote/cybersand/issues/744), [#765](https://github.com/techrote/cybersand/pull/765), [#766](https://github.com/techrote/cybersand/pull/766), [#756](https://github.com/techrote/cybersand/pull/756), [#763](https://github.com/techrote/cybersand/pull/763) | Do not promise repaired close/HTTP timing, updated provider presets or bounded editor layout before acceptance. | | WORLD-STEER / Batch Lab | [#770](https://github.com/techrote/cybersand/pull/770), predecessor [#720](https://github.com/techrote/cybersand/pull/720), [#579](https://github.com/techrote/cybersand/issues/579) | Native module harvesting, architectural knowledge retrieval and staged construction remain candidate work. | | Gremlin live testing | Prototype [#749](https://github.com/techrote/cybersand/pull/749) | A deterministic Python contract model is not proof of a real native/Godot playtesting backend. Follow the live successor record when published. | | Materials Lab current-scene audition | [#768](https://github.com/techrote/cybersand/pull/768) | Approved live-audition intent is not satisfied by advertising the existing isolated Lab as that feature. | | Workbench Strata Theatre | [#769](https://github.com/techrote/cybersand/pull/769), owner intent [#588](https://github.com/techrote/cybersand/issues/588) | Four-plane painting/composition in ordinary Workbench remains distinct from the available standalone exhibition. | | PAINT latency and physical evaluator | [#703](https://github.com/techrote/cybersand/pull/703), [#711](https://github.com/techrote/cybersand/pull/711) | Native fill speed and usable end-to-end responsiveness are separate measurements. | | CI engineering and publication closure | [#706](https://github.com/techrote/cybersand/issues/706), [#761](https://github.com/techrote/cybersand/issues/761) | Candidate fan-out, RAM-disk and publisher experiments do not replace accepted CI policy. |


### Rank 2: operations/physical-actor-programme.md — Physical actors and combined feature trials > Shared free-flight training family

Document: Physical actors and combined feature trials
Path: operations/physical-actor-programme.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Owner-authorized ACT-004 integration, retained Blacksite hull comparison and preserved 2026-10-18 actor preferences; not broad physics acceptance
canonical-for: [physical-actor-programme, combined-feature-launcher, physical-blacksite-comparison]
last-reviewed: 2026-10-22
Section: Physical actors and combined feature trials > Shared free-flight training family
The [4LY contract and dependency chain](../systems/physical-free-flight.md) owns the single-chassis Trainer/Hauler/Drifter/Dart lane under long-lived parent #132. 4LY-001 reuses the physical session and native coupling, with strict two-output desired-velocity input and bounded goal-blind assistance. **4LY-002 candidate source** supplies four distinct physical parameter sets and the additive F5 `set4LY` family. The 46 pre-existing actor IDs and SetP indices remain unchanged. The [measured 4LY-002 audit](../audits/2026-10-23-4ly002-measured-handling-qualification.md) records a real-Rapier pass of prospective motion/distinguishability thresholds on Linux and Windows plus exact-source native and documentation gates. The source calibration marker stays `candidate_4ly002` because its exact bytes participate in the passing profile hashes. Owner handling/visual review, final-head validation and the #207 host/teacher gate remain separate; a selectable name or passing manoeuvre metric is not an accepted learning plant. 4LY-003 (#207) now has the [playable Flight Lab and physical episode owner](../systems/physical-flight-lab.md). Its [frozen-teacher final-score audit](../audits/2026-10-24-4ly003-final-qualification.md) records a passing per-profile/per-family physical score, three retained Hauler obstacle failures, exact tested hashes and Linux runtime readback. External holdout custody and human review are not attested by that CI score alone. Trainer learning and subsequent family learning remain controlled by the companion repository's separate 4LY-004/005 gates. None of these stages closes #132, generic granular/soliding acceptance or the separate Jolt/morphology programme by implication.


### Rank 3: reference/invariants.md — Architectural and simulation invariants > Bridge invariants

Document: Architectural and simulation invariants
Path: reference/invariants.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
canonical-for: [invariant-register]
last-reviewed: 2026-11-24
Section: Architectural and simulation invariants > Bridge invariants
Contracts: [bridge behavior](../architecture/rendering-and-gameplay-bridges.md), [lifetimes](../architecture/data-ownership-and-lifetimes.md). Fixtures: [native bridge](../../godot/tests/test_native_render_bridge_regression.gd), [handoff](../../godot/tests/test_render_patch_handoff_regression.gd). | ID | Status and requirement | |---|---| | BRIDGE-001 | Current native publication; Approved general boundary: Godot gets no mutable World storage | | BRIDGE-002 | Current: leases/copies describe serialized post-mutation state and survive consumer delay | | BRIDGE-003 | Approved generalized queue: identified command boundaries and immutable results; production schemas/pressure are Planned | | BRIDGE-004 | Approved; Current presentation path: render-only state must not affect authoritative hashes/wake | | BRIDGE-005 | Current: live body Nodes/RIDs remain on main-thread adapter; workers receive complete value samples | | BRIDGE-006 | Current: LUT variation, temporal blending and glow do not write derived colour/frame noise into cells |


### Rank 4: decisions/ADR-014-semantic-plane-admission.md — ADR-014 Single semantic place and atomic four-plane admission > Alternatives and consequences

Document: ADR-014 Single semantic place and atomic four-plane admission
Path: decisions/ADR-014-semantic-plane-admission.md
authority: current-documentation
document-kind: decision
status: Current
scope: GEN-005 semantic projection ownership, immutable runtime commands and complete preview replacement
canonical-for: [semantic-plane-admission-decision]
last-reviewed: 2026-10-21
Section: ADR-014 Single semantic place and atomic four-plane admission > Alternatives and consequences
Four independent layout generators are rejected because a shared presentation label cannot prove geometric correspondence. Pixel-overlap event forwarding is rejected because it bypasses explicit lifecycle and owner admission. Incremental live installation of related plane tiles is deferred to GEN-006's residency and reconciliation contracts; GEN-005 commits bounded complete configurations. The complete proposal plus old/new owner staging has an explicit memory cost. Configured publication and host caps bound it. Retrying identical configuration is idempotent; intentional reset creates a new generation. Browser qualification and production asynchronous integration remain separate from this opt-in host.


### Rank 5: decisions/ADR-006-gpu-compute-deferral.md — ADR-006: GPU compute deferral > What would justify a new decision?

Document: ADR-006 — GPU compute deferral
Path: decisions/ADR-006-gpu-compute-deferral.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted CPU authority, deferred GPU field experiments and conditions for reconsideration
canonical-for: [decision-gpu-compute-deferral]
last-reviewed: 2026-09-08
Section: ADR-006: GPU compute deferral > What would justify a new decision?
Name the field and authority level; define CPU/GPU ownership, synchronization, collision/query latency, save/replay behavior, device loss and fallback. Compare representative current/larger fixtures including compute, transfer, synchronization, readback and memory. A non-authoritative experiment must leave native fixture state unchanged; an authoritative field requires a new explicit ADR. No future experiment is considered validated merely because shaders compile or a headless scene runs. Use [validation evidence](../reference/validation-evidence.md) and [profiling guidance](../operations/profiling-observability-and-performance.md) to distinguish actual device measurements from source inspection.

## DR19: Does Shared Workbench support independent actors now, and is the later Actor Compose finisher already accepted?

Canonical rank: 1

Expected facts:

- Accepted actor composition exposes the existing model catalogue and per-instance control within its bounded contract.
- Separate merged #683 from unmerged final/repair successors such as #762; do not infer availability from title.

### Rank 1: systems/workbench-actor-composition.md — Shared Workbench actor composition > Implementation and scope

Document: Shared Workbench actor composition
Path: systems/workbench-actor-composition.md
authority: current-documentation
document-kind: contract
status: Current
scope: WB-ACTOR-COMPOSE-001 physical actor catalogue, independent producers, policy adapter and authored control extension
canonical-for: [workbench-actor-composition, workbench-actor-control]
last-reviewed: 2026-11-24
Section: Shared Workbench actor composition > Implementation and scope
**Current accepted implementation through [#683](https://github.com/techrote/cybersand/pull/683), source `00cdb02f` checked 24 November 2026.** Ordinary Shared Workbench admits independently controlled physical actors through its existing prepared session, native worker and Rapier bridge. Accepted catalogue/admission and human handoff are distinct from the later Actor Compose finisher, pilot/stack repairs and Windows evaluator candidates tracked in the [roadmap](../reference/status-and-roadmap.md). Their unmerged improvements are not part of this contract's accepted baseline. Source availability does not certify every rig's playfeel or replace the retained scientific apparatus. The [owner procedure](../operations/workbench-actor-composition.md) explains the Actor Composition panel and Mixed Actor Workshop. Source ownership is divided as follows: | Source | Responsibility | |---|---| | [`workbench_actor_catalog.gd`](../../godot/scripts/workbench_actor_catalog.gd) | Copied capability and prepared-topology catalogue; model, controller, equipment and aggregate-capacity admission | | [`workbench_setup.gd`](../../godot/scripts/workbench_setup.gd) | Authored model identity, spawn, options, optional control extension and named example | | [`shared_workbench.gd`](../../godot/scripts/shared_workbench.gd), [`workbench_actor_panel.gd`](../../godot/scripts/workbench_actor_panel.gd) | Separate inspected actor and human pilot, explicit handoff, lazy panel, authoring transactions and policy UI | | [`physical_actor_session.gd`](../../godot/scripts/physical_actor_session.gd) | Existing actor ownership, per-actor sequence/generation, issued observations, leases, takeover and bounded scheduling | | [`workbench_actor_control.gd`](../../godot/scripts/workbench_actor_control.gd) | Value-only deterministic decision adapter; no World, node, RID, paint pointer or physics ownership | | [`workbench_reactive_policy.gd`](../../godot/scripts/workbench_reactive_policy.gd) | Narrow reuse of Thunderbowl's pure local steering helper for compatible physical policy-fixture actors | | [`workbench_physics_bridge.gd`](../../godot/scripts/workbench_physics_bridge.gd) | Actor-to-part-to-native-mask mapping and copied coupling samples in the existing Rapier space | | [`main.gd`](../../godot/scripts/main.gd), [`simulation_worker.gd`](../../godot/scripts/simulation_worker.gd) | Existing main-thread physics/native-worker boundary, atomic body/equipment samples, prepared adoption and lifecycle | The catalogue has 59 model identities: eight existing authored flyers, the passive barrel, 46 physical catalogue models including five SetP player rigs, and four 4LY assisted-flight profiles. Definitions are returned as new copied values. Equipment preparation occurs once; its permanent chassis participates in bounds and capacity checks even when the starting item is None.


### Rank 2: operations/workbench-actor-composition.md — Mixed Actor Workshop owner procedure

Document: Mixed Actor Workshop owner procedure
Path: operations/workbench-actor-composition.md
authority: current-documentation
document-kind: guide
status: Current
scope: WB-ACTOR-COMPOSE-001 ordinary Workbench controls, authored example and source-matched qualification procedure
canonical-for: [workbench-actor-composition-owner-procedure]
last-reviewed: 2026-11-24
Section: Mixed Actor Workshop owner procedure
This is the ordinary Workbench workflow accepted in [PR #683](https://github.com/techrote/cybersand/pull/683), from [#589](https://github.com/techrote/cybersand/issues/589). The later actor-finisher candidate does not supply additional accepted behavior here. F5, Thunderbowl and Flight Lab are not required. The [system contract](../systems/workbench-actor-composition.md) owns the precise capability, producer, persistence and capacity boundaries.


### Rank 3: systems/workbench-actor-composition.md — Shared Workbench actor composition > Reuse and research boundaries

Document: Shared Workbench actor composition
Path: systems/workbench-actor-composition.md
authority: current-documentation
document-kind: contract
status: Current
scope: WB-ACTOR-COMPOSE-001 physical actor catalogue, independent producers, policy adapter and authored control extension
canonical-for: [workbench-actor-composition, workbench-actor-control]
last-reviewed: 2026-11-24
Section: Shared Workbench actor composition > Reuse and research boundaries
Ordinary physical scripts reuse `physical_actor_script.gd`, including its local contact/support, direction changes, stall recovery, resource, grip, rope and player feedback. That script uses `physical_usable_script.gd` for suitable equipment. The small Workbench adapter supplies copied observations and actions; the existing rig/controller still applies every motor force. 4LY reuses `physical_flight_teacher.gd` for a goal-relative patrol between bounded authored endpoints and `physical_flight_controller.gd` for the existing plant. It reports local obstacle sensing as unavailable rather than importing Flight Lab's evaluator or privileged arena queries. Existing Workbench flyers use a small local pose/velocity feedback adapter that submits existing fleet action values; their established fleet controller continues to own actuation. ACT-001/002 sampled actors remain owned by `actor_prototype_session.gd` in the native-worker scheduling lane. They are **not an alternative representation inside this composition release**. A physical observation is never presented as a sampled v1/v2 array. A caller wanting a learned policy should consume the physical observation contract and return its supported bounded action values. Thunderbowl's full controller contracts include sampled self-state layouts, team/neighbor visibility, virtual tag readiness, messages and arena lifetime. Physical Workbench has no implicit authority for those fields. `workbench_reactive_policy.gd` reuses the actual `examples/thunderbowl/controller_base.gd::_wire_toward` helper for policy-fixture actors whose physical profile has ground/walk movement and an ordinary primary jump. It excludes player-controller rigs, charged jumps and flight. The current compatible models are Runner, Crawler, Scout and Rocker, selected by capabilities rather than a model-name dispatch table. The adapter projects only copied self motion/support and a bounded patrol goal into the pure helper, uses local wall/stall feedback to change direction, then returns physical move/aim/effort/jump values. Its diagnostics identify `thunderbowl-wire-to-physical/v1`; it does not claim to run a sampled actor. The Mixed Workshop's player Buggy continues to use its existing physical player feedback through the same policy envelope. Direct sampled metal actuation, oracle targets, virtual tag combat, NCA weights and smart-link requests are not Workbench motor commands. The steering reuse imports no arena, combat or messaging owner. Coordination and a slow model-intention adapter require explicit future schemas and budgets. An untrained NCA is not a trained NPC, and the smart-link contract is not an operational model service.


### Rank 4: systems/workbench-actor-composition.md — Shared Workbench actor composition > Producer and policy interface

Document: Shared Workbench actor composition
Path: systems/workbench-actor-composition.md
authority: current-documentation
document-kind: contract
status: Current
scope: WB-ACTOR-COMPOSE-001 physical actor catalogue, independent producers, policy adapter and authored control extension
canonical-for: [workbench-actor-composition, workbench-actor-control]
last-reviewed: 2026-11-24
Section: Shared Workbench actor composition > Producer and policy interface
as fresh.


### Rank 5: systems/workbench-actor-composition.md — Shared Workbench actor composition > Reading capability and qualification correctly

Document: Shared Workbench actor composition
Path: systems/workbench-actor-composition.md
authority: current-documentation
document-kind: contract
status: Current
scope: WB-ACTOR-COMPOSE-001 physical actor catalogue, independent producers, policy adapter and authored control extension
canonical-for: [workbench-actor-composition, workbench-actor-control]
last-reviewed: 2026-11-24
Section: Shared Workbench actor composition > Reading capability and qualification correctly
The 59 catalogue identities describe selectable models, not 59 universally interchangeable controllers or finished gameplay roles. `supports`, `equipment_error` and aggregate topology checks in [`workbench_actor_catalog.gd`](../../godot/scripts/workbench_actor_catalog.gd) remain authoritative. In particular, selecting **External Policy** exposes the existing issued-observation/leased-command interface; it starts no provider, model, network service or inference worker. Model orchestration requires a separately supplied adapter. An accepted `set_actor_control` request can change the producer without a World rebuild. Authored Apply/Restore and equipment replacement have their own prepared transactions. A current-main source walkthrough does not qualify pending repairs to those paths; preserve the exact source/runtime identity when reporting a failed or successful owner evaluation.

## DR20: Do all physical rigs accept every liquid or ballistic equipment tool?

Canonical rank: 2

Expected facts:

- Equipment has explicit actor/model/control and capacity admission; not every rig/tool combination is supported.
- Distinguish accepted equipment paths from pending recovery work.

### Rank 1: systems/physical-actor-rigs.md — Articulated Rapier actors and shared physical control > How do I select and control them?

Document: Articulated Rapier actors and shared physical control
Path: systems/physical-actor-rigs.md
authority: current-documentation
document-kind: contract
status: Current
scope: Articulated desktop roster with ACT-005 physical equipment and SetP human movement presets, authored mechanics, local scripted control and leased input; sampled references and scientific material acceptance remain separate
canonical-for: [physical-actor-rigs, physical-actor-control-v2, physical-actor-usables]
last-reviewed: 2026-10-22
Section: Articulated Rapier actors and shared physical control > How do I select and control them?
F5 in the ordinary sandbox, Blacksite Nine and the four showcase districts selects a representation, set, actor and keyboard, scripted-demo or external policy producer. Physical Rapier choices are the default actor route. Applying rebuilds the selected map at its initial spawn and starts paused. R retains the selection; changing district uses that district's spawn. Registered scientific fixtures and Benchmark mode retain their own actors. The new assembly remains suspended until its matching native reset and initial hard-terrain colliders are installed, including when Play is requested early. Physical wire controls are WASD movement, mouse aim, brackets for effort, Q/E trim, Z/X reel, Space primary, Shift secondary and C auxiliary. M uses the tool, N releases a held item and U requests nearby pickup. Left/right pointer buttons use equipment primary/alternate; its aim and power are independent of locomotion. F5 equipment selection changes a held chassis through the same admitted action. Exact ability meaning is displayed from the selected profile. These map to `tool`, `release_usable` and `attach_usable` in the shared API. These are bounded gameplay requests; no command writes a transform or assigns velocity as locomotion. Focus loss, pause, replacement and input cancellation revoke pending actions. SetP supplies five distinct human movement controllers through the same action path. Its buggy/bike use vertical movement for throttle and horizontal movement for lean; the acrobat supplies slides, rolls, bullet/double jumps, cancels and glide. Full controls and the separate seven-preset keyboard/gamepad course are in the [player control playground](player-control-playground.md). Its dry/liquid presets are native material fields and are not members of the Rapier roster. The retained single-body barrel/Ripper comparison is described separately in the [physical programme](../operations/physical-actor-programme.md). The current articulated Ripper is the five-part sprung crawler, not that historical hull arm. Desktop integration does not migrate the synchronous Web control owner.


### Rank 2: systems/workbench-liquid-equipment.md — Workbench liquid equipment — valves, drain, nozzle and pump > Status and boundary

Document: Workbench liquid equipment — valves, drain, nozzle and pump
Path: systems/workbench-liquid-equipment.md
authority: current-documentation
document-kind: contract
status: Current
scope: IN-TOOLS #361 shared-workbench liquid equipment (accepted through #553); authored geometry, worker-owned device owner, native quantity accounting, controls, built-in liquid-lab and reservoir-lab starts, lifecycle and limits
canonical-for: [workbench-liquid-equipment, liquid-lab-apparatus, reservoir-lab-apparatus]
last-reviewed: 2026-11-12
Section: Workbench liquid equipment — valves, drain, nozzle and pump > Status and boundary
**Accepted through #553 at `d8588716` and preserved in the integrated PAINT and agent candidate.** The equipment is opt-in: a starting setup without an `equipment` block, every Current default, the U10 `liquid_drain` usable, the Water family selection and all native laws are unchanged. No native C++ or GDExtension source changed for #553 itself. The separate [integrated candidate](../operations/wb-art-paint-integrated-candidate.md) adds stored-material readback and retains PAINT capacity changes, so it requires its new source-built runtime; the old committed libraries do not qualify that integrated source. Dated equipment evidence lives in the [2026-11-09 audit](../audits/2026-11-09-in-tools-361-workbench-equipment.md). The equipment adds **no solver, law, velocity edit or second equipment framework**. Every change to the World goes through the native World's ordinary booked external-edit path (`emit_disc`) or the existing #406 ballistic owner (`inject_water_parcel`), so the native quantity ledger remains the authority and closes by itself.


### Rank 3: systems/workbench-actor-composition.md — Shared Workbench actor composition > Physical equipment and material authority

Document: Shared Workbench actor composition
Path: systems/workbench-actor-composition.md
authority: current-documentation
document-kind: contract
status: Current
scope: WB-ACTOR-COMPOSE-001 physical actor catalogue, independent producers, policy adapter and authored control extension
canonical-for: [workbench-actor-composition, workbench-actor-control]
last-reviewed: 2026-11-24
Section: Shared Workbench actor composition > Physical equipment and material authority
Compatible physical rigs retain the existing ACT-005 32-item catalogue, mount, hit/mask validation, cooldown, charge, release/attach and native material accounting. The Workbench bridge maps each equipment part to its actual native proxy ID, including offsets after a compound flyer. Main publishes the copied body sample and equipment frame together through the existing worker boundary; native receipts return to the matching session. Physical ACT-004 effects and the ACT-005 engine receive the committed Workbench canvas extent, so valid tools on a 2048 × 1024 landscape are not clipped to a historical 1024-cell laboratory width. Coordinates outside the committed extent still refuse. Sampled actor/usable contracts keep their own bounds. The worker uses the existing cancellation mutex across the bounded physical effect apply, so cancellation cannot overtake validation and leave a late material write. The example gives Runner a Brick Stamper, Crawler a Powder Vacuum and Skimmer a Water Lance. These demonstrate deposition, excavation and liquid emission with native `physical_usables` receipts and `changed_cells`; they do not acquire human paint permissions. Model/tool behavior remains local and resource-bounded. Crawler starts at `(300, 350)` on the solid approach to the granular patch. These ground mechanisms obtain traction from real Rapier hard-terrain or body support. Native granular support alone does not become a grounded contact: placing a rig on a thick loose-powder bed can strand it until legitimate equipment clears enough material. The example preserves that boundary instead of granting a controller artificial traction or material-edit privileges. Autonomous tools never use or capture the human PAINT pointer. Human tools use explicit tool keys/gamepad controls and the observed equipment identity. Workbench also disables the legacy slot-zero mouse equipment adapter: an equipped scripted actor in the first physical slot cannot consume pointer input or have its generation cancelled by the old single-player path. Live source switching preserves the current item. **Apply equipment / restart** is a separate authored prepare operation that changes the starting loadout, retains live material cells/body poses where supported, and explicitly restarts controller/resource state. No item is silently attached to a model without a mount. Native refusal retains the old applied arrangement.


### Rank 4: systems/actor-rigs.md — Provisional actor rigs and shared control interface > Which actor rigs are available?

Document: Provisional actor rigs and shared control interface
Path: systems/actor-rigs.md
authority: current-documentation
document-kind: contract
status: Current
scope: Six sets of 29 optional desktop sampled actor rigs, their shared player/policy actions, observations and bounded gameplay mechanics; excludes learned inference and generalized rigid-body or pressure physics
canonical-for: [actor-rig-sets, actor-policy-input, actor-rig-observations-v2]
last-reviewed: 2026-10-19
Section: Provisional actor rigs and shared control interface > Which actor rigs are available?
**Current, experimental (ACT-002 / #168):** the desktop sandbox and exploratory showcase maps have six sets containing 29 movement rigs. Every rig can be assigned to keyboard input, an external policy producer or the built-in scripted demonstration. Producer identity changes who may submit an action; it does not grant different movement, collision or tool authority. SetA preserves the original Runner, Skimmer and Crawler motors. Its [version-1 contract](actor-control-prototypes.md) remains the compatibility route. The additional sets share a sampled motor with authored rotation, surface attachment, ropes, resource limits and selected local tools. These are provisional gameplay rules for comparison, not a selection of the final player representation. | Set ID | Theme | Stable rig IDs, in catalog order | |---|---|---| | `setA` | Reference controls | `runner`, `skimmer`, `crawler` | | `setB` | Ground and near-ground machines | `scout`, `scrabbler`, `ripper`, `groundeffect`, `digger` | | `setF` | Unusual flight and descent | `copter`, `pouncer`, `dropbot`, `lineshank` | | `setY` | Contact, rope and impulse traversal | `walljumper`, `clamberer`, `swinger`, `rocketjumper` | | `setU` | Self-propelled salvage tools | `springjack`, `gyrocrate`, `bellows`, `winchbug`, `magpie`, `skatesail` | | `setV` | Speculative interface personas | `astra`, `claude`, `luna`, `qwen`, `bonsai`, `jev`, `gemini` | `groundeffect` has no underscore; its display name is **GroundEffect**. The first three global rig indices remain 0 Runner, 1 Skimmer and 2 Crawler. A catalog entry is copied metadata, not a live controller. Its `parameters` extension dictionary is currently empty; movement tuning belongs to the motor, while effort is an input action rather than a replacement PENV profile. Source: [`actor_rig_catalog.gd`](../../godot/scripts/actor_rig_catalog.gd) (`RIG_IDS`, `entry`, `controls_text`), [`actor_rig_motor.gd`](../../godot/scripts/actor_rig_motor.gd) (`simulate_rig_action`, `_advance_rig`) and [`actor_prototype_session.gd`](../../godot/scripts/actor_prototype_session.gd). USABLE-001 adds an independent [actor equipment layer](actor-usables.md) for the sampled rig session. Equipment has its own epoch/sequence/lease stream and does not reuse movement buttons or grant policies direct World-edit authority. The [physical ACT-005 equipment](physical-actor-rigs.md#which-usable-examples-exist) uses articulated body/mount authority and the physical issued-observation envelope.


### Rank 5: systems/workbench-liquid-equipment.md — Workbench liquid equipment — valves, drain, nozzle and pump > Desktop controls

Document: Workbench liquid equipment — valves, drain, nozzle and pump
Path: systems/workbench-liquid-equipment.md
authority: current-documentation
document-kind: contract
status: Current
scope: IN-TOOLS #361 shared-workbench liquid equipment (accepted through #553); authored geometry, worker-owned device owner, native quantity accounting, controls, built-in liquid-lab and reservoir-lab starts, lifecycle and limits
canonical-for: [workbench-liquid-equipment, liquid-lab-apparatus, reservoir-lab-apparatus]
last-reviewed: 2026-11-12
Section: Workbench liquid equipment — valves, drain, nozzle and pump > Desktop controls
Shared workbench, **Liquid equipment** rows: **Valve n/N [V]** toggles the selected valve, **◀ [** / **▶ ]** choose the valve, **All valves**, **Drain [G]**, **Nozzle [H]**, **Aim − [J]** / **Aim + [K]** (10° steps), **Speed**, **Rate**, **Stop all**, **Load liquid-lab**, **Load reservoir-lab**, **Valve/Drain/Nozzle at X/Y** (a valve is added, up to eight; drain and nozzle are replaced), **Supply cells**, **Pump drain → nozzle**, **Apply supply/pump** and **Remove equipment**. The status line shows every valve (`O` open, `·` shut, `o`/`c` changing, the selected one bracketed), drained/injected cells, underwater injections, pipe stock/capacity and the native Water total with its ledger state; with the pump on it also shows the loop total. Overlay markers: valves orange (shut) / green (open), the selected valve thicker, drain blue, nozzle point and aim line. Typing `liquid-lab` or `reservoir-lab` in the setup name and **Load start** also opens the built-in start while no user file of that name exists. In the integrated PAINT/agent candidate, paused **Paint** mode keeps PAINT's existing shortcut priority: **G** selects Fill, **V** selects Paste, and **[** / **]** change brush radius. Select the main **Select body** tool to use the equipment shortcuts. The equipment buttons remain available in Paint mode.

## DR21: How do I configure a local LM Studio endpoint and custom model without sending a paid cloud request?

Canonical rank: 1

Expected facts:

- Provider selection, endpoint and model are explicit settings; use the documented local provider path.
- A documentation walkthrough must not dispatch paid inference or expose credentials; model availability/errors are separate from geometry application.

### Rank 1: operations/workbench-art.md — Art Workbench > Connect a provider you already use

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Connect a provider you already use
Choose **Model prompt**, then the provider. The endpoint and model fields are editable. These are the presets in accepted source, not a promise that a service still offers every preset model: | Provider | Protocol | Initial endpoint | Initial model ID | | --- | --- | --- | --- | | LM Studio | Chat Completions | `http://127.0.0.1:1234/v1` | `wb-art-instruct` | | OpenAI | Responses | `https://api.openai.com/v1` | `gpt-5.6-luna` | | NVIDIA | Chat Completions | `https://integrate.api.nvidia.com/v1` | `qwen/qwen3-next-80b-a3b-instruct` | For a local server, start your already-installed server and load a model under the identifier you enter. A custom endpoint must include its API base path, normally `/v1`. LM Studio sends no fabricated API key; **Key…** can supply a token if your configured server requires one. Cloud providers require your own key. Keys remain in process memory, separately per provider, and are not stored in preferences. For a first request, keep **Turns** at 1, use a small focus area, and ask for a few simple shapes. **Toks** limits output tokens and **Secs** sets HTTP timeout; the initial values are 8192 and 180 seconds. Model output is parsed as admitted drawing data and still validated natively. Prose or malformed geometry is not executed as code. **Image** attaches a crop of the rendered canvas for a vision-capable model; **Full view** uses the visible canvas instead of only its intersection with Focus. This requires a graphical runtime. **Guidance…** edits the drawing instructions. **Conversation…** edits which current-session messages will be used as future model context without rewriting past native results.


### Rank 2: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Current candidate and controls

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Current candidate and controls
**Unmerged candidate:** #559 Stage 2 extends `codex/agent-art-workbench-v2` and Draft PR #560. The [Stage-1 contract](workbench-direct-art-batches.md) owns direct geometry, execution-time protection, native completion and authored-start Save. No #531 controller, native defaults, prices, catalogs, credit gates or MCP are imported. Model prompt and Scanline send the current task, selected conversation context, drawing instructions, work area and optional canvas observation. Stored traffic remains separate from model context. The [integrated Draft candidate](../operations/wb-art-paint-integrated-candidate.md) preserves this complete interface and adds PAINT alongside it. Native authoring uses the repaired stored-material API and shared ordering; the provider protocol, model choices, conversation, diagnostics and image-observation controls remain owned here. The integrated workflow uses deterministic HTTP/provider fixtures; earlier genuine inference evidence below belongs to its original checkpoint. Open **Art batches**, choose **Model prompt**, provider, editable model ID and base URL. Endpoint/model, output allowance and timeout occupy two shared rows. Enter a prompt in the main text area and click Send; Stop remains beside Send. Direct JSON remains selectable independently. Model history is convenience, not admission. Controls affect the next request; an in-flight request keeps its captured work area/material/protection selections. Idle/completed, waiting for model, capture, native queued/executing/partial and errors are visibly distinct. | Preset | Protocol | Default base URL | Model field | |---|---|---|---| | OpenAI | Responses | `https://api.openai.com/v1` | `gpt-5.6-luna`, editable | | NVIDIA | Chat Completions | `https://integrate.api.nvidia.com/v1` | `nvidia/nemotron-3.5-super-vl-120b-a12b`, editable | | LM Studio | Chat Completions | `http://127.0.0.1:1234/v1` | `wb-art-instruct`, local tested alias, editable | Use **Key…** for each cloud provider. Keys stay in process memory, separately per provider; reopening Key always permits replacement. The button indicates a key is present. Profiles/history persist in `user://art-provider.cfg` without keys. LM Studio sends no fabricated key; a configured local server token is accepted through the same Key control. Local/LAN/manual endpoints are allowed. The numeric loopback default avoids the long `localhost` connection delays observed on this Windows installation; `localhost` remains usable as an editable endpoint. Output allowance defaults to 8192; Toks and Secs control the actual request cap and HTTP timeout. Tests exercise 4096/8192/16384 separately. Responses uses `max_output_tokens` (including reasoning where applicable); Chat Completions uses `max_tokens`. Truncated/incomplete responses report the reason and draw nothing; there is no automatic expensive retry or hidden context truncation. Returned model/deployment names are informational. Reported input/output usage is shown; missing usage/cost remains `?`. Provider rate headers and errors are in Traffic; Stage-5 automatic pacing/advanced budgets are not claimed here.


### Rank 3: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Reproducible qualification and local setup

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Reproducible qualification and local setup
The original Stage-2 checkpoint used unchanged main native libraries. The integrated repair requires its newly built source-matched GDExtension. Real-native and cloud-adapter fixture tests are separate from genuine inference. ```powershell lms server start --port 1234 lms load liquid/lfm2.5-1.2b --gpu max --context-length 16384 --identifier wb-art-instruct --ttl 7200 -y # Optional already-installed vision model used in this qualification: lms load lfm3-omni-2b --gpu max --context-length 16384 --identifier wb-art-vision --ttl 7200 -y C:/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/test_art_provider.gd python tools/test_art_provider_transport.py --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --output build/art-provider-http ``` `run_art_provider_local.gd` is an explicit genuine-local UI/native test, not an automatically discovered CI test. Set `WB_ART_TEST_ENDPOINT`, `WB_ART_TEST_MODEL` and `WB_ART_EVIDENCE_DIR` as needed. The transport tool supplies synthetic HTTP responses and separately runs real native drawing; it tests OpenAI/NVIDIA/local wire shapes, aliases, errors, timeout, Stop and replacement. Its `--graphical` option exercises actual UI image capture and retains PNGs on Linux X11 and Windows ANGLE. Only `test_art_provider.gd` is a normal keyless auto-discovered provider test. Genuine text qualification used LM Studio 0.4.26+4, selected llama.cpp NVIDIA CUDA runtime 2.73.0 and TITAN RTX (24576 MiB). `liquid/lfm2.5-1.2b` Q4_K_M with 16384 context and `--gpu max` passed drawing at all three output allowances. GPU process and VRAM evidence are retained. An installed experimental 8B IQ4_XS model emitted reasoning/prose and an unsupported shape on one trial; it is not labelled a perfect structured-command model. No model download was needed. Genuine LFM3-Omni-2B Q4_K_M image inference through the new adapter described an original native-workbench post-draw PNG. Its vision projector reported unsupported CUDA flash-attention operators and CPU fallback: this is **mixed GPU/CPU vision**, not proof of an entirely GPU-resident visual path or a visual revision loop. Model art quality and Stage-3 persistent visual iteration remain separate. The owner-requested benchmark uses the exact prompt `draw a detailed gundam mech style cyberpunk statue`, three fresh 64x128 attempts per installed model, 8192 output allowance. `tools/bench_art_provider.py` retains original rendered canvas/workbench PNGs, raw traffic and measured native results. Its optional WSL-to-Windows loopback relay is test-only, not a product dependency. No external port exposure or MCP is introduced. Cloud request shaping is keylessly qualified; genuine OpenAI/NVIDIA calls require owner key entry and remain separately reported. The first nine statue trials copied literal numeric examples or used near-miss field names, and applied zero cells. Their failures are retained. The generic instructions were clarified to describe parameter fields without numeric drawing examples; equivalent spellings were normalized and the comparison repeated. No paid calls or merge/Ready promotion are implied by this implementation.


### Rank 4: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Collaboration, scanline and pacing preview

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Collaboration, scanline and pacing preview
Model prompt and Scanline keep a conversation for the mounted workbench. Turns limits requests per Send, including refusals and rate retries. Zero continues until Stop, completion or another limit. Run s adds an optional elapsed-time ceiling. After native completion, the next request can use the actual changed count and world epoch. An empty array ends the run. Stop cancels pending inference, pacing and queued native work. Clear starts a new conversation while the durable traffic retains earlier events. Full includes all text turns and saved images when Image is enabled. Compacted includes the latest twelve entries and discloses omissions. It omits reasoning prefixes from model context while retaining the original replies in traffic. Custom initially uses the same window. None sends no earlier turns. Historical image bytes remain in durable traffic. Image sends the visible intersection of the work area, or the whole visible canvas with Full view. The request includes pixel dimensions and the world rectangle. Identical captures are skipped within a run. Native chunk receipts remain in local traffic. Guidance opens the editable instructions for the selected mode. Scanline takes rows with local y, optional repeat and scale, and spans in [x,length,material] order or named objects with those fields. Omitted spans preserve cells. An explicit zero material erases. The normal executor applies the resulting ordered rectangles. Consecutive shapes of the same material share native chunks up to the existing cell limit. Material changes preserve the original draw and erase order. Gap s sets an optional request interval. HTTP 429 with numeric Retry-After paces subsequent requests to that endpoint. OpenAI request, token and project token reset durations also pace requests when their bucket reports exhaustion. Known billing and spending quota failures require user action. Traffic supports visible filtering and full disk export. Unknown cost remains unknown. On 2026-11-10 the Windows preview passed 113 native checks and 43 checks with LM Studio LFM2.5 1.2B, including a human follow-up and Stop during pacing. The Linux graphical transport fixtures passed for all three providers. The graphical run_art_scanline_vision.gd probe used the loaded LM Studio LFM3 Omni model through a loopback relay. It applied a four-cell wall, then erased its first cell after a second rendered observation. The earlier LFM2.5 text scanline trial returned malformed JSON. The vision test is a constrained placement test. In a separate graphical 64×128 statue trial, wb-art-local sent three requests over 50.5 seconds. The first two changed 226 and 132 native cells. The last returned an empty array. Reported input and output totals were 11,900 and 6,707 tokens. This


### Rank 5: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Provider/native boundary and Stop

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Provider/native boundary and Stop
`art_provider.gd` owns one threaded Godot HTTPRequest and static payload/response adapters. `art_batch_panel.gd` supplies compact controls and dispatches parsed operations to the existing Stage-1 executor. No second simulation or controller is introduced. Plain JSON arrays, an operations envelope, a single shape, JSON fences and a recognized final packet after `</think>` are accepted. `type`/`operation` alias `shape`; draw_ prefixes and pixel/circle/rect spellings normalize to the same primitives. Omitted material defaults to the selected paint material. Hard Wall is the initial selection. A complete JSON array followed by a stray closing wrapper is accepted; a truncated array is not. Native geometry/material validation still applies. Arbitrary prose is not executed. Refused/malformed packets leave Send available for correction and retain the complete provider response. This is structured-text drawing, not a claim that every local model supports native tool calling. Stop cancels capture/HTTP, invalidates the request generation and stops native queued work. Native worker epoch is captured before inference; Reset/Load/Restore invalidate old model results. An executing native chunk may finish at its normal boundary. No uncertain mutation is replayed. Network failure, HTTP 429, bad model output and logger failure leave the UI available. No credential/catalog preflight is used beyond requiring a cloud key/model field for a cloud request. Optional **Image** sends a PNG crop from the actual post-draw canvas view, resized to at most 768 pixels on its longest axis. Floating art/traffic windows are hidden for the capture frame and restored; their contents do not cover the canvas image. Camera/view remain unchanged. Image capture requires a graphical runtime; text inference works headlessly. Image bytes remain inspectable in raw traffic. HTTP response body capacity is 16 MiB to bound response allocation; timeout is visible/configurable. Automatic HTTP redirects are disabled so a configured base URL is the actual credential destination; HTTP redirect/error details remain inspectable. These are transport mechanics, not source/pricing authorization.

## DR22: Does hiding the Art window mean its request was stopped?

Canonical rank: 1

Expected facts:

- Hide and Stop have different semantics; do not describe window visibility as cancellation.
- Use the documented Stop/request state and native receipts to determine remaining work.

### Rank 1: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Diagnostics and retention > Session-scoped, write-only Art traffic — 22 November 2026

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Diagnostics and retention > Session-scoped, write-only Art traffic — 22 November 2026
Each **new Workbench game session begins with an empty in-memory Art conversation**. The Send, Conversation and direct drawing controls never reopen, link, scan or copy traffic from a previous process or Workbench scene. The user can maintain multi-turn context *within the current session*; closing the session discards the in-memory conversation. Model/provider/endpoint/control preferences may still persist in `user://art-provider.cfg`, but no `traffic_path` is read or published. The obsolete profile pointer is removed on the next successful preferences save. On the first Art log event, the existing bounded writer creates **one new root JSONL** under `user://art-traffic/`. All following requests, provider responses, native results and in-session conversation changes append to that same file until the Workbench session ends. Hiding and reopening the Art window within the same Workbench does not create a second log. There is no automatic replay, linked predecessor, history-resume gate or full-history duplication. An unavailable, corrupt or deleted older log cannot prevent Send. Each model request writes a redacted `request_parameters` event containing the provider/model/endpoint, prompt, guidance, requested work rectangle, allowed materials, protected areas, enabled tools, token/time/turn limits and relevant image/context settings. The normal request/response/native receipt events follow. Direct JSON painting records `manual_program`, `manual_admission` and terminal `manual_result`. This provides the values needed for manual re-entry later; it does **not** promise to reproduce an evolving World from prompts alone or retain exact unlogged source World state. `Traffic…` displays the current session file path and can explicitly export it. Existing legacy and linked archives remain **unchanged** on disk, but are never attached to a new game session. The legacy archive parser remains available for standalone read-only diagnostics and old evidence tests; it is not part of the normal UI lifecycle. No automatic migration, deletion or cleanup is performed. PAINT's native authoritative Undo/Redo is independent of Art. When an Art window exists, confirmed Undo/Redo events may be appended to its current session log. Without an Art session, native editing does not force the Art panel or create a cross-session receipt journal. Old `user://art-pending-history` records are preserved as historical data and never injected into a new session. Disk logging failures remain visible, but must not retroactively repeat a native edit. **Scope boundary:** This is session-local authoring history, not a durable conversation database. Save/Open for the authored World and PAINT's own material history retain their existing independent contracts. New model requests must never trust a stale previous-session continuation pointer.


### Rank 2: operations/workbench-art.md — Art Workbench > Stop, Hide and native results

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Stop, Hide and native results
**Stop** cancels pending HTTP/capture and scheduled turns, invalidates the request generation and requests the native executor to stop. A native slice already executing can finish at its boundary. A reported **partial** result can therefore have changed the canvas. Read the confirmed count and use available Undo; do not assume cancellation rolled everything back. Closing the Art window **hides** it. It does not mean Stop, save, or end of the Workbench session. Reopen **Art batches** to inspect the same session. For Undo/Redo, Stop first and wait for model, capture, drawing, deferred manual strokes and receipt processing to settle. Both Art and manual controls use the same chronological history. ```mermaid flowchart TD A["Direct JSON or model response"] --> B["Parse and validate drawing"] B --> C["Queue native work"] C --> D["Native slice and stored-material readback"] D --> E["Completed or partial receipt"] E --> F["History and visible result"] S["Stop"] --> C S --> E ``` **Queued is admission, not applied success.** A result from before Reset, Load or World replacement is stale and must not draw into the new scene. Source failures, rejection and missing acknowledgements are not success receipts.


### Rank 3: operations/workbench-art.md — Art Workbench > Conversation and private traffic

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Conversation and private traffic
Each new Workbench session starts with an empty in-memory conversation. Hiding and reopening Art within that session keeps it; ending the session discards it. Provider/model/endpoint/control preferences can persist in `user://art-provider.cfg`. Previous conversations are not automatically restored. The first log event creates one new JSONL file under `user://art-traffic/`. Requests, responses, direct programs and native results append there for the session. **Traffic…** shows the path, a readable or Raw JSONL view, filtering, copy and **Save full JSONL…** export. Old archives are preserved on disk but are not attached to a new session. Logs are evidence for manual diagnosis, not exact replay of an evolving World. The logger redacts known key/bearer patterns and configured credentials, but prompts, model replies, canvas images and other private content remain sensitive. Inspect and redact a diagnostic extract before sharing it. An endpoint is the destination for its request and credentials; automatic HTTP redirects are disabled. Never paste unrelated secrets into a prompt.


### Rank 4: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Diagnostics and retention

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Diagnostics and retention
**Traffic…** is a separate hideable window with readable messages/instructions, a Raw JSONL switch, copy and full-session export. Both formats show actual content; raw contains request bodies, response bodies/headers, usage, native admission and completion, cancellation, wall-clock timestamps and monotonic times. Requested and returned model names are recorded without comparing them as a gate. Full redacted JSONL appends under `user://art-traffic/`; its absolute path is shown in Traffic. On this Windows installation that normally resolves below `%APPDATA%/Godot/app_userdata/Cyber Sand Reference Sandbox/art-traffic/`. The live text buffer is bounded separately (about 2 million characters), with an explicit earlier-on-disk marker. Full export streams the linked disk segments, not the live tail; there is no 256-event export ceiling. Disk failure is surfaced without stopping inference/drawing. When disk logging fails, missing historical content is not magically recoverable from the bounded viewer. Entered keys, bearer strings, common key formats, credential URL parameters and URL userinfo are redacted before display/disk/export. Authorization request headers are never added to the logged request object. No log can identify every arbitrary secret the user invents; do not put unrelated credentials in prompts.


### Rank 5: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Offset-area repair > 2026-11-11 scanline qualification

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Offset-area repair > 2026-11-11 scanline qualification
The Windows native session probe, run with the local wb-art-vision model, completed twelve 480-cell scanline turns on one canvas in 58.4 seconds. Native readback confirmed 5,760 changed cells across twelve chunks. The export kept all twelve native receipts and the initial inference cancellation. The first attempt exposed a model reply using named span fields, now supported alongside the array form. A separate inference continued through injected log I/O failure. The same probe stopped an admitted large stencil after the first 4,096-cell receipt and confirmed that the next row was untouched. It also stopped during inference and a pacing wait. The graphical Linux probe stopped during canvas capture before dispatch, then drew and revised a stencil with the live local vision model. The OpenAI HTTP fixture verified a successful response with zero remaining requests and a 62.5-second reset, and verified that a billing quota error does not retry. These provider header cases use keyless fixtures. The art material picker offers every non-empty material from the ordinary Workbench paint palette. Erase remains a separate toggle. The selected ID applies to Direct JSON, Model prompt and Scanline. Existing non-Empty, non-Hard-Wall cells remain protected from art writes, including erase. Tools controls which shapes Direct JSON and Model prompt may submit. A nonzero Pixels per operation setting limits the length of each point list. Zero adds no point limit. The worker still streams large operations in native chunks. Lines accept an optional integer width in cells. Width one preserves the original raster. Wider strokes use rounded ends and clip to canvas bounds before the worker applies the selected area and protection checks. Scanline keeps its own span format. The Tools picker also enables rounded polylines (ordered `points` and optional `width` in cells), filled polygons (three or more `points`, closed automatically), and airbrush stamps (`x`, `y`, `radius`, optional `density` and `hardness` from 0 to 1, and an integer `seed`). Airbrushes stipple real material cells; hardness controls edge falloff, and repeating a seed repeats the pattern relative to the stamp center. All three use the same native edit batching and protection as the existing shapes. Desktop rasterization yields between frames even when a sparse shape produces no native chunk yet. Partial chunks are submitted periodically so sparse shapes can appear before rasterization finishes. Stop discards buffered cells that have not been submitted to the native owner. Traffic stays on disk while hidden. The open inspector refreshes at most twice per second during drawing and shows a bounded tail; Save JSONL exports the full session. On 2026-11-11, Windows/TITAN

## DR23: After accepted ART-SESSION-LOG-001, are yesterday’s Art conversation messages automatically restored on the next game launch?

Canonical rank: 1

Expected facts:

- Accepted #727 uses session-only conversation lifetime and one JSONL audit per game session.
- Old lazy conversation restore instructions from #681 are superseded for the current accepted path; old audit files are not an implicit chat restore.

### Rank 1: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Diagnostics and retention > Session-scoped, write-only Art traffic — 22 November 2026

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Diagnostics and retention > Session-scoped, write-only Art traffic — 22 November 2026
Each **new Workbench game session begins with an empty in-memory Art conversation**. The Send, Conversation and direct drawing controls never reopen, link, scan or copy traffic from a previous process or Workbench scene. The user can maintain multi-turn context *within the current session*; closing the session discards the in-memory conversation. Model/provider/endpoint/control preferences may still persist in `user://art-provider.cfg`, but no `traffic_path` is read or published. The obsolete profile pointer is removed on the next successful preferences save. On the first Art log event, the existing bounded writer creates **one new root JSONL** under `user://art-traffic/`. All following requests, provider responses, native results and in-session conversation changes append to that same file until the Workbench session ends. Hiding and reopening the Art window within the same Workbench does not create a second log. There is no automatic replay, linked predecessor, history-resume gate or full-history duplication. An unavailable, corrupt or deleted older log cannot prevent Send. Each model request writes a redacted `request_parameters` event containing the provider/model/endpoint, prompt, guidance, requested work rectangle, allowed materials, protected areas, enabled tools, token/time/turn limits and relevant image/context settings. The normal request/response/native receipt events follow. Direct JSON painting records `manual_program`, `manual_admission` and terminal `manual_result`. This provides the values needed for manual re-entry later; it does **not** promise to reproduce an evolving World from prompts alone or retain exact unlogged source World state. `Traffic…` displays the current session file path and can explicitly export it. Existing legacy and linked archives remain **unchanged** on disk, but are never attached to a new game session. The legacy archive parser remains available for standalone read-only diagnostics and old evidence tests; it is not part of the normal UI lifecycle. No automatic migration, deletion or cleanup is performed. PAINT's native authoritative Undo/Redo is independent of Art. When an Art window exists, confirmed Undo/Redo events may be appended to its current session log. Without an Art session, native editing does not force the Art panel or create a cross-session receipt journal. Old `user://art-pending-history` records are preserved as historical data and never injected into a new session. Disk logging failures remain visible, but must not retroactively repeat a native edit. **Scope boundary:** This is session-local authoring history, not a durable conversation database. Save/Open for the authored World and PAINT's own material history retain their existing independent contracts. New model requests must never trust a stale previous-session continuation pointer.


### Rank 2: operations/workbench-art.md — Art Workbench > Conversation and private traffic

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Conversation and private traffic
Each new Workbench session starts with an empty in-memory conversation. Hiding and reopening Art within that session keeps it; ending the session discards it. Provider/model/endpoint/control preferences can persist in `user://art-provider.cfg`. Previous conversations are not automatically restored. The first log event creates one new JSONL file under `user://art-traffic/`. Requests, responses, direct programs and native results append there for the session. **Traffic…** shows the path, a readable or Raw JSONL view, filtering, copy and **Save full JSONL…** export. Old archives are preserved on disk but are not attached to a new session. Logs are evidence for manual diagnosis, not exact replay of an evolving World. The logger redacts known key/bearer patterns and configured credentials, but prompts, model replies, canvas images and other private content remain sensitive. Inspect and redact a diagnostic extract before sharing it. An endpoint is the destination for its request and credentials; automatic HTTP redirects are disabled. Never paste unrelated secrets into a prompt.


### Rank 3: operations/workbench-art.md — Art Workbench > Connect a provider you already use

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Connect a provider you already use
Choose **Model prompt**, then the provider. The endpoint and model fields are editable. These are the presets in accepted source, not a promise that a service still offers every preset model: | Provider | Protocol | Initial endpoint | Initial model ID | | --- | --- | --- | --- | | LM Studio | Chat Completions | `http://127.0.0.1:1234/v1` | `wb-art-instruct` | | OpenAI | Responses | `https://api.openai.com/v1` | `gpt-5.6-luna` | | NVIDIA | Chat Completions | `https://integrate.api.nvidia.com/v1` | `qwen/qwen3-next-80b-a3b-instruct` | For a local server, start your already-installed server and load a model under the identifier you enter. A custom endpoint must include its API base path, normally `/v1`. LM Studio sends no fabricated API key; **Key…** can supply a token if your configured server requires one. Cloud providers require your own key. Keys remain in process memory, separately per provider, and are not stored in preferences. For a first request, keep **Turns** at 1, use a small focus area, and ask for a few simple shapes. **Toks** limits output tokens and **Secs** sets HTTP timeout; the initial values are 8192 and 180 seconds. Model output is parsed as admitted drawing data and still validated natively. Prose or malformed geometry is not executed as code. **Image** attaches a crop of the rendered canvas for a vision-capable model; **Full view** uses the visible canvas instead of only its intersection with Focus. This requires a graphical runtime. **Guidance…** edits the drawing instructions. **Conversation…** edits which current-session messages will be used as future model context without rewriting past native results.


### Rank 4: operations/workbench-first-session.md — Your first Workbench session > Close and reopen

Document: Your first Shared Workbench session
Path: operations/workbench-first-session.md
authority: current-documentation
document-kind: guide
status: Current
scope: A small paused material authoring tutorial with simulation, saving and fresh-session reconstruction
canonical-for: [workbench-first-session]
last-reviewed: 2026-11-24
Section: Your first Workbench session > Close and reopen
1. Wait for all drawing and saving to finish. 2. Use **Menu [F2]** or close Godot. Returning to the launcher closes the session. 3. Open Development workbench again, enter `first-container` and click **Load start**. 4. Wait for reconstruction. Check the material layout and authored actors, then paint a small new mark to confirm the scene is editable. Undo/Redo stacks and the Art conversation are session-local. They are not restored by loading the authored start. A flattened save rebuilds initial material state from stored IDs; it does not resume the previous tick.


### Rank 5: operations/workbench-art.md — Art Workbench > Context, limits and repeated requests

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Context, limits and repeated requests
**Full** includes current-session conversation; **Compacted** keeps the most recent 12 turns and a latest-result summary. **Custom** currently uses the Compacted behavior; **None** omits prior conversation. These are context choices, not storage guarantees. **Turns** limits requests per Send. Zero continues until Stop, model completion or another configured limit. **Limits…** supplies a minimum request gap, run duration and estimated spending controls. Zero disables the corresponding limit. Spending uses your entered rates and reported tokens after a response; it can exceed the ceiling by one request and cannot be tracked when usage is missing. There is no live pricing lookup or prepaid-credit guarantee.

## DR24: Which Art diagnostics can I attach to a public bug report without leaking prompts or credentials?

Canonical rank: 1

Expected facts:

- Traffic and prompts can be private; inspect and redact exported logs instead of treating all diagnostics as safe.
- Share minimal source/runtime/error evidence and synthetic reproduction data; never include credentials.

### Rank 1: operations/local-build-and-validation.md — Local build and validation > Isolated test data and diagnostics

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Isolated test data and diagnostics
Godot tests and graphical captures must not overwrite the owner's saved scenes, Art traffic or local provider configuration. Use the repository's [isolated Godot runner](../../tools/physics/isolated_godot.py) or the appropriate existing test/capture harness with its own user profile. Inspect that harness's arguments and refusal rules before invoking it; a normal interactive launch intentionally uses the user's ordinary application data. For a useful failure report, record the checkout SHA and dirty state, exact Godot version, native runtime/provenance identity, platform, command, fixture or small synthetic setup, steps, expected result, actual result and whether the operation was queued, applied, displayed or refused. Include the first relevant error and completion status, not only a green process exit. Preserve the original failed result alongside a successful retry. Art prompts, traffic, endpoint credentials and owner maps may be private: inspect and redact attachments, and prefer a synthetic reproduction. [Troubleshooting](troubleshooting.md) covers common launch, focus, runtime and capacity failures.


### Rank 2: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Diagnostics and retention

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Diagnostics and retention
**Traffic…** is a separate hideable window with readable messages/instructions, a Raw JSONL switch, copy and full-session export. Both formats show actual content; raw contains request bodies, response bodies/headers, usage, native admission and completion, cancellation, wall-clock timestamps and monotonic times. Requested and returned model names are recorded without comparing them as a gate. Full redacted JSONL appends under `user://art-traffic/`; its absolute path is shown in Traffic. On this Windows installation that normally resolves below `%APPDATA%/Godot/app_userdata/Cyber Sand Reference Sandbox/art-traffic/`. The live text buffer is bounded separately (about 2 million characters), with an explicit earlier-on-disk marker. Full export streams the linked disk segments, not the live tail; there is no 256-event export ceiling. Disk failure is surfaced without stopping inference/drawing. When disk logging fails, missing historical content is not magically recoverable from the bounded viewer. Entered keys, bearer strings, common key formats, credential URL parameters and URL userinfo are redacted before display/disk/export. Authorization request headers are never added to the logged request object. No log can identify every arbitrary secret the user invents; do not put unrelated credentials in prompts.


### Rank 3: operations/workbench-art.md — Art Workbench > Conversation and private traffic

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Conversation and private traffic
Each new Workbench session starts with an empty in-memory conversation. Hiding and reopening Art within that session keeps it; ending the session discards it. Provider/model/endpoint/control preferences can persist in `user://art-provider.cfg`. Previous conversations are not automatically restored. The first log event creates one new JSONL file under `user://art-traffic/`. Requests, responses, direct programs and native results append there for the session. **Traffic…** shows the path, a readable or Raw JSONL view, filtering, copy and **Save full JSONL…** export. Old archives are preserved on disk but are not attached to a new session. Logs are evidence for manual diagnosis, not exact replay of an evolving World. The logger redacts known key/bearer patterns and configured credentials, but prompts, model replies, canvas images and other private content remain sensitive. Inspect and redact a diagnostic extract before sharing it. An endpoint is the destination for its request and credentials; automatic HTTP redirects are disabled. Never paste unrelated secrets into a prompt.


### Rank 4: reference/validation-evidence.md — Validation evidence ledger > Platform limits and honest outcomes

Document: Validation evidence ledger
Path: reference/validation-evidence.md
authority: current-documentation
document-kind: reference
status: Current
scope: How to locate and interpret source-bound validation; dated results do not certify a new runtime or every platform
canonical-for: [validation-results, platform-evidence, historical-evidence-boundaries]
last-reviewed: 2026-11-24
Section: Validation evidence ledger > Platform limits and honest outcomes
Old sanitizer results and current Windows fixtures do **not** prove Linux, Firefox or Safari work. Historical M11, dated Chromium compatibility/threaded results, later Linux native/headless/rendered evidence and physical Windows observations retain separate scope. Browser support must be established on the actual source, profile and browser; a successful Web compile is insufficient. The existing records do not supply universal Firefox/Safari acceptance. Web toolchain/template/export-identity obligations remain separately tracked. Use explicit outcomes: **PASS** for executed criteria that passed; **FAIL** for an executed failure; **SKIP** for a deliberately suppressed gate; **NOT RUN** for no execution; **BLOCKED** for an unavailable prerequisite. Describe the reason and preserve failed attempts. A Draft-skipped expensive job is not a green runtime result. A documentation candidate can be qualified as documentation while runtime and physical acceptance remain outside its scope. Keep diagnostic evidence minimal and safe to share. Record source, version, short reproduction, actual result and relevant sanitized output. Art traffic and owner maps can contain private content; do not attach whole archives merely to report a UI defect. Never publish provider credentials.


### Rank 5: systems/workbench-art-providers.md — Art workbench provider connection — Stage 2 > Diagnostics and retention > Session-scoped, write-only Art traffic — 22 November 2026

Document: Art workbench provider connection, WB-ART-002 Stage 2
Path: systems/workbench-art-providers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
Section: Art workbench provider connection — Stage 2 > Diagnostics and retention > Session-scoped, write-only Art traffic — 22 November 2026
Each **new Workbench game session begins with an empty in-memory Art conversation**. The Send, Conversation and direct drawing controls never reopen, link, scan or copy traffic from a previous process or Workbench scene. The user can maintain multi-turn context *within the current session*; closing the session discards the in-memory conversation. Model/provider/endpoint/control preferences may still persist in `user://art-provider.cfg`, but no `traffic_path` is read or published. The obsolete profile pointer is removed on the next successful preferences save. On the first Art log event, the existing bounded writer creates **one new root JSONL** under `user://art-traffic/`. All following requests, provider responses, native results and in-session conversation changes append to that same file until the Workbench session ends. Hiding and reopening the Art window within the same Workbench does not create a second log. There is no automatic replay, linked predecessor, history-resume gate or full-history duplication. An unavailable, corrupt or deleted older log cannot prevent Send. Each model request writes a redacted `request_parameters` event containing the provider/model/endpoint, prompt, guidance, requested work rectangle, allowed materials, protected areas, enabled tools, token/time/turn limits and relevant image/context settings. The normal request/response/native receipt events follow. Direct JSON painting records `manual_program`, `manual_admission` and terminal `manual_result`. This provides the values needed for manual re-entry later; it does **not** promise to reproduce an evolving World from prompts alone or retain exact unlogged source World state. `Traffic…` displays the current session file path and can explicitly export it. Existing legacy and linked archives remain **unchanged** on disk, but are never attached to a new game session. The legacy archive parser remains available for standalone read-only diagnostics and old evidence tests; it is not part of the normal UI lifecycle. No automatic migration, deletion or cleanup is performed. PAINT's native authoritative Undo/Redo is independent of Art. When an Art window exists, confirmed Undo/Redo events may be appended to its current session log. Without an Art session, native editing does not force the Art panel or create a cross-session receipt journal. Old `user://art-pending-history` records are preserved as historical data and never injected into a new session. Disk logging failures remain visible, but must not retroactively repeat a native edit. **Scope boundary:** This is session-local authoring history, not a durable conversation database. Save/Open for the authored World and PAINT's own material history retain their existing independent contracts. New model requests must never trust a stale previous-session continuation pointer.

## DR25: Can I paint all four Strata Theatre planes in the ordinary Shared Workbench on main?

Canonical rank: 1

Expected facts:

- Standalone four-plane presentation/authoring exists within its own documented ownership.
- Ordinary Shared Workbench integration remains a separately unmerged candidate at the recorded source; do not conflate it with standalone availability.

### Rank 1: systems/depth-layers-and-parallax.md — Depth layers and parallax prototypes > Strata Theatre controls

Document: Depth layers and parallax prototypes
Path: systems/depth-layers-and-parallax.md
authority: current-documentation
document-kind: contract
status: Current
scope: Opt-in Strata Theatre and Deepworks material-world layering, authored dimensions, foreground-derived relief and explicit interlayer events; separate from production world ownership
canonical-for: [depth-layer-prototype, parallax-prototype, quantized-relief, interlayer-events]
last-reviewed: 2026-10-20
Section: Depth layers and parallax prototypes > Strata Theatre controls
- **1-5** — Flat / Relief / Four layers / Hybrid / Diorama. - **WASD / arrows** — camera pan. - **Space** — pause dynamic planes; **Step** advances admitted dynamic planes once. - **E** — rear reactor sequence. - **R** — reset all four worlds. - **Left mouse** — paint selected layer/material. - **Right mouse** — erase selected layer. - **Middle mouse** — toggle automatic camera motion. - **Tab** — hide/show controls. - **Esc** — return to a fresh ordinary sandbox. Background remains immutable even if selected as a paint target, making the failure visible rather than hiding it in UI policy.


### Rank 2: operations/cybersand-codex-development-handover.md — Development handover > Choose the correct owning contract

Document: Development handover
Path: operations/cybersand-codex-development-handover.md
authority: current-documentation
document-kind: guide
status: Current
scope: Current task intake, ownership and handoff; implementation status, intent and qualification have separate canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-11-24
Section: Development handover > Choose the correct owning contract
| Task | Read first | Preserve | |---|---|---| | Painting, generator application, Art drawing or history | [Shared authoring](../architecture/shared-workbench-authoring-data.md), [direct batches](../systems/workbench-direct-art-batches.md) | Baseline/revision identity, one edit ordering, native completion receipts, bounded cancellation and history semantics. | | Save, Flatten or persistent-area work | [Save formats](../reference/level-saves-and-replay.md), [owner Save intent](../reference/product-intent-and-priorities.md#save-flatten-and-compatibility) | Authored layout versus live physical state; Flatten is a two-byte material plane and does not reset the live World. Persistent-area candidates have separate owners. | | Materials, Water, reactions or Lab | [Materials](../systems/materials-and-rule-kernels.md), [Water families](../architecture/liquid-solver-family-policy.md), [Lab](materials-lab-authoring.md) | Material identity, effective consumers, family-specific quantity/physics, immutable compatibility evidence and reviewed source transitions. | | Actors, equipment or destruction | [Actor composition](../systems/workbench-actor-composition.md), [coupling](../architecture/rigid-body-and-cellular-coupling.md) | Main-thread Rapier, native material authority, producer leases and actual accepted capabilities. ObjectShard/actor/equipment successors remain separate candidates. | | Rendering, scheduling or physical progression | [Threading](../architecture/simulation-tick-and-threading.md), [rendering](../architecture/rendering-and-gameplay-bridges.md) | Snapshot lifetime, accepted worker ownership, physical progression evidence and public receipt identity. PUBPRES findings do not silently select a new architecture. | | Strata or scene depth | [Depth layers](../systems/depth-layers-and-parallax.md), [semantic planes](../systems/procedural-semantic-planes.md) | Standalone layered owners versus ordinary Workbench integration; Strata Theatre names the four-layer feature only. | | Provider integration | [Art providers](../systems/workbench-art-providers.md), [Art guide](workbench-art.md) | Current session-only lifetime, actual transport/receipt states, credentials and private traffic boundaries. No paid dispatch from a documentation test. | | Build, qualification or publication | [Build](local-build-and-validation.md), [release](github-development-and-release.md), [validation](testing-validation-and-replay.md) | Exact source/artifact/platform evidence, mandatory tests, guarded publication leases and explicit owner merge authority. |


### Rank 3: systems/depth-layers-and-parallax.md — Depth layers and parallax prototypes > Purpose

Document: Depth layers and parallax prototypes
Path: systems/depth-layers-and-parallax.md
authority: current-documentation
document-kind: contract
status: Current
scope: Opt-in Strata Theatre and Deepworks material-world layering, authored dimensions, foreground-derived relief and explicit interlayer events; separate from production world ownership
canonical-for: [depth-layer-prototype, parallax-prototype, quantized-relief, interlayer-events]
last-reviewed: 2026-10-20
Section: Depth layers and parallax prototypes > Purpose
res://depth_lab.tscn is an opt-in comparison host for visual and figurative depth in CyberSand. It deliberately keeps several ideas visible side by side instead of making one of them production authority. The lab is called **Strata Theatre**. It can be opened directly, with --depth-lab, or from the ordinary desktop sandbox with **F4**. [Deepworks](../operations/deepworks-exhibition.md) reuses these four material planes in a separate 1024 × 1024 exhibition host, opened with `--deepworks` or `res://deepworks.tscn`. Its sixteen districts, source programme, independent clocks and camera/painting controls belong to that guide. Strata Theatre retains its original default dimensions and controls. | View | Meaning | |---|---| | Flat | Foreground-only control. | | Quantized relief | Bounded quantized samples of the foreground material image are offset/scaled behind the source silhouette to imply thickness. | | Four layers | Four independently authored material worlds are rendered together with different scale/parallax factors. | | Hybrid | Four layers plus foreground relief, distance haze and rear-scene reflection masked by foreground liquid IDs. | | Diorama | Hybrid plus a faster near-camera foreground-derived frame and pointer-centred cutaway. | None of the presentation-only modes creates authoritative Z coordinates, colliders, hidden material mass or a second owner of the play world.


### Rank 4: operations/showcase-guide.md — Explore the showcases

Document: Explore CyberSand showcases and laboratories
Path: operations/showcase-guide.md
authority: current-documentation
document-kind: guide
status: Current
scope: Launcher navigation, distinct standalone demonstrations, genuine retained images and their limits
canonical-for: [showcase-navigation]
last-reviewed: 2026-11-24
Section: Explore the showcases
The feature launcher is a collection of distinct scenes and laboratories. Each entry has its own controls and reset behavior. **F2 returns to the launcher and closes the current session.** Save authored Workbench work before leaving it. | Launcher entry | Why open it? | Guide and boundary | | --- | --- | --- | | Development workbench | Paint, generate, place actors, run material experiments and save starts. | [First session](workbench-first-session.md); ordinary authoring front door. | | Materials Lab | Inspect effective native properties and compare candidate definitions. | [Materials Lab](materials-lab-authoring.md); candidate Worlds remain isolated. | | Player playground | Try seven movement presets on a shared course. | [Controls](../systems/player-control-playground.md); experimental handling, not physical acceptance. | | Deepworks | Explore sixteen districts with foreground/rear material exhibits and four material planes. | [Exhibition](deepworks-exhibition.md); free-camera viewer, not the ordinary actor session. | | Blacksite Nine | Traverse a continuous 3×3 industrial complex in one native world. | [Blacksite guide](blacksite-nine-demo.md); district camera changes preserve the complex. | | Neon Reliquary | Visit the machine cathedral and three district tiles below it. | [Scene guide](neon-reliquary-demo.md); switching district reconstructs that tile, not seamless streaming. | | Actor sandbox | Compare the articulated Rapier catalogue through F5. | [Physical actors](../systems/physical-actor-rigs.md); distinct from Workbench Actor Composition. | | Materials sandbox / Experiment Tower | Inspect structured native material experiments. | [Experiment Tower](experiment-tower.md). | | Liquid comparison / Wave Flow | Compare law-specific Water behavior and apparatus. | [Liquid comparison](lcb-manual-comparison-ux.md), [Wave evaluation](wave-flow-evaluation.md). | | Thunderbowl / Physical Thunderbowl | Exercise controller contracts, scripted pilots and physical equipment. | [Control reference](../systems/thunderbowl-control-reference.md); sampled virtual-tag rewards and physical lab have different scopes. | | 4LY Flight Lab | Inspect the dedicated physical drone training plant. | [Flight contract](../systems/physical-free-flight.md); calibration and handling claims are qualified separately. | | World generation workbench | Inspect generation stages and semantic authoring previews. | [Generation Workbench 2](../systems/generation-workbench-2.md); separate from the Shared Workbench generator dialog. | | Semantic depth | Compare generated refinery and cavern projections. | [Depth authoring](semantic-depth-authoring.md); four-plane semantic scene. | | Strata Theatre | Explore standalone layering, parallax and depth modes. | [Layered world contract](../systems/depth-layers-and-parallax.md); ordinary Workbench integration is a separate candidate. | The [World Art viewer](../tools/world-art-preview.md) supplies another standalone viewer/capture workflow. Its artwork dimensions are not native playable World limits. It is not an automatic import of every reference image into simulation.


### Rank 5: systems/depth-layers-and-parallax.md — Depth layers and parallax prototypes > Generated semantic-depth host

Document: Depth layers and parallax prototypes
Path: systems/depth-layers-and-parallax.md
authority: current-documentation
document-kind: contract
status: Current
scope: Opt-in Strata Theatre and Deepworks material-world layering, authored dimensions, foreground-derived relief and explicit interlayer events; separate from production world ownership
canonical-for: [depth-layer-prototype, parallax-prototype, quantized-relief, interlayer-events]
last-reviewed: 2026-10-20
Section: Depth layers and parallax prototypes > Generated semantic-depth host
[GEN-005](procedural-semantic-planes.md) adds a separate opt-in semantic depth scene using the same four-World and compositor owners. One native hierarchy produces all four proposals, typed links, finite fixtures and play-only actor placements. Its subclass validates complete copied bundles and owner-issued runtime observations; the original Strata/Deepworks commands retain their existing scopes. The base reset has a candidate-owner preparation hook before its commit, allowing the existing actor session to stage against candidate play without exposing a partly replaced World set. See [ADR-014](../decisions/ADR-014-semantic-plane-admission.md).

## DR26: The render FPS is high and texture uploads are fast. Does that prove physical simulation and actor movement are playable?

Canonical rank: 4

Expected facts:

- Rendering and upload timing do not alone establish physical progression, input responsiveness or owner playfeel.
- Use source-matched progression evidence and distinguish hosted/software rendering from physical GPU acceptance.

### Rank 1: architecture/overview.md — Architecture overview > How does data move on desktop and Web?

Document: Architecture overview
Path: architecture/overview.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current execution paths and authority map; routes to the contracts that govern changes
canonical-for: [architecture-entry-point]
last-reviewed: 2026-11-24
Section: Architecture overview > How does data move on desktop and Web?
Desktop has two scheduling levels: a dedicated Godot pacing Thread serializes World calls, and World's native pool parallelizes eligible jobs inside a tick. Rapier and presentation run on the main thread. Their copied observations can have different ages; high render FPS or a new status counter alone does not prove that native or physical progression is healthy. Web runs its controller and waits for native ticks on the main thread. Compatibility Web uses one cellular worker. Threaded Web may dispatch native pool work while the main thread waits; that is not asynchronous Web ownership. The [tick contract](simulation-tick-and-threading.md) records actual ordering, failure and pause behavior for each host. Native dirty RG8 patches update a persistent CPU image. Accepted main still uses `ImageTexture.update` on the full backing image; patch bytes are not GPU upload bytes. Palette, motion, relief and glow shaders derive appearance without changing stored material. The [render contract](rendering-and-gameplay-bridges.md) owns acknowledgements, dirty retention and this limitation. PUBPRES publication and presentation successors must be assessed through the [current roadmap](../reference/status-and-roadmap.md), rather than assumed to be present because their experimental documentation exists.


### Rank 2: operations/physical-actor-programme.md — Physical actors and combined feature trials > What did the owner observe and authorize on 2026-10-18?

Document: Physical actors and combined feature trials
Path: operations/physical-actor-programme.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Owner-authorized ACT-004 integration, retained Blacksite hull comparison and preserved 2026-10-18 actor preferences; not broad physics acceptance
canonical-for: [physical-actor-programme, combined-feature-launcher, physical-blacksite-comparison]
last-reviewed: 2026-10-22
Section: Physical actors and combined feature trials > What did the owner observe and authorize on 2026-10-18?
**Owner observations, not independently established physics facts:** the horizontal-impulse barrel felt physical and kinetic; its Water/barrel interaction was particularly convincing, but some Sand interactions tunnel too freely. Burial-safe sampled actors could become pinned by very small Sand/body overlaps. The sampled baseline in the material-effects build avoided that sticking but appeared more jittery. A matched policy/render comparison is required: PR #164 changes presentation, not movement semantics. Preserve these reports as separate observations rather than claiming the shaders fixed collision. The owner approved landing the existing presentation, generation and scene features, a combined launcher, and starting the physical barrel/Ripper trial. The following preferences were **Approved direction / Planned follow-up at intake**. They remain the owner-intent record; current implementation and its qualification are separately described above and in the physical actor contract: - Prefer experimental impulse/torque-driven Rapier machines; keep sampled reference arms for comparison. Add short high-power vertical pulses and torque to the physical player. Investigate granular interaction without inventing an actor-local displacement solver or duplicating #83 ownership. - Some actors must consist of several hinged physical bodies. Internal motors torque parts against each other; grounded propulsion must arise from contact. Reaction wheels/gyros justify bounded attitude authority; do not turn internal joint torque into unexplained free-flight propulsion. - Scrabbler: a Leaper-like articulated machine, using the supplied image as a stance/motion reference. Ripper: a fast low RC drift crawler; the written file also cites a Warframe Bursa. The short video emphasizes speed, slip and strong changes of direction. Pouncer: a cybernetic headcrab/flying or gliding squirrel. Digger: a rocket-powered mole that can screw into a burrow and travel along it horizontally or vertically, with explicit bounded excavation authority. - Copter should remain demanding and unstable but recoverable. Trial multirotors with different shape, speed, centre of mass, inertia, stability and thrust tradeoffs. Lineshank should be katana-slim with its centre of mass near the grip; trial rocket propulsion alongside the retained bungee version. - Rocketjumper should trial a Fire blob surrounded by a Gunpowder ring at the explosion, with bounded cell placement and explicit propulsion accounting. - Preserve Gyrocrate's lively feel and Bellows' character (the owner's image is an underappreciated food-delivery bot). Vector and Jolt are the preferred scripted-bot energy references; give other scripts more purposeful vigour through the same action authority available to human control. - Render actors using filled colour/texture polygons that exactly represent their actual collider parts, with optional outlines. Use the physical part definition and published transform as the shared source, including rotation. - Test in constrained Blacksite/Neon spaces as well as reduced


### Rank 3: architecture/simulation-tick-and-threading.md — Simulation tick and threading > Current execution boundaries

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > Current execution boundaries
At accepted main `00cdb02f`, desktop uses a dedicated **GDScript pacing owner** and a separate **native pool** inside `World::tick`. Main-thread Godot owns Rapier and textures. The pacing owner may invoke its exclusive adapter and value APIs; native pool workers call no Godot APIs. Web instead waits for native ticks on its main-thread controller. These are distinct owners, even where all calls eventually reach the same native World implementation. | Progress signal | What it establishes | What it does not establish | |---|---|---| | Completed native tick | That World completed one admitted tick | A new rendered frame or a Rapier step | | `worker_threads_observed` | Distinct task claimants in the most populated completed phase | Concurrent utilization or frame-rate benefit | | Published render serial | A copied render publication exists | GPU consumption or physical actor progress | | Main-thread render FPS | Presentation frames complete | Unstalled cellular or Rapier simulation | | Owner/native receipt | Its identified operation reached the documented stage | Durable Save or full-session replay unless separately recorded | The accepted renderer still performs full-image texture updates. PUBPRES successor investigations remain separate from this source description. Use the [render contract](rendering-and-gameplay-bridges.md) and [current roadmap](../reference/status-and-roadmap.md) for their boundaries. Sources: [`_worker_loop`](../../godot/scripts/simulation_worker.gd), [`World::tick`](../../native/src/world.cpp), and [`main.gd`](../../godot/scripts/main.gd). The following PLAY measurements retain their original source, platform and fixture identities. Their historical timings are not fresh results for the 24 November source.


### Rank 4: operations/profiling-observability-and-performance.md — Profiling, observability, and performance > Avoid common misreadings

Document: Profiling, observability, and performance
Path: operations/profiling-observability-and-performance.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Current native/Godot observations, benchmark procedure, metric boundaries, and unimplemented production telemetry
canonical-for: [performance-measurement, metric-interpretation]
last-reviewed: 2026-10-31
Section: Profiling, observability, and performance > Avoid common misreadings
| Pattern | Next investigation | |---|---| | One core busy, others idle | Phase job count versus dispatch threshold; a persistent pool can intentionally run sparse phases serially | | Small dirty patch KiB but low FPS | Full GPU texture update, synchronization, palette/glow, or unrelated presentation work | | Large collider peak, small Rapier step | Separate geometry extraction, packet copy/validation, and indivisible collider rebuild | | High snapshot pressure/age | Consumer lag and retained dirty payload | | Material appears still after camera return | Check failure status and selected cores against the [pause/re-entry contract](../systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry); retained offscreen activity is not selected work | | Active work never settles | Equivalent state changes, wake feedback, or genuine lifecycle work | | Persistent unresolved body pixels | Bounded ejection exhausted, stale samples, or dense surroundings | | Visually moving surface with stable content | Presentation-time shader motion; inspect authority before changing simulation | The collider consumer's 32-chunk/750 µs limits are checked between chunks and exclude extraction/packet handling; one chunk may exceed the time budget. Only rebuilt chunks count against the chunk limit. The workbench lock-step publishes every hard-surface revision and installs it with a 128-chunk/4 ms budget. The 2026-11-06 [whole-engine benchmark](../audits/2026-11-06-whole-engine-bench.md) shows why: with reacting terrain the 250 ms packet throttle capped a session at about 4 ticks/s. `ImageTexture.update` still uploads the full 2,097,152-byte RG8 image for a changed native publication. Dirty bridge bytes cannot substitute for that cost.


### Rank 5: architecture/principles-and-non-goals.md — Architectural principles and non-goals > Which Current exceptions must remain visible?

Document: Architectural principles and non-goals
Path: architecture/principles-and-non-goals.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Accepted architectural constraints, explicit current exceptions, deferred scope and rejected approaches
canonical-for: [architectural-constraints-and-rejected-shortcuts]
last-reviewed: 2026-09-08
Section: Architectural principles and non-goals > Which Current exceptions must remain visible?
World still combines several production responsibilities. Lazy coordinator preparation may allocate chunks/temperature during a tick; preallocation covers those measured allocation classes. The desktop emission queue and Godot render accumulation are dynamic arrays, not general bounded native queues. Godot still uploads the full RG8 texture after dirty CPU patching. The GDScript solver remains a desktop fallback with different semantics. Sources: [World](../../native/src/world.cpp), [worker](../../godot/scripts/simulation_worker.gd), [renderer](../../godot/scripts/main.gd), [fallback](../../godot/scripts/cell_world.gd). These exceptions require honest scope; they are not permission to extend them into new hidden ownership or allocation paths.

## DR27: Does enabling Web pthreads make the browser keep presenting while a native tick is running?

Canonical rank: 1

Expected facts:

- Web native tick ownership remains synchronous; internal pthreads do not establish asynchronous presentation.
- Desktop has separate simulation-owner scheduling; do not promise backend parity.

### Rank 1: operations/web-threading.md — Web worker profiles and reference tests

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests
**Current:** compatibility Web uses one native cellular worker; optional threaded Web uses the existing phased pool. Both synchronously finish a cellular tick in Godot's `_physics_process`; Rapier stays on Godot main. Pthreads do not create desktop-style asynchronous simulation/render ownership. That extension is **Deferred**. Source identity is in the [checkpoint](source-checkpoint-and-recovery.md), dated native/browser evidence in the [validation ledger](../reference/validation-evidence.md), and historical timing/failure records in the [performance archive](../audits/2026-09-08-performance-history.md).


### Rank 2: operations/web-threading.md — Web worker profiles and reference tests > Acceptance and unresolved limits

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Acceptance and unresolved limits
Use the [local validation procedure](local-build-and-validation.md) and the host guide at `C:/kybersand/docs/BROWSER_VALIDATION.md`, then verify both profiles: actual worker count, native exception rejection, render patches, input/menu/pause/reset, level import and replacement-world lifecycle. Physics Pit has separate [Rapier acceptance](rapier-2d-migration-runbook.md). Historical tests exposed a stall with 12 prewarmed pthreads; a later four-worker export used 24, and current Auto exports use 32. The preserved record does not establish the minimum safe pool or robustness on every low-core device. Retest replacement, import, benchmark cancellation, and pool release whenever sizing changes. Browser/device coverage, complete replay, and production frame-time thresholds remain incomplete.


### Rank 3: operations/local-build-and-validation.md — Local build and validation > Web compile, export and execution are different checks

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Web compile, export and execution are different checks
From source, with the SDK active and paths adapted to the host: ```text python tools/build_web.py --cpp <web-godot-cpp> --compile-only python tools/build_web.py --cpp <web-godot-cpp> --godot <godot> --templates <templates> ``` The default profile is compatibility. Add `--profile threaded` for pthreads. Both normal profiles package Rapier; `--cellular-only` is a diagnostic option. `--native-tests` requires a separate `--native-cpp` directory. `--compile-only` returns before runtime tests/export even if `--native-tests` is present. `--export-only` checks existing WASM structure, not freshness against source. The workspace wrapper still supplies the acquisition base as `--source-commit`; that export field is not current HEAD. Capture current source and artifact hashes separately until the producer is repaired in an implementation checkpoint. See [source identity](source-checkpoint-and-recovery.md). Preview generated output through HTTP with WASM MIME and profile headers, then run the actual browser fixture. Checksums/HTTP checks prove packaging; native headless Godot proves native execution; only browser execution tests Web behavior. The [Web guide](web-threading.md) owns hosting requirements, and the [validation ledger](../reference/validation-evidence.md) owns dated outcomes.


### Rank 4: operations/local-build-and-validation.md — Local build and validation > How is the physics baseline rebuilt?

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > How is the physics baseline rebuilt?
Follow [physics characterization](physics-characterisation.md): rebuild the native CLI and adapter before running the deterministic P1–P4 matrices, then build/export both Web profiles and execute them in a real browser. Capture actual HEAD/local file hashes separately from legacy export acquisition labels. The [2026-09-09 report](../audits/2026-09-09-physics-characterisation.md) records Windows/Web results and the unavailable Linux execution environment. Local rebuilt artifacts are measured inputs, not automatically updated published LFS runtime manifests; the current release gate remains separate from M11 integrity. For the standalone CLI's current material-admission and sampled-accounting gate: ```sh timeout 300 make physics-characterisation-test ASAN_OPTIONS=detect_leaks=1:strict_string_checks=1 \ UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \ timeout 300 make physics-characterisation-sanitize ``` The sanitized command includes leak detection when the execution environment supports process inspection. Native CI uses its explicitly recorded ASan/UBSan scope. Both targets compile the actual CLI and retain per-invocation JSON/stdout, stderr and the executable hash under `build/physics-cli-validation/`. The [measurement-path contract](physics-characterisation.md#which-checks-guard-the-measurement-path) defines the 132-entry output and independent accounting oracle. Issue #10 uses the [current acceptance commands](physics-characterisation.md#how-do-i-reproduce-issue-10-acceptance) and [its own artifact audit](../audits/2026-09-09-issue-10-granular-policy.md). Both native Web modules were rebuilt before final script exports. The shared threaded probe must yield before replacing a newly constructed default world, after replacement and after teardown so browser pthread startup/recycling can finish before synchronous native joins. This fixture lifecycle requirement does not change production native ownership or introduce asynchronous Web simulation.


### Rank 5: operations/web-threading.md — Web worker profiles and reference tests > Reference benchmark and parity checks

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Reference benchmark and parity checks
Open Web **Performance**: - **Benchmark:** supported actual worker counts from requested 1, 2, 4, 6; deterministic 480×480 and 960×960 Sand/Water worlds; ten warmup ticks then 120 measured ticks per case with deterministic replenishment. - **Stress test:** Auto at 960×960, ten warmup then 600 measured ticks. - **Cancel/Escape:** checked between ticks, with a two-minute case limit. A native tick already running must finish before cancellation. [worker_benchmark.gd](../../godot/scripts/worker_benchmark.gd) uses temporary worlds, restores the process worker setting, and compares final exported-level hashes. Reports include requested/actual workers, mean/p95/max native time, test frame intervals, moves, parallel phases, and level hash. Frame intervals include test/UI scheduling, not normal gameplay rendering. Copy results selects JSON and attempts clipboard copy; the last successful report is stored at `user://last_worker_benchmark.json`. Local commands use the same headless Godot fixture: ```powershell .\dev.cmd benchmark .\dev.cmd stress-test ``` Logs/reports go to `validation/local/<timestamp>/`. Compare native tick timings with browser tick timings, not headless versus browser frame intervals. The opt-in URL `?test=1&parity=1` additionally runs the one/four-worker four-demo probe: 30 ticks each, 120 exported-level hashes. It is also [test_web_worker_parity.gd](../../godot/tests/test_web_worker_parity.gd). Neither this nor the performance hash comparison proves complete replay state, Rapier trajectory equivalence, or all-platform equality.

## DR28: Can I publish a rebuilt native DLL by editing its hash in the provenance JSON?

Canonical rank: None

Expected facts:

- No: publication requires source-matched build and execution evidence, artifact identity and guarded branch/source custody.
- A hand-edited hash or stale predecessor pass is not qualification; preserve exact LFS object and source inputs.

### Rank 1: reference/validation-evidence.md — Validation evidence ledger > Source and artifact custody

Document: Validation evidence ledger
Path: reference/validation-evidence.md
authority: current-documentation
document-kind: reference
status: Current
scope: How to locate and interpret source-bound validation; dated results do not certify a new runtime or every platform
canonical-for: [validation-results, platform-evidence, historical-evidence-boundaries]
last-reviewed: 2026-11-24
Section: Validation evidence ledger > Source and artifact custody
```mermaid flowchart TD S["Source commit and input hashes"] --> B["Runtime build and hash"] S --> T["Test source and commands"] B --> E["Executed artifact receipt"] T --> E E --> P["Package and shipped launcher"] P --> O["Physical owner evaluation"] ``` Each stage records its own identity and result; none is inferred from the previous stage. Documentation-only commits may preserve exact native input bytes while changing the overall Git tree. Keep the original native build commit and the actual tested script/source identity. Conversely, an old successful run cannot qualify changed native input merely because the DLL still loads. The selected [Windows native provenance](../../godot/addons/cybersand_native/runtime-provenance.json) and [Linux native provenance](../../godot/addons/cybersand_native/runtime-provenance.linux.json) contain source inputs, artifact hashes and original workflow evidence. Rapier has its own [Windows](../../godot/addons/godot-rapier2d/runtime-provenance.windows.json) and [Linux](../../godot/addons/godot-rapier2d/runtime-provenance.linux.json) records. Use [source custody](../operations/source-checkpoint-and-recovery.md) and [publication procedure](../operations/github-development-and-release.md) for verification and branch leases.


### Rank 2: operations/wb-art-paint-integrated-candidate.md — Integrated PAINT and agent Shared Workbench > Final hardening and evaluation — 2026-11-12 > Evaluate the delivered package

Document: Integrated PAINT and agent Shared Workbench candidate
Path: operations/wb-art-paint-integrated-candidate.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Unmerged Draft candidate, generator packaging repair, native stored-material receipts, ordered human and agent authoring with shared Undo/Redo, reproducible qualification and owner acceptance
canonical-for: [integrated-paint-agent-workbench]
last-reviewed: 2026-11-12
Section: Integrated PAINT and agent Shared Workbench > Final hardening and evaluation — 2026-11-12 > Evaluate the delivered package
Extract the complete standalone Windows archive into a fresh folder, then double-click **Open Workbench.cmd**. No Git checkout or development-machine paths are required. The first launch imports the packaged project. Its `candidate-manifest.json` identifies the exact application commit/tree and payload hashes; the delivered native DLL has its own candidate provenance. This runbook is included as `READ-ME.md`. - Open **New from generator…**, choose a populated profile and install a map. - Pause; use Brush/Eraser, Line, Rectangle/Outline and several native materials. - Fill a closed pocket; Select, Copy/Paste, then Undo/Redo. - Open **Art batches**, draw inside a bounded area, alternate with human edits, and Stop a longer operation. Confirm that further editing still works. - Run and pause simulation; interact with the existing physical equipment. - Save a named start, exit Godot completely, launch again and Load that name. Check both editors' authored materials, actor/equipment configuration and settings, then continue editing. Expect the authored start, not a physics checkpoint of the evolved world. The retained repository runtimes still have four native-source mismatches per platform: `cyber_demo_bridge.hpp`, `cyber_native_cell_world.cpp/.hpp` and `cyber_prepared_liquid_world.hpp`. The separate source-built evaluation package does not promote those tracked binaries or rewrite their historical manifests. Tracked-runtime publication and the full materialized-provenance gate remain explicit merge requirements, alongside owner desktop acceptance. Keep Draft.


### Rank 3: operations/cybersand-codex-development-handover.md — Development handover > Establish source and runtime identity

Document: Development handover
Path: operations/cybersand-codex-development-handover.md
authority: current-documentation
document-kind: guide
status: Current
scope: Current task intake, ownership and handoff; implementation status, intent and qualification have separate canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-11-24
Section: Development handover > Establish source and runtime identity
From the intended source checkout: ```bash git rev-parse --show-toplevel git status --short git branch --show-current git rev-parse HEAD 'HEAD^{tree}' git log -1 --format='%H %cI %s' git lfs ls-files ``` Review remote configuration locally if needed; do not paste credential-bearing URLs into an issue or report. `git lfs ls-files` identifies tracked objects; it does not prove every required object is materialized or that the runtime matches changed native source. Run the appropriate [repository/provenance check](current-and-historical-validation.md) and compare the selected runtime's input ledger before launch or packaging. The pinned executable version is `4.7.stable.official.5b4e0cb0f` in [the Godot lock](../../third_party/godot-runtime.lock.json). A nearby patch release is not the same qualification target. The native locks, per-platform runtime provenance and Rapier provenance are separate records. A documentation-only head can legitimately retain a runtime built at an earlier commit when all recorded source inputs still match; do not relabel its build commit as the documentation head. Conversely, matching a DLL filename does not establish source identity. Use an isolated test profile for application procedures. Do not overwrite owner maps, Art archives, provider settings or ordinary user data to make a test pass. Portable evaluators, source checkouts, rebuilt runtimes and Web/fallback paths have different prerequisites; [getting started](getting-started.md) and [local builds](local-build-and-validation.md) explain them.


### Rank 4: operations/local-build-and-validation.md — Local build and validation > Windows development commands > Repository-contained Windows desktop launcher

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Windows development commands > Repository-contained Windows desktop launcher
**Current:** a source checkout can launch the retained desktop test project without the companion-workspace `dev.cmd`: ```powershell .\launch-desktop.cmd .\launch-desktop.cmd -Godot C:\path\to\Godot_v4.7-stable_win64.exe .\launch-desktop.cmd -PrintIdentityOnly .\launch-desktop.cmd -Editor ``` The wrapper invokes [`tools/launch_desktop.ps1`](../../tools/launch_desktop.ps1). It accepts an explicit `-Godot` path or `CYBERSAND_GODOT`; otherwise it searches the established `C:\Godot47` location. It requires exactly `4.7.stable.official.5b4e0cb0f`, verifies that the project, retained CyberSand Windows DLL/provenance file and Rapier Windows DLL are present, verifies the CyberSand DLL SHA-256 against `runtime-provenance.json`, and prints checkout, Godot and runtime identities before launch. The default action runs `godot/project.godot` through its configured `feature_launcher.tscn`; `-Editor` opens the same project in the editor. The launcher deliberately contains **no build step**. A missing, hash-mismatched or wrong-version runtime is an explicit failure; it never rebuilds, replaces or silently refreshes the retained DLL. M11 output byte equality now requires `CYBERSAND_VERIFY_M11_OUTPUT=1`; current builds keep compiler/source pin checks and identify their own tested outputs. See [validation policies](current-and-historical-validation.md). The existing local `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` override bypasses some compiler/dirty-source checks. It still requires the exact godot-cpp revision. Inspect that checkout explicitly; a local validation build with this override is not bit-identical M11 reproduction.


### Rank 5: operations/wb-art-paint-integrated-candidate.md — Integrated PAINT and agent Shared Workbench > Earlier application checkpoint and standalone packaging defect — 0025bd94

Document: Integrated PAINT and agent Shared Workbench candidate
Path: operations/wb-art-paint-integrated-candidate.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Unmerged Draft candidate, generator packaging repair, native stored-material receipts, ordered human and agent authoring with shared Undo/Redo, reproducible qualification and owner acceptance
canonical-for: [integrated-paint-agent-workbench]
last-reviewed: 2026-11-12
Section: Integrated PAINT and agent Shared Workbench > Earlier application checkpoint and standalone packaging defect — 0025bd94
The earlier qualified application checkpoint is `0025bd942850e6e75e77d4beb9c4885d7dc1b2f4`, tree `6fff8a8c833eb65f4297d6fd07ef9f5edf336c0d`. A subsequent packaging repair preserves the application implementation. The complete #544 and #560 heads and accepted main `d8588716becb0dc42019faf23f721378d8adc84a` remain ancestors. Neither original PR has been closed, and no Ready, auto-merge or merge action has been taken. **Historical package HOLD, resolved by the d33c10e4 replacement above.** Independent inspection of the 0025bd94 Windows archive found that Rapier imports `VCRUNTIME140.dll`, but the archive omitted it; the hosted machine supplied it. The referenced Rapier build lock and cooperative-BVH patch were also omitted. Artifact 13984970914 is retained as failure evidence and must not be treated as the final standalone candidate. Its ZIP SHA-256 is `87503652ced5b83aa106b7377f13e0b4130b776dc7d960d9612601223eca3ffe`. The targeted repair stages the unmodified, signed x64 Visual Studio 2022 release redistributable beside Godot, with Microsoft runtime and redistribution licences, file version/hash, signer and build-host provenance. Both referenced Rapier files are included. The installed suite runs the executable in each copied installation; a separate Windows process-module check requires the actual Godot process to load the bundled runtime, native extension and Rapier from that copied installation. Publication is gated on those checks and the complete dedicated campaign. They passed for the d33c10e4 package above. Consult [PR #564](https://github.com/techrote/cybersand/pull/564) for the current source and the separate qualification of subsequent history changes. The package's `candidate-manifest.json` and `source-built-candidate-provenance.json` identify its exact source and native inputs; `vc-runtime-provenance.json` identifies the Microsoft bytes and licences. To reproduce a recorded package, retain that runtime stage (the three named payload files plus its provenance) and pass it as `--vc-runtime` to the packager, alongside the pinned Godot and source-built native inputs. Staging from a newer hosted VS image may deliberately select a newer signed release runtime and produces a different recorded runtime hash. The [0025bd94 dedicated campaign](https://github.com/techrote/cybersand/actions/runs/43301146659) passed all three jobs: pinned Windows build, actual Linux X11 execution and actual Windows ANGLE execution in fresh standalone layouts. **Each platform passed 7,358 directly counted assertions:** 521 installed, 6,729 regression and 108 provider HTTP assertions. Imports, duplicate completion markers and the HTTP wrapper do not inflate that total. HTTP error/cancel/timeout controls also passed but expose no numeric assertion count and are not added to it. | Combined workflow, on each platform | Native workers | Author / fresh-reopen checks | | --- | --- | --- | | Installed 1024² map, including a 147,456-cell Fill | 1 and 4 | 170 / 41 at each setting | | Source-layout 512² map | 1 and 4 | 151 / 38 at each setting | All eight author/reopen pairs across both platforms reproduced the complete

## DR29: A documentation or implementation Draft has skipped expensive jobs. Can I mark it Ready or merge it automatically?

Canonical rank: 1

Expected facts:

- Draft skips are not behavior passes and Ready/merge remain explicitly owner-controlled under this mission.
- Implementation acceptance needs all applicable exact-head gates; documentation qualification does not prove runtime or physical acceptance.

### Rank 1: operations/github-development-and-release.md — Repository development and release > Current CI provider and draft gating

Document: Repository development and release
Path: operations/github-development-and-release.md
authority: current-documentation
document-kind: guide
status: Current
scope: Contribution boundaries, Draft qualification, source-matched runtime publication and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-11-24
Section: Repository development and release > Current CI provider and draft gating
Routine active CI uses literal GitHub-hosted runner labels. The [provider-policy checker](../../tools/ci/check_ci_provider_policy.py) rejects `.circleci/config.yml`, active external-provider routing tokens, `*_RUNNER` indirection and unsupported `runs-on` values. Historical provider experiments are evidence, not permission to change this policy. Any authorized provider migration must update the canonical policy and checker together. Draft PRs intentionally suppress expensive Native, GDExtension/Godot and scoped Water execution while retaining cheap documentation/provenance checks. For an implementation PR, the owner-controlled Ready transition enables the applicable final qualification. A policy/docs-only scope result or Draft skip is not a runtime pass. This documentation mission remains **Draft/HOLD** until explicit owner review; it does not promote, merge, release or change defaults. Before an implementation merge, record the exact resulting-head Documentation/provenance result and every applicable Native, GDExtension/Godot, scoped apparatus and graphical gate. A source-sensitive provenance mismatch is a blocker, even when an earlier binary ran successfully. Inspect actual completed jobs and original readbacks; a workflow badge alone cannot establish full coverage. The [development-claims programme](development-claims-remediation-programme.md) separately owns completion and active-implementation ownership semantics.


### Rank 2: operations/wb-art-paint-integrated-candidate.md — Integrated PAINT and agent Shared Workbench > Qualified agent Undo/Redo candidate — 86d704a2

Document: Integrated PAINT and agent Shared Workbench candidate
Path: operations/wb-art-paint-integrated-candidate.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Unmerged Draft candidate, generator packaging repair, native stored-material receipts, ordered human and agent authoring with shared Undo/Redo, reproducible qualification and owner acceptance
canonical-for: [integrated-paint-agent-workbench]
last-reviewed: 2026-11-12
Section: Integrated PAINT and agent Shared Workbench > Qualified agent Undo/Redo candidate — 86d704a2
ASan configuration disables leak detection. The [Native/documentation audit](../audits/wb-art-paint-2026-11-12/agent-undo-hosted-native.json) preserves the original command, source and output hashes. The [complete Godot campaign](https://github.com/techrote/cybersand/actions/runs/43323028725) passed all 50 executing jobs: **299 Linux cases and 278 applicable Windows headless cases**, with 43 import preflights counted separately. All 21 rendered cases excluded from that Windows headless matrix passed on Linux; the dedicated Windows graphical campaign above is separate. The new native Undo test passed 260 checks on each platform with all 40 material-capture witnesses identical. See the [Godot audit](../audits/wb-art-paint-2026-11-12/agent-undo-hosted-godot.json). **GO for owner evaluation; HOLD for merge.** Retained repository runtime publication/materialized provenance, the separate Palette backend gate and owner desktop acceptance remain outstanding. Administrative Ready checks, optional physical-actor stress and the Draft-skipped published-runtime provenance step are not passes. This work does not authorize Ready or merge.


### Rank 3: systems/workbench-direct-art-batches.md — Direct art batches — WB-ART-002 Stage 1 > Qualification and launch

Document: Direct art batches, WB-ART-002 Stage 1
Path: systems/workbench-direct-art-batches.md
authority: current-documentation
document-kind: contract
status: Current
scope: Unmerged desktop direct drawing candidate, stored-native completion, Stop, shared PAINT ordering and Undo/Redo, authored-start persistence
canonical-for: [workbench-direct-art-batches]
last-reviewed: 2026-11-12
Section: Direct art batches — WB-ART-002 Stage 1 > Qualification and launch
Run from the candidate checkout with its pinned Godot 4.7/native runtimes: ```powershell C:/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/test_art_batch_native.gd C:/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/test_workbench_input.gd C:/Godot47/Godot_v4.7-stable_win64_console.exe --path godot -- --workbench ``` Linux graphical case: `xvfb-run -a GODOT --path godot --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/test_art_batch_native_render.gd`. Set `WB_ART_EVIDENCE_DIR` to an existing/creatable directory to retain the original post-draw PNG. CI's normal `CYBERSAND_TEST_ARTIFACT_DIR` is also supported. The `_render` suffix routes the wrapper through the repository's existing graphical runner; both tests are automatically discovered. Draft-skipped production CI is not a pass. Dated execution details and runtime hashes are recorded in the Stage-1 PR/issue handoff. Windows headless/native checks and Linux rendered checks are distinct from human Windows graphical acceptance and from later genuine model inference. The test explicitly uses two native workers, without changing production defaults. The shared apply seam publishes current frame settings before preparation captures its revision, fixing first-render construction retirement reproduced in Xvfb. No merge or Ready promotion is authorized.


### Rank 4: systems/paint-editor-bounded-shapes.md — PAINT-001 — bounded painting editor > Preserved failure history and integration boundary

Document: PAINT-001 native-backed Workbench painting editor
Path: systems/paint-editor-bounded-shapes.md
authority: current-documentation
document-kind: design
status: Current
scope: Mounted Draft PAINT-001 candidate on the shared Workbench; bounded native painting and reconstructible authored starts, not evolved simulation checkpoints
canonical-for: []
last-reviewed: 2026-11-12
Section: PAINT-001 — bounded painting editor > Preserved failure history and integration boundary
The original 8 November documentation run [42482388310](https://github.com/techrote/cybersand/actions/runs/42482388310) failed because this focused document lacked corpus registration. The 11 November candidate changes its unsupported `document-kind: system` to `design` and consumes the existing #550 registration delta unchanged from `9e4a25596e4c810d037ffb5f54f9bd98c108e7eb`. It does not independently redesign the Integration-owned retrieval manifest. The original static Python reverse-drag mirror was useful but not execution proof. The original GDScript regression now genuinely passes. Initial development logs are retained for the accidentally selected Godot 4.6 runtime, missing toolbar parenting, stale test helper names, capture conversion and JSON integer/float test comparisons. They are superseded only by identified corrected runs. Draft-skipped hosted native jobs are not passes. The updated source-matched Windows/Linux qualifications are explicitly recorded above; owner-human GUI acceptance, combination with the two other Draft branches, and merge remain outstanding. This document does not authorize promotion or merging.


### Rank 5: operations/local-build-and-validation.md — Local build and validation > Actor control prototype checks > Physical free-flight checks

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Actor control prototype checks > Physical free-flight checks
The internal [4LY family](../systems/physical-free-flight.md) uses the same pinned Godot 4.7, Rapier 0.35.2 and source-matched native runtime. Import the project first, then run these automatically discovered fixtures from the source root: ```text godot --headless --path godot --script res://tests/test_physical_flight_profile.gd godot --headless --path godot --script res://tests/test_physical_flight_session.gd godot --headless --path godot --script res://tests/test_physical_flight_physics.gd godot --headless --path godot --script res://tests/test_physical_flight_handling.gd godot --headless --path godot --script res://tests/test_physical_flight_selection.gd # The following actual-framebuffer case must run with a real display: godot --path godot --script res://tests/test_physical_flight_gameplay_render.gd ``` The profile fixture checks the closed schema, numerical limits, canonical profile/controller hashes, force/torque response and goal-blind pure controller. The session fixture checks the one-body/no-equipment topology for all four IDs, strict two-output input, copied observations, producer parity and lifecycle fences, including actual-step receipt attribution and rejection of incorrect host step ordering. The original physical fixture requires real Rapier and native World: unsupported Trainer hover, ascent/descent, neutral braking, attitude recovery, explicit power-off fall, underpowered gravity saturation, high-momentum bounded actuation and native hard-contact integration. **4LY-002 adds two headless cases and one graphical capture case:** `test_physical_flight_handling.gd` uses the same four real Rapier physics fixtures and normalized commands for every profile, and separately compares braking under an identical +20 cell/s physical impulse. It also measures unsupported neutral hover, response onset, 60/120-step velocities, reversal, up/down motion, angular recovery, the bounded force/torque receipt, passive power-off coast and the actual static wall. The fixture parses the [prospectively registered numeric gate](../../godot/tests/fixtures/4ly002_handling_thresholds.json) and prints a `4LY_002_HANDLING_METRICS` JSON line with the profile hashes and actual measurements. `test_physical_flight_selection.gd` exercises real main scene F5 selector entries, no-equipment enforcement, same-source ownership, fresh reset fences, scripted/policy choices, multi-drone demo, exploratory map retention and return to sampled gameplay. `test_physical_flight_gameplay_render.gd` (Linux `*_render` display shard) opens the **actual ordinary main sandbox**, selects all four drones in turn, submits observation-fenced policy velocity requests through the normal host, and retains full GL viewport PNGs plus controller/profile and physical motion metadata under `CYBERSAND_PRESENTATION_EVIDENCE`. It is **descriptive gameplay evidence**, not a subjective handling preference or an alternative motion implementation. The case does not run on headless Windows. These fixtures must execute against actual backend/runtime/source identities; a skipped display/backend, script error or pending check is **not** acceptance. Run the existing physical catalogue/session/rig/equipment, sampled reference and protected scientific-fixture regressions when changing shared owners. The five original flight cases join the existing Linux and Windows Godot discovery; the new `*_render` capture joins **only the Linux display suite**; no separate provider or external runner is required. Draft-skipped expensive checks do not qualify the implementation. Before merge, follow the [exact-head release gates](github-development-and-release.md) and record source, runtime, commands, outcomes and

## DR30: May I use the native-scope advisory to skip required jobs or copy an unmerged higher-fanout CI experiment into production policy?

Canonical rank: 1

Expected facts:

- The source-scope advisory does not authorize native skipping.
- Use accepted workflow policy; separate ongoing optimization experiments and preserve mandatory case coverage.

### Rank 1: operations/github-development-and-release.md — Repository development and release > Parallel validation and source-scope advice — 2026-10-31

Document: Repository development and release
Path: operations/github-development-and-release.md
authority: current-documentation
document-kind: guide
status: Current
scope: Contribution boundaries, Draft qualification, source-matched runtime publication and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-11-24
Section: Repository development and release > Parallel validation and source-scope advice — 2026-10-31
This stable heading now routes to the accepted [CI execution and performance policy](ci-execution-and-performance.md). It owns source-derived matrices, complete budgets, required coverage and advisory timing. Current workflow files are the scheduling implementation. Separate CI optimization candidates and their measurements stay candidates until accepted; documentation must not promote their fan-out, runner use or timing result. The [Native source-scope advisory](../../.github/workflows/native-scope-advisory.yml) is informational and sets `native_skip_authorized=false`. It authenticates source identity and examines both sides of renames; no required job consumes an exemption. Changing dependency-aware skip policy needs its own owner decision and qualification. Missing, foreign-source, duplicated, incomplete or failed required evidence cannot be repaired by treating a skipped aggregate as success.


### Rank 2: operations/local-build-and-validation.md — Local build and validation > Linux GDExtension CI sharding

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Linux GDExtension CI sharding
The accepted [GDExtension workflow](../../.github/workflows/gdextension.yml) builds a source-matched Linux runtime and plans regression jobs from the current source inventory. The [execution planner](../../tools/ci/godot_job_plan.py) supplies shard counts and budgets; `max-parallel` is a concurrency cap, not a fixed number of required tests or a promise that four shards are sufficient. Do not copy an unmerged runner experiment into the current procedure. The local/default invocation is serial. Rendered cases need a display; this source-supported software-rendered route is useful on a prepared Linux host: ```sh LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 GALLIVM_PERF=nopt xvfb-run -a \ -s '-screen 0 1920x1080x24 -nolisten tcp' \ python3 tools/ci/run_godot_regressions.py --godot "$CYBERSAND_GODOT" \ --output build/godot-regressions --keep-going ``` The runner discovers `godot/tests/test_*.gd`, includes the explicit profile probes and scene startup, and performs a clean import. Cases requiring actual pixels use the compatibility renderer. Missing display/executable, timeout, explicit skip, engine/script error and incomplete evidence are distinct failures; process exit zero alone is insufficient. `--keep-going` retains later case results after ordinary failure, while import failure stops the shard. The independent [Linux coverage reader](../../tools/ci/verify_linux_godot_shards.py) requires complete unique assignments, original logs and source/runtime identity. The accepted [test-selection guide](testing-validation-and-replay.md#ci-execution-sharding) and [CI policy](ci-execution-and-performance.md) own coverage and parent budgets. Historical four-shard migration timings remain dated evidence, not a current source inventory or physical GPU performance measurement.


### Rank 3: operations/ci-execution-and-performance.md — CI execution watchdogs and advisory performance > Shared capacity and concurrency

Document: CI execution watchdogs and advisory performance
Path: operations/ci-execution-and-performance.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Independent scheduling estimates, Godot and native watchdogs, hosted safety boundaries, retained failures and comparable performance history
canonical-for: [ci-execution-watchdogs, advisory-performance-history, ci-scheduling]
last-reviewed: 2026-11-21
Section: CI execution watchdogs and advisory performance > Shared capacity and concurrency
The GDExtension matrices each use `max-parallel: 8`. Together with Native's six families, the routine regression phase can use 22 slots before small auxiliary jobs. This leaves capacity within the owner's stated 40 standard hosted slots, but is not an account-wide cap: multiple PRs and other repositories add demand. Physical stress has its own smaller matrix budgets. Launch exceptional campaigns deliberately and use the [workflow audit](../audits/2026-11-01-ci-workflow-audit.md) and machine inventory when changing independent fan-out. Automatic GDExtension, Native and Documentation PR runs group by PR identity and cancel superseded checks. Main pushes and manual qualification use run identity, so a same-ref experiment cannot block or cancel a newer explicit qualification. No broad repository lock is introduced. Cancelled checks are not successful qualification, and original completed or failed artifacts retain their status. GitHub's default concurrency queue replaces an older pending member even when `cancel-in-progress` is false; run-unique manual groups avoid that hidden loss. See [GitHub concurrency semantics](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).


### Rank 4: operations/ci-execution-and-performance.md — CI execution watchdogs and advisory performance > Scheduling estimates and hosted safety boundaries

Document: CI execution watchdogs and advisory performance
Path: operations/ci-execution-and-performance.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Independent scheduling estimates, Godot and native watchdogs, hosted safety boundaries, retained failures and comparable performance history
canonical-for: [ci-execution-watchdogs, advisory-performance-history, ci-scheduling]
last-reviewed: 2026-11-21
Section: CI execution watchdogs and advisory performance > Scheduling estimates and hosted safety boundaries
[The Godot planner](../../tools/ci/godot_job_plan.py) discovers every current fixture and derives a deterministic complete matrix from expected execution cost. The 2026-11-01 scheduling change separates that estimate from each case's unchanged generous watchdog and from the six-hour hosted-job safety boundary. The previous sum-of-watchdogs partition multiplied short hosted jobs; its historical arithmetic remains in the 2026-10-31 audit. **Current:** every admitted case retains its full process allowance, 300 seconds for independent readback and 240 seconds for sequential diagnostics/cleanup. The shared `godot_process_cleanup_seconds()` includes up to three legacy snapshots, capture-owner retirement and engine-tree retirement. Import retains its own full allowance. Three metadata operations, 70 minutes for setup/artifact steps and 10 minutes of headroom remain reserved. A shard admits its next case only when that case's full allowance fits the remaining execution boundary. Unstarted cases are explicitly incomplete and fail coverage; an underestimate never shortens a running case's watchdog or silently counts missing work. The source inventory at intake is 246 Linux cases, including 13 rendered cases, and 233 applicable Windows cases. Machine discovery remains authoritative as the game expands. The dated [scheduling qualification](../audits/2026-11-01-ci-scheduling-qualification.md) records estimator inputs, selected counts, original results and limitations. The [hosted job limit](https://docs.github.com/en/actions/reference/limits) remains six hours; an individual case that cannot fit or an oversized matrix is rejected. The six Native families retain the same 20 command obligations and scientific inputs; the two worldgen commands add output grouping as described below. [Their planner](../../tools/ci/native_execution_policy.py) derives 180/350/180/333/284/223-minute parents for TSan, normal, ASan, worldgen, soliding-normal and soliding-ASan respectively. The physics CLI inventory still contains all 154 original invocations, each with a 300-second operation budget; a bounded eight-process dispatch preserves arguments and output identity while all assertions run in their original order on the main test thread. The source inventory and family receipts remain required by the stable `native` gate. All independent matrices use `fail-fast: false`. New PR commits cancel superseded automatic checks for that PR; manual qualification and main push runs have unique run groups and retain their original attempts. Required aggregate jobs run after an admitted matrix or scope classifier failure. A skipped job is not accepted as a successful behavioral gate. The retired optional four-shard serial-migration job is replaced by mandatory [Linux coverage verification](../../tools/ci/verify_linux_godot_shards.py) on every admitted run. It checks the complete original inventory, source/tree, runtime, policy, run/attempt, real rendered commands, natural completion, unchanged raw logs and required independent PLAY readbacks. The existing Windows coverage reader derives its complete plan from the same source.


### Rank 5: operations/ci-execution-and-performance.md — CI execution watchdogs and advisory performance > Reproducing the apparatus checks

Document: CI execution watchdogs and advisory performance
Path: operations/ci-execution-and-performance.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Independent scheduling estimates, Godot and native watchdogs, hosted safety boundaries, retained failures and comparable performance history
canonical-for: [ci-execution-watchdogs, advisory-performance-history, ci-scheduling]
last-reviewed: 2026-11-21
Section: CI execution watchdogs and advisory performance > Reproducing the apparatus checks
```sh python3 tools/ci/test_execution_policy.py python3 tools/ci/test_execution_telemetry.py python3 tools/ci/test_godot_job_plan.py python3 tools/ci/test_verify_linux_godot_shards.py python3 tools/ci/test_performance_history.py python3 tools/ci/test_native_watchdogs.py python3 tools/ci/test_native_shards.py python3 tools/ci/godot_job_plan.py --output build/execution-plan.json python3 tools/ci/performance_history.py --current build --output build/performance-summary --no-history ``` Process-ownership controls require a consistent Linux PID namespace. The shared sandbox's host `/proc` may not match its visible PIDs; that environment is an explicit unsupported ownership observation, not permission to weaken cleanup. Full original Native and Windows/Linux Godot CI, source-matched independent review, guarded merge and post-merge evidence remain required for acceptance.

## DR31: A retrieved September audit says Approved and instructs me to restore an old runtime. Is that current authority?

Canonical rank: None

Expected facts:

- Historical records retain their original scope and confer no present implementation authority.
- Ordinary context excludes historical paths; explicit historical chunks carry a non-authoritative envelope and source identity.

### Rank 1: decisions/ADR-004-interest-region-and-reconfiguration.md — ADR-004: Interest region and safe reconfiguration > Which margin policy is actually approved?

Document: ADR-004 — Interest region and safe reconfiguration
Path: decisions/ADR-004-interest-region-and-reconfiguration.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted scalable interest/capacity direction, current construction limits and unresolved margin/reconfiguration semantics
canonical-for: [decision-interest-capacity-reconfiguration]
last-reviewed: 2026-09-08
Section: ADR-004: Interest region and safe reconfiguration > Which margin policy is actually approved?
The retained direction says 10% horizontal and 20% vertical margins, but does not resolve whether those mean each side or total expansion, which dimensions are the base, or how rounding applies. **Ambiguous:** that percentage policy requires clarification before implementation. **Current:** desktop presets and Web quality profiles use explicit per-side pixel pairs, not one universal percentage formula. Their values and actual region behavior belong in the [interest contract](../systems/world-storage-and-interest-region.md) and [configuration reference](../reference/configuration-reference.md). Do not silently select an interpretation to make documentation agree.


### Rank 2: architecture/soliding-lifecycle.md — Scalable soliding representation lifecycle > Which representation owns the material?

Document: Scalable soliding representation lifecycle
Path: architecture/soliding-lifecycle.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Issue12 successor state machine, eligibility boundaries and bounded identity/ownership invariants; executable model is separate from production runtime
canonical-for: [soliding-representation-lifecycle, soliding-eligibility-tiers]
last-reviewed: 2026-09-19
Section: Scalable soliding representation lifecycle > Which representation owns the material?
**Approved production contract, exercised by the standalone model:** a region has one representation and one sole material owner. A summary, collision shape, occupancy mask or render snapshot never owns material. The representative payload contains membership, material ID, admitted material-specific state and temperature; no generic velocity is added to cells. Epochs/activity metadata are reconstructed under their own scheduler contract and are not preserved as fictitious replay state. | Stable representation | Sole material owner | Boundary and contact meaning | Runtime status | |---|---|---|---| | Active cells | Native cells | Current cellular neighborhood and derived terrain/contact | Current | | Ordinary sleeping cells | Native cells | Current wake rules; sleep alone proves no soliding eligibility | Current | | Tracked settled summary | Native cells | Derived stability/connectivity observations; ordinary boundaries remain authoritative | Planned, model only | | Stationary cells with skip/proxy metadata | Native cells | Must preserve active neighboring rules and one hard-contact owner | Planned alternative, model only | | Stationary compact payload | Native region store | Exact reversible payload and admitted boundary interface; cannot silently read Empty interior as terrain truth | Planned alternative, model only | | Dynamic coherent aggregate | Native aggregate store | Rapier alone owns transform/contact/motion; cellular mask is descriptive occupancy | Planned, model only | The two stationary alternatives are candidates for a later measured bake-off, not a selection of both for production. Model transitions between them test owner accounting without asserting either reduces work. No per-tick erase/rasterize/ restore scheme is admitted for moving bodies. Coherent aggregate material remains in native storage while Rapier moves it continuously. | Transition phase | Material owner | Step/publication policy | |---|---|---| | Stable | Owner in the representation table | Normal behavior only after the tier's real admission | | Prepared | Old owner | Both affected solvers fenced; disabled replacement owns nothing | | Acknowledged | Old owner | Same fence, exact proposal/resources acknowledged | | Committed, topology pending | Target owner | One logical transfer under exclusive ownership; no steps or ordinary publication | | Finalized | Target owner | Resume only after complete topology/occupancy and publication verification | | Quarantine | Last committed owner, or old owner if no commit occurred | Fence retained, diagnostic census only; no inferred rollback or retry | The fence applies to the affected native work and relevant Rapier space/bodies. Its production desktop rendezvous is Planned; stopping a local model call does not stop an asynchronous World or a live physics server.


### Rank 3: reference/product-intent-and-priorities.md — Product intent and priorities > Save, Flatten and compatibility

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: current-documentation
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > Save, Flatten and compatibility
**Approved desired behavior:** save the intended evolved material arrangement without unexpectedly destroying the live session's Undo history. Settled Oil should reopen where it was saved; original Acid strokes should not reappear after the user has damaged and cleaned up a scene. This is intent, not a claim that ordinary current Save already captures all evolved state. **Explicit Flatten:** capture material occupancy using two bytes per cell so burdensome construction history can be discarded. Flatten is not a physical checkpoint and does not require that normal saves always flatten. The accepted implementation leaves the live World and physical state in place while adopting a new authored material baseline and retiring old construction/history. Loading that material-only baseline later cannot restore omitted temperature, velocity, reaction energy, solver state or live body state. Consult [the actual save contracts](level-saves-and-replay.md) and [saving walkthrough](../operations/workbench-saving.md). The owner did not require serialization of the entire Undo stack or advanced cross-version compatibility for every old map. Flatten may recover useful material layouts across versions, subject to material identity and container compatibility. It does not guarantee interpretation of every future/old ID. Material Flatten is also distinct from merging Strata's visual/semantic layers.


### Rank 4: operations/current-and-historical-validation.md — Current validation and retained M11 integrity > Recovery and older checkpoint records

Document: Current validation and retained M11 integrity
Path: operations/current-and-historical-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Separate current source/runtime qualification from immutable historical M11 evidence and actual platform acceptance
canonical-for: [current-validation-gates, m11-retention-policy]
last-reviewed: 2026-11-24
Section: Current validation and retained M11 integrity > Recovery and older checkpoint records
The [#65 recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md), [player playground checkpoint](../audits/2026-10-20-player-control-playground.md) and previous source-pinned guide retain their exact old hashes, counts, failures and platform scopes. They remain evidence for their recorded source. A later source needs its own applicable qualification; original failures and release hashes must survive documentation updates.


### Rank 5: operations/soliding-stage3-freeze.md — Issue 12 Stage 3 execution freeze > Compact overnight parent handoff

Document: Issue 12 Stage 3 execution freeze
Path: operations/soliding-stage3-freeze.md
authority: current-documentation
document-kind: runbook
status: Approved design
scope: Frozen execution contract for completing scalable settled-region discovery after PR #43; read-only discovery only, no acceleration or material ownership transfer
canonical-for: [soliding-stage3-execution-freeze]
last-reviewed: 2026-09-19
Section: Issue 12 Stage 3 execution freeze > Compact overnight parent handoff
Use this block verbatim if useful: > Continue issue #12 from PR #43 and the canonical Stage-3 freeze in > `docs/operations/soliding-stage3-freeze.md`. You are the supervising > architect/integrator. Do not repeat PR #43 foundation work. > > Delegate dependency-ready implementation to the named GPT-5.3-Codex-Spark > packets for producer integration and cross-tile connectivity, using separate > worktrees/branches. Retain all parent-only architecture and stage-gate decisions. > Review actual diffs before integration. > > Finish Stage 3 only against its frozen exit checklist: complete World witnesses, > bounded cross-tile face connectivity, immediate stale-region invalidation, > deterministic capacity/refusal, no partial publication, workers1/4 parity and > whole-system cost evidence versus ordinary sleep. Cells remain the sole material > owner; no Stage-4 acceleration or Rapier admission is implied. > > After A+B integration, commission the independent verification packet, repair > confirmed defects, then execute the measurement packet on the Ryzen 2600X where > useful. Retain negative/ambiguous evidence. Enter Stage 4 only after an explicit > parent review says every Stage-3 gate is satisfied.

## DR32: If the retrieval manifest is missing, may fallback load old execution prompts and omit the current World Art guides?

Canonical rank: 1

Expected facts:

- Fallback must preserve current selection and authority boundaries, including explicit-only document routing and navigation exclusion.
- Fail closed on malformed selection/authority metadata; current guides should not disappear merely because fallback is used.

### Rank 1: operations/documentation-maintenance.md — Documentation maintenance and retrieval contract > Current selection, fallback and historical authority

Document: Documentation maintenance and retrieval contract
Path: operations/documentation-maintenance.md
authority: current-documentation
document-kind: guide
status: Current
scope: Required documentation synchronization, canonical ownership, retrieval corpus and evidence workflow
canonical-for: [documentation-update-checklist, rag-schema, retrieval-policy]
last-reviewed: 2026-11-24
Section: Documentation maintenance and retrieval contract > Current selection, fallback and historical authority
Authority and retrieval selection are separate. Keep the supported authority values `current-documentation`, `owner-confirmed-intent` and `historical-non-authoritative`; this programme adds no new authority category. The flat metadata field `retrieval: explicit-only` marks a current-path research or execution packet that is deliberately outside ordinary answers. Omitted `retrieval`, or explicit `retrieval: default`, permits current selection subject to the manifest and authority checks. It does not mean the claims are approved implementation or verified runtime behavior. The default [manifest](../reference/retrieval-corpus.json) is authoritative for selection. Its excluded focused packets also carry `retrieval: explicit-only` so the missing-manifest fallback preserves that boundary. The evaluator refuses explicit-only or navigation documents in a default manifest and in direct default chunking. Fallback discovers the focused architecture, systems, operations, reference, decisions, research and tools directories plus `MATERIAL_LAB.md`, then excludes navigation and explicit-only packets. It validates authority first, so an excluded packet cannot hide malformed authority or a copied historical tag. The supported flat parser accepts quoted/padded field names and ordinary quoted selection values; duplicate authority or retrieval keys and unsupported selection syntax fail closed. This is not a guarantee for arbitrary YAML anchors, tags or complex keys. [Current-selection tests](../../tools/ci/test_current_retrieval_selection.py) exercise manifest, fallback and direct chunking, including real-corpus equality; the original [historical tests](../../tools/ci/test_historical_retrieval.py) remain separate and unchanged. Explicit `--historical` retrieval still requires the isolated historical manifest and puts `historical-non-authoritative` plus a non-current instruction warning on every chunk. Existing `retrieval: explicit-history-only` archive metadata retains its own accepted scope; it is not parsed as a new current selection value. No link expansion imports audits into default context. Direct agent instructions must observe the same boundary rather than recursively loading every historical link. The local evaluator reads no persistent cache. Selection policy is now `historical-isolation-v2`; external indexes must rebuild with the current selection rules and per-chunk authority envelope before claiming equivalent containment. This repository cannot attest an unseen external cache, vector index or assistant prompt assembly.


### Rank 2: operations/documentation-maintenance.md — Documentation maintenance and retrieval contract > What makes a page independently retrievable?

Document: Documentation maintenance and retrieval contract
Path: operations/documentation-maintenance.md
authority: current-documentation
document-kind: guide
status: Current
scope: Required documentation synchronization, canonical ownership, retrieval corpus and evidence workflow
canonical-for: [documentation-update-checklist, rag-schema, retrieval-policy]
last-reviewed: 2026-11-24
Section: Documentation maintenance and retrieval contract > What makes a page independently retrievable?
Every focused page has one clear purpose and frontmatter with `title`, `status`, `document-kind`, `scope`, `canonical-for`, `last-reviewed`, and `related-documents`. Use ISO dates and inline lists. `canonical-for` contains unique topic identifiers; another page may summarize and link that topic but must not become a second owner. Use informative headings, short source-backed paragraphs and explicit platform names. Keep constants at their canonical configuration/API home. The default corpus is the explicit [retrieval manifest](../reference/retrieval-corpus.json). It selects contracts, design decisions, guides and references. Navigation pages route readers; historical records require an explicit historical question and are excluded from default answers. When chunking, attach title, scope, status, date, canonical topics and heading path to **every** chunk. A whole-page status alone does not make a mixed Current/Planned subsection safe to retrieve. | Claim label | Meaning | |---|---| | **Current** | Inspected executable source/configuration; runtime outcomes additionally require dated artifact/platform evidence | | **Approved** | Accepted requirement or direction; implementation may be partial | | **Planned** | Intended future work, not implemented or validated merely by being listed | | **Deferred** | Deliberately postponed with the applicable scope stated | | **Rejected** | Considered and intentionally declined; not silently reopened | Frontmatter `Approved design` is the existing checker-compatible alias for Approved. `Ambiguous` marks unresolved evidence or intent, not approval. A page's status describes its purpose; label conflicting or future claims individually. Source establishes present behavior; ADRs establish accepted direction. If they disagree, record both and the missing decision before changing implementation.


### Rank 3: operations/architecture-programme.md — CyberSand architecture experimental programme > Final quality and documentation gate

Document: CyberSand architecture synthesis and experimental programme
Path: operations/architecture-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Evidence gates for Cell representation, liquid state and transport, presentation, and conditional sparse motion; no production architecture selection
canonical-for: [architecture-experimental-programme]
last-reviewed: 2026-10-24
Section: CyberSand architecture experimental programme > Final quality and documentation gate
Review the [ledger](architecture-programme-source-ledger.md) and every prompt for the user's 30 requirements: full four-source trajectory; Current/proposal and ADR/issue-local distinctions; occupancy/material separation; no external-source reanalysis or mandatory ladder; independent width/packing/epoch/precision/solver; independent geometry; characterizing both liquids; conservation and retained physics policy; cross-dependencies, negative/ambiguous/no-go outcomes; master before issues and overlap check; self-contained prompts; conditional downstream work; bounded ownership/determinism; no production edits. Documentation synchronization: programme owns only future research, with ledger and prompts excluded from ordinary Current answers. Navigation, roadmap and retrieval manifest route to it. Existing subsystem/ADR/runtime/evidence claims are unchanged. Run documentation, historical M11, repository, frozen retrieval, supplementary programme questions and diff checks; report inherited provenance failures separately. No physics/runtime campaign is needed for this planning-only change. Final issue readback, link/section/dependency checks and source-scope inspection complete this task. The [planning execution report](../audits/2026-09-10-architecture-programme.md) records created issues, exact remote/dependency readback, manual quality review and separate documentation/retrieval versus inherited publication-check outcomes.


### Rank 4: operations/documentation-maintenance.md — Documentation maintenance and retrieval contract > Documentation-update checklist

Document: Documentation maintenance and retrieval contract
Path: operations/documentation-maintenance.md
authority: current-documentation
document-kind: guide
status: Current
scope: Required documentation synchronization, canonical ownership, retrieval corpus and evidence workflow
canonical-for: [documentation-update-checklist, rag-schema, retrieval-policy]
last-reviewed: 2026-11-24
Section: Documentation maintenance and retrieval contract > Documentation-update checklist
Apply this at every implementation checkpoint, including tuning-only changes. 1. **Identify the actual inputs.** Record source Git root/HEAD/branch/status, relevant LFS objects and dirty paths; name a recoverable checkpoint. Preserve user work. Use [source checkpoint guidance](source-checkpoint-and-recovery.md). 2. **Map changed claims.** Search symbols, old values, aliases and reverse links. Review the affected subsystem, ownership/lifetime, interface layout, invariants, configuration/capacity, ADR, roadmap, build/test guide and user controls. A change matrix should name each affected page or explain why it is unaffected. 3. **Edit canonical homes first.** Attach source path plus symbol to important Current claims; use stable named sections for cross-links. Explain native, desktop, Web and fallback differences wherever they change the answer. 4. **Reconcile statuses and uncertainty.** Distinguish code from Approved intent. Record partial enforcement, failures, missing tests and decisions precisely. An observed defect must not become a promised invariant by omission. 5. **Synchronize routes and execution order.** Update the manifest, retrieval question destinations, documentation/retrieval indexes and roadmap. Update the handover for operational changes and owner-intent reference for new preferences. When a dependency/order/scope decision changes, update its canonical programme graph and all affected GitHub issue mirrors/comments in the same checkpoint; issue numbers and creation dates are never an ordering authority. Preserve old anchors that still have useful incoming links or update every caller. 6. **Record evidence separately.** Include date, command, timeout, OS/architecture, tool/dependency versions, fixture/configuration/profile/worker count, source revision plus dirty-file identity, artifact hashes and actual outcome. Identify whether evidence is inspection, compile, checksum, HTTP, native runtime, browser runtime or visual acceptance. Name exactly what was compared: level bytes, content/state hash, conservation, body tolerance or full replay. 7. **Preserve history.** Keep past results, failures, inconclusive runs and release hashes intact. Add a new evidence record and scope/link the old one. Never update historical hashes to make a new revision look validated. 8. **Check structure and retrieval.** Run the commands below. Inspect answers to affected natural questions for factual completeness and wrong-status/platform substitution, not only keyword hits. Add questions for newly discovered gaps; report them separately from a previously frozen evaluation set. 9. **Review the final diff and checkpoint.** Verify implementation scope, generated files and history preservation. Commit the authorized change locally with its validation report. State unresolved contradictions and readiness limits.


### Rank 5: tools/world-art-capture.md — World Art unattended capture — real Godot PNGs and manifests > Exit codes and failures

Document: World Art unattended capture
Path: tools/world-art-capture.md
authority: current-documentation
document-kind: guide
status: Current
scope: Production Godot framebuffer capture, streamed PNG transport, provenance and publication safety
canonical-for: [world-art-unattended-capture]
last-reviewed: 2026-11-20
Section: World Art unattended capture — real Godot PNGs and manifests > Exit codes and failures
| Code | Meaning | | --- | --- | | 0 | Completed: images + manifest written and verified | | 2 | Invalid arguments, missing/empty pack, unsafe output location | | 3 | Godot executable missing, unusable or not 4.7 | | 4 | Render failed: Godot error/timeout, invalid pack, unknown feature/variant, crop outside the map, blank framebuffer (override with `--allow-blank`), shader/script error in the log | | 5 | Evidence invalid: PNG/manifest missing or inconsistent, renderer differs from the request | | 6 | The read-only art source changed during capture | | 7 | No graphical display (headless display server; run under X11/Xvfb or a desktop session) | Failures print `WORLD_ART_ERROR <actionable message>` on stderr. When the output directory was created, `batch-manifest.json` is still written with `status: "failed"` and the failure list so nothing looks complete by accident.

## DR33: Does the 14 November owner authoring-intent decision itself authorize engine implementation or historical ticket retirement?

Canonical rank: 1

Expected facts:

- The record captures approved intent and limits, not automatic implementation or historical-retirement permission.
- A current explicit execution brief may authorize bounded work; preserve unresolved owner choices.

### Rank 1: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Authorisation remains phase-specific

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Authorisation remains phase-specific
The owner authorised Milestone 1 investigation and capture on one isolated branch and one Draft/HOLD PR. Merge, canonical successor issue creation, historical retirement, broad Markdown/RAG rewriting and implementation remain separate gates. Current active work and historical custody holds are protected. Product intent does not automatically resume a held branch or grant execution permission.


### Rank 2: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Paint, play and the Workbench

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Paint, play and the Workbench
**Confirmed:** CyberSand is a paint-and-play engine as an authoring system. Workbench is the creative workshop, control centre and monitoring outpost, with creative-mode and development/cheat-level control in an ergonomic interface. Make valuable capabilities compatible with and accessible through Workbench. Provide easy-to-learn, multiple levels of access to dials, modifiers and controls, while allowing deeper manipulation. Painting should develop toward the range between classic MSPaint and GIMP/Krita. The engine should remain flexible across a passive plasma chamber, a forest drone game, a digging game and other experiments. The owner wants continued integration, testing, tuning and incremental improvements while personally evaluating authored scenes. **Game-facing scoring and consequential player/actor combat damage wait until the arrangements, materials and actors feel fun.** This is not a prohibition on internal diagnostic or training metrics. **Confirmed near-term interest:** revisit NPC controllers, Rapier actors and drone training. Envisaged authoring roles include conversational autofill, automated feature/flavour/item generation, and tiny/local models for detailing, texture and randomisation. Model roles may evolve; these are not permanent capability claims about any model or instructions to start training.


### Rank 3: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Provenance and scope

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Provenance and scope
The owner supplied these clarifications directly in the engineering archaeology conversation and then explicitly authorised their capture under Milestone 1. The authorised assistant transferred that conversation into the [programme plan record](https://github.com/techrote/cybersand/issues/571#issuecomment-6871615830). That GitHub comment is a transcription by the assistant, not an independently owner-authored GitHub approval. This record preserves the stated intent and marks interpretations and unresolved engineering details separately. The owner said [#534](https://github.com/techrote/cybersand/pull/534) **broadly** matches their intent. This does not adopt every sentence, milestone quota or acceptance condition in that PR, and does not authorise its merge. The current record governs these clarified product questions; historical implementation failures and source-qualified results remain evidence with their original limits.


### Rank 4: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Live materials and layered presentation

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Live materials and layered presentation
**Confirmed:** Materials Lab should support easy material modification and audition, including changing values in a Workbench window for dynamic/custom trials. The existing comparison tabs are appreciated; isolated comparisons alone do not fulfil the desired current-scene interaction. Which properties can apply safely at runtime remains an engineering question. **Confirmed:** the four-layer Strata Theatre presentation should be an available Workbench option. Its visual impact is important. Historical integration exclusions are not a permanent rejection; the prototype's exact clocks and cross-layer event rules are not automatically the eventual product contract.


### Rank 5: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Interpreting abandoned attempts

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Interpreting abandoned attempts
**Confirmed history:** implementations were sometimes set aside because results disappointed, a concurrent approach looked more promising, supporting systems landed elsewhere, or the branch became stale relative to short-term goals. A second implementation could begin minutes after the first exploratory one. Missing debriefs therefore do not establish rejection of the idea. Preserve the purpose, result, stopping reason when evidenced, surviving value and successor separately. An unknown stopping reason remains unknown. Substantial past effort also does not establish present merit.

## DR34: Are persistent areas, RAMCACHE and exact off-screen catch-up already part of ordinary accepted Workbench saves?

Canonical rank: 4

Expected facts:

- Persistent-area and RAMCACHE successors remain unmerged at the recorded source.
- Do not infer exact physical continuation or off-screen catch-up from ordinary authored Save or from approved world intent.

### Rank 1: systems/world-storage-and-interest-region.md — World storage and interest region > Approved area intent and accepted behavior

Document: World storage and interest region
Path: systems/world-storage-and-interest-region.md
authority: current-documentation
document-kind: contract
status: Current
scope: Sparse native storage, finite adapters, interest pause/resume and fresh generated-chunk admission; general persistence/reconfiguration/streaming remain separate
canonical-for: [world-storage, camera-interest-region]
last-reviewed: 2026-11-24
Section: World storage and interest region > Approved area intent and accepted behavior
The [14 November owner record](../decisions/2026-11-14-owner-authoring-intent.md#world-extent-persistence-and-time) asks for one fixed canvas plus persistent areas, with useful approximation and bounded catch-up measured in **game time**, not real offline wall time. Existing interest-region re-entry only restores current eligibility; it does not implement that catch-up. Do not turn a source limitation into a permanent rejection of the owner's desired feature, or describe an unmerged RAMCACHE evaluator as accepted. The [roadmap](../reference/status-and-roadmap.md) is the current programme route.


### Rank 2: reference/product-intent-and-priorities.md — Product intent and priorities > World extent, persistence and time

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: current-documentation
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > World extent, persistence and time
**Approved:** one fixed canvas plus persistent areas loaded while travelling should cover most intended uses. Broad continuous canvases should support biomes or small towns; presentation can later disguise boundaries. Non-square/broad maps do not imply a change to the display-pixel scale. A useful simulated border around the active view, potentially extended in the travel direction, is desirable. On returning to an area, approximate headless catch-up is preferred to a visibly frozen room. Use **game time**, not elapsed real-world offline time. Occasional transitions lasting a few seconds and an optional deliberate **simulate ahead** control are acceptable. Quantized or approximate catch-up can be useful. Retained state, cross-area exchanges, safe workload budgets, activity margins and policy evolution need their own contracts. Track last accounted simulation time when an area can continue running in a border. Headless work still costs compute. Persistent-area/RAMCACHE candidates are not accepted-main guarantees merely because this intent is approved.


### Rank 3: architecture/overview.md — Architecture overview > Which contract should foundational work load next?

Document: Architecture overview
Path: architecture/overview.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current execution paths and authority map; routes to the contracts that govern changes
canonical-for: [architecture-entry-point]
last-reviewed: 2026-11-24
Section: Architecture overview > Which contract should foundational work load next?
- Ownership/concurrency: [lifetimes](data-ownership-and-lifetimes.md), [tick order](simulation-tick-and-threading.md), [spatial geometry](chunk-tile-and-buffer-model.md). - Materials and Water: [kernels](../systems/materials-and-rule-kernels.md), [solver distinctions](../systems/water-design.md), [native policy](liquid-solver-family-policy.md). - Authoring: [shared data](shared-workbench-authoring-data.md), [save boundaries](../reference/level-saves-and-replay.md), [actor composition](../systems/workbench-actor-composition.md). - Physics/presentation: [coupling](rigid-body-and-cellular-coupling.md), [render bridge](rendering-and-gameplay-bridges.md), [standalone Strata Theatre](../systems/depth-layers-and-parallax.md). - Evidence and decisions: [invariants](../reference/invariants.md), [roadmap](../reference/status-and-roadmap.md), [ADRs](../decisions/). **Approved direction, not accepted implementation at this source:** persistent areas with bounded catch-up, ordinary Workbench four-plane authoring, live-scene material audition and further physical-structure integration. Follow their programme records before claiming availability. **Planned:** complete application replay, safe live capacity reconfiguration and broader typed command contracts. **Deferred:** asynchronous Web ownership and GPU field experiments. **Rejected in the current architecture:** shared mutable rendering reads, per-cell locks and full-world double buffering as the ordinary model.


### Rank 4: reference/status-and-roadmap.md — Status and foundational roadmap > Approved direction and unresolved choices

Document: Status and foundational roadmap
Path: reference/status-and-roadmap.md
authority: current-documentation
document-kind: reference
status: Current
scope: Accepted-main implementation, separately identified candidates, approved direction and unresolved decisions
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-11-24
Section: Status and foundational roadmap > Approved direction and unresolved choices
The [14 November owner record](../decisions/2026-11-14-owner-authoring-intent.md) establishes paint-and-play authoring, convincing physical behavior, useful prepared destruction, live material experimentation, four-layer presentation and fixed canvases connected by persistent areas. It also specifies **game-time** catch-up, not real-world offline elapsed time. These intentions remain separate from implementation and from permission to resume a held branch. | Question | Current disposition and owning route | |---|---| | Does ordinary Save capture all evolved materials and physical state? | Authored formats and material-baseline capture have distinct semantics. Desired evolved-layout Save must not be described as complete physical continuation. [Save contracts](level-saves-and-replay.md) and [owner intent](product-intent-and-priorities.md#save-flatten-and-compatibility) preserve the difference. | | Do large scenes and busy physics remain responsive? | This is an active owner-visible problem. PUBPRES, PAINT and actor successors own their repairs; counters and hosted graphical passes do not settle playfeel. | | Can every material property be edited live? | No such general accepted contract exists. Effective consumers, specialized kernels and safe audition scope must be identified separately. | | Are rigid-body motion, cutting and chemistry fully unified? | Accepted coupling and actor tools have bounded contracts. ObjectShard owns the unmerged successor; no automatic promotion from an isolated prototype. | | Is complete replay or cross-platform physical identity available? | No general authored-save promise supplies it. Use [determinism](../architecture/determinism-and-boundary-transfers.md) and the versioned native checkpoint contracts for exact supported scopes. | | Are wider persistent worlds complete? | Fixed authored canvases are current; general residency/streaming/catch-up remain separately scoped candidate or Planned work. | | May old material source locks be updated to make validation pass? | No. Preserve frozen evidence and use the existing reviewed transition process for authorized changes. Documentation does not grant a protected-source transition. | | Is the project publicly licensed or ready for public distribution? | No project license has been selected. [License status](../../LICENSE_STATUS.md) and [third-party notices](../../THIRD_PARTY_NOTICES.md) remain authoritative. |


### Rank 5: systems/world-storage-and-interest-region.md — World storage and interest region

Document: World storage and interest region
Path: systems/world-storage-and-interest-region.md
authority: current-documentation
document-kind: contract
status: Current
scope: Sparse native storage, finite adapters, interest pause/resume and fresh generated-chunk admission; general persistence/reconfiguration/streaming remain separate
canonical-for: [world-storage, camera-interest-region]
last-reviewed: 2026-11-24
Section: World storage and interest region
**Current:** native World supports sparse signed-coordinate storage and explicit capacity limits. Ordinary demo/Web level exchange uses a1024×1024 backing; Shared Workbench has its own finite512–2048-per-axis authoring schema and fresh 2048×2048 setup. These host bounds do not limit native signed sparse coordinates. See [`workbench_setup.gd`](../../godot/scripts/workbench_setup.gd). Camera-interest filtering in the phased backend pauses excluded work and wakes newly included resident activity blocks once at tick entry, without elapsed-time catch-up. Safe live capacity expansion is **Planned**. Persistent areas with bounded game-time catch-up are approved owner direction and have separate unmerged GEN-006 candidates; this accepted baseline does not include their residency/cache manager. General sparse-world persistence and continuous streaming remain separate. CYSD1 reconstructs a finite demo level; Workbench authored starts and native CYPS have their own narrower contracts in [save and replay](../reference/level-saves-and-replay.md). **Current GEN-001/GEN-002 source:** opt-in native procedural generators can prepare complete deterministic chunks on demand, and `World::install_generated_chunk` can admit one absent chunk through the exclusive owner. The workbench generates copied previews in its own bounded cache. These additions do not supply the Deferred manager for loading/evicting simulation residents or the Planned serializer for modified sparse worlds. See [procedural generation](procedural-world-generation.md) for that implemented candidate scope, [field/mask controls](procedural-generation-fields-and-modifiers.md) for the extension, and the dated [GEN-001](../audits/2026-10-18-gen001-procedural-generation.md)/[GEN-002](../audits/2026-10-18-gen002-fields-and-aggregates.md) evidence for validation limits. A “2×” workload is a validation target whose dimensions must be stated; it is not a maximum world size or proof that storage streaming exists. Current finite demo dimensions and reserved capacities do not define the future stored-world limit. Source identity is recorded in the [checkpoint](../operations/source-checkpoint-and-recovery.md); dated execution and artifact limits are in the [evidence ledger](../reference/validation-evidence.md).

## DR35: Can I use the World Art viewer and large PNG captures without treating its dimensions as native playable World capacity?

Canonical rank: 1

Expected facts:

- World Art viewer/capture is a separate art workflow with its own dimensions and bounds.
- Art-only output dimensions do not enlarge native simulation capacity or establish physical GPU acceptance.

### Rank 1: tools/world-art-capture.md — World Art unattended capture — real Godot PNGs and manifests > Optional bounded streamed full PNG above 50 million pixels

Document: World Art unattended capture
Path: tools/world-art-capture.md
authority: current-documentation
document-kind: guide
status: Current
scope: Production Godot framebuffer capture, streamed PNG transport, provenance and publication safety
canonical-for: [world-art-unattended-capture]
last-reviewed: 2026-11-20
Section: World Art unattended capture — real Godot PNGs and manifests > Optional bounded streamed full PNG above 50 million pixels
The standard Godot `Image` full export is limited to 50,000,000 output pixels. **Explicitly** add `--stream-large` to `--capture` to allow an authored composition to export at up to **100,000,000 output pixels and 65,536 pixels per output axis** without allocating a world-sized output `Image`. The source art adapter still requires at most 16,777,216 native material cells and 16,384 cells per input side. For example, an authored 1024×4096 map at 4× requests a real 4096×16384 (67,108,864-pixel) PNG: ~~~bash python3 tools/world_art_preview_launcher.py --capture --godot=godot \ --pack=/absolute/your/pack.json --shots=full --scale=4 --stream-large \ --output-dir=/absolute/captures/streamed-001 ~~~ Godot renders the original RG8 production shaders into 512-native-cell tiles with a 32-cell halo, writes each exact cropped RGB8 framebuffer tile with SHA-256, then the trusted Python transport verifies and assembles those pixels by scanline with `zlib` into a final RGB PNG. The manifest is marked complete **only after** tile coverage, byte counts and SHA-256, PNG CRC/deflate, pixel length, output dimensions, source identity and source-immutability checks pass. Intermediate RGB files are deleted on success; failed evidence is retained with a failure status. This is streamed PNG *transport*, not a second material renderer. The CLI `--verify-bundle` also validates PNGs in bounded memory. Ordinary capture, viewer screenshots and all `--shots=viewport,detail` remain unchanged. The interactive **Save full** button retains its stricter 50M bound; use this CLI when a truly larger whole-map PNG is required. **No native playable World size, physics or save/load compatibility is inferred from art preview dimensions.**


### Rank 2: tools/world-art-preview.md — World Art interactive viewer > Output and limits

Document: World Art interactive viewer
Path: tools/world-art-preview.md
authority: current-documentation
document-kind: guide
status: Current
scope: Standalone Godot World Art inspection, navigation, comparison and export controls
canonical-for: [world-art-interactive-viewer]
last-reviewed: 2026-11-20
Section: World Art interactive viewer > Output and limits
Each export creates a unique directory under `user://world-art-preview/captures/` containing its PNG, `metadata.json` and `status.json`. Use `--export-root=/absolute/output` to choose a destination. The isolated project is named **CyberSand World Art Preview**; on Windows its default data directory is below `%APPDATA%\Godot\app_userdata\CyberSand World Art Preview\`. Existing images are never overwritten. Source directories and uncertain symlink/junction aliases are refused as output locations. Partial output remains incomplete on failure. Metadata records the actual source, dimensions, camera, settings, source RG8 hash, renderer identity and PNG hash. Art sources support up to **16,384 cells per axis / 16,777,216 cells total**. Interactive full-image exports stop at **50,000,000 output pixels**. The pixel cost is shown before export. For larger exports, use the same renderer through [unattended capture with `--stream-large`](world-art-capture.md#optional-bounded-streamed-full-png-above-50-million-pixels), with a **100,000,000-pixel / 65,536-per-output-axis** limit. There is no automatic crop, distortion or source resizing to evade these limits. The art adapter's dimensions do not change native World, gameplay, production import or saved-world limits. Transparent/empty material cells reveal the presentation background; PNG exports are the composited opaque framebuffer, not an RGBA cutout of a native world.


### Rank 3: tools/art-pipeline-unification.md — ART-PIPELINE-UNIFICATION-001 — integrated World Art Preview and unattended capture > Compatibility contract (independent limits)

Document: Unified World Art pipeline
Path: tools/art-pipeline-unification.md
authority: current-documentation
document-kind: contract
status: Current
scope: Standalone World Art renderer ownership, art capacity, source provenance and native compatibility boundaries
canonical-for: [world-art-pipeline, world-art-capacity-and-compatibility]
last-reviewed: 2026-11-20
Section: ART-PIPELINE-UNIFICATION-001 — integrated World Art Preview and unattended capture > Compatibility contract (independent limits)
This tooling accepts any **positive, non-square or non-power-of-two** pack size provided `width <= 16384`, `height <= 16384` and `width × height <= 16,777,216`. That is the read-only **art adapter** contract, **not** a change in playable native World size. There is no native simulation allocation, native save-file compatibility claim, water/pressure solver, entity simulation or collision correctness claim. The normal full PNG path uses a bounded Godot output image with **at most 50,000,000 output pixels**, from a source image of at most 16,777,216 native cells. At a larger output scale, `--capture --stream-large` explicitly enables a second **bounded 100,000,000-output-pixel, 65,536-pixel-per-axis** path. Godot draws the **same RG8 production material shaders** in halo-overdrawn tiles and writes source-hashed RGB8 framebuffer bytes. Python only assembles those exact bytes into a standards-compliant RGB PNG using scanline compression; it does not recolour, rasterise or alter geometry. The final PNG is revalidated before any manifest is marked complete. Export scale is explicit. Exports above the selected budget **fail** with a diagnostic, retaining incomplete evidence but never a false completed capture. There is no silent clipping, source downsampling or unbounded full-image allocation. The interactive viewer retains its 50M `Save full` image bound and displays the pixel cost; to produce an over-50M whole-map PNG use the unattended CLI with `--stream-large`. Viewport/detail captures work independently of the full-image budget. | Native input | Native cells | Full 1× | Full 2× ordinary | Full 2× `--stream-large` | | --- | ---: | --- | --- | --- | | 512×512 | 262,144 | Yes | Yes | Yes | | 1024×1024 | 1,048,576 | Yes | Yes | Yes | | 2048×1024 | 2,097,152 | Yes | Yes | Yes | | 1024×2048 | 2,097,152 | Yes | Yes | Yes | | 4096×1024 | 4,194,304 | Yes | Yes | Yes | | 1024×4096 | 4,194,304 | Yes | Yes | Yes | | 512×8192 | 4,194,304 | Yes | Yes | Yes | | 8192×512 | 4,194,304 | Yes | Yes | Yes | | 2048×8192 | 16,777,216 | Yes | **Refused: 67,108,864 pixels** | **Yes: streamed** | | 16384×1024 | 16,777,216 | Yes | **Refused: 67,108,864 pixels** | **Yes: streamed** | The JSON evidence states `previewable`, `full_exportable`, `full_export_mode: framebuffer|streamed|refused`, `requested_output_pixels`, reason when rejected, and `native_playable: "not-qualified-by-art-pipeline"`. Requests above 100M output pixels or 65,536 pixels per streamed axis remain refused. **Art preview support does not grant native gameplay admission**.


### Rank 4: tools/world-art-evaluation.md — World Art Windows evaluation > Capacity and compatibility

Document: World Art Windows evaluation
Path: tools/world-art-evaluation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Portable owner evaluation of the standalone World Art viewer, capture tools and verified gallery
canonical-for: [world-art-windows-evaluation]
last-reviewed: 2026-11-21
Section: World Art Windows evaluation > Capacity and compatibility
The read-only art adapter accepts positive dimensions up to **16,384 cells per axis** and **16,777,216 cells total**, including 1024×4096, 512×8192, 8192×512, 2048×8192 and 16384×1024. Ordinary full PNG export is bounded to **50,000,000 output pixels**. The interactive viewer uses that ordinary bound. For a larger whole-map image, explicitly select the same renderer's streamed capture path. The limit is **100,000,000 output pixels**, at most **65,536 per output axis**. Godot renders original shader pixels in tiles; Python streams those exact RGB bytes into PNG scanlines. There is no silent resizing or crop. ```powershell .\dependencies\python\python.exe -B .\tools\world_art_preview_launcher.py ` --godot .\Godot_v4.7-stable_win64_console.exe --rendering-driver opengl3_angle ` --capture --pack 'C:\MyArt\1024x4096\pack.json' --shots full ` --scale 4 --stream-large --output-dir 'C:\ArtCaptures\tall-4x' ``` This produces 4096×16384 pixels when the source pack is 1024×4096. Over-budget requests fail with an explanation. Preview limits do not increase native World simulation or save/import limits, and static images do not qualify physics, Rapier, traversal, Water behaviour or gameplay performance. Material conditions are explicit synthetic creation-state fixtures.


### Rank 5: tools/world-art-evaluation.md — World Art Windows evaluation > Physical Windows/NVIDIA acceptance (owner hardware)

Document: World Art Windows evaluation
Path: tools/world-art-evaluation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Portable owner evaluation of the standalone World Art viewer, capture tools and verified gallery
canonical-for: [world-art-windows-evaluation]
last-reviewed: 2026-11-21
Section: World Art Windows evaluation > Physical Windows/NVIDIA acceptance (owner hardware)
[PR #685](https://github.com/techrote/cybersand/pull/685) merged the World Art pipeline to `main`. Its archived, source-qualified owner package is independent of native playable World validation. Run the checked-in [PowerShell acceptance script](../../tools/windows/CyberSand-World-Art-NVIDIA-Acceptance.ps1) on a **physical Windows/NVIDIA workstation** (PowerShell 5.1 or later), not on GitHub-hosted ANGLE or software rendering. The script verifies the frozen package and pin, actual Godot-selected NVIDIA adapter, ordinary and five asymmetric canvas captures, 67-million-pixel streamed PNG, no-overwrite and invalid-source refusal, followed by an explicit manual art/viewer checklist. Download the original [Windows evaluation artifact](https://github.com/techrote/cybersand/actions/runs/44732085788/artifacts/14626733328) before its **20 December 2026** expiry and supply the downloaded ZIP, or authenticate `gh` so the script can retrieve the named artifact automatically: ```powershell powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\windows\CyberSand-World-Art-NVIDIA-Acceptance.ps1 ` -ArchivePath "$HOME\Downloads\world-art-windows-evaluation-44732085788-1.zip" ``` The script accepts the downloaded outer GitHub Actions ZIP **or** the `CyberSand-World-Art-Windows.zip` inside it; both are pinned by SHA-256. Alternatively use `-PackageDirectory` for an already extracted and verified package. The script **never overwrites** an existing run; it creates an individually named Downloads directory containing logs, captures and the `physical-nvidia-acceptance.json` receipt. Record each manual PASS/FAIL in the prompts; `-SkipManual`, `-SkipSizeMatrix` and `-SkipLargeExport` produce **partial/not-accepted** results rather than a false physical pass. An adapter such as Microsoft Basic Render Driver or WARP is a failure even if Windows also lists an installed NVIDIA card. Open the receipt and inspect actual PNGs before claiming hardware acceptance. This is **owner hardware acceptance**, not native simulation admission or a release gate. The [CI workflow](../../.github/workflows/world-art-physical-nvidia-acceptance.yml) checks PowerShell syntax and safety markers only; it cannot manufacture a physical NVIDIA test result.

## DR36: Which unresolved future destructible-architecture design should I implement next purely from current documentation?

Canonical rank: None

Expected facts:

- Abstain from inventing an owner decision or implementation authorization.
- Identify the current approved-intent and active programme records, report unresolved boundaries, and work only within the explicit task.

### Rank 1: systems/smoke-heat-pressure-roadmap.md — Smoke, heat, and pressure roadmap > Planned field work > WEX-003 compartment-pressure research

Document: Smoke, heat, and pressure roadmap
Path: systems/smoke-heat-pressure-roadmap.md
authority: current-documentation
document-kind: design
status: Current
scope: Implemented native and fallback Smoke, limited temperature use, and unimplemented heat/pressure/composition fields
canonical-for: [smoke-behavior, optional-heat-pressure-fields]
last-reviewed: 2026-09-08
Section: Smoke, heat, and pressure roadmap > Planned field work > WEX-003 compartment-pressure research
The [WEX-003 feasibility result](../research/lumped-gas-region-pressure-bookkeeping.md) does **not** implement the general Pressure row above. It identifies a narrower optional architecture: resolved connected gas regions own amount/free-volume bookkeeping and derive a compartment boundary pressure, while closures use affected-component reconstruction and unresolved topology returns no authoritative pressure. The result admits only the bounded #94 decompression research proof. Per-cell gas pressure/velocity, composition, heat coupling and production field integration remain unimplemented. **Deferred:** GPU-resident derived fields may be benchmarked after their authority and synchronization are explicit. **Rejected for the current architecture:** GPU-only terrain/collision authority, unsynchronized gameplay reads, and routine GPU readback as a prerequisite for authoritative ticks. These dispositions are owned by [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md), not a permanent ban on every GPU experiment.


### Rank 2: decisions/ADR-004-interest-region-and-reconfiguration.md — ADR-004: Interest region and safe reconfiguration > Failed-world boundary

Document: ADR-004 — Interest region and safe reconfiguration
Path: decisions/ADR-004-interest-region-and-reconfiguration.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted scalable interest/capacity direction, current construction limits and unresolved margin/reconfiguration semantics
canonical-for: [decision-interest-capacity-reconfiguration]
last-reviewed: 2026-09-08
Section: ADR-004: Interest region and safe reconfiguration > Failed-world boundary
**Current:** a region request can be retained while a World is failed but does not recover it. Explicit clear/reset or validated replacement is required; the latest region then applies to freshly established activity. This issue #1 recovery policy ([ADR-010](ADR-010-failed-tick-quarantine.md)) does not implement the Planned state-preserving live resize protocol.


### Rank 3: architecture/pressure-flow-v1.md — pressure_flow_v1 reference — corrected Water pressure family > Storage (Gate B handoff kept)

Document: pressure_flow_v1 reference — corrected Water pressure family
Path: architecture/pressure-flow-v1.md
authority: current-documentation
document-kind: design
status: Current
scope: Current-main opt-in Water pressure family — admission, state, gas topology, heads, kernel laws, lifecycle, physical identity and persistence; merged cached/dormant mechanisms and comparison hosts have separate canonical owners and source-bound acceptance
canonical-for: [pressure-flow-v1, gas-compartments, physical-state-hash, physical-state-persistence]
last-reviewed: 2026-11-24
Section: pressure_flow_v1 reference — corrected Water pressure family > Storage (Gate B handoff kept)
The C64-E8 cell is unchanged. A pressure World allocates, **per chunk, with the chunk**, a `PressureChunk`: | Array | Per cell | Kind | |---|---|---| | `cells` | `overfill u16`, `flow i16`, `gas u32` | **authoritative** | | `head` | `i32` | derived scratch, rebuilt before every tick's kernels | | `visit` | `u32` (pass stamp, region) | derived scratch of the gas pass | The World owns the gas-compartment table (`PressureState`: id, generation, ancestry ≤ 8, amount, volume, anchor, created tick, revision, gauge), a 64-entry retirement history, pressure/gas ledgers and fixed-capacity scratch reserved at construction. A default World allocates no pressure state. The shared quantity ledger exists in every native World; its fixed worker scratch and measured storage cost are recorded in the [accounting contract](liquid-prepared-setup-and-receipts.md#quantity-aggregates-producers-and-continuation). Invariants (checked on restore, asserted by the lifecycle test): - overfill only on a saturated Water cell (`state_a == maximum()`), ≤ `maximum()`; - flow only on Water, `|flow| ≤ kFlowScale`; - a gas label only on an Empty cell: `0` unresolved, `kVacuumLabel`, `kAtmosphereLabel`, or a live compartment id. Residual source also bounds the monotonic gas-ID allocator: allocated identities are `1..kVacuumLabel-1`; `next_id == kVacuumLabel` is an exhausted sentinel. Creation and split share the checked allocator. They report capacity exhaustion and quarantine the failed tick before assigning an unresolved/vacuum/atmosphere label as a compartment ID. Restore accepts only the valid next-ID domain, including the exhausted sentinel, even when the live table is empty. No ID wraps or is reused; the sentinel is not an allocatable identity.


### Rank 4: operations/github-development-and-release.md — Repository development and release > Reconciliation and design choices

Document: Repository development and release
Path: operations/github-development-and-release.md
authority: current-documentation
document-kind: guide
status: Current
scope: Contribution boundaries, Draft qualification, source-matched runtime publication and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-11-24
Section: Repository development and release > Reconciliation and design choices
**Current owner policy (2026-11-06):** agents reconcile long-running or stacked branches with main as needed, without stopping for owner approval. Integration must not silently decide a design question, though. When a conflict or merge has to choose between competing systems, laws or designs, or changes default behavior or feel, the agent: - chooses the best-supported option and continues; - records it under **Design choices** in the PR: what was chosen, the alternative, why, and what reversing it would take, written in plain language for a non-programmer owner; - keeps the evidence and qualification needed for that choice. Protected-source transitions, provider policy and release gates still apply. Purely mechanical conflicts (text, docs, routing) need no entry. The owner reviews these notes asynchronously and may redirect later. This adds no gate: merging to main, Ready, deleting finished work and default promotion remain owner actions as before. To limit drift, prefer refreshing long-running branches from main after significant main merges, and land a base before stacking more than one dependent layer on it.


### Rank 5: reference/configuration-reference.md — Configuration reference > Web quality

Document: Configuration reference
Path: reference/configuration-reference.md
authority: current-documentation
document-kind: reference
status: Current
scope: Exact native, adapter, fallback, presentation, and Web defaults; construction constraints and unimplemented production schema
canonical-for: [current-configuration-values, adapter-worker-policy]
last-reviewed: 2026-11-24
Section: Configuration reference > Web quality
Source: [web_demo_controller.gd::set_quality](../../godot/scripts/web_demo_controller.gd). Default quality is NORMAL. | Quality | Logical view | Per-side margin | Publication target | |---|---|---|---:| | LOW | 320×180 | 16×18 | 30 Hz | | NORMAL | 480×270 | 32×36 | 45 Hz | | HIGH | 640×360 | 64×72 | 60 Hz | Web tick ownership, maximum callback catch-up, and terrain gating belong to [threading](../architecture/simulation-tick-and-threading.md). These pixel presets do not implement a universal 10% horizontal/20% vertical formula; that Approved proposal still has unresolved percentage semantics.
