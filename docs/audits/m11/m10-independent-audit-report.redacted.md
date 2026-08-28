# Cyber Sand Engine m10 independent validation audit

Audit date: 2026-08-28 UTC
Audit type: validation of final immutable artifacts, not migration or remediation
Overall validation budget: 3,600 seconds
Measured validation duration: 1,113 seconds
Timed-out commands: 0

## Executive conclusion

The final m10 artifacts are byte-intact, internally coherent, and usable as a
drag-and-run Godot project on the tested Linux x86-64 environment. The expected
project opened at `cyber-sand-engine/godot/project.godot`; both native
extensions registered; Rapier2D initialized; the 1920×1080/F3 presentation
regression passed; and the main scene completed a 180-frame headless run with
no logged errors.

The complete delivered validation surface is **not all-green**. Two Godot test
scripts fail reproducibly:

1. `test_native_fire_presentation_regression.gd` contains stale collision-chunk
   header assertions for 64 chunks, while the delivered 64×64 partition of the
   1024×1024 world correctly produces 256 chunks.
2. `test_cell_world.gd` reproduces the already-documented fallback-GDScript
   wide-Water leveling failure.

LeakSanitizer is inconclusive because the hosted environment prevents it from
reading `/proc/.../task`. The same ASan+UBSan binary passes all 39 native tests
with leak detection disabled and strict UBSan halt behavior enabled. TSan also
passes all 39 tests.

No claim is made that the project is crash-free or regression-free outside the
tested scope. Windows runtime, real-GPU visual output, export workflows,
non-x86-64 CyberSand binaries, and exact GDExtension rebuilding were not
validated.

## Immutable artifacts

| Artifact | Size | Recomputed SHA-256 | Result |
|---|---:|---|---|
| `cyber-sand-engine-m10-workspace.zip` | 104,813,716 B | `921af0603ddd869a909fb8d8e1b5337cbaa1b87e79bcb285805b9b67b222014b` | Matches sidecar and prior report |
| `cyber-sand-engine-setup-cache-v1.zip` | 75,672,883 B | `010ce5bd4a641861522df5dad8a8e326325931a19f4527c839a0ab26876e5fe9` | Matches sidecar and prior report |
| `cyber-sand-engine-m10-archives.sha256` | 269 B | `713cf320eda4a933ebf923ca9709014a9623efec404dbfbce34cf08e45d511ae` | Final sidecar inspected |

Original archive size, mtime, inode, and SHA-256 values were rechecked after
testing and were unchanged. The original restored workspace remained clean at
commit `9b5856ba3c481f74bf9e86a76b99722272709e3b`.

## Clean restoration and environment

The main clean audit extraction used separate roots beneath:

`$AUDIT_ROOT/clean_restore/`

- Workspace root: `clean_restore/workspace/`
- Setup-cache root: `clean_restore/setup/`
- Restored project: `clean_restore/workspace/cyber-sand-engine/`
- Godot project: `clean_restore/workspace/cyber-sand-engine/godot/project.godot`
- Extracted cached editor: `tools/godot-4.7/Godot_v4.7-stable_linux.x86_64`

An additional pristine workspace-only extraction was tested without any
`setup-cache/` directory. Using an already-available compatible Godot
executable, its material/LUT test and 180-frame main-scene run both passed. This
establishes that runtime project paths do not depend on the setup-cache layout.

### Recorded toolchain

| Component | Audit value |
|---|---|
| Operating system | Ubuntu 24.04.3 LTS, Linux 6.18.35 |
| Architecture | x86_64 |
| CPU | Intel Xeon Platinum 8370C; 9 available virtual CPUs |
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Godot API | 4.7 |
| Rapier2D | 0.35.2 |
| GCC/G++ | 13.3.0 |
| GNU ld/binutils | 2.42 |
| GNU Make | 4.3 |
| glibc runtime | 2.39 |
| Git | 2.51.1 |
| Python | 3.12.13 |
| pip | 26.2.1 |
| Zip / UnZip | 3.0 / 6.00 |
| CMake, Ninja, Meson, SCons | Not installed |
| Rust/Cargo | Not installed |
| MinGW-w64 | Not installed |
| MSVC, MSBuild, Windows SDK | Not available on this Linux host |
| `godot-cpp` source/static libraries | Absent; exact original revision unpinned |
| Godot export templates | Absent |
| GPU/display interfaces | No `/dev/dri`; `vulkaninfo`, `glxinfo`, and `nvidia-smi` unavailable |

The CyberSand Linux GDExtension requires at least `GLIBC_2.38`,
`GLIBCXX_3.4.30`, and `CXXABI_1.3.9`; the bundled Rapier Linux binary requires
up to `GLIBC_2.34`. All required Linux shared libraries resolved on the audit
host.

## Findings

### Critical

No critical artifact corruption, credential exposure, path traversal,
unrecoverable restore failure, or demonstrated main-scene startup failure was
found.

### Important

1. **The complete Godot test set does not pass.**

   `test_native_fire_presentation_regression.gd` exits 3 on both the primary
   run and one exact reproduction. Its Fire lifetime and Wood-destruction
   assertions do not report failures; only these collision-header assertions
   fail:

   ```text
   ERROR: chunked hard-surface count is not 64
   ERROR: first chunk offset is malformed
   ERROR: final chunk offset does not match snapshot size
   ```

   Source inspection shows that the delivered C++ code uses 64×64 collision
   chunks over a 1024×1024 world, yielding 16×16 = 256 chunks. The independently
   passing material/LUT regression also explicitly expects 256. The evidence
   therefore identifies stale test expectations rather than a demonstrated Fire
   simulation failure, but the delivered regression is still red.

2. **The fallback GDScript Water regression remains red.**

   `test_cell_world.gd` exits 1 on both the primary run and one exact
   reproduction:

   ```text
   ERROR: wide Water fixture exceeded the two-pixel resting-height target (13..19)
   GDScript backtrace:
     _expect (res://tests/test_cell_world.gd:283)
     _test_wide_water_mound_levels_quickly (res://tests/test_cell_world.gd:178)
     _run (res://tests/test_cell_world.gd:21)
   ```

   This is disclosed in the project testing documentation as a known
   fallback-only failure. The preferred native Water conservation and leveling
   tests pass.

3. **The checksum sidecar is byte-correct but path-nonportable.**

   Its two records contain creator-absolute paths under
   `$WORKSPACE_ROOT/`. The values describe the final archives,
   not an earlier build, but `sha256sum -c` will fail after the three files are
   moved unless the hashes are checked explicitly or paths are adjusted.

4. **Restore/setup documentation has an optionality and layout gap.**

   The READMEs call the setup cache optional, but `restore.sh` always requires
   and validates it. A natural same-directory extraction followed by passing
   the same root twice fails because workspace ledger completeness sees the
   sibling `setup-cache/` as unmanifested. Extracting the archives into separate
   workspace/setup roots and passing those roots succeeds. The documentation
   does not provide a complete outer-ZIP verification, extraction, editor
   installation, launch sequence, workspace-only validator, or Windows
   PowerShell equivalent.

5. **Manifest validation is strong for bytes but weak for semantics.**

   `validate_manifest.py` proves JSON readability and complete per-file ledger
   hashing. It does not apply `manifest.schema.json` or verify declared item
   size/hash/path/origin/license/dependency/restore relationships. Independent
   cross-checking found the included binary hashes and sizes correct, but the
   validator's success message alone does not establish those semantic claims.

6. **The required cache-item schema is incomplete for the Godot bootstrap.**

   `cache-inventory.json` records the three-file bootstrap collectively and
   hashes only the global-class cache. It does not give every requested field
   for each bootstrap item: version, platform, origin, source type, license,
   path, size, required-by, portability, and restore instructions.

7. **Exact native rebuilding is not reproducible from m10.**

   This is candidly documented: the original exact `godot-cpp` commit and its
   static libraries are absent/unpinned. The preserved Linux and Windows
   binaries are runtime-usable, but an offline or bit-identical extension
   rebuild cannot be established.

8. **Linux drag-and-run support has an ABI floor not highlighted in the main
   checkpoint README.**

   The CyberSand extension's `GLIBC_2.38` requirement excludes older Linux
   distributions even if the cached Godot editor itself runs there.

9. **Opening the project changes Git status.**

   The pristine extracted repository is clean. A real headless editor
   startup/import creates the previously absent, untracked file
   `godot/tests/test_presentation_controls.gd.uid`. All other test-script UIDs
   are tracked. This does not block execution, but the documented editor-open
   workflow leaves the restored worktree dirty.

10. **Reproducibility documentation is incomplete.**

    No archive-creation script/procedure is included; restore scripts have no
    timeout or dependency preflight; and no successful setup-command log is
    supplied that reconstructs compilers or native SDKs. The checkpoint is a
    reproducible runtime snapshot, not a fully reproducible build environment.

### Minor

- The Rapier external-item record mixes scopes: `size_bytes=154437035` is the
  extracted addon tree, while its SHA-256 is the absent 48,701,845-byte source
  release ZIP. `checksum_scope` explains this and the full file ledger protects
  the tree, but generic consumers may assume size and hash describe one object.
- `checkpoint/logs/inventory.txt` reports the project payload excluding Git as
  158,496,720 bytes. The actual archived payload is 158,501,104 bytes, exactly
  4,384 bytes larger because of the subsequently included bootstrap files.
- External manifests retain creator-machine scratch paths. Upstream native
  binaries also contain non-sensitive build provenance such as CI/home/tmp
  paths. No secret was found in them.
- `docs/operations/testing-validation-and-replay.md` says 38 native tests in
  frontmatter but later text and the executable suite report 39.
- `docs/operations/troubleshooting.md` still describes R8/no Godot dirty-patch
  consumer, contradicting the current RG8 bridge.
- README fallback wording can be read too broadly: cellular simulation has a
  GDScript fallback, but the complete project still selects and requires
  Rapier2D; the migration runbook correctly says there is no Godot-physics
  runtime fallback.
- The Linux extension builder hard-codes `g++` and does not enforce the
  recorded compiler version or exact `godot-cpp` input.
- Compile output contained only benign LTO notices that two link-time jobs were
  serialized.

### Pass

- Both outer ZIPs pass CRC/integrity testing.
- Workspace ZIP: 667 entries, 457 files, no duplicate entry names, unsafe
  paths, symlinks, encryption, case-insensitive collisions, Windows reserved
  names, trailing-space/dot names, or legacy-path-length concern.
- Setup ZIP: 17 entries, 9 files, one `setup-cache/` top level, no project copy.
- The workspace contains one usable `cyber-sand-engine/` project folder plus a
  sibling `checkpoint/` metadata folder.
- The project exists at the documented
  `cyber-sand-engine/godot/project.godot` path.
- The setup cache is separate; the workspace contains no nested archive.
- No `.next`, partial, temporary, backup, cookie, credential, token, private
  key, or unrelated machine-cache file was detected.
- The portable Godot bootstrap contains exactly `.gdignore`,
  `extension_list.cfg`, and `global_script_class_cache.cfg`; all operational
  references are relative `res://` paths and all referenced files exist.
- Git HEAD/main, index, 196 tracked blobs, and working-tree bytes match baseline
  commit `9b5856ba3c481f74bf9e86a76b99722272709e3b`; no remote is configured.
- Workspace and setup ledgers are complete and hash-clean.
- Compatibility IDs match across archives.
- Nested official Godot ZIP passes CRC, matches SHA-256
  `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`,
  and reports the expected version.
- All four recorded generated Linux/Windows CyberSand/Rapier binary sizes and
  hashes match.
- Cross-archive exact-content duplicates: 0.
- Required Godot, Rapier, godot-cpp, and Sandspiel license/notice material is
  present. The lack of a public top-level Cyber Sand license is explicitly
  disclosed.
- The separated-root static restore script passes Git fsck, manifest ledgers,
  compatibility ID, nested Godot hash, and nested ZIP integrity.
- A workspace-only extraction passes runtime tests with a compatible external
  Godot executable.

## Complete validation results

### Native and toolchain

| Validation | Result | Evidence summary |
|---|---|---|
| C header compile-only | Pass | GCC C11 syntax check, exit 0 |
| Native C++ test compile-only | Pass | GCC 13.3/C++20, exit 0 |
| Shared native library build | Pass | Exit 0 |
| Normal native suite | Pass | 39/39 tests |
| ASan+UBSan build | Pass | Exit 0 |
| ASan+UBSan, LeakSan enabled | Inconclusive | Exit 1 before tests; hosted `/proc` restriction |
| ASan+UBSan strict, LeakSan disabled | Pass | 39/39; no sanitizer diagnostics |
| TSan build | Pass | Exit 0 |
| TSan suite | Pass | 39/39; no race diagnostic |
| Benchmark build/default | Pass, non-gating | 512² dense: 28.23 ms/tick |
| Documented 1024² dense benchmark | Pass, non-gating | 121.96 ms/tick |
| Documented 2048×1024 sparse, 4 workers | Pass, non-gating | 2.27 ms/tick |
| Windows DLL static architecture/import checks | Pass | Both are PE32+ x86-64; runtime not exercised |

The benchmark and profile figures are hosted-VM observations without acceptance
thresholds; they are not target-hardware performance claims.

### Godot pass/fail scripts

| Script | Result |
|---|---|
| `test_material_appearance_lut.gd` | Pass, exit 0; 81 IDs/42 flair classes, representative flair/HDR/contrast checks, 1920×1080, native hard-surface partition |
| `test_rapier_backend_preflight.gd` | Pass |
| `test_native_render_bridge_regression.gd` | Pass, exit 0; full/delta RG8 contract |
| `test_native_fire_presentation_regression.gd` | **Fail, reproducible**, exit 3; stale 64-chunk header assertions |
| `test_native_edge_contact_regression.gd` | Pass; max rectangle refresh 8.450 ms, no enforced performance ceiling |
| `test_presentation_controls.gd` | Pass; F3 hide/restore and 1920×1080 settings |
| `test_rapier_drop_in.gd` | Pass |
| `test_rapier_manual_step.gd` | Pass |
| `test_cell_world.gd` | **Fail, reproducible**, exit 1; documented fallback wide-Water fixture |

Godot script totals: **7 passed, 2 failed, 0 timed out**.

### Startup, shader, registration, and focused runtime

| Validation | Result |
|---|---|
| Full main scene, headless, 180 frames | Pass, exit 0, no logged error |
| Headless editor scan/import/start/stop | Pass, exit 0, no logged error |
| Extension registration | Pass; CyberSand and Rapier loaded |
| Global GDScript class scan | Pass during editor initialization |
| Rapier PhysicsServer selection | Pass; Rapier2D 0.35.2 |
| Material shader/LUT resource smoke | Pass in headless resource/full-scene scope |
| Native-world profile probe | Pass; 60 ticks, 5.778 ms/tick hosted observation |
| Fallback scheduler profile probe | Pass; serial 474.08, phased 383.51 ms/tick hosted observation |
| Workspace-only, no setup-cache directory | Pass for LUT and 180-frame scene |

Because no GPU/display device is exposed, these checks establish shader
resource parsing/loading and scene integration, not rendered-image correctness,
GPU compilation on target hardware, motion quality, or 1920×1080 framebuffer
output.

### Failed and inconclusive command evidence

#### Native Fire presentation regression

```text
timeout: 240 s
exit: 3 (same on one exact reproduction)
scene/script: res://tests/test_native_fire_presentation_regression.gd
configuration: Godot 4.7 headless, Rapier2D, isolated XDG state
failure: three hard-surface chunk header assertions
```

The Godot stderr contains GDScript backtraces to `_expect` at line 90 and
`_run` at lines 54–56. No native crash or hang occurred.

#### Fallback cell-world regression

```text
timeout: 1200 s
exit: 1 (same on one exact reproduction)
scene/script: res://tests/test_cell_world.gd
configuration: Godot 4.7 headless, Rapier2D, isolated XDG state
failure: wide Water resting height 13..19 exceeds two-pixel target
```

No native crash or hang occurred.

#### LeakSanitizer

```text
timeout: 900 s
exit: 1
configuration: ASAN_OPTIONS=detect_leaks=1:strict_string_checks=1
stderr: Can't open /proc/.../task for reading; LeakSanitizer fatal error
```

This is classified as hosted-environment inconclusive. It is not evidence of a
project leak. The same ASan+UBSan executable passes all tests with
`detect_leaks=0`.

#### Combined-root restore invocation

```text
exit: 1
failure: workspace ledger completeness reported setup-cache files as unmanifested
```

The supported separated-root invocation passes. This is a restore-procedure
layout/documentation issue, not artifact corruption.

## Skipped or unsupported scope

- Windows Godot runtime launch and shutdown
- Windows exports and matching export templates
- Linux/Windows GDExtension rebuild from source
- Non-x86-64 CyberSand runtime
- macOS, Android, iOS, and Web runtime/export validation
- Real-GPU shader compilation, GPU profiling, screenshots, golden-image tests,
  animation/motion inspection, and target-monitor 1920×1080 output
- Successful LeakSanitizer pass in this hosted environment
- Serialization/replay file compatibility and Rapier state save/load, which are
  documented as planned/absent

## Suitability assessment

### Drag-and-run workspace

**Suitable with qualifications.** On a compatible Linux x86-64 host with Godot
4.7 and glibc 2.38 or newer, the folder can be copied as a unit and opened at
`godot/project.godot`; this was validated from a clean extraction. The main
scene, Rapier, native extension, global classes, material LUT, presentation
controls, and headless editor startup work on the tested host.

The two red regression scripts, the untracked UID generated on editor open, the
Linux ABI floor, and absence of Windows runtime testing should remain visible
qualifications. No general crash-free claim is justified.

### Setup cache

**Useful and correctly separated, but intentionally narrow.** It contains the
exact licensed Linux x86-64 Godot 4.7 editor ZIP and verification metadata. It
is unnecessary for project execution when a compatible editor already exists,
as demonstrated by the workspace-only run. It is not a complete cross-platform
offline setup cache and contains neither Windows/macOS editors nor export
templates or native rebuild SDKs.
