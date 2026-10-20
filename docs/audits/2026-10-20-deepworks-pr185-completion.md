---
title: Deepworks PR 185 completion and reaction evidence correction
status: Current
document-kind: audit
scope: Correction of false-positive reaction evidence, rear Stone transport and focused UI input in PR 185; source-matched local and hosted acceptance
canonical-for: []
last-reviewed: 2026-10-20
related-documents: [2026-10-20-deepworks-exhibition.md, ../operations/deepworks-exhibition.md, ../operations/local-build-and-validation.md, ../reference/validation-evidence.md]
---

# Deepworks PR 185 completion

## Inspected authority and preserved failure

The owner requested completion of [PR #185](https://github.com/techrote/cybersand/pull/185).
The initial public head was `7590316e01f0b6efbcc11598fc454656f38f8558`, tree
`09089e708ded9576869b83b467fcf239f269905c`, based on main
`fc015a77d3b851fef4ea7734923bcdb3762a19a5`. There were no review threads.
An isolated checkout at `/workspace/scratch/0e6965f1b503/cybersand-pr185`
preserved existing work and materialized all eighteen retained runtime files.

The initial head passed [Documentation/provenance](https://github.com/techrote/cybersand/actions/runs/39352428591)
and [Native C++ validation](https://github.com/techrote/cybersand/actions/runs/39352428486).
[GDExtension/Godot run 39352428502](https://github.com/techrote/cybersand/actions/runs/39352428502)
failed Linux shard 2 and actual Windows headless regression. Both logs identify
the same untyped conditional-array assignment in
`test_deepworks_reactions.gd::_check_flow()`. The helper aborted before four
transport assertions in each A1 plane. Its caller nevertheless marked both
exhibits verified because the assertion failure counter had not changed.
The shared CI harness correctly rejected the script diagnostics despite exit 0.

**The earlier native-reaction pass is invalidated.** Its retained local log
also contains those two script errors. SHA-256
`4ce1c2d6aa180a90242978b46a36d147636772159e87eb0cf5bb19e3adbf0af6`
matches the original evidence manifest. The old 626 simulation assertions
(627 with report writing) omitted eight required checks. The original
[manifest](2026-10-20-deepworks-exhibition-evidence.json), observations, hashes
and image files remain unchanged as historical evidence; their reaction-pass
label is superseded by this correction. Independently completed visual,
dimension and other scene checks retain their original source/platform scope.

A fresh local reproduction on the initial public head reproduced the same
two script errors, exit 0 and 627-assertion summary in 28.595 seconds. Its A1
rear Stone observation contained **zero Stone cells below y143**, confirming
that the missing assertion concealed an actual apparatus failure.

## Corrections and independent review

The A1 rear Stone feed was above a continuous shelf. Stone's native kernel does
not make it flow sideways off that shelf. The feed now occupies x170–172, the
open chute between the grating ending at x168 and the Gabion beginning at x175.
Its material, timing, finite supply and original below-y143 transport oracle
remain intact. No material kernel or native ABI changed.

The reaction test constructs its typed material array explicitly. Every helper
returns a completion receipt, and each exhibit must execute mechanism checks
before it can be marked verified. Final accounting requires all 32 distinct
expected district/plane identities to have completed and passed. The evidence
report records completion, mechanism assertion counts and the verified total.
The shared CI diagnostic gate remains unchanged.

Independent source review found no blocker in the shared depth dimensions,
guard/weather bounds, camera transforms, generation rejection or retained
Strata defaults. A second review found that globally polled arrow keys could
pan the map while a focused brush slider consumed them. The focused UI repair
preserves keyboard adjustment and releases world input at that boundary;
controller regression execution must prove camera stability and fresh-press
rearming. This is separate from the reaction correction.

## Validation and source identity

Local validation uses Linux x86_64, pinned Godot
`4.7.stable.official.5b4e0cb0f`, accepted MAT-002 native libraries and Rapier
0.35.2. The editor archive SHA-256 is
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
Native worlds retain one worker each. Test execution scans complete logs for
engine/script errors as well as checking exit status and explicit result counts.

The [completion evidence](2026-10-20-deepworks-pr185-completion-evidence.json)
binds the starting public head plus four changed executable hashes, complete
commands, 180-second per-test budgets, runtime identities and result records.
The corrected recipe SHA-256 is
`828f5174b41aa5fa3ed693dae9bb463f24c49d8ce18b506af7573152afd83caa`.

| Check | Observed outcome |
|---|---|
| Hardened reaction test, old Stone feed | Correct rejection: exit 1, 732 assertions including report, two failures, 31/32 verified; zero Stone below y143 |
| Hardened reaction test, repaired Stone feed | Passed: 731 simulation assertions plus one report-write check, zero failures, all 32 verified; 360 ticks per dynamic plane in 48.515 seconds |
| Scratch helper returns true without any checks | Correct rejection: exit 1, 728 assertions, two failures, 31/32 verified, no script error needed |
| Scratch helper reproduces the original array error | Correct rejection: exit 1, 728 assertions, three failures, 31/32 verified, deliberate script error retained |
| Focused UI regression against original controller | Five failures reproduced across 206 assertions |
| Final controller regression with additional middle-drag checks | Passed: 208 assertions, zero failures; keyboard slider adjustment retained |
| Full map, materials, passages and bounded programme | Passed: 304 assertions, zero failures |
| Feature launcher and direct Deepworks argument/return | Passed: 35 launcher assertions plus direct-launch/return regression |
| Actual full-map rendering, HUD, all rear/far districts and atmospheric pulses | Passed: 173 checks, zero failures/artifact errors; 126.862 seconds in-test, 130.559 seconds including process launch/exit |
| Documentation, materialized runtime provenance and historical M11 | Passed; 18 runtime payloads, 18 M11 records and 28 historical source hashes |
| Git LFS and whitespace | `git lfs fsck` and `git diff --check` passed |
| Retrieval | Frozen 32/32 and supplementary 79/79 canonical top-five; 21/32 and 62/79 top-one respectively |

The repaired classifier produced 90 Stone cells below y143 and a final mean
Stone height of y164.697. Its original material and transport threshold remain
unchanged. All positive logs are free of engine/script errors. The
two scratch mutations override one helper while retaining the complete map;
their exact source is embedded in the evidence record. They are deliberately
rejected controls, separate from positive execution.

Graphical execution uses an isolated Xvfb display and Mesa llvmpipe. The initial
sandbox attempt could not create X11 listening sockets and ran no Godot test;
the scoped local-rendering retry passed. The expected unsupported-V-Sync warning
is distinct from engine/script errors. The actual overview and HUD images were
visually inspected: all sixteen districts are visible and the controls leave
the map unobscured. Exact-head hosted acceptance remains a separate gate after
publication; the PR body records those run URLs and final disposition.

The initial documentation check in the new checkout lacked five companion
workspace inputs referenced by unchanged frozen retrieval questions. They were
restored directly from pinned workspace commit
`6a58311982941b75f46e22109a0829e5acb83c7e`, as used by the documentation workflow.
No source checker or frozen question was changed. The recovery record retains
each file's bytes and SHA-256 identity.

## Documentation and acceptance boundary

The exhibition guide and build guide describe the repaired apparatus and
completion checks; the handover, documentation index and validation ledger
route this correction. The original audit links here and explicitly rejects its
old reaction-pass label. The historical JSON and images are preserved, including
their original recipe identity. The paused architectural scene is unchanged
by moving an event source; post-tick historical images describe the old feed.

The native rules, dependency pins, four-plane ownership, rates, capacities,
material catalogue and scene extent remain unchanged. This work does not create
an actor session or extend Windows graphical, browser, hardware-GPU or target-PC
performance acceptance. Exact-head hosted checks remain required before merge;
the PR body records the final candidate and merge disposition.
