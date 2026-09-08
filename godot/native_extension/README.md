# Cyber Sand native Godot bridge

Status: **Current** implementation/build guide, reviewed 2026-09-08. Historical
M11 rebuild recipes below identify earlier inputs; current source and retained
binary/test identities are in the [documentation audit](../../docs/audits/2026-09-08-documentation-audit.md).
This source directory is a reconstructed snapshot plus edits without Git history.

This GDExtension exposes the native phased cellular core as
`CyberNativeCellWorld`. The desktop Godot sandbox selects it when the matching
platform library is present and retains `CyberCellWorld` as a functional
fallback. Web requires its native WASM extension and does not substitute that
fallback when native creation fails.

The extension owns no scene-tree node or Rapier RID. Rigid-body transforms enter
as packed value data, become a transient native occupancy field for the cellular
tick, and return only bounded impulses and counters.

On desktop, `CyberSimulationWorker` exclusively owns the adapter/World from a
Godot Thread. On Web, `web_demo_controller.gd` calls the adapter synchronously on
the Godot main thread. Native pool workers call no Godot APIs; their job
parallelism does not transfer World ownership. Rapier is main-thread owned in
both cases. See [threading](../../docs/architecture/simulation-tick-and-threading.md)
and [coupling](../../docs/architecture/rigid-body-and-cellular-coupling.md).

`CyberDemoBridge` adds fixed-size level construction/export/import. CYSD1 stores
cell material/state/temperature and selected Web metadata, not scheduler or
Rapier replay state. Export clears the transient obstacle mask, so the exclusive
owner must rebuild coupling before the next tick; it is not a concurrent const
read. See [demo_snapshot.hpp](../../native/include/cybersand/demo_snapshot.hpp)
and [save/replay scope](../../docs/operations/testing-validation-and-replay.md).

Linux builds are produced by `tools/build_native_extension.sh`. Windows x86_64
builds are produced by `tools/build_native_extension_windows.sh`. Both require
`GODOT_CPP_ROOT` to point to the exact Godot 4.7 `godot-cpp` revision
`101ae38034304346a46ea9ea84ae156d3e860496`; the scripts reject an unknown or
different revision. All cached input names, origins, sizes, licenses, and
historical SHA-256 values are in
[native-toolchain.lock.json](../../third_party/native-toolchain.lock.json).
The lock's M11 outputs do not identify today's locally rebuilt DLL.

The historical M11 Windows binary used LLVM-MinGW 20260826 (LLVM 23.1.0, UCRT). Set
`WINDOWS_CXX` and `GODOT_CPP_LIBRARY` to override the compiler or static-library
paths. `MINGW_CXX` remains a compatibility alias. Historical UCRT/system-import
checks are not a substitute for checking a newly produced binary.

## Active Windows and Web workflow

From `C:/kybersand`, use `dev.cmd native-bindings`, `native-build`, `native-test`
and `godot-test`; Godot is installed in `C:/Godot47`. `dev.cmd web` builds the
compatibility profile; `web --profile threaded` builds optional native job
parallelism. The [Web builder](../../tools/build_web.py) checks Emscripten 4.0.20,
Godot 4.7, SCons 4.10.1 and separate pinned Web godot-cpp bindings. Rapier v0.35.2
is included by default. Local setup is `C:/kybersand/docs/LOCAL_DEVELOPMENT.md`.

The explicit local drift override permits historical archive/output hash
mismatches and bypasses some source-cleanliness/compiler checks; the exact
godot-cpp revision requirement remains. This is not bit-identical M11 reproduction.
Fresh 2026-09-08 Windows tests used the retained DLL without rebuilding it;
the audit above records its hash and the limitation on source-to-binary proof.

## Historical offline pinned rebuild recipe (Linux host)

The historical setup-cache v2 inventory lists these inputs; availability must
be verified before using this recipe:

- `godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496.tar.gz`;
- `scons-4.10.1-py3-none-any.whl`; and
- `llvm-mingw-20260826-ucrt-ubuntu-22.04-x86_64.tar.xz`.

Prepare a new environment without network access:

```sh
tools/prepare_native_build_env.sh /new/build-env \
  /cache/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496.tar.gz \
  /cache/scons-4.10.1-py3-none-any.whl \
  /cache/llvm-mingw-20260826-ucrt-ubuntu-22.04-x86_64.tar.xz
```

Build both binding libraries and extensions:

```sh
export GODOT_CPP_ROOT=/new/build-env/godot-cpp-101ae38034304346a46ea9ea84ae156d3e860496
export SCONS_PYTHON=/new/build-env/venv/bin/python
export LLVM_MINGW_ROOT=/new/build-env/llvm-mingw-20260826
SCONS_JOBS=8 tools/build_pinned_godot_cpp.sh linux
SCONS_JOBS=8 tools/build_pinned_godot_cpp.sh windows
GODOT_CPP_ROOT="$GODOT_CPP_ROOT" tools/build_native_extension.sh
GODOT_CPP_ROOT="$GODOT_CPP_ROOT" \
  WINDOWS_CXX="$LLVM_MINGW_ROOT/bin/x86_64-w64-mingw32-g++" \
  tools/build_native_extension_windows.sh
tools/check_linux_runtime_floor.sh
```

The Linux build uses the tracked `tools/toolchains/g++` wrapper for both
`godot-cpp` and the final extension. It adds `-fno-math-errno` so a modern build
host does not inject `fmodf@GLIBC_2.38`. The resulting CyberSand extension has
a glibc 2.32 symbol floor, while the complete project requires glibc 2.34 due
to the official Rapier2D v0.35.2 library. It also requires a compatible
libstdc++/C++ ABI providing `GLIBCXX_3.4.30` and `CXXABI_1.3.9`; the floor
checker asserts all three symbol-version families. These are historical artifact
floors/required checks, not an audit of the current local Linux LFS pointer.
Linux PE/import checks alone cannot certify Windows execution; dated Windows
runtime passes are now recorded separately in the current audit.

The exact Linux host package identities are also recorded in the lock file:
GCC/libstdc++ development packages `13.3.0-6ubuntu2~24.04`, binutils
`2.42-4ubuntu2.5`, glibc development packages `2.39-0ubuntu8.6`, and
`linux-libc-dev` `6.8.0-85.85`. Those installed packages were not present as
redistributable local archives, so setup-cache v2 records them as
snapshot/reference-only dependencies rather than embedding host packages.
