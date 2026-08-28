# Cyber Sand Engine m11 completion report

Date: 2026-08-28 UTC

## Result

Cyber Sand Engine m11 is complete. All ten findings classified as **Important**
in the m10 independent audit were remediated, and
`cyber-sand-engine-render-patch-race-fix-c644b23.patch` was applied exactly.
The final archives passed clean combined and workspace-only restoration tests.
The complete validation runner finished with 34 passed, 0 failed, 0 timed out,
1 inconclusive, and 0 skipped tests.

Source state:

- Branch: `m11/audit-remediation`
- m11 commit: `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`
- Race-fix parent commit: `c644b235fbcb5e085802918c0d6cebec118b6405`
- Supplied patch SHA-256:
  `f46101539bfcd86b017c01a738377d647da85894ca81f4a68dec35032ea6e28a`
- Supplied patch stable patch-id:
  `50aae8b3e567e9a27cf4e057b711d2b63ee1bd8b`
- Original and restored Git worktrees: clean
- Configured Git remotes: none

## Important finding remediation

| # | m10 finding | m11 resolution |
|---:|---|---|
| 1 | Fire presentation regression expected 64 collision chunks | Test now derives the 16×16 layout and verifies all 256 64×64 chunks over the 1024² world. |
| 2 | Fallback GDScript Water regression failed | Added bounded contiguous pressure look-ahead; the fallback suite now passes 9/9 and the documentation matches behavior. |
| 3 | Checksum sidecar used absolute paths | Sidecar records are basename-only, relocatable, strictly parsed, and protected from self-overwrite. |
| 4 | Restore/setup optionality and layout gap | Workspace and setup cache have separate roots; setup is optional; bounded Bash and PowerShell restore wrappers document and verify both paths. |
| 5 | Manifest validation was byte-only | JSON Schema, semantic item fields, paths, sizes, hashes, licenses, dependencies, notices, restore instructions, complete ledgers, and cross-archive compatibility are validated fail-closed. |
| 6 | Godot bootstrap inventory was incomplete | `.gdignore`, `extension_list.cfg`, and `global_script_class_cache.cfg` each have complete individual records. |
| 7 | Exact native rebuild was not reproducible | Pinned `godot-cpp` source/commit/tree ledger, SCons, Linux compiler/static library, LLVM-MinGW, Windows static library, and both rebuilt extensions are recorded and hash-verified. Builds use verified temporary outputs and atomic replacement. |
| 8 | Linux ABI floor was not prominent | Main documentation and executable checks cover bundle GLIBC 2.34, CyberSand GLIBCXX 3.4.30, and CXXABI 1.3.9. |
| 9 | Editor startup dirtied Git with a UID | `godot/tests/test_presentation_controls.gd.uid` is tracked and explicitly verified during restore. |
| 10 | Reproducibility procedures were incomplete | Added deterministic transactional archive creation, dependency preflight, explicit per-command/overall timeouts, portable restore tooling, archive tests, manifests, checksums, and successful setup/build logs. |

The render-patch race fix now publishes immutable snapshot-owned patch buffers,
validates payloads before Godot image operations, acknowledges only successful
uploads, and requests a full refresh after rejected data. This closes the
zero-byte `Image.create_from_data()` / `blit_rect()` lifetime race represented
by commit `c644b23`.

## Final artifacts

Compatibility identifier:
`cse-m11__setup-v2__godot-4.7.5b4e0cb0f__rapier2d-0.35.2__godotcpp-101ae380__gdapi-4.7`

| Artifact | Size (bytes) | SHA-256 |
|---|---:|---|
| `cyber-sand-engine-m11-workspace.zip` | 105,936,992 | `6faa9c9020bb926088f76013f38c246026dc8e62aab7d33c1a10a1d411577b8b` |
| `cyber-sand-engine-setup-cache-v2.zip` | 227,650,494 | `b3824928ac59215a62211c19f4c5bef08e3eb4c79ca4e7c3839ac2dc3a49082c` |
| `cyber-sand-engine-m11-archives.sha256` | 205 | `33a038a9262f1abcc0330b229b13d7af7c6bf75f7dca7120e476d043ffe8fac5` |
| `m11-archive-creation-result.json` | 950 | `6a91e5679d84e59f3c65eb93b5d92903862d22919650ce48fd82ea735269aa54` |

The workspace archive contains the usable top-level
`cyber-sand-engine/godot/project.godot` project and separate `checkpoint/`
metadata. It does not contain the setup cache. The setup-cache archive is
optional when exact Godot 4.7 and compatible native runtime components are
already installed.

## Restore proof

Two new clean destinations were used, without relying on the original project:

1. Combined offline restore from both final archives passed checksum, safe ZIP,
   schema, semantic, ledger, cross-link, Git integrity, exact editor-version,
   and native runtime preflight checks.
2. Workspace-only restore from the workspace archive plus an existing exact
   Godot 4.7 editor passed the same applicable checks.

The complete workspace ledger was also revalidated after each restore wrapper
finished, proving that its Git and Python checks do not mutate ledger-covered
metadata. No downloads were performed.

## Complete validation

Validation ran against the clean combined restored copy with explicit
per-command and overall timeouts.

- Result: `passed-with-inconclusive`
- Duration: 262.740 seconds
- Passed: 34
- Failed: 0
- Timed out: 0
- Inconclusive: 1
- Skipped: 0
- Godot: `4.7.stable.official.5b4e0cb0f`

Passed scope included native C/C++ compilation and tests, shared-library build,
ASan/UBSan with leak detection disabled, TSan, all three benchmarks, Linux ABI
floor, Windows PE32+ x86-64/import checks, m11 tooling and complete manifest
validation, fallback cell-world and Water behavior, material/LUT and
presentation checks, native render bridge and render-patch handoff regression,
Fire and edge-contact regressions, Rapier preflight/drop-in/manual-step,
native-world and scheduler profiles, 180-frame full-scene headless smoke, editor
startup/shutdown, and final Git cleanliness.

The sole inconclusive result was ASan/UBSan with LeakSanitizer enabled. It exited
1 with the hosted-environment marker `LeakSanitizer has encountered a fatal
error`. The same sanitized binary passed with leak detection disabled, and TSan
passed. This is reported as a limitation, not converted into a pass.

Windows runtime execution and PowerShell execution were not available on this
Linux host. PowerShell was statically reviewed, while the Windows DLL passed
PE/import validation. Interactive GPU visual quality was not evaluated by the
headless suite. These results establish the tested behavior only; they do not
claim that every future runtime workload is crash-free.
