---
title: M11 private GitHub migration validation
status: Current
scope: Pre-push source identity, clean checkout, LFS, functional validation, build-path validation, and remaining platform gaps
keywords: [m11, GitHub migration, clean checkout, validation, Git LFS, CI]
related-documents: [README.md, ../../operations/github-development-and-release.md, ../../BUILD_ID.md]
last-reviewed: 2026-08-28
implementation-state: The Git migration preserves audited M11 source, passes the feasible native/Godot matrix from a clean checkout, and records archive/build-host limitations without converting them into passes.
---

# M11 private GitHub migration validation

## Identity and clean checkout

- Audited source commit: `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`.
- Annotated baseline tag: `m11-audited`, pointing to that exact commit.
- First GitHub-migration commit:
  `26c7de882a15ea9bcf1e5b80f91a6087210052ab`.
- M11 workspace archive SHA-256:
  `6faa9c9020bb926088f76013f38c246026dc8e62aab7d33c1a10a1d411577b8b`.
- A fresh local clone populated all 18 LFS runtime files, passed `git lfs
  fsck`, matched the migration commit, and remained clean after validation.
- All 28 source hashes recorded in `docs/BUILD_ID.md` still match.

## Pre-push validation

The timeout-bounded M11 runner executed against the clean clone with exact
Godot `4.7.stable.official.5b4e0cb0f`.

| Scope | Result |
|---|---|
| Native C header/C++ compile and all 39 behavioral tests | Pass |
| Shared library, ASan+UBSan with leak detection disabled, and TSan | Pass |
| Default, 1024² dense, and 2048×1024 sparse benchmarks | Pass, non-gating |
| Linux ABI floor and Windows PE32+/import structure | Pass |
| Fallback interactions/Water, LUT/flair, 1920×1080/F3 presentation | Pass |
| Native render bridge and immutable render-patch handoff | Pass |
| Fire, edge contact, Rapier preflight/drop-in/manual step | Pass |
| Native/scheduler profiles, 180-frame scene smoke, editor start/stop | Pass |
| Final clean working tree | Pass |
| LeakSanitizer enabled | Inconclusive: hosted `/proc`/ptrace limitation |

The combined runner initially reported its archive-manifest item failed because
the setup-cache directory itself was supplied where the script expects the
parent containing `setup-cache/`. The archive-only validator was then run with
the correct separated roots against a new M11 extraction and
`PYTHONDONTWRITEBYTECODE=1`; workspace/setup ledgers, semantic manifests, and
the compatibility identifier passed. No functional test was retried or hidden.

## Build-path result

The retained source archive, SCons wheel, static-library hashes, LLVM-MinGW
archive, and compiler locks were verified. A shortcut attempt that copied the
cached godot-cpp static libraries without generating `gen/include` failed at
the expected missing-header boundary, confirming that the documented
godot-cpp-first order is required. A subsequent full godot-cpp rebuild was
interrupted before completion, so a new bit-identical Linux/Windows extension
rebuild is **inconclusive** in this migration environment. The previously
audited M11 binaries remain hash-valid, and GitHub Actions performs fresh pinned
Linux and Windows x86_64 validation builds.

## Remaining gaps

- GitHub Actions results are pending the first private push.
- Windows Godot runtime execution was not available; PE/import checks are not a
  substitute.
- Interactive GPU visual quality and target-hardware profiling were not run.
- Exact export templates remain absent and unpinned; reproducible export CI is
  intentionally disabled.
- Public project licensing remains an owner decision before public or
  third-party distribution.
