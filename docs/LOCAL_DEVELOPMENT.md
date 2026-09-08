# CyberSand local development

**Current Windows host procedure, reviewed 2026-09-08.** Work in `C:/kybersand`,
with Godot 4.7 in `C:/Godot47`. This page owns host setup and wrapper paths.
The source [build guide](../source/docs/operations/local-build-and-validation.md)
owns dependency pins, repository-native commands and build/evidence distinctions.
[Source identity](../source/docs/operations/source-checkpoint-and-recovery.md)
records the two local repositories; the acquisition base is not current HEAD.

## Configured layout

| Location | Role |
|---|---|
| `source/` | Separate upstream-derived source checkout; do not edit build staging |
| `.local/python/` | Python 3.12.14 environment with SCons 4.10.1 |
| `.local/godot-cpp-native/`, `.local/godot-cpp-web/` | Separate pinned bindings/generated libraries |
| `.local/llvm-mingw-20260826-ucrt-x86_64/` | Windows-host Clang 23.1.0/UCRT |
| `.local/emsdk/` | Emscripten 4.0.20; emsdk tag4.0.20 commit `e4fe26ef59168ff44f4c23c466e497bf60b3411e` |
| `.local/web-templates/` | Four matching Godot 4.7 dlink template ZIPs |
| `.local/git/` | PortableGit 2.55.0.windows.5, Bash/coreutils |
| `.local/dev-config.json` | Host paths and explicit local overrides |
| `source/build/` | Generated tests, side modules, staging and exports |
| `validation/local/<timestamp>/` | Commands, outputs, hashes and result JSON |

Tools/configuration are ignored, not part of either source checkpoint. Use the
exact retained inputs or reconstruct from the dependency locks and
[historical setup report](../LOCAL-DEV-SETUP-REPORT.md). The M13 ZIP was not supplied;
this is the reconstructed branch, not verified package extraction.

## Recreate host configuration when needed

Keep the existing `.local/dev-config.json`. For a new setup, copy
[dev-config.example.json](../tools/dev-config.example.json) there and set `GODOT_BIN`
to `C:/Godot47/Godot_v4.7-stable_win64_console.exe` on this host. The example's older
`.local/godot-4.7` path is not the active location. Environment variables override
JSON; paths may be absolute or workspace-relative.

Create a Python environment and install the hash-pinned build requirement:

```powershell
python -m venv .local/python
.local/python/Scripts/python.exe -m pip install --require-hashes -r source/tools/requirements-build.txt
```

For retained offline wheels add `--no-index --find-links .local/downloads`.
Extract the exact Godot/LLVM-MinGW/PortableGit inputs; archive identities are in
the setup report. Put all four dlink template members in `.local/web-templates`.
The Bash Windows builder needs this archiver alias if absent:

```powershell
Copy-Item .local/llvm-mingw-20260826-ucrt-x86_64/bin/llvm-ar.exe .local/llvm-mingw-20260826-ucrt-x86_64/bin/x86_64-w64-mingw32-gcc-ar.exe
```

Use emsdk4.0.20 and run `emsdk.py install 4.0.20`, then `emsdk.py activate 4.0.20`
from its directory. Reactivate after moving machines/directories and recreate the
Python venv. SDK PIC C++ exception libraries are built when required; no global
PATH change is needed. Keep native and Web godot-cpp checkouts at the exact revision
in the source build guide; never share generated bindings between targets.

The explicit local `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` bypasses some native
compiler/dirty and archive-provenance checks. Current native builds no longer
require M11 output byte equality; opt into that historical check with
`CYBERSAND_VERIFY_M11_OUTPUT=1`, which cannot be bypassed by the drift flag. Exact
godot-cpp revision remains enforced. Inspect status yourself; this override is not
a historical reproducible-release claim. Git safe-directory configuration is scoped
by the wrapper to the two configured local bindings paths in child processes.

## Normal commands

From `C:/kybersand`:

```powershell
.\dev.cmd doctor
.\dev.cmd native-bindings
.\dev.cmd native-build
.\dev.cmd native-test
.\dev.cmd godot-test
.\dev.cmd web
# Or the optional pthread profile:
.\dev.cmd web --profile threaded
```

Close Godot before replacing its loaded Windows DLL. `native-test` compiles Debug
core tests; `godot-test` uses the installed DLL without rebuilding it. `web-build`
compiles only, `web-export` exports existing modules, `web` does both. Export-only
does not establish source freshness. The wrapper still records the acquired base
in `build-info.json`; capture actual HEAD/local deltas and artifact hashes separately.
The [release guide](../source/docs/operations/github-development-and-release.md)
records unresolved CI and provenance contradictions.

Godot needs normal user-data-directory access. Historical restricted runs crashed
on log creation; this is not a requirement to run as Administrator. Missing runtime
libraries must be materialized from Git LFS or rebuilt for the target; the local
all 18 required payloads were materialized and verified during finalisation.
Materialization establishes artifact identity, not platform runtime acceptance.

## Preview and browser checks

```powershell
.local/python/Scripts/python.exe preview.py --directory source/build/web --port 8000 --open
.\dev.cmd http-smoke --url http://127.0.0.1:8000/
```

For threaded output select `source/build/web-threaded` and pass `--profile threaded`
to the HTTP check. `0Preview.cmd`/default preview prefer `static-web` when it exists,
otherwise `source/build/web`; select a directory explicitly for revision-specific tests.
Serve HTTP, not `file://`; the helper provides WASM MIME, isolation and no-cache
headers. Ctrl+C stops preview. HTTP smoke is structural, not browser execution.
Run the [browser procedure](BROWSER_VALIDATION.md), including the appropriate
Rapier fixture, against the identified export. Both profiles normally include Rapier.

## Rebuild and platform limits

`dev.cmd clean` deletes only verified generated `source/build`; it preserves
installed DLLs, tools and bindings caches. `dev.cmd rebuild` performs that clean
then Web compile/export. Neither is a cold bindings rebuild. For one, configure
fresh pinned native/Web checkouts, rebuild their libraries and the extension,
then test/export/browser-check the resulting artifacts.

WSL/macOS were not executed locally. Linux native/sanitizer and rebuilt Godot
CI outcomes are recorded in the source publication evidence. Use native Python/Godot/tools
and separate target bindings; do not reuse a Windows venv or compiler library.
The source build guide lists Linux commands and historical ABI requirements.
Current source inspection is separate from [dated validation](../source/docs/reference/validation-evidence.md).
