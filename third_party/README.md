# Dependency locks and provenance

- `godot-runtime.lock.json` pins the exact audited Godot editor and records that
  export templates are absent and unpinned.
- `native-toolchain.lock.json` pins godot-cpp, SCons, LLVM-MinGW, host compiler
  packages, cached static libraries, release output hashes, and Linux ABI floor.
- `godot/third_party/rapier2d.lock.json` pins the vendored official Rapier2D
  v0.35.2 release asset and activation contract.
- `THIRD_PARTY_NOTICES.md` and add-on-local license files preserve attribution.

Downloaded archives and package caches are not source-controlled. Verify every
download before extraction. The private M11 setup-cache v2 remains an optional
offline source of the exact recorded inputs.
