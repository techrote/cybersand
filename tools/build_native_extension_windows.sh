#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_cpp_root="${GODOT_CPP_ROOT:-}"
mingw_cxx="${MINGW_CXX:-x86_64-w64-mingw32-g++}"

if [[ -z "$godot_cpp_root" ]]; then
    echo "GODOT_CPP_ROOT must point to a godot-cpp checkout built for Windows x86_64" >&2
    exit 2
fi

if ! command -v "$mingw_cxx" >/dev/null 2>&1; then
    echo "MinGW C++ compiler not found: $mingw_cxx" >&2
    echo "Set MINGW_CXX to a Linux cross-compiler or MSYS2 MinGW-w64 g++ path." >&2
    exit 2
fi

godot_cpp_library="${GODOT_CPP_LIBRARY:-$godot_cpp_root/bin/libgodot-cpp.windows.template_debug.x86_64.a}"
output="$project_root/godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"

if [[ ! -f "$godot_cpp_library" ]]; then
    echo "Windows godot-cpp library not found: $godot_cpp_library" >&2
    exit 2
fi

"$mingw_cxx" -std=c++20 -O3 -DNDEBUG -DWINDOWS_ENABLED \
    -shared -pthread \
    -I"$project_root/native/include" \
    -I"$godot_cpp_root/include" \
    -I"$godot_cpp_root/gen/include" \
    -I"$godot_cpp_root/gdextension" \
    "$project_root/godot/native_extension/cyber_native_cell_world.cpp" \
    "$project_root/godot/native_extension/register_types.cpp" \
    "$project_root/native/src/world.cpp" \
    "$project_root/native/src/render_snapshot.cpp" \
    "$project_root/native/src/material_rules.cpp" \
    "$project_root/native/src/scheduler_geometry.cpp" \
    "$godot_cpp_library" \
    -Wl,--no-undefined \
    -static -static-libgcc -static-libstdc++ \
    -o "$output"

echo "$output"
