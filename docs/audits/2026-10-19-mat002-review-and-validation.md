---
title: MAT-002 PR review and completed-test evidence
status: Current
document-kind: evidence
scope: Review corrections, meaningful native and rendered regressions, source-matched runtime publication and platform-scoped validation for PR 179
canonical-for: []
last-reviewed: 2026-10-19
related-documents: [2026-10-18-material-fidelity-pass-2.md, ../systems/building-material-catalogue.md, ../systems/material-appearance-and-rendering.md, ../reference/level-saves-and-replay.md, ../operations/testing-validation-and-replay.md, ../reference/validation-evidence.md]
---

# MAT-002 review and validation — 2026-10-19

This record follows the owner's request to review
[PR #179](https://github.com/techrote/cybersand/pull/179) and complete its tests.
It preserves the [original fidelity-pass audit](2026-10-18-material-fidelity-pass-2.md)
as historical evidence. The original audit's stale-runtime and failed-test claims
describe that earlier checkpoint, not all later commits on the branch.

## Inspected checkpoint and evidence boundaries

| Identity | Value |
|---|---|
| Reviewed PR head | `57595ac9fff1fad85e9aa9a85ba7f16e02ee329e` |
| Merge base / inspected main | `f2e34cf9b6fbaa5d9dedf9aa2cbc721a87472497` |
| Existing runtime source at intake | `d4c4492d3cc9f98f5d0982a9d0e1948f281b0de8` |
| Existing runtime build commit | `6057d32b180f6ccad542da60b9ed3367f226aa8c` |
| Existing retained Linux SHA-256 | `950d6b6163ce2ee503273b6767ceedae9b7a0a5fbbb26c23affb09d6189f6ab2` |
| Local corrected Linux SHA-256 | `19924b8b37c53d7c08e82c10d0a5e570afdbd1d34f7b9bd75873c8620bb926e1` |
| Published runtime commit | `8f841a291a1ceb7f1717fa961d04bc5964bff1e3` |
| Published Linux SHA-256 | `bf65f1e1a7576b1df5fe8dc93eee807f3297200c0b1c311a52d04167fae42cf3` |
| Published Windows SHA-256 | `aa38827014c193134ecf2986670f71c72609789fd0bedfee292ef276a2fbc3cc` |
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Local compiler / binding | GCC 13.3.0, GNU ld 2.42, SCons 4.10.1, godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` |
| Local rendered backend | Linux x86_64, Xvfb, OpenGL compatibility, Mesa 25.2.8 llvmpipe / LLVM 20.1.2 |

The intake branch was draft. Native, GDExtension and Water workflow runs were
skipped, and the draft Documentation run did not execute its source-sensitive
runtime gate. Those outcomes do not constitute completed implementation tests.
The earlier [runtime publisher](https://github.com/techrote/cybersand/actions/runs/39178688631)
did build the expanded catalogue and execute focused Linux cases. Its Windows
result was a cross-build, not Windows runtime execution.

Local rebuild inputs are recorded by SHA-256 for all 38 required native input
files and the pinned godot-cpp archive. The local copy is used only for testing;
retained binaries and provenance must come from a guarded fresh publication.
The reviewed implementation is committed as
[`6684017c96d1619fe853987f5098bff670b779c8`](https://github.com/techrote/cybersand/commit/6684017c96d1619fe853987f5098bff670b779c8),
tree `c8a8d180ec67108eee8bc7bf30822c24d0ed405a`. Its immediate child
[`e621348f4b4fde4d49763f4c1f320b56cbcc2a29`](https://github.com/techrote/cybersand/commit/e621348f4b4fde4d49763f4c1f320b56cbcc2a29)
installs only the temporary, guarded runtime publisher. Publication and subsequent
standalone CLI changes are tracked separately below.

## Review findings and corrections

| Finding | User-visible or validation consequence | Correction and regression |
|---|---|---|
| CYSD1 and native rectangle construction retained the old ID-80 ceiling | New building cells could be painted but could not survive level construction/import; selecting them also failed save metadata validation | Derive legal bounds from the catalogue and reject wide IDs before narrowing. Native snapshot tests preserve all 51 IDs, state bytes and signed temperatures. The new Godot integration runner checks construction, codec/native round trips and unchanged active worlds on rejection. |
| Diagnostic fill, fallback counts, MicroScenario identity and body-face stride retained old extents | New-ID fixtures were rejected, fallback counting indexed outside its array, evidence advertised 81 slots, and a 528-bin allocation was populated with an 81-slot face stride | Use 132-slot catalogue extents and four complete faces. Tests put distinct movable materials on N/E/S/W and check every bin independently. The 81-entry transport schema and 9×9 tool footprint remain intentional. |
| Actor hard-surface and tool-protection predicates stopped at ID 80 | Sampled actor queries ignored new walls and bounded digging could reach editable cells behind an uneditable new barrier | Extend the shared mirror predicates. Tests cover all 51 barriers, a positive dig control and existing read/write budgets. |
| Half-resolution emission sampled a block from the fragment centre | Single-cell firework emitters could miss their correct bloom texel | Anchor the 2×2 maximum at the covered source block. Real half-resolution pixel fixtures cover quadrants, parity and boundaries, with Spark and idle-firework controls. The old shader fails 11 negative controls. |
| Vapour history lacked a complete presentation lifecycle | Reset/replacement could leave ghosts; alternating viewport resize discarded history; a slow frame prolonged trails; disabled history could return | Initialize and resize both buffers together, invalidate history on the accepted world lifecycle, retain elapsed-time decay, reject out-of-view history and provide a persistent disable hook. Production-controller pixel fixtures cover reset, resize, pan, fallback and disable/re-enable. A full transport refresh alone is not a world reset. |
| Large building finish was nested inside repeatedly inlined shared flair calls | The software OpenGL shader compiler exhausted an 8 GiB limit before readback | Dispatch the building finish once per material-colour evaluation while retaining default/probed geometry. The full palette then renders and passes its pixel oracle on llvmpipe. |
| The common runner counted headless pixel-test skips as passes | Five graphical fixtures could satisfy the gate without making their framebuffer assertions | Auto-classify `test_*_render.gd`, provide an actual display/backend, and fail on skips, launch failures, timeouts or engine/script diagnostics even with exit zero. A new vapour fixture is also automatically included. |
| Pair regressions used weak probability, product and lifecycle controls | Swapped roles, untested byte values or ordinary lifetime transitions could hide a regression | Check all 256 probability rolls and both roles for each new rule; check the full 256×256 prefilter domain; refresh source state explicitly for execution fixtures; separately seed once for sleeping/busy and serial/phased comparisons, with real one/four-worker boundary contacts. |
| Standalone physics CLI accepted the new IDs but retained 81-entry sample arrays | Sample collection could overflow stack storage or return exit zero with corrupted/truncated accounting; narrowing also admitted wrapped invalid IDs | Validate signed wide arguments before narrowing and derive both sample arrays/output loops from the catalogue. Execute all 51 IDs in both fixture layers plus old/invalid controls, and independently parse counts, moments and centroids under normal and sanitized binaries. |

## Focused evidence before publication

- The new native CYSD1 probe fails against the reviewed source because material
  81 is accepted by the catalogue but rejected by snapshot construction.
- The new Godot integration runner against the old runtime/scripts records
  966 assertions, 315 repeated material-boundary failures and the fallback
  histogram indexing error. With corrected scripts and the freshly compiled
  Linux extension it passes **1,091 assertions, zero failures**.
- The final expanded native World suite passes **78 tests** with repository
  warning flags (`-std=c++20 -O0 -g3`), exit zero in 175.986 seconds. The same final
  test source passes **78 tests** under ASan, UBSan and LeakSanitizer, exit zero in
  159.947 seconds, with no sanitizer diagnostics. `ASAN_OPTIONS` is
  `detect_leaks=1:strict_string_checks=1`; `UBSAN_OPTIONS` is
  `halt_on_error=1:print_stacktrace=1`. The leak-enabled final run uses the
  process-inspection-capable execution environment. Test source SHA-256 is
  `9f309158db6103eb6675ce0a0ec33e619bd1d05e4be3c3ff0dc73a66710b46e2`.
- The complete material presentation pixel runner passes after the dispatch
  correction. Its rendered-output oracle checks invalid rows, all current ID
  slots, relative colour intent, static controls, camera anchoring, crossfade
  endpoints, growth blockers and the real emission footprint. The all-ID loop
  checks valid non-Empty/non-magenta output; it is not an independent
  expected-colour table or golden image for every catalogue entry.
- The final production vapour pipeline passes **26 actual-pixel assertions**;
  the real native/R8 owner-generation runner passes **23 assertions** for ordinary
  paints, transport resync, accepted/rejected reset and identical paused
  replacements. The initial production vapour negative control recorded five
  failures among twelve assertions.
- The regression-runner unit/integration suite passes **15 tests**, including
  actual child-process timeout, error-with-zero-exit, explicit skip, missing
  executable and continuation-after-failure controls.

## Completed full Linux suite

The final frozen implementation at `6684017c96d1619fe853987f5098bff670b779c8`
passes import plus **93 of 93 discovered regression cases**, each executed exactly
once, in **1,024.383 seconds (17 minutes, 4 seconds)**. This comprises **87 headless
cases** (including profiles and scene startup) and **six actual rendered-pixel
cases**. The completed report contains zero failed, skipped or timed-out cases,
zero engine/script errors and zero frozen-input changes. Ordinary case timeouts
were retained. The only warnings were the expected unsupported V-Sync warning
from the software display, once per graphical case.

| Selected final regression | Result |
|---|---|
| Building material integration | 1,091 assertions, zero failures using the rebuilt native library |
| MicroScenarios | 8,855 assertions, zero failures in 127.085 seconds, within the unchanged 180-second timeout |
| Material LUT | All 132 material ID slots, 256 palette/program rows and 50 flair classes |
| Material presentation | Actual-pixel oracle passed in 25.088 seconds |
| Production vapour pipeline | 26 actual-pixel assertions, zero failures |
| Render world generation | 23 assertions, zero failures with real native and fallback workers |
| Web worker parity | Passed in 21.234 seconds; this is the Godot-side parity test, not a fresh browser export |
| WEX-001 water-body baseline | Passed in 145.789 seconds, within the unchanged 180-second timeout |

All six graphical fixtures (Blacksite Nine, depth surface, material presentation,
production vapour, showcase backdrop and water presentation) submitted real
frames through the backend recorded above.

The local evidence directory is
`/tmp/cybersand-pr179-evidence/final-suite`. These paths identify the original
execution evidence; they are not a claim that transient local files are hosted
by this repository. `timings.json` contains all 94 execution records (import plus
93 cases), commands and durations. A separate `source-binding.json` verifies all
38 native build inputs against the immutable implementation's Git blobs, plus
406 direct Git-blob matches and 17 materialized LFS matches for frozen suite
inputs. It separately accounts for the rebuilt Linux library and 135 generated
import UID files. The binding SHA-256 is
`190b0da844712beeed942353d8e3dbfb83315e8ca6f97289ec8e72b68a8fc072`.

The final `evidence-manifest.json` inventories 105 evidence files and has SHA-256
`daa6f5650a8d5eb20c3d10510f5c471af1e26d18a8d5e3c9ed051fae5313d5a0`.
All 94 individual log hashes match the timing report. The wrapper hashed its
aggregate `runner.log` before appending the final JSON footer; the final evidence
inventory hashes the completed aggregate log. Raw execution evidence was
preserved unchanged. Retained pixel artifacts include the complete material
catalogue PNG and seeded, decayed and reset vapour EXRs.

## Completed standalone CLI regression

After the full Godot source was frozen, the additional standalone CLI correction
passed **154 of 154 executable invocations** normally in **6.072 seconds**, then
**154 of 154** under ASan, UBSan and LeakSanitizer in **5.690 seconds**, with zero
failures, errors or sanitizer diagnostics. Each run comprises 102 building-ID
cases (all 51 IDs in both fixture layers), four old-ID controls and 48 invalid-ID
cases. The normal and sanitized Make targets compile the actual bench executable;
the test oracle does not substitute a model implementation.

Sanitizer execution explicitly used
`ASAN_OPTIONS=detect_leaks=1:strict_string_checks=1` and
`UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1` in the process-inspection-capable
environment. Every child has a ten-second timeout; the hosted gate separately
has a five-minute build/run limit, `pipefail`, and always-retained evidence.
An independent review verified the fixture accounting and failure propagation.

| Bound identity | SHA-256 |
|---|---|
| Corrected CLI source | `1fa8061d7a3ec863be988aaf9a3838fb6245dd259cc9eb3e2d3abcb0737179ea` |
| Executable regression source | `14d019a7a5e655d312bbaf422e5f5f9298e2178210e159c7188c9474786d895c` |
| Normal executable | `c74fb6998b70bdcc3c66b84e924bdca3948118ac50a6346e657047e4997bb797` |
| Sanitized executable | `90d64e1a5d1da5b23a0d17cde7c481849d39659fab9861e72012010615bbd88a` |
| Normal result manifest | `e3b96212fee4b86d9e2950aa88f8656138515cfaad9c27b931fb1c02a7382d6b` |
| Sanitized result manifest | `f6da53501753f7e1b2456ea6b3b304ba48964d6201af9457aa6a6c2c97dd5898` |

Original local per-case JSONL, stderr, command and byte identities are retained
under `build/physics-cli-validation/{normal,sanitized}`; their compact inventory
is `/tmp/pr179-physics-cli-final-evidence.json`. The original red runs remain
separate. This additive bench/Makefile/Native-CI change leaves every GDExtension
source input and the already-tested native World test source unchanged.

## Commands and acceptance

Native World tests use `make build/tests` then `./build/tests` with a 15-minute
limit for each build/run. Sanitizers use the repository ASan/UBSan flags and
explicitly recorded leak-detection settings. The ordinary hosted Native workflow
also owns its existing broader native, soliding, generation and thread-safety
checks; a focused World pass does not replace them.

The Linux suite uses the pinned Godot executable and an isolated copy of the
source/runtime inputs:

```sh
LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 GALLIVM_PERF=nopt \
  xvfb-run -a -s '-screen 0 1920x1080x24 -nolisten tcp' \
  python3 tools/ci/run_godot_regressions.py --godot <pinned-godot> \
  --output <evidence-directory> --keep-going
```

`nopt` is the installed Mesa flag for disabling its LLVM optimization pass;
the actual shaders still execute and framebuffer pixels are asserted. Logic and
import are headless; six `*_render.gd` cases require the display. The planner
discovers 93 non-import cases, including both profile probes and scene startup.
Each case keeps its ordinary timeout, and the final report must be completed,
contain every assigned case and have no failed or skipped required cases.

Runtime publication builds Linux and Windows from one frozen implementation
parent, records byte and source identities, executes focused Linux cases and
validates the actual Windows DLL on a GitHub-hosted Windows runner. Publication
checks the source/branch lease, retains logs and reports, commits only the two
LFS runtimes and their manifests, and removes its temporary workflow. The
ordinary ready-for-review CI remains a separate final gate.

## Completed runtime publication and Windows execution

The guarded
[publication run 39183102017](https://github.com/techrote/cybersand/actions/runs/39183102017)
passed all four jobs on attempt 1: Linux build `117839855099`, Windows cross-build
`117839860316`, actual Windows execution `117843183910`, and publication
`117847290441`. It committed the two matching LFS runtimes and their manifests as
[`8f841a291a1ceb7f1717fa961d04bc5964bff1e3`](https://github.com/techrote/cybersand/commit/8f841a291a1ceb7f1717fa961d04bc5964bff1e3)
at 2026-10-19 01:30 UTC and removed its temporary workflow. The original source
commit, build commit, source-input hashes and execution scope remain recorded
in the manifests; no source identities were relabelled after building.

| Retained runtime | Actual-byte and execution evidence |
|---|---|
| Linux x86_64 | 2,132,928 bytes; SHA-256 `bf65f1e1a7576b1df5fe8dc93eee807f3297200c0b1c311a52d04167fae42cf3`. The hosted build passed 78 native World tests and import plus all six focused Godot cases with this exact library. Its source/build inputs and all 12 log hashes were independently verified after downloading the artifact. |
| Windows x86_64 | 2,619,904 bytes; SHA-256 `aa38827014c193134ecf2986670f71c72609789fd0bedfee292ef276a2fbc3cc`. This exact DLL passed import plus all 87 applicable headless cases on GitHub-hosted Windows Server 2022, Python 3.12.10 and the pinned Godot 4.7 executable. |

Windows execution completed in **1,036.562 seconds (17 minutes, 16.6 seconds)**.
All 88 records (import plus 87 cases) passed, each assigned case occurred exactly
once, and there were zero warnings, errors, skips or timeouts. The six graphical
cases were explicitly outside this lane's scope. Source checks verified all
249 tested files against the frozen source, all 37 Windows native inputs and all
88 individual log hashes. Selected Windows results include building integration
with 1,091 assertions, MicroScenarios with 8,855 assertions in 113.384 seconds,
owner generation with 23 assertions, and worker parity.

The Windows artifact `mat002-windows-execution-39183102017` has ID `12157009587`;
its ZIP SHA-256 is
`9d141cb33f806dee57be721b1d1a49b18d045ad61c441163de4dadd1af01db17`.
The contained `windows-execution.json` SHA-256 is
`2c6b461740efe9b6b56634b45514ef7c419b34dc4faeb72ce9d0e1245c99fd97`.
The Linux artifact `mat002-runtime-linux-39183102017` has ID `12157297862` and
ZIP SHA-256
`d8f8211e914a21ed65a7fa9763d1c153e9f23b32d9eaa064a1162a258121712b`.
These are same-run artifacts, retained by GitHub Actions under the linked run.

The source-bound complete local Linux suite above used its separately identified
library, `19924b8...`; it is not silently relabelled as a pass of retained
`bf65f1e...`. The final delivery record identifies the complete-suite execution
against the published library as well as the ordinary hosted CI results.

## Repository checks and final delivery record

The separately saved
[CLI/test/documentation checkpoint `f676af0`](https://github.com/techrote/cybersand/commit/f676af098a08bfa209f9bf51388d202caf8266ec)
is incorporated after runtime publication. Every retained extension source input
remains byte-identical to `6684017`; the additive CLI and Makefile targets have
their own executable test identities above.

After materializing the publication, `check_repository.py --require-materialized`
passed current source/documentation and artifact identity for all 18 required
runtime files, and `git lfs fsck` passed. Documentation structure, CI-provider
policy and historical M11 integrity also passed; the M11 check covered 18 records
and 28 historical hashes at `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`, independently
of current runtime acceptance. `git diff --check` passed.

The final branch head and the exact Documentation/provenance, Native,
GDExtension/Godot and Water workflow runs are recorded in the
[PR #179 validation section](https://github.com/techrote/cybersand/pull/179).
That delivery record is updated after the workflows finish, without creating a
new untested source commit merely to record the prior commit's results. The same
record identifies the complete published-Linux execution and final retrieval
evaluation. This audit's dated local and publication evidence remains scoped to
the immutable source and artifact identities above. Draft-skipped workflows are
never counted as completed implementation tests. The PR is left open for review.

## Preserved failures and scope limits

Local Godot first encountered a sandbox IPC error despite exit zero. The corrected
runner detects such diagnostics. An exploratory run using the old retained
runtime overlapped script edits; its individual logs are diagnostic evidence and
are not labelled an exact-original-head suite pass. The interrupted pre-lifecycle
correction run is likewise not a complete-suite result.

The initial palette compiler OOM and the pre-fix emission failures remain retained
as failures. A LeakSanitizer process-inspection failure under restricted `/proc`
is an environment limitation, not a source defect or successful leak check.
Later reruns are reported with their own commands and identity.

Rendered Linux software checks establish framebuffer behavior within these
fixtures. Windows headless execution establishes its own logic/runtime scope.
This review does not add physical-GPU performance, owner visual/feel acceptance,
or fresh browser/WebAssembly export execution. The earlier one-desktop captures
and palette/glow timing do not measure the total new vapour pipeline cost or
certify other platforms.

## Historical progress checkpoint — preserved as recorded at 2026-10-19 01:13 UTC

The following interim status is preserved as recorded at 01:13 UTC, before the
completed CLI results above. That checkpoint was committed on
`review/pr179-validation-progress` so that the publisher's guarded PR-branch
lease remained intact. The record was scheduled for incorporation into the PR
after publication. Present-tense statements in this section describe that
historical checkpoint.

The current
[guarded runtime publication run, 39183102017](https://github.com/techrote/cybersand/actions/runs/39183102017),
started from publisher commit `e621348f4b4fde4d49763f4c1f320b56cbcc2a29`, has:

| Hosted job | Checkpoint result |
|---|---|
| Linux build, job 117839855099 | **Passed**, including the current core native suite and focused execution of the actual rebuilt Linux extension |
| Windows cross-build, job 117839860316 | **Passed** |
| Actual Windows runtime execution, job 117843183910 | **Running** the 87 applicable headless cases after source, DLL, Rapier and engine identity checks passed |
| Runtime publication | Waiting for successful Windows execution; retained repo runtimes have not yet been replaced by this run |

The final review of the standalone physics CLI found an additional concrete
defect in `native/bench/physics_characterisation.cpp`: it accepted new material
IDs but indexed 81-entry stack arrays when collecting samples. Material 81
reproduced a **stack-buffer-overflow under ASan**, while the old-ID control
succeeded. A new parsed-output regression run against the unchanged sanitizer
binary exercised 154 actual invocations and reported 134 failing subcases;
some high IDs exited zero while still producing incorrect samples, so exit-code
checks alone are insufficient. The original red log is
`/tmp/pr179-physics-characterisation-new-id-red.log`.

The CLI correction and its normal/sanitized regression gate are in progress. They
are separate from the frozen GDExtension implementation: the standalone bench
file is not a retained-runtime source input. The planned correction derives
sample extents from the catalogue and rejects invalid wide IDs before narrowing;
the executable-level oracle checks every new ID, old-ID controls, count/sum-Y/
centroid accounting and invalid inputs. Historical fixed-fixture analysis
reducers are outside this change.

Remaining work is to complete that CLI validation, let the guarded Linux/Windows
runtime publication finish, incorporate this checkpoint and the CLI fix into
the PR, verify materialized runtime provenance and documentation/retrieval
gates, and run all applicable ready-for-review Native, GDExtension, Water and
Documentation workflows on the resulting branch head. Draft-skipped workflows
are not counted as completed tests. The PR remains open and unmerged.
