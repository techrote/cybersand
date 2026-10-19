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
| Sampled-rig hard-surface and digging-protection predicates stopped at ID 80 | Sampled actor queries ignored new walls and existing `CyberActorRigEffects` digging could reach editable cells behind an uneditable new barrier | Extend the shared mirror predicates. Tests cover all 51 barriers, a positive dig control and existing read/write budgets. USABLE-001 equipment retains its separate authored eligibility and occlusion contract. |
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

### Complete Linux suite against the published runtime

A separate, immutable checkout of runtime publication `8f841a2`, tree
`fe6ca13b00d72c87f2dd531b00ffb13354e09fba`, passed import and **93/93 non-import
cases** against the exact retained Linux library `bf65f1e...`. All 87 headless
and six actual-pixel cases executed exactly once, with the original timeouts,
in **1,006.662 seconds (16 minutes, 46.7 seconds)**. There were no failures,
skips, timeouts or source drift. The only warnings were the six expected
unsupported V-Sync notices from software-rendered cases.

The command used the pinned Godot 4.7 runtime, Xvfb and llvmpipe with
`LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 GALLIVM_PERF=nopt`, running
`tools/ci/run_godot_regressions.py --keep-going` without a shard selection.
Source binding verifies 427 inputs against publication bytes: 409 direct Git
blobs and 18 materialized LFS files. All 37 native runtime inputs also match
origin `6684017`. The retained `source-binding.json` SHA-256 is
`34da8c79967a028be00bf8231292d6bf3f837fd229df6ead28e3377bed88641a`;
`evidence-manifest.json` SHA-256
`fedf38b374dadace4a6a4135f006cb53c0d78fb3d348bb1479a9220f650ee731`
binds 105 completed evidence files, including the per-case logs and pixel images.

This execution is additional evidence for the published library. The preceding
complete local suite used separately identified `19924b8...`; its source binding,
timings and logs remain preserved under that identity.

## Upstream integration and Windows gate checkpoint — 01:58 UTC

Before ordinary final CI could start, upstream `main` advanced to
[`42d1925`](https://github.com/techrote/cybersand/commit/42d19253c71ec3cc45fc959d11b218aeb45fbe62)
with USABLE-001 equipment and three tests. GitHub reported PR head
`121cd6cc8253351253b8af89f1316cf418e0d6f2` as merge-conflicted and created no
Native/GDExtension/Water workflow runs for that head. The integration preserves
both parents and both sets of supplementary retrieval questions; the sole text
conflict was in `retrieval-challenges.json`. No native GDExtension source input
changed, so the published Linux and Windows runtimes remain source-matched.

An isolated merged-source import and focused run using retained Linux `bf65f1e...`
passed `test_usables.gd` (196 assertions), `test_usable_session.gd` (28),
`test_actor_usables_integration.gd` (29), `test_render_world_generation.gd` (23)
and `test_building_material_integration.gd` (1,091), with no failures or engine
diagnostics in **7.985 seconds combined**. The focused result manifest SHA-256 is
`9f90f71392e7db5f27b82d5f3be7e78b2beabd2c0e52cb1f09c75fef260fcddc`.
Equip changes preserve World generation; accepted World replacement clears
usable state and advances the render publication generation. Pause/resume keeps
the existing distinction between actor input lifetime and World replacement.
The new usable modules, tests and authored contract are unchanged from upstream.
The catalogue's sampled-rig digging claim is explicitly scoped separately from
the new equipment's authored eligibility and occlusion policy.

The final integration adds a permanent GitHub-hosted Windows headless job to the
ordinary GDExtension workflow, preserving the Windows cross-build check and four
Linux shards. It verifies the retained DLL against its committed LFS bytes and
provenance, requires complete coverage of current native source/header inputs,
pins Godot/Rapier and executes every applicable case through the strict common
runner. Commands, identities, completion, source drift and log hashes are retained
incrementally and uploaded even on failure. Focused helper tests cover stale or
missing provenance inputs, changed or unmaterialized runtimes, incorrect pins,
failed import, real exit-zero diagnostic/skip children and continued execution.
All **11 Windows-helper tests and 15 shared-runner tests** passed locally; an
independent helper review found no blocker. The pinned Godot console wrapper
owns a kill-on-close Windows Job Object, so the common runner's timeout cleanup
also terminates the actual engine child. The helper SHA-256 is
`b97c75ba18212794c6f501dbee1ed94a2f315333b59293268e124ffdcb1d5dad`,
its test SHA-256 is
`4cbc94f17b1911a29f12dc76d02688dad0fe0437578de22056ad4ac47d17780b`
and the integrated GDExtension workflow SHA-256 is
`3b62c06e1199619455ba2a2b9b70d52d95a67259a8af1aad2d8953c19a33afae`.

The inventory at this checkpoint is **96 Linux cases, including six rendered cases, and
90 applicable Windows headless cases**, plus import. The earlier 93-case Linux
and 87-case Windows results remain bound to their original pre-USABLE-001 source.
Final combined-branch execution is recorded in the PR delivery section after the
applicable workflows complete; inventory and helper tests alone are not a suite
pass. The canonical
[Windows execution procedure](../operations/local-build-and-validation.md#windows-retained-runtime-execution)
describes the permanent gate's bounds and artifact route.

## Resumed delivery after upstream integration — 19:46 UTC

The user resumed this review after the prepared integration tree
`9d1d4d332ec55d54ac3d0044e55d259477e12000` had been created, but its commit request
was interrupted by a tool-catalog change. That tree was never installed as the
PR branch head. Meanwhile, the PR independently merged USABLE-001 as `de30f8b`,
received the catalogue boundary correction `64aa3e8`, and merged ACT-005/current
main `02f9c890dc4faf0bf132a95acbc13a4d9cdc002f` as
[`232fe00`](https://github.com/techrote/cybersand/commit/232fe00bff148b775c163eb943435c351cf19791).
The PR is open, ready and mergeable. The resumed change applies only the pending
Windows harness, test-selection documentation and audit updates onto that current
head, preserving both intervening merges and the newer physical-usable source.

Commit `64aa3e8` fixes a further catalogue-sensitive fixture: material 81 is now
valid, so the generated-chunk malformed-payload test uses
`kMaterialDefinitions.size()` as the first ID past the catalogue instead. It also sizes the transport benchmark's
internal histogram to the complete catalogue while retaining that benchmark's
explicit 0–80 output schema. These changes are preserved. None of the intervening
changes alters the native source/header inputs of the retained extension runtimes.

The current suite contains **103 Linux cases, including six rendered cases, and
97 Windows headless cases**, with import counted separately. This supersedes the
96/90 inventory at the preceding checkpoint. The recovered Windows helper and its
tests retain the exact reviewed hashes above; discovery includes the seven new
ACT-005 cases automatically. Current USABLE01–USABLE04 retrieval questions and
their physical-equipment facts remain intact, and TEST03 is added separately.

An independent read-only review of the merged worker/main/snapshot and physical
equipment paths found no concrete integration defect. Equipment epochs and
receipts remain separate from World generation; accepted render bytes retain
their corresponding generation. Physical source clearance and selective material
recipes retain their authored contract. The 81-element physical observation
buffer is a 9×9 spatial patch, not a catalogue limit. Existing physical lifecycle,
owner-generation and rendered vapour regressions cover their respective paths;
this review does not claim exhaustive physical-tool combinations for all 51 IDs.

Before the resumed changes, head `232fe00` passed all four ordinary hosted gates:

| Workflow | Exact run and executed scope |
|---|---|
| Documentation/provenance | [39219447248](https://github.com/techrote/cybersand/actions/runs/39219447248), passed |
| Native | [39219447245](https://github.com/techrote/cybersand/actions/runs/39219447245), 78/78 normally, 78/78 ASan+UBSan, 78/78 TSan and 154/154 CLI invocations; hosted ASan disables leak detection |
| GDExtension/Godot | [39219447265](https://github.com/techrote/cybersand/actions/runs/39219447265), Linux build, Windows cross-build, four imports and 103/103 Linux cases, including all six rendered cases |
| Water apparatus | [39219447355](https://github.com/techrote/cybersand/actions/runs/39219447355), 120/120 registered cases with complete accounting |

These runs tested GitHub's PR merge checkout
`25635d91f454c1d15f4646b985cd15f8efd1021e` for head `232fe00` and base `02f9c89`.
All four Linux shard artifact ZIP digests were checked against GitHub; each
identifies the same retained Linux runtime `bf65f1e...` and pinned Godot 4.7.
The resumed inspection passes 261 identity, coverage, timeout, rendered-command
and log-diagnostic checks; its `inspection.json` SHA-256 is
`0b65b40e158c376cfcc9bddfda9bac03c94fc0fa2ad43992128e7c5d8ed73f36`.
The ready-scope classifier and optional serial-equivalence lane were skipped;
the required implementation jobs executed. There was no actual Windows execution
job on `232fe00`. The new 97-case Windows gate and final updated-head results are
recorded in the PR delivery section after they execute.

Workspace maintenance removed the earlier local raw-log directories during the
interruption. The completed results and hashes recorded before removal remain
historical evidence here; those local paths are no longer offered as recoverable
files. The publisher and subsequent GitHub Actions artifacts provide the retained
remote execution evidence. The resumed run restores repository source and pinned
runtimes directly from Git and LFS.

## Windows descriptor line endings and byte-exact evidence — 20:22 UTC

The first permanent Windows job
[`118273306125`](https://github.com/techrote/cybersand/actions/runs/39314781025/job/118273306125)
at head `908ce2b` executed import plus **97/97 cases** successfully in
**867.875 seconds**. All 98 individual records passed, but the aggregate gate
failed its final drift check. The four changed paths were Rapier's
`Radial2D.svg.import`, `icons/Fluid2D.svg.import`,
`icons/StateManager2D.svg.import` and `logo_square_2d.png.import`. Those descriptors
had CRLF checkout bytes and Godot re-saved them as LF text. The failure remains a
failed gate; successful individual cases do not erase its identity failure.

Artifact `12217529791` retains the failed report and all 98 logs. Its ZIP SHA-256
is `82915c9f422ca3ba0b58fac2d42a3c69cfdbf0b5576d8998bc979180f39cd8d3`;
the contained `windows-execution.json` SHA-256 is
`66b15da8ff690185399d0afe5de6c801ff9894592bd96962f361dca4deb7f9ae`.
It identifies Windows Server 2022, Python 3.12.10, pinned Godot 4.7, retained DLL
`aa388270...` and test-merge tree `090ec922f6b6d97ce186c0de3ce26664759d0c26`.
All four Linux shards and their aggregate gate passed in the same workflow.

Another session's follow-up
[`16eece8`](https://github.com/techrote/cybersand/commit/16eece87cab95bdad079acb77696d4d3c438e7dd)
added newline normalization and a descriptor-content regression. Its initial
implementation normalized every tracked input, including binary files. Review
reproduced a missed byte change in an MZ/NUL binary when CRLF became LF. The actual
retained CyberSand DLL contains 25 CRLF byte pairs; normalization reported
`7a5eaf3f1170c4977b0e8702e8e471a851a5ebec1cfd37444b89f4c14b701a81`
instead of its actual `aa388270...` SHA-256. Rapier and PNG hashes were also
changed. This was an evidence and binary-drift defect, independent of the
successfully executed Godot cases.

The correction preserves the descriptor newline fix while limiting it to the
four declared Rapier import-descriptor text files. Other tracked inputs retain
raw SHA-256, including DLLs, image assets and source files. Descriptor content
changes still fail, and binary-byte changes remain visible even when they look
like newline conversions. The focused regression covers the actual input-map
boundary and both accepted descriptor rewrites and rejected content/binary
changes. Per-case deadlines, coverage and failure/skip rules are unchanged.
The next exact-head Windows execution must complete before final acceptance;
its outcome is recorded in the PR delivery section.

At 20:33 UTC, independent inspection of all six execution/runtime archives from
the intervening `16eece8` GDExtension run
[`39317576111`](https://github.com/techrote/cybersand/actions/runs/39317576111)
confirmed successful execution of 103 Linux and 97 Windows cases and all 205
individual log hashes. Its workflow is green, but the Windows tested-input map
has exactly three incorrect binary digests: the two DLLs and Rapier's logo PNG.
The separately recorded raw runtime identities are correct. This evidence
confirms the normalization defect; it is not accepted as a fully verified final
run. That session recorded verification report SHA-256
`96181d94f95020d6516fb1383e3a4cecb9f4500c87d7cdcfb18cf7ff221692ed`.
The byte-identical original report was not recovered on the final resumption;
this digest is retained as historical metadata, not an assertion about the later
verification report at the same local path.

The new real-Git input-map regressions first ran against the unchanged `16eece8`
helper and failed seven subcases: three binary files and four unrelated text
paths. Both descriptor controls passed. With the narrow correction, all
**15 Windows-helper tests passed in 0.716 seconds**, and an independent reviewer
confirmed the path set, call sites and Windows portability. The **15 shared-runner
tests also passed**, in 1.386 seconds. The corrected helper SHA-256 is
`6e66c243e2fc8fd60f2c721f80eb868a21e05b212fddeb1753072b20d98cf1f0`;
its regression-file SHA-256 is
`91773e3598b99247c73742d9b269e8d9f1044f1907cac9f743168f5f441d218a`.
Materialized-runtime, documentation, M11, provider-policy, LFS and whitespace
checks passed. Retrieval remains 32/32 frozen and 77/77 supplementary canonical
top-five hits, with 21/59 top-one hits and MRR 0.8031/0.8652 respectively; the
updated descriptor/binary fact was separately reviewed against source.

## Completion resumed — 22:58 UTC

The owner requested completion of PR #179. The public branch still points to
`16eece8`; the five-file descriptor/binary correction above was recovered from
the interrupted checkout without changing its implementation. The earlier
checkout and its staged work are preserved separately. The resumed local
Windows-helper and shared-runner commands each pass **15/15 tests** (0.509 and
0.689 seconds respectively). A separate reviewer reproduced all seven failing
subcases with the unchanged helper, then passed the corrected helper with Git
`core.autocrlf=false`, `true` and `input`.

Independent reinspection verified all six retained GDExtension archive digests
against GitHub metadata, all extracted files against their ZIP members and all
205 execution log hashes. The Linux 103-case inventory and Windows 97-case
inventory match the immutable tested source exactly. The later retained
verification report SHA-256 is
`df0f25b25a9c9a8e5ebe0be4fb3c027e414421a3af5ea9f4095522ceefbf4843`.
These checks preserve the earlier execution evidence while keeping the known
binary-input-map defect explicit.

The recreated checkout initially lacked the five companion-workspace reference
files required by documentation validation. Restoring those exact files from
the workflow's pinned `6a58311982941b75f46e22109a0829e5acb83c7e` commit
resolved all six missing-reference diagnostics. Documentation, current runtime
provenance for all 18 materialized LFS files, historical M11 integrity, CI-provider
policy, LFS integrity and whitespace then passed. Frozen and supplementary
retrieval retain their 32/32 and 77/77 canonical top-five results.

Live reconciliation also records the prior Native run
[`39317576052`](https://github.com/techrote/cybersand/actions/runs/39317576052)
as **cancelled**, after its ordinary native, CLI, ASan/UBSan and TSan steps passed.
That partial result is not a completed Native gate. The correction therefore
requires a new identified source checkpoint and completion of Documentation,
Native, GDExtension/Godot (including actual Windows execution) and Water gates.
Final artifact verification must compare binary input hashes with raw bytes,
check all expected case records and their log hashes, and confirm source identity.
The PR delivery record owns the resulting run IDs, outcomes and integration
disposition, so recording the results does not invalidate the tested source.

The cancelled Native job ran for **35 minutes 8 seconds**, at its 35-minute job
limit. Comparison with successful runs
[`39219447245`](https://github.com/techrote/cybersand/actions/runs/39219447245)
and [`39314781247`](https://github.com/techrote/cybersand/actions/runs/39314781247)
records **28 minutes 8 seconds** and **34 minutes 8 seconds** respectively.
The relevant native inputs and workflow are identical between these runs; the
CLI plus evidence upload occupies 45–55 seconds. Most variability comes from the
sanitized settled-regions build and soliding regressions. The final shared-library
and benchmark step began at 34 minutes 40 seconds in the cancelled run; complete
benchmark output was printed before cancellation. These observations support a
job-budget correction rather than a source or benchmark-performance change.
The Native job allowance is raised to **45 minutes**, preserving every test,
per-command timeout and sanitizer setting.

Final source review also corrects narrow Current documentation claims: the
frozen interaction oracle covers original IDs 0–80 with twelve rolls, while the
new building rules have their separate full-byte probability tests; old-to-old
pair rules are preserved, but old materials can participate in new building
pairs. Current World uses the eight-byte experimental storage carrier; CYSD1's
five-byte serialized record remains a separate format contract.
The catalogue also distinguishes stored inclusive probability thresholds from
probability fractions. Frozen question Q30 keeps its original ID and wording;
its expected fact is corrected to separate dated current Linux execution from
historical and Windows evidence, with the correction disclosed in fixture
metadata. This is not a retrieval-ranking improvement claim.

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

At the 01:58 UTC checkpoint, the combined pre-commit documentation gate passed 92 canonical documents, 175
claims, 1,781 local links and 124 heading anchors without warnings. Current
materialized-runtime, LFS, CI-provider and M11 checks also pass after integration.
Frozen retrieval recorded **32/32 canonical top-5 hits**, 21 top-1 and MRR 0.8031.
The combined 74-question supplementary set records **74/74 canonical top-5
hits**, 59 top-1 and MRR 0.8811. The added Windows execution and scoped sampled-rig
facts were reviewed against source. These are corpus-routing measurements, not a
before/after improvement claim or a substitute for expected-answer review.

After resumption and the ACT-005 integration, the local gate again passes all 18
materialized runtime identities, M11, LFS, provider policy and whitespace checks.
The restored 11 Windows-helper and 15 shared-runner tests pass. Documentation
passes 92 canonical documents, 175 claims, 1,833 local links and 137 heading
anchors. The frozen retrieval result remains 32/32 top-five, 21 top-one and MRR
0.8031; the 77-question supplementary set records 77/77 top-five, 59 top-one and
MRR 0.8652. Added and changed Windows/sampled-rig facts were checked separately
against source, with all newer physical-equipment questions preserved.

The final branch head and the exact Documentation/provenance, Native,
GDExtension/Godot and Water workflow runs are recorded in the
[PR #179 validation section](https://github.com/techrote/cybersand/pull/179).
That delivery record is updated after the workflows finish, without creating a
new untested source commit merely to record the prior commit's results. The same
record identifies the complete published-Linux execution and final retrieval
evaluation. This audit's dated local and publication evidence remains scoped to
the immutable source and artifact identities above. Draft-skipped workflows are
never counted as completed implementation tests. Final review and integration
disposition are recorded on that PR after its applicable gates complete.

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
