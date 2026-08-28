#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
extension="$project_root/godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
rapier="$project_root/godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"

for file in "$extension" "$rapier"; do
    if [[ ! -f "$file" ]]; then
        echo "Required Linux runtime library is missing: $file" >&2
        exit 2
    fi
done
if ! command -v objdump >/dev/null 2>&1; then
    echo "objdump is required to validate ELF symbol versions" >&2
    exit 2
fi

if objdump -T "$extension" | grep -Eq 'GLIBC_2\.38.*[[:space:]]fmodf([[:space:]]|$)'; then
    echo "CyberSand extension imports fmodf@GLIBC_2.38; rebuild godot-cpp and the extension through the portable compiler wrapper" >&2
    exit 1
fi

max_glibc() {
    objdump -T "$1" \
        | sed -nE 's/.*\(GLIBC_([0-9]+\.[0-9]+)\).*/\1/p' \
        | sort -V | tail -n 1
}

max_versioned_symbol() {
    local file="$1"
    local family="$2"
    objdump -T "$file" \
        | sed -nE "s/.*\\(${family}_([0-9]+(\\.[0-9]+)+)\\).*/\\1/p" \
        | sort -V | tail -n 1
}

extension_floor="$(max_glibc "$extension")"
rapier_floor="$(max_glibc "$rapier")"
bundle_floor="$(printf '%s\n%s\n' "$extension_floor" "$rapier_floor" | sort -V | tail -n 1)"
if [[ "$bundle_floor" != "2.34" ]]; then
    echo "Unexpected Linux bundle GLIBC floor: $bundle_floor (expected 2.34)" >&2
    echo "CyberSand extension: $extension_floor; Rapier2D: $rapier_floor" >&2
    exit 1
fi
extension_glibcxx="$(max_versioned_symbol "$extension" GLIBCXX)"
extension_cxxabi="$(max_versioned_symbol "$extension" CXXABI)"
if [[ "$extension_glibcxx" != "3.4.30" ]]; then
    echo "Unexpected CyberSand GLIBCXX requirement: $extension_glibcxx (expected 3.4.30)" >&2
    exit 1
fi
if [[ "$extension_cxxabi" != "1.3.9" ]]; then
    echo "Unexpected CyberSand CXXABI requirement: $extension_cxxabi (expected 1.3.9)" >&2
    exit 1
fi

echo "Linux runtime floor passed: GLIBC_$bundle_floor bundle (CyberSand GLIBC_$extension_floor, GLIBCXX_$extension_glibcxx, CXXABI_$extension_cxxabi; Rapier2D GLIBC_$rapier_floor)"
