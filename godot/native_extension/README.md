# Cyber Sand native Godot bridge

This GDExtension exposes the native phased cellular core as
`CyberNativeCellWorld`. The runnable Godot sandbox selects it when the matching
platform library is present and retains `CyberCellWorld` as a functional
fallback.

The extension owns no scene-tree node or Rapier RID. Rigid-body transforms enter
as packed value data, become a transient native occupancy field for the cellular
tick, and return only bounded impulses and counters.

Linux builds are produced by `tools/build_native_extension.sh`. Windows x86_64
builds are produced by `tools/build_native_extension_windows.sh`. Both require
`GODOT_CPP_ROOT` to point to the exact Godot 4.7 `godot-cpp` revision
`101ae38034304346a46ea9ea84ae156d3e860496`; the scripts reject an unknown or
different revision. All cached input names, origins, sizes, licenses, and
SHA-256 values are in `third_party/native-toolchain.lock.json`.

The m11 Windows binary uses LLVM-MinGW 20260826 (LLVM 23.1.0, UCRT). Set
`WINDOWS_CXX` and `GODOT_CPP_LIBRARY` to override the compiler or static-library
paths. `MINGW_CXX` remains a compatibility alias. The shipped DLL imports only
Windows UCRT/system DLLs.

## Offline pinned rebuild

The setup-cache v2 contains these already-downloaded inputs:

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
checker asserts all three symbol-version families. Windows execution still
requires a real Windows Godot 4.7 validation pass; Linux can only provide
PE/import checks.

The exact Linux host package identities are also recorded in the lock file:
GCC/libstdc++ development packages `13.3.0-6ubuntu2~24.04`, binutils
`2.42-4ubuntu2.5`, glibc development packages `2.39-0ubuntu8.6`, and
`linux-libc-dev` `6.8.0-85.85`. Those installed packages were not present as
redistributable local archives, so setup-cache v2 records them as
snapshot/reference-only dependencies rather than embedding host packages.
