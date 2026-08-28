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
`GODOT_CPP_ROOT` to point to a Godot 4.7 `godot-cpp` checkout built for the
matching target.

The Windows script expects MinGW-w64's `x86_64-w64-mingw32-g++` by default.
Set `MINGW_CXX` and `GODOT_CPP_LIBRARY` to override the compiler or static
library paths. It statically links the GCC, C++ and POSIX-thread runtimes so the
shipped DLL requires only standard Windows system libraries.

Example Linux cross-build of the matching binding library:

```sh
cd /path/to/godot-cpp
python3 -m SCons platform=windows arch=x86_64 target=template_debug \
  api_version=4.7 mingw_prefix=/usr use_mingw=yes
cd /path/to/cyber-sand-engine
GODOT_CPP_ROOT=/path/to/godot-cpp tools/build_native_extension_windows.sh
```
