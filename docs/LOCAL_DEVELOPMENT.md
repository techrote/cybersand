# CyberSand local development

**Status: Current local workflow, reviewed 2026-09-08.** Work in `C:/kybersand`;
functional deliverables belong in `C:/cybersand`. Open the editable project with
`Open-Godot.cmd`, using Godot in `C:/Godot47`.

`source/` is reconstructed from `web-demo-m11` base
`e2892c54d4bd91aac60971e81c748bd49fbe2adb` plus local changes; it has no `.git`.
The original [setup report](../LOCAL-DEV-SETUP-REPORT.md) is historical evidence,
not an exhaustive list of today's edits. The [current audit](../source/docs/audits/2026-09-08-documentation-audit.md)
records actual source identity, partial backup coverage, fresh tests and runtime
hashes. No current local changes are committed in the inspected repositories.
Original blob hashes are in [SOURCE-PROVENANCE.json](../SOURCE-PROVENANCE.json).
The M13 ZIP remains unavailable; this is not package extraction/verification.
Native C++ remains authoritative for cellular simulation.

## Required software

| Component | Exact version used |
| --- | --- |
| Godot editor/exporter | `4.7.stable.official.5b4e0cb0f` |
| Web templates | Godot 4.7 `web_dlink_nothreads_{debug,release}.zip` for compatibility; `web_dlink_{debug,release}.zip` for threaded |
| emcc/em++ | **Emscripten 4.0.20** |
| emsdk scripts | tag 4.0.20, commit `e4fe26ef59168ff44f4c23c466e497bf60b3411e` |
| godot-cpp | `101ae38034304346a46ea9ea84ae156d3e860496`, API 4.7 |
| Windows compiler | LLVM-MinGW `20260826-ucrt-x86_64`, Clang **23.1.0** |
| Python | **3.12.14** tested; helpers require 3.10+ |
| SCons | **4.10.1**, existing hash-pinned requirements |
| Git Bash/coreutils | PortableGit **2.55.0.windows.5** |
| Native/Web Rapier2D | **0.35.2**, single precision; profile-specific WASM hashes in the source Rapier lock |
| Browser | Retained Chromium 152 runs; dates/limits in [browser validation](BROWSER_VALIDATION.md), no browser rerun in the documentation audit |

Emscripten installs its own Node 22.16.0 and Python 3.13.3. No separate JS package
stack, Docker, WSL, account, backend or GitHub service is needed for ordinary
development from this workspace copy.

## One-time setup

Open `C:/kybersand` as the VS Code workspace to use its tasks. All commands below
start there. `.local/` contains configured tools; Godot is in `C:/Godot47`.
Offline transfer requires the **whole workspace including .local/** plus that
Godot installation/retained archive. The intended Git policy ignores these
large files; this snapshot itself is not tracked in Git. Verify backup copies.
After moving machines, recreate the Python venv and reactivate emsdk.

1. Install Python 3.12.14, or set `PYTHON` to a compatible interpreter. The initial
   interpreter here came from Codex's bundled runtime; that path is not required.

   ```powershell
   python -m venv .local/python
   .local/python/Scripts/python.exe -m pip install --no-index --find-links .local/downloads --require-hashes -r source/tools/requirements-build.txt
   ```

   For a new online install omit `--no-index --find-links .local/downloads`.
   The pinned SCons wheel is retained in that downloads directory.

2. Extract these retained official inputs. Archive hashes are in the report.

   | Input | Destination |
   | --- | --- |
   | `Godot_v4.7-stable_win64.exe.zip` | `C:/Godot47/` on this host; configure another machine's equivalent path |
   | `Godot_v4.7-stable_export_templates.tpz` | Copy all four nested `templates/web_dlink_{debug,release}.zip` and `templates/web_dlink_nothreads_{debug,release}.zip` files into `.local/web-templates/` |
   | `llvm-mingw-20260826-ucrt-x86_64.zip` | `.local/llvm-mingw-20260826-ucrt-x86_64/` |
   | `PortableGit-2.55.0.5-64-bit.7z.exe` | `.local/git/` |

   Official download locations: [Godot 4.7](https://github.com/godotengine/godot-builds/releases/tag/4.7-stable),
   [LLVM-MinGW 20260826](https://github.com/mstorsjo/llvm-mingw/releases/tag/20260826),
   [PortableGit](https://github.com/git-for-windows/git/releases/tag/v2.55.0.windows.5).
   No newer versions should be silently substituted.

   Create the archiver alias expected by the existing Bash build script:

   ```powershell
   Copy-Item .local/llvm-mingw-20260826-ucrt-x86_64/bin/llvm-ar.exe .local/llvm-mingw-20260826-ucrt-x86_64/bin/x86_64-w64-mingw32-gcc-ar.exe
   ```

3. Use the retained `.local/emsdk`, or obtain emsdk tag `4.0.20`, then:

   ```powershell
   Push-Location .local/emsdk
   ../python/Scripts/python.exe emsdk.py install 4.0.20
   ../python/Scripts/python.exe emsdk.py activate 4.0.20
   Pop-Location
   ```

   Reactivate after moving directories to regenerate SDK paths. Keep the installed
   SDK tree for offline use. The Web builder caches matching PIC exception
   libraries using `embuilder.py --pic`. No system PATH edits are needed.

4. Retain/copy the two separate pinned bindings checkouts. For an online first install:

   ```powershell
   .local/git/cmd/git.exe clone https://github.com/godotengine/godot-cpp.git .local/godot-cpp-native
   .local/git/cmd/git.exe -C .local/godot-cpp-native checkout --detach 101ae38034304346a46ea9ea84ae156d3e860496
   .local/git/cmd/git.exe clone --no-hardlinks .local/godot-cpp-native .local/godot-cpp-web
   ```

   Git verifies local revisions; no remote access is required for later builds.
   Never share generated bindings between Web and native.

5. On a new setup, create local paths (preserve an existing configuration):

   ```powershell
   Copy-Item tools/dev-config.example.json .local/dev-config.json
   ```

   Set the copied JSON's `GODOT_BIN` to
   `C:/Godot47/Godot_v4.7-stable_win64_console.exe` for this host. The example
   still uses the older `.local/godot-4.7/` path; the active configuration already
   points to `C:/Godot47`. Environment variables override JSON. Paths may be workspace-relative or absolute.
   The example explicitly enables the repository's existing
   `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` for local Windows builds: local archive/DLL
   bytes differ from historical cross-build hashes, despite pinned compiler/source.
   This is **not** a release provenance attestation. The override also bypasses
   some native source-cleanliness/compiler checks; exact godot-cpp revision is
   still required. Inspect binding status explicitly. Strict script defaults
   remain when the override is absent.

6. If copying source without binaries, restore Rapier's Windows DLL from the
   retained `godot-rapier-2d-single-v0.35.2.zip` into
   `source/godot/addons/godot-rapier2d/bin/`. Its SHA-256 must be
   `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`.
   The original asset is `godot-rapier-2d-single.zip` from
   [Rapier v0.35.2](https://github.com/appsinacup/godot-rapier-physics/releases/tag/v0.35.2).
   Build the CyberSand Windows DLL with `native-build`.
   Restore the two pinned Web Rapier members when needed; paths/hashes are in the
   [Rapier runbook](../source/docs/operations/rapier-2d-migration-runbook.md).
   The current audit found 14 remaining other-platform LFS pointers. They must
   be restored or rebuilt before those platforms can run.

7. Run `dev.cmd doctor`, `native-bindings`, `native-build`, `native-test`,
   `godot-test`, then `web`. Godot needs normal access to its user-data directory.
   The 2026-09-07 restricted setup run failed without that access; this is
   historical environment evidence, not a current approval requirement or an
   instruction to run Godot as Administrator.

## Directory layout and architecture

```text
source/native/                 authoritative C++ solver and existing regressions
source/godot/                  desktop project, UI/input, shaders, Godot fixtures
source/godot/native_extension/ bulk adapters and native demo snapshot bridge
source/tools/                  existing build scripts and preview helper
source/build/tests.exe         Windows native regression executable
source/build/web-libs/         CyberSand WASM side module
source/build/web-project/      disposable staged Web project and imports
source/build/web/              fresh static HTML/JS/PCK/WASM export
.local/godot-cpp-native/       native generated bindings/archive
.local/godot-cpp-web/          independent Web generated bindings/archive
.local/                       ignored tools/downloads/local configuration
validation/local/<timestamp>/  commands, outputs, timings, result JSON
tools/dev.py, dev.cmd          wrappers around existing project tooling
preview.py, 0Preview.cmd       HTTP preview launchers
```

C++ `World` and fixed-step scheduling remain authoritative. Desktop Godot retains
its asynchronous Godot worker, immutable snapshots and render-patch handoff.
Web synchronously completes one native tick per unpaused 60 Hz Godot physics
callback, with bounded publication cadence. Compatibility forces one cellular
worker; threaded Web uses Auto's 2/4/6 native pool internally and still waits for
the tick. Rapier stays on the Godot main thread. Godot exchanges packed bulk data, renders textures and
samples character collision against native cells. There are no per-cell Godot
objects or per-cell JS/WASM calls. The builder selects Web scene, viewport,
worker policy and optional cellular-only physics in the disposable stage;
the source project separately selects native Auto and Rapier.

CYSD1 stores the native 1024×1024 level payload and metadata using DEFLATE,
SHA-256 and Base64. Validation precedes a native-world swap. It reconstructs a
level; it omits tick/epoch/activity, complete configuration, pending commands
and Rapier caches. Body restoration uses a `1e-5` tolerance. Export clears
transient obstacles under exclusive ownership; rebuild coupling before the
next tick. See [save/replay contracts](../source/docs/operations/testing-validation-and-replay.md).

## Native build

```powershell
.\dev.cmd native-bindings
.\dev.cmd native-build
```

These run the existing `tools/build_pinned_godot_cpp.sh windows` and
`tools/build_native_extension_windows.sh` in `source/`, through Git Bash with
the configured SCons interpreter, LLVM compiler and native bindings checkout.
The DLL goes to the path already selected by the GDExtension manifest.

## Native tests

```powershell
.\dev.cmd native-test
.\dev.cmd godot-test
```

The native command wraps the real Makefile invocation from `source/`:

```text
mingw32-make test CXX=clang++ CC=clang
```

It includes the C11 header check and Debug `-O0 -g3` C++ regressions.
Godot-test imports `source/godot/` and runs each existing `tests/test_*.gd` with:

```text
Godot --headless --path source/godot --script res://tests/<fixture>.gd
```

Timeout, nonzero exit and Godot error output fail the wrapper. It discovers
`test_*.gd` with a 180-second per-runner timeout. The current inventory has **15**
runners, including CYSD1, worker parity, Auto, benchmark and Web Rapier fixtures.
The setup fixture covers four non-body constructors; Physics Pit has a separate
fixture. Nine groups in `test_cell_world.gd` are one runner. Earlier 11/12/14
totals describe earlier checkpoints. Fresh audit results: six doctor checks,
39/39 native tests and 15/15 Godot runners on Windows. Godot loaded the retained
DLL without rebuilding; its hash is in the current audit. These passes do not
prove source-to-DLL reproducibility or browser execution.

## Web C++ build

```powershell
.\dev.cmd web-build
```

Equivalent command from `source/` after activating SDK and SCons:

```text
python tools/build_web.py --cpp ../.local/godot-cpp-web --compile-only
```

The builder verifies both emcc/em++ 4.0.20 and clean pinned bindings, uses the
existing reduced Web bindings profile, `template_release`, wasm32 and threads=no.
It compiles the actual solver into a dynamic side module. Matching PIC libc++,
libc++abi and unwind support are bound inside that module, since the official
Godot runtime does not supply C++ exception handling. Catches remain enabled.

## Web export

An optional threaded Auto profile is available; see [Web threading](WEB_THREADING.md)
for build, hosting, delivery, and acceptance instructions. Compatibility remains
the default for the commands below.

```powershell
.\dev.cmd web-export
# Compile and export together:
.\dev.cmd web
```

Underlying export-only command from `source/`:

```text
python tools/build_web.py --cpp ../.local/godot-cpp-web --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --templates ../.local/web-templates --export-only --source-commit e2892c54d4bd91aac60971e81c748bd49fbe2adb
```

The `Web Demo` preset uses matching dlink/no-thread templates. Output includes
`index.html`, `index.js`, `index.wasm`, `index.side.wasm`, `index.pck`, the
CyberSand side module, notices, `build-info.json`, and `SHA256SUMS`. A PCK alone
does not establish success. The builder rejects Godot errors even with exit zero.
Rapier-enabled exports also contain `godot_rapier.wasm` and its notices.
`--source-commit` records a **snapshot base**, not HEAD or a local-change manifest.
`--export-only` checks WASM structure but does not prove freshness relative to
source. Record current inputs/hashes alongside validation. Existing Web CI's
Emscripten 4.0.11/missing `--native-cpp` contradictions are documented in the
[release/build guide](../source/docs/operations/github-development-and-release.md).

## Preview

```powershell
.\0Preview.cmd
python preview.py --open
# Or without changing PATH:
.local/python/Scripts/python.exe preview.py --open
```

The helper selects `static-web/` if present, otherwise `source/build/web/`.
To force the rebuilt output:

```text
python preview.py --directory source/build/web --port 8000 --open
```

Open `http://127.0.0.1:8000/`, never `file://`. Python's standard-library server
sets WASM MIME, COOP/COEP/CORP and no-cache headers. Ctrl+C stops the server.

## Browser validation

With preview running, `dev.cmd http-smoke` checks six HTTP payloads, WASM magic,
MIME and isolation headers. This is structural verification, not browser execution.
For Chromium smoke testing, open `http://127.0.0.1:8000/?test=1` and follow
[BROWSER_VALIDATION.md](BROWSER_VALIDATION.md). The existing opt-in
`window.cybersandTest` interface exposes tick/player/material/save diagnostics;
a JSON DOM mirror supports read-only test tools. Normal URLs expose neither.
Capture console output and check actual rendering. Reload after every export.

## WSL/Linux invocation

Windows was tested directly; WSL was not installed. For WSL, install Linux Godot
4.7, Emscripten 4.0.20, Python/SCons, and use Linux paths in local config. Keep
Windows, Linux and Web bindings checkouts separate. Do not use the Windows venv
from Linux. Existing Linux scripts pin GCC 13.3.0 and binutils 2.42.

```bash
python3 -m venv .local/python-linux
. .local/python-linux/bin/activate
python -m pip install --require-hashes -r source/tools/requirements-build.txt
. "$EMSDK/emsdk_env.sh"
python tools/dev.py native-test
python tools/dev.py native-bindings
python tools/dev.py native-build
python tools/dev.py godot-test
python tools/dev.py web
python preview.py --open
```

Configure GODOT_BIN, GODOT_CPP_NATIVE, GODOT_CPP_WEB and EMSDK for Linux first.
Restore/build native Linux GDExtensions, including Rapier. The wrapper delegates
Linux native builds to the existing `source/tools/build_native_extension.sh`.
These are documented invocations, **not executed WSL/Linux validation**.

## Troubleshooting actually encountered

- **Godot startup crash:** sandbox writes to
  `%APPDATA%/Godot/app_userdata/.../logs` failed, followed by `0xC0000005`.
  The same binary/fixtures passed with normal directory access. Allow that access.
- **PATH and Windows .bat lookup:** wrappers explicitly configure child-process
  PATH; the exporter resolves Emscripten batch executables with `shutil.which`.
- **Missing Bash utilities/archiver:** full PortableGit and the documented gcc-ar
  alias are needed by the existing scripts.
- **Historical native hash mismatch:** use the explicit local drift override,
  not rewritten release hashes. Source revision checking remains enabled.
- **Godot parse errors with exit zero:** stale inherited member names and direct
  Rapier class references were corrected to match the existing base controller
  and dynamic capability-probe approach. Exports now fail on error output.
- **WASM exception tag/unresolved runtime functions:** side modules normally omit
  SDK libraries. Matching C++ exception libraries are now linked locally. Trying
  emulated exceptions alone failed; no unsafe casts or JS runtime shims were added.
- **Missing package files:** this source branch had no original static export,
  validation manifest, preset or preview helper. Added replacements are setup
  changes, not claims about the supplied M13 ZIP.
- **Historical consistency checker:** `source/tools/ci/check_m11_consistency.py`
  reports local-snapshot-vs-release hash drift and an unresolved Linux LFS pointer.
  Broken onboarding links/frontmatter were repaired. Remaining historical hash
  failures are retained, not hidden by updating old locks.
- **Git checkout ownership:** Codex's sandbox and normal Windows account have
  different owners. The wrapper scopes Git `safe.directory` entries to the two
  verified bindings directories under `.local/`, in child processes only. Global
  Git configuration remains unchanged. Exact binding revision checks remain;
  the native drift override can bypass dirty-tree checks. This does not create
  a source checkout or verify source commit/backup status.

## Clean rebuild

Stop preview, then run:

```powershell
.\dev.cmd clean
.\dev.cmd native-test
.\dev.cmd native-build
.\dev.cmd godot-test
.\dev.cmd web
.\0Preview.cmd
# In another terminal:
.\dev.cmd http-smoke
```

Clean deletes only the verified `source/build/` generated directory, preserving
source, tools, downloaded archives, DLLs and browser saves. `dev.cmd rebuild`
combines that clean with Web compile/export. Both retain bindings/SDK caches.
For a cold bindings build create two fresh checkouts at the pinned revision,
configure their paths, and rerun native-bindings/native-build/web. SDK PIC
libraries rebuild automatically when missing. Recheck the browser afterward.

## Known limitations

- Default compatibility export: one simulation worker. Optional threaded export:
  2/4/6 Auto native workers, with synchronous Godot tick ownership; see WEB_THREADING.md.
- Rapier Web / Physics Pit runs in both profiles; see the [Rapier runbook](../source/docs/operations/rapier-2d-migration-runbook.md). Full asynchronous Web ownership remains unimplemented.
- CYSD1 restores levels, not exact replay checkpoints.
- Browser storage is origin/profile dependent; keep portable saves.
- Firefox, Safari, WSL/Linux and macOS were not tested here.
- Original M13 archive integrity and prebuilt verification remain blocked by
  the missing ZIP. See the report for actual local build/browser results.

