#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-}"
godot_cpp_root="${GODOT_CPP_ROOT:-}"
scons_python="${SCONS_PYTHON:-python3}"
expected_revision="101ae38034304346a46ea9ea84ae156d3e860496"
expected_source_ledger_sha="8a2fb6cdcd174a749692da86716c7a1e008ee4216000b53374bcb89ba31e521b"
expected_scons="4.10.1"
expected_linux_cxx_fragment="13.3.0"
expected_linux_ld_fragment="2.42"
expected_llvm_fragment="23.1.0"
jobs="${SCONS_JOBS:-1}"

usage() {
    cat >&2 <<'EOF'
Usage: tools/build_pinned_godot_cpp.sh linux|windows

Required environment:
  GODOT_CPP_ROOT  Extracted pinned godot-cpp source
  SCONS_PYTHON    Python from the offline SCons 4.10.1 venv (default: python3)

Windows additionally requires LLVM_MINGW_ROOT. Linux prepends the tracked
portable `g++` wrapper to PATH. Set CYBERSAND_DRY_RUN=1 to validate and print
the SCons invocation without compiling.
EOF
}

if [[ "$target" != "linux" && "$target" != "windows" ]]; then
    usage
    exit 2
fi
if [[ -z "$godot_cpp_root" || ! -f "$godot_cpp_root/SConstruct" ]]; then
    echo "GODOT_CPP_ROOT must point to the extracted pinned godot-cpp source" >&2
    exit 2
fi
if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo "SCONS_JOBS must be a positive integer" >&2
    exit 2
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

if ! "$scons_python" -m SCons --version >/dev/null 2>&1; then
    echo "SCons is unavailable through SCONS_PYTHON=$scons_python" >&2
    exit 2
fi
scons_version="$("$scons_python" -c 'import SCons; print(SCons.__version__)')"
if [[ "$scons_version" != "$expected_scons" ]]; then
    echo "SCons version mismatch: expected $expected_scons, got $scons_version" >&2
    exit 3
fi

common=(
    "$scons_python" -m SCons -C "$godot_cpp_root"
    "platform=$target" "arch=x86_64" "target=template_debug"
    "api_version=4.7" "debug_symbols=no" "-j$jobs"
)

if [[ "$target" == "linux" ]]; then
    linux_cxx="$project_root/tools/toolchains/g++"
    real_linux_cxx="${CYBERSAND_REAL_CXX:-${LINUX_CXX:-/usr/bin/g++}}"
    linux_ld="${LINUX_LD:-ld}"
    linux_cxx_version="$(CYBERSAND_REAL_CXX="$real_linux_cxx" "$linux_cxx" --version | head -n 1)"
    linux_ld_version="$("$linux_ld" --version | head -n 1)"
    if [[ "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
        if [[ "$linux_cxx_version" != *"$expected_linux_cxx_fragment"* ]]; then
            echo "Linux compiler mismatch: expected GCC $expected_linux_cxx_fragment" >&2
            echo "actual: $linux_cxx_version" >&2
            exit 3
        fi
        if [[ "$linux_ld_version" != *"$expected_linux_ld_fragment"* ]]; then
            echo "Linux linker mismatch: expected GNU ld $expected_linux_ld_fragment" >&2
            echo "actual: $linux_ld_version" >&2
            exit 3
        fi
    fi
    command=("${common[@]}")
    expected_output="$godot_cpp_root/bin/libgodot-cpp.linux.template_debug.x86_64.a"
    expected_output_sha="b99b8868348f0018b9cdbbb186c10dabad13610e537945290e91b69040c7e5e0"
else
    llvm_mingw_root="${LLVM_MINGW_ROOT:-}"
    windows_cxx="$llvm_mingw_root/bin/x86_64-w64-mingw32-g++"
    if [[ -z "$llvm_mingw_root" || ! -x "$windows_cxx" ]]; then
        echo "LLVM_MINGW_ROOT must point to the extracted LLVM-MinGW 20260826 toolchain" >&2
        exit 2
    fi
    windows_cxx_version="$("$windows_cxx" --version | head -n 1)"
    if [[ "$windows_cxx_version" != *"$expected_llvm_fragment"* && "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
        echo "LLVM-MinGW compiler mismatch: expected LLVM $expected_llvm_fragment" >&2
        echo "actual: $windows_cxx_version" >&2
        exit 3
    fi
    # LLVM-MinGW supplies g++/gcc aliases. The non-LLVM SCons branch avoids
    # godot-cpp's legacy explicit -lstdc++ addition while still invoking Clang.
    command=("${common[@]}" "use_mingw=yes" "use_llvm=no" "mingw_prefix=$llvm_mingw_root")
    expected_output="$godot_cpp_root/bin/libgodot-cpp.windows.template_debug.x86_64.a"
    expected_output_sha="db7a8c71f32ba9168b380d6a2599352bb2182178797745dd93956e5294638b09"
fi

printf 'Pinned godot-cpp %s build command:' "$target"
printf ' %q' "${command[@]}"
printf '\n'
if [[ "${CYBERSAND_DRY_RUN:-0}" == "1" ]]; then
    exit 0
fi
if [[ "$target" == "linux" ]]; then
    env LC_ALL=C TZ=UTC SOURCE_DATE_EPOCH=0 \
        PATH="$project_root/tools/toolchains:$PATH" \
        CYBERSAND_REAL_CXX="$real_linux_cxx" \
        "${command[@]}"
else
    env LC_ALL=C TZ=UTC SOURCE_DATE_EPOCH=0 "${command[@]}"
fi

if [[ ! -f "$expected_output" ]]; then
    echo "Expected godot-cpp build product is absent: $expected_output" >&2
    exit 3
fi
actual_output_sha="$(sha256sum "$expected_output" | awk '{print $1}')"
if [[ "$actual_output_sha" != "$expected_output_sha" && "${CYBERSAND_ALLOW_TOOLCHAIN_DRIFT:-0}" != "1" ]]; then
    echo "godot-cpp build product differs from the pinned m11 release artifact" >&2
    echo "expected: $expected_output_sha" >&2
    echo "actual:   $actual_output_sha" >&2
    exit 3
fi
echo "$expected_output"
