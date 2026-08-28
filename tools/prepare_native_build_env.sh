#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage:
  tools/prepare_native_build_env.sh OUTPUT_DIR GODOT_CPP_ARCHIVE SCONS_WHEEL [LLVM_MINGW_ARCHIVE]

Creates an offline native-build environment from already downloaded, pinned
artifacts. It performs no network access and refuses to reuse OUTPUT_DIR.
EOF
}

if (( $# < 3 || $# > 4 )); then
    usage
    exit 2
fi

output_dir="$1"
godot_cpp_archive="$2"
scons_wheel="$3"
llvm_mingw_archive="${4:-}"

expected_godot_cpp_sha="f55d1cd5a2d528a9dc72fc54c1ef2b3d4dd90a0570dd8841d6766cbd4912dad8"
expected_scons_sha="bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126"
expected_llvm_mingw_sha="cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65"
expected_revision="101ae38034304346a46ea9ea84ae156d3e860496"

verify_file() {
    local path="$1"
    local expected="$2"
    local actual
    if [[ ! -f "$path" ]]; then
        echo "Required cached artifact is missing: $path" >&2
        exit 3
    fi
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "SHA-256 mismatch for $path" >&2
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        exit 3
    fi
}

if [[ -e "$output_dir" ]]; then
    echo "OUTPUT_DIR already exists; refusing to modify it: $output_dir" >&2
    exit 3
fi

verify_file "$godot_cpp_archive" "$expected_godot_cpp_sha"
verify_file "$scons_wheel" "$expected_scons_sha"
if [[ -n "$llvm_mingw_archive" ]]; then
    verify_file "$llvm_mingw_archive" "$expected_llvm_mingw_sha"
fi

mkdir -p "$output_dir"
tar -xzf "$godot_cpp_archive" -C "$output_dir"
godot_cpp_root="$output_dir/godot-cpp-$expected_revision"
if [[ ! -f "$godot_cpp_root/SConstruct" ]]; then
    echo "Pinned godot-cpp archive has an unexpected structure" >&2
    exit 3
fi
python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify_pinned_source_tree.py" \
    create "$godot_cpp_root"
printf '%s\n' "$expected_revision" > "$godot_cpp_root/.cybersand-source-revision"
printf '%s\n' "$expected_godot_cpp_sha" > "$godot_cpp_root/.cybersand-source-archive-sha256"

python3 -m venv "$output_dir/venv"
"$output_dir/venv/bin/python" -m pip install \
    --disable-pip-version-check --no-index --no-deps "$scons_wheel"

llvm_mingw_root=""
if [[ -n "$llvm_mingw_archive" ]]; then
    mkdir -p "$output_dir/llvm-mingw-20260826"
    tar -xJf "$llvm_mingw_archive" \
        -C "$output_dir/llvm-mingw-20260826" --strip-components=1
    llvm_mingw_root="$output_dir/llvm-mingw-20260826"
    if [[ ! -x "$llvm_mingw_root/bin/x86_64-w64-mingw32-g++" ]]; then
        echo "Pinned LLVM-MinGW archive has an unexpected structure" >&2
        exit 3
    fi
    # godot-cpp's MinGW SCons branch requests gcc-ar. LLVM-MinGW provides the
    # equivalent llvm-ar but no gcc-ar alias in this release.
    if [[ ! -e "$llvm_mingw_root/bin/x86_64-w64-mingw32-gcc-ar" ]]; then
        ln -s llvm-ar "$llvm_mingw_root/bin/x86_64-w64-mingw32-gcc-ar"
    fi
fi

cat <<EOF
Offline native build environment prepared.
GODOT_CPP_ROOT=$godot_cpp_root
SCONS_PYTHON=$output_dir/venv/bin/python
LLVM_MINGW_ROOT=$llvm_mingw_root
EOF
