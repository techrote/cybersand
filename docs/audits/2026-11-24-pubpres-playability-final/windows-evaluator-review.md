# Windows evaluator source and workflow review

**Draft / HOLD — source review, 2026-11-24.** Specialist B reviewed the new
`evaluator-windows` and `renderer-windows` integration in
`.github/workflows/pubpres-playability-final.yml`. Specialist C independently
reviewed the evaluator packer and launcher custody at `e0860da9`. Actual Windows
PowerShell 5.1 execution and graphical extracted-package results remain required.

## Source and dependency custody

The workflow obtains C and frozen D source separately, downloads their independent
native build receipts, and hydrates each source's retained Windows x64 Rapier.
The inherited `archive_source` skips every other platform binary/framework and
the retained native DLL; each fresh native DLL is installed only after source
closure, build driver, dependency, toolchain and artifact verification. All
current LFS pointers are in those binary paths. The ordinary evaluator's engine
ZIP name matches the output of the official pinned `download_engine.py` helper.
Canonical Windows checkout and archive rules preserve source hashes.

The dependency preparation helper delegates to the retained VC runtime stage,
which requires the exact official licence bytes, an installed release Visual
Studio redistributable, AMD64 PE identity and valid Microsoft Authenticode.
The optional EGL engine is restored through the original proof verifier and is
kept separately identifiable. The launcher clears inherited `CYBERSAND_*`
selectors before applying the declared run policy. Nothing in this review
establishes physical NVIDIA behavior or a gameplay improvement.

## Corrections made before hosted qualification

- The extracted evaluator test now opens and reopens the optional frozen donor
  through the actual shipped launcher. It requires the D source identity, a
  distinct persistent profile, unchanged run manifest and a fresh process ID.
- The mixed start's mistakenly selected material 1 was Wall. It now uses
  `CyberCellWorld.SAND`, which is 2 in both `godot/scripts/cell_world.gd` and
  `native/include/cybersand/material.hpp`. Its startup receipt records a cell
  from Main's already accepted native material image; the extracted test requires
  material 2 at the registered cell. This is a paused material witness, not
  credit for a completed physical step.
- The new launcher's local profile path is named `RunProfile`, leaving the
  PowerShell automatic `Profile` variable untouched in new code.
- Workflow upload exclusions were flagged to the integrator: the authoring
  qualifier's saved-start files must be retained as evidence even when private
  source copies and import caches are excluded.

## Local checks and their limits

All 14 evaluator Python admission/authoring/two-slot-oracle tests passed after
these changes. The revised owner observer parsed with actual official Godot
`4.7.stable.official.5b4e0cb0f`; `git diff --check` passed. No local PowerShell or
graphical execution is represented by these results. The workflow's actual
PowerShell 5.1 parser, launchers, Windows process ownership controls, native
authoring, Save, fresh-process reopen and collector remain separate gates.
