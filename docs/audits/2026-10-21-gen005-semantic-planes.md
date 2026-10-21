---
title: GEN-005 semantic-plane implementation and acceptance evidence
status: Current
document-kind: evidence
scope: Dated source, runtime, platform, deterministic generation, native fixture and rendered evidence for issue 192
canonical-for: []
last-reviewed: 2026-10-21
related-documents: [../systems/procedural-semantic-planes.md, ../operations/semantic-depth-authoring.md, ../operations/local-build-and-validation.md]
---

# GEN-005 semantic-plane implementation and acceptance evidence

## Source and recovery boundary

Implementation started at `bc6af48d14f5da74db9548043ba5a6ac2a57477a` (main at intake
with GEN-003, GEN-004 and player playground #189 integrated). Work is isolated on
`feat/gen005-semantic-planes`. Relevant unrelated open Water/presentation/map
work remains separate. The implementation PR records recoverable checkpoints.

The first published implementation checkpoint is
`3070f97a8172ff7be8950520dcf1ac09e1a7d04c` in
[PR #197](https://github.com/techrote/cybersand/pull/197), with Git tree
`20d9b2e4b6c09287265f3ea67b4eba4d606febff`. The original local checkpoint
`0be15ab462a3ddb54033551fe7abb9f94eb8b44a` has the same tree; this establishes
identical file contents, not identical commit ancestry.

The [canonical contract](../systems/procedural-semantic-planes.md),
[ADR-014](../decisions/ADR-014-semantic-plane-admission.md) and
[authoring guide](../operations/semantic-depth-authoring.md) distinguish source
behavior from executed acceptance. Two existing depth routes and native material
kernels are retained. No persistent streaming or player-edit rebasing is claimed.

## Gate ledger

The native and Godot controls below retain the initial implementation evidence for source
`3070f97a8172ff7be8950520dcf1ac09e1a7d04c` and Linux runtime SHA-256
`1d6df5e188da2ad1d0de759784cadba6298a1cb0d404aa6f642548d0782cd0c4`.
They do not certify the later compatibility correction. The documentation row
records the refreshed publication preflight against the restored benchmark fixtures.
Current publication is recorded separately below; final-head acceptance remains
conditional on the required successful checks recorded in the linked receipt.

| Gate | State at this checkpoint |
|---|---|
| Native four-plane deterministic and rejection tests | Linux optimized: 217,773 assertions, zero failures, including actors and shared typed masks. |
| ASan/UBSan semantic-plane tests | Same 217,773 assertions, zero failures in 30.890 s; local leak detection disabled because LeakSanitizer is incompatible with this ptrace environment. |
| Native adapter whole/tiled examples and immutable copies | Source-built Linux extension: 606 assertions, zero failures; all five sections completed, including retained workbench revision compatibility. |
| Four-World host lifecycle, bounded events and native chemistry | Source-built Linux extension: 1,108 assertions, zero failures; all six sections completed. Base depth regression: 83 checks passed. |
| Actual example native fixtures | 1,391 assertions, zero failures, all 40 fixture IDs verified across both recipes. |
| Actual composited/per-plane captures and pixel controls | Actual Xvfb/Mesa OpenGL pixel oracle: 104 assertions, zero failures, both examples complete. Twenty-two original local captures were completed. The fresh corrected-runtime package passed separately and supersedes their image hashes, as recorded below. |
| Canonical docs, historical M11 and RAG | Refreshed documentation, materialized runtime provenance and M11 checks passed: 101 docs, all 18 runtime files, 18 historical records and 28 source hashes. The original frozen 32-query fixture is unchanged; all 32 frozen and all 105 supplemental challenge queries hit their canonical target within five results. |
| Matching Linux/Windows native runtime publication | First attempt failed the retained Linux C++ runtime floor; Windows execution passed. Corrected-source publication subsequently passed; see the current publication ledger below. |
| Exact-head Documentation, Native, Linux/Windows GDExtension and scoped apparatus | Required successful results on the final PR head are tracked in the [acceptance receipt](https://github.com/techrote/cybersand/pull/197#issuecomment-6326437084) and [PR Checks](https://github.com/techrote/cybersand/pull/197/checks). |

The launcher also passed 43 assertions and the direct semantic-depth argument/return regression. Publisher guard tests passed 19 adversarial cases. These local controls are development feedback until the platform and exact-head gates pass. The [acceptance receipt](https://github.com/techrote/cybersand/pull/197#issuecomment-6326437084) binds the accepted final source, platform scope, merge and issue disposition.

## Retained publication failure and compatibility correction

[Publication run 39665646472](https://github.com/techrote/cybersand/actions/runs/39665646472)
built source `3070f97a8172ff7be8950520dcf1ac09e1a7d04c`. The Linux runtime
built successfully, but its ABI check rejected `GLIBCXX_3.4.31`; the existing
maximum remains `GLIBCXX_3.4.30`. Linux Godot execution did not start and the
publisher correctly withheld both runtime files. The Windows cross-build and
actual Windows execution of the 14 focused cases passed independently; they do
not turn this failed publication into accepted platform evidence.

Disassembly identified three new C-string assignments in `generation_planes.cpp`
as the only callers of `std::string::_M_replace_cold`, introduced by the pinned
GCC 13 optimization. The correction appends into known-empty strings, clearing
the reserved error buffer first in the catch-all path. Compiler/dependency pins,
the ABI floor, publication guards and acceptance thresholds are unchanged. An
original-object control reproduced the newer symbol; the corrected-object
control removed it. The corrected publisher subsequently passed the unchanged Linux ABI floor and
actual execution on both target operating systems, as recorded below.

## Current publication and final acceptance

The compatibility correction is published as source
`720e51e2b6bdaa1fdf20a06d732892fdbeb736fe`, tree
`8867a7638dc542c83087a5f67c5f7d2a1e3213d0`. Recovered local checkpoint
`a74f64f4f27c9a56573d25e8b29e6b58dfa93139` has the same tree. The correction
changes the three string operations described above; source matching remains
mandatory for both runtime binaries.

| Publication or acceptance step | Current evidence |
|---|---|
| Corrected Linux/Windows publisher | [Run 39674901695](https://github.com/techrote/cybersand/actions/runs/39674901695) passed all four jobs for corrected source `720e51e2b6bdaa1fdf20a06d732892fdbeb736fe`. Linux and Windows each passed import and all 14 scoped cases with zero skips or diagnostic errors. |
| Runtime/provenance publication commit | [4925e4349fa221507a754c091887fbc3044ef63a](https://github.com/techrote/cybersand/commit/4925e4349fa221507a754c091887fbc3044ef63a), tree `9dd175d4dc3feb6f8ca223d9b5fabe92d8a232a8`, appends only the four Linux/Windows runtime/provenance paths to built source `720e51e2b6bdaa1fdf20a06d732892fdbeb736fe`. |
| Corrected-runtime capture package | Passed on runtime publication checkout `4925e4349fa221507a754c091887fbc3044ef63a`: 104 graphical assertions, zero failures, both examples complete, 22 PNGs with verified hashes/dimensions and exact runtime/recipe binding. [Capture manifest](../images/semantic-depth/capture-manifest.json) SHA-256: `233f7a6fbfc531ed1e613874cb2716e65e17f5ba67c2462f2b872b0321eb5520`. |
| Final-head documentation/provenance | Required successful result after evidence publication; source and outcome tracked in [PR Checks](https://github.com/techrote/cybersand/pull/197/checks) and the [acceptance receipt](https://github.com/techrote/cybersand/pull/197#issuecomment-6326437084). |
| Final-head Native C++ | Required successful ready-for-review execution; source and outcome tracked in the [acceptance receipt](https://github.com/techrote/cybersand/pull/197#issuecomment-6326437084). |
| Final-head Linux and Windows Godot | Both required successful results are tracked in the [acceptance receipt](https://github.com/techrote/cybersand/pull/197#issuecomment-6326437084); Linux owns actual graphical tests and Windows owns applicable headless tests. |
| Final-head scoped Water apparatus | Required successful applicable execution; source and outcome tracked in the [acceptance receipt](https://github.com/techrote/cybersand/pull/197#issuecomment-6326437084). |
| Merge, landed-main verification and issue closure | Authorized only after all required acceptance checks succeed. The [acceptance receipt](https://github.com/techrote/cybersand/pull/197#issuecomment-6326437084) records the tested head, merged commit, landed-main verification and #192 disposition. |

The immutable target-OS reports are retained unchanged with their SHA-256
identities:

| Target OS | Published native runtime SHA-256 | Target-OS report SHA-256 |
|---|---|---|
| Linux | `f3dd574268d1f4cf01167faf7e9d0e1ccbdf4f0a219051fdbbb6e0a76b9ed326` | [Linux report](2026-10-21-gen005-linux-publication.json): `5949df0bd16aee05d23f5cdf885c4d2f21a90c7626321f20d301241c2c00310b` |
| Windows | `83967708c71936a1f51c07be2e509497a1e2355f9ae5c1b099782d6cd25f97eb` | [Windows report](2026-10-21-gen005-windows-publication.json): `962dc7363c03f931cb1f57168a4899bf8d7f0a5428a097dd97ece284256a7060` |

Both reports bind built source `720e51e2b6bdaa1fdf20a06d732892fdbeb736fe`,
the exact runtime, Godot/Rapier identities and all 15 import/case log hashes.
Downloaded runtime bytes, report hashes and every referenced log hash were
verified. Both operating systems report **606 adapter, 1,107 runtime and 1,390
example assertions, zero failures, with all 40 fixtures verified**. The initial
local runtime/example counts of 1,108/1,391 included one extra assertion that the
optional JSON report destination opened successfully. The publisher does not
request those optional files; all functional sections and fixture controls still
complete. These headless publisher cases qualify source-matched runtime
publication. Fresh graphical acceptance is recorded below; the full final-head
CI remains a separately required gate.

Fresh rendered acceptance used checkout
`4925e4349fa221507a754c091887fbc3044ef63a` with the published Linux runtime
built from `720e51e2b6bdaa1fdf20a06d732892fdbeb736fe`. The clean import
completed in 6.093 s; the actual-pixel oracle passed **104 assertions, zero
failures, both examples complete** in 68.472 s. Capture completed in 43.368 s
under X11, `gl_compatibility` and llvmpipe (LLVM 20.1.2, 256 bits).

The final package contains 20 images at 1024 × 1024 and two guide images at
1440 × 1000. Every PNG hash and dimension, both recipe hashes and both complete
example receipts were verified. Each example contains 20 fixtures and advances
240 native ticks, recording 544 scheduled applications, 9,664 fixture cell writes
and 448 cleanup cell writes. All 300 checked source/runtime input hashes stayed
unchanged in both the repository and the isolated render copy. Representative
visual inspection passed; this is not owner aesthetic approval or a guarantee
of byte-identical pixels across render runs. Compact timing, log-hash, renderer,
image-dimension and source-binding receipts are retained in the
[machine-readable evidence](2026-10-21-gen005-evidence.json).

The first restricted import attempt encountered denied local TCP sockets.
Strict log validation rejected that attempt despite its zero process exit;
no rendering pass was admitted. Repeating the same pinned workflow with approved
local-execution escalation produced clean import, graphical and capture logs.
The expected unsupported-VSync warning remains qualified. This is Linux software
OpenGL evidence; Windows graphical, browser and target-GPU performance scope
is unchanged.

Fresh optimized native execution on corrected tree
`8867a7638dc542c83087a5f67c5f7d2a1e3213d0` passed **217,773 assertions with
zero failures**. Its executable SHA-256 is
`4678107f2fbcf9a41fa4f05b1afe0c14330d267fd4c04198e712602c4acd385e`;
`native/src/generation_planes.cpp` has SHA-256
`55bb115341df14f538e9b7e0cff9ad282309130bb4b021b1f73f6415ddd3d123`.
All 19 publication guard tests and the GitHub-hosted CI provider policy check
passed. With full historical Git objects and the pinned companion workspace
restored, M11 integrity passed all 18 retained records and 28 source hashes.
These fresh checks are distinct from the original local sanitizer/runtime results.
Final local preflight passed documentation (101 documents, 198 canonical claims,
2,150 links, 176 anchors and 32 frozen questions, zero errors or warnings),
`check_repository.py --require-materialized` for all 18 runtime files, M11,
`git lfs fsck` and whitespace validation. These local passes retain their own
scope; final-head hosted provenance and implementation CI remain required.

Acceptance is contingent on successful execution of every applicable required
check against the final PR head. The external acceptance receipt binds that head
and the resulting merge commit; this source-controlled audit records the
requirements without embedding a self-referential commit identity.

The publisher refuses a changed feature-branch tip and only appends the validated
runtime/provenance commit. Evidence/documentation publication follows that
commit; normal acceptance must then run on the resulting final PR head.
The [machine-readable evidence](2026-10-21-gen005-evidence.json) retains the
initial failed attempt, corrected source identity and externally tracked final
gate requirements.
Draft workflow skips, a Windows cross-build, or local-only passes do not close
[#192](https://github.com/techrote/cybersand/issues/192).

## Review corrections and evidence boundaries

Review found and corrected omitted projection endpoints granting link authority,
the ordinary chunk metadata serial after semantic revision support, an unchecked
packed run-array allocation, and the publisher artifact prefix. Focused
rejection and retained workbench tests cover those boundaries. The host validates
the complete replacement before changing any current World, fixture, link or
actor registration.

The frozen retrieval fixture was restored byte-for-byte to its 32-query baseline.
Three GEN-005 queries were added to the separate supplemental challenge set;
all prior 102 challenge records remain unchanged. Local results are 32/32 frozen
and 105/105 supplemental canonical hits within five results, with all three new
queries ranked first. These records preserve the historical baseline rather
than expanding its denominator.

The [machine-readable evidence](2026-10-21-gen005-evidence.json) records the
source, runtime, individual fixture observations, lifecycle accounting, controls
and retrieval measurements. The [capture gallery](../operations/semantic-depth-authoring.md#rendered-examples)
provides the composite, per-plane and annotated-image routes for the final
capture package. Current capture publication and hosted gate states are recorded
above; historical local results are not relabelled as corrected-source execution.

## Reproducible local controls

```sh
make -j2 build/test_generation_planes
./build/test_generation_planes
make -j2 build/test_generation_planes_sanitized
./build/test_generation_planes_sanitized
make worldgen-test
make worldgen-sanitize
python3 tools/ci/test_gen005_runtime_publication.py
python3 tools/ci/check_ci_provider_policy.py
python3 tools/ci/check_docs.py
python3 tools/ci/check_m11_consistency.py
python3 tools/ci/check_repository.py
```

Source-matched Godot cases: `test_worldgen_planes.gd`,
`test_semantic_planes_runtime.gd`, `test_semantic_planes_examples.gd` and
`test_semantic_depth_render.gd`.
The render case requires Xvfb/software OpenGL on this Linux host; it must not use
a headless skip. Retained generation, depth, Deepworks and player regressions
protect the integrated prerequisites. The normal hosted test discovery includes
the new cases and keeps errors/timeouts/skips distinct from passes.

## Actual fixture observations

The two example revisions tested locally are `a9ae4e7ecad92a14` (refinery) and
`94b7ebaa1329d946` (flooded cavern). Each completed 20 fixture IDs, 544 scheduled
applications, 9,664 source/drain cell writes and 448 cleanup writes, exactly
matching its declared finite programmes. Rear-only execution ran 220 ticks with
play, effects and background bytes and play actor tick unchanged. Subsequent
240 play/effects ticks left rear and background unchanged.

Eight native rear Water/Salt reactors started with zero Brine and reached
48–56 observed Brine cells. Brine was never a source/setup material. Water below
the reactor feeds grew from zero to 404–408 cells. Eight waterfall observations
grew from 112 to 516–530 downstream Water cells. Inactive-source and missing-Salt
controls qualify the mechanism. In the focused native counterfactuals, retiring
the Water source leaves zero Brine and zero downstream Water after 180 ticks;
removing Salt leaves zero Brine despite four Water feeds and observed transport.
A paired two-tick atmosphere control creates Steam from an empty nozzle; an
active drain removes four seeded Water cells while its retired counterpart
retains all four. Helper completion and exact per-fixture schedule counts qualify
the accounting; the 24 atmospheric example records are accounted by schedules
and cleanup rather than separate per-record material-effect observations. These are finite observation windows, not a
claim of eventual equilibrium or persistent streaming.

## Explicit qualifications

The semantic scene uses the existing synchronous depth owner. Actor proposals
are play-only and use the existing sampled actor session. It is not a new
non-play physics owner, an articulated-controller traversal qualification or
production asynchronous layer integration. Real four-plane material captures
and isolated native reaction checks do not establish browser execution or target
hardware performance. Linux and Windows execution require their own receipts.
