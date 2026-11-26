#!/usr/bin/env bash
set -euo pipefail

# GCC may lower std::fmod(float, float) to the GLIBC_2.38 fmodf symbol when
# math errno semantics are enabled. That raises the extension's runtime floor
# above the GLIBC_2.34 floor already imposed by the vendored Rapier2D binary.
# Use this wrapper for both godot-cpp and the final Linux GDExtension.
real_cxx="${CYBERSAND_REAL_CXX:-/usr/bin/g++}"

if [[ "$real_cxx" == "$0" ]]; then
    echo "CYBERSAND_REAL_CXX must not point back to this wrapper" >&2
    exit 2
fi

if ! command -v "$real_cxx" >/dev/null 2>&1; then
    echo "Linux C++ compiler not found: $real_cxx" >&2
    exit 2
fi

exec "$real_cxx" -fno-math-errno "$@"
