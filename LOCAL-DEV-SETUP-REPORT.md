# CyberSand local development setup report

> **Historical setup record: 2026-09-07, pre-threaded-Web and pre-Rapier-Web.**
> The original results and limitations below are preserved. Its no-commit,
> 11-fixture, 16-pointer, single-worker and disabled-Rapier-Web statements
> describe that setup date only. Follow the
> [2026-09-08 documentation audit](source/docs/audits/2026-09-08-documentation-audit.md)
> for current identity, backup coverage, source differences, and later validation.

Date: 2026-09-07. Workspace: `C:\Users\-\Documents\ChatGPT\cybersand\cybersand-m13-dev`.

**Status: Windows native and Web development are operational.** The reconstructed
source builds, native and Godot tests pass, and a fresh export runs in Chromium.
This does **not** certify the unavailable M13 ZIP or its prebuilt export.
The user-reported Godot startup crash was reproduced under restricted directory
access and resolved by running the same binary with normal Windows user-data access.

## Source and integrity

The initial directory contained only `.git`. Shell execution worked, but
`Test-Path -LiteralPath './cybersand-m13.zip'` returned false; searches in Downloads,
Desktop and Documents did not find the archive. The user then designated
`https://github.com/techrote/cybersand` and identified M13 with the Web M11 demo.

The acquired source is branch `web-demo-m11`, commit
`e2892c54d4bd91aac60971e81c748bd49fbe2adb`. The GitHub connector returned 244 file
blobs; their Git SHA-1, byte size and local SHA-256 were verified and recorded in
`SOURCE-PROVENANCE.json`. Original blob responses remain in ignored
`.local/intake-*.json`. Do not rerun `.local/materialize.py` over current edits.
No push, PR, upload, remote mutation or local commit was performed.

This branch did not contain the claimed M13 `VALIDATION.md`, `MANIFEST.sha256`,
`static-web/`, `build-inputs/`, preview launchers, Web export preset, or the
referenced `docs/WEB_DEMO.md` and `test_web_demo.gd`. Existing CI records did not
provide an available validated prebuilt export. Thus original archive integrity
and prebuilt-first browser proof remain **externally blocked by the missing ZIP**.
No archive was modified, and the fresh build is not represented as a prebuilt one.

`tools/audit_workspace.py` compares every acquired file with its original digest.
All **18/18 files under `source/native/` are byte-for-byte unchanged**. Eighteen
runtime files were originally Git LFS pointers: the Windows Rapier DLL was restored
to its exact LFS digest and the Windows CyberSand DLL was built. Sixteen pointers
for other platforms remain; they are listed in `validation/source-audit.json`.

## Observed environment

| Component | Executed/observed version |
| --- | --- |
| Host | Microsoft Windows 10.0.26200, X64; registry ProductName `Windows 10 Pro`, DisplayVersion `25H2`, build `26200.9278` |
| CPU | X64, 12 logical processors; model unavailable from denied CIM query |
| Shell | PowerShell 7.6.5 |
| WSL | Not installed; no distro used |
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Emscripten | Both emcc and em++ **4.0.20**, revision `6913738ec5371a88c4af5a80db0ab42bad3de681` |
| emsdk | Tag 4.0.20, commit `e4fe26ef59168ff44f4c23c466e497bf60b3411e`; SDK release `c387d7a7e9537d0041d2c3ae71b7538cc978104e` |
| Web templates | Official Godot 4.7 dlink/no-thread debug and release ZIPs |
| godot-cpp | `101ae38034304346a46ea9ea84ae156d3e860496`; separate native and Web checkouts |
| Native compiler | LLVM-MinGW 20260826 UCRT, Clang 23.1.0, `x86_64-w64-windows-gnu` |
| Orchestration Python | 3.12.14 in `.local/python` |
| SDK runtime | SDK Python 3.13.3 and Node 22.16.0 |
| SCons | 4.10.1, repository hash-pinned requirement |
| Git Bash | PortableGit 2.55.0.windows.5 |
| Native Rapier | Rapier2D 0.35.2, single precision; exact Windows asset hash |
| Tested browser | Codex's connected in-app Chromium, UA Chrome/152.0.0.0, Windows x64, WebGL 2.0 |

Tools and archives are contained in ignored `.local/`. There is no Docker,
additional JS application stack, system PATH rewrite or required GitHub connection
for ordinary builds from this workspace copy. Offline portability requires copying
`.local/` too, recreating the venv and reactivating emsdk at its new path.

## Setup and primary commands

The initial Python executable was the Codex runtime at
`C:\Users\-\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`.
It was used to create `.local/python`; any installed matching Python can be used
instead. The following commands express the installed configuration, from this
workspace root (tool extraction destinations and online/offline instructions are
in `docs/LOCAL_DEVELOPMENT.md`):

```powershell
python -m venv .local/python
.local/python/Scripts/python.exe -m pip install --no-index --find-links .local/downloads --require-hashes -r source/tools/requirements-build.txt
Copy-Item .local/llvm-mingw-20260826-ucrt-x86_64/bin/llvm-ar.exe .local/llvm-mingw-20260826-ucrt-x86_64/bin/x86_64-w64-mingw32-gcc-ar.exe
Push-Location .local/emsdk
../python/Scripts/python.exe emsdk.py install 4.0.20
../python/Scripts/python.exe emsdk.py activate 4.0.20
Pop-Location
Copy-Item tools/dev-config.example.json .local/dev-config.json
```

Official inputs were downloaded into `.local/downloads` and extracted locally.
Godot and LLVM ZIPs were extracted with Python's `zipfile`; only the two relevant
nested Web templates were extracted from the TPZ. The original downloads are
retained. The pinned bindings use independent checkouts, including
`git clone --no-hardlinks .local/godot-cpp-native .local/godot-cpp-web`.
Their revision and clean-tree checks were executed; godot-cpp was not upgraded.

These are the **executed final workflow commands**, from the workspace root:

```powershell
.\dev.cmd doctor
.\dev.cmd native-bindings
.\dev.cmd native-build
.\dev.cmd native-test
.\dev.cmd godot-test
.\dev.cmd web-build
.\dev.cmd web-export
.\dev.cmd rebuild
.\0Preview.cmd --port 8000
.\dev.cmd http-smoke
.local/python/Scripts/python.exe tools/audit_workspace.py
```

`doctor` actually invokes Godot `--version`, emcc/em++ `--version`, Python,
SCons and clang++ version commands. Each wrapper run records the resolved command,
working directory, exit status, output and elapsed time in `validation/local/`.
The final launcher was run as
`.\0Preview.cmd --port 8000 *> validation/local/preview-final.log`; it invokes
`python preview.py --open` through the configured local interpreter.

Native regression command inside `source/`:

```text
mingw32-make test CXX=clang++ CC=clang
```

Native bindings and extension commands inside `source/`, with the wrapper's local
environment and Git Bash:

```text
bash tools/build_pinned_godot_cpp.sh windows
bash tools/build_native_extension_windows.sh
```

Final clean Web build/export command inside `source/` (the wrapper resolves paths):

```text
python tools/build_web.py --cpp ../.local/godot-cpp-web --godot ../.local/godot-4.7/Godot_v4.7-stable_win64_console.exe --templates ../.local/web-templates --cellular-only --source-commit e2892c54d4bd91aac60971e81c748bd49fbe2adb
```

Godot fixtures use the actual existing SceneTree runners:

```text
Godot --headless --path source/godot --script res://tests/<fixture>.gd
```

## Test/build results executed here

These are local results, not the previous package's 39/14/22 claims.

| Check | Actual result | Elapsed | Evidence under `validation/local/` |
| --- | --- | --- | --- |
| Initial native baseline before build-script changes | 39/39 passed, 0 failed; C11 header check included | 23.615 s including build | `native-test.log`, `native-test.json` |
| Final native Debug build/regressions | **39/39 passed, 0 failed**, Clang 23.1.0, `-O0 -g3`; C11 check passed | 20.164 s including clean test build | `20260907-213621/native-test.*` |
| Final Windows GDExtension | Passed, existing native release build script | 11.666 s | `20260907-213717/native-build.*` |
| Godot fixtures | **11/11 passed, 0 failed**: all 10 existing plus one setup regression | 26.193 s fixtures, plus 4.556 s import | `20260907-213405/godot-fixtures.json` and individual logs |
| Clean Web C++ compile and Godot export | Passed, Emscripten 4.0.20, release compat profile | 38.072 s, retaining bindings/SDK caches | `20260907-213553/rebuild.*` |
| HTTP/export smoke | **6/6 payloads passed**, including WASM magic, MIME and headers | No aggregate timing recorded | `20260907-213949/http-smoke.json` |
| Final integrity/syntax check | **15/15 export checksums and 6/6 retained download hashes passed**; 5 Python files compiled and 5 JSON files parsed | No aggregate timing recorded | `final-integrity.json`, `final_integrity.py` |
| Source audit | 244 original files compared; **18/18 native files unchanged** | No aggregate timing recorded | `../source-audit.json` |
| Historical M11 consistency checker | **Failed: 4 historical hash mismatches remain** | No aggregate timing recorded | `m11-consistency-final.log` |

The eleven fixture filenames are `test_cell_world.gd`,
`test_material_appearance_lut.gd`, `test_native_edge_contact_regression.gd`,
`test_native_fire_presentation_regression.gd`,
`test_native_render_bridge_regression.gd`, `test_presentation_controls.gd`,
`test_rapier_backend_preflight.gd`, `test_rapier_drop_in.gd`,
`test_rapier_manual_step.gd`, `test_render_patch_handoff_regression.gd`, and
the added `test_web_demo_setup.gd`. The added fixture covers four demo constructors,
native stepping, exact snapshot/CYSD1 restoration, checksum corruption, malformed
Base64 and invalid native payload/material rejection without altering the world.
The existing Rapier-native fixtures passed after the capability-reference fix.

The historical consistency failures concern
`godot/native_extension/cyber_native_cell_world.hpp` (already different in the
acquired branch), the Linux CyberSand LFS pointer, the locally built Windows DLL,
and the changed Rapier bridge script. Broken onboarding links/frontmatter were
fixed; historical BUILD_ID hashes were deliberately preserved. This checker is
not reported as passing.

## Fresh export and browser execution

The clean export is `source/build/web/`, served at `http://127.0.0.1:8000/`.
It includes HTML, JS, PCK, loader WASM, Godot side WASM, CyberSand side WASM,
audio helpers, icons, notices, build identity and `SHA256SUMS`.

| Payload | Bytes |
| --- | ---: |
| `index.html` | 5,497 |
| `index.js` | 2,859,484 |
| `index.pck` | 243,872 |
| `index.wasm` | 1,508,095 |
| `index.side.wasm` | 44,072,184 |
| `libcybersand_native.web.nothreads.wasm` | 1,873,535 |

The CyberSand side module SHA-256 is
`46f863d7c5e5ac178d8b44b047812fb8a8d2dc79755796139471585e28d01667`.
It was identical before and after the clean rebuild. The final Windows CyberSand
DLL SHA-256 is `635dd1d908d7c5ab4fa5766a1b7ececa0a7c6df4e76162c64d2950245f76b6ab`.
Browser HTTP logs record the actual CyberSand WASM request returning 200.
Increasing native movement counters and a safely caught C++ exception additionally
prove execution of the loaded module, rather than merely payload download.

Browser evidence is recorded in `validation/browser-results.json` and
`validation/browser-console.log`; the repeatable flow is in
`docs/BROWSER_VALIDATION.md`. Testing used a 1280×800 desktop viewport and the
in-app browser's narrow panel. The final clean build was reloaded and all four
demos launched again:

| Demo | Observed native tick | Observed native moves | Render rejections |
| --- | ---: | ---: | ---: |
| Material Lab | 12 | 4,645 | 0 |
| Waterworks | 6 | 14,629 | 0 |
| Foundry | 15 | 9,097 | 0 |
| Neon Works | 9 | 7,697 | 0 |

Menu/status, simulation motion, cyan character and spawn clearance were inspected.
No black/magenta fallback materials, exposed placeholder geometry, missing shaders,
texture-update failures or WebGL/WASM errors were observed in the final run.
Intentional magenta neon strips were visible. UI tests established:

- Wall selection with keyboard 3 and LMB painting changed native probe (420,25)
  from 0 to 1; RMB erasing changed it back to 0. Native paint counters increased.
- Repeated D key input moved the player from x=24 to x=24.9527740478516.
  P toggled pause; Escape opened the menu. The Restart world button reset ticks
  and player position. Instantaneous automation key taps can miss physics ticks.
- LOW/HIGH/NORMAL selected 320×180, 640×360 and 480×270 logical rendering sizes.
- A mutated, paused Neon Works level exported **23,040 Base64 characters**,
  decoding to **17,278 bytes**. Its stored CYSD1 payload digest was
  `2509ba37f0d3b2dddf66cfce3974ad9037524fec85e986477419e15287bcb2ac`.
- Switching to Material Lab removed the mutation; importing the retained Base64
  restored Neon Works and the mutation. Re-export matched the **entire string**.
- Importing `a` reported `Malformed Base64`, kept the active world and import
  count intact, and re-export still matched the complete saved string.
- Local Save Slot / Load Slot restored the same exact export and player state
  after switching worlds. Reloading the browser and loading the slot repeated
  the exact comparison successfully: persistence across reload was actually tested.
- Final clean-build console reported `WEB_CPP_EXCEPTION_PROBE true` from an
  intentionally invalid native payload, confirming C++ validation catches work
  inside the WASM side module. The opt-in test preserves the active world.
- Final clean-build console capture contained **0 errors and 0 warnings**.

The final handover tab was then navigated to the normal URL without `?test=1`.
Its menu rendered in the narrow panel, no test-state DOM node existed, and its
console contained no errors or warnings. The temporary desktop viewport override
was reset. Preview remains running through the tested Windows launcher.

Portable import used the exported text retained in the Godot save field across
world changes. The automation interface did not deliver external clipboard paste
to Godot's canvas TextEdit; **external copy/paste interoperability is unverified**.
Held jetpack input was not independently proven. Persistence was tested across
page reload on the same origin/profile, not browser restart or another profile.
The default browser was opened by `0Preview.cmd`; acceptance claims refer only to
the connected Chromium actually inspected, not an unobserved desktop browser.

## Setup fixes and deviations

1. Reconstructed the user-designated source because the M13 ZIP was missing.
   Added missing export preset/preview helpers around existing tooling.
2. Changed the branch's Emscripten 4.0.11 check to the explicitly requested M13
   **4.0.20**. Kept Godot and godot-cpp exact versions. Separate native/Web
   generated bindings and stage/build outputs prevent collisions.
3. Added explicit Windows child-process PATH and `.bat` resolution, full Git Bash,
   the LLVM archiver alias, configurable local paths and logged wrapper commands.
4. Godot crashed with `0xC0000005` after sandbox denial of user-data/log writes.
   The same Godot executable and fixtures passed with normal directory access.
   This does not require an Administrator Godot session in ordinary use.
5. Used the existing explicit local `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` override
   because native bindings/DLL bytes differ from historical cross-build hashes.
   Local bindings archive SHA-256:
   `bf4ac16823c53cd74ad7ea8c95227deb77b885df30be021e8f3117cd18ea218a`.
   Historical release hashes were not rewritten. Scoped child-process Git
   `safe.directory` entries handle the two local bindings checkout owners.
6. Added the missing Godot `ref.hpp` include and reused the existing Windows
   narrowing-warning setting for the Web build; no unsafe ABI casts were added.
7. Corrected two Web-controller references to existing inherited member names.
   Rapier static calls now resolve through the existing guarded ClassDB capability
   path, allowing GDScript to parse with the Web Rapier plugin absent.
8. Preserved native C++ exceptions. The first side module expected an exception
   tag the official Godot runtime did not provide. Emulated exceptions also
   failed on runtime imports. The working build retains `-fwasm-exceptions`,
   `-sSUPPORT_LONGJMP=wasm`, `-sWASM_LEGACY_EXCEPTIONS=1` and links matching PIC
   `libc++-legacyexcept`, `libc++abi-legacyexcept`, and `libunwind-legacyexcept`
   with `-Wl,-Bsymbolic`. No C++ STL objects/exceptions cross the C GDExtension
   boundary. Actual browser exception rejection was tested; validation was not disabled.
9. Export now rejects Godot error output even when Godot returns exit zero.
   Added export-only/snapshot identity options and safe staging boundaries.
10. Added one focused Godot fixture and opt-in browser diagnostics: native exception
    probe, browser version and DOM mirror of the existing test state. Normal play
    URLs do not enable them. Added workflow docs, local config template, VS Code
    tasks, source audit and evidence. No solver files changed.

Changed original source files and original/current hashes are exhaustively listed
in `validation/source-audit.json`. Added workflow files are `dev.cmd`, `tools/dev.py`,
`tools/dev-config.example.json`, `tools/audit_workspace.py`, `preview.py`,
`0Preview.cmd`, `.vscode/tasks.json`, `.vscode/settings.json`, root README/AGENTS,
the documentation/evidence files, `source/tools/serve_web.py`,
`source/godot/export_presets.cfg` and `source/godot/tests/test_web_demo_setup.gd`.

## Retained official download hashes

These hashes identify downloaded tool inputs, not an absent M13 package manifest.
Official source links and extraction destinations are in the development guide.

| File under `.local/downloads/` | SHA-256 |
| --- | --- |
| `Godot_v4.7-stable_win64.exe.zip` | `02a5312236f4e0209c78bcb2f52135b1963e6b8888c873c9cee81459e60bcd71` |
| `Godot_v4.7-stable_export_templates.tpz` | `9714459dc071907c0f3d5f17d608faf69e7cda21331fc5d39c4503ffa4e99eec` |
| `llvm-mingw-20260826-ucrt-x86_64.zip` | `ae601f4e0f72bbdf441ad2df8bb16f037e2e9251559ea6b37b4057aef39c06c3` |
| `PortableGit-2.55.0.5-64-bit.7z.exe` | `5aa8a20f6e9abb2c755f0e73c91c687701a46b309ad84a0ca6509380fa4ae290` |
| `scons-4.10.1-py3-none-any.whl` | `bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126` |
| `godot-rapier-2d-single-v0.35.2.zip` | `73b46bfe2cfc40e3875f4f367478bbd2b1090f563eeef57f4fed3fc274aae1f0` |

## Clean rebuild and remaining scope

`dev.cmd rebuild` was executed successfully: it deletes only the verified
`source/build/` directory, then compiles and exports Web again. Native tests/builds
were rerun afterward. SDK and bindings caches are intentionally preserved.
The complete native-plus-Web clean sequence and cold bindings procedure are in
`docs/LOCAL_DEVELOPMENT.md`.

All feasible Windows source-build, fixture, Web export and Chromium interaction
gates have evidence above. The original prebuilt/archive gates remain blocked;
the four historical consistency hashes remain unresolved. WSL/Linux, macOS,
Firefox and Safari are untested. Sixteen other-platform LFS pointers require
restoration/building before those platforms can be used.

Web remains **single-worker compatibility mode**. Rapier Web / Physics Pit is
disabled, and full browser threading parity is not established. CYSD1 reconstructs
a level, not a full mid-tick scheduler/RNG replay checkpoint. There was no Rapier
port, engine redesign, per-cell Godot object model or JavaScript simulation rewrite.

Recommended next task: add a repeatable Chromium acceptance runner around the
existing opt-in diagnostics, including verified external clipboard import/export.
If the original M13 ZIP becomes available, separately compare its manifest and
prebuilt export with this source-based environment.
