---
title: Materials Lab completion, runtime publication and platform qualification
status: Current
document-kind: audit
scope: Owner-requested continuation of Draft PR 562; additive Lab diagnostics, source-matched runtime publication and automated platform acceptance; human acceptance and production catalogue cutover are separate
canonical-for: [materials-lab-completion-evidence]
last-reviewed: 2026-11-12
related-documents: [2026-11-11-materials-lab-v1.md, ../operations/materials-lab-authoring.md, ../architecture/material-authoring-catalogue-plan.md, ../operations/local-build-and-validation.md]
---

# Materials Lab completion

The owner cannot run the candidate now and requested completion of the remaining
work. This continuation closes implementation and automated qualification work
without claiming human acceptance. Draft PR [#562](https://github.com/techrote/cybersand/pull/562)
remains unmerged; Ready promotion, auto-merge and production material installation
are not part of this assignment. MoltenGlass H1 remains excluded.

## Intake and retained evidence

Accepted main is `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`. The intake branch is
`codex/materials-lab-v1-20261111` at
`f684dcffb18614dd9557e85d3c811abcb28cf325`. The
[preceding audit](2026-11-11-materials-lab-v1.md) retains its actual native,
sanitizer, graphical and hosted results, including the completed 202-test suite.
Those results remain qualified to their recorded source, not automatically to
the new source below.

The earlier manually dispatched
[Godot run 43100826964](https://github.com/techrote/cybersand/actions/runs/43100826964)
tested `55c25abf93328cc4d47f1a50941ee418c04d949a`. Both platform builds passed,
but the run failed. Windows shard 4 could not compile the Lab World because its
staged native paths were absent. Observed Linux shard failures followed successful
case execution and detected missing Lab entries in the tracked portable class
cache. The subsequent path-inventory/compiler-argument and portable-cache fixes
are already ancestors of the intake. Their presence does not relabel the failed
run as passing; fresh actual platform execution is required.

## Source and platform boundaries

The Lab's native observer is a cold-path, copied-value API on its exclusive test
owner. It must not change World updates, kernels, masks, scheduling, material IDs,
saved state or shared Workbench ownership. Resolver inspection at a supplied
roll must distinguish available eligibility facts from unobserved scheduling and
competing mechanisms.

Runtime publication follows the existing branch-scoped publisher contract:
an explicit source-bound request, exact branch lease, newly built Linux and
Windows artifacts, actual target-platform test receipts, and a guarded four-path
LFS/provenance append. Historical provenance cannot be relabelled or rewritten as
new execution. Candidate packaging must retain the immutable source history
needed by authoring validation, without copying machine configuration or secrets.

The separately owned #353-B generated-capability consumer is reviewed in its own
worktree and [Draft #563](https://github.com/techrote/cybersand/pull/563), stacked
on #562. It is not installed in #562 by this publication. Existing
display-name consumer work in #384 retains its ownership.

## Implemented completion work

The contact inspector copies native stored/visible cells, A/B state, raw thermal
storage, body masks, source-core scheduling windows and compiled resolver facts
from its exclusive paused MicroScenario owner. Source/target selection and role
swapping are mounted in the existing Native test tab. A supplied probability roll
is kept separate from actual native scheduling; per-cell sleeping, wake deadlines,
epochs and competing mechanisms remain explicitly unobserved.

The Windows authoring process owner creates each child suspended, assigns a
private kill-on-close Job Object, then resumes its initial thread. This closes
the orphan-descendant gap after a driver exits, including descendants with
redirected pipes. POSIX retains process-group ownership and now also retires
redirected descendants after successful driver exit. Four actual portable
fixtures cover timeout, cancellation, inherited pipes and redirected descendants;
they execute on both platforms without replacing native Windows acceptance with
mocked taskkill calls.

The runtime publisher requires the complete discovered catalogue suite, all
seven selected actual native/Godot Lab/Workbench cases, Linux and Windows
graphical UI/World receipts, and a freshly exercised self-contained Windows
package. It retains failure artifacts, checks source/branch custody and publishes
only the two runtime binaries and two provenance manifests. A final narrowly
scoped job requests the unchanged manual documentation, Native, GDExtension and
palette workflows on the exact publication child. Accepted dispatch is recorded
separately from downstream completion. No general Draft gate is disabled.

The package reconstructs clean Git history from a self-contained bundle and
includes Godot, Python, Git for Windows, the tested C++ compiler and their notices.
It copies no originating Git configuration, remotes, hooks or untracked files.
Actual package execution takes place in a disposable path containing spaces with
only the included authoring prerequisites on PATH. The file manifest binds the
source, runtime, dependencies and qualification artifacts.

## Qualification ledger

Fresh local native-core qualification used GCC 14.2 on Linux, the unchanged
production native source inventory, and the existing Makefile targets:

| Command | Result | Elapsed |
|---|---|---|
| `make -j2 build/tests build/tests_sanitized` | Both existing build targets current | Build log retained |
| `./build/tests` | 192 passed | 329.597 s |
| `ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 ./build/tests_sanitized` | 192 passed; no ASan/UBSan error | 345.778 s |
| `PYTHONPATH=tools/material_catalogue python3 -m unittest -v test_process_owner test_lab.LabTests.test_timeout_and_cancel_kill_real_child_descendants test_lab.LabTests.test_process_output_limit_is_enforced_for_a_real_child` | Six actual process-lifetime/output controls passed | 7.220 s |
| `python3 tools/ci/check_docs.py` | Passed, no errors/warnings | Local |
| `python3 tools/ci/check_m11_consistency.py` | 18 historical records / 28 source hashes pass | Historical integrity only |
| Materials Lab retrieval fixture | 10/10 canonical routes rank 1 | Lexical routing, not runtime acceptance |

The native inventory was hashed before and after both core executions and
remained unchanged. Leak detection was disabled for this local sanitizer run;
there is no TSAN or Windows claim in these results. The rebuilt local inspection
extension uses a declared development-toolchain override; the hosted publisher
must independently use the pinned release build path.

The final frozen native contact test passes **116 assertions**. Actual Linux X11
captures pass **123 contact assertions** and **196 full mounted UI assertions** at
1680×1050 with Godot 4.7 and Mesa llvmpipe. The actual service and compiled World
UI checks also pass (87 and 201 respectively). Their local development extension
SHA-256 is `22f39a70915f4eb00636b0d85a6cd640f22dd70884965b4e8acbb026d5d0ba1c`;
the pre-existing retained runtime was restored after execution.

[Contact screenshot](materials-lab-completion-20261111/09-native-contact-inspector.png),
[contact readback](materials-lab-completion-20261111/contact-readback.json),
[contact capture manifest](materials-lab-completion-20261111/contact-capture-manifest.json),
[retained-Salt World screenshot](materials-lab-completion-20261111/08-kept-salt-world.png),
[native World receipt](materials-lab-completion-20261111/effects-ui-world-receipt.json),
and [its source/display manifest](materials-lab-completion-20261111/effects-ui-capture-manifest.json)
retain actual graphics alongside native facts. The
[core qualification record](materials-lab-completion-20261111/completion-core-qualification.json)
binds both full core runs to their source inventory and log hashes.

The first new full catalogue run executed 206 tests, with 205 passing and one
source-custody refusal: `material_lab_experiment.gd` changed during the native
pair-product test while the inert-source diagnostic fix was applied. The
[original failed log](materials-lab-completion-20261111/completion-catalogue-attempt1-suite.log)
and [attempt record](materials-lab-completion-20261111/completion-catalogue-attempt1-qualification.json)
remain preserved. The [frozen-source rerun](materials-lab-completion-20261111/completion-catalogue-frozen.json)
passes **206 tests in 313.110 seconds**, with no skips. The complete 94-input
World authoring inventory has the same before/after digest,
`7fb1f4f66b1de4be6d12bfb1b04d8857da749543b67c55e36a3718676b6c0e51`.
Its [original log](materials-lab-completion-20261111/completion-catalogue-frozen.log)
is retained; the earlier failed attempt is not relabeled as passing.

The publisher's focused guard suites pass **7 + 12 + 30** tests, including
complete native-suite admission, graphical receipt custody, clean package
history and branch/dispatch race controls. Pinned actionlint 1.7.12 and the
54-workflow scheduling/provider checks pass. Automated mocks in these guard
suites qualify refusal logic only; they do not replace target-platform execution.

## Retained platform failures and corrections

[Request 1 / run 43117390171](https://github.com/techrote/cybersand/actions/runs/43117390171)
built source `9eb90272cb2261e429c965dfbd21c6adc862a021`. The complete Linux
catalogue suite passed 206 tests in 381.398 seconds, the pinned Windows
cross-build passed, and all seven Linux native/Godot cases passed. Windows
packaging guards exposed a fixture that wrote host-native newlines but
asserted LF bytes. Request 2 makes LF explicit and also proves that a tracked
CRLF binary fixture retains its actual bytes. The Linux graphical stage failed
with exit 126 because the existing non-executable display preparation script
was invoked directly. Its invocation is corrected to `bash`; the shared script
is unchanged. Neither failed attempt published a runtime.

[Request 2 / run 43118926062](https://github.com/techrote/cybersand/actions/runs/43118926062)
built source `c594dc30c2eaa9e9c32122725e028d4961afa78d`. Linux again passed its
206-test inventory (419.039 seconds) and all seven actual native/Godot cases
(1348/131/116/87/189/201/164 assertions, all zero failures), then reached the
already identified display-launch failure. Windows executed the entire
206-test catalogue inventory in 859.366 seconds. Its original result contains
12 failing subtest records, one error and three explicit POSIX-only skips,
all failures/errors confined to Godot receipt-root controls. The actual four
portable process-owner tests, five native extended-effect tests, and native
World movement/products/persistence/parity tests passed. Separate actual
Windows timeout and cancellation probes also observed and retired their child
processes. The later Windows Godot, graphical and package stages were not reached.

The [original Windows receipt](materials-lab-completion-20261111/request2-windows-catalogue-suite.json)
and [test log](materials-lab-completion-20261111/request2-windows-catalogue-suite.log)
retain these failures. The validator resolved each child path but compared it
with an unresolved supplied root. An equivalent `root/existing-directory/..`
spelling reproduced the false refusal independently on Linux. Resolving the
root once fixes that inconsistency; the receipt-deletion test also now uses the
canonical forward-slash path. The exact hosted Windows path spellings were not
logged, so short-name expansion is not claimed as an observed cause. Eighteen
focused guards pass, including new equivalent-root admission, changed/missing
custody rejection and same-byte symlink escape rejection. Discovery now contains
209 catalogue tests. No skip was added or threshold relaxed.

## Request 3 platform qualification and package correction

Request 3 is source `8e2206d5a664cc86b2ca432e6ad976e5f6d86bff`, tree
`2d9ab65b3c881b7a06d91c340ce19e0b490d0c0e`, in
[run 43122038666](https://github.com/techrote/cybersand/actions/runs/43122038666).
It includes the path and display fixes above and adds actual graphical contact
execution inside the relocated Windows evaluation package. That fourth package
case runs the existing native contact test through the bundled ANGLE engine,
requires natural completion, and binds its original process log, screenshot,
stored Salt/partial-Water cells, source inventory and native owner readback to
the original delivered files. Receipt-admission fixtures qualify refusal logic;
only the actual Windows smoke establishes package acceptance.

The fresh hosted Linux catalogue stage passes **209 tests in 474.823 seconds**,
with no skips, failures or errors, using recorded GCC 13.3 and Python 3.12.3.
Its [original receipt](materials-lab-completion-20261111/request3-linux-catalogue-suite.json)
and [original log](materials-lab-completion-20261111/request3-linux-catalogue-suite.log)
bind that result to request 3; artifact `13900964469` has archive SHA-256
`6bf939c26bd3e64282f302c0716e5fbe51518416aa1040e85beb63155f49cc0f`.

The same source's pinned Linux runtime stage also passes. Its seven native/Godot
cases report **1348 catalogue, 131 experiment, 116 contact, 87 lifecycle,
189 mounted UI, 201 compiled World and 164 Workbench assertions**, all with zero
failures. The actual X11/OpenGL mounted UI and World captures pass **196 and
206 assertions**. Every recorded process completed naturally without a skip.
The [original validation](materials-lab-completion-20261111/request3-linux/validation.json),
[graphical record](materials-lab-completion-20261111/request3-linux/graphical.json)
and [runtime provenance](materials-lab-completion-20261111/request3-linux/runtime-provenance.linux.json)
are retained alongside their original logs and captures. Artifact `13902367010`
has archive SHA-256 `712e55c440fddcd04ec3125e280fde5c4eb356d30f1f4f48104780ed9c8d33ab`.
Its 4,571,160-byte Linux library has SHA-256
`0f257fe66e043cbb77366d99ce77325eacf8481443df4c5e000dcbc9ac075ea9`;
all 88 native and 779 build input blobs were independently compared with Git at
the recorded source. This verification is separate from the original execution.

The [density capture](materials-lab-completion-20261111/request3-linux/graphical/test_material_lab_world/07-candidate-world-density.png)
and its [native World receipt](materials-lab-completion-20261111/request3-linux/graphical/test_material_lab_world/world-ui-receipt.json)
show reference Sand density 1600 versus candidate density 500, seed 2 and
120 steps. Native readback counts **369 reference Sand cells below the reservoir
versus zero candidate cells**, with **1,644,240 Water quantity units on both
sides**. Both sides pass repeat, one/four-worker configuration comparison,
persistence checkpoint/replay and quantity accounting. The configured worker
count is four; this is not a claim that all four workers participated in every
phase. The receipt correctly remains `runtime_active: false`.

Windows Server 2022 also passes its complete source-owned catalogue inventory:
**209 tests run, 206 passed and three existing POSIX-only skips**, in 850.575
seconds, with no failures or errors. The skips are the response-symlink protocol
fixture, the POSIX process-tree fixture and the POSIX spaced compiler-symlink
fixture. The four new portable Job Object/process-owner fixtures actually pass
on Windows, as do the separately observed timeout/cancellation descendant probes.
All seven native/Godot cases pass with the same assertion counts above; actual
Windows ANGLE UI/World captures pass **196/206 assertions**. Their
[original validation](materials-lab-completion-20261111/request3-windows/validation.json),
[catalogue receipt](materials-lab-completion-20261111/request3-windows/catalogue-suite.json)
and [graphical record](materials-lab-completion-20261111/request3-windows/graphical.json)
retain natural completion and their own source, runtime and log identities.
Windows runtime artifact `13903143269` has archive SHA-256
`e14f405657774eafc62d67cd78d0dc8ba601b068614c393244ca50d5885237fd`;
the DLL SHA-256 is `83fb4488ec3a1fdc5f639d242109b73861083514b9d8e176fd8051c74dfb4611`.

The subsequent Windows package job `130883326148` failed **before package smoke**:
the selected Python 3.12.10 distribution contains executable symlinks and the
copier rejected every link. This does not undo the original platform execution,
but no package or runtime was published and downstream dispatch was skipped.
The correction materializes executable aliases only when their strictly resolved
file remains inside the canonical Python installation. Broken, external and
directory aliases remain refused. Two real filesystem regressions cover accepted
alias chains and four refusal cases; **14 package guards and seven publisher
guards pass locally**. No new skip or weakened source check is introduced.

## Accepted-main reconciliation and next delivery

While request 3 ran, accepted main advanced to
`d8588716becb0dc42019faf23f721378d8adc84a` through the owner's merge of liquid
equipment PR #553. The Lab now incorporates that accepted worker/equipment
implementation and capped-Details toolbar fix. The only manual merge conflict
was adjacent roadmap sections; both are retained. No production native source,
catalogue identity, immutable compatibility lock or inspection bridge changes
in this reconciliation. Earlier evidence remains bound to its original source.

Fresh local Linux execution at reconciliation commit
`a069e7cabda74039f7e3d5bde4074815fbd06ab8` passes project import, Workbench canvas
164, liquid edges 70, mounted Lab UI 189, equipment 103 checks at each of the
one/four-worker configurations, and pressure reservoir 81 checks at each
configuration. All have zero failures. The
[original reconciliation receipt](materials-lab-completion-20261111/accepted-main-reconciliation/reconciliation-summary.json)
records the pinned request-3 Linux runtime, its 88 matching native inputs and the
677-file desktop/test/catalogue inventory unchanged across execution. These are
headless Linux results. An initial harness run placed user data inside source;
the Lab correctly refused the response path. Only that UI case was repeated with
external user data, retaining the original refusal separately. No product or
test threshold change was needed. Documentation (127 documents / 253 claims),
historical M11 (18 records / 28 hashes) and Lab retrieval (10/10 rank 1) pass.
The recoverable public reconciliation is
`1331e4e01be363f6bf0a60ca591c1afa7fb7b55f`, with the **identical Git tree**
`d38040cab694ecdfbc56aa07d723212d8be2c0e5` and public parents `8e2206d5…`
and accepted `d8588716…`. Git metadata differs; original test receipts retain
the actual local commit and are not relabeled as another execution.

The independently scoped capability branch's first Windows campaign passed its
catalogue and headless cases but hit the existing UI wait and 60-second native
World execution limits during graphical tests. Its original failures remain
separate; they are not a main-Lab platform failure. Main request-3 Windows
graphics passed but took 600.789 seconds for the UI and 332.666 for the World.
On hosted Linux, the otherwise identical World case used 2.93 direct Godot CPU
seconds headless versus 272.5 with software graphics, indicating substantial
rendering work while native child jobs ran. Windows CPU counters were unavailable,
so software-renderer contention there remains an inference pending fresh execution.

The next publisher limits **only automated graphical captures to 15 rendered
frames per second**. Product/global frame-rate settings, rendering backends,
simulation time scale, fixtures, assertions and all UI/compilation/execution
watchdogs remain unchanged. Recorded-command checks refuse a missing, altered,
duplicate or ineffective frame cap; the packaged contact capture uses the same
cadence. Focused publisher/package/unchanged-base guards pass **8/14/30**.

An actual local X11 graphical World trial passes **206 checks** with that cap,
in 60.155 seconds and 49.43 direct Godot CPU seconds, completing naturally under
the unchanged 1200-second graphical watchdog. The
[comparison record](materials-lab-completion-20261111/graphical-world-maxfps15/comparison.json)
shows an **identical image SHA-256 and identical candidate/reference final native
readback** to the original hosted uncapped capture: stored grids/state, quantities,
120 ticks and comparison results all agree. Repeat, one/four-worker configuration,
persistence and quantity checks remain true. The hosts differ, so the timing
comparison is diagnostic evidence, not a controlled performance benchmark.

Request 4 includes accepted-main integration, Python alias materialization and
bounded graphical capture cadence. A fresh complete campaign must establish its
own platform, relocated package and downstream results. Final successful artifact
identities and their limits will be recorded before handover. Human acceptance
remains unperformed.

## Windows evaluation continuation — 2026-11-12

Request 4, source `cd534e9b8d2e98ea75e463b2fcf261f08deead96`, completed the
[fresh platform campaign](https://github.com/techrote/cybersand/actions/runs/43129518539)
with successful Linux and Windows catalogue, native/Godot and graphical stages.
Its Windows DLL is 5,118,976 bytes, SHA-256
`34b33948dbe252231c1132de4832deb17984ea1c05d1d3c059f98a7ec8195ba9`.
The package stage then failed before smoke: Git for Windows 2.56 uses `ucrt64`
and places native helpers in `bin`, while the copier required `mingw64/libexec`.
No runtime publication or executable package is claimed for this failed campaign.
The original hosted job log remains attached to that run; the preceding Python
alias failure and earlier qualification records remain unchanged.

The corrected copier admits exactly one complete `mingw64` or `ucrt64` layout,
retains its DLLs/helpers and dependency license notices, and excludes installed
machine configuration. Missing, ambiguous and unlicensed distributions remain
refused. The isolated launcher/smoke PATH supports both native layouts. Two new
layout regressions raise package guards to 16; Linux package/publisher/base
guards pass 16/8/30. The actual official MinGit 2.56.0.4 x64 ZIP, SHA-256
`e3bf78351fe777fba47ddee5950082f8a98bb0f02604fdc7ba3ee2cb68ffa877`, was
copied and executed on Windows with only the copied tools and system directories
on PATH. Its full immutable compatibility check passes with
`production_cutover: false`. Local Windows symlink privilege was unavailable for
the existing Python alias fixtures; their WSL results and original hosted
Windows execution remain separately scoped. No skip or validation relaxation was
added.

Independent ordinary Windows launch also exposed two usability defects hidden
by the large graphical fixture viewport: standalone game scaling shrank the
13-pixel Lab controls at 1280×720, and native/contact or candidate World controls
extended below compact windows. Pending numeric text could also be committed
after a compile request, causing an avoidable stale-revision refusal. The
continuation corrects Lab-specific scaling/overflow and commits visible numeric
edits before request capture; endpoint/roll changes retire resolver diagnostics.
These changes retain the existing native consumers and authoring boundaries.
Fresh resulting-source execution and the relocated package remain required.

Final local Windows authoring regressions on the frozen correction pass:
mounted authoring UI **196 assertions**, compiled candidate/reference World UI
**204 checks**, and native contacts plus all-tab compact-window reachability
**180 assertions**, all with zero failures. The full UI exercises creation,
duplication, property/reaction edits, validation, native compilation and Worlds,
preset/recipe persistence and reopening, pending text and stale-result refusals.
The World test adds raw typed seed/tick recipe saving. Direct ANGLE interaction
also confirms that typing density1337 and immediately clicking Compile qualifies
that value on the first attempt. These use the request-4 DLL with unchanged
native inputs; they do not reattest its manifest to the new source. The
[UI qualification receipt](materials-lab-completion-20261111/windows-evaluation-20261112/materials-lab-ui-qualification.json)
records commands, timeouts, tools, actual runtime and preceding failed attempts;
its final source-file hashes are labelled as inspection, not a captured
whole-run before/after inventory. The
[packaging guard receipt](materials-lab-completion-20261111/windows-evaluation-20261112/packaging-guards-qualification.json)
separately retains the 16/8/30 guarded runs and their before/after input hashes.

Documentation and historical M11 checks pass; the existing frozen retrieval set
scores 19/32 at rank1 and 31/32 at rank5, while the additive Lab questions score
11/11 at rank1. Retrieval is lexical routing evidence, not semantic acceptance.
The first local documentation run lacked the pinned companion workspace files;
restoring its five exact expected-fact inputs from CI's unchanged
`6a58311982941b75f46e22109a0829e5acb83c7e` checkpoint passes without changing
the checker or questions. Current repository validation still refuses the old
published Windows/Linux manifests pending source-matched publication.

One earlier WSL guard invocation inherited Git location variables and touched
local repository configuration. The corrected guard harness removes those
variables from its independent fixtures and passes 16/8/30 with unchanged
guarded inputs. The real repository's worktree mode and owner identity were
restored from its pre-existing reflog; refs, staging index and source files were
verified intact. This harness failure does not count as a passing guard run.

Publication request **5** carries these fixes, exact contact-capture source
custody and the current Git package layout. It requires a fresh complete
Windows/Linux campaign and relocated package smoke under all existing gates.

## Request 5 delivery and palette preflight correction — 2026-11-12

[Campaign 43137926965](https://github.com/techrote/cybersand/actions/runs/43137926965)
passes completely from source `bcb3b62d324581f319e029a657db6b97879c9cc4`, tree
`a2314bbfb35b7e35d05240c66fa25401a7e907e2`. The exact four-path runtime
publication child is `44645b7a3bc0df8fe57fbd0073152da8965e8f4f`.
Both platforms pass all seven Lab/Workbench cases: catalogue1348,
experiment131, contacts180, lifecycle87, mountedUI196, compiledWorld204 and
Workbench164. Actual Linux X11 and Windows ANGLE captures pass UI203/World209.
Linux runs all209 catalogue tests; Windows runs209 with206 passes and the three
unchanged POSIX-only skips. No failure or error is suppressed.

The self-contained relocated Windows package passes import, actual bundled-tool
authoring, compiled Worlds and ANGLE contact inspection187. Artifact13910367089
contains the707,255,622-byte evaluation ZIP, SHA-256
`29c203ad274ec1a231051a4a113502ca7dd3139e837c2be9557f1dc3162c6e63`;
its outer archive SHA-256 is
`1ef920c8214e98d06c9eae3b4e277a9e8a7abc11f5d8143e5b40166445636413`.
Manifest SHA-256 is
`858b06b57721a90fe7b2ffb9e5f4cce98095ffddf9d57a71663330a8bbf88533`.
Windows DLL SHA-256 is
`7aff557ea0f2f87d6380e645ed17f5878ab8a5746cd66cfa33be783728c6e2a2`;
Linux is `0f257fe66e043cbb77366d99ce77325eacf8481443df4c5e000dcbc9ac075ea9`.
Independent verification checks all20,773 package files,2,516 tracked source
blobs,88 native inputs,2,248 ancestor commits,22 compatibility ancestry pins,
bundled tools/notices and absence of remotes/credential configuration.208 source
files differ only by authenticated Windows checkout line endings. The three
intentional runtime/provenance overlays are recorded separately. Original
package smoke evidence is artifact13910681673, outer SHA-256
`d93f21e51119f6c83c1f0131806990c8ab6dc3e347092391873a586951cf7ad2`.

Exact publication-child manual gates pass: Documentation/provenance43143420508,
Native43143423461 (all six families, including TSAN and ASan/UBSan), and
GDExtension/Godot43143426557 (both source builds and all dispatched shards).
Palette43143429621 fails before rendering: its strict checkout-custody parser
rejects the root raw-evidence `**` attribute pattern. Missing shader manifests
are downstream symptoms; no rendering result is inferred. Original Linux and
Windows failure artifacts13910761899/13910113178 remain retained.

The correction moves the same evidence attributes into that directory's scoped
`.gitattributes` using supported `*` syntax and preserves the original later
Markdown/YAML overrides. The validator is unchanged. Effective attributes for
all85 retained evidence files and five source/launcher witnesses are identical;
all85 raw SHA-256 values remain unchanged. Scope-isolation and fail-closed
regressions pass14/14 normally and14/14 with optimized Python. An optional local
broader palette-controls attempt lacked NumPy and is not a graphics result.
Local materialized repository/provenance validation and historical M11 pass
after fetching the exact runtime publication. Request6 qualifies this corrected
publication input afresh; request5 remains a verified recoverable package,
without relabelling its source or execution.

The [independent package proof](materials-lab-completion-20261111/windows-evaluation-20261112/independent-package-proof.json)
and [attribute equivalence proof](materials-lab-completion-20261111/windows-evaluation-20261112/palette-attributes-equivalence.json)
retain exact checked identities, commands and qualification boundaries.

## Windows AppData alias replay correction — 2026-11-12

Independent local execution of the pristine request5 package with its bundled
tools passes import, compiled World204 and actual ANGLE contact187. The UI runs
all196 assertions with one failure: its string-prefix destination assertion
compares Godot's logical Roaming path against Python's resolved MSIX
LocalCache/Roaming path. Both name the actual exported directory; export and
all required bundle-file checks succeed. This is a failed local qualification,
retained separately from the successful hosted run, not an accepted replay.

The test-only correction proves live directory identity with a fresh256-bit
nonce written under the requested child, read through the reported path,
removed through that path and then absent through the requested path. Unrelated
same-basename directories and copied payload bytes cannot qualify. Relative or
missing paths and failed writes/removals fail closed. Production source/output
admission, receipts, processes and simulation code remain unchanged.
Focused filesystem controls pass10/0. The full mounted UI with bundled Godot,
Python, C++ and Git and external spaced user data passes205/0 in233.265s;
the test's before/after SHA-256 is
`69549d0e373902a3446c4418d53fb80317c9233f55e633ae8d032effe9b21a2c`.
The [original local replay summary](materials-lab-completion-20261111/windows-evaluation-20261112/local-package-replay-attempt1.json)
and [corrected UI qualification](materials-lab-completion-20261111/windows-evaluation-20261112/ui-directory-custody-qualified.json)
retain their own commands, tools, source/runtime identities and actual outcomes.
The focused alias control uses filesystem `..` resolution; the final package
still requires a fresh complete local replay under the original MSIX conditions.

Request7 supersedes request6 before publication and requires the complete
source-bound campaign again. Request6's Linux catalogue/runtime success and
other partial outputs keep their original identities; neither those outputs
nor the request5 package are relabelled as request7 execution. No native/Godot
application behavior, material authority or validation rule was relaxed.

Independent Windows 11 execution additionally passes **625 checks**: Workbench
canvas 164, a fresh-process saved-start reopen 23, liquid edges 70, equipment
103 at each of one/four workers, and reservoir 81 at each configuration.
The [original combined receipt](materials-lab-completion-20261111/windows-evaluation-20261112/combined-qualification.json)
retains exact commands, watchdogs, timings, tool identities and all 1,076 input
hashes before/after. All 88 native inputs and the 11 named Workbench/equipment
owners/tests remained unchanged; five concurrently edited Lab UI/test files
are explicitly recorded as deltas, so this is equipment integration evidence,
not a frozen-source Lab execution claim. The
[independent equipment readbacks](materials-lab-completion-20261111/windows-evaluation-20261112/equipment-native-readbacks.json)
observe actual worker peaks of one and four and retain Water accounting.
Default-sandbox import first failed on safe-save permissions; the same import
passed outside that sandbox. An initial parent-harness cp1252 printing failure
is retained locally; a fresh UTF-8 edges run completed naturally. Product checks
and policy watchdogs were unchanged.

## Request7 recovery package and final Workbench window — 2026-11-12

[Campaign43178348103](https://github.com/techrote/cybersand/actions/runs/43178348103)
passes completely from source `b04232560333e5de69af651c67e2a53a6679d5b4`,
tree `67f666562aeae9756e7cfa9663af64d035b90356`. The four-path runtime
publication child is `c6084fa15bb22e69fcf3e101080375a29a30a5b1`, tree
`4c5b563023bb271dcc81cc0cdcf767749ec9f9e9`. All four exact-child manual gates
pass: Documentation43184413537, Native43184416960 including TSAN/ASan/UBSan,
GDExtension43184420969 and palette43184425040. Palette executes all six
Linux/Windows cohorts and aggregate readback, qualifying the scoped evidence
attribute correction through actual rendering. The
[workflow ledger](materials-lab-completion-20261111/windows-evaluation-20261112/request7-manual-gates.json)
keeps bot-triggered `action_required` PR siblings separate from these executed
manual gates; approval policy is unchanged.

The preserved Windows package is artifact13927398778; inner ZIP707,297,673 bytes,
SHA-256 `c50d53778d24aed7cc45e90a11d1b398d557fdb3b99f212ce67f8ea7e73127e2`.
Outer artifact SHA-256 is
`a8d3a1294e5adf16f8bb0f543a52f51fbefc73678df234b69ef82718cc49705c`;
manifest `d3c84f914fa21be784601c6f81fabe507adefadf791e0ecb33a88510fbfbb2f7`.
Its Windows DLL is
`636f285beb96ce9ae02ab1df00527647220d538621df785c4a6c4275fbe5703c`.
Original relocated bundled-tool smoke artifact13927841392 passes UI205,
World204 and actual ANGLE contact187. Its outer SHA-256 is
`e696acc160676becd9c25da988f3be27b1b71d77b39f9f730552c61ea5fbbeb1`.
This is a recoverable source-qualified package, without the following final
Workbench popup correction. The earlier local default-AppData full UI rerun
also passed205/0 with both MSIX alias pairs naturally recurring; the executed
test blob matches published request7 exactly.

Manual1280x720 inspection found that the Workbench's embedded Lab inherited
the game's1920x1080 canvas scaling. Its13px controls shrank to roughly8px even
though the standalone Lab was already corrected. On supported desktop displays
the Lab now owns a native Window with disabled content scaling and local input.
Headless/Web retains embedded fallback; the game scale, clamped sizing and
modeless lifecycle are preserved. A new Window must be hidden before setting
`force_native`; the first ANGLE attempt exposed that lifecycle error and remains
retained locally, separately from the corrected passing run.

Actual Windows ANGLE focused popup qualification passes26/0 and reports
`embedded=false` with physical control scale `[1,1]` at1000x650 and1280x720.
Headless fallback passes24/0. Pause/step/camera keys and Lab clicks leave the
underlying native tick and authored edits unchanged; after closing, the original
Step shortcut advances exactly one native tick. Complete mounted authoring UI
passes217/0 in227.907s with bundled request5 tools and unchanged native DLL
`7aff557e...c6e2a2`. The
[original receipt](materials-lab-completion-20261111/windows-evaluation-20261112/ui-workbench-native-popup-final.json)
binds local base44645 plus its source delta, command and before/after hashes;
this does not claim execution of the future publication commit. Graphical source
custody now includes `shared_workbench.gd`; publisher guards refuse its omission
and pass8/8 outside the Windows temporary-directory sandbox restriction. The
first sandbox cleanup error is not counted as a passing run.

An independent exact-navigation probe starts with the original `--materials-lab`
argument and invokes mounted Close, Development workbench, Load liquid-lab and
Step handlers. It passes13/0 in5.111s: blank2048 request1 and equipment512
request2 are acknowledged, equipment serial1 is configured, and native tick
advances0 to1 while remaining paused. The worker is started/alive with no start
error throughout; ten recorded source hashes remain unchanged. The
[navigation proof](materials-lab-completion-20261111/windows-evaluation-20261112/navigation-proof.json)
records the actual local source/runtime identity. No navigation/owner defect was
reproduced; this headless handler probe does not qualify GUI coordinate hits.

Request8 carries only this bounded popup correction, its regressions/source
custody and documentation. Its complete fresh platform/package campaign and
exact-child gates remain required. No material physics, compatibility lock,
equipment owner, #563 consumer or production candidate installer changes.

## Request8 hosted desktop-fit refusal — 2026-11-12

[Campaign43283807002](https://github.com/techrote/cybersand/actions/runs/43283807002)
from source `42298e8129b5609b28c330b2fbfe936be45a51ef`, tree
`a9d65259f25939258e763d5d56a89b44e9d8bbf9`, correctly refuses publication.
Complete Linux catalogue/runtime/graphics pass: catalogue1348, experiment131,
contacts180, lifecycle87, mountedUI217, World204, Workbench164; graphicalUI226
and World209. Windows catalogue209 completes with206 passes and the three
unchanged POSIX-only skips; all seven headless cases and graphicalWorld209 pass.
Actual Windows graphicalUI runs226 assertions with exactly one failure:
the native Lab's initial bounds do not fit the usable desktop. Both later
explicit1000x650/1280x720 physical-scale/contact checks pass. Package creation,
runtime publication and final-child gate dispatch are skipped after this failure.

Original Windows artifact13976867296 is retained with outer SHA-256
`d7beb2ce65eae4634b0ad5732a464e18b267e315efa7e689b8905cbe708754dd`.
The first capture did not record initial screen/decorated geometry, so exact
hosted coordinates cannot be reconstructed from it. Pinned Godot's native
[`popup_centered_clamped`](https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/main/window.cpp#L1957-L1992)
uses the full monitor rather than its usable work area.
The strict initial-fit assertion is preserved; the correction must explicitly
admit client and decorated window bounds within the usable work area and record
the actual geometry. Request7 remains the fully qualified recovery package.

## Request9 usable-work-area correction — 2026-11-12

The native popup now selects its owning screen, measures visible client/frame
geometry, clamps the requested client to usable capacity minus actual borders,
and centers the complete frame in that usable area. The existing1000x650 client
minimum is preserved. An insufficient work area returns an explicit capacity
refusal instead of clipping the window or reducing its minimum. Embedded fallback
and all material/equipment/native ownership remain unchanged.

The strict initial client-bounds assertion remains. Tests additionally require
the title bar/borders to fit, retain geometry before every assertion, exercise
a restricted1024x728 area and a500x400 refusal, move the parent near a screen
edge, and close/reopen the retained native window across screens. Original root
Windows ANGLE tests pass44/0 on a portrait desktop and44/0 on a landscape desktop.
Measured borders are16x39; the restricted fixture admits a1008x689 client inside
the exact1024x728 outer rectangle. The landscape run verifies actual1000x650 and
1280x720 clients at physical scale `[1,1]`. The portrait run honestly records a
screen-clamped1184x720 client for the larger request. Headless fallback passes24/0.
The [geometry/custody record](materials-lab-completion-20261111/windows-evaluation-20261112/workarea-geometry-qualified-summary.json)
preserves original log hashes, measurements and the separate restricted-child
startup failure. It explicitly distinguishes the portrait observation from the
[landscape run's before/after source and tool receipt](materials-lab-completion-20261111/windows-evaluation-20261112/workarea-qualified-landscape.json).

Complete mounted UI authoring passes217/0 in213.101s with bundled tools and
unchanged inherited AppData. The
[full execution receipt](materials-lab-completion-20261111/windows-evaluation-20261112/workarea-qualified-full.json)
records local source8 plus the two named frozen placement deltas, before/after
hashes, actual native DLL636f285b...5703c, tools, command and watchdog. The
[headless receipt](materials-lab-completion-20261111/windows-evaluation-20261112/workarea-qualified-headless.json)
retains its own command and runtime identity. These are local delta qualifications,
not attestations of a future commit. Request9 requires the complete fresh
Windows/Linux, graphical, package and exact-publication-child gate campaign.
No assertion, compiler check, compatibility restriction or native consumer is
weakened; no authored candidate becomes production-active.

## Local readability follow-up — 2026-11-12

The local follow-up starts at publication `37dfc2cce9dbc2246eab9cb20d2efa7f04aae8a7`
with unchanged Windows DLL SHA-256
`1cd3b955fd24fdec58531b6fabd95563f054359c71a35008bff9c142338fb415`.
Inspect has six draggable column widths and horizontal scrolling. Selection
preserves widths; double-click restores a column's width. The menu separates
checking a definition, trying built-in materials, and comparing an edited copy.
Full technical values remain in hover text and the inspector details panel.
The capture validators bind the new property-table source.

Actual Windows ANGLE pointer tests pass 21 checks at both 1000x650 and 1280x720.
A separate interactive launch verified that dragging the Property divider widens
the actual table column. The local authoring regression passes 217 assertions,
the World comparison regression passes 204 checks, and graphical contacts and
compact tab layout pass 187 assertions. The authoring run preceded the final
wording-only clarification of the match choices and empty-copy message.
Publisher/package guards pass 8/16 on Linux; the direct Windows guard attempt
could not create symlink fixtures without the host privilege. The initial
unbundled compiler PATH and outdated-caption test failures are retained locally
under `build/lab-wording-*`; the successful runs use bundled tools and the revised
captions. No native source, compatibility lock, or material behavior changed.

This is a locally tested interface preview using the retained runtime. The
request9 ZIP, its source identity, and the published Draft remain unchanged.

## Local PressureFlow follow-up — 2026-11-12

On top of `0bf31bcd22573894d9fb45d54912baceb7ed5845`, the **Try originals**
Water movement model menu uses the existing native `pressure_flow_v1/reference`
assignment. Preparation checks the applied native policy hash against the
native validation receipt. The selected model appears in the prepared-run
summary, Inspect reads back the active experiment settings, and reopening a
matching case restores the menu and the solver. Compare edits continues to
use the built-in solver settings in both compiled Worlds.

Windows Godot `4.7.stable.official.5b4e0cb0f` used DLL SHA-256
`1cd3b955fd24fdec58531b6fabd95563f054359c71a35008bff9c142338fb415`
and experiment script SHA-256
`f3512c6eb4663f629d790795be2f259f6484928d16cb1fbf0f52e0b7ada2c34e`.
The headless `--path godot --script res://tests/test_material_lab_experiment.gd`
run passed 141 assertions, including one-worker, 32-tick Water/Wall execution,
exact repeat and source-bound case reopening. The Windows ANGLE
`res://tests/test_material_lab_ui.gd` run at 1280×720 passed 246 assertions
with bundled prerequisites and a 1,200-second watchdog. It prepared and
stepped a four-worker PressureFlow World, saved and reopened its case, and
copied the applied settings into Inspect. The local logs and UI receipt are
under `build/lab-pressure-*`. The Windows preview launcher import check passed.

The native source, compatibility lock and default production assignments are
unchanged. This is local Windows preview evidence. The request9 ZIP and Draft
#562 retain publication `37dfc2cce9dbc2246eab9cb20d2efa7f04aae8a7`.
