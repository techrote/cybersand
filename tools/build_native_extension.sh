#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_cpp_root="${GODOT_CPP_ROOT:-}"

if [[ -z "$godot_cpp_root" ]]; then
    echo "GODOT_CPP_ROOT must point to a built godot-cpp checkout" >&2
    exit 2
fi

godot_cpp_library="${GODOT_CPP_LIBRARY:-$godot_cpp_root/bin/libgodot-cpp.linux.template_debug.x86_64.a}"
output="$project_root/godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"

g++ -std=c++20 -O3 -DNDEBUG -fPIC -shared -pthread \
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
    -o "$output"

echo "$output"
