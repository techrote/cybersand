#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_cpp_root="${GODOT_CPP_ROOT:-}"
expected_revision="101ae38034304346a46ea9ea84ae156d3e860496"
expected_source_ledger_sha="8a2fb6cdcd174a749692da86716c7a1e008ee4216000b53374bcb89ba31e521b"
cxx="${LINUX_CXX:-$project_root/tools/toolchains/g++}"
expected_cxx_fragment="13.3.0"
expected_ld_fragment="2.42"
expected_library_sha="b99b8868348f0018b9cdbbb186c10dabad13610e537945290e91b69040c7e5e0"
expected_output_sha="bf58b2bf4e6ffb639ce847e6f2eb920f89c69f98fe212eed27ba2aede2ddf677"

if [[ -z "$godot_cpp_root" ]]; then
    echo "GODOT_CPP_ROOT must point to a built godot-cpp checkout" >&2
    exit 2
fi

godot_cpp_library="${GODOT_CPP_LIBRARY:-$godot_cpp_root/bin/libgodot-cpp.linux.template_debug.x86_64.a}"
output="${CYBERSAND_NATIVE_OUTPUT:-$project_root/godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so}"

if [[ ! -f "$godot_cpp_library" ]]; then
    echo "Linux godot-cpp library not found: $godot_cpp_library" >&2
    exit 2
fi
actual_library_sha="$(sha256sum "$godot_cpp_library" | awk '{print $1}')"
if [[ "$actual_library_sha" != "$expected_library_sha" && "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
    echo "Linux godot-cpp library differs from the pinned m11 build input" >&2
    echo "expected: $expected_library_sha" >&2
    echo "actual:   $actual_library_sha" >&2
    exit 3
fi
if [[ ! -x "$cxx" ]] && ! command -v "$cxx" >/dev/null 2>&1; then
    echo "Linux C++ compiler not found: $cxx" >&2
    exit 2
fi

cxx_version="$("$cxx" --version | head -n 1)"
ld_version="$(ld --version | head -n 1)"
if [[ "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
    if [[ "$cxx_version" != *"$expected_cxx_fragment"* ]]; then
        echo "Linux compiler mismatch: expected GCC $expected_cxx_fragment" >&2
        echo "actual: $cxx_version" >&2
        exit 3
    fi
    if [[ "$ld_version" != *"$expected_ld_fragment"* ]]; then
        echo "Linux linker mismatch: expected GNU ld $expected_ld_fragment" >&2
        echo "actual: $ld_version" >&2
        exit 3
    fi
fi

source_revision=""
if git -C "$godot_cpp_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    source_revision="$(git -C "$godot_cpp_root" rev-parse HEAD)"
    if [[ -n "$(git -C "$godot_cpp_root" status --porcelain=v1 --untracked-files=no)" && "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
        echo "godot-cpp tracked source is dirty; refusing a release build" >&2
        exit 3
    fi
elif [[ -f "$godot_cpp_root/.cybersand-source-revision" ]]; then
    source_revision="$(tr -d '[:space:]' < "$godot_cpp_root/.cybersand-source-revision")"
    source_archive_sha="$(tr -d '[:space:]' < "$godot_cpp_root/.cybersand-source-archive-sha256" 2>/dev/null || true)"
    if [[ "$source_archive_sha" != "f55d1cd5a2d528a9dc72fc54c1ef2b3d4dd90a0570dd8841d6766cbd4912dad8" && "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
        echo "godot-cpp source archive provenance marker is absent or mismatched" >&2
        exit 3
    fi
    source_ledger="$godot_cpp_root/.cybersand-source-files.sha256"
    source_ledger_sha="$(sha256sum "$source_ledger" 2>/dev/null | awk '{print $1}')"
    if [[ "$source_ledger_sha" != "$expected_source_ledger_sha" && "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
        echo "godot-cpp source ledger is absent or mismatched" >&2
        exit 3
    fi
    python3 "$project_root/tools/verify_pinned_source_tree.py" verify "$godot_cpp_root"
fi
if [[ "$source_revision" != "$expected_revision" ]]; then
    echo "godot-cpp revision mismatch or unverifiable source" >&2
    echo "expected: $expected_revision" >&2
    echo "actual:   ${source_revision:-unknown}" >&2
    exit 3
fi

mkdir -p "$(dirname "$output")"
build_output="$output"
if [[ "${CYBERSAND_DRY_RUN:-0}" != "1" ]]; then
    build_output="$(mktemp "$(dirname "$output")/.$(basename "$output").partial.XXXXXX")"
    trap 'rm -f -- "$build_output"' EXIT
fi
command=(
    "$cxx" -std=c++20 -O3 -DNDEBUG -fPIC -shared -pthread -fno-math-errno
    "-ffile-prefix-map=$project_root=."
    "-ffile-prefix-map=$godot_cpp_root=godot-cpp"
    -I"$project_root/native/include"
    -I"$godot_cpp_root/include"
    -I"$godot_cpp_root/gen/include"
    -I"$godot_cpp_root/gdextension"
    "$project_root/godot/native_extension/cyber_native_cell_world.cpp"
    "$project_root/godot/native_extension/register_types.cpp"
    "$project_root/native/src/world.cpp"
    "$project_root/native/src/render_snapshot.cpp"
    "$project_root/native/src/material_rules.cpp"
    "$project_root/native/src/scheduler_geometry.cpp"
    "$godot_cpp_library"
    -Wl,--build-id=sha1
    -o "$build_output"
)

printf 'Linux GDExtension build command:'
printf ' %q' "${command[@]}"
printf '\n'
if [[ "${CYBERSAND_DRY_RUN:-0}" == "1" ]]; then
    exit 0
fi
env LC_ALL=C TZ=UTC SOURCE_DATE_EPOCH=0 "${command[@]}"

actual_output_sha="$(sha256sum "$build_output" | awk '{print $1}')"
if [[ "$actual_output_sha" != "$expected_output_sha" && "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
    echo "Linux extension differs from the pinned m11 release output" >&2
    echo "expected: $expected_output_sha" >&2
    echo "actual:   $actual_output_sha" >&2
    exit 3
fi
mv -f -- "$build_output" "$output"
trap - EXIT

echo "$output"
